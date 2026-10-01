// Deterministic periodic scalar field shared by both renderers.
import { mkdirSync, writeFileSync } from 'node:fs';
const size = 64;
const hash = (x, y, z) => {
  let n = Math.imul(x, 73856093) ^ Math.imul(y, 19349663) ^ Math.imul(z, 83492791) ^ 1941;
  n = Math.imul(n ^ (n >>> 16), 0x45d9f3b);
  return ((n ^ (n >>> 16)) >>> 0) / 4294967295;
};
const smooth = t => t * t * (3 - 2 * t);
function noise(x, y, z, period) {
  const ix = Math.floor(x), iy = Math.floor(y), iz = Math.floor(z);
  const f = [smooth(x - ix), smooth(y - iy), smooth(z - iz)];
  let v = 0;
  for (let dz = 0; dz < 2; dz++) for (let dy = 0; dy < 2; dy++) for (let dx = 0; dx < 2; dx++) {
    v += hash((ix + dx) % period, (iy + dy) % period, (iz + dz) % period)
      * (dx ? f[0] : 1 - f[0]) * (dy ? f[1] : 1 - f[1]) * (dz ? f[2] : 1 - f[2]);
  }
  return v;
}
const data = new Uint8Array(size ** 3);
for (let z = 0; z < size; z++) for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
  let v = 0, weight = 0;
  for (let o = 0; o < 4; o++) {
    const period = 4 << o, a = 2 ** -o;
    v += noise(x / size * period, y / size * period, z / size * period, period) * a;
    weight += a;
  }
  data[x + size * (y + size * z)] = Math.round(v / weight * 255);
}
mkdirSync('assets/textures', { recursive: true });
writeFileSync('assets/textures/fog_noise_64.bin', data);
console.log(`Cloud volume: ${data.length} bytes; 64³, seed 1941`);
