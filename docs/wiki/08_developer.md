**English** · [Türkçe](tr/08_gelistirici.md)

# Developer notes

## Tests
Everything runs headless and exits with 1 when it finds a problem. On pull requests and pushes to main, GitHub Actions
(`.github/workflows/tests.yml`) runs `tools/run_tests.sh`; the balance test lives in the same workflow but only runs when
triggered by hand.

| Command | What it does |
|---|---|
| `GODOT=godot tools/run_tests.sh` | Import + `tests/run.gd` + `country_check` (60 days); step by step and an overall result |
| `godot --headless --path . -s tests/run.gd [-- --file=test_data] [--filter=hatay]` | Test suite: every `test_*` function in `tests/test_*.gd` runs on a fresh game |
| `godot --headless --path . -s game/dev/country_check.gd -- --days=150` | Starts the game with each of the 80 countries; checks that player actions affect the game and that nothing is done automatically for the player |
| `godot --headless --path . -s game/dev/gov_check.gd -- --player=TUR` | 1936 effective stability/home front, dated events, elections |
| `tools/balance_parallel.sh 6` | 1936–1942 historical flow balance test (12 checks; each must pass at least 5/6, otherwise exit 1) |
| `godot --headless --path . -s game/dev/playtest.gd` | Turkey → Iraq war, orders, surrender, save/load |

### Writing a test
A `tests/test_<topic>.gd` file starts with `extends "res://tests/test_case.gd"`; every function starting with `test_` is
a test. Before each test the runner calls `Game.new_game()` + `World.start_game(player_tag())` (TUR by default; override
`player_tag()` in the file to change it). Assertions: `check`, `eq`, `near`, `gt`, `ge`, `lt`, `none` (the list must be
empty), `fail`, `warn` (does not turn red); helpers: `days(n)`, `player()`, `country(tag)`, `read_json(path)`.
An engine/script error printed during a test (`push_error`, SCRIPT ERROR) also turns the test red.
The data tests (`tests/test_data.gd`) read the effect and condition keys the engine knows from `politics.gd`; a new effect
that is not added to `apply_effects` and `describe_effects` turns the test red.

| File | Scope |
|---|---|
| `test_data.gd` | Data references, effect dictionary, translation table |
| `test_economy.gd` | Construction, building slots, public construction floor, production efficiency, resource shortfall, consumer goods |
| `test_trade.gd` | Manual deals, payment limit, no trade with enemies (player and AI), automatic trade, convoys |
| `test_politics.gd` | Stability/home front formulas, law requirements, advisors, decisions, timed national conditions, elections, dated events, locked options |
| `test_diplomacy.gd` | Casus belli, crisis index thresholds, joining wars, surrender progress and limit, state transfer, white peace |
| `test_land_combat.gd` | Combat multipliers and damage, entrenchment, hold to the last man, retreat, encirclement, supply, army → front |
| `test_commanders.gd` | Commander rosters, assignment/promotion/new general costs, combat bonus, experience, no automatic assignment for the player, direct orders |
| `test_navy_air.gd` | Fleet missions/return, naval combat, convoy raiding, wings, air superiority |
| `test_military.gd` | Training time (conscription law) |
| `test_save_load.gd` | 200 days → save → load: every field identical (a differing field is named) |
| `test_determinism.gd` | Two runs with the same seed give the same world |
| `test_sea_lanes.gd` | Sea lanes only cross water; every port–sea / sea–sea neighbour has a route and a quay |
| `test_fleet_motion.gd` | The fleet's visual position (corner curves, leaving port, sailing) stays at sea; the FleetLayer formation never spills onto land |
| `test_map_logic.gd` | Division path continuity, movement arrows, weather, counter/flag/hidden modes by zoom |

Tests that need the map image load the region image (`data/map/provinces.png`) once through `tests/map_probe.gd`; layer
tests use `ProbeMap` (a MapView3D subclass that skips the heavy textures). If the sea lanes change,
`python3 tools/build_sea_lanes.py` (~1 min, `pip install pillow numpy scipy`) rebuilds the network and repairs land contact.

A game continued from a save starts with `World.resume_game(tag)` (the player's saved preferences are kept);
`World.start_game(tag)` sets the player defaults only for a new game. When you add a country/division field, add it to the
save as well: `test_save_load.gd` catches an unsaved field by name (fields recomputed every day are in the DERIVED list in
`tests/snapshot.gd`).

## Developer arguments (`godot --path . -- ...`)
`--play=TAG`, `--panel=politics|focus|research|diplomacy|trade|construction|production|army|navy|air|logistics`,
`--target=TAG` (diplomacy), `--event=id[,FROM]`, `--select=PID`, `--days=N`, `--dist=N` (camera), `--demo_order`,
`--demo_fleet`, `--weather=rain|snow`, `--war=A,B`, `--screenshot=file.png --wait=N`, `--click=x,y`,
`--pause_menu`, `--settings` (in-game settings), `--menu_settings` (main menu settings), `--lang_test=en|tr`,
`--gameover=win|lose`, `--politics_of=TAG` (another country's politics), `--ctrl_hover=x,y` (country card),
`--hover_at=x,y` (region card at a screen position), `--army=TAG [--army_select --army_cmd]` (all divisions in one army
facing TAG), `--army_demo=TAG [--army_sel=a:1|g:1] [--sel_demo]` (sample chain of command / mixed selection).
To try the web renderer on desktop: `godot --path . --rendering-method gl_compatibility -- ...`

## New icon set and leader portraits
- Prompt list: `docs/art/ICON_PROMPTS.md` (regenerated with `python3 tools/make_icon_prompts.py`).
- Icons go to `assets/ui/icons_new/<name>.png` → the game uses them instead of the old icon automatically.
- Portraits go to `assets/portraits/<TAG>.png` (the 1936 leader) and `assets/portraits/<first_last>.png` (a leader who
  comes through an event, e.g. `ismet_inonu.png`) → shown instead of the flag on the top bar and in the Politics and
  Diplomacy screens; the flag otherwise.

## Data
Content lives in `data/common/*.json` (countries, laws, national conditions and advisors in `spirits.json`, events, state
programs in `focuses.json`, technologies, units, buildings, equipment, commanders in `commanders.json`).
If an event option has `"require": [conditions]`, it shows as locked until they are met; the AI does not pick it either.

## Language
The game's main language is English; every text is in `game/localization/strings.csv` in English and Turkish. With no
saved setting the game starts in English (`GameSettings.DEFAULT_LANG`); Settings → Language switches it and remembers it.
The documentation follows the same rule: the English file is the main one, the Turkish one sits next to it
(`*.tr.md`, `docs/wiki/tr/`).
