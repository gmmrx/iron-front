// Birlikler: bölge başına ülke başına tek pul (tümen sayısı = güç). Yürüyüş bölge merkezinden bölge merkezine; düşman
// bölgesine girerken sınırda durup çatışır (iki taraf karşılıklı güç kaybeder), boşalan bölgeye girer ve alır. Aynı ülkenin
// aynı bölgedeki pulları birleşir. Oyuncunun düşmanları basit bir yapay zekâyla ilerler. Çizim: iki InstancedMesh (taban +
// piyon), bulutun altındaki düşman pulu gizli.
import * as THREE from 'three';
import { World, LAND } from './world';
import { MapView } from './map';
import { Fog } from './fog';

export interface Unit {
  id: number; owner: number; pid: number; str: number;
  path: number[]; prog: number; x: number; z: number;
  fight: Unit | null; dead: boolean; aiWait: number;
}

const SPEED = 1.0;             // dünya birimi / oyun saati (piyade ~20 km/sa yol hızı, demo için hızlı)
const FIRE = 0.06;
const PAWN = 0.45;             // pul ölçeği (bölgeler ~5-10 birim: pul bölgenin içinde kalsın)             // oyun saati başına karşı tarafın gücünün bu kadarı kadar kayıp

export class Units {
  list: Unit[] = [];
  base: THREE.InstancedMesh;
  body: THREE.InstancedMesh;
  ring: THREE.Mesh;
  selected: Unit | null = null;
  private nextId = 1;
  private m = new THREE.Matrix4();
  private q = new THREE.Quaternion();
  private s = new THREE.Vector3();
  private p = new THREE.Vector3();
  captured = 0;

  constructor(private world: World, private map: MapView, private fog: Fog, private player: number, private side: Set<number>) {
    const by = new Map<string, Unit>();
    for (const [o, pid] of world.divisions) {
      const k = `${o}:${pid}`;
      let u = by.get(k);
      if (!u) {
        u = this.make(o, pid, 0);
        by.set(k, u);
      }
      u.str += 1;
    }
    const max = this.list.length + 400;
    const baseGeo = new THREE.CylinderGeometry(1.25, 1.35, 0.35, 20);
    baseGeo.translate(0, 0.175, 0);
    const pts = [[0, 0], [0.75, 0], [0.62, 0.25], [0.32, 0.55], [0.26, 1.2], [0.48, 1.35], [0.42, 1.55], [0.2, 1.62],
      [0.38, 1.85], [0.36, 2.15], [0.18, 2.36], [0, 2.4]].map(([x, y]) => new THREE.Vector2(x, y));
    const bodyGeo = new THREE.LatheGeometry(pts, 18);
    bodyGeo.translate(0, 0.35, 0);
    this.base = new THREE.InstancedMesh(baseGeo, new THREE.MeshStandardMaterial({ roughness: 0.6 }), max);
    this.body = new THREE.InstancedMesh(bodyGeo, new THREE.MeshStandardMaterial({ roughness: 0.45, metalness: 0.1 }), max);
    for (const im of [this.base, this.body]) { im.instanceMatrix.setUsage(THREE.DynamicDrawUsage); im.frustumCulled = false; }
    const ringGeo = new THREE.RingGeometry(1.5, 1.9, 32);
    ringGeo.rotateX(-Math.PI / 2);
    this.ring = new THREE.Mesh(ringGeo, new THREE.MeshBasicMaterial({ color: 0xffd060, transparent: true, opacity: 0.9 }));
    this.ring.visible = false;
    for (const u of this.list) this.fog.explore(u.pid, this.side.has(u.owner));
  }

  private make(owner: number, pid: number, str: number): Unit {
    const u: Unit = { id: this.nextId++, owner, pid, str, path: [], prog: 0, x: this.world.cx[pid], z: this.world.cz[pid],
      fight: null, dead: false, aiWait: Math.random() * 6 };
    this.list.push(u);
    return u;
  }

  hidden(u: Unit): boolean { return !this.side.has(u.owner) && !this.fog.isExplored(u.pid); }

  order(u: Unit, target: number): boolean {
    if (this.world.kind[target] !== LAND) return false;
    const path = this.world.path(u.pid, target);
    if (!path.length) return false;
    u.path = path; u.prog = 0; u.fight = null;
    return true;
  }

  // ekran noktasına en yakın oyuncu pulu (yalnız görünen pullar)
  pick(camera: THREE.Camera, mx: number, my: number, w: number, h: number, mine: boolean): Unit | null {
    let best: Unit | null = null, bd = 22 * 22;
    const v = new THREE.Vector3();
    for (const u of this.list) {
      if (u.dead || (mine && u.owner !== this.player) || this.hidden(u)) continue;
      v.set(u.x, 1.5, u.z).project(camera);
      const sx = (v.x * 0.5 + 0.5) * w, sy = (-v.y * 0.5 + 0.5) * h;
      const d = (sx - mx) ** 2 + (sy - my) ** 2;
      if (d < bd) { bd = d; best = u; }
    }
    return best;
  }

  private enemyIn(pid: number, owner: number): Unit | null {
    for (const u of this.list) if (!u.dead && u.pid === pid && u.path.length === 0 && this.world.atWar(u.owner, owner)) return u;
    return null;
  }

  // oyun saati ilerlet
  tick(hours: number): void {
    const w = this.world;
    for (const u of this.list) {
      if (u.dead) continue;
      if (u.fight) {
        const e = u.fight;
        if (e.dead) { u.fight = null; }
        else {
          const lossU = e.str * FIRE * hours, lossE = u.str * FIRE * hours * 0.8;   // savunan biraz avantajlı
          u.str -= lossU; e.str -= lossE;
          if (e.str <= 0.05) e.dead = true;
          if (u.str <= 0.05) { u.dead = true; continue; }
          if (!e.dead) continue;
          u.fight = null;
        }
      }
      if (!u.path.length) {
        if (!this.side.has(u.owner) && w.atWar(u.owner, this.player)) this.ai(u, hours);
        continue;
      }
      const next = u.path[0];
      const ax = w.cx[u.pid], az = w.cz[u.pid], bx = w.cx[next], bz = w.cz[next];
      const len = Math.hypot(bx - ax, bz - az) || 1;
      const was = u.prog;
      u.prog = Math.min(1, u.prog + (SPEED * hours) / len);
      // sınıra varınca: hedefte düşman pulu varsa çatış
      if (was < 0.5 && u.prog >= 0.5) {
        const e = this.enemyIn(next, u.owner);
        if (e) { u.prog = 0.5; u.fight = e; }
      }
      u.x = ax + (bx - ax) * u.prog; u.z = az + (bz - az) * u.prog;
      if (u.prog >= 1) {
        u.pid = next; u.path.shift(); u.prog = 0;
        if (w.atWar(w.controller[next], u.owner)) {
          this.map.setController(next, u.owner);
          this.captured++;
        }
        if (this.side.has(u.owner)) this.fog.explore(next, true);
        // aynı bölgede duran kendi pulu: birleş
        if (!u.path.length) {
          for (const o of this.list) {
            if (o !== u && !o.dead && o.owner === u.owner && o.pid === u.pid && !o.path.length) {
              o.str += u.str; u.dead = true;
              if (this.selected === u) this.selected = o;
              break;
            }
          }
        }
      }
    }
    if (this.list.some((u) => u.dead)) this.list = this.list.filter((u) => !u.dead);
  }

  // basit yapay zekâ: belli aralıklarla komşu düşman bölgesine saldır (en zayıfına)
  private ai(u: Unit, hours: number): void {
    u.aiWait -= hours;
    if (u.aiWait > 0) return;
    u.aiWait = 6 + Math.random() * 10;
    const w = this.world;
    let best = 0, bs = Infinity;
    for (const n of w.adj[u.pid]) {
      if (w.kind[n] !== LAND || !w.atWar(w.controller[n], u.owner)) continue;
      const e = this.enemyIn(n, u.owner);
      const s = e ? e.str : 0;
      if (s < bs && s < u.str * 1.5) { bs = s; best = n; }
    }
    if (best) { u.path = [best]; u.prog = 0; }
  }

  draw(t: number): void {
    const col = new THREE.Color();
    let i = 0;
    for (const u of this.list) {
      if (this.hidden(u)) continue;
      const k = (0.75 + 0.22 * Math.log2(1 + u.str)) * PAWN;
      const bob = u.fight ? Math.abs(Math.sin(t * 9 + u.id)) * 0.25 : 0;
      this.p.set(u.x, bob, u.z); this.s.set(k, k, k);
      this.m.compose(this.p, this.q, this.s);
      this.base.setMatrixAt(i, this.m); this.body.setMatrixAt(i, this.m);
      const c = this.world.countries[u.owner];
      col.set(c ? c.color : '#888');
      this.base.setColorAt(i, col.clone().multiplyScalar(0.55));
      this.body.setColorAt(i, col.lerp(new THREE.Color(1, 1, 1), 0.25));
      i++;
    }
    for (const im of [this.base, this.body]) {
      im.count = i;
      im.instanceMatrix.needsUpdate = true;
      if (im.instanceColor) im.instanceColor.needsUpdate = true;
    }
    const s = this.selected;
    this.ring.visible = !!s && !s.dead;
    if (s) { this.ring.position.set(s.x, 0.2, s.z); this.ring.scale.setScalar((0.75 + 0.22 * Math.log2(1 + s.str)) * PAWN); }
  }
}
