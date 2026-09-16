import 'dart:js_interop';
import 'dart:js_interop_unsafe';

Future<void> registerPmtilesProtocol() async {
  final promise = globalContext.callMethod<JSPromise<JSAny?>>(
    'registerUsraPmtiles'.toJS,
  );
  await promise.toDart;
}
