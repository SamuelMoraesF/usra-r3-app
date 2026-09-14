import 'database.dart';
import 'package:drift/drift.dart' show Value;

const csvHeaders = [
  'created_at',
  'callsign',
  'operator_name',
  'location',
  'operator_grid',
  'power_watts',
  'station_type',
  'traffic',
  'via',
  'frequency',
  'frequency_mhz',
  'repeater_grid',
  'energy',
  'traffic_message',
  'network_started_at',
  'network_ended_at',
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
      entry.via,
      entry.frequency,
      entry.frequencyMhz?.toString() ?? '',
      entry.repeaterGrid ?? '',
      entry.energy,
      entry.trafficMessage,
      entry.networkStartedAt?.toUtc().toIso8601String() ?? '',
      entry.networkEndedAt?.toUtc().toIso8601String() ?? '',
    ]);
  }
  return rows.map((row) => row.map(_escapeCsv).join(',')).join('\r\n');
}

List<LogEntriesCompanion> csvToLogCompanions(String source) {
  final rows = _parseCsv(source);
  final headers = rows.isEmpty
      ? <String>[]
      : rows.first.map(_normalizeHeader).toList();
  final legacy = headers.join(',') == csvHeaders.take(8).join(',');
  final withoutNetwork = headers.join(',') == csvHeaders.take(14).join(',');
  if (rows.isEmpty ||
      (!legacy &&
          !withoutNetwork &&
          headers.join(',') != csvHeaders.join(','))) {
    throw const FormatException('Cabeçalho CSV inválido.');
  }
  final result = <LogEntriesCompanion>[];
  for (var index = 1; index < rows.length; index++) {
    final row = rows[index];
    if (row.length == 1 && row.first.trim().isEmpty) continue;
    final missingNetworkColumns =
        headers.length == csvHeaders.length && row.length == 14;
    if (row.length != headers.length && !missingNetworkColumns) {
      throw FormatException('Linha ${index + 1} inválida.');
    }
    final timestamp = row[0].trim();
    final hasTime = RegExp(r'[Tt ]').hasMatch(timestamp);
    final hasZone =
        hasTime &&
        RegExp(r'(?:[zZ]|[+-]\d{2}(?::?\d{2})?)$').hasMatch(timestamp);
    // CSV without an offset is UTC, independent of the importing device.
    final createdAt = DateTime.tryParse(
      hasZone ? timestamp : '$timestamp${hasTime ? 'Z' : 'T00:00:00Z'}',
    );
    final power = double.tryParse(row[5].replaceAll(',', '.'));
    final mhz = legacy || row[10].isEmpty ? null : double.tryParse(row[10]);
    final networkStart =
        !legacy &&
            !missingNetworkColumns &&
            row.length > 14 &&
            row[14].isNotEmpty
        ? DateTime.tryParse(row[14])?.toUtc()
        : null;
    final networkEnd =
        !legacy &&
            !missingNetworkColumns &&
            row.length > 15 &&
            row[15].isNotEmpty
        ? DateTime.tryParse(row[15])?.toUtc()
        : null;
    if (!legacy &&
        (!['simplex', 'repeater'].contains(row[9]) ||
            (row[10].isNotEmpty &&
                (mhz == null || !mhz.isFinite || mhz <= 0)))) {
      throw FormatException('Frequência inválida na linha ${index + 1}.');
    }
    if (createdAt == null || power == null || row[1].trim().isEmpty) {
      throw FormatException('Dados inválidos na linha ${index + 1}.');
    }
    result.add(
      LogEntriesCompanion.insert(
        createdAt: createdAt.toUtc(),
        callsign: row[1].trim().toUpperCase(),
        operatorName: row[2].trim(),
        location: row[3].trim(),
        operatorGrid: row[4].trim().toUpperCase(),
        powerWatts: power,
        stationType: row[6].trim().toUpperCase(),
        traffic: row[7].trim().toUpperCase(),
        via: legacy ? const Value.absent() : Value(row[8].trim().toUpperCase()),
        frequency: legacy ? const Value.absent() : Value(row[9]),
        frequencyMhz: Value(mhz),
        repeaterGrid: Value(
          legacy || row[11].isEmpty ? null : row[11].trim().toUpperCase(),
        ),
        energy: legacy ? const Value.absent() : Value(row[12]),
        trafficMessage: legacy ? const Value.absent() : Value(row[13]),
        networkStartedAt: Value(networkStart),
        networkEndedAt: Value(networkEnd),
      ),
    );
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
      if (character == '\r' &&
          index + 1 < source.length &&
          source[index + 1] == '\n') {
        index++;
      }
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
