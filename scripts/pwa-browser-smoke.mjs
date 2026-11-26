import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {once} from 'node:events';
import {createServer} from 'node:http';
import {mkdtemp, readFile, realpath, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join, resolve, sep, extname} from 'node:path';
import {setTimeout as wait} from 'node:timers/promises';

const root = resolve('build/web');
const temporary = await realpath(tmpdir());
const profile = await mkdtemp(join(temporary, 'jbm-pwa-smoke-'));
const browserPath = process.env.CHROME_EXECUTABLE ??
  (process.platform === 'win32' ? 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe' : 'google-chrome');
const mime = {
  '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.png': 'image/png',
};
const server = createServer(async (request, response) => {
  try {
    const path = new URL(request.url, 'http://127.0.0.1').pathname;
    const relative = path === '/' || path === '/orders' ? '/index.html' : path;
    const file = resolve(root, '.' + relative);
    if (!file.startsWith(root + sep)) { response.writeHead(403).end(); return; }
    const bytes = await readFile(file);
    response.writeHead(200, {'Content-Type': mime[extname(file)] ?? 'application/octet-stream'});
    response.end(bytes);
  } catch (_) {
    response.writeHead(404).end();
  }
});

async function until(check, description, limit = 45000) {
  const end = Date.now() + limit;
  while (Date.now() < end) {
    try {
      const value = await check();
      if (value) return value;
    } catch (_) {}
    await wait(250);
  }
  throw new Error('Timed out waiting for ' + description);
}

let browser, socket;
try {
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const origin = 'http://127.0.0.1:' + server.address().port;
  browser = spawn(browserPath, [
    '--headless=new', '--disable-gpu', '--no-first-run', '--remote-debugging-port=0',
    '--user-data-dir=' + profile, 'about:blank',
  ], {windowsHide: true, stdio: 'ignore'});
  const [, debugging] = await Promise.race([
    once(browser, 'spawn').then(async () => ['spawn', await until(async () => {
      const port = (await readFile(join(profile, 'DevToolsActivePort'), 'utf8')).split(/\r?\n/)[0];
      const targets = await (await fetch('http://127.0.0.1:' + port + '/json/list')).json();
      return targets.find((target) => target.type === 'page')?.webSocketDebuggerUrl;
    }, 'Chrome DevTools')]),
    once(browser, 'error').then(([error]) => { throw error; }),
  ]);
  socket = new WebSocket(debugging);
  await once(socket, 'open');
  let sequence = 0;
  const pending = new Map();
  const documents = [];
  socket.addEventListener('message', (event) => {
    const payload = JSON.parse(event.data);
    if (payload.method === 'Network.responseReceived' && payload.params.type === 'Document') {
      documents.push(payload.params.response);
    }
    const callback = pending.get(payload.id);
    if (!callback) return;
    pending.delete(payload.id);
    if (payload.error) callback.reject(new Error(payload.error.message));
    else callback.resolve(payload.result);
  });
  function cdp(method, params = {}) {
    const id = ++sequence;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        pending.delete(id); reject(new Error(method + ' timed out'));
      }, 10000);
      pending.set(id, {
        resolve: (data) => { clearTimeout(timer); resolve(data); },
        reject: (error) => { clearTimeout(timer); reject(error); },
      });
      socket.send(JSON.stringify({id, method, params}));
    });
  }
  async function evaluate(expression) {
    return (await cdp('Runtime.evaluate', {expression, returnByValue: true})).result.value;
  }
  await cdp('Page.enable');
  await cdp('Network.enable');
  await cdp('Page.navigate', {url: origin});
  await until(() => evaluate("navigator.serviceWorker?.controller !== null && !!navigator.serviceWorker?.controller"),
    'the app shell service worker', 90000);
  await cdp('Network.emulateNetworkConditions', {
    offline: true, latency: 0, downloadThroughput: 0, uploadThroughput: 0,
  });
  const navigation = await cdp('Page.navigate', {url: origin + '/orders'});
  assert.equal(navigation.errorText, undefined);
  const offline = await until(() => documents.find((response) =>
    response.url === origin + '/orders' && response.fromServiceWorker && response.status === 200),
    'Chrome to serve the offline deep-link document from the app-shell worker', 20000);
  assert.equal(offline.fromServiceWorker, true);
  const cached = await cdp('Runtime.evaluate', {
    expression: "Promise.all([caches.match('/main.dart.js'), caches.match('/flutter_bootstrap.js')]).then((items) => items.every(Boolean))",
    awaitPromise: true, returnByValue: true,
  });
  assert.equal(cached.result.value, true);
  console.log('PASS: Chrome reopened the offline deep link through the service worker with Flutter bootstrap and app code cached.');
} finally {
  socket?.close();
  if (browser?.pid && browser.exitCode == null) {
    const exit = once(browser, 'exit');
    browser.kill();
    await Promise.race([exit, wait(3000)]);
  }
  server.closeAllConnections();
  server.close();
  const target = await realpath(profile);
  if (target.startsWith(join(temporary, 'jbm-pwa-smoke-'))) {
    await rm(target, {recursive: true, force: true, maxRetries: 4, retryDelay: 250});
  }
}