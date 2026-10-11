**English** · [Türkçe](tr/01_nasil_oynanir.md)

# How to play

## Starting a game
In the main menu choose **New game**, then one of the countries that took part in the Second World War. The game starts on
1 January 1936 and has no end date; every other country is run by the computer. Scenarios (a prepared moment of the
war) are no longer in the menu. The game starts at 07:00 in your capital.

**Tutorial** (main menu): about twenty minutes as Italy in January 1936, at war with Ethiopia (the war was going on that
day). A small guide card at the bottom says one thing at a time and walks through the whole game: move the map and zoom
in; the top bar (influence, stability, home front, manpower, industry points); research (open the timeline, start a
technology); building (Rome's state panel, Build here); select soldiers, read the attack estimate with Shift, attack,
start the clock, motivate the fighting troops, take a region; the air force (a target region, air superiority from the
airfield at Asmara); reconnaissance under the clouds; recruit in an East African city; Politics and Diplomacy; the alerts.
Each step passes when you have done it (the guide never does anything for you); **Show** takes the camera to the place,
**Skip step** and **End tutorial** are always there. When it ends the game simply goes on. Steps:
`data/common/tutorial.json`.

## The game loop
1. **Scout**: beyond your land and one region past the border the map is dark. Press **K** (or the Recon button) and
   click a region: an idle air wing flies over it for a day and reveals 350 km around it for good. A flight costs
   15 industry points (SP).
2. **Recruit**: click one of your cities: the state panel lists what you can buy there (infantry, armour, fighter,
   close support and bomber wings) with its SP cost, manpower and training days. The unit appears in that city.
3. **Fight**: select your figures and order them on the map; the card of an enemy region estimates the attack.
4. **Grow**: every day the factories of the states whose main city you hold give SP (military factory 1, civilian
   0.4), multiplied by **factory output** (research, laws, advisors, national conditions, stability; the top bar's SP
   tooltip shows it). Take a city and its factories work for you; bombed factories give nothing.
5. **Research (I)**: every technology sits on one timeline by year and branch; pick a card, read its file on the right
   and start it there in a free slot. Industry research raises your SP, weapons and doctrine make divisions stronger, and close support planes,
   bombers and new ship types can only be bought once researched (a grey Buy button says which research is missing).
6. **Build**: in your state's panel, **Build here**: a military factory gives 1 SP a day, a civilian factory 0.4 SP and
   faster construction, an air base a home for planes, anti-air protection from bombing.

## Getting started (free game)
1. In the main menu choose **New game** → pick a country from the boxes at the top or on the map: the rest of the map
   darkens, the country's border lights up and the camera glides to it; the leader and the country's figures come in on
   the left → **Play**: the selection panels rise, the camera lands on your capital and the game panels come down.
2. The game starts **paused** (1 January 1936). Space starts/pauses, 1–5 set the speed.
3. The game starts in English; switch to Turkish in **Settings → Language** (main menu or Esc menu).

## The first 30 days (any country)
1. **Fill the research slots (I)**: an empty slot glows red. A technology ahead of its year takes +150% time per year early.
2. **Build**: click one of your states and use "Build here" (or T): civilian factories speed up construction, military
   factories give SP.
3. **Recruit** in your cities with SP; **motivate** fighting divisions with influence (selected divisions → Motivate).
4. **Politics (Q)**: with 150 influence, change a law (a wider military service law gives more manpower, mobilisation
   laws more factory output) or hire an advisor.
5. **Air (H)** and **Recon (K)**: give your wings air superiority over the front; scout the enemy under the clouds.

## Controls
| Action | Shortcut |
|---|---|
| Pause / resume | Space |
| Speed 1–5, faster/slower | 1–5, + / − |
| Map modes: political, terrain, states, routes | F1 F2 F3 F4 |
| Back to the capital | Home |
| Quick save | F5 |
| Menu / close panels | Esc |
| Politics, Program, Research, Diplomacy | Q, F, I, O |
| Trade, Construction, Production, Army | R, T, Y, U |
| Navy, Air, Logistics, World events | N, H, L, E |
| Select a division / box select / add to selection | Left click / drag / Shift |
| Move or attack order | Right click (on the web and on Mac: Ctrl + left click while divisions are selected) |
| A country's overall situation | Hold Ctrl over the map |
| That country's politics screen (read-only) | Ctrl + left click (no divisions selected) |
| Camera | Middle-button drag (glides on when you let go), wheel, two fingers, arrow keys / WASD; every move eases in and out |

Movement arrows are drawn **green** (move) or **red** (attack into enemy land). At far zoom small country flags replace
division counts; further out unit markers are hidden to keep the map clean.

## Winning and losing
The game has **no end date**: it goes on until one of these happens.
- **Losing**: your country no longer exists (it has lost its last state or has been annexed). A surrender alone does not
  end the game: when your country surrenders, the occupied states pass to the occupiers and you leave the war; if you
  still hold land, you play on and can rebuild. Surrender progress is the share of your cities' victory points held by
  the enemy (colonies count ¼, +10% if the capital falls); the limit is 80%, dropping as low as 50% when the home front is
  under 50% (see [Diplomacy](06_diplomacy.md)).
- **Winning**: no country is left standing outside your side (you and your alliance). Conquer the world with the chain
  casus belli → war → surrender (the occupied states of a surrendering country pass to the occupier), or bring countries
  into your alliance. The end screen shows the reason and the date; after a victory you can keep playing.

## Tips for Turkey
- In May 1936 the **Soviet pressure over the Straits** arrives: a polite refusal recalling Atatürk's friendship (only while
  Atatürk leads), granting bases, or refusal + mobilisation (gives the Soviets a casus belli).
- **November 1938**: Atatürk dies; you choose the successor (İnönü, Çakmak, Bayar).
- **October 1939**: the Moscow talks: a treaty with Britain and France, the Soviet demands, or mobilisation.
- Turkey is non-aligned: preparing a casus belli needs a crisis index of 50%. Without imported steel the factories cannot
  run at full output.
