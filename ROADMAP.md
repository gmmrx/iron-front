**English** · [Türkçe](ROADMAP.tr.md)

# Roadmap — "Iron Front" (working title)

A World War II grand strategy game made with Godot 4.7.
Start: **1 January 1936**. Map: the whole world (it began with Europe, North Africa, the Middle East and the western USSR).

Principle: **data-driven architecture** — content lives in JSON/CSV under `data/`; engine code is independent of content.
Goal: **a good-looking map at every zoom, 60 FPS**, deep gameplay with its own character.
Language: the game and the documentation are in **English first**; Turkish is complete and chosen in Settings → Language.

Status: ✔ done · ◐ basic version exists, to be deepened · ☐ not done
Last update: **29 September 2026**

> ### ⚠ READ FIRST — ORIGINALITY AND INTELLECTUAL PROPERTY (for all agents)
> The first versions of the game were modelled on the best-known commercial game of the genre; the names, number tables,
> terms and screen layout largely came from there. To remove the legal risk, **the gameplay stays, the expression becomes
> ours**. Rules and plan: [docs/ORIGINALITY.md](docs/ORIGINALITY.md) (PART O). In short:
> - No file, wiki, screenshot or guide video of another game is used as a source (clean room).
> - Names are real historical names or ours; numbers are derived from our own formula and historical data, with the
>   reason written down.
> - In code, comments, documents and commits no other game is mentioned, neither by name nor by euphemisms like "the
>   genre classic"; there is no "parity" goal.
> - The game is a **free, open-source browser game** (no store). Being free does not remove the copyright risk: the
>   realistic danger is a copyright notice to GitHub and the repository being taken down. The licence of every asset in
>   the repository must allow redistribution.
> - **"Iron Front" is a working title**: a commercial World War II game with the same name is on the market. A name
>   change is recommended; since the game will be moddable (WWII, alternative history, zombies…) the new name should be
>   generic, not tied to WWII. A new name is not used before a trademark search.

### New direction: the war game (29 September 2026)
The game becomes shorter and simpler: one scenario takes 30–45 minutes, alone or online with 2–4 players. The rules are
on [docs/DESIGN.md](docs/DESIGN.md); what does not fit that page is not built. The sections below describe the code as
it is today and stay as a record; the stages remove what the design page drops. Nice small details come later, spread
across the stages.

0. ✔ **Design page**: [docs/DESIGN.md](docs/DESIGN.md)
1. ◐ **Land war commands**: ✔ halt and dig in, withdraw, stance, split (1 / half / all); ✔ attack estimate on the map
   card before an order; ✔ artillery supports neighbouring battles; ◐ armies, army groups and commanders go (✔ out of the interface: no Army screen, selection panel on the right; ☐ out of the code)
2. ◐ **Air**: ✔ click a region, pick a mission (superiority, close support, bombing); ✔ bombing stops factories and
   wears war support; ✔ a wing forms at the base nearest the capital and moves to a base in range; ✔ reconnaissance
   (reveals the zone through the fog)
3. ◐ **Economy and politics cut down**: ✔ left menu down to six buttons (plus Recon); ✔ only WWII participants play
   and move (`data/common/participants.json`); ✔ no construction, buildings fixed (shown, hidden under the fog); ✔ fuel and equipment stock off (losses made good with manpower); supply stays (the balance test needs it); ✔ no dockyards or synthetic refineries: ships bought with SP in ports with a naval base (the computer too, up to its 1936 navy + 8% a year); ✔ research back in the menu, a few minutes per technology in a scenario; ✔ influence motivates troops (Motivate command); ✔ alerts show the next step (never idle); ☐ one morale instead of stability and war support;
   ✔ units bought directly in cities with industry points (SP, `data/common/recruit.json`), paid recon flights; ☐ event and discovery cards
4. ◐ **Scenarios and victory**: ✔ scenario file (start save, duration, sides, key cities), main menu Scenarios screen,
   no time limit (the war ends when a side gives up), AI weighs key cities; ✔ first
   scenario the 1941 Eastern Front; ☐ 1939 West, 1941 Pacific
5. ◐ **Fog of war**: ✔ clouds over everything beyond sight (our land, our divisions and recon zones clear, a strip
   across the border), foreign divisions, fleets and wings hidden under them, region card and attack estimate respect
   it; ✔ only city markers under the clouds, buildings hidden
6. ☐ **Navy**: sea control and landings only
7. ☐ **Multiplayer**: deterministic simulation, 2 players first
8. ☐ **Zombie scenario** on the same engine

### Where are we? (summary)
- The whole world map, **80 playable countries**, the 1936 economy and the historical flow (Poland → France →
  Barbarossa → Pacific) work; the balance test passes all 12 checks at least 5 times in 6 runs.
- **Government model**: leader, ruling party, ideology popularity (up to +15% stability), elections, a home front tied to
  the crisis index and the war situation, the effects of stability on factories/influence/consumer goods, a surrender
  limit tied to the home front, laws with requirements, dated and timed national conditions, 1936 values from the
  historical starting point (`game/dev/gov_check.gd`).
- **Interface**: metal texture set, top bar + a separate command power/know-how box, a vertical menu down the left
  edge with shortcut letters; all side panels in the same frame, large screens full-screen with drag scrolling (the map
  does not move while they are open); research as a one-page timeline; colour-coded tooltips (good green, bad red).
- **The player decides**: the player's trade is manual (automatic trade optional), air wings are manual, divisions
  "hold to the last man" (no retreat without an order), no commander is ever assigned automatically, historical
  pressures are events with choices (Turkey: the May 1936 Soviet pressure, the 1938 successor, the 1939 Moscow talks).
- **History**: every country except the player's follows the real timeline on the exact dates (`data/common/history.json`:
  Rhineland, Anschluss, Munich, Poland, the Winter War, the West, Barbarossa, Pearl Harbor…); the player's country
  never acts by itself; a step whose conditions no longer hold is skipped (the player has changed history); until
  2 Sep 1945 the AI starts no war of its own and joins no war of aggression when called.
- **Chain of command**: army group (field marshal) → army (general) → division; a commander roster for all 80 countries
  (the real commanders of the era in 57 countries, local names elsewhere), skill 1–5 combat bonus, experience and rising
  skill in battle, promotion to field marshal and new generals for command power; the Army screen (U) with tree + detail
  + roster; micromanagement in the selection panel (composition, split, join/leave army, direct orders).
- **Map cards**: a country card while Ctrl is held (portrait, relation, indicators, wars), Ctrl + click opens that
  country's politics screen read-only; sea regions show naval control by country.
- **The map is a general staff table (pin design)**: the 3D terrain stays; cities, divisions, fleets and air wings are
  pins stuck into the map (a city pin's head is the colour of the country holding it; a counter is the pin's flag); far
  away the usual map icons, up close the pins. Each state's buildings stand on one pin as pictures with their level,
  a construction in progress as an orange "+n". Aircraft are the only model (one small plane). State borders and the
  smaller province borders (the unit the mouse highlights) are drawn as clear lines at every zoom.
- **Settings** in the main menu and in the game: volumes, music choice, language (English / Türkçe), fullscreen.
- Features whose interface exists but which do not affect the game yet (land/naval/air know-how) are shown faded with a
  "not allowed" cursor and say why.
- Game wiki: [docs/wiki](docs/wiki/README.md). The new icon set is in the game; prompt list for icons and portraits:
  [docs/art/ICON_PROMPTS.md](docs/art/ICON_PROMPTS.md) (the game picks up new files automatically).

### Next up (by priority)
0. ◐ **Originality (PART O)**: ✔ terms, laws, advisors, national conditions, technology/program names,
   construction/production/combat numbers in our own expression, copy traces removed; ☐ remaining numbers
   (docs/ORIGINALITY.md), interface identity, a new generic game name and trademark search
1. ✔ **Ships no longer go ashore**: sea lanes verified and repaired at full resolution (land contact 236 → 0 routes,
   missing port–sea 12 → 0), node corner curves with a radius that stays on water, a fleet group that falls on land is
   moved to the nearest water; `tests/test_sea_lanes.gd`, `tests/test_fleet_motion.gd` check this with numbers
2. ◐ **New icon set and portraits** (made by the user): ✔ icon set in the game; portraits arriving → visual check as they come
3. ◐ **An open-ended game (PART OPEN)**: ✔ no end date — the game goes on until the player takes the whole world or is
   destroyed; ✔ research without an end (refinement levels); ✔ a world events menu on the left to follow and answer
   what happens in the world (PART EV)
3b. **An end-to-end game with Turkey**: the path to conquering the world / being defeated is checked visually
4. **Content**: ◐ 1936 events with choices added: Japan (26 February), Italy (League sanctions), Britain (the Defence White
   Paper), France (the Popular Front), Germany (the Berlin Olympics), Poland (the Rambouillet loan), USSR (the 1936
   Constitution), China (Xi'an). Remaining: middle and small countries, 1937–1945 event chains (the Spanish Civil War, the
   Winter War, the Balkans)
5. **Missing mechanics** (PART M): ◐ generals (chain of command ✔; traits, portraits, historical entry/exit next),
   doctrines (the know-how cells light up with them), war plans, peace conference, puppets, intelligence, supply hubs
6. ✔ Small countries can build too (public construction floor of 1 factory, import payments cannot eat it); ✔ pause menu,
   game over, division panel in the new design
7. ☐ **Mod support** (PART MOD): the game becomes a moddable platform; WWII is the first scenario

---

## PART O — ORIGINALITY AND INTELLECTUAL PROPERTY ◐ ← BEFORE ANY TASK
Details and rules: [docs/ORIGINALITY.md](docs/ORIGINALITY.md). Every PR goes through the review list on that page.
- [◐] Layer 1 — Expression: ✔ glossary, laws, advisors, national conditions, technology and shared program names,
      construction (factory-days), production (factory-hours), combat values, commanders; ☐ influence scale,
      trade/convoy ratios, crisis index thresholds, stability effects, battalion manpower/equipment, 1936 starting
      values (list: docs/ORIGINALITY.md)
- [ ] Layer 2 — Interface identity: our own layout, shortcut and colour language; an open symbol standard for map
      counters (needs a human eye)
- [ ] Layer 3 — Signature mechanics: crisis bargaining with choices, balancing diplomacy for neutral countries,
      weather/seasons and the front system
- [◐] Layer 4 — Process: ✔ "genre classic" phrasing and parity/guide-video sections removed; ◐ third-party attributions
      (flag licences to be verified one by one); ☐ optional: release from a new repository without history
- [ ] **Game name** (recommended, not urgent; low trademark risk for a free open-source game): "Iron Front" is a working
      title. A commercial World War II computer game (2012) and a mobile game with the same name are on the market; the
      name is also that of a real political organisation of the 1930s. Since the game will be moddable, the new name is
      generic (not tied to WWII). Candidate names are searched in TÜRKPATENT, EUIPO, USPTO, WIPO (Nice 9, 28, 41), stores
      and domain names; the chosen name is read from a single translation key

---

## PART A — COMPLETED FOUNDATION (Phases 0–9)

| Phase | Topic | Status |
|---|---|---|
| 0 | Project, map generation pipeline, camera, clock, basic interface | ✔ |
| 1 | 3D map, relief, rivers/lakes/straits, cities, country names | ✔ (whole world ✔, see W) |
| 2 | Economy: factories, construction, resources, trade, production lines, laws | ✔ |
| 3 | Politics: state program trees, events, national conditions, advisors, decisions | ◐ |
| 4 | Research: 33 technologies, slots, year penalty | ◐ |
| 5 | Land warfare: divisions, A*, combat, encirclement, basic supply, armies/fronts (C1), chain of command | ◐ |
| 6 | Air (real wings, ★4) & navy (real fleets, sea lanes, ★3) | ◐ |
| 7 | Diplomacy: casus belli, war, alliances, guarantees, surrender, peace | ◐ |
| 8 | AI: economy + fronts + historical flow | ◐ |
| 9 | Save/load (including armies and commanders), menus, settings (sound, music, language), basic sounds | ✔ |
| 10 | Multiplayer | ☐ |

---

## PART W — THE WHOLE WORLD ✔ (Phase 11c)
- [x] Miller cylindrical projection, 16,384 px; the seam at the Bering Strait, neighbourhood wraps across the seam
- [x] Variable region density: Europe detailed; East Asia/India 2–2.5x, Siberia/Africa/ocean 5x
      → 13,414 regions (8,812 land, 1,901 islands, 2,134 sea, 567 lakes), 1,652 states, 1,847 cities
- [x] World elevation (Terrarium z5 + Europe z6), snow line by latitude, southern hemisphere biomes
- [x] 1936 political situation: 82 countries, all colonial empires, dominions, Manchukuo, the Chinese warlords
- [x] Exact 1 January 1936 borders where they cut through modern regions (`tools/fix_borders_1936.py`, pixel level):
      German Upper Silesia/Pomerania/West Prussia, the Free City of Danzig (own country), Poland's Riga border,
      the Dniester and the Budjak, Finnish Karelia/Salla/Petsamo, Petseri/Abrene, Fiume/Zara/Dodecanese/Tenda, Karafuto
      and the Kurils, Kwantung, Jehol and eastern Inner Mongolia, Spanish Morocco's southern border, Ifni, Cape Juby,
      the Tangier International Zone (own country), Gibraltar and Macau as their own states, Newfoundland, Goa,
      Pondichéry, Kwangchowan, British Cameroons, the Canal Zone; ~270 border towns checked by `test_borders_1936.gd`
      → 13,548 regions, 1,687 states
- [x] World economy (USA, Japan, China, India…), real deposits (Malayan rubber, Texas oil…)
- [x] Movement by geographic distance (great circle), pathfinding, sea regions, air range
- [x] Realistic marching (a third of road speed over the day: infantry ~33 km/day, armour ~84) and march fatigue
  (cohesion drops on the march, recovers when stopped); Ctrl shows the selected divisions' march reach (1 / 3 / 7 days)
- [x] Memory budget (~750 MB): 16-bit region texture, half-resolution SDF/terrain, a map mesh in 128 pieces
- [x] Camera: the view never leaves the map at any zoom (no margin); the farthest zoom shows the whole world; no clouds
- [x] Asian programs: Japan (Marco Polo 1937, the Tripartite Pact, Strike South 1941), USA, China
- [x] Colonial population adds 15% to manpower
- [x] Germany's Balkan/Barbarossa and Italy's Greece programs do not open before the war with France ends
- [x] World balance test, 12 checks ≥5/6: Poland 1940-02, France Jul–Sep 1940, Barbarossa 1941-09,
      Japan–China 1937-08, Pacific War 1941-12, China/Britain/USSR standing
- [x] Seamless east–west scrolling: a map copy at the seam, the camera wraps, no seam line/darkening
- [x] Messina / Little Belt / Panama canals (map regenerated; 11 straits, the Channel cannot be walked across)
- [ ] Detailed state program trees for the other great powers (USA, Japan, China to be expanded)

## PART ★ — VISIBLE WAR (Phase 11) ◐ ← TOP PRIORITY
The player must **see** the war: soldiers, tanks, ships, submarines, aircraft as real, moving 3D models on the map.

### ★1. 3D model library ✔
- [x] Land: Muster WWII (MIT) models → simplified + colour-baked GLB (`tools/muster/`):
      infantry and machine gunners (GER/SOV/UK/USA), guns (PaK 40, ZiS-3, 25-pdr, M2A1, Flak 36)
- [x] Armour: Panzer IV, T-34-85, Cromwell, Sherman, M13/40, Chi-Ha, Tiger, KV-1, Churchill; Opel Blitz, ZiS-5
- [x] Air: Bf 109, Spitfire, P-51, Il-2 (Muster); bomber (Blender)
- [x] Sea: destroyer, cruiser, battleship, submarine, cargo ship (Blender)
- [x] Country-specific equipment; period uniform colours for other countries
- [ ] Aircraft carrier, transport aircraft, motorcycle, armoured car

### ★2. The look of land units ◐
- [x] Close zoom: 3–5 figures per division (infantry/MG/gun/truck/tank by template), scaled by camera distance
- [x] Walking animation; a division walks between regions in proportion to its progress
- [x] **Smooth movement**: in-hour interpolation + Catmull-Rom route (no hourly jumps or sharp corners)
- [x] **Per-figure steering**: each soldier/vehicle turns to its own slot and accelerates; carries the division's speed
      (never lags behind)
- [x] Step phase tied to real ground speed (no sliding / "moonwalk"); body bob and sway on the march
- [x] Two-file column on the march, a defensive line while waiting, a spread line in combat; vehicles tilt with the terrain
- [x] Counters follow the units' smooth position and sit above the figures
- [x] In combat figures face the enemy; muzzle flash, explosions, smoke
- [ ] Retreat, surrender/destruction animation when encircled
- [ ] Divisions in training drill at the barracks

### ★3. Naval units (system + look) ◐
- [x] Fleet unit (`Navy` + `Fleet`): ships in fleets instead of stock; in port or in a sea region; reserve fleet
- [x] Missions: in port, naval superiority, convoy raiding (submarines), convoy escort; mission region (≈420 km)
- [x] Naval combat: hourly fire/damage, submarine detection, cohesion, retreat, sinking ships
- [x] Naval control: divisions in transit take losses under enemy control; routes avoid enemy seas
- [x] Convoys: sunk by raids, open imports drop; the AI builds convoys
- [x] Navy panel (N), fleet selection on the map, right click for region/base orders, fleet tooltip
- [x] Look: ships anchored in port, sailing + wake, submerged submarines, gun flashes + water columns,
      sinking ship animation
- [x] **Proper sailing**: the fleet moves as one, in a tidy formation (heavy ship in the middle + 4 escorts), turns at a
      limited rate, leans slightly in turns, no sideways sliding; short wake by speed; parallel rows along the quay in port
- [x] Calm fleet movement: sailing speeds (battleship 24, destroyer 30 km/h), holding station in the region, a slow
      patrol drift every few days, no threshold flip-flopping in AI region choice
- [ ] Landing plan (player), port strike, mines, aircraft carriers and naval air power
- [x] Sea lane network (tools/build_sea_lanes.py): an open-sea node in every sea region, routes between neighbours and
      ports that only cross water and keep away from the coast (Suez, straits, narrow canals at full resolution)
- [x] Fleets and transports follow these lanes; Bézier curves at the nodes; positions do not change with zoom (fixed scale)
- [x] Routes at least ~12 px from the coast; pathfinding and speed use the real route length; sailing speeds
      13–23 km/h; a tight triangle formation, the bow follows the route tangent, the formation squeezes gently near the coast
- [x] The camera does not follow terrain height (fixed height, no bobbing)
- [x] The sea lane generator verifies/repairs every route at full resolution in its last step (land contact 0), ports
      facing the open sea leave from the city's quay, a corner radius per node (the curve stays on water); the FleetLayer
      formation (fit_formation) is tested headless, a group position that falls on land is moved to the nearest water
- [x] Fleets/divisions in the same place form one representative group (at most 3 ships / 1 division formation), the
      number on the counter
- [x] Convoy / trade routes visible on the map (Routes mode)
- [x] Sea region card: naval control by country (share bar), our side's share, whether transports are safe, fleets there

### ★4. Air forces (system + look) ◐
- [x] Air wing unit (`Air` + `AirWing`): fighter / close support / bomber wings at air bases (100 aircraft)
- [x] Missions per region (≈350 km, range-checked): air superiority, close air support, port strike
- [x] Daily dogfights + anti-air losses; regional air superiority and close support bonus to land combat
- [x] AI: moves bases to the hottest front and gives missions; the player's wings can be left to the AI with "Automatic"
- [x] Air panel (H): form a wing (from stock, at the chosen base), mission, region choice, automatic mode, reinforce, disband
- [x] The player decides: aircraft the player builds wait in stock and are deployed as wings by hand
- [x] Look: aircraft parked at bases, flights circling in V formation over the mission region,
      dogfights (tracers), falling aircraft, close support bombs + ground explosions
- [x] A division moving overseas appears as a transport ship
- [ ] Strategic bombing (factory damage), base capacity penalty, anti-air fire over cities

### ★6. Cities and buildings on the map ◐
- [x] **Pin design** (`game/map/pin_layer.gd`, 27 Sep 2026): the map is a general staff table — 3D terrain, and on it
      pins instead of models. City: a pin with a head in the controlling country's colour (bigger for bigger cities), the
      name on the head. Division, fleet, air wing: the counter is the pin's flag. Pins keep the same size on screen at
      every zoom; far away the usual map icons, and each icon rises into a pin when you zoom in
- [x] Buildings as pins: one pin per state with its buildings side by side as pictures (civilian/military factory,
      dockyard, refinery, anti-air, naval base) and their level; a construction in progress is an orange-framed picture
      with "+n"; the air base has its own pin
- [x] Building badges come only up close (28 Sep 2026): from camera distance ~215 small icons on the map (72% size),
      full size with the pin rising under them from ~130 in; further out the map shows no buildings. The size follows
      the pin's node scale (resizing every label while zooming stalled frames for 150+ ms). Hovering a badge makes it grow, plays that building's sound (`map_<building>.wav`, a nearby action sound
      until the file exists) and the card describes it (level / maximum, construction, country total, air wings based);
      clicking opens its state
- [x] The player's army shows its commander's portrait above its main counter up close (initials if there is no picture)
- [x] Battle status arrows: a small green ▲ on the side that has just improved, a red ▼ on the side losing ground; they
      rise and fade (`game/map/battle_ticker.gd`)
- [x] Aircraft: one small plane model in the country's colour, parked at the air base or flying its mission
- [x] State borders as clear lines at every zoom (thicker up close) and province borders (the unit the mouse highlights)
      as thinner, lighter lines inside the states
- [x] Nothing overlaps: divisions stand beside cities, buildings and air bases; the air base is not placed next to another
      city
- [ ] Pins for more things: supply hubs, forts, radar, strategic resources (oil, steel…) at their states
- [ ] Occupied city: the pin head in the occupier's colour with a thin ring of the owner's colour; ruined city after bombing
- [ ] The 3D model library is kept switched off (`SHOW_MODELS` in `city_layer_3d.gd`, `industry_layer.gd`,
      `unit_models.gd`); the model pipeline (`tools/blender/build_cities.py`, `build_industry.py`) stays for later use.
      Detailed city dioramas, rigged industry (cranes, AA guns, refinery flare) and the model-based land units are in it

### ★5. Combat effects and sounds ◐
- [x] Particles: muzzle flash, explosions, smoke; water columns at sea
- [x] Procedural effect shader (vfx.gdshader): noisy fireball (white core → orange → soot),
      billowing irregular smoke, flying earth, muzzle flash opening to both sides; scaled to figure size
- [x] Momentary flashes at the muzzles of firing figures (infantry frequent/small, guns/tanks rare/big)
- [x] Combat plate at far zoom (crossed swords + the balance bar of both sides; green when the player attacks, red when defending)
- [x] Aircraft at fixed scale, without shadows; same region/base + owner + type form one representative group (at most
      3 aircraft) + number counter
- [x] Close support as a real attack run: target an enemy division, dive, 2 bombs (bombers a stick of 4), impact
      explosion; fighters fire short bursts from the nose (the random tracer cloud covering the screen was removed)
- [x] Infantry/machine-gun tracers towards the enemy; muzzle flashes
- [x] A division that changes direction does not go back (it continues from the region it was heading to)
- [x] A single info card (broken tooltip delay setting fixed); the card of buttons at the bottom (map modes) opens above them
- [x] Square icon buttons + square alert strip (event, empty research, state program, idle factory/dockyard, idle
      construction, unsupplied divisions, convoy shortfall, aircraft in stock, manpower, surrender danger)
- [x] Navy: great powers up to 6 fleets, turning into a reserve fleet of 12+ ships; the player can always make landings
      (cannot cross a sea under enemy control)
- [ ] Combat sounds by zoom (rifles, machine guns, artillery, tanks, aircraft engines, naval guns)
- [ ] Performance: pooling

---

## PART P — PLAYABILITY (Phase 11b) ◐ ← top priority together with ★
The game must go from "watchable" to **playable**: a balanced historical flow, clear feedback, little micromanagement.

### P1. War balance (critical)
- [x] AI deployment routes do not cross enemy land; a garrison in every front region; the Channel cannot be walked
- [x] Ship and aircraft types cannot be built without research (the technology of the types on hand is given at the start)
- [x] Automatic balance test (parallel, ~15–20 min): `tools/balance_parallel.sh 6`
- [x] AI main effort (Schwerpunkt): concentration in 2 regions per front → France falls in March–April 1940
- [x] AI performance: deployment by friendly-land components (ai_military 130 s → 16 s / 1,700 days)
- [x] Eastern front balance: supply range (at most 9 regions into occupied land from a source) + home defence
      (+15%) → the "winner wipes out everything" dynamic ended; Germany and the USSR standing until mid-1942 (6/6)
- [x] All 9 balance checks 6/6: Poland 1940-02, France April–June 1940, Barbarossa 1941-09
- [x] Balance test on the world map (12 checks, 6 parallel runs): all ≥5/6 — France Jul–Sep 1940,
      Japan–China 1937-08, Pacific war 1941-12, China/Britain/USSR standing
- [x] Balance broke on the new world map (canals) → diagnosis: almost all destroyed divisions were "nowhere to retreat"
      (units infiltrating deep on their own); with the German army in France the homeland emptied and surrendered.
      Fixes: AI front integrity (only advance into an empty region that also touches a friendly one), small armies for
      naval powers (Britain ×0.5, USA ×0.6), an attack penalty for democracies in the first 270 days (−25%)
      → Germany standing 0/6 → 2/6, France falls 1/6 → 3/6
- [x] The 1939–41 flow (25 Sep 2026, 6 runs): all 12 checks ≥5/6 — Poland falls Sep–Dec 1939, Germany/Britain/USSR/Italy
      standing, Barbarossa 1941-07. Fixes: an AI army targets a single enemy (does not spread onto an ally's front), a cap
      per army, a garrison in every front region, no offensive between great powers in the first 240 days, democracies
      do not attack a solid great power ("phoney war"), no new divisions before the old ones are full, doctrine
      conditions (Blitzkrieg +25% attack, Maginot −30%, Great Terror −30%, unprepared army), historical German program
      dates (Danzig 1 Sep 1939, West May 1940)
- [x] With commanders (27 Sep 2026, 6 runs): all 12 checks ≥5/6; Germany/Italy fell early in one run and France late in
      another — to be watched
- [x] The fall of France in June–July 1940 (6/6 runs, 28 Sep 2026): the historical timeline (Case Yellow on 10 May 1940)
      and the "Collapse of the Front" condition of May–October 1940
- [x] A surrendering country passes on consistently: its occupied states go to the occupiers, it leaves every war and its
      alliance (unless it leads it), its guarantees lapse and it cannot declare war for two years (`Diplomacy.TRUCE_DAYS`),
      so it is not pulled back into its old allies' wars
- [ ] Peace conference (simple): the winning side shares the states

### P2. Feedback to the player
- [ ] Combat detail window (both sides, strength, losses, terrain/river penalties)
- [x] Arrival time: with divisions selected the card of the region under the mouse shows the estimated arrival (the
      slowest of the first three, without battles; `Military.eta`, the same speed as the march); with a fleet selected
      likewise (`Navy.eta_hours`). No route is drawn before the order: a path following the mouse looked like the
      units choosing their own way
- [x] Movement arrows: a chain of faint marks flowing to the destination, as if under the map, in the country's colour
      (red when attacking); an ordered division keeps its place instead of jumping to the region's centre; the arrow ends
      where the counter will stand, and right-clicking a counter orders to that counter's region (joining a stack)
- [x] "No route" says why: no military access to a named country, sea-only destination with the sea closed, in training
- [◐] "Why?" tooltips: breakdown of stability and home front, surrender limit, law requirements, the reason a
      diplomacy action is closed, resource shortfall rows, naval control by sea region ✔; remaining: supply shortfall
- [x] Country card with Ctrl (leader, relation, indicators coloured against ours), other countries' politics read-only
- [ ] Goals / hint system (a guide for the first 30 minutes)

### P3. Less micromanagement — and better micromanagement
- [x] Army → front assignment (C1) — basic version done; war plan arrows (C2) next
- [x] Chain of command and the selection panel: split, form an army, join/leave, direct orders (C3)
- [ ] Reinforcement/deployment queue (if the player switches it on), copy template

### P4. The player decides (automation check) ✔
- [x] The player's trade is manual: pick a seller, +8/−8, cancel; "Automatic trade" only if the player switches it on;
      imports that cannot be paid for are blocked (reason in the tooltip)
- [x] The player's air wings start with "Automatic" off (both the starting ones and newly deployed ones)
- [x] Divisions start with "Hold to the last man" on: they never retreat by themselves; when cohesion runs out they fight
      at half strength (can be switched off in the division panel)
- [x] Historical pressures are events with choices; options can have conditions (`require`), an option without its
      condition shows as locked and the AI does not pick it either
- [x] Per-country test (`game/dev/country_check.gd`): player actions affect the game, nothing is done automatically for the player
- [x] Automatic test suite and CI: `tests/` (data integrity: event/program/technology/law/template references, effect
      dictionary, translation table), `tools/run_tests.sh`, GitHub Actions; dev scripts exit with 1 when they find a problem
- [x] System scenario tests (95 tests): economy, trade, politics, diplomacy, land war, navy/air, commanders, save/load
      (200 days, field by field), determinism; bugs found were fixed (the player trading with an enemy, a member's white
      peace, preferences/pending events/entrenchment lost on load, 1936 trade on load, stale cache in a new game)
- [x] No commander is assigned automatically to the player's armies; an empty player army is not deleted; a division the
      player orders on the map is not pulled back by the army plan
- [x] Features with an interface but no effect yet are locked visibly (faded, "not allowed" cursor, reason in the
      tooltip): land/naval/air know-how
- [ ] The AI's automatic trade also buys from countries it is at war with (mid-1940 Germany ~57, Italy ~53 resources a
      day, mostly from British/French colonies). Cutting it (blockade) is realistic but leaves Germany without resources
      and drops the "France falls in 1940–41" check to 4/6 — blockade + compensation (e.g. Soviet/Swedish/Romanian trade)
      must be handled together
- [ ] The AI rule "wait for the moment and join later" (`Diplomacy.ai_answers_call`) is written but not connected (Italy
      waiting until June 1940 on an alliance call); connecting it changes the balance — waiting for a decision
- [ ] The player's army does not send divisions overseas by itself to separate front pieces (e.g. East Prussia)
- [x] Movement and animation logic tests: sea lanes, fleet corners/leaving port/formation, division path continuity,
      movement arrows, weather (deterministic; cache bug fixed), counter/flag/hidden by zoom

## PART V — GAME DEPTH ◐ ← the next main work together with P
Our own design goals; the source is history and our own balance test (PART O rules). Every item is written with how it
shows in the game.

### V1. The feel of war and combat maths ◐
- [x] Division experience: Raw −25% · Drilled · Seasoned +25% · Hardened +50% · Crack +75%; grows with combat, falls
      with losses (new recruits); a star on the counter, a bar in the panel
- [x] Preparation bonus: a division waiting next to the enemy builds up to +20% preparation over 15 days; attacking wears
      it down (draw the plan and wait → a strong first blow; scattered attacks are weak)
- [x] Weather and seasons: winter (Dec–Feb, above 45°N) attack −9…−15%, wear without winter kit; autumn mud (Oct–Nov,
      Eastern Europe) speed −45%; heat wear in the desert; a winter cover on the map (in every mode, patchy)
- [x] Fuel: base income (industry) + oil → a fuel store; armoured/motorised movement and combat, air missions and ships
      at sea consume it; without fuel armoured/motorised strength −35%, speed −50%; fuel on the top bar, alert
- [x] Research carry-over: an empty slot banks up to 30 days of research (the rest is lost), passed to the next research
- [ ] Encirclement penalty: an encircled unit −30% (on top of being unsupplied); capturing generals (later)
- [ ] Combat detail window (with P2): both sides, frontage, terrain/river/air/preparation/experience/fuel multipliers

### V2. Logistics (merges with B) ☐
- [ ] Trains are produced as equipment; the railway network needs trains (need/stock on the top bar)
- [ ] Supply hubs and railway levels; trucks from the hub to the front; supply shortfall → wear, cohesion drop
- [ ] Division supply use by template (logistics company −%); heavy tanks use the most
- [ ] Convoys: overseas trade, supply and troop transport use convoys; convoys on the top bar

### V3. Army structure and command ◐
- [ ] Division templates: battalions + support companies (engineers, recon, military police, maintenance, field hospital,
      logistics, signals, artillery, anti-air, anti-tank); a frontage target (plains 70 → templates dividing 35/70)
- [ ] Special forces: marines (landings/rivers), mountaineers, paratroopers, rangers; terrain bonuses
- [x] Generals and field marshals (basic): country rosters (commanders of the era + local names), skill 1–5, army/group
      assignment, combat bonus (general skill × 4%, full up to 24 divisions; field marshal × 2% to the whole group),
      experience in battle → skill, promotion to field marshal (30) and new generals (15) for command power; save/load;
      `tests/test_commanders.gd`
- [ ] Generals' **traits**: separate attack, defense, logistics, planning values; traits earned with experience
      (e.g. encirclement expert, defensive specialist, armoured commander, winter fighter, mountain warfare)
- [ ] Commander **portraits** (made by the user; to be added to the prompt list) and a commander detail card
- [ ] Historical entry/exit: commanders joining the roster by year, the 1937 Soviet purge (Tukhachevsky, Blyukher,
      Yegorov), retirement, wounds/capture/death in battle, the general of an encircled army taken prisoner
- [ ] Division cap per commander and headquarters (army/army group HQ counter on the map), renaming armies
- [ ] Doctrines: land, naval, air; structure and names are ours, from real concepts of the era (manoeuvre warfare, deep
      operations, methodical battle, infiltration tactics); bought with land/naval/air know-how (the know-how cells on
      the top bar are unlocked then)
- [ ] Offensive stance: cautious / balanced / "at any cost" (plan aggressiveness)

### V4. Economy and politics details ◐
- [x] Civilian/military factories, construction, the infrastructure construction speed bonus, trade law (export share),
      production efficiency
- [ ] Infrastructure raises a state's resource output (+10% per level), building slots per state grow with technology
- [ ] Consumer goods: mobilization law + stability → part of the civilian factories go to the people
- [ ] Order of production lines on a resource shortfall: the lines in front get a small penalty, those behind a big one
- [ ] A warning so influence is not wasted; country-specific historical advisors and design bureaus (tank/aircraft/ship)
- [ ] Stability and home front effects: recruitment slows as the home front weakens
- [ ] Peace conference: annexation / puppet / demands for resources and factories; puppets pay tribute
- [ ] Occupation: resistance and compliance; occupation law (civilian oversight … military administration), needs garrisons

### V5. Air and naval depth ◐
- [x] Air superiority, close support, port strike; visible attack run, bombs
- [ ] Naval bombers (against fleets at sea), strategic bombing (factory damage + repair), logistics strikes
- [ ] Air base capacity (200 aircraft per level); a penalty above it; anti-air buildings reduce attacks on the base
- [ ] Fleet structure: screening ships (destroyers/light cruisers) in front, heavy ships and carriers behind; without
      enough screens the heavy ships get hit; light attack on the screen, heavy attack on the big ships; at most 4–6
      carriers per fleet
- [ ] Mining; landing technology (number of simultaneous landings); marine bonus

### V6. Later
- [ ] Intelligence and agents, code-breaking; the atomic bomb (lowers the surrender limit); rocket attacks
- [ ] Tank/aircraft designer (modules, reliability, cost)

## PART B — TRANSPORT AND LOGISTICS (Phase 12) ◐
The backbone of the economy and of war: supply, movement speed, industry and resource transport depend on it.

### B0. Routes map mode (F4) ✔
- [x] On a faded political base: the sea lane network, trade routes (in the resource's colour, a wave flowing to the
      importer; land neighbours overland, others capital → port → sea lane → port → capital), the player's fleet routes
      (dashed, remaining km and arrival day), air mission lines
- [x] Info card on hover (goods, distance, convoy coverage, risk in enemy sea regions), click-to-select highlight
- [ ] Roads and railways will be added to the same mode (B1–B2), train/truck supply flow (B3)

### B1. Road network
- [ ] A road graph linking the city gates (`City.gates`, ready)
- [ ] Road classes: dirt → gravel → asphalt (rising with infrastructure level)
- [ ] Roads drawn onto the terrain (slopes, rivers, mountain passes; bridges with the truss module)
- [ ] Effect: division speed, truck supply efficiency, construction speed

### B2. Railway network
- [ ] The historical main lines of 1936 (Berlin–Warsaw–Moscow, the Baghdad Railway, Paris–Marseille…)
- [ ] Railway levels 1–5; the player builds them by drawing on the Construction screen
- [ ] Visual: rails + sleepers, stations, **moving trains** at close zoom
- [ ] Capacity → supply flow; damage and repair from bombing/occupation; armoured trains

### B3. Supply system (a modern supply model: hub + railway + trucks)
- [ ] Supply hubs (buildable, connected to the railway)
- [ ] Capital/ports → railway → supply hub → trucks to the front
- [ ] Truck use, horse-drawn supply
- [ ] Regional supply capacity vs. use → shortfall: cohesion/attack/wear penalties
- [ ] Supply map mode (flow, bottlenecks)
- [ ] Sea supply: convoys; submarines sink convoys

### B4. Effect on the economy
- [ ] Resources travel by rail; a resource without a connection cannot be used
- [ ] Factory output and construction speed depend on the transport network
- [ ] Trade routes (convoy need), embargo, blockade

---

## PART C — THE WAR SCREEN AND COMMAND (Phase 13) ◐

### C1. Front lines ◐
- [x] Armies (player): "Create army" from the selected divisions, front = the border with the chosen country (even
      before the war), Hold / Attack, select army, disband; an army row in the division panel; save/load
- [x] Front assignment: divisions spread along the front by themselves according to enemy density (no pointless shuffling)
- [x] Offensive: divisions at the front advance into neighbouring enemy regions where they are stronger, without breaking
      the line (flank safety)
- [x] Drawing the contact line: right on the border, a line in the army's colour + teeth facing the enemy (longer when attacking)
- [x] AI great powers use front armies in war: an army per enemy, a weekly plan (divisions in proportion to front length
      + enemy strength), a capital garrison, attack when 25% stronger at the front
- [x] Counter merging at far zoom: nearby counters of the same country merge into one (total divisions) on a fixed map
      grid, changing only at 3 zoom thresholds, staying where the biggest stack is (no sliding/animation); a click selects
      the whole group
- [x] Fleets in the same place form one counter (total ships), no side-by-side counters sliding with zoom
- [x] AI: overlapping fronts (allied enemies) in one army; concentration when attacking (3× divisions at the 2 weakest
      points); army code performance (integer set of target countries, fronts reachable overland, daily order cap):
      285 s → 41 s
- [x] Assigning generals (V3): in the Army screen and the commander roster; the army's commander in the selected divisions panel
- [ ] Army counter / army card, choosing a front by clicking on the map
- [ ] Encirclement pockets marked visually

### C2. War plans (arrows) ◐
- [ ] Drawing offensive arrows (by dragging, curved), spearhead units
- [ ] Preparation bonus, run/stop the plan
- [ ] Defensive line, fortification line, naval landing plan, airborne landing
- [x] Movement arrow: starts where the unit is, an unbroken curved body, thinning at the tail, a wide notched head,
      shadow, gradient + outline + flowing highlight, thickness by zoom; one head per shared target
- [ ] Progress indicator

### C3. Command structure
- [x] Armies → Army Groups → Field Marshal; generals (skill, experience); traits in V3
- [x] Army panel: chain of command tree, army/group detail (commander, front, stance, group), division list (cohesion,
      strength, status, location), moving divisions, unassigned divisions, commander roster; ☐ equipment fill
- [x] Micromanagement (selection panel): army header (commander, front, stance, manage), summary cells, composition by
      template (click: only that type), division cards (click: select only that one), split in half, new army from the
      selection, join/leave army, **direct orders** (a division of an army ordered on the map is left out of the army
      plan, handed back with "Back to army plan")
- [x] Division experience / veterancy (done in V1)

### C4. Deeper combat
- [ ] Combat screen (both sides, frontage, dice, tactics)
- [ ] Combat tactics
- [x] Weather and seasons (winter, mud, desert heat — V1)
- [ ] Fortifications (Maginot, Metaxas, coastal forts)

---

## PART D — ATMOSPHERE AND INTERFACE ANIMATION (Phase 14) ◐

### D1. Traces of war
- [ ] Fires in besieged cities, ruined building variants, trenches and crater marks along the front

### D4. Map atmosphere
- [x] Painted map (28 Sep 2026): farmland as a patchwork of fields with dark edges, earthy mountains with fine ridges and
      valleys (fixed north-west hillshade + warped ridged noise), turquoise shallows and a thin foam line; the political
      colours as a wash over the ground (the Terrain mode without it); no tree models (the layer, its data and the tree
      model builder are gone)
- [x] Pins in the map design: city names in dark framed boxes (serif), ivory heads, capital medallion (gold ring and
      star), buildings on dark square tiles with gold pictograms and the level in the corner
- [x] Land cover (28 Sep 2026): forests dark green with canopy clumps up close, steppe khaki with dry grass, desert
      sand; mountains earthy on plateaus and grey-brown rock on steep and high slopes, snow above the snow line (lower
      in winter), fine ridges and gullies along the slope direction
- [x] Pin animation: city pins spring up when they enter the view range and shrink away when they leave; pins far from
      the screen centre stay small (all full size up close), the pin under the mouse grows; a soft shadow where the pin
      enters the map. Far away plain white city names; buildings only at the closest zoom steps; aircraft only up close
- [x] Roads and railways (Natural Earth, `tools/build_roads.py`) in the Routes map mode, hidden behind mountains; a
      darker map overall; pin with a polished steel shaft and brass collar; city pin icons (5 tiers x 4 styles, prompts in
      `docs/art/CITY_PIN_PROMPTS.md`) — the pictures are still to be made
- [x] City pins only for big cities (capitals, 10+ victory points); the rest are plain names at every zoom
- [x] Unit names in each country's own language (`data/common/unit_names.json`, 24 languages, English fallback)
- [x] Units as plates (28 Sep 2026, `art/soldier-pins.png`): far away tags, closer a dark plate with the flag strip,
      unit picture, map symbol and number on an iron pin (the round heads tried first were dropped)
- [x] Units as round pins (superseded by the plates above): far away "flag | number", "ship | number", "plane | number" tags without pins;
      closer a round pin head after `art/soldier-pins.png` (metal rim, flag dome, ivory unit picture, number tab, name
      plate) on an iron
      pin, the same for divisions, fleets and air wings; very close a stack spreads into equal-size heads per battalion;
      matte iron pins; building pins at different heights and from farther away
- [x] Deploy on the map: the panel closes, the map darkens all but the valid places, the player clicks where the
      division / air wing / new ships go (new ships no longer join a fleet by themselves)
- [x] Division cards (superseded by the round pins above):
      up close the battalions inside as small cards; pictures from `docs/art/UNIT_CARD_PROMPTS.md` (until then the
      equipment icons in ivory); no hover growth on pins
- [x] Winter snow cover (by season and latitude, patchy)
- [ ] Day/night cycle (city lights), seasonal colours
- [x] Rain/snow particles (regional, by season, at close zoom; FPS-friendly)
- [ ] Fog; port/factory smoke; trains

### D5. Interface animation
- [x] Side panels slide in, news animation
- [ ] Button hover/press animations
- [ ] Period illustrations in event windows
- [ ] Cinematic headlines for declarations of war / surrender

---

## PART E — SOUND (Phase 14) ✔
- [x] Procedural synthesis engine (`tools/audio_synth.py`): wavetable strings/brass/winds, piano, percussion, hall
      reverb, mastering
- [x] Dynamic music (`tools/make_music.py`, 8 tracks ~19 min, OGG): a mode-independent menu theme (solemn, 3 min,
      loopable; also the web loading screen, with an on/off button), a march (distant war), peace (2), tension, distant
      war, the player's war (2); crossfades, no-repeat order
- [x] Event music: the player's war (siren + tutti) differs from war in the world; victory, defeat, peace; the music ducks
      while they play
- [x] Map-room sound world (`tools/make_audio.py`, 59 effects, with variants): everything is heard from the 1936–45
      headquarters map table (brass pin on felt, paper, leather dossier, typewriter, teleprinter, telegraph, field
      telephone); the war itself only from far away, through a line or a closed window. Interface: bakelite switch,
      dossier, index tab, rubber stamp, brass lever, clock gear. Unit counters: wooden counter, slide across the paper
      map, pin into cork, line click and wordless murmur; attack: red pin and stamp with a distant rumble
- [x] Building badges on the map: hovering a badge plays the pin touch and the building's distant signature (factory
      whistle and belt clatter, steel press, steam and pipe, riveting and chains, ship's horn and wave, radial engine,
      anti-aircraft thumps, locomotive)
- [x] Notifications and completions in the same world (teleprinter and desk bell, stuttering teleprinter and muted alarm
      bell, courier envelope torn open, carriage return and stamp, dossier closed onto the stack, distant factory
      whistle); no modern notification tones; they never overlap, they play in turn (queue)
- [x] Combat ambience (3D, close zoom: rifles, machine guns, artillery, tanks, aircraft, naval guns)
- [x] Settings: master, music, effects and interface volume; music choice (automatic or any track on repeat)
- [ ] Alliance and peace conference sounds; a battle turning for/against us on the map; audio buses and compression

---

## PART F — DESIGN LANGUAGE AND INTERFACE (Phase 15) ◐
- [x] One design system: metal texture set (`tools/make_ui_skin.py`), theme variations, panel template (`PanelLayout`)
- [x] New icon set: made by the user from the prompt list (`docs/art/ICON_PROMPTS.md`) in `assets/ui/icons_new/`, used
      automatically (a web size diet for them is open, see WEB)
- [x] Side panel template (close button, one panel at a time), news in the middle
- [x] Tabs (Army), full-screen screens with drag scrolling, research on one timeline page
- [◐] Leader portraits: the loader is ready (top bar, Politics, Diplomacy, Ctrl card; the flag otherwise); files keep
      arriving in `assets/portraits/<TAG>.png`
- [ ] Real flags for the 12 missing countries
- [ ] Nested tooltips (hover a term for its explanation)
- [ ] Minimap; map modes (supply, infrastructure, resources, ideology, alliances, naval control)
- [ ] Notification settings; interface scale

---

## PART UI — INTERFACE STATUS (Phase 16) ◐
Today's interface still follows a layout from the first versions; our own interface identity is designed in PART O
Layer 2 (layout, shortcuts, icon and colour language). Below is what works today.
- [x] Top bar: influence, stability, home front, manpower, factories, fuel, crisis index, date/speed
- [x] Top bar (25 Sep): supply fill (share of supplied divisions), convoys (stock / import need), command power
      (+0.3/day, +0.5 at war; cap 200; spent on the chain of command), land/naval/air know-how (from battles; cap 500;
      **not spent yet → locked**) — added to save/load
- [x] HUD: flag · compact indicator cells (fuel/supply with bars) · command power + know-how group; the menu down the
      left edge with shortcut letters (Q F I O R T Y U N H L) and alert tiles; side panels open to the right of the menu
- [x] Logistics screen (L): equipment stock / in use / daily output / need / balance, resource production-use, factory use
- [x] Screens: Politics (leader, party, pie, broken-down indicators, laws, advisors, national conditions, decisions; other
      countries read-only), State Program tree, Research (slots + one-page timeline), Diplomacy, Trade (manual deals),
      Construction, Production, Logistics, Army (chain of command + templates), Navy, Air, State (slots + build here),
      Event window, pause, game over, Settings
- [ ] Where know-how is spent: a **General staff** screen (doctrines, general traits) — V3/C3
- [ ] Division design and training: template editor (battalions/support companies, spends land know-how),
      reinforcement/upgrade priority
- [ ] A separate Decisions screen, Intelligence (agents), a world resource market
- [ ] Supply map mode (railway/supply hubs) — with B3; radar and fortification buildings (land/coastal forts)
- [ ] End of war: peace conference, governments in exile, puppet administration
- [ ] Nested tooltips

## PART M — MECHANICS COVERAGE ◐
✔ exists · ◐ basic version exists · ☐ none
| System | Status | Missing |
|---|---|---|
| Government: ideology, party, elections, stability, home front | ✔ | coups, civil wars, party splits |
| Laws (conscription, economy, trade) | ✔ | education / press / government laws |
| Advisors | ◐ | country-specific historical advisors, design bureaus (tank/aircraft/ship) |
| State programs | ◐ | 9 trees (Turkey 33 programs); other countries a shared tree; wide trees for the great powers |
| Events | ◐ | option conditions ✔; historical chains (Spanish Civil War, Winter War, Balkans, North Africa) |
| Decisions | ◐ | a separate Decisions screen, categories, timed missions |
| Construction, production, efficiency | ✔ | equipment variants, licensed production |
| Trade | ✔ | effect of relations, embargo, a world resource market |
| Research | ✔ | doctrine trees (land/naval/air), scientists |
| Division templates | ◐ | support companies, template changes spend know-how, reinforcement priority |
| Combat | ◐ | tactics, frontage detail, day/night, weather effect on combat |
| Armies, fronts | ◐ | offensive plan arrows; ✔ army groups, generals (skill/experience); ☐ general traits |
| General staff (command power, know-how spending) | ◐ | ✔ command power spent on generals; ☐ doctrines (know-how) |
| Logistics | ◐ | supply hubs, railways, trucks, port capacity, fuel detail |
| Navy | ◐ | mission regions, naval landing plans, base range |
| Air | ◐ | strategic bombing, paratroopers, superiority per air region |
| Diplomacy | ◐ | non-aggression pacts, volunteers, lend-lease, relations, alliance management |
| Peace | ◐ | peace conference, governments in exile, puppets/autonomy |
| Occupation | ☐ | resistance, compliance, garrisons |
| Intelligence | ☐ | agents, operations, code-breaking |
| Crisis index | ✔ | thresholds by ideology ✔ |
| Mods | ☐ | scenario packages, see PART MOD |

## PART MOD — MOD SUPPORT ☐
The game will be a platform: the engine (map, economy, politics, war, AI, interface) plus scenario packages. WWII 1936 is
the first scenario; others can come from us or from players (e.g. an alternative-history fantasy with Atatürk, a zombie
outbreak).
- [ ] Scenario package format: `mods/<name>/` with `data/common/*.json` (countries, laws, events, programs, technologies,
      units, commanders…), text (`strings.csv`), optional map, icons, portraits, music; a manifest (name, version,
      description, start date, base scenario)
- [ ] Loading order and overriding (a mod replaces or extends base files), a mod list in the main menu
- [ ] Engine texts free of WWII assumptions (dates, "1936–1945", end date from the scenario)
- [ ] A generic game name (not tied to WWII) — see PART O, Game name
- [ ] Modder documentation (English + Turkish) and a validation tool (the data tests from `tests/test_data.gd`)

## PART WEB — BROWSER VERSION ◐
- [x] GitHub Pages release: https://gmmrx.github.io/iron-front/ (`.github/workflows/web.yml`; Compatibility renderer on
      the web only, thread support off, the pck split into 90 MB parts and joined by `tools/web/shell.html`)
- [x] Compatibility renderer differences solved: the scene is drawn in sRGB space, so shaders convert their output with
      `srgb_out`; in MultiMeshes with custom_data the colour slot stays zero, so instance colours are made white (web only)
- [x] Colours match the desktop: in Compatibility the sun shadow + glow/SSAO/colour adjustment are off (GLES3 does tone
      mapping in the LDR post-process with them and over-brightens); sRGB output in effect shaders; measured difference
      9/255 (SSAO detail)
- [x] Region tooltip/click on the web (RGBA8 ID decoding fixed)
- [x] The loading page is in English
- [ ] No unit shadows on the web (off because the GLES3 shadow pass breaks brightness)
- [ ] Asset diet for the web: half-resolution height map, texture sizes (the new icons and portraits add ~57 MB; they
      could be imported at 128 px), first load time
- [ ] Mobile browser support (memory), save files kept in the browser

## PART G — PERFORMANCE (ongoing) ◐
Goal: 1080p, **60 FPS** on a mid-range system; no stutter at speed 5.
- [x] Simulation profiling tools (`game/dev/sim.gd`, `--fps` measurement; `--prof_every=365` prints the costliest systems
      every year)
- [x] Long-war navy cost (28 Sep 2026): every fleet on a mission scanned every enemy fleet each hour (quadratic as fleets
      multiplied: navy missions 12 → 22 → 37 → 51 s per game year in 1941–44) → a per-hour location index and a zone
      scan (1944: 7 s); naval control rebuilt every 6 hours (transports 22 → 8 s up to 1942); a stranded fleet looks
      for a port once a day. 1936–44 headless: 560 → 436 s
- [x] Air combat compared every wing on a mission with every other wing each day (quadratic): wings are summed per mission
      zone and nearby zone pairs measured once, the same result. After the historical flow the AI's fleets and air
      wings are capped by industry (surface fleets = dockyards / 3 within 6–24, submarine fleets dockyards / 8 within
      2–8, wings = military factories / 3 within 12–40; extra ships make fleets bigger, extra planes stay in stock) —
      they grew by ~60 fleets and ~55 wings a year without end. Not applied before 2 Sep 1945: in 1940–41 the cap merged
      British fleets and delayed the fall of France
- [x] AI/supply/statistics caches; tree shadows off; FXAA instead of MSAA; half-resolution SSAO
- [ ] Batched drawing of counters and labels in one draw call (currently ~2,600 draw calls)
- [ ] LOD: city model → icon at far zoom
- [ ] Moving the simulation to its own thread
- [ ] Graphics quality settings in the menu

---

## PART OPEN — AN OPEN-ENDED GAME ◐ ← needed before the end-to-end game
A strategy game does not end on a date: it goes on until **the player has taken the whole world** or **the player's
country is completely destroyed**. How many years that takes cannot be known in advance, so nothing may assume an end year.
- [x] No end date (`END_DATE` removed): victory = no country is left standing outside the player's side (the player and
      the alliance); defeat = the player's country no longer exists (last state lost or annexed). A surrendered player who
      still holds land plays on. The game-over screen shows the reason and the date; after a victory the player can keep
      playing (the victory is saved and does not come back). `tests/test_open_game.gd`
- [x] Research without an end: once a branch's historical technologies are done it goes on with refinement levels
      ("Infantry Refinement I, II, …", `rep_<branch>_<n>`): cost 180 days +15% per level, gain −15% per level (bounded
      total), dated one year after the previous level (from 1943) so the year penalty keeps them after the historical
      tree; the last column of the research timeline; the AI researches them too, only once a level's year has come (a
      level taken years early would lock a research slot for years) (formula and reasons in
      `data/common/technologies.json` → `repeatable`)
- [ ] Production and units after the war years: later equipment generations follow the repeatable research levels
- [x] Events and AI after the historical flow: from 2 Sep 1945 rule-based recurring events come to every country (`"recur"`
      in `events.json`: after, average period, pause, requirements, a neighbour as the other side) — Clash on the Border
      (a casus belli: the AI finds new wars this way), Run on the Banks, Officers' Plot (low stability), The Soldiers Come
      Home (great powers at peace); no random number is drawn before that date, so the historical flow is unchanged
- [ ] More rule-based events: uprisings in occupied lands, real coups (a change of regime), disasters, colonial crises
- [ ] Laws, programs and decisions that stay useful in a long game (post-war reconstruction, occupation policy, the
      economy of a large empire)
- [ ] Performance and save size stay stable over decades of game time (long-run test: 30+ game years)
- [ ] Engine texts without fixed years (also part of PART MOD: the scenario gives the start date, not an end date)

## PART EV — WORLD EVENTS MENU ◐
Things happen in the world all the time (wars declared, alliances, coups, disasters, other countries' decisions). They
should come to the player as a feed, and some of them can be answered.
- [x] A world events menu on the left (E, `game/ui/world_panel.gd`): what happens in the world, newest on top, with the
      country's flag, date, kind and a short text; filters (neighbours, my alliance, the whole world); click → the map
      goes there. The log (`World.world_log`, last 400) is saved; texts are rebuilt in the current language
- [x] Reacting to events: a declaration of war (30 days) or an annexation (60 days) where the player is on neither side
      carries options — condemn / send rifles / stay out, refuse to recognise (casus belli) / recognise — with costs,
      requirements and effects from the existing effect dictionary (`data/common/world_reactions.json`,
      `game/core/world_react.gd`); democratic great powers condemn the player's own aggression the same way
- [x] AI countries' wars, alliances, guarantees, surrenders, annexations, peace, elections, new leaders and the great
      powers' state programs become entries
- [x] The notification feed keeps to the player's matters (and the great powers' wars and annexations); the world menu is
      the rest of the world. `tests/test_world_events.gd`
- [ ] More answers: volunteers, sanctions, guarantees offered from the entry; coups, uprisings, disasters as entries

## PART H — CONTENT DEPTH (ongoing) ◐
- [ ] A wide state program tree for every great power, country trees for the middle powers
- [ ] Historical event chains (Spanish Civil War, Winter War, the Balkans, North Africa)
- [ ] Elections, coups, civil wars
- [ ] Puppet states, a peace conference screen, lend-lease, volunteers
- [ ] Equipment designers (tank, aircraft, ship)
- [x] The whole world map

---

## PART I — MULTIPLAYER (Phase 10) ☐
- [ ] Deterministic simulation, lockstep network model, lobby, sync check

---

## Suggested order
1. **★ Visible war**: models ✔ → land units ✔ → navy ✔ → air ✔ → effects ✔ (remaining: sounds, retreat/surrender
   animation, landing plans, strategic bombing, pooling)
2. **P** Playability: war balance (P1, the 1939–41 flow) → war plans (C2) → feedback (P2)
3. **B** Transport & logistics (roads, railways, trains, supply)
4. **C** The rest of the front lines, command, combat depth
5. **D** Atmosphere, **E** sound, **F** design language (in parallel)
6. **H** Content, **MOD** mod support, **I** multiplayer

---

## Architecture
```
data/            → content (JSON/CSV), generated map files
tools/           → map, texture, model (Blender), sound generation scripts
game/autoload/   → World, Economy, Politics, Research, Diplomacy, Military, Navy, Air, AI, Game, GameClock, Audio
game/core/       → pure simulation classes (Country, StateRegion, Province, Division, Army, ArmyGroup, Commander, Fleet…)
game/map/        → 3D map, camera, city/pin/unit layers
game/ui/         → interface
game/dev/        → headless tests and simulation
tests/           → headless test suite (tests/run.gd runner, test_*.gd tests)
assets/          → shaders, models, textures, icons, fonts, sounds
docs/            → wiki (docs/wiki, Turkish in docs/wiki/tr), originality, cloud tasks, art prompts
```

## Developer tools
- Test suite: `tools/run_tests.sh` (import + `tests/run.gd` + country_check); CI: `.github/workflows/tests.yml`
  (on PRs and pushes to main; the balance test is a separate job triggered by hand)
- Balance test: `tools/balance_parallel.sh 6` (6 parallel runs, ~15–20 min); a single run `game/dev/balance.gd`
- Performance: `godot --path . -- --play=GER --run --fps=10` (`--fps_mouse`: the mouse circles over the map, `--fps_zoom`:
  the camera zooms in and out; `--load=slot` measures a save)
- Visual QA (frame series): `-- --play=DEN --war=GER,DEN --focus_battle=150 --speed=1 --shots=8 --every=30 --screenshot=out.png`
- Video: `godot --path . --write-movie out.avi --fixed-fps 30 -- --play=DEN --war=GER,DEN --focus_battle=200 --speed=2
  --film=5 --dolly=320,120` (`--pan=dx,dz`, `--track`, `--hide_ui`); clips are joined with ffmpeg → `docs/media/`
