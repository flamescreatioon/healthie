'use client';

/**
 * Application Providers: TanStack Query + Repository DI + Sync Lifecycle +
 * Theme & Undo Toast state (`docs/web/02-domain-architecture.md` & `04-auth-sync.md`).
 *
 * UI components depend on `useRepositories()` (which returns domain repository
 * interfaces) rather than importing Dexie or fetch directly.
 */

import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import {
  type Clock,
  type MeasurementRepository,
  type MedicationRepository,
  type ProfileRepository,
  type ReminderRepository,
  systemClock,
} from '@/domain';
import {
  checkIndexedDbAvailability,
  DexieMeasurementRepository,
  DexieMedicationRepository,
  DexieProfileRepository,
  DexieReminderRepository,
} from '@/data';
import {
  getLastSyncedAt,
  isSyncOptedIn,
  requestBackgroundSync,
  runSyncCycle,
  setSyncOptIn,
  type SyncStateKind,
} from '@/data/sync-engine';

export interface AppRepositories {
  readonly measurements: MeasurementRepository;
  readonly profile: ProfileRepository;
  readonly reminders: ReminderRepository;
  readonly medications: MedicationRepository;
  readonly clock: Clock;
}

export interface UndoToastItem {
  readonly id: string;
  readonly message: string;
  readonly onUndo: () => Promise<void>;
}

export interface SyncUser {
  readonly id: string;
  readonly email: string;
  readonly displayName: string | null;
}

interface AppContextValue {
  readonly repositories: AppRepositories;
  readonly storageDegradedReason: string | null;
  readonly syncState: SyncStateKind;
  readonly syncEnabled: boolean;
  readonly lastSyncedAt: string | null;
  readonly pendingOutboxCount: number;
  readonly user: SyncUser | null;
  readonly setUser: (user: SyncUser | null) => void;
  readonly toggleSyncOptIn: (enabled: boolean) => Promise<void>;
  readonly triggerSync: (options?: { force?: boolean }) => Promise<void>;
  readonly undoToast: UndoToastItem | null;
  readonly showUndoToast: (item: UndoToastItem) => void;
  readonly dismissUndoToast: () => void;
  readonly theme: 'system' | 'light' | 'dark';
  readonly setTheme: (theme: 'system' | 'light' | 'dark') => void;
}

const AppContext = createContext<AppContextValue | null>(null);

export function useAppContext(): AppContextValue {
  const ctx = useContext(AppContext);
  if (!ctx) {
    throw new Error('useAppContext must be used inside <AppProviders>');
  }
  return ctx;
}

export function useRepositories(): AppRepositories {
  return useAppContext().repositories;
}

export function AppProviders({
  children,
  overrideRepositories,
}: {
  children: React.ReactNode;
  overrideRepositories?: Partial<AppRepositories>;
}) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 2_000,
            retry: false,
          },
        },
      }),
  );

  const repositories = useMemo<AppRepositories>(
    () => ({
      measurements:
        overrideRepositories?.measurements ?? new DexieMeasurementRepository(),
      profile: overrideRepositories?.profile ?? new DexieProfileRepository(),
      reminders: overrideRepositories?.reminders ?? new DexieReminderRepository(),
      medications:
        overrideRepositories?.medications ?? new DexieMedicationRepository(),
      clock: overrideRepositories?.clock ?? systemClock,
    }),
    [overrideRepositories],
  );

  const [storageDegradedReason, setStorageDegradedReason] = useState<string | null>(
    null,
  );
  const [syncState, setSyncState] = useState<SyncStateKind>('idle');
  const [syncEnabled, setSyncEnabledState] = useState<boolean>(false);
  const [lastSyncedAt, setLastSyncedAt] = useState<string | null>(null);
  const [pendingOutboxCount, setPendingOutboxCount] = useState<number>(0);
  const [user, setUser] = useState<SyncUser | null>(null);
  const [undoToast, setUndoToast] = useState<UndoToastItem | null>(null);
  const [theme, setThemeState] = useState<'system' | 'light' | 'dark'>('system');

  const setTheme = useCallback((next: 'system' | 'light' | 'dark') => {
    setThemeState(next);
    if (typeof document !== 'undefined') {
      if (next === 'system') {
        document.documentElement.removeAttribute('data-theme');
      } else {
        document.documentElement.setAttribute('data-theme', next);
      }
    }
  }, []);

  const refreshOutboxCount = useCallback(async () => {
    try {
      const outbox = await repositories.measurements.getOutbox();
      setPendingOutboxCount(outbox.length);
    } catch {
      // ignore in fake/SSR mode
    }
  }, [repositories.measurements]);

  const triggerSync = useCallback(
    async (options?: { force?: boolean }) => {
      await refreshOutboxCount();
      if (typeof navigator !== 'undefined' && !navigator.onLine) {
        setSyncState('offline');
        await requestBackgroundSync();
        return;
      }
      try {
        setSyncState('syncing');
        const result = await runSyncCycle({ force: options?.force });
        if (result.unauthorized) {
          setUser(null);
          setSyncState('idle');
          return;
        }
        const syncedAt = await getLastSyncedAt();
        setLastSyncedAt(syncedAt);
        setSyncState('synced');
        await refreshOutboxCount();
        await queryClient.invalidateQueries();
      } catch {
        setSyncState('error');
        await requestBackgroundSync();
      }
    },
    [queryClient, refreshOutboxCount],
  );

  const toggleSyncOptIn = useCallback(
    async (enabled: boolean) => {
      await setSyncOptIn(enabled);
      setSyncEnabledState(enabled);
      if (enabled) {
        await triggerSync({ force: true });
      } else {
        setSyncState('idle');
      }
    },
    [triggerSync],
  );

  const showUndoToast = useCallback((item: UndoToastItem) => {
    setUndoToast(item);
  }, []);

  const dismissUndoToast = useCallback(() => {
    setUndoToast(null);
  }, []);

  // Initial check: IndexedDB availability, sync opt-in state, and active session
  useEffect(() => {
    if (overrideRepositories) return;
    let active = true;
    (async () => {
      const check = await checkIndexedDbAvailability();
      if (!active) return;
      if (!check.available && check.reason) {
        setStorageDegradedReason(check.reason);
      }
      const optedIn = await isSyncOptedIn();
      const syncedAt = await getLastSyncedAt();
      if (!active) return;
      setSyncEnabledState(optedIn);
      setLastSyncedAt(syncedAt);
      await refreshOutboxCount();

      try {
        const res = await fetch('/api/auth/session', { credentials: 'include' });
        if (res.ok) {
          const data = (await res.json()) as {
            authenticated: boolean;
            user: SyncUser | null;
          };
          if (active && data.authenticated && data.user) {
            setUser(data.user);
            if (optedIn) {
              void triggerSync();
            }
          }
        }
      } catch {
        // Offline launch is a normal state in an offline-first PWA
      }
    })();
    return () => {
      active = false;
    };
  }, [overrideRepositories, refreshOutboxCount, triggerSync]);

  // Foreground sync triggers: `online`, `visibilitychange`, and 60s interval
  useEffect(() => {
    if (overrideRepositories || typeof window === 'undefined') return;
    const onOnline = () => {
      if (syncEnabled) void triggerSync();
    };
    const onOffline = () => {
      setSyncState('offline');
    };
    const onVisibility = () => {
      if (document.visibilityState === 'visible' && syncEnabled) {
        void triggerSync();
      }
    };

    window.addEventListener('online', onOnline);
    window.addEventListener('offline', onOffline);
    document.addEventListener('visibilitychange', onVisibility);
    const interval = window.setInterval(() => {
      if (syncEnabled && navigator.onLine) {
        void triggerSync();
      }
    }, 60_000);

    return () => {
      window.removeEventListener('online', onOnline);
      window.removeEventListener('offline', onOffline);
      document.removeEventListener('visibilitychange', onVisibility);
      window.clearInterval(interval);
    };
  }, [overrideRepositories, syncEnabled, triggerSync]);

  const value = useMemo<AppContextValue>(
    () => ({
      repositories,
      storageDegradedReason,
      syncState,
      syncEnabled,
      lastSyncedAt,
      pendingOutboxCount,
      user,
      setUser,
      toggleSyncOptIn,
      triggerSync,
      undoToast,
      showUndoToast,
      dismissUndoToast,
      theme,
      setTheme,
    }),
    [
      repositories,
      storageDegradedReason,
      syncState,
      syncEnabled,
      lastSyncedAt,
      pendingOutboxCount,
      user,
      toggleSyncOptIn,
      triggerSync,
      undoToast,
      showUndoToast,
      dismissUndoToast,
      theme,
      setTheme,
    ],
  );

  return (
    <QueryClientProvider client={queryClient}>
      <AppContext.Provider value={value}>{children}</AppContext.Provider>
    </QueryClientProvider>
  );
}
