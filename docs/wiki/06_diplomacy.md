**English** · [Türkçe](tr/06_diplomasi.md)

# Diplomacy

## History (what the other countries do)
Every country except the player's follows history: on the real date, the AI takes the historical step — the
Rhineland (7 Mar 1936), the Marco Polo Bridge (7 Jul 1937), the Anschluss (12 Mar 1938), Munich (30 Sep 1938), Prague
(15 Mar 1939), Albania (7 Apr 1939), the Pact of Steel, the Molotov–Ribbentrop Pact, Poland (1 Sep 1939), the Soviet
invasion of Poland (17 Sep), the Winter War (30 Nov) and the Moscow Peace, Denmark and Norway (9 Apr 1940), the West
(10 May 1940), Italy entering the war (10 Jun 1940), the Baltic states and Bessarabia, the Tripartite Pact, Greece
(28 Oct 1940), the Axis members of 1940–41, the Balkans (6 Apr 1941), Barbarossa (22 Jun 1941) with Romania, Italy,
Finland and Hungary, Pearl Harbor (7 Dec 1941) and the declarations that followed, up to the Soviet war on Japan
(8 Aug 1945). In May 1940 the Netherlands, Belgium and France (if the AI plays them) get "Collapse of the Front" until
1 October (−40% defense, −35% cohesion, −20% attack, a lower surrender limit): the 1940 campaign ends in weeks, as it did.
The timeline is data (`data/common/history.json`).
- **The player's country never acts by itself**: its historical moments come as events with choices. If history is
  aimed at the player (say you play Poland), it still comes.
- **The player changes history**: every step has conditions; when they no longer hold (Germany is not at war with
  Poland, Vyborg is no longer Finnish…) the step is skipped and the world goes its own way from there.
- **Until 2 September 1945** the AI starts no war on its own and does not join an ally's war of aggression when called
  (defending an ally or a guaranteed country still happens at once). After that date the AI acts freely.
- **After the historical flow the world keeps moving**: from 2 September 1945, rule-based events come to every country
  (the player decides, the AI picks by weight), each on average once in its period and not again before its pause:
  | Event | Comes to | On average | Pause | Options |
  |---|---|---|---|---|
  | Clash on the Border | a country at peace, with a non-allied neighbour | 1,800 days | 720 days | demand reparations (−20 influence, casus belli against the neighbour, crisis +2) / settle it (+2% stability, −2% home front) |
  | Run on the Banks | any country | 2,600 days | 1,100 days | rescue the banks (−40 influence, +2% stability) / let them fail (−6% stability, +15 influence) |
  | Officers' Plot | a country with stability under 35% | 1,500 days | 1,500 days | arrest them (+4% stability, −3% home front) / give the army a voice (fascism +10%, +3% stability, +3% home front) / early elections (democracy +10%, −2% stability) |
  | The Soldiers Come Home | a great power at peace | 400 days | 10 years | demobilise (2 civilian factories, −8% home front, +3% stability) / keep the army (+4% home front, −4% stability) |

  The border clash is how the AI finds new wars: a country that demands reparations gets a casus belli, and a
  non-democratic AI with a casus belli declares war when its army is strong enough. The events are data (`"recur"` in
  `data/common/events.json`).

## Crisis index
How close the world is to general war. It rises with aggression (preparing a casus belli, annexations, war). It strengthens
everyone's home front (+0.4% per 1%, at most +40%).

| Ideology | Casus belli | Can guarantee | Can join an alliance |
|---|---|---|---|
| Fascist / communist | always | always | always |
| Non-aligned | index ≥ 50% | index ≥ 40% | index ≥ 40% |
| Democratic | index 100% and the target is not a democracy | index ≥ 25% | index ≥ 80% (50% at war) |

## Actions (O, or a country on the map → Diplomacy)
- **Casus belli**: 30 influence, 30 days. Once ready, war can be declared.
- **Declaration of war**: the target's allies and guarantors join in.
- **Guarantee of independence**: you go to war against whoever attacks it.
- **Military access**: your divisions may cross its land (the same ideology or an ally accepts, others 30%).
- **Invite to alliance**: alliance leader only.
- **White peace**: peace with no change of land; the losing side accepts. Between two war leaders the war ends for
  everyone; if one side is an alliance member, only that member leaves the war and the leader keeps fighting the rest.
- The reason an action is closed is written in orange under its row.

## Answering the world (World events, E)
When a country declares war on another, or annexes it, and you are on neither side (nor allied to either), the entry in
the world events menu carries options for a while:
| Event | Option | Effect |
|---|---|---|
| War declared (30 days) | Condemn the aggression | −10 influence, +2% home front (the public rallies) |
| | Send rifles to the victim | −500 rifles from your stock, −5 influence; the victim gets 500 rifles (needs 500 in stock) |
| | Stay out of it | +1% stability |
| Annexation (60 days) | Refuse to recognise it | −25 influence, a casus belli against the annexer |
| | Recognise it | crisis index −1 |

When **you** start a war, the democratic great powers that are not on either side condemn a non-democratic aggressor
(the same option, with its cost to them); their condemnation appears in the menu and in your feed. Options and numbers
are data (`data/common/world_reactions.json`).

## Surrender
- Surrender progress = the share of your cities' victory points held by the enemy (colonies count ¼) + 10% if the capital
  has fallen.
- The limit is 80%; when the home front is below 50% it drops by (0.5 − home front) × 0.6; some national conditions change
  it (e.g. France's Revolving-Door Cabinets −30%). The lowest is 20%.
- The occupied states of a surrendering country pass to the occupier.
