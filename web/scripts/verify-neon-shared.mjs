import { neon } from '@neondatabase/serverless';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const envLocalPath = path.resolve(__dirname, '..', '.env.local');

function loadDatabaseUrl() {
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL;
  if (fs.existsSync(envLocalPath)) {
    const content = fs.readFileSync(envLocalPath, 'utf8');
    const match = content.match(/^DATABASE_URL="([^"]+)"/m);
    if (match?.[1]) return match[1];
  }
  throw new Error('DATABASE_URL not found in environment or .env.local');
}

async function main() {
  const databaseUrl = loadDatabaseUrl();
  const sql = neon(databaseUrl);

  const tables = await sql`
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
    ORDER BY table_name
  `;
  const tableNames = tables.map((r) => r.table_name);
  console.log('Connected to shared Neon DB! Public tables:', tableNames.join(', '));

  const requiredTables = [
    'users',
    'measurements',
    'workouts',
    'sleep_sessions',
    'meals',
    'personal_access_tokens',
    'sessions',
    'web_sessions',
    'profiles',
    'goals',
    'reminders',
    'medications',
    'medication_logs',
    'sync_cursors',
  ];

  for (const reqTable of requiredTables) {
    if (!tableNames.includes(reqTable)) {
      throw new Error(`Missing required shared table in Neon DB: ${reqTable}`);
    }
  }

  const rlsStatus = await sql`
    SELECT relname, relrowsecurity
    FROM pg_class
    WHERE relname IN ('measurements', 'profiles', 'goals', 'reminders', 'sync_cursors')
    ORDER BY relname
  `;
  console.log(
    'RLS status on health tables:',
    rlsStatus.map((r) => `${r.relname}: ${r.relrowsecurity ? 'ENABLED' : 'DISABLED'}`).join(', '),
  );

  console.log('Shared Neon DB verification succeeded for both Mobile (Laravel) and Web (Next.js)!');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
