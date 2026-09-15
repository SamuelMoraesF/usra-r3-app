{{flutter_js}}
{{flutter_build_config}}

// The custom service worker is registered by service_worker_client.js. It is
// intentionally not passed to Flutter's loader because updates must be able
// to remain waiting until the user confirms them.
_flutter.loader.load();
