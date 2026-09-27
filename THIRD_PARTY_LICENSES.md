**English** · [Türkçe](THIRD_PARTY_LICENSES.tr.md)

# Third-party licences

## Muster – WWII Model Archive
The land unit and aircraft 3D models (`assets/models/muster_units.glb`) were exported from the Muster project and
simplified: https://github.com/Kenton-GMI/muster-ww2

```
MIT License

Copyright (c) 2026 Kenton Wang

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Natural Earth
Administrative regions (admin-1, 10m), rivers, lakes, cities and the relief rasters (`HYP_50M_SR_W.tif`, `SR_50M.tif`)
are inputs of the map generator (`tools/fetch_data.py`, `tools/generate_map.py`). Natural Earth data is in the public
domain; attribution is not required but recommended: **Made with Natural Earth.** Source: https://www.naturalearthdata.com/

## Elevation data (Terrain Tiles, Terrarium format)
The map elevation is built from the Terrain Tiles on AWS Open Data (`tools/fetch_data.py`). Attribution required by the
source data providers (https://github.com/tilezen/joerd/blob/master/docs/attribution.md):

- Mapzen
- ArcticDEM terrain data DEM(s) were created from DigitalGlobe, Inc., imagery and funded under National Science Foundation
  awards 1043681, 1559691, and 1542736
- Australia terrain data © Commonwealth of Australia (Geoscience Australia) 2017
- Austria terrain data © offene Daten Österreichs – Digitales Geländemodell (DGM) Österreich
- Canada terrain data contains information licensed under the Open Government Licence – Canada
- Europe terrain data produced using Copernicus data and information funded by the European Union - EU-DEM layers
- Global ETOPO1 terrain data U.S. National Oceanic and Atmospheric Administration
- Mexico terrain data source: INEGI, Continental relief, 2016
- New Zealand terrain data Copyright 2011 Crown copyright (c) Land Information New Zealand and the New Zealand Government
  (All rights reserved)
- Norway terrain data © Kartverket
- United Kingdom terrain data © Environment Agency copyright and/or database right 2015. All rights reserved
- United States 3DEP (formerly NED) and global GMTED2010 and SRTM terrain data courtesy of the U.S. Geological Survey

## Flags (Wikimedia Commons)
The `assets/flags/*.svg` files are downloaded from Wikimedia Commons (`tools/fetch_data.py --flags`); the flag of a
country without a file is drawn procedurally in the game. Most national flag drawings on Commons are in the public domain,
but the licence varies from file to file. **Before release the licence on each file's Commons page is verified one by
one**, and for those not in the public domain the author and licence are written here (e.g. CC BY-SA: author name +
licence + note of changes).

| Tag | Commons file | Licence (to be verified) |
|---|---|---|
| TUR | File:Flag_of_Turkey.svg | ☐ |
| ENG | File:Flag_of_the_United_Kingdom.svg | ☐ |
| ITA | File:Flag_of_Italy_(1861-1946)_crowned.svg | ☐ |
| SOV | File:Flag_of_the_Soviet_Union_(1936-1955).svg | ☐ |
| SPR | File:Flag_of_the_Second_Spanish_Republic.svg | ☐ |
| POR | File:Flag_of_Portugal.svg | ☐ |
| ROM | File:Flag_of_Romania.svg | ☐ |
| HUN | File:Flag_of_Hungary_(1920-1946).svg | ☐ |
| CZE | File:Flag_of_the_Czech_Republic.svg | ☐ |
| AUS | File:Flag_of_Austria.svg | ☐ |
| BUL | File:Flag_of_Bulgaria.svg | ☐ |
| ALB | File:Flag_of_Albania_(1934-1939).svg | ☐ |
| NOR | File:Flag_of_Norway.svg | ☐ |
| FIN | File:Flag_of_Finland.svg | ☐ |
| HOL | File:Flag_of_the_Netherlands.svg | ☐ |
| LUX | File:Flag_of_Luxembourg.svg | ☐ |
| SWI | File:Flag_of_Switzerland.svg | ☐ |
| IRE | File:Flag_of_Ireland.svg | ☐ |
| ICE | File:Flag_of_Iceland.svg | ☐ |
| IRQ | File:Flag_of_Iraq_(1924-1959).svg | ☐ |
| SAU | File:Flag_of_Saudi_Arabia_(1934-1938).svg | ☐ |

## Fonts (SIL Open Font License 1.1)
Licence text: `assets/fonts/OFL.txt`.

- **Barlow Condensed** (`assets/fonts/BarlowCondensed-*.ttf`) — Copyright 2017 The Barlow Project Authors
  (https://github.com/jpt/barlow)
- **Cinzel** (`assets/fonts/CinzelVariable.ttf`) — Copyright 2020 The Cinzel Project Authors
  (https://github.com/NDISCOVER/Cinzel)

## Germany 1936 leader portrait (`assets/portraits/GER.png`)
Photo: Heinrich Hoffmann, Adolf Hitler at the Berghof, 1936; Bundesarchiv, Bild 146-1990-048-29A.
Source: https://commons.wikimedia.org/wiki/File:Adolf_Hitler_Berghof-1936.jpg
Licence: [CC BY-SA 3.0 DE](https://creativecommons.org/licenses/by-sa/3.0/de/deed.en).
Cropped and scaled to 400×500 pixels for the game portrait; the source photo was left black and white.
The modified image is distributed under CC BY-SA 3.0 DE; the source and licence notice for this asset must be kept here.

## Historical commander portraits (`assets/portraits/commanders/`)

Per-image source page, credited author, and licence are recorded in
[`assets/portraits/commanders/SOURCES.csv`](assets/portraits/commanders/SOURCES.csv).
The portraits are archival images from Wikimedia Commons and remain under the
licences stated in that manifest. Keep the manifest with the assets; apply any
share-alike terms to modified portraits. Entries marked “AI-generated” are
illustrative reconstructions, not authentic historical photographs; the source
atlas for each set is kept beside the cropped portraits.
