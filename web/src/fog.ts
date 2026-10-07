// Persistent discovery only. Atmospheric clouds are an independent map layer.
import * as THREE from 'three';
import { World, LAND } from './world';
import { maskVertex, maskFragment } from './cloud-volume';

export class Fog {
  explored: Uint8Array;
  tex: THREE.DataTexture;
  private data: Uint8Array;
  dirty = false;
  mask: THREE.WebGLRenderTarget;
  private maskScene = new THREE.Scene();
  private maskCamera = new THREE.Camera();

  constructor(private world: World, provTex: THREE.Texture, private side: Set<number>) {
    const n = world.kind.length;
    this.explored = new Uint8Array(n);
    const rows = Math.ceil(n / 256);
    this.data = new Uint8Array(256 * rows * 4);
    this.tex = new THREE.DataTexture(this.data, 256, rows, THREE.RGBAFormat);
    this.tex.magFilter = this.tex.minFilter = THREE.NearestFilter;
    this.tex.needsUpdate = true;
    this.mask = new THREE.WebGLRenderTarget(Math.ceil(world.w / 2), Math.ceil(world.h / 2), {
      minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter, depthBuffer: false,
    });
    const maskMat = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3, vertexShader: maskVertex, fragmentShader: maskFragment,
      depthTest: false, depthWrite: false,
      uniforms: { provTex: { value: provTex }, fogTex: { value: this.tex }, worldSize: { value: new THREE.Vector2(world.w, world.h) } },
    });
    this.maskScene.add(new THREE.Mesh(new THREE.PlaneGeometry(2, 2), maskMat));
    this.refreshTerritory();
    this.dirty = true;
  }

  // bölgeyi ve (around ise) komşularını keşfet
  explore(pid: number, around: boolean): void {
    const set = (p: number) => {
      if (p > 0 && !this.explored[p]) { this.explored[p] = 1; this.data[p * 4] = 255; this.dirty = true; }
    };
    set(pid);
    if (around) for (const q of this.world.adj[pid]) set(q);
  }

  // kendi tarafın kontrol ettiği bölgeler ve bir bölge ötesi (toprak alınınca yeniden çağrılır)
  refreshTerritory(): void {
    const c = this.world.controller;
    for (let i = 1; i < c.length; i++) if (this.side.has(c[i]) && this.world.kind[i] === LAND) this.explore(i, true);
  }

  // keşif uçuşu: merkezden r birim içindeki bölgeler
  recon(x: number, z: number, r: number): void {
    const w = this.world;
    for (let i = 1; i < w.kind.length; i++) {
      if (!w.kind[i]) continue;
      const dx = w.cx[i] - x, dz = w.cz[i] - z;
      if (dx * dx + dz * dz < r * r) this.explore(i, false);
    }
  }

  isExplored(pid: number): boolean { return this.explored[pid] === 1; }

  update(renderer: THREE.WebGLRenderer): void {
    if (this.dirty) {
      this.tex.needsUpdate = true;
      const previous = renderer.getRenderTarget();
      renderer.setRenderTarget(this.mask);
      renderer.render(this.maskScene, this.maskCamera);
      renderer.setRenderTarget(previous);
      this.dirty = false;
    }
  }
}
