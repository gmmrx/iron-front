"""Deterministic, sample-free physical/foley synthesis for Iron Front SFX.

No music, sampled recordings, neural service or speech model is used. Every
primitive receives the same per-asset Generator; rendering a subset reproduces
the exact bytes of a full build. Signals are float64 mono at 48 kHz internally.
"""
from __future__ import annotations

import math
import wave
from pathlib import Path

import numpy as np

SR = 48_000


def timeline(seconds: float) -> np.ndarray:
    return np.arange(max(1, round(seconds * SR)), dtype=np.float64) / SR


def envelope(n: int, attack: float = .002, release: float = .025) -> np.ndarray:
    out = np.ones(n)
    a, r = min(n, round(attack * SR)), min(n, round(release * SR))
    if a: out[:a] *= np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    if r: out[-r:] *= np.sin(np.linspace(np.pi / 2, 0, r)) ** 2
    return out


def filtered(x: np.ndarray, low: float = 30, high: float = 14_000) -> np.ndarray:
    # Padded FFT prevents circular leakage from the tail back into the attack.
    size = 1 << max(1, (len(x) * 2 - 1).bit_length())
    f = np.fft.rfftfreq(size, 1 / SR)
    response = 1 / (1 + (low / np.maximum(f, 1)) ** 6)
    response /= 1 + (f / min(high, SR * .47)) ** 8
    return np.fft.irfft(np.fft.rfft(x, size) * response, size)[:len(x)]


def mix(*events: tuple[float, np.ndarray, float]) -> np.ndarray:
    length = max((round(offset * SR) + len(x) for offset, x, _ in events), default=1)
    out = np.zeros(length)
    for offset, x, level in events:
        start = round(offset * SR)
        out[start:start + len(x)] += x * level
    return out


def modes(g: np.random.Generator, duration: float, frequencies: list[float], decay: float) -> np.ndarray:
    t = timeline(duration)
    out = np.zeros(len(t))
    for i, frequency in enumerate(frequencies):
        # A struck surface starts coherently; slight detuning avoids a musical chord.
        f = frequency * g.uniform(.981, 1.019)
        out += np.sin(2 * np.pi * f * t) * np.exp(-t / (decay / (1 + i * .48))) / (1 + i * .9)
    return out * envelope(len(out), .0004, .012)


def impact(g: np.random.Generator, material: str = "wood", weight: float = 1) -> np.ndarray:
    settings = {
        "wood": ([177, 843, 1639], .042, 4100),
        "felt": ([146, 473, 913], .015, 1600),
        "bakelite": ([292, 1819, 3127], .024, 7500),
        "steel": ([361, 1423, 2297, 3931], .095, 9800),
        "brass": ([527, 1921, 3481, 5879], .07, 10_000),
        "leather": ([101, 421, 757], .029, 2800),
        "stamp": ([84, 297, 831], .032, 4100),
    }
    frequencies, decay, cutoff = settings[material]
    decay *= math.sqrt(weight)
    t = timeline(max(.075, decay * 5))
    transient = filtered(g.normal(size=len(t)), 130, cutoff) * np.exp(-t / (.0025 * weight))
    body = modes(g, len(t) / SR, [f / math.sqrt(weight) for f in frequencies], decay)
    out = transient * .7 + body * .43
    return out * envelope(len(out), .00025, .012)


def friction(g: np.random.Generator, material: str = "paper", duration: float = .22) -> np.ndarray:
    t = timeline(duration)
    low, high = {"paper": (900, 10_500), "cloth": (250, 5200), "pencil": (2200, 11_000),
                 "steel": (900, 6900), "leather": (180, 2900)}[material]
    x = filtered(g.normal(size=len(t)), low, high)
    control = g.uniform(.1, 1, max(5, round(duration * 70)))
    roughness = np.interp(np.arange(len(t)), np.linspace(0, len(t) - 1, len(control)), control)
    x *= roughness * np.sin(np.pi * t / duration) ** .8
    # Discrete folds/fibres instead of a uniform white-noise swoosh.
    for _ in range(max(2, round(duration * 35))):
        start = int(g.integers(0, max(1, len(t) - 80)))
        n = min(int(g.integers(25, 90)), len(t) - start)
        x[start:start + n] += g.normal(size=n) * np.hanning(n) * g.uniform(.05, .35)
    return x * envelope(len(x), .007, .035) * .65


def latch(g: np.random.Generator, heavy: bool = False) -> np.ndarray:
    w = g.uniform(.85, 1.2) * (1.65 if heavy else 1)
    return mix((0, impact(g, "bakelite", w), .8),
               (g.uniform(.026, .043), impact(g, "brass", .45), .32),
               (.013, friction(g, "steel", .055), .12))


def paper(g: np.random.Generator, duration: float = .28) -> np.ndarray:
    return mix((0, friction(g, "paper", duration), .55),
               (duration * .7, impact(g, "felt", .6), .18),
               (duration * .18, friction(g, "paper", duration * .6), .25))


def stamp(g: np.random.Generator, weight: float = 1) -> np.ndarray:
    return mix((0, impact(g, "stamp", weight), 1),
               (.014, friction(g, "paper", .065), .35),
               (.098, impact(g, "wood", .6), .16))


def keys(g: np.random.Generator, count: int = 4, gap: float = .066) -> np.ndarray:
    events = []
    offset = 0.0
    for _ in range(count):
        events.append((offset, impact(g, "bakelite", g.uniform(.55, .9)), g.uniform(.45, .7)))
        events.append((offset + .022, impact(g, "steel", .3), .1))
        offset += gap * g.uniform(.78, 1.23)
    return mix(*events)


def radio(g: np.random.Generator, duration: float = .25) -> np.ndarray:
    t = timeline(duration)
    # Receiver squelch, tube hiss and a connection relay; no fake syllables/voices.
    n = filtered(g.normal(size=len(t)), 560, 3300)
    env = (np.exp(-t / .029) + .32 * np.exp(-((t - duration * .77) / .025) ** 2))
    hum = np.sin(2 * np.pi * 100 * t) * .018
    return (n * env * .55 + hum) * envelope(len(t), .002, .028)


def bell(g: np.random.Generator, low: bool = False, duration: float = .55) -> np.ndarray:
    f = g.uniform(540, 610) if low else g.uniform(1450, 1620)
    return modes(g, duration, [f, f * 2.756, f * 4.139, f * 5.404], .17 if low else .12)


def ratchet(g: np.random.Generator, duration: float = .19) -> np.ndarray:
    events = []
    for offset in np.arange(0, duration, .016):
        events.append((float(offset), impact(g, "steel", .24), g.uniform(.1, .22)))
    return mix(*events, (duration, impact(g, "wood", .65), .4))


def engine(g: np.random.Generator, duration: float = .6, aircraft: bool = False) -> np.ndarray:
    t = timeline(duration)
    rate = (24 if aircraft else 18) + (15 if aircraft else 7) * t / duration
    rate *= 1 + .013 * np.sin(2 * np.pi * 3.7 * t)
    phase = np.cumsum(rate) / SR
    firing = np.exp(-((phase % 1 - .15) / .065) ** 2)
    body = filtered(firing - np.mean(firing), 45, 1300)
    combustion = filtered(g.normal(size=len(t)), 130, 2600) * (.1 + firing * .7)
    bearing = np.sin(2 * np.pi * np.cumsum(rate * (4.2 if aircraft else 2.7)) / SR) * .035
    return (body * 1.2 + combustion * .33 + bearing) * envelope(len(t), .035, .16)


def horn(g: np.random.Generator, duration: float = .48) -> np.ndarray:
    t = timeline(duration)
    f = g.uniform(94, 111) * (1 + .012 * np.sin(t * 19))
    phase = 2 * np.pi * np.cumsum(f) / SR
    x = sum(np.sin(phase * k) / k ** 1.5 for k in range(1, 12))
    x += filtered(g.normal(size=len(t)), 200, 1800) * .09
    return filtered(x, 55, 1700) * envelope(len(t), .07, .17) * .45


def shot(g: np.random.Generator, kind: str = "rifle") -> np.ndarray:
    heavy = kind != "rifle"
    duration = {"rifle": .46, "artillery": 1.4, "explosion": 1.7, "naval": 1.85}[kind]
    t = timeline(duration)
    pressure = filtered(g.normal(size=len(t)), 32, 2100 if heavy else 8500)
    pressure *= np.exp(-t / (.22 if heavy else .042))
    bass_phase = 2 * np.pi * np.cumsum((43 if heavy else 118) * (1 + 2 * np.exp(-t / .014))) / SR
    body = np.sin(bass_phase) * np.exp(-t / (.22 if heavy else .017))
    crack = filtered(g.normal(size=len(t)), 500, 11_500) * np.exp(-t / (.007 if heavy else .0018))
    direct = (pressure * .75 + body * .45 + crack * .95) * envelope(len(t), .00015, .05)
    events = [(0, direct, 1)]
    for delay, level in [(.065, .14), (.139, .1), (.251, .05)]:
        events.append((delay, filtered(direct, 160, 1900), level))
    if heavy:
        for _ in range(8):
            events.append((float(g.uniform(.19, .83)), impact(g, "wood", .22), float(g.uniform(.015, .07))))
    return mix(*events)


def signature(g: np.random.Generator, family: str, duration: float = .35) -> np.ndarray:
    """Recognizable workshop/branch vocabulary, not different pitches of one click."""
    if family == "infantry":
        return mix((0, friction(g, "steel", .105), .4), (.064, latch(g), .55), (.16, impact(g, "wood", .6), .3))
    if family == "artillery":
        return mix((0, ratchet(g, .14), .5), (.17, impact(g, "steel", 2.1), .8))
    if family in ("armor", "motorized"):
        return mix((0, latch(g, True), .4), (.08, engine(g, duration, False), .8))
    if family == "air":
        return mix((0, latch(g), .34), (.045, engine(g, duration, True), .8))
    if family == "naval":
        return mix((0, ratchet(g, .1), .22), (.07, horn(g, duration), .85))
    if family == "industry":
        return mix((0, impact(g, "steel", 1.8), .65), (.11, ratchet(g, .15), .5))
    if family == "electronics":
        return mix((0, keys(g, 2, .041), .5), (.04, radio(g, duration), .9), (.19, latch(g), .15))
    if family == "doctrine":
        return mix((0, paper(g, .2), .5), (.12, impact(g, "wood", .7), .6), (.21, impact(g, "felt", .8), .55))
    return mix((0, paper(g, .2), .7), (.14, stamp(g), .8))


def small_room(g: np.random.Generator, x: np.ndarray, wet: float = .08, size: float = 1) -> np.ndarray:
    # Sparse early reflections, no synthetic wash masking the next UI action.
    reflections = [(0, x, 1)]
    dark = filtered(x, 140, 5400)
    for delay, level in ((.011, .6), (.024, .39), (.043, .25), (.069, .11)):
        reflections.append((delay * size * g.uniform(.94, 1.06), dark, wet * level))
    return mix(*reflections)


def master(x: np.ndarray, rms_db: float, peak_db: float, g: np.random.Generator) -> np.ndarray:
    """DC rejection, active-RMS matching, peak headroom and boundary de-clicking."""
    x = filtered(np.asarray(x, dtype=np.float64), 32, 16_000)
    if not np.all(np.isfinite(x)) or np.max(np.abs(x)) < 1e-10:
        raise ValueError("Nonfinite or silent cue")
    x -= np.mean(x)
    # Remove sub-audible tails, retain natural decay; never insert leading silence.
    active = np.flatnonzero(np.abs(x) > np.max(np.abs(x)) * .002)
    end = min(len(x), int(active[-1]) + round(.018 * SR))
    x = x[:end] * envelope(end, .0004, .012)
    window = max(1, round(.02 * SR))
    padded = np.pad(x, (0, (-len(x)) % window))
    energies = np.mean(padded.reshape(-1, window) ** 2, axis=1)
    rms = math.sqrt(float(np.mean(energies[energies > np.max(energies) * .025])))
    gain = min(10 ** (rms_db / 20) / max(rms, 1e-9), 10 ** (peak_db / 20) / np.max(np.abs(x)))
    x *= gain
    # TPDF dither is below audible level; force file boundaries to digital zero.
    x += (g.random(len(x)) - g.random(len(x))) / 65536
    x[0] = x[-1] = 0
    return x


def write_wav(path: Path, x: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.rint(np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(SR)
        stream.writeframes(pcm.tobytes())
