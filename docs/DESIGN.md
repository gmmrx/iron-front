**English** · [Türkçe](TASARIM.md)

# Game design: the rules

This page says what the game is and what it is not. A feature that does not fit this page is not built; if needed, the
page changes first.
Last update: **1 October 2026**.

## In one sentence
You pick one of the countries of the Second World War in 1936 and play an open-ended game: you build in your cities, raise
your army, research, keep your people standing, scout and win your wars. Played alone, later online with 2–4 players.
Scenarios (a prepared moment of the war) are not played; their code stays.

## It must hold up
A free game runs for years of game time. The economy, the computer's countries and the frame rate have to stay sound all
the way: nothing may pile up without end, no country may stall, the world must not freeze. The balance test (1936–1942,
the historical flow) and a long run to 1948 check this after every change to the game logic.

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
1. **Build**: you put buildings in your cities (factories, air bases, naval bases, anti-air,
   infrastructure); ships are bought in ports with a naval base; more factories mean
   more industry points.
2. **Produce**: with manpower and industry points you buy infantry, armour, artillery and planes; a unit appears in a city.
3. **Research**: a short list of technologies over 2–3 slots; a better rifle, tank or plane is a decision you keep
   making.
4. **Motivate**: influence is spent on the troops — selected divisions get part of their cohesion back at once and fight
   harder for a while (`data/common/recruit.json` → `motivate`).
5. **Keep standing**: a country whose morale reaches zero surrenders. Event cards and bombing move morale.
6. **Fight**: you give orders region to region on the map. Neighbouring enemies shoot each other; a soldier who enters an
   empty enemy region takes it.

## Never idle
Come in fast, make the right calls, make the right military moves, scout, win. The player should never sit for a minute
with nothing to do: the alerts under the top bar always show the next useful step — a free research slot, enough
industry to recruit, influence to motivate fighting divisions, divisions out of supply, idle air wings, an event waiting
for an answer, a free construction slot. Each alert
is one click to the place where the decision is made.

## What stays and what goes
| Stays | Goes |
|---|---|
| The world map and all countries; buildings on the map (hidden under the fog) | Roads |
| Region-to-region land war, figures | Armies, army groups, commanders |
| Halt, withdraw, stance, split, motivate commands | Templates, battalions, equipment stock (off: losses are made good with manpower) |
| Air: a mission over a region (superiority, close support, bombing, reconnaissance) | Deploying wings base by base |
| Navy: sea control and landings | Raiding, escort, convoys |
| Manpower, industry, morale, influence; construction in cities; supply (works by itself) | Trade, production lines, consumer goods, fuel (off) |
| Events with options, discovery cards, short research | Laws, advisors, parties, elections, the long research tree |
| Alliance, declaring war, military access, peace | Justification, guarantees |

The "Goes" column is still in the code; the stages of the roadmap remove it step by step. Already off for everyone:
fuel and the equipment stock (`Military.FUEL`, `EQUIPMENT`: they no longer touch the war). Supply stays on
(`Military.SUPPLY`): there is nothing to manage, but a division cut off from its own land or landed across the sea
fights weaker and does not recover; without it the balance test broke (Britain fell, Germany collapsed in 1941).
Construction is on (`Economy.CONSTRUCTION`) for the player and the computer. Buildings are shown on the map; under the
clouds only cities are seen.

## Winning
There is no end date. A war ends when one side gives up: its morale breaks and it surrenders, or it is destroyed. The game
goes on as long as you like.

## Rules that do not change
- The player decides everything; nothing is done on the player's behalf by itself.
- Content lives in data, the engine is independent of content. The zombie scenario runs on the same engine with another
  data set.
- No new features are added; work comes from the stages of the [roadmap](../ROADMAP.md). Small nice details come later,
  here and there.
