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
OUT = ROOT / "data" / "map"
COUNTRIES = ROOT / "data" / "common" / "countries.json"

# ---------------------------------------------------------------- projeksiyon
R_EARTH = 6371.0
LON0, LAT0 = math.radians(25.0), math.radians(50.0)
W = 5120
X_MIN, X_MAX = -3150.0, 3150.0  # km
Y_MIN, Y_MAX = -2900.0, 2450.0
KM_PER_PX = (X_MAX - X_MIN) / W
H = int(round((Y_MAX - Y_MIN) / KM_PER_PX))
PX_AREA = KM_PER_PX ** 2

# ---------------------------------------------------------------- ayarlar
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


def log(msg, t0=[time.time()]):
    print(f"[{time.time() - t0[0]:7.1f}s] {msg}", flush=True)


# ---------------------------------------------------------------- projeksiyon fonksiyonları
def project(lon, lat):
    """derece -> piksel (float)."""
    lam, phi = np.radians(lon), np.radians(lat)
    k = np.sqrt(2.0 / (1.0 + math.sin(LAT0) * np.sin(phi) + math.cos(LAT0) * np.cos(phi) * np.cos(lam - LON0)))
    x = R_EARTH * k * np.cos(phi) * np.sin(lam - LON0)
    y = R_EARTH * k * (math.cos(LAT0) * np.sin(phi) - math.sin(LAT0) * np.cos(phi) * np.cos(lam - LON0))
    return (x - X_MIN) / KM_PER_PX, (Y_MAX - y) / KM_PER_PX


def unproject(px, py):
    """piksel -> (boylam, enlem) derece."""
    x = (X_MIN + (px + 0.5) * KM_PER_PX) / R_EARTH
    y = (Y_MAX - (py + 0.5) * KM_PER_PX) / R_EARTH
    rho = np.maximum(np.sqrt(x * x + y * y), 1e-12)
    c = 2.0 * np.arcsin(np.clip(rho / 2.0, -1, 1))
    lat = np.arcsin(np.cos(c) * math.sin(LAT0) + y * np.sin(c) * math.cos(LAT0) / rho)
    lon = LON0 + np.arctan2(x * np.sin(c), rho * math.cos(LAT0) * np.cos(c) - y * math.sin(LAT0) * np.sin(c))
    return np.degrees(lon), np.degrees(lat)


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
    return m


def encode_dist(mask):
    d = ndimage.distance_transform_edt(~mask) + 0.5
    return np.clip(d * 8.0, 0, 255).astype(np.uint8)


def adjacency(lab):
    """Etiket çiftleri ve ortak sınır uzunlukları."""
    a = np.concatenate([lab[:, :-1].ravel(), lab[:-1, :].ravel()])
    b = np.concatenate([lab[:, 1:].ravel(), lab[1:, :].ravel()])
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


def build_dem(lon, lat):
    """Web Mercator Terrarium karolarından harita projeksiyonuna yükseklik (metre)."""
    log("yükseklik mozaiği örnekleniyor")
    d = CACHE / "dem" / str(DEM_ZOOM)
    tiles = {}
    for f in d.glob("*.png"):
        x, y = f.stem.split("_")
        tiles[(int(x), int(y))] = f
    xs = [k[0] for k in tiles]
    ys = [k[1] for k in tiles]
    x0, y0 = min(xs), min(ys)
    mos = np.zeros(((max(ys) - y0 + 1) * 256, (max(xs) - x0 + 1) * 256), np.float32)
    for (x, y), f in tiles.items():
        a = np.asarray(Image.open(f).convert("RGB"), dtype=np.float32)
        mos[(y - y0) * 256:(y - y0 + 1) * 256, (x - x0) * 256:(x - x0 + 1) * 256] = \
            a[..., 0] * 256.0 + a[..., 1] + a[..., 2] / 256.0 - 32768.0
    n = (2 ** DEM_ZOOM) * 256
    gx = (lon.astype(np.float64) + 180.0) / 360.0 * n - x0 * 256 - 0.5
    r = np.radians(np.clip(lat.astype(np.float64), -85, 85))
    gy = (1.0 - np.log(np.tan(r) + 1.0 / np.cos(r)) / math.pi) / 2.0 * n - y0 * 256 - 0.5
    return ndimage.map_coordinates(mos, [gy, gx], order=3).astype(np.float32)


def hillshade(h, exaggeration=5.0):
    """Çok yönlü tepe gölgesi; düz arazi = 1.0."""
    m = KM_PER_PX * 1000.0
    hz = ndimage.gaussian_filter(h, 0.8)
    dy, dx = np.gradient(hz, m)
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
    dy, dx = np.gradient(ndimage.gaussian_filter(h, 0.8), KM_PER_PX * 1000.0)
    return np.sqrt(dx * dx + dy * dy).astype(np.float32)


# ---------------------------------------------------------------- 1b) arazi rengi
def build_terrain():
    """HYP (iklim tonu), NE1 (arazi örtüsü) ve SR (eski gölge) raster'larını harita projeksiyonuna örnekler."""
    log("arazi raster'ları örnekleniyor")
    ys, xs = np.mgrid[0:H, 0:W]
    lon, lat = unproject(xs.astype(np.float64), ys.astype(np.float64))
    # kaynak raster koordinatları (30 px / derece)
    col = (lon + 180.0) * 30.0 - 0.5
    row = (90.0 - lat) * 30.0 - 0.5
    c0, r0 = int(col.min()) - 4, int(row.min()) - 4
    c1, r1 = int(col.max()) + 4, int(row.max()) + 4
    coords = [row - r0, col - c0]

    def sample(path, channels):
        a = np.asarray(Image.open(path).crop((c0, r0, c1, r1)), dtype=np.float32)
        if channels == 1:
            return ndimage.map_coordinates(a, coords, order=1).astype(np.float32)
        return np.stack([ndimage.map_coordinates(a[..., i], coords, order=1) for i in range(3)], -1).astype(np.float32)

    hyp = sample(CACHE / "HYP_50M_SR_W.tif", 3)
    ne1 = sample(CACHE / "NE1_50M_SR_W" / "NE1_50M_SR_W.tif", 3)
    sr = sample(CACHE / "SR_50M.tif", 1)
    return hyp, ne1, sr, lon.astype(np.float32), lat.astype(np.float32)


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
        if ring[:, 0].max() < -35 or ring[:, 0].min() > 80 or ring[:, 1].max() < 12 or ring[:, 1].min() > 84:
            continue
        px, py = project(ring[:, 0], ring[:, 1])
        yield list(zip(px.tolist(), py.tolist()))


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
            area = 0.5 * abs(np.dot(a[:, 0], np.roll(a[:, 1], 1)) - np.dot(a[:, 1], np.roll(a[:, 0], 1))) * PX_AREA
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
            if ring[:, 0].max() < -35 or ring[:, 0].min() > 80 or ring[:, 1].max() < 12 or ring[:, 1].min() > 84:
                continue
            px, py = project(ring[:, 0], ring[:, 1])
            if px.max() < 0 or px.min() > W or py.max() < 0 or py.min() > H:
                continue
            pts_all.append(np.stack([px, py], 1))
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
    area = np.bincount(lab.ravel(), minlength=n).astype(np.float64)
    ys, xs = np.nonzero(lab)
    lv = lab[ys, xs]
    cx = np.bincount(lv, weights=xs, minlength=n) / np.maximum(area, 1)
    cy = np.bincount(lv, weights=ys, minlength=n) / np.maximum(area, 1)

    edges = adjacency(lab)
    parent = list(range(n))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    garea = area.copy()
    min_px = MIN_STATE_KM2 / PX_AREA
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
            if garea[r] >= min_px or r in merged:
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
    tiny_px = TINY_STATE_KM2 / PX_AREA
    big_roots = [r for r in roots if garea[r] >= tiny_px]
    for r in roots:
        if garea[r] < tiny_px:
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
        a_km2 = m.sum() * PX_AREA
        h = float(hab[sl][m].mean())
        limit = MAX_STATE_REMOTE_KM2 if h < 0.35 else MAX_STATE_KM2
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
        npx = len(yy)
        h = float(hab[sl][m].mean())
        la = float(lat[sl][m].mean())
        target = PROVINCE_KM2 * (1.0 + 2.8 * (1.0 - min(h, 1.0)) ** 1.5) * (1.8 if la > 61 else 1.0)
        k = int(np.clip(round(npx * PX_AREA / target), 1, 16))
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
    dist = ndimage.distance_transform_edt(water)
    types = {}
    nid = first_id
    lake_px = LAKE_MIN_KM2 / PX_AREA
    objs = ndimage.find_objects(comp)
    for c in range(1, ncomp + 1):
        sz = sizes[c]
        sl = objs[c - 1]
        yy, xx = np.nonzero(comp[sl] == c)
        yy, xx = yy + sl[0].start, xx + sl[1].start
        touches_edge = yy.min() == 0 or xx.min() == 0 or yy.max() == H - 1 or xx.max() == W - 1
        # göl yalnızca gerçek göl verisinden geliyorsa (Marmara gibi boğazla kopan denizler deniz kalır)
        lake_frac = lake_mask[yy, xx].mean()
        is_sea = touches_edge or (lake_frac < 0.5 and sz >= lake_px)
        if not is_sea and sz < lake_px:
            P[yy, xx] = -1  # karaya doldurulacak
            continue
        if not is_sea:
            P[yy, xx] = nid
            types[nid] = "lake"
            nid += 1
            continue
        # kıyıya yakın daha küçük bölgeler: örnekleri kıyı yakınında yoğunlaştır
        d = dist[yy, xx]
        prob = 1.0 / (1.0 + d / 60.0)
        k = max(1, int(round(sz * PX_AREA / SEA_PROVINCE_KM2 * 1.3)))
        pick = rng.random(len(yy)) < prob
        coords = np.stack([xx + warp_x[yy, xx] * 2, yy + warp_y[yy, xx] * 2], 1).astype(np.float32)
        samp = coords[pick]
        if len(samp) > 60000:
            samp = samp[rng.choice(len(samp), 60000, replace=False)]
        if k > 1 and len(samp) > k:
            cent, _ = kmeans2(samp.astype(np.float64), k, minit="++", iter=20, seed=rng)
            _, part = cKDTree(cent).query(coords)
        else:
            part = np.zeros(len(yy), np.int64)
        P[yy, xx] = nid + part
        for j in range(k):
            types[nid + j] = "sea"
        nid += k
    # küçük boşlukları en yakın kara bölgesiyle doldur
    hole = P < 0
    if hole.any():
        idx = ndimage.distance_transform_edt(P <= 0, return_distances=False, return_indices=True)
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
CITY_MIN_POP_1936 = 25000
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
    sea_dist = ndimage.distance_transform_edt(~sea[P])
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
        pop = int((p.get("pop_max") or 0) * POP_1936_FACTOR.get(p.get("adm0_a3"), 0.55))
        if pop < CITY_MIN_POP_1936 and not p.get("adm0cap"):
            continue
        region = int(lab[y, x])
        out.append({
            "name": p["name"].replace("  ", " "), "names": city_names(p), "pos": [x, y], "province": int(P[y, x]), "state": int(S[y, x]),
            "pop": pop, "adm0cap": bool(p.get("adm0cap")), "style": CITY_STYLE.get(p.get("adm0_a3"), "west"),
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
        elif green[i] < -4 and la[i] < 42:
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
    idx_land = ndimage.distance_transform_edt(water, return_distances=False, return_indices=True)
    landc = landc[idx_land[0], idx_land[1]]
    idx_water = ndimage.distance_transform_edt(land, return_distances=False, return_indices=True)
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
    desert = np.clip((-green - 2.0) / 10.0, 0, 1) * (lat < 44)
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
    keep = land[iy, ix] & (rng.random(px.shape) < prob) & (elev[iy, ix] < 2600)
    # şehirlerin altı boş
    for c in cities:
        r = CITY_FOOTPRINT[city_size(c)] * 1.15
        keep &= (px - c["pos"][0]) ** 2 + (py - c["pos"][1]) ** 2 > r * r
    px, py = px[keep], py[keep]
    la = lat[iy[keep], ix[keep]]
    el = elev[iy[keep], ix[keep]]
    conifer_p = np.clip((la - 50.0) / 10.0, 0, 1) * 0.8 + np.clip((el - 700.0) / 900.0, 0, 1) * 0.7
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
    log(f"harita {W}x{H}, {KM_PER_PX:.3f} km/px, {PX_AREA:.2f} km²/px")

    rgb, ne1, sr, lon, lat = build_terrain()
    elev = build_dem(lon, lat)
    slope = slope_map(elev)
    hab = np.clip((rgb[..., 1] - rgb[..., 0] + 15.0) / 40.0, 0.05, 1.0)
    hab *= np.clip(1.0 - (lat - 60.0) / 10.0, 0.15, 1.0)

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
    hm.tofile(OUT / "heightmap.r32")
    log(f"  heightmap.r32 {hm.shape[1]}x{hm.shape[0]}, maks {hm.max():.0f} m")
    ids = P.astype(np.uint32)
    prov_img = np.stack([(ids & 255), (ids >> 8) & 255, (ids >> 16) & 255], -1).astype(np.uint8)
    Image.fromarray(prov_img, "RGB").save(OUT / "provinces.png")

    log("sınır mesafe alanları")
    b_prov = encode_dist(boundary_mask(P, P > 0))
    b_state = encode_dist(boundary_mask(S, land))
    # kıyı: işaretli mesafe (kara +, su -), 128 merkezli, 1/8 texel -> doğrusal süzgeçle pürüzsüz kıyı çizgisi
    d_in = ndimage.distance_transform_edt(land) - 0.5
    d_out = ndimage.distance_transform_edt(~land) - 0.5
    sd = np.where(land, d_in, -d_out)
    b_coast = np.clip(128.0 + sd * 8.0, 0, 255).astype(np.uint8)
    # nehirler: kenara işaretli mesafe (texel), +2 kaydırmalı, 1/8 birim
    river_masks = rasterize_rivers()
    river_d = np.full((H, W), 99.0, np.float32)
    crossing_d = np.full((H, W), 99.0, np.float32)
    for (max_rank, half_w), m in zip(RIVER_CLASSES, river_masks):
        d = ndimage.distance_transform_edt(~m).astype(np.float32)
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
        provinces.append({
            "id": i, "type": t, "terrain": terrain_type.get(i, "plains"),
            "state": int(ps[i]) if t == "land" else 0,
            "coastal": bool(coastal), "center": [int(cx), int(cy)],
            "river_adj": sorted(int(j) for j in river_adj[i]),
            "strait_adj": sorted(int(j) for j in strait_adj[i]),
            "area_km2": int(cnt[i] * PX_AREA), "adj": sorted(int(j) for j in adj[i]),
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
            "area_km2": int(s_cnt[sid] * PX_AREA), "center": [int(cx), int(cy)],
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
            "projection": {"type": "laea", "lon0": 25.0, "lat0": 50.0,
                           "x_min": X_MIN, "y_max": Y_MAX}}
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
