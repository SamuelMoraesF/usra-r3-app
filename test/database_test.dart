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
}
