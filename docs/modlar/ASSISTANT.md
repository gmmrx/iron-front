**English** · [Türkçe](ASISTAN.md)

# One page to give your AI assistant: adding a mode to this game

Paste this text into your assistant (Claude, ChatGPT, Copilot...); for details see docs/modlar/README.md.

**Game:** Godot 4.7 + GDScript, a data-driven World War II grand strategy game. Modes bring their own data without changing the engine.

**What goes where**
- Manifest: `data/modes/<id>/mode.json` (name `{en,tr}`, dates, player, `featured`, `playable`, `scenario`, `rules`).
- Data: `data/modes/<id>/common/<file>.json` (the whole file) or `<file>.patch.json` (deep merge; `null` deletes;
  in arrays with an `"id"`, `{"id": x, "_delete": true}` deletes). Only `.json`; the map is shared. A file cannot have both a copy and a patch.
- The mode's own data (no counterpart in WWII): `data/modes/<id>/own/<name>.json`; the rule script reads it with `GameModes.load_own("<name>.json")`.
- In the manifest the `welcome` text contains exactly one `%s` (country name); percent sign `%%`. Dates are days that exist in the calendar.
- Code (if needed): `game/modes/<id>/rules.gd`, `extends ModeRules`; hooks: on_new_game, on_game_started, on_day, on_hour,
  on_month, check_end, score, to_save/from_save, effect_keys/apply_effect/describe_effect, condition_keys/check_condition.
- Text: inside data `{"en": "...", "tr": "..."}`; interface/code text in `game/localization/strings.csv` (English + Turkish).
- Skeleton and tools: `python3 tools/new_mode.py <id>`, `--check`, `--copy <id> common/x.json`, `--blank <id> common/events.json`
  (also `common/focuses.json`, `common/history.json`: the WWII program trees and history timeline).

**Not allowed**
- Do not change `data/common`, `game/autoload`, `game/map`, `game/ui` files for a mode; if you need to, STOP and ask a human.
- Take no name, text, number table or screen layout from another game; never mention another commercial game in files (docs/ORIGINALITY.md).
- Do nothing on the player's behalf (trade, production, retreat...); crises become events with 2–3 options.
- Do not download or generate image/sound files; make no render/shader/colour/camera/model changes.
- Do not delete the engine's own events (`call_to_arms`, `white_peace`, `election`, `faction_invite`) or the `_generic` tree.

**Before saying "done"**
1. `python3 tools/new_mode.py --check <id>`
2. `godot --headless --path . --import` (if you added a new .gd/CSV)
3. `godot --headless --path . -s tests/run.gd -- --file=test_modes` and `-- --file=test_mode_<id>`
4. `godot --headless --path . -s game/dev/country_check.gd -- --game_mode=<id> --days=30`
5. `GODOT=... tools/run_tests.sh`
6. A separate branch + pull request; in the description: what changed, which tests, result numbers, known limits.
