#!/usr/bin/env python3
"""
Arayüz dokuları (9-dilim StyleBoxTexture için): panel, başlık şeridi, düğme durumları.
    python3 tools/make_ui.py   -> assets/ui/*.png
Stil: fırçalanmış koyu çelik zemin, çift pirinç çerçeve, köşelerde perçin, iç gölge.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets" / "ui"
S = 4  # süper örnekleme


def brushed(w, h, base, seed, streak=0.05):
    rng = np.random.default_rng(seed)
    n = rng.standard_normal((h, w)).astype(np.float32)
    n = np.asarray(Image.fromarray(((n - n.min()) / np.ptp(n) * 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(0)), np.float32) / 255 - 0.5
    rows = np.asarray(Image.fromarray(((n + 0.5) * 255).astype(np.uint8)).resize((w, h)).filter(ImageFilter.GaussianBlur((12, 0)) if False else ImageFilter.BoxBlur(1)), np.float32) / 255 - 0.5
    horiz = np.cumsum(rng.standard_normal((h, 1)), 0) * 0.0 + rng.standard_normal((h, 1)) * 0.5
    img = np.array(base, np.float32)[None, None] / 255.0 * (1 + rows[..., None] * 0.06 + horiz[..., None] * streak)
    # dikey hafif degrade (üst açık)
    img *= np.linspace(1.08, 0.9, h)[:, None, None]
    return img


def panel(name, w, h, base, border, inner, radius=10, rivets=True, seed=0, glow=None):
    W, H = w * S, h * S
    img = brushed(W, H, base, seed)
    im = Image.fromarray(np.clip(img * 255, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, H - 1], radius * S, fill=255)
    d = ImageDraw.Draw(im)
    # iç gölge
    shade = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shade).rounded_rectangle([6 * S, 6 * S, W - 6 * S, H - 6 * S], radius * S, fill=255)
    shade = shade.filter(ImageFilter.GaussianBlur(6 * S))
    dark = Image.new("RGBA", (W, H), (0, 0, 0, 110))
    im = Image.composite(im, Image.alpha_composite(im, dark), shade)
    d = ImageDraw.Draw(im)
    # dış çerçeve (pirinç, üstte açık)
    for i, col in enumerate([(30, 24, 14), border, tuple(min(255, int(c * 1.25)) for c in border), border]):
        o = i * S
        d.rounded_rectangle([o, o, W - 1 - o, H - 1 - o], max(radius * S - o, 1), outline=col, width=S)
    # iç ince çizgi
    o = 7 * S
    d.rounded_rectangle([o, o, W - 1 - o, H - 1 - o], max((radius - 6) * S, 1), outline=inner, width=S)
    if glow:
        g = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(g).rounded_rectangle([o, o, W - 1 - o, H - 1 - o], max((radius - 6) * S, 1), outline=glow, width=3 * S)
        im = Image.alpha_composite(im, g.filter(ImageFilter.GaussianBlur(3 * S)))
        d = ImageDraw.Draw(im)
    if rivets:
        for cx, cy in [(12, 12), (w - 12, 12), (12, h - 12), (w - 12, h - 12)]:
            r = 3.2 * S
            x, y = cx * S, cy * S
            d.ellipse([x - r - S, y - r - S, x + r + S, y + r + S], fill=(20, 16, 10))
            d.ellipse([x - r, y - r, x + r, y + r], fill=border)
            d.ellipse([x - r * 0.5, y - r * 0.7, x + r * 0.1, y - r * 0.1], fill=(250, 230, 170))
    im.putalpha(mask)
    im = im.resize((w, h), Image.LANCZOS)
    im.save(OUT / f"{name}.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    brass = (178, 146, 82)
    dim = (104, 90, 60)
    panel("panel", 96, 96, (34, 38, 36), brass, (86, 74, 48), seed=1)
    panel("panel_light", 96, 96, (46, 50, 46), brass, (96, 84, 54), seed=2)
    panel("topbar", 96, 64, (28, 31, 30), brass, (70, 62, 42), radius=4, rivets=False, seed=3)
    panel("button", 64, 40, (48, 52, 48), dim, (70, 64, 48), radius=5, rivets=False, seed=4)
    panel("button_hover", 64, 40, (62, 66, 58), brass, (110, 96, 60), radius=5, rivets=False, seed=5)
    panel("button_pressed", 64, 40, (78, 66, 36), (232, 196, 110), (150, 124, 70), radius=5, rivets=False, seed=6,
          glow=(255, 214, 120, 150))
    panel("button_disabled", 64, 40, (32, 34, 32), (60, 56, 46), (50, 48, 40), radius=5, rivets=False, seed=7)
    panel("button_primary", 64, 40, (104, 80, 34), (236, 204, 120), (170, 136, 70), radius=5, rivets=False, seed=8,
          glow=(255, 214, 120, 120))
    panel("tooltip", 64, 48, (22, 24, 22), brass, (70, 62, 42), radius=4, rivets=False, seed=9)
    print("ui dokuları:", len(list(OUT.glob("*.png"))))


main()
