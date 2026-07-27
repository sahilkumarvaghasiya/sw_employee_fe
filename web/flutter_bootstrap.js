{{flutter_js}}
{{flutter_build_config}}

// Do not register a service worker. Flutter re-registers only when one already
// exists, which traps previously-installed iOS PWAs on old cached builds.
(async function bootstrapRetailPilot() {
  var reloadFlag = 'rp_sw_cleanup_reload';

  async function clearStaleWebCache() {
    try {
      if ('caches' in window) {
        var keys = await caches.keys();
        await Promise.all(keys.map(function (key) { return caches.delete(key); }));
      }
    } catch (_) {}

    try {
      if ('serviceWorker' in navigator) {
        var registrations = await navigator.serviceWorker.getRegistrations();
        await Promise.all(
          registrations.map(function (registration) {
            return registration.unregister();
          }),
        );
      }
    } catch (_) {}
  }

  function hardReloadOnce() {
    try {
      if (sessionStorage.getItem(reloadFlag) === '1') {
        sessionStorage.removeItem(reloadFlag);
        return false;
      }
      sessionStorage.setItem(reloadFlag, '1');
    } catch (_) {}

    try {
      var url = new URL(window.location.href);
      url.searchParams.set('_swclear', String(Date.now()));
      window.location.replace(url.toString());
    } catch (_) {
      window.location.reload();
    }
    return true;
  }

  var hadController = false;
  try {
    hadController = !!(
      navigator.serviceWorker && navigator.serviceWorker.controller
    );
  } catch (_) {}

  await clearStaleWebCache();

  if (hadController && hardReloadOnce()) {
    return;
  }

  try {
    sessionStorage.removeItem(reloadFlag);
  } catch (_) {}

  _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      var appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
    },
  });
})();
