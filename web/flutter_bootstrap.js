{{flutter_js}}
{{flutter_build_config}}

(async function startApp() {
  try {
    if ('serviceWorker' in navigator) {
      const registrations = await navigator.serviceWorker.getRegistrations();
      await Promise.all(registrations.map((registration) => registration.unregister()));
    }
    if (window.caches) {
      const keys = await caches.keys();
      await Promise.all(keys.map((key) => caches.delete(key)));
    }
  } catch (error) {
    console.warn('Failed to clear old web cache', error);
  }

  _flutter.loader.load({
    onEntrypointLoaded: async function(engineInitializer) {
      try {
        const appRunner = await engineInitializer.initializeEngine({
          canvasKitBaseUrl: "/canvaskit/",
        });
        await appRunner.runApp();
        document.getElementById('app-loading')?.remove();
      } catch (error) {
        console.error('Flutter app failed to start', error);
        const failed = document.getElementById('app-failed');
        const loading = document.getElementById('app-loading');
        if (failed) failed.hidden = false;
        if (loading) loading.hidden = true;
      }
    }
  }).catch(function(error) {
    console.error('Flutter loader failed', error);
    const failed = document.getElementById('app-failed');
    const loading = document.getElementById('app-loading');
    if (failed) failed.hidden = false;
    if (loading) loading.hidden = true;
  });
})();
