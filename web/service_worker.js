'use strict';

const VERSION = new URL(self.location.href).searchParams.get('v') || 'dev';
const CACHE_NAME = `usra-r3-${VERSION}`;
const SHELL = [
  './',
  './index.html',
  './flutter_bootstrap.js',
  './flutter.js',
  './main.dart.js',
  './manifest.json',
  './favicon.png',
  './pmtiles.js',
  './pmtiles_init.js',
  './drift_worker.js',
  './sqlite3.wasm',
  './canvaskit/canvaskit.js',
  './canvaskit/canvaskit.wasm',
];

async function notifyClients() {
  const clients = await self.clients.matchAll({
    type: 'window',
    includeUncontrolled: true,
  });
  for (const client of clients) {
    client.postMessage({type: 'usra-new-version-available'});
  }
}

async function cacheResponse(request, response) {
  if (!response || !response.ok) return response;
  try {
    const cache = await caches.open(CACHE_NAME);
    await cache.put(request, response.clone());
  } catch (_) {
    // Cache API rejects 206 Partial Content responses. The original response
    // must still be returned to MapLibre/PMTiles.
  }
  return response;
}

function isPmtiles(request) {
  return new URL(request.url).pathname.endsWith('.pmtiles');
}

function pmtilesCacheKey(request) {
  return new Request(new URL(request.url).href);
}

async function responseForRange(response, request) {
  const range = request.headers.get('range');
  if (!range || response.status === 206) return response;

  const match = /^bytes=(\d+)-(\d+)?$/i.exec(range);
  if (!match) return response;
  const bytes = await response.arrayBuffer();
  const start = Number(match[1]);
  const requestedEnd = match[2] ? Number(match[2]) : bytes.byteLength - 1;
  const end = Math.min(requestedEnd, bytes.byteLength - 1);
  if (start > end || start >= bytes.byteLength) return response;

  return new Response(bytes.slice(start, end + 1), {
    status: 206,
    headers: {
      'Accept-Ranges': 'bytes',
      'Content-Length': String(end - start + 1),
      'Content-Range': `bytes ${start}-${end}/${bytes.byteLength}`,
      'Content-Type': response.headers.get('content-type') || 'application/octet-stream',
    },
  });
}

async function handlePmtiles(request, event) {
  const cache = await caches.open(CACHE_NAME);
  const key = pmtilesCacheKey(request);
  const full = await cache.match(key);
  if (full) return responseForRange(full, request);

  const response = await fetch(request);
  if (response.ok && response.status !== 206) {
    await cache.put(key, response.clone());
    return responseForRange(response, request);
  }

  if (response.ok && response.status === 206) {
    // Keep the first range request fast, then persist the complete map for
    // subsequent offline sessions. This is deliberately not awaited.
    event.waitUntil((async () => {
      try {
        const complete = await fetch(key);
        if (complete.ok && complete.status === 200) {
          await cache.put(key, complete.clone());
        }
      } catch (_) {
        // The current range response remains usable online.
      }
    })());
  }
  return response;
}

async function refreshInBackground(request) {
  try {
    await cacheResponse(request, await fetch(request));
  } catch (_) {
    // The cached shell remains the source of truth while offline.
  }
}

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await Promise.all(SHELL.map(async (url) => {
      try {
        await cache.add(url);
      } catch (_) {
        // Optional renderer files vary by Flutter/browser build.
      }
    }));
    // Do not show an update prompt during the first installation.
    if (self.registration.active) await notifyClients();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names
      .filter((name) => name.startsWith('usra-r3-') && name !== CACHE_NAME)
      .map((name) => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener('message', (event) => {
  if (event.data?.type === 'usra-activate-new-version') {
    self.skipWaiting();
  } else if (event.data?.type === 'usra-new-version-available') {
    notifyClients();
  }
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) {
    return;
  }

  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      const cache = await caches.open(CACHE_NAME);
      const cached = await cache.match(request) || await cache.match('./index.html');
      // Return the local shell immediately. Refreshing in the background means
      // F5 remains usable offline and the next load sees the newest artifact.
      event.waitUntil(refreshInBackground(request));
      return cached || fetch(request).then((response) => cacheResponse(request, response));
    })());
    return;
  }

  if (isPmtiles(request)) {
    event.respondWith((async () => {
      try {
        return await handlePmtiles(request, event);
      } catch (_) {
        const cached = await caches.match(pmtilesCacheKey(request));
        if (cached) return responseForRange(cached, request);
        return new Response('', {status: 503, statusText: 'Offline'});
      }
    })());
    return;
  }

  event.respondWith((async () => {
    const cached = await caches.match(request);
    if (cached) {
      event.waitUntil(refreshInBackground(request));
      return cached;
    }
    try {
      return await cacheResponse(request, await fetch(request));
    } catch (_) {
      return new Response('', {status: 503, statusText: 'Offline'});
    }
  })());
});
