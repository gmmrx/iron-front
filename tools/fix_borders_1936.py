#!/usr/bin/env python3
"""1936 sınır düzeltmeleri: üretilmiş haritayı (data/map) 1 Ocak 1936 sınırlarına piksel düzeyinde getirir.

Harita modern idari bölgelerden (Natural Earth admin-1) üretilir; 1936 sınırı bir idari bölgenin ortasından geçiyorsa
(Yukarı Silezya, Batı Belarus, Budjak, Karelya, Güney Sahalin, Kwantung...) bölge tablosu yetmez. Burada her düzeltme
1936 sınırını izleyen bir çokgendir: çokgenin içindeki, kaynak ülkeye ait kara pikselleri hedef ülkeye geçer.
    python3 tools/fix_borders_1936.py            # uygula (data/map)
    python3 tools/audit_1936.py                  # denetle (tests/data/borders_1936.json)
    python3 tools/assign_economy.py              # eyalet binaları/kaynakları yeni eyaletlere göre
    python3 tools/build_sea_lanes.py             # liman bölgesi değiştiyse deniz yolları

Kurallar:
- Var olan bölge ve eyalet kimlikleri korunur; yeni bölge/eyaletler sona eklenir (kayıtlar ve veriler bozulmaz).
- Sınırı kesen bölge bölünür; 16 pikselden küçük kırpıntı aynı taraftaki komşu bölgeye katılır (ince şerit kalmaz).
- Kaynak eyaletin bütün bölgeleri geçiyorsa eyalet korunur, yalnız sahibi değişir; kısmen geçiyorsa geçen parça yeni
  eyalet olur (ya da into_at ile hedefteki bir eyalete katılır).
- Tekrar çalıştırmak bir şey değiştirmez (çokgenin içinde kaynak ülkeye ait piksel kalmamıştır).
Sınır çizgileri 1 Ocak 1936 durumudur; nokta seçimleri tarihî sınır kasabalarının iki yanına göre yapılmıştır
(tests/data/borders_1936.json aynı kasabaları denetler).
"""
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_map as G  # noqa: E402  (projeksiyon, piksel alanı, mesafe alanı yardımcıları)

Image.MAX_IMAGE_PIXELS = None
ROOT = Path(__file__).resolve().parent.parent
MAP = ROOT / "data" / "map"
MIN_PIECE = 16          # bundan küçük parça ayrı bölge olmaz (komşuya katılır)

# ---------------------------------------------------------------- düzeltmeler
# name: yeni eyaletin adı (en, tr); src -> dst; poly: (boylam, enlem) köşeleri; exclude: çıkarılacak çokgen;
# mode "province": bölge merkezi çokgenin içindeyse bütün bölge (adalar); into_at: hedef eyalet bu noktadaki eyalet;
# names_by_src: kaynak eyalete göre ayrı yeni eyalet adları; pop: yeni eyaletin 1936 dolayı nüfusu (sayım ya da dönem
# tahmini: Danzig 1929 sayımı, Karafuto 1935 sayımı, Kanal Bölgesi 1930 sayımı, Portekiz Hindistanı 1940 sayımı...).
# Nüfus verilmezse kaynak eyaletin nüfusu alan ve şehir payıyla bölünür; küçük topraklarda şehir payı çok şişirir.
POMERANIA_WEST = [(15.5, 54.7), (18.03, 54.85), (17.97, 54.62), (17.90, 54.45), (17.72, 54.30), (17.70, 54.10),
                  (17.60, 53.95), (17.45, 53.80), (17.47, 53.62), (17.40, 53.55), (15.5, 53.55)]
GRENZMARK = [(15.5, 53.55), (17.40, 53.55), (17.35, 53.50), (17.25, 53.38), (17.15, 53.22), (16.95, 53.12),
             (16.75, 53.10), (16.60, 53.00), (16.30, 52.95), (16.05, 52.87), (15.90, 52.85), (15.5, 52.85)]
# İspanyol Fas'ı (kuzey bölgesi) güney sınırı: Arbaoua - Rif'in güneyi - Muluye nehri
SPANISH_ZONE = [(-6.40, 34.93), (-6.08, 34.93), (-5.60, 34.93), (-5.00, 34.95), (-4.50, 34.92), (-4.00, 34.90),
                (-3.50, 34.85), (-3.15, 34.80), (-2.85, 34.85), (-2.60, 34.95), (-2.40, 35.05), (-2.36, 35.10), (-2.36, 35.60),
                (-6.40, 36.10)]
TANGIER = [(-5.97, 35.62), (-5.97, 35.82), (-5.60, 35.86), (-5.52, 35.72), (-5.70, 35.62)]

FIXES = [
    # --- Almanya / Danzig / Polonya
    dict(name=("Stolp", "Stolp"), src="POL", dst="GER", poly=POMERANIA_WEST),
    dict(name=("Schneidemühl", "Schneidemühl"), src="POL", dst="GER", poly=GRENZMARK),
    dict(name=("Danzig", "Danzig"), src="POL", dst="DNZ", pop=408000,
         poly=[(18.45, 54.47), (18.62, 54.47), (19.00, 54.40), (19.30, 54.36), (19.30, 54.27), (19.12, 54.15),
               (18.98, 54.03), (18.88, 53.92), (18.82, 54.02), (18.80, 54.15), (18.60, 54.18), (18.45, 54.25),
               (18.40, 54.38)]),
    dict(name=("Marienwerder", "Marienwerder"), src="POL", dst="GER",
         poly=[(18.88, 53.92), (18.98, 54.03), (19.12, 54.15), (19.30, 54.27), (19.70, 54.30), (19.70, 53.62),
               (19.10, 53.60), (18.83, 53.62), (18.80, 53.75), (18.83, 53.85)]),
    dict(name=("Działdowo", "Działdowo"), src="GER", dst="POL",
         poly=[(19.30, 53.57), (19.45, 53.60), (19.65, 53.56), (19.85, 53.53), (20.05, 53.40), (20.35, 53.30),
               (20.45, 53.18), (20.30, 53.05), (19.30, 53.05)]),
    dict(name=("Gleiwitz", "Gleiwitz"), src="POL", dst="GER",
         poly=[(18.00, 49.90), (18.33, 49.93), (18.40, 50.05), (18.47, 50.15), (18.62, 50.24), (18.76, 50.27),
               (18.85, 50.31), (18.93, 50.33), (19.00, 50.345), (18.97, 50.38), (18.85, 50.39), (18.76, 50.42),
               (18.68, 50.52), (18.60, 50.62), (18.50, 50.75), (18.00, 50.75)]),
    # --- Polonya'nın doğu sınırı (1921 Riga)
    dict(name=("Wilejka", "Wilejka"), src="SOV", dst="POL",
         poly=[(25.5, 56.0), (27.60, 55.90), (28.15, 55.85), (28.45, 55.55), (28.30, 55.25), (28.05, 54.95),
               (27.90, 54.65), (27.40, 54.25), (27.18, 53.98), (27.07, 53.78), (25.5, 53.78)]),
    dict(name=("Nieśwież", "Nieśwież"), src="SOV", dst="POL",
         poly=[(25.5, 53.78), (27.07, 53.78), (26.95, 53.62), (27.00, 53.40), (27.05, 53.10), (27.10, 52.80),
               (27.25, 52.40), (27.40, 52.10), (27.50, 51.60), (25.5, 51.60)]),
    dict(name=("Druskieniki", "Druskieniki"), src="LIT", dst="POL",
         poly=[(23.60, 54.00), (23.90, 54.25), (24.30, 54.28), (24.60, 54.35), (24.90, 54.35), (25.00, 53.90),
               (23.60, 53.90)]),
    # --- Romanya / SSCB: Dinyester sınırı
    dict(name=("Tiraspol", "Tiraspol"), src="ROM", dst="SOV",
         poly=[(27.25, 48.47), (27.80, 48.42), (28.30, 48.15), (28.75, 47.95), (29.00, 47.75), (29.10, 47.45),
               (29.10, 47.30), (29.40, 46.97), (29.55, 46.86), (29.75, 46.55), (29.95, 46.60), (31.00, 46.60),
               (31.00, 48.60), (27.25, 48.60)]),
    dict(name=("Cetatea Albă", "Akkerman"), src="SOV", dst="ROM",
         poly=[(28.20, 46.00), (28.20, 45.20), (29.80, 45.20), (30.50, 45.90), (30.50, 46.08), (30.36, 46.25),
               (30.20, 46.35), (30.05, 46.45), (29.90, 46.50), (28.90, 46.50), (28.20, 46.40)]),
    # --- İtalya: Fiume, Carnaro adaları, Zara, Lagosta, Tenda, Onikiadalar
    dict(name=("Fiume", "Fiume"), src="YUG", dst="ITA", pop=70000,
         poly=[(14.10, 45.20), (14.10, 45.50), (14.40, 45.50), (14.47, 45.37), (14.46, 45.31), (14.30, 45.25)]),
    dict(name=("Cherso", "Cherso"), src="YUG", dst="ITA", mode="province",
         poly=[(14.20, 44.40), (14.20, 45.20), (14.46, 45.20), (14.50, 44.95), (14.60, 44.45)], into_at=(13.85, 44.87)),
    dict(name=("Zara", "Zara"), src="YUG", dst="ITA", pop=22000,
         poly=[(15.17, 44.08), (15.17, 44.16), (15.29, 44.16), (15.29, 44.08)]),
    dict(name=("Zara", "Zara"), src="YUG", dst="ITA",
         poly=[(16.65, 42.68), (16.65, 42.81), (17.00, 42.81), (17.00, 42.68)]),
    dict(name=("Tenda", "Tenda"), src="FRA", dst="ITA",
         poly=[(7.45, 44.00), (7.45, 44.20), (7.72, 44.17), (7.72, 44.03), (7.60, 43.98)], into_at=(7.55, 44.38)),
    dict(name=("Dodecanese", "Onikiadalar"), src="GRE", dst="ITA", pop=130000,
         poly=[(26.25, 36.45), (26.25, 36.70), (26.45, 37.10), (26.45, 37.42), (26.70, 37.42), (27.00, 37.30),
               (27.40, 37.05), (28.40, 36.60), (29.70, 36.20), (29.70, 35.30), (26.80, 35.30)]),
    # --- Finlandiya: Karelya Kıstağı, Ladoga Karelyası, Salla, Petsamo, Fin Körfezi adaları
    dict(name=("Viipuri", "Viipuri"), src="SOV", dst="FIN", pop=280000,
         poly=[(26.5, 59.95), (29.20, 59.95), (29.95, 60.13), (30.20, 60.28), (30.55, 60.38), (30.95, 60.45),
               (31.30, 60.85), (29.5, 61.25), (26.5, 61.25)]),
    dict(name=("Sortavala", "Sortavala"), src="SOV", dst="FIN", pop=100000,
         poly=[(29.5, 61.25), (31.30, 60.85), (31.95, 61.25), (32.15, 61.45), (32.45, 61.75), (32.90, 62.05),
               (32.70, 62.35), (32.00, 62.80), (31.60, 62.95), (31.00, 63.20), (29.5, 63.20)]),
    dict(name=("Salla", "Salla"), src="SOV", dst="FIN",
         poly=[(29.0, 66.30), (30.20, 66.35), (30.70, 66.65), (30.75, 67.05), (30.30, 67.35), (29.0, 67.40)],
         into_at=(28.66, 66.83)),
    dict(name=("Petsamo", "Petsamo"), src="SOV", dst="FIN", pop=4000,
         poly=[(28.3, 69.10), (28.5, 68.85), (29.3, 68.75), (30.2, 68.90), (31.0, 69.05), (31.7, 69.30),
               (32.1, 69.60), (32.3, 69.95), (31.5, 70.05), (28.3, 70.05)]),
    # --- Estonya / Letonya: Narva ötesi, Petseri, Abrene
    dict(name=("Jaanilinn", "Jaanilinn"), src="SOV", dst="EST",
         poly=[(27.9, 58.95), (27.9, 59.47), (28.20, 59.55), (28.42, 59.40), (28.35, 59.10), (28.0, 58.95)],
         into_at=(28.19, 59.38)),
    dict(name=("Petseri", "Petseri"), src="SOV", dst="EST", pop=61000,
         poly=[(27.30, 57.50), (27.30, 58.00), (27.60, 58.00), (27.95, 57.95), (28.15, 57.80), (28.10, 57.60),
               (27.80, 57.52)]),
    dict(name=("Abrene", "Abrene"), src="SOV", dst="LAT", pop=40000,
         poly=[(27.50, 56.85), (27.50, 57.30), (27.75, 57.35), (28.05, 57.25), (28.15, 57.05), (27.95, 56.85)]),
    # --- Japonya: Karafuto (50. paralelin güneyi), Kuriller (Chishima), Kwantung
    dict(name=("Karafuto", "Karafuto"), src="SOV", dst="JAP", pop=332000,
         poly=[(141.0, 45.8), (141.0, 50.0), (145.0, 50.0), (145.0, 45.8)]),
    dict(name=("Chishima", "Chishima"), src="SOV", dst="JAP", pop=12000, mode="province",
         poly=[(145.3, 43.3), (145.3, 44.6), (146.5, 45.5), (148.5, 46.4), (151.5, 48.0), (154.5, 49.6),
               (155.8, 50.60), (156.4, 50.86), (157.0, 50.80), (157.0, 50.3), (155.5, 49.3), (153.0, 47.8),
               (150.0, 46.2), (147.5, 44.8), (146.2, 43.4)]),
    dict(name=("Kwantung", "Kwantung"), src="MAN", dst="JAP", pop=1300000,
         poly=[(120.9, 38.6), (120.9, 39.45), (121.6, 39.55), (122.1, 39.45), (122.4, 39.20), (122.4, 38.6)]),
    # --- Mançukuo: Jehol ve Doğu İç Moğolistan (Hulunbuir, Hinggan, Tongliao, Chifeng); Çin Seddi sınırı
    dict(name=("Jehol", "Jehol"), src="CHI", dst="MAN",
         poly=[(119.80, 40.05), (119.20, 40.30), (118.60, 40.35), (118.00, 40.45), (117.30, 40.62), (116.70, 40.85),
               (116.20, 41.05), (116.00, 41.40), (116.25, 41.90), (116.90, 42.50), (117.40, 43.10), (117.90, 43.90),
               (118.60, 44.50), (119.40, 45.00), (120.00, 45.40), (119.95, 46.00), (119.95, 46.75), (119.30, 47.20),
               (117.50, 47.60), (115.30, 47.70), (115.30, 53.90), (127.5, 53.9), (127.5, 40.5), (121.0, 39.9)],
         names_by_src={"Xilingol": ("Chifeng", "Chifeng"), "Inner Mongol IV": ("Hulunbuir", "Hulunbuir"),
                       "Inner Mongol V": ("Hsingan", "Hsingan")}),
    # --- Fransa: Kwangchowan, Fransız Hindistanı; Portekiz Hindistanı
    dict(name=("Kwangchowan", "Kwangchowan"), src="CHI", dst="FRA", pop=250000,
         poly=[(110.15, 20.95), (110.15, 21.40), (110.55, 21.40), (110.60, 20.95)]),
    dict(name=("Pondichéry", "Pondichéry"), src="RAJ", dst="FRA", pop=250000,
         poly=[(79.70, 11.80), (79.70, 12.05), (79.90, 12.05), (79.90, 11.80)]),
    dict(name=("Pondichéry", "Pondichéry"), src="RAJ", dst="FRA",
         poly=[(79.72, 10.82), (79.72, 11.02), (79.90, 11.02), (79.90, 10.82)]),
    dict(name=("Goa", "Goa"), src="RAJ", dst="POR", pop=620000,
         poly=[(73.60, 14.88), (73.60, 15.80), (74.05, 15.80), (74.35, 15.40), (74.30, 14.90)]),
    dict(name=("Goa", "Goa"), src="RAJ", dst="POR",
         poly=[(70.85, 20.66), (70.85, 20.76), (71.10, 20.76), (71.10, 20.66)]),
    dict(name=("Goa", "Goa"), src="RAJ", dst="POR",
         poly=[(72.78, 20.33), (72.78, 20.48), (72.95, 20.48), (72.95, 20.33)]),
    # --- İngiliz Kamerunu (güney)
    dict(name=("Buea", "Buea"), src="FRA", dst="ENG",
         poly=[(8.5, 4.0), (9.55, 3.95), (9.60, 4.35), (9.75, 4.70), (9.90, 5.05), (10.10, 5.35), (10.45, 5.75),
               (10.75, 6.10), (11.00, 6.45), (11.20, 6.80), (11.0, 7.2), (8.5, 7.2)]),
    # --- Fas: İspanyol bölgesinin güney sınırı, Tanca, İfni, Cape Juby
    dict(name=("Nador", "Nador"), src="FRA", dst="SPR", poly=SPANISH_ZONE, into_at=(-2.94, 35.29)),
    dict(name=("Taza", "Taza"), src="SPR", dst="FRA",
         poly=[(-6.6, 33.8), (-1.5, 33.8), (-1.5, 35.4), (-6.6, 35.4)], exclude=SPANISH_ZONE),
    dict(name=("Tangier", "Tanca"), src="SPR", dst="TNG", pop=60000, poly=TANGIER),
    dict(name=("Ifni", "İfni"), src="FRA", dst="SPR", pop=30000,
         poly=[(-10.40, 29.20), (-10.40, 29.55), (-10.00, 29.55), (-9.95, 29.20)]),
    dict(name=("Cape Juby", "Cape Juby"), src="FRA", dst="SPR",
         poly=[(-13.5, 27.66), (-8.67, 27.66), (-8.67, 28.95), (-10.0, 28.85), (-11.15, 28.72), (-13.5, 28.72)],
         into_at=(-12.92, 27.94)),
    # --- Panama Kanal Bölgesi
    dict(name=("Canal Zone", "Kanal Bölgesi"), src="PAN", dst="USA", pop=40000, one_province=True,
         poly=[(-80.05, 9.40), (-79.85, 9.42), (-79.75, 9.20), (-79.55, 9.05), (-79.50, 8.93), (-79.60, 8.86),
               (-79.75, 9.05), (-79.95, 9.20)],
         exclude=[[(-79.58, 8.90), (-79.58, 9.02), (-79.40, 9.02), (-79.40, 8.90)],       # Panama şehri ve
                  [(-79.94, 9.32), (-79.94, 9.40), (-79.86, 9.40), (-79.86, 9.32)]]),      # Colón Panama'nın
    # --- yanlış eyalete katılmış küçük topraklar: kendi eyaletleri
    dict(name=("Gibraltar", "Cebelitarık"), src="ENG", dst="ENG", pop=20000, mode="province",
         poly=[(-5.45, 36.05), (-5.45, 36.20), (-5.25, 36.20), (-5.25, 36.05)]),
    dict(name=("Macau", "Makao"), src="POR", dst="POR", pop=160000,
         poly=[(113.40, 22.05), (113.40, 22.30), (113.70, 22.30), (113.70, 22.05)]),
]

# bütün eyaleti el değiştiren bölgeler: (eyalet adı öneki, eski sahip, yeni sahip)
STATE_OWNER = [("Newfoundland and Labrador", "CAN", "ENG")]
# 1936'da ayrı yönetimi olan topraklar (Danzig Serbest Şehri, Tanca Uluslararası Bölgesi): ülke -> başkent eyaleti
NEW_CAPITALS = {"DNZ": "Danzig", "TNG": "Tangier"}
# ad düzeltmeleri: eyalet başka bir bölgenin adını taşıyor (ör. Timor eyaleti "Macau"): kimlik -> (en, tr)
RENAME = {228: ("Timor", "Timor"), 60: ("Xilingol", "Xilingol")}     # 60: Chifeng şehri Mançukuo'nun, kalan Şilingol


# ---------------------------------------------------------------- yardımcılar
def to_px(pts):
    lon = np.array([p[0] for p in pts], np.float64)
    lat = np.array([p[1] for p in pts], np.float64)
    x, y = G.project(lon, lat)
    return list(zip(x.tolist(), y.tolist()))


def poly_mask(pts, x0, y0, w, h):
    img = Image.new("1", (w, h), 0)
    ImageDraw.Draw(img).polygon([(x - x0, y - y0) for x, y in pts], fill=1)
    return np.array(img, bool)


def lonlat_px(lon, lat):
    x, y = G.project(np.array([lon]), np.array([lat]))
    return int(x[0]), int(y[0])


class Map:
    def __init__(self):
        la = np.asarray(Image.open(MAP / "provinces.png"))
        self.ids = (la[..., 0].astype(np.int32) | (la[..., 1].astype(np.int32) << 8))
        del la
        self.H, self.W = self.ids.shape
        self.meta = json.load(open(MAP / "provinces.json"))
        self.P = {p["id"]: p for p in self.meta["provinces"]}
        sj = json.load(open(MAP / "states.json"))
        self.capitals = sj["capitals"]
        self.S = {s["id"]: s for s in sj["states"]}
        self.cities = json.load(open(MAP / "cities.json"))["cities"]
        self.next_pid = max(self.P) + 1
        self.next_sid = max(self.S) + 1
        self.changed = set()              # bölge kimliği: pikselleri değişti
        self.dirty = []                   # değişen piksel kutuları (y0, y1, x0, x1)
        self.pop_override = {}            # yeni eyalet -> 1936 nüfusu (küçük topraklar: şehir payı çok şişirir)

    def prov_state(self, pid):
        p = self.P.get(pid)
        return p["state"] if p and p["type"] == "land" else 0

    def owner(self, pid):
        s = self.S.get(self.prov_state(pid))
        return s["owner"] if s else ""

    def owner_grid(self, sub, tag):
        uniq = np.unique(sub)
        good = np.array([u for u in uniq if self.owner(int(u)) == tag], np.int32)
        return np.isin(sub, good)

    def state_at(self, lon, lat):
        x, y = lonlat_px(lon, lat)
        for r in range(0, 12):
            win = self.ids[max(y - r, 0):y + r + 1, max(x - r, 0):x + r + 1]
            for v in np.unique(win):
                if self.prov_state(int(v)):
                    return self.prov_state(int(v))
        return 0

    def new_province(self, like):
        pid = self.next_pid
        self.next_pid += 1
        src = self.P[like]
        self.P[pid] = {"id": pid, "type": "land", "terrain": src["terrain"], "state": src["state"],
                       "coastal": False, "center": list(src["center"]), "river_adj": [], "strait_adj": [],
                       "area_km2": 0, "adj": [], "ll": list(src["ll"]), "_origin": like}
        self.changed.add(pid)
        return pid

    def new_state(self, name, owner, like_sid):
        sid = self.next_sid
        self.next_sid += 1
        base = self.S[like_sid]
        self.S[sid] = {"id": sid, "name": name[0], "names": {"en": name[0], "tr": name[1]}, "owner": owner,
                       "adm0": base["adm0"], "provinces": [], "population": 0, "area_km2": 0,
                       "center": list(base["center"])}
        return sid


# ---------------------------------------------------------------- bir düzeltme
def apply_fix(M, fx, made_states):
    pts = to_px(fx["poly"])
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    x0, x1 = max(int(min(xs)) - 2, 0), min(int(max(xs)) + 3, M.W)
    y0, y1 = max(int(min(ys)) - 2, 0), min(int(max(ys)) + 3, M.H)
    w, h = x1 - x0, y1 - y0
    sub = M.ids[y0:y1, x0:x1]                                  # görünüm: yazılanlar M.ids'e gider
    inside = poly_mask(pts, x0, y0, w, h)
    ex = fx.get("exclude", [])
    for poly in ([ex] if ex and isinstance(ex[0][0], (int, float)) else ex):
        inside &= ~poly_mask(to_px(poly), x0, y0, w, h)
    src_px = M.owner_grid(sub, fx["src"])
    moved = []                                                 # bütünüyle geçen bölgeler
    pieces = []                                                # bölünmeden yeni doğan (hedef tarafı) bölgeler
    if fx.get("mode") == "province":
        for u in np.unique(sub[src_px]):
            p = M.P[int(u)]
            cx, cy = p["center"]
            if y0 <= cy < y1 and x0 <= cx < x1 and inside[cy - y0, cx - x0]:
                moved.append(int(u))
    else:
        mask = inside & src_px
        if not mask.any():
            return []
        n_in = defaultdict(int)
        for u, c in zip(*np.unique(sub[mask], return_counts=True)):
            n_in[int(u)] = int(c)
        for pid, cin in n_in.items():
            total = len(_where(M, pid)[0])
            n_out = total - cin
            if n_out <= max(3, int(0.02 * total)) or n_out < MIN_PIECE:
                moved.append(pid)
                continue
            if cin <= 3:
                continue
            # bölünür: içteki pikseller bağlı bileşenlere ayrılır
            part = (sub == pid) & mask
            lab, n = ndimage.label(part)
            for k in range(1, n + 1):
                comp = lab == k
                npid = M.new_province(pid)
                sub[comp] = npid
                _set_seed(M, npid, comp, x0, y0)
                pieces.append(npid)
            M.changed.add(pid)
            _fix_remainder(M, pid, fx["src"])
        if fx.get("one_province") and pieces:
            # dar şerit (Kanal Bölgesi): bütün parçalar tek bölge
            main = max(pieces, key=lambda q: int(np.count_nonzero(sub == q)))
            for q in pieces:
                if q != main:
                    sub[sub == q] = main
                    del M.P[q]
                    M.changed.discard(q)
            pieces = [main]
        # küçük parçalar: hedef taraftaki komşuya
        target_side = set(moved) | set(pieces)
        for npid in list(pieces):
            cnt = int(np.count_nonzero(sub == npid))
            if cnt >= MIN_PIECE:
                continue
            nb = _contacts(sub, npid)
            # önce bu düzeltmede geçenler, yoksa zaten hedef ülkenin olan komşu bölge
            cands = [(c, q) for q, c in nb.items() if q in target_side and q != npid]
            cands = cands or [(c, q) for q, c in nb.items() if q in M.P and M.owner(q) == fx["dst"] and q != npid]
            # komşu hedef bölgeye katılır; yoksa kaynak ülkenin karasına değen ince şerit kaynağa geri döner
            # (sınır çizgisinin kırıntısı); yalnız denize/göle değen parça ada olarak ayrı bölge kalır
            sliver = [(c, q) for q, c in nb.items() if q in M.P and M.P[q]["type"] == "land" and M.owner(q) == fx["src"]]
            if cands or sliver:
                q = max(cands)[1] if cands else M.P[npid]["_origin"]
                M.changed.add(q)
                sub[sub == npid] = q
                pieces.remove(npid)
                target_side.discard(npid)
                del M.P[npid]
                M.changed.discard(npid)
    M.dirty.append((y0, y1, x0, x1))
    for pid in moved:
        M.changed.add(pid)
    # eyalet ataması
    group = defaultdict(list)                  # kaynak eyalet -> hedefe geçen bölgeler
    for pid in moved + pieces:
        group[M.P[pid]["state"]].append(pid)
    for pid in moved:
        M.P[pid]["_moved"] = True
    out = []
    for ssid, pids in group.items():
        st = M.S[ssid]
        if fx["src"] == fx["dst"] and st["name"] == fx["name"][0]:
            continue                                           # zaten kendi eyaletinde (tekrar çalıştırma)
        remaining = [q for q in st["provinces"] if q not in pids]
        # kaynak eyaletten parça kalıyor mu (bölünenlerin kalanı da kalan sayılır)
        whole = not remaining and all(M.P[q].get("_moved") for q in pids) and "into_at" not in fx
        if whole and fx["src"] != fx["dst"]:
            st["owner"] = fx["dst"]
            if st["name"] in fx.get("names_by_src", {}):
                en, tr = fx["names_by_src"][st["name"]]
                st["name"], st["names"] = en, {"en": en, "tr": tr}
            out.append(ssid)
            continue
        if "into_at" in fx:
            tsid = M.state_at(*fx["into_at"])
            assert M.S[tsid]["owner"] == fx["dst"], (fx["name"], M.S[tsid]["name"], M.S[tsid]["owner"])
        else:
            name = fx.get("names_by_src", {}).get(st["name"], fx["name"])
            key = (name, fx["dst"])
            if key not in made_states:
                made_states[key] = M.new_state(name, fx["dst"], ssid)
                if name == fx["name"] and "pop" in fx:
                    M.pop_override[made_states[key]] = fx["pop"]
            tsid = made_states[key]
        for q in pids:
            _move_to_state(M, q, tsid)
        out.append(tsid)
    return out


def _set_seed(M, pid, comp, x0, y0):
    """Yeni parçanın geçici merkezi kendi pikseli (piksel araması bu noktanın çevresinde yapılır)."""
    cy, cx = np.argwhere(comp)[0]
    M.P[pid]["center"] = [int(cx) + x0, int(cy) + y0]


def _contacts(sub, pid):
    m = sub == pid
    dil = ndimage.binary_dilation(m) & ~m
    vals, cnt = np.unique(sub[dil], return_counts=True)
    return {int(v): int(c) for v, c in zip(vals, cnt)}


def _fix_remainder(M, pid, src_tag):
    """Bölünen bölgenin kalanı: en büyük bileşen kimliği korur; küçük kopuklar aynı eyaletteki komşuya."""
    ys, xs = _where(M, pid)
    if len(ys) == 0:
        return
    y0, y1, x0, x1 = max(ys.min() - 1, 0), min(ys.max() + 2, M.H), max(xs.min() - 1, 0), min(xs.max() + 2, M.W)
    sub = M.ids[y0:y1, x0:x1]
    lab, n = ndimage.label(sub == pid)
    if n <= 1:
        return
    sizes = ndimage.sum(np.ones_like(lab), lab, index=np.arange(1, n + 1))
    keep = int(np.argmax(sizes)) + 1
    for k in range(1, n + 1):
        if k == keep:
            continue
        comp = lab == k
        if sizes[k - 1] >= MIN_PIECE:
            npid = M.new_province(pid)
            sub[comp] = npid
            _set_seed(M, npid, comp, x0, y0)
            _move_to_state(M, npid, M.P[pid]["state"])
            continue
        dil = ndimage.binary_dilation(comp) & ~comp
        vals, cnt = np.unique(sub[dil], return_counts=True)
        best = [(c, int(v)) for v, c in zip(vals, cnt) if int(v) != pid and M.prov_state(int(v)) == M.P[pid]["state"]]
        if best:
            sub[comp] = max(best)[1]
    M.dirty.append((y0, y1, x0, x1))


def _where(M, pid):
    """Bölgenin pikselleri: etiket noktası çevresinde (en büyük bölgeler de ~700 pikselden küçük)."""
    p = M.P[pid]
    cx, cy = p["center"]
    r = 700
    y0, y1, x0, x1 = max(cy - r, 0), min(cy + r, M.H), max(cx - r, 0), min(cx + r, M.W)
    ys, xs = np.nonzero(M.ids[y0:y1, x0:x1] == pid)
    return ys + y0, xs + x0


def _move_to_state(M, pid, sid):
    old = M.P[pid]["state"]
    if old == sid:
        if pid not in M.S[sid]["provinces"]:
            M.S[sid]["provinces"].append(pid)
        return
    if old in M.S and pid in M.S[old]["provinces"]:
        M.S[old]["provinces"].remove(pid)
    M.P[pid]["state"] = sid
    M.S[sid]["provinces"].append(pid)


# ---------------------------------------------------------------- yeniden hesaplamalar
def recompute(M, orig_state_of, orig_pop, orig_area):
    ids = M.ids
    H, W = M.H, M.W
    # bölge alanları, merkezleri, komşulukları (değişen bölgeler ve komşuları)
    log("bölge istatistikleri")
    cnt = np.bincount(ids.ravel(), minlength=M.next_pid)
    area = np.bincount(ids.ravel(), weights=np.repeat(G.ROW_AREA.astype(np.float64), W), minlength=M.next_pid)
    for pid in list(M.P):
        if pid < len(cnt) and cnt[pid] == 0:
            # tamamı başka bölgelere katıldı (yalnız yeni doğanlar olabilir)
            assert M.P[pid].get("_origin"), f"var olan bölge {pid} haritadan silindi"
            st = M.S.get(M.P[pid]["state"])
            if st and pid in st["provinces"]:
                st["provinces"].remove(pid)
            del M.P[pid]
            M.changed.discard(pid)
    log("komşuluk")
    edges = G.adjacency(ids)
    adj = defaultdict(set)
    for a, b, _ in edges:
        adj[a].add(b)
        adj[b].add(a)
    # doğrulama: değişmeyen bölgelerde komşuluk aynı kalmalı
    touched = set(M.changed)
    for pid in M.changed:
        touched |= adj[pid]
        touched |= set(M.P[pid]["adj"]) if pid in M.P else set()
    diff = [pid for pid, p in M.P.items() if pid not in touched and sorted(adj[pid]) != p["adj"]]
    assert not diff, f"değişmeyen bölgelerde komşuluk farkı: {diff[:10]}"
    types = {pid: p["type"] for pid, p in M.P.items()}
    for pid in touched:
        if pid not in M.P:
            continue
        p = M.P[pid]
        new_adj = sorted(int(q) for q in adj[pid] if q in M.P)
        p["adj"] = new_adj
        if p["type"] == "land":
            p["coastal"] = any(types.get(q) == "sea" for q in new_adj)
        p["area_km2"] = int(area[pid])
        org = p.get("_origin")
        rv = set(p["river_adj"]) | (set(M.P[org]["river_adj"]) if org and org in M.P else set())
        p["river_adj"] = sorted(q for q in rv if q in new_adj and q in M.P)
    for pid in touched:
        if pid in M.P:
            for q in M.P[pid]["river_adj"]:
                if pid not in M.P[q]["river_adj"] and q in M.P:
                    M.P[q]["river_adj"] = sorted(M.P[q]["river_adj"] + [pid])
    # etiket noktaları: değişen bölgelerde sınıra en uzak piksel
    for pid in M.changed:
        if pid not in M.P:
            continue
        ys, xs = _where(M, pid)
        y0, y1, x0, x1 = ys.min() - 1, ys.max() + 2, xs.min() - 1, xs.max() + 2
        y0, x0 = max(y0, 0), max(x0, 0)
        m = ids[y0:y1, x0:x1] == pid
        d = ndimage.distance_transform_edt(np.pad(m, 1))[1:-1, 1:-1]
        cy, cx = np.unravel_index(int(np.argmax(d)), d.shape)
        cy, cx = cy + y0, cx + x0
        M.P[pid]["center"] = [int(cx), int(cy)]
        lo, la = G.unproject(cx, cy)
        M.P[pid]["ll"] = [round(float(lo), 3), round(float(la), 3)]
    # şehirler: konumdaki bölge (deniz pikselindeki liman şehri bölgesini korur, eyaleti bölgeden alır)
    log("şehirler")
    for c in M.cities:
        x, y = int(c["pos"][0]) % W, min(int(c["pos"][1]), H - 1)
        pid = int(ids[y, x])
        if pid in M.P and M.P[pid]["type"] == "land":
            c["province"] = pid
        if c["province"] not in M.P or M.P[c["province"]]["type"] != "land":
            # bölgesi kalmadı: en yakın kara bölgesi
            c["province"] = _nearest_land(M, x, y)
        c["state"] = M.P[c["province"]]["state"]
    # eyaletler: alan, merkez, nüfus (kaynak eyaletten alan ve şehir nüfusu payıyla)
    log("eyaletler")
    for s in M.S.values():
        s["provinces"] = sorted(q for q in s["provinces"] if q in M.P)
    city_pop = defaultdict(float)
    for c in M.cities:
        city_pop[c["state"]] += c["pop"]
    # her eyaletin pikselleri hangi eski eyaletten: eski eyalet nüfusunu alan ve şehir payıyla dağıt
    new_area = defaultdict(lambda: defaultdict(float))      # yeni eyalet -> eski eyalet -> km²
    new_city = defaultdict(lambda: defaultdict(float))
    for pid, p in M.P.items():
        if p["type"] != "land":
            continue
        o = orig_state_of.get(pid) or orig_state_of.get(p.get("_origin"))
        new_area[p["state"]][o] += p["area_km2"]
    for c in M.cities:
        o = c["_orig_state"]
        new_city[c["state"]][o] += c["pop"]
    old_city = defaultdict(float)
    for c in M.cities:
        old_city[c["_orig_state"]] += c["pop"]
    affected = {sid for sid in M.S if sid not in orig_pop}
    for pid in M.changed:
        if pid in M.P:
            affected.add(M.P[pid]["state"])
        o = orig_state_of.get(pid) or orig_state_of.get(M.P.get(pid, {}).get("_origin"))
        if o:
            affected.add(o)
    affected = {sid for sid in affected if sid in M.S}
    contrib = defaultdict(dict)
    for sid in affected:
        s = M.S[sid]
        pop = 0.0
        for o, a in new_area[sid].items():
            if o not in orig_pop:
                continue
            share_a = a / max(orig_area[o], 1.0)
            share_c = new_city[sid].get(o, 0.0) / old_city[o] if old_city[o] > 0 else share_a
            contrib[sid][o] = orig_pop[o] * (0.5 * share_a + 0.5 * share_c)
            pop += contrib[sid][o]
        s["population"] = int(pop)
    # tarihî nüfusu bilinen küçük topraklar: fark kaynak eyaletlere katkıları oranında geri döner
    for sid, want in M.pop_override.items():
        s = M.S[sid]
        have = float(s["population"])
        tot = sum(v for o, v in contrib[sid].items() if o != sid) or 1.0
        for o, v in contrib[sid].items():
            if o != sid and o in M.S:
                M.S[o]["population"] = int(M.S[o]["population"] + (have - want) * v / tot)
        s["population"] = int(want)
    # adını taşıdığı şehri kaybeden eyalet: kalan en büyük şehrin adını alır (ör. Dalian şehri Kwantung'a geçti)
    by_state = defaultdict(list)
    for c in M.cities:
        by_state[c["state"]].append(c)
    names_of = {c["name"] for c in M.cities}
    for sid in affected:
        s = M.S[sid]
        if s["name"] in names_of and not any(c["name"] == s["name"] for c in by_state[sid]) and by_state[sid]:
            big = max(by_state[sid], key=lambda c: c["pop"])
            s["name"], s["names"] = big["name"], dict(big["names"])
    for sid, s in M.S.items():
        s["area_km2"] = int(sum(M.P[q]["area_km2"] for q in s["provinces"]))
    # eyalet merkezi: değişen eyaletlerde en büyük bölgenin etiket noktası
    for sid in affected:
        s = M.S[sid]
        if s["provinces"]:
            big = max(s["provinces"], key=lambda q: M.P[q]["area_km2"])
            s["center"] = list(M.P[big]["center"])
    return affected


def _nearest_land(M, x, y):
    for r in range(1, 40):
        win = M.ids[max(y - r, 0):y + r + 1, max(x - r, 0):x + r + 1]
        for v in np.unique(win):
            if int(v) in M.P and M.P[int(v)]["type"] == "land":
                return int(v)
    raise RuntimeError("yakında kara yok")


def rebuild_borders(M):
    """borders.png R (bölge sınırı) ve G (eyalet sınırı) mesafe alanları: değişen kutularda yeniden."""
    log("sınır mesafe alanları")
    b = np.asarray(Image.open(MAP / "borders.png")).copy()      # yarım çözünürlük RGBA
    land_lut = np.zeros(M.next_pid + 1, bool)
    st_lut = np.zeros(M.next_pid + 1, np.int32)
    for pid, p in M.P.items():
        if p["type"] == "land":
            land_lut[pid] = True
            st_lut[pid] = p["state"]
    pad = 40                               # kodlama 255/8 ≈ 32 pikselde doyar
    for (y0, y1, x0, x1) in _merge_boxes(M.dirty):
        Y0, Y1 = max((y0 - pad) // 2 * 2, 0), min((y1 + pad + 1) // 2 * 2, M.H // 2 * 2)
        X0, X1 = max((x0 - pad) // 2 * 2, 0), min((x1 + pad + 1) // 2 * 2, M.W // 2 * 2)
        E = 48
        ey0, ey1, ex0, ex1 = max(Y0 - E, 0), min(Y1 + E, M.H), max(X0 - E, 0), min(X1 + E, M.W)
        P = M.ids[ey0:ey1, ex0:ex1]
        land = land_lut[P]
        S = st_lut[P]
        rp = _enc(G.boundary_mask(P, P > 0))
        rs = _enc(G.boundary_mask(S, land))
        iy0, iy1, ix0, ix1 = Y0 - ey0, Y1 - ey0, X0 - ex0, X1 - ex0
        for ch, full in ((0, rp), (1, rs)):
            blk = full[iy0:iy1, ix0:ix1].astype(np.float32)
            hh, ww = blk.shape[0] // 2, blk.shape[1] // 2
            half = blk[:hh * 2, :ww * 2].reshape(hh, 2, ww, 2).mean((1, 3))
            b[Y0 // 2:Y0 // 2 + hh, X0 // 2:X0 // 2 + ww, ch] = np.clip(np.rint(half), 0, 255).astype(np.uint8)
    return b


def _enc(mask):
    # G.encode_dist sarmalamalı tam genişlik ister; kutu içinde düz mesafe dönüşümü (kenarlar dolgu payıyla uzak)
    d = ndimage.distance_transform_edt(~mask) + 0.5
    return np.clip(d * 8.0, 0, 255).astype(np.uint8)


def _merge_boxes(boxes):
    out = []
    for b in sorted(boxes):
        if out and b[0] <= out[-1][1] + 80 and b[2] <= out[-1][3] + 80 and b[3] >= out[-1][2] - 80:
            y0, y1, x0, x1 = out[-1]
            out[-1] = (min(y0, b[0]), max(y1, b[1]), min(x0, b[2]), max(x1, b[3]))
        else:
            out.append(b)
    return out


def check_borders_encoding(M):
    """Değişmemiş bir kutuda yeniden hesaplanan R/G, dosyadakiyle aynı olmalı (yöntem doğrulaması)."""
    b = np.asarray(Image.open(MAP / "borders.png"))
    y0, x0, n = 3000, 8800, 256              # Avrupa ortası (değişmeyen bir yer)
    E = 48
    P = M.ids[y0 - E:y0 + n + E, x0 - E:x0 + n + E]
    land_lut = np.zeros(M.next_pid + 1, bool)
    st_lut = np.zeros(M.next_pid + 1, np.int32)
    for pid, p in M.P.items():
        if p["type"] == "land":
            land_lut[pid] = True
            st_lut[pid] = p["state"]
    rp = _enc(G.boundary_mask(P, P > 0))[E:E + n, E:E + n].astype(np.float32)
    half = np.rint(rp.reshape(n // 2, 2, n // 2, 2).mean((1, 3)))
    ref = b[y0 // 2:y0 // 2 + n // 2, x0 // 2:x0 // 2 + n // 2, 0].astype(np.float32)
    err = float(np.abs(half - ref).max())
    assert err <= 1.0, f"sınır kodlaması dosyayla uyuşmuyor (en büyük fark {err})"


def log(msg):
    print(msg, flush=True)


def main():
    M = Map()
    check_borders_encoding(M)
    orig_state_of = {pid: p["state"] for pid, p in M.P.items() if p["type"] == "land"}
    orig_pop = {sid: s["population"] for sid, s in M.S.items()}
    orig_area = {sid: s["area_km2"] for sid, s in M.S.items()}
    for c in M.cities:
        c["_orig_state"] = c["state"]
    for sid, (en, tr) in RENAME.items():
        M.S[sid]["name"], M.S[sid]["names"] = en, {"en": en, "tr": tr}
    # önceki çalıştırmada kurulan eyaletler yeniden kullanılır (tekrar çalıştırma yeni eyalet kurmaz)
    made = {((st["names"]["en"], st["names"]["tr"]), st["owner"]): sid for sid, st in M.S.items()}
    for fx in FIXES:
        res = apply_fix(M, fx, made)
        log(f"{fx['name'][0]:14s} {fx['src']}->{fx['dst']}: eyalet {sorted(set(res))}")
    for prefix, old, new in STATE_OWNER:
        for s in M.S.values():
            if s["name"].startswith(prefix) and s["owner"] == old:
                s["owner"] = new
                log(f"{s['name']}: {old}->{new}")
    if not M.changed:
        log("değişiklik yok")
        return
    recompute(M, orig_state_of, orig_pop, orig_area)
    for tag, sname in NEW_CAPITALS.items():
        sid = next(k for k, st in M.S.items() if st["name"] == sname and st["owner"] == tag)
        M.capitals[tag] = sid
        in_state = [c for c in M.cities if c["state"] == sid]
        if in_state:
            cap = max(in_state, key=lambda c: c["pop"])
            cap["capital"] = True
            cap["vp"] = max(cap["vp"], 20)        # küçük ülke başkenti (generate_map ile aynı kural)
    borders = rebuild_borders(M)
    # yaz
    log("yazılıyor")
    ids = M.ids
    assert ids.max() < 65536
    Image.fromarray(np.stack([ids & 255, ids >> 8], -1).astype(np.uint8), "LA").save(MAP / "provinces.png")
    Image.fromarray(borders, "RGBA").save(MAP / "borders.png")
    provs = []
    for pid in sorted(M.P):
        p = {k: v for k, v in M.P[pid].items() if not k.startswith("_")}
        provs.append(p)
    M.meta["provinces"] = provs
    json.dump(M.meta, open(MAP / "provinces.json", "w"), ensure_ascii=False, separators=(",", ":"))
    states = [M.S[sid] for sid in sorted(M.S) if M.S[sid]["provinces"]]
    empty = [M.S[sid]["name"] for sid in sorted(M.S) if not M.S[sid]["provinces"]]
    assert not empty, f"boş eyalet kaldı: {empty}"
    json.dump({"capitals": M.capitals, "states": states}, open(MAP / "states.json", "w"), ensure_ascii=False, indent=1)
    for c in M.cities:
        del c["_orig_state"]
    json.dump({"cities": M.cities}, open(MAP / "cities.json", "w"), ensure_ascii=False, indent=0)
    import csv
    with open(MAP / "definition.csv", "w", newline="") as fh:
        w = csv.writer(fh, delimiter=";")
        for p in provs:
            i = p["id"]
            w.writerow([i, i & 255, (i >> 8) & 255, (i >> 16) & 255, p["type"], str(p["coastal"]).lower(), p["terrain"]])
    log(f"bitti: {len(provs)} bölge, {len(states)} eyalet")


if __name__ == "__main__":
    main()
