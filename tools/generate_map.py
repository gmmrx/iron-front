#!/usr/bin/env python3
"""
Harita üretim hattı.

Girdi : Natural Earth idari bölgeleri (admin-1, 10m) + hipsometrik kabartma raster'ı
Çıktı : data/map/ altında
    provinces.png   RGB, province id = R + G*256 (0 = harita dışı)
    terrain.png     RGB, arazi + stilize deniz
    borders.png     RGB, sınır mesafe alanları (R=province, G=state, B=kıyı), 1/8 texel birimi
    provinces.json  bölge listesi (tip, arazi, eyalet, merkez, komşular)
    states.json     eyalet listesi (sahip, bölgeler, nüfus, merkez)
    definition.csv  klasik strateji tarzı id;r;g;b;tip;kıyı;arazi

Projeksiyon: Lambert azimutal eşit-alan (merkez 25°D, 50°K) -> her piksel aynı alana sahip.
Çalıştırma: python3 tools/generate_map.py
"""
import csv
import os
import re
import json
import math
import time
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.cluster.vq import kmeans2
from scipy.spatial import cKDTree

Image.MAX_IMAGE_PIXELS = None

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / "cache"
OUT = Path(os.environ["MAP_OUT"]) if os.environ.get("MAP_OUT") else ROOT / "data" / "map"
COUNTRIES = ROOT / "data" / "common" / "countries.json"

# ---------------------------------------------------------------- projeksiyon (tüm dünya, Miller silindirik — türün klasiklerindeki gibi)
R_EARTH = 6371.0
W = int(os.environ.get("MAP_W", 16384))
LON_MIN = -168.5                     # dikiş: Bering Boğazı (Çukotka sağda, Alaska solda)
LAT_TOP, LAT_BOT = 83.7, -57.0       # Grönland kuzeyi .. Horn Burnu (Antarktika yok)
PX_PER_RAD = W / (2.0 * math.pi)


def miller_y(phi):
    return 1.25 * np.log(np.tan(np.pi / 4.0 + 0.4 * phi))


Y_TOP = float(miller_y(math.radians(LAT_TOP)))
Y_BOT = float(miller_y(math.radians(LAT_BOT)))
H = int(round((Y_TOP - Y_BOT) * PX_PER_RAD))
KM_PER_PX = 2.0 * math.pi * R_EARTH / W          # ekvatorda (nominal)


def _row_lat(py):
    y = Y_TOP - np.asarray(py, dtype=np.float64) / PX_PER_RAD
    return np.degrees(2.5 * np.arctan(np.exp(0.8 * y)) - 0.625 * np.pi)


# satır başına piksel alanı (km²) ve yatay/dikey piksel boyu (km): Miller alan korumaz
_edges = np.radians(_row_lat(np.arange(H + 1)))
ROW_AREA = (R_EARTH ** 2 * (2.0 * math.pi / W) * np.abs(np.sin(_edges[:-1]) - np.sin(_edges[1:]))).astype(np.float32)
ROW_LAT = _row_lat(np.arange(H) + 0.5).astype(np.float32)
ROW_KX = (KM_PER_PX * np.cos(np.radians(ROW_LAT))).astype(np.float32)
ROW_KY = (ROW_AREA / ROW_KX).astype(np.float32)
PX_AREA = float(ROW_AREA.mean())                  # yalnız kaba tahminler için
del _edges

# ---------------------------------------------------------------- ayarlar
# Bölge yoğunluğu (türün klasiklerindeki gibi): Avrupa ayrıntılı, uzak bölgeler büyük. (boylam0, enlem0, boylam1, enlem1, çarpan)
THEATERS = [
    (-12, 34, 45, 72, 1.0),       # Avrupa çekirdeği
    (-20, 20, 62, 75, 1.5),       # Kuzey Afrika, Orta Doğu, Batı SSCB
    (95, 18, 146, 50, 2.0),       # Doğu Asya
    (66, 5, 95, 37, 2.5),         # Hindistan
    (-100, 24, -65, 50, 2.5),     # ABD doğusu
    (-125, 24, -100, 50, 3.5),    # ABD batısı
    (90, -12, 155, 18, 3.0),      # Güneydoğu Asya
]
THEATER_DEFAULT = 5.0


def theater(lon, lat):
    """Boylam/enlem (skaler ya da dizi) -> bölge boyutu çarpanı."""
    lon = np.asarray(lon, dtype=np.float64)
    lat = np.asarray(lat, dtype=np.float64)
    f = np.full(np.broadcast(lon, lat).shape, THEATER_DEFAULT)
    done = np.zeros(f.shape, bool)
    for x0, y0, x1, y1, k in THEATERS:
        m = ~done & (lon >= x0) & (lon <= x1) & (lat >= y0) & (lat <= y1)
        f[m] = k
        done |= m
    return f


MIN_STATE_KM2 = 11000      # bundan küçük idari bölgeler komşularıyla birleşir
TINY_STATE_KM2 = 250       # komşusuz ve bundan küçükse en yakın eyalete katılır
MAX_STATE_KM2 = 55000      # bundan büyük eyaletler bölünür (yerleşik alanlar)
MAX_STATE_REMOTE_KM2 = 140000
PROVINCE_KM2 = 3000        # ideal kara bölgesi alanı (verimli arazi)
SEA_PROVINCE_KM2 = 22000
MIN_ISLAND_PROVINCE_PX = 60
SEED = 1936

# 1936 sahipliği: modern ülke kodu -> etiket
ADM0_OWNER = {
    "DEU": "GER", "AUT": "AUS", "LIE": "SWI", "CHE": "SWI",
    "GBR": "ENG", "IMN": "ENG", "GGY": "ENG", "JEY": "ENG", "GIB": "ENG", "MLT": "ENG",
    "CYP": "ENG", "CYN": "ENG", "ESB": "ENG", "WSB": "ENG",
    "EGY": "ENG", "SDN": "ENG", "ISR": "ENG", "PSX": "ENG", "JOR": "ENG", "KWT": "ENG",
    "QAT": "ENG", "ARE": "ENG", "BHR": "ENG",
    "IRL": "IRE", "ISL": "ICE",
    "FRA": "FRA", "MCO": "FRA", "DZA": "FRA", "TUN": "FRA", "MAR": "FRA", "SYR": "FRA", "LBN": "FRA",
    "MRT": "FRA", "MLI": "FRA", "NER": "FRA", "TCD": "FRA",
    "ITA": "ITA", "SMR": "ITA", "VAT": "ITA", "LBY": "ITA",
    "ESP": "SPR", "AND": "SPR", "SAH": "SPR",
    "PRT": "POR",
    "RUS": "SOV", "UKR": "SOV", "BLR": "SOV", "GEO": "SOV", "ARM": "SOV", "AZE": "SOV",
    "KAZ": "SOV", "KAB": "SOV", "TKM": "SOV", "UZB": "SOV", "KGZ": "SOV", "TJK": "SOV",
    "MDA": "ROM", "ROU": "ROM",
    "POL": "POL", "HUN": "HUN", "CZE": "CZE", "SVK": "CZE",
    "SRB": "YUG", "MNE": "YUG", "HRV": "YUG", "SVN": "YUG", "BIH": "YUG", "MKD": "YUG", "KOS": "YUG",
    "GRC": "GRE", "BGR": "BUL", "ALB": "ALB", "TUR": "TUR",
    "SWE": "SWE", "NOR": "NOR", "DNK": "DEN", "FRO": "DEN", "FIN": "FIN", "ALD": "FIN",
    "EST": "EST", "LVA": "LAT", "LTU": "LIT",
    "NLD": "HOL", "BEL": "BEL", "LUX": "LUX",
    "IRN": "PER", "IRQ": "IRQ", "SAU": "SAU", "YEM": "YEM", "OMN": "OMA", "AFG": "AFG",
    "PAK": "RAJ", "IND": "RAJ",
}

# 1936'da modern sınırlardan farklı olan bölgeler: (modern ülke, bölge adı) -> etiket
REGION_OWNER = {
    ("RUS", "Kaliningrad"): "GER",
    ("POL", "West Pomeranian"): "GER", ("POL", "Lubusz"): "GER", ("POL", "Lower Silesian"): "GER",
    ("POL", "Opole"): "GER", ("POL", "Warmian-Masurian"): "GER",
    ("LTU", "Vilniaus"): "POL",
    ("UKR", "Volyn"): "POL", ("UKR", "Rivne"): "POL", ("UKR", "L'viv"): "POL",
    ("UKR", "Ternopil'"): "POL", ("UKR", "Ivano-Frankivs'k"): "POL",
    ("BLR", "Brest"): "POL", ("BLR", "Grodno"): "POL",
    ("UKR", "Chernivtsi"): "ROM", ("UKR", "Transcarpathia"): "CZE",
    ("MDA", "Stîngă Nistrului"): "SOV", ("MDA", "Camenca"): "SOV", ("MDA", "Grigoriopol"): "SOV",
    ("MDA", "Transnistria"): "SOV",
    ("BGR", "Dobrich"): "ROM", ("BGR", "Silistra"): "ROM",
    ("TUR", "Hatay"): "FRA",
    ("HRV", "Istarska"): "ITA",
    ("MAR", "Tanger - Tétouan"): "SPR", ("MAR", "Taza - Al Hoceima - Taounate"): "SPR",
    ("MAR", "Laâyoune - Boujdour - Sakia El Hamra"): "SPR", ("MAR", "Oued el Dahab"): "SPR",
}
# Slovenya'nın batısı (Julian March) 1936'da İtalyan
for _n in ["Nova Goriška", "Koper", "Piran", "Izola", "Sežana", "Tolmin", "Bovec", "Kobarid", "Postojna",
           "Ilirska Bistrica", "Ajdovščina", "Idrija", "Vipava", "Cerkno", "Kanal", "Brda", "Komen", "Divaca",
           "Hrpelje-Kozina", "Pivka", "Miren-Kostanjevica", "Šempeter-Vrtojba"]:
    REGION_OWNER[("SVN", _n)] = "ITA"

# 1936 nüfusu (milyon), modern ülke alanına göre (harita penceresi içinde kalan kısım)
POP1936 = {
    "DEU": 60, "POL": 32, "RUS": 92, "UKR": 30, "BLR": 9, "KAZ": 3, "UZB": 5, "TKM": 1.2, "KGZ": 0.3, "TJK": 0.2,
    "GEO": 3.5, "ARM": 1.2, "AZE": 3.1, "MDA": 2.8, "LTU": 2.5, "LVA": 1.95, "EST": 1.1, "FIN": 3.7, "ALD": 0.03,
    "SWE": 6.2, "NOR": 2.9, "DNK": 3.7, "FRO": 0.03, "ISL": 0.12, "GBR": 47, "IMN": 0.05, "GGY": 0.04,
    "JEY": 0.05, "IRL": 3.0, "NLD": 8.5, "BEL": 8.3, "LUX": 0.3, "FRA": 42, "MCO": 0.02, "CHE": 4.1,
    "LIE": 0.01, "AUT": 6.7, "CZE": 11, "SVK": 3.4, "HUN": 9, "ROU": 16, "BGR": 6.2, "GRC": 7, "ALB": 1.05,
    "MKD": 1.0, "SRB": 6.0, "MNE": 0.4, "BIH": 2.5, "HRV": 3.8, "SVN": 1.4, "KOS": 0.6, "ITA": 43,
    "SMR": 0.01, "VAT": 0.001, "ESP": 24.5, "AND": 0.005, "PRT": 7.2, "GIB": 0.02, "MLT": 0.25,
    "TUR": 16.2, "CYP": 0.3, "CYN": 0.07, "SYR": 2.8, "LBN": 0.9, "ISR": 1.0, "PSX": 0.3, "WSB": 0.01,
    "JOR": 0.4, "IRQ": 3.5, "IRN": 15, "SAU": 2.5, "KWT": 0.08, "QAT": 0.02, "ARE": 0.08, "BHR": 0.1,
    "OMN": 0.3, "YEM": 0.5, "EGY": 15.9, "LBY": 0.8, "TUN": 2.6, "DZA": 7.2, "MAR": 6.2, "SAH": 0.03,
    "MRT": 0.2, "MLI": 0.3, "NER": 0.2, "TCD": 0.2, "SDN": 1.0, "AFG": 5.0, "PAK": 8.0, "IND": 0.5,
}

import world_1936 as _W36  # noqa: E402  (tools/ klasöründen)

CAPITALS = {  # (boylam, enlem)
    "GER": (13.40, 52.52), "ENG": (-0.13, 51.51), "FRA": (2.35, 48.86), "ITA": (12.50, 41.90),
    "SOV": (37.62, 55.75), "TUR": (32.85, 39.93), "SPR": (-3.70, 40.42), "POR": (-9.14, 38.72),
    "POL": (21.01, 52.23), "ROM": (26.10, 44.43), "HUN": (19.04, 47.50), "CZE": (14.42, 50.08),
    "AUS": (16.37, 48.21), "YUG": (20.46, 44.80), "GRE": (23.73, 37.98), "BUL": (23.32, 42.70),
    "ALB": (19.82, 41.33), "SWE": (18.07, 59.33), "NOR": (10.75, 59.91), "DEN": (12.57, 55.68),
    "FIN": (24.94, 60.17), "EST": (24.75, 59.44), "LAT": (24.10, 56.95), "LIT": (23.90, 54.90),
    "HOL": (4.90, 52.37), "BEL": (4.35, 50.85), "LUX": (6.13, 49.61), "SWI": (7.45, 46.95),
    "IRE": (-6.26, 53.35), "ICE": (-21.90, 64.15), "PER": (51.39, 35.69), "IRQ": (44.36, 33.31),
    "SAU": (46.72, 24.69), "OMA": (58.40, 23.60),
}

ADM0_OWNER.update(_W36.ADM0_OWNER)
REGION_OWNER.update(_W36.REGION_OWNER)
POP1936.update(_W36.POP1936)
CAPITALS.update(_W36.CAPITALS)


def log(msg, t0=[time.time()]):
    print(f"[{time.time() - t0[0]:7.1f}s] {msg}", flush=True)


# ---------------------------------------------------------------- projeksiyon fonksiyonları
def project(lon, lat):
    """derece -> piksel (float). x dikişten itibaren sarmalanır."""
    lon = np.asarray(lon, dtype=np.float64)
    lat = np.clip(np.asarray(lat, dtype=np.float64), -89.0, 89.0)
    x = np.mod(lon - LON_MIN, 360.0) / 360.0 * W
    y = (Y_TOP - miller_y(np.radians(lat))) * PX_PER_RAD
    return x, y


def unproject(px, py):
    """piksel -> (boylam [-180,180), enlem) derece."""
    lon = LON_MIN + (np.asarray(px, dtype=np.float64) + 0.5) / W * 360.0
    lon = np.mod(lon + 180.0, 360.0) - 180.0
    return lon, _row_lat(np.asarray(py, dtype=np.float64) + 0.5)


def unwrap_ring(px):
    """Dikişi kesen halka: x'leri tek tarafa toplar (sol yarıdakiler +W). Kesmiyorsa aynen döner."""
    if px.max() - px.min() > W / 2:
        return np.where(px < W / 2, px + W, px), True
    return px, False


def area_image():
    """Piksel alanı (km²), tam boyut float32 (satır sabitli)."""
    return np.broadcast_to(ROW_AREA[:, None], (H, W))


# ---------------------------------------------------------------- yardımcılar
def land_of(ids, types):
    """id dizisi -> kara mı maskesi."""
    lut = np.zeros(int(ids.max()) + 1, bool)
    for k, t in types.items():
        if t == "land" and k < len(lut):
            lut[k] = True
    return lut[ids]


def boundary_mask(lab, valid=None):
    """Komşusuyla farklı etikete sahip pikseller (her iki taraf da işaretlenir)."""
    m = np.zeros(lab.shape, bool)
    dh = lab[:, :-1] != lab[:, 1:]
    dv = lab[:-1, :] != lab[1:, :]
    if valid is not None:
        dh &= valid[:, :-1] & valid[:, 1:]
        dv &= valid[:-1, :] & valid[1:, :]
    m[:, :-1] |= dh
    m[:, 1:] |= dh
    m[:-1, :] |= dv
    m[1:, :] |= dv
    # doğu-batı dikişi (sütun 0 ile son sütun komşu)
    dw = lab[:, 0] != lab[:, -1]
    if valid is not None:
        dw &= valid[:, 0] & valid[:, -1]
    m[:, 0] |= dw
    m[:, -1] |= dw
    return m


def edt_wrap(mask, return_indices=False):
    """Doğu-batı sarmalanan mesafe dönüşümü: harita kenarları dikişten komşu sayılır."""
    pad = min(1024, W // 4)
    m = np.concatenate([mask[:, -pad:], mask, mask[:, :pad]], axis=1)
    if return_indices:
        idx = ndimage.distance_transform_edt(m, return_distances=False, return_indices=True)
        iy = idx[0][:, pad:pad + W]
        ix = np.mod(idx[1][:, pad:pad + W] - pad, W)
        return np.stack([iy, ix])
    return ndimage.distance_transform_edt(m)[:, pad:pad + W]


def encode_dist(mask):
    d = edt_wrap(~mask) + 0.5
    return np.clip(d * 8.0, 0, 255).astype(np.uint8)


def adjacency(lab):
    """Etiket çiftleri ve ortak sınır uzunlukları (doğu-batı dikişinden sarmalanır)."""
    a = np.concatenate([lab[:, :-1].ravel(), lab[:-1, :].ravel(), lab[:, -1]])
    b = np.concatenate([lab[:, 1:].ravel(), lab[1:, :].ravel(), lab[:, 0]])
    m = (a != b) & (a > 0) & (b > 0)
    a, b = a[m].astype(np.int64), b[m].astype(np.int64)
    n = int(lab.max()) + 1
    key = np.minimum(a, b) * n + np.maximum(a, b)
    uk, cnt = np.unique(key, return_counts=True)
    return [(int(k // n), int(k % n), int(c)) for k, c in zip(uk, cnt)]


def smooth_noise(shape, sigma, rng):
    n = rng.standard_normal(shape).astype(np.float32)
    n = ndimage.gaussian_filter(n, sigma)
    return n / (n.std() + 1e-9)


def kmeans_partition(coords, k, rng):
    """coords (N,2) -> her nokta için 0..k-1 küme etiketi."""
    if k <= 1 or len(coords) <= k:
        return np.zeros(len(coords), np.int32)
    sample = coords
    if len(coords) > 30000:
        sample = coords[rng.choice(len(coords), 30000, replace=False)]
    cent, _ = kmeans2(sample.astype(np.float64), k, minit="++", iter=25, seed=rng)
    _, idx = cKDTree(cent).query(coords)
    return idx.astype(np.int32)


# ---------------------------------------------------------------- 1a) yükseklik (Terrarium DEM)
DEM_ZOOM = 6
DEM_WORLD_ZOOM = 5


def _dem_mosaic(zoom):
    d = CACHE / "dem" / str(zoom)
    tiles = {}
    for f in d.glob("*.png"):
        x, y = f.stem.split("_")
        tiles[(int(x), int(y))] = f
    if not tiles:
        return None
    xs = [k[0] for k in tiles]
    ys = [k[1] for k in tiles]
    x0, y0 = min(xs), min(ys)
    mos = np.zeros(((max(ys) - y0 + 1) * 256, (max(xs) - x0 + 1) * 256), np.float32)
    for (x, y), f in tiles.items():
        a = np.asarray(Image.open(f).convert("RGB"), dtype=np.float32)
        mos[(y - y0) * 256:(y - y0 + 1) * 256, (x - x0) * 256:(x - x0 + 1) * 256] = \
            a[..., 0] * 256.0 + a[..., 1] + a[..., 2] / 256.0 - 32768.0
    return mos, x0, y0, zoom


def _dem_sample(m, lon, lat):
    mos, x0, y0, zoom = m
    n = (2 ** zoom) * 256
    gx = (lon.astype(np.float64) + 180.0) / 360.0 * n - x0 * 256 - 0.5
    r = np.radians(np.clip(lat.astype(np.float64), -85, 85))
    gy = (1.0 - np.log(np.tan(r) + 1.0 / np.cos(r)) / math.pi) / 2.0 * n - y0 * 256 - 0.5
    inside = (gx >= 1) & (gy >= 1) & (gx < mos.shape[1] - 2) & (gy < mos.shape[0] - 2)
    v = ndimage.map_coordinates(mos, [gy, gx], order=3, mode="nearest").astype(np.float32)
    return v, inside


def build_dem(lon, lat):
    """Web Mercator Terrarium karolarından: tüm dünya zoom 5, Avrupa penceresi zoom 6 (daha ayrıntılı)."""
    log("yükseklik mozaiği örnekleniyor (dünya z5 + Avrupa z6)")
    world = _dem_mosaic(DEM_WORLD_ZOOM)
    fine = _dem_mosaic(DEM_ZOOM)
    out = np.zeros((H, W), np.float32)
    step = 512
    for r0 in range(0, H, step):
        r1 = min(r0 + step, H)
        lo, la = lon[r0:r1], lat[r0:r1]
        v, _ = _dem_sample(world, lo, la)
        if fine is not None:
            vf, ok = _dem_sample(fine, lo, la)
            v = np.where(ok, vf, v)
        out[r0:r1] = v
    return out


def hillshade(h, exaggeration=5.0):
    """Çok yönlü tepe gölgesi; düz arazi = 1.0."""
    hz = ndimage.gaussian_filter(h, 0.8)
    dy, dx = np.gradient(hz)
    dx /= ROW_KX[:, None] * 1000.0
    dy /= ROW_KY[:, None] * 1000.0
    nx, ny, nz = -dx * exaggeration, -dy * exaggeration, np.ones_like(h)
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx * inv, ny * inv, nz * inv
    alt = math.radians(42)
    shade = np.zeros_like(h)
    for az_deg, w in [(315, 0.55), (270, 0.2), (0, 0.25)]:
        az = math.radians(az_deg)
        # görüntü koordinatları: x doğu, y güney; azimut kuzeyden saat yönünde
        lx, ly, lz = math.sin(az) * math.cos(alt), -math.cos(az) * math.cos(alt), math.sin(alt)
        shade += w * np.maximum(nx * lx + ny * ly + nz * lz, 0.0)
    return shade / math.sin(alt)


def slope_map(h):
    dy, dx = np.gradient(ndimage.gaussian_filter(h, 0.8))
    dx /= ROW_KX[:, None] * 1000.0
    dy /= ROW_KY[:, None] * 1000.0
    return np.sqrt(dx * dx + dy * dy).astype(np.float32)


# ---------------------------------------------------------------- 1b) arazi rengi
def build_terrain():
    """HYP (iklim tonu), NE1 (arazi örtüsü) ve SR (eski gölge) raster'larını harita projeksiyonuna örnekler."""
    log("arazi raster'ları örnekleniyor")
    lon1, _ = unproject(np.arange(W), np.zeros(W))
    lat1 = ROW_LAT.astype(np.float64)
    srcs = {}
    for key, path in [("hyp", CACHE / "HYP_50M_SR_W.tif"), ("ne1", CACHE / "NE1_50M_SR_W" / "NE1_50M_SR_W.tif"), ("sr", CACHE / "SR_50M.tif")]:
        srcs[key] = np.asarray(Image.open(path), dtype=np.float32)
    hyp = np.zeros((H, W, 3), np.float32)
    ne1 = np.zeros((H, W, 3), np.float32)
    sr = np.zeros((H, W), np.float32)
    col1 = (lon1 + 180.0) * 30.0 - 0.5
    step = 256
    for r0 in range(0, H, step):
        r1 = min(r0 + step, H)
        row = np.broadcast_to(((90.0 - lat1[r0:r1]) * 30.0 - 0.5)[:, None], (r1 - r0, W))
        col = np.broadcast_to(col1[None, :], (r1 - r0, W))
        coords = [row, col]
        for i in range(3):
            hyp[r0:r1, :, i] = ndimage.map_coordinates(srcs["hyp"][..., i], coords, order=1, mode="wrap")
            ne1[r0:r1, :, i] = ndimage.map_coordinates(srcs["ne1"][..., i], coords, order=1, mode="wrap")
        sr[r0:r1] = ndimage.map_coordinates(srcs["sr"], coords, order=1, mode="wrap")
    lon = np.broadcast_to(lon1.astype(np.float32)[None, :], (H, W))
    lat = np.broadcast_to(ROW_LAT[:, None], (H, W))
    return hyp, ne1, sr, lon, lat


# ---------------------------------------------------------------- 1c) göller ve nehirler
LAKE_MIN_KM2 = 300
# nehir sınıfları: (en büyük scalerank, yarı genişlik bonusu texel)
RIVER_CLASSES = [(5, 1.3), (8, 0.8), (10, 0.45)]
RIVER_CROSSING_MAX_RANK = 8    # bu ve daha büyük nehirler bölge sınırında "nehir geçişi" sayılır


def _project_lines(geom):
    parts = [geom["coordinates"]] if geom["type"] in ("LineString", "Polygon") else geom["coordinates"]
    for part in parts:
        ring = np.asarray(part[0] if geom["type"] in ("Polygon", "MultiPolygon") else part, dtype=np.float64)
        if ring.ndim != 2 or len(ring) < 2:
            continue
        if ring[:, 1].max() < LAT_BOT:
            continue
        px, py = project(ring[:, 0], ring[:, 1])
        px, wrapped = unwrap_ring(px)
        yield list(zip(px.tolist(), py.tolist()))
        if wrapped:
            yield list(zip((px - W).tolist(), py.tolist()))


def rasterize_lakes():
    log("göller rasterize ediliyor")
    img = Image.new("L", (W, H), 0)
    draw = ImageDraw.Draw(img)
    count = 0
    for f in json.load(open(CACHE / "ne_10m_lakes.geojson"))["features"]:
        if f["geometry"] is None:
            continue
        for pts in _project_lines(f["geometry"]):
            a = np.asarray(pts)
            row = int(np.clip(a[:, 1].mean(), 0, H - 1))
            area = 0.5 * abs(np.dot(a[:, 0], np.roll(a[:, 1], 1)) - np.dot(a[:, 1], np.roll(a[:, 0], 1))) * ROW_AREA[row]
            if area >= LAKE_MIN_KM2:
                draw.polygon(pts, fill=255)
                count += 1
    log(f"  {count} göl poligonu")
    return np.asarray(img) > 0


def rasterize_rivers():
    """Her nehir sınıfı için merkez çizgisi maskesi."""
    log("nehirler rasterize ediliyor")
    masks = [Image.new("L", (W, H), 0) for _ in RIVER_CLASSES]
    draws = [ImageDraw.Draw(m) for m in masks]
    for f in json.load(open(CACHE / "ne_10m_rivers_lake_centerlines.geojson"))["features"]:
        p = f["properties"]
        if f["geometry"] is None or p.get("featurecla") != "River":
            continue
        rank = p.get("scalerank") or 10
        for ci, (max_rank, _) in enumerate(RIVER_CLASSES):
            if rank <= max_rank:
                for pts in _project_lines(f["geometry"]):
                    draws[ci].line(pts, fill=255, width=1)
                break
    return [np.asarray(m) > 0 for m in masks]


# ---------------------------------------------------------------- 1d) boğazlar
# Çözünürlükte kapanan su yolları: haritaya ince kanal olarak açılır (boylam, enlem noktaları)
CARVED_CHANNELS = {
    "bosporus": [(29.13, 41.23), (29.07, 41.12), (29.04, 41.06), (29.00, 41.01), (28.98, 40.98)],
    "dardanelles": [(26.17, 40.03), (26.33, 40.10), (26.42, 40.18), (26.55, 40.30), (26.68, 40.40), (26.75, 40.46)],
    "suez": [(32.31, 31.27), (32.31, 30.85), (32.33, 30.55), (32.43, 30.30), (32.56, 29.95)],
    "messina": [(15.60, 38.27), (15.63, 38.21), (15.65, 38.14), (15.64, 38.08)],
    "little_belt": [(9.73, 55.61), (9.75, 55.54), (9.71, 55.47)],
    "panama": [(-79.92, 9.38), (-79.85, 9.2), (-79.70, 9.07), (-79.58, 8.95), (-79.53, 8.88)],
}
# Kara birliklerinin su üzerinden geçebildiği boğazlar: (ad, TR ad, A kıyısı, B kıyısı)
STRAITS = [
    ("Bosporus", "İstanbul Boğazı", (28.97, 41.04), (29.07, 41.02)),
    ("Dardanelles", "Çanakkale Boğazı", (26.37, 40.23), (26.45, 40.10)),
    ("Strait of Gibraltar", "Cebelitarık Boğazı", (-5.60, 36.03), (-5.34, 35.88)),
    ("Øresund", "Öresund", (12.58, 56.02), (12.72, 56.05)),
    ("Great Belt", "Büyük Belt", (10.80, 55.31), (11.12, 55.33)),
    ("Little Belt", "Küçük Belt", (9.75, 55.57), (9.74, 55.49)),
    ("Kerch Strait", "Kerç Boğazı", (36.47, 45.33), (36.73, 45.22)),
    ("Strait of Messina", "Messina Boğazı", (15.55, 38.20), (15.66, 38.12)),
    ("Strait of Dover", "Manş (Dover) Boğazı", (1.30, 51.13), (1.85, 50.95)),
    ("Strait of Bonifacio", "Bonifacio Boğazı", (9.17, 41.40), (9.25, 41.23)),
    ("Suez Canal", "Süveyş Kanalı", (32.27, 30.60), (32.37, 30.60)),
]


def carve_channels(lab):
    img = Image.new("L", (W, H), 0)
    draw = ImageDraw.Draw(img)
    for pts in CARVED_CHANNELS.values():
        xs, ys = project(np.array([p[0] for p in pts]), np.array([p[1] for p in pts]))
        draw.line(list(zip(xs.tolist(), ys.tolist())), fill=255, width=3)
    mask = np.asarray(img) > 0
    lab[mask] = 0
    log(f"  {len(CARVED_CHANNELS)} kanal açıldı ({int(mask.sum())} piksel)")


def nearest_land_province(P, types, x, y, radius=10):
    best, best_d = 0, 1e9
    for yy in range(max(y - radius, 0), min(y + radius + 1, H)):
        for xx in range(max(x - radius, 0), min(x + radius + 1, W)):
            pid = int(P[yy, xx])
            if types.get(pid) == "land":
                d = (xx - x) ** 2 + (yy - y) ** 2
                if d < best_d:
                    best, best_d = pid, d
    return best


NO_LAND_CROSSING = {"Strait of Dover"}


def build_straits(P, types):
    out = []
    for name, name_tr, a, b in STRAITS:
        pts = []
        for lon, lat in (a, b):
            x, y = project(np.array([lon]), np.array([lat]))
            pts.append((int(x[0]), int(y[0])))
        pa = nearest_land_province(P, types, *pts[0])
        pb = nearest_land_province(P, types, *pts[1])
        if pa and pb and pa != pb:
            # türün klasiklerindeki gibi: geniş deniz geçitleri (Manş) yürünemez; yalnız feribot/görsel
            out.append({"name": {"en": name, "tr": name_tr}, "provinces": [pa, pb],
                        "from": list(pts[0]), "to": list(pts[1]), "land_crossing": name not in NO_LAND_CROSSING})
        else:
            log(f"  ! boğaz atlandı: {name} ({pa}, {pb})")
    log(f"  {len(out)} boğaz geçişi")
    return out


# ---------------------------------------------------------------- 2) idari bölgeleri rasterize et
def rasterize_regions():
    log("idari bölgeler rasterize ediliyor")
    data = json.load(open(CACHE / "ne_10m_admin_1.geojson"))
    feats = []
    polys = []  # (alan, feat_index, noktalar)
    for f in data["features"]:
        p = f["properties"]
        g = f["geometry"]
        if g is None:
            continue
        rings = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
        pts_all = []
        for poly in rings:
            ring = np.asarray(poly[0], dtype=np.float64)
            if ring[:, 1].max() < LAT_BOT:
                continue
            px, py = project(ring[:, 0], ring[:, 1])
            px, wrapped = unwrap_ring(px)
            pts_all.append(np.stack([px, py], 1))
            if wrapped:
                pts_all.append(np.stack([px - W, py], 1))
        if not pts_all:
            continue
        adm0 = p.get("adm0_a3")
        name = p.get("name") or p.get("name_en") or p.get("gn_name") or "?"
        fi = len(feats) + 1
        feats.append({"adm0": adm0, "name": name, "names": {
            "en": p.get("name_en") or name,
            "tr": clean_tr(p.get("name_tr")) or (p.get("name_en") or name),
        }})
        for pts in pts_all:
            area = 0.5 * abs(np.dot(pts[:, 0], np.roll(pts[:, 1], 1)) - np.dot(pts[:, 1], np.roll(pts[:, 0], 1)))
            polys.append((area, fi, pts))
    polys.sort(key=lambda t: -t[0])  # büyükler önce, içteki küçükler üstüne çizilir
    img = Image.new("I", (W, H), 0)
    draw = ImageDraw.Draw(img)
    for _, fi, pts in polys:
        draw.polygon([tuple(q) for q in pts], fill=fi)
    lab = np.asarray(img, dtype=np.int32).copy()
    log(f"  {len(feats)} bölge, {len(polys)} poligon")
    return lab, feats


# ---------------------------------------------------------------- 3) eyaletleri oluştur
def build_states(lab, feats, hab, rng):
    log("eyaletler oluşturuluyor")
    n = len(feats) + 1
    owner = [None] * n
    unknown = defaultdict(int)
    area = np.bincount(lab.ravel(), minlength=n)
    for i, f in enumerate(feats, 1):
        o = REGION_OWNER.get((f["adm0"], f["name"])) or ADM0_OWNER.get(f["adm0"])
        if o is None and area[i] > 0:
            unknown[f["adm0"]] += int(area[i])
        owner[i] = o
    if unknown:
        log(f"  sahipsiz ülke kodları (piksel): {dict(unknown)}")
    # sahipsiz bölgeleri haritadan çıkar
    ok = np.array([o is not None for o in owner])
    lab[~ok[lab]] = 0
    npx = np.bincount(lab.ravel(), minlength=n).astype(np.float64)
    ys, xs = np.nonzero(lab)
    lv = lab[ys, xs]
    area = np.bincount(lv, weights=ROW_AREA[ys].astype(np.float64), minlength=n)   # km²
    cx = np.bincount(lv, weights=xs, minlength=n) / np.maximum(npx, 1)
    cy = np.bincount(lv, weights=ys, minlength=n) / np.maximum(npx, 1)
    c_lon, c_lat = unproject(cx, cy)
    tf = theater(c_lon, c_lat)          # bölge başına yoğunluk çarpanı
    del ys, xs, lv

    edges = adjacency(lab)
    parent = list(range(n))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    garea = area.copy()
    changed = True
    while changed:
        changed = False
        nb = defaultdict(lambda: defaultdict(int))
        for a, b, c in edges:
            ra, rb = find(a), find(b)
            if ra != rb:
                nb[ra][rb] += c
                nb[rb][ra] += c
        roots = sorted({find(i) for i in range(1, n) if area[i] > 0}, key=lambda r: garea[r])
        merged = set()
        for r in roots:
            if garea[r] >= MIN_STATE_KM2 * tf[r] or r in merged:
                continue
            cands = [(garea[o], -c, o) for o, c in nb[r].items()
                     if owner[o] == owner[r] and feats[o - 1]["adm0"] == feats[r - 1]["adm0"] and o not in merged]
            if not cands:
                continue
            _, _, o = min(cands)
            big, small = (r, o) if garea[r] >= garea[o] else (o, r)
            parent[small] = big
            garea[big] += garea[small]
            merged.update((r, o))
            changed = True
    # küçük ve komşusuz adacıklar: en yakın aynı sahipli eyalete
    roots = {find(i) for i in range(1, n) if area[i] > 0}
    big_roots = [r for r in roots if garea[r] >= TINY_STATE_KM2]
    for r in roots:
        if garea[r] < TINY_STATE_KM2:
            same = [b for b in big_roots if owner[b] == owner[r]]
            if same:
                d = [(cx[b] - cx[r]) ** 2 + (cy[b] - cy[r]) ** 2 for b in same]
                parent[r] = same[int(np.argmin(d))]
    roots = sorted({find(i) for i in range(1, n) if area[i] > 0})

    # grup -> eyalet etiketi
    remap = np.zeros(n, np.int32)
    groups = defaultdict(list)
    for i in range(1, n):
        if area[i] > 0:
            groups[find(i)].append(i)
    state_list = []
    for r in roots:
        members = groups[r]
        sid = len(state_list) + 1
        for m in members:
            remap[m] = sid
        biggest = max(members, key=lambda m: area[m])
        state_list.append({
            "owner": owner[r], "adm0": feats[r - 1]["adm0"],
            "name": feats[biggest - 1]["name"],
            "names": dict(feats[biggest - 1]["names"]),
            "regions": [feats[m - 1]["name"] for m in members],
        })
    S = remap[lab]

    # çok büyük eyaletleri böl
    log(f"  {len(state_list)} eyalet (bölme öncesi)")
    objs = ndimage.find_objects(S)
    next_id = len(state_list) + 1
    for sid in range(1, len(state_list) + 1):
        sl = objs[sid - 1]
        if sl is None:
            continue
        sub = S[sl]
        m = sub == sid
        rows = np.nonzero(m)[0] + sl[0].start
        a_km2 = float(ROW_AREA[rows].sum())
        h = float(hab[sl][m].mean())
        cyy, cxx = rows.mean(), (np.nonzero(m)[1] + sl[1].start).mean()
        lo_, la_ = unproject(cxx, cyy)
        limit = (MAX_STATE_REMOTE_KM2 if h < 0.35 else MAX_STATE_KM2) * float(theater(lo_, la_))
        if a_km2 <= limit:
            continue
        k = int(math.ceil(a_km2 / (limit * 0.7)))
        yy, xx = np.nonzero(m)
        part = kmeans_partition(np.stack([xx, yy], 1).astype(np.float32), k, rng)
        base = state_list[sid - 1]
        for j in range(1, k):
            sel = part == j
            if not sel.any():
                continue
            sub[yy[sel], xx[sel]] = next_id
            state_list.append({**base, "name": f"{base['name']} {roman(j + 1)}",
                               "names": {k: f"{v} {roman(j + 1)}" for k, v in base["names"].items()}})
            next_id += 1
        if k > 1:
            base["name"] = f"{base['name']} I"
            base["names"] = {kk: f"{v} I" for kk, v in base["names"].items()}
    log(f"  {len(state_list)} eyalet (bölme sonrası)")
    return S, state_list


TR_SUFFIX = re.compile(r"\s+(eyaleti|ili|bölgesi|vilayeti|oblastı|ilçesi|kontluğu|departmanı|valiliği|bölge|voyvodalığı)$", re.IGNORECASE)


def clean_tr(name):
    return TR_SUFFIX.sub("", name).strip() if name else None


def roman(n):
    return ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"][n] if n < 13 else str(n)


# ---------------------------------------------------------------- 4) bölgeler (province)
def build_provinces(S, states, hab, lat, rng):
    log("kara bölgeleri oluşturuluyor")
    warp_x = smooth_noise((H, W), 22, rng) * 9 + smooth_noise((H, W), 5, rng) * 2.5
    warp_y = smooth_noise((H, W), 22, rng) * 9 + smooth_noise((H, W), 5, rng) * 2.5
    P = np.zeros((H, W), np.int32)
    prov_state = {}
    next_pid = 1
    objs = ndimage.find_objects(S)
    for sid in range(1, len(states) + 1):
        sl = objs[sid - 1]
        if sl is None:
            continue
        m = S[sl] == sid
        yy, xx = np.nonzero(m)
        gy, gx = yy + sl[0].start, xx + sl[1].start
        h = float(hab[sl][m].mean())
        la = float(ROW_LAT[gy].mean())
        lo = float(unproject(gx.mean(), 0)[0])
        a_km2 = float(ROW_AREA[gy].sum())
        target = PROVINCE_KM2 * (1.0 + 2.8 * (1.0 - min(h, 1.0)) ** 1.5) * (1.8 if abs(la) > 61 else 1.0) * float(theater(lo, la))
        k = int(np.clip(round(a_km2 / target), 1, 16))
        coords = np.stack([gx + warp_x[gy, gx], gy + warp_y[gy, gx]], 1).astype(np.float32)
        part = kmeans_partition(coords, k, rng)
        P[gy, gx] = next_pid + part
        for j in range(k):
            prov_state[next_pid + j] = sid
        next_pid += k
    log(f"  {len(prov_state)} kara bölgesi")
    return P, prov_state, warp_x, warp_y


def build_sea(P, land, lake_mask, warp_x, warp_y, rng, first_id):
    log("deniz bölgeleri oluşturuluyor")
    water = ~land
    comp, ncomp = ndimage.label(water)
    sizes = np.bincount(comp.ravel())
    dist = edt_wrap(water)
    types = {}
    nid = first_id
    lake_km2 = LAKE_MIN_KM2
    objs = ndimage.find_objects(comp)
    for c in range(1, ncomp + 1):
        sz = sizes[c]
        sl = objs[c - 1]
        yy, xx = np.nonzero(comp[sl] == c)
        yy, xx = yy + sl[0].start, xx + sl[1].start
        touches_edge = yy.min() == 0 or xx.min() == 0 or yy.max() == H - 1 or xx.max() == W - 1
        a_c = float(ROW_AREA[yy].sum())
        # göl yalnızca gerçek göl verisinden geliyorsa (Marmara gibi boğazla kopan denizler deniz kalır)
        lake_frac = lake_mask[yy, xx].mean()
        is_sea = touches_edge or (lake_frac < 0.5 and a_c >= lake_km2 * 8)
        if not is_sea and a_c < lake_km2:
            P[yy, xx] = -1  # karaya doldurulacak
            continue
        if not is_sea:
            P[yy, xx] = nid
            types[nid] = "lake"
            nid += 1
            continue
        # hedef bölge alanı: kıyıda küçük, açık okyanusta büyük; bölge çarpanı (Avrupa denizleri ayrıntılı)
        d_km = dist[yy, xx] * ROW_KX[yy]
        lo_, la_ = unproject(xx.astype(np.float64), yy.astype(np.float64))
        want = SEA_PROVINCE_KM2 * theater(lo_, la_) ** 0.8 * (1.0 + np.clip(d_km / 250.0, 0, 8))
        pa = ROW_AREA[yy]
        k = max(1, int(round(float((pa / want).sum()))))
        coords = np.stack([xx + warp_x[yy, xx] * 2, yy + warp_y[yy, xx] * 2], 1).astype(np.float32)
        if k > 1:
            # tohumlar: yoğunluğa (1/istenen alan) göre ağırlıklı, birbirine çok yakın olmayan noktalar
            prob = pa / want
            prob = prob / prob.sum()
            cand = rng.choice(len(yy), size=min(len(yy), k * 6), replace=False, p=prob)
            seeds = []
            tree = None
            for ci in cand:
                pnt = coords[ci]
                r_px = math.sqrt(float(want[ci]) / math.pi) / float(ROW_KX[yy[ci]]) * 0.9
                if seeds:
                    near = cKDTree(np.asarray(seeds)).query_ball_point(pnt, r_px) if len(seeds) < 64 or tree is None else tree.query_ball_point(pnt, r_px)
                    if near:
                        continue
                seeds.append(pnt)
                if len(seeds) % 64 == 0:
                    tree = cKDTree(np.asarray(seeds))
                if len(seeds) >= k:
                    break
            seeds = np.asarray(seeds, np.float64)
            # birkaç Lloyd adımı: düzgün şekiller
            _, part = cKDTree(seeds).query(coords)
            for _it in range(3):
                w = pa.astype(np.float64)
                sx = np.bincount(part, weights=coords[:, 0] * w, minlength=len(seeds))
                sy = np.bincount(part, weights=coords[:, 1] * w, minlength=len(seeds))
                sw = np.maximum(np.bincount(part, weights=w, minlength=len(seeds)), 1e-9)
                seeds = np.stack([sx / sw, sy / sw], 1)
                _, part = cKDTree(seeds).query(coords)
            k = len(seeds)
        else:
            part = np.zeros(len(yy), np.int64)
        P[yy, xx] = nid + part
        for j in range(k):
            types[nid + j] = "sea"
        nid += k
    # küçük boşlukları en yakın kara bölgesiyle doldur
    hole = P < 0
    if hole.any():
        idx = edt_wrap(P <= 0, return_indices=True)
        filled = P[idx[0], idx[1]]
        P[hole] = filled[hole]
    log(f"  {sum(1 for t in types.values() if t == 'sea')} deniz, {sum(1 for t in types.values() if t == 'lake')} göl")
    return types


def split_disconnected(P, prov_state, types):
    """Kopuk parçaları ayrı bölge yapar (büyükse) ya da komşuya katar."""
    log("kopuk parçalar düzeltiliyor")
    objs = ndimage.find_objects(P)
    nid = len(objs) + 1
    extra = 0
    for pid in range(1, len(objs) + 1):
        sl = objs[pid - 1]
        if sl is None:
            continue
        sub = P[sl]
        m = sub == pid
        comp, nc = ndimage.label(m)
        if nc <= 1:
            continue
        sizes = np.bincount(comp.ravel())
        sizes[0] = 0
        keep = int(np.argmax(sizes))
        for c in range(1, nc + 1):
            if c == keep:
                continue
            cm = comp == c
            if sizes[c] >= MIN_ISLAND_PROVINCE_PX:
                sub[cm] = nid
                types[nid] = types.get(pid, "land")
                if pid in prov_state:
                    prov_state[nid] = prov_state[pid]
                nid += 1
                extra += 1
            else:
                # aynı eyaletten bitişik bir bölgeye kat (yoksa olduğu gibi kalsın)
                ring = ndimage.binary_dilation(cm) & ~cm
                cand = sub[ring]
                cand = cand[(cand > 0) & (cand != pid)]
                if types.get(pid, "land") == "land":
                    cand = np.array([c2 for c2 in cand if prov_state.get(int(c2)) == prov_state[pid]], dtype=np.int32)
                else:
                    cand = np.array([c2 for c2 in cand if types.get(int(c2)) == types.get(pid)], dtype=np.int32)
                if len(cand):
                    vals, cnts = np.unique(cand, return_counts=True)
                    sub[cm] = vals[np.argmax(cnts)]
    log(f"  {extra} ada bölgesi eklendi")


# ---------------------------------------------------------------- 4b) şehirler
# günümüz nüfusunu kabaca 1936'ya indirgeme katsayıları (ülke kodu -> çarpan)
POP_1936_FACTOR = {
    "TUR": 0.12, "EGY": 0.12, "IRN": 0.1, "IRQ": 0.1, "SAU": 0.03, "KWT": 0.03, "ARE": 0.02, "QAT": 0.02,
    "BHR": 0.1, "OMN": 0.05, "JOR": 0.03, "SYR": 0.15, "LBN": 0.2, "ISR": 0.1, "PSX": 0.1, "WSB": 0.1,
    "DZA": 0.15, "MAR": 0.15, "TUN": 0.2, "LBY": 0.1, "SAH": 0.02, "MRT": 0.05, "MLI": 0.1, "NER": 0.1,
    "TCD": 0.1, "SDN": 0.1, "PAK": 0.1, "AFG": 0.1, "KAZ": 0.2, "UZB": 0.2, "TKM": 0.15, "KGZ": 0.2,
    "TJK": 0.2, "AZE": 0.3, "GEO": 0.4, "ARM": 0.2, "RUS": 0.35, "UKR": 0.45, "BLR": 0.35, "MDA": 0.4,
    "ESP": 0.5, "PRT": 0.5, "GRC": 0.4, "ALB": 0.3, "MKD": 0.3, "BIH": 0.4, "SRB": 0.4, "KOS": 0.3,
    "MNE": 0.3, "BGR": 0.4, "ROU": 0.45, "CYP": 0.3, "CYN": 0.3,
}
POP_1936_FACTOR.update({
    "USA": 0.4, "CAN": 0.3, "MEX": 0.12, "CUB": 0.3, "BRA": 0.15, "ARG": 0.3, "CHL": 0.2, "URY": 0.4, "COL": 0.1,
    "VEN": 0.1, "PER": 0.1, "ECU": 0.1, "BOL": 0.15, "PRY": 0.15, "JPN": 0.35, "KOR": 0.07, "PRK": 0.12, "TWN": 0.1,
    "CHN": 0.12, "HKG": 0.12, "MNG": 0.05, "IND": 0.1, "BGD": 0.06, "LKA": 0.15, "NPL": 0.05, "MMR": 0.12,
    "THA": 0.08, "VNM": 0.08, "PHL": 0.07, "IDN": 0.07, "MYS": 0.1, "SGP": 0.12, "AUS": 0.3, "NZL": 0.3,
    "ZAF": 0.15, "NGA": 0.04, "ETH": 0.05, "KEN": 0.04, "COD": 0.03,
})
CITY_MIN_POP_1936 = 25000
CITY_STYLE_REGION = [  # (boylam0, enlem0, boylam1, enlem1, stil) Avrupa dışı için
    (-170, 5, -30, 85, "west"), (-95, -60, -30, 5, "west"), (110, -50, 180, -10, "west"),
    (60, -12, 180, 60, "orient"), (-20, -40, 60, 20, "orient"),
]
MAJOR_CAPITAL_VP = 50
MAJORS = {"GER", "ENG", "FRA", "ITA", "SOV"}


# 1936'daki adlar (günümüz adı -> tarihi ad)
HISTORIC_CITY_NAMES = {
    "Kaliningrad": "Königsberg", "Wrocław": "Breslau", "Szczecin": "Stettin", "Gdańsk": "Danzig",
    "Olsztyn": "Allenstein", "Opole": "Oppeln", "Zielona Góra": "Grünberg", "Lviv": "Lwów", "Vilnius": "Wilno",
    "Grodno": "Grodno", "Brest": "Brześć", "Chernivtsi": "Cernăuți", "Uzhgorod": "Užhorod", "Rijeka": "Fiume",
    "Pula": "Pola", "St. Petersburg": "Leningrad", "Volgograd": "Stalingrad", "Samara": "Kuybyshev",
    "Nizhny Novgorod": "Gorky", "Yekaterinburg": "Sverdlovsk", "Tver": "Kalinin", "Donetsk": "Stalino",
    "Dnipro": "Dnipropetrovsk", "Luhansk": "Voroshilovgrad", "Tbilisi": "Tiflis", "Almaty": "Alma-Ata",
    "Bishkek": "Frunze", "Dushanbe": "Stalinabad", "Istanbul": "İstanbul", "Izmir": "İzmir",
    "Chisinau": "Chișinău", "Podgorica": "Podgorica", "Tallinn": "Tallinn", "Kharkiv": "Kharkov",
    "Kyiv": "Kiev", "Odesa": "Odessa", "Zaporizhzhya": "Zaporozhye",
}
# 1936 sahibine göre eyalet adı düzeltmeleri (üretilen ad -> {dil: ad})
STATE_NAME_OVERRIDES = {
    "West Pomeranian": {"en": "Pomerania", "tr": "Pomeranya"},
    "Lubusz": {"en": "Neumark", "tr": "Neumark"},
    "Warmian-Masurian": {"en": "East Prussia", "tr": "Doğu Prusya"},
    "Lower Silesian": {"en": "Silesia", "tr": "Silezya"},
    "Opole": {"en": "Upper Silesia", "tr": "Yukarı Silezya"},
    "Hatay": {"en": "Alexandretta", "tr": "İskenderun Sancağı"},
}


def city_names(p):
    base = p["name"].replace("  ", " ")
    if base in HISTORIC_CITY_NAMES:
        h = HISTORIC_CITY_NAMES[base]
        return {"en": h, "tr": h}
    return {"en": p.get("name_en") or base, "tr": p.get("name_tr") or p.get("name_en") or base}


# şehir mimari stili (modern ülke koduna göre) — tools/blender/build_assets.py stilleriyle eşleşir
CITY_STYLE = {}
for _c in ["TUR", "SYR", "LBN", "ISR", "PSX", "WSB", "JOR", "IRQ", "IRN", "SAU", "KWT", "QAT", "ARE", "BHR", "OMN",
           "YEM", "EGY", "LBY", "TUN", "DZA", "MAR", "SAH", "MRT", "MLI", "NER", "TCD", "SDN", "AZE", "TKM", "UZB",
           "KAZ", "KGZ", "TJK", "AFG", "PAK", "CYN", "KOS"]:
    CITY_STYLE[_c] = "orient"
for _c in ["RUS", "UKR", "BLR", "MDA", "BGR", "SRB", "MKD", "MNE", "GEO", "ARM", "ROU"]:
    CITY_STYLE[_c] = "east"
for _c in ["SWE", "NOR", "FIN", "DNK", "ISL", "FRO", "ALD", "EST"]:
    CITY_STYLE[_c] = "nordic"


def vp_for_pop(pop):
    for limit, vp in [(2_500_000, 30), (1_000_000, 15), (500_000, 10), (250_000, 5), (120_000, 3), (60_000, 1)]:
        if pop >= limit:
            return vp
    return 0


def build_cities(P, S, lab, feats, types, river_d):
    log("şehirler yerleştiriliyor")
    land = S > 0
    sea = np.zeros(int(P.max()) + 1, bool)
    for k, t in types.items():
        if t == "sea":
            sea[k] = True
    sea_dist = edt_wrap(~sea[P])
    out = []
    for f in json.load(open(CACHE / "ne_10m_populated_places.geojson"))["features"]:
        p = {k.lower(): v for k, v in f["properties"].items()}
        lon, lat = p["longitude"], p["latitude"]
        x, y = project(np.array([lon]), np.array([lat]))
        x, y = int(x[0]), int(y[0])
        if not (0 <= x < W and 0 <= y < H):
            continue
        if not land[y, x]:
            # kıyıdaki şehirler rasterizasyonda denize düşebilir: en yakın kara pikseli
            y0, y1, x0, x1 = max(y - 6, 0), min(y + 7, H), max(x - 6, 0), min(x + 7, W)
            yy, xx = np.nonzero(land[y0:y1, x0:x1])
            if len(yy) == 0:
                continue
            k = int(np.argmin((yy + y0 - y) ** 2 + (xx + x0 - x) ** 2))
            y, x = int(yy[k] + y0), int(xx[k] + x0)
        pop = int((p.get("pop_max") or 0) * POP_1936_FACTOR.get(p.get("adm0_a3"), 0.25 if float(theater(lon, lat)) > 1.5 else 0.55))
        if pop < CITY_MIN_POP_1936 * min(float(theater(lon, lat)), 3.0) and not p.get("adm0cap"):
            continue
        region = int(lab[y, x])
        out.append({
            "name": p["name"].replace("  ", " "), "names": city_names(p), "pos": [x, y], "province": int(P[y, x]), "state": int(S[y, x]),
            "pop": pop, "adm0cap": bool(p.get("adm0cap")), "style": CITY_STYLE.get(p.get("adm0_a3")) or next((st_ for x0_, y0_, x1_, y1_, st_ in CITY_STYLE_REGION if x0_ <= lon <= x1_ and y0_ <= lat <= y1_), "west"),
            "region": feats[region - 1]["name"] if region > 0 else None,
            "region_names": feats[region - 1]["names"] if region > 0 else None,
            # kıyı limanı ya da denize yakın büyük nehir üzerindeki liman (Hamburg, Anvers, Rouen...)
            "port": bool(pop >= 40000 and (sea_dist[y, x] < 10 or (sea_dist[y, x] < 50 and river_d[y, x] < 3))),
        })
    out.sort(key=lambda c: -c["pop"])
    # aynı bölgede aynı adlı yinelenen kayıtları at
    seen = set()
    uniq = []
    for c in out:
        key = (c["province"], c["name"])
        near_dup = any(u["names"]["tr"] == c["names"]["tr"] and (u["pos"][0] - c["pos"][0]) ** 2 + (u["pos"][1] - c["pos"][1]) ** 2 < 40 ** 2 for u in uniq)
        if key not in seen and not near_dup:
            seen.add(key)
            uniq.append(c)
    for c in uniq:
        c["vp"] = vp_for_pop(c["pop"])
    log(f"  {len(uniq)} şehir, {sum(c['port'] for c in uniq)} liman")
    return uniq


def rename_states(states, cities):
    """Birleştirilmiş/bölünmüş eyaletleri en büyük şehirlerine göre adlandırır."""
    best = {}
    for c in cities:
        if c["state"] and c["state"] not in best:
            best[c["state"]] = c  # nüfusa göre sıralı; ilk görülen en büyüğü
    renamed = 0
    for sid, s in enumerate(states, 1):
        c = best.get(sid)
        if c is None:
            continue
        split = s["name"].rsplit(" ", 1)[-1] in {"I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"}
        if split and c["pop"] >= 20000:
            s["name"] = c["name"]
            s["names"] = dict(c["names"])
        elif len(s["regions"]) > 1:
            if c["pop"] >= 150_000 or c["region"] not in s["regions"]:
                s["name"] = c["name"]
                s["names"] = dict(c["names"])
            else:
                s["name"] = c["region"]
                s["names"] = dict(c["region_names"])
        else:
            continue
        renamed += 1
    for st in states:
        base = st["name"]
        if base in STATE_NAME_OVERRIDES:
            st["names"] = dict(STATE_NAME_OVERRIDES[base])
        elif base in HISTORIC_CITY_NAMES:
            st["names"] = {"en": HISTORIC_CITY_NAMES[base], "tr": HISTORIC_CITY_NAMES[base]}
    log(f"  {renamed} eyalet yeniden adlandırıldı")


# ---------------------------------------------------------------- 5) arazi türü
FOREST_THRESHOLD = 11.0  # NE1: G - max(R, B); tarım ~0-5, karışık ~10, orman 15+

MARSH_BOXES = [  # (boylam0, enlem0, boylam1, enlem1): bilinen büyük bataklıklar
    (-58.5, -19.5, -55.5, -16.0),  # Pantanal
    (29.5, 6.0, 32.0, 9.5),        # Sudd
    (22.0, -20.0, 23.8, -18.5),    # Okavango
    (-81.5, 25.1, -80.3, 26.6),    # Everglades
    (88.0, 21.5, 90.0, 22.5),      # Sundarban
    (23.5, 51.0, 31.0, 53.0),   # Pripyat / Polesya
    (28.4, 44.7, 29.8, 45.5),   # Tuna deltası
    (11.9, 44.6, 12.6, 45.2),   # Po deltası
    (45.8, 30.3, 48.0, 32.2),   # Mezopotamya bataklıkları
    (41.4, 41.8, 42.4, 42.5),   # Kolhis
]


def classify_terrain(rgb, ne1, elev, slope, lon, lat, P, n):
    log("arazi türleri sınıflandırılıyor (yükseklik + eğim)")
    lab = P.ravel()
    cnt = np.maximum(np.bincount(lab, minlength=n), 1)

    def mean(a):
        return np.bincount(lab, weights=a.ravel().astype(np.float64), minlength=n) / cnt

    r, g = rgb[..., 0], rgb[..., 1]
    green = mean(g - r)
    forest = mean(ne1[..., 1] - np.maximum(ne1[..., 0], ne1[..., 2]))
    el = mean(elev)
    el_sd = np.sqrt(np.maximum(mean(elev.astype(np.float64) ** 2) - el ** 2, 0))
    slp = mean(slope)
    la = mean(lat)
    lo = mean(lon)
    out = {}
    for i in range(1, n):
        if slp[i] > 0.06 or (el[i] > 1500 and el_sd[i] > 220):
            t = "mountain"
        elif slp[i] > 0.035 or el_sd[i] > 180:
            t = "hills"
        elif green[i] < -4 and abs(la[i]) < 42:
            t = "desert"
        elif slp[i] < 0.01 and el[i] < 220 and any(b[0] <= lo[i] <= b[2] and b[1] <= la[i] <= b[3] for b in MARSH_BOXES):
            t = "marsh"
        elif forest[i] > FOREST_THRESHOLD:
            t = "forest"
        else:
            t = "plains"
        out[i] = t
    return out


# ---------------------------------------------------------------- 6) sea & terrain görseli
def paint_terrain(rgb, ne1, sr, elev, land):
    log("terrain.png boyanıyor")
    # HYP rengindeki eski (bulanık) gölgeyi çıkar, yüksek çözünürlüklü DEM gölgesiyle değiştir
    sr_rel = np.clip(ndimage.gaussian_filter(sr, 1.0) / 206.0, 0.55, 1.25)[..., None]
    hyp_t = np.clip(rgb / sr_rel, 0, 255)
    ne1_t = np.clip(ne1 / sr_rel, 0, 255)
    lum = ne1_t.mean(-1, keepdims=True)
    ne1_t = (lum + (ne1_t - lum) * 1.9) * 0.86          # soluk NE1 renklerini canlandır
    tint = ndimage.gaussian_filter(ne1_t * 0.7 + hyp_t * 0.3, (1.2, 1.2, 0))
    shade = hillshade(elev, 5.0)[..., None]
    # gerçek zamanlı ışık kabartmayı gösterdiği için gömülü gölge hafif tutulur (uzak zoom okunurluğu için biraz kalır)
    landc = tint * (0.62 + 0.38 * shade)
    landc = (landc - 128) * 1.12 + 122

    water = ~land
    # su tonu: L = derinlik (0 sığ .. 1 derin), A = deniz tabanı gölgesi / 1.6  -> renk shader'da
    depth = np.maximum(-elev, 0.0)
    t = np.clip(np.log1p(depth / 25.0) / math.log1p(4500 / 25.0), 0, 1)
    rng = np.random.default_rng(7)
    t = np.clip(t + smooth_noise(water.shape, 2, rng) * 0.006, 0, 1)
    seabed = np.clip(0.85 + 0.15 * np.clip(hillshade(np.minimum(elev, 0), 2.0), 0, 1.6), 0, 1.6) / 1.6
    # kıyıda iki tarafın rengi birbirine taşmasın: her doku kendi tarafını karşıya "uzatır"
    idx_land = edt_wrap(water, return_indices=True)
    landc = landc[idx_land[0], idx_land[1]]
    idx_water = edt_wrap(land, return_indices=True)
    t = t[idx_water[0], idx_water[1]]
    seabed = seabed[idx_water[0], idx_water[1]]
    water_img = np.stack([t * 255, seabed * 255], -1)
    return np.clip(landc, 0, 255).astype(np.uint8), np.clip(water_img, 0, 255).astype(np.uint8)


# ---------------------------------------------------------------- 7) biyom ve ağaçlar (yakın zoom detayları)
CITY_FOOTPRINT = {"capital": 16.5, "large": 13.5, "medium": 9.5, "town": 6.5}   # city_layer_3d.gd ile aynı


def city_size(c):
    if c["capital"]:
        return "capital"
    return "large" if c["vp"] >= 10 else "medium" if c["vp"] >= 3 else "town"


def build_biome_and_trees(rgb, ne1, elev, lat, land, hab, cities, rng):
    """biome.png (yarım çözünürlük, RGBA = orman, tarla, çöl, bozkır) ve trees.bin (x, z, ölçek, tür)."""
    log("biyom haritası ve ağaçlar")
    green = rgb[..., 1] - rgb[..., 0]
    forest = np.clip((ne1[..., 1] - np.maximum(ne1[..., 0], ne1[..., 2]) - 6.0) / 12.0, 0, 1)
    desert = np.clip((-green - 2.0) / 10.0, 0, 1) * (np.abs(lat) < 44)
    steppe = np.clip((8.0 - green) / 12.0, 0, 1) * (1 - desert)
    farm = np.clip(hab * 1.3, 0, 1) * (1 - forest) * (1 - desert) * (1 - 0.6 * steppe)
    w = [ndimage.gaussian_filter(np.where(land, a, 0).astype(np.float32), 1.5) for a in (forest, farm, desert, steppe)]
    half = [a[: H // 2 * 2, : W // 2 * 2].reshape(H // 2, 2, W // 2, 2).mean((1, 3)) for a in w]
    Image.fromarray(np.clip(np.stack(half, -1) * 255, 0, 255).astype(np.uint8), "RGBA").save(OUT / "biome.png")

    # ağaçlar: titreşimli ızgara; olasılık orman ağırlığına (tarlada çit ağaçları) bağlı
    step = 2.0
    gy, gx = np.mgrid[0:H:step, 0:W:step]
    px = (gx + rng.random(gx.shape) * step).ravel()
    py = (gy + rng.random(gy.shape) * step).ravel()
    ix = np.clip(px.astype(int), 0, W - 1)
    iy = np.clip(py.astype(int), 0, H - 1)
    f = w[0][iy, ix]
    # kümelenme: orman içinde açıklıklar, ağaçlar gruplar halinde
    clump = smooth_noise((H // 4 + 1, W // 4 + 1), 2.0, rng)[iy // 4, ix // 4]
    cl = np.clip(0.75 + clump * 0.45, 0, 1)
    prob = np.clip(f, 0, 1) ** 1.3 * cl + w[1][iy, ix] * 0.006 * (clump > 0.8) * 6 + np.clip(1 - f - w[1][iy, ix] - w[2][iy, ix] - w[3][iy, ix], 0, 1) * 0.02 * cl
    # uzak bölgelerde seyrek (performans): yoğunluk / bölge çarpanı
    tf = theater(np.asarray(unproject(px, py)[0]), ROW_LAT[iy])
    prob = prob / np.maximum(tf, 1.0) ** 0.9
    keep = land[iy, ix] & (rng.random(px.shape) < prob) & (elev[iy, ix] < 2600)
    # şehirlerin altı boş
    city_mask = Image.new("L", (W, H), 0)
    cdraw = ImageDraw.Draw(city_mask)
    for c in cities:
        r = CITY_FOOTPRINT[city_size(c)] * 1.15
        cdraw.ellipse([c["pos"][0] - r, c["pos"][1] - r, c["pos"][0] + r, c["pos"][1] + r], fill=255)
    keep &= np.asarray(city_mask)[iy, ix] == 0
    px, py = px[keep], py[keep]
    la = lat[iy[keep], ix[keep]]
    el = elev[iy[keep], ix[keep]]
    conifer_p = np.clip((np.abs(la) - 50.0) / 10.0, 0, 1) * 0.8 + np.clip((el - 700.0) / 900.0, 0, 1) * 0.7
    kind = (rng.random(px.shape) < conifer_p).astype(np.float32)          # 0 yaprak döken, 1 iğne yapraklı
    kind += rng.integers(0, 3, px.shape) * 2                                # 3 varyant: tür = varyant*2 + iğne
    scale = rng.uniform(0.75, 1.3, px.shape) * np.where(w[0][iy[keep], ix[keep]] > 0.4, 1.0, 0.8)
    np.stack([px, py, scale, kind], 1).astype("<f4").tofile(OUT / "trees.bin")
    log(f"  {len(px)} ağaç")


# ---------------------------------------------------------------- ana akış
def main():
    rng = np.random.default_rng(SEED)
    OUT.mkdir(parents=True, exist_ok=True)
    countries = json.load(open(COUNTRIES))["countries"]
    log(f"harita {W}x{H}, ekvatorda {KM_PER_PX:.3f} km/px, 50°K'de {KM_PER_PX * math.cos(math.radians(50)):.3f} km/px")

    rgb, ne1, sr, lon, lat = build_terrain()
    elev = build_dem(lon, lat)
    slope = slope_map(elev)
    hab = np.clip((rgb[..., 1] - rgb[..., 0] + 15.0) / 40.0, 0.05, 1.0)
    hab *= np.clip(1.0 - (np.abs(lat) - 60.0) / 10.0, 0.15, 1.0)

    lab, feats = rasterize_regions()
    lake_mask = rasterize_lakes()
    lab[lake_mask] = 0
    carve_channels(lab)
    S, states = build_states(lab, feats, hab, rng)
    land = S > 0

    P, prov_state, warp_x, warp_y = build_provinces(S, states, hab, lat, rng)
    types = {i: "land" for i in prov_state}
    types.update(build_sea(P, land, lake_mask, warp_x, warp_y, rng, max(prov_state) + 1))
    # dolgu sonrası kara maskesini güncelle (küçük boşluklar karaya katıldı)
    split_disconnected(P, prov_state, types)
    n_prov = int(P.max()) + 1
    # eyalet haritasını bölgelerden yeniden türet (dolgu ve düzeltmeler dahil)
    ps = np.zeros(n_prov, np.int32)
    for i in range(1, n_prov):
        if types.get(i) == "land":
            ps[i] = prov_state.get(i, 0)
    S = ps[P]
    land = S > 0

    terrain_type = classify_terrain(rgb, ne1, elev, slope, lon, lat, P, n_prov)
    for i, t in types.items():
        if t != "land":
            terrain_type[i] = "ocean" if t == "sea" else "lake"

    # ---- görsel dokular
    terrain_img, water_img = paint_terrain(rgb, ne1, sr, elev, land)
    Image.fromarray(terrain_img, "RGB").save(OUT / "terrain.png", optimize=False)
    Image.fromarray(water_img, "LA").save(OUT / "water.png", optimize=False)
    # 3D arazi için yükseklik: yarım çözünürlük, float32 ham (metre; su yüzeyi 0)
    hm = np.where(land, np.maximum(elev, 0.0), 0.0).astype(np.float32)
    hm = ndimage.gaussian_filter(hm, 1.0)
    hm = hm[: H // 2 * 2, : W // 2 * 2].reshape(H // 2, 2, W // 2, 2).mean((1, 3)).astype("<f4")
    import gzip
    with gzip.open(OUT / "heightmap.r32.gz", "wb", compresslevel=6) as fz:
        fz.write(hm.tobytes())
    log(f"  heightmap.r32.gz {hm.shape[1]}x{hm.shape[0]}, maks {hm.max():.0f} m")
    ids = P.astype(np.uint32)
    prov_img = np.stack([(ids & 255), (ids >> 8) & 255, (ids >> 16) & 255], -1).astype(np.uint8)
    Image.fromarray(prov_img, "RGB").save(OUT / "provinces.png")

    log("sınır mesafe alanları")
    b_prov = encode_dist(boundary_mask(P, P > 0))
    b_state = encode_dist(boundary_mask(S, land))
    # kıyı: işaretli mesafe (kara +, su -), 128 merkezli, 1/8 texel -> doğrusal süzgeçle pürüzsüz kıyı çizgisi
    d_in = edt_wrap(land) - 0.5
    d_out = edt_wrap(~land) - 0.5
    sd = np.where(land, d_in, -d_out)
    b_coast = np.clip(128.0 + sd * 8.0, 0, 255).astype(np.uint8)
    # nehirler: kenara işaretli mesafe (texel), +2 kaydırmalı, 1/8 birim
    river_masks = rasterize_rivers()
    river_d = np.full((H, W), 99.0, np.float32)
    crossing_d = np.full((H, W), 99.0, np.float32)
    for (max_rank, half_w), m in zip(RIVER_CLASSES, river_masks):
        d = edt_wrap(~m).astype(np.float32)
        river_d = np.minimum(river_d, d - half_w)
        if max_rank <= RIVER_CROSSING_MAX_RANK:
            crossing_d = np.minimum(crossing_d, d)
    river_d[~land] = 99.0
    b_river = np.clip((river_d + 2.0) * 8.0, 0, 255).astype(np.uint8)
    Image.fromarray(np.stack([b_prov, b_state, b_coast, b_river], -1), "RGBA").save(OUT / "borders.png")

    # nehir geçişleri: sınır piksellerinin nehre yakın olduğu kara komşulukları
    near = crossing_d < 1.6
    river_pairs = defaultdict(int)
    for a_, b_, n_ in [(P[:, :-1], P[:, 1:], near[:, :-1] | near[:, 1:]), (P[:-1, :], P[1:, :], near[:-1, :] | near[1:, :])]:
        m = (a_ != b_) & land_of(a_, types) & land_of(b_, types) & n_
        for x, y in zip(a_[m].tolist(), b_[m].tolist()):
            river_pairs[(min(x, y), max(x, y))] += 1
    river_adj = defaultdict(set)
    for (x, y), c in river_pairs.items():
        if c >= 3:
            river_adj[x].add(y)
            river_adj[y].add(x)
    log(f"  {sum(len(v) for v in river_adj.values()) // 2} nehir geçişi")

    # ---- istatistikler
    log("istatistikler ve JSON")
    flat = P.ravel()
    cnt = np.bincount(flat, minlength=n_prov)
    area_p = np.bincount(flat, weights=np.repeat(ROW_AREA.astype(np.float64), W), minlength=n_prov)
    edges = adjacency(P)
    adj = defaultdict(set)
    for a, b, c in edges:
        adj[a].add(b)
        adj[b].add(a)
    # etiket noktası: sınıra en uzak piksel
    dist_in = ndimage.distance_transform_edt(~boundary_mask(P))
    centers = ndimage.maximum_position(dist_in, labels=P, index=np.arange(1, n_prov))
    # nüfus ağırlığı
    adm0_of_state = {i + 1: s["adm0"] for i, s in enumerate(states)}
    hab_p = np.bincount(flat, weights=hab.ravel(), minlength=n_prov)

    straits = build_straits(P, types)
    strait_adj = defaultdict(set)
    for st_ in straits:
        if not st_["land_crossing"]:
            continue
        a_, b_ = st_["provinces"]
        strait_adj[a_].add(b_)
        strait_adj[b_].add(a_)
    json.dump({"straits": straits}, open(OUT / "straits.json", "w"), ensure_ascii=False, indent=1)

    provinces = []
    for i in range(1, n_prov):
        if cnt[i] == 0:
            continue
        t = types.get(i, "land")
        cy, cx = centers[i - 1]
        coastal = t == "land" and any(types.get(j) == "sea" for j in adj[i])
        c_lo, c_la = unproject(cx, cy)
        provinces.append({
            "id": i, "type": t, "terrain": terrain_type.get(i, "plains"),
            "state": int(ps[i]) if t == "land" else 0,
            "coastal": bool(coastal), "center": [int(cx), int(cy)],
            "river_adj": sorted(int(j) for j in river_adj[i]),
            "strait_adj": sorted(int(j) for j in strait_adj[i]),
            "area_km2": int(area_p[i]), "adj": sorted(int(j) for j in adj[i]),
            "ll": [round(float(c_lo), 3), round(float(c_la), 3)],
        })

    cities = build_cities(P, S, lab, feats, types, crossing_d)
    rename_states(states, cities)

    # eyalet nüfusları: modern ülke nüfusu; yarısı yaşanabilirliğe, yarısı şehir nüfusuna göre dağıtılır
    hab_w = defaultdict(float)
    for p in provinces:
        if p["type"] == "land":
            hab_w[p["state"]] += hab_p[p["id"]] * (1.6 if p["coastal"] else 1.0)
    city_w = defaultdict(float)
    for c in cities:
        if c["state"]:
            city_w[c["state"]] += c["pop"]
    adm0_hab = defaultdict(float)
    adm0_city = defaultdict(float)
    for sid in hab_w:
        adm0_hab[adm0_of_state[sid]] += hab_w[sid]
        adm0_city[adm0_of_state[sid]] += city_w[sid]
    st_w = {}
    adm0_w = defaultdict(lambda: 1.0)
    for sid in hab_w:
        a = adm0_of_state[sid]
        share_h = hab_w[sid] / max(adm0_hab[a], 1e-9)
        share_c = city_w[sid] / adm0_city[a] if adm0_city[a] > 0 else share_h
        st_w[sid] = 0.5 * share_h + 0.5 * share_c
    s_cnt = np.bincount(S.ravel(), minlength=len(states) + 1)
    s_area = np.bincount(S.ravel(), weights=np.repeat(ROW_AREA.astype(np.float64), W), minlength=len(states) + 1)
    s_dist = ndimage.distance_transform_edt(~boundary_mask(S))
    s_centers = ndimage.maximum_position(s_dist, labels=S, index=np.arange(1, len(states) + 1))
    state_provs = defaultdict(list)
    for p in provinces:
        if p["type"] == "land":
            state_provs[p["state"]].append(p["id"])

    out_states = []
    for sid, s in enumerate(states, 1):
        if s_cnt[sid] == 0 or not state_provs[sid]:
            continue
        pop = POP1936.get(s["adm0"], 0.1) * 1e6 * st_w.get(sid, 0.0)
        cy, cx = s_centers[sid - 1]
        out_states.append({
            "id": sid, "name": s["name"], "names": s["names"], "owner": s["owner"], "adm0": s["adm0"],
            "provinces": sorted(state_provs[sid]), "population": int(pop),
            "area_km2": int(s_area[sid]), "center": [int(cx), int(cy)],
        })

    # başkentler (eyalet)
    caps = {}
    for tag, (lo, la) in CAPITALS.items():
        x, y = project(np.array([lo]), np.array([la]))
        x, y = int(x[0]), int(y[0])
        best = None
        for r in range(0, 40, 2):
            y0, y1, x0, x1 = max(y - r, 0), min(y + r + 1, H), max(x - r, 0), min(x + r + 1, W)
            win = S[y0:y1, x0:x1]
            ok = [int(v) for v in np.unique(win) if v > 0 and states[v - 1]["owner"] == tag]
            if ok:
                best = ok[0]
                break
        if best:
            caps[tag] = best
    for tag in countries:
        if tag not in caps:
            own = [s for s in out_states if s["owner"] == tag]
            if own:
                caps[tag] = max(own, key=lambda s: s["population"])["id"]

    # başkent şehirleri ve zafer puanları
    owner_of_state = {st["id"]: st["owner"] for st in out_states}
    for c in cities:
        c["capital"] = False
    for tag, sid in caps.items():
        in_state = [c for c in cities if c["state"] == sid]
        if not in_state:
            continue
        cap = next((c for c in in_state if c["adm0cap"]), in_state[0])
        cap["capital"] = True
        cap["port"] = cap["port"] or False
        cap["vp"] = MAJOR_CAPITAL_VP if tag in MAJORS else max(cap["vp"], 20)
    city_out = []
    for i, c in enumerate(cities, 1):
        if not c["state"] or c["state"] not in owner_of_state:
            continue
        city_out.append({"id": i, "name": c["name"], "names": c["names"], "province": c["province"], "state": c["state"],
                         "pos": c["pos"], "pop": c["pop"], "vp": c["vp"], "capital": c["capital"], "port": c["port"], "style": c["style"]})
    json.dump({"cities": city_out}, open(OUT / "cities.json", "w"), ensure_ascii=False, indent=0)
    build_biome_and_trees(rgb, ne1, elev, lat, land, hab, city_out, rng)

    meta = {"width": W, "height": H, "km_per_px": KM_PER_PX, "heightmap_size": [W // 2, H // 2],
            "projection": {"type": "miller", "lon_min": LON_MIN, "lat_top": LAT_TOP, "lat_bot": LAT_BOT,
                           "y_top": Y_TOP, "px_per_rad": PX_PER_RAD, "wrap": True}}
    json.dump({**meta, "provinces": provinces}, open(OUT / "provinces.json", "w"), ensure_ascii=False, separators=(",", ":"))
    json.dump({"capitals": caps, "states": out_states}, open(OUT / "states.json", "w"), ensure_ascii=False, indent=1)
    with open(OUT / "definition.csv", "w", newline="") as fh:
        w = csv.writer(fh, delimiter=";")
        for p in provinces:
            i = p["id"]
            w.writerow([i, i & 255, (i >> 8) & 255, (i >> 16) & 255, p["type"], str(p["coastal"]).lower(), p["terrain"]])

    owners = defaultdict(int)
    for s in out_states:
        owners[s["owner"]] += 1
    missing = [t for t in countries if t not in owners]
    log(f"bitti: {len(provinces)} bölge, {len(out_states)} eyalet. Eyaletsiz ülkeler: {missing}")


if __name__ == "__main__":
    main()
