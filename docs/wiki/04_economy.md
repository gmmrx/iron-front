**English** · [Türkçe](tr/04_ekonomi.md)

# Economy

## Factories and consumer goods
- **Civilian factory**: builds, and pays for trade. Part of them must make **consumer goods** for the population
  (33% → 12% depending on the economic mobilization law; less when stability is above 50%).
- **Military factory**: produces equipment. **Dockyard**: ships and convoys.
- The factory cell on the top bar shows in its tooltip: civilian / consumer goods / available for construction.
- Even when consumer goods and imports take every factory (or there are no civilian factories at all), **one factory's
  worth of public construction** remains, so even the smallest country can build.

## Construction (T)
| Building | Cost (factory-days) | Max | Note |
|---|---|---|---|
| Civilian factory | 2,160 | 20 | shared slot |
| Military factory | 1,440 | 20 | shared slot |
| Dockyard | 1,280 | 20 | shared slot, coastal |
| Synthetic refinery | 3,000 | 3 | shared slot; fuel and rubber |
| Infrastructure | 1,100 | 5 | each level speeds construction by +5% |
| Air base | 300 | 10 | |
| Naval base | 450 | 10 | coastal |
| Anti-air | 400 | 5 | |

- Costs are in **factory-days**: each civilian factory does **1** a day; at most **12** factories work on one project.
- Factories, dockyards and refineries share the state's **building slots** (shown in the state panel).
- Speed bonuses: laws, advisor (Planning Commissioner +9%), decision (Emergency Industrial Drive +15%), technology;
  a penalty when stability is below 50%.

### On the map
Close up, each state's buildings stand on one pin next to its main city: pictures of civilian and military factories,
dockyards, refineries, anti-air and the naval base side by side, each with its level in the corner. A construction in
progress shows as an orange-framed picture with "+n" (projects queued). The air base has its own pin. Far away the usual
map icons are shown (see [Interface](02_interface.md#the-map-pins)).

## Production (Y)
- At most **12** factories per line. Costs are in **factory-hours**: each military factory and dockyard works **24** hours
  a day (e.g. rifles 2.7, artillery 19, light tank 43, fighter 117, destroyer 580, battleship 4,800 factory-hours).
- **Efficiency** starts at 15% and rises ever more slowly towards the cap (2% of the remaining gap per day); the cap is
  50%. Switching a line resets its efficiency.
- A resource shortfall slows the line (down to 25% speed); the line's row turns red.
- Total output bonus: laws, advisor, technology + stability effect (+20% at 100%, −50% at 0%).

## Trade (R)
- Every country offers part of its output on the market (foreign trade policy: Open Markets 70%, Clearing Agreements 45%,
  Autarky 20%, State Trade Monopoly 5%).
- **8 resources = 1 civilian factory**: the buyer pays, the seller earns.
- **The player trades by hand**: for a resource in shortfall, **Buy** → the selling country. In the deal list: +8 / −8 /
  cancel. You cannot import what you cannot pay for (factories left after consumer goods + export earnings).
  If the seller's supply is short the deal is partly filled ("the seller cannot cover it all"). You cannot buy from a
  country you are at war with; deals with it are cut on the day the war starts.
- The **Automatic trade** box only works if you switch it on (shortfalls are bought from the biggest sellers). AI countries
  always trade automatically.
- Imports come by sea: **1 convoy per 2 resources**; without enough convoys only part of the imports arrive (at least 25%).

## Resources
Oil, steel, aluminium, tungsten, chromium, rubber. Oil becomes fuel (tanks, motorised units, ships and aircraft burn
fuel; units without fuel lose 35% of their strength). Synthetic refineries give rubber and fuel.

## Logistics (L)
Per equipment type: stock, in use with divisions, daily output, needed to bring divisions to full strength, balance.
A negative balance is red: start producing that equipment or import it.
