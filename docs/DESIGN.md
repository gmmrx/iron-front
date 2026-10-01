**English** · [Türkçe](TASARIM.md)

# Game design: the rules

This page says what the game is and what it is not. A feature that does not fit this page is not built; if needed, the
page changes first.
Last update: **29 September 2026**.

## In one sentence
You pick a country and a scenario; in 30–45 minutes you build your army, keep your people standing and win by holding the
key cities. Played alone or online with 2–4 players.

## The feel: real-time war on a strategic map, with WWII
Orders are given straight on the map and the war moves in real time, but it is never a clicking race. Only the countries
that took part in the Second World War are played and move (`data/common/participants.json`); the others stay on the
map as neutrals with no troops. Beyond your sight lies the fog of war (patchy clouds): across a shared border you see
one region deep, the rest needs reconnaissance (the Recon button or K, then a click on the map). These three things stay:
- **Pace**: you pause whenever you like and give orders while paused. In multiplayer, pausing is voted on.
- **Decisions**: where to push, where to halt and dig in, where to send the planes, which card to pick. No fiddling with
  units one by one.
- **The world**: every country is alive; historical pressures arrive as events with 2–3 real options.

## The game loop
1. **Produce**: with manpower and industry you buy infantry, armour, artillery and planes; a unit appears in a city.
2. **Keep standing**: a country whose morale reaches zero surrenders. Event cards and bombing move morale.
3. **Fight**: you give orders region to region on the map. Neighbouring enemies shoot each other; a soldier who enters an
   empty enemy region takes it.

## What stays and what goes
| Stays | Goes |
|---|---|
| The world map and all countries | Roads, building pins |
| Region-to-region land war, figures | Armies, army groups, commanders |
| Halt, withdraw, stance, split commands | Templates, battalions, equipment stock |
| Air: a mission over a region (superiority, close support, bombing, reconnaissance) | Deploying wings base by base |
| Navy: sea control and landings | Raiding, escort, convoys |
| Manpower, industry, morale | Trade, construction, production lines, consumer goods, fuel, supply |
| Events with options, discovery cards | Laws, advisors, parties, elections, the research tree |
| Alliance, declaring war, military access, peace | Justification, guarantees |

The "Goes" column is still in the code; the stages of the roadmap remove it step by step. Construction is already off
for everyone (`Economy.CONSTRUCTION`): buildings stay as the map data sets them, ports, air bases and factories work in
the background and are not shown on the map; only cities are.

## Winning
There is no time limit. A scenario ends when one side gives up: its morale breaks and it surrenders, or it is destroyed.
Key cities are what both sides fight for.

## Rules that do not change
- The player decides everything; nothing is done on the player's behalf by itself.
- Content lives in data, the engine is independent of content. The zombie scenario runs on the same engine with another
  data set.
- No new features are added; work comes from the stages of the [roadmap](../ROADMAP.md). Small nice details come later,
  here and there.
