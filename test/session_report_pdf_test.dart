import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:usra_r3/data/database.dart';
import 'package:usra_r3/data/session_report_pdf.dart';
import 'package:usra_r3/data/session_report_request.dart';

void main() {
  test('report metadata survives JSON without changing UTC or values', () {
    final values = <String, dynamic>{
      'createdAt': '2026-09-17T12:00:00.000Z',
      'callsign': 'PY3TEST',
      'frequency': 'simplex',
      'frequencyMhz': 146.52,
      'operatorName': 'João',
      'via': 'PY3VIA',
      'operatorGrid': 'GG30DH',
      'location': 'Local anotado',
      'stationType': 'F',
      'powerWatts': 25.0,
      'energy': 'AC',
      'traffic': 'C',
      'trafficMessage': 'Mensagem recebida',
    };
    final logo = Uint8List.fromList([1, 2]);
    final maps = {
      'simplex': Uint8List.fromList([3, 4]),
    };
    final request = SessionReportRequest(
      entries: [ReportEntry(values)],
      control: 'PY3NCS',
      opening: '09:00 GMT-3',
      closing: '09:30 GMT-3',
      logoBytes: logo,
      mapImages: maps,
    );
    final restored = SessionReportRequest.fromMetadata(
      jsonDecode(jsonEncode(request.metadata)) as Map<String, dynamic>,
      logo,
      maps,
    );
    expect(restored.metadata, request.metadata);
    expect(restored.entries.single.createdAt, DateTime.utc(2026, 9, 17, 12));
    expect(restored.entries.single.createdAt.isUtc, isTrue);
    expect(restored.entries.single.powerWatts, 25.0);
    expect(restored.logoBytes, same(logo));
    expect(restored.mapImages, same(maps));
  });

  test(
    'native facade still builds PDF with both frequencies and images',
    () async {
      final logo = await File('assets/branding/report_logo.png').readAsBytes();
      final bytes = await SessionReportPdf.build(
        entries: [
          for (final mode in ['simplex', 'repeater'])
            LogEntry(
              id: 1,
              createdAt: DateTime.utc(2026, 9, 17, 12),
              callsign: 'PY3TEST',
              frequency: mode,
              frequencyMhz: mode == 'simplex' ? 146.52 : 145.37,
              via: '',
              energy: 'AC',
              operatorName: 'João',
              location: 'Local anotado',
              operatorGrid: 'GG30DH',
              powerWatts: 25,
              stationType: 'F',
              traffic: 'C',
              trafficMessage: 'Mensagem recebida',
            ),
        ],
        control: 'PY3NCS',
        opening: '09:00 GMT-3',
        closing: '09:30 GMT-3',
        logoBytes: logo,
        mapImages: {'simplex': logo, 'repeater': logo},
      );
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(ascii.decode(bytes.sublist(bytes.length - 6)).trim(), '%%EOF');
    },
  );
}
