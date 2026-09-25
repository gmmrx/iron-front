#!/usr/bin/env python3
"""Deniz yolu ağı: her deniz bölgesi için açık denizde bir düğüm, komşu deniz bölgeleri ve
liman–deniz çiftleri arasında yalnız sudan geçen, kıyıdan uzak duran yumuşak rotalar.

Girdi : data/map/provinces.png (LA8 bölge kimliği), provinces.json, cities.json
Çıktı : data/map/sea_lanes.json
    nodes: {pid: [x, y]}           — deniz bölgesi düğümü (tam çözünürlük pikseli)
    docks: {"port-sea": [x, y]}     — limanın o denize açılan rıhtım noktası
    lanes: {"a-b": [[x, y], ...]}   — a < b, noktalar a'dan b'ye (dikişte sarmalanmamış, a'ya göre)
Oyun rota görünümü ve filo hareketi bu ağı kullanır.
"""
import json
import heapq
import time
import numpy as np
from PIL import Image
from scipy import ndimage

Image.MAX_IMAGE_PIXELS = None
F = 4                     # yol bulma ızgarası küçültme katsayısı
OUT = "data/map/sea_lanes.json"
T0 = time.time()


def log(*a):
    print(f"[{time.time() - T0:7.1f}s]", *a, flush=True)


meta = json.load(open("data/map/provinces.json"))
W, H = meta["width"], meta["height"]
provs = {p["id"]: p for p in meta["provinces"]}
sea = {pid for pid, p in provs.items() if p["type"] == "sea"}
cities = json.load(open("data/map/cities.json"))
cities = cities["cities"] if isinstance(cities, dict) else cities

im = np.asarray(Image.open("data/map/provinces.png"))
# kaba ızgara: her F×F bloğun ortasındaki piksel
ids = im[F // 2::F, F // 2::F, 0].astype(np.int32) + im[F // 2::F, F // 2::F, 1].astype(np.int32) * 256
full_ids = im[:, :, 0].astype(np.uint16) + im[:, :, 1].astype(np.uint16) * 256   # dar kanallar için
del im
gh, gw = ids.shape
log("ızgara", gw, gh)
is_sea = np.isin(ids, np.fromiter(sea, np.int32))
# kıyıya uzaklık (doğu–batı sarmalı: kenarlar dolgu ile)
pad = 256
edt = ndimage.distance_transform_edt(np.pad(is_sea, ((0, 0), (pad, pad)), mode="wrap"))[:, pad:-pad]
log("kıyı uzaklığı hazır")

# ---------------------------------------------------------------- düğümler
objs = ndimage.find_objects(ids)
nodes = {}
for pid in sea:
    if pid - 1 >= len(objs) or objs[pid - 1] is None:
        continue
    sl = objs[pid - 1]
    m = ids[sl] == pid
    if not m.any():
        continue
    ys, xs = np.nonzero(m)
    # dikişi aşan bölge: iki yarının büyüğü
    if xs.max() - xs.min() > gw // 2:
        keep = xs < gw // 2 if (xs < gw // 2).sum() >= (xs >= gw // 2).sum() else xs >= gw // 2
        ys, xs = ys[keep], xs[keep]
    cy, cx = ys.mean(), xs.mean()
    e = edt[sl][ys, xs]
    score = np.minimum(e, 10.0) - 0.035 * np.hypot(ys - cy, xs - cx)
    i = int(np.argmax(score))
    nodes[pid] = (int(xs[i] + sl[1].start), int(ys[i] + sl[0].start))
log("düğüm", len(nodes))

# ---------------------------------------------------------------- yol bulma
cost_grid = 1.0 + 12.0 / (1.0 + edt) ** 1.5   # kıyıya yakın çok pahalı: rota açık denizden
NB = [(-1, 0, 1.0), (1, 0, 1.0), (0, -1, 1.0), (0, 1, 1.0),
      (-1, -1, 1.414), (1, -1, 1.414), (-1, 1, 1.414), (1, 1, 1.414)]


def straight_ok(a, b):
    n = int(max(abs(b[0] - a[0]), abs(b[1] - a[1]))) + 1
    xs = np.linspace(a[0], b[0], n).round().astype(int) % gw
    ys = np.clip(np.linspace(a[1], b[1], n).round().astype(int), 0, gh - 1)
    return bool((edt[ys, xs] >= 3.0).all())


def dijkstra(a, b, allowed):
    """a, b: (x, y) ızgara; allowed: izinli hücre maskesi (bbox içinde) + bbox kökü"""
    mask, ox, oy = allowed
    h, w = mask.shape
    sx, sy = a[0] - ox, a[1] - oy
    tx, ty = b[0] - ox, b[1] - oy
    if not (0 <= sx < w and 0 <= sy < h and 0 <= tx < w and 0 <= ty < h):
        return None
    mask = mask.copy()
    mask[sy, sx] = mask[ty, tx] = True
    cg = cost_grid[oy:oy + h, ox:ox + w]
    dist = np.full((h, w), np.inf)
    prev = np.full((h, w), -1, np.int64)
    dist[sy, sx] = 0.0
    pq = [(0.0, sx, sy)]
    while pq:
        d, x, y = heapq.heappop(pq)
        if x == tx and y == ty:
            break
        if d > dist[y, x]:
            continue
        for dx, dy, L in NB:
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and mask[ny, nx]:
                nd = d + L * cg[ny, nx]
                if nd < dist[ny, nx]:
                    dist[ny, nx] = nd
                    prev[ny, nx] = y * w + x
                    heapq.heappush(pq, (nd, nx, ny))
    if not np.isfinite(dist[ty, tx]):
        return None
    out = []
    k = ty * w + tx
    while k >= 0:
        y, x = divmod(int(k), w)
        out.append((x + ox, y + oy))
        k = prev[y, x]
    return out[::-1]


def region(a, b, pids, margin=6):
    x0 = max(min(a[0], b[0]) - margin, 0)
    x1 = min(max(a[0], b[0]) + margin + 1, gw)
    y0 = max(min(a[1], b[1]) - margin, 0)
    y1 = min(max(a[1], b[1]) + margin + 1, gh)
    for pid in pids:
        sl = objs[pid - 1] if pid - 1 < len(objs) else None
        if sl is not None and sl[1].stop - sl[1].start < gw // 2:
            y0, y1 = min(y0, sl[0].start), max(y1, sl[0].stop)
            x0, x1 = min(x0, sl[1].start), max(x1, sl[1].stop)
    sub = ids[y0:y1, x0:x1]
    return sub, x0, y0


def rdp(pts, eps):
    if len(pts) < 3:
        return pts
    a, b = np.array(pts[0], float), np.array(pts[-1], float)
    ab = b - a
    n = np.hypot(*ab) or 1e-9
    p = np.array(pts, float)
    d = np.abs(ab[0] * (p[:, 1] - a[1]) - ab[1] * (p[:, 0] - a[0])) / n
    i = int(np.argmax(d))
    if d[i] > eps:
        return rdp(pts[:i + 1], eps)[:-1] + rdp(pts[i:], eps)
    return [pts[0], pts[-1]]


def chaikin(pts, it=2):
    for _ in range(it):
        if len(pts) < 3:
            return pts
        out = [pts[0]]
        for p, q in zip(pts[:-1], pts[1:]):
            out.append((0.75 * p[0] + 0.25 * q[0], 0.75 * p[1] + 0.25 * q[1]))
            out.append((0.25 * p[0] + 0.75 * q[0], 0.25 * p[1] + 0.75 * q[1]))
        out.append(pts[-1])
        pts = out
    return pts


def to_full(pts):
    return [[round(x * F + F / 2, 1), round(y * F + F / 2, 1)] for x, y in pts]


SEA_LUT = np.zeros(65536, bool)
SEA_LUT[list(sea)] = True


def fine_route(a, b, margin=120):
    """Tam çözünürlükte (dar boğaz / kanal / haliç): kıyı maliyeti yok, yalnız su"""
    ax, ay = a[0] * F + F // 2, a[1] * F + F // 2
    bx, by = b[0] * F + F // 2, b[1] * F + F // 2
    x0, x1 = max(min(ax, bx) - margin, 0), min(max(ax, bx) + margin + 1, W)
    y0, y1 = max(min(ay, by) - margin, 0), min(max(ay, by) + margin + 1, H)
    mask = SEA_LUT[full_ids[y0:y1, x0:x1]]
    t = time.time()
    p = _dijkstra_plain((ax, ay), (bx, by), mask, x0, y0)
    log("  ince", (ax, ay), (bx, by), mask.shape, "ok" if p else "YOK", f"{time.time() - t:.1f}s")
    if p is None:
        return None
    p = rdp(p, 1.5)
    return [((x - F // 2) / F, (y - F // 2) / F) for x, y in p]


def _dijkstra_plain(a, b, mask, ox, oy):
    """Seyrek grafik üzerinde (scipy) 8 komşulu en kısa yol"""
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import dijkstra as sp_dijkstra
    h, w = mask.shape
    sx, sy, tx, ty = a[0] - ox, a[1] - oy, b[0] - ox, b[1] - oy
    mask = mask.copy()
    mask[sy, sx] = mask[ty, tx] = True
    idx = np.full((h, w), -1, np.int64)
    ys, xs = np.nonzero(mask)
    idx[ys, xs] = np.arange(len(ys))
    rows, cols, wts = [], [], []
    for dx, dy, L in NB:
        nx, ny = xs + dx, ys + dy
        ok = (nx >= 0) & (nx < w) & (ny >= 0) & (ny < h)
        ok[ok] = mask[ny[ok], nx[ok]]
        rows.append(idx[ys[ok], xs[ok]])
        cols.append(idx[ny[ok], nx[ok]])
        wts.append(np.full(ok.sum(), L))
    n = len(ys)
    g = coo_matrix((np.concatenate(wts), (np.concatenate(rows), np.concatenate(cols))), shape=(n, n)).tocsr()
    s0, t0 = idx[sy, sx], idx[ty, tx]
    dist, pred = sp_dijkstra(g, indices=s0, return_predecessors=True)
    if not np.isfinite(dist[t0]):
        return None
    out = []
    k = t0
    while k >= 0:
        out.append((int(xs[k]) + ox, int(ys[k]) + oy))
        k = pred[k]
        if k == -9999:
            break
    return out[::-1]


def route(a, b, pids):
    """a -> b ızgara rotası; dikişi aşan çiftte düz çizgi (açık Pasifik)"""
    if abs(a[0] - b[0]) > gw // 2:
        bx = b[0] + (gw if b[0] < a[0] else -gw)
        return [a, (bx, b[1])], "seam"
    if straight_ok(a, b):
        return [a, b], "straight"
    sub, ox, oy = region(a, b, pids)
    allowed = np.isin(sub, list(pids)) & is_sea[oy:oy + sub.shape[0], ox:ox + sub.shape[1]]
    p = dijkstra(a, b, (allowed, ox, oy))
    kind = "pair"
    if p is None:
        allowed = is_sea[oy:oy + sub.shape[0], ox:ox + sub.shape[1]]
        p = dijkstra(a, b, (allowed, ox, oy))
        kind = "any"
    if p is None:
        sub, ox, oy = region(a, b, pids, margin=80)
        p = dijkstra(a, b, (is_sea[oy:oy + sub.shape[0], ox:ox + sub.shape[1]], ox, oy))
        kind = "wide"
    if p is None:
        p = fine_route(a, b)
        kind = "fine"
    if p is None:
        FAILS.append((a, b, sorted(pids)))
        return [a, b], "fail"
    return chaikin(rdp(p, 0.8)), kind


FAILS = []
lanes = {}
stats = {}
pairs = set()
for pid in sea:
    for n in provs[pid]["adj"]:
        if n in sea and n != pid:
            pairs.add((min(pid, n), max(pid, n)))
log("deniz çifti", len(pairs))
for i, (a, b) in enumerate(sorted(pairs)):
    if a not in nodes or b not in nodes:
        continue
    pts, kind = route(nodes[a], nodes[b], {a, b})
    stats[kind] = stats.get(kind, 0) + 1
    lanes[f"{a}-{b}"] = to_full(pts)
    if i % 2000 == 0:
        log(i, stats)
log("deniz rotaları", stats)

# ---------------------------------------------------------------- limanlar
docks = {}
pstats = {}
for c in cities:
    if not c.get("port"):
        continue
    pid = c["province"]
    cx, cy = c["pos"][0] // F, c["pos"][1] // F
    for s in provs[pid]["adj"]:
        if s not in sea or s not in nodes:
            continue
        # rıhtım: şehre en yakın, o denize ait su hücresi
        r = 40
        x0, y0 = max(cx - r, 0), max(cy - r, 0)
        sub = ids[y0:cy + r + 1, x0:cx + r + 1]
        ys, xs = np.nonzero(sub == s)
        if len(xs) == 0:
            continue
        k = int(np.argmin((xs + x0 - cx) ** 2 + (ys + y0 - cy) ** 2))
        dock = (int(xs[k] + x0), int(ys[k] + y0))
        pts, kind = route(dock, nodes[s], {s})
        pstats[kind] = pstats.get(kind, 0) + 1
        key = f"{min(pid, s)}-{max(pid, s)}"
        full = to_full(pts)
        lanes[key] = full if pid < s else full[::-1]
        docks[f"{pid}-{s}"] = full[0]
log("liman rotaları", pstats)

json.dump({"grid": F, "nodes": {str(k): [v[0] * F + F / 2, v[1] * F + F / 2] for k, v in nodes.items()},
           "docks": docks, "lanes": lanes}, open(OUT, "w"), separators=(",", ":"))
log("yazıldı", OUT)
for a, b, p in FAILS: print("FAIL", (a[0]*F, a[1]*F), (b[0]*F, b[1]*F), p)
