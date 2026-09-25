/**
 * Godot export: bakes each asset into ONE vertex-coloured mesh for GPU instancing.
 *  COLOR_0 rgb = material colour with cavity/edge shading, a = tint mask (uniform cloth / hull paint)
 *  TEXCOORD_0: x = part id + 0.5 (0 body, 1 left leg, 2 right leg), y = shade factor (for tinting)
 * Output: window.__glb[name] = base64 GLB.
 */
import * as THREE from 'three';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';
import { mergeGeometries, mergeVertices, toCreasedNormals } from 'three/addons/utils/BufferGeometryUtils.js';
import { MeshoptSimplifier } from 'meshoptimizer';
import { getModel, loadAssetByPath } from '../core/registry';
import { defaultConfig } from '../core/types';

declare global { interface Window { __ready?: boolean; __error?: string; __glb?: Record<string, string>; __stats?: unknown } }

const lum = (c: THREE.Color) => 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;

function tintable(name: string, isInfantry: boolean): boolean {
  if (isInfantry) return /^(wool|cotton)/.test(name);
  return /^(paint|castPaint)/.test(name);
}


let RENDERER: THREE.WebGLRenderer | null = null;
const RES = 1024;

/** Orijinal (tam shader'lı) modeli 14 yönden albedo olarak çizip her vertex'e görünür görünümlerden renk yansıtır. */
async function bakeColors(template: THREE.Object3D, geo: THREE.BufferGeometry, err: number): Promise<Float32Array> {
  if (!RENDERER) {
    RENDERER = new THREE.WebGLRenderer({ antialias: false });
    RENDERER.setPixelRatio(1);
    RENDERER.setSize(RES, RES);
    RENDERER.outputColorSpace = THREE.LinearSRGBColorSpace;
    RENDERER.toneMapping = THREE.NoToneMapping;
  }
  const r = RENDERER;
  const scene = new THREE.Scene();
  const model = template.clone();
  // yalnız ortam ışığı (π) -> çıktı = albedo; metaller difüz olarak alınsın
  model.traverse((o) => {
    const m = o as THREE.Mesh;
    if (!m.isMesh) return;
    const mats = (Array.isArray(m.material) ? m.material : [m.material]) as THREE.MeshStandardMaterial[];
    for (const mt of mats) {
      if ('metalness' in mt && mt.metalness > 0.5) { mt.metalness = 0; mt.color.multiplyScalar(0.85); }
      else if ('metalness' in mt) mt.metalness = 0;
    }
  });
  scene.add(model);
  scene.add(new THREE.AmbientLight(0xffffff, Math.PI));
  const box = new THREE.Box3().setFromObject(model);
  const sph = box.getBoundingSphere(new THREE.Sphere());
  const R = sph.radius * 1.02;
  const cam = new THREE.OrthographicCamera(-R, R, R, -R, 0.01, R * 4);
  const colRT = new THREE.WebGLRenderTarget(RES, RES, { type: THREE.FloatType });
  const depRT = new THREE.WebGLRenderTarget(RES, RES, { type: THREE.FloatType });
  const depthMat = new THREE.ShaderMaterial({
    vertexShader: 'varying float vd; void main(){ vec4 mv = modelViewMatrix * vec4(position,1.0); vd = -mv.z; gl_Position = projectionMatrix * mv; }',
    fragmentShader: 'varying float vd; void main(){ gl_FragColor = vec4(vd, 0.0, 0.0, 1.0); }',
    side: THREE.DoubleSide,
  });
  const dirs: THREE.Vector3[] = [];
  for (const [x, y, z] of [[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1],[1,1,1],[1,1,-1],[-1,1,1],[-1,1,-1],[1,-1,1],[1,-1,-1],[-1,-1,1],[-1,-1,-1]])
    dirs.push(new THREE.Vector3(x, y, z).normalize());
  const P = geo.attributes.position, N = geo.attributes.normal;
  const n = P.count;
  const acc = new Float32Array(n * 4);
  const col = new Float32Array(RES * RES * 4), dep = new Float32Array(RES * RES * 4);
  const v = new THREE.Vector3(), nv = new THREE.Vector3(), pv = new THREE.Vector3();
  for (const d of dirs) {
    cam.position.copy(sph.center).addScaledVector(d, R * 2);
    cam.up.set(0, 1, 0);
    if (Math.abs(d.y) > 0.99) cam.up.set(0, 0, 1);
    cam.lookAt(sph.center);
    cam.updateMatrixWorld(true);
    scene.background = new THREE.Color(0, 0, 0);
    scene.overrideMaterial = null;
    r.setRenderTarget(colRT); r.clear(); r.render(scene, cam);
    r.readRenderTargetPixels(colRT, 0, 0, RES, RES, col);
    scene.overrideMaterial = depthMat;
    scene.background = new THREE.Color(1e6, 0, 0);
    r.setRenderTarget(depRT); r.clear(); r.render(scene, cam);
    r.readRenderTargetPixels(depRT, 0, 0, RES, RES, dep);
    const viewDir = d.clone(); // kameraya doğru
    for (let i = 0; i < n; i++) {
      nv.fromBufferAttribute(N, i);
      const w = nv.dot(viewDir);
      if (w < 0.2) continue;
      v.fromBufferAttribute(P, i);
      pv.copy(v).applyMatrix4(cam.matrixWorldInverse);
      const vd = -pv.z;
      v.project(cam);
      const px = Math.floor((v.x * 0.5 + 0.5) * RES), py = Math.floor((v.y * 0.5 + 0.5) * RES);
      let sr = 0, sg = 0, sb = 0, sn = 0;
      for (let oy = -1; oy <= 1; oy++) for (let ox = -1; ox <= 1; ox++) {
        const x = px + ox, y = py + oy;
        if (x < 0 || y < 0 || x >= RES || y >= RES) continue;
        const k = (y * RES + x) * 4;
        if (Math.abs(dep[k] - vd) > 0.015 + err * 1.5 + R * 0.004) continue;   // örtülmüş
        sr += col[k]; sg += col[k + 1]; sb += col[k + 2]; sn++;
      }
      if (sn === 0) continue;
      const ww = w * w * sn / 9;
      acc[i * 4] += sr / sn * ww; acc[i * 4 + 1] += sg / sn * ww; acc[i * 4 + 2] += sb / sn * ww; acc[i * 4 + 3] += ww;
    }
  }
  r.setRenderTarget(null);
  colRT.dispose(); depRT.dispose();
  return acc;
}

type Item = [string, string, Record<string, unknown>, number?, number?];

async function exportOne(path: string, cfgOverride: Record<string, unknown>, err: number, minFeature: number) {
  await MeshoptSimplifier.ready;
  const def = await loadAssetByPath(path);
  const cfg0 = { ...defaultConfig(def), ...cfgOverride };
  const cfg = def.constrain ? def.constrain(cfg0).config : cfg0;
  const obj = await def.build(cfg, { detail: 'low' });
  obj.updateMatrixWorld(true);
  const inf = def.category === 'Infantry';
  const parts: THREE.BufferGeometry[] = [];
  let rawTris = 0, skipped = 0;
  const dbg: string[] = [];
  let o_name = '';
  const handle = (geo: THREE.BufferGeometry, mw: THREE.Matrix4, material: THREE.Material | THREE.Material[]) => {
    const mats = Array.isArray(material) ? material : [material];
    let g = geo.index ? geo : mergeVertices(geo);
    const groups = mats.length > 1 && g.groups.length ? g.groups : [{ start: 0, count: g.index!.count, materialIndex: 0 }];
    for (const gr of groups) {
      const mat = mats[gr.materialIndex ?? 0] as THREE.MeshStandardMaterial;
      if (!mat || !mat.visible || (mat.transparent && mat.opacity < 0.5)) continue;
      const P = g.attributes.position, C = g.attributes.color;
      // konumları dünya uzayına al, yalnız konuma göre kaynak (simplifier için)
      const map = new Map<string, number>();
      const pos: number[] = [], vcol: number[] = [];
      const idx = new Uint32Array(gr.count);
      const v = new THREE.Vector3();
      for (let i = 0; i < gr.count; i++) {
        const vi = g.index!.getX(gr.start + i);
        v.fromBufferAttribute(P, vi).applyMatrix4(mw);
        const key = `${Math.round(v.x * 1e4)},${Math.round(v.y * 1e4)},${Math.round(v.z * 1e4)}`;
        let ni = map.get(key);
        if (ni === undefined) {
          ni = pos.length / 3; map.set(key, ni); pos.push(v.x, v.y, v.z);
          vcol.push(C ? C.getX(vi) : 1, C ? C.getY(vi) : 1, C ? C.getZ(vi) : 1);
        }
        idx[i] = ni;
      }
      if (mw.determinant() < 0) for (let i = 0; i < idx.length; i += 3) { const t = idx[i + 1]; idx[i + 1] = idx[i + 2]; idx[i + 2] = t; }
      rawTris += gr.count / 3;
      const P32 = new Float32Array(pos);
      const box = new THREE.Box3().setFromArray(P32);
      const sz = box.getSize(new THREE.Vector3());
      if (Math.max(sz.x, sz.y, sz.z) < minFeature) { skipped++; continue; }
      const big = Math.max(sz.x, sz.y, sz.z) > minFeature * 4;
      let [simp] = MeshoptSimplifier.simplify(idx, P32, 3, 0, err, ['ErrorAbsolute', 'Prune']);
      let how = 'p';
      // büyük parçalar (gövde, levhalar) aşırı çökerse: kümeleme ile güvenli sadeleştirme, olmazsa ham
      if (err < 1e-5) { simp = idx; how = "raw"; }
      else if (big && simp.length < idx.length * 0.03) {
        [simp] = MeshoptSimplifier.simplifySloppy(idx, P32, 3, null, Math.min(idx.length, Math.max(Math.floor(idx.length * 0.06 / 3) * 3, 36)), 1e9);
        how = 's';
      }
      if (big && simp.length < 12) { simp = idx; how = 'raw'; }
      if (gr.count > 600) dbg.push(`${how}|${mat.name}|${gr.count / 3}->${simp.length / 3}|${sz.toArray().map((x) => x.toFixed(2))}`);
      if (simp.length < 3) { skipped++; continue; }
      const base = (mat.color ?? new THREE.Color(0.5, 0.5, 0.5)).clone();
      if ((mat.metalness ?? 0) > 0.5) base.multiplyScalar(0.8);
      const mask = tintable(mat.name ?? '', inf) ? 1 : 0;
      // düz (non-indexed) üçgenler -> kırışık normaller
      const n = simp.length;
      const fp = new Float32Array(n * 3), fc = new Float32Array(n * 4), fu = new Float32Array(n * 2);
      for (let i = 0; i < n; i++) {
        const k = simp[i];
        fp[i * 3] = P32[k * 3]; fp[i * 3 + 1] = P32[k * 3 + 1]; fp[i * 3 + 2] = P32[k * 3 + 2];
        fc[i * 4] = base.r * vcol[k * 3]; fc[i * 4 + 1] = base.g * vcol[k * 3 + 1]; fc[i * 4 + 2] = base.b * vcol[k * 3 + 2]; fc[i * 4 + 3] = mask;
      }
      // parça: piyade bacakları (kalça altı, yana göre; +X = kendi solu). Üçgen merkezine göre, kopmasın diye.
      for (let t = 0; t < n; t += 3) {
        const cx = (fp[t * 3] + fp[t * 3 + 3] + fp[t * 3 + 6]) / 3;
        const cy = (fp[t * 3 + 1] + fp[t * 3 + 4] + fp[t * 3 + 7]) / 3;
        const part = inf && cy < 0.84 && cy > 0.0 && Math.abs(cx) < 0.3 ? (cx >= 0 ? 1 : 2) : 0;
        for (let j = 0; j < 3; j++) { fu[(t + j) * 2] = part + 0.5; fu[(t + j) * 2 + 1] = 0.5; }
      }
      let pg = new THREE.BufferGeometry();
      pg.setAttribute('position', new THREE.BufferAttribute(fp, 3));
      pg.setAttribute('color', new THREE.BufferAttribute(fc, 4));
      pg.setAttribute('uv', new THREE.BufferAttribute(fu, 2));
      pg = toCreasedNormals(pg, 0.6);
      parts.push(pg);
    }
  };
  obj.traverse((o) => {
    const m = o as THREE.Mesh;
    if (!m.isMesh || !o.visible) return;
    for (let p = o.parent; p; p = p.parent) if (p.userData.noBake) return;
    o_name = o.name;
    const im = o as THREE.InstancedMesh;
    if (im.isInstancedMesh) {
      const t = new THREE.Matrix4();
      for (let i = 0; i < im.count; i++) { im.getMatrixAt(i, t); handle(m.geometry, m.matrixWorld.clone().multiply(t), m.material); }
    } else handle(m.geometry, m.matrixWorld, m.material);
  });
  const merged = mergeVertices(mergeGeometries(parts.map((p) => { const q = p.index ? p.toNonIndexed() : p; return q; }), false), 1e-5);
  const tris = merged.index!.count / 3;
  // gerçek boya (kamuflaj, işaretler, kenar aşınması): orijinal modelden renk aktarımı
  const built = await getModel(def, cfg, 'high');
  const acc = await bakeColors(built.template, merged, err);
  const C = merged.attributes.color as THREE.BufferAttribute;
  let miss = 0;
  for (let i = 0; i < C.count; i++) {
    const w = acc[i * 4 + 3];
    if (w > 1e-4) C.setXYZ(i, acc[i * 4] / w, acc[i * 4 + 1] / w, acc[i * 4 + 2] / w);
    else miss++;
  }
  C.needsUpdate = true;
  const mesh = new THREE.Mesh(merged, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.8 }));
  const box = new THREE.Box3().setFromBufferAttribute(merged.attributes.position as THREE.BufferAttribute);
  const ab = await new GLTFExporter().parseAsync(mesh, { binary: true }) as ArrayBuffer;
  let s = '';
  const b = new Uint8Array(ab);
  for (let i = 0; i < b.length; i += 0x8000) s += String.fromCharCode(...b.subarray(i, i + 0x8000));
  return { miss, dbg: [], glb: btoa(s), tris, rawTris, skipped, size: box.getSize(new THREE.Vector3()).toArray(), minY: box.min.y };
}

async function main() {
  const q = new URLSearchParams(location.search);
  const list: Item[] = JSON.parse(q.get('list') ?? '[]');
  window.__glb = {};
  const stats: Record<string, unknown> = {};
  for (const [name, path, cfg, err, minF] of list) {
    try {
      const r = await exportOne(path, cfg, err ?? 0.012, minF ?? 0.02);
      window.__glb[name] = r.glb;
      stats[name] = { miss: r.miss, tris: r.tris, raw: r.rawTris, skipped: r.skipped, dbg: r.dbg, size: r.size.map((x) => +x.toFixed(2)), minY: r.minY };
    } catch (e) {
      stats[name] = { error: String((e as Error)?.stack ?? e) };
    }
  }
  window.__stats = stats;
  window.__ready = true;
}
main().catch((e) => { window.__error = String(e?.stack ?? e); window.__ready = true; });
