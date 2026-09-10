import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class LogEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get callsign => text()();
  TextColumn get operatorName => text()();
  TextColumn get location => text()();
  RealColumn get powerWatts => real()();
  TextColumn get stationType => text()();
  TextColumn get traffic => text()();
}

@DriftDatabase(tables: [LogEntries])
class UsraDatabase extends _$UsraDatabase {
  UsraDatabase() : super(driftDatabase(name: 'usra_r3_logbook'));

  UsraDatabase.test(super.e);

  @override
  int get schemaVersion => 1;

  Future<int> saveLog({
    required String callsign,
    required String operatorName,
    required String location,
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
        powerWatts: powerWatts,
        stationType: stationType,
        traffic: traffic,
      ),
    );
  }

  Stream<List<LogEntry>> watchLogs() => (select(
    logEntries,
  )..orderBy([(entry) => OrderingTerm.desc(entry.createdAt)])).watch();
}
