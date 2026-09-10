import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra_r3/data/database.dart';

void main() {
  late UsraDatabase database;

  setUp(() => database = UsraDatabase.test(NativeDatabase.memory()));
  tearDown(() => database.close());

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
      callsign: 'PY2ABC', operatorName: 'Operador', location: 'GG30CH90NH',
      operatorGrid: 'GG30CH90NH', powerWatts: 25, stationType: 'P', traffic: 'C',
    );
    expect(await database.updateLog(id: id, callsign: 'PY3XYZ', operatorName: 'Novo', location: 'GG30CH90NH', powerWatts: 50, stationType: 'F', traffic: 'S'), isTrue);
    expect((await database.select(database.logEntries).get()).single.callsign, 'PY3XYZ');
    expect(await database.deleteLog(id), isTrue);
    expect(await database.select(database.logEntries).get(), isEmpty);
  });
}
