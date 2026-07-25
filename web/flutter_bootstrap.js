{{flutter_js}}
{{flutter_build_config}}

// Clear stale PWA caches / service workers before bootstrapping.
// Fixes iOS home-screen apps stuck on old Flutter builds after deploy.
(async function bootstrapRetailPilot() {
  async function clearStaleWebCache() {
    try {
      if ('caches' in window) {
        const keys = await caches.keys();
        await Promise.all(keys.map((key) => caches.delete(key)));
      }
    } catch (e) {
      console.warn('Failed to clear Cache Storage:', e);
    }

    try {
      if ('serviceWorker' in navigator) {
        const registrations = await navigator.serviceWorker.getRegistrations();
        await Promise.all(registrations.map((registration) => registration.unregister()));
      }
    } catch (e) {
      console.warn('Failed to unregister service workers:', e);
    }
  }

  var hadController = false;
  try {
    hadController = !!(navigator.serviceWorker && navigator.serviceWorker.controller);
  } catch (_) {}

  await clearStaleWebCache();

  // Unregister does not detach the current page until the next navigation.
  if (hadController) {
    window.location.reload();
    return;
  }

  // Do not pass serviceWorkerSettings — avoid re-registering any worker.
  _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
    },
  });
})();
