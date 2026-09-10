import 'database.dart';

const csvHeaders = [
  'created_at',
  'callsign',
  'operator_name',
  'location',
  'operator_grid',
  'power_watts',
  'station_type',
  'traffic',
];

String logsToCsv(List<LogEntry> entries) {
  final rows = <List<String>>[csvHeaders];
  for (final entry in entries) {
    rows.add([
      entry.createdAt.toUtc().toIso8601String(),
      entry.callsign,
      entry.operatorName,
      entry.location,
      entry.operatorGrid,
      entry.powerWatts.toString(),
      entry.stationType,
      entry.traffic,
    ]);
  }
  return rows.map((row) => row.map(_escapeCsv).join(',')).join('\r\n');
}

List<LogEntriesCompanion> csvToLogCompanions(String source) {
  final rows = _parseCsv(source);
  if (rows.isEmpty || rows.first.map(_normalizeHeader).toList().join(',') != csvHeaders.join(',')) {
    throw const FormatException('Cabeçalho CSV inválido.');
  }
  final result = <LogEntriesCompanion>[];
  for (var index = 1; index < rows.length; index++) {
    final row = rows[index];
    if (row.length == 1 && row.first.trim().isEmpty) continue;
    if (row.length != csvHeaders.length) {
      throw FormatException('Linha ${index + 1} inválida.');
    }
    final createdAt = DateTime.tryParse(row[0]);
    final power = double.tryParse(row[5].replaceAll(',', '.'));
    if (createdAt == null || power == null || row[1].trim().isEmpty) {
      throw FormatException('Dados inválidos na linha ${index + 1}.');
    }
    result.add(LogEntriesCompanion.insert(
      createdAt: createdAt.toUtc(),
      callsign: row[1].trim().toUpperCase(),
      operatorName: row[2].trim(),
      location: row[3].trim(),
      operatorGrid: row[4].trim().toUpperCase(),
      powerWatts: power,
      stationType: row[6].trim().toUpperCase(),
      traffic: row[7].trim().toUpperCase(),
    ));
  }
  return result;
}

String _escapeCsv(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _normalizeHeader(String value) => value.trim().toLowerCase();

List<List<String>> _parseCsv(String source) {
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var quoted = false;
  for (var index = 0; index < source.length; index++) {
    final character = source[index];
    if (character == '"') {
      if (quoted && index + 1 < source.length && source[index + 1] == '"') {
        field.write('"');
        index++;
      } else {
        quoted = !quoted;
      }
    } else if (character == ',' && !quoted) {
      row.add(field.toString());
      field = StringBuffer();
    } else if ((character == '\n' || character == '\r') && !quoted) {
      if (character == '\r' && index + 1 < source.length && source[index + 1] == '\n') index++;
      row.add(field.toString());
      rows.add(row);
      row = <String>[];
      field = StringBuffer();
    } else {
      field.write(character);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  if (quoted) throw const FormatException('CSV possui aspas não fechadas.');
  return rows;
}
