'use strict';

(async () => {
  if (!('serviceWorker' in navigator)) return;

  try {
    const registration = await navigator.serviceWorker.register('service_worker.js', {
      updateViaCache: 'none',
    });

    const announceIfWaiting = () => {
      if (registration.waiting) {
        registration.waiting.postMessage({
          type: 'usra-new-version-available',
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
