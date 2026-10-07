import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import { World, SCALE } from '../src/world';
import { Fog } from '../src/fog';
import { AmbientClouds, cloudLayout, cloudAmount, CLOUD_SEED, MAX_CLOUDS } from '../src/ambient-clouds';

function world(): World {
  return new World({
    w: 16384, h: 8106,
    provinces: [null, [1, 500, 500, [2]], [1, 600, 500, [1, 3]], [1, 900, 500, [2]], [1, 1400, 500, []]],
    countries: [null, { tag: 'A', color: '#556644', name: 'A' }, { tag: 'B', color: '#995533', name: 'B' }],
    cities: [], scenario: { controller: [0, 1, 2, 2, 2], divisions: [], date: [1941, 6, 22], wars: [] },
  });
}

test('discovery remains persistent, allied territory and one neighbor start visible', () => {
  const fog = new Fog(world(), new THREE.Texture(), new Set([1]));
  assert.equal(fog.isExplored(1), true);
  assert.equal(fog.isExplored(2), true);
  assert.equal(fog.isExplored(3), false);
  assert.equal(fog.isExplored(4), false);
  fog.explore(3, false);
  assert.equal(fog.isExplored(3), true);
  fog.refreshTerritory();
  assert.equal(fog.isExplored(3), true, 'finishing reconnaissance does not erase discovery');
  assert.equal(fog.isExplored(4), false);
  fog.recon(1400 / SCALE, 500 / SCALE, 2);
  assert.equal(fog.isExplored(4), true);
  assert.equal('layers' in fog, false, 'no discovery-linked cloud actors');
  assert.equal('mats' in fog, false, 'no per-frame discovery cloud uniforms');
});

test('discovery target redraws once only when exploration changes', () => {
  const fog = new Fog(world(), new THREE.Texture(), new Set([1]));
  const previous = { previous: true };
  let target: unknown = previous;
  let renders = 0;
  const renderer = {
    getRenderTarget: () => target,
    setRenderTarget: (next: unknown) => { target = next; },
    render: () => { renders++; },
  } as unknown as THREE.WebGLRenderer;
  fog.update(renderer);
  assert.equal(renders, 1);
  assert.equal(target, previous, 'restore the main framebuffer');
  for (let frame = 0; frame < 50; frame++) fog.update(renderer);
  assert.equal(renders, 1, 'not a per-frame map pass');
  fog.explore(3, false);
  fog.update(renderer);
  assert.equal(renders, 2);
  fog.explore(3, false);
  fog.update(renderer);
  assert.equal(renders, 2, 'already-known provinces do not invalidate the mask');
  assert.deepEqual([fog.mask.width, fog.mask.height], [1024, 507]);
});

test('cloud patches are sparse, deterministic, unequal and not a tiled discovery pattern', () => {
  const patches = cloudLayout(16384, 8106);
  assert.deepEqual(patches, cloudLayout(16384, 8106, CLOUD_SEED));
  assert.notDeepEqual(patches, cloudLayout(16384, 8106, CLOUD_SEED + 1));
  assert.ok(patches.length >= 180 && patches.length <= MAX_CLOUDS);
  const widths = new Set<number>();
  let rectangleArea = 0;
  for (let i = 0; i < patches.length; i++) {
    const p = patches[i];
    assert.ok(p.x > 0 && p.x < 16384 && p.z > 0 && p.z < 8106);
    assert.ok(p.width >= 160 && p.width <= 380);
    assert.ok(p.depth / p.width >= 0.45 && p.depth / p.width <= 0.75);
    assert.ok(p.y >= 110 && p.y <= 172);
    widths.add(Math.round(p.width));
    rectangleArea += p.width * p.depth;
    for (let j = 0; j < i; j++) {
      assert.ok(Math.hypot(p.x - patches[j].x, p.z - patches[j].z) >= 240);
    }
  }
  assert.ok(widths.size > 80, 'many sizes, not repeated stamps');
  // The analytical billows occupy only part of these already sparse rectangles.
  assert.ok(rectangleArea / (16384 * 8106) < 0.09);
  assert.deepEqual(cloudLayout(0, 8106), []);
});

test('one static two-triangle batch, independent of discovery and without a raymarch or texture fetch', () => {
  const w = world();
  const clouds = new AmbientClouds(w);
  const fog = new Fog(w, new THREE.Texture(), new Set([1]));
  assert.equal(clouds.mesh.count, clouds.patches.length);
  assert.equal(clouds.mesh.geometry.index?.count, 6);
  assert.equal(clouds.mesh.geometry.getAttribute('position').count, 4);
  assert.equal(clouds.mesh.instanceMatrix.usage, THREE.StaticDrawUsage);
  assert.equal(clouds.material.depthTest, true);
  assert.equal(clouds.material.depthWrite, false);
  assert.equal(clouds.material.forceSinglePass, true, 'one draw, not two transparent face passes');
  assert.deepEqual(Object.keys(clouds.material.uniforms).sort(), ['cloudAmount', 'time']);
  assert.ok(clouds.material.fragmentShader.includes('vec4 ambient_cloud'));
  assert.ok(!/sampler|texture\s*\(|for\s*\(|maskTex|fog_density/.test(clouds.material.fragmentShader));
  const matrices = Array.from(clouds.mesh.instanceMatrix.array);
  const layout = JSON.stringify(clouds.patches);
  const version = clouds.mesh.instanceMatrix.version;
  for (const d of [55, 160, 420, 1600, 5200]) {
    clouds.update(45, d / SCALE);
    assert.ok(clouds.material.uniforms.cloudAmount.value <= 0.85);
  }
  fog.recon(1400 / SCALE, 500 / SCALE, 100);
  assert.deepEqual(Array.from(clouds.mesh.instanceMatrix.array), matrices);
  assert.equal(clouds.mesh.instanceMatrix.version, version, 'no per-frame transform upload');
  assert.equal(JSON.stringify(clouds.patches), layout, 'exploration cannot alter atmospheric cloud placement');
  assert.equal(cloudAmount(55), 0);
  assert.equal(cloudAmount(260), 0);
  assert.equal(cloudAmount(650), 0.85);
  clouds.update(60, 55 / SCALE);
  assert.equal(clouds.mesh.visible, false, 'near zoom does not draw transparent fullscreen geometry');
  assert.ok(clouds.material.fragmentShader.includes('smoothstep(5.0, 90.0'));
  assert.ok(clouds.material.vertexShader.includes('modelMatrix * instanceMatrix'));
  clouds.dispose();
});
