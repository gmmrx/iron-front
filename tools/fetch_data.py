#!/usr/bin/env python3
"""
Harita üretimi için dış verileri tools/cache/ içine indirir (idempotent).
    python3 tools/fetch_data.py
Kaynaklar:
  - Natural Earth (public domain): idari bölgeler, nehirler, göller, şehirler, kabartma raster'ı
  - Mapzen/Tilezen Terrarium yükseklik karoları (AWS Open Data; SRTM/GMTED/ETOPO türevi)
  - Wikimedia Commons bayrakları (çoğu kamu malı) -> assets/flags/
"""
import concurrent.futures as cf
import math
import subprocess
import sys
import time
import urllib.parse
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / "cache"
FLAGS = ROOT / "assets" / "flags"
NE_GEOJSON = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/"
NE_RASTER = "https://naciscdn.org/naturalearth/50m/raster/"
TERRARIUM = "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"
DEM_ZOOM = 6
DEM_BOUNDS = (-50.0, 10.0, 82.0, 80.0)  # boylam/enlem

GEOJSON = {
    "ne_10m_admin_1.geojson": "ne_10m_admin_1_states_provinces.geojson",
    "ne_10m_rivers_lake_centerlines.geojson": "ne_10m_rivers_lake_centerlines.geojson",
    "ne_10m_rivers_europe.geojson": "ne_10m_rivers_europe.geojson",
    "ne_10m_lakes.geojson": "ne_10m_lakes.geojson",
    "ne_10m_populated_places.geojson": "ne_10m_populated_places.geojson",
}

# 1936 bayrakları (Commons dosya adları). GER bilinçli olarak yok: prosedürel siyah-beyaz-kırmızı kullanılır.
FLAG_FILES = {
    "TUR": "Flag_of_Turkey.svg",
    "ENG": "Flag_of_the_United_Kingdom.svg",
    "FRA": "Flag_of_France.svg",
    "ITA": "Flag_of_Italy_(1861-1946)_crowned.svg",
    "SOV": "Flag_of_the_Soviet_Union_(1936-1955).svg",
    "SPR": "Flag_of_the_Second_Spanish_Republic.svg",
    "POR": "Flag_of_Portugal.svg",
    "POL": "Flag_of_Poland.svg",
    "ROM": "Flag_of_Romania.svg",
    "HUN": "Flag_of_Hungary_(1920-1946).svg",
    "CZE": "Flag_of_the_Czech_Republic.svg",
    "AUS": "Flag_of_Austria.svg",
    "YUG": "Flag_of_the_Kingdom_of_Yugoslavia.svg",
    "GRE": "Flag_of_Greece_(1822-1978).svg",
    "BUL": "Flag_of_Bulgaria.svg",
    "ALB": "Flag_of_Albania_(1934-1939).svg",
    "SWE": "Flag_of_Sweden.svg",
    "NOR": "Flag_of_Norway.svg",
    "DEN": "Flag_of_Denmark.svg",
    "FIN": "Flag_of_Finland.svg",
    "EST": "Flag_of_Estonia.svg",
    "LAT": "Flag_of_Latvia.svg",
    "LIT": "Flag_of_Lithuania_(1918-1940).svg",
    "HOL": "Flag_of_the_Netherlands.svg",
    "BEL": "Flag_of_Belgium.svg",
    "LUX": "Flag_of_Luxembourg.svg",
    "SWI": "Flag_of_Switzerland.svg",
    "IRE": "Flag_of_Ireland.svg",
    "ICE": "Flag_of_Iceland.svg",
    "PER": "Flag_of_Iran_(1925-1964).svg",
    "IRQ": "Flag_of_Iraq_(1924-1959).svg",
    "SAU": "Flag_of_Saudi_Arabia_(1934-1938).svg",
    "OMA": "Flag_of_Muscat.svg",
}


def fetch(url, dest, min_size=100):
    """curl ile indirir (macOS Python'unda sertifika sorunu yaşanmaması için)."""
    dest = Path(dest)
    if dest.exists() and dest.stat().st_size >= min_size:
        return True
    tmp = dest.with_suffix(dest.suffix + ".part")
    r = subprocess.run(["curl", "-sfL", "-A", "IronFront-mapgen/0.1 (hobby game project)", "-o", str(tmp), url])
    if r.returncode != 0 or not tmp.exists() or tmp.stat().st_size < min_size:
        tmp.unlink(missing_ok=True)
        print(f"  ! {url}")
        return False
    tmp.rename(dest)
    return True


def tile_range():
    lon0, lat0, lon1, lat1 = DEM_BOUNDS
    n = 2 ** DEM_ZOOM

    def tx(lon):
        return int((lon + 180.0) / 360.0 * n)

    def ty(lat):
        r = math.radians(lat)
        return int((1.0 - math.log(math.tan(r) + 1.0 / math.cos(r)) / math.pi) / 2.0 * n)

    return range(tx(lon0), tx(lon1) + 1), range(ty(lat1), ty(lat0) + 1)


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    FLAGS.mkdir(parents=True, exist_ok=True)
    print("Natural Earth vektör verileri")
    for local, remote in GEOJSON.items():
        fetch(NE_GEOJSON + remote, CACHE / local, 10000)
    print("Natural Earth raster verileri")
    for name in ["HYP_50M_SR_W", "SR_50M"]:
        if not (CACHE / f"{name}.tif").exists():
            if fetch(NE_RASTER + f"{name}.zip", CACHE / f"{name}.zip", 10000):
                zipfile.ZipFile(CACHE / f"{name}.zip").extractall(CACHE)
    print("Yükseklik karoları")
    xs, ys = tile_range()
    dem = CACHE / "dem" / str(DEM_ZOOM)
    dem.mkdir(parents=True, exist_ok=True)
    jobs = [(TERRARIUM.format(z=DEM_ZOOM, x=x, y=y), dem / f"{x}_{y}.png") for x in xs for y in ys]
    with cf.ThreadPoolExecutor(16) as ex:
        ok = sum(ex.map(lambda j: fetch(*j), jobs))
    print(f"  {ok}/{len(jobs)} karo")
    # tüm dünya: daha kaba (zoom 5) karolar; Avrupa penceresi zoom 6 önbelleğinden gelir
    world = CACHE / "dem" / "5"
    world.mkdir(parents=True, exist_ok=True)
    jobs = [(TERRARIUM.format(z=5, x=x, y=y), world / f"{x}_{y}.png") for x in range(32) for y in range(32)]
    with cf.ThreadPoolExecutor(16) as ex:
        ok = sum(ex.map(lambda j: fetch(*j), jobs))
    print(f"  dünya (zoom 5): {ok}/{len(jobs)} karo")
    if "--flags" not in sys.argv:
        print("Bayraklar atlandı (indirmek için: --flags)")
        return
    print("Bayraklar")
    for tag, fname in FLAG_FILES.items():
        dest = FLAGS / f"{tag}.svg"
        ok = dest.exists()
        # Commons yıl aralıklarında uzun tire (–) kullanır; hız sınırı için bekleyerek dener
        for variant in [fname, fname.replace("-", "\u2013")] * 2:
            if ok:
                break
            time.sleep(4)
            ok = fetch("https://commons.wikimedia.org/wiki/Special:FilePath/" + urllib.parse.quote(variant), dest, 200)
        if not ok:
            print(f"  {tag}: bulunamadı, prosedürel bayrak kullanılacak")


if __name__ == "__main__":
    main()
