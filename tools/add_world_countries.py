#!/usr/bin/env python3
"""Dünya ülkelerini oyun verisine ekler (tekrar çalıştırılabilir; var olanın üstüne yazar).
    python3 tools/add_world_countries.py
Kaynak: tools/world_1936.py. Hedef: data/common/countries.json, units.json (start_divisions),
equipment.json (start_fleets, _bases)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import world_1936 as W  # noqa: E402

COMMON = ROOT / "data" / "common"


def load(name):
    return json.load(open(COMMON / name))


def save(name, data):
    json.dump(data, open(COMMON / name, "w"), ensure_ascii=False, indent=1)


countries = load("countries.json")
for tag, (names, color, ideology, leader, cap, stab, ws, flag) in W.COUNTRIES.items():
    countries["countries"][tag] = {
        "name": {"en": names[0], "tr": names[1]}, "color": color, "ideology": ideology, "leader": leader,
        "capital_hint": cap, "stability": stab, "war_support": ws, "flag": flag,
    }
save("countries.json", countries)

units = load("units.json")
units["start_divisions"].update(W.START_DIVISIONS)
save("units.json", units)

eq = load("equipment.json")
eq["start_fleets"].update(W.START_FLEETS)
eq["start_fleets"].setdefault("_bases", {}).update(W.FLEET_BASES)
save("equipment.json", eq)
print(f"{len(countries['countries'])} ülke, {len(W.START_DIVISIONS)} başlangıç ordusu, {len(W.START_FLEETS)} donanma")
