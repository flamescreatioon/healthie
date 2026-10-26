import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');

function walkFiles(dir, extList = ['.ts', '.tsx']) {
  const results = [];
  if (!fs.existsSync(dir)) return results;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walkFiles(fullPath, extList));
    } else if (extList.includes(path.extname(entry.name))) {
      results.push(fullPath);
    }
  }
  return results;
}

let violations = [];

// 1. Domain layer purity check (docs/web/02-architecture-and-domain.md)
const domainDir = path.join(rootDir, 'src', 'domain');
const forbiddenInDomain = [
  /from\s+['"]react/,
  /from\s+['"]next/,
  /from\s+['"]dexie/,
  /from\s+['"]@neondatabase\/serverless/,
  /from\s+['"]drizzle-orm/,
  /from\s+['"]@\/data/,
  /from\s+['"]@\/server/,
  /from\s+['"]@\/components/,
  /\bfetch\s*\(/,
  /\bwindow\./,
  /\bdocument\./,
];

for (const file of walkFiles(domainDir)) {
  const content = fs.readFileSync(file, 'utf8');
  for (const pattern of forbiddenInDomain) {
    if (pattern.test(content)) {
      violations.push(
        `Domain purity violation in ${path.relative(rootDir, file)}: matched ${pattern}`
      );
    }
  }
}

// 2. Client components must never import Neon, Drizzle, or server modules
const clientDirs = [
  path.join(rootDir, 'src', 'components'),
  path.join(rootDir, 'src', 'data'),
  path.join(rootDir, 'src', 'app'),
];

const forbiddenInClient = [
  /from\s+['"]@neondatabase\/serverless/,
  /from\s+['"]drizzle-orm/,
  /from\s+['"]@\/server/,
];

for (const dir of clientDirs) {
  for (const file of walkFiles(dir)) {
    const rel = path.relative(rootDir, file).replace(/\\/g, '/');
    // Skip API Route Handlers which run on the server
    if (rel.startsWith('src/app/api/')) continue;

    const content = fs.readFileSync(file, 'utf8');
    for (const pattern of forbiddenInClient) {
      if (pattern.test(content)) {
        violations.push(
          `Client/server boundary violation in ${rel}: matched ${pattern}`
        );
      }
    }
  }
}

if (violations.length > 0) {
  console.error('Layering check failed:\n' + violations.map((v) => `  - ${v}`).join('\n'));
  process.exit(1);
}

console.log('Layering check passed: src/domain is 100% pure and client/server boundaries are intact.');
