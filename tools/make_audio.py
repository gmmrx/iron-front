#!/usr/bin/env python3
"""Iron Front ses seti (prosedürel sentez) -> assets/audio/*.wav

Amaç: 2. Dünya Savaşı büyük strateji hissi. Arayüz sesleri mekanik/kâğıt dokulu ve kısa; birim sesleri
telsiz cızırtılı; uyarılar telgraf/daktilo; büyük olaylar davul + boru; muharebe sesleri (3D, yakın zoom'da
duyulur) tüfek, makineli, top, tank motoru, uçak geçişi, gemi topu. Telifli örnek kullanılmaz.

Çalıştır: python3 tools/make_audio.py
"""
import wave
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
SR = 44100
rng = np.random.default_rng(7)


# ------------------------------------------------------------------ yardımcılar
def write(name, x, peak=0.8):
    x = np.asarray(x, dtype=np.float64)
    x = np.clip(x / (np.abs(x).max() + 1e-9) * peak, -1, 1)
    data = (x * 32767).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def t_(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=0.1, hold=0.0):
    t = np.arange(n) / SR
    return np.minimum(t / max(a, 1e-5), 1.0) * np.exp(-np.maximum(t - hold, 0) / r)


def noise(d):
    return rng.standard_normal(int(SR * d))


def band(x, lo, hi):
    """FFT bant geçiren (yumuşak kenarlı)."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    m = np.clip((f - lo) / max(lo * 0.3, 20), 0, 1) * np.clip((hi - f) / max(hi * 0.3, 40), 0, 1)
    return np.fft.irfft(np.fft.rfft(x) * m, n)


def lowpass(x, fc):
    return band(x, 0, fc)


def tone(f, d, harm=(1.0,), fm=None):
    t = t_(d)
    ph = 2 * np.pi * f * t if fm is None else 2 * np.pi * np.cumsum(fm(t)) / SR
    x = np.zeros_like(t)
    for i, h in enumerate(harm, 1):
        x += h * np.sin(ph * i)
    return x


def reverb(x, d=0.5, wet=0.35, dark=3000):
    """Basit uzay: azalan gürültü darbe yanıtı ile evrişim."""
    ir = noise(d) * np.exp(-t_(d) / (d / 3.5))
    ir = lowpass(ir, dark)
    ir /= np.abs(ir).sum() / 40
    y = np.fft.irfft(np.fft.rfft(x, len(x) + len(ir)) * np.fft.rfft(ir, len(x) + len(ir)))
    out = np.zeros(len(y))
    out[: len(x)] += x
    return out + wet * y


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(x, offset, part):
    """x içine offset saniyede part ekle (gerekirse uzatır)."""
    o = int(SR * offset)
    n = max(len(x), o + len(part))
    out = np.zeros(n)
    out[: len(x)] = x
    out[o:o + len(part)] += part
    return out


def thump(f=70.0, d=0.35, decay=6.0, punch=0.4):
    """Alçak vuruş: aşağı kayan sinüs + kısa gürültü darbesi."""
    t = t_(d)
    x = np.sin(2 * np.pi * f * (1 + 1.6 * np.exp(-t * 18)) * t) * np.exp(-t * decay)
    x += lowpass(noise(d), 900) * np.exp(-t * 40) * punch
    return x


def crack(d=0.09, lo=900, hi=5000, decay=60):
    return band(noise(d), lo, hi) * np.exp(-t_(d) * decay)


# ------------------------------------------------------------------ arayüz
def ui_click():
    # mekanik tık: kısa yüksek transient + ahşap gövde
    n = int(SR * 0.05)
    x = band(noise(0.05), 1800, 6500) * env(n, 0.0005, 0.006)
    x += np.sin(2 * np.pi * 190 * t_(0.05)) * env(n, 0.0008, 0.02) * 0.9
    write("ui_click", x, 0.6)


def ui_hover():
    n = int(SR * 0.02)
    x = band(noise(0.02), 3000, 8000) * env(n, 0.0003, 0.003)
    write("ui_hover", x, 0.25)


def ui_open():
    # kâğıt kayması + kapanış tıkı
    n = int(SR * 0.16)
    slide = band(noise(0.16), 700, 3500) * np.minimum(t_(0.16) / 0.06, 1) * np.exp(-np.maximum(t_(0.16) - 0.09, 0) * 40)
    x = at(slide * 0.6, 0.12, band(noise(0.04), 1500, 6000) * env(int(SR * 0.04), 0.0005, 0.006))
    write("ui_open", x, 0.55)


def ui_close():
    click = band(noise(0.04), 1500, 6000) * env(int(SR * 0.04), 0.0005, 0.006)
    slide = band(noise(0.12), 500, 2500) * np.exp(-t_(0.12) * 25)
    write("ui_close", at(click, 0.02, slide * 0.5), 0.5)


def ui_tab():
    n = int(SR * 0.04)
    x = band(noise(0.04), 2500, 7000) * env(n, 0.0004, 0.005) + np.sin(2 * np.pi * 320 * t_(0.04)) * env(n, 0.001, 0.012) * 0.5
    write("ui_tab", x, 0.5)


def ui_error():
    t = t_(0.18)
    x = np.sign(np.sin(2 * np.pi * 140 * t)) * 0.4 + np.sin(2 * np.pi * 140 * t)
    x = lowpass(x, 1200) * env(len(t), 0.005, 0.08)
    write("ui_error", x, 0.5)


# ------------------------------------------------------------------ birim / emir
def radio_blip(f=1200, d=0.05):
    return tone(f, d) * env(int(SR * d), 0.002, 0.02)


def squelch(d=0.07):
    return band(noise(d), 900, 3200) * env(int(SR * d), 0.002, 0.03)


def select_unit():
    x = mix(squelch(0.08) * 0.8, at(np.zeros(1), 0.03, radio_blip(1100, 0.05)))
    write("select_unit", x, 0.5)


def order_move():
    # telsiz "anlaşıldı": iki blip + üç adım
    x = mix(squelch(0.06) * 0.6, radio_blip(1000, 0.05))
    x = at(x, 0.08, radio_blip(1350, 0.05))
    for i in range(3):
        step = mix(lowpass(noise(0.07), 1200) * env(int(SR * 0.07), 0.001, 0.02), thump(110, 0.08, 40, 0.2) * 0.6)
        x = at(x, 0.22 + i * 0.13, step * (0.7 + 0.15 * i))
    write("order_move", x, 0.55)


def order_attack():
    # telsiz + subay düdüğü
    x = mix(squelch(0.06) * 0.6, radio_blip(1000, 0.05))
    whistle = tone(2600, 0.32, harm=(1, 0.25), fm=lambda t: 2600 + 500 * np.minimum(t / 0.1, 1) + 60 * np.sin(2 * np.pi * 28 * t))
    whistle *= env(int(SR * 0.32), 0.01, 0.12, hold=0.15)
    x = at(x, 0.1, whistle * 0.5)
    write("order_attack", x, 0.55)


def select_fleet():
    # gemi çanı
    t = t_(0.9)
    x = np.zeros_like(t)
    for f, a, dec in ((1050, 1.0, 3.2), (2480, 0.55, 5), (3950, 0.3, 7), (5300, 0.15, 9)):
        x += a * np.sin(2 * np.pi * f * t) * np.exp(-t * dec)
    x = at(x, 0.0, band(noise(0.015), 2000, 9000) * env(int(SR * 0.015), 0.0003, 0.004) * 0.6)
    write("select_fleet", x, 0.5)


def select_air():
    # telsiz + pervane vızıltısı
    t = t_(0.45)
    prop = np.zeros_like(t)
    for i, h in enumerate((1, 0.6, 0.4, 0.25, 0.15), 1):
        prop += h * np.sin(2 * np.pi * 95 * i * t + 0.3 * i)
    prop = lowpass(prop, 1800) * env(len(t), 0.03, 0.18, hold=0.15)
    x = mix(squelch(0.06) * 0.6, at(prop * 0.5, 0.0, radio_blip(1250, 0.05)))
    write("select_air", x, 0.5)


# ------------------------------------------------------------------ uyarılar
def alert():
    # telgraf: di di dah
    x = np.zeros(1)
    for off, d in ((0.0, 0.06), (0.11, 0.06), (0.22, 0.18)):
        beep = tone(720, d, harm=(1, 0.2)) * env(int(SR * d), 0.003, 0.05, hold=d * 0.6)
        x = at(x, off, beep)
        x = at(x, off, band(noise(0.01), 2000, 6000) * env(int(SR * 0.01), 0.0003, 0.003) * 0.5)
    write("alert", x, 0.45)


def research_done():
    a = tone(988, 0.5, harm=(1, 0.35, 0.12)) * env(int(SR * 0.5), 0.004, 0.16)
    b = tone(1319, 0.6, harm=(1, 0.3, 0.1)) * env(int(SR * 0.6), 0.004, 0.2)
    write("research_done", reverb(at(a, 0.12, b), 0.4, 0.3), 0.5)


def focus_done():
    # kauçuk damga: kâğıda vuruş + kısa kâğıt hışırtısı
    st = thump(140, 0.18, 22, 0.8)
    paper = band(noise(0.12), 900, 4000) * np.exp(-t_(0.12) * 30) * 0.4
    write("focus_done", reverb(at(st, 0.03, paper), 0.25, 0.2), 0.6)


def event():
    # daktilo şaryo zili + tuş
    key = band(noise(0.03), 1500, 6000) * env(int(SR * 0.03), 0.0004, 0.006)
    bell = tone(2100, 0.7, harm=(1, 0.4, 0.15)) * env(int(SR * 0.7), 0.002, 0.22)
    write("event", reverb(at(key, 0.05, bell * 0.8), 0.35, 0.25), 0.5)


def production_done():
    # kısa fabrika düdüğü
    t = t_(0.55)
    x = tone(640, 0.55, harm=(1, 0.5, 0.3, 0.2)) + band(noise(0.55), 500, 2500) * 0.35
    x *= env(len(t), 0.03, 0.15, hold=0.25)
    write("production_done", reverb(x, 0.5, 0.35), 0.45)


def capitulation():
    # alçalan boru + davul yuvarlaması
    horn = tone(196, 1.6, harm=(1, 0.6, 0.35, 0.2), fm=lambda t: 196 - 30 * np.minimum(t / 1.2, 1)) * env(int(SR * 1.6), 0.08, 0.5, hold=0.6)
    roll = np.zeros(1)
    for i in range(28):
        roll = at(roll, i * 0.045, band(noise(0.05), 200, 3000) * env(int(SR * 0.05), 0.001, 0.015) * (0.4 + i / 40))
    x = mix(horn, roll * 0.5, at(np.zeros(1), 1.3, thump(55, 1.2, 3, 0.6)))
    write("capitulation", reverb(x, 0.9, 0.4), 0.7)


def victory():
    # yükselen boru fanfarı (majör)
    x = np.zeros(1)
    for off, f, d in ((0.0, 262, 0.22), (0.22, 330, 0.22), (0.44, 392, 0.22), (0.66, 523, 0.9)):
        b = tone(f, d, harm=(1, 0.7, 0.45, 0.3, 0.15)) * env(int(SR * d), 0.02, 0.25, hold=d * 0.6)
        x = at(x, off, b)
    x = at(x, 0.66, thump(65, 0.9, 3.5, 0.5) * 0.8)
    write("victory", reverb(x, 0.8, 0.4), 0.7)


def war_declare():
    # üç timpani vuruşu + minör boru akoru + trampet
    x = np.zeros(1)
    for off in (0.0, 0.32, 0.64):
        x = at(x, off, thump(58, 0.7, 4, 0.6))
    roll = np.zeros(1)
    for i in range(40):
        roll = at(roll, 0.55 + i * 0.04, band(noise(0.05), 300, 4000) * env(int(SR * 0.05), 0.001, 0.014) * (0.3 + i / 60))
    t = t_(2.4)
    brass = np.zeros_like(t)
    for f in (110, 130.8, 164.8, 220):
        brass += tone(f, 2.4, harm=(1, 0.6, 0.35, 0.2, 0.1))
    brass *= np.minimum(np.maximum(t - 0.6, 0) / 0.3, 1) * np.exp(-np.maximum(t - 1.5, 0) * 2.2) * 0.22
    x = mix(x, roll * 0.5, brass)
    write("war_declare", reverb(x, 1.0, 0.4), 0.75)


def battle_start():
    # uzak topçu: iki boğuk gümbürtü
    x = mix(reverb(thump(48, 1.2, 2.5, 0.3), 1.2, 0.6, 900), at(np.zeros(1), 0.45, reverb(thump(42, 1.4, 2.2, 0.25), 1.2, 0.6, 700) * 0.8))
    write("battle_start", lowpass(x, 1200), 0.6)


# ------------------------------------------------------------------ muharebe (3D, yakın zoom)
def rifle_crack():
    x = mix(crack(0.12, 700, 6000, 45), thump(160, 0.1, 40, 0.5) * 0.5)
    write("rifle_crack", reverb(x, 0.35, 0.3, 2500), 0.7)


def mg_burst():
    x = np.zeros(1)
    for i in range(7):
        x = at(x, i * 0.085, mix(crack(0.08, 600, 5000, 55) * (0.9 + 0.2 * rng.random()), thump(140, 0.07, 45, 0.4) * 0.4))
    write("mg_burst", reverb(x, 0.4, 0.3, 2500), 0.7)


def artillery_boom():
    x = mix(thump(50, 1.4, 2.6, 0.9), crack(0.05, 300, 3000, 80) * 0.6)
    write("artillery_boom", reverb(x, 1.0, 0.5, 1200), 0.8)


def explosion():
    x = mix(thump(38, 1.9, 2.0, 1.2), band(noise(1.4), 200, 4000) * np.exp(-t_(1.4) * 3.5) * 0.5)
    debris = np.zeros(1)
    for i in range(10):
        debris = at(debris, 0.25 + rng.random() * 0.9, crack(0.03, 1500, 7000, 120) * 0.25)
    write("explosion", reverb(mix(x, debris), 1.2, 0.5, 1500), 0.85)


def tank_engine():
    # döngü: 2 sn, dizel darbeleri + egzoz gürültüsü (baş/son eşleşir)
    d = 2.0
    t = t_(d)
    pulses = np.sign(np.sin(2 * np.pi * 27 * t)) * 0.5 + np.sin(2 * np.pi * 54 * t) * 0.6 + np.sin(2 * np.pi * 81 * t) * 0.3
    x = lowpass(pulses, 600) + band(noise(d), 300, 2200) * 0.25
    x *= 1 + 0.08 * np.sin(2 * np.pi * 1.0 * t)
    write("tank_engine", x, 0.5)


def plane_flyby():
    # doppler'lı pervane geçişi
    d = 2.6
    t = t_(d)
    f0 = 118 - 40 * (t / d)
    x = np.zeros_like(t)
    for i, h in enumerate((1, 0.7, 0.5, 0.35, 0.2, 0.12), 1):
        x += h * np.sin(2 * np.pi * np.cumsum(f0 * i) / SR)
    x = lowpass(x, 2200)
    wind = band(noise(d), 400, 3000)
    amp = np.exp(-((t - d * 0.45) ** 2) / (2 * 0.45 ** 2))
    write("plane_flyby", (x * 0.7 + wind * 0.3) * amp, 0.6)


def naval_gun():
    x = mix(crack(0.06, 200, 2500, 60) * 0.7, thump(44, 1.8, 2.0, 1.0))
    write("naval_gun", reverb(x, 1.4, 0.55, 900), 0.85)


# ------------------------------------------------------------------ ortam
def ambient():
    """75 sn: karanlık akor döngüsü + rüzgâr + arada uzak gümbürtü (döngüye uygun)."""
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
    x = x / np.abs(x).max() * 0.55
    wind = band(rng.standard_normal(n), 150, 900)
    wind *= 0.5 + 0.5 * np.sin(2 * np.pi * 0.05 * t) * np.sin(2 * np.pi * 0.013 * t + 1)
    x += wind * 0.18
    for off in (9, 27, 44, 61):
        r = reverb(thump(40, 2.0, 1.8, 0.3), 1.5, 0.7, 600)
        o = int(off * SR)
        x[o:o + len(r)] += r[: n - o] * 0.35
    # döngü dikişini yumuşat
    k = int(SR * 2)
    x[:k] *= np.linspace(0, 1, k)
    x[-k:] *= np.linspace(1, 0, k)
    write("ambient", x, 0.8)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for old in ("click", "notify", "war"):
        p = OUT / f"{old}.wav"
        if p.exists():
            p.unlink()
        pi = OUT / f"{old}.wav.import"
        if pi.exists():
            pi.unlink()
    for fn in (ui_click, ui_hover, ui_open, ui_close, ui_tab, ui_error, select_unit, order_move, order_attack,
               select_fleet, select_air, alert, research_done, focus_done, event, production_done, capitulation,
               victory, war_declare, battle_start, rifle_crack, mg_burst, artillery_boom, explosion, tank_engine,
               plane_flyby, naval_gun, ambient):
        fn()
    print(sorted(p.name for p in OUT.glob("*.wav")))
