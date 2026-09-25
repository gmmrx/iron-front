# Muster → Godot birim modelleri

Kaynak: https://github.com/Kenton-GMI/muster-ww2 (MIT, © Kenton-GMI). Modeller three.js ile prosedürel üretilir.

Boru hattı:
1. Muster reposunu klonla, `npm install && npm install meshoptimizer`.
2. `export.ts` → `src/harness/export.ts`, `export_godot.mjs` → `scripts/`, `harness.html` kopyasını
   `export.html` olarak `/src/harness/export.ts` betiğine yönlendir.
3. `npx vite --port 5199` açıkken: `node scripts/export_godot.mjs models.json out`
   - küçük parçalar atılır, her parça meshoptimizer ile sadeleşir,
   - renkler orijinal shader'lı modelden 14 yönlü projeksiyonla vertex rengine aktarılır (kamuflaj, işaretler),
   - vertex A = ülke rengi maskesi (piyade kumaşı), UV.x = parça (1/2 = bacaklar → yürüme animasyonu).
4. `blender -b -P tools/blender/decimate_units.py -- out assets/models/muster_units.glb ad=üçgen ...`
   (piyade 2500, top 3000, araç/uçak 5000).
