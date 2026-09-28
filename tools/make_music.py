#!/usr/bin/env python3
"""Iron Front müzikleri (prosedürel orkestra) -> assets/audio/music/*.ogg (+ web yükleme ekranı için tools/web/loading_theme.mp3)

Parçalar oyun durumuna göre çalar (game/autoload/audio.gd):
  main_theme     menü ve yükleme ekranı (Sol minör, ağır ve vakur; mod bağımsız: 2. Dünya Savaşı'na özgü marş değil)
  march          dünyada savaş (Re minör ağır marş; eski ana tema)
  peace_1/2      barış (Fa majör pastoral / Si bemol majör hafif)
  tension        gerginlik (Do minör, saat tıkırtısı, alçak yaylı ostinato)
  war_world      dünyada savaş var, oyuncu savaşta değil (Sol minör askerî marş)
  war_front      oyuncu savaşta: sürükleyici (Re minör, hızlı ostinato, bakır vuruşları)
  war_hold       oyuncu savaşta: ağır, kahramanca (Mi minör bakır korali)
  stinger_*      kısa olay müzikleri: oyuncunun savaşı, dünyada savaş, zafer, yenilgi, barış

Çalıştır: python3 tools/make_music.py [parça adları...]
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audio_synth import (SR, Mix, bass_drum, bell, brass, chord_bass, chord_pcs, choir, cymbal, hz, master, mel, piano,  # noqa: E402
                         pizz, rng, siren, snare, snare_roll, strings, timpani, timpani_roll, voicing, woodblock,
                         woodwind, write_mp3, write_ogg)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio" / "music"

# enstrüman: (pan, yankı gönderimi, kazanç)
SEAT = {
    "violins": (-0.4, 0.32, 0.55), "violins2": (-0.15, 0.32, 0.45), "violas": (0.1, 0.3, 0.45), "cellos": (0.3, 0.28, 0.55),
    "basses": (0.4, 0.25, 0.5), "horns": (-0.2, 0.38, 0.5), "trumpets": (0.2, 0.3, 0.45), "trombones": (0.3, 0.32, 0.45),
    "tuba": (0.35, 0.28, 0.45), "clarinet": (-0.1, 0.32, 0.45), "oboe": (0.05, 0.32, 0.42), "flute": (-0.25, 0.35, 0.4),
    "choir": (0.0, 0.5, 0.4), "piano": (0.0, 0.28, 0.5), "pizz": (-0.2, 0.25, 0.5), "celesta": (0.25, 0.4, 0.35),
    "harp": (-0.3, 0.35, 0.4), "timpani": (-0.25, 0.35, 0.7), "snare": (0.1, 0.2, 0.24), "bassdrum": (0.0, 0.3, 0.55),
    "cymbal": (0.2, 0.35, 0.25), "clock": (0.35, 0.15, 0.3), "bells": (0.3, 0.45, 0.35),
}


def note(inst: str, m: int, dur: float, vel: float, prev: int | None = None, short: bool = False) -> np.ndarray:
    atk = 0.012 if short else min(0.26, max(0.04, dur * 0.3))
    rel = 0.12 if short else 0.55
    if inst in ("violins", "violins2"):
        return strings(m, dur, vel, attack=atk, release=rel, voices=3, kind="string", bright=1.0, legato_from=prev)
    if inst == "violas":
        return strings(m, dur, vel, attack=atk, release=rel, voices=3, kind="string", bright=0.8, legato_from=prev)
    if inst == "cellos":
        return strings(m, dur, vel, attack=atk, release=rel, voices=3, kind="cello", bright=1.0, legato_from=prev)
    if inst == "basses":
        return strings(m, dur, vel, attack=atk, release=rel, voices=2, kind="cello", bright=0.6)
    if inst == "horns":
        return brass(m, dur, vel, kind="horn", attack=0.08 if not short else 0.03, release=0.4, voices=2)
    if inst == "trumpets":
        return brass(m, dur, vel, kind="trumpet", attack=0.035, release=0.3, voices=2)
    if inst == "trombones":
        return brass(m, dur, vel, kind="brass", attack=0.06, release=0.35, voices=2)
    if inst == "tuba":
        return brass(m, dur, vel, kind="horn", attack=0.07, release=0.35, voices=1, vib=0.0)
    if inst in ("clarinet", "oboe", "flute"):
        return woodwind(m, dur, vel, kind=inst, attack=0.05 if inst != "flute" else 0.07)
    if inst == "choir":
        return choir(m, dur, vel)
    if inst == "piano":
        return piano(m, dur, vel)
    if inst == "pizz":
        return pizz(m, vel)
    if inst == "celesta":
        return bell(m, vel * 0.6, 3.0)
    if inst == "harp":
        return pizz(m, vel, 1.6)
    raise ValueError(inst)


class Song:
    def __init__(self, bpm: float, bars: int, beats: int = 4, tail: float = 6.0):
        self.spb = 60.0 / bpm
        self.beats = beats
        self.bars = bars
        self.mix = Mix(bars * beats * self.spb + tail)

    def t(self, bar: float, beat: float = 0.0) -> float:
        return (bar * self.beats + beat) * self.spb

    def put(self, inst: str, when: float, x: np.ndarray, gain: float = 1.0, pan: float | None = None):
        p, rev, g = SEAT[inst]
        self.mix.add(when + rng.uniform(-0.005, 0.005), x, p if pan is None else pan, g * gain, rev)

    # -------------------------------------------------------------- kalıplar
    def melody(self, bar: float, text: str, inst: str, vel=0.75, octave=0, gain=1.0, legato=True, swell=False):
        beat = 0.0
        prev = None
        for m, d in mel(text):
            if m is not None:
                m += 12 * octave
                v = vel * rng.uniform(0.93, 1.05) * (1.0 + (0.15 if d >= 2 and swell else 0))
                self.put(inst, self.t(bar, beat), note(inst, m, d * self.spb * 0.98, v, prev if legato else None), gain)
                prev = m
            else:
                prev = None
            beat += d

    def pad(self, bar: float, chords: list[str], inst="violins2", low=55, high=76, n=4, per=4.0, vel=0.45, gain=1.0):
        prev = None
        for i, c in enumerate(chords):
            if c in ("-", ""):
                continue
            v = voicing(c, low, high, prev, n)
            prev = v
            for m in v:
                self.put(inst, self.t(bar, i * per), note(inst, m, per * self.spb * 1.02, vel * rng.uniform(0.92, 1.03)), gain / n ** 0.5)

    def bass(self, bar: float, chords: list[str], inst="basses", octave=2, per=4.0, rhythm=((0, 4),), vel=0.6, gain=1.0,
             fifth=False):
        for i, c in enumerate(chords):
            if c in ("-", ""):
                continue
            root = chord_bass(c)
            m = 12 * (octave + 1) + root
            for k, (b, d) in enumerate(rhythm):
                mm = m + (7 if fifth and k % 2 == 1 else 0)
                self.put(inst, self.t(bar, i * per + b), note(inst, mm, d * self.spb * 0.95, vel, short=d < 1), gain)

    def ostinato(self, bar: float, chords: list[str], figure: list[int], inst="cellos", step=0.5, per=4.0, low=45,
                 vel=0.5, gain=1.0, accent=None):
        """figure: akor tonu indeksleri (0 = kök, 1 = üçlü, 2 = beşli, 3 = oktav); -1 sus."""
        for i, c in enumerate(chords):
            if c in ("-", ""):
                continue
            root, iv = chord_pcs(c)
            base = low + (root - low) % 12
            tones = [base + x for x in iv[:3]] + [base + 12]
            k = 0
            b = 0.0
            while b < per - 1e-6:
                idx = figure[k % len(figure)]
                if idx >= 0:
                    v = vel * (1.25 if accent and (k % len(accent)) < len(accent) and accent[k % len(accent)] == "x" else 1.0)
                    self.put(inst, self.t(bar, i * per + b), note(inst, tones[idx % len(tones)], step * self.spb * 0.9, v, short=True), gain)
                k += 1
                b += step

    def arp(self, bar: float, chords: list[str], inst="piano", per=4.0, step=0.5, low=48, vel=0.4, gain=1.0,
            pattern=(0, 1, 2, 3, 2, 1)):
        for i, c in enumerate(chords):
            if c in ("-", ""):
                continue
            root, iv = chord_pcs(c)
            base = low + (root - low) % 12
            tones = [base + x for x in iv[:3]] + [base + 12, base + 12 + iv[1], base + 12 + iv[2]]
            b = 0.0
            k = 0
            while b < per - 1e-6:
                m = tones[pattern[k % len(pattern)] % len(tones)]
                self.put(inst, self.t(bar, i * per + b), note(inst, m, step * self.spb * 2.2, vel * rng.uniform(0.85, 1.05)), gain)
                b += step
                k += 1

    def drums(self, bar: float, bars: int, pattern: str, inst="snare", vel=0.5, gain=1.0, steps_per_beat=4):
        """pattern: tek ölçü, '.' sus, 'x' vuruş, 'X' vurgulu, 'r' kısa dörtlü (drag); ölçü boyunca tekrarlanır."""
        step = 1.0 / steps_per_beat
        for b in range(bars):
            for k, ch in enumerate(pattern):
                if ch == ".":
                    continue
                w = self.t(bar + b, k * step)
                if inst == "snare":
                    if ch == "r":
                        for j in range(3):
                            self.put("snare", w - (3 - j) * 0.035, snare(vel * 0.45, 0.15), gain)
                        self.put("snare", w, snare(vel * 1.1, 0.3), gain)
                    else:
                        self.put("snare", w, snare(vel * (1.3 if ch == "X" else 1.0) * rng.uniform(0.9, 1.05), 0.3), gain)
                elif inst == "bassdrum":
                    self.put("bassdrum", w, bass_drum(vel * (1.2 if ch == "X" else 1.0)), gain)
                elif inst == "clock":
                    self.put("clock", w, woodblock(vel * (1.2 if ch == "X" else 0.8), 1100 if ch == "X" else 850), gain)

    def timp(self, bar: float, beat: float, m: int, vel=0.8, gain=1.0):
        self.put("timpani", self.t(bar, beat), timpani(m, vel), gain)

    def timp_roll(self, bar: float, beat: float, m: int, beats: float, v0=0.15, v1=0.9, gain=1.0):
        self.put("timpani", self.t(bar, beat), timpani_roll(m, beats * self.spb, v0, v1), gain)

    def snare_roll(self, bar: float, beat: float, beats: float, v0=0.15, v1=0.8, gain=1.0):
        self.put("snare", self.t(bar, beat), snare_roll(beats * self.spb, v0, v1), gain)

    def crash(self, bar: float, beat: float = 0.0, vel=0.6, gain=1.0):
        self.put("cymbal", self.t(bar, beat), cymbal(vel), gain)
        self.put("bassdrum", self.t(bar, beat), bass_drum(vel), gain * 0.8)

    def render(self, rt60=2.4) -> np.ndarray:
        return master(self.mix.render(rt60))


def bars_of(chords_per_bar: str) -> list[str]:
    return chords_per_bar.split()


# ====================================================================== parçalar
def main_theme() -> np.ndarray:
    """Ana tema (menü ve yükleme ekranı; mod bağımsız): Sol minör, 60 BPM, ~3 dk. Gece yarısı harekât masası: alçak
    yaylı pedal, uzak trampet, korno çağrısı → ağır tema (korno + çello) → yaylılarda oktav yukarı, alçak bakır karşı ses →
    Si bemol majör asil bölüm (trompet + yaylı) → tutti doruk → çağrının yankısı ve tek çan ile kapanış. Başı ve sonu aynı
    pedalda: döngüye uygun (web yükleme ekranı)."""
    s = Song(60, 45)
    A = bars_of("Gm Eb Cm D Bb Cm D Gm")
    melA = ("G4:1.5 A4:.5 Bb4:1 D5:1 C5:2 Bb4:1 A4:1 G4:1.5 F4:.5 Eb4:1 G4:1 D4:4 "
            "Bb4:1.5 C5:.5 D5:1 F5:1 Eb5:2 D5:1 C5:1 Bb4:1 A4:1 G4:1 F#4:1 G4:4")
    call = "D4:1 G4:2 Bb4:1 A4:3 r:1 D4:1 G4:2 Bb4:1 A4:4"
    # --- giriş (0–5): pedal, uzak trampet, korno çağrısı, koro
    s.bass(0, ["Gm"] * 6, "basses", octave=1, vel=0.42)
    s.pad(0, ["Gm", "Gm", "Gm", "Gm", "Gm", "Gm"], "cellos", 43, 58, 3, vel=0.26)
    s.timp_roll(1, 0, 43, 6, 0.03, 0.35)
    s.drums(2, 4, "x...............", "snare", vel=0.12)
    s.melody(2, call, "horns", vel=0.5)
    s.pad(4, ["Gm", "D"], "choir", 55, 67, 3, vel=0.2)
    # --- A (6–13): tema kornoda, çello bir oktav altta
    s.pad(6, A, "violins2", 55, 72, 4, vel=0.32)
    s.bass(6, A, "basses", octave=1, vel=0.45)
    s.bass(6, A, "cellos", octave=2, vel=0.35, rhythm=((0, 2), (2, 2)))
    s.melody(6, melA, "horns", vel=0.62)
    s.melody(6, melA, "cellos", vel=0.3, octave=-1)
    s.drums(6, 8, "x.......x.......", "snare", vel=0.14)
    for b in (6, 10):
        s.timp(b, 0, 43, 0.4)
    # --- A' (14–21): kemanlarda oktav yukarı, trombon karşı sesi, koro
    s.pad(14, A, "violas", 52, 67, 4, vel=0.38)
    s.pad(14, A, "choir", 55, 70, 3, vel=0.22)
    s.bass(14, A, "basses", octave=1, vel=0.5, rhythm=((0, 2), (2, 2)), fifth=True)
    s.bass(14, A, "cellos", octave=2, vel=0.4, rhythm=((0, 1), (1, 1), (2, 1), (3, 1)))
    s.melody(14, melA, "violins", vel=0.58, octave=1)
    s.melody(14, "r:4 G3:4 Eb4:4 D4:4 F4:4 Eb4:2 D4:2 D4:4 G3:4", "trombones", vel=0.4)
    s.drums(14, 8, "x.......x...x...", "snare", vel=0.2)
    for b in range(14, 22, 2):
        s.timp(b, 0, 43 if b % 4 == 2 else 38, 0.45)
    s.timp_roll(21, 2, 41, 2, 0.1, 0.7)
    # --- B (22–29): Si bemol majör, asil ama ölçülü (trompet + keman)
    B = bars_of("Bb Bb Eb F F Gm Eb D")
    melB = ("F4:1 Bb4:1 D5:1.5 C5:.5 Bb4:2 F4:2 G4:1 Bb4:1 Eb5:1.5 D5:.5 C5:3 Bb4:1 "
            "A4:1 C5:1 F5:1.5 Eb5:.5 D5:2 Bb4:1 G4:1 F5:1 Eb5:1 D5:1 C5:1 D5:4")
    s.pad(22, B, "violins2", 57, 76, 4, vel=0.4)
    s.pad(22, B, "horns", 50, 65, 3, vel=0.3)
    s.bass(22, B, "basses", octave=1, vel=0.5, rhythm=((0, 2), (2, 2)), fifth=True)
    s.bass(22, B, "tuba", octave=2, vel=0.35)
    s.melody(22, melB, "trumpets", vel=0.5)
    s.melody(22, melB, "violins", vel=0.45)
    s.drums(22, 8, "x...x...x...x...", "snare", vel=0.18)
    s.drums(22, 8, "x.......x.......", "bassdrum", vel=0.25)
    for b in range(22, 30):
        s.timp(b, 0, 46 if b % 2 == 0 else 41, 0.4)
    s.snare_roll(29, 0, 4, 0.1, 0.8)
    s.timp_roll(29, 0, 38, 4, 0.1, 0.9)
    # --- A'' tutti (30–37)
    s.crash(30, 0, 0.6)
    s.pad(30, A, "violins2", 57, 77, 4, vel=0.48)
    s.pad(30, A, "trombones", 45, 62, 3, vel=0.42)
    s.pad(30, A, "choir", 55, 70, 4, vel=0.35)
    s.bass(30, A, "basses", octave=1, vel=0.62, rhythm=((0, 2), (2, 2)), fifth=True)
    s.bass(30, A, "tuba", octave=2, vel=0.45, rhythm=((0, 2), (2, 2)))
    s.melody(30, melA, "horns", vel=0.85)
    s.melody(30, melA, "trumpets", vel=0.5, octave=1)
    s.melody(30, melA, "violins", vel=0.6, octave=1)
    for b in range(30, 38):
        s.timp(b, 0, 43 if b % 2 == 0 else 38, 0.6)
        s.timp(b, 2, 43, 0.3)
    s.drums(30, 8, "X...x...X...x.x.", "snare", vel=0.32)
    s.drums(30, 8, "X.......X.......", "bassdrum", vel=0.35)
    # --- kapanış (38–44): çağrının yankısı, tek çan, pedal (başa döner)
    coda = ["Gm", "Eb", "Cm", "D", "Gm", "Gm", "Gm"]
    s.pad(38, coda, "violins2", 55, 72, 4, vel=0.34)
    s.bass(38, coda, "basses", octave=1, vel=0.42)
    s.bass(38, coda, "cellos", octave=2, vel=0.3)
    s.melody(39, "D4:1 G4:2 Bb4:1 A4:3 r:1 D4:1 G4:2 Bb4:1 A4:2 G4:6", "horns", vel=0.5)
    s.put("bells", s.t(42, 0), bell(43, 0.45, 6.0, 0.6), 1.0)
    s.drums(40, 4, "x...............", "snare", vel=0.1)
    s.timp_roll(42, 0, 43, 8, 0.4, 0.03)
    return s.render(2.8)


def march() -> np.ndarray:
    """Re minör, 72 BPM (eski ana tema; dünyada savaş listesinde): korno çağrısı → ana tema (korno + viyola) → yaylılarda
    tekrar → Fa majör marş (trompet, trampet) → tutti doruk → çağrının yankısı ile kapanış."""
    s = Song(72, 54)
    # --- giriş (0–5)
    s.bass(0, ["Dm"] * 6, "basses", octave=1, vel=0.5)
    s.bass(0, ["Dm"] * 6, "cellos", octave=2, vel=0.4, rhythm=((0, 4),), fifth=False)
    s.timp_roll(2, 0, 38, 8, 0.05, 0.6)
    s.melody(1, "A3:1 D4:1 E4:1 F4:1 E4:3 A3:1 D4:4", "horns", vel=0.7)
    s.pad(4, ["Dm", "A"], "violins2", 57, 74, 4, vel=0.35)
    s.melody(4.5, "A4:2 G4:2 E4:4", "violas", vel=0.4)
    # --- A (6–13)
    A = bars_of("Dm C Bb A Dm F Gm A7")
    melA = ("D4:1.5 E4:.5 F4:1 A4:1 G4:1.5 F4:.5 E4:2 F4:1 G4:1 A4:1 D5:1 C#5:3 A4:1 "
            "D5:1.5 C5:.5 A4:1 F4:1 C5:1.5 Bb4:.5 A4:2 G4:1 Bb4:1 A4:1 C#4:1 D4:4")
    s.pad(6, A[:7] + ["Dm"], "violins2", 55, 74, 4, vel=0.4)
    s.bass(6, A[:7] + ["Dm"], "basses", octave=1, vel=0.5, rhythm=((0, 2), (2, 2)), fifth=True)
    s.bass(6, A[:7] + ["Dm"], "cellos", octave=2, vel=0.35)
    s.melody(6, melA, "horns", vel=0.72)
    s.melody(6, melA, "violas", vel=0.35, octave=0)
    for b in (6, 10):
        s.timp(b, 0, 38, 0.45)
    # --- A' (14–21): yaylılarda oktav yukarı, bakır karşı ses
    A2 = bars_of("Dm C Bb A Dm F Gm A")
    s.pad(14, A2, "violas", 55, 72, 4, vel=0.42)
    s.bass(14, A2, "basses", octave=1, vel=0.55, rhythm=((0, 2), (2, 2)), fifth=True)
    s.bass(14, A2, "cellos", octave=2, vel=0.45, rhythm=((0, 1), (1, 1), (2, 1), (3, 1)))
    s.melody(14, melA.replace("D4:4", "E4:4"), "violins", vel=0.62, octave=1)
    s.melody(14, "r:4 C4:4 D4:4 E4:4 F4:4 A3:4 D4:2 E4:2 E4:4", "trombones", vel=0.4)
    s.drums(14, 8, "X.......x.......", "snare", vel=0.25)
    s.timp_roll(21, 0, 45, 4, 0.1, 0.8)
    # --- B marş (22–37), Fa majör
    B = bars_of("F C Dm Bb F C Bb F Dm A Bb F Gm C A A")
    melB = ("C5:1 C5:.5 D5:.5 C5:1 A4:1 G4:1.5 A4:.5 G4:1 E4:1 F4:1 A4:1 D5:1.5 C5:.5 Bb4:1.5 A4:.5 Bb4:1 D5:1 "
            "C5:1 C5:.5 D5:.5 C5:1 F5:1 E5:1.5 D5:.5 C5:2 D5:1 Bb4:1 C5:1 E4:1 F4:4 "
            "A4:1 A4:.5 Bb4:.5 A4:1 F4:1 E4:1 A4:1 C#5:2 D5:1.5 C5:.5 Bb4:1 A4:1 C5:2 F4:2 "
            "G4:1 Bb4:1 D5:1 G5:1 F5:1.5 E5:.5 D5:1 C5:1 C#5:2 E5:2 A4:4")
    s.crash(22, 0, 0.45)
    s.drums(22, 15, "X..rx.x.X..rx.xx", "snare", vel=0.4)
    s.drums(22, 16, "X.......x.......", "bassdrum", vel=0.35)
    s.bass(22, B, "tuba", octave=2, vel=0.5, rhythm=((0, 1), (1, 1), (2, 1), (3, 1)), fifth=True)
    s.ostinato(22, B, [0, 2, 3, 2], "violas", step=1.0, low=55, vel=0.3)
    s.pad(22, B, "horns", 53, 70, 3, vel=0.3)
    s.melody(22, melB, "trumpets", vel=0.62)
    s.snare_roll(36, 0, 8, 0.1, 0.9)
    s.timp_roll(36, 0, 45, 8, 0.1, 1.0)
    # --- A'' tutti (38–45)
    s.crash(38, 0, 0.8)
    s.pad(38, A2[:7] + ["Dm"], "violins2", 57, 77, 4, vel=0.5)
    s.pad(38, A2[:7] + ["Dm"], "trombones", 45, 62, 3, vel=0.45)
    s.bass(38, A2[:7] + ["Dm"], "basses", octave=1, vel=0.65, rhythm=((0, 2), (2, 2)), fifth=True)
    s.bass(38, A2[:7] + ["Dm"], "tuba", octave=2, vel=0.5, rhythm=((0, 2), (2, 2)))
    s.melody(38, melA, "horns", vel=0.85, octave=0)
    s.melody(38, melA, "trumpets", vel=0.6, octave=1)
    s.melody(38, melA, "violins", vel=0.6, octave=1)
    for b in range(38, 46):
        s.timp(b, 0, 38 if b % 2 == 0 else 45, 0.65)
    s.drums(38, 7, "X...x...X...x.x.", "snare", vel=0.35)
    # --- kapanış (46–53)
    s.pad(46, ["Dm", "Bb", "Gm", "A", "Dm", "Dm"], "violins2", 55, 72, 4, vel=0.38)
    s.bass(46, ["Dm", "Bb", "Gm", "A", "Dm", "Dm"], "basses", octave=1, vel=0.45)
    s.melody(47, "A3:1 D4:1 E4:1 F4:1 E4:3 A3:1 D4:8", "horns", vel=0.55)
    s.timp_roll(50, 0, 38, 8, 0.6, 0.05)
    return s.render(2.6)


def peace_1() -> np.ndarray:
    """Fa majör, 66 BPM: piyano arpejleri, obua ve flüt melodisi, yaylı yastık, korno solosu."""
    s = Song(66, 42)
    intro = bars_of("F Dm Bb C")
    s.arp(0, intro, "piano", step=0.5, low=53, vel=0.38)
    s.bass(0, intro, "cellos", octave=2, vel=0.3)
    A = bars_of("F Am Bb F Dm Gm C F")
    melA = ("A4:1.5 G4:.5 F4:1 C5:1 E5:1.5 D5:.5 C5:2 D5:1 C5:1 Bb4:1 A4:1 C5:2 A4:2 "
            "F5:1.5 E5:.5 D5:1 A4:1 Bb4:1.5 A4:.5 G4:1 D5:1 C5:1 Bb4:1 A4:1 G4:1 F4:4")
    s.arp(4, A, "piano", step=0.5, low=53, vel=0.32)
    s.pad(4, A, "violins2", 53, 70, 4, vel=0.3)
    s.bass(4, A, "cellos", octave=2, vel=0.32)
    s.melody(4, melA, "oboe", vel=0.6)
    B = bars_of("Dm Bb F C Dm Bb Gm C")
    melB = ("D5:2 E5:1 F5:1 F5:1.5 E5:.5 D5:2 C5:1 D5:1 C5:1 A4:1 G4:3 C5:1 "
            "A4:1 D5:1 F5:1 E5:1 D5:2 Bb4:2 G4:1 A4:1 Bb4:1 D5:1 C5:2 E4:2")
    s.pad(12, B, "violas", 50, 67, 4, vel=0.3)
    s.bass(12, B, "basses", octave=1, vel=0.38)
    s.melody(12, melB, "violins", vel=0.55)
    s.arp(12, B, "harp", step=1.0, low=60, vel=0.3, pattern=(0, 1, 2, 3))
    # C: korno solosu
    C = bars_of("Bb F Gm C Bb F Gm F")
    melC = "F4:2 G4:1 A4:1 C5:2 A4:2 Bb4:1.5 A4:.5 G4:1 F4:1 E4:2 G4:2 D5:2 C5:1 Bb4:1 A4:2 C5:2 Bb4:1 A4:1 G4:1 E4:1 F4:4"
    s.pad(20, C, "violins2", 53, 70, 4, vel=0.28)
    s.bass(20, C, "cellos", octave=2, vel=0.35, rhythm=((0, 2), (2, 2)))
    s.melody(20, melC, "horns", vel=0.55)
    # A': flüt + pizz
    s.arp(28, A, "piano", step=0.5, low=53, vel=0.3)
    s.ostinato(28, A, [0, -1, 2, -1, 3, -1, 2, -1], "pizz", step=0.5, low=48, vel=0.4)
    s.pad(28, A, "violins2", 53, 70, 4, vel=0.26)
    s.melody(28, melA, "flute", vel=0.55, octave=1)
    s.melody(28, melA, "clarinet", vel=0.3, octave=0)
    # kapanış
    out = bars_of("Bb F C F F F")
    s.arp(36, out, "piano", step=0.5, low=53, vel=0.3)
    s.pad(36, out, "violins2", 53, 70, 4, vel=0.25)
    s.bass(36, out, "basses", octave=1, vel=0.3)
    s.melody(37, "A4:2 G4:2 F4:8", "oboe", vel=0.45)
    s.put("celesta", s.t(40, 0), bell(77, 0.3, 4.0), 1.0)
    return s.render(2.4)


def peace_2() -> np.ndarray:
    """Si bemol majör, 92 BPM: pizzicato, klarnet, flüt; hafif ve diplomatik."""
    s = Song(92, 42)
    A = bars_of("Bb Gm Eb F Bb Gm Cm F Bb")
    melA = ("F4:.5 Bb4:.5 D5:1 C5:.5 Bb4:.5 C5:1 D5:1 Bb4:1 G4:2 G4:.5 A4:.5 Bb4:1 Eb5:1 D5:1 C5:3 r:1 "
            "F4:.5 Bb4:.5 D5:1 F5:1 D5:1 Eb5:1 D5:.5 C5:.5 Bb4:2 C5:1 Eb5:1 D5:1 C5:1 Bb4:3 r:1")
    chA = bars_of("Bb Gm Eb F Bb Gm Cm Bb")
    s.ostinato(0, bars_of("Bb Bb"), [0, 2, 3, 2], "pizz", step=1.0, low=46, vel=0.45)
    for sec, inst in ((2, "clarinet"), (26, "flute")):
        s.ostinato(sec, chA, [0, -1, 2, -1, 3, -1, 2, 1], "pizz", step=0.5, low=46, vel=0.42)
        s.bass(sec, chA, "cellos", octave=2, vel=0.32, rhythm=((0, 1), (2, 1)), fifth=True)
        s.pad(sec, chA, "violins2", 55, 72, 3, vel=0.22)
        s.melody(sec, melA, inst, vel=0.6, octave=1 if inst == "flute" else 0)
        s.drums(sec, 8, "x...x...x...x.x.", "snare", vel=0.08)
    B = bars_of("Gm Cm F Bb Eb Cm D D7")
    melB = ("G5:1 F5:.5 Eb5:.5 D5:2 Eb5:1 D5:.5 C5:.5 Bb4:2 A4:1 C5:1 F5:1 Eb5:1 D5:3 r:1 "
            "G4:1 Bb4:1 Eb5:1 G5:1 F5:1.5 Eb5:.5 C5:2 F#4:1 A4:1 D5:1 C5:1 A4:2 F#4:2")
    s.pad(10, B, "violas", 50, 67, 4, vel=0.3)
    s.bass(10, B, "basses", octave=1, vel=0.35, rhythm=((0, 2), (2, 2)))
    s.ostinato(10, B, [0, 1, 2, 1], "pizz", step=1.0, low=55, vel=0.35)
    s.melody(10, melB, "flute", vel=0.55)
    C = bars_of("Eb Bb Cm F Eb Bb Cm Bb")
    melC = "G4:2 Bb4:1 Eb5:1 D5:2 Bb4:2 C5:1 Eb5:1 D5:1 C5:1 A4:3 r:1 G4:1 Bb4:1 Eb5:2 F5:1.5 D5:.5 Bb4:2 C5:1 Eb5:1 A4:1 C5:1 Bb4:4"
    s.pad(18, C, "violins2", 55, 72, 4, vel=0.28)
    s.bass(18, C, "cellos", octave=2, vel=0.35)
    s.melody(18, melC, "horns", vel=0.5)
    s.melody(18, melC, "clarinet", vel=0.25, octave=1)
    # tekrar + kapanış
    s.ostinato(34, chA, [0, -1, 2, -1, 3, -1, 2, 1], "pizz", step=0.5, low=46, vel=0.4)
    s.bass(34, chA, "cellos", octave=2, vel=0.3, rhythm=((0, 1), (2, 1)), fifth=True)
    s.melody(34, melA, "clarinet", vel=0.5)
    s.melody(34, melA, "flute", vel=0.3, octave=1)
    s.pad(34, chA, "violins2", 55, 72, 3, vel=0.22)
    s.put("celesta", s.t(41, 0), bell(82, 0.25, 3.5), 1.0)
    return s.render(2.2)


def tension() -> np.ndarray:
    """Do minör, 58 BPM: saat tıkırtısı, alçak yaylı ostinato, timpani kabarmaları, korno motifi."""
    s = Song(58, 32)
    s.drums(0, 31, "X...x...X...x...", "clock", vel=0.35)
    s.bass(0, ["Cm"] * 4, "basses", octave=1, vel=0.35)
    s.pad(0, ["Cm", "Cm", "Ab", "G"], "violins", 72, 88, 3, vel=0.18)
    A = bars_of("Cm Ab Fm G Cm Db Bbm G")
    melA = "G3:2 Ab3:1 G3:1 Eb4:3 D4:1 C4:2 Db4:1 C4:1 B3:4 G3:2 C4:1 Eb4:1 F4:2 Ab4:2 Gb4:1 F4:1 Db4:1 Bb3:1 B3:2 D4:2"
    s.ostinato(4, A, [0, 0, -1, 0, 1, 0, -1, 0], "cellos", step=0.5, low=36, vel=0.45)
    s.bass(4, A, "basses", octave=1, vel=0.4)
    s.melody(4, melA, "horns", vel=0.55)
    s.pad(4, A, "violas", 55, 70, 3, vel=0.22)
    for b in range(4, 12, 2):
        s.timp_roll(b, 2, 36, 2, 0.05, 0.45)
    B = bars_of("Ab Fm Db G Ab Fm G G")
    melB = "C5:4 Ab4:4 F4:2 Ab4:2 G4:4 Eb5:4 C5:2 Ab4:2 B4:2 D5:2 G4:4"
    s.ostinato(12, B, [0, 0, 2, 0, 3, 0, 2, 0], "cellos", step=0.5, low=36, vel=0.5)
    s.bass(12, B, "basses", octave=1, vel=0.45)
    s.melody(12, melB, "violins", vel=0.45)
    s.pad(12, B, "choir", 55, 70, 3, vel=0.25)
    for b in range(12, 20):
        s.timp(b, 0, 36 if b % 2 == 0 else 43, 0.4)
    s.drums(16, 4, "....x.......x...", "snare", vel=0.15)
    s.ostinato(20, A, [0, 0, 1, 0, 2, 0, 1, 0], "cellos", step=0.5, low=36, vel=0.55)
    s.bass(20, A, "basses", octave=1, vel=0.5)
    s.melody(20, melA, "trombones", vel=0.55)
    s.melody(20, melA, "horns", vel=0.4, octave=1)
    s.pad(20, A, "violins2", 60, 76, 3, vel=0.25)
    s.drums(20, 8, "x.......x.....x.", "snare", vel=0.18)
    s.timp_roll(26, 0, 43, 8, 0.1, 0.8)
    s.bass(28, ["Cm"] * 4, "basses", octave=1, vel=0.35)
    s.pad(28, ["Cm", "Ab", "G", "Cm"], "violins", 72, 88, 3, vel=0.16)
    s.melody(28, "G3:2 Ab3:1 G3:1 C4:8", "horns", vel=0.35)
    return s.render(2.8)


def war_world() -> np.ndarray:
    """Sol minör, 84 BPM: askerî trampet marşı, bas davul, alçak bakır, korno ve trompet melodisi."""
    s = Song(84, 44)
    s.drums(0, 2, "X..rX..rX.xxX.xx", "snare", vel=0.4)
    s.drums(0, 2, "X.......X.......", "bassdrum", vel=0.4)
    A = bars_of("Gm Gm Eb D Gm Cm D Gm")
    melA = ("G4:1 G4:.5 A4:.5 Bb4:1 G4:1 D5:2 Bb4:2 Eb5:1 D5:.5 C5:.5 Bb4:1 G4:1 A4:3 D4:1 "
            "G4:1 Bb4:1 D5:1 G5:1 F5:1 Eb5:.5 D5:.5 C5:2 Bb4:1 A4:1 C5:1 F#4:1 G4:4")
    B = bars_of("Eb Bb Cm D Eb Bb Cm D")
    melB = ("G5:2 Eb5:2 F5:1.5 D5:.5 Bb4:2 C5:1 Eb5:1 G5:1 F5:1 F#5:3 D5:1 "
            "Bb5:2 G5:1 Eb5:1 F5:1 D5:1 Bb4:2 C5:1 Eb5:1 D5:1 F#4:1 G4:4")
    C = bars_of("Cm Gm Ab D Cm Gm Eb D")
    melC = "Eb4:2 C4:2 D4:2 Bb3:2 C4:1 Eb4:1 Ab4:2 F#4:4 G4:1 Ab4:1 G4:1 Eb4:1 D4:4 Eb4:2 D4:1 C4:1 D4:4"
    plan = [(2, "A"), (10, "B"), (18, "A"), (26, "C"), (34, "A")]
    for start, sec in plan:
        ch, ml = {"A": (A, melA), "B": (B, melB), "C": (C, melC)}[sec]
        loud = sec != "C"
        s.drums(start, 8, "X..rx.x.X..rx.xx" if loud else "x.......x.......", "snare", vel=0.36 if loud else 0.2)
        if loud:
            s.drums(start, 8, "X.......X.......", "bassdrum", vel=0.35)
            s.bass(start, ch, "tuba", octave=2, vel=0.5, rhythm=((0, 1), (1, 1), (2, 1), (3, 1)), fifth=True)
            s.bass(start, ch, "basses", octave=1, vel=0.45, rhythm=((0, 2), (2, 2)))
            s.pad(start, ch, "trombones", 50, 65, 3, vel=0.3)
            s.pad(start, ch, "violins2", 58, 74, 4, vel=0.3)
            s.melody(start, ml, "horns" if sec == "A" else "trumpets", vel=0.68)
            if sec == "A" and start > 2:
                s.melody(start, ml, "violins", vel=0.4, octave=1)
            s.crash(start, 0, 0.35)
        else:
            s.pad(start, ch, "violins2", 55, 72, 4, vel=0.3)
            s.bass(start, ch, "cellos", octave=2, vel=0.4, rhythm=((0, 2), (2, 2)))
            s.melody(start, ml, "violas", vel=0.55, octave=1)
            s.timp_roll(start + 7, 0, 43, 4, 0.1, 0.7)
    s.bass(42, ["Gm", "Gm"], "basses", octave=1, vel=0.5)
    s.timp_roll(42, 0, 43, 6, 0.8, 0.1)
    s.drums(42, 1, "X..rX..rX.......", "snare", vel=0.3)
    return s.render(2.4)


def war_front() -> np.ndarray:
    """Re minör, 112 BPM: oyuncunun savaşı — sürükleyici yaylı ostinato, bakır vuruşları, timpani, kahraman korno teması."""
    s = Song(112, 60)
    A = bars_of("Dm Dm Bb C Dm Dm Gm A")
    melA = ("D4:1.5 A4:.5 A4:2 G4:1 F4:1 E4:1 D4:1 F4:1.5 Bb4:.5 Bb4:2 A4:1 G4:1 E4:2 "
            "D4:1.5 A4:.5 D5:2 C5:1 A4:1 F4:1 A4:1 Bb4:1 A4:1 G4:1 Bb4:1 A4:4")
    B = bars_of("Bb F C Dm Bb F Gm A")
    melB = ("D5:2 F5:2 C5:1.5 A4:.5 C5:2 E5:2 G5:2 F5:1 E5:1 D5:2 D5:1 F5:1 Bb5:2 A5:1.5 G5:.5 F5:2 "
            "G5:1 F5:1 E5:1 D5:1 C#5:2 E5:2")
    Br = bars_of("Gm Dm Bb A Gm Dm E A")
    melBr = "D4:4 F4:2 E4:2 D4:2 F4:2 E4:4 G4:4 A4:2 F4:2 G#4:2 B4:2 A4:4"
    fig = [0, 0, 2, 0, 3, 0, 2, 0]
    acc = "x...x...x.x.x..."

    def driving(start, ch, vel=0.5):
        s.ostinato(start, ch, fig, "cellos", step=0.5, low=38, vel=vel)
        s.ostinato(start, ch, [0, 2, 3, 2], "violas", step=0.5, low=50, vel=vel * 0.7)
        s.bass(start, ch, "basses", octave=1, vel=0.55, rhythm=((0, 2), (2, 2)))
        s.drums(start, len(ch), "X.x.x.x.X.x.xxxx", "snare", vel=0.28)
        s.drums(start, len(ch), "X.....X...X.....", "bassdrum", vel=0.45)
        for b in range(start, start + len(ch)):
            tp = 36 + (chord_bass(ch[b - start]) - 36) % 12      # timpani aralığı: Do2–Si2
            s.timp(b, 0, tp, 0.55)
            s.timp(b, 2.5, tp, 0.35)

    # giriş: ostinato kurulur
    s.ostinato(0, bars_of("Dm Dm Dm Dm"), fig, "cellos", step=0.5, low=38, vel=0.4)
    s.timp_roll(2, 0, 38, 8, 0.05, 0.9)
    s.snare_roll(3, 0, 4, 0.05, 0.7)
    # A
    s.crash(4)
    driving(4, A)
    s.melody(4, melA, "horns", vel=0.8)
    s.pad(4, A, "trombones", 50, 65, 3, vel=0.28)
    # A'
    driving(12, A, 0.55)
    s.melody(12, melA, "horns", vel=0.82)
    s.melody(12, melA, "violins", vel=0.5, octave=1)
    s.pad(12, A, "trombones", 50, 65, 3, vel=0.32)
    # B
    s.crash(20, 0, 0.7)
    driving(20, B, 0.6)
    s.melody(20, melB, "trumpets", vel=0.7)
    s.pad(20, B, "horns", 53, 70, 3, vel=0.35)
    s.pad(20, B, "violins2", 62, 79, 4, vel=0.35)
    # köprü (yarı tempo hissi)
    s.pad(28, Br, "choir", 55, 70, 4, vel=0.4)
    s.pad(28, Br, "violins2", 60, 77, 4, vel=0.3)
    s.bass(28, Br, "basses", octave=1, vel=0.45)
    s.melody(28, melBr, "horns", vel=0.6)
    for b in range(28, 36, 2):
        s.timp(b, 0, 38, 0.5)
    s.timp_roll(35, 0, 45, 4, 0.1, 0.95)
    s.snare_roll(35, 0, 4, 0.1, 0.9)
    # A'' doruk
    s.crash(36, 0, 0.9)
    driving(36, A, 0.62)
    s.melody(36, melA, "horns", vel=0.85)
    s.melody(36, melA, "trumpets", vel=0.6, octave=1)
    s.melody(36, melA, "violins", vel=0.55, octave=1)
    s.pad(36, A, "trombones", 50, 65, 3, vel=0.4)
    # B'
    s.crash(44, 0, 0.8)
    driving(44, B, 0.62)
    s.melody(44, melB, "trumpets", vel=0.75)
    s.melody(44, melB, "violins", vel=0.45)
    s.pad(44, B, "horns", 53, 70, 3, vel=0.4)
    # kapanış
    driving(52, bars_of("Dm Dm Bb A"), 0.6)
    s.melody(52, "D4:4 F4:4 D5:4 C#5:4", "horns", vel=0.8)
    s.melody(52, "D5:4 F5:4 D6:4 C#6:4", "trumpets", vel=0.55)
    s.crash(56, 0, 0.9)
    s.pad(56, ["Dm", "Dm", "-", "-"], "trombones", 50, 65, 3, vel=0.55)
    s.pad(56, ["Dm", "-", "-", "-"], "violins2", 62, 79, 4, vel=0.45)
    s.bass(56, ["Dm", "Dm"], "basses", octave=1, vel=0.6)
    s.timp_roll(56, 0, 38, 6, 1.0, 0.1)
    return s.render(2.3)


def war_hold() -> np.ndarray:
    """Mi minör, 76 BPM: 'Son Mevzi' — ağır bakır korali, timpani, trampet yuvarlanmaları, koro."""
    s = Song(76, 42)
    s.bass(0, ["Em"] * 4, "basses", octave=1, vel=0.45)
    s.timp_roll(0, 0, 40, 16, 0.05, 0.7)
    s.pad(2, ["Em", "C"], "choir", 52, 67, 4, vel=0.3)
    A = bars_of("Em C G D Em Am B B")
    melA = "E4:2 G4:1 F#4:1 E4:2 C4:2 D4:1.5 E4:.5 G4:2 F#4:4 E4:1 G4:1 B4:1 A4:1 A4:2 C5:2 B4:2 A4:1 G4:1 F#4:4"
    B = bars_of("C G Am Em C G Am Em")
    melB = "E5:2 G5:2 D5:2 B4:2 C5:1 E5:1 A5:2 G5:2 E5:2 E5:1 F#5:1 G5:2 D5:1.5 B4:.5 D5:2 C5:1 E5:1 D#5:2 E5:4"
    C = bars_of("Am Em C B Am Em F#dim B")
    melC = "A4:2 C5:2 B4:2 G4:2 E5:2 G5:2 F#5:4 A5:2 E5:2 G5:2 B4:2 C5:2 A4:2 B4:4"

    def heavy(start, ch, vel=0.5):
        s.bass(start, ch, "basses", octave=1, vel=vel, rhythm=((0, 3), (3, 1)))
        s.bass(start, ch, "tuba", octave=2, vel=vel * 0.8, rhythm=((0, 3), (3, 1)))
        s.pad(start, ch, "violins2", 55, 72, 4, vel=vel * 0.6)
        for b in range(start, start + len(ch)):
            s.timp(b, 0, 40 if b % 2 == 0 else 47, 0.6)
            s.timp(b, 3, 40, 0.3)
        s.drums(start, len(ch), "X.....r.x.....xx", "snare", vel=0.3)

    heavy(4, A)
    s.melody(4, melA, "trombones", vel=0.7)
    s.melody(4, melA, "horns", vel=0.55, octave=1)
    s.crash(12, 0, 0.7)
    heavy(12, B, 0.55)
    s.melody(12, melB, "trumpets", vel=0.68)
    s.pad(12, B, "horns", 52, 67, 3, vel=0.35)
    s.pad(12, B, "choir", 55, 70, 4, vel=0.35)
    # kırılma: yaylılar
    s.pad(20, C, "violas", 52, 67, 4, vel=0.35)
    s.bass(20, C, "cellos", octave=2, vel=0.4, rhythm=((0, 2), (2, 2)))
    s.melody(20, melC, "violins", vel=0.55)
    s.timp_roll(27, 0, 47, 4, 0.1, 0.9)
    s.snare_roll(27, 0, 4, 0.1, 0.85)
    # tutti dönüş
    s.crash(28, 0, 0.9)
    heavy(28, A, 0.6)
    s.melody(28, melA, "trombones", vel=0.8)
    s.melody(28, melA, "horns", vel=0.65, octave=1)
    s.melody(28, melA, "violins", vel=0.5, octave=1)
    s.pad(28, A, "choir", 55, 70, 4, vel=0.4)
    heavy(36, bars_of("Em C Am B"), 0.55)
    s.melody(36, "E4:4 G4:4 C5:4 B4:4", "horns", vel=0.7)
    s.crash(40, 0, 0.8)
    s.pad(40, ["Em", "-"], "trombones", 45, 62, 3, vel=0.5)
    s.pad(40, ["Em", "-"], "choir", 55, 70, 4, vel=0.4)
    s.bass(40, ["Em"], "basses", octave=1, vel=0.55)
    s.timp_roll(40, 0, 40, 6, 0.9, 0.05)
    return s.render(2.6)


# ---------------------------------------------------------------------- olay müzikleri
def stinger_war_player() -> np.ndarray:
    """Oyuncunun savaşı: hava saldırısı sireni, tutti Re minör darbe, timpani ve trampet yuvarlanması, uzun bakır."""
    s = Song(90, 7, tail=4)
    s.put("bells", 0.0, siren(7.0, 230, 610, 0.55), 1.0, pan=0.0)
    s.timp_roll(0, 0, 38, 6, 0.05, 1.0)
    s.snare_roll(0.5, 0, 4, 0.05, 0.9)
    s.crash(2, 0, 1.0)
    for inst, lo, hi, n, v in (("trombones", 45, 62, 3, 0.8), ("horns", 53, 69, 3, 0.8), ("trumpets", 62, 77, 3, 0.6),
                               ("violins2", 62, 81, 4, 0.55), ("choir", 55, 70, 4, 0.5)):
        s.pad(2, ["Dm", "Bb", "A"], inst, lo, hi, n, per=4.0 / 3 * 2, vel=v)
    s.bass(2, ["Dm", "Bb", "A"], "basses", octave=1, per=8 / 3, vel=0.7)
    s.timp(2, 0, 38, 1.0)
    s.timp(4, 0, 34, 0.9)
    s.timp(5, 1, 45, 1.0)
    s.melody(2, "D4:1 A4:1 D5:6", "horns", vel=0.9)
    return s.render(2.6)


def stinger_war_world() -> np.ndarray:
    """Dünyada yeni savaş (oyuncu değil): uzak timpani ve alçak bakır minör akor."""
    s = Song(70, 4, tail=4)
    s.timp(0, 0, 43, 0.6)
    s.timp(0, 1.5, 43, 0.5)
    s.timp_roll(1, 0, 43, 3, 0.1, 0.6)
    s.pad(1, ["Gm", "D"], "horns", 50, 65, 3, per=3, vel=0.55)
    s.pad(1, ["Gm", "D"], "violas", 55, 70, 4, per=3, vel=0.35)
    s.bass(1, ["Gm", "D"], "basses", octave=1, per=3, vel=0.5)
    return s.render(3.0)


def stinger_victory() -> np.ndarray:
    """Zafer: Re majör bakır fanfarı, zil, timpani, yaylı yastık."""
    s = Song(96, 6, tail=4)
    s.crash(0, 0, 0.6)
    s.melody(0, "D4:.5 F#4:.5 A4:.5 D5:1.5 A4:.5 D5:.5 F#5:4", "trumpets", vel=0.85)
    s.melody(0, "D3:.5 F#3:.5 A3:.5 D4:1.5 A3:.5 D4:.5 F#4:4", "horns", vel=0.75)
    s.pad(2, ["D", "G", "A", "D"], "violins2", 62, 81, 4, per=2, vel=0.5)
    s.pad(2, ["D", "G", "A", "D"], "trombones", 45, 62, 3, per=2, vel=0.5)
    s.bass(2, ["D", "G", "A", "D"], "basses", octave=1, per=2, vel=0.6)
    for b, m in ((0, 38), (2, 38), (3, 43), (4, 45), (5, 38)):
        s.timp(b, 0, m, 0.8)
    s.crash(4, 0, 0.8)
    s.melody(4, "A4:1 D5:1 F#5:1 A5:5", "trumpets", vel=0.75)
    return s.render(2.8)


def stinger_defeat() -> np.ndarray:
    """Yenilgi: ağıt yaylıları ve çan."""
    s = Song(56, 5, tail=5)
    ch = ["Dm", "Bb", "Gm", "A", "Dm"]
    s.pad(0, ch, "violins2", 57, 74, 4, per=4, vel=0.42)
    s.bass(0, ch, "cellos", octave=2, per=4, vel=0.45)
    s.bass(0, ch, "basses", octave=1, per=4, vel=0.4)
    s.melody(0, "F4:2 E4:1 D4:1 D4:2 F4:2 Bb4:3 A4:1 G4:2 E4:2 D4:4", "violins", vel=0.55)
    for b in range(0, 5):
        s.put("bells", s.t(b, 0), bell(50, 0.5, 5.0, 0.7), 1.0)
    s.timp_roll(3, 0, 38, 8, 0.4, 0.05)
    return s.render(3.0)


def stinger_peace() -> np.ndarray:
    """Barış: Fa majör yaylı çözümü ve korno."""
    s = Song(60, 4, tail=5)
    ch = ["F", "C/E", "Dm", "Bb", "F"]
    s.pad(0, ch, "violins2", 57, 74, 4, per=3.2, vel=0.4)
    s.bass(0, ["F", "C", "D", "Bb", "F"], "cellos", octave=2, per=3.2, vel=0.4)
    s.melody(0, "C5:3 A4:3 F4:3 G4:3 A4:4", "horns", vel=0.55)
    s.put("celesta", s.t(3.6, 0), bell(77, 0.35, 4.0), 1.0)
    return s.render(2.8)


TRACKS = {
    "main_theme": main_theme, "march": march, "peace_1": peace_1, "peace_2": peace_2, "tension": tension, "war_world": war_world,
    "war_front": war_front, "war_hold": war_hold, "stinger_war_player": stinger_war_player,
    "stinger_war_world": stinger_war_world, "stinger_victory": stinger_victory, "stinger_defeat": stinger_defeat,
    "stinger_peace": stinger_peace,
}

def trim_tail(st: np.ndarray, thr_db: float = -46.0, keep: float = 0.3) -> np.ndarray:
    """Sondaki sessizliği kes (eşik altı), kısa kararma ile bitir."""
    win = int(0.05 * SR)
    p = (st ** 2).mean(axis=0)
    n = len(p) // win
    rms = np.sqrt(p[: n * win].reshape(n, win).mean(axis=1))
    idx = np.nonzero(rms > 10 ** (thr_db / 20))[0] * win
    if len(idx) == 0:
        return st
    end = min(st.shape[1], int(idx[-1] + keep * SR))
    st = st[:, :end].copy()
    k = min(int(0.4 * SR), end)
    st[:, -k:] *= np.linspace(1, 0, k)
    return st


if __name__ == "__main__":
    import time
    names = sys.argv[1:] or list(TRACKS)
    OUT.mkdir(parents=True, exist_ok=True)
    for name in names:
        t0 = time.time()
        st = trim_tail(TRACKS[name]())
        write_ogg(OUT / f"{name}.ogg", st)
        if name == "main_theme":
            write_mp3(ROOT / "tools" / "web" / "loading_theme.mp3", st, 112)
        print(f"{name}: {st.shape[1] / SR:.1f} sn, {time.time() - t0:.1f} sn üretim, "
              f"{(OUT / f'{name}.ogg').stat().st_size / 1e6:.2f} MB")
