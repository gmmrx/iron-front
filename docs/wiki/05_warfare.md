**English** · [Türkçe](tr/05_savas.md)

# Warfare

## Divisions and templates (U → Division templates)
- Battalion types: infantry, artillery, anti-tank, motorised infantry, light tank, medium tank (needs research).
- Template designer: +/− per battalion (at most 25 battalions per template). Values: anti-personnel fire, anti-armor fire,
  defense, shock, cohesion, speed, frontage, manpower. An infantry battalion: 30 anti-personnel fire, 110 defense, 15 shock,
  100 cohesion, 50 durability.
- **Deploy**: with enough manpower and equipment the division trains for 14 days (it cannot move meanwhile); the
  conscription law changes this (Two-Year Service 13, Reserve Call-Up 16, Levée en Masse 20 days).

## Orders
- Select with left click / box, **right click** (on the web and on Mac: Ctrl + left click while divisions are selected) to
  move to or attack the target region.
- With divisions selected, the region card under the mouse shows the **estimated arrival** ("about N days", the slowest
  of the first three divisions; terrain, infrastructure, season, fuel, supply and cohesion count, battles do not) or says
  there is no route.
- Arrow colour: **green** move, **red** attack into enemy land. Arrows are drawn with marks flowing towards the tip.
- **Stop**, **Disband** (manpower returns; equipment does **not**).
- **Hold to the last man**: on by default for the player's divisions. The division never retreats by itself; below 12%
  cohesion it fights at half strength and is destroyed when its strength runs out. Switch it off and it falls back to the
  nearest safe region when its cohesion is spent.

## Selected divisions panel (micromanagement)
The selected divisions appear in the panel at the bottom:
- **Header**: if they all belong to one army, its colour, name, commander (rank, skill, command bonus), front, Hold /
  Attack, **Manage** (opens the army in the Army screen) and **Select army**. Otherwise the number selected and whether
  they come from several armies or none.
- **Summary cells**: number of divisions, average cohesion and strength, how many are in combat, supply, how many are on
  direct orders.
- **Composition**: how many of each template; click a template → only those stay selected.
- **Division cards**: icon, name, cohesion and strength bars, status and army. A card turns red in combat or out of supply
  and gold on direct orders. Click a card → only that division is selected; × → remove it from the selection.
- **Toolbar**: Stop · **Split** (the first half stays selected, the rest is released: send the two halves to different
  places) · **Back to army plan** · **New army with these** · **Join army…** · **Leave army** · Hold to the last man ·
  Disband.
- **Direct orders**: if you order a division of an army on the map, it stays in the army (keeping the command bonus) but
  the army no longer pulls it back to the front. **Back to army plan** hands it back to the army.

## Chain of command (U → Chain of command)
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
- Modifiers: terrain, river (−), landing from the sea (−), no supply −35%, no fuel −35%, winter and mud, preparation
  (up to +20%), air superiority and close air support, command bonus (general and field marshal skill).
- Of the attacks met by defense/shock 10% hit, of the rest 40%. Hits reduce cohesion and strength.
- Entrenchment: a waiting division gains up to +15% defense over 10 days.
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

## Supply and fuel
Supply reaches at most 9 regions into occupied land from a source on friendly soil; divisions beyond that or encircled
are out of supply: attack −35%, slow recovery. The top bar shows the share of supplied divisions.

## Air (H)
Aircraft in stock are **not used by themselves**: deploy them to an air base as a wing. Missions: standby, air
superiority, close air support, port strike. Pick the mission region on the map. The "Automatic" box starts off.

## Navy (N)
Fleets: in port, naval superiority, convoy raiding, convoy escort. Mission region on the map. When cohesion drops the fleet
returns to port. Ships only travel along sea lanes. Hover a sea region to see **naval control** by country and whether
your transports are safe there.
