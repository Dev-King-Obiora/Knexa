'use strict';

const CACHE_NAME = 'knexa-shell-v1';
const SHELL_URLS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/offline.html',
  '/icons/knexa.svg',
  '/icons/knexa-192.png',
  '/icons/knexa-512.png',
  '/icons/knexa-maskable-512.png'
];
const STATIC_PATHS = new Set(SHELL_URLS.filter(path => path !== '/' && path !== '/index.html'));
const APP_DOCUMENT_PATHS = new Set(['/', '/index.html']);

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await Promise.all(SHELL_URLS.map(async path => {
      try {
        const response = await fetch(path, { cache: 'reload', credentials: 'same-origin' });
        if (response.ok && response.type === 'basic') {
          await cache.put(path, response);
        }
      } catch (_) {
        // A partial precache is safer than failing installation entirely.
      }
    }));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter(name => name.startsWith('knexa-') && name !== CACHE_NAME)
      .map(name => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET' || request.headers.has('authorization')) return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // Never store API, account, exam, payment, admin-data or health responses.
  if (url.pathname.startsWith('/api/') || url.pathname === '/health' || url.pathname === '/admin') return;

  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      try {
        const response = await fetch(request);
        // Only cache the public, static application document at its canonical URL.
        if (response.ok && APP_DOCUMENT_PATHS.has(url.pathname) && !url.search && response.type === 'basic') {
          const cache = await caches.open(CACHE_NAME);
          await cache.put('/', response.clone());
        }
        return response;
      } catch (_) {
        const cache = await caches.open(CACHE_NAME);
        return (await cache.match('/')) || (await cache.match('/offline.html')) ||
          new Response('Knexa AI is offline. Reconnect to continue using AI solving, practice and exams.', {
            status: 503, headers: { 'Content-Type': 'text/plain; charset=utf-8' }
          });
      }
    })());
    return;
  }

  if (STATIC_PATHS.has(url.pathname)) {
    event.respondWith((async () => {
      const cache = await caches.open(CACHE_NAME);
      const cached = await cache.match(url.pathname);
      if (cached) return cached;
      try {
        const response = await fetch(request);
        if (response.ok && response.type === 'basic') await cache.put(url.pathname, response.clone());
        return response;
      } catch (_) {
        return new Response('', { status: 503, statusText: 'Offline' });
      }
    })());
  }
});
