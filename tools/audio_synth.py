#!/usr/bin/env python3
"""Iron Front ses sentez motoru (müzik ve efektler ortak).

Telifli örnek kullanılmaz: tüm sesler matematiksel olarak üretilir.
- Dalga tablosu osilatörü (bant sınırlı, vibrato, detune, glide) -> düşük maliyetli zengin tınılar
- Enstrümanlar: yaylılar (topluluk), bakırlar (parlaklık zarfı), korno, trompet, çello/kontrbas, klarnet, obua, flüt,
  koro, piyano, pizzicato, çan/çelesta, timpani, trampet, bas davul, zil, tahta blok, siren
- Akor çözümleme ve yakın ses yürütmeli yerleşim
- Karıştırıcı: stereo pan, yankı gönderimi (salon yanıtı ile evrişim), bus sıkıştırma, sınırlayıcı, OGG/MP3/WAV yazımı
"""
from __future__ import annotations

import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 44100
rng = np.random.default_rng(1936)

# ------------------------------------------------------------------ nota ve akor
_NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(s: str) -> int:
    """'C#4', 'Bb3', 'E5' -> MIDI numarası."""
    i = 1
    acc = 0
    while i < len(s) and s[i] in "#b":
        acc += 1 if s[i] == "#" else -1
        i += 1
    return 12 * (int(s[i:]) + 1) + _NOTE[s[0]] + acc


def hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def mel(text: str) -> list:
    """'D4:1.5 E4:.5 r:1' -> [(midi|None, vuruş), ...]"""
    out = []
    for tok in text.split():
        n, d = tok.split(":")
        out.append((None if n == "r" else midi(n), float(d)))
    return out


_QUAL = {
    "": (0, 4, 7), "m": (0, 3, 7), "7": (0, 4, 7, 10), "m7": (0, 3, 7, 10), "maj7": (0, 4, 7, 11),
    "dim": (0, 3, 6), "dim7": (0, 3, 6, 9), "sus4": (0, 5, 7), "sus2": (0, 2, 7), "add9": (0, 4, 7, 14),
    "madd9": (0, 3, 7, 14), "aug": (0, 4, 8), "m6": (0, 3, 7, 9), "6": (0, 4, 7, 9),
}


def chord_pcs(sym: str) -> tuple[int, list[int]]:
    """'Dm', 'Bb', 'F#m7', 'A7', 'C/E' -> (kök perde sınıfı, aralıklar)."""
    base = sym.split("/")[0]
    i = 1
    acc = 0
    while i < len(base) and base[i] in "#b":
        acc += 1 if base[i] == "#" else -1
        i += 1
    root = (_NOTE[base[0]] + acc) % 12
    return root, list(_QUAL[base[i:]])


def chord_bass(sym: str) -> int:
    if "/" in sym:
        b = sym.split("/")[1]
        acc = b.count("#") - b.count("b")
        return (_NOTE[b[0]] + acc) % 12
    return chord_pcs(sym)[0]


def voicing(sym: str, low: int, high: int, prev: list[int] | None = None, n: int = 4) -> list[int]:
    """Akoru [low, high] aralığında n sesle yakın yerleştir; önceki akora en yakın olanı seç (ses yürütme)."""
    root, iv = chord_pcs(sym)
    pcs = {(root + x) % 12 for x in iv}
    tones = [m for m in range(low, high + 1) if m % 12 in pcs]
    need = min(len(pcs), n)
    cands = [tones[i:i + n] for i in range(len(tones) - n + 1) if len({x % 12 for x in tones[i:i + n]}) >= need]
    if not cands:
        return tones[:n] if len(tones) >= n else [low + (root - low) % 12 + 12 * k for k in range(n)]
    if prev is None:
        mid = (low + high) / 2
        return min(cands, key=lambda v: abs(sum(v) / n - mid))
    return min(cands, key=lambda v: sum(min(abs(a - b) for b in prev) for a in v))


# ------------------------------------------------------------------ zarflar ve filtreler
def adsr(n: int, a: float, d: float, s: float, r: float, hold: float) -> np.ndarray:
    """Saldırı/düşüş/sürdürme/bırakma; hold = bırakmanın başladığı an (sn)."""
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    rel = np.exp(-np.maximum(t - hold, 0) / max(r / 4.6, 1e-4))
    e = e * np.where(t < hold, 1.0, rel)
    return e


def fade_edges(x: np.ndarray, a: float = 0.002, r: float = 0.01) -> np.ndarray:
    n = len(x)
    ka = min(int(a * SR), n // 2)
    kr = min(int(r * SR), n // 2)
    if ka > 0:
        x[:ka] *= np.linspace(0, 1, ka)
    if kr > 0:
        x[-kr:] *= np.linspace(1, 0, kr)
    return x


def bandpass(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    n = len(x)
    if n < 8:
        return x
    f = np.fft.rfftfreq(n, 1 / SR)
    m = np.ones_like(f)
    if lo > 0:
        m *= 1 / (1 + (lo / np.maximum(f, 1)) ** 4)
    if hi < SR / 2:
        m *= 1 / (1 + (f / hi) ** 4)
    return np.fft.irfft(np.fft.rfft(x) * m, n)


def lowpass(x, fc):
    return bandpass(x, 0, fc)


def highpass(x, fc):
    return bandpass(x, fc, SR / 2)


def noise(d: float) -> np.ndarray:
    return rng.standard_normal(max(int(SR * d), 1))


# ------------------------------------------------------------------ dalga tablosu osilatörü
TL = 4096


def table(amps, phases=None) -> np.ndarray:
    """Tek periyot: sum a_k sin(2πk t + φ_k)."""
    t = np.arange(TL) / TL
    x = np.zeros(TL)
    for k, a in enumerate(amps, 1):
        if a == 0:
            continue
        ph = 0.0 if phases is None else phases[k - 1]
        x += a * np.sin(2 * np.pi * k * t + ph)
    m = np.abs(x).max()
    return x / m if m > 0 else x


def spectrum(f0: float, kind: str, bright: float = 1.0) -> list[float]:
    """Tını reçeteleri: harmonik genlikleri (Nyquist altında)."""
    kmax = max(1, int((SR * 0.45) / f0))
    out = []
    for k in range(1, min(kmax, 120) + 1):
        fk = k * f0
        if kind == "string":
            a = (1 / k) * np.exp(-fk / (3200 * bright)) * (1 + 0.6 * np.exp(-((fk - 2800) / 900) ** 2))
        elif kind == "cello":
            a = (1 / k) * np.exp(-fk / (1700 * bright))
        elif kind == "brass":
            a = k ** -0.85 * np.exp(-fk / (3000 * bright))
        elif kind == "horn":
            a = k ** -1.2 * np.exp(-fk / (1300 * bright))
        elif kind == "trumpet":
            a = k ** -0.7 * np.exp(-fk / (3800 * bright)) * (1 + 0.8 * np.exp(-((fk - 1500) / 700) ** 2))
        elif kind == "clarinet":
            a = (1 / k if k % 2 else 0.06 / k) * np.exp(-fk / (3500 * bright))
        elif kind == "oboe":
            a = (0.35 if k == 1 else 1.0 / (1 + 0.25 * (k - 2) ** 1.4)) * np.exp(-fk / (4200 * bright))
        elif kind == "flute":
            a = [1.0, 0.28, 0.12, 0.05, 0.02][k - 1] if k <= 5 else 0.0
        elif kind == "choir":
            a = (1 / k ** 0.6) * (np.exp(-((fk - 650) / 220) ** 2) + 0.7 * np.exp(-((fk - 1080) / 260) ** 2)
                                 + 0.25 * np.exp(-((fk - 2600) / 400) ** 2) + (0.35 if k == 1 else 0))
        elif kind == "organ":
            a = {1: 1.0, 2: 0.5, 3: 0.3, 4: 0.25, 6: 0.12, 8: 0.1}.get(k, 0.0)
        else:  # sine
            a = 1.0 if k == 1 else 0.0
        out.append(float(a))
    return out


_TABLE_CACHE: dict = {}


def cached_table(f0: float, kind: str, bright: float, variant: int = 0) -> np.ndarray:
    key = (round(f0 / 1.0), kind, round(bright, 2), variant)
    if key not in _TABLE_CACHE:
        amps = spectrum(f0, kind, bright)
        ph = np.random.default_rng(variant * 7919 + int(f0)).uniform(0, 2 * np.pi, len(amps))
        _TABLE_CACHE[key] = table(amps, ph)
    return _TABLE_CACHE[key]


def osc(tbl: np.ndarray, freq: np.ndarray, phase0: float = 0.0) -> np.ndarray:
    """freq: anlık frekans dizisi (Hz)."""
    ph = (phase0 + np.cumsum(freq) / SR) % 1.0
    pos = ph * TL
    i = pos.astype(np.int64)
    fr = pos - i
    return tbl[i % TL] * (1 - fr) + tbl[(i + 1) % TL] * fr


def freq_curve(f: float, n: int, vib_rate=5.5, vib_depth=0.0, vib_delay=0.25, glide_from=None, glide=0.06,
               detune_cents=0.0, drift=0.0) -> np.ndarray:
    t = np.arange(n) / SR
    fc = np.full(n, f * 2 ** (detune_cents / 1200))
    if glide_from is not None:
        g = np.exp(-t / max(glide, 1e-3))
        fc *= (glide_from / f) ** g
    if vib_depth > 0:
        on = np.clip((t - vib_delay) / 0.35, 0, 1)
        fc *= 1 + vib_depth * on * np.sin(2 * np.pi * vib_rate * t + rng.uniform(0, 6.28))
    if drift > 0:
        fc *= 1 + drift * np.sin(2 * np.pi * 0.3 * t + rng.uniform(0, 6.28))
    return fc


# ------------------------------------------------------------------ enstrümanlar (mono çıkış)
def strings(m: float, dur: float, vel=0.7, attack=0.28, release=0.6, voices=3, kind="string", bright=1.0,
            vib=0.004, legato_from=None):
    f = hz(m)
    n = int((dur + release) * SR)
    out = np.zeros(n)
    for v in range(voices):
        det = rng.uniform(-9, 9)
        tbl = cached_table(f, kind, bright * (0.8 + 0.4 * vel), v)
        fc = freq_curve(f, n, rng.uniform(4.8, 6.0), vib, 0.2 + rng.uniform(0, 0.2),
                        glide_from=hz(legato_from) if legato_from else None, glide=0.08, detune_cents=det, drift=0.0008)
        out += osc(tbl, fc, rng.uniform(0, 1))
    env = adsr(n, attack * (1.3 - vel * 0.5), 0.6, 0.85, release, dur)
    bow = lowpass(highpass(rng.standard_normal(n), 1500), 6000) * 0.0035 * env
    return (out / voices * env + bow) * vel


def brass(m: float, dur: float, vel=0.8, kind="brass", attack=0.05, release=0.35, voices=2, vib=0.003, scoop=True):
    f = hz(m)
    n = int((dur + release) * SR)
    out = np.zeros(n)
    t = np.arange(n) / SR
    # parlaklık zarfı: saldırıda açılır (bakır "blat"), sonra biraz kapanır
    bright_env = 0.55 + 0.45 * np.exp(-np.maximum(t - attack, 0) / 0.35) * vel + 0.35 * vel
    for v in range(voices):
        dark = cached_table(f, kind, 0.45, v)
        brt = cached_table(f, kind, 1.25 * (0.7 + 0.5 * vel), v + 11)
        fc = freq_curve(f, n, rng.uniform(4.8, 5.6), vib, 0.35, glide_from=f * 2 ** (-35 / 1200) if scoop else None,
                        glide=0.045, detune_cents=rng.uniform(-6, 6), drift=0.0006)
        ph0 = rng.uniform(0, 1)
        a = osc(dark, fc, ph0)
        b = osc(brt, fc, ph0)
        w = np.clip(bright_env - 0.55, 0, 1)
        out += a * (1 - w) + b * w
    env = adsr(n, attack, 0.3, 0.8, release, dur)
    breath = bandpass(rng.standard_normal(n), 800, 5000) * 0.005 * env
    return (out / voices * env + breath) * vel


def woodwind(m: float, dur: float, vel=0.7, kind="clarinet", attack=0.06, release=0.25, vib=0.005):
    f = hz(m)
    n = int((dur + release) * SR)
    tbl = cached_table(f, kind, 0.9 + 0.3 * vel, 3)
    fc = freq_curve(f, n, 5.2, vib, 0.25, detune_cents=rng.uniform(-3, 3), drift=0.0005)
    x = osc(tbl, fc, rng.uniform(0, 1))
    env = adsr(n, attack, 0.4, 0.88, release, dur)
    breath = bandpass(rng.standard_normal(n), 1500, 8000) * (0.025 if kind == "flute" else 0.008) * env
    return (x * env + breath) * vel


def choir(m: float, dur: float, vel=0.6, attack=0.5, release=0.9, voices=4):
    return strings(m, dur, vel, attack, release, voices, kind="choir", bright=1.0, vib=0.006)


def piano(m: float, dur: float, vel=0.7, release=0.4):
    f = hz(m)
    total = min(dur + release, 6.0)
    n = int(total * SR)
    t = np.arange(n) / SR
    B = 0.00018 * (1 + (m - 60) / 30)
    x = np.zeros(n)
    for k in range(1, 16):
        fk = f * k * np.sqrt(1 + B * k * k)
        if fk > SR * 0.45:
            break
        a = (1 / k ** 1.35) * (0.6 + 0.4 * vel) ** (k * 0.25)
        dec = (1.8 + 60 / max(m - 20, 5)) / (1 + 0.35 * k)
        x += a * np.sin(2 * np.pi * fk * t + rng.uniform(0, 6.28)) * np.exp(-t / dec)
    hammer = bandpass(noise(0.03), 1500, 7000) * np.exp(-np.arange(int(0.03 * SR)) / SR / 0.006) * 0.25 * vel
    x[: len(hammer)] += hammer
    damp = np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.12))
    x *= damp
    x[: int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    return x * vel


def pizz(m: float, vel=0.7, dur=0.6):
    f = hz(m)
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k in range(1, 10):
        fk = f * k
        if fk > SR * 0.45:
            break
        x += (1 / k ** 1.1) * np.sin(2 * np.pi * fk * t) * np.exp(-t * (6 + 3.5 * k))
    x[: int(0.001 * SR)] *= np.linspace(0, 1, int(0.001 * SR))
    return x * vel


def bell(m: float, vel=0.6, dur=4.0, bright=1.0):
    f = hz(m)
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for ratio, a, dec in ((0.5, 0.35, 3.5), (1.0, 1.0, 2.4), (1.19, 0.5, 1.6), (1.56, 0.4, 1.1), (2.0, 0.55, 1.2),
                          (2.51, 0.25 * bright, 0.7), (2.66, 0.2 * bright, 0.6), (3.01, 0.15 * bright, 0.45)):
        x += a * np.sin(2 * np.pi * f * ratio * t + rng.uniform(0, 6.28)) * np.exp(-t / dec)
    x[: int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    return x * vel


def timpani(m: float, vel=0.8, dur=2.2):
    f = hz(m)
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for ratio, a, dec in ((1.0, 1.0, 0.9), (1.504, 0.55, 0.6), (1.742, 0.3, 0.45), (2.0, 0.28, 0.4), (2.245, 0.15, 0.3)):
        fr = f * ratio * (1 + 0.012 * np.exp(-t / 0.05))
        x += a * np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t / dec)
    hit = lowpass(noise(0.08), 1800) * np.exp(-np.arange(int(0.08 * SR)) / SR / 0.012) * 0.4
    x[: len(hit)] += hit
    x[: int(0.001 * SR)] *= np.linspace(0, 1, int(0.001 * SR))
    return x * vel


def timpani_roll(m: float, dur: float, v0=0.2, v1=0.9, rate=16.0):
    n = int((dur + 1.5) * SR)
    x = np.zeros(n)
    k = int(dur * rate)
    for i in range(k):
        v = v0 + (v1 - v0) * (i / max(k - 1, 1))
        h = timpani(m, v * rng.uniform(0.85, 1.0), 1.2)
        o = int((i / rate + rng.uniform(-0.004, 0.004)) * SR)
        o = max(o, 0)
        x[o:o + len(h)] += h[: n - o] * 0.55
    return x


def snare(vel=0.7, dur=0.35, snappy=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.035) + 0.5 * np.sin(2 * np.pi * 330 * t) * np.exp(-t / 0.025)
    wires = bandpass(noise(dur), 2000, 8000) * np.exp(-t / (0.065 * snappy))
    x = body * 0.55 + wires * 0.8
    x[: int(0.0008 * SR)] *= np.linspace(0, 1, int(0.0008 * SR))
    return x * vel


def snare_roll(dur: float, v0=0.2, v1=0.8, rate=22.0):
    n = int((dur + 0.4) * SR)
    x = np.zeros(n)
    k = int(dur * rate)
    for i in range(k):
        v = v0 + (v1 - v0) * (i / max(k - 1, 1))
        h = snare(v * rng.uniform(0.8, 1.0), 0.18, 0.8)
        o = int((i / rate + rng.uniform(-0.003, 0.003)) * SR)
        o = max(o, 0)
        x[o:o + len(h)] += h[: n - o] * 0.6
    return x


def bass_drum(vel=0.8, dur=0.9):
    n = int(dur * SR)
    t = np.arange(n) / SR
    fr = 52 * (1 + 1.2 * np.exp(-t / 0.03))
    x = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t / 0.28)
    x += lowpass(noise(dur), 600) * np.exp(-t / 0.03) * 0.3
    return x * vel


def cymbal(vel=0.6, dur=3.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = highpass(noise(dur), 3000) * np.exp(-t / 0.9) + bandpass(noise(dur), 5000, 12000) * np.exp(-t / 0.35) * 0.6
    x[: int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    return x * vel


def woodblock(vel=0.5, pitch=900.0):
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * pitch * t) * np.exp(-t / 0.025) + 0.4 * np.sin(2 * np.pi * pitch * 2.7 * t) * np.exp(-t / 0.012)
    x += bandpass(noise(0.12), 2000, 7000) * np.exp(-t / 0.004) * 0.3
    return x * vel


def siren(dur=6.0, f0=240.0, f1=620.0, vel=0.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    rise = np.clip(t / (dur * 0.45), 0, 1)
    fall = np.clip((t - dur * 0.6) / (dur * 0.4), 0, 1)
    f = f0 + (f1 - f0) * (np.sin(rise * np.pi / 2) ** 1.5) * (1 - fall * 0.6)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)
    x = lowpass(x, 2500)
    env = np.clip(t / 0.4, 0, 1) * np.clip((dur - t) / 1.2, 0, 1)
    return x * env * vel


# ------------------------------------------------------------------ karıştırıcı ve mastering
class Mix:
    def __init__(self, seconds: float):
        self.dry = np.zeros((2, int(SR * (seconds + 10))))
        self.send = np.zeros_like(self.dry)
        self.length = seconds

    def add(self, t: float, x: np.ndarray, pan: float = 0.0, gain: float = 1.0, rev: float = 0.25):
        i = int(max(t, 0) * SR)
        n = len(x)
        if i + n > self.dry.shape[1]:
            grow = i + n - self.dry.shape[1] + SR
            self.dry = np.pad(self.dry, ((0, 0), (0, grow)))
            self.send = np.pad(self.send, ((0, 0), (0, grow)))
        p = (np.clip(pan, -1, 1) + 1) * np.pi / 4
        l, r = np.cos(p), np.sin(p)
        self.dry[0, i:i + n] += x * gain * l
        self.dry[1, i:i + n] += x * gain * r
        if rev > 0:
            self.send[0, i:i + n] += x * gain * rev * l
            self.send[1, i:i + n] += x * gain * rev * r

    def render(self, rt60=2.4, predelay=0.025, tail=4.0) -> np.ndarray:
        end = min(int(SR * (self.length + tail)), self.dry.shape[1])
        dry = self.dry[:, :end]
        send = self.send[:, :end]
        wet = np.zeros_like(dry)
        for ch in range(2):
            ir = hall_ir(rt60, predelay, seed=ch)
            wet[ch] = fft_convolve(send[ch], ir)[:end]
        return dry + wet


def hall_ir(rt60=2.4, predelay=0.025, seed=0) -> np.ndarray:
    g = np.random.default_rng(100 + seed)
    d = rt60 * 1.1
    n = int(d * SR)
    t = np.arange(n) / SR
    ir = np.zeros(n)
    # erken yansımalar
    for _ in range(14):
        tt = predelay + g.uniform(0.004, 0.09)
        ir[int(tt * SR)] += g.uniform(0.25, 0.7) * (1 if g.random() > 0.5 else -1)
    # frekansa bağlı sönümlenen kuyruk: bas uzun, tiz kısa
    tail = np.zeros(n)
    for lo, hi, scale in ((0, 500, 1.15), (500, 3000, 1.0), (3000, 12000, 0.55)):
        tau = rt60 * scale / 6.9
        band = bandpass(g.standard_normal(n), lo, hi)
        tail += band * np.exp(-np.maximum(t - predelay, 0) / tau) * (t > predelay + 0.01)
    tail *= np.clip((t - predelay) / 0.08, 0, 1)
    ir += tail * 0.12
    ir /= np.sqrt((ir ** 2).sum()) + 1e-9
    return ir


def fft_convolve(x: np.ndarray, h: np.ndarray) -> np.ndarray:
    n = len(x) + len(h) - 1
    nf = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, nf) * np.fft.rfft(h, nf), nf)[:n]


def moving_average(x: np.ndarray, win: int) -> np.ndarray:
    """Merkezli kayan ortalama, O(n) (kümülatif toplam)."""
    win = max(int(win), 1)
    c = np.cumsum(np.concatenate([np.zeros(1), x]))
    h = win // 2
    idx = np.arange(len(x))
    lo = np.clip(idx - h, 0, len(x))
    hi = np.clip(idx - h + win, 0, len(x))
    return (c[hi] - c[lo]) / np.maximum(hi - lo, 1)


def master(st: np.ndarray, target_rms_db=-19.0, ceiling_db=-1.0, fade_out=3.0) -> np.ndarray:
    """Bus sıkıştırma (yavaş, yumuşak) + normalleştirme + yumuşak sınırlayıcı + son kararma."""
    st = st - st.mean(axis=1, keepdims=True)
    power = (st ** 2).mean(axis=0)
    env = np.sqrt(moving_average(power, int(0.3 * SR))) + 1e-6
    ref = np.percentile(env, 90)
    thr = ref * 0.5
    gain = np.where(env > thr, (thr / env) ** (1 - 1 / 2.2), 1.0)
    gain = moving_average(gain, int(0.05 * SR))
    st = st * gain
    rms = np.sqrt((st ** 2).mean())
    st *= 10 ** (target_rms_db / 20) / (rms + 1e-9)
    ceil = 10 ** (ceiling_db / 20)
    st = np.tanh(st / ceil) * ceil
    if fade_out > 0:
        k = int(fade_out * SR)
        st[:, -k:] *= np.linspace(1, 0, k) ** 2
    k0 = int(0.01 * SR)
    st[:, :k0] *= np.linspace(0, 1, k0)
    return st


def write_ogg(path: Path, st: np.ndarray, quality: float = 0.45):
    import soundfile as sf
    path.parent.mkdir(parents=True, exist_ok=True)
    data = np.ascontiguousarray(st.T.astype(np.float32))
    # libsndfile Vorbis kodlayıcısı büyük tek yazımda yığın taşmasıyla kilitleniyor: parça parça yaz
    with sf.SoundFile(str(path), "w", SR, data.shape[1], format="OGG", subtype="VORBIS", compression_level=1 - quality) as f:
        for i in range(0, len(data), 4096):
            f.write(data[i:i + 4096])


def write_mp3(path: Path, st: np.ndarray, kbps: int = 112):
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with tempfile.TemporaryDirectory() as d:
            w = Path(d) / "x.wav"
            write_wav(w, st)
            subprocess.run(["lame", "--quiet", "-b", str(kbps), str(w), str(path)], check=True)
    except FileNotFoundError:
        # lame kurulu değilse libsndfile'ın MP3 kodlayıcısı (soundfile >= 0.12, libsndfile >= 1.1)
        import soundfile as sf
        data = np.ascontiguousarray(st.T.astype(np.float32))
        with sf.SoundFile(str(path), "w", SR, data.shape[1], format="MP3", subtype="MPEG_LAYER_III") as f:
            for i in range(0, len(data), 4096):
                f.write(data[i:i + 4096])


def write_wav(path: Path, x: np.ndarray, peak: float | None = None):
    path.parent.mkdir(parents=True, exist_ok=True)
    x = np.asarray(x, dtype=np.float64)
    if peak is not None:
        x = x / (np.abs(x).max() + 1e-9) * peak
    x = np.clip(x, -1, 1)
    ch = 1 if x.ndim == 1 else x.shape[0]
    data = (x.T * 32767).astype("<i2") if ch > 1 else (x * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
