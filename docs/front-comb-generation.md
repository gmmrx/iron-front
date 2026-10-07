# Front comb texture

Current production version: [perpendicular v3](front-comb-perpendicular-v3.md). The historical notes below describe v2 and the intermediate analytical implementation.

Generated with the built-in ImageGen tool. Asset: `assets/ui/map/front_comb_v2.png`.
The generated stencil is preserved as a source asset, but is no longer loaded by the live frontier renderer. Its long raster teeth distorted at tight curves. The live frontier now uses short analytically filtered strokes on one static, curvature-limited mesh, without zoom LOD swaps or hover/combat extrusion.

## Prompt

Use case: stylized-concept. Asset type: production WWII grand strategy map frontline comb texture, single reusable alpha sprite for both opposed sides (engine tints and mirrors the same stencil). Create a high-resolution horizontal seamless repeating strip: a straight continuous narrow spine at the bottom edge, evenly spaced confident diagonal comb teeth extending upwards, open transparent space between teeth. The comb fills the width edge to edge and repeats seamlessly left/right. Neutral ivory-white ink only, very subtle engraved military cartographic ink grain within the strokes, crisp clean silhouettes, no heavy distress, no glow or shadows. Flat orthographic 2D game decal, not a physical comb, not barbed wire, not landscape, no mockup. The teeth have uniform length and weight and terminate cleanly. Make teeth substantial and readable from far away. Truly transparent background, no checkerboard baked into pixels, no text, symbols, border frame or labels. Landscape 4:1 composition. This sprite will be repeated along curving borders and mirrored into two facing sides, green-friendly versus red-hostile supplied by shader; do not bake colors.
