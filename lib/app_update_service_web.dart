// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

class AppUpdateService {
  AppUpdateService() {
    html.window.navigator.serviceWorker?.onMessage.listen((event) {
      if (event.data is Map &&
          (event.data as Map)['type'] == 'usra-new-version-available') {
        _updates.add(null);
      }
    });
  }

  final _updates = StreamController<void>.broadcast();

  Stream<void> get updates => _updates.stream;

  Future<void> activate() async {
    final registration = await html.window.navigator.serviceWorker?.ready;
    registration?.waiting?.postMessage({'type': 'usra-activate-new-version'});
    // Give skipWaiting/activate time to take control before reloading.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    html.window.location.reload();
  }

  Future<void> checkForUpdate() async {
    final registration = await html.window.navigator.serviceWorker?.ready;
    await registration?.update();
    if (registration?.waiting != null) _updates.add(null);
  }

  Future<void> clearCache() async {
    final registration = await html.window.navigator.serviceWorker?.ready;
    registration?.active?.postMessage({'type': 'usra-clear-cache'});
    await Future<void>.delayed(const Duration(milliseconds: 300));
    html.window.location.reload();
  }
}

AppUpdateService createAppUpdateService() => AppUpdateService();
