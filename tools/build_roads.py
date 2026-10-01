#!/usr/bin/env python3
"""Kara yolları ve demiryolları: haritada ince çizgiler (RoadLayer). Yalnız görünüm; oyun mantığı kullanmaz.
    python3 tools/fetch_data.py          # tools/cache/ne_10m_roads.geojson, ne_10m_railroads.geojson (Natural Earth, kamu malı)
    python3 tools/build_roads.py         # -> data/map/roads.json

Kaynak Natural Earth 10 m yol ve demiryolu çizgileri. Feribot hatları alınmaz; suyun (deniz, göl) üstünden geçen
parçalar kesilir (1936'da boğazlarda köprü yoktu). Uç uca eklenen parçalar tek çizgide birleştirilir (eklem yerinde
kopukluk ya da üst üste binme olmasın), çizgiler 0,15 piksel toleransla inceltilir.
Çıktı: {"kinds": [...], "lines": [[tür, x0, y0, x1, y1, ...], ...]} — koordinatlar harita pikseli x 10 (tam sayı);
tür 0 ana yol, 1 tali yol, 2 demiryolu.
"""
import json
import math
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None
ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / "cache"
MAP = ROOT / "data" / "map"
KINDS = ["road_major", "road_minor", "rail"]
MAJOR_TYPES = {"Major Highway", "Beltway", "Bypass"}
SKIP_TYPES = {"Ferry Route", "Ferry, seasonal"}
SNAP = 0.25                    # uç birleştirme ızgarası (piksel)
SIMPLIFY = 0.15                # Douglas–Peucker toleransı (piksel)


def load_map():
    meta = json.load(open(MAP / "provinces.json"))
    la = np.asarray(Image.open(MAP / "provinces.png"))
    ids = la[..., 0].astype(np.int32) | (la[..., 1].astype(np.int32) << 8)
    land = np.zeros(max(p["id"] for p in meta["provinces"]) + 1, bool)
    for p in meta["provinces"]:
        land[p["id"]] = p["type"] == "land"
    return meta, land[ids]


def project(pr, w, lon, lat):
    x = ((lon - pr["lon_min"]) % 360.0) / 360.0 * w
    lat = max(min(lat, 89.0), -89.0)
    y = (pr["y_top"] - 1.25 * math.log(math.tan(math.pi / 4 + 0.4 * math.radians(lat)))) * pr["px_per_rad"]
    return x, y


def lines_of(feature):
    g = feature.get("geometry")
    if not g:
        return []
    return [g["coordinates"]] if g["type"] == "LineString" else g["coordinates"] if g["type"] == "MultiLineString" else []


def on_land(landmask, x, y):
    h, w = landmask.shape
    xi, yi = int(x) % w, int(y)
    return 0 <= yi < h and landmask[yi, xi]


def split_polyline(pts, w, landmask):
    """Dikişte (doğu-batı) ve suyun üstünde böl: yalnız karadaki parçalar (yarım pikselde bir denetlenir)."""
    out = []
    cur = []
    prev = None
    for x, y in pts:
        if prev is not None and abs(x - prev[0]) > w / 2:
            out.append(cur)
            cur = []
            prev = None
        if prev is None:
            if on_land(landmask, x, y):
                cur = [(x, y)]
            prev = (x, y)
            continue
        x0, y0 = prev
        n = max(1, int(math.hypot(x - x0, y - y0) / 0.5))
        last_land = cur[-1] if cur else None
        for k in range(1, n + 1):
            t = k / n
            sx, sy = x0 + (x - x0) * t, y0 + (y - y0) * t
            if on_land(landmask, sx, sy):
                if not cur:
                    cur = [(sx, sy)]
                last_land = (sx, sy)
            elif cur:
                if last_land and last_land != cur[-1]:
                    cur.append(last_land)
                out.append(cur)
                cur = []
        if cur and cur[-1] != (x, y):
            cur.append((x, y))
        prev = (x, y)
    out.append(cur)
    return [c for c in out if len(c) >= 2]


def merge_chains(polys):
    """Uçları aynı noktaya düşen çizgileri (yalnız iki çizginin buluştuğu uçlarda) tek çizgide birleştir."""
    def key(p):
        return (round(p[0] / SNAP), round(p[1] / SNAP))
    ends = defaultdict(list)
    for i, pl in enumerate(polys):
        ends[key(pl[0])].append(i)
        ends[key(pl[-1])].append(i)
    used = [False] * len(polys)
    out = []
    for i in range(len(polys)):
        if used[i]:
            continue
        used[i] = True
        chain = list(polys[i])
        for at_end in (True, False):                   # önce sona doğru, sonra başa doğru uzat
            while True:
                end = chain[-1] if at_end else chain[0]
                k = key(end)
                cand = [j for j in ends[k] if not used[j]]
                if len(ends[k]) != 2 or not cand:
                    break
                j = cand[0]
                used[j] = True
                pl = list(polys[j])
                if at_end:
                    if key(pl[0]) != k:
                        pl.reverse()
                    chain.extend(pl[1:])
                else:
                    if key(pl[-1]) != k:
                        pl.reverse()
                    chain = pl[:-1] + chain
        out.append(chain)
    return out


def simplify(pts, eps):
    if len(pts) < 3:
        return pts
    a = np.asarray(pts)
    keep = np.zeros(len(a), bool)
    keep[0] = keep[-1] = True
    stack = [(0, len(a) - 1)]
    while stack:
        i, j = stack.pop()
        if j <= i + 1:
            continue
        seg = a[j] - a[i]
        ln = math.hypot(seg[0], seg[1])
        rel = a[i + 1:j] - a[i]
        d = np.abs(rel[:, 0] * seg[1] - rel[:, 1] * seg[0]) / ln if ln > 1e-9 else np.hypot(rel[:, 0], rel[:, 1])
        k = int(np.argmax(d))
        if d[k] > eps:
            m = i + 1 + k
            keep[m] = True
            stack += [(i, m), (m, j)]
    return [tuple(p) for p in a[keep]]


def main():
    meta, landmask = load_map()
    pr = meta["projection"]
    w = meta["width"]
    per_kind = defaultdict(list)
    roads = json.load(open(CACHE / "ne_10m_roads.geojson"))["features"]
    for f in roads:
        p = f["properties"]
        if p.get("type") in SKIP_TYPES:
            continue
        kind = 0 if p.get("type") in MAJOR_TYPES or int(p.get("scalerank") or 10) <= 5 else 1
        for ln in lines_of(f):
            pts = [project(pr, w, lon, lat) for lon, lat in ln]
            per_kind[kind] += split_polyline(pts, w, landmask)
    rails = json.load(open(CACHE / "ne_10m_railroads.geojson"))["features"]
    for f in rails:
        for ln in lines_of(f):
            pts = [project(pr, w, lon, lat) for lon, lat in ln]
            per_kind[2] += split_polyline(pts, w, landmask)
    lines = []
    for kind in (0, 1, 2):
        merged = merge_chains(per_kind[kind])
        n_pts = 0
        for pl in merged:
            s = simplify(pl, SIMPLIFY)
            if len(s) < 2 or sum(math.hypot(s[i + 1][0] - s[i][0], s[i + 1][1] - s[i][1]) for i in range(len(s) - 1)) < 0.6:
                continue
            flat = [kind]
            for x, y in s:
                flat += [int(round(x * 10)), int(round(y * 10))]
            lines.append(flat)
            n_pts += len(s)
        print(f"{KINDS[kind]}: {len(per_kind[kind])} parça -> {len(merged)} çizgi, {n_pts} nokta")
    json.dump({"kinds": KINDS, "lines": lines}, open(MAP / "roads.json", "w"), separators=(",", ":"))
    print(f"data/map/roads.json: {len(lines)} çizgi, {(MAP / 'roads.json').stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
