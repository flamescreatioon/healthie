'use client';

/**
 * Profile, Units, Targets, Reminders, and Opt-In Neon Cloud Sync Screen
 * (`lib/features/profile/presentation/profile_screen.dart`,
 * `docs/web/04-auth-sync.md`, & `docs/web/08-privacy-compliance.md`).
 */

import React, { useState } from 'react';
import Link from 'next/link';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import {
  Bell,
  Cloud,
  LogOut,
  Plus,
  RefreshCw,
  ShieldCheck,
  Trash2,
  UserCheck,
} from 'lucide-react';
import { useAppContext, useRepositories } from '@/components/providers/app-providers';
import {
  AppCard,
  SectionHeader,
  SegmentedControl,
  StatusPill,
} from '@/components/ui/primitives';

export function ProfileView() {
  const queryClient = useQueryClient();
  const { profile: profileRepo, reminders: reminderRepo, clock } =
    useRepositories();
  const {
    user,
    setUser,
    syncEnabled,
    toggleSyncOptIn,
    triggerSync,
    syncState,
    lastSyncedAt,
    pendingOutboxCount,
  } = useAppContext();

  const { data: profile } = useQuery({
    queryKey: ['profile'],
    queryFn: () => profileRepo.getProfile(),
  });

  const { data: reminders = [] } = useQuery({
    queryKey: ['reminders'],
    queryFn: () => reminderRepo.listReminders(),
  });

  const [displayNameInput, setDisplayNameInput] = useState('');
  const [authMode, setAuthMode] = useState<'login' | 'register'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [authError, setAuthError] = useState<string | null>(null);
  const [authMessage, setAuthMessage] = useState<string | null>(null);

  const handleSaveName = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!profile) return;
    await profileRepo.saveProfile({
      ...profile,
      displayName: displayNameInput.trim() || profile.displayName || null,
      updatedAt: clock.now().toISOString(),
    });
    await queryClient.invalidateQueries({ queryKey: ['profile'] });
  };

  const handleMassUnitChange = async (unit: 'kg' | 'lb') => {
    if (!profile) return;
    await profileRepo.saveProfile({
      ...profile,
      preferredMassUnit: unit,
      updatedAt: clock.now().toISOString(),
    });
    await queryClient.invalidateQueries({ queryKey: ['profile'] });
  };

  const handleSeedReminders = async () => {
    await reminderRepo.seedDefaults(clock.now().toISOString());
    await queryClient.invalidateQueries({ queryKey: ['reminders'] });
  };

  const handleToggleReminder = async (id: string, enabled: boolean) => {
    const found = reminders.find((r) => r.id === id);
    if (!found) return;
    await reminderRepo.saveReminder({
      ...found,
      enabled,
      updatedAt: clock.now().toISOString(),
    });
    await queryClient.invalidateQueries({ queryKey: ['reminders'] });
  };

  const handleDeleteReminder = async (id: string) => {
    await reminderRepo.deleteReminder(id);
    await queryClient.invalidateQueries({ queryKey: ['reminders'] });
  };

  const handleAuthSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setAuthError(null);
    setAuthMessage(null);

    const endpoint =
      authMode === 'register' ? '/api/auth/register' : '/api/auth/login';
    try {
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          email,
          password,
          displayName: profile?.displayName ?? undefined,
        }),
      });
      const data = (await res.json()) as {
        user?: { id: string; email: string; displayName: string | null };
        message?: string;
      };
      if (!res.ok || !data.user) {
        setAuthError(data.message ?? 'Authentication failed.');
        return;
      }
      setUser(data.user);
      setPassword('');
      setAuthMessage(
        authMode === 'register'
          ? 'Account created on Neon Postgres.'
          : 'Signed in with cookie session.',
      );
    } catch {
      setAuthError('Network unavailable. Local data remains safe on this device.');
    }
  };

  const handleSignOut = async () => {
    try {
      await fetch('/api/auth/logout', {
        method: 'POST',
        credentials: 'include',
      });
    } finally {
      setUser(null);
      setAuthMessage(
        'Signed out. Your local IndexedDB health records remain intact on this device.',
      );
    }
  };

  const handleDeleteCloudAccount = async () => {
    const res = await fetch('/api/auth/delete-account', {
      method: 'DELETE',
      credentials: 'include',
    });
    if (res.ok) {
      setUser(null);
      await toggleSyncOptIn(false);
      setAuthMessage(
        'Cloud account and all Neon Postgres records permanently deleted.',
      );
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="type-headline m-0">Profile &amp; Settings</h1>
        <p
          className="m-0 mt-1 text-xs"
          style={{ color: 'var(--color-on-surface-variant)' }}
        >
          Manage your preferred units, reminders, and opt-in Neon Postgres cloud
          sync.
        </p>
      </div>

      {/* Identity & Display Name */}
      <AppCard className="space-y-4">
        <SectionHeader
          title="Profile"
          subtitle="Only fill in what you want to use. Stored locally first."
        />
        <form onSubmit={handleSaveName} className="flex flex-wrap gap-3">
          <div className="flex-1 min-w-[220px]">
            <label htmlFor="profile-name-input" className="sr-only">
              Preferred name
            </label>
            <input
              id="profile-name-input"
              type="text"
              placeholder={profile?.displayName ?? 'What should we call you?'}
              value={displayNameInput}
              onChange={(e) => setDisplayNameInput(e.target.value)}
              style={{
                backgroundColor: 'var(--color-surface-low)',
                border: '1px solid var(--color-outline-variant)',
                borderRadius: 'var(--radius-control)',
                color: 'var(--color-on-surface)',
              }}
              className="touch-target w-full px-3.5 py-2 text-sm"
            />
          </div>
          <button
            type="submit"
            style={{
              backgroundColor: 'var(--color-primary)',
              color: 'var(--color-on-primary)',
              borderRadius: 'var(--radius-control)',
            }}
            className="touch-target cursor-pointer px-5 py-2 text-xs font-semibold"
          >
            Save name
          </button>
        </form>
      </AppCard>

      {/* Preferred Units */}
      <AppCard className="space-y-4">
        <SectionHeader
          title="Units"
          subtitle="Values are stored in canonical metric units and converted at the boundary."
        />
        <div className="max-w-xs">
          <div
            className="type-label mb-1.5"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            Body Mass Unit
          </div>
          <SegmentedControl
            options={['kg', 'lb'] as const}
            selected={profile?.preferredMassUnit ?? 'kg'}
            onChange={(u) => void handleMassUnitChange(u)}
            ariaLabel="Preferred mass unit"
          />
        </div>
      </AppCard>

      {/* Reminders */}
      <AppCard className="space-y-4">
        <SectionHeader
          title="Reminders"
          subtitle="Reminders power Today's Protocol checklist on your dashboard."
        />
        {reminders.length === 0 ? (
          <p
            className="m-0 text-xs"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            No reminders set up yet.
          </p>
        ) : (
          <div className="divide-y divide-[var(--color-outline-variant)]">
            {reminders.map((rem) => (
              <div
                key={rem.id}
                className="flex items-center justify-between py-2.5 text-sm"
              >
                <div className="flex items-center gap-3">
                  <input
                    type="checkbox"
                    checked={rem.enabled}
                    aria-label={`Toggle ${rem.title}`}
                    onChange={(e) =>
                      void handleToggleReminder(rem.id, e.target.checked)
                    }
                    className="h-4 w-4 cursor-pointer"
                  />
                  <div>
                    <div className="font-semibold">{rem.title}</div>
                    <div
                      className="text-xs tabular-nums"
                      style={{ color: 'var(--color-on-surface-variant)' }}
                    >
                      {String(rem.hour).padStart(2, '0')}:
                      {String(rem.minute).padStart(2, '0')}
                    </div>
                  </div>
                </div>
                <button
                  type="button"
                  aria-label={`Delete ${rem.title}`}
                  onClick={() => void handleDeleteReminder(rem.id)}
                  style={{ color: 'var(--color-error)' }}
                  className="cursor-pointer p-1.5"
                >
                  <Trash2 size={16} />
                </button>
              </div>
            ))}
          </div>
        )}
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() => void handleSeedReminders()}
            style={{
              border: '1px solid var(--color-outline-variant)',
              color: 'var(--color-primary)',
              borderRadius: 'var(--radius-control)',
            }}
            className="touch-target inline-flex cursor-pointer items-center gap-2 px-4 py-2 text-xs font-semibold"
          >
            <Bell size={15} aria-hidden="true" />
            <span>Add default BP &amp; Weight reminders</span>
          </button>
        </div>
      </AppCard>

      {/* Neon Cloud Sync & Cookie-Session Auth (`docs/web/04-auth-sync.md`) */}
      <AppCard className="space-y-4">
        <div className="flex items-start justify-between gap-3">
          <SectionHeader
            title="Opt-In Cloud Sync (Neon Postgres)"
            subtitle="Sync is off by default. Opting out keeps all local IndexedDB records on your device."
          />
          <StatusPill
            label={
              syncEnabled
                ? `Sync ${syncState} (${pendingOutboxCount} queued)`
                : 'Local-only'
            }
            tone={syncEnabled ? 'primary' : 'neutral'}
            dense
          />
        </div>

        <div className="flex items-center justify-between gap-4 rounded-xl p-3.5" style={{ backgroundColor: 'var(--color-surface-low)' }}>
          <div>
            <label
              htmlFor="sync-opt-in-toggle"
              className="text-sm font-semibold block"
            >
              Enable Neon Cloud Sync
            </label>
            <span
              className="text-xs"
              style={{ color: 'var(--color-on-surface-variant)' }}
            >
              Replicates outbox changes via first-party Next.js Route Handlers
              with per-user RLS isolation.
            </span>
          </div>
          <input
            id="sync-opt-in-toggle"
            type="checkbox"
            checked={syncEnabled}
            onChange={(e) => void toggleSyncOptIn(e.target.checked)}
            className="h-5 w-5 cursor-pointer"
          />
        </div>

        {user ? (
          <div className="space-y-3">
            <div
              style={{
                backgroundColor: 'var(--color-surface-low)',
                borderRadius: 'var(--radius-control)',
              }}
              className="flex flex-wrap items-center justify-between gap-3 p-3.5 text-xs"
            >
              <div className="flex items-center gap-2">
                <UserCheck
                  size={16}
                  style={{ color: 'var(--color-positive)' }}
                />
                <span>
                  Signed in as <strong>{user.email}</strong>
                </span>
              </div>
              {lastSyncedAt && (
                <span style={{ color: 'var(--color-on-surface-variant)' }}>
                  Last synced: {new Date(lastSyncedAt).toLocaleTimeString()}
                </span>
              )}
            </div>

            <div className="flex flex-wrap gap-2">
              <button
                type="button"
                onClick={() => void triggerSync({ force: true })}
                style={{
                  backgroundColor: 'var(--color-primary)',
                  color: 'var(--color-on-primary)',
                  borderRadius: 'var(--radius-control)',
                }}
                className="touch-target inline-flex cursor-pointer items-center gap-1.5 px-4 py-2 text-xs font-semibold"
              >
                <RefreshCw size={14} aria-hidden="true" />
                <span>Sync now</span>
              </button>
              <button
                type="button"
                onClick={() => void handleSignOut()}
                style={{
                  border: '1px solid var(--color-outline-variant)',
                  color: 'var(--color-on-surface)',
                  borderRadius: 'var(--radius-control)',
                }}
                className="touch-target inline-flex cursor-pointer items-center gap-1.5 px-4 py-2 text-xs font-semibold"
              >
                <LogOut size={14} aria-hidden="true" />
                <span>Sign out (keep local data)</span>
              </button>
              <button
                type="button"
                onClick={() => void handleDeleteCloudAccount()}
                style={{
                  backgroundColor: 'var(--color-error-container)',
                  color: 'var(--color-on-error-container)',
                  borderRadius: 'var(--radius-control)',
                }}
                className="touch-target inline-flex cursor-pointer items-center gap-1.5 px-4 py-2 text-xs font-semibold"
              >
                <Trash2 size={14} aria-hidden="true" />
                <span>Delete Neon cloud account</span>
              </button>
            </div>
          </div>
        ) : (
          <form onSubmit={handleAuthSubmit} className="space-y-3">
            <div className="max-w-xs">
              <SegmentedControl
                options={['login', 'register'] as const}
                selected={authMode}
                onChange={setAuthMode}
                ariaLabel="Authentication mode"
                labelBuilder={(m) =>
                  m === 'login' ? 'Sign In' : 'Create Account'
                }
              />
            </div>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div>
                <label
                  htmlFor="auth-email-input"
                  className="type-label block mb-1"
                  style={{ color: 'var(--color-on-surface-variant)' }}
                >
                  Email
                </label>
                <input
                  id="auth-email-input"
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  style={{
                    backgroundColor: 'var(--color-surface-low)',
                    border: '1px solid var(--color-outline-variant)',
                    borderRadius: 'var(--radius-control)',
                    color: 'var(--color-on-surface)',
                  }}
                  className="touch-target w-full px-3.5 py-2 text-sm"
                />
              </div>
              <div>
                <label
                  htmlFor="auth-password-input"
                  className="type-label block mb-1"
                  style={{ color: 'var(--color-on-surface-variant)' }}
                >
                  Password (min 8 chars)
                </label>
                <input
                  id="auth-password-input"
                  type="password"
                  required
                  minLength={8}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  style={{
                    backgroundColor: 'var(--color-surface-low)',
                    border: '1px solid var(--color-outline-variant)',
                    borderRadius: 'var(--radius-control)',
                    color: 'var(--color-on-surface)',
                  }}
                  className="touch-target w-full px-3.5 py-2 text-sm"
                />
              </div>
            </div>
            {authError && (
              <p
                role="alert"
                className="m-0 text-xs font-semibold"
                style={{ color: 'var(--color-error)' }}
              >
                {authError}
              </p>
            )}
            {authMessage && (
              <p
                role="status"
                className="m-0 text-xs font-semibold"
                style={{ color: 'var(--color-positive)' }}
              >
                {authMessage}
              </p>
            )}
            <button
              type="submit"
              style={{
                backgroundColor: 'var(--color-primary)',
                color: 'var(--color-on-primary)',
                borderRadius: 'var(--radius-control)',
              }}
              className="touch-target inline-flex cursor-pointer items-center gap-2 px-5 py-2.5 text-xs font-semibold"
            >
              <Cloud size={15} aria-hidden="true" />
              <span>
                {authMode === 'register'
                  ? 'Create Sync Account'
                  : 'Sign In to Sync'}
              </span>
            </button>
          </form>
        )}
      </AppCard>

      {/* Data & Privacy Card */}
      <AppCard className="space-y-2">
        <SectionHeader title="Data & Privacy" />
        <p
          className="m-0 text-xs leading-relaxed"
          style={{ color: 'var(--color-on-surface-variant)' }}
        >
          Your health data is stored on this device in IndexedDB by default and
          never leaves it unless you explicitly opt into Neon Postgres Cloud Sync
          or export a file yourself. There is no analytics SDK and no advertising
          SDK in this app.
        </p>
        <p
          className="m-0 text-xs leading-relaxed"
          style={{ color: 'var(--color-on-surface-variant)' }}
        >
          Healthie is a personal tracker, not a medical device. It does not
          diagnose, and it does not replace professional medical advice.
        </p>
        <div className="pt-1">
          <Link
            href="/privacy"
            style={{ color: 'var(--color-primary)' }}
            className="inline-flex items-center gap-1.5 text-xs font-semibold underline"
          >
            <ShieldCheck size={14} aria-hidden="true" />
            <span>Read Full Privacy Policy &amp; Neon Processor Disclosure</span>
          </Link>
        </div>
      </AppCard>
    </div>
  );
}
