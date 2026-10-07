// Reuse Vite's installed bundler; no browser, downloads or generated test files.
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { rolldown } from 'rolldown';

const input = fileURLToPath(new URL('./clouds.test.ts', import.meta.url));
const bundle = await rolldown({
  input, platform: 'node',
  plugins: [{
    name: 'shared-shader-raw',
    resolveId(source, importer) {
      if (source.endsWith('?raw') && importer) return resolve(dirname(importer), source.slice(0, -4)) + '?raw';
    },
    load(id) {
      if (id.endsWith('?raw')) return 'export default ' + JSON.stringify(readFileSync(id.slice(0, -4), 'utf8'));
    },
  }],
});
const { output } = await bundle.generate({ format: 'esm' });
await bundle.close();
const chunk = output.find((item) => item.type === 'chunk');
if (!chunk) throw new Error('No test bundle');
await import('data:text/javascript;base64,' + Buffer.from(chunk.code).toString('base64'));
