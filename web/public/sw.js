/**
 * Healthie PWA Service Worker
 *
 * Security & Privacy Invariant (ADR-0006 & docs/web/07-privacy-security-compliance.md):
 * - Caches ONLY static application shell routes and icon assets.
 * - NEVER caches `/api/*` responses or any authenticated/health data payloads in Cache Storage.
 * - Supports Background Sync (`healthie-sync-outbox`) to trigger outbox replay in open clients.
 */

const CACHE_NAME = 'healthie-shell-v1';

const CACHE_ALLOW_LIST = [
  '/',
  '/home',
  '/track',
  '/analytics',
  '/history',
  '/profile',
  '/privacy',
  '/manifest.webmanifest',
  '/icons/icon-192.svg',
  '/icons/icon-512.svg',
  '/icons/icon-maskable.svg',
];

const CACHE_DENY_PREFIXES = ['/api/', '/_next/data/'];

function isDeniedFromCache(pathname) {
  return CACHE_DENY_PREFIXES.some((prefix) => pathname.startsWith(prefix));
}

function isAllowedShellRequest(request, url) {
  if (request.method !== 'GET') return false;
  if (url.origin !== self.location.origin) return false;
  if (isDeniedFromCache(url.pathname)) return false;
  if (CACHE_ALLOW_LIST.includes(url.pathname)) return true;
  if (url.pathname.startsWith('/_next/static/')) return true;
  if (url.pathname.startsWith('/icons/')) return true;
  return false;
}

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE_NAME)
      .then((cache) => cache.addAll(CACHE_ALLOW_LIST).catch(() => undefined))
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((key) => key !== CACHE_NAME)
            .map((staleKey) => caches.delete(staleKey))
        )
      )
      .then(() => self.clients.claim())
  );
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Strict privacy guard: never intercept or cache /api/ routes
  if (isDeniedFromCache(url.pathname)) {
    return;
  }

  if (!isAllowedShellRequest(request, url)) {
    return;
  }

  event.respondWith(
    fetch(request)
      .then((networkResponse) => {
        if (
          networkResponse &&
          networkResponse.status === 200 &&
          networkResponse.type === 'basic'
        ) {
          const cloned = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(request, cloned);
          });
        }
        return networkResponse;
      })
      .catch(async () => {
        const cached = await caches.match(request);
        if (cached) return cached;
        if (request.mode === 'navigate') {
          const fallback = await caches.match('/home');
          if (fallback) return fallback;
        }
        return Response.error();
      })
  );
});

self.addEventListener('sync', (event) => {
  if (event.tag === 'healthie-sync-outbox') {
    event.waitUntil(
      self.clients
        .matchAll({ type: 'window', includeUncontrolled: true })
        .then((clients) => {
          for (const client of clients) {
            client.postMessage({ type: 'HEALTHIE_BACKGROUND_SYNC' });
          }
        })
    );
  }
});
