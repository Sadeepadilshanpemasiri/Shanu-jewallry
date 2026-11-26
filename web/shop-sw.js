const release = '__SHOP_RELEASE__';
const shellCache = 'jbm-shell-' + release;
const publicCache = 'jbm-public-' + release;
const manifestPath = '/shop-pwa-version.json';

function publicAsset(url) {
  return url.protocol === 'https:' && (
    (url.hostname === 'www.gstatic.com' && /^\/firebasejs\/\d+\.\d+\.\d+\//.test(url.pathname)) ||
    url.hostname === 'fonts.gstatic.com'
  );
}

function shellAsset(url) {
  if (url.origin !== self.location.origin) return false;
  return ['/index.html', '/flutter.js', '/flutter_bootstrap.js', '/main.dart.js', '/shop-pwa.js', '/manifest.json']
    .includes(url.pathname) || /^\/(assets|canvaskit|icons)\//.test(url.pathname);
}

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const response = await fetch(manifestPath, {cache: 'no-store'});
    if (!response.ok) throw new Error('Missing PWA release manifest');
    const manifest = await response.json();
    if (manifest.release !== release) throw new Error('PWA release version mismatch');
    if (!manifest.assets.every((path) => shellAsset(new URL(path, self.location.origin)))) {
      throw new Error('Unexpected app shell asset');
    }
    const cache = await caches.open(shellCache);
    await cache.addAll(manifest.assets.map((path) => new Request(path, {cache: 'reload'})));
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if ((key.startsWith('jbm-shell-') || key.startsWith('jbm-public-')) &&
          key !== shellCache && key !== publicCache) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || request.headers.has('authorization')) return;
  const url = new URL(request.url);
  if (request.mode === 'navigate' && url.origin === self.location.origin &&
      !url.pathname.startsWith('/__/') && !url.pathname.startsWith('/api/')) {
    event.respondWith((async () => (await caches.match('/index.html', {cacheName: shellCache})) ?? fetch(request))());
  } else if (shellAsset(url)) {
    event.respondWith((async () => (await caches.match(url.pathname, {cacheName: shellCache})) ?? fetch(request))());
  } else if (publicAsset(url)) {
    event.respondWith((async () => {
      const cache = await caches.open(publicCache);
      const stored = await cache.match(request);
      if (stored) return stored;
      const response = await fetch(request);
      if (response.ok && response.type === 'cors') await cache.put(request, response.clone());
      return response;
    })());
  }
});