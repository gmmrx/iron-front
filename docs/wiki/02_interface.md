**English** · [Türkçe](tr/02_arayuz.md)

# Interface

## Top bar (left to right)
The top bar is built from the interface sheet `assets/ui/ui-sprite2.png` (cut into `assets/ui/sheet/` by
`tools/slice_ui_sprite.py`): a framed portrait, the resource bar (icon on top, value under it, divided cells), the
alert box of the same height next to it, and the date box. The menu buttons sit on a tray in the same frame. Values that
grow every day (influence, industry points) show the daily gain in small green figures to the right of the value.

| Indicator | What it tells you |
|---|---|
| Leader portrait / flag | The leader if a portrait file exists, otherwise the flag; click for country info |
| Influence | +2 a day × (1 + bonuses + stability effect), the gain in green. Laws, advisors, decisions and diplomacy spend it |
| Stability | Effective value; the tooltip breaks it down (base, national conditions/laws/advisors, ruling party popularity) |
| Home front | Effective value; the tooltip breaks it down (base, bonuses, crisis index, war situation) and shows the surrender limit |
| Manpower | Recruitable population (depends on the conscription law) |
| Industry points | Recruiting and recon money, the daily gain in green; factories and resources in the tooltip |
| Fuel, Supply, Convoys | Fuel stock, share of supplied divisions, convoy/import need |
| Crisis, War | Crisis index; at war, the number of enemies and your surrender progress |
| Date and speed | Top right; ❚❚ pauses, ▶ resumes (while the game runs it slows down one step), ▶▶ speeds up; the gold bar under the date shows the speed; five speeds 0.1× · 0.2× · 0.3× · 0.5× · 1× (1× = 5 game hours a second) |
| World clock | The globe left of the date: centred on your capital, the lit half follows the game hour and the season (day / night) |

The menu runs down the left edge of the screen with six buttons: politics, diplomacy, production, army, navy and air;
each shows its shortcut letter. The program, research, world events, trade, construction and logistics screens are no
longer in the menu (their shortcuts still open them) and are being cut down (roadmap stage 3). The tiles in the box next to the resource bar
are alerts (the box is hidden when there are none): an event waiting for an answer, enough industry points to recruit (opens the capital), idle air wings,
divisions out of supply, low manpower, risk of surrender. Map buildings (ports, air bases, factories) are fixed and shown
on the map; a foreign state's buildings stay hidden under the fog until it is explored.

## Screens
Every side panel follows the same layout: a title band, summary cells on top, the content below (drag to scroll).
Large screens open full-screen and the map does not move while they are open.
- **Politics (Q)**: leader, party, ideology pie, elections; influence / stability / home front breakdowns; national
  conditions; three law groups side by side (requirements in the tooltip); advisors; decisions.
- **State Program (F)**: full-screen tree. Green = done, gold = in progress, bright = available, faded = locked,
  red dashed line = only one of the two. Move around it like the map: the mouse wheel (or a trackpad pinch) zooms where
  the cursor is, dragging empty space pans (it glides on when you let go), the arrow keys / WASD pan too; −, + and
  *Fit* sit in the header. Every move eases in instead of jumping.
- **Research (I)**: slots on top, all technologies on one timeline by year and category, with prerequisite lines and a
  "today" line. Research never runs out: the last column (1943+) holds each branch's next **refinement** level, open
  once every technology of the branch is done. Each level takes longer (+15%) and gives less (−15%) than the one before,
  so a branch keeps paying off in a long game without ever growing out of bounds; a level is dated one year after the
  previous, so racing ahead costs the usual +150% per year early. A running technology's progress fills its button (and
  its slot) from the left as a gold background; the text stays in front.
- **Diplomacy (O)**: country list (every flag the same size; a search box on top filters it by name or country code,
  Turkish letters or capitals do not matter, Enter picks the first match), the selected country's details and actions
  (with the reason when an action is closed), world situation (crisis index, wars, alliances).
- **World events (E)**: what happens in the world, newest on top: wars, alliances, guarantees, surrenders, annexations,
  peace, elections, new leaders, the great powers' state programs — flag, text, date and kind. Filters: *Neighbours* (you
  and the countries on your borders), *My alliance*, *Whole world*. Click a row and the map goes there. A declaration of
  war or an annexation where you are on neither side can be answered for a while (30 / 60 days; gold rows): the options,
  their cost and effects are in the tooltip (see [Diplomacy](06_diplomacy.md)). The news feed in the middle of the screen
  keeps to your own matters (and the great powers' wars and annexations); the rest of the world is in this menu.
- **Trade (R)**: resource table, buying, deals (+/−, cancel), exports. *Automatic trade* is one of the summary cells at the
  top: its state (off — you trade / on) and a Turn on / Turn off button next to it.
- **Construction (T)**: summary, building tiles, queue (ordering, cancel, factories at work).
- **Production (Y)**: military factory / dockyard use, lines (factory icons, efficiency, resource shortfall), stock. On
  each line the factory count (− n +) and the separate remove button sit in the middle of the row on the right.
- The Army screen (armies, army groups, commanders, templates) is no longer in the menu: you select divisions on the
  map and command them directly (see [Warfare](05_warfare.md)).
- **Navy (N)**, **Air (H)**: fleets and wings, missions, mission regions; the wings' "Automatic" box starts off. Each
  fleet / wing is a card: an icon slot with its name and where it is, the ship make-up or the wing's planes, a cohesion /
  planes bar, a row of missions (the chosen one gold and bold, the others dim) and the region with its buttons. The
  selected card has a gold frame and a gold name. With the air panel open, a click on the map makes that region the
  **target** at the top of the panel, where each wing gets its mission buttons (see Warfare → Air).
- **Logistics (L)**: equipment stock / in use / daily output / need / balance, resource balance.
- **State panel**: click a state on the map. Building slots, provincial buildings, resources; build directly in your own states.
- **Selected divisions** (bottom): army header, summary cells, composition by template, division cards and a toolbar
  (see [Warfare](05_warfare.md)).
- **Event window**: title, picture, description, options (effects in the tooltip; an option whose condition is not met is locked).

## Map cards
Map cards do not open by themselves: hold **Shift** for the card of what is under the cursor (region, building, fleet or
route; with units selected also the order's arrival and attack estimate), hold **Ctrl** for the country card.
- Shift over a land region: owner and relation to you (ours / ally / enemy), coast / port / river; **ground and weather**
  (terrain, weather — clear, mud, winter, hard winter —, march speed, the penalty for attacking here, frontage, supply,
  river and landing penalties, air superiority at war); **region** (population, victory points, infrastructure,
  building slots, buildings and resources as icon cells); the divisions there by country (in training too) and the
  battle there.
- Shift over a sea region: weather (winter sea), coasts and ports; **naval control** by country (coloured share bar), our
  side's share, whether transports are safe, the fleets there.
- Hold **Ctrl** over a country: leader portrait, relation, alliance, ideology bar, stability, home front, influence,
  population, factories, divisions, ships and aircraft (red when stronger than you, green when weaker), wars, national
  conditions and the current state program. **Ctrl + click** opens that country's politics screen, read-only.
- Numbers are coloured: good green, bad red.

## Day and night
The sun moves with the game clock: where it is night the map is dark blue, with a thin warm band
of dusk at the boundary, which slides smoothly across the map; its shape follows the season (long winter nights in the
north). Up close the 3D models (soldiers, tanks, cities, ships) share the light of the place you are looking at.
Clouds darken too, and at night the windows of the city miniatures light up one by one. At the fastest speeds the night
is lighter so the map does not flicker. The game starts at 07:00 in your capital, and the clock in the top bar shows
your capital's local time. Night counts in battle: attacking at night is −25% and a division sees only its own region
(see [Warfare](05_warfare.md)).

## The map: pins
The map is a general staff table: the 3D terrain stays, and everything on it is a pin stuck into it instead of a model.
Far away you see only the countries, their names and the capitals; the usual map icons (big cities, ports, air bases),
city names and unit tags appear as you zoom in to a theatre, and up close each icon rises into a pin.
- **The ground** is a painted map: up close farmland is a patchwork of fields (green, olive, mustard, wheat) with dark
  field edges, mountains have fine ridges and valleys lit from the north-west in earthy tones, and the coast has
  turquoise shallows and a thin line of foam. There are no tree models. The **Political** mode is plain: each country's
  colour lies over the ground like a thin wash — see-through inside the country, deepening towards its border — so the
  countries read at a glance. The colours are the countries' own, brought into one light, lively range (dark ones
  lightened, very pale ones deepened, the hue never changes). Far away the map is flat colour: no relief, no rivers, no
  province lines, and state lines only at theatre zoom; the relief, rivers and province lines come in as you zoom in
  (no fields, ridges or forest detail in this mode); the **Terrain** mode shows the detail at every
  zoom (ridges, forest texture and field patches keep a fixed size on screen, stronger relief); the **Terrain** mode
  shows the ground in its own colours. The mode buttons are no longer on screen; the keys still switch: F1 political,
  F2 terrain, F3 states, F4 routes.
- **City**: far away a plain white name (gold for capitals). Only the big cities (capitals and cities worth 10+ victory
  points) have a model; the others stay a plain name at every zoom. Zoom in and a big city's town hall miniature (a domed
  building on a dark round plinth, `assets/models/city-hall.glb`) springs up on the map, its entrance towards the camera;
  the bigger the city, the bigger the model, and a capital's roof stays below the counter of a division standing in it.
  The name then sits just below the plinth in a dark, thin-framed box. Models keep their size and place while you pan, and
  one that leaves the view range shrinks and disappears.
- **Aircraft** appear only up close.
- **Roads and railways** show only in the **Routes** map mode (up close): roads as thin cream lines, railways as dark
  lines with sleepers; a road behind a mountain is hidden.
- **Divisions, fleets, air wings** look alike. From afar they are small tags lying on the map without a pin:
  "flag | number" for divisions, "ship | number" for fleets, "plane | number" for air wings (the tag is in the country's
  dark colour with a light-to-dark border in the country's colour; you can select them and give orders). Zoom in and
  each tag turns into a plate on an iron pin (after `art/soldier-pins.png`): a dark plate with a bronze frame (gold when
  selected), the country's flag as a strip on the left, the picture of the unit in the middle (infantry, motorized,
  light or medium tank — the most common type in the stack —, ship, submarine, plane), a small map symbol top right,
  the number in large figures bottom right. No names are written on the map (in a war they only cluttered it; the name
  is in the tooltip and the selection panel); instead an army's counters carry rank stars just outside the plate's
  top-left corner: ★ an army without a commander, ★★ an army under a general, ★★★ under a marshal; a division outside
  any army has none. The flag is a strip the full height of the plate, hung vertically
  like a banner (never cut or stretched; a square flag stays square), its colours toned to the painted map (very light
  colours softened). Very close a stack spreads out:
  the battalions inside appear as round heads of the same size (infantry, artillery, anti-tank, trucks, tanks) with
  their numbers. Cohesion and strength are in the selection panel. Pins do not grow under the mouse. Each army has its own counter. Up close, the portrait of the army's commander sits
  above the army's main counter (the one with the most divisions), so you can tell your armies apart at a glance; an
  army whose commander has no picture shows his initials.
- **Up close, divisions are soldier miniatures** (desktop; the browser version keeps the plates). Instead of the plate,
  a division counter up close is a painted soldier on a round dark base, like a miniature on a table (a stack that is
  mostly armoured divisions is a tank on the same base, turning the same way): the country's flag in a thin brass frame and the number of
  divisions sit on the front of the base. A figure has a fixed size on the map (about 12 km tall), so zooming never
  moves it — it only looks larger as you zoom in and smaller as you zoom out. Figures stand on the ground: on a slope or
  a hill the base sits on the terrain (never sunk into it) and leans a little with the slope. The soldier and the disc
  he stands on turn to face where he is going: a marching soldier faces his road (and the way he steps when giving
  way), a soldier in battle faces the enemy, a soldier standing at the front faces the nearest enemy region, an idle
  one turns back to the camera; the base with the flag and the number never turns. Figures never pass through each
  other and never slide: every displacement is a walk at walking pace, facing the way it goes. A marching figure steps
  aside around one standing in its way (the standing one is not pushed) and returns to its road once past; of two
  marching the same way the one behind gives way; two that meet head on both give way; two standing figures that would
  touch move apart a little. Because the camera looks from the south, figures behind one another are kept a whole
  figure apart. A figure marching to friends at its destination reserves a free place in their formation from the last
  leg on and walks straight into it; one that sets off leaves from its place in the formation. Fleets and air wings
  keep their plates.
- **Up close, counters never cover each other.** Friendly plates that would touch or overlap on screen (side by side
  or on top of each other, e.g. several armies in one region) gather at one point into a small grid: the first plate
  stays exactly where it is, on its pin, and the others sit beside and above it (right, left, the row above...) without
  pins. Every plate keeps its cell while it is in the grid — when one joins or leaves the others do not move (a gap is
  left). Joining takes a touch, leaving takes a clear gap. A counter moves only when its divisions really march. More than nine plates in one spot become a
  closed deck: one plate with the total number and two card edges behind it; click it to select them all, hover it
  and it opens into the grid (it closes when the mouse leaves). For figures the grid is laid out on the map itself, so
  zooming in or out never rearranges it: ranks of three, each rank behind the last and shifted by half a place, so the
  soldiers behind show between the ones in front. Marching counters pass by without joining. Far away the
  small tags stay where they are. A counter attacking an enemy stays where it is and fires from there (it does not slide
  towards the enemy and back); it marches in only once the enemy is gone. A division that meets the enemy while marching
  halts before the halfway point of its leg, so that even if both sides halt facing each other a gap of about a figure
  and a half stays between them: they fire at range, never base to base. A division's standing spot is always inside
  its own region. When a division is destroyed its counter turns
  black and white, then fades away over a couple of seconds.
- **Buildings**: each state's buildings side by side on dark square tiles with a gold frame and a gold pictogram (civilian
  and military factories, dockyards, refineries, anti-air, naval base), the level in the lower right corner; a
  construction in progress has an orange frame and "+n". Buildings appear only at the closest zoom steps. The air base has its own badge. Buildings show only up close: zoom in and the badges appear on the
  map as small icons; closer still they grow to full size while the pin rises under them. Move the mouse over a badge: it grows, you hear that building, and the card
  shows the building (level / maximum, construction in progress, the country's total, air wings based at an air base).
  Clicking a badge opens its state (with Construction open: builds there).
- **Battles**: the plates in a battle glow around their edge, pulsing gently: green on the side that is getting the
  upper hand, red on the side that is losing ground; the crossed-swords marker between them beats softly. Small orange
  muzzle flashes spark on the side of the counter that faces the enemy (on a figure, by its rifle; a figure does not
  glow). Small arrows
  rise and fade right beside the counters: a green ▲ next to the side whose position has just improved, a red ▼ next
  to the side that is losing ground. The arrows belong to the counter, so they travel with it when it moves (when a
  counter is hidden far away, the arrow shows at the battle instead). Counter numbers of 1000 and more are shortened
  (1.1K) and long numbers are written smaller, so they stay inside the plate.
- **Aircraft** are the only models: one small fighter carrying the country's flag on both wings and both sides of the
  fin, its propeller spinning in flight (stopped on the ground), parked by the air base or flying its mission.
  Air wings have no pin: their "plane | number" tag sits on the air base (all the planes based there). Planes fly like
  planes — steady speed, turning at a limited rate and banking into the turn, never a sharp corner — and in sorties:
  take off, fly to the target, do the job once, fly home, land and re-arm on the ground for a while, then go again.
  Close support dives on the target, drops a bomb at the bottom and strafes on the way down; tactical bombers make a
  level pass and drop a stick of bombs; fighters fly a wide patrol loop around their region (and weave in a dogfight).
  They no longer circle the target and bomb it without end.
- **State borders** are drawn as clear dark lines, thicker up close; in the Political mode they fade out when you zoom
  out to a whole continent (only country borders stay). In the States and Terrain modes they show at every zoom.
Pins keep the same size on screen at every zoom.

## Settings
Main menu → **Settings**, or Esc → **Settings** in the game: master volume, music, sound effects and interface sounds;
music (automatic by game situation, or any track on repeat); language (English / Türkçe, switches at once and a game in
progress carries on); fullscreen, screen-edge scrolling. Everything is saved.
