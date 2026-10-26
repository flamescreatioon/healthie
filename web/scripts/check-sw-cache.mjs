import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const swPath = path.resolve(__dirname, '..', 'public', 'sw.js');

if (!fs.existsSync(swPath)) {
  console.error('Service Worker check failed: public/sw.js does not exist.');
  process.exit(1);
}

const content = fs.readFileSync(swPath, 'utf8');

const requiredAssertions = [
  {
    name: 'CACHE_DENY_PREFIXES includes /api/',
    test: () => /CACHE_DENY_PREFIXES\s*=\s*\[[^\]]*['"]\/api\/['"]/.test(content),
  },
  {
    name: 'fetch handler enforces isDeniedFromCache(url.pathname)',
    test: () => content.includes('if (isDeniedFromCache(url.pathname))'),
  },
  {
    name: 'CACHE_ALLOW_LIST does not contain any /api/ route',
    test: () => {
      const match = content.match(/CACHE_ALLOW_LIST\s*=\s*\[([\s\S]*?)\]/);
      if (!match) return false;
      return !match[1].includes('/api/');
    },
  },
];

const failures = requiredAssertions.filter((a) => !a.test());

if (failures.length > 0) {
  console.error(
    'Service Worker cache audit failed:\n' +
      failures.map((f) => `  - ${f.name}`).join('\n')
  );
  process.exit(1);
}

console.log('Service Worker cache audit passed: /api/* health payloads are excluded from Cache Storage.');
