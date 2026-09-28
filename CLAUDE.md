**English** · [Türkçe](CLAUDE.tr.md)

# Iron Front — Claude Code working rules

A World War II grand strategy game set in 1936–1948, playable as any of 80 countries. Godot 4.7.2, GDScript,
data-driven (`data/common/*.json`). Web version: https://gmmrx.github.io/iron-front/ (republished on every push to main).
Game wiki: `docs/wiki/` (Turkish in `docs/wiki/tr/`), roadmap: `ROADMAP.md` (Turkish in `ROADMAP.tr.md`).
**Talk to the user in Turkish.** The main language of the game and of the documentation is English.

## Setup (Linux, headless)
```
GODOT_VERSION=4.7.2
BASE=https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable
curl -sSL -o godot.zip $BASE/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip
unzip -q godot.zip -d ~/godot && mv ~/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64 ~/godot/godot
export GODOT=~/godot/godot
$GODOT --headless --path . --import      # once; again after a new class_name / translation change
```
For the Python tools: `pip install pillow numpy scipy`.

## Tests (all headless)
| Command | What it measures |
|---|---|
| `GODOT=$GODOT tools/run_tests.sh` | import + `tests/run.gd` + country_check (60 days); this is the CI job |
| `$GODOT --headless --path . -s tests/run.gd [-- --file=test_data]` | test suite (`tests/test_*.gd`, each test on a fresh game; how to write one: `docs/wiki/08_developer.md`) |
| `$GODOT --headless --path . -s game/dev/country_check.gd -- --days=150` | with each of the 80 countries: do player actions affect the game, is anything done automatically for the player (exit code 1 = problem) |
| `GODOT=$GODOT tools/balance_parallel.sh 6` | 1936–1942 historical flow, 12 checks. Each check must pass at least 5/6 |
| `$GODOT --headless --path . -s game/dev/gov_check.gd -- --player=TUR` | 1936 stability/home front, dated events, elections |
| `$GODOT --headless --path . -s game/dev/playtest.gd` | Turkey → Iraq war, orders, surrender, save/load |
| `$GODOT --headless --path . -s game/dev/sim.gd` | simulation speed (profile) |
| `$GODOT --headless --path . -s tests/run.gd -- --file=test_modes` | game mode system (registry, patch merge, mode switching, save version) |

The balance test takes long (~15–20 min, 6 parallel processes); run it after any change to game logic.

## Fixed rules
1. **The player decides everything.** Nothing is done automatically on the player's behalf (trade, production,
   assignments, retreats, air wings, commanders…). If an automatic convenience is needed, it is an option that starts off
   and the player switches on. AI countries may be automatic. Historical pressures and crises arrive as events with 2–3
   real options.
2. **Data-driven**: content lives in `data/common/*.json`; engine code is independent of content. For event/program
   effects use the existing effect dictionary (`game/autoload/politics.gd` → `apply_effects` and `describe_effects`). If
   you add a new effect, add it to both.
3. **All texts** are in `game/localization/strings.csv` in **English and Turkish**. A CSV change needs `--import`.
   Without a saved setting the game starts in English (`GameSettings.DEFAULT_LANG`); Turkish is chosen in
   Settings → Language.
4. **Originality (legal risk): read `docs/ORIGINALITY.md` first** (Turkish: `docs/OZGUNLUK.md`). Never mention other
   commercial games' names or wiki addresses in any file (code, comments, documents, commit messages); not through
   euphemisms like "like the genre classic" or "parity" either. Take no name, text, number table or screen layout from
   another game; names are historical or ours, numbers come from our own formula with the reason written down.
   "Iron Front" is a working title; never hard-code the game's name in texts.
5. **You cannot see the visuals**: make no render, shader, lighting, colour, camera or model changes; the desktop
   (Forward+) and web (gl_compatibility) picture must not break. If you need to add interface, use only the existing
   helpers (`game/ui/panel_layout.gd`: `frame`, `fixed`, `info_cells`, `section`, `row`, `row_action`, `table`,
   `table_row`, `small_button`, `progress`, `tile`, `empty`; `UiTheme.skin()`, `UiTheme.mark_unavailable()` for a feature
   whose interface exists but has no effect yet), invent no new visual style.
6. **Do not download or generate art files** (icons, portraits, pictures, sounds). Icon/portrait names are listed with
   `tools/make_icon_prompts.py`; the user makes the files.
7. Do not touch: `docs/reference/`, `topbar.png`, `art/prototypes/`, `tools/blender/dress_survivor.py`,
   `tools/blender/inspect_survivor.py`.
8. GDScript: do not infer a variable with `:=` from an expression of unknown type ("Cannot infer the type" parse error);
   write the type explicitly (`var x: bool = ...`). Autoloads: World, Economy, Politics, Research, Diplomacy, Military,
   Navy, Air, AI, Game, GameClock, Audio.
9. The player's country is `World.player_tag`; `World.start_game(tag)` sets the player-specific defaults (manual trade,
   manual wings, "hold to the last man"); a game continued from a save uses `World.resume_game(tag)` (preferences are
   kept). Save/load: `game/autoload/game.gd` — add every new country/division field to the save.

## Game modes
- A mode = `data/modes/<id>/mode.json` manifest + only the data files it changes (a full file or a `.patch.json`) + an
  optional `game/modes/<id>/rules.gd` (`extends ModeRules`). Registry: `data/modes/modes.json`. The first mode is `ww2`
  (today's game, its data is `data/common`).
- When writing a mode, do not change the engine; if a hook you need is missing, ask. Guide: `docs/modlar/README.md`,
  skeleton: `python3 tools/new_mode.py <id>`, check: `--check <id>`. The engine reads through `GameModes` (pure, static):
  dates, player, major powers, starting technologies, AI calendar; data files (including `history.json`) through
  `GameModes.load_json`. WWII behaviour must stay exactly the same as without modes.
- In modes other than `ww2`, `balance.gd`, `gov_check.gd` and `playtest.gd` exit with code 2 (WWII-specific); a mode is
  checked by `country_check --game_mode=<id>` and `tests/test_mode_<id>.gd`. Zombie mode design (Turkish):
  `docs/modlar/zombi/`.

## Workflow
- Every task is **its own branch + pull request**. **No direct push to main** (a push to main republishes the web version).
- In the PR description: what changed, which tests ran and their results (with numbers), known limits.
- Commit messages in Turkish. If you added a new mechanic, update the relevant pages in `docs/wiki/` and `docs/wiki/tr/`,
  and the status in `ROADMAP.md` and `ROADMAP.tr.md`.
- **Documentation is bilingual**: the main file is English (`README.md`, `ROADMAP.md`, `docs/wiki/*.md`,
  `docs/ORIGINALITY.md`, `docs/cloud/TASKS.md`), the Turkish one sits next to it (`*.tr.md`, `docs/wiki/tr/`,
  `docs/OZGUNLUK.md`, `docs/cloud/GOREVLER.md`). If you change one, update the other in the same task; every file links
  to its other language at the top.
