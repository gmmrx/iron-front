#!/usr/bin/env python3
"""
Sanayi ve askerî tesis dokuları (döşenebilir, 512 px; make_textures.py ile aynı biçim: <ad>.png + <ad>_n.png).
    python3 tools/blender/make_industry_textures.py
build_industry.py bu dokuları kullanır. Her doku kendi dünya ölçeğiyle eşlenir (build_industry.py → UV).
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from make_textures import OUT, S, base, noise, save, tileable


def _img(arr):
    return Image.fromarray(np.clip(arr * 255, 0, 255).astype(np.uint8))


def _arr(im):
    return np.asarray(im, np.float32) / 255.0


def _grime(arr, seed, amount=0.10, vertical=True):
    """Kir akıntısı ve lekeler: yukarıdan aşağı koyulaşan dikey izler."""
    streak = noise(6, 1.0, seed) + noise(40, 0.6, seed + 1)
    streak = (streak - streak.min()) / (np.ptp(streak) + 1e-9)
    if vertical:
        streak = np.asarray(_img(np.repeat(streak[..., None], 3, -1)).resize((S // 8, S)).resize((S, S)), np.float32)[..., 0] / 255.0
    ys = np.linspace(0.3, 1.0, S)[:, None]
    return arr * (1.0 - amount * np.clip(streak - 0.4, 0, 1) * 2.0 * ys)[..., None]


def industrial_brick(name, color, seed=0):
    """Sanayi cephesi: tuğla duvar, iki yüksek kemerli çelik pencere, aralarında plaster; altta koyu taban şeridi."""
    arr = base(color, 0.06, 0.07, seed)
    rng = np.random.default_rng(seed)
    bh, bw = 12, 32
    mortar = np.array([0.62, 0.58, 0.52], np.float32)
    for row in range(S // bh):
        y0 = row * bh
        arr[y0:y0 + 2] = arr[y0:y0 + 2] * 0.35 + mortar * 0.65
        off = (bw // 2) * (row % 2)
        for x in range(-bw, S, bw):
            xx = (x + off) % S
            arr[y0:y0 + bh, xx:xx + 2] = arr[y0:y0 + bh, xx:xx + 2] * 0.35 + mortar * 0.65
            arr[y0 + 2:y0 + bh, xx + 2:min(xx + bw, S)] *= 1.0 + rng.uniform(-0.1, 0.1)
    im = _img(arr)
    d = ImageDraw.Draw(im)
    dark = tuple(int(c * 0.55) for c in color)
    light = tuple(min(255, int(c * 1.18)) for c in color)
    cw = S // 2
    for c in range(2):
        x0 = c * cw
        # plaster (duvar payandası) sütun kenarlarında
        d.rectangle([x0, 0, x0 + 18, S], fill=light)
        d.line([x0 + 18, 0, x0 + 18, S], fill=dark, width=3)
        ww, wh = cw * 0.52, S * 0.62
        wx0 = x0 + (cw - ww) / 2 + 9
        wy0 = S * 0.16
        # kemer lentosu
        d.pieslice([wx0 - 10, wy0 - ww * 0.28, wx0 + ww + 10, wy0 + ww * 0.28], 180, 360, fill=light)
        d.rectangle([wx0 - 6, wy0, wx0 + ww + 6, wy0 + wh + 6], fill=dark)
        d.pieslice([wx0, wy0 - ww * 0.2, wx0 + ww, wy0 + ww * 0.2], 180, 360, fill=(40, 48, 56))
        for yy in range(int(wy0), int(wy0 + wh)):
            t = (yy - wy0) / wh
            g = (int(58 - 30 * t), int(70 - 34 * t), int(82 - 38 * t))
            d.line([wx0, yy, wx0 + ww, yy], fill=g)
        # çelik kayıt ızgarası (küçük camlar)
        for k in range(1, 6):
            d.line([wx0 + ww * k / 6, wy0 - ww * 0.15, wx0 + ww * k / 6, wy0 + wh], fill=(34, 36, 38), width=3)
        for k in range(1, 9):
            d.line([wx0, wy0 + wh * k / 9, wx0 + ww, wy0 + wh * k / 9], fill=(34, 36, 38), width=3)
        # kırık/açık camlar ve yansıma
        for _ in range(3):
            i, j = rng.integers(0, 6), rng.integers(0, 9)
            d.rectangle([wx0 + ww * i / 6 + 2, wy0 + wh * j / 9 + 2, wx0 + ww * (i + 1) / 6 - 2, wy0 + wh * (j + 1) / 9 - 2], fill=(90, 104, 116))
        d.rectangle([wx0 - 12, wy0 + wh + 4, wx0 + ww + 12, wy0 + wh + 14], fill=(170, 164, 150))
    # taban şeridi (koyu tuğla + beton)
    d.rectangle([0, S - 40, S, S], fill=tuple(int(c * 0.62) for c in color))
    d.rectangle([0, S - 44, S, S - 40], fill=(150, 146, 136))
    arr = _grime(_arr(im.filter(ImageFilter.GaussianBlur(0.5))), seed + 7, 0.14)
    save(name, arr, strength=3.0)


def corrugated(name, color, seed=0, rust=0.0):
    """Oluklu sac: dikey oluklar (ışık-gölge), birleşim çizgileri, pas ve kir akıntısı."""
    arr = base(color, 0.03, 0.05, seed)
    x = np.arange(S)
    ribs = 0.5 + 0.5 * np.cos(x / S * 2 * np.pi * 24)
    arr = arr * (0.78 + 0.32 * ribs)[None, :, None]
    # yatay levha birleşimi
    for y0 in (S // 2 - 3,):
        arr[y0:y0 + 4] *= 0.7
    if rust > 0:
        r = noise(16, 1.0, seed + 3) + noise(3, 0.5, seed + 4)
        r = np.clip((r - 0.1) * 3.0, 0, 1) * rust
        rust_c = np.array([0.45, 0.24, 0.12], np.float32)
        arr = arr * (1 - r[..., None]) + rust_c * r[..., None]
    arr = _grime(arr, seed + 9, 0.18)
    save(name, tileable(arr), strength=4.0)


def skylight(name, seed=0):
    """Çatı ışıklığı: çelik kayıtlı, kirli cam paneller; güneşte parlayan birkaç cam."""
    rng = np.random.default_rng(seed)
    arr = np.zeros((S, S, 3), np.float32)
    im = _img(arr)
    d = ImageDraw.Draw(im)
    n = 8
    for i in range(n):
        for j in range(n):
            x0, y0 = i * S / n, j * S / n
            v = rng.uniform(0.8, 1.25)
            g = (int(70 * v), int(88 * v), int(100 * v))
            d.rectangle([x0, y0, x0 + S / n, y0 + S / n], fill=g)
            d.polygon([(x0 + 4, y0 + 4), (x0 + S / n * 0.5, y0 + 4), (x0 + 4, y0 + S / n * 0.45)],
                      fill=(int(g[0] * 1.5), int(g[1] * 1.45), int(g[2] * 1.4)))
    for k in range(n + 1):
        d.line([k * S / n, 0, k * S / n, S], fill=(46, 48, 50), width=6)
        d.line([0, k * S / n, S, k * S / n], fill=(46, 48, 50), width=4)
    arr = _grime(_arr(im), seed + 2, 0.2)
    save(name, arr, strength=2.0)


def yard(name, color, seed=0, joints=4, stains=True):
    """Beton avlu: derz çizgileri, yağ lekeleri, lastik izleri."""
    arr = base(color, 0.05, 0.1, seed)
    rng = np.random.default_rng(seed)
    step = S // joints
    for k in range(joints):
        arr[k * step:k * step + 2] *= 0.72
        arr[:, k * step:k * step + 2] *= 0.72
    if stains:
        im = _img(arr)
        d = ImageDraw.Draw(im)
        for _ in range(14):
            cx, cy = rng.uniform(0, S, 2)
            r = rng.uniform(8, 40)
            v = rng.uniform(0.55, 0.8)
            c = tuple(int(cc * v) for cc in color)
            d.ellipse([cx - r, cy - r * 0.7, cx + r, cy + r * 0.7], fill=c)
        arr = _arr(im.filter(ImageFilter.GaussianBlur(5)))
    save(name, tileable(arr), strength=1.5)


def gravel(name, color, seed=0):
    arr = base(color, 0.22, 0.08, seed)
    rng = np.random.default_rng(seed)
    im = _img(arr)
    d = ImageDraw.Draw(im)
    for _ in range(2600):
        cx, cy = rng.uniform(0, S, 2)
        r = rng.uniform(1.5, 4.5)
        v = rng.uniform(0.7, 1.3)
        c = tuple(int(min(255, cc * v)) for cc in color)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=c)
    save(name, tileable(_arr(im)), strength=3.0)


def sandbag(name, color, seed=0):
    """Kum torbası duvarı: şaşırtmalı sıralar, yuvarlak kenarlar, bağ izleri."""
    arr = base(color, 0.08, 0.06, seed)
    rows, cols = 8, 4
    rh, cw = S // rows, S // cols
    y, x = np.mgrid[0:S, 0:S]
    shade = np.ones((S, S), np.float32)
    for r in range(rows):
        off = (cw // 2) * (r % 2)
        band = (y >= r * rh) & (y < (r + 1) * rh)
        ty = (y - r * rh) / rh
        tx = ((x + off) % cw) / cw
        bump = np.sin(np.clip(ty, 0, 1) * np.pi) ** 0.6 * np.sin(np.clip(tx, 0, 1) * np.pi) ** 0.35
        shade[band] = (0.55 + 0.55 * bump)[band]
    save(name, arr * shade[..., None], strength=5.0)


def timber(name, color, seed=0):
    arr = base(color, 0.04, 0.06, seed)
    y = np.arange(S)
    seam = ((y % 64) < 3).astype(np.float32)
    grain = noise(2, 0.1, seed + 3)
    grain = np.asarray(_img(np.repeat(((grain + 0.5))[..., None], 3, -1)).resize((S * 4, S // 4)).resize((S, S)), np.float32)[..., 0] / 255.0 - 0.5
    arr = arr * (1 - 0.35 * seam[:, None, None]) * (1 + 0.25 * grain[..., None])
    save(name, tileable(arr), strength=2.5)


def camo(name, colors, seed=0):
    """Kamuflaj boyası: büyük yumuşak lekeler (üç renk), boya aşınması."""
    rng = np.random.default_rng(seed)
    a = noise(64, 1.0, seed) + noise(24, 0.4, seed + 1)
    b = noise(64, 1.0, seed + 5) + noise(24, 0.4, seed + 6)
    c0, c1, c2 = [np.array(c, np.float32) / 255.0 for c in colors]
    m1 = (a > 0.08).astype(np.float32)
    m2 = (b > 0.12).astype(np.float32)
    arr = c0 * (1 - m1[..., None]) + c1 * m1[..., None]
    arr = arr * (1 - m2[..., None]) + c2 * m2[..., None]
    arr *= (1 + noise(3, 0.1, seed + 9))[..., None]
    arr = np.asarray(_img(arr).filter(ImageFilter.GaussianBlur(1.5)), np.float32) / 255.0
    save(name, tileable(_grime(arr, seed + 3, 0.1)), strength=1.2)


def steel_panel(name, color, seed=0, rivet_step=32):
    """Perçinli çelik levhalar: levha sınırları, perçin sıraları, pas akıntısı."""
    arr = base(color, 0.04, 0.08, seed)
    step = S // 4
    for k in range(4):
        arr[k * step:k * step + 3] *= 0.6
        arr[:, k * step:k * step + 3] *= 0.6
    im = _img(arr)
    d = ImageDraw.Draw(im)
    hi = tuple(min(255, int(c * 1.35)) for c in color)
    for k in range(4):
        for t in range(0, S, rivet_step // 2):
            for (px, py) in [(k * step + 9, t), (t, k * step + 9)]:
                d.ellipse([px - 3, py - 3, px + 3, py + 3], fill=hi)
    arr = _arr(im)
    r = np.clip((noise(12, 1.0, seed + 4) - 0.2) * 2.5, 0, 1) * 0.35
    arr = arr * (1 - r[..., None]) + np.array([0.42, 0.22, 0.1], np.float32) * r[..., None]
    save(name, tileable(_grime(arr, seed + 6, 0.2)), strength=3.0)


def tank_paint(name, color, seed=0):
    """Depo tankı boyası: yatay kaynak dikişleri, dikey kir akıntısı, alt kısımda pas."""
    arr = base(color, 0.03, 0.05, seed)
    for y0 in range(0, S, S // 4):
        arr[y0:y0 + 3] *= 0.78
    for x0 in range(0, S, S // 3):
        arr[:, x0:x0 + 2] *= 0.85
    arr = _grime(arr, seed + 2, 0.22)
    ys = np.linspace(0, 1, S)[:, None]
    r = np.clip((noise(8, 1.0, seed + 8) + ys * 1.2 - 0.9) * 2.0, 0, 1) * 0.5
    arr = arr * (1 - r[..., None]) + np.array([0.45, 0.28, 0.16], np.float32) * r[..., None]
    save(name, tileable(arr), strength=1.5)


def office_facade(name, wall, seed=0):
    """Fabrika idare binası: sade sıva, düzenli dikdörtgen pencereler (3 sütun × 2 kat)."""
    arr = base(wall, 0.04, 0.06, seed)
    im = _img(arr)
    d = ImageDraw.Draw(im)
    cw, fh = S // 3, S // 2
    for f in range(2):
        d.rectangle([0, f * fh + fh - 8, S, f * fh + fh - 2], fill=tuple(int(c * 0.8) for c in wall))
        for c in range(3):
            wx0, wy0 = c * cw + cw * 0.22, f * fh + fh * 0.2
            ww, wh = cw * 0.56, fh * 0.52
            d.rectangle([wx0 - 5, wy0 - 5, wx0 + ww + 5, wy0 + wh + 8], fill=tuple(int(cc * 0.7) for cc in wall))
            d.rectangle([wx0, wy0, wx0 + ww, wy0 + wh], fill=(38, 48, 58))
            for k in range(1, 4):
                d.line([wx0 + ww * k / 4, wy0, wx0 + ww * k / 4, wy0 + wh], fill=(210, 206, 196), width=3)
            d.line([wx0, wy0 + wh * 0.35, wx0 + ww, wy0 + wh * 0.35], fill=(210, 206, 196), width=3)
    save(name, _grime(_arr(im.filter(ImageFilter.GaussianBlur(0.5))), seed + 3, 0.1), strength=2.5)


def paving(name, color, seed=0):
    """Kent zemini: koyu parke taşı + küçük taş döşeme, lekeler (şehrin tabanı parlamasın)."""
    arr = base(color, 0.1, 0.12, seed)
    rng = np.random.default_rng(seed)
    im = _img(arr)
    d = ImageDraw.Draw(im)
    step = 16
    for y in range(0, S, step):
        off = (step // 2) * ((y // step) % 2)
        for x in range(-step, S, step):
            v = rng.uniform(0.8, 1.15)
            c = tuple(int(min(255, cc * v)) for cc in color)
            d.rectangle([x + off + 1, y + 1, x + off + step - 2, y + step - 2], fill=c)
    arr = _arr(im.filter(ImageFilter.GaussianBlur(0.8)))
    arr *= (1 + noise(48, 0.25, seed + 3))[..., None]
    save(name, tileable(arr), strength=2.0)


def garden(name, seed=0):
    """Avlu ve bahçe: çimen, toprak yollar, çalı lekeleri."""
    arr = base((70, 96, 46), 0.14, 0.14, seed)
    rng = np.random.default_rng(seed)
    im = _img(arr)
    d = ImageDraw.Draw(im)
    for _ in range(40):
        cx, cy = rng.uniform(0, S, 2)
        r = rng.uniform(6, 22)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(int(rng.uniform(40, 60)), int(rng.uniform(66, 86)), 34))
    save(name, tileable(_arr(im.filter(ImageFilter.GaussianBlur(1.2)))), strength=2.0)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    industrial_brick("ind_brick", (132, 64, 46), seed=101)
    industrial_brick("ind_brick_yellow", (176, 142, 98), seed=102)
    corrugated("corrugated", (118, 124, 128), seed=103, rust=0.25)
    corrugated("corrugated_dark", (72, 78, 80), seed=104, rust=0.15)
    corrugated("corrugated_red", (128, 56, 40), seed=105, rust=0.1)
    skylight("skylight", seed=106)
    yard("yard_concrete", (140, 138, 132), seed=107)
    yard("yard_asphalt", (64, 64, 62), seed=108, joints=2)
    gravel("gravel", (116, 108, 96), seed=109)
    gravel("ballast", (92, 86, 80), seed=110)
    sandbag("sandbag", (150, 132, 96), seed=111)
    timber("timber", (150, 116, 74), seed=112)
    camo("camo", [(92, 98, 64), (64, 72, 46), (120, 106, 74)], seed=113)
    steel_panel("steel_panel", (84, 90, 94), seed=114)
    steel_panel("crane_paint", (196, 150, 52), seed=115)
    tank_paint("tank_white", (196, 194, 184), seed=116)
    tank_paint("tank_grey", (130, 134, 136), seed=117)
    office_facade("office_cream", (206, 192, 162), seed=118)
    paving("city_paving", (104, 98, 90), seed=119)
    paving("city_paving_warm", (128, 112, 90), seed=120)
    garden("garden", seed=121)
    print("sanayi dokuları hazır:", OUT)


if __name__ == "__main__":
    main()
