import 'package:flutter_test/flutter_test.dart';
import 'package:usra_r3/data/database.dart';
import 'package:usra_r3/map/contact_aggregation.dart';

LogEntry entry(String grid, int minute, {String callsign = 'PY2AA'}) => LogEntry(
  id: minute,
  createdAt: DateTime(2026, 1, 1, 0, minute),
  callsign: callsign,
  operatorName: 'Operator',
  location: grid,
  operatorGrid: 'GG30DH31',
  powerWatts: 10,
  stationType: 'P',
  traffic: 'S',
);

void main() {
  test('uses the most precise grid inside the same area', () {
    final result = aggregateMapContacts([
      entry('GG30DH31', 1),
      entry('GG30DH31GH', 2),
    ]);
    expect(result, hasLength(1));
    expect(result.single.latest.location, 'GG30DH31GH');
  });

  test('last-only mode keeps one marker per callsign', () {
    final result = aggregateMapContacts([
      entry('GG30DH31', 1),
      entry('GG31AA00', 2),
      entry('GG30DH31', 3, callsign: 'PY3BB'),
    ], lastOnlyByCallsign: true);
    expect(result, hasLength(2));
    expect(result.firstWhere((c) => c.latest.callsign == 'PY2AA').latest.location, 'GG31AA00');
  });
}
