#!/usr/bin/env python3
"""Iron Front arayüz dokuları (türün klasiği görünümü): koyu perçinli metal paneller, başlık bandı, oyulmuş bölüm
çubukları, gömük ikon yuvaları, metal düğmeler, sekmeler, üst çubuk hücreleri. Hepsi 9-dilim (StyleBoxTexture).
Çıktı: assets/ui/skin/*.png   Çalıştır: python3 tools/make_ui_skin.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets" / "ui" / "skin"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(3)


def noise_bg(w, h, base, amp=6, streak=True):
    a = np.zeros((h, w, 4), np.float32)
    a[..., :3] = base
    n = rng.normal(0, amp, (h, w, 1))
    if streak:  # fırçalanmış metal: yatay çizgisel doku
        s = rng.normal(0, amp * 0.6, (h, 1, 1)).repeat(w, axis=1)
        n = n * 0.6 + s
    a[..., :3] += n
    a[..., 3] = 255
    return np.clip(a, 0, 255)


def to_img(a):
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def bevel(img, x0, y0, x1, y1, light, dark, width=1):
    d = ImageDraw.Draw(img)
    for i in range(width):
        d.line([(x0 + i, y1 - i), (x0 + i, y0 + i), (x1 - i, y0 + i)], fill=light)
        d.line([(x0 + i, y1 - i), (x1 - i, y1 - i), (x1 - i, y0 + i)], fill=dark)


def rivet(img, cx, cy, r=3):
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1], fill=(8, 8, 8, 255))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(92, 86, 74, 255))
    d.ellipse([cx - r + 1, cy - r + 1, cx, cy], fill=(150, 140, 118, 255))


def panel(name, w=96, h=96, base=(34, 37, 39), rivets=True, alpha=255):
    img = to_img(noise_bg(w, h, base, 5))
    d = ImageDraw.Draw(img)
    # çerçeve: dış siyah, 3 px metal (açık üst-sol, koyu alt-sağ), iç koyu hat
    d.rectangle([0, 0, w - 1, h - 1], outline=(6, 7, 8, 255))
    frame = noise_bg(w, h, (70, 72, 72), 5)
    fi = to_img(frame)
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    md.rectangle([1, 1, w - 2, h - 2], fill=255)
    md.rectangle([5, 5, w - 6, h - 6], fill=0)
    img.paste(fi, (0, 0), mask)
    bevel(img, 1, 1, w - 2, h - 2, (128, 126, 118, 255), (28, 28, 28, 255))
    bevel(img, 4, 4, w - 5, h - 5, (20, 21, 22, 255), (96, 94, 88, 255))
    d.rectangle([5, 5, w - 6, h - 6], outline=(10, 11, 12, 255))
    # iç ince pirinç hat
    d.rectangle([7, 7, w - 8, h - 8], outline=(92, 80, 52, 150))
    if rivets:
        for cx, cy in [(10, 10), (w - 11, 10), (10, h - 11), (w - 11, h - 11)]:
            rivet(img, cx, cy, 2)
    a = np.array(img)
    a[6:h - 6, 6:w - 6, 3] = alpha
    Image.fromarray(a).save(OUT / f"{name}.png")


def header(name, w=96, h=36):
    img = to_img(noise_bg(w, h, (22, 24, 26), 4))
    d = ImageDraw.Draw(img)
    # dikey degrade (üst biraz açık)
    a = np.array(img).astype(np.float32)
    g = np.linspace(1.25, 0.8, h)[:, None, None]
    a[..., :3] *= g
    img = to_img(np.clip(a, 0, 255))
    d = ImageDraw.Draw(img)
    d.line([(0, 0), (w, 0)], fill=(96, 96, 90, 255))
    d.line([(0, h - 2), (w, h - 2)], fill=(150, 124, 70, 255))
    d.line([(0, h - 1), (w, h - 1)], fill=(10, 10, 10, 255))
    img.save(OUT / f"{name}.png")


def section(name, w=96, h=24):
    img = to_img(noise_bg(w, h, (27, 29, 31), 3))
    d = ImageDraw.Draw(img)
    d.line([(0, 0), (w, 0)], fill=(10, 11, 12, 255))
    d.line([(0, 1), (w, 1)], fill=(64, 64, 60, 255))
    d.line([(0, h - 2), (w, h - 2)], fill=(10, 11, 12, 255))
    d.line([(0, h - 1), (w, h - 1)], fill=(70, 66, 56, 255))
    img.save(OUT / f"{name}.png")


def inset(name, w=48, h=48, base=(16, 17, 19), border=(4, 4, 5, 255), glow=None):
    img = to_img(noise_bg(w, h, base, 3, streak=False))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], outline=border)
    bevel(img, 1, 1, w - 2, h - 2, (6, 6, 7, 255), (70, 68, 62, 255))
    if glow:
        d.rectangle([2, 2, w - 3, h - 3], outline=glow)
    img.save(OUT / f"{name}.png")


def raised(name, w=96, h=32, top=(76, 79, 82), bottom=(40, 43, 46), border=(6, 6, 7, 255), hl=(140, 138, 128, 255), accent=None):
    a = np.zeros((h, w, 4), np.float32)
    for y in range(h):
        t = y / (h - 1)
        a[y, :, :3] = np.array(top) * (1 - t) + np.array(bottom) * t
    a[..., :3] += rng.normal(0, 3, (h, w, 1))
    a[..., 3] = 255
    img = to_img(np.clip(a, 0, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], outline=border)
    d.line([(1, 1), (w - 2, 1)], fill=hl)
    d.line([(1, 1), (1, h - 2)], fill=(hl[0] - 30, hl[1] - 30, hl[2] - 30, 255))
    d.line([(1, h - 2), (w - 2, h - 2)], fill=(18, 18, 18, 255))
    if accent:
        d.rectangle([1, 1, w - 2, h - 2], outline=accent)
    img.save(OUT / f"{name}.png")


def tooltip(name, w=48, h=48):
    img = Image.new("RGBA", (w, h), (12, 13, 14, 240))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], outline=(0, 0, 0, 255))
    d.rectangle([1, 1, w - 2, h - 2], outline=(120, 100, 60, 255))
    d.rectangle([2, 2, w - 3, h - 3], outline=(20, 20, 20, 255))
    img.save(OUT / f"{name}.png")


panel("panel")
panel("panel_flat", rivets=False)
panel("strip", w=96, h=44, base=(40, 42, 44))
header("header")
section("section")
inset("slot")
inset("slot_good", glow=(70, 120, 60, 255))
inset("slot_bad", glow=(130, 50, 40, 255))
inset("slot_gold", glow=(170, 140, 70, 255))
inset("cell", w=32, h=28, base=(12, 13, 14))
raised("button")
raised("button_hover", top=(96, 99, 100), bottom=(52, 55, 58), hl=(170, 166, 150, 255))
raised("button_pressed", top=(30, 32, 34), bottom=(50, 52, 54), hl=(60, 60, 58, 255), accent=(160, 130, 70, 255))
raised("button_disabled", top=(46, 48, 50), bottom=(32, 34, 36), hl=(70, 70, 68, 255))
raised("card", w=96, h=48, top=(44, 47, 49), bottom=(30, 32, 34), hl=(90, 90, 86, 255))
raised("card_hover", w=96, h=48, top=(58, 61, 63), bottom=(38, 40, 42), hl=(120, 118, 110, 255))
raised("card_selected", w=96, h=48, top=(52, 50, 40), bottom=(34, 32, 26), hl=(150, 130, 80, 255), accent=(190, 150, 70, 255))
raised("tab", w=64, h=30, top=(40, 43, 45), bottom=(28, 30, 32), hl=(80, 80, 76, 255))
raised("tab_active", w=64, h=30, top=(66, 62, 48), bottom=(40, 38, 30), hl=(170, 150, 90, 255), accent=(190, 150, 70, 255))
raised("menu_btn", w=48, h=48, top=(62, 64, 66), bottom=(34, 36, 38), hl=(130, 128, 120, 255))
raised("menu_btn_hover", w=48, h=48, top=(84, 86, 88), bottom=(46, 48, 50), hl=(170, 166, 150, 255))
raised("menu_btn_pressed", w=48, h=48, top=(34, 36, 38), bottom=(54, 56, 58), hl=(70, 70, 68, 255), accent=(190, 150, 70, 255))
tooltip("tooltip")
print(sorted(p.name for p in OUT.glob("*.png")))
