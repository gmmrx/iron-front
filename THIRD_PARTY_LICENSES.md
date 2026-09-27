# Üçüncü taraf lisansları

## Muster – WWII Model Archive
Kara birimi ve uçak 3D modelleri (`assets/models/muster_units.glb`) Muster projesinden
dışa aktarılıp sadeleştirilmiştir: https://github.com/Kenton-GMI/muster-ww2

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
İdari bölgeler (admin-1, 10m), nehirler, göller, şehirler ve kabartma raster'ları (`HYP_50M_SR_W.tif`, `SR_50M.tif`)
harita üreticisinin girdisidir (`tools/fetch_data.py`, `tools/generate_map.py`). Natural Earth verisi kamu malıdır;
atıf zorunlu değildir ama önerilir: **Made with Natural Earth.** Kaynak: https://www.naturalearthdata.com/

## Yükseklik verisi (Terrain Tiles, Terrarium biçimi)
Harita yükseltisi AWS Open Data'daki Terrain Tiles karolarından üretilir (`tools/fetch_data.py`). Kaynak veri sağlayıcılarının
istediği atıf (https://github.com/tilezen/joerd/blob/master/docs/attribution.md):

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

## Bayraklar (Wikimedia Commons)
`assets/flags/*.svg` dosyaları Wikimedia Commons'tan indirilir (`tools/fetch_data.py --flags`); dosyası olmayan ülkelerin
bayrağı oyunda prosedürel çizilir. Ulusal bayrak çizimlerinin çoğu Commons'ta kamu malıdır, ama lisans dosyadan dosyaya
değişir. **Yayından önce her dosyanın Commons sayfasındaki lisansı tek tek doğrulanır** ve kamu malı olmayanlar için
yazar ve lisans buraya yazılır (ör. CC BY-SA: yazar adı + lisans + değişiklik notu).

| Etiket | Commons dosyası | Lisans (doğrulanacak) |
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

## Yazı tipleri (SIL Open Font License 1.1)
Lisans metni: `assets/fonts/OFL.txt`.

- **Barlow Condensed** (`assets/fonts/BarlowCondensed-*.ttf`) — Copyright 2017 The Barlow Project Authors
  (https://github.com/jpt/barlow)
- **Cinzel** (`assets/fonts/CinzelVariable.ttf`) — Copyright 2020 The Cinzel Project Authors
  (https://github.com/NDISCOVER/Cinzel)
