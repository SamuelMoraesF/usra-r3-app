import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'session_report_request.dart';
import 'session_report_wire.dart';

@JS('Worker')
extension type _ReportWorker._(JSObject _) implements JSObject {
  external factory _ReportWorker(JSString url);
  external set onmessage(JSFunction? callback);
  external set onerror(JSFunction? callback);
  external set onmessageerror(JSFunction? callback);
  external void postMessage(JSObject data);
  external void terminate();
}

@JS('document.baseURI')
external JSString get _baseUri;

/// A dedicated worker per export; never falls back to blocking the UI thread.
Future<Uint8List> buildReport(SessionReportRequest request) async {
  final worker = _ReportWorker(
    Uri.parse(_baseUri.toDart).resolve('report_pdf_worker.js').toString().toJS,
  );
  final result = Completer<Uint8List>();
  void fail(Object error, [StackTrace? stack]) {
    if (!result.isCompleted) result.completeError(error, stack);
  }

  try {
    worker.onmessage = ((JSObject event) {
      try {
        final data = event.getProperty<JSObject>('data'.toJS);
        final error = data.getProperty<JSString?>('error'.toJS);
        if (error != null) {
          fail(StateError(error.toDart));
        } else if (!result.isCompleted) {
          result.complete(data.getProperty<JSUint8Array>('pdf'.toJS).toDart);
        }
      } catch (error, stack) {
        fail(error, stack);
      }
    }).toJS;
    worker.onerror = ((JSObject event) {
      fail(
        StateError(
          'Falha no Worker de PDF: '
          '${event.getProperty<JSString?>('message'.toJS)?.toDart ?? 'não foi possível carregar o Worker'}',
        ),
      );
    }).toJS;
    worker.onmessageerror = ((JSObject event) {
      fail(StateError('Não foi possível receber o PDF do Worker.'));
    }).toJS;
    // Structured clone preserves ownership of the captured map/logo buffers.
    worker.postMessage(encodeReport(request));
    return await result.future.timeout(const Duration(minutes: 2));
  } finally {
    worker.terminate();
  }
}
