#!/usr/bin/env python3
"""Harita çıktılarını oyunun bellek bütçesine göre paketler (tekrar çalıştırılabilir).
    MAP_OUT=<klasör> python3 tools/pack_map.py
- provinces.png : RGB -> LA (L = kimlik düşük bayt, A = yüksek bayt; 16 bit, en fazla 65535 bölge)
- borders.png   : yarım çözünürlük (SDF değerleri tam çözünürlük pikseli cinsinden kalır; ortalama korur)
- terrain.png, water.png : yarım çözünürlük
- biome.png     : çeyrek çözünürlük (zaten bulanık ağırlık haritası)
"""
import json
import os
from pathlib import Path

import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None
ROOT = Path(__file__).resolve().parent.parent
MAP = Path(os.environ["MAP_OUT"]) if os.environ.get("MAP_OUT") else ROOT / "data" / "map"
meta = json.load(open(MAP / "provinces.json"))
W, H = meta["width"], meta["height"]


def half(a):
    h2, w2 = a.shape[0] // 2 * 2, a.shape[1] // 2 * 2
    a = a[:h2, :w2].astype(np.float32)
    return a.reshape(h2 // 2, 2, w2 // 2, 2, *a.shape[2:]).mean((1, 3))


p = Image.open(MAP / "provinces.png")
if p.mode == "RGB":
    a = np.asarray(p).astype(np.uint32)
    ids = a[..., 0] | (a[..., 1] << 8) | (a[..., 2] << 16)
    assert ids.max() < 65536, "bölge sayısı 16 biti aşıyor"
    Image.fromarray(np.stack([ids & 255, ids >> 8], -1).astype(np.uint8), "LA").save(MAP / "provinces.png")
    print("provinces.png -> LA")
for name, mode in [("borders.png", "RGBA"), ("terrain.png", "RGB"), ("water.png", "LA")]:
    im = Image.open(MAP / name)
    if im.size[0] == W:
        a = np.asarray(im)
        Image.fromarray(np.clip(np.rint(half(a)), 0, 255).astype(np.uint8), mode).save(MAP / name)
        print(f"{name} -> {W // 2}x{H // 2}")
im = Image.open(MAP / "biome.png")
if im.size[0] == W // 2:
    a = np.asarray(im)
    Image.fromarray(np.clip(np.rint(half(a)), 0, 255).astype(np.uint8), "RGBA").save(MAP / "biome.png")
    print(f"biome.png -> {W // 4}x{H // 4}")
