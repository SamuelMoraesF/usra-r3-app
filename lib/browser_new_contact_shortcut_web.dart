import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class BrowserNewContactShortcut {
  BrowserNewContactShortcut(this._listener);

  final JSFunction _listener;

  void dispose() {
    globalContext.callMethod<JSAny?>(
      'removeEventListener'.toJS,
      'keydown'.toJS,
      _listener,
    );
  }
}

BrowserNewContactShortcut installBrowserNewContactShortcut(
  void Function() onNewContact,
) {
  final listener = ((JSAny event) {
    final keyboardEvent = event as JSObject;
    final ctrlKey = keyboardEvent.getProperty<JSBoolean>('ctrlKey'.toJS);
    final shiftKey = keyboardEvent.getProperty<JSBoolean>('shiftKey'.toJS);
    final key = keyboardEvent.getProperty<JSString?>('key'.toJS);
    if ((ctrlKey.toDart || shiftKey.toDart) &&
        key?.toDart.toLowerCase() == 'n') {
      keyboardEvent.callMethod<JSAny?>('preventDefault'.toJS);
      onNewContact();
    }
  }).toJS;
  globalContext.callMethod<JSAny?>(
    'addEventListener'.toJS,
    'keydown'.toJS,
    listener,
  );
  return BrowserNewContactShortcut(listener);
}
