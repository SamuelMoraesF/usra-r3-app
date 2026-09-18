import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'session_report_request.dart';

JSObject encodeReport(SessionReportRequest request) =>
    {
          'metadata': jsonEncode(request.metadata),
          'logo': request.logoBytes.toJS,
          'maps': request.mapImages.map(
            (key, bytes) => MapEntry(key, bytes.toJS),
          ),
        }.jsify()!
        as JSObject;

SessionReportRequest decodeReport(JSObject data) {
  final maps = data.getProperty<JSObject>('maps'.toJS);
  return SessionReportRequest.fromMetadata(
    jsonDecode(data.getProperty<JSString>('metadata'.toJS).toDart)
        as Map<String, dynamic>,
    data.getProperty<JSUint8Array>('logo'.toJS).toDart,
    {
      for (final mode in ['simplex', 'repeater'])
        if (maps.getProperty<JSUint8Array?>(mode.toJS) case final bytes?)
          mode: bytes.toDart,
    },
  );
}
