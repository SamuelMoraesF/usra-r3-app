import 'dart:js_interop';
import 'dart:js_interop_unsafe';

Future<void> registerPmtilesProtocol() async {
  globalContext.callMethod<JSAny?>('registerUsraPmtiles'.toJS);
}
