'use strict';

// One-shot cleanup worker for phones that still have an old Flutter SW.
self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    (async function () {
      try {
        var keys = await caches.keys();
        await Promise.all(keys.map(function (key) { return caches.delete(key); }));
      } catch (_) {}

      try {
        await self.registration.unregister();
      } catch (_) {}

      try {
        var clients = await self.clients.matchAll({
          type: 'window',
          includeUncontrolled: true,
        });
        clients.forEach(function (client) {
          if (client.url && 'navigate' in client) {
            client.navigate(client.url);
          }
        });
      } catch (_) {}
    })(),
  );
});
