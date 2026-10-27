{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({config: {canvasKitBaseUrl: 'canvaskit/'}});
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('rsa_service_worker.js').catch(console.warn);
  });
}
