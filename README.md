**English** · [Türkçe](README.tr.md)

# Iron Front (working title)

A World War II grand strategy game made with Godot 4.7. **Play in the browser:** https://gmmrx.github.io/iron-front/
(desktop Chrome/Firefox, downloads ~370 MB; republished by GitHub Actions on every push)

**Game wiki (how to play, mechanics, countries):** [docs/wiki](docs/wiki/README.md) · Roadmap: [ROADMAP.md](ROADMAP.md) ·
Trailer: [docs/media/iron_front_demo_2026-09-25.mp4](docs/media/iron_front_demo_2026-09-25.mp4) (clips: `docs/media/clips/`)

The game's main language is English; Turkish can be chosen in **Settings → Language** (main menu, or Esc in the game).

## Running
Open the project with Godot 4.7 and press F5. Or:
```
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## Controls
| Key / mouse | Action |
|---|---|
| WASD / arrow keys / screen edge, middle-drag, trackpad scroll | Camera |
| Wheel / pinch | Zoom |
| Left click | Select a state/region or a division counter (Shift: add) |
| Left drag | Box-select divisions |
| Right click | Move / attack order for the selected divisions (nothing selected: clear the selection) |
| Hold Ctrl / Ctrl + click | A country's overall situation / that country's politics screen (read-only) |
| Space · 1–5 · + / - | Pause · game speed |
| Q / F / I / O / R / T / Y / U | Politics / State program / Research / Diplomacy / Trade / Construction / Production / Army |
| N / H / L | Navy / Air / Logistics |
| F1 F2 F3 F4 | Political / Terrain / State / Routes map |
| Home | Back to the capital |
| Esc | Clear the selection → close panels → menu (save/load/settings) |
| F5 | Quick save |

## How to play (short)
1. Pick your country → choose a state program in the **Program (F)** tree and technologies in **Research (I)**.
2. **Construction (T)**: build factories. **Production (Y)**: assign military factories to equipment. **Army (U)**: deploy
   divisions, form armies and give each a general and a front.
3. Click a country → **Diplomacy**: prepare a casus belli (30 days), declare war.
4. Select divisions (click / drag) and right-click to send them into enemy regions. Take cities with victory points; when
   the enemy surrenders, the states you occupy become yours.
5. The game ends on 1 January 1948 (or when you surrender).

## Tests / development
```
Godot --headless --path . -s game/dev/sim.gd -- --days=1500            # AI world, historical flow + profile
Godot --headless --path . -s game/dev/playtest.gd                      # player flow + save/load test
Godot --path . -- --play=TUR --days=400 --panel=army --screenshot=o.png
```
More in the [developer notes](docs/wiki/08_developer.md).

## Regenerating the map
```
pip install numpy scipy pillow
python3 tools/fetch_data.py     # downloads the source data into tools/cache/ (once)
python3 tools/generate_map.py   # ~80 s
```
Source data (`tools/cache/`, not in git):
- `ne_10m_admin_1.geojson` — github.com/nvkelso/natural-earth-vector (geojson/ne_10m_admin_1_states_provinces.geojson)
- `HYP_50M_SR_W.tif`, `SR_50M.tif` — naciscdn.org/naturalearth/50m/raster/

The 1936 borders are defined by the `ADM0_OWNER` and `REGION_OWNER` tables in `tools/generate_map.py`.

## Developer arguments
```
Godot --path . -- --play=TUR --screenshot=out.png --focus=1800,1800 --dist=600 --select=1500 --mode=1 --run
Godot --path . -- --setup          # straight to country selection
# video (Godot movie maker; the window must stay on top, otherwise covered frames are not drawn):
Godot --path . --always-on-top --write-movie out.avi --fixed-fps 30 -- --play=DEN --war=GER,DEN --focus_battle=200 --speed=1 --film=4.5 --dolly=230,105
#   --film=sec  [--dolly=far,near] [--pan=dx,dz] [--track] [--hide_ui]; scenes: --focus_air, --focus_fleet=sea --track, --army=POL --army_mode=attack, --panel=focus
```

## Assets (Blender)
```
python3 tools/blender/make_textures.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/blender/build_assets.py -- --render /tmp/renders
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/blender/build_buildings.py -- --render /tmp/buildings --save-blend tools/blender/scenes/city_asset_library.blend
```
