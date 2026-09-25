#!/usr/bin/env python3
"""
Asset dokuları (döşenebilir, 512px): cepheler, çatılar, taş, tuğla, zemin.
    python3 tools/blender/make_textures.py
Her cephe dokusu 3 pencere sütunu x 2 kat = TILE_W x TILE_H dünya birimi kaplar (build_assets.py ile eşleşir).
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[2] / "assets" / "models" / "textures"
S = 512
RNG = np.random.default_rng(1936)


def noise(scale, amp, seed):
    rng = np.random.default_rng(seed)
    small = rng.standard_normal((S // scale + 2, S // scale + 2))
    img = Image.fromarray(((small - small.min()) / (np.ptp(small) + 1e-9) * 255).astype(np.uint8))
    img = img.resize((S + 2 * scale, S + 2 * scale), Image.BICUBIC).crop((scale, scale, S + scale, S + scale))
    a = np.asarray(img, np.float32) / 255.0 - 0.5
    return a * amp


def tileable(a):
    """Kenarları sarmalı karıştırarak döşenebilir yap."""
    b = np.roll(a, (S // 2, S // 2), (0, 1))
    y, x = np.mgrid[0:S, 0:S]
    w = np.minimum(np.minimum(x, S - 1 - x), np.minimum(y, S - 1 - y)) / (S / 2)
    w = np.clip(w * 2.5, 0, 1)
    if a.ndim == 3:
        w = w[..., None]
    return a * w + b * (1 - w)


def base(color, grain=0.05, stains=0.08, seed=0):
    c = np.array(color, np.float32)[None, None, :] / 255.0
    n = noise(4, grain, seed) + noise(32, stains, seed + 1) + noise(96, stains * 0.8, seed + 2)
    img = c * (1.0 + n[..., None])
    return tileable(img)


def save(name, img, strength=2.5):
    arr = np.clip(img * 255, 0, 255).astype(np.uint8)
    Image.fromarray(arr, "RGB").save(OUT / f"{name}.png")
    # normal map: parlaklıktan yükseklik (koyu = gömük: pencere camı, harç; açık = kabarık: çerçeve, korniş)
    lum = arr.astype(np.float32).mean(-1) / 255.0
    h = np.asarray(Image.fromarray((lum * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255.0
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.stack([-dx, dy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB").save(OUT / f"{name}_n.png")


def facade(name, wall, window_style="tall", shutters=None, seed=0, frame=(0.92, 0.90, 0.85)):
    img = base(wall, seed=seed)
    im = Image.fromarray(np.clip(img * 255, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    cols, floors = 3, 2
    cw, fh = S // cols, S // floors
    wall_dark = tuple(int(v * 0.72) for v in wall)
    for f in range(floors):
        # kat silmesi (korniş şeridi)
        y0 = f * fh
        d.rectangle([0, y0 + fh - 10, S, y0 + fh - 4], fill=tuple(min(255, int(v * 1.08)) for v in wall))
        d.line([0, y0 + fh - 3, S, y0 + fh - 3], fill=wall_dark, width=2)
        for c in range(cols):
            x0 = c * cw
            ww, wh = (cw * 0.42, fh * 0.56) if window_style == "tall" else (cw * 0.5, fh * 0.42)
            wx0 = x0 + (cw - ww) / 2
            wy0 = y0 + fh * 0.18
            fr = tuple(int(v * 255) for v in frame)
            # pencere gölgesi + çerçeve + cam + kayıtlar
            d.rectangle([wx0 - 6, wy0 - 6, wx0 + ww + 6, wy0 + wh + 10], fill=wall_dark)
            d.rectangle([wx0 - 4, wy0 - 4, wx0 + ww + 4, wy0 + wh + 4], fill=fr)
            glass_top = (48, 62, 78)
            glass_bot = (22, 28, 36)
            for yy in range(int(wy0), int(wy0 + wh)):
                t = (yy - wy0) / wh
                g = tuple(int(glass_top[i] * (1 - t) + glass_bot[i] * t) for i in range(3))
                d.line([wx0, yy, wx0 + ww, yy], fill=g)
            d.line([wx0 + ww / 2, wy0, wx0 + ww / 2, wy0 + wh], fill=fr, width=4)
            d.line([wx0, wy0 + wh * 0.38, wx0 + ww, wy0 + wh * 0.38], fill=fr, width=4)
            # cam yansıması
            d.polygon([(wx0 + 4, wy0 + 4), (wx0 + ww * 0.35, wy0 + 4), (wx0 + 4, wy0 + wh * 0.3)], fill=(90, 108, 126))
            # pencere denizliği ve lento
            d.rectangle([wx0 - 10, wy0 + wh + 4, wx0 + ww + 10, wy0 + wh + 12], fill=tuple(min(255, int(v * 1.12)) for v in wall))
            d.rectangle([wx0 - 8, wy0 - 16, wx0 + ww + 8, wy0 - 8], fill=tuple(min(255, int(v * 1.1)) for v in wall))
            if shutters:
                sc = shutters
                d.rectangle([wx0 - 4 - ww * 0.45, wy0 - 2, wx0 - 6, wy0 + wh + 2], fill=sc)
                d.rectangle([wx0 + ww + 6, wy0 - 2, wx0 + ww + 4 + ww * 0.45, wy0 + wh + 2], fill=sc)
                for k in range(1, 8):
                    yy = wy0 + wh * k / 8
                    dk = tuple(int(v * 0.75) for v in sc)
                    d.line([wx0 - 4 - ww * 0.45, yy, wx0 - 6, yy], fill=dk, width=2)
                    d.line([wx0 + ww + 6, yy, wx0 + ww + 4 + ww * 0.45, yy], fill=dk, width=2)
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    arr = np.asarray(im, np.float32) / 255.0
    # hafif kir akıntısı (dikey lekeler)
    streak = np.clip(noise(8, 1.0, seed + 5), -0.5, 0.5)
    streak = np.asarray(Image.fromarray(((streak + 0.5) * 255).astype(np.uint8)).resize((S, S)).filter(ImageFilter.BoxBlur(1)), np.float32) / 255.0
    ys = np.linspace(0, 1, S)[:, None]
    arr *= (1.0 - 0.06 * np.clip(streak - 0.55, 0, 1) * 4 * ys)[..., None]
    save(name, arr)


def bricks(name, color, mortar=(170, 160, 145), seed=0, bw=64, bh=24):
    img = base(color, 0.06, 0.06, seed)
    rng = np.random.default_rng(seed)
    out = img.copy()
    m = np.array(mortar, np.float32) / 255.0
    for row in range(S // bh):
        off = (bw // 2) * (row % 2)
        y0 = row * bh
        out[y0:y0 + 3, :, :] = m
        for x in range(-bw, S, bw):
            xx = (x + off) % S
            out[y0:y0 + bh, xx:xx + 3, :] = m
            v = 1.0 + rng.uniform(-0.12, 0.12)
            x1 = min(xx + bw, S)
            out[y0 + 3:y0 + bh, xx + 3:x1, :] *= v
    save(name, out)


def stone_blocks(name, color, seed=0):
    bricks(name, color, mortar=tuple(int(c * 0.7) for c in color), seed=seed, bw=128, bh=48)


def roof_tiles(name, color, seed=0, rows=16, scallop=True):
    img = base(color, 0.06, 0.1, seed)
    rng = np.random.default_rng(seed)
    rh = S // rows
    y, x = np.mgrid[0:S, 0:S]
    shade = np.ones((S, S), np.float32)
    for r in range(rows):
        band = (y >= r * rh) & (y < (r + 1) * rh)
        t = (y - r * rh) / rh
        shade[band] = (0.72 + 0.4 * t)[band]
        if scallop:
            off = (r % 2) * 16
            ripple = 0.08 * np.cos((x + off) / 32.0 * 2 * np.pi)
            shade[band] += ripple[band]
        shade[band] *= 1.0 + rng.uniform(-0.05, 0.05)
    save(name, img * shade[..., None])


def planks(name, color, seed=0):
    img = base(color, 0.04, 0.06, seed)
    x = np.arange(S)
    seam = ((x % 43) < 3).astype(np.float32)
    grain = noise(2, 0.08, seed + 3)
    img = img * (1 - 0.35 * seam[None, :, None]) * (1 + grain[..., None])
    # pencereler (ahşap evler için)
    im = Image.fromarray(np.clip(img * 255, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    for f in range(2):
        for c in range(3):
            cw, fh = S // 3, S // 2
            wx0, wy0 = c * cw + cw * 0.3, f * fh + fh * 0.25
            ww, wh = cw * 0.4, fh * 0.45
            d.rectangle([wx0 - 6, wy0 - 6, wx0 + ww + 6, wy0 + wh + 6], fill=(236, 232, 222))
            d.rectangle([wx0, wy0, wx0 + ww, wy0 + wh], fill=(30, 38, 48))
            d.line([wx0 + ww / 2, wy0, wx0 + ww / 2, wy0 + wh], fill=(236, 232, 222), width=4)
    save(name, np.asarray(im, np.float32) / 255.0)


def cobble(name, color, seed=0):
    img = base(color, 0.1, 0.08, seed)
    rng = np.random.default_rng(seed)
    im = Image.fromarray(np.clip(img * 255, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    for _ in range(900):
        cx, cy = rng.uniform(0, S, 2)
        r = rng.uniform(7, 13)
        v = rng.uniform(0.85, 1.12)
        c = tuple(int(min(255, cc * v)) for cc in color)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=c, outline=tuple(int(cc * 0.6) for cc in color))
    save(name, tileable(np.asarray(im, np.float32) / 255.0))


def flat(name, color, seed=0, grain=0.05):
    save(name, base(color, grain, 0.1, seed))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    facade("facade_cream", (214, 196, 160), shutters=None, seed=1)
    facade("facade_white", (222, 216, 202), shutters=(70, 96, 72), seed=2)
    facade("facade_ochre", (200, 150, 92), shutters=(110, 70, 50), seed=3)
    facade("facade_grey", (160, 158, 150), seed=4)
    facade("facade_pink", (206, 160, 150), seed=5, frame=(0.95, 0.93, 0.88))
    facade("facade_yellow", (222, 190, 110), seed=6, frame=(0.96, 0.95, 0.9))
    facade("facade_beige_flat", (214, 190, 150), window_style="square", seed=7)
    facade("facade_whitewash", (232, 226, 214), window_style="square", shutters=(60, 110, 140), seed=8)
    bricks("brick_red", (140, 62, 44), seed=9)
    bricks("brick_dark", (104, 52, 42), seed=10)
    stone_blocks("stone_light", (190, 184, 168), seed=11)
    stone_blocks("stone_sand", (206, 182, 140), seed=12)
    roof_tiles("roof_terracotta", (168, 72, 42), seed=13)
    roof_tiles("roof_slate", (62, 68, 78), seed=14, rows=22, scallop=False)
    roof_tiles("roof_copper", (78, 140, 118), seed=15, rows=10, scallop=False)
    roof_tiles("roof_dark", (80, 60, 50), seed=16, rows=18, scallop=False)
    planks("wood_red", (140, 40, 32), seed=17)
    planks("wood_yellow", (206, 170, 80), seed=18)
    planks("wood_white", (220, 216, 204), seed=19)
    cobble("ground_cobble", (128, 120, 108), seed=20)
    flat("ground_dirt", (122, 104, 72), seed=21, grain=0.08)
    flat("concrete", (150, 148, 142), seed=22)
    flat("asphalt", (48, 50, 52), seed=23, grain=0.1)
    flat("grass", (74, 102, 44), seed=24, grain=0.12)
    print("dokular:", len(list(OUT.glob("*.png"))))


main()
