import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:usra_r3/data/session_report_backend_native.dart';
import 'package:usra_r3/data/session_report_wire.dart';

@JS('self')
external JSObject get _scope;

void main() {
  _scope.setProperty(
    'onmessage'.toJS,
    ((JSObject event) {
      generate(event.getProperty<JSObject>('data'.toJS));
    }).toJS,
  );
}

Future<void> generate(JSObject data) async {
  try {
    final bytes = await buildReport(decodeReport(data));
    final pdf = bytes.toJS;
    _scope.callMethod<JSAny?>(
      'postMessage'.toJS,
      {'pdf': pdf}.jsify(),
      [pdf.getProperty<JSArrayBuffer>('buffer'.toJS)].toJS,
    );
  } catch (error) {
    _scope.callMethod<JSAny?>(
      'postMessage'.toJS,
      {'error': error.toString()}.jsify(),
    );
  }
}
