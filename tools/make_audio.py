#!/usr/bin/env python3
"""Iron Front ses efektleri (prosedürel sentez) -> assets/audio/*.wav

Ses dünyası: 1936–45 karargâhında bir harekât masasının başında durmak. Pirinç iğne, keçe kaplı masa, kâğıt, deri dosya,
daktilo, teleks, telgraf, sahra telefonu, telsiz cızırtısı. Savaşın kendisi uzaktan, bir telefon hattının ya da kapalı bir
pencerenin ardından duyulur; böylece yakın zoom'daki 3B muharebe sesleriyle (BattleAudio) karışmaz.
- Arayüz: bakalit şalter, deri dosya, fihrist, lastik damga, pirinç kol, saat dişlisi.
- Harita rozetleri (üstüne gelince): iğnenin keçeye dokunuşu + o yapının uzaktan gelen minyatür imzası.
- Birim sayaçları: ahşap sayaç, kâğıt üstünde kaydırma, mantara iğne, sahra telefonu tıkı, sözsüz hat mırıltısı.
- Bildirimler: teleks, masa zili, kurye zarfı, daktilo şaryosu, dosya kapağı, uzak fabrika düdüğü (müzik ve modern
  bildirim sesi yok).
Sık çalan sesler 2–3 çeşitlemeyle üretilir (ad_1.wav, ad_2.wav...); oyun rastgele birini seçer.
Müzikler ve olay müzikleri: tools/make_music.py. Telifli örnek ve tarihî kayıt kullanılmaz: her şey matematiksel sentez.

Çalıştır: python3 tools/make_audio.py [ad ...]     (adsız: hepsi)
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audio_synth import SR, bandpass, bell as _bell, highpass, lowpass, write_wav  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
rng = np.random.default_rng(1938)


# ------------------------------------------------------------------ yardımcılar
class Sig(np.ndarray):
    """Uzunlukları farklı sinyaller toplanınca kısa olan sıfırla uzatılır."""
    def __add__(self, other):
        if isinstance(other, np.ndarray) and other.ndim == 1 and self.ndim == 1 and len(other) != len(self):
            n = max(len(self), len(other))
            out = np.zeros(n)
            out[: len(self)] += np.asarray(self)
            out[: len(other)] += np.asarray(other)
            return out.view(Sig)
        return np.ndarray.__add__(self, other)

    __radd__ = __add__


def S(x):
    return np.asarray(x, dtype=np.float64).view(Sig)


def bell(*a, **k):
    return S(_bell(*a, **k))


def t_(d):
    return np.arange(int(SR * d)) / SR


def noise(d):
    return rng.standard_normal(max(int(SR * d), 1))


def dec(d, tau):
    return np.exp(-t_(d) / tau)


def env_ar(d, a, r):
    """Doğrusal giriş (a sn) ve çıkış (r sn) zarfı."""
    t = t_(d)
    return np.minimum(t / max(a, 1e-4), 1) * np.minimum((d - t) / max(r, 1e-4), 1)


def at(x, offset, part):
    o = int(SR * offset)
    n = max(len(x), o + len(part))
    out = np.zeros(n)
    out[: len(x)] = x
    out[o:o + len(part)] += part
    return S(out)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return S(out)


def room(x, d=0.35, wet=0.25, dark=4000, seed=0):
    """Küçük ahşap oda / masa yankısı."""
    g = np.random.default_rng(seed)
    ir = g.standard_normal(int(d * SR)) * np.exp(-t_(d) / (d / 4))
    ir = lowpass(ir, dark)
    ir /= np.abs(ir).sum() / 30
    n = len(x) + len(ir)
    y = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)
    out = np.zeros(n)
    out[: len(x)] += x
    return S(out + wet * y)


def hall(x, d=1.2, wet=0.4, dark=2500, seed=1):
    return room(x, d, wet, dark, seed)


def distant(x, cutoff=2200.0, wet=0.3, level=0.5, seed=99, d=0.3):
    """Kapalı pencere ardından / telefon hattından: tizler ve en altlar kırpılır, küçük oda, düşük düzey."""
    y = lowpass(highpass(np.asarray(x, dtype=np.float64), 160), cutoff)
    return S(room(y, d, wet, min(cutoff, 3500), seed) * level)


def tick(d=0.012, lo=2500, hi=9000, tau=0.0015):
    return S(bandpass(noise(d), lo, hi) * dec(d, tau))


def partials(freqs, amps, taus, d):
    t = t_(d)
    x = np.zeros_like(t)
    for f, a, tau in zip(freqs, amps, taus):
        x += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / tau)
    return S(x)


def thump(f=70.0, d=0.35, tau=0.12, punch=0.4):
    t = t_(d)
    x = np.sin(2 * np.pi * np.cumsum(f * (1 + 1.4 * np.exp(-t / 0.02))) / SR) * np.exp(-t / tau)
    x += lowpass(noise(d), 900) * np.exp(-t / 0.012) * punch
    return S(x)


def sweep_noise(d, f0, f1, width=0.6):
    """Merkezi f0'dan f1'e kayan bant gürültüsü (kısa pencerelerle)."""
    n = int(d * SR)
    out = np.zeros(n)
    seg = int(0.02 * SR)
    for i in range(0, n, seg // 2):
        fc = f0 + (f1 - f0) * (i / max(n, 1))
        part = bandpass(noise(seg / SR), fc * (1 - width / 2), fc * (1 + width / 2)) * np.hanning(seg)
        e = min(n, i + seg)
        out[i:e] += part[: e - i]
    return S(out)


def radio(x, drive=2.5):
    """Telsiz / telefon hattı: bant sınırlı + hafif doyum."""
    y = bandpass(np.asarray(x, dtype=np.float64), 350, 3000)
    y = np.tanh(y * drive / (np.abs(y).max() + 1e-9)) / np.tanh(drive)
    return S(y)


def squelch(d=0.08):
    return S(bandpass(noise(d), 800, 3500) * np.minimum(t_(d) / 0.004, 1) * dec(d, 0.03))


def chatter(d=0.35, seed=0):
    """Boğuk hat mırıltısı izlenimi: hece zarflı, formantlı gürültü + ses tellerini andıran ton (sözsüz, anlaşılmaz)."""
    g = np.random.default_rng(seed)
    t = t_(d)
    syll = np.zeros_like(t)
    pos = 0.0
    while pos < d:
        ln = g.uniform(0.06, 0.13)
        c = pos + ln / 2
        syll += np.exp(-((t - c) / (ln / 2.5)) ** 2) * g.uniform(0.5, 1.0)
        pos += ln + g.uniform(0.01, 0.05)
    f0 = g.uniform(105, 140) * (1 + 0.08 * np.sin(2 * np.pi * g.uniform(2, 4) * t))
    ph = 2 * np.pi * np.cumsum(f0) / SR
    voice = sum(np.sin(k * ph) / k for k in range(1, 18))
    formants = np.zeros_like(t)
    for fc, bw in ((g.uniform(500, 800), 200), (g.uniform(1100, 1700), 300), (2500, 400)):
        formants += bandpass(voice, fc - bw, fc + bw)
    x = (formants * 0.8 + bandpass(noise(d), 1500, 3000) * 0.15) * syll
    return S(radio(x, 3.0) * 0.6)


def beep(f, d, level=0.5):
    return S(np.sin(2 * np.pi * f * t_(d)) * env_ar(d, 0.003, 0.006) * level)


def step(level=1.0):
    return S((lowpass(noise(0.08), 1400) * dec(0.08, 0.018) + thump(95, 0.1, 0.03, 0.2) * 0.6) * level)


def trim_tail(x, thr_db=-54.0, keep=0.04):
    """Sondaki duyulmaz yankı kuyruğunu kes (tepeye göre eşik altı), kısa kararma ile bitir: başta ve sonda sessizlik yok."""
    x = np.asarray(x, dtype=np.float64)
    a = np.abs(x) / (np.abs(x).max() + 1e-9)
    idx = np.nonzero(a > 10 ** (thr_db / 20))[0]
    if len(idx) == 0:
        return x
    end = min(len(x), int(idx[-1] + keep * SR))
    x = x[:end].copy()
    k = min(int(0.02 * SR), end)
    x[-k:] *= np.linspace(1, 0, k)
    return x


def w(name, x, peak=0.7):
    write_wav(OUT / f"{name}.wav", trim_tail(x), peak)


# ------------------------------------------------------------------ harekât masası paleti
def felt_tap(level=1.0, pitch=1.0):
    """Pirinç iğnenin keçe kaplı masaya hafif dokunuşu: keçenin boğuk tıkı, masa gövdesi, ince pirinç çınlaması."""
    felt = lowpass(noise(0.05), 1300 * pitch) * dec(0.05, 0.006)
    body = thump(185 * pitch, 0.08, 0.02, 0.0) * 0.45
    brass = partials([5300 * pitch, 7800 * pitch], [0.1, 0.05], [0.012, 0.008], 0.04)
    return mix(S(felt * 0.8), body, brass) * level


def cork_push(level=1.0, d=0.07, firm=False):
    """İğnenin mantar panoya itilmesi: çıtırtılı sürtünme + küçük tokluk (firm: kararlı, sert)."""
    t = t_(d)
    gate = rng.random(len(t)) ** (2.5 if not firm else 1.8)
    crunch = bandpass(noise(d) * gate, 700, 5000) * np.minimum(t / 0.008, 1) * dec(d, 0.028)
    thud = thump(150 if not firm else 120, 0.07, 0.016, 0.35) * (0.6 if not firm else 1.0)
    return mix(S(crunch * (1.0 if not firm else 1.3)), at(np.zeros(1), d * 0.55, thud)) * level


def cork_pull(level=1.0, d=0.08):
    """İğnenin mantardan çekilmesi: yükselen sürtünme + küçük 'pop'."""
    t = t_(d)
    gate = rng.random(len(t)) ** 2.5
    scr = bandpass(noise(d) * gate, 900, 6000) * np.minimum(t / (d * 0.8), 1) * dec(d, 0.06)
    pop = at(np.zeros(1), d * 0.85, tick(0.01, 1500, 5000, 0.002) * 0.6 + thump(260, 0.03, 0.006, 0.2) * 0.4)
    return mix(S(scr), pop) * level


def wood_knock(level=1.0, pitch=1.0, soft=False):
    """Ahşap sayaç masaya konur / kaldırılır: kısa tok vuruş + ahşap tınısı."""
    x = thump(230 * pitch, 0.09, 0.02 if not soft else 0.012, 0.35 if not soft else 0.15)
    ring = partials([1150 * pitch, 2050 * pitch, 3300 * pitch], [0.25, 0.12, 0.06], [0.02, 0.012, 0.008], 0.06)
    return mix(x, ring * (0.6 if soft else 1.0)) * level


def scrape(d=0.25, lo=1200, hi=4500, level=1.0, seed=0):
    """Sayacın kâğıt harita üstünde kaydırılması: dalgalı sürtünme."""
    g = np.random.default_rng(seed)
    t = t_(d)
    env = np.sin(np.pi * np.clip(t / d, 0, 1)) ** 0.8
    ripple = 0.65 + 0.35 * np.sin(2 * np.pi * g.uniform(26, 40) * t + g.uniform(0, 6))
    return S(bandpass(noise(d), lo, hi) * env * ripple) * level


def line_click(level=1.0):
    """Sahra telefonu hattının tıkı: kısa tık + bir anlık hat vızıltısı (hat filtresinden)."""
    t = t_(0.06)
    hum = lowpass(np.sign(np.sin(2 * np.pi * 50 * t)), 600) * dec(0.06, 0.015) * 0.3
    return S(radio(mix(tick(0.012, 1200, 4000, 0.002), S(hum)), 2.0)) * level


def morse(seq, f=850.0, unit=0.045, level=0.5, freqs=None):
    """Telgraf: '.' kısa, '-' uzun; freqs verilirse her işaret sırayla o tonda (yükselen/alçalan çift ton)."""
    x = np.zeros(1)
    off = 0.0
    for i, ch in enumerate(seq):
        d = unit if ch == "." else unit * 3
        fi = f if freqs is None else freqs[i % len(freqs)]
        x = at(x, off, beep(fi, d, 1.0) + tick(0.004, 2000, 6000, 0.001) * 0.3)
        off += d + unit
    return S(radio(x, 1.8)) * level


def teleprinter(d=0.5, stutter=False, seed=0):
    """Teleks: bir satır basar; her karakter bir çekiç tıkı, altında motor vızıltısı (stutter: takılan, düzensiz)."""
    g = np.random.default_rng(seed)
    x = np.zeros(1)
    off = 0.02
    while off < d:
        hit = tick(0.014, 1400, 6000, 0.0025) * g.uniform(1.0, 1.6) + thump(300, 0.03, 0.006, 0.3) * 0.55
        x = at(x, off, hit)
        off += g.uniform(0.07, 0.11) if not stutter else g.choice([0.05, 0.06, 0.17, 0.22])
    t = t_(d + 0.05)
    hum = lowpass(np.sign(np.sin(2 * np.pi * 98 * t)), 500) * 0.07 * env_ar(d + 0.05, 0.02, 0.05)
    return mix(x, S(hum))


def small_bell(f=1400.0, d=0.8, tau=0.22, level=0.5, seed=0):
    """Küçük pirinç zil (masa zili, şaryo zili): inharmonik kısımlar, hızlı sönüm, vuruş tıkı."""
    g = np.random.default_rng(seed)
    t = t_(d)
    x = np.zeros_like(t)
    for r, a, k in ((1.0, 1.0, 1.0), (2.0, 0.5, 0.7), (2.76, 0.35, 0.5), (3.9, 0.2, 0.35), (5.4, 0.1, 0.25)):
        x += a * np.sin(2 * np.pi * f * r * t + g.uniform(0, 6.28)) * np.exp(-t / (tau * k))
    strike = bandpass(noise(0.012), 3000, 9000) * dec(0.012, 0.002) * 0.5
    x[: len(strike)] += strike
    x[: int(0.001 * SR)] *= np.linspace(0, 1, int(0.001 * SR))
    return S(x * level)


def paper_tear(d=0.25, level=1.0, seed=0):
    """Zarf yırtılır: çıtırtılı gürültü, hızlanan, sonda durur."""
    g = np.random.default_rng(seed)
    t = t_(d)
    gate = (g.random(len(t)) < np.clip(0.25 + 0.6 * t / d, 0, 0.9)).astype(float)
    x = bandpass(noise(d) * gate, 1500, 6500) * env_ar(d, 0.02, 0.03)
    return S(x) * level


def factory_whistle(d=0.35, f=520.0, level=1.0, breath=0.3):
    """Buhar düdüğü: harmonikli ton, başta perde kayması, buhar hışırtısı."""
    t = t_(d)
    fr = f * (0.92 + 0.08 * np.minimum(t / 0.05, 1))
    ph = 2 * np.pi * np.cumsum(fr) / SR
    x = sum(a * np.sin(k * ph) for k, a in ((1, 1.0), (2, 0.55), (3, 0.4), (4, 0.25), (5, 0.15), (6, 0.08)))
    x = lowpass(x, 5000) * 0.6
    x += bandpass(noise(d), 2000, 6000) * breath
    return S(x * env_ar(d, 0.03, 0.1)) * level


def clatter(d=0.35, rate=7.0, level=1.0, seed=0):
    """Kayış tahrikli makine takırtısı: ritmik tıklar + zayıf motor uğultusu."""
    g = np.random.default_rng(seed)
    x = np.zeros(1)
    off = 0.0
    while off < d:
        x = at(x, off, lowpass(tick(0.02, 900, 4000, 0.004), 3500) * g.uniform(0.6, 1.0))
        x = at(x, off + 0.5 / rate, lowpass(tick(0.015, 1500, 5000, 0.003), 3500) * g.uniform(0.3, 0.6))
        off += 1.0 / rate
    t = t_(d)
    hum = lowpass(np.sign(np.sin(2 * np.pi * 60 * t)), 300) * 0.12 * env_ar(d, 0.05, 0.08)
    return mix(x, S(hum)) * level


def steel_press(level=1.0):
    """Ağır çelik pres vuruşu: boğuk tokluk + kısa metalik çınlama."""
    x = thump(58, 0.28, 0.06, 0.8)
    ring = partials([1180, 1880, 3050], [0.35, 0.2, 0.1], [0.09, 0.06, 0.04], 0.25)
    return mix(x, at(np.zeros(1), 0.004, ring)) * level


def steam_hiss(d=0.3, level=1.0):
    t = t_(d)
    return S(highpass(noise(d), 1800) * np.minimum(t / 0.02, 1) * dec(d, 0.09)) * level


def pipe_knock(level=1.0):
    """Metal boru içinde boş, alçak vuruş."""
    x = partials([390, 780, 1230, 1650], [1.0, 0.5, 0.3, 0.15], [0.12, 0.08, 0.05, 0.04], 0.3)
    return mix(x, thump(120, 0.08, 0.02, 0.3) * 0.5) * level


def rivet(level=1.0):
    return mix(tick(0.02, 2500, 8000, 0.004), partials([3200, 5100], [0.4, 0.2], [0.03, 0.02], 0.08)) * level


def chain_rattle(d=0.18, level=1.0, seed=0):
    g = np.random.default_rng(seed)
    x = np.zeros(1)
    for _ in range(7):
        x = at(x, g.uniform(0, d), partials([g.uniform(1800, 4500)], [0.5], [0.012], 0.03) + tick(0.006, 2000, 7000, 0.001) * 0.4)
    return S(x) * level


def ship_horn(d=0.35, f=104.0, level=1.0):
    t = t_(d)
    x = sum(np.sin(2 * np.pi * f * k * t) / k ** 1.1 for k in range(1, 14))
    return S(lowpass(x, 1400) * env_ar(d, 0.08, 0.14)) * level


def wave_lap(d=0.45, level=1.0):
    t = t_(d)
    x = lowpass(noise(d), 900) * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.4
    x += bandpass(noise(d), 2000, 5000) * np.clip((t - d * 0.55) / (d * 0.45), 0, 1) * dec(d, d) * 0.25
    return S(x) * level


def engine_turnover(d=0.5, f0=9.0, f1=27.0, level=1.0):
    """Yıldız motor çalıştırılır: hızlanan patlamalar + pervane uğultusu, çabuk söner."""
    t = t_(d)
    f = f0 + (f1 - f0) * np.clip(t / (d * 0.7), 0, 1)
    ph = np.cumsum(f) / SR % 1.0
    pulses = np.exp(-((ph - 0.5) / 0.07) ** 2)
    x = lowpass(pulses, 700) * 1.6 + bandpass(noise(d), 250, 1400) * (0.25 + 0.25 * np.clip(t / d, 0, 1))
    return S(x * env_ar(d, 0.04, 0.16)) * level


def aa_thumps(level=1.0):
    x = mix(thump(58, 0.22, 0.05, 0.6), at(np.zeros(1), 0.095, thump(62, 0.22, 0.05, 0.6) * 0.9))
    x = lowpass(x, 1500)
    return mix(S(x), at(np.zeros(1), 0.24, partials([4400, 6600], [0.12, 0.06], [0.03, 0.02], 0.08))) * level


def loco(level=1.0):
    """Buharlı lokomotif: iki 'çuf' + ray ekinde tekerlek tak-tak."""
    x = mix(lowpass(noise(0.12), 1500) * dec(0.12, 0.03), at(np.zeros(1), 0.17, lowpass(noise(0.12), 1500) * dec(0.12, 0.03) * 0.85))
    for o in (0.34, 0.375, 0.45, 0.485):
        x = at(x, o, tick(0.012, 800, 3500, 0.003) * 0.7 + thump(200, 0.03, 0.006, 0.2) * 0.4)
    return S(x) * level


def wind(d=2.0, level=1.0, seed=0):
    g = np.random.default_rng(seed)
    t = t_(d)
    slow = 0.5 + 0.5 * np.sin(2 * np.pi * g.uniform(0.3, 0.5) * t + g.uniform(0, 6))
    return S(lowpass(noise(d), 500) * slow * env_ar(d, 0.4, 0.6)) * level


def stamp(f=105.0, level=1.0):
    """Lastik damga: kâğıda tok vuruş + kâğıt şaklaması."""
    x = thump(f, 0.18, 0.045, 0.9)
    slap = bandpass(noise(0.05), 900, 4500) * dec(0.05, 0.01) * 0.6
    x = at(x, 0.004, slap)
    x = at(x, 0.09, bandpass(noise(0.08), 1200, 5000) * dec(0.08, 0.025) * 0.15)
    return S(x) * level


def pencil_tick(level=1.0):
    """Kurşun kalemle deftere çentik: iki kısa çizik."""
    a = highpass(noise(0.05), 3000) * env_ar(0.05, 0.005, 0.02)
    b = highpass(noise(0.08), 2500) * env_ar(0.08, 0.01, 0.03) * 0.8
    return mix(S(a), at(np.zeros(1), 0.06, S(b))) * level


def typewriter_key(level=1.0):
    return mix(tick(0.02, 1500, 7000, 0.003), thump(260, 0.03, 0.006, 0.3) * 0.4) * level


def carriage_return(level=1.0):
    """Daktilo şaryosu: cırcırlı kayma + şaryo zili + tokluk."""
    d = 0.16
    t = t_(d)
    zip_ = bandpass(noise(d), 2000, 6000) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 62 * t))) * env_ar(d, 0.01, 0.03) * 0.5
    x = mix(S(zip_), at(np.zeros(1), 0.02, small_bell(2400, 0.5, 0.14, 0.45, 5)))
    x = at(x, d, thump(190, 0.06, 0.015, 0.4) * 0.7 + tick(0.01, 1000, 4000, 0.002) * 0.4)
    return S(x) * level


def leather_thud(level=1.0):
    return mix(thump(110, 0.12, 0.035, 0.3), lowpass(sweep_noise(0.08, 2500, 900), 3500) * 0.3) * level


def coins(level=1.0):
    c = partials([4200, 6100, 7900], [0.4, 0.3, 0.2], [0.12, 0.08, 0.05], 0.3)
    return mix(c, at(np.zeros(1), 0.07, c * 0.6)) * level


# ------------------------------------------------------------------ arayüz (masa, dosya, kâğıt)
def ui_click():
    """Bakalit şalter: basma + bırakma iki tık, kısa pirinç çınlama, ahşap gövde."""
    for i, (pitch, gap) in enumerate(((3100, 0.026), (2750, 0.031), (3450, 0.022)), 1):
        press = tick(0.012, 2200, 9000, 0.0012) + partials([pitch, pitch * 1.47, pitch * 2.09], [0.35, 0.2, 0.1], [0.01, 0.007, 0.005], 0.04)
        press = at(press, 0.0, thump(170, 0.05, 0.012, 0.25) * 0.5)
        rel = tick(0.01, 3000, 9000, 0.001) * 0.45
        w(f"ui_click_{i}", room(at(press, gap, rel), 0.12, 0.12, 6000, i), 0.55)


def ui_hover():
    """Kâğıt kenarının keçeye sürtünmesi: çok kısık, çok kısa."""
    x = bandpass(noise(0.05), 1800, 7000) * np.hanning(int(0.05 * SR))
    w("ui_hover", S(x), 0.16)


def ui_open():
    """Deri dosya kapağı açılır: yükselen kâğıt hışırtısı + yumuşak deri tokluğu."""
    for i, (f0, f1) in enumerate(((900, 3200), (700, 2600)), 1):
        swish = sweep_noise(0.2, f0, f1) * np.sin(np.pi * np.clip(t_(0.2) / 0.2, 0, 1)) ** 1.5
        thud = thump(120, 0.12, 0.03, 0.25) * 0.5
        x = at(swish * 0.7, 0.17, thud)
        x = at(x, 0.18, tick(0.01, 1500, 6000, 0.002) * 0.3)
        w(f"ui_open_{i}", room(x, 0.2, 0.18, 5000, 10 + i), 0.5)


def ui_close():
    """Dosya kapanır: alçalan hışırtı + deri tokluğu + pirinç mandal tıkı."""
    for i, (f0, f1) in enumerate(((2800, 800), (2400, 700)), 1):
        swish = sweep_noise(0.15, f0, f1) * np.sin(np.pi * np.clip(t_(0.15) / 0.15, 0, 1)) ** 1.5
        latch = tick(0.012, 2000, 8000, 0.0015) + partials([2300, 3500], [0.3, 0.15], [0.008, 0.005], 0.03)
        x = at(swish * 0.6, 0.12, thump(105, 0.1, 0.03, 0.25) * 0.4)
        x = at(x, 0.15, latch * 0.8)
        w(f"ui_close_{i}", room(x, 0.18, 0.15, 5000, 20 + i), 0.5)


def ui_tab():
    """Fihrist kulağı parmaklar arasında çıtlatılır."""
    x = tick(0.02, 2000, 7000, 0.004) + beep(520, 0.03, 0.15) * dec(0.03, 0.01)
    w("ui_tab", room(x, 0.1, 0.1, 6000, 3), 0.45)


def ui_error():
    """Ahşap tokluk + eski masa interkomunun kısa alçak vızıltısı."""
    knock = lambda: thump(210, 0.08, 0.02, 0.5) + tick(0.01, 800, 3000, 0.003) * 0.5
    t = t_(0.16)
    buzz = lowpass(np.sign(np.sin(2 * np.pi * 98 * t)), 900) * np.minimum(t / 0.01, 1) * dec(0.16, 0.06) * 0.35
    x = at(at(knock(), 0.09, knock() * 0.8), 0.04, buzz)
    w("ui_error", room(x, 0.15, 0.15, 4000, 4), 0.5)


def ui_confirm():
    """Lastik damga kâğıda basılır: tok vuruş + kâğıt şaklaması + masa yankısı."""
    for i, f in enumerate((110, 95), 1):
        w(f"ui_confirm_{i}", room(stamp(f), 0.25, 0.25, 3500, 30 + i), 0.6)


def ui_toggle():
    """Ağır pirinç anahtar çevrilir."""
    x = at(tick(0.01, 2500, 9000, 0.001), 0.012, partials([1800, 2700], [0.3, 0.12], [0.02, 0.012], 0.05))
    w("ui_toggle", room(x, 0.1, 0.1, 6000, 5), 0.45)


def ui_speed():
    """Mekanik saat dişlisi bir diş ilerler."""
    x = partials([1400, 3100], [0.5, 0.25], [0.012, 0.006], 0.05) + tick(0.006, 3000, 9000, 0.0008) * 0.6
    w("ui_speed", room(x, 0.12, 0.12, 6000, 6), 0.4)


def ui_pause():
    """Büyük pirinç kol indirilir ve kilitlenir."""
    x = thump(80, 0.25, 0.06, 0.6) + partials([420, 980, 1630], [0.35, 0.2, 0.12], [0.08, 0.05, 0.03], 0.25)
    x = at(tick(0.015, 1500, 6000, 0.003) * 0.5, 0.0, x)
    w("ui_pause", room(x, 0.25, 0.2, 3500, 7), 0.55)


def ui_resume():
    """Kol bırakılır, saat iki kez tıklayarak yeniden işler."""
    x = at(thump(90, 0.15, 0.04, 0.4), 0.0, tick(0.01, 2000, 8000, 0.002) * 0.4)
    for k in range(3):
        x = at(x, 0.12 + k * 0.14, partials([1250, 2800], [0.35, 0.15], [0.012, 0.006], 0.04))
    w("ui_resume", room(x, 0.2, 0.15, 5000, 8), 0.5)


# ------------------------------------------------------------------ harita yapı rozetleri (üstüne gelince)
def _badge(name, signature, delay=0.06, seed=0, peak=0.45, tap=1.0):
    """İğne dokunuşu + yapının uzaktan gelen imzası; küçük ahşap oda."""
    x = at(felt_tap(tap, 1.0 + 0.06 * (seed % 3)), delay, signature)
    w(name, room(x, 0.2, 0.15, 5000, 200 + seed), peak)


def map_civilian_factory():
    """Sivil sanayi: uzak fabrika düdüğü + kayış tahrikli makine takırtısı."""
    sig = mix(factory_whistle(0.22, 480.0, 0.7), at(np.zeros(1), 0.05, clatter(0.32, 7.0, 0.5, 1)))
    _badge("map_civilian_factory", distant(sig, 2000, 0.3, 0.7, 101), seed=1)


def map_military_factory():
    """Silah sanayi: tek boğuk çelik pres vuruşu."""
    _badge("map_military_factory", distant(steel_press(1.0), 1800, 0.25, 0.9, 102), seed=2)


def map_synthetic_refinery():
    """Rafineri: valften kaçan buhar + boruda boş vuruş."""
    sig = mix(steam_hiss(0.26, 0.9), at(np.zeros(1), 0.18, pipe_knock(0.9)))
    _badge("map_synthetic_refinery", distant(sig, 2400, 0.3, 0.8, 103), seed=3)


def map_dockyard():
    """Tersane: çelik gövdeye iki hızlı perçin çekici + zincir şıngırtısı, liman yankısı."""
    sig = mix(rivet(1.7), at(np.zeros(1), 0.09, rivet(1.5)), at(np.zeros(1), 0.13, chain_rattle(0.2, 0.9, 4)))
    _badge("map_dockyard", distant(sig, 2600, 0.45, 1.1, 104, 0.55), seed=4)


def map_naval_base():
    """Liman: uzakta kısa alçak gemi borusu + rıhtım taşına tek dalga."""
    sig = mix(ship_horn(0.3, 104.0, 1.0), at(np.zeros(1), 0.14, wave_lap(0.42, 0.6)))
    _badge("map_naval_base", distant(sig, 1800, 0.35, 0.9, 105, 0.5), seed=5)


def map_air_base():
    """Hava üssü: açık pistte yıldız motorun çalıştırılması, pervane uğultusu, çabuk söner."""
    _badge("map_air_base", distant(engine_turnover(0.48), 2000, 0.25, 1.2, 106), seed=6)


def map_anti_air():
    """Uçaksavar: uzak, boğuk çift vuruş + kovan şıngırtısı."""
    _badge("map_anti_air", distant(aa_thumps(1.3), 1500, 0.25, 1.2, 107), seed=7)


def map_infrastructure():
    """Demiryolu: uzak lokomotif çufu + ray ekinde tak-tak (ileride, rozeti henüz yok)."""
    _badge("map_infrastructure", distant(loco(1.3), 2200, 0.3, 1.0, 108), seed=8)


# ------------------------------------------------------------------ birim sayaçları (seçme ve emir)
def select_unit():
    """Ahşap sayaç keçeden kaldırılır; sahra telefonu hattı tıklar, hatta iki heceli sözsüz mırıltı."""
    for i in range(1, 4):
        x = wood_knock(0.8, 1.0 + 0.05 * i, soft=True)
        x = at(x, 0.09, line_click(0.7))
        x = at(x, 0.14, chatter(0.16 + 0.03 * i, 30 + i) * 0.8)
        w(f"select_unit_{i}", room(x, 0.15, 0.12, 5000, 40 + i), 0.5)


def order_move():
    """Sayaç kâğıt harita üstünde kaydırılır, mantara iğne itilir; sonda kısık telsiz açılışı."""
    for i in range(1, 4):
        x = scrape(0.2 + 0.02 * i, 1100 + 100 * i, 4300, 0.9, 50 + i)
        x = at(x, 0.2 + 0.02 * i, cork_push(1.0, 0.07))
        x = at(x, 0.36 + 0.02 * i, radio(squelch(0.06)) * 0.35)
        w(f"order_move_{i}", room(x, 0.15, 0.12, 5000, 50 + i), 0.55)


def order_attack():
    """Kırmızı başlı iğne mantara kararlılıkla itilir, lastik damga vurur; altında uzak topçu gürlemesi."""
    for i in range(1, 3):
        x = cork_push(1.1, 0.08, firm=True)
        x = at(x, 0.11 + 0.02 * i, stamp(100 - 8 * i, 0.9))
        rumble = distant(thump(46, 0.55, 0.2, 0.3), 700, 0.5, 0.9, 60 + i, 0.6)
        x = at(x, 0.14, rumble)
        w(f"order_attack_{i}", room(x, 0.25, 0.18, 3500, 60 + i), 0.55)


def select_fleet():
    """Küçük metal gemi işareti masaya konur (çınlama); kısık bir telgraf işareti."""
    for i, (pitch, seq) in enumerate(((1.0, "."), (0.9, ".-")), 1):
        clink = partials([2900 * pitch, 4300 * pitch, 6200 * pitch], [0.5, 0.3, 0.15], [0.03, 0.02, 0.012], 0.1)
        x = mix(felt_tap(0.9, pitch), clink)
        x = at(x, 0.16, morse(seq, 900.0, 0.045, 0.35))
        w(f"select_fleet_{i}", room(x, 0.2, 0.15, 6000, 70 + i), 0.5)


def select_air():
    """Küçük metal uçak işareti masaya tıklatılır; uzaktan ince bir pervane uğultusu geçer."""
    for i in range(1, 3):
        d = 0.32
        t = t_(d)
        f = (95 + 30 * i) * (0.85 + 0.15 * np.minimum(t / 0.2, 1))
        ph = 2 * np.pi * np.cumsum(f) / SR
        prop = sum(np.sin(k * ph) * (0.8 ** k) for k in range(1, 9))
        prop = lowpass(prop, 2000) * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.2
        clink = partials([3400, 5200], [0.4, 0.2], [0.025, 0.015], 0.08)
        x = mix(felt_tap(0.9, 1.05), clink * 0.8)
        x = at(x, 0.1, distant(prop * 0.5, 2200, 0.3, 0.8, 80 + i))
        w(f"select_air_{i}", room(x, 0.2, 0.15, 6000, 80 + i), 0.5)


def deploy():
    """Ağır ahşap blok masaya konur; uzakta iki uygun adım, tüfek sürgüsü."""
    x = mix(thump(120, 0.16, 0.04, 0.6), partials([700, 1300, 2100], [0.3, 0.15, 0.08], [0.03, 0.02, 0.012], 0.08))
    x = at(x, 0.26, distant(step(1.0), 1500, 0.4, 1.4, 90, 0.5))
    x = at(x, 0.46, distant(step(0.9), 1500, 0.4, 1.4, 91, 0.5))
    x = at(x, 0.58, partials([2600, 3900], [0.25, 0.12], [0.02, 0.012], 0.05) + tick(0.008, 2000, 7000, 0.0015) * 0.4)
    w("deploy", room(x, 0.3, 0.2, 3500, 46), 0.55)


# ------------------------------------------------------------------ muharebe durumu (harita işaretleri)
def battle_start():
    """Uzakta iki top gümbürtüsü (telefon zili yok: savaşta çok sık çalar)."""
    for i in range(1, 3):
        x = mix(hall(thump(46, 1.2, 0.5, 0.3), 1.2, 0.6, 900, 70 + i),
                at(np.zeros(1), 0.35 + 0.2 * i, hall(thump(40, 1.4, 0.5, 0.25), 1.2, 0.6, 700, 72 + i) * 0.8))
        w(f"battle_start_{i}", lowpass(x, 1200), 0.6)


def capitulation():
    """Ağır lastik damga belgeye çarpar; sessizlik; uzakta bir kilise çanı, altında hafif rüzgâr."""
    x = room(stamp(90, 1.3), 0.3, 0.25, 3500, 66)
    bellx = lowpass(bell(43, 0.7, 1.7, 0.6) * dec(1.7, 0.9), 1800)
    x = at(x, 0.95, hall(bellx, 1.4, 0.5, 1800, 67))
    x = at(x, 0.5, wind(2.0, 0.1, 3))
    w("capitulation", x[: int(2.6 * SR)], 0.6)


# ------------------------------------------------------------------ oyuncunun eylemleri
def build_queued():
    """İnşaat defterine kalemle çentik; uzakta örse iki çekiç."""
    x = pencil_tick(0.8)
    for k, (off, f) in enumerate(((0.25, 2150), (0.42, 2310))):
        hit = partials([f, f * 1.61, f * 2.37], [0.6, 0.35, 0.2], [0.12, 0.08, 0.05], 0.3) + tick(0.01, 2000, 9000, 0.001)
        x = at(x, off, distant(hit * (1.0 - 0.15 * k), 3000, 0.4, 0.8, 40 + k, 0.5))
    w("build_queued", room(x, 0.3, 0.2, 4000, 40), 0.55)


def production_line():
    """Fabrika ofisinin penceresinden: pnömatik pres bir kez vurur, konveyör dönmeye başlar."""
    press = mix(steam_hiss(0.1, 0.5), at(np.zeros(1), 0.06, thump(70, 0.3, 0.08, 0.8)),
                at(np.zeros(1), 0.07, partials([640, 1450], [0.4, 0.2], [0.1, 0.06], 0.3)))
    d = 0.45
    t = t_(d)
    conv = lowpass(noise(d), 600) * (0.7 + 0.3 * np.sin(2 * np.pi * 4.0 * t)) * env_ar(d, 0.12, 0.15)
    rollers = np.zeros(1)
    for k in range(4):
        rollers = at(rollers, 0.05 + k * 0.11, lowpass(tick(0.015, 800, 3000, 0.003), 2500) * 0.5)
    x = at(press, 0.2, mix(S(conv * 0.8), rollers))
    w("production_line", distant(x, 2600, 0.3, 1.0, 41, 0.4), 0.6)


def research_start():
    """Daktilo: altı düzensiz tuş vuruşu ve şaryo zili."""
    x = np.zeros(1)
    off = 0.0
    for k in range(6):
        x = at(x, off, typewriter_key(rng.uniform(0.7, 1.0)))
        off += rng.uniform(0.06, 0.11)
    x = at(x, off + 0.04, small_bell(2400, 0.5, 0.14, 0.4, 6))
    w("research_start", room(x, 0.2, 0.15, 5000, 42), 0.5)


def focus_start():
    """Planlama dosyasında sayfa çevrilir, imza kalemi çizer."""
    paper = sweep_noise(0.18, 1500, 3500) * np.sin(np.pi * t_(0.18) / 0.18) * 0.5
    t = t_(0.34)
    pen = bandpass(noise(0.34), 3000, 7000) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t) ** 2) * env_ar(0.34, 0.03, 0.08) * 0.35
    w("focus_start", room(at(paper, 0.22, S(pen)), 0.25, 0.2, 4500, 43), 0.55)


def trade_deal():
    """Kısa telgraf 'dit-dah-dit'; ahşap tezgâha düşen birkaç madenî para."""
    x = morse(".-.", 780.0, 0.045, 0.5)
    x = at(x, 0.4, coins(1.0))
    w("trade_deal", room(x, 0.25, 0.2, 6000, 44), 0.5)


def diplomacy():
    """Dolmakalem imza atar, sonra mum mühür kâğıda bastırılır."""
    t = t_(0.42)
    pen = bandpass(noise(0.42), 3000, 7000) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t) ** 2) * env_ar(0.42, 0.03, 0.1) * 0.35
    seal = thump(85, 0.25, 0.06, 0.7) + partials([380, 820], [0.2, 0.1], [0.05, 0.03], 0.1)
    w("diplomacy", room(at(S(pen), 0.45, seal), 0.3, 0.25, 3500, 45), 0.55)


# ------------------------------------------------------------------ bildirimler
def alert():
    """İyi haber: teleks kısa bir satır basar, hoş iki tonlu masa zili. Kötü haber: teleks takılır, eski alarm zilinin
    alçak, boğuk tek tonu."""
    good = teleprinter(0.34, False, 1)
    good = at(good, 0.38, small_bell(1500, 0.8, 0.2, 0.5, 11))
    good = at(good, 0.5, small_bell(1900, 0.9, 0.22, 0.5, 12))
    w("notify_good", room(good, 0.3, 0.2, 6000, 61), 0.42)
    bad = teleprinter(0.4, True, 2)
    bad = at(bad, 0.44, lowpass(small_bell(620, 0.7, 0.3, 0.7, 13), 2500) * dec(0.7, 0.35))
    w("notify_bad", room(bad, 0.35, 0.25, 3000, 62), 0.42)


def event():
    """Kurye zarfı masaya bırakır; zarf yırtılarak açılır."""
    x = mix(thump(160, 0.1, 0.025, 0.4), at(np.zeros(1), 0.005, bandpass(noise(0.06), 800, 3000) * dec(0.06, 0.015) * 0.5))
    x = at(x, 0.26, paper_tear(0.28, 1.5, 7))
    w("event", room(x, 0.3, 0.2, 5000, 63), 0.45)


def research_done():
    """Daktilo şaryosu başa döner (cırcır, zil, tokluk); kâğıda memnun bir damga."""
    x = carriage_return(1.0)
    x = at(x, 0.36, stamp(112, 0.9))
    w("research_done", room(x, 0.25, 0.2, 5000, 64), 0.45)


def focus_done():
    """Dosya kararlılıkla kapatılır ve dosya yığınının üstüne konur."""
    x = leather_thud(1.0)
    x = at(x, 0.02, tick(0.012, 2000, 8000, 0.0015) * 0.4)
    x = at(x, 0.3, mix(thump(140, 0.12, 0.03, 0.35) * 1.6, lowpass(sweep_noise(0.1, 1800, 700), 3000) * 0.5))
    w("focus_done", room(x, 0.3, 0.22, 4000, 65), 0.45)


def production_done():
    """Uzak fabrika düdüğü: kısa ve parlak."""
    x = distant(factory_whistle(0.45, 640.0, 1.0, 0.25), 2600, 0.4, 1.0, 66, 0.6)
    w("production_done", x, 0.42)


# ------------------------------------------------------------------ muharebe (3D, yakın zoom) — cepheden, belgesel kaydı gibi
def crack(d=0.09, lo=900, hi=5000, tau=0.017):
    return S(bandpass(noise(d), lo, hi) * dec(d, tau))


def rifle_crack():
    x = mix(crack(0.12, 700, 6000, 0.022), thump(160, 0.1, 0.025, 0.5) * 0.5)
    w("rifle_crack", room(x, 0.35, 0.3, 2500, 80), 0.7)


def mg_burst():
    x = np.zeros(1)
    for i in range(7):
        x = at(x, i * 0.085, mix(crack(0.08, 600, 5000, 0.018) * (0.9 + 0.2 * rng.random()), thump(140, 0.07, 0.022, 0.4) * 0.4))
    w("mg_burst", room(x, 0.4, 0.3, 2500, 81), 0.7)


def artillery_boom():
    x = mix(thump(50, 1.4, 0.38, 0.9), crack(0.05, 300, 3000, 0.012) * 0.6)
    w("artillery_boom", hall(x, 1.0, 0.5, 1200, 82), 0.8)


def explosion():
    x = mix(thump(38, 1.9, 0.5, 1.2), bandpass(noise(1.4), 200, 4000) * dec(1.4, 0.28) * 0.5)
    debris = np.zeros(1)
    for _ in range(10):
        debris = at(debris, 0.25 + rng.random() * 0.9, crack(0.03, 1500, 7000, 0.008) * 0.25)
    w("explosion", hall(mix(x, debris), 1.2, 0.5, 1500, 83), 0.85)


def tank_engine():
    d = 2.0
    t = t_(d)
    pulses = np.sign(np.sin(2 * np.pi * 27 * t)) * 0.5 + np.sin(2 * np.pi * 54 * t) * 0.6 + np.sin(2 * np.pi * 81 * t) * 0.3
    x = lowpass(pulses, 600) + bandpass(noise(d), 300, 2200) * 0.25
    x *= 1 + 0.08 * np.sin(2 * np.pi * 1.0 * t)
    w("tank_engine", x, 0.5)


def plane_flyby():
    d = 2.6
    t = t_(d)
    f0 = 118 - 40 * (t / d)
    x = np.zeros_like(t)
    for i, h in enumerate((1, 0.7, 0.5, 0.35, 0.2, 0.12), 1):
        x += h * np.sin(2 * np.pi * np.cumsum(f0 * i) / SR)
    x = lowpass(x, 2200)
    wind_ = bandpass(noise(d), 400, 3000)
    amp = np.exp(-((t - d * 0.45) ** 2) / (2 * 0.45 ** 2))
    w("plane_flyby", (x * 0.7 + wind_ * 0.3) * amp, 0.6)


def naval_gun():
    x = mix(crack(0.06, 200, 2500, 0.016) * 0.7, thump(44, 1.8, 0.5, 1.0))
    w("naval_gun", hall(x, 1.4, 0.55, 900, 84), 0.85)


ALL = (ui_click, ui_hover, ui_open, ui_close, ui_tab, ui_error, ui_confirm, ui_toggle, ui_speed, ui_pause, ui_resume,
       map_civilian_factory, map_military_factory, map_synthetic_refinery, map_dockyard, map_naval_base, map_air_base,
       map_anti_air, map_infrastructure,
       select_unit, order_move, order_attack, select_fleet, select_air, deploy,
       battle_start, capitulation,
       build_queued, production_line, research_start, focus_start, trade_deal, diplomacy,
       alert, event, research_done, focus_done, production_done,
       rifle_crack, mg_burst, artillery_boom, explosion, tank_engine, plane_flyby, naval_gun)

# artık kullanılmayan dosyalar (müzik ve olay müzikleri tools/make_music.py'ye geçti; tek dosyalar çeşitlemeye bölündü)
OBSOLETE = ("alert_1", "alert_2", "ambient", "victory", "war_declare", "ui_click", "ui_open", "ui_close", "select_unit", "order_move",
            "order_attack", "select_fleet", "select_air", "alert", "battle_start", "click", "notify", "war")

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OBSOLETE:
        for ext in (".wav", ".wav.import"):
            p = OUT / f"{old}{ext}"
            if p.exists():
                p.unlink()
    want = set(sys.argv[1:])
    for fn in ALL:
        if not want or fn.__name__ in want:
            fn()
    print(len(list(OUT.glob("*.wav"))), "efekt:", sorted(p.stem for p in OUT.glob("*.wav")))
