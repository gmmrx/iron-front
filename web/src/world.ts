// Dünya verisi (tools/prepare.py üretir): bölgeler, ülkeler, şehirler, senaryonun kontrol ve tümen durumu.
// Koordinatlar: kaynak harita 16384 piksel; demo dünyası bunun 1/SCALE'i (x yatay, z dikey).

export const SCALE = 8;
export const LAND = 1, SEA = 2, LAKE = 3;

export interface Country { tag: string; color: string; name: string }
export interface City { n: string; x: number; y: number; vp: number; cap: boolean; p: number }

export class World {
  w = 0; h = 0;                       // dünya birimi
  kind: Uint8Array;                   // bölge türü
  cx: Float32Array; cz: Float32Array; // bölge merkezi (dünya birimi)
  adj: number[][];
  controller: Uint8Array;             // bölge -> ülke indeksi (0 yok)
  countries: (Country | null)[];
  cities: City[];
  enemies = new Set<string>();        // "a:b" savaşta olan ülke indeks çiftleri
  divisions: [number, number][];      // [ülke, bölge]
  date: number[];

  constructor(d: any) {
    this.w = d.w / SCALE; this.h = d.h / SCALE;
    const n = d.provinces.length;
    this.kind = new Uint8Array(n); this.cx = new Float32Array(n); this.cz = new Float32Array(n);
    this.adj = new Array(n);
    for (let i = 0; i < n; i++) {
      const p = d.provinces[i];
      if (!p) { this.adj[i] = []; continue; }
      this.kind[i] = p[0]; this.cx[i] = p[1] / SCALE; this.cz[i] = p[2] / SCALE; this.adj[i] = p[3];
    }
    this.controller = new Uint8Array(n);
    const ctl: number[] = d.scenario.controller;
    for (let i = 0; i < Math.min(n, ctl.length); i++) this.controller[i] = ctl[i];
    this.countries = d.countries;
    this.cities = d.cities;
    this.divisions = d.scenario.divisions;
    this.date = d.scenario.date;
    const idx = new Map<string, number>();
    this.countries.forEach((c, i) => { if (c) idx.set(c.tag, i); });
    for (const w of d.scenario.wars) {
      for (const a of w.attackers) for (const b of w.defenders) {
        const ia = idx.get(a), ib = idx.get(b);
        if (ia && ib) { this.enemies.add(`${ia}:${ib}`); this.enemies.add(`${ib}:${ia}`); }
      }
    }
  }

  tagIndex(tag: string): number { return this.countries.findIndex((c) => c?.tag === tag); }
  atWar(a: number, b: number): boolean { return this.enemies.has(`${a}:${b}`); }

  // kara üstünden en kısa bölge yolu (genişlik öncelikli); bulunamazsa []
  path(from: number, to: number): number[] {
    if (from === to) return [];
    const prev = new Int32Array(this.kind.length).fill(-1);
    prev[from] = from;
    const q = [from];
    for (let qi = 0; qi < q.length; qi++) {
      const c = q[qi];
      for (const n of this.adj[c]) {
        if (prev[n] !== -1 || this.kind[n] !== LAND) continue;
        prev[n] = c;
        if (n === to) {
          const out = [n];
          for (let p = c; p !== from; p = prev[p]) out.push(p);
          return out.reverse();
        }
        q.push(n);
      }
    }
    return [];
  }
}
