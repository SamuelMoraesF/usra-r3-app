import 'dart:typed_data';

/// Pure Dart snapshot: no database or Flutter dependencies in the worker.
class ReportEntry {
  ReportEntry(this.values);
  final Map<String, dynamic> values;
  DateTime get createdAt => DateTime.parse(values['createdAt'] as String);
  double? get frequencyMhz => (values['frequencyMhz'] as num?)?.toDouble();
  double get powerWatts => (values['powerWatts'] as num).toDouble();
  String get callsign => values['callsign'] as String;
  String get frequency => values['frequency'] as String;
  String get operatorName => values['operatorName'] as String;
  String get via => values['via'] as String;
  String get operatorGrid => values['operatorGrid'] as String;
  String get location => values['location'] as String;
  String get stationType => values['stationType'] as String;
  String get energy => values['energy'] as String;
  String get traffic => values['traffic'] as String;
  String get trafficMessage => values['trafficMessage'] as String;
}

class SessionReportRequest {
  SessionReportRequest({
    required this.entries,
    required this.control,
    required this.opening,
    required this.closing,
    required this.logoBytes,
    this.mapImages = const {},
  });
  final List<ReportEntry> entries;
  final String control;
  final String opening;
  final String closing;
  final Uint8List logoBytes;
  final Map<String, Uint8List> mapImages;

  Map<String, dynamic> get metadata => {
    'entries': entries.map((entry) => entry.values).toList(),
    'control': control,
    'opening': opening,
    'closing': closing,
  };

  factory SessionReportRequest.fromMetadata(
    Map<String, dynamic> metadata,
    Uint8List logoBytes,
    Map<String, Uint8List> mapImages,
  ) => SessionReportRequest(
    entries: (metadata['entries'] as List)
        .map((entry) => ReportEntry(Map<String, dynamic>.from(entry as Map)))
        .toList(),
    control: metadata['control'] as String,
    opening: metadata['opening'] as String,
    closing: metadata['closing'] as String,
    logoBytes: logoBytes,
    mapImages: mapImages,
  );
}
