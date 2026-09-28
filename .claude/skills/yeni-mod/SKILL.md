---
name: yeni-mod
description: Add a new game mode to this strategy game or edit an existing one (data/modes, game/modes). Use for requests like "new mode", "new scenario", "add a game mode", "zombie mode", "mode data", "mode.json" — also in Turkish: "yeni mod", "yeni senaryo", "oyun modu ekle", "zombi modu", "mod verisi".
---

# New game mode

Detailed guide: `docs/modlar/README.md` (Turkish: `docs/modlar/README.tr.md`). This skill applies its steps in order.
Talk to the user in Turkish.

## 0. Read first
- `docs/ORIGINALITY.md`: take no name, text, number or screen layout from another game; never mention another commercial
  game in any file.
- `CLAUDE.md` rules: the player decides (rule 1), data-driven (2), texts EN+TR (3), no visual changes (5), no art files (6).

## 1. Skeleton
`python3 tools/new_mode.py <id> --name-en "..." --name-tr "..."` → `data/modes/<id>/mode.json`,
`game/modes/<id>/rules.gd`, `tests/test_mode_<id>.gd`, registry (`data/modes/modes.json`). Id: lowercase letters, digits, `_`.
Then `godot --headless --path . --import` (for the new .gd files).

## 2. Manifest
The `mode.json` fields are in the README table. A field left out takes the WWII value. An "off" value is `0` or `""` (not null).
To hide an unfinished mode from the menu: `"hidden": true`.

## 3. Data
- If most of a file changes: `python3 tools/new_mode.py --copy <id> common/<file>.json`, then edit it.
- A few additions/deletions: `data/modes/<id>/common/<file>.patch.json` (`null` deletes; `_delete` in arrays with an `"id"`).
- No WWII events, country trees or history timeline: `--blank <id> common/events.json`, `--blank <id> common/focuses.json`
  AND `--blank <id> common/history.json` (the timeline completes WWII programs; with an empty timeline the AI may start its
  own wars from the first day).
- A file cannot have both a full copy and a patch (the tool and `--check` stop it).
- Data with no counterpart in WWII (epidemic, a new table...): `data/modes/<id>/own/<name>.json`; in the rule script
  `GameModes.load_own("<name>.json")`. Do not hard-code numbers in code.
- Do NOT change the files under `data/common/` for a mode.
- The keys the engine refers to are in the README's "Mode contract" table; do not delete them.

## 4. Scenario (optional)
`scenario.json`: `owners` (state → country), `capitals` (country → state), `vp` (city → points); in the manifest
`"scenario": "scenario.json"`.

## 5. rules.gd (optional)
- `extends ModeRules`; hook list `game/core/mode_rules.gd`, example `game/modes/_template/rules.gd`.
- A new effect: `effect_keys` + `apply_effect` + `describe_effect`, all three; add its text to `strings.csv` (EN+TR).
- Randomness: your own seeded `RandomNumberGenerator`; write its state to `to_save` with `str()`.
- Do nothing on the player's behalf.

## 6. Texts
Inside data `{"en", "tr"}`; code/interface texts in `game/localization/strings.csv` (EN+TR), then `--import`.

## 7. Verification
1. `python3 tools/new_mode.py --check <id>`
2. `$GODOT --headless --path . -s tests/run.gd -- --file=test_mode_<id>` and `-- --file=test_modes`
3. `$GODOT --headless --path . -s game/dev/country_check.gd -- --game_mode=<id> --days=30`
4. `GODOT=$GODOT tools/run_tests.sh`
If a test is red, apply the "how to fix" part of its message; never skip or disable the test.

## 8. If you need to touch engine code, STOP
Changes to `game/autoload`, `game/map`, `game/ui`, `game/core` are not a mode's job. Write to the user what is needed and
why, and wait for approval. If approved, also run the WWII balance test (`tools/balance_parallel.sh 6`, each check at least 5/6).

## 9. Delivery
A separate branch + pull request. In the description: what changed, the tests run and their results (with numbers), known
limits. Commit messages in Turkish. Documentation is bilingual: if you change an English page, update its Turkish twin in
the same task.
