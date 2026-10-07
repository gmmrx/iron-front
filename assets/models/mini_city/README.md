# Compact city miniature assets

New low-profile WWII urban districts for the flat painted map. They replace the live single-building city marker; the disabled older large city layer is not reactivated. Old assets remain available.

Source: `tools/blender/build_mini_cities.py`. Editable Blender scene and honest asset renders are saved by that script. Runtime meshes: `city_{west,east,orient,nordic}_{0,1}.gltf` with shared textures. Each miniature has normalized width 1 and its ground at 0; actual bounds drive placement.

## Runtime integration

- `game/map/mini_city_models.gd` caches eight imported meshes. Architecture uses `City.style`; `City.id % 2` selects a stable layout. Every city can receive a miniature.
- `PinLayer` uses the existing near-zoom thresholds (capital 410, major 280, medium 210, other towns at their existing label range, capped at 300). The old large city/port/airbase layer stays disabled.
- Miniature widths are fixed world units by city importance: capital 4.0, major 3.5, city 3.0, town 2.6 and village 2.2. Camera distance, hover, focus and visibility do not rescale their geometry. Surface materials are preserved; there is no global material override.
- Model and hover use the same land-tested visual city center. The single normal cartographic label has a fixed nearby world anchor and constant screen typography; it does not switch to a boxed serif name at close zoom. Gameplay coordinates are unchanged. Ground contact and selection height come from the imported transformed bounds.
- Each district contains 14 buildings, narrow street ribbons and small courtyards, with no full ground plate. Geometry is 12,552–14,608 triangles and 5–6 material surfaces; imported Godot LODs remain intact. See `metrics.json`.
- Editable source and diagnostic renders have local `.gdignore` files, so they do not get imported or shipped as runtime city assets.

## Rebuild and verify

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/blender/build_mini_cities.py -- --render
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/run.gd -- --file=test_mini_city_assets
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/run.gd -- --file=test_map_pins
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/run.gd -- --file=test_map_label_stability
```

`tools/preview_mini_city_assets.gd` renders the actual imported meshes and materials. `tools/preview_mini_city_map.gd` captures actual city placement on the flat map, including a distant regional shot that checks the miniatures are hidden. Both can be run in Forward+ or with `--rendering-method gl_compatibility`; this is not a browser/WebGL performance benchmark.

`tools/preview_map_landmarks.gd` captures the actual city at camera distances 350, 150, 90 and 55, and checks that the world transform and text/font/color/anchor stay identical. It also captures the new strait scenery at two zoom levels and checks the same invariants. These scripts use the actual game's environment and sun.

## Material provenance

`textures/material_atlas.png` was generated with the built-in imagegen tool. It is a UV base-color atlas, not a rendered city or an image-to-3D reconstruction. The building geometry, roofs, windows, streets and details are authored in Blender.

`textures/material_atlas_normal.png` is a native tangent-space normal atlas baked in Blender from a mild material bump setup. It is used through standard glTF `normalTexture`, not a custom runtime shader. Deterministic building/roof tint and subtle base weathering are exported as `COLOR_0` vertex attributes; they add no material surfaces. There are no baked perspective pictures or painted scene shadows on the miniature.

Generation prompt:

> Production UV material atlas for miniature WWII city buildings. Square high-resolution PBR base color divided exactly into four equal quadrants without gaps or separator lines: top-left aged warm off-white lime plaster, top-right pale warm beige limestone masonry, bottom-left muted terracotta roof tile courses viewed perpendicular, bottom-right charcoal grey-blue slate roof courses. Restrained matte materials, even lighting, crisp fine detail. No buildings, windows, doors, perspective, scene, street, trees, text, logos, frame or watermark. Each quadrant intended to tile independently.

No claim that this asset alone establishes the complete game's AAA production quality; geometry, shading, map readability and renderer behavior are checked separately.
