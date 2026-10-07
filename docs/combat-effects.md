# Combat graphics — 2026-10-06

The active land, aircraft and naval effect paths now share `game/map/combat_effects.gd`.
This change is cosmetic: damage, casualties, mission outcomes, terrain, map UI and
Fog of War rules remain owned by the existing simulation. No map background work
is included.

## Visual profiles

- Infantry: short, small directional muzzle flash, narrow fast tracer, small earth
  impact and powder smoke. Uses the existing figure's muzzle socket and recoil.
- Tank/cannon: larger bore-aligned flash, short light pulse, slower firing cadence,
  shell travel followed by impact. Not an explosion emitted on the firing frame.
- Land impact: 16-frame alpha flipbook with interpolated frames, brief hot core,
  cooling soot, ballistic soil fragments, low dust skirt and fading scorch.
- Aircraft: paired wing-gun flashes; visual-only dogfight tracers; ground impacts
  only for downward strafing rays that reach nearby ground. Staggered physical
  finned bombs retain horizontal velocity and fall under gravity. Actual aircraft
  losses can produce a falling burning model and a world-space smoke trail.
- Sea: naval gunfire and water impacts use the shared renderer. Water impacts use
  pale spray, droplets and a surface skirt, without a land fireball or scorch.
  Sinking effects preserve the existing ship-model visibility policy.

## Assets and portability

- `assets/vfx/combat/explosion_flipbook.png`: 1254×1254 RGBA, 4×4 frames.
- `assets/vfx/combat/smoke_atlas.png`: 1254×1254 RGBA, four variations.
- `assets/vfx/combat/water_flipbook.png`: 1254×1254 RGBA, 4×4 liquid splash frames.
- Full source prompts: `assets/vfx/combat/PROMPTS.md`.
- All are imported Texture2D resources, with mipmaps and alpha-border repair.
  Runtime resource loading works with packed resources; it does not load raw PNG
  source files or fetch images from a service.
- Three small shaders support Forward+ and Compatibility. They do not require
  depth-texture sampling, compute particles or screen-space effects. Alpha sprites
  are camera-facing, depth-tested and sorted back-to-front within their batch.
- Generated sprites are 2D VFX billboards, not volumetric fluid simulation. Water
  uses its own splash flipbook plus a few subtle mist puffs and ballistic droplets.
  These are deliberate bounded-cost approximations for an RTS camera.

## Runtime limits

| Resource | Whole shared renderer limit |
| --- | ---: |
| Alpha sprites | 256 |
| Muzzle/tracer streaks | 160 |
| Ground dust/scorches | 48 |
| Debris fragments | 96 |
| Total transient particles | 560 |
| Moving smoke/fire trails | 16 |
| Reusable non-shadowed flash lights | 3 |

Four preallocated MultiMesh batches; no particle node or light allocation per
shot. Over-budget cosmetic particles are dropped. Aircraft also limit active plus
pending bombs to 96, crash queue to 6 and simultaneous falling planes to 3.
Naval sinking roots/tweens are capped at 8 and retired when offscreen, far away,
hidden or finished. Disbanding an aircraft wing does not invent a combat crash.

Effects stop beyond camera distance 580 and fade from 430. Layer-specific close
visibility gates can be stricter. Event origins and moving particles are checked
against actual province visibility and the viewport. Unknown events do not reserve
resources. Leaving the close view clears transient effects rather than replaying
them later.

Pause freezes event admission, age, motion, bombs and crash/sink animations. Camera
billboarding and visibility still update, including hiding flash lights when the
underlying province becomes unknown. Each effect producer uses private cosmetic
randomness instead of changing the gameplay RNG sequence.

## Verification and reproduction

Run from the repository root with the installed Godot executable:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . -s tests/run.gd -- --file=test_combat_effects
godot --headless --path . -s tests/run.gd -- --file=test_ground_combat_fx
godot --path . -s tools/preview_combat_effects.gd
godot --path . --rendering-method gl_compatibility -s tools/preview_combat_effects.gd
```

`test_combat_effects`: seven regressions covering saturation/fixed allocations,
pause, expiry/reuse, far zoom, Fog of War, global RNG independence and water profile.
`test_ground_combat_fx`: five regressions covering muzzle alignment, weapon
cadences, pause and visibility gates. Existing air-sortie, fleet-zoom and naval
damage regressions were also run.

A production Main-scene smoke check additionally verified all three layers share
the exact same renderer and the impact/recoil signal is connected. A real TUR–IRQ
border-battle fixture emitted a figure shot and a delayed impact with no runtime
errors. Aircraft's isolated behavioural probe covered 32 assertions, including
identical 30/120fps shot counts, bomb staggering, disband versus casualty,
visibility changes during pause, and visibility at the next projectile position.

The deterministic preview uses the actual map renderer, existing miniatures and
aircraft, production `UnitLayer._fire`, aircraft bomb integration and shared VFX.
It records actual GPU frames into `art/previews/combat/<renderer>/`. It is a staged
effect demonstration, not a recording of a simulated battle. Optional
`-- --frames=/absolute/temp/folder` writes 120 PNG frames for a four-second 30fps
video. Preview artifacts are excluded from Godot import/export with `.gdignore`.

Forward+ and desktop Compatibility were visually checked on Apple M1 Max. This
does not constitute a browser performance measurement. No numeric FPS gain is
claimed. Existing audio/ObjectDB resource warnings can still appear at process
shutdown after successful tests; runtime test loggers reported no effect errors.
