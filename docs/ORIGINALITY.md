**English** · [Türkçe](OZGUNLUK.md)

# Originality and intellectual property policy

This page is for everyone who works in this repository (human or AI agent). Read it before any task.
It is not legal advice; if the release model changes (sales, a store) it goes to an IP lawyer.

## Release model
The game is **a free, open-source (MIT) browser game**; it is published on GitHub Pages and not on a store (Steam etc.).
What follows from that:

- **Being free does not remove copyright or unfair-competition risk.** The realistic danger is not a lawsuit but a
  copyright notice (DMCA) from a rights holder to GitHub, taking down the repository and the web version. So the rules
  below apply as written.
- **The trademark risk is lower** (no commercial activity), but not zero: with a game of the same name out there, a
  confusion complaint can also come through GitHub's trademark policy. A name change is recommended, not urgent (rule 8).
- **In open source every file is redistributed.** The licence of every asset in the repository (flags, fonts, models,
  icons, sounds) must allow redistribution, and the required attribution must be in `THIRD_PARTY_LICENSES.md`. For
  AI-generated images, the generator's terms of use are checked.
- The git history is public; old wording stays in the history (Layer 4).

## Why this exists
The first versions of the game were modelled on the best-known commercial game of the genre. Beyond the systems, the
names, number tables, terms and screen layout largely came from there. That creates legal risk:

- **Copyright** does not protect game rules and mechanics; it protects **expression**. Expression is names, texts,
  images, the look of the interface and systematically copied data tables.
- **Unfair competition** (in Turkey, TTK art. 55): taking someone else's work product without a contribution of your own.
- **Interface look**: the whole of the screen layout, icons and flow.
- **Trademark**: the game's name and distinctive terms.

The goal: **the gameplay (ideas) stays, the expression becomes ours.** Building factories, moving divisions, ideology,
stability and front lines are shared ideas of the genre; they are free to use. Another game's distinctive names,
sentences, numbers and layouts are not.

## Rules
1. **Clean room.** No file, wiki, screenshot, guide video or video transcript of another game is used as a source. No
   name, text, value or screen layout is taken from there; no task is written as "make it the same".
2. **Our sources:** real history (laws, institutions, people, events, production and army statistics), our own design
   calculations and our tests (balance test, scenario tests).
3. **Names** are either real historical names (a real law, institution, person, weapon) or names we made up. The general
   words of the genre (factory, division, stability, manpower, ideology) may be used. Another game's distinctive names
   are not (e.g. made-up names of law tiers, national spirits, advisor archetypes, technologies and doctrines).
4. **Numbers** are derived from our own formulas and historical data. The reasoning is written in the `_comment` field
   of the JSON concerned or in the wiki. No value is copied one-to-one from another game's table; an occasional
   coincidence is fine, systematic similarity is not.
5. **Interface:** new screens are designed with our own flow. "The same screen as in that game" is never the goal. The
   whole of the screens (layout, shortcuts, icon language, colours) carries our own identity.
6. **Writing:** in code, comments, documents and commit messages no other game is mentioned, neither by name nor by
   euphemism. Phrases like "like the genre classic", "parity with X", "classic values" are not used. A design goal is
   written with its own reason ("the player should see the front at a glance").
7. **Assets** (map data, flags, models, sounds, fonts) come only from sources with a known licence. Every new source is
   added to `THIRD_PARTY_LICENSES.md`.
8. **The game's name:** "Iron Front" is a **working title**. A commercial World War II computer game and a mobile game
   with the same name are on the market; the name is also that of a real political organisation of the 1930s. The risk
   is low for a free open-source game, but a name change is recommended; the decision is the project owner's. A new name
   is not used until it has been searched in the TÜRKPATENT, EUIPO, USPTO and WIPO trademark databases (Nice classes 9,
   28, 41), in stores and among domain names. In the game the name is read only from the `GAME_TITLE` translation key;
   when it changes, `project.godot` (`config/name`) and `tools/web/shell.html` are updated too.

## Differentiation plan
Status: ✔ done · ◐ started · ☐ not done

### Layer 1 — Expression (data and text; testable in the cloud)
- ✔ Our own glossary (EN + TR): influence, home front, crisis index, state program, national condition, command power,
  land/naval/air know-how; anti-personnel/anti-armor fire, shock, cohesion, frontage, preparation; casus belli;
  division experience: Raw → Drilled → Seasoned → Hardened → Crack
- ✔ Laws: 6 military service (treaty-limited army → levée en masse), 4 economic (peacetime economy → total war), 4 foreign
  trade (open markets, clearing, autarky, state trade monopoly); starting laws by history
- ✔ Advisors: real offices of state (Cabinet Secretary, Planning Commissioner, Minister of Armaments…)
- ✔ National conditions: made-up names replaced with historical facts (Resistance to the Reforms, The Moscow Trials, The
  Peace Ballot, Revolving-Door Cabinets, Laval's Deflation Decrees, the palace camarilla, the Sudeten German question…)
- ✔ Technology names from historical concepts; shared state programs with our own names and 6–12 week durations
- ✔ Numbers on our own scale: construction in factory-days, production in factory-hours, 12 factories per project/line,
  combat values (infantry battalion 30 / 110 / 100 cohesion), armour and piercing in mm
- ✔ Commanders: real commanders of the era per country, our own skill scale (1–5) and bonus formula
- ☐ Remaining (to be done together with the balance test):
  - Influence scale (2 a day, law and advisor 150, casus belli 30) and decision costs
  - "8 resources = 1 factory" in trade, "2 resources = 1 convoy" for imports
  - Crisis index thresholds (non-aligned 50%, democracy 100% / 25% / 80%) and its effect on the home front (+0.4% per 1%)
  - The stability effects table (+20% factories, +10% influence at 100%…) and the surrender limit formula (80%, home front < 50%)
  - Battalion manpower and equipment numbers (infantry 1,000 men / 100 rifles, artillery 500 men / 12 guns), speeds,
    armour shares
  - Equipment resource needs (steel, tungsten… per factory); the "+150% per year" early research penalty
  - 1936 starting values (stability, home front, ideology popularity): the table in `tools/setup_1936_government.py`
    should be re-derived from historical election results and our own calculation
  - Country codes (GXC, XSM, RAJ, AST…) are internal IDs only; invisible to the player, low priority

### Layer 2 — Interface identity (needs a human eye)
- ☐ Our own layout and screen flow, our own shortcut layout and colour language
- ☐ An open military symbol standard for map counters (e.g. NATO APP-6) or our own symbol language

### Layer 3 — Signature mechanics
- ☐ "The player decides": historical crises arrive as multi-option bargaining
- ☐ The neutral-country game: balancing diplomacy between blocs (Turkey 1939–45 is a game in itself)
- ☐ Weather and seasons, the army → front system brought forward

### Layer 4 — Process and history
- ✔ "Genre classic" phrasing, parity sections and guide-video sources removed; "classic strategy game style" removed from
  the icon prompt tool
- ◐ `THIRD_PARTY_LICENSES.md`: map, elevation, flag and font sources written; each flag's licence to be verified one by
  one; the generator's terms added as new icons and portraits arrive
- ☐ Old wording remains in the public git history (a shader comment in the first commit names another game). If a fully
  clean start is wanted, the game is published from a new repository without history (optional; the project owner decides).
- ☐ Design log: the reasoning behind important numbers and names is kept in writing (JSON `_comment`, wiki)

## Review list (every PR)
- [ ] No new name, text or value is taken from another game; its source is history or our own calculation
- [ ] No other game is mentioned by name or euphemism in code, comments, documents or commit messages
- [ ] Any new external source is in `THIRD_PARTY_LICENSES.md`
- [ ] New player-facing text is in `strings.csv` in English and Turkish
