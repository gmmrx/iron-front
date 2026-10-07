# Perpendicular frontline stencil — 2026-10-06

Mode: built-in ImageGen, transparent generation using the user's HOI4 screenshot as style reference, not as a source to copy map/UI pixels from.

Asset: `assets/ui/map/front_comb_perpendicular_v3.png` (2172 × 724, original alpha preserved).

Production: `front_ink.gdshader` samples the band at source rows 303–418, repeats 23 perpendicular teeth, and tints it mint at 70% opacity. Mipmaps and unwrapped texture gradients filter distant views. One fixed curvature-limited mesh is retained across zoom/hover/combat changes. No diagonal shear, gold spine, animation, shadow or camera-dependent widening. The stencil is above terrain by 0.06 world units, below units, rather than physically hidden underneath terrain.

## Final prompt

Use case: stylized-concept. Asset type: a production transparent frontline decal texture for a WWII grand strategy game. Image 1 is STYLE REFERENCE ONLY, especially its pale turquoise comb-shaped front lines; do not reproduce its map or UI. Generate ONE straight horizontal comb strip, pure white ink on actual transparency, intended to be tinted by the game. A substantial perfectly straight horizontal spine with evenly spaced SHORT, WIDE, RECTANGULAR teeth extending PERPENDICULARLY downward at precisely 90 degrees, ONLY on one side. No diagonal teeth, no taper, no triangles, no arrows. Tooth length about 3 times spine thickness; tooth width approximately spine thickness; space between teeth about tooth width. Flat military cartographic ink with almost imperceptible worn ink texture inside solid strokes; clean edges, consistent spacing and weight. Full strip spans from left edge to right edge, seamlessly repeatable horizontally; teeth and spine lie in one plane. Wide landscape 3:1 canvas, a single large strip centered vertically, transparent background and transparent gaps. Orthographic front-on 2D sprite, no 3D extrusion, no perspective, no shadow, no glow, no lettering, no map, no unit counters, no ornamental details, no border around canvas. This is an actual engine texture, not a mockup.
