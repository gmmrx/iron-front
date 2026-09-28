**English** · [Türkçe](tr/02_arayuz.md)

# Interface

## Top bar (left to right)
| Indicator | What it tells you |
|---|---|
| Leader portrait / flag | The leader if a portrait file exists, otherwise the flag; click for country info |
| Influence | +2 a day × (1 + bonuses + stability effect). Laws, advisors, decisions and diplomacy spend it |
| Stability | Effective value; the tooltip breaks it down (base, national conditions/laws/advisors, ruling party popularity) |
| Home front | Effective value; the tooltip breaks it down (base, bonuses, crisis index, war situation) and shows the surrender limit |
| Manpower | Recruitable population (depends on the conscription law) |
| Factories | Civilian / military; dockyards and resources in the tooltip |
| Fuel, Supply, Convoys | Cells with bars: fuel stock, share of supplied divisions, convoy/import need |
| Crisis, War | Crisis index; at war, the number of enemies and your surrender progress |
| Command power, know-how | Separate box: command power (spent on the chain of command), land/naval/air know-how |
| Date and speed | Top right; pause, speed buttons |

Land, naval and air know-how build up in battle but are **not spent on anything yet** (doctrines come later). Their cells
are shown faded with a "not allowed" cursor, and the tooltip says why.

The menu runs down the left edge of the screen; each button shows its shortcut letter. The red tiles next to the top bar
are alerts (empty research slot, idle factories, no state program chosen).

## Screens
Every side panel follows the same layout: a title band, summary cells on top, the content below (drag to scroll).
Large screens open full-screen and the map does not move while they are open.
- **Politics (Q)**: leader, party, ideology pie, elections; influence / stability / home front breakdowns; national
  conditions; three law groups side by side (requirements in the tooltip); advisors; decisions.
- **State Program (F)**: full-screen tree. Green = done, gold = in progress, bright = available, faded = locked,
  red dashed line = only one of the two.
- **Research (I)**: slots on top, all technologies on one timeline by year and category, with prerequisite lines and a
  "today" line. Research never runs out: the last column (1943+) holds each branch's next **refinement** level, open
  once every technology of the branch is done. Each level takes longer (+15%) and gives less (−15%) than the one before,
  so a branch keeps paying off in a long game without ever growing out of bounds; a level is dated one year after the
  previous, so racing ahead costs the usual +150% per year early.
- **Diplomacy (O)**: country list, the selected country's details and actions (with the reason when an action is closed),
  world situation (crisis index, wars, alliances).
- **World events (E)**: what happens in the world, newest on top: wars, alliances, guarantees, surrenders, annexations,
  peace, elections, new leaders, the great powers' state programs — flag, text, date and kind. Filters: *Neighbours* (you
  and the countries on your borders), *My alliance*, *Whole world*. Click a row and the map goes there. A declaration of
  war or an annexation where you are on neither side can be answered for a while (30 / 60 days; gold rows): the options,
  their cost and effects are in the tooltip (see [Diplomacy](06_diplomacy.md)). The news feed in the middle of the screen
  keeps to your own matters (and the great powers' wars and annexations); the rest of the world is in this menu.
- **Trade (R)**: resource table, buying, deals (+/−, cancel), exports.
- **Construction (T)**: summary, building tiles, queue (ordering, cancel, factories at work).
- **Production (Y)**: military factory / dockyard use, lines (factory icons, efficiency, resource shortfall), stock.
- **Army (U)**: two tabs. *Chain of command*: army groups → armies → divisions, the selected army or group (commander,
  front, stance, divisions), commander roster. *Division templates*: templates, designer (battalion grid, +/−), deployment.
- **Navy (N)**, **Air (H)**: fleets and wings, missions, mission regions; the wings' "Automatic" box starts off.
- **Logistics (L)**: equipment stock / in use / daily output / need / balance, resource balance.
- **State panel**: click a state on the map. Building slots, provincial buildings, resources; build directly in your own states.
- **Selected divisions** (bottom): army header, summary cells, composition by template, division cards and a toolbar
  (see [Warfare](05_warfare.md)).
- **Event window**: title, picture, description, options (effects in the tooltip; an option whose condition is not met is locked).

## Map cards
- Hover a land region: owner, relation to you (ours / ally / enemy), terrain, buildings, resources, divisions.
- Hover a sea region: **naval control** by country (coloured share bar), our side's share, whether transports are safe,
  the fleets there.
- Hold **Ctrl** over a country: leader portrait, relation, alliance, ideology bar, stability, home front, influence,
  population, factories, divisions, ships and aircraft (red when stronger than you, green when weaker), wars, national
  conditions and the current state program. **Ctrl + click** opens that country's politics screen, read-only.
- Numbers are coloured: good green, bad red.

## The map: pins
The map is a general staff table: the 3D terrain stays, and everything on it is a pin stuck into it instead of a model.
Far away you see the usual map icons (cities, ports, air bases); zoom in and each icon rises into a pin.
- **City**: a pin with a head in the colour of the country holding it; the bigger the city, the bigger the pin. The name
  sits on the head.
- **Division, fleet, air wing**: the counter is the pin's flag. Each army has its own pin (armies in the same region stand
  side by side, the name of your army written under its counter). Up close, the portrait of the army's commander sits
  above the army's main counter (the one with the most divisions), so you can tell your armies apart at a glance; an
  army whose commander has no picture shows his initials.
- **Buildings**: each state's buildings side by side as pictures (civilian and military factories, dockyards,
  refineries, anti-air, naval base) with their level in the corner; a construction in progress is an orange-framed
  picture with "+n". The air base has its own badge. Buildings show only up close: zoom in and the badges appear on the
  map as small icons; closer still they grow to full size while the pin rises under them. Move the mouse over a badge: it grows, you hear that building, and the card
  shows the building (level / maximum, construction in progress, the country's total, air wings based at an air base).
  Clicking a badge opens its state (with Construction open: builds there).
- **Battles**: small arrows appear beside a battle and fade away: a green ▲ on the side whose position has just
  improved, a red ▼ on the side that is losing ground (the attacker's arrow on the side the attack comes from).
- **Aircraft** are the only models: one small plane in the country's colour, parked by the air base or flying its mission.
- **State borders** are drawn as clear dark lines at every zoom, thicker up close.
Pins keep the same size on screen at every zoom.

## Settings
Main menu → **Settings**, or Esc → **Settings** in the game: master volume, music, sound effects and interface sounds;
music (automatic by game situation, or any track on repeat); language (English / Türkçe, switches at once and a game in
progress carries on); fullscreen, screen-edge scrolling. Everything is saved.
