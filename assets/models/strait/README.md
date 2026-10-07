# Iron Front maritime miniatures

Four original, editable 3D models for the flat-map diorama. These are restrained
1930s/WWII-inspired game miniatures, not scale-exact historical reconstructions.

## Active map assets

The live strait layer is **bridge-only**. The truss span and stone end modules
are reused for every strait crossing with fixed world width and grounded ends.
The `little_belt_*` filenames identify the source kit, not a restriction to one
strait. `shore_terminal` and `steam_ferry` were rejected civilian studies and are
not loaded or placed by `StraitModels` / `StraitLayer`. Their editable source is
retained; fleet warship models are separate and unchanged.

| Asset | Triangles | Surfaces | Coordinate contract (Godot) |
| --- | ---: | ---: | --- |
| `shore_terminal` | 6,404 | 5 | X width 1, centred X/Z, base Y 0; +X pier/water, −X buildings/shore |
| `steam_ferry` | 11,986 | 8 | +X bow, X length 1, waterline Y 0, keel about −0.047 |
| `little_belt_span` | 11,376 | 4 | X 0→1, roadway Y 0, low through-truss, piers below |
| `little_belt_end` | 1,908 | 4 | X 0→1, roadway Y 0, stone abutment at the forward end |

Each glTF contains one joined mesh with identity node transform. Standard PBR,
UVs, native tangent attributes and native vertex colours are retained. Detailed
bounds and counts are recorded in `metrics.json`.

## Shared materials / provenance

The existing Iron Front mini-city albedo atlas and its genuine Blender-baked
tangent-space normal map are reused without modification. All glTF image URIs
point to `../mini_city/textures/`; there are no duplicate texture resources.
Additional hull, steel, rubber and paint materials are native PBR colours, not
perspective/shadow paintings or billboards. Geometry is authored in the Blender
script using the project's existing primitive helpers.

The terminal includes actual facade openings, lantern panes, wooden piles,
mooring bollards, rubber fenders and a pier ladder. The steam ferry has a curved
displacement hull, two cabin/deck levels, window openings, funnel, thin railing,
mast rigging, external stairs and geometrically modelled life rings. The bridge
uses real beam/web cross-sections, gussets, rivets and low stone supports.

## Rebuild and source

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python tools/blender/build_strait_assets.py -- --render
```

Run from the project root. Requires the existing mini-city atlas and normal map.
The editable library is `art/source/strait/library.blend`, with project-relative
texture paths. Honest daylight renders are under `art/previews/strait/`, including
`terminal_and_ferry.png`. Source and preview folders contain `.gdignore` files;
Godot imports only the runtime glTF assets, not Blender files or render images.
