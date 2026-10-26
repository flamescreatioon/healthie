import Link from 'next/link';
import { ShieldCheck, Lock, Database, Download, Trash2, HeartPulse } from 'lucide-react';
import { AppCard } from '@/components/ui/primitives';

export default function PrivacyPolicyPage() {
  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <div>
        <span className="inline-flex items-center gap-1.5 rounded-full bg-indigo-50 px-3 py-1 text-xs font-semibold text-indigo-700 dark:bg-indigo-950/60 dark:text-indigo-300">
          <ShieldCheck className="h-3.5 w-3.5" aria-hidden="true" />
          Privacy &amp; Clinical Safety Policy
        </span>
        <h1 className="mt-2 text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100">
          Healthie Privacy Policy &amp; Data Stewardship
        </h1>
        <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">
          Effective Date: October 2026 &middot; Applies to Healthie Web &amp; Mobile
        </p>
      </div>

      <AppCard className="space-y-3 border-l-4 border-l-amber-500">
        <div className="flex items-center gap-2 font-semibold text-slate-900 dark:text-slate-100">
          <HeartPulse className="h-5 w-5 text-amber-600" aria-hidden="true" />
          <h2>Medical Disclaimer</h2>
        </div>
        <p className="text-sm text-slate-600 dark:text-slate-300">
          Healthie is an informational personal health log and self-tracking companion. It is{' '}
          <strong>not a medical device</strong> and does not diagnose, treat, cure, or prevent any
          disease. Blood pressure classifications follow the published AHA/ACC 2017 High Blood
          Pressure Clinical Practice Guideline for educational awareness only. Never change or
          discontinue medication without consulting a qualified clinician. If you experience chest
          pain, shortness of breath, neurological symptoms, or blood pressure above 180/120 mmHg,
          contact emergency services immediately.
        </p>
      </AppCard>

      <AppCard className="space-y-4">
        <div className="flex items-center gap-2 font-semibold text-slate-900 dark:text-slate-100">
          <Database className="h-5 w-5 text-indigo-600" aria-hidden="true" />
          <h2>1. Local-First Storage by Default</h2>
        </div>
        <p className="text-sm text-slate-600 dark:text-slate-300">
          By default, every measurement, goal, reminder, and profile setting you record in Healthie
          Web is stored locally inside your browser&apos;s IndexedDB database (via Dexie). You can
          use all core logging, trending, analytics, and export features without creating an account
          or transmitting health data over the network.
        </p>
        <ul className="list-disc space-y-1.5 pl-5 text-sm text-slate-600 dark:text-slate-300">
          <li>
            <strong>No third-party ad or analytics trackers:</strong> Healthie includes zero ad
            pixels, session replay scripts, or third-party behavioral analytics.
          </li>
          <li>
            <strong>No health values in URLs or logs:</strong> Measurement values are never placed
            in query strings, URL paths, or application console/server logs.
          </li>
          <li>
            <strong>Service Worker Cache isolation:</strong> Our Progressive Web App Service Worker
            caches only static application shell assets. All <code>/api/*</code> responses are
            explicitly excluded from browser Cache Storage.
          </li>
        </ul>
      </AppCard>

      <AppCard className="space-y-4">
        <div className="flex items-center gap-2 font-semibold text-slate-900 dark:text-slate-100">
          <Lock className="h-5 w-5 text-indigo-600" aria-hidden="true" />
          <h2>2. Opt-In Cloud Sync &amp; Neon Postgres Processor</h2>
        </div>
        <p className="text-sm text-slate-600 dark:text-slate-300">
          If you explicitly create an account and enable Cloud Sync in{' '}
          <Link href="/profile" className="font-semibold text-indigo-600 underline">
            Profile &amp; Settings
          </Link>
          , your measurements, profile, goals, and reminders are synchronized with our cloud
          database so you can back up and access your records across devices.
        </p>
        <ul className="list-disc space-y-1.5 pl-5 text-sm text-slate-600 dark:text-slate-300">
          <li>
            <strong>Cloud Database Processor:</strong> Cloud-synced data is stored in{' '}
            <strong>Neon</strong> (serverless PostgreSQL) over TLS-encrypted connections with
            AES-256 encryption at rest.
          </li>
          <li>
            <strong>Strict Per-User Isolation:</strong> Every query enforces both application-layer{' '}
            <code>user_id</code> filtering and PostgreSQL Row-Level Security (RLS) policies scoped
            to your authenticated session.
          </li>
          <li>
            <strong>Authentication Security:</strong> Web sessions use first-party{' '}
            <code>HttpOnly</code>, <code>Secure</code>, <code>SameSite=Lax</code> cookies. Auth
            tokens are never stored in <code>localStorage</code>.
          </li>
          <li>
            <strong>Branch Hygiene:</strong> Production data is never copied into preview or
            development Neon branches without synthetic anonymization, and ephemeral preview
            branches are automatically expired.
          </li>
        </ul>
      </AppCard>

      <AppCard className="space-y-4">
        <div className="flex items-center gap-2 font-semibold text-slate-900 dark:text-slate-100">
          <Download className="h-5 w-5 text-indigo-600" aria-hidden="true" />
          <h2>3. Full Data Portability (Offline JSON &amp; CSV Export)</h2>
        </div>
        <p className="text-sm text-slate-600 dark:text-slate-300">
          Your health data belongs to you. At any time—even while offline—you can export a complete,
          human-readable copy of your measurements, profile, goals, and reminders in structured JSON
          (<code>schemaVersion: 1</code>) or spreadsheet-ready CSV format from the{' '}
          <Link href="/profile" className="font-semibold text-indigo-600 underline">
            Profile
          </Link>{' '}
          or{' '}
          <Link href="/history" className="font-semibold text-indigo-600 underline">
            History
          </Link>{' '}
          screens.
        </p>
      </AppCard>

      <AppCard className="space-y-4">
        <div className="flex items-center gap-2 font-semibold text-slate-900 dark:text-slate-100">
          <Trash2 className="h-5 w-5 text-rose-600" aria-hidden="true" />
          <h2>4. Right to Erasure &amp; Account Deletion</h2>
        </div>
        <p className="text-sm text-slate-600 dark:text-slate-300">
          You can permanently erase your local IndexedDB store (&ldquo;Clear Local Device
          Data&rdquo;) or permanently delete your cloud account (&ldquo;Delete Account &amp;
          Data&rdquo;) directly from{' '}
          <Link href="/profile" className="font-semibold text-indigo-600 underline">
            Profile &amp; Settings
          </Link>
          . Cloud account deletion cascades across all measurements, goals, reminders, profile
          records, sync cursors, and active sessions in Neon Postgres immediately.
        </p>
      </AppCard>
    </div>
  );
}
