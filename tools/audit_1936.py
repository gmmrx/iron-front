#!/usr/bin/env python3
"""1936 sınır denetimi: tests/data/borders_1936.json'daki her yerin haritadaki sahibi beklenenle aynı mı.
    python3 tools/audit_1936.py            # yalnız uyuşmayanlar
    python3 tools/audit_1936.py --all      # hepsi
Ayrıca şehirlerin (cities.json) konumundaki bölge ile kayıtlı bölge/eyaleti uyuşuyor mu (ör. Cebelitarık şehri
İngiltere'deki bir eyalete yazılmış) denetlenir.
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None
ROOT = Path(__file__).resolve().parent.parent
MAP = ROOT / "data" / "map"


def load():
    meta = json.load(open(MAP / "provinces.json"))
    pr = meta["projection"]
    la = np.asarray(Image.open(MAP / "provinces.png"))
    ids = la[..., 0].astype(np.int32) | (la[..., 1].astype(np.int32) << 8)
    states = {s["id"]: s for s in json.load(open(MAP / "states.json"))["states"]}
    prov_state = {p["id"]: p.get("state", 0) for p in meta["provinces"]}
    return meta, pr, ids, states, prov_state


def to_px(pr, w, lon, lat):
    x = ((lon - pr["lon_min"]) % 360.0) / 360.0 * w
    y = (pr["y_top"] - 1.25 * math.log(math.tan(math.pi / 4 + 0.4 * math.radians(lat)))) * pr["px_per_rad"]
    return int(x), int(y)


def owner_at(ctx, lon, lat):
    meta, pr, ids, states, prov_state = ctx
    x, y = to_px(pr, ids.shape[1], lon, lat)
    pid = int(ids[y, x])
    # kıyı kasabası denize düşebilir (2 km piksel): 5 piksel içindeki en yakın kara
    if prov_state.get(pid, 0) == 0:
        best = None
        for dy in range(-5, 6):
            for dx in range(-5, 6):
                q = int(ids[y + dy, (x + dx) % ids.shape[1]])
                if prov_state.get(q, 0) and (best is None or dx * dx + dy * dy < best[0]):
                    best = (dx * dx + dy * dy, q)
        if best:
            pid = best[1]
    sid = prov_state.get(pid, 0)
    st = states.get(sid)
    return pid, sid, (st["owner"] if st else "-"), (st["name"] if st else "sea")


def main():
    ctx = load()
    pts = json.load(open(ROOT / "tests" / "data" / "borders_1936.json"))["points"]
    show_all = "--all" in sys.argv
    bad = 0
    for name, lon, lat, want in pts:
        pid, sid, own, sname = owner_at(ctx, lon, lat)
        ok = own == want
        bad += 0 if ok else 1
        if show_all or not ok:
            print(f"{'ok ' if ok else 'YANLIŞ'} {name:28s} beklenen {want:4s} harita {own:4s}  bölge {pid} eyalet {sid} {sname}")
    print(f"{len(pts)} nokta, {bad} yanlış")
    # şehir tutarlılığı
    meta, pr, ids, states, prov_state = ctx
    cities = json.load(open(MAP / "cities.json"))["cities"]
    wrong = 0
    for c in cities:
        x, y = int(c["pos"][0]), int(c["pos"][1])
        pid = int(ids[y % ids.shape[0], x % ids.shape[1]])
        if prov_state.get(pid, 0) == 0:
            continue                      # deniz pikseli (liman şehri kıyıda): bölge ataması generator'ın
        if pid != c["province"] or prov_state[pid] != c["state"]:
            so = states.get(c["state"], {}).get("owner", "-")
            po = states.get(prov_state[pid], {}).get("owner", "-")
            if so != po or "--cities" in sys.argv:
                wrong += 1
                print(f"ŞEHİR {c['name']}: kayıt bölge {c['province']} eyalet {c['state']} ({so}), konumda bölge {pid} eyalet {prov_state[pid]} ({po})")
    print(f"{len(cities)} şehir, {wrong} farklı sahipli yerde")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
