#!/usr/bin/env python3
"""
Harita detay dokuları (yakın zoom): döşenebilir albedo + normal, 1024 px.
    python3 tools/make_terrain_textures.py
Çıktı: assets/terrain/<katman>_albedo.png, <katman>_normal.png
Katmanlar (sıra shader'daki dizi indeksidir): farmland, grass, forest, rock, sand, snow, steppe

Tüm gürültüler spektral sentezle (ters FFT) üretilir -> kendiliğinden periyodik, dikişsiz döşenir.
Tarlalar torus üzerinde Voronoi: her parsel ayrı ürün rengi, sürüm izi yönü ve çit sırası.
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

OUT = Path(__file__).resolve().parents[1] / "assets" / "terrain"
N = 1024
LAYERS = ["farmland", "grass", "forest", "rock", "sand", "snow", "steppe"]


def spectral(beta, seed, lo=1.0, hi=None):
    """Periyodik 1/f^beta gürültü, [-1, 1] aralığına normalize."""
    rng = np.random.default_rng(seed)
    fx = np.fft.fftfreq(N)[None, :]
    fy = np.fft.fftfreq(N)[:, None]
    f = np.sqrt(fx * fx + fy * fy) * N
    amp = np.where(f > 0, 1.0 / np.maximum(f, lo) ** beta, 0.0)
    if hi:
        amp *= np.exp(-(f / hi) ** 2)
    phase = rng.uniform(0, 2 * np.pi, (N, N))
    spec = amp * np.exp(1j * phase)
    n = np.real(np.fft.ifft2(spec))
    n -= n.mean()
    return n / (np.abs(n).max() + 1e-9)


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.stack([-dx, -dy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save(name, albedo, height, strength):
    Image.fromarray(np.clip(albedo * 255, 0, 255).astype(np.uint8), "RGB").save(OUT / f"{name}_albedo.png")
    Image.fromarray(normal_from_height(height, strength), "RGB").save(OUT / f"{name}_normal.png")


def colorize(t, stops):
    """t (0..1) -> renk; stops: [(konum, (r,g,b))]"""
    t = np.clip(t, 0, 1)
    out = np.zeros(t.shape + (3,), np.float32)
    for i in range(len(stops) - 1):
        a, ca = stops[i]
        b, cb = stops[i + 1]
        m = (t >= a) & (t <= b)
        k = ((t - a) / max(b - a, 1e-6))[m][:, None]
        out[m] = np.array(ca) * (1 - k) + np.array(cb) * k
    return out


def torus_voronoi(n_cells, seed):
    """Periyodik Voronoi: her pikselin hücre indeksi ve en yakın sınıra uzaklık."""
    rng = np.random.default_rng(seed)
    pts = rng.uniform(0, N, (n_cells, 2))
    # Lloyd benzeri düzenleme için hafif ızgara çekimi
    tiled = np.concatenate([pts + np.array([dx, dy]) * N for dx in (-1, 0, 1) for dy in (-1, 0, 1)])
    ids = np.tile(np.arange(n_cells), 9)
    from scipy.spatial import cKDTree
    tree = cKDTree(tiled)
    yy, xx = np.mgrid[0:N, 0:N]
    q = np.stack([xx.ravel() + 0.5, yy.ravel() + 0.5], 1)
    d, idx = tree.query(q, k=2)
    cell = ids[idx[:, 0]].reshape(N, N)
    edge = (d[:, 1] - d[:, 0]).reshape(N, N) * 0.5
    return cell, edge, rng


def farmland():
    """Avrupa tarla dokusu: özyinelemeli dikdörtgen bölme (uzun şeritler), sınırlarda çit ve ağaç sırası,
    periyodik gürültüyle hafif bükülmüş kenarlar."""
    rng = np.random.default_rng(11)
    rects = []

    def split(x0, y0, x1, y1, depth):
        w, h = x1 - x0, y1 - y0
        if depth > 7 or (w < 150 and h < 150 and rng.random() < 0.6) or min(w, h) < 40:
            rects.append((x0, y0, x1, y1))
            return
        vertical = w > h * rng.uniform(0.7, 1.4)
        t = rng.uniform(0.3, 0.7)
        if vertical:
            m = int(x0 + w * t)
            split(x0, y0, m, y1, depth + 1)
            split(m, y0, x1, y1, depth + 1)
        else:
            m = int(y0 + h * t)
            split(x0, y0, x1, m, depth + 1)
            split(x0, m, x1, y1, depth + 1)

    split(0, 0, N, N, 0)
    # hafif bükülme (periyodik)
    wx = spectral(2.4, 15) * 14
    wy = spectral(2.4, 16) * 14
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    sx = (xx + wx) % N
    sy = (yy + wy) % N
    cell = np.zeros((N, N), np.int32)
    edge = np.full((N, N), 1e9, np.float32)
    for i, (x0, y0, x1, y1) in enumerate(rects):
        m = (sx >= x0) & (sx < x1) & (sy >= y0) & (sy < y1)
        cell[m] = i
        d = np.minimum.reduce([sx - x0, x1 - sx, sy - y0, y1 - sy])
        edge[m] = d[m]
    k = len(rects)
    crops = np.array([
        (0.50, 0.57, 0.25), (0.58, 0.62, 0.29), (0.72, 0.66, 0.38), (0.78, 0.70, 0.44),
        (0.43, 0.52, 0.23), (0.55, 0.45, 0.30), (0.64, 0.58, 0.32), (0.47, 0.56, 0.30), (0.69, 0.62, 0.42),
    ])
    col = crops[rng.integers(0, len(crops), k)][cell]
    col *= (0.93 + 0.14 * rng.random(k))[cell][..., None]
    # sürüm izleri: dikdörtgenin uzun kenarı boyunca
    long_x = np.array([(r[2] - r[0]) > (r[3] - r[1]) for r in rects])[cell]
    freq = rng.uniform(0.9, 1.5, k)[cell]
    rows = np.where(long_x, np.sin(sy * freq), np.sin(sx * freq))
    amp = rng.uniform(0.03, 0.08, k)[cell]
    col *= 1 + rows[..., None] * amp[..., None]
    n = spectral(1.6, 12) * 0.05 + spectral(0.7, 13, hi=320) * 0.03
    col *= 1 + n[..., None]
    # çit (koyu yeşil ince şerit) + düzensiz ağaç kümeleri
    hedge = np.clip(1 - edge / 3.0, 0, 1)
    clumps = np.clip(spectral(1.2, 14, hi=200) * 3.0 - 0.2, 0, 1)
    trees = np.clip(1 - edge / 7.0, 0, 1) * clumps
    col = col * (1 - hedge[..., None] * 0.6) + np.array([0.19, 0.28, 0.12]) * hedge[..., None] * 0.6
    col = col * (1 - trees[..., None] * 0.75) + np.array([0.11, 0.2, 0.08]) * trees[..., None] * 0.75
    h = rows * amp * 3 + n * 2 + trees * 2.0 + hedge * 0.5
    return col, h, 1.4


def grass():
    n1 = spectral(1.8, 21)
    n2 = spectral(0.9, 22, hi=400)
    blades = spectral(0.2, 23, hi=500)
    t = 0.5 + n1 * 0.35 + n2 * 0.15
    col = colorize(t, [(0, (0.25, 0.36, 0.13)), (0.5, (0.36, 0.48, 0.19)), (1, (0.52, 0.56, 0.26))])
    col *= (1 + blades[..., None] * 0.08)
    h = n1 * 0.5 + blades * 0.8
    return col, h, 2.0


def forest():
    """Tepeden orman örtüsü: kümelenen taçlar (eşiklenmiş yüksek frekans gürültü), aralarda koyu boşluk."""
    c1 = spectral(0.9, 31, hi=260)
    c2 = spectral(0.6, 32, hi=480)
    big = spectral(2.0, 33)
    canopy = np.clip(c1 * 1.6 + c2 * 0.6 + 0.35, 0, 1)
    gaps = np.clip((0.25 - canopy) * 4, 0, 1)
    hue = 0.5 + big * 0.4
    col = colorize(hue, [(0, (0.09, 0.18, 0.07)), (0.5, (0.13, 0.25, 0.09)), (1, (0.24, 0.34, 0.12))])
    col *= (0.55 + 0.6 * canopy)[..., None]
    col = col * (1 - gaps[..., None] * 0.5) + np.array([0.06, 0.09, 0.04]) * gaps[..., None] * 0.5
    h = canopy * 3 + big * 0.5
    return col, h, 2.2


def rock():
    base = spectral(2.0, 41)
    mid = spectral(1.2, 42)
    fine = spectral(0.6, 43, hi=500)
    # çatlaklar: sırt gürültüsü
    ridge = 1 - np.abs(spectral(1.5, 44))
    cracks = np.clip((ridge - 0.9) * 10, 0, 1)
    t = 0.5 + base * 0.3 + mid * 0.15
    col = colorize(t, [(0, (0.33, 0.31, 0.29)), (0.5, (0.47, 0.45, 0.42)), (1, (0.62, 0.60, 0.56))])
    col *= (1 + fine[..., None] * 0.1)
    col *= (1 - cracks[..., None] * 0.35)
    h = base * 2 + mid + fine * 0.4 - cracks * 1.5
    return col, h, 3.0


def sand():
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    warp = spectral(2.0, 51) * 40
    ripples = np.sin((xx + yy * 0.35 + warp) * 2 * np.pi / 22.0)
    big = spectral(2.2, 52)
    t = 0.5 + big * 0.35 + ripples * 0.05
    col = colorize(t, [(0, (0.70, 0.58, 0.40)), (0.5, (0.80, 0.68, 0.48)), (1, (0.88, 0.78, 0.58))])
    fine = spectral(0.3, 53, hi=500)
    col *= (1 + fine[..., None] * 0.04)
    h = ripples * 0.6 + big * 2
    return col, h, 1.2


def snow():
    n = spectral(1.9, 61)
    fine = spectral(0.5, 62, hi=400)
    t = 0.5 + n * 0.4
    col = colorize(t, [(0, (0.78, 0.82, 0.88)), (1, (0.96, 0.97, 0.99))])
    col *= (1 + fine[..., None] * 0.03)
    return col, n * 2 + fine * 0.3, 1.0


def steppe():
    n1 = spectral(1.7, 71)
    tufts = np.clip(spectral(0.6, 72, hi=350) * 2 - 0.3, 0, 1)
    t = 0.5 + n1 * 0.35
    col = colorize(t, [(0, (0.52, 0.50, 0.30)), (0.5, (0.62, 0.58, 0.36)), (1, (0.70, 0.64, 0.42))])
    col = col * (1 - tufts[..., None] * 0.3) + np.array([0.36, 0.40, 0.20]) * tufts[..., None] * 0.3
    h = n1 + tufts * 1.2
    return col, h, 1.6


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name in LAYERS:
        col, h, strength = globals()[name]()
        save(name, col, h, strength)
        print("doku:", name, f"ort. renk {np.round(col.reshape(-1, 3).mean(0), 3)}")


main()
