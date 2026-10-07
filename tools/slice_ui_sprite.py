#!/usr/bin/env python3
"""Arayüz sayfasını (assets/ui/ui-sprite2.png, kullanıcının çizimi, saydam zeminli) parçalara ayırır:
assets/ui/sheet/<ad>.png

Her parça kendi kaba kutusundan kesilir, saydamlığa göre sıkılaştırılır (görünen pikselin çevresinde 2 px pay). Portre
çerçevesinin içi (örnek resim ve bayrak) saydam yapılır: oyuncunun portresi altına girer. Zemin zaten saydam olduğundan
renklere dokunulmaz.

Kutular sayfadan ölçüldü (1 Ekim 2026, 2172 × 724; saydamlık > 24 olan bağlantılı parçalar):
- üstte hazır üst çubuk örneği; ondan yalnız portre çerçevesi ve hücre ayracı (x 343-344) alınır
- ikinci satır: boş kaynak çubuğu, ordu/donanma/hava kutusu, tarih kutusu (dünya dairesi, çubuk ve üç düğme yuvasıyla)
- üçüncü satır: ikonlar, duraklat / oynat / hızlı düğmeleri, ilerleme çubuğu (altın dolgu x 1839..1948)
- solda menü düğmeleri (ikinci sütun, tek tek çerçeveli) ve boş kare düğmeler
Tarih kutusunun yuvaları ve portre deliği çerçeve resimlerinde ölçülü (game/ui/top_bar.gd).

Kullanım: python3 tools/slice_ui_sprite.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets/ui/ui-sprite2.png")
OUT = os.path.join(ROOT, "assets/ui/sheet")
PAD = 2

# ad -> kaba kutu (x0, y0, x1, y1) sayfada; saydamlığa göre sıkılaştırılır
PIECES = {
    "portrait_frame": (40, 30, 219, 199),
    "bar_frame": (231, 189, 1363, 283),
    "mil_frame": (1380, 190, 1638, 284),
    "date_frame": (1654, 188, 2146, 285),
    "icon_political_power": (240, 302, 309, 369),
    "icon_stability": (340, 303, 404, 371),
    "icon_war_support": (437, 302, 503, 371),
    "icon_manpower": (534, 302, 601, 369),
    "icon_factory": (628, 300, 701, 376),
    "icon_fuel": (734, 298, 802, 377),
    "icon_supply": (836, 303, 905, 375),
    "icon_convoy": (932, 300, 1009, 371),
    "icon_tension": (1042, 296, 1095, 379),
    "icon_army": (1134, 307, 1203, 370),
    "icon_navy": (1244, 301, 1310, 370),
    "icon_air": (1333, 320, 1422, 359),
    "icon_globe": (1451, 304, 1522, 377),
    "btn_pause": (1561, 303, 1630, 373),
    "btn_play": (1649, 303, 1718, 373),
    "btn_fast": (1737, 303, 1806, 373),
    "menu_politics": (135, 235, 213, 307),
    "menu_research": (135, 310, 213, 382),
    "menu_production": (135, 385, 213, 455),
    "menu_navy": (135, 459, 213, 527),
    "menu_air": (135, 530, 213, 600),
    "menu_recon": (135, 603, 213, 676),
    "btn_square": (233, 489, 311, 568),
    "divider": (342, 80, 346, 150),           # hücre ayracı (kaynak çubuğu örneğinden; sıkılaştırılmaz)
}
PORTRAIT_HOLE = (51, 39, 207, 187)            # portre çerçevesinin içi (sayfada; çerçeve halkası ~10 px)
FILL_X = (1839, 1949)                          # ilerleme çubuğunun altın dolgusu


def tight(a: np.ndarray, box) -> tuple:
    x0, y0, x1, y1 = box
    ys, xs = np.where(a[y0:y1, x0:x1, 3] > 4)
    return (max(x0 + xs.min() - PAD, 0), max(y0 + ys.min() - PAD, 0), x0 + xs.max() + 1 + PAD, y0 + ys.max() + 1 + PAD)


def main() -> None:
    a = np.asarray(Image.open(SRC).convert("RGBA")).copy()
    os.makedirs(OUT, exist_ok=True)
    for name, box in PIECES.items():
        x0, y0, x1, y1 = tight(a, box) if name != "divider" else box
        piece = a[y0:y1, x0:x1].copy()
        if name == "portrait_frame":
            hx0, hy0, hx1, hy1 = PORTRAIT_HOLE
            piece[hy0 - y0:hy1 - y0, hx0 - x0:hx1 - x0, 3] = 0
            print("portre deliği (çerçeve resminde):", hx0 - x0, hy0 - y0, hx1 - hx0, hy1 - hy0)
        if name == "date_frame":
            print("tarih kutusu başlangıcı (sayfada):", x0, y0)
        Image.fromarray(piece, "RGBA").save(os.path.join(OUT, name + ".png"))
    # altın dolgu: çubuğun altın piksellerinin satırları
    sub = a[300:380, FILL_X[0]:FILL_X[1]].astype(int)
    gold = (sub[..., 0] > 120) & (sub[..., 0] - sub[..., 2] > 60) & (sub[..., 3] > 200)
    rows = np.where(gold.any(1))[0]
    Image.fromarray(a[300 + rows.min():300 + rows.max() + 1, FILL_X[0]:FILL_X[1]], "RGBA").save(os.path.join(OUT, "bar_fill.png"))
    print("%d parça: %s" % (len(PIECES) + 1, OUT))


if __name__ == "__main__":
    main()
