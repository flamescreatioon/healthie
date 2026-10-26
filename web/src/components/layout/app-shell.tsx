'use client';

/**
 * Responsive PWA Application Shell (`docs/web/07-design-responsive.md`).
 *
 * - Desktop: Left navigation rail + persistent "Log reading" primary action.
 * - Mobile / narrow widths: Bottom navigation bar + Quick Log action sheet.
 * - Calm inline PWA install affordance (`beforeinstallprompt` on Chromium +
 *   iOS Safari Add-to-Home-Screen guidance).
 * - Service worker registration (`CACHE_ALLOW_LIST` shell-only, never `/api/*`)
 *   and versioned update banner (`SKIP_WAITING`).
 * - Undo toast for soft-deleted measurements (`aria-live="polite"`).
 */

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  Activity,
  BarChart3,
  CheckCircle2,
  Clock,
  Cloud,
  CloudOff,
  Download,
  Home,
  Moon,
  Plus,
  RefreshCw,
  ShieldCheck,
  Sun,
  User,
  X,
} from 'lucide-react';
import { useAppContext } from '@/components/providers/app-providers';

interface BeforeInstallPromptEvent extends Event {
  prompt(): Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>;
}

const NAV_ITEMS = [
  { href: '/', label: 'Home', icon: Home },
  { href: '/track', label: 'Track', icon: Activity },
  { href: '/analytics', label: 'Analytics', icon: BarChart3 },
  { href: '/history', label: 'History', icon: Clock },
  { href: '/profile', label: 'Profile', icon: User },
] as const;

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const {
    storageDegradedReason,
    syncState,
    syncEnabled,
    pendingOutboxCount,
    undoToast,
    dismissUndoToast,
    theme,
    setTheme,
  } = useAppContext();

  const [deferredInstallPrompt, setDeferredInstallPrompt] =
    useState<BeforeInstallPromptEvent | null>(null);
  const [isIosSafariHintVisible, setIsIosSafariHintVisible] = useState(false);
  const [installDismissed, setInstallDismissed] = useState(false);
  const [swWaitingWorker, setSwWaitingWorker] = useState<ServiceWorker | null>(
    null,
  );
  const [quickLogOpen, setQuickLogOpen] = useState(false);

  // Register Service Worker + listen for versioned updates (`docs/web/03-local-data-web.md`)
  useEffect(() => {
    if (typeof window === 'undefined' || !('serviceWorker' in navigator)) return;

    navigator.serviceWorker
      .register('/sw.js')
      .then((registration) => {
        if (registration.waiting) {
          setSwWaitingWorker(registration.waiting);
        }
        registration.addEventListener('updatefound', () => {
          const installing = registration.installing;
          if (!installing) return;
          installing.addEventListener('statechange', () => {
            if (
              installing.state === 'installed' &&
              navigator.serviceWorker.controller
            ) {
              setSwWaitingWorker(installing);
            }
          });
        });
      })
      .catch(() => {
        // Non-fatal in dev or test environments
      });

    const onBeforeInstall = (e: Event) => {
      e.preventDefault();
      setDeferredInstallPrompt(e as BeforeInstallPromptEvent);
    };

    window.addEventListener('beforeinstallprompt', onBeforeInstall);

    // Detect iOS Safari non-standalone for Add-to-Home-Screen guidance
    const ua = window.navigator.userAgent;
    const isIos = /iPad|iPhone|iPod/.test(ua);
    const isStandalone = window.matchMedia('(display-mode: standalone)').matches;
    if (isIos && !isStandalone) {
      setIsIosSafariHintVisible(true);
    }

    return () => {
      window.removeEventListener('beforeinstallprompt', onBeforeInstall);
    };
  }, []);

  const handleInstallClick = async () => {
    if (!deferredInstallPrompt) return;
    await deferredInstallPrompt.prompt();
    await deferredInstallPrompt.userChoice;
    setDeferredInstallPrompt(null);
  };

  const handleApplySwUpdate = () => {
    if (!swWaitingWorker) return;
    swWaitingWorker.postMessage({ type: 'SKIP_WAITING' });
    setSwWaitingWorker(null);
    window.location.reload();
  };

  const toggleTheme = () => {
    const next = theme === 'dark' ? 'light' : 'dark';
    setTheme(next);
  };

  return (
    <div
      className="min-h-screen flex flex-col md:flex-row"
      style={{ backgroundColor: 'var(--color-surface)' }}
    >
      {/* Desktop Sidebar Navigation */}
      <aside
        style={{
          backgroundColor: 'var(--color-surface-lowest)',
          borderRight: '1px solid var(--color-outline-variant)',
        }}
        className="hidden md:flex md:w-64 md:flex-col md:justify-between md:p-5 shrink-0"
        aria-label="Primary navigation"
      >
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <Link
              href="/"
              className="flex items-center gap-2.5 no-underline"
              style={{ color: 'var(--color-on-surface)' }}
            >
              <span
                style={{
                  backgroundColor: 'var(--color-primary)',
                  color: 'var(--color-on-primary)',
                }}
                className="flex h-9 w-9 items-center justify-center rounded-xl font-bold"
              >
                <Activity size={20} aria-hidden="true" />
              </span>
              <div>
                <div className="type-title leading-none">Healthie</div>
                <div
                  className="text-[11px] font-medium"
                  style={{ color: 'var(--color-on-surface-variant)' }}
                >
                  Clinical Clarity PWA
                </div>
              </div>
            </Link>
            <button
              type="button"
              onClick={toggleTheme}
              aria-label="Toggle dark mode"
              style={{ color: 'var(--color-on-surface-variant)' }}
              className="touch-target inline-flex cursor-pointer items-center justify-center rounded-xl p-2"
            >
              {theme === 'dark' ? <Sun size={18} /> : <Moon size={18} />}
            </button>
          </div>

          <Link
            href="/entry/blood-pressure"
            style={{
              backgroundColor: 'var(--color-primary)',
              color: 'var(--color-on-primary)',
              borderRadius: 'var(--radius-control)',
            }}
            className="touch-target flex w-full items-center justify-center gap-2 px-4 py-3 text-sm font-semibold no-underline shadow-xs"
          >
            <Plus size={18} aria-hidden="true" />
            <span>Log reading</span>
          </Link>

          <nav className="space-y-1">
            {NAV_ITEMS.map((item) => {
              const Icon = item.icon;
              const active =
                item.href === '/'
                  ? pathname === '/' || pathname === '/home'
                  : pathname?.startsWith(item.href);
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  aria-current={active ? 'page' : undefined}
                  style={{
                    backgroundColor: active
                      ? 'var(--color-primary-container)'
                      : 'transparent',
                    color: active
                      ? 'var(--color-on-primary-container)'
                      : 'var(--color-on-surface-variant)',
                    borderRadius: 'var(--radius-control)',
                  }}
                  className="touch-target flex items-center gap-3 px-3.5 py-2.5 text-sm font-semibold no-underline transition-calm"
                >
                  <Icon size={19} aria-hidden="true" />
                  <span>{item.label}</span>
                </Link>
              );
            })}
          </nav>
        </div>

        {/* Local-first & Sync Status Indicator */}
        <div
          style={{
            backgroundColor: 'var(--color-surface-low)',
            borderRadius: 'var(--radius-control)',
            border: '1px solid var(--color-outline-variant)',
          }}
          className="p-3 text-xs space-y-1.5"
        >
          <div className="flex items-center justify-between font-semibold">
            <span className="flex items-center gap-1.5">
              {syncEnabled ? (
                syncState === 'offline' ? (
                  <CloudOff size={14} aria-hidden="true" />
                ) : (
                  <Cloud size={14} aria-hidden="true" />
                )
              ) : (
                <ShieldCheck size={14} aria-hidden="true" />
              )}
              <span>{syncEnabled ? 'Neon Cloud Sync' : 'Device-Only Mode'}</span>
            </span>
            <span
              className="tabular-nums"
              style={{ color: 'var(--color-on-surface-variant)' }}
            >
              {pendingOutboxCount > 0 ? `${pendingOutboxCount} queued` : 'Synced'}
            </span>
          </div>
          <p
            className="m-0 text-[11px]"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            IndexedDB is the primary source of truth. Works 100% offline.
          </p>
          <Link
            href="/privacy"
            className="inline-block text-[11px] font-semibold underline"
            style={{ color: 'var(--color-primary)' }}
          >
            Privacy &amp; Neon Policy
          </Link>
        </div>
      </aside>

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0 pb-24 md:pb-8">
        {/* Mobile Header */}
        <header
          style={{
            backgroundColor: 'var(--color-surface-lowest)',
            borderBottom: '1px solid var(--color-outline-variant)',
          }}
          className="flex md:hidden items-center justify-between px-4 py-3 sticky top-0 z-20"
        >
          <Link
            href="/"
            className="flex items-center gap-2 no-underline"
            style={{ color: 'var(--color-on-surface)' }}
          >
            <span
              style={{
                backgroundColor: 'var(--color-primary)',
                color: 'var(--color-on-primary)',
              }}
              className="flex h-8 w-8 items-center justify-center rounded-lg"
            >
              <Activity size={18} aria-hidden="true" />
            </span>
            <span className="type-title">Healthie</span>
          </Link>
          <div className="flex items-center gap-2">
            <span
              style={{
                backgroundColor: 'var(--color-surface-low)',
                color: 'var(--color-on-surface-variant)',
              }}
              className="rounded-full px-2.5 py-1 text-[11px] font-semibold tabular-nums"
            >
              {pendingOutboxCount > 0
                ? `${pendingOutboxCount} unsynced`
                : 'Local ready'}
            </span>
            <button
              type="button"
              onClick={toggleTheme}
              aria-label="Toggle dark mode"
              style={{ color: 'var(--color-on-surface-variant)' }}
              className="touch-target inline-flex cursor-pointer items-center justify-center rounded-lg p-2"
            >
              {theme === 'dark' ? <Sun size={18} /> : <Moon size={18} />}
            </button>
          </div>
        </header>

        {/* Degraded IndexedDB / Private Window Banner */}
        {storageDegradedReason && (
          <div
            role="status"
            style={{
              backgroundColor: 'var(--color-tertiary-container)',
              color: 'var(--color-on-tertiary-container)',
            }}
            className="px-4 py-2.5 text-xs font-medium"
          >
            {storageDegradedReason}
          </div>
        )}

        {/* Service Worker Version Update Prompt (`docs/web/07-design-responsive.md`) */}
        {swWaitingWorker && (
          <div
            role="status"
            aria-live="polite"
            style={{
              backgroundColor: 'var(--color-primary-container)',
              color: 'var(--color-on-primary-container)',
            }}
            className="flex items-center justify-between gap-3 px-4 py-2.5 text-xs font-medium"
          >
            <span className="flex items-center gap-2">
              <RefreshCw size={15} aria-hidden="true" />
              <span>A newer version of Healthie PWA is ready.</span>
            </span>
            <button
              type="button"
              onClick={handleApplySwUpdate}
              style={{
                backgroundColor: 'var(--color-primary)',
                color: 'var(--color-on-primary)',
                borderRadius: 'var(--radius-pill)',
              }}
              className="cursor-pointer px-3 py-1 text-xs font-semibold"
            >
              Reload to update
            </button>
          </div>
        )}

        {/* Calm Inline PWA Install Affordance */}
        {!installDismissed && (deferredInstallPrompt || isIosSafariHintVisible) && (
          <div
            style={{
              backgroundColor: 'var(--color-secondary-container)',
              color: 'var(--color-on-secondary-container)',
            }}
            className="mx-auto mt-3 flex w-full max-w-5xl items-center justify-between gap-3 rounded-2xl px-4 py-2.5 text-xs"
          >
            <div className="flex items-center gap-2.5">
              <Download size={16} aria-hidden="true" />
              {deferredInstallPrompt ? (
                <span>
                  Install Healthie for instant one-tap offline logging from your
                  home screen or desktop.
                </span>
              ) : (
                <span>
                  Install on iOS Safari: tap <strong>Share</strong> →{' '}
                  <strong>Add to Home Screen</strong> for full offline PWA mode.
                </span>
              )}
            </div>
            <div className="flex items-center gap-2 shrink-0">
              {deferredInstallPrompt && (
                <button
                  type="button"
                  onClick={handleInstallClick}
                  style={{
                    backgroundColor: 'var(--color-primary)',
                    color: 'var(--color-on-primary)',
                    borderRadius: 'var(--radius-pill)',
                  }}
                  className="cursor-pointer px-3 py-1 font-semibold"
                >
                  Install app
                </button>
              )}
              <button
                type="button"
                aria-label="Dismiss install hint"
                onClick={() => setInstallDismissed(true)}
                className="cursor-pointer p-1"
              >
                <X size={15} />
              </button>
            </div>
          </div>
        )}

        {/* Page Container */}
        <main className="mx-auto w-full max-w-5xl flex-1 p-4 sm:p-6">
          {children}
        </main>
      </div>

      {/* Undo Toast (`aria-live="polite"`) */}
      {undoToast && (
        <div
          role="status"
          aria-live="polite"
          style={{
            backgroundColor: 'var(--color-inverse-surface)',
            color: 'var(--color-on-inverse-surface)',
            borderRadius: 'var(--radius-control)',
          }}
          className="fixed bottom-20 md:bottom-6 right-4 z-50 flex items-center gap-4 px-4 py-3 text-sm shadow-lg"
        >
          <span className="flex items-center gap-2">
            <CheckCircle2 size={16} aria-hidden="true" />
            <span>{undoToast.message}</span>
          </span>
          <button
            type="button"
            onClick={async () => {
              await undoToast.onUndo();
              dismissUndoToast();
            }}
            style={{ color: 'var(--color-secondary)' }}
            className="cursor-pointer font-bold underline"
          >
            Undo
          </button>
          <button
            type="button"
            aria-label="Close notification"
            onClick={dismissUndoToast}
            className="cursor-pointer opacity-75"
          >
            <X size={15} />
          </button>
        </div>
      )}

      {/* Mobile Bottom Navigation */}
      <nav
        aria-label="Mobile navigation"
        style={{
          backgroundColor: 'var(--color-surface-lowest)',
          borderTop: '1px solid var(--color-outline-variant)',
        }}
        className="fixed bottom-0 inset-x-0 z-30 flex md:hidden items-center justify-around px-2 py-1.5"
      >
        {NAV_ITEMS.slice(0, 2).map((item) => {
          const Icon = item.icon;
          const active =
            item.href === '/'
              ? pathname === '/' || pathname === '/home'
              : pathname?.startsWith(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              style={{
                color: active
                  ? 'var(--color-primary)'
                  : 'var(--color-on-surface-variant)',
              }}
              className="touch-target flex flex-col items-center justify-center px-2 text-[11px] font-semibold no-underline"
            >
              <Icon size={20} aria-hidden="true" />
              <span className="mt-0.5">{item.label}</span>
            </Link>
          );
        })}

        <button
          type="button"
          onClick={() => setQuickLogOpen(true)}
          aria-label="Quick log a measurement"
          style={{
            backgroundColor: 'var(--color-primary)',
            color: 'var(--color-on-primary)',
          }}
          className="touch-target -mt-4 flex h-12 w-12 cursor-pointer items-center justify-center rounded-full shadow-md"
        >
          <Plus size={22} aria-hidden="true" />
        </button>

        {NAV_ITEMS.slice(2).map((item) => {
          const Icon = item.icon;
          const active = pathname?.startsWith(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              style={{
                color: active
                  ? 'var(--color-primary)'
                  : 'var(--color-on-surface-variant)',
              }}
              className="touch-target flex flex-col items-center justify-center px-2 text-[11px] font-semibold no-underline"
            >
              <Icon size={20} aria-hidden="true" />
              <span className="mt-0.5">{item.label}</span>
            </Link>
          );
        })}
      </nav>

      {/* Quick Log Modal Sheet */}
      {quickLogOpen && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label="Log a measurement"
          className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 p-4 sm:items-center"
        >
          <div
            style={{
              backgroundColor: 'var(--color-surface-lowest)',
              borderRadius: 'var(--radius-hero)',
              border: '1px solid var(--color-outline-variant)',
            }}
            className="w-full max-w-md p-6 space-y-4"
          >
            <div className="flex items-center justify-between">
              <h2 className="type-title m-0">Log a measurement</h2>
              <button
                type="button"
                aria-label="Close quick log sheet"
                onClick={() => setQuickLogOpen(false)}
                className="touch-target inline-flex items-center justify-center"
              >
                <X size={20} />
              </button>
            </div>
            <div className="space-y-2">
              <Link
                href="/entry/blood-pressure"
                onClick={() => setQuickLogOpen(false)}
                style={{
                  backgroundColor: 'var(--color-surface-low)',
                  borderRadius: 'var(--radius-control)',
                  color: 'var(--color-on-surface)',
                }}
                className="flex items-center justify-between p-3.5 no-underline"
              >
                <div>
                  <div className="font-semibold text-sm">Blood pressure</div>
                  <div
                    className="text-xs"
                    style={{ color: 'var(--color-on-surface-variant)' }}
                  >
                    Systolic, diastolic, and pulse
                  </div>
                </div>
                <Plus size={18} />
              </Link>
              <Link
                href="/entry/weight"
                onClick={() => setQuickLogOpen(false)}
                style={{
                  backgroundColor: 'var(--color-surface-low)',
                  borderRadius: 'var(--radius-control)',
                  color: 'var(--color-on-surface)',
                }}
                className="flex items-center justify-between p-3.5 no-underline"
              >
                <div>
                  <div className="font-semibold text-sm">Body weight</div>
                  <div
                    className="text-xs"
                    style={{ color: 'var(--color-on-surface-variant)' }}
                  >
                    Weight, body fat, and waist
                  </div>
                </div>
                <Plus size={18} />
              </Link>
              <Link
                href="/track"
                onClick={() => setQuickLogOpen(false)}
                style={{
                  backgroundColor: 'var(--color-surface-low)',
                  borderRadius: 'var(--radius-control)',
                  color: 'var(--color-on-surface)',
                }}
                className="flex items-center justify-between p-3.5 no-underline"
              >
                <div>
                  <div className="font-semibold text-sm">
                    Heart rate, SpO₂, Temp, or Glucose
                  </div>
                  <div
                    className="text-xs"
                    style={{ color: 'var(--color-on-surface-variant)' }}
                  >
                    All metrics in the catalog
                  </div>
                </div>
                <Plus size={18} />
              </Link>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
