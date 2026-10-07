"""Godot projesinin harita verisini tarayıcı demosu için hazırlar (web/public/data/).
- prov_8k.png / prov_4k.png: bölge kimliği R (düşük bayt) + G (yüksek bayt), A=255 (tarayıcı alfa çarpımı bozmasın)
- terrain_4k.jpg: arazi rengi
- world.json: bölgeler [id, tür, x, y, komşular], ülkeler, şehirler, senaryo (kontrol + tümenler)
Koordinatlar 16384 genişlikli harita pikseli; demo dünyası bunun 1/8'i (2048 birim)."""
import json, os
import numpy as np
from PIL import Image
Image.MAX_IMAGE_PIXELS = None
ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
OUT = os.path.join(os.path.dirname(__file__), '..', 'public', 'data')
os.makedirs(OUT, exist_ok=True)

im = Image.open(os.path.join(ROOT, 'data/map/provinces.png'))
la = np.asarray(im)                      # (h, w, 2): L düşük, A yüksek bayt
for step, name in [(2, 'prov_8k.png'), (4, 'prov_4k.png')]:
    sub = la[::step, ::step]
    rgba = np.zeros((sub.shape[0], sub.shape[1], 4), np.uint8)
    rgba[..., 0] = sub[..., 0]
    rgba[..., 1] = sub[..., 1]
    rgba[..., 3] = 255
    Image.fromarray(rgba, 'RGBA').save(os.path.join(OUT, name), optimize=True)
    print(name, rgba.shape)

t = Image.open(os.path.join(ROOT, 'data/map/terrain.png')).convert('RGB')
t = t.resize((4096, int(4096 * t.height / t.width)), Image.BILINEAR)
t.save(os.path.join(OUT, 'terrain_4k.jpg'), quality=85)
print('terrain', t.size)

P = json.load(open(os.path.join(ROOT, 'data/map/provinces.json')))
kinds = {'land': 1, 'sea': 2, 'lake': 3}
provs = [None] * (max(p['id'] for p in P['provinces']) + 1)
for p in P['provinces']:
    provs[p['id']] = [kinds.get(p['type'], 0), p['center'][0], p['center'][1], p.get('adj', [])]
C = json.load(open(os.path.join(ROOT, 'data/common/countries.json')))['countries']
countries = [None] + [{'tag': t, 'color': c['color'], 'name': c['name'].get('tr', t) if isinstance(c['name'], dict) else c['name']} for t, c in C.items()]
idx = {c['tag']: i for i, c in enumerate(countries) if c}
cities = [{'n': c['names'].get('tr', c['name']), 'x': c['pos'][0], 'y': c['pos'][1], 'vp': c['vp'], 'cap': c['capital'], 'p': c['province']}
          for c in json.load(open(os.path.join(ROOT, 'data/map/cities.json')))['cities'] if c['vp'] >= 3 or c['capital']]
S = json.load(open(os.path.join(ROOT, 'data/scenarios/east_1941.json')))
active = set(json.load(open(os.path.join(ROOT, 'data/common/participants.json')))['active'])
divs = [[idx[d['o']], d['p']] for d in S['divisions'] if d['o'] in active and d['o'] in idx]
world = {'w': P['width'], 'h': P['height'], 'provinces': provs, 'countries': countries, 'cities': cities,
         'scenario': {'date': S['date'], 'controller': S['controller'], 'divisions': divs, 'wars': S['wars']}}
json.dump(world, open(os.path.join(OUT, 'world.json'), 'w'), separators=(',', ':'))
print('world.json', len(provs), 'bölge', len(divs), 'tümen', len(cities), 'şehir')
