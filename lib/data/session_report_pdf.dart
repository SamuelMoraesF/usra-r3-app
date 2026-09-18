import 'dart:typed_data';

import 'database.dart';
import 'session_report_request.dart';
import 'session_report_backend_native.dart'
    if (dart.library.js_interop) 'session_report_backend_web.dart'
    as backend;

class SessionReportPdf {
  static Future<Uint8List> build({
    required List<LogEntry> entries,
    required String control,
    required String opening,
    required String closing,
    required Uint8List logoBytes,
    Map<String, Uint8List> mapImages = const {},
  }) => backend.buildReport(
    SessionReportRequest(
      entries: entries
          .map(
            (entry) => ReportEntry({
              'createdAt': entry.createdAt.toUtc().toIso8601String(),
              'callsign': entry.callsign,
              'frequency': entry.frequency,
              'frequencyMhz': entry.frequencyMhz,
              'operatorName': entry.operatorName,
              'via': entry.via,
              'operatorGrid': entry.operatorGrid,
              'location': entry.location,
              'stationType': entry.stationType,
              'powerWatts': entry.powerWatts,
              'energy': entry.energy,
              'traffic': entry.traffic,
              'trafficMessage': entry.trafficMessage,
            }),
          )
          .toList(),
      control: control,
      opening: opening,
      closing: closing,
      logoBytes: logoBytes,
      mapImages: mapImages,
    ),
  );
}
