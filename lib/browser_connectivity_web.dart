// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

class BrowserConnectivity {
  BrowserConnectivity() {
    html.window.onOnline.listen((_) => _isOnline = true);
    html.window.onOffline.listen((_) => _isOnline = false);
  }

  bool _isOnline = html.window.navigator.onLine ?? true;

  bool get isOnline => _isOnline;
}

BrowserConnectivity createBrowserConnectivity() => BrowserConnectivity();
