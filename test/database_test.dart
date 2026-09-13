import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra_r3/data/database.dart';
import 'package:usra_r3/data/csv_transfer.dart';
import 'package:usra_r3/map/map_settings.dart';

void main() {
  late UsraDatabase database;

  setUp(() => database = UsraDatabase.test(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<int> save({
    String mode = 'repeater',
    String grid = defaultRepeaterGrid,
  }) => database.saveLog(
    callsign: 'PY3AA',
    frequency: mode,
    frequencyMhz: mode == 'simplex' ? 146.52 : 145.37,
    repeaterGrid: grid,
    operatorName: 'Operador',
    location: 'GG30CH90NH',
    operatorGrid: 'GG30DH31GH',
    powerWatts: 5,
    stationType: 'P',
    traffic: 'S',
  );

  test(
    'stores MHz and repeater snapshot, simplex has no repeater; editing preserves snapshot',
    () async {
      final id = await save();
      await save(grid: 'GG30AA00AA');
      await save(mode: 'simplex');
      await database.updateLog(
        id: id,
        callsign: 'PY3BB',
        operatorName: 'Novo',
        location: 'GG30CH90NH',
        powerWatts: 10,
        stationType: 'P',
        traffic: 'S',
      );
      final entries = await database.allLogs();
      expect(entries.map((e) => e.frequencyMhz), [145.37, 145.37, 146.52]);
      expect(entries.map((e) => e.frequency), [
        'repeater',
        'repeater',
        'simplex',
      ]);
      expect(entries.map((e) => e.repeaterGrid), [
        defaultRepeaterGrid,
        'GG30AA00AA',
        null,
      ]);
    },
  );

  test(
    'CSV round trip preserves mode, MHz and historical repeater grids',
    () async {
      await save();
      await save(mode: 'simplex');
      final original = await database.allLogs();
      await database.importLogs(csvToLogCompanions(logsToCsv(original)));
      final imported = (await database.allLogs()).skip(2).toList();
      expect(
        imported.map((e) => e.frequencyMhz),
        original.map((e) => e.frequencyMhz),
      );
      expect(
        imported.map((e) => e.repeaterGrid),
        original.map((e) => e.repeaterGrid),
      );
      expect(
        imported.map((e) => e.frequency),
        original.map((e) => e.frequency),
      );
    },
  );

  test('legacy CSV remains importable', () async {
    await database.importLogs(
      csvToLogCompanions(
        'created_at,callsign,operator_name,location,operator_grid,power_watts,station_type,traffic\n'
        '2026-09-13T12:00:00Z,PY3AA,Nome,GG30CH90NH,GG30DH31GH,5,P,S',
      ),
    );
    expect((await database.allLogs()).single.repeaterGrid, isNull);
  });

  test(
    'version 8 migration preserves records and backfills known MHz without inventing repeater grids',
    () async {
      await database.close();
      database = UsraDatabase.test(
        NativeDatabase.memory(
          setup: (db) {
            db.execute('''CREATE TABLE log_entries (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        created_at INTEGER NOT NULL, callsign TEXT NOT NULL,
        via TEXT NOT NULL DEFAULT '', frequency TEXT NOT NULL DEFAULT 'repeater',
        energy TEXT NOT NULL DEFAULT 'B', operator_name TEXT NOT NULL,
        location TEXT NOT NULL, operator_grid TEXT NOT NULL,
        power_watts REAL NOT NULL, station_type TEXT NOT NULL,
        traffic TEXT NOT NULL, traffic_message TEXT NOT NULL DEFAULT '')''');
            db.execute(
              "INSERT INTO log_entries (created_at,callsign,frequency,operator_name,location,operator_grid,power_watts,station_type,traffic) VALUES (1,'AA','simplex','Nome','GG30CH','GG30DH',5,'P','S'),(2,'BB','repeater','Nome','GG30CH','GG30DH',5,'P','S')",
            );
            db.execute('PRAGMA user_version = 8');
          },
        ),
      );
      final entries = await database.allLogs();
      expect(entries.map((e) => e.frequencyMhz), [146.52, 145.37]);
      expect(entries.every((e) => e.repeaterGrid == null), isTrue);
      expect(entries.map((e) => e.callsign), ['AA', 'BB']);
    },
  );

  test('persists a log entry with its UTC timestamp', () async {
    final before = DateTime.now().toUtc();
    await database.saveLog(
      callsign: 'PY2ABC',
      operatorName: 'Operador',
      location: 'GG30CH90NH',
      operatorGrid: 'GG30CH90NH',
      powerWatts: 25,
      stationType: 'P',
      traffic: 'C',
    );
    final entries = await database.select(database.logEntries).get();

    expect(entries, hasLength(1));
    expect(entries.single.callsign, 'PY2ABC');
    expect(entries.single.powerWatts, 25);
    expect(
      entries.single.createdAt.toUtc().isAfter(
        before.subtract(const Duration(seconds: 1)),
      ),
      isTrue,
    );
  });

  test('updates and deletes a log entry', () async {
    final id = await database.saveLog(
      callsign: 'PY2ABC',
      operatorName: 'Operador',
      location: 'GG30CH90NH',
      operatorGrid: 'GG30CH90NH',
      powerWatts: 25,
      stationType: 'P',
      traffic: 'C',
    );
    expect(
      await database.updateLog(
        id: id,
        callsign: 'PY3XYZ',
        operatorName: 'Novo',
        location: 'GG30CH90NH',
        powerWatts: 50,
        stationType: 'F',
        traffic: 'S',
      ),
      isTrue,
    );
    expect(
      (await database.select(database.logEntries).get()).single.callsign,
      'PY3XYZ',
    );
    expect(await database.deleteLog(id), isTrue);
    expect(await database.select(database.logEntries).get(), isEmpty);
  });
}
