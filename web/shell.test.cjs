const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const { runInNewContext } = require('node:vm');
const { inflateSync } = require('node:zlib');

const read = (path) => readFileSync(join(__dirname, path), 'utf8');

function worker() {
  const handlers = {};
  const entries = new Map();
  const deleted = [];
  const calls = [];
  const base = 'https://example.test/app/';
  const cacheName = 'tradieflow-shell:/app/:v1';
  const cache = {
    put: async (url, response) => entries.set(url, response),
    match: async (url) => entries.get(url)?.clone(),
  };
  const state = {
    response: () => new Response('shell-v1', { headers: { 'content-type': 'text/html' } }),
    offline: false,
    claimed: false,
  };
  runInNewContext(read('sw.js'), {
    URL, Response, AbortController, setTimeout, clearTimeout,
    fetch: async (url, options) => {
      calls.push({ url, options });
      if (state.offline) throw new Error('offline');
      return state.response(url);
    },
    caches: {
      open: async (name) => { assert.equal(name, cacheName); return cache; },
      keys: async () => [cacheName, 'tradieflow-shell:/app/:v0', 'tradieflow-shell:/other/:v0', 'unrelated'],
      delete: async (name) => deleted.push(name),
    },
    self: {
      registration: { scope: base },
      clients: { claim: async () => { state.claimed = true; } },
      addEventListener: (name, callback) => { handlers[name] = callback; },
    },
  });
  const request = (path, options = {}) => {
    let result;
    handlers.fetch({
      request: {
        url: new URL(path, base).href,
        method: 'GET', mode: 'navigate', cache: 'default', headers: new Headers(),
        ...options,
      },
      respondWith: (promise) => { result = promise; },
    });
    return result;
  };
  return { handlers, entries, deleted, calls, state, request, base };
}

test('worker is bounded, network-first, anonymous, and falls back only for shell', async () => {
  const sw = worker();
  assert.equal(await (await sw.request('')).text(), 'shell-v1');
  sw.state.response = () => new Response('shell-v2', { headers: { 'content-type': 'text/html' } });
  assert.equal(await (await sw.request('index.html')).text(), 'shell-v2');
  sw.state.offline = true;
  assert.equal(await (await sw.request('')).text(), 'shell-v2');
  assert.equal((await sw.request('favicon.png')).type, 'error');
  for (const path of [
    'api/triage', 'jobs/123', 'triageJobs/123', 'auth/callback', '__/auth/handler',
    'storage/photo.jpg', 'assets/personal.json', 'main.dart.js', 'flutter_bootstrap.js',
    'index.html?token=secret', '?code=secret', '../', '../application/index.html',
    'https://firestore.googleapis.com/v1/projects/private',
    'https://firebasestorage.googleapis.com/v0/b/private/o/photo.jpg',
    'https://identitytoolkit.googleapis.com/v1/accounts:signInAnonymously',
  ]) assert.equal(sw.request(path), undefined, path);
  for (const options of [
    { method: 'POST' }, { cache: 'no-store' },
    { headers: new Headers({ Authorization: 'Bearer private' }) },
    { headers: new Headers({ Range: 'bytes=0-99' }) },
  ]) assert.equal(sw.request('index.html', options), undefined);
  for (const call of sw.calls) {
    assert.equal(call.options.credentials, 'omit');
    assert.equal(call.options.cache, 'no-store');
    assert.equal(call.options.redirect, 'error');
  }
  assert.equal(sw.entries.size, 1);
  let activation;
  sw.handlers.activate({ waitUntil: (promise) => { activation = promise; } });
  await activation;
  assert.deepEqual(sw.deleted, ['tradieflow-shell:/app/:v0']);
  assert.equal(sw.state.claimed, true);
});

test('worker does not store private, untyped, error, or redirected responses', async () => {
  for (const headers of [
    { 'content-type': 'text/html', 'cache-control': 'private' },
    { 'content-type': 'text/html', 'cache-control': 'no-store' },
    { 'content-type': 'text/html', vary: 'Cookie' },
    { 'content-type': 'text/html', vary: 'Authorization' },
    { 'content-type': 'text/html', vary: '*' },
    { 'content-type': 'application/json' },
  ]) {
    const sw = worker();
    sw.state.response = () => new Response('do-not-cache', { headers });
    await sw.request('index.html');
    assert.equal(sw.entries.size, 0);
  }
  const sw = worker();
  await sw.request('index.html');
  sw.state.response = () => new Response('unavailable', { status: 503 });
  assert.equal(await (await sw.request('index.html')).text(), 'shell-v1');
  sw.state.response = () => new Response('unauthorized', { status: 401 });
  assert.equal((await sw.request('index.html')).status, 401);
  sw.state.response = () => { throw new TypeError('redirect blocked'); };
  assert.equal(await (await sw.request('index.html')).text(), 'shell-v1');
});

test('worker warms only declared public shell files during installation', async () => {
  const sw = worker();
  sw.state.response = (url) => new Response('static', { headers: {
    'content-type': url.endsWith('.html') ? 'text/html'
      : url.endsWith('.json') ? 'application/manifest+json'
        : url.endsWith('.svg') ? 'image/svg+xml' : 'image/png',
  } });
  let installation;
  sw.handlers.install({ waitUntil: (promise) => { installation = promise; } });
  await installation;
  assert.equal(sw.entries.size, 8);
  assert.ok(sw.entries.has(`${sw.base}index.html`));
});

function page() {
  const window = new EventTarget();
  const elements = new Map();
  for (const id of ['startup-shell', 'startup-status', 'startup-retry', 'connection-hint']) {
    const element = new EventTarget();
    element.hidden = id === 'startup-retry';
    element.remove = () => { element.removed = true; };
    elements.set(id, element);
  }
  let timeout;
  let reloaded = false;
  window.location = { reload: () => { reloaded = true; } };
  const context = {
    window, URL,
    navigator: { onLine: true },
    document: { baseURI: 'https://example.test/app/', getElementById: (id) => elements.get(id) },
    setTimeout: (callback) => { timeout = callback; return 1; },
    clearTimeout: () => { timeout = undefined; },
  };
  const source = read('index.html').match(/<script>\s*([\s\S]*?)<\/script>/)[1];
  runInNewContext(source, context);
  return { context, window, elements, tick: () => timeout?.(), reloaded: () => reloaded };
}

test('shell exposes offline, timeout, failure and retry; only first frame removes it', () => {
  const p = page();
  const status = p.elements.get('startup-status');
  const retry = p.elements.get('startup-retry');
  const shell = p.elements.get('startup-shell');
  p.context.navigator.onLine = false;
  p.window.dispatchEvent(new Event('offline'));
  assert.match(p.elements.get('connection-hint').textContent, /offline/);
  p.tick();
  assert.match(status.textContent, /longer than expected/);
  assert.equal(retry.hidden, false);
  assert.equal(shell.removed, undefined);
  p.window.dispatchEvent(new Event('error'));
  assert.match(status.textContent, /could not start/);
  p.tick();
  assert.match(status.textContent, /could not start/);
  retry.dispatchEvent(new Event('click'));
  assert.equal(p.reloaded(), true);
  p.window.dispatchEvent(new Event('flutter-first-frame'));
  assert.equal(shell.removed, true);
});

test('bootstrap waits for a real frame, catches startup failures and never uses Flutter SW', async () => {
  const p = page();
  let options;
  let registration;
  p.window.isSecureContext = true;
  p.context.navigator.serviceWorker = {
    register: async (url, config) => { registration = { url, config }; },
  };
  p.context._flutter = { loader: { load: async (config) => { options = config; } } };
  const bootstrap = read('flutter_bootstrap.js')
    .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');
  await runInNewContext(bootstrap, p.context);
  assert.equal(options.serviceWorkerSettings, undefined);
  let ran = false;
  await options.onEntrypointLoaded({ initializeEngine: async () => ({ runApp: async () => { ran = true; } }) });
  assert.equal(ran, true);
  assert.equal(registration, undefined);
  assert.equal(p.elements.get('startup-shell').removed, undefined);
  await options.onEntrypointLoaded({ initializeEngine: async () => { throw new Error('engine unavailable'); } });
  assert.match(p.elements.get('startup-status').textContent, /could not start/);
  p.window.dispatchEvent(new Event('flutter-first-frame'));
  assert.equal(registration.url.href, 'https://example.test/app/sw.js');
  assert.equal(registration.config.scope, 'https://example.test/app/');
  assert.equal(registration.config.updateViaCache, 'none');
});

test('manifest, generated PNG dimensions and task commands are valid', () => {
  const manifest = JSON.parse(read('manifest.json'));
  assert.equal(manifest.name, 'TradieFlow AI');
  assert.equal(manifest.short_name, 'TradieFlow');
  assert.equal(manifest.theme_color, '#F1F3F5');
  for (const icon of manifest.icons.filter((icon) => icon.type === 'image/png')) {
    const png = readFileSync(join(__dirname, icon.src));
    assert.deepEqual([...png.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
    const size = Number(icon.sizes.split('x')[0]);
    assert.equal(png.readUInt32BE(16), size);
    assert.equal(png.readUInt32BE(20), size);
    const compressed = [];
    for (let offset = 8; offset < png.length;) {
      const length = png.readUInt32BE(offset);
      if (png.toString('ascii', offset + 4, offset + 8) === 'IDAT') {
        compressed.push(png.subarray(offset + 8, offset + 8 + length));
      }
      offset += 12 + length;
    }
    const pixels = inflateSync(Buffer.concat(compressed));
    assert.equal(pixels.length, size * (1 + size * 3));
    assert.deepEqual([...pixels.subarray(1, 4)], [15, 20, 25]);
    assert.ok(pixels.includes(255));
  }
  const tasks = JSON.parse(read('../.vscode/tasks.json')).tasks;
  assert.equal(tasks.length, 6);
  assert.ok(tasks.some((task) => task.args.includes('--pwa-strategy=none')));
  assert.ok(tasks.every((task) => !task.args.includes('deploy')));
});
