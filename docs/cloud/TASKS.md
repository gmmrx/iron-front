**English** · [Türkçe](GOREVLER.md)

# Claude Code Cloud tasks

Every task can be done headless and verified with tests. The shared rules, setup and test commands are in `CLAUDE.md` at
the root (Claude Code reads it by itself). To hand out a task, paste the text under its heading as it is.
Suggested order: 1 → 2 → 3, then the rest in any order. Each task opens its own PR.

Status: ✔ done · ◐ partly done · ☐ open

---

## 1. Automatic test suite and CI (base infrastructure) ✔
```
Set up a headless test suite for the whole game and connect it to GitHub Actions.

1) A small test framework in tests/ (GDScript, `extends SceneTree`): each test file holds `test_*` functions,
   `tests/run.gd` finds and runs them all, prints the passed/failed counts and the errors, and quits with 1 on failure.
   Every test starts clean with `Game.new_game()` + `World.start_game(TAG)`.
2) Data integrity tests: is every reference in data/common/*.json valid (national condition/event/country codes in event
   option effects, program prerequisites and exclusives, program coordinate overlaps, technology requirements, law keys,
   battalions in templates, equipment names, countries' starting conditions/laws). Every tr("KEY") used in code and every
   strings.csv row: no missing key, en and tr filled in every row, the same number of % placeholders in both languages.
3) tools/run_tests.sh: runs import + tests/run.gd + country_check (short: --days=60) and prints the overall result.
4) .github/workflows/tests.yml: on pull requests and pushes to main install Godot 4.7.2 (as in web.yml, cached),
   run --import, run tools/run_tests.sh. Put the balance test in a separate job that only runs by hand (workflow_dispatch).
5) game/dev/gov_check.gd, playtest.gd, sim.gd exit with quit(1) when they find a problem.

Done when: tests/run.gd is green locally and in CI; deliberately broken data (e.g. a national condition that does not
exist) turns the test red (show it in the PR description, then revert).
```

## 2. System tests: every scenario of the game ✔
```
Using the framework from task 1, write scenario tests for every mechanic of the game. Each test checks one behaviour with
numbers. At least:
- Economy: construction progresses and finishes (building level rises), slot limit, the public construction floor of at
  least 1 factory; production line efficiency growth and cap, slowdown on resource shortfall; consumer goods change with
  the law and stability.
- Trade: the player makes a manual deal and the resource rises; a deal that cannot be paid for is refused; nothing is
  bought from an enemy; automatic trade starts off for the player and on for the AI; imports drop without enough convoys.
- Politics: stability and home front formulas (party contribution, crisis index, war situation), law requirements, advisor
  and decision effects, a timed national condition ending, election result, dated events arriving on their date, a
  conditional option being locked, an event for the player never being chosen automatically (it waits in pending_events).
- Diplomacy: casus belli duration and cost, crisis index thresholds by ideology, allies/guarantors joining on a
  declaration of war, surrender progress (capital +10%, colonies ¼), the surrender limit formula, state transfer on
  surrender, white peace.
- Land warfare: combat resolution (attacker/defender damage), river/landing penalty, no-supply and no-fuel penalties,
  entrenchment bonus, a "hold to the last man" division not retreating and being destroyed when spent, retreating when it
  is off, an encircled division being destroyed, army → front distribution.
- Navy and air: fleet mission and return, naval combat, convoy raiding; deploying a wing, the player's wing starting with
  automatic off, the effect of air superiority on land combat.
- Save/load: play 200 days → save → load → every country and division field identical (trade deals, hold, leader, next
  election, event history, national conditions, laws, stock, queues). If something differs, name the field.
- Determinism: two runs with the same seed give the same result (or report in the PR why they do not).

Fix every bug you find in a separate commit and list them in the PR. The balance test must stay at least 5/6 on every check.
```

## 3. Movement and animation logic tests (+ ships must not go ashore) ✔
```
You cannot see the visual result, but the logic of the animations can be tested with numbers. Add to tests/:
- Sea lanes: every route in data/map/sea_lanes.json must only cross sea regions (sample with data/map/provinces.png +
  provinces.json). Known state: 62 routes touch land (the worst 9033-12949, 9295-13269, 10215-13110), 12 port–sea routes
  are missing (San Juan, Valparaíso/Viña del Mar, Newcastle…). Fix tools/build_sea_lanes.py, regenerate the JSON, make
  the test green.
- Fleet movement: every position sampled along the route with PathMotion.fleet / sea_pose must be on water (including
  leaving port and the quay points). FleetLayer's fleet group position and ship formation (_ship_pos, spread) must not
  spill onto land at the coast: if the group position is on land, snap it to the nearest water point. Split this into a
  function that can be tested headless.
- Land units: the position along a division's path (PathMotion) is continuous between neighbouring regions (no jumps)
  and ends in the target region.
- Movement arrows: UnitLayer._curve/_ribbon geometry — red when the target is hostile, green otherwise; the tip is in the
  target region; triangle count and UV ranges are valid.
- Weather: WeatherLayer.weather_at is deterministic for the same day and cell; snow in the north in winter, little rain
  in the desert belt.
- Zoom modes: UnitLayer and FleetLayer — numbers below FLAG_MODE, flags above it, nothing above HIDE_ALL (check the node
  visibility by building the scene).

Do not change render/shader/colours. Done when: all new tests are green, the sea lane test has 0 land contacts.
```

## 4. Optional: screenshot smoke test with a software renderer ☐
```
On Linux, open the game with xvfb + mesa (llvmpipe) in `--rendering-method gl_compatibility` mode and, with the developer
arguments in game/main.gd (--play, --panel, --event, --demo_order, --dist, --screenshot, --wait), take these frames: every
side panel open, the event window, the program tree, 3 zoom levels. You cannot look at the images and judge them; only
check: the game writes the frame without crashing, there is no script error, the frame is not entirely black/one colour
(a pixel variance threshold). Add it as tests/screens.sh and put it in the manually triggered CI job; upload the frames as
artifacts. If it does not work, explain why in the PR, do not force it.
```

## 5. Historical events: middle and small countries, 1937–1941 chains ☐
```
Right now most countries get no event at all in the first 150 days. Add dated events with 2–3 real options
("trigger": {tag, from, date, require}) to data/common/events.json. Scope:
- Middle powers 1936–39: Austria (Anschluss pressure), Czechoslovakia (Sudetenland/Munich), Poland (Danzig, German
  demands), Romania, Hungary (the Vienna Awards), Yugoslavia (the 1941 coup), Greece (Metaxas, the 1940 ultimatum),
  Albania (the 1939 Italian invasion), Finland (the 1939 Soviet demands), the Baltic states (the 1939–40 Soviet
  ultimatums), Belgium/Netherlands (neutrality), Sweden/Switzerland, Spain (the course of the civil war), Portugal,
  Turkey (Hatay 1938–39).
- The 1937–41 chains of the great powers (Germany, Italy, Britain, France, USSR, USA, Japan), at least 3 events each.
- Options must be real decisions (refuse / concede / war); use "require" for conditional options where needed; AI weights
  should lean towards the historical outcome. Effects from the existing dictionary; if a new effect is needed, add it to
  apply_effects and describe_effects.
- Text in both languages for every event (event texts live in the JSON as tr/en). For the picture, add a fitting alias to
  PAINTED_ALIASES in ui_theme.gd, run tools/make_icon_prompts.py and update docs/art/ICON_PROMPTS.md.
Verify: the number of events rose in country_check (before/after table in the PR); the balance test at least 5/6 on every
check; an event for the player is never chosen automatically. Update the event table in docs/wiki/03_government.md and
docs/wiki/tr/03_hukumet.md.
```

## 6. State program trees: middle powers and a bigger Turkey ☐
```
Add country-specific trees (20–30 programs each) to data/common/focuses.json for Poland, Romania, Hungary, Yugoslavia,
Greece, Czechoslovakia, Spain and China; grow the Turkish tree to 45+ programs (economy, army, diplomacy branches,
mutually exclusive foreign policy paths). Use the existing effect dictionary; x/y coordinates must not overlap;
prerequisites must be valid; AI weights sensible. The data tests from task 1 must stay green. Run
tools/make_icon_prompts.py for the program icon names. Balance test at least 5/6.
```

## 7. Peace conference and puppet states ☐
```
Right now the occupied states of a surrendering country pass to the occupier. Make this a choice:
- On surrender the winning side gets a share in proportion to its contribution (victory points it occupies); if the
  player is a winner, an event window lets them choose: annex / set up a puppet state / return core lands. The AI should
  choose close to historical behaviour.
- Puppet system: an overlord field on Country; the puppet joins its overlord's wars, enters its alliance, makes its own
  decisions through the AI; save/load; the puppet relation is shown in the diplomacy panel (with PanelLayout.row).
- Update the wiki (06_diplomacy.md, tr/06_diplomasi.md) and the ROADMAP.
Tests: check with scenario tests (a puppet joins the war, annexation transfers states, returning works); balance at least 5/6.
```

## 8. Deeper diplomacy: non-aggression pacts, volunteers, lend-lease ☐
```
Add to the Diplomacy autoload: non-aggression pact (duration, breaking penalty: crisis index + stability), sending
volunteer divisions (to a country in a civil war or at war, without entering the war), lend-lease (sending equipment from
stock to another country). Each action: requirements (ideology, crisis index), influence cost, AI rules, save/load, a row
in the diplomacy panel (the existing _action pattern). Offers to the player arrive as events with choices. Scenario tests
+ balance at least 5/6. Update the wiki and the ROADMAP.
```

## 9. Occupation and resistance ☐
```
Resistance and compliance in occupied states: resistance grows over time, a garrison (number/strength of divisions in the
state) suppresses it; high resistance lowers that state's resource and factory output and disrupts supply; compliance
grows over time and restores the output. Data-driven constants (JSON), an info row in the state panel (PanelLayout.stat),
save/load, an AI garrison rule. Scenario tests (resistance grows in an ungarrisoned state and output drops; a garrison
suppresses it). Balance at least 5/6.
```

## 10. General staff: doctrines and generals ◐
```
Generals are done (chain of command: army groups → armies → divisions, commander rosters in data/common/commanders.json,
skill 1–5, combat bonus, experience, promotion and new generals for command power; tests/test_commanders.gd).
Remaining — the system to spend land/naval/air know-how on:
- Doctrines: data/common/doctrines.json — three branches (land/naval/air), 3 schools per branch, 6–8 tiers per school;
  a tier is bought with know-how and gives modifiers (the existing c.mod() dictionary: attack/defense/org/speed/planning…).
  When doctrines exist, remove the "not in use yet" state of the know-how cells on the top bar (UiTheme.mark_unavailable).
- General traits: separate attack/defense/logistics/planning values, traits earned with experience (e.g. encirclement
  expert, defensive specialist, armoured commander, winter fighter, mountain warfare).
- Interface: a plain panel built with the existing PanelLayout helpers, no new style.
- Save/load, AI (doctrine choice), wiki (05_warfare.md, tr/05_savas.md) and the ROADMAP.
Scenario tests: buying a doctrine applies its modifier; a trait shows in combat. Balance at least 5/6.
```

## 11. Weather and day/night in combat ☐
```
Move the deterministic weather decision of WeatherLayer.weather_at into a helper independent of the visual layer (e.g. an
autoload function) so the simulation can use it too; the visual layer keeps using the same result (the picture must not
change). Effect on combat: rain attack −10% and air missions −30%, snow attack −20% and speed −25% (data-driven
constants). Day/night: night attack penalty (−25%), no air missions at night. Show the reason in the combat
tooltip/panel (text). Scenario tests + balance at least 5/6; wiki 05_warfare.md and tr/05_savas.md.
```

## 12. Better AI (measurable) ☐
```
The AI (game/autoload/ai.gd) should use these sensibly: laws (conscription/economy by home front), advisors, decisions,
trade law, construction priority (when to switch from civilian to military), research priority, convoy production.
Measure: add 1939-09 and 1941-06 snapshots to game/dev/sim.gd (factory count, division count, manpower, laws of the great
powers) and give a before/after table in the PR. It should move closer to the historical values; balance test at least 5/6
(preferably 6/6). The AI must not touch the player's country (test this).
```

## 13. Strategic bombing and naval landing plans (back end) ☐
```
- Air wing mission "strategic bombing": damage to factories and infrastructure in the target region (repairs need the
  construction queue), anti-air and fighters inflict losses.
- Naval landing: the player/AI plans a landing on a coastal region; preparation time, naval superiority requirement,
  landing penalty (Military.amphibious_attack), losses on failure.
Data-driven constants, save/load, AI rules, one row/mission button in the existing panels each (no new style).
Scenario tests + balance at least 5/6. Update the wiki and the ROADMAP.
```

## 14. Simulation performance ☐
```
Profile the daily tick time with game/dev/sim.gd (GameClock.timed already measures it section by section). Speed up the
3 most expensive sections without changing behaviour (e.g. the O(n²) seller sort in Economy._run_trade, AI loops, a supply
calculation cache). Measure: the 1936–1942 simulation must get at least 30% shorter; the balance test results must stay
statistically the same (12 checks, at least 5/6); country_check green. Before/after time table in the PR.
```

## 15. Wiki numbers from the data ☐
```
tools/make_wiki.py: generate the tables in the docs/wiki pages (laws, advisors, decisions, buildings, events, countries,
national conditions) from data/common/*.json and the game constants, in both the English pages (docs/wiki/) and the
Turkish ones (docs/wiki/tr/); leave hand-written text untouched (rewrite only between marked blocks). Add a "is the wiki up
to date" check to the CI job from task 1 (red if the generated output differs from the file).
```
