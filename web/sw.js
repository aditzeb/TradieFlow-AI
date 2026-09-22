const scope = new URL(self.registration.scope);
const cachePrefix = `tradieflow-shell:${scope.pathname}:`;
const cacheName = `${cachePrefix}v1`;
const shellFiles = new Map([
  ['index.html', 'text/html'],
  ['manifest.json', 'application/json'],
  ['favicon.png', 'image/png'],
  ['icons/tradieflow.svg', 'image/svg+xml'],
  ['icons/Icon-192.png', 'image/png'],
  ['icons/Icon-512.png', 'image/png'],
  ['icons/Icon-maskable-192.png', 'image/png'],
  ['icons/Icon-maskable-512.png', 'image/png'],
]);

async function networkFirst(path) {
  const url = new URL(path, scope).href;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await fetch(url, {
      cache: 'no-store',
      credentials: 'omit',
      redirect: 'error',
      signal: controller.signal,
    });
    if (response.status >= 500) throw new Error('Shell unavailable');
    const type = response.headers.get('content-type')?.split(';')[0].trim();
    const expected = shellFiles.get(path);
    const cacheControl = response.headers.get('cache-control') || '';
    const vary = response.headers.get('vary') || '';
    if (response.ok && (type === expected || (path === 'manifest.json' && type === 'application/manifest+json'))
        && !/no-store|private/i.test(cacheControl) && !/\*|cookie|authorization/i.test(vary)) {
      try {
        const cache = await caches.open(cacheName);
        await cache.put(url, response.clone());
      } catch {}
    }
    return response;
  } catch {
    try {
      const cache = await caches.open(cacheName);
      return await cache.match(url) || Response.error();
    } catch {
      return Response.error();
    }
  } finally {
    clearTimeout(timeout);
  }
}

self.addEventListener('install', (event) => {
  event.waitUntil(Promise.all([...shellFiles.keys()].map(async (path) => {
    const response = await networkFirst(path);
    if (!response.ok) throw new Error('Shell installation incomplete');
  })));
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((key) => key.startsWith(cachePrefix) && key !== cacheName)
      .map((key) => caches.delete(key)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== scope.origin || url.search
      || !url.pathname.startsWith(scope.pathname) || request.headers.has('authorization')
      || request.headers.has('range') || request.cache === 'no-store') return;
  let path = url.pathname.slice(scope.pathname.length);
  if (path === '' && request.mode === 'navigate') path = 'index.html';
  if (!shellFiles.has(path)) return;
  event.respondWith(networkFirst(path));
});
