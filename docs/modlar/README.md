**English** · [Türkçe](README.tr.md)

# Game modes — contributor guide

The game can carry several **modes**. The first mode is today's World War II game (`ww2`). A new mode brings its own data,
start date, playable countries and an optional small rule script without changing the engine. The design research for the
zombie outbreak mode is in the [zombi/](zombi/README.md) folder (in Turkish).

This page is written for people who code with an AI assistant ("vibecoders"). You can give your assistant the one-page
summary [ASSISTANT.md](ASSISTANT.md). If you use Claude Code, the `yeni-mod` skill follows these steps by itself.

> **Read first:** [docs/ORIGINALITY.md](../ORIGINALITY.md). Take no name, text, number table or screen layout from another game.

---

## Your first mode in 30 minutes

```bash
# 1) skeleton: folder, manifest, rule script, test; adds the mode to the registry
python3 tools/new_mode.py cold_war --name-en "Cold War" --name-tr "Soğuk Savaş"

# 2) edit the manifest: data/modes/cold_war/mode.json (dates, player, description)

# 3) change the data (details below)
python3 tools/new_mode.py --blank cold_war common/events.json     # no WWII events
python3 tools/new_mode.py --blank cold_war common/focuses.json    # no WWII program trees
python3 tools/new_mode.py --blank cold_war common/history.json    # no WWII history timeline
python3 tools/new_mode.py --copy  cold_war common/laws.json       # I will rewrite the laws

# 4) quick check (no Godot needed)
python3 tools/new_mode.py --check cold_war

# 5) open it in the game (or New Game → mode list in the menu)
godot --path . -- --game_mode=cold_war

# 6) tests
godot --headless --path . --import                                # if you added a new .gd file
godot --headless --path . -s tests/run.gd -- --file=test_mode_cold_war
godot --headless --path . -s tests/run.gd -- --file=test_modes
godot --headless --path . -s game/dev/country_check.gd -- --game_mode=cold_war --days=30
```

When you are done, open a pull request from a separate branch and write the test results with numbers in the description.

---

## Folders

```
data/modes/
  modes.json                       registry: {"default": "ww2", "modes": ["ww2", "_template", ...]}  (order = menu order)
  ww2/mode.json                    WWII: only the manifest; its data is data/common, data/history, data/map
  _template/                       a hidden but WORKING example mode (CI tests it on every run) — start by copying it
    mode.json
    scenario.json                  start ownership layer
    common/events.patch.json       adds 1 event, deletes 2 WWII events
    own/settings.json              the mode's own data (read by the rule script)
  <id>/                            your mode: manifest + ONLY the files that change
game/modes/<id>/rules.gd           optional code hooks (extends ModeRules)
tests/test_mode_<id>.gd            the mode's tests
```

**Not allowed** (caught by `--check` and `tests/test_modes.gd`):
- Only `.json` goes under `data/modes/**`. A `.gd` file under `data/` is not loaded (the folder is hidden from the engine);
  scripts go under `game/modes/<id>/`. Translations go into `game/localization/strings.csv`. No image/sound files
  (CLAUDE.md rule 6).
- No `map/`: the map geometry is shared by all modes (see "Known limits" below).
- For every `X.json` or `X.patch.json` in the mode folder, `data/X.json` must exist (this catches typos).
  The only exception is `own/`: the mode's own data (below).
- A file cannot have both a full copy (`X.json`) and a patch (`X.patch.json`): the patch is applied on top of the copy and
  its `null`s silently delete the records you edited in the copy.

---

## Manifest (`mode.json`)

A field you leave out takes the WWII value.

| Field | Type | Default (WWII) | Meaning |
|---|---|---|---|
| `id` | text | — (required) | same as the folder name; lowercase letters, digits, `_` |
| `name` | `{en, tr}` | — (required) | name in the menu |
| `hidden` | bool | `false` | `true`: not shown in the menu (for unfinished modes) |
| `description` | `{en, tr}` | — | under the name in the menu |
| `subtitle` / `subtitle_key` | `{en, tr}` / CSV key | `MENU_SUBTITLE` | main menu subtitle |
| `welcome` / `welcome_key` | `{en, tr}` (exactly one `%s`) | `NOTE_WELCOME` | news at the start of the game (`%s` = country name; percent sign `%%`) |
| `end_text` / `end_text_key` | `{en, tr}` | `GAMEOVER_TIME` | game-over text when time runs out |
| `start_date` | `"YYYY-MM-DD"` | `1936-01-01` | start date (a day that exists in the calendar; cannot be empty) |
| `end_date` | `"YYYY-MM-DD"` or `""` | `1948-01-01` | time limit (`""` = none) |
| `start_tension` | number | `0.0` | starting crisis index |
| `default_player` | country tag | `TUR` | country selected first in the country selection |
| `featured` | [country tag] | 8 large countries | the cards above the country selection |
| `playable` | `"all"` or [country tag] | `"all"` | selectable countries |
| `menu_focus` | country tag | `GER` | where the main menu camera drifts |
| `majors` | [country tag] | GER ENG FRA ITA SOV | major powers (research slot, AI behaviour) |
| `start_techs` | [technology] | 4 basic technologies | given at the start to large and populous countries |
| `start_techs_min_population` | integer | `15000000` | countries above this population get them too |
| `ai.rearm_year` | year (`0` = off) | `1939` | after this year the AI turns to military factories |
| `ai.cautious_until` | date (`""` = off) | `1942-01-01` | democracies are cautious towards major powers until this date |
| `ai.phoney_war_days` | days (`0` = off) | `270` | democracies are reluctant in the first days of a war |
| `ai.major_hold_fire_days` | days (`0` = off) | `240` | major powers do not attack each other's homeland for this many days |
| `combat.phoney_war_days` | days | `270` | how long the democracies' reluctance penalty lasts in combat |
| `scenario` | file name | `""` | start ownership layer (below) |
| `rules` | `res://game/modes/<id>/rules.gd` | `""` | code hooks (below) |

For an "off" value do not write `null`; write `0` or `""`.

---

## Changing data: a full file or a patch

A mode can change every JSON under `data/` (except the map geometry) in two ways:

| Way | When | How |
|---|---|---|
| **Full file** | most of the file will change | `data/modes/<id>/common/laws.json` (copy: `--copy`). Replaces the **whole** base file. |
| **Patch** | a few things are added/removed | `data/modes/<id>/common/events.patch.json`. Deep-merged with the base file. |

**Patch rules:**
- Dictionaries merge recursively. A key whose value is `null` is **deleted**; a new key is added at the end.
- Arrays whose items carry an `"id"` merge by id: the same id is updated, a new id is added at the end,
  `{"id": "x", "_delete": true}` deletes that item.
- Other arrays and values are replaced as they are.
- The base order is kept; the result is the same every time (deterministic).

Example (`_template`):
```json
{"events": {
  "jap_february_26": null,
  "template_hello": {"title": {"en": "...", "tr": "..."}, "options": [...], "trigger": {"tag": "TUR", "date": "1936-01-10"}}
}}
```

**`--blank`:** writes a patch that removes every WWII event for `common/events.json`, every country program tree for
`common/focuses.json`, and the history timeline for `common/history.json`. The engine's own events and the `_generic` tree
stay. If you empty the events, empty the trees too: WWII programs fire some events. If you empty the trees, empty the
timeline too: the timeline completes WWII programs (the tool warns about both, and the tests catch it).

**History timeline (`common/history.json`):** AI countries take the historical steps listed here on their exact day (wars,
annexations, alliances); the player's country never takes any of them by itself. Before the `ai_free_from` date the AI does
not start wars on its own and does not answer calls to a war of aggression (1945-09-02 in WWII). A mode can write its own
timeline (`{"ai_free_from": "YYYY-MM-DD", "entries": [{"date", "tag", "focus" | "mark_focus" | "effects", "require"}]}`)
or empty it with `--blank`; with an empty timeline `ai_free_from` becomes the mode's start date.

## Scenario layer (`scenario.json`)

The map is shared, but the starting borders can change per mode:
```json
{"owners": {"346": "TUR"}, "capitals": {"TUR": 346}, "vp": {"123": 10}}
```
`owners`: state id → country; `capitals`: country → state id; `vp`: city id → victory points. The ids are in
`data/map/states.json` and `data/map/cities.json`. Population, manpower and control are recomputed automatically.
An id of a state/country/city that does not exist (a typo) turns `test_modes::test_mode_contract` red.

## The mode's own data (`own/`)

Everything with no counterpart in the WWII data (e.g. epidemic parameters, zombie types, a research centre table) is
written to `data/modes/<id>/own/<name>.json` files. This folder has no "does the base file exist" check and no
full-file/patch rule; the engine does not read these files by itself, **your rule script** does:
```gdscript
var cfg: Variant = GameModes.load_own("epidemic.json")     # null if missing
```
Do not hard-code numbers in code; put them here (CLAUDE.md rule 2). Example: `data/modes/_template/own/settings.json` and
`game/modes/_template/rules.gd`.

---

## Rule script (`game/modes/<id>/rules.gd`)

Small code hooks for when data is not enough. `extends ModeRules`; delete the hooks you do not use. Full list:
[`game/core/mode_rules.gd`](../../game/core/mode_rules.gd), example: [`game/modes/_template/rules.gd`](../../game/modes/_template/rules.gd).

| Hook | When |
|---|---|
| `on_new_game()` | on every new game (at startup and at the end of `Game.new_game`); a fresh script instance for every game |
| `on_game_started(player)` | when the player picks a country and enters the game |
| `on_day()` / `on_hour()` / `on_month()` | every day (after the AI, before the game-over check) / hour / month |
| `check_end()` | `{}` = go on; `{"victory": bool, "reason": "<CSV key>"}` = the game ends |
| `score(tag)` | game-over score (`-1` = sum of victory points) |
| `to_save()` / `from_save(d)` | the mode's own state is written to / read from the save (write large integers with `str()`) |
| `effect_keys()`, `apply_effect`, `describe_effect` | a **new effect** for events/programs (add all three; CLAUDE.md rule 2) |
| `condition_keys()`, `check_condition` | a **new condition** for events/programs |

Rules: do nothing on the player's behalf (rule 1); if you need randomness, seed your own `RandomNumberGenerator` and write it
to the save; you can reach the autoloads by name (`World`, `Economy`...), but if you need to change engine files, **stop and
ask**.

## Texts

- Texts inside data are JSON `{"en": "...", "tr": "..."}` (event titles, mode name...).
- Interface or rule-script texts go into `game/localization/strings.csv` as English and Turkish rows; then
  `godot --headless --path . --import`.

---

## Mode contract

The engine refers to some keys directly. A mode's data must not delete them; `tests/test_modes.gd::test_mode_contract` and
`test_mode_<id>` check this.

| File | Key | If missing |
|---|---|---|
| `common/events.json` | `call_to_arms`, `white_peace`, `election`, `faction_invite` | `call_to_arms`/`faction_invite`: no error, silently does nothing (allies are not called to war, the invitation is lost); `white_peace`: the peace offer never reaches the player; `election`: the election window errors |
| `common/focuses.json` | `trees._generic` | the program tree errors every time it is asked for; countries without their own tree have no programs |
| `common/laws.json` | the `conscription`, `economy`, `trade` groups; `start._default` | law setup crashes |
| `common/spirits.json` | `popularity._<ideology>` (for every ideology of the countries), `start`, `start_factions` | politics setup crashes |
| `common/units.json` | `start_divisions._default`, `templates` (at least one template; 0: infantry, 1: armour), `terrain.plains` (fallback for unknown terrain) | army setup crashes |
| `common/equipment.json` | `infantry_equipment`, `convoy`; `start_fleets._default_coastal` | production/convoy/fleet setup crashes |
| `common/buildings.json` | `oil` among the resources | fuel calculation |
| `common/technologies.json` | every technology in `start_techs` | the starting technology cannot be given |
| `common/countries.json` | every country that owns a state on the map | the map cannot load |

## Definition of "done"

1. `python3 tools/new_mode.py --check <id>` → no problems
2. `-s tests/run.gd -- --file=test_modes` and `--file=test_mode_<id>` → all pass
3. `-s game/dev/country_check.gd -- --game_mode=<id> --days=30` → 0 problems
4. `GODOT=... tools/run_tests.sh` (the CI job; runs every mode) → all pass
5. If you touched engine code, the WWII balance test: `GODOT=... tools/balance_parallel.sh 6` (each check at least 5/6)

## Known limits

- **The map is shared.** All modes use the same region/state/city geometry; a separate map package (≈120 MB) would bloat
  the web version. Borders change through `scenario.json`.
- **Engine details written for WWII.** They work as long as the mode keeps the same ids: ideology names
  (democratic/communist/fascist/non-aligned), the AI's law and advisor order (`ai.gd`), a few country-specific AI settings,
  the equipment of the starting production lines. A mode that changes them leaves the AI passive on that subject.
- **Unit models, icons, sounds** cannot be changed from a mode (rules 5 and 6); visual needs are listed and the user makes them.
- **No mode-specific interface panel or map mode.** If needed, it is added as a separate task, only with the `panel_layout`
  helpers.
- **The WWII checks** (`balance.gd`, `gov_check.gd`, `playtest.gd`) only run in the `ww2` mode.
- A mode's save opened in an older version loads onto the WWII data.

## FAQ

- **My mode does not show up in the menu.** Is it registered in `modes.json`? (`--check` reports it as a problem.) Is
  `"hidden": true` still in `mode.json`? (`--check` prints this as an "info" line; set it to `false`.)
- **Log warning "Kaydın oyun modu bulunamadı…" (the save's game mode was not found).** The save comes from a mode that is
  not registered (deleted or renamed).
- **I want a new effect.** First look at the existing effect dictionary (`game/autoload/politics.gd` → `apply_effects`); if
  it is not there, `effect_keys` + `apply_effect` + `describe_effect` in `rules.gd`.
- **The test says "unknown effect".** The effect key is neither in the engine nor in the `effect_keys()` list of `rules.gd`.
