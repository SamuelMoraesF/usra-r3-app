import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void toggleBrowserFullscreen() {
  final document = globalContext.getProperty<JSObject>('document'.toJS);
  final fullscreenElement = document.getProperty<JSAny?>(
    'fullscreenElement'.toJS,
  );
  if (fullscreenElement != null) {
    document.callMethod<JSAny?>('exitFullscreen'.toJS);
    return;
  }
  final documentElement = document.getProperty<JSObject>(
    'documentElement'.toJS,
  );
  documentElement.callMethod<JSAny?>('requestFullscreen'.toJS);
}
