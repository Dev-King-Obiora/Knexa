const VERSION = 'knexa-v2';
const STATIC = `${VERSION}-static`;
const PRECACHE = ['/', '/index.html', '/manifest.json',
  '/icons/icon-192.png', '/icons/icon-512.png', '/icons/icon-maskable-512.png'];
const CDN_HOSTS = ['cdn.jsdelivr.net', 'fonts.googleapis.com', 'fonts.gstatic.com'];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(STATIC)
      .then(c => Promise.allSettled(PRECACHE.map(u => c.add(u))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k.startsWith('knexa-') && k !== STATIC).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // Never cache or intercept private API traffic, payments or the backend host.
  if (url.pathname.startsWith('/api/') || url.hostname.endsWith('onrender.com') || url.hostname.includes('paystack')) return;

  if (req.mode === 'navigate') {
    e.respondWith(networkFirstPage(req));
    return;
  }
  if (url.origin === self.location.origin || CDN_HOSTS.includes(url.hostname)) {
    e.respondWith(staleWhileRevalidate(req));
  }
});

// Only the public app shell is stored, under a fixed key. Nothing with tokens, payment references or account data.
async function networkFirstPage(req) {
  const cache = await caches.open(STATIC);
  try {
    const res = await fetch(req);
    if (res.ok) cache.put('/index.html', res.clone());
    return res;
  } catch {
    return (await cache.match('/index.html')) || (await cache.match('/')) || offlineResponse();
  }
}

async function staleWhileRevalidate(req) {
  const cache = await caches.open(STATIC);
  const cached = await cache.match(req);
  const network = fetch(req)
    .then(res => { if (res.ok || res.type === 'opaque') cache.put(req, res.clone()); return res; })
    .catch(() => cached);
  return cached || network;
}

function offlineResponse() {
  const html = `<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Offline · Knexa AI</title>
<body style="font-family:system-ui,sans-serif;background:#f5f3ee;color:#121c2b;display:grid;place-items:center;min-height:100vh;margin:0;text-align:center;padding:24px">
<div><h1 style="font-weight:600">You are offline</h1>
<p style="color:#5d6878;max-width:360px;margin:auto">Knexa AI needs a connection to solve questions and run exams. Reconnect and try again.</p>
<button onclick="location.reload()" style="margin-top:16px;padding:12px 20px;border:0;border-radius:12px;background:#1c3556;color:#fff;font-weight:700">Retry</button></div></body>`;
  return new Response(html, { status: 503, headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' } });
}