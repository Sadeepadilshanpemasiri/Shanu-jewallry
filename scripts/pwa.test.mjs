import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import vm from 'node:vm';

test('versioned shell supports deep links without caching Firebase records', async () => {
  const handlers = new Map();
  const origin = 'https://demo.test';
  const created = new Map();
  const resolve = (path) => new URL(path.url ?? path, origin).href;
  const cache = {
    async addAll(requests) { for (const request of requests) created.set(resolve(request), 'cached ' + request.url); },
    async match(request) { return created.get(resolve(request)); },
    async put(request, response) { created.set(resolve(request), response); },
  };
  const state = {
    URL,
    Request: class { constructor(path) { this.url = resolve(path); } },
    self: {location: {origin}, clients: {claim: async () => {}}, addEventListener: (name, run) => handlers.set(name, run)},
    caches: {open: async () => cache, match: (request) => cache.match(request), keys: async () => []},
    fetch: async (request) => ({
      ok: true, type: 'cors',
      json: async () => ({release: 'test-release', assets: ['/index.html', '/main.dart.js']}),
      clone: () => 'cached public resource', url: request.url,
    }),
  };
  vm.runInNewContext((await readFile('web/shop-sw.js', 'utf8')).replace('__SHOP_RELEASE__', 'test-release'), state);
  let install;
  handlers.get('install')({waitUntil: (promise) => { install = promise; }});
  await install;
  function fetchEvent(url, mode = 'cors', authorized = false, method = 'GET') {
    let response;
    handlers.get('fetch')({
      request: {url, mode, method, headers: {has: () => authorized}},
      respondWith: (value) => { response = value; },
    });
    return response;
  }
  assert.equal(await fetchEvent(origin + '/orders', 'navigate'), 'cached ' + origin + '/index.html');
  assert.equal(await fetchEvent(origin + '/main.dart.js'), 'cached ' + origin + '/main.dart.js');
  assert.equal(fetchEvent(origin + '/__/auth/handler', 'navigate'), undefined);
  assert.equal(fetchEvent(origin + '/api/private', 'navigate'), undefined);
  assert.equal(fetchEvent('https://firestore.googleapis.com/v1/documents'), undefined);
  assert.equal(fetchEvent(origin + '/assets/token', 'cors', true), undefined);
  assert.equal(fetchEvent(origin + '/assets/write', 'cors', false, 'POST'), undefined);
  await fetchEvent('https://www.gstatic.com/firebasejs/13.1.0/firebase-app.js');
  assert.equal(await fetchEvent('https://www.gstatic.com/firebasejs/13.1.0/firebase-app.js'), 'cached public resource');
});