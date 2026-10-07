#!/usr/bin/env python3
"""Seçim ekranı sayfasını (assets/ui/first-selection.png, saydam arka plan) parçalara keser: assets/ui/selection/*.png.

Üst panel uçlar + yuva birimleri olarak kesilir: arayüz yan yana dizerek istediği sayıda yuvalı panel kurar (sayfada 7
yuva var, öne çıkan ülke sayısı farklı olabilir). Birimler yuvalar arası boşluğun ortasından kesilir; ardışık birimler
sayfadaki gibi kesintisiz birleşir.

    python3 tools/slice_selection_sheet.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/ui/first-selection.png"
OUT = ROOT / "assets/ui/selection"

# parça: (sol, üst, sağ, alt) — sağ/alt hariç
PIECES = {
    "panel_left": (15, 96, 347, 568),        # harita desenli uzun panel (üstte süslü ayraç)
    "panel_right": (1284, 98, 1645, 862),    # savaş resimli uzun panel
    "panel_bottom": (58, 608, 1239, 883),    # savaş resimli geniş panel
    "box": (392, 390, 566, 555),             # kare kutu
    "box_selected": (593, 388, 771, 558),    # seçili kare kutu (altın parıltı)
    "bar": (812, 385, 1231, 473),            # uzun düğme
    "bar_active": (812, 481, 1228, 569),     # etkin uzun düğme (altın dolgu)
}
TOP = (106, 343)                              # üst panelin dikey sınırları
TOP_CUTS = [356, 385, 504, 626, 747, 871, 994, 1119, 1241, 1273]   # sol uç | 7 yuva birimi | sağ uç


def main() -> None:
    im = Image.open(SRC).convert("RGBA")
    OUT.mkdir(parents=True, exist_ok=True)
    for name, box in PIECES.items():
        im.crop(box).save(OUT / f"{name}.png")
    y0, y1 = TOP
    im.crop((TOP_CUTS[0], y0, TOP_CUTS[1], y1)).save(OUT / "top_left.png")
    for i in range(7):
        im.crop((TOP_CUTS[1 + i], y0, TOP_CUTS[2 + i], y1)).save(OUT / f"top_unit_{i}.png")
    im.crop((TOP_CUTS[8], y0, TOP_CUTS[9], y1)).save(OUT / "top_right.png")
    print("yazıldı:", len(PIECES) + 9, "parça →", OUT)


if __name__ == "__main__":
    main()
