# Discovery mask and sparse atmospheric clouds

Unexplored terrain remains visible with a subtle neutral tint. Military discovery, unit hiding and saved exploration are independent of atmospheric clouds. A cloud can appear above explored or unexplored ground; flying below it never reveals an unknown unit.

## Discovery: mask only

- Native `game/map/fog_volume.gd` retains the `CloudFog` API name for compatibility, but allocates only a small 2D `SubViewport` mask. Its `CELL = 16` grid is 1024 × 507 on the current 16384 × 8106 map. `assets/shaders/fog_mask.gdshader` samples province discovery at 4 × 4 points per cell, then the map samples the smoothly filtered result.
- Web `web/src/fog.ts` retains persistent exploration and a cached render-target mask; `web/src/cloud-volume.ts` now contains only the mask shaders. The web mask uses half-resolution web coordinates, matching the native world scale approximately.
- Both masks render only when exploration changes. Native `MapView3D.set_fog` also skips uploads when `Military.fog_version` has not changed.
- Native `assets/shaders/map3d.gdshader` and web `web/src/map.ts` blend unknown ground toward `(0.53, 0.59, 0.64)` by at most 8%. The native transition still uses `fog_fade`. There is no black floor, animated discovery-noise calculation, 3D noise texture, or discovery-cloud volume.
- `Military.hidden`, `hidden_at` and `state_fogged` continue to gate divisions, fleets, aircraft and foreign buildings. Recon, movement, allies, observer mode and save data are unchanged.

## Atmosphere: shared soft patches

`game/map/ambient_clouds.gd` and `web/src/ambient-clouds.ts` generate sparse, deterministic world-space patches once. Both use the same `assets/shaders/ambient_clouds.gdshaderinc` soft multi-lobe silhouette: arithmetic only, with no texture sampler, noise lookup or raymarch loop.

- Budget: approximately one patch per 650,000 original map pixels, at most 256; seed `19360901`. Native and web share dimensions/budget and silhouette, but use different deterministic RNG implementations, so their patch positions are not promised to be identical.
- Width 160–380 map units; depth 45–75% of width; height 110–172. Shape, rotation, width, height and opacity vary rather than forming a repeated grid. Web uses the existing 1:8 coordinate scale.
- Each patch is a two-triangle plane. Native groups patches in 2048-unit spatial MultiMesh batches and adds bounded edge copies for horizontal world wrapping. Web uses a static `InstancedMesh` with a shared material and a single transparent pass.
- Slow shader wind moves each patch by at most 10 units horizontally and 5 units longitudinally. CPU instance layouts are not rebuilt per frame or zoom.
- Cloud amount fades from zero at distance 260 to 0.85 at 650; per-patch opacity is additionally limited to 0.20–0.30 and multiplied by the soft silhouette. A height fade hides cards when the camera approaches or moves below their altitude. Nearby views have no cloud cards.
- No shadow pass is added. Native `MapView3D` disables the old full-map procedural weather-shadow branch (`cloud_amount = 0`). Atmosphere never samples discovery or changes exploration.

The removed cost is the former full-map transparent discovery raymarch: 28 steps on Forward+, 20 on Compatibility/WebGL2, including repeated density/shadow noise sampling. The terrain discovery tint also no longer evaluates its five-octave cloud noise every fragment. This is a structural cost reduction, not a measured FPS guarantee for every GPU.

Legacy `fog_volume.gdshader`, `fog_density.gdshaderinc` and `fog_noise_64.bin` remain as inactive source assets; current native/web discovery paths do not load them.

## Checks

`tools/preview_fog_volume.gd` keeps its legacy filename but now captures the actual map, mask-only discovery and sparse atmosphere at strategic, regional, cloud-bank, close and below-cloud views. It uses `RenderingServer.force_draw(false)` rather than waiting for `frame_post_draw`, which may never arrive for a background macOS window. Screenshots are under `art/previews/atmosphere/<renderer>/`; engine/shader/capture failures cause a nonzero exit.

```sh
godot --headless --path . --script tests/run.gd -- --file=test_fog
godot --headless --path . --script tests/run.gd -- --file=test_fog_visuals
godot --headless --path . --script tests/run.gd -- --file=test_ambient_clouds
godot --path . --script tools/test_cloud_coverage.gd
godot --path . --rendering-method gl_compatibility --script tools/test_cloud_coverage.gd
godot --path . --script tools/preview_fog_volume.gd
godot --path . --rendering-method gl_compatibility --script tools/preview_fog_volume.gd
```

The GPU coverage check extracts the actual map tint branch. Explored pixels and a zero-fade unknown mask must match the disabled-FoW baseline; unknown pixels must retain their subtle tint at camera heights 600, 4400, 160 and 55, with no discovery volume allocated. It isolates the discovery cue from atmospheric cards.

Web: `npm run build` in `web/` performs TypeScript checking and a Vite production build. Use a current Node runtime; the system Node 18 is too old for the installed toolchain.

Verified on 2026-10-05: unchanged discovery rules 3/3 and mask-only visibility/resource regressions 3/3; the isolated GPU coverage check passes all four camera heights on Forward+ and desktop GL Compatibility. The actual-map preview also passes on both renderers with 204 patches in 56 native batches, six zoom captures and a regional no-atmosphere comparison. Near (160) and below (55) captures have atmospheric cards disabled, and all zoom/cloud toggles preserve the discovery bytes. No engine/shader/capture errors were collected; existing shutdown CanvasItem/ObjectDB/resource warnings still print after teardown. Web build/browser checks remain separate validation steps; desktop Compatibility is not a claim of coverage across every browser/GPU combination.

Visual QA note: the current GL Compatibility cloud-bank capture is more faint than Forward+. Shared silhouette code does not guarantee pixel-identical opacity/tonemapping across renderers; inspect the paired `cloud_bank.png` previews before claiming equivalent visual strength.
