// Sparse atmosphere, not discovery. Static two-triangle world patches share Godot's silhouette.
import * as THREE from 'three';
import silhouette from '../../assets/shaders/ambient_clouds.gdshaderinc?raw';
import { World, SCALE } from './world';

export interface CloudPatch {
  x: number; z: number; y: number; width: number; depth: number; angle: number;
  shape: number; wind: number; opacity: number;
}

export const CLOUD_SEED = 19360901;
export const MAX_CLOUDS = 256;
const TAU = Math.PI * 2;

// Original map pixels throughout layout generation; Three.js uses the common 1:8 scale.
export function cloudLayout(width: number, height: number, seed = CLOUD_SEED): CloudPatch[] {
  if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) return [];
  const count = Math.min(MAX_CLOUDS, Math.max(1, Math.round(width * height / 650_000)));
  const minGap = Math.min(240, Math.min(width, height) * 0.18);
  let state = seed >>> 0;
  const random = () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let n = Math.imul(state ^ (state >>> 15), state | 1);
    n ^= n + Math.imul(n ^ (n >>> 7), n | 61);
    return ((n ^ (n >>> 14)) >>> 0) / 4294967296;
  };
  const patches: CloudPatch[] = [];
  for (let attempt = 0; patches.length < count && attempt < count * 60; attempt++) {
    const x = (0.015 + random() * 0.97) * width;
    const z = (0.015 + random() * 0.97) * height;
    if (patches.some((p) => (p.x - x) ** 2 + (p.z - z) ** 2 < minGap ** 2)) continue;
    const size = 160 + random() * 220;
    patches.push({
      x, z, y: 110 + random() * 62, width: size, depth: size * (0.45 + random() * 0.30),
      angle: random() * TAU, shape: random(), wind: random(), opacity: random(),
    });
  }
  return patches;
}

export function cloudAmount(distanceInMapPixels: number): number {
  const x = THREE.MathUtils.clamp((distanceInMapPixels - 260) / (650 - 260), 0, 1);
  return x * x * (3 - 2 * x) * 0.85;
}

const vertex = /* glsl */`
in vec3 cloudPatch;
out vec2 vCloudUv;
out vec3 vCloudWorld;
out vec3 vCloudPatch;
uniform float time;
void main() {
  vCloudUv = uv;
  vCloudPatch = cloudPatch;
  vec4 world = modelMatrix * instanceMatrix * vec4(position, 1.0);
  // Apply wind AFTER scaling: ten map pixels must not become ten cloud widths.
  world.x += sin(time * 0.015 + cloudPatch.y * 6.28) * (10.0 / 8.0);
  world.z += cos(time * 0.011 + cloudPatch.x * 6.28) * (5.0 / 8.0);
  vCloudWorld = world.xyz;
  gl_Position = projectionMatrix * viewMatrix * world;
}`;

const fragment = /* glsl */`
precision highp float;
in vec2 vCloudUv;
in vec3 vCloudWorld;
in vec3 vCloudPatch;
out vec4 outColor;
uniform float cloudAmount;
${silhouette}
void main() {
  float heightFade = smoothstep(5.0, 90.0, (cameraPosition.y - vCloudWorld.y) * 8.0);
  if (heightFade < 0.003 || cloudAmount < 0.003) discard;
  vec4 cloud = ambient_cloud(vCloudUv * 2.0 - 1.0, vCloudPatch.x);
  float alpha = cloud.a * (0.20 + vCloudPatch.z * 0.10) * cloudAmount * heightFade;
  if (alpha < 0.003) discard;
  outColor = vec4(cloud.rgb, alpha);
}`;

export class AmbientClouds {
  readonly patches: CloudPatch[];
  readonly mesh: THREE.InstancedMesh;
  readonly material: THREE.ShaderMaterial;

  constructor(world: World) {
    this.patches = cloudLayout(world.w * SCALE, world.h * SCALE);
    const geometry = new THREE.PlaneGeometry(1, 1);
    geometry.rotateX(-Math.PI / 2);
    const parameters = new Float32Array(this.patches.length * 3);
    this.patches.forEach((p, i) => parameters.set([p.shape, p.wind, p.opacity], i * 3));
    geometry.setAttribute('cloudPatch', new THREE.InstancedBufferAttribute(parameters, 3));
    this.material = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3, vertexShader: vertex, fragmentShader: fragment,
      transparent: true, depthWrite: false, depthTest: true, side: THREE.DoubleSide,
      forceSinglePass: true, // Flat soft cards need no transparent front/back double draw.
      uniforms: { time: { value: 0 }, cloudAmount: { value: 0 } },
    });
    this.mesh = new THREE.InstancedMesh(geometry, this.material, this.patches.length);
    this.mesh.name = 'Independent ambient cloud patches';
    this.mesh.renderOrder = 10;
    this.mesh.visible = false;
    const transform = new THREE.Matrix4();
    const rotation = new THREE.Quaternion();
    const up = new THREE.Vector3(0, 1, 0);
    for (let i = 0; i < this.patches.length; i++) {
      const p = this.patches[i];
      rotation.setFromAxisAngle(up, p.angle);
      transform.compose(new THREE.Vector3(p.x / SCALE, p.y / SCALE, p.z / SCALE), rotation,
        new THREE.Vector3(p.width / SCALE, 1, p.depth / SCALE));
      this.mesh.setMatrixAt(i, transform);
    }
    this.mesh.instanceMatrix.setUsage(THREE.StaticDrawUsage);
    this.mesh.instanceMatrix.needsUpdate = true;
    this.mesh.computeBoundingBox();
    this.mesh.computeBoundingSphere();
    // Bounded vertex wind needs a little extra culling room, not a world-sized box.
    this.mesh.boundingBox?.expandByScalar(24 / SCALE);
    if (this.mesh.boundingSphere) this.mesh.boundingSphere.radius += 24 / SCALE;
  }

  update(seconds: number, cameraDistance: number): void {
    const amount = cloudAmount(cameraDistance * SCALE);
    this.material.uniforms.time.value = seconds;
    this.material.uniforms.cloudAmount.value = amount;
    this.mesh.visible = amount > 0.003;
  }

  dispose(): void {
    this.mesh.geometry.dispose();
    this.material.dispose();
    this.mesh.dispose();
  }
}
