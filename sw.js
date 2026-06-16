const CACHE_NAME = 'vault-v2';

// Assets to pre-cache on install
const PRECACHE_URLS = [
  '/',
  '/index.html',
  'https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js',
  'https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js'
];

// ── Install: pre-cache all assets ──────────────────────────────────────────
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      // Cache CDN assets with CORS mode; cache local assets normally
      const requests = PRECACHE_URLS.map(url =>
        url.startsWith('http')
          ? new Request(url, { mode: 'cors' })
          : url
      );
      return cache.addAll(requests);
    }).then(() => self.skipWaiting())
  );
});

// ── Activate: remove old caches ─────────────────────────────────────────────
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

// ── Fetch strategy ───────────────────────────────────────────────────────────
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);

  // CDN assets: cache-first (versioned URLs, safe to serve stale)
  if (url.hostname === 'cdn.jsdelivr.net') {
    event.respondWith(
      caches.match(event.request).then(cached =>
        cached || fetch(event.request).then(response => {
          const clone = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
          return response;
        })
      )
    );
    return;
  }

  // App shell: NETWORK-FIRST (always serve fresh deploy; fall back to cache only when offline)
  if (event.request.mode === 'navigate' || url.pathname === '/' || url.pathname.endsWith('.html')) {
    event.respondWith(
      fetch(event.request).then(response => {
        const clone = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
        return response;
      }).catch(() =>
        caches.open(CACHE_NAME).then(cache => cache.match(event.request))
      )
    );
    return;
  }

  // Everything else (API calls, sync): network-only
  // Don't intercept — let them go straight to network
});
