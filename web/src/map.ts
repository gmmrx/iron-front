// Harita: tek düzlem, bölge kimliği dokusundan (prov_8k: R düşük, G yüksek bayt) siyasi renk, deniz ve sınırlar.
// Bölge başına veri dokusu (256 × satır): R = kontrol eden ülke, G = tür. Ülke renkleri palet dokusunda (256 × 1).
import * as THREE from 'three';
import { World } from './world';

const vert = /* glsl */`
out vec2 vUv;
void main() {
  vUv = uv;
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
}`;

const frag = /* glsl */`
precision highp float;
precision highp int;
precision highp usampler2D;
in vec2 vUv;
out vec4 outColor;
uniform sampler2D provTex;
uniform sampler2D terrainTex;
uniform sampler2D dataTex;
uniform sampler2D paletteTex;
uniform sampler2D fogMask;
uniform int hovered;
uniform int selected;
uniform int player;

int pid(ivec2 p) {
  ivec2 sz = textureSize(provTex, 0);
  p = clamp(p, ivec2(0), sz - 1);
  vec4 c = texelFetch(provTex, p, 0);
  return int(round(c.r * 255.0)) + int(round(c.g * 255.0)) * 256;
}
vec4 pdata(int id) { return texelFetch(dataTex, ivec2(id % 256, id / 256), 0); }
int owner(int id) { return int(round(pdata(id).r * 255.0)); }

void main() {
  vec2 sz = vec2(textureSize(provTex, 0));
  vec2 tp = vUv * sz;
  ivec2 ip = ivec2(tp);
  int id = pid(ip);
  vec4 d = pdata(id);
  int kind = int(round(d.g * 255.0));
  int own = int(round(d.r * 255.0));
  vec3 ter = texture(terrainTex, vUv).rgb;
  vec3 col;
  // ekran pikseli başına doku pikseli: sınır kalınlığı zoom'dan bağımsız ~1 piksel
  float tpp = max(fwidth(tp.x), 1e-3);
  if (kind == 2 || kind == 3 || id == 0) {
    float depth = 0.5 + 0.5 * sin(tp.x * 0.004) * cos(tp.y * 0.006);
    col = mix(vec3(0.20, 0.36, 0.48), vec3(0.28, 0.46, 0.58), depth);
    col = mix(col, ter * vec3(0.55, 0.75, 0.95), 0.15);
  } else {
    vec3 cc = texelFetch(paletteTex, ivec2(own, 0), 0).rgb;
    float lum = dot(ter, vec3(0.299, 0.587, 0.114));
    col = mix(ter, cc * (0.55 + lum * 0.7), own > 0 ? 0.55 : 0.0);
    if (own == player) col *= 1.05;
  }
  // sınırlar: komşu doku piksellerinde kimlik farkı (bölge ince, ülke kalın)
  float off = max(1.0, tpp * 0.8);
  int edge_prov = 0;
  int edge_ctry = 0;
  for (int k = 0; k < 4; k++) {
    ivec2 o = k == 0 ? ivec2(1, 0) : k == 1 ? ivec2(-1, 0) : k == 2 ? ivec2(0, 1) : ivec2(0, -1);
    int nid = pid(ip + ivec2(vec2(o) * off));
    if (nid != id) {
      edge_prov = 1;
      vec4 nd = pdata(nid);
      if (int(round(nd.r * 255.0)) != own || int(round(nd.g * 255.0)) != kind) edge_ctry = 1;
    }
  }
  bool land = kind == 1;
  if (edge_ctry == 1) col = mix(col, vec3(0.06, 0.06, 0.07), land ? 0.85 : 0.45);
  else if (edge_prov == 1 && land) col = mix(col, vec3(0.1), clamp(0.55 - tpp * 0.25, 0.0, 0.4));
  if (id == hovered && land) col = mix(col, vec3(1.0, 0.95, 0.8), 0.18);
  if (id == selected) col = mix(col, vec3(1.0, 0.85, 0.4), 0.3);
  float unknown = texture(fogMask, vec2(vUv.x, 1.0 - vUv.y)).r;
  col = mix(col, vec3(0.53, 0.59, 0.64), smoothstep(0.05, 0.85, unknown) * 0.08);
  outColor = vec4(col, 1.0);
}`;

export class MapView {
  mesh: THREE.Mesh;
  mat: THREE.ShaderMaterial;
  dataTex: THREE.DataTexture;
  private data: Uint8Array;

  constructor(private world: World, provTex: THREE.Texture, terrainTex: THREE.Texture, player: number) {
    const n = world.kind.length;
    const rows = Math.ceil(n / 256);
    this.data = new Uint8Array(256 * rows * 4);
    for (let i = 0; i < n; i++) {
      this.data[i * 4] = world.controller[i];
      this.data[i * 4 + 1] = world.kind[i];
      this.data[i * 4 + 3] = 255;
    }
    this.dataTex = new THREE.DataTexture(this.data, 256, rows, THREE.RGBAFormat);
    this.dataTex.magFilter = this.dataTex.minFilter = THREE.NearestFilter;
    this.dataTex.needsUpdate = true;
    const pal = new Uint8Array(256 * 4);
    world.countries.forEach((c, i) => {
      if (!c) return;
      // ham sRGB değerleri (gölgelendirici renkleri olduğu gibi yazar; THREE.Color doğrusal uzaya çevirirdi)
      const v = parseInt(c.color.replace('#', '').slice(0, 6), 16);
      pal[i * 4] = (v >> 16) & 255; pal[i * 4 + 1] = (v >> 8) & 255; pal[i * 4 + 2] = v & 255; pal[i * 4 + 3] = 255;
    });
    const palTex = new THREE.DataTexture(pal, 256, 1, THREE.RGBAFormat);
    palTex.magFilter = palTex.minFilter = THREE.NearestFilter;
    palTex.needsUpdate = true;
    this.mat = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: vert, fragmentShader: frag,
      uniforms: {
        provTex: { value: provTex }, terrainTex: { value: terrainTex }, dataTex: { value: this.dataTex },
        paletteTex: { value: palTex }, hovered: { value: 0 }, selected: { value: 0 }, player: { value: player },
        fogMask: { value: null },
      },
    });
    const geo = new THREE.PlaneGeometry(world.w, world.h);
    geo.rotateX(-Math.PI / 2);
    this.mesh = new THREE.Mesh(geo, this.mat);
    this.mesh.position.set(world.w / 2, 0, world.h / 2);
  }

  setController(pid: number, owner: number): void {
    this.world.controller[pid] = owner;
    this.data[pid * 4] = owner;
    this.dataTex.needsUpdate = true;
  }
}
