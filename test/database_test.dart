import 'dart:io';
import 'package:drift/drift.dart' show Value;
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
      final originalIds = original.map((entry) => entry.id).toSet();
      final imported = (await database.allLogs())
          .where((entry) => !originalIds.contains(entry.id))
          .toList();
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

  test('looks up the latest callsign power within the selected frequency', () async {
    await database.importLogs(
      csvToLogCompanions(
        '${csvHeaders.join(',')}\n'
        '2026-09-13T12:00:00Z,PY3AA,Nome,GG30CH,GG30DH,5,P,S,,repeater,145.37,,B,\n'
        '2026-09-13T13:00:00Z,PY3AA,Nome,GG30CH,GG30DH,10,P,S,,repeater,145.37,,B,\n'
        '2026-09-13T14:00:00Z,PY3AA,Nome,GG30CH,GG30DH,50,P,S,,simplex,146.52,,B,\n'
        '2026-09-13T15:00:00Z,PY3BB,Nome,GG30CH,GG30DH,25,P,S,,repeater,145.37,,B,',
      ),
    );
    expect((await database.latestLogForCallsign('PY3AA'))!.powerWatts, 50);
    expect(
      (await database.latestLogForCallsign(
        ' py3aa ',
        frequency: 'repeater',
      ))!.powerWatts,
      10,
    );
    expect(
      (await database.latestLogForCallsign(
        'PY3AA',
        frequency: 'simplex',
      ))!.powerWatts,
      50,
    );
    expect(
      await database.latestLogForCallsign('PY3BB', frequency: 'simplex'),
      isNull,
    );
  });

  test(
    'persists network session bounds and merges overlapping imports',
    () async {
      final firstStart = DateTime.utc(2026, 9, 13, 10);
      final firstEnd = DateTime.utc(2026, 9, 13, 12);
      final secondStart = DateTime.utc(2026, 9, 13, 11);
      final secondEnd = DateTime.utc(2026, 9, 13, 13);
      await database.importLogs([
        LogEntriesCompanion.insert(
          createdAt: firstStart,
          callsign: 'PY3AA',
          operatorName: 'A',
          location: 'GG30CH',
          operatorGrid: 'GG30DH',
          powerWatts: 5,
          stationType: 'P',
          traffic: 'S',
          networkStartedAt: Value(firstStart),
          networkEndedAt: Value(firstEnd),
        ),
        LogEntriesCompanion.insert(
          createdAt: secondStart,
          callsign: 'PY3BB',
          operatorName: 'B',
          location: 'GG30CH',
          operatorGrid: 'GG30DH',
          powerWatts: 5,
          stationType: 'P',
          traffic: 'S',
          networkStartedAt: Value(secondStart),
          networkEndedAt: Value(secondEnd),
        ),
      ]);
      final entries = await database.allLogs();
      expect(entries.map((e) => e.networkStartedAt), [firstStart, firstStart]);
      expect(entries.map((e) => e.networkEndedAt), [secondEnd, secondEnd]);
      final csv = logsToCsv(entries);
      expect(csv, contains('network_started_at'));
      expect(
        csvToLogCompanions(csv).every(
          (e) =>
              e.networkStartedAt.value == firstStart &&
              e.networkEndedAt.value == secondEnd,
        ),
        isTrue,
      );
    },
  );

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
      expect(entries.every((e) => e.createdAt.isUtc), isTrue);
      expect(entries.first.createdAt, DateTime.utc(1970, 1, 1, 0, 0, 1));
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
    expect(entries.single.createdAt.isUtc, isTrue);
    expect(
      entries.single.createdAt.toUtc().isAfter(
        before.subtract(const Duration(seconds: 1)),
      ),
      isTrue,
    );
  });

  test('version 9 UTC migration preserves instants and runs only once', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp(
      'usra-utc-migration-',
    );
    final file = File('${directory.path}/logbook.sqlite');
    final original = DateTime.utc(2026, 1, 1, 1, 2, 3);
    final seconds = original.millisecondsSinceEpoch ~/ 1000;
    var migrated = UsraDatabase.test(
      NativeDatabase(
        file,
        setup: (db) {
          db.execute('''CREATE TABLE log_entries (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        created_at INTEGER NOT NULL, callsign TEXT NOT NULL,
        via TEXT NOT NULL DEFAULT '', frequency TEXT NOT NULL DEFAULT 'repeater',
        frequency_mhz REAL, repeater_grid TEXT,
        energy TEXT NOT NULL DEFAULT 'B', operator_name TEXT NOT NULL,
        location TEXT NOT NULL, operator_grid TEXT NOT NULL,
        power_watts REAL NOT NULL, station_type TEXT NOT NULL,
        traffic TEXT NOT NULL, traffic_message TEXT NOT NULL DEFAULT '')''');
          db.execute(
            "INSERT INTO log_entries (id,created_at,callsign,operator_name,location,operator_grid,power_watts,station_type,traffic) VALUES (42,?,'PY3AA','Nome','GG30CH','GG30DH',5,'P','S')",
            [seconds],
          );
          db.execute('PRAGMA user_version = 9');
        },
      ),
    );
    try {
      final first = (await migrated.allLogs()).single;
      expect(first.id, 42);
      expect(first.createdAt, original);
      expect(first.createdAt.isUtc, isTrue);
      final raw = await migrated
          .customSelect('SELECT created_at_utc FROM log_entries')
          .getSingle();
      expect(raw.read<int>('created_at_utc'), original.microsecondsSinceEpoch);
      await migrated.close();
      migrated = UsraDatabase.test(NativeDatabase(file));
      final reopened = (await migrated.allLogs()).single;
      expect(reopened, first);
      expect(reopened.createdAt.isUtc, isTrue);
      expect(logsToCsv([reopened]), contains('2026-01-01T01:02:03.000Z'));
    } finally {
      await migrated.close();
      await directory.delete(recursive: true);
      database = UsraDatabase.test(NativeDatabase.memory());
    }
  });

  test(
    'CSV offsets and zone-less timestamps normalize to UTC without losing precision',
    () async {
      final entries = csvToLogCompanions(
        'created_at,callsign,operator_name,location,operator_grid,power_watts,station_type,traffic\n'
        '2025-12-31T22:02:03.123456-03:00,PY3AA,Nome,GG30CH,GG30DH,5,P,S\n'
        '2026-01-01T03:02:03.123456+02:00,PY3BB,Nome,GG30CH,GG30DH,5,P,S\n'
        '2026-01-01T01:02:03.123456Z,PY3CC,Nome,GG30CH,GG30DH,5,P,S\n'
        '2026-01-01T01:02:03.123456,PY3DD,Nome,GG30CH,GG30DH,5,P,S',
      );
      final expected = DateTime.utc(2026, 1, 1, 1, 2, 3, 123, 456);
      expect(entries.every((e) => e.createdAt.value.isUtc), isTrue);
      expect(entries.every((e) => e.createdAt.value == expected), isTrue);
      await database.importLogs(entries);
      final saved = await database.allLogs();
      expect(
        saved.every((e) => e.createdAt.isUtc && e.createdAt == expected),
        isTrue,
      );
      final csv = logsToCsv(saved);
      expect('2026-01-01T01:02:03.123456Z'.allMatches(csv), hasLength(4));
      expect(
        csvToLogCompanions(csv).every((e) => e.createdAt.value == expected),
        isTrue,
      );
    },
  );

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
