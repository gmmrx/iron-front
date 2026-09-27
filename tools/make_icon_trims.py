"""
Arayüz ikonlarının kırpma kutuları: assets/ui/icons_new/*.png içeriğinin (saydam olmayan kısmın) kare çerçevesi.
    python3 tools/make_icon_trims.py
Çıktı: assets/ui/icon_trims.json  {"<ikon adı>": [x, y, w, h, kaynak genişliği]} (piksel). Oyun (UiTheme.trimmed) ikonu bu kutuyla kırpar;
böylece yuvada ikonun kendisi büyük görünür, kenar boşluğu değil. Yeni ikon eklenince yeniden çalıştırın (listede
olmayan ikon masaüstünde çalışma anında kırpılır, web'de olduğu gibi kalır).
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "ui" / "icons_new"
OUT = ROOT / "assets" / "ui" / "icon_trims.json"
MARGIN = 1.08          # içerik kutusunun çevresinde bırakılan pay
MAX_FILL = 0.8         # içerik zaten karenin bu kadarını dolduruyorsa kırpılmaz (tam resimler)


def trim_box(path):
    im = Image.open(path).convert("RGBA")
    a = np.array(im)[:, :, 3]
    h, w = a.shape
    ys, xs = np.where(a > 12)
    if len(xs) == 0:
        return None
    bw, bh = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
    if bw * bh >= w * h * MAX_FILL:
        return None
    side = max(bw, bh) * MARGIN
    cx, cy = (xs.min() + xs.max() + 1) / 2, (ys.min() + ys.max() + 1) / 2
    x0, y0 = max(0.0, cx - side / 2), max(0.0, cy - side / 2)
    x1, y1 = min(float(w), cx + side / 2), min(float(h), cy + side / 2)
    return [round(x0), round(y0), round(x1 - x0), round(y1 - y0), w]


def main():
    out = {}
    for p in sorted(SRC.glob("*.png")):
        box = trim_box(p)
        if box:
            out[p.stem] = box
    OUT.write_text(json.dumps(out, separators=(",", ":"), sort_keys=True))
    print(f"{len(out)} ikon kırpıldı -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
