# Combat VFX sources

Generated with the built-in `image_gen` tool for Iron Front. All original PNGs retain their generated alpha. No gameplay or geographical content is baked into them.

- `explosion_flipbook.png`: 4×4 chronological burst frames, sampled with adjacent-frame crossfade.
- `smoke_atlas.png`: 2×2 smoke variations, also tinted as powder, earth dust and faint mist.
- `water_flipbook.png`: 4×4 liquid splash frames; foam is neutralized and gently cool-tinted by the shader.
- Runtime: `game/map/combat_effects.gd`; no external service or network fetch.

## Explosion prompt

Use case: stylized-concept.
Asset type: production realtime VFX FLIPBOOK SPRITE SHEET with genuine transparent RGBA background for a realistic WWII RTS.
Create exactly a 4-column by 4-row perfectly uniform grid, SIXTEEN consecutive animation frames of ONE compact ground-impact high-explosive artillery burst, chronological order left-to-right then top-to-bottom. Square overall canvas, maximum available native resolution. Each of the 16 square cells has the same empty margin, fixed camera, same ground anchor at bottom-center, same scale and exact aligned center. Entire effect stays inside its own cell with transparent padding on every edge; no overlap across cells.
Render like an expertly simulated fluid/pyro Houdini explosion, filmed from a strategy camera 45 degrees down at the ground: frame1 a tiny very brief hot white/yellow ignition; frames2–4 fast asymmetric compact orange fireball with incandescent core and sharply resolved turbulent lobes; frames5–8 dark russet turbulent combustion with grey-black soot folding over the orange core, very short-lived flame; frames9–12 irregular rising charcoal/grey billowing smoke and brown soil plume with internal depth; frames13–16 smoke expands, becomes thin and wispy and disperses. Ejected earth should mostly stay in a low wide skirt, while the smoke rises; no nuclear mushroom. This is a 75mm to medium artillery impact, not a huge Hollywood fuel fire.
High-end photorealistic volume detail, readable small silhouette, varied eddies, small hot flecks within the earliest frames only, natural short combustion phase and much longer cooling smoke. Warm realistic fire colours, neutral grey/charcoal smoke with side-lit volume; no black flat disks, no round cartoon puff balls, no blue magic energy. Crisp enough for a game camera, no photographic motion blur.
ISOLATED EFFECTS ONLY with a real alpha channel, no background at all, no ground plane or scenery baked into frames, no gradients behind effect, no contact-shadow plate. No grid lines, borders, numbers, labels, watermarks, UI, people, weapons or debris crossing frame boundaries. Do not draw a checkerboard. Exactly16 frames in4x4, consistent placement and progressive animation.

## Water splash prompt

Use case: stylized-concept.
Asset type: production realistic WWII naval RTS water-impact flipbook, genuine transparent RGBA background.
A perfect 4 columns by 4 rows grid of exactly SIXTEEN chronological frames of one high-explosive shell landing in water. Same fixed elevated strategy camera, same scale and centered bottom anchor in every equal square cell. Square canvas, maximum native resolution. Each frame fully inside its cell, with transparent padding, no overlaps.
Frames1–3: a sharp compact white foamy crown bursts outward and several tall narrow irregular liquid fingers shoot upwards. Frames4–7: a powerful tall white and pale blue-grey turbulent column of WATER sheets and foam rises, crisp transparent liquid edges and hundreds of tiny droplets, asymmetrical spray, not smoke. Frames8–11: liquid column falls back outward under gravity, broken curtains of clear water, lower foam corona. Frames12–16: falling droplets and thin low foamy remnants disperse. Natural hydrodynamics, expert Houdini water simulation stills, fine liquid filaments and realistic silvery specular highlights, consistent chronological motion. Thin translucent outer droplets and dense pale foam core. Not cartoon, not a fountain, not a cloud, not a grey smoke puff, no orange fire, no dirt.
Isolated splash ONLY: no sea background, no blue square, no ground plane, no horizon, no ships, no people, no UI, no grid lines, no numbers or labels, no checkerboard, no watermark. True alpha outside every splash. The sea will be rendered by the game underneath. 16 perfectly uniform cells, fixed framing and center, readable at small RTS scale.

## Smoke prompt

Use case: stylized-concept.
Asset type: production photorealistic smoke sprite atlas for a WWII RTS realtime particle system. Square canvas, maximum native resolution, exactly2columns x2rows equal squarecells, FOUR different isolated natural turbulent grey smoke billows, genuine transparent RGBA background.
Each quadrant contains one self-contained volumetric smoke puff with at least12% empty transparent margin on every edge. All four fit entirely inside their cells and never touch. Upper-left variation a broad irregular lateral smoke lobe; upper-right taller ascending curl; lower-left soft diffuse spreading dust-like cloud; lower-right dense asymmetric rolling billow. Realistic simulated fluid detail: folded cauliflower eddies at several scales, wispy eroded soft edges, translucent periphery, medium-grey internal light/shade, no pure black opaque blobs, no smooth white balls, no circular radial gradients. Lighting from upper-left, soft ambient fill, clearly readable volume. Neutral monochrome smoke, it will be tinted to brown earth dust, grey powder smoke, charcoal wreck smoke and pale water spray in engine. View from a camera45degrees above the horizon, naturally dimensional but not a raised diorama. No baked ground, scene, horizon, shadow plate, flames or embers, no text, numbering, grid lines or borders. Real alpha; do not paint checkerboards or background. Consistent texel scale and high-end cinematic pyro texture quality, not an illustration.
