#!/usr/bin/env python3
"""Build the versioned Iron Front effects bank; NEVER writes music or legacy SFX.

    python3 tools/build_ww2_sfx.py                 # all cues, catalog, QA, audition
    python3 tools/build_ww2_sfx.py --only 'research_*radar*'
    python3 tools/build_ww2_sfx.py --check         # read-only asset verification
    python3 tools/build_ww2_sfx.py --list

Only dependency: NumPy. Stable per-file seeds, independent of iteration order.
New technologies are discovered from the game's source JSON automatically.
"""
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import math
import wave
from dataclasses import dataclass
from pathlib import Path

import numpy as np

import sfx_dsp as d

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = ROOT / "assets/audio/ww2"
SCHEMA = 2
SEED = 1940
PHASES = ("select", "start", "done", "cancel")


@dataclass(frozen=True)
class Cue:
    key: str
    recipe: str
    family: str = "governance"
    variants: int = 1
    gain_db: float = -6.0
    bus: str = "sfx"
    priority: int = 0
    queue: bool = False
    cooldown_ms: int = 90
    phase: str = ""
    identity: str = ""
    description: str = ""


def stable_seed(text: str) -> int:
    return int.from_bytes(hashlib.sha256(f"{SEED}:{text}".encode()).digest()[:8], "little")


def specifications() -> tuple[list[Cue], dict, dict]:
    specs: list[Cue] = []
    def add(key: str, recipe: str, **kw):
        specs.append(Cue(key, recipe, **kw))

    # Quiet dry tactile interface. Menu bodies are lower/heavier than battlefield UI.
    for scope in ("ui", "menu"):
        for action in ("click", "hover", "open", "close", "tab", "confirm", "toggle", "error"):
            add(f"{scope}_{action}", f"{scope}_{action}", bus="ui",
                variants=3 if action in ("click", "confirm", "open", "close") else 2,
                gain_db=-12 if action == "hover" else -6,
                cooldown_ms=100 if action == "hover" else 45,
                description=f"{scope}: tactile {action}; no musical notification tone")
    for action in ("new_game", "tutorial", "continue", "settings", "quit"):
        add("menu_" + action, "menu_" + action, bus="ui", variants=2, cooldown_ms=180)
    for key, recipe in [("country_select", "counter"), ("game_start", "game_start"),
                        ("ui_speed", "gear"), ("ui_pause", "pause"), ("ui_resume", "resume"),
                        ("unit_deselect", "lift"), ("notification_open", "envelope")]:
        add(key, recipe, bus="ui", variants=2, cooldown_ms=100)
    for key, family in [("select_unit", "infantry"), ("select_infantry", "infantry"),
                        ("select_armor", "armor"), ("select_artillery", "artillery"),
                        ("select_motorized", "motorized"), ("select_fleet", "naval"), ("select_air", "air")]:
        add(key, "selection", family=family, variants=3, gain_db=-7, cooldown_ms=130)
    for key, recipe in [("order_move", "move"), ("order_attack", "attack"),
                        ("order_stop", "stop"), ("order_retreat", "retreat"), ("deploy", "deploy")]:
        add(key, recipe, variants=3, cooldown_ms=160)
    for key, recipe, priority in [
        ("notify_info", "dispatch", 0), ("notify_good", "positive", 1),
        ("notify_bad", "negative", 1), ("notify_warning", "warning", 1),
        ("notify_urgent", "urgent", 3), ("event", "envelope", 1),
        ("war_declare", "war_dispatch", 3), ("war_declared_on", "urgent_war", 3),
        ("war_world", "remote_war", 2), ("peace_signed", "peace_document", 3),
        ("alliance_formed", "alliance_document", 2), ("guarantee_issued", "seal", 1),
        ("access_granted", "permit", 1), ("diplomacy_rejected", "negative", 1),
        ("war_justification", "war_dossier", 1), ("capitulation", "surrender", 3),
        ("battle_start", "battle", 1), ("government_change", "cabinet", 2),
    ]:
        add(key, recipe, variants=2, priority=priority, queue=True,
            cooldown_ms=700 if priority >= 2 else 400, gain_db=-4 if priority >= 3 else -7)
    for key, recipe, family in [
        ("build_queued", "work_order", "industry"), ("production_line", "work_order", "industry"),
        ("production_done", "work_done", "industry"), ("trade_deal", "trade", "governance"),
        ("diplomacy", "seal", "governance"), ("law_change", "law", "governance"),
        ("advisor_hire", "personnel", "governance"), ("advisor_dismiss", "dismiss", "governance"),
        ("decision_take", "decision", "governance"), ("research_start", "research", "electronics"),
        ("research_done", "research", "electronics"), ("focus_start", "research", "doctrine"),
        ("focus_done", "research", "doctrine"),
    ]:
        add(key, recipe, family=family, variants=2, phase="done" if key.endswith("done") else "start",
            queue=key.endswith("done"), priority=1, cooldown_ms=200)
    for building, family in [("civilian_factory", "industry"), ("military_factory", "infantry"),
                             ("synthetic_refinery", "motorized"), ("dockyard", "naval"),
                             ("naval_base", "naval"), ("air_base", "air"),
                             ("anti_air", "artillery"), ("infrastructure", "industry")]:
        add("map_" + building, "selection", family=family, gain_db=-15, bus="ui", cooldown_ms=350)
    for key, recipe in [("rifle_crack", "rifle"), ("mg_burst", "mg"),
                        ("artillery_boom", "artillery"), ("explosion", "explosion"),
                        ("naval_gun", "naval"), ("plane_flyby", "flyby"), ("tank_engine", "engine")]:
        add(key, "combat_" + recipe, variants=3, gain_db=-4, cooldown_ms=90, description="3D battlefield source, not a UI overlay")

    data = json.loads((ROOT / "data/common/technologies.json").read_text())
    research, categories = {}, {}
    # Exact tech identities: each has its own deterministic mechanical gesture.
    for tech_id, tech in sorted(data["techs"].items()):
        research[tech_id] = {}
        for phase in PHASES:
            key = f"research_{tech_id}_{phase}"
            add(key, "research", family=tech["cat"], phase=phase, identity=tech_id,
                bus="ui" if phase in ("select", "cancel") else "sfx", gain_db=-7 if phase == "select" else -5,
                queue=phase == "done", priority=2 if phase == "done" else 0,
                cooldown_ms=90 if phase == "select" else 220,
                description=f"{tech['name'].get('en', tech_id)} / {phase}")
            research[tech_id][phase] = key
    # Future/repeatable technologies have a real branch-specific fallback, never silence.
    for category in sorted(data["categories"]):
        categories[category] = {}
        for phase in PHASES:
            key = f"research_category_{category}_{phase}"
            add(key, "research", family=category, phase=phase, identity=category,
                bus="ui" if phase in ("select", "cancel") else "sfx",
                queue=phase == "done", priority=2 if phase == "done" else 0)
            categories[category][phase] = key
    if len({s.key for s in specs}) != len(specs):
        raise ValueError("Duplicate logical cue")
    return specs, research, categories


def render(cue: Cue, variant: int) -> np.ndarray:
    g = np.random.default_rng(stable_seed(f"{cue.key}:{variant}"))
    R = cue.recipe
    P = lambda material="paper", duration=.2: d.friction(g, material, duration)
    I = lambda material="wood", weight=1: d.impact(g, material, weight)
    S = lambda family=cue.family, duration=.32: d.signature(g, family, duration)
    def compose(*events): return d.mix(*events)
    if R in ("ui_hover", "menu_hover"):
        x = d.friction(g, "cloth", .035)
    elif R in ("ui_click", "ui_toggle", "menu_click", "menu_toggle", "gear", "menu_settings"):
        x = d.latch(g, R.startswith("menu"))
        if R == "menu_settings": x = compose((0, x, 1), (.07, d.ratchet(g, .07), .3))
    elif R in ("ui_open", "menu_open", "menu_new_game", "menu_tutorial", "menu_continue"):
        length = .26 if R.startswith("menu") else .13
        x = compose((0, d.paper(g, length), .7), (length * .68, I("leather", 1.7 if R.startswith("menu") else .8), .6))
        if R == "menu_continue": x = compose((0, x, 1), (.19, d.keys(g, 3), .32))
        if R == "menu_tutorial": x = compose((0, x, 1), (.15, P("pencil", .15), .5))
        if R == "menu_new_game": x = compose((0, x, 1), (.23, d.stamp(g, 1.25), .65))
    elif R in ("ui_close", "menu_close", "menu_quit"):
        x = compose((0, d.paper(g, .1), .38), (.072, I("leather", 1.25), .8), (.11, d.latch(g), .28))
    elif R in ("ui_tab", "menu_tab"):
        x = compose((0, d.paper(g, .09), .5), (.035, I("bakelite", .35), .5))
    elif R in ("ui_confirm", "menu_confirm", "seal", "law", "decision"):
        x = compose((0, P("pencil", .16), .23), (.12, d.stamp(g, 1.4 if R == "law" else .8), 1))
    elif R in ("ui_error", "menu_error", "negative", "warning", "diplomacy_rejected"):
        x = compose((0, d.latch(g, True), .6), (.105, I("wood", 1.3), .7), (.065, d.radio(g, .17), .18))
        if R in ("negative", "warning"): x = compose((0, x, 1), (.17, d.bell(g, True, .4), .25))
    elif R in ("counter", "lift", "selection"):
        x = compose((0, I("wood" if R != "lift" else "felt", .65), .7), (.025, P("cloth", .075), .15))
        if R == "selection": x = compose((0, x, 1), (.035, S(duration=.24), .43))
    elif R == "move":
        x = compose((0, P("paper", .15), .6), (.1, I("felt", .75), .65), (.17, d.radio(g, .12), .24))
    elif R in ("attack", "stop", "retreat", "deploy"):
        x = compose((0, I("wood", 1.25), .75), (.06, d.latch(g, True), .45))
        if R == "attack": x = compose((0, x, 1), (.15, d.stamp(g, 1.4), .85), (.21, d.radio(g, .22), .23))
        if R == "retreat": x = compose((0, d.radio(g, .17), .4), (.18, P("paper", .16), .7), (.29, x, .8))
        if R == "deploy": x = compose((0, x, 1), (.12, S("infantry"), .6))
    elif R == "pause": x = d.latch(g, True)
    elif R == "resume": x = compose((0, d.latch(g), .8), (.075, d.keys(g, 2, .05), .32))
    elif R in ("envelope", "dispatch", "positive"):
        x = compose((0, d.paper(g, .21), .48), (.055, d.keys(g, 4 if R == "dispatch" else 2), .75))
        if R == "positive": x = compose((0, x, 1), (.31, d.bell(g), .25))
        if R == "envelope": x = compose((0, x, 1), (.18, d.ratchet(g, .09), .2))
    elif R in ("urgent", "urgent_war", "war_dispatch", "remote_war"):
        x = compose((0, d.keys(g, 5, .045), .75), (.16, d.paper(g, .26), .55))
        if R != "remote_war":
            x = compose((0, x, 1), (.27, d.stamp(g, 2.1), 1), (.3, d.radio(g, .26), .25))
        if R in ("urgent", "urgent_war"):
            x = compose((0, x, 1), (.025, d.bell(g, True), .42), (.23, d.bell(g, True), .35))
        if R != "urgent": x = compose((0, x, 1), (.4, d.filtered(d.shot(g, "artillery"), 40, 950), .23))
    elif R in ("peace_document", "alliance_document", "permit", "war_dossier", "surrender", "cabinet", "game_start"):
        x = compose((0, d.paper(g, .3), .58), (.17, P("pencil", .25), .65), (.43, d.stamp(g, 1.7), .9))
        if R == "alliance_document": x = compose((0, x, 1), (.64, d.stamp(g, .9), .65), (.73, d.latch(g), .2))
        if R == "peace_document": x = compose((0, x, 1), (.6, I("leather", 1.5), .7))
        if R == "surrender": x = compose((0, x, 1), (.57, I("leather", 2.6), .9), (.68, d.radio(g, .22), .2))
        if R in ("cabinet", "game_start"): x = compose((0, x, 1), (.58, d.keys(g, 4), .55), (.88, d.latch(g, True), .7))
    elif R == "battle": x = d.filtered(d.shot(g, "artillery"), 45, 1600)
    elif R in ("work_order", "work_done", "trade", "personnel", "dismiss"):
        x = compose((0, d.paper(g, .17), .5), (.1, d.keys(g, 3, .052), .5), (.25, d.stamp(g), .7))
        if R.startswith("work"): x = compose((0, x, 1), (.12, S("industry"), .45))
        if R == "work_done": x = compose((0, x, 1), (.48, d.bell(g), .23))
        if R == "trade": x = compose((0, x, 1), (.28, I("brass", .36), .45), (.35, I("brass", .28), .25))
        if R == "dismiss": x = compose((0, d.paper(g, .22), .75), (.17, I("leather", 1.8), .9))
    elif R == "research":
        # A stable identity controls material weight AND gesture rhythm, not just pitch.
        identity = stable_seed(cue.identity or cue.key) % 997
        gesture_delay = .045 + identity % 7 * .009
        family = cue.family
        if cue.identity == "motorization": family = "motorized"
        sig = S(family, .22 if cue.phase == "select" else .4)
        if "computing" in cue.identity: sig = compose((0, d.keys(g, 6, .035), .7), (.09, d.ratchet(g, .14), .4))
        elif "radar" in cue.identity: sig = compose((0, d.radio(g, .27), .6), (.09, d.ratchet(g, .15), .55))
        elif "submarine" in cue.identity: sig = compose((0, d.latch(g, True), .75), (.07, d.filtered(P("steel", .24), 90, 1900), .5))
        elif "government_" in cue.identity:
            arrangements = {"democratic": 2, "fascism": 3, "communism": 5, "neutrality": 1}
            count = next((v for name, v in arrangements.items() if name in cue.identity), 2)
            sig = compose((0, d.keys(g, count, .045), .5), (.04 + count * .04, d.stamp(g, .8 + count * .15), .8))
        if cue.phase == "select":
            x = compose((0, d.paper(g, .07), .36), (.015, I("felt", .6), .5), (gesture_delay, sig, .38))
        elif cue.phase == "start":
            x = compose((0, d.paper(g, .16), .4), (.08, d.keys(g, 2 + identity % 3, .042), .4),
                        (.19 + gesture_delay, sig, .6), (.28 + gesture_delay, d.stamp(g, .95), .65))
        elif cue.phase == "done":
            x = compose((0, d.keys(g, 3 + identity % 3, .043), .5), (.17 + gesture_delay, sig, .6),
                        (.37 + gesture_delay, d.stamp(g, 1.45), .9), (.52 + gesture_delay, d.ratchet(g, .09), .4))
        else:
            x = compose((0, d.paper(g, .12), .5), (.055, d.filtered(sig, 200, 2700), .19),
                        (.135, I("leather", .95), .65))
    elif R.startswith("combat_"):
        kind = R.removeprefix("combat_")
        if kind == "mg":
            shot = d.shot(g, "rifle")
            x = compose(*[(i * .079, shot, float(g.uniform(.67, 1))) for i in range(5)])
        elif kind == "engine": x = d.engine(g, 1.4, False)
        elif kind == "flyby":
            x = d.engine(g, 1.8, True)
            x *= np.sin(np.linspace(0, np.pi, len(x))) ** 1.5
        else: x = d.shot(g, kind)
    else: raise ValueError(f"No renderer for {R}")
    if not R.startswith("combat_"): x = d.small_room(g, x, .09 if R.startswith("menu") else .05)
    rms = -29 if R.endswith("hover") else (-21 if cue.priority >= 2 else -23)
    if R.startswith("combat_"): rms = -18
    return d.master(x, rms, -2.0 if cue.priority >= 2 or R.startswith("combat_") else -4.0, g)


def filenames(cue: Cue) -> list[str]:
    return [f"{cue.key}{'_' + str(i + 1) if cue.variants > 1 else ''}.wav" for i in range(cue.variants)]


def validate(out: Path, specs: list[Cue]) -> dict:
    rows, problems, hashes = [], [], {}
    for cue in specs:
        for name in filenames(cue):
            path = out / name
            if not path.is_file():
                problems.append(f"Missing {name}")
                continue
            with wave.open(str(path), "rb") as stream:
                info = (stream.getnchannels(), stream.getsampwidth(), stream.getframerate())
                raw = stream.readframes(stream.getnframes())
            if info != (1, 2, d.SR): problems.append(f"Wrong format: {name} {info}")
            x = np.frombuffer(raw, dtype="<i2").astype(float) / 32768
            peak = float(np.max(np.abs(x)))
            duration = len(x) / d.SR
            digest = hashlib.sha256(raw).hexdigest()
            if digest in hashes: problems.append(f"Duplicate audio: {name} = {hashes[digest]}")
            hashes[digest] = name
            peak_db = 20 * math.log10(max(peak, 1e-12))
            dc = float(abs(np.mean(x)))
            if peak > .805 or peak < .003: problems.append(f"Peak outside safe range: {name} {peak_db:.1f} dBFS")
            if duration < .02 or duration > 4.0: problems.append(f"Invalid cue duration: {name} {duration:.2f}s")
            if dc > .005: problems.append(f"DC offset: {name} {dc}")
            if x[0] != 0 or x[-1] != 0: problems.append(f"Boundary click risk: {name}")
            if not np.any(np.abs(x[:int(.08 * d.SR)]) > .0008): problems.append(f"Slow attack: {name}")
            rows.append({"file": name, "duration": round(duration, 4), "peak_dbfs": round(peak_db, 2),
                         "rms_dbfs": round(20 * math.log10(max(float(np.sqrt(np.mean(x*x))), 1e-12)), 2),
                         "dc": round(dc, 7), "sha256": digest, "bytes": path.stat().st_size})
    return {"sample_rate": d.SR, "files": len(rows), "bytes": sum(row["bytes"] for row in rows),
            "problems": problems, "assets": rows}


def audition(out: Path) -> None:
    keys = ["menu_click_1", "menu_open_1", "ui_click_1", "select_infantry_1", "select_armor_1",
            "select_fleet_1", "select_air_1", "research_infantry_weapons_2_select", "research_infantry_weapons_2_done",
            "research_radar_1_done", "research_government_democratic_transition_start", "law_change_1",
            "war_declare_1", "peace_signed_1", "alliance_formed_1", "notify_urgent_1"]
    events, index, offset = [], [], .15
    for key in keys:
        path = out / f"{key}.wav"
        if not path.exists(): continue
        with wave.open(str(path), "rb") as stream:
            x = np.frombuffer(stream.readframes(stream.getnframes()), dtype="<i2").astype(float) / 32768
        events.append((offset, x, .75))
        index.append({"time": round(offset, 2), "cue": key})
        offset += len(x) / d.SR + .35
    d.write_wav(out / "audition.wav", d.mix(*events))
    (out / "audition.json").write_text(json.dumps(index, indent=2) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--only", action="append", default=[], help="Glob; repeatable. Existing unrelated files are untouched.")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    specs, research, categories = specifications()
    selected = [cue for cue in specs if not args.only or any(fnmatch.fnmatchcase(cue.key, pattern) for pattern in args.only)]
    if not selected: parser.error("No cues matched --only")
    if args.list:
        for cue in selected: print(cue.key, cue.variants, cue.family, cue.phase)
        return 0
    out = args.out.resolve()
    if not args.check:
        out.mkdir(parents=True, exist_ok=True)
        for i, cue in enumerate(selected):
            for variant, name in enumerate(filenames(cue)):
                d.write_wav(out / name, render(cue, variant))
            if i % 30 == 0: print(f"{i+1}/{len(selected)} {cue.key}", flush=True)
        # A full catalog is only published when every referenced source exists.
        missing = [name for cue in specs for name in filenames(cue) if not (out / name).is_file()]
        if not missing:
            sounds = {}
            for cue in specs:
                desc = {field: getattr(cue, field) for field in ("gain_db", "bus", "priority", "queue", "cooldown_ms", "description")}
                desc["files"] = ["res://assets/audio/ww2/" + name for name in filenames(cue)]
                sounds[cue.key] = desc
            catalog = {"version": SCHEMA, "sample_rate": d.SR, "seed": SEED, "generator": "tools/build_ww2_sfx.py",
                       "license": "Original procedural synthesis; no third-party samples or music.",
                       "sounds": sounds, "research": research, "research_categories": categories}
            (out / "catalog.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
            audition(out)
        else:
            print(f"Partial build: {len(missing)} other files absent; full catalog not published.")
    report = validate(out, selected)
    if not args.check: (out / "qa.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"{len(selected)} cues / {report['files']} WAVs / {report['bytes']/1024**2:.2f} MiB; {len(report['problems'])} QA problems")
    for problem in report["problems"]: print("ERROR:", problem)
    return 1 if report["problems"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
