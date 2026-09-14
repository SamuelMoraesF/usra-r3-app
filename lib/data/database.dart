import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class UtcDateTimeConverter extends TypeConverter<DateTime, int> {
  const UtcDateTimeConverter();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMicrosecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.toUtc().microsecondsSinceEpoch;
}

class LogEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get createdAt =>
      integer().named('created_at_utc').map(const UtcDateTimeConverter())();
  TextColumn get callsign => text()();
  TextColumn get via => text().withDefault(const Constant(''))();
  TextColumn get frequency => text().withDefault(const Constant('repeater'))();
  RealColumn get frequencyMhz => real().nullable()();
  TextColumn get repeaterGrid => text().nullable()();
  TextColumn get energy => text().withDefault(const Constant('B'))();
  TextColumn get operatorName => text()();
  TextColumn get location => text()();
  TextColumn get operatorGrid => text()();
  RealColumn get powerWatts => real()();
  TextColumn get stationType => text()();
  TextColumn get traffic => text()();
  TextColumn get trafficMessage => text().withDefault(const Constant(''))();
  IntColumn get networkStartedAt => integer()
      .nullable()
      .named('network_started_at_utc')
      .map(const UtcDateTimeConverter())();
  IntColumn get networkEndedAt => integer()
      .nullable()
      .named('network_ended_at_utc')
      .map(const UtcDateTimeConverter())();
}

@DriftDatabase(tables: [LogEntries])
class UsraDatabase extends _$UsraDatabase {
  UsraDatabase()
    : super(
        driftDatabase(
          name: 'usra_r3_logbook',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  UsraDatabase.test(super.e);

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 4) {
        // Some early web builds reported schema version 2 before applying
        // this column migration. Check the actual table so those databases
        // are repaired without touching existing log entries.
        final columns = await m.database
            .customSelect('PRAGMA table_info(log_entries)')
            .get();
        final hasOperatorGrid = columns.any(
          (row) => row.data['name'] == 'operator_grid',
        );
        if (!hasOperatorGrid) {
          await m.addColumn(logEntries, logEntries.operatorGrid);
        }
      }
      if (from < 5) {
        await m.addColumn(logEntries, logEntries.trafficMessage);
      }
      if (from < 6) {
        await m.addColumn(logEntries, logEntries.via);
      }
      if (from < 7) {
        await m.addColumn(logEntries, logEntries.frequency);
      }
      if (from < 8) {
        await m.addColumn(logEntries, logEntries.energy);
      }
      if (from < 9) {
        await m.addColumn(logEntries, logEntries.frequencyMhz);
        await m.addColumn(logEntries, logEntries.repeaterGrid);
        await customStatement(
          "UPDATE log_entries SET frequency_mhz = CASE frequency WHEN 'simplex' THEN 146.52 WHEN 'repeater' THEN 145.37 END",
        );
      }
      if (from < 10) {
        await m.addColumn(logEntries, logEntries.networkStartedAt);
        await m.addColumn(logEntries, logEntries.networkEndedAt);
        // Legacy Drift DateTime columns are Unix seconds, already absolute
        // instants. Preserve them while moving to explicit UTC microseconds;
        // never apply the device's offset to existing records.
        await m.alterTable(
          TableMigration(
            logEntries,
            columnTransformer: {
              logEntries.createdAt: const CustomExpression<int>(
                'created_at * 1000000',
              ),
            },
          ),
        );
      }
      if (from < 11 && from >= 10) {
        await m.addColumn(logEntries, logEntries.networkStartedAt);
        await m.addColumn(logEntries, logEntries.networkEndedAt);
      }
    },
  );

  Future<int> saveLog({
    required String callsign,
    String via = '',
    String frequency = 'repeater',
    double? frequencyMhz,
    String? repeaterGrid,
    String energy = 'B',
    required String operatorName,
    required String location,
    required String operatorGrid,
    required double powerWatts,
    required String stationType,
    required String traffic,
    String trafficMessage = '',
    DateTime? networkStartedAt,
    DateTime? networkEndedAt,
  }) {
    return into(logEntries).insert(
      LogEntriesCompanion.insert(
        createdAt: DateTime.now().toUtc(),
        callsign: callsign,
        via: Value(via),
        frequency: Value(frequency),
        frequencyMhz: Value(
          frequencyMhz ?? (frequency == 'simplex' ? 146.52 : 145.37),
        ),
        repeaterGrid: Value(frequency == 'repeater' ? repeaterGrid : null),
        energy: Value(energy),
        operatorName: operatorName,
        location: location,
        operatorGrid: operatorGrid,
        powerWatts: powerWatts,
        stationType: stationType,
        traffic: traffic,
        trafficMessage: Value(trafficMessage),
        networkStartedAt: Value(networkStartedAt),
        networkEndedAt: Value(networkEndedAt),
      ),
    );
  }

  Future<bool> deleteLog(int id) async {
    return await (delete(
          logEntries,
        )..where((entry) => entry.id.equals(id))).go() >
        0;
  }

  Future<bool> updateLog({
    required int id,
    required String callsign,
    String via = '',
    String? frequency,
    double? frequencyMhz,
    String? repeaterGrid,
    String energy = 'B',
    required String operatorName,
    required String location,
    required double powerWatts,
    required String stationType,
    required String traffic,
    String trafficMessage = '',
  }) async {
    return await (update(
          logEntries,
        )..where((entry) => entry.id.equals(id))).write(
          LogEntriesCompanion(
            callsign: Value(callsign),
            via: Value(via),
            frequency: frequency == null
                ? const Value.absent()
                : Value(frequency),
            frequencyMhz: frequencyMhz == null
                ? const Value.absent()
                : Value(frequencyMhz),
            // Null preserves the existing snapshot; an empty value clears it.
            repeaterGrid: repeaterGrid == null
                ? const Value.absent()
                : Value(repeaterGrid.isEmpty ? null : repeaterGrid),
            energy: Value(energy),
            operatorName: Value(operatorName),
            location: Value(location),
            powerWatts: Value(powerWatts),
            stationType: Value(stationType),
            traffic: Value(traffic),
            trafficMessage: Value(trafficMessage),
          ),
        ) >
        0;
  }

  Stream<List<LogEntry>> watchLogs() => (select(
    logEntries,
  )..orderBy([(entry) => OrderingTerm.desc(entry.createdAt)])).watch();

  Future<LogEntry?> latestLogForCallsign(String value, {String? frequency}) {
    return (select(logEntries)
          ..where((entry) => entry.callsign.equals(value.trim().toUpperCase()))
          ..where(
            (entry) => frequency == null
                ? const Constant(true)
                : entry.frequency.equals(frequency),
          )
          ..orderBy([
            (entry) => OrderingTerm.desc(entry.createdAt),
            (entry) => OrderingTerm.desc(entry.id),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<LogEntry>> allLogs() => (select(
    logEntries,
  )..orderBy([(entry) => OrderingTerm.asc(entry.createdAt)])).get();

  Future<void> closeNetwork(DateTime startedAt, DateTime endedAt) async {
    await (update(logEntries)
          ..where((e) => e.networkStartedAt.equalsValue(startedAt)))
        .write(LogEntriesCompanion(networkEndedAt: Value(endedAt.toUtc())));
  }

  Future<void> importLogs(List<LogEntriesCompanion> entries) async {
    final normalized = _mergeImportedNetworks(entries);
    await transaction(() async {
      await batch((batch) {
        batch.insertAll(logEntries, normalized);
      });
    });
  }

  List<LogEntriesCompanion> _mergeImportedNetworks(
    List<LogEntriesCompanion> entries,
  ) {
    final intervals = <({DateTime start, DateTime end})>[];
    for (final entry in entries) {
      final start = entry.networkStartedAt.value?.toUtc();
      final end = entry.networkEndedAt.value?.toUtc() ?? start;
      if (start == null || end == null) continue;
      var mergedStart = start.isBefore(end) ? start : end;
      var mergedEnd = start.isBefore(end) ? end : start;
      var changed = true;
      while (changed) {
        changed = false;
        for (final existing in intervals.toList()) {
          if (!mergedEnd.isBefore(existing.start) &&
              !mergedStart.isAfter(existing.end)) {
            mergedStart = mergedStart.isBefore(existing.start)
                ? mergedStart
                : existing.start;
            mergedEnd = mergedEnd.isAfter(existing.end)
                ? mergedEnd
                : existing.end;
            intervals.remove(existing);
            changed = true;
          }
        }
      }
      intervals.add((start: mergedStart, end: mergedEnd));
    }
    return entries.map((entry) {
      final start = entry.networkStartedAt.value?.toUtc();
      final end = entry.networkEndedAt.value?.toUtc();
      if (start == null) return entry;
      final matching = intervals.where(
        (interval) =>
            !interval.end.isBefore(start) &&
            (end == null || !interval.start.isAfter(end)),
      );
      if (matching.isEmpty) return entry;
      final interval = matching.first;
      return entry.copyWith(
        networkStartedAt: Value(interval.start),
        networkEndedAt: Value(interval.end),
      );
    }).toList();
  }
}
