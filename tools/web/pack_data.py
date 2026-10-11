"""Web paketini kayıpsız küçültür. Yalnız CI'da, web dışa aktarımından hemen önce koşar (.github/workflows/web.yml);
depodaki dosyalar ve masaüstü oyunu değişmez.

- Harita resimleri (data/map: terrain, borders, biome; assets/terrain detay albedoları) kayıpsız WebP'ye çevrilir.
  `exact=True`: saydam piksellerin RGB'si de birebir korunur (borders ve biome dört kanalı da veri olarak kullanır).
  Oyun önce .webp'yi arar (MapView3D._map_image). provinces.png (16384 px; WebP en çok 16383 px) ve water.png (LA:
  WebP'de RGBA olurdu, GPU belleği iki katına çıkardı) PNG kalır.
- Büyük harita JSON'ları gzip'lenir (path + ".gz"); oyun önce .gz'yi okur (World.read_text).
- Yeni dosyalar Godot'ya olduğu gibi ("keep") verilir: dışa aktarım onları ham dosya olarak pakete koyar.

Kullanım (depo kökünde): python3 tools/web/pack_data.py
"""
import gzip
import os
import sys

from PIL import Image, ImageChops

Image.MAX_IMAGE_PIXELS = None
KEEP = '[remap]\n\nimporter="keep"\n'
WEBP = ["data/map/terrain.png", "data/map/borders.png", "data/map/biome.png"] + sorted(
    os.path.join("assets/terrain", f) for f in os.listdir("assets/terrain") if f.endswith("_albedo.png"))
GZIP = ["data/map/roads.json", "data/map/provinces.json", "data/map/sea_lanes.json", "data/map/states.json",
        "data/map/cities.json", "data/map/straits.json"]


def remove(path: str) -> None:
    for p in (path, path + ".import"):
        if os.path.exists(p):
            os.remove(p)


def main() -> int:
    before = after = 0
    for png in WEBP:
        img = Image.open(png)
        img.load()
        webp = os.path.splitext(png)[0] + ".webp"
        img.save(webp, "WEBP", lossless=True, quality=100, method=4, exact=True)
        back = Image.open(webp)
        back.load()
        if back.size != img.size or ImageChops.difference(back.convert(img.mode), img).getbbox() is not None:
            print(f"HATA: {png} kayıpsız çevrilemedi", file=sys.stderr)
            return 1
        before += os.path.getsize(png)
        after += os.path.getsize(webp)
        remove(png)
        with open(webp + ".import", "w") as f:
            f.write(KEEP)
        print(f"{png} -> {webp}")
    for js in GZIP:
        with open(js, "rb") as f:
            raw = f.read()
        with open(js + ".gz", "wb") as f:
            f.write(gzip.compress(raw, 9))
        before += len(raw)
        after += os.path.getsize(js + ".gz")
        remove(js)
        print(f"{js} -> {js}.gz")
    print(f"web paketi: {before / 1e6:.1f} MB -> {after / 1e6:.1f} MB (kayıpsız)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
