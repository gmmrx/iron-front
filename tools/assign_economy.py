#!/usr/bin/env python3
"""
1936 ekonomi başlangıç verisi: eyalet kategorileri, binalar ve kaynaklar.
    python3 tools/assign_economy.py
Girdi : data/map/states.json, data/map/cities.json, data/map/provinces.json
Çıktı : data/history/states_1936.json

Ülke toplamları (fabrika/tersane) aşağıdaki tabloda; eyaletlere şehir nüfusu ağırlıklı dağıtılır.
Kaynaklar gerçek yatak koordinatlarından en yakın eyalete atanır.
"""
import json
import math
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
import os
MAP = Path(os.environ["MAP_OUT"]) if os.environ.get("MAP_OUT") else ROOT / "data" / "map"
OUT = Path(os.environ["HIST_OUT"]) if os.environ.get("HIST_OUT") else ROOT / "data" / "history"

# (sivil, askeri, tersane, taban altyapı)
COUNTRY_INDUSTRY = {
    "GER": (32, 16, 4, 4), "ENG": (28, 9, 12, 4), "FRA": (30, 12, 5, 4), "ITA": (17, 12, 7, 3),
    "SOV": (32, 22, 3, 2), "TUR": (10, 3, 1, 2), "SPR": (10, 3, 2, 3), "POR": (3, 1, 1, 2),
    "POL": (8, 6, 1, 2), "ROM": (9, 4, 1, 2), "HUN": (4, 2, 0, 3), "CZE": (12, 6, 0, 3),
    "AUS": (5, 1, 0, 3), "YUG": (8, 2, 1, 2), "GRE": (3, 1, 1, 2), "BUL": (2, 1, 0, 2),
    "ALB": (1, 0, 0, 1), "SWE": (10, 3, 2, 3), "NOR": (4, 1, 2, 3), "DEN": (4, 1, 1, 4),
    "FIN": (3, 2, 1, 2), "EST": (1, 1, 0, 3), "LAT": (2, 1, 0, 3), "LIT": (1, 1, 0, 2),
    "HOL": (9, 2, 2, 4), "BEL": (9, 3, 1, 4), "LUX": (1, 0, 0, 4), "SWI": (7, 2, 0, 4),
    "IRE": (2, 0, 0, 3), "ICE": (1, 0, 0, 2), "PER": (6, 1, 0, 1), "IRQ": (1, 0, 0, 1),
    "SAU": (1, 0, 0, 1), "OMA": (0, 0, 0, 1),
    # dünya (türün klasikleri 1936 başlangıcına yakın)
    "USA": (41, 14, 13, 4), "JAP": (22, 17, 11, 3), "CHI": (10, 6, 0, 1), "MAN": (5, 4, 0, 2), "PRC": (1, 1, 0, 1),
    "SHX": (2, 2, 0, 1), "GXC": (2, 1, 0, 1), "YUN": (1, 1, 0, 1), "XSM": (1, 1, 0, 1), "SIK": (1, 0, 0, 1),
    "RAJ": (14, 4, 1, 1), "CAN": (8, 1, 1, 3), "AST": (5, 1, 1, 3), "SAF": (4, 1, 0, 2), "NZL": (2, 0, 0, 3),
    "BRA": (8, 1, 1, 1), "ARG": (6, 1, 1, 2), "MEX": (4, 1, 0, 1), "CHL": (3, 1, 1, 2), "SIA": (3, 1, 1, 1),
    "COL": (2, 0, 0, 1), "VEN": (2, 0, 0, 1), "PRU": (2, 0, 0, 1), "CUB": (2, 0, 0, 2), "URU": (2, 0, 0, 2),
    "PHI": (1, 0, 0, 1), "ETH": (1, 1, 0, 1), "MON": (1, 0, 0, 1), "AFG": (1, 0, 0, 1), "YEM": (1, 0, 0, 1),
}

MAJORS = {"GER", "ENG", "FRA", "ITA", "SOV"}

# nüfus eşiği -> (kategori, bina slotu) — türün klasikleri state_category
CATEGORIES = [
    (15_000, "wasteland", 0), (60_000, "pastoral", 1), (300_000, "rural", 2), (800_000, "town", 4),
    (1_500_000, "large_town", 5), (2_500_000, "city", 6), (4_000_000, "large_city", 8),
    (7_000_000, "metropolis", 10), (10 ** 12, "megalopolis", 12),
]

# gerçek yataklar: (boylam, enlem, kaynak, miktar)
DEPOSITS = [
    # petrol
    (49.9, 40.4, "oil", 60), (45.7, 43.3, "oil", 20), (40.1, 44.6, "oil", 10), (26.0, 44.9, "oil", 36),
    (44.4, 35.5, "oil", 30), (48.3, 30.9, "oil", 40), (9.7, 52.4, "oil", 3), (19.9, 40.8, "oil", 4),
    (23.4, 49.3, "oil", 4), (16.8, 46.6, "oil", 2), (50.6, 26.2, "oil", 4), (53.1, 51.4, "oil", 12),
    # çelik (demir cevheri + kömür havzaları)
    (7.2, 51.4, "steel", 48), (18.6, 50.3, "steel", 18), (19.0, 50.1, "steel", 10), (6.2, 49.2, "steel", 30),
    (6.1, 49.6, "steel", 8), (20.2, 67.8, "steel", 40), (37.8, 48.0, "steel", 30), (33.4, 47.9, "steel", 36),
    (59.0, 53.4, "steel", 24), (14.2, 49.9, "steel", 12), (-2.9, 43.2, "steel", 10), (-1.5, 53.4, "steel", 16),
    (-4.2, 55.9, "steel", 8), (-3.4, 51.7, "steel", 8), (5.6, 50.6, "steel", 8), (14.9, 47.5, "steel", 8),
    (17.4, 68.4, "steel", 6), (22.2, 48.7, "steel", 4), (31.6, 41.2, "steel", 4), (11.2, 43.5, "steel", 6),
    # alüminyum (boksit/izabe)
    (6.2, 43.4, "aluminium", 20), (17.8, 47.1, "aluminium", 16), (16.4, 43.5, "aluminium", 16),
    (22.5, 38.4, "aluminium", 8), (13.8, 45.1, "aluminium", 6), (6.8, 60.4, "aluminium", 8),
    (12.3, 51.3, "aluminium", 12), (32.3, 59.9, "aluminium", 10), (7.6, 46.3, "aluminium", 4),
    # tungsten
    (-7.7, 40.2, "tungsten", 20), (-8.5, 42.9, "tungsten", 10), (15.1, 59.9, "tungsten", 2),
    # krom
    (39.3, 38.6, "chromium", 22), (29.1, 36.6, "chromium", 8), (21.4, 41.9, "chromium", 10),
    (20.4, 41.7, "chromium", 8), (22.2, 40.3, "chromium", 6), (57.2, 50.3, "chromium", 20),
    # ---- dünya
    # petrol
    (-97.5, 31.5, "oil", 120), (-97.5, 35.5, "oil", 60), (-119.0, 35.3, "oil", 50), (-71.6, 10.4, "oil", 80),
    (-97.9, 22.2, "oil", 20), (101.5, 1.0, "oil", 30), (116.8, -1.2, "oil", 20), (-61.4, 10.4, "oil", 8),
    (94.9, 20.5, "oil", 6), (143.0, 51.0, "oil", 4), (-81.3, -4.6, "oil", 6), (-67.5, -45.9, "oil", 8),
    (-73.8, 7.1, "oil", 10),
    # çelik
    (-92.5, 47.5, "steel", 120), (-80.0, 40.4, "steel", 80), (-86.8, 33.5, "steel", 30), (-79.8, 43.2, "steel", 10),
    (-43.9, -20.0, "steel", 20), (123.0, 41.1, "steel", 30), (118.2, 39.6, "steel", 10), (130.8, 33.9, "steel", 10),
    (86.2, 22.8, "steel", 30), (151.8, -32.9, "steel", 16), (28.0, -26.0, "steel", 12), (-71.3, -29.4, "steel", 8),
    (126.1, 38.9, "steel", 10), (86.1, 53.8, "steel", 30),
    # alüminyum
    (-55.2, 5.5, "aluminium", 40), (-92.6, 34.6, "aluminium", 20), (-71.2, 48.4, "aluminium", 20),
    (104.5, 1.1, "aluminium", 10), (-2.0, 6.3, "aluminium", 10),
    # kauçuk
    (101.7, 3.2, "rubber", 60), (99.0, 3.5, "rubber", 45), (80.6, 7.3, "rubber", 10), (106.7, 11.5, "rubber", 12),
    (100.5, 7.0, "rubber", 6), (-10.2, 6.4, "rubber", 12), (21.0, 0.0, "rubber", 8), (-60.0, -3.0, "rubber", 6),
    # tungsten
    (114.9, 25.8, "tungsten", 60), (98.2, 14.0, "tungsten", 12), (128.0, 37.0, "tungsten", 8),
    (-117.0, 37.0, "tungsten", 10), (-66.5, -19.0, "tungsten", 8),
    # krom
    (30.5, -18.5, "chromium", 20), (27.5, -25.0, "chromium", 20), (120.5, 15.5, "chromium", 10),
    (165.5, -21.5, "chromium", 10), (-75.0, 20.5, "chromium", 4), (86.0, 21.0, "chromium", 4),
]


# harita dışı sömürge kaynakları (başkent eyaletine yazılır): Malaya, Hollanda Doğu Hint Adaları, Çinhindi...
COLONIAL = {}   # dünya haritasında sömürge kaynakları gerçek yataklarında


def project(lon, lat, meta):
    """generate_map.py ile aynı Miller silindirik projeksiyonu (dikişten sarmalanır)."""
    pr = meta["projection"]
    x = ((lon - pr["lon_min"]) % 360.0) / 360.0 * meta["width"]
    phi = math.radians(max(min(lat, 89.0), -89.0))
    y = (pr["y_top"] - 1.25 * math.log(math.tan(math.pi / 4.0 + 0.4 * phi))) * pr["px_per_rad"]
    return x, y


def category(pop):
    for limit, name, slots in CATEGORIES:
        if pop < limit:
            return name, slots
    return CATEGORIES[-1][1], CATEGORIES[-1][2]


def distribute(total, weights, capacity):
    """total adet binayı ağırlıklara göre, kapasiteyi aşmadan dağıt (en büyük kalan yöntemi)."""
    out = defaultdict(int)
    remaining = total
    for _ in range(total * 2):
        if remaining <= 0:
            break
        free = {k: w for k, w in weights.items() if capacity[k] - out[k] > 0 and w > 0}
        if not free:
            break
        s = sum(free.values())
        # her turda en "eksik" eyalete bir bina
        best = max(free, key=lambda k: free[k] / s * total - out[k])
        out[best] += 1
        remaining -= 1
    return out


def main():
    pmeta = json.load(open(MAP / "provinces.json"))
    provinces = {p["id"]: p for p in pmeta["provinces"]}
    states = json.load(open(MAP / "states.json"))["states"]
    cities = json.load(open(MAP / "cities.json"))["cities"]

    city_pop = defaultdict(int)
    port_pop = defaultdict(int)
    for c in cities:
        city_pop[c["state"]] += c["pop"]
        if c["port"]:
            port_pop[c["state"]] += c["pop"]
    coastal = {s["id"]: any(provinces[p]["coastal"] for p in s["provinces"]) for s in states}

    vp = defaultdict(int)
    for c in cities:
        vp[c["state"]] += c["vp"]
    capitals = json.load(open(MAP / "states.json"))["capitals"]

    result = {}
    by_owner = defaultdict(list)
    for s in states:
        cat, slots = category(s["population"])
        result[s["id"]] = {"category": cat, "slots": slots, "buildings": {}, "resources": {}}
        by_owner[s["owner"]].append(s)

    home_adm0 = {tag: next((s["adm0"] for s in states if s["id"] == sid), None) for tag, sid in capitals.items()}
    for tag, sts in by_owner.items():
        civ, mil, dock, infra = COUNTRY_INDUSTRY.get(tag, (1, 0, 0, 1))
        cap = {s["id"]: result[s["id"]]["slots"] for s in sts}
        # sanayi ağırlığı: şehir nüfusu ağır basar (sanayi şehirlerde)
        w = {s["id"]: city_pop[s["id"]] + 0.15 * s["population"] for s in sts}
        docks = distribute(dock, {k: port_pop[k] if coastal[k] else 0 for k in w}, cap)
        cap2 = {k: cap[k] - docks[k] for k in cap}
        mils = distribute(mil, w, cap2)
        cap3 = {k: cap2[k] - mils[k] for k in cap}
        civs = distribute(civ, w, cap3)
        for s in sts:
            b = result[s["id"]]["buildings"]
            for name, d in (("civilian_factory", civs), ("military_factory", mils), ("dockyard", docks)):
                if d[s["id"]]:
                    b[name] = d[s["id"]]
            level = infra + (1 if s["population"] > 1_500_000 else 0) - (1 if result[s["id"]]["slots"] <= 1 else 0)
            b["infrastructure"] = max(1, min(5, level))
            if port_pop[s["id"]] > 0:
                b["naval_base"] = min(10, 1 + int(port_pop[s["id"]] / 250_000))
            # hava üsleri: başkent + büyük şehirler (büyük güçlerde daha çok)
            major = tag in MAJORS
            home = s["adm0"] == home_adm0.get(tag)
            if s["id"] == capitals.get(tag):
                b["air_base"] = 6 if major else 3
            elif major and home and vp[s["id"]] >= 5:
                b["air_base"] = 3
            elif vp[s["id"]] >= 10:
                b["air_base"] = 1

    # kaynaklar: en yakın eyalet merkezi
    centers = {s["id"]: s["center"] for s in states}
    for lon, lat, res, amount in DEPOSITS:
        x, y = project(lon, lat, pmeta)
        if not (0 <= x < pmeta["width"] and 0 <= y < pmeta["height"]):
            continue
        sid = min(centers, key=lambda k: (centers[k][0] - x) ** 2 + (centers[k][1] - y) ** 2)
        r = result[sid]["resources"]
        r[res] = r.get(res, 0) + amount

    for tag, res in COLONIAL.items():
        cap = capitals.get(tag)
        if cap:
            r = result[cap]["resources"]
            for k, v in res.items():
                r[k] = r.get(k, 0) + v

    OUT.mkdir(parents=True, exist_ok=True)
    json.dump({"states": {str(k): v for k, v in result.items()}}, open(OUT / "states_1936.json", "w"), ensure_ascii=False, indent=1)

    # özet
    tot = defaultdict(lambda: defaultdict(int))
    for s in states:
        for k, v in result[s["id"]]["buildings"].items():
            if k in ("civilian_factory", "military_factory", "dockyard", "air_base"):
                tot[s["owner"]][k] += v
        for k, v in result[s["id"]]["resources"].items():
            tot[s["owner"]][k] += v
    for tag in ["GER", "ENG", "FRA", "ITA", "SOV", "TUR", "USA", "JAP", "CHI", "RAJ"]:
        print(tag, dict(tot[tag]))


main()
