// The production build replaces these with the exact, hashed app assets.
const manifest = __EXERLY_SHELL_MANIFEST__;
const version = __EXERLY_SHELL_VERSION__;
const prefix = 'exerly-shell-v1-';
const cacheName = prefix + version;
const assets = new Set(manifest);

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(cacheName);
      try {
        await cache.addAll(manifest.map((url) => new Request(url, { cache: 'reload' })));
      } catch (error) {
        await caches.delete(cacheName);
        throw error;
      }
      // Let an update wait until the previous app's tabs close. Taking over a
      // live form would risk replacing the code that owns its pending changes.
    })()
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      for (const key of await caches.keys()) {
        if (key.startsWith(prefix) && key !== cacheName) await caches.delete(key);
      }
      await self.clients.claim();
    })()
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin) return;
  const navigation =
    request.mode === 'navigate' && (url.pathname === '/' || url.pathname === '/index.html');
  if (!navigation && (!assets.has(url.pathname) || url.search)) return;
  // Only the build's public shell belongs here. API/auth responses, videos,
  // uploads and account data never enter the service worker cache.
  const key = navigation ? '/index.html' : url.pathname;
  event.respondWith(
    (async () => {
      const cached = await (await caches.open(cacheName)).match(key);
      if (cached) return cached;
      return fetch(request);
    })()
  );
});
