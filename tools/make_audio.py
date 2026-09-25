#!/usr/bin/env python3
"""Arayüz sesleri ve ortam müziği (basit sentez) -> assets/audio/*.wav"""
import wave
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
SR = 44100


def write(name, x):
    x = np.clip(x / (np.abs(x).max() + 1e-9) * 0.8, -1, 1)
    data = (x * 32767).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def env(n, a=0.005, r=0.1):
    t = np.arange(n) / SR
    return np.minimum(t / a, 1.0) * np.exp(-t / r)


def tone(f, d, wave_="sine", harm=(1.0,)):
    t = np.arange(int(SR * d)) / SR
    x = np.zeros_like(t)
    for i, h in enumerate(harm, 1):
        x += h * np.sin(2 * np.pi * f * i * t)
    return x


def click():
    n = int(SR * 0.06)
    x = tone(1800, 0.06) * env(n, 0.001, 0.012) + np.random.default_rng(1).standard_normal(n) * env(n, 0.0005, 0.004) * 0.3
    write("click", x)


def notify():
    a = tone(880, 0.35, harm=(1, 0.3, 0.1)) * env(int(SR * 0.35), 0.005, 0.12)
    b = tone(1320, 0.35, harm=(1, 0.3)) * env(int(SR * 0.35), 0.005, 0.15)
    x = np.concatenate([a, np.zeros(int(SR * 0.02))])
    x[int(SR * 0.08):int(SR * 0.08) + len(b)] += b[: len(x) - int(SR * 0.08)]
    write("notify", x)


def war():
    # alçak davul + boru akoru
    d = 2.2
    n = int(SR * d)
    rng = np.random.default_rng(2)
    t = np.arange(n) / SR
    drum = np.sin(2 * np.pi * 55 * t * np.exp(-t * 3)) * np.exp(-t * 4)
    drum += rng.standard_normal(n) * np.exp(-t * 20) * 0.4
    brass = np.zeros(n)
    for f in (110, 138.6, 164.8, 220):
        brass += np.sin(2 * np.pi * f * t) + 0.5 * np.sin(4 * np.pi * f * t) + 0.25 * np.sin(6 * np.pi * f * t)
    brass *= np.minimum(t / 0.25, 1) * np.exp(-np.maximum(t - 0.8, 0) * 2.5) * 0.25
    write("war", drum + brass)


def ambient():
    """75 sn'lik yavaş, karanlık akor döngüsü (döngüye uygun)."""
    d = 75.0
    n = int(SR * d)
    t = np.arange(n) / SR
    chords = [(55, 65.4, 82.4, 110), (49, 61.7, 73.4, 98), (43.7, 55, 65.4, 87.3), (41.2, 49, 61.7, 82.4)]
    seg = d / len(chords)
    x = np.zeros(n)
    for i, ch in enumerate(chords):
        s = int(i * seg * SR)
        e = int((i + 1) * seg * SR)
        tt = t[s:e] - t[s]
        fade = np.minimum(tt / 4.0, 1.0) * np.minimum((seg - tt) / 4.0, 1.0)
        for k, f in enumerate(ch):
            det = 1 + 0.002 * (k - 1.5)
            v = np.sin(2 * np.pi * f * det * tt) + 0.35 * np.sin(4 * np.pi * f * det * tt) + 0.12 * np.sin(6 * np.pi * f * tt)
            x[s:e] += v * fade * (0.9 - k * 0.12) * (1 + 0.15 * np.sin(2 * np.pi * 0.1 * tt + k))
    # yavaş uzak tambur
    rng = np.random.default_rng(3)
    for beat in np.arange(0, d, 4.8):
        s = int(beat * SR)
        m = min(int(SR * 1.2), n - s)
        tt = np.arange(m) / SR
        x[s:s + m] += np.sin(2 * np.pi * 48 * tt) * np.exp(-tt * 5) * 0.6
    # hafif yankı
    for delay, g in ((0.31, 0.3), (0.53, 0.2), (0.89, 0.12)):
        k = int(delay * SR)
        x[k:] += x[:-k] * g
    write("ambient", x)


OUT.mkdir(parents=True, exist_ok=True)
click(); notify(); war(); ambient()
print(sorted(p.name for p in OUT.glob("*.wav")))
