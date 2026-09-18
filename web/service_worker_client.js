'use strict';

(async () => {
  if (!('serviceWorker' in navigator)) return;

  const isLocalDevelopment =
    window.location.hostname === 'localhost' ||
    window.location.hostname === '127.0.0.1';

  if (isLocalDevelopment) {
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      window.location.reload();
    }, {once: true});
  }

  try {
    // Replaced by the release pipeline in build/web.
    const version = '__USRA_WEB_VERSION__';
    const registration = await navigator.serviceWorker.register(`service_worker.js?v=${encodeURIComponent(version)}`, {
      updateViaCache: 'none',
    });

    const announceIfWaiting = () => {
      if (registration.waiting) {
        registration.waiting.postMessage({
          type: isLocalDevelopment
            ? 'usra-activate-new-version'
            : 'usra-new-version-available',
        });
      }
    };

    registration.addEventListener('updatefound', () => {
      const worker = registration.installing;
      worker?.addEventListener('statechange', () => {
        if (worker.state === 'installed' && navigator.serviceWorker.controller) {
          announceIfWaiting();
        }
      });
    });
    announceIfWaiting();
  } catch (error) {
    console.warn('USRA service worker registration failed:', error);
  }
})();
