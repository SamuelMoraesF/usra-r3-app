import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class LogEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get callsign => text()();
  TextColumn get operatorName => text()();
  TextColumn get location => text()();
  TextColumn get operatorGrid => text()();
  RealColumn get powerWatts => real()();
  TextColumn get stationType => text()();
  TextColumn get traffic => text()();
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(logEntries, logEntries.operatorGrid);
    },
  );

  Future<int> saveLog({
    required String callsign,
    required String operatorName,
    required String location,
    required String operatorGrid,
    required double powerWatts,
    required String stationType,
    required String traffic,
  }) {
    return into(logEntries).insert(
      LogEntriesCompanion.insert(
        createdAt: DateTime.now().toUtc(),
        callsign: callsign,
        operatorName: operatorName,
        location: location,
        operatorGrid: operatorGrid,
        powerWatts: powerWatts,
        stationType: stationType,
        traffic: traffic,
      ),
    );
  }

  Future<bool> deleteLog(int id) async {
    return await (delete(logEntries)..where((entry) => entry.id.equals(id))).go() > 0;
  }

  Future<bool> updateLog({
    required int id,
    required String callsign,
    required String operatorName,
    required String location,
    required double powerWatts,
    required String stationType,
    required String traffic,
  }) async {
    return await (update(logEntries)..where((entry) => entry.id.equals(id))).write(
          LogEntriesCompanion(
            callsign: Value(callsign),
            operatorName: Value(operatorName),
            location: Value(location),
            powerWatts: Value(powerWatts),
            stationType: Value(stationType),
            traffic: Value(traffic),
          ),
        ) >
        0;
  }

  Stream<List<LogEntry>> watchLogs() => (select(
    logEntries,
  )..orderBy([(entry) => OrderingTerm.desc(entry.createdAt)])).watch();
}
