// Iron Front web demo: map + persistent discovery + sparse atmospheric clouds + units + FPS.
import * as THREE from 'three';
import { MapControls } from 'three/examples/jsm/controls/MapControls.js';
import { World, LAND } from './world';
import { MapView } from './map';
import { Fog } from './fog';
import { AmbientClouds } from './ambient-clouds';
import { Units, Unit } from './units';

const SIDE_TAG = new URLSearchParams(location.search).get('side') ?? 'SOV';
const HOURS_PER_SECOND = 8;

async function loadTex(url: string, data: boolean): Promise<THREE.Texture> {
  const t = await new THREE.TextureLoader().loadAsync(url);
  if (data) {
    t.magFilter = t.minFilter = THREE.NearestFilter;
    t.generateMipmaps = false;
    t.colorSpace = THREE.NoColorSpace;
  } else {
    t.anisotropy = 8;
    t.colorSpace = THREE.NoColorSpace;      // gölgelendirici renkleri olduğu gibi (sRGB) yazar
  }
  return t;
}

// fareyle bölge bulmak için 4096 genişlikli kimlik dizisi
async function loadPick(url: string): Promise<{ ids: Uint16Array; w: number; h: number }> {
  const img = new Image();
  img.src = url;
  await img.decode();
  const c = document.createElement('canvas');
  c.width = img.width; c.height = img.height;
  const g = c.getContext('2d', { willReadFrequently: true })!;
  g.drawImage(img, 0, 0);
  const px = g.getImageData(0, 0, c.width, c.height).data;
  const ids = new Uint16Array(c.width * c.height);
  for (let i = 0; i < ids.length; i++) ids[i] = px[i * 4] | (px[i * 4 + 1] << 8);
  return { ids, w: c.width, h: c.height };
}

async function main(): Promise<void> {
  const [data, provTex, terrainTex, pick] = await Promise.all([
    fetch('/data/world.json').then((r) => r.json()),
    loadTex('/data/prov_8k.png', true),
    loadTex('/data/terrain_4k.jpg', false),
    loadPick('/data/prov_4k.png'),
  ]);
  const world = new World(data);
  const player = world.tagIndex(SIDE_TAG);
  const side = new Set<number>([player]);
  world.countries.forEach((c, i) => {
    if (c && i !== player) {
      // müttefik: oyuncuyla aynı düşmanlara karşı savaşan (demo için yeterli)
      let ally = false;
      for (let j = 1; j < world.countries.length; j++) if (world.atWar(player, j) && world.atWar(i, j)) ally = true;
      if (ally && !world.atWar(i, player)) side.add(i);
    }
  });

  const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(innerWidth, innerHeight);
  document.getElementById('app')!.appendChild(renderer.domElement);
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x0d1014);
  scene.add(new THREE.HemisphereLight(0xdde6ff, 0x3a3020, 1.6));
  const sun = new THREE.DirectionalLight(0xfff0d8, 2.2);
  sun.position.set(-0.6, 1.0, 0.4);
  scene.add(sun);

  const camera = new THREE.PerspectiveCamera(38, innerWidth / innerHeight, 0.5, 6000);
  const controls = new MapControls(camera, renderer.domElement);
  controls.mouseButtons = { LEFT: THREE.MOUSE.PAN, MIDDLE: THREE.MOUSE.ROTATE, RIGHT: null as unknown as THREE.MOUSE };
  controls.screenSpacePanning = false;
  controls.enableDamping = true;
  controls.minDistance = 8;
  controls.maxDistance = 5200 / 8; // Same regional zoom cap as Godot (web world units are 1:8).
  controls.maxPolarAngle = 1.15;
  controls.zoomToCursor = true;
  const fx = world.cx[world.cities.find((c) => c.n === 'Minsk')?.p ?? 1] || 1115;
  const fz = world.cz[world.cities.find((c) => c.n === 'Minsk')?.p ?? 1] || 307;
  controls.target.set(fx - 60, 0, fz);
  camera.position.set(fx - 60, 300, fz + 230);
  controls.update();

  const map = new MapView(world, provTex, terrainTex, player);
  scene.add(map.mesh);
  const fog = new Fog(world, provTex, side);
  map.mat.uniforms.fogMask.value = fog.mask.texture;
  const clouds = new AmbientClouds(world);
  scene.add(clouds.mesh);
  const units = new Units(world, map, fog, player, side);
  scene.add(units.base, units.body, units.ring);

  // şehir adları (zafer puanı 10+ ve başkentler): sabit ekran boyutlu yazı
  const labels: THREE.Sprite[] = [];
  for (const c of world.cities) {
    if (c.vp < 10 && !c.cap) continue;
    const cv = document.createElement('canvas');
    const g = cv.getContext('2d')!;
    g.font = 'bold 30px system-ui';
    cv.width = Math.ceil(g.measureText(c.n).width) + 16; cv.height = 40;
    g.font = 'bold 30px system-ui';
    g.lineWidth = 6; g.strokeStyle = 'rgba(0,0,0,0.8)'; g.fillStyle = c.cap ? '#f2d38a' : '#efe6d2';
    g.strokeText(c.n, 8, 30); g.fillText(c.n, 8, 30);
    const tex = new THREE.CanvasTexture(cv);
    tex.colorSpace = THREE.NoColorSpace;
    const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, depthTest: false, sizeAttenuation: false }));
    sp.scale.set(cv.width / cv.height * 0.026, 0.026, 1);
    sp.position.set(c.x / 8, 3, c.y / 8);
    sp.renderOrder = 20;
    sp.userData.cap = c.cap;
    labels.push(sp);
    scene.add(sp);
  }

  // ---------------------------------------------------------------- girdi
  const ray = new THREE.Raycaster();
  const ground = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
  const ndc = new THREE.Vector2();
  const hit = new THREE.Vector3();
  const provinceAt = (mx: number, my: number): { pid: number; x: number; z: number } => {
    ndc.set((mx / innerWidth) * 2 - 1, -(my / innerHeight) * 2 + 1);
    ray.setFromCamera(ndc, camera);
    if (!ray.ray.intersectPlane(ground, hit)) return { pid: 0, x: 0, z: 0 };
    const px = Math.floor((hit.x / world.w) * pick.w), py = Math.floor((hit.z / world.h) * pick.h);
    if (px < 0 || py < 0 || px >= pick.w || py >= pick.h) return { pid: 0, x: hit.x, z: hit.z };
    return { pid: pick.ids[py * pick.w + px], x: hit.x, z: hit.z };
  };
  let paused = false;
  let reconMode = false;
  let down = { x: 0, y: 0 };
  const sel = document.getElementById('sel')!;
  const tip = document.getElementById('tip')!;
  const showSel = (u: Unit | null) => {
    units.selected = u;
    sel.style.display = u ? 'block' : 'none';
    if (u) sel.textContent = `${world.countries[u.owner]?.name} · ${u.str.toFixed(1)} tümen · sağ tık: yürü / saldır`;
  };
  renderer.domElement.addEventListener('contextmenu', (e) => e.preventDefault());
  renderer.domElement.addEventListener('pointerdown', (e) => { down = { x: e.clientX, y: e.clientY }; });
  renderer.domElement.addEventListener('pointerup', (e) => {
    if (Math.hypot(e.clientX - down.x, e.clientY - down.y) > 5) return;      // sürükleme: kaydırma, tık değil
    if (e.button === 0) {
      if (reconMode) {
        const at = provinceAt(e.clientX, e.clientY);
        fog.recon(at.x, at.z, 18);
        reconMode = false;
        return;
      }
      showSel(units.pick(camera, e.clientX, e.clientY, innerWidth, innerHeight, true));
    } else if (e.button === 2 && units.selected) {
      const at = provinceAt(e.clientX, e.clientY);
      if (at.pid && world.kind[at.pid] === LAND) units.order(units.selected, at.pid);
    }
  });
  let hoverAt = { x: 0, y: 0 };
  renderer.domElement.addEventListener('pointermove', (e) => { hoverAt = { x: e.clientX, y: e.clientY }; });
  addEventListener('keydown', (e) => {
    if (e.code === 'Space') { paused = !paused; e.preventDefault(); }
    if (e.code === 'KeyK') reconMode = true;
    if (e.code === 'Escape') { reconMode = false; showSel(null); }
  });
  addEventListener('resize', () => {
    camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix();
    renderer.setSize(innerWidth, innerHeight);
  });

  // ---------------------------------------------------------------- ölçüm
  const frames: number[] = [];
  const fpsEl = document.getElementById('fps')!, p95El = document.getElementById('p95')!;
  const callsEl = document.getElementById('calls')!, unitsEl = document.getElementById('units')!;
  const clockEl = document.getElementById('clock')!;
  (window as any).__perf = { fps: 0, p95: 0, calls: 0, units: 0, frames: 0 };
  let lastUi = 0;

  // ---------------------------------------------------------------- döngü
  const start = new Date(world.date[0], world.date[1] - 1, world.date[2]);
  let gameHours = 0;
  let last = performance.now();
  const loop = (now: number) => {
    const dt = Math.min((now - last) / 1000, 0.1);
    frames.push(now - last);
    if (frames.length > 300) frames.shift();
    last = now;
    if (!paused) {
      const h = dt * HOURS_PER_SECOND;
      gameHours += h;
      units.tick(h);
    }
    controls.update();
    const hp = provinceAt(hoverAt.x, hoverAt.y).pid;
    map.mat.uniforms.hovered.value = hp;
    map.mat.uniforms.selected.value = units.selected ? units.selected.pid : 0;
    fog.update(renderer);
    units.draw(now / 1000);
    const dist = camera.position.distanceTo(controls.target);
    clouds.update(now / 1000, dist);
    for (const l of labels) l.visible = dist < (l.userData.cap ? 900 : 420);
    renderer.render(scene, camera);
    if (now - lastUi > 500) {
      lastUi = now;
      const sorted = [...frames].sort((a, b) => a - b);
      const p95 = sorted[Math.floor(sorted.length * 0.95)] ?? 0;
      const fps = Math.round(1000 / (frames.reduce((a, b) => a + b, 0) / frames.length));
      const info = renderer.info.render;
      fpsEl.textContent = String(fps); p95El.textContent = p95.toFixed(1);
      callsEl.textContent = String(info.calls); unitsEl.textContent = String(units.list.length);
      Object.assign((window as any).__perf, { fps, p95, calls: info.calls, units: units.list.length, frames: frames.length });
      const d = new Date(start.getTime() + gameHours * 3600_000);
      clockEl.textContent = `${d.toLocaleDateString('tr-TR', { day: 'numeric', month: 'long', year: 'numeric' })}${paused ? ' · duraklatıldı' : ''}` +
        `${reconMode ? ' · keşif: haritaya tıkla' : ''} · ele geçen bölge ${units.captured}`;
      const t = world.countries[world.controller[hp]];
      if (hp && world.kind[hp] === LAND) {
        tip.style.display = 'block';
        tip.style.left = `${hoverAt.x + 16}px`; tip.style.top = `${hoverAt.y + 16}px`;
        tip.textContent = fog.isExplored(hp) || side.has(world.controller[hp]) ? `${t?.name ?? '—'} · bölge ${hp}` : 'Bilgi yok (sis): keşif gerekir';
      } else tip.style.display = 'none';
    }
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
}

main();
