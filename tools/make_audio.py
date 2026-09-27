#!/usr/bin/env python3
"""Iron Front ses efektleri (prosedürel sentez) -> assets/audio/*.wav

Arayüz sesleri mekanik ve kâğıt dokulu (şalter, dosya kapağı, lastik damga, daktilo, telgraf); birim emirleri telsiz
cızırtısı ve boğuk konuşma; muharebe sesleri (3D, yakın zoom'da) tüfek, makineli, top, tank, uçak, gemi topu.
Sık çalan sesler 2–3 çeşitlemeyle üretilir (ad_1.wav, ad_2.wav...); oyun rastgele birini seçer.
Müzikler ve olay müzikleri: tools/make_music.py. Telifli örnek kullanılmaz.

Çalıştır: python3 tools/make_audio.py
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
    return np.asarray(x).view(Sig)


def bell(*a, **k):
    return S(_bell(*a, **k))


def t_(d):
    return np.arange(int(SR * d)) / SR


def noise(d):
    return rng.standard_normal(max(int(SR * d), 1))


def dec(d, tau):
    return np.exp(-t_(d) / tau)


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
    """Küçük oda / masa yankısı."""
    g = np.random.default_rng(seed)
    ir = g.standard_normal(int(d * SR)) * np.exp(-t_(d) / (d / 4))
    ir = lowpass(ir, dark)
    ir /= np.abs(ir).sum() / 30
    n = len(x) + len(ir)
    y = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)
    out = np.zeros(n)
    out[: len(x)] += x
    return out + wet * y


def hall(x, d=1.2, wet=0.4, dark=2500, seed=1):
    return room(x, d, wet, dark, seed)


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
    """Telsiz: bant sınırlı + hafif doyum."""
    y = bandpass(x, 350, 3000)
    y = np.tanh(y * drive / (np.abs(y).max() + 1e-9)) / np.tanh(drive)
    return S(y)


def squelch(d=0.08):
    return S(bandpass(noise(d), 800, 3500) * np.minimum(t_(d) / 0.004, 1) * dec(d, 0.03))


def chatter(d=0.35, seed=0):
    """Boğuk telsiz konuşması izlenimi: hece zarflı, formantlı gürültü + titreşimli ses tellerini andıran ton (sözsüz)."""
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
    return S(np.sin(2 * np.pi * f * t_(d)) * np.minimum(t_(d) / 0.003, 1) * np.minimum((d - t_(d)) / 0.006, 1) * level)


def step(level=1.0):
    return S((lowpass(noise(0.08), 1400) * dec(0.08, 0.018) + thump(95, 0.1, 0.03, 0.2) * 0.6) * level)


def w(name, x, peak=0.7):
    write_wav(OUT / f"{name}.wav", x, peak)


# ------------------------------------------------------------------ arayüz
def ui_click():
    """Pirinç şalter: basma + bırakma iki tık, kısa metal çınlama, ahşap gövde."""
    for i, (pitch, gap) in enumerate(((3100, 0.026), (2750, 0.031), (3450, 0.022)), 1):
        press = tick(0.012, 2200, 9000, 0.0012) + partials([pitch, pitch * 1.47, pitch * 2.09], [0.35, 0.2, 0.1], [0.01, 0.007, 0.005], 0.04)
        press = at(press, 0.0, thump(170, 0.05, 0.012, 0.25) * 0.5)
        rel = tick(0.01, 3000, 9000, 0.001) * 0.45
        w(f"ui_click_{i}", room(at(press, gap, rel), 0.12, 0.12, 6000, i), 0.55)


def ui_hover():
    w("ui_hover", tick(0.008, 4000, 10000, 0.0009), 0.18)


def ui_open():
    """Dosya kapağı açılır: yükselen kâğıt hışırtısı + yumuşak deri tokluğu."""
    for i, (f0, f1) in enumerate(((900, 3200), (700, 2600)), 1):
        swish = sweep_noise(0.2, f0, f1) * np.sin(np.pi * np.clip(t_(0.2) / 0.2, 0, 1)) ** 1.5
        thud = thump(120, 0.12, 0.03, 0.25) * 0.5
        x = at(swish * 0.7, 0.17, thud)
        x = at(x, 0.18, tick(0.01, 1500, 6000, 0.002) * 0.3)
        w(f"ui_open_{i}", room(x, 0.2, 0.18, 5000, 10 + i), 0.5)


def ui_close():
    """Dosya kapanır: alçalan hışırtı + mandal tıkı."""
    for i, (f0, f1) in enumerate(((2800, 800), (2400, 700)), 1):
        swish = sweep_noise(0.15, f0, f1) * np.sin(np.pi * np.clip(t_(0.15) / 0.15, 0, 1)) ** 1.5
        latch = tick(0.012, 2000, 8000, 0.0015) + partials([2300, 3500], [0.3, 0.15], [0.008, 0.005], 0.03)
        x = at(swish * 0.6, 0.13, latch * 0.8)
        w(f"ui_close_{i}", room(x, 0.18, 0.15, 5000, 20 + i), 0.5)


def ui_tab():
    x = tick(0.02, 2000, 7000, 0.004) + beep(520, 0.03, 0.15) * dec(0.03, 0.01)
    w("ui_tab", room(x, 0.1, 0.1, 6000, 3), 0.45)


def ui_error():
    knock = lambda: thump(210, 0.08, 0.02, 0.5) + tick(0.01, 800, 3000, 0.003) * 0.5
    t = t_(0.16)
    buzz = lowpass(np.sign(np.sin(2 * np.pi * 98 * t)), 900) * np.minimum(t / 0.01, 1) * dec(0.16, 0.06) * 0.35
    x = at(at(knock(), 0.09, knock() * 0.8), 0.04, buzz)
    w("ui_error", room(x, 0.15, 0.15, 4000, 4), 0.5)


def ui_confirm():
    """Lastik damga: kâğıda tok vuruş + kâğıt şaklaması + masa yankısı."""
    for i, f in enumerate((110, 95), 1):
        stamp = thump(f, 0.18, 0.045, 0.9)
        slap = bandpass(noise(0.05), 900, 4500) * dec(0.05, 0.01) * 0.6
        x = at(stamp, 0.004, slap)
        x = at(x, 0.09, bandpass(noise(0.08), 1200, 5000) * dec(0.08, 0.025) * 0.15)
        w(f"ui_confirm_{i}", room(x, 0.25, 0.25, 3500, 30 + i), 0.6)


def ui_toggle():
    x = at(tick(0.01, 2500, 9000, 0.001), 0.012, partials([1800, 2700], [0.3, 0.12], [0.02, 0.012], 0.05))
    w("ui_toggle", room(x, 0.1, 0.1, 6000, 5), 0.45)


def ui_speed():
    x = partials([1400, 3100], [0.5, 0.25], [0.012, 0.006], 0.05) + tick(0.006, 3000, 9000, 0.0008) * 0.6
    w("ui_speed", room(x, 0.12, 0.12, 6000, 6), 0.4)


def ui_pause():
    """Kol indirme: ağır metal kilitlenme."""
    x = thump(80, 0.25, 0.06, 0.6) + partials([420, 980, 1630], [0.35, 0.2, 0.12], [0.08, 0.05, 0.03], 0.25)
    x = at(tick(0.015, 1500, 6000, 0.003) * 0.5, 0.0, x)
    w("ui_pause", room(x, 0.25, 0.2, 3500, 7), 0.55)


def ui_resume():
    x = at(thump(90, 0.15, 0.04, 0.4), 0.0, tick(0.01, 2000, 8000, 0.002) * 0.4)
    for k in range(3):
        x = at(x, 0.12 + k * 0.14, partials([1250, 2800], [0.35, 0.15], [0.012, 0.006], 0.04))
    w("ui_resume", room(x, 0.2, 0.15, 5000, 8), 0.5)


# ------------------------------------------------------------------ eylemler
def build_queued():
    """İnşaat: örse iki çekiç + vinç cırcırı."""
    x = np.zeros(1)
    for k, (off, f) in enumerate(((0.0, 2150), (0.19, 2310))):
        hit = partials([f, f * 1.61, f * 2.37, f * 3.2], [0.6, 0.35, 0.2, 0.1], [0.12, 0.08, 0.05, 0.03], 0.3) + tick(0.01, 2000, 9000, 0.001)
        x = at(x, off, hit * (1.0 - 0.15 * k))
    for k in range(6):
        x = at(x, 0.42 + k * 0.035, tick(0.012, 1500, 5000, 0.003) * 0.35)
    w("build_queued", room(x, 0.35, 0.25, 4000, 40), 0.55)


def production_line():
    """Üretim: pres vuruşu + metal şangırtı + buhar tıslaması."""
    x = thump(65, 0.35, 0.09, 0.8)
    x = at(x, 0.03, partials([640, 1450, 2380], [0.4, 0.25, 0.15], [0.1, 0.06, 0.04], 0.3))
    x = at(x, 0.2, highpass(noise(0.35), 3000) * np.minimum(t_(0.35) / 0.03, 1) * dec(0.35, 0.12) * 0.25)
    w("production_line", room(x, 0.4, 0.25, 3500, 41), 0.6)


def research_start():
    """Daktilo: düzensiz tuş vuruşları."""
    x = np.zeros(1)
    off = 0.0
    for k in range(7):
        key = tick(0.02, 1500, 7000, 0.003) + thump(260, 0.03, 0.006, 0.3) * 0.4
        x = at(x, off, key * rng.uniform(0.7, 1.0))
        off += rng.uniform(0.055, 0.1)
    w("research_start", room(x, 0.2, 0.15, 5000, 42), 0.5)


def focus_start():
    """Karar: kâğıt çevirme + damga."""
    paper = sweep_noise(0.18, 1500, 3500) * np.sin(np.pi * t_(0.18) / 0.18) * 0.5
    stamp = thump(105, 0.18, 0.045, 0.9) + bandpass(noise(0.05), 900, 4500) * dec(0.05, 0.01) * 0.6
    w("focus_start", room(at(paper, 0.2, stamp), 0.25, 0.25, 3500, 43), 0.6)


def trade_deal():
    """Ticaret: telgraf 'dit-dah' + madenî para şıngırtısı."""
    x = np.zeros(1)
    for off, d in ((0.0, 0.05), (0.09, 0.15)):
        x = at(x, off, beep(760, d, 0.5) + tick(0.006, 2000, 6000, 0.001) * 0.4)
    coin = partials([4200, 6100, 7900], [0.4, 0.3, 0.2], [0.12, 0.08, 0.05], 0.3)
    x = at(x, 0.33, coin)
    x = at(x, 0.4, coin * 0.6)
    w("trade_deal", room(x, 0.25, 0.2, 6000, 44), 0.5)


def diplomacy():
    """Diplomasi: kalem gıcırtısı + mühür bası."""
    t = t_(0.45)
    pen = bandpass(noise(0.45), 3000, 7000) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t) ** 2) * np.minimum(t / 0.03, 1) * dec(0.45, 0.3) * 0.35
    seal = thump(85, 0.25, 0.06, 0.7) + partials([380, 820], [0.2, 0.1], [0.05, 0.03], 0.1)
    w("diplomacy", room(at(pen, 0.45, seal), 0.3, 0.25, 3500, 45), 0.55)


def deploy():
    """Konuşlandırma: dört ağır adım + tüfek şakırtısı."""
    x = np.zeros(1)
    for k in range(4):
        x = at(x, k * 0.24, step(0.8 + 0.05 * k))
        x = at(x, k * 0.24 + 0.02, partials([2600, 3900], [0.15, 0.08], [0.02, 0.012], 0.05))
    w("deploy", room(x, 0.3, 0.2, 3500, 46), 0.55)


# ------------------------------------------------------------------ birimler (telsiz)
def select_unit():
    for i in range(1, 4):
        x = radio(squelch(0.07) * 0.8)
        x = at(x, 0.05, chatter(rng.uniform(0.22, 0.34), i))
        x = at(x, 0.05 + 0.34, radio(beep(1150 + 120 * i, 0.04)))
        w(f"select_unit_{i}", x, 0.5)


def order_move():
    for i in range(1, 4):
        x = radio(squelch(0.06) * 0.7)
        x = at(x, 0.04, chatter(rng.uniform(0.25, 0.4), 10 + i))
        x = at(x, 0.46, radio(beep(1000, 0.045)))
        x = at(x, 0.52, radio(beep(1350, 0.045)))
        for k in range(3):
            x = at(x, 0.62 + k * 0.16, step(0.45 + 0.1 * k))
        w(f"order_move_{i}", x, 0.55)


def order_attack():
    for i in range(1, 3):
        x = radio(squelch(0.06) * 0.7)
        x = at(x, 0.04, chatter(rng.uniform(0.25, 0.35), 20 + i) * 1.1)
        t = t_(0.28)
        fw = 2700 + 450 * np.minimum(t / 0.06, 1) + 70 * np.sin(2 * np.pi * 30 * t)
        whistle = np.sin(2 * np.pi * np.cumsum(fw) / SR) * np.minimum(t / 0.01, 1) * np.minimum((0.28 - t) / 0.03, 1)
        x = at(x, 0.45, whistle * 0.35)
        x = at(x, 0.8, whistle[: int(0.16 * SR)] * 0.35)
        x = at(x, 1.0, thump(55, 0.6, 0.2, 0.3) * 0.4)
        w(f"order_attack_{i}", hall(x, 0.6, 0.2, 2500, 21 + i), 0.55)


def select_fleet():
    # 1: gemi çanı iki vuruş; 2: gemi düdüğü
    b = bell(81, 0.7, 1.2, 1.0)
    w("select_fleet_1", hall(at(b, 0.28, b * 0.8), 0.8, 0.3, 3000, 50), 0.5)
    t = t_(1.0)
    horn = sum(np.sin(2 * np.pi * 117 * k * t) / k ** 1.1 for k in range(1, 14))
    horn = lowpass(horn, 1400) * np.minimum(t / 0.08, 1) * np.minimum((1.0 - t) / 0.25, 1)
    w("select_fleet_2", hall(horn * 0.6, 1.2, 0.45, 1500, 51), 0.5)


def select_air():
    for i in range(1, 3):
        d = 0.8
        t = t_(d)
        f = (80 + 45 * i) * (0.6 + 0.4 * np.minimum(t / 0.5, 1))
        ph = 2 * np.pi * np.cumsum(f) / SR
        prop = sum(np.sin(k * ph) * (0.8 ** k) for k in range(1, 9))
        prop = lowpass(prop, 2000) * np.minimum(t / 0.1, 1) * np.minimum((d - t) / 0.25, 1)
        x = mix(radio(squelch(0.06) * 0.6), at(prop * 0.45, 0.05, radio(beep(1250, 0.04))))
        w(f"select_air_{i}", x, 0.5)


# ------------------------------------------------------------------ uyarılar ve olaylar
def soft_note(m, d=1.2, vel=0.6, kind="marimba", tau=0.45):
    """Yumuşak girişli, tizleri alınmış perdeli ses (bildirimler için)."""
    f = 440 * 2 ** ((m - 69) / 12)
    t = t_(d)
    if kind == "marimba":
        ratios, amps, taus = (1.0, 3.93, 9.2), (1.0, 0.25, 0.06), (tau, tau * 0.35, tau * 0.15)
    elif kind == "celesta":
        ratios, amps, taus = (1.0, 2.0, 3.0, 4.1), (1.0, 0.35, 0.12, 0.06), (tau, tau * 0.6, tau * 0.4, tau * 0.3)
    else:  # "warm": bakır benzeri yumuşak akor sesi
        ratios, amps, taus = (1.0, 2.0, 3.0, 4.0, 5.0), (1.0, 0.55, 0.3, 0.15, 0.08), (tau,) * 5
    x = np.zeros_like(t)
    for r, a, tt in zip(ratios, amps, taus):
        x += a * np.sin(2 * np.pi * f * r * t + rng.uniform(0, 6.28)) * np.exp(-t / tt)
    atk = 0.012 if kind != "warm" else 0.09
    x *= np.minimum(t / atk, 1)
    return S(lowpass(x, 3500) * vel)


def alert():
    """1: iyi haber (yükselen büyük üçlü, marimba); 2: kötü haber (alçak, boğuk inen küçük ikili + yumuşak davul)."""
    good = at(soft_note(72, 1.0, 0.5), 0.13, soft_note(76, 1.2, 0.55))
    w("notify_good", room(good, 0.4, 0.3, 3000, 61), 0.4)
    bad = at(soft_note(58, 1.0, 0.55, tau=0.35), 0.16, soft_note(57, 1.3, 0.6, tau=0.45))
    bad = at(bad, 0.0, thump(70, 0.4, 0.12, 0.05) * 0.35)
    w("notify_bad", room(bad, 0.45, 0.3, 2500, 62), 0.42)


def event():
    """Olay: kısık teleks şakırtısı + derin, yumuşak çan."""
    x = np.zeros(1)
    off = 0.0
    while off < 0.3:
        x = at(x, off, lowpass(tick(0.012, 1200, 4000, 0.002), 3500) * rng.uniform(0.2, 0.4))
        off += rng.uniform(0.03, 0.05)
    x = at(x, 0.36, S(lowpass(bell(67, 0.5, 2.2, 0.5), 3000)))
    w("event", hall(x, 0.8, 0.3, 3000, 63), 0.45)


def research_done():
    """Araştırma bitti: yükselen üç notalı çelesta arpeji (Do majör)."""
    x = np.zeros(1)
    for k, m in enumerate((72, 76, 79)):
        x = at(x, k * 0.11, soft_note(m, 1.4, 0.45, "celesta", 0.5))
    w("research_done", hall(x, 0.8, 0.3, 3500, 64), 0.42)


def focus_done():
    """Odak bitti: yumuşak kabaran sıcak bakır beşli (Fa + Do) ve altında kâğıt."""
    x = mix(soft_note(53, 1.6, 0.5, "warm", 0.7), soft_note(60, 1.6, 0.45, "warm", 0.7), soft_note(65, 1.6, 0.3, "warm", 0.7))
    x = at(x, 0.0, lowpass(sweep_noise(0.15, 1200, 2500), 3000) * 0.12)
    w("focus_done", hall(x, 0.9, 0.35, 2500, 65), 0.45)


def production_done():
    """İnşaat bitti: tahta vuruş + alçak marimba beşlisi."""
    knock = lowpass(thump(180, 0.1, 0.02, 0.4), 2500) * 0.6
    x = at(knock, 0.08, soft_note(60, 1.1, 0.45))
    x = at(x, 0.2, soft_note(67, 1.2, 0.4))
    w("production_done", room(x, 0.4, 0.3, 3000, 66), 0.4)


def capitulation():
    """Başka bir büyük gücün teslimi: uzak çan + boğuk davul."""
    x = mix(bell(45, 0.7, 4.0, 0.6), at(np.zeros(1), 0.05, thump(50, 1.2, 0.35, 0.4) * 0.6))
    x = at(x, 1.6, bell(45, 0.5, 4.0, 0.6))
    w("capitulation", hall(x, 1.6, 0.45, 2000, 66), 0.6)


def battle_start():
    for i in range(1, 3):
        x = mix(hall(thump(46, 1.2, 0.5, 0.3), 1.2, 0.6, 900, 70 + i),
                at(np.zeros(1), 0.35 + 0.2 * i, hall(thump(40, 1.4, 0.5, 0.25), 1.2, 0.6, 700, 72 + i) * 0.8))
        w(f"battle_start_{i}", lowpass(x, 1200), 0.6)


# ------------------------------------------------------------------ muharebe (3D, yakın zoom) — önceki tasarım korunur
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
    wind = bandpass(noise(d), 400, 3000)
    amp = np.exp(-((t - d * 0.45) ** 2) / (2 * 0.45 ** 2))
    w("plane_flyby", (x * 0.7 + wind * 0.3) * amp, 0.6)


def naval_gun():
    x = mix(crack(0.06, 200, 2500, 0.016) * 0.7, thump(44, 1.8, 0.5, 1.0))
    w("naval_gun", hall(x, 1.4, 0.55, 900, 84), 0.85)


ALL = (ui_click, ui_hover, ui_open, ui_close, ui_tab, ui_error, ui_confirm, ui_toggle, ui_speed, ui_pause, ui_resume,
       build_queued, production_line, research_start, focus_start, trade_deal, diplomacy, deploy,
       select_unit, order_move, order_attack, select_fleet, select_air,
       alert, event, research_done, focus_done, production_done, capitulation, battle_start,
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
    for fn in ALL:
        fn()
    print(len(list(OUT.glob("*.wav"))), "efekt:", sorted(p.stem for p in OUT.glob("*.wav")))
