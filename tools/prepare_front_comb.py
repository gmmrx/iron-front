#!/usr/bin/env python3
"""Cephe tarağı resmini (assets/ui/cephe.png, saydam, üstte sırt + aşağı sarkan dişler) oyunda döşenebilir dokuya
çevirir: assets/ui/map/front_comb.png. Dikeyde yalnız tarak (boş saydam alan atılır), yatayda tam N diş aralığı
(dişlerin ortası arası), dikişsiz tekrar etsin diye diş aralarının ortasından kesilir.

    python3 tools/prepare_front_comb.py
"""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/ui/cephe.png"
OUT = ROOT / "assets/ui/map/front_comb.png"


def main() -> None:
    im = Image.open(SRC).convert("RGBA")
    a = np.array(im)[..., 3] > 40
    rows = np.where(a.any(1))[0]
    top, bottom = rows.min(), rows.max() + 1
    band = a[top:bottom]
    # dişler: sırtın altındaki satırda dolu sütun grupları
    h = bottom - top
    probe = band[int(h * 0.75)]
    xs = np.where(probe)[0]
    groups = []
    for x in xs:
        if groups and x - groups[-1][-1] <= 2:
            groups[-1].append(x)
        else:
            groups.append([x])
    centers = [(g[0] + g[-1]) / 2 for g in groups if len(g) > 5]
    n = len(centers)
    period = (centers[-1] - centers[0]) / (n - 1)
    left = int(round(centers[0] - period / 2))
    right = int(round(left + period * n))
    if left < 0 or right > im.width:            # tam sığmıyorsa bir diş eksik
        n -= 1
        right = int(round(left + period * n))
        left = max(left, 0)
    out = im.crop((left, top, right, bottom))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT)
    print(f"{OUT.relative_to(ROOT)}: {out.size}, {n} diş, aralık {period:.1f} px")


if __name__ == "__main__":
    main()
