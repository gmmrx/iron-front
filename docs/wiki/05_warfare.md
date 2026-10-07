**English** · [Türkçe](tr/05_savas.md)

# Warfare

## Divisions and templates (U → Division templates)
- Battalion types: infantry, artillery, anti-tank, motorised infantry, light tank, medium tank (needs research).
- Template designer: +/− per battalion (at most 25 battalions per template). Values: anti-personnel fire, anti-armor fire,
  defense, shock, cohesion, speed, frontage, manpower. An infantry battalion: 30 anti-personnel fire, 110 defense, 15 shock,
  100 cohesion, 50 durability.
- **Unit names** are in each country's own language, whatever the interface language: "1. Piyade Tümeni" for Turkey,
  "1. Infanterie-Division" for Germany, "1st Infantry Division" for Britain, "1re Armée" for France, "Dai 1 Shidan" for
  Japan (non-Latin languages in Latin letters). The names are in `data/common/unit_names.json` (24 languages; the
  others use English).
- **Deploy**: the panel closes and the map darkens everything except where the unit can go (divisions: your own
  regions; air wings: states with an air base; new ships: states with a port); click a highlighted region to deploy
  there (right click / Esc: cancel). Ships are bought with SP in the port of a state with a naval
  base (state panel → recruit: destroyer 41, submarine 30, cruiser 121, battleship 336 SP) and join the reserve fleet
  there; the computer buys ships the same way, up to its 1936 navy grown by 8% a year. With enough manpower and equipment the division
  trains for 14 days (it cannot move meanwhile); the conscription law changes this (Two-Year Service 13, Reserve
  Call-Up 16, Levée en Masse 20 days).

## Orders
- Select with left click / box, **right click** (on the web and on Mac: Ctrl + left click while divisions are selected) to
  move to or attack the target region. Right-clicking **another counter** sends the divisions to that counter's region
  (to join a stack): counters stand above the map next to the city, so the ground under them is often a neighbouring
  region. The highlight and the card follow the region the order will go to.
- **Marching takes time and wears troops out**: a battalion's speed is its road speed (infantry 4 km/h, motorized 12,
  light tanks 10, medium tanks 9; a division moves at its slowest battalion), but nobody marches 24 hours a day — rests,
  nights, supply columns and jammed roads cut the daily average to about a third: infantry ~33 km a day, an armoured
  division ~84, a motorized one ~100 (1939-45 infantry marched 25-30 km a day; armoured breakthroughs made 40-80). Terrain,
  infrastructure, season, fuel and supply still count. On the march a division's cohesion drops a little every hour (at
  most to 60%) and only recovers once it stops, so a division that has just marched far is weaker in its first attack
  and shifting an army from front to front has a price.
- **Hold Ctrl** with divisions selected to see how far they can march (the slowest of them): regions reached within a
  day are bright green, within three days mid green, within a week faint green, the rest of the map darkens. Enemy
  regions show as the edge of the reach (there is a battle there); neutral land without access is left out.
- **Where they stand is yours to choose**: the divisions stop at the very spot you right-click inside the region (right
  at the border, in the middle, behind a river...); right-clicking a spot inside the division's own region stops it and
  moves its counter there. The spot is where the counter stands on the map (and is kept in the save); combat is still
  decided region by region.
- When no route exists the message says why: no military access to a named country (on the destination or on the way;
  ask for access in Diplomacy), the destination is only reachable by sea and the sea is closed (an enemy navy or no coast
  to sail from), or the divisions are still in training.
- With divisions selected, the card of the region under the mouse shows the **estimated arrival** (no route is drawn
  before the order) ("about N days", the slowest
  of the first three divisions; terrain, infrastructure, season, fuel, supply and cohesion count, battles do not) or says
  there is no route.
- Arrows: no body and no big head — a chain of small marks flowing towards the destination, faint, as if under the map;
  in the country's colour when moving, **red** when attacking into enemy land. A division keeps its place when ordered
  (it does not jump to the region's centre) and starts from there; the arrow passes through and ends at the spots where
  the counters stand (next to the city, or the spot you chose), so an order onto a stack ends under that stack.
- **Motion on the map**: a division ordered into a region where the enemy stands stays where it is and fires from
  there (it never slides towards the enemy and back, even when the attack is called off); it marches in only once the
  enemy has gone. Divisions on the move leave their stack on a counter of their own
  (the stack stays put); divisions marching together share one counter and a straggler comes on its own. A counter
  keeps its identity when it changes region, and any change of place — joining, retreating, advancing — glides instead
  of jumping.
- **Attack estimate**: with divisions selected, the card of an enemy region shows how an attack by the selection would go
  right now: a verdict (hopeless, hard, even, favourable, overwhelming), how many divisions stand on each side, how long
  until the defenders break or our attack runs out, and the factors that move it most (terrain, river crossing, landing
  from the sea, enemy entrenchment, air superiority, supply, mud and winter, planning, commanders, artillery next door).
  It uses the combat formula without the dice. An enemy region with no troops says that whoever enters takes it.
- **Halt**: stops moving and attacking. A division that waits in place digs in: its defence rises by up to 15% over
  10 days.
- **Withdraw**: the division marches to the nearest safe friendly region behind the front (no enemy in it or next to
  it). An attacking division breaks off at no cost. A division under attack breaks away at once and steps back one
  region, but loses a quarter of its cohesion. An encircled division has nowhere to go and the order is refused.
- **Split**: 1, Half or All. For each selected figure, the next order moves one division, half of them or all of them;
  the freshest (highest cohesion) go first and the rest stay. All selects every division standing in those regions.
- **Stance**: **To the last man** (the default for the player's divisions) never retreats by itself; below 12%
  cohesion it fights at half strength and is destroyed when its strength runs out. **Flexible** falls back to the
  nearest safe region when its cohesion is spent.
- **Disband** (manpower returns; equipment does **not**).

## Selected divisions panel (micromanagement)
The selected divisions appear in a panel that slides in from the right edge of the screen:
- **Header**: the number selected and a close button.
- **Summary cells**: number of divisions, average cohesion and strength, how many are in combat, supply.
- **Composition**: how many of each template; click a template → only those stay selected.
- **Division cards** (two columns): icon, name, cohesion and strength bars, status. A card turns red in combat or out of
  supply. Click a card → only that division is selected; × → remove it from the selection.
- **Toolbar** (bottom of the panel): Halt · Withdraw · Split (1 · Half · All) · Stance (To the last man · Flexible) ·
  Disband.

## Chain of command (no longer in the interface)
The war game is played by selecting divisions; the Army screen and the army tools were taken out of the interface
(roadmap new direction, stage 1). The rules below are still in the engine and are used by AI countries.
- **Army group** (field marshal) → **army** (general) → **division**.
- An army is given a front (a country) and its divisions spread along the border by themselves; **Hold** or **Attack**.
  In an army group, front and stance can be given to every army at once.
- **Commanders**: every country has a roster (the great powers have the commanders of the era: Fevzi Çakmak, Manstein,
  Zhukov, Wavell…). Skill 1–5. A general's skill × 4% is added to the attack and defense of the army's divisions (full
  effect up to 24 divisions, more divisions spread it thinner); a field marshal's skill × 2% to every army in the group.
- Commanders gain **experience** while their divisions fight; when it fills up their skill rises by 1.
- **Promotion**: general → field marshal for 30 command power. **Train a new general**: 15 command power (skill 1).
  Command power grows every day, faster at war.
- No commander is **ever assigned automatically** to the player's armies, and an empty army is not deleted. You decide.

## Combat
- Attack: anti-personnel fire × (1 − the target's armour share) + anti-armor fire × armour share, multiplied by strength
  and experience.
- Modifiers: terrain, river (−), landing from the sea (−), no supply −35%, no fuel −35%, winter and mud, night −25%
  (only the attacker; eased at dusk and dawn; `data/common/units.json` → `night`), preparation
  (up to +20%), air superiority and close air support, command bonus (general and field marshal skill).
- Of the attacks met by defense/shock 10% hit, of the rest 40%. Hits reduce cohesion and strength.
- Entrenchment: a waiting division gains up to +15% defense over 10 days.
- **Artillery support**: divisions standing still next to a battle (not marching, not attacking, not in another battle)
  join it with their artillery, on either side. Each adds a quarter of its artillery's anti-personnel fire (a tenth of
  that against armour); it is not fired back at. A division supports one battle an hour and does not trade fire with
  neighbouring enemies that hour. Why a quarter: the two artillery battalions of an infantry division are more than half
  of its anti-personnel fire, so full support would make every neighbour a second attacker; a quarter lets two
  supporters add about a quarter to an attack, which is felt but does not decide a battle by itself. The garrison
  division has no artillery and gives no support.
- Experience: Raw → Drilled → Seasoned → Hardened → Crack.
- **Front integrity**: a division only attacks a region that also touches another of its own (or allied) regions, so no
  lone "finger" is pushed deep and cut off (capitals are the exception). In a narrow peninsula or corridor (Jutland, the
  Danzig corridor) that never holds, so there it attacks when it is clearly superior (2.5× local power) and the target has
  at most 3 other hostile neighbours.
- **An army's front** (U → front: a country) is the border with that country, plus the land of allies that are also at war
  with it and are connected by land to your homeland; an ally's overseas border does not pull your divisions away.
- **A country that loses all its states disappears with its army**: when a country is annexed (e.g. Bohemia and Moravia)
  its divisions, fleets and air wings are removed from the map too.

## On the map
Each division counter shows its type: infantry ✕, motorised ✕ with wheels, armoured an oval (track). Your armies stand
on separate pins even in the same region, with the army's name under the counter; a single division of yours shows its
own name. Names only appear close up.

### The front line
While you are at war, the border between regions held by your side (you and your allies) and regions held by your
enemies glows like a seam of fire under the ground, at every zoom. Click next to it and the **front panel** opens at the
bottom: the two regions, the divisions on each side (number · average strength; "?" under the fog of war), your share of
the air over the enemy region and the battle going on there (each side's cohesion left). Two buttons send a free air
wing that can reach the front: **Air support** (close support over the battle, or the enemy region if there is none)
and **Air superiority**. A close support plane goes first for air support, a fighter for superiority; a wing already on
another mission is not taken. The panel closes by itself when the region changes hands.

## Supply and fuel
Supply reaches at most 9 regions into occupied land from a source on friendly soil; divisions beyond that or encircled
are out of supply: attack −35%, slow recovery. The top bar shows the share of supplied divisions.

## Air (H)
Aircraft in stock are **not used by themselves**: **Form wing** turns up to 100 of them into a wing at the air base
nearest the capital. Missions: standby, air superiority, close air support, port strike, **bombing**. The "Automatic"
box starts off.
- **Region first, then the mission**: with the air panel open, click a region on the map. It becomes the **target** at the
  top of the panel, with our air superiority there and, for an enemy state, its bombing damage. Every wing gets a row
  with Air superiority, Close support and Bombing buttons. If the wing's base is out of range, it moves to the nearest
  of our air bases that reaches the target; if none does, the row says it is out of range. Clear removes the target.
- The old way still works: in a wing's card pick the mission, then Pick zone and click the map.
- **Close air support** is visible on the map: the planes dive on the enemy divisions of a battle in their zone and drop
  their bombs.
- **Bombing**: hits the factories of an enemy state on land and its people's will to fight. Each day it stops
  planes × bomb load × 0.0003 × our air superiority there × (1 − 0.1 per anti-air level) of the state's factories, at
  most 80%; the damage is repaired by 1% a day. Stopped factories produce nothing: military lines lose output by the
  share of stopped military factories (dockyards for ships), and stopped civilian factories do not build. The target
  country's war support drops by planes × bomb load × 0.00001 × superiority a day. Bomb load: bomber 1, close support 0.3,
  fighter 0 (fighters cannot bomb). Why these numbers: an unopposed full wing of 100 bombers stops 3% a day against 1%
  of repairs, so a month of raids stops more than half of a state's industry, and it is back in two months; war support
  drops about 3% a month per wing, so breaking a people takes several wings and months. The bombers fly over the
  state's largest city. The state card shows the damage, and every week you are told which of your states are being
  bombed.
- **Quick reconnaissance**: the Recon button at the bottom of the left menu (or K), then a click on the map: the
  nearest idle wing that can reach the region flies over it (fighters first; wings on another mission are not taken).
- **Reconnaissance**: the wing flies over the zone, and enemy divisions within 350 km of its centre show on the map
  through the fog of war (at night only 175 km: `night_recon_range` in `data/common/recruit.json`). Any aircraft can fly
  it; enemy fighters shoot at it.

## Fog of war
Everything beyond your sight lies under patchy **clouds** on the map: scattered clouds drift over it with clear gaps
between them, so the map stays easy on the eye. Clear: regions held by you or your allies, regions where
your divisions stand and the zones of your reconnaissance wings. Across the border only a strip stays open: in the
neighbouring regions the part near the border is clear and the clouds close in about 100 map pixels further in (the
border strip; divisions standing in these regions are visible). Everything else needs reconnaissance. Under the clouds
the divisions, fleets and air wings of every country that is not your ally are hidden. At night a division sees only
the region it stands in; it uncovers the neighbouring regions when the sun rises, the region card says there is no
information, and the attack estimate says the enemy strength is unknown. The computer's countries are not limited by the
fog; the watch mode has no fog. Until you reconnoitre it, a foreign region under the clouds shows only its cities: the
city markers stay, buildings (ports, air bases, factories) are hidden, and the region card shows the population and
the city but not the infrastructure, buildings or resources.

## Navy (N)
Fleets: in port, naval superiority, convoy raiding, convoy escort. Mission region on the map. When cohesion drops the fleet
returns to port. Ships only travel along sea lanes. Hover a sea region to see **naval control** by country and whether
your transports are safe there. With a fleet selected, the card under the mouse shows the estimated arrival at the order's
target (your port: rebase; elsewhere: the mission region) — the real length of the sea lanes at the slowest ship's speed.
