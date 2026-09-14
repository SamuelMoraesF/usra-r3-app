import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usra_r3/data/database.dart';
import 'package:usra_r3/grid_locator.dart';
import 'package:usra_r3/map/contact_scene.dart';
import 'package:usra_r3/map/map_settings.dart';

final now = DateTime.utc(2026, 9, 13, 12);
final session = now.subtract(const Duration(days: 2));
const userGrid = 'GG30DH31GH';
const remoteGrid = 'GG30CH90NH';
const oldRepeater = 'GG30AA00AA';

LogEntry qso({
  String callsign = 'PY3AA',
  String mode = 'simplex',
  double? mhz,
  String grid = remoteGrid,
  String via = '',
  String? repeater = defaultRepeaterGrid,
  int ageHours = 1,
}) => LogEntry(
  id: ageHours,
  networkStartedAt: session,
  createdAt: now.subtract(Duration(hours: ageHours)),
  callsign: callsign,
  via: via,
  frequency: mode,
  frequencyMhz: mhz ?? (mode == 'simplex' ? 146.52 : 145.37),
  repeaterGrid: mode == 'repeater' ? repeater : null,
  energy: 'B',
  operatorName: 'Operador',
  location: grid,
  operatorGrid: userGrid,
  powerWatts: 5,
  stationType: 'P',
  traffic: 'S',
  trafficMessage: '',
);

ContactScene scene(
  List<LogEntry> entries, {
  bool all = false,
  bool lines = true,
  String mode = 'simplex',
  int hours = 24,
  bool lastOnly = false,
  String operator = userGrid,
}) => buildContactScene(
  entries,
  now: now,
  sessionStartedAt: session,
  showAll: all,
  maxAgeHours: hours,
  operatorGrid: operator,
  repeaterGrid: defaultRepeaterGrid,
  selectedMode: mode,
  selectedFrequencyMhz: mode == 'simplex' ? 146.52 : 145.37,
  showLines: lines,
  lastOnly: lastOnly,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('callsign labels include hidden stations and exclude the operator', () {
    final result = scene([
      qso(callsign: 'PY3SELF'),
      qso(callsign: 'PY3SIM'),
      qso(callsign: 'PY3REP', mode: 'repeater', repeater: oldRepeater),
      qso(callsign: 'PY3OTHER', mhz: 147.0),
      qso(callsign: 'PY3SAMEGRID', grid: userGrid),
    ]);
    expect(
      result.markers.any((m) => m.kind == MarkerKind.currentRepeater),
      isTrue,
    );
    expect(
      result.markers.any((m) => m.kind == MarkerKind.historicalRepeater),
      isTrue,
    );
    expect(
      result.callsignContacts(' py3self ').map((c) => c.latest.callsign),
      unorderedEquals(['PY3SIM', 'PY3REP', 'PY3OTHER', 'PY3SAMEGRID']),
    );
  });

  test(
    'callsign labels default off and persist when enabled and disabled',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(MapSettings.read(prefs).showCallsigns, isFalse);
      for (final enabled in [true, false]) {
        await MapSettings(showCallsigns: enabled).save(prefs);
        await prefs.reload();
        expect(MapSettings.read(prefs).showCallsigns, enabled);
      }
    },
  );

  test('new record focus defaults off and persists', () async {
    SharedPreferences.setMockInitialValues({});
    var prefs = await SharedPreferences.getInstance();
    expect(MapSettings.read(prefs).focusNewRecord, isFalse);

    await const MapSettings(focusNewRecord: true).save(prefs);
    prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(MapSettings.read(prefs).focusNewRecord, isTrue);
  });

  test('contact marker colors follow station and energy', () {
    expect(
      const ContactMarker(
        '',
        MarkerKind.selectedContact,
        stationType: 'F',
        energy: 'AC',
      ).color,
      '#4CAF50',
    );
    expect(
      const ContactMarker(
        '',
        MarkerKind.selectedContact,
        stationType: 'F',
        energy: 'G',
      ).color,
      '#FFEB3B',
    );
    expect(
      const ContactMarker(
        '',
        MarkerKind.selectedContact,
        stationType: 'P',
        energy: 'B',
      ).color,
      '#F44336',
    );
    expect(
      const ContactMarker(
        '',
        MarkerKind.selectedContact,
        stationType: 'M',
        energy: 'AC',
      ).color,
      '#FF9800',
    );
    expect(
      const ContactMarker('', MarkerKind.currentRepeater).color,
      '#7E57C2',
    );
    expect(const ContactMarker('', MarkerKind.otherContact).color, '#9E9E9E');
  });

  test(
    'default grid contains supplied coordinates at maximum supported precision',
    () {
      final lat = -(29 + 42 / 60 + 58.7 / 3600);
      final lon = -(53 + 51 / 60 + 2.3 / 3600);
      expect(GridLocator.fromCoordinates(lat, lon), defaultRepeaterGrid);
      expect(defaultRepeaterGrid.length, 10);
      final bounds = GridLocator.bounds(defaultRepeaterGrid)!;
      expect(lat, inInclusiveRange(bounds.minLatitude, bounds.maxLatitude));
      expect(lon, inInclusiveRange(bounds.minLongitude, bounds.maxLongitude));
    },
  );

  test(
    'both toggles default off and persist independently across reloads',
    () async {
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();
      expect(MapSettings.read(prefs).showLines, isFalse);
      expect(MapSettings.read(prefs).showAll, isFalse);
      expect(MapSettings.read(prefs).showPrecision, isFalse);
      expect(MapSettings.read(prefs).showElevation, isFalse);
      expect(MapSettings.read(prefs).showCompass, isTrue);
      expect(MapSettings.read(prefs).focusNewRecord, isFalse);
      expect(MapSettings.read(prefs).repeaterGrid, defaultRepeaterGrid);
      for (final lines in [true, false]) {
        for (final all in [true, false]) {
          for (final precision in [true, false]) {
            for (final compass in [true, false]) {
              for (final elevation in [true, false]) {
                await MapSettings(
                  showLines: lines,
                  showAll: all,
                  showPrecision: precision,
                  showElevation: elevation,
                  showCompass: compass,
                  repeaterGrid: oldRepeater,
                ).save(prefs);
                prefs = await SharedPreferences.getInstance();
                await prefs.reload();
                final restored = MapSettings.read(prefs);
                expect(restored.showLines, lines);
                expect(restored.showAll, all);
                expect(restored.showPrecision, precision);
                expect(restored.showElevation, elevation);
                expect(restored.showCompass, compass);
                expect(restored.repeaterGrid, oldRepeater);
              }
            }
          }
        }
      }
    },
  );

  test('filter respects mode, actual MHz and expires at the time limit', () {
    final entries = [
      qso(ageHours: 23),
      qso(callsign: 'EXPIRED', ageHours: 24),
      qso(callsign: 'OLD', ageHours: 25),
      qso(callsign: 'REP', mode: 'repeater'),
      qso(callsign: 'OTHER', mhz: 146.5),
    ];
    expect(
      scene(entries).contacts.map((c) => c.latest.callsign),
      unorderedEquals(['PY3AA', 'REP', 'OTHER']),
    );
    expect(
      scene(entries, mode: 'repeater').contacts.last.latest.callsign,
      'REP',
    );
    expect(scene(entries, hours: 1).contacts, isEmpty);
  });

  test(
    'simplex direct route is gray with 90 percent opacity; ruler hides all routes',
    () {
      final route = scene([qso()]).routes.single;
      expect(route.grids, [userGrid, remoteGrid]);
      expect(route.color, '#808080');
      expect(route.opacity, .9);
      expect(scene([qso()], lines: false).routes, isEmpty);
      expect(scene([qso()], operator: '').routes, isEmpty);
      expect(scene([qso(grid: '')]).contacts, isEmpty);
    },
  );

  test(
    'via resolves latest recent valid grid only within the selected frequency',
    () {
      final result = scene([
        qso(via: ' py3bb '),
        qso(
          callsign: 'PY3BB',
          grid: oldRepeater,
          mode: 'repeater',
          ageHours: 2,
        ),
        qso(callsign: 'PY3BB', grid: defaultRepeaterGrid, ageHours: 3),
      ]);
      expect(result.routes.first.grids, [
        userGrid,
        defaultRepeaterGrid,
        remoteGrid,
      ]);
      expect(result.routes.first.missingVia, isFalse);
    },
  );

  test('absent, expired or invalid via creates a red direct route', () {
    for (final viaEntries in <List<LogEntry>>[
      [],
      [qso(callsign: 'VIA', ageHours: 25)],
      [qso(callsign: 'VIA', grid: '')],
    ]) {
      final route = scene([qso(via: 'VIA'), ...viaEntries]).routes.first;
      expect(route.grids, [userGrid, remoteGrid]);
      expect(route.color, '#F44336');
    }
  });

  test(
    'repeater is always intermediate and historical locations survive grouping',
    () {
      final result = scene(
        [
          qso(mode: 'repeater', repeater: oldRepeater, ageHours: 2),
          qso(mode: 'repeater', via: 'MISSING'),
        ],
        mode: 'repeater',
        lastOnly: true,
      );
      expect(result.contacts, hasLength(1));
      expect(result.routes.map((r) => r.grids[1]), [
        oldRepeater,
        defaultRepeaterGrid,
      ]);
      expect(result.routes.every((r) => !r.missingVia), isTrue);
      final repeaters = result.markers
          .where(
            (m) =>
                m.kind == MarkerKind.currentRepeater ||
                m.kind == MarkerKind.historicalRepeater,
          )
          .toList();
      expect(repeaters, hasLength(2));
      expect(repeaters.first.color, '#7E57C2');
      expect(repeaters.last.color, '#7E57C2');
      expect(
        repeaters.every((m) => m.radius == result.markers.first.radius),
        isTrue,
      );
    },
  );

  test('current repeater exists without QSOs only in repeater mode', () {
    expect(scene([]).markers, hasLength(1));
    expect(
      scene([], mode: 'repeater').markers.last.kind,
      MarkerKind.currentRepeater,
    );
    final result = scene([
      qso(mode: 'repeater'),
      qso(mode: 'repeater', callsign: 'BB'),
    ], mode: 'repeater');
    expect(
      result.markers.where((m) => m.grid == defaultRepeaterGrid),
      hasLength(1),
    );
    expect(
      scene(
        [qso(mode: 'repeater', repeater: oldRepeater, ageHours: 25)],
        mode: 'repeater',
      ).markers.where((m) => m.kind == MarkerKind.historicalRepeater),
      isEmpty,
    );
  });

  test('operator blue; contacts on other frequencies always remain gray', () {
    final result = scene([
      qso(ageHours: 2),
      qso(mode: 'repeater'),
      qso(callsign: 'BB', mode: 'repeater'),
      qso(callsign: 'BB', ageHours: 25),
    ]);
    expect(result.markers.first.color, '#2196F3');
    final stations = result.markers
        .where((m) => m.contactIndex != null)
        .toList();
    expect(stations.map((m) => m.color), ['#9E9E9E', '#9E9E9E', '#F44336']);
    expect(stations.every((m) => m.radius == 6), isTrue);
  });

  test('legacy repeater position is not fabricated from current config', () {
    expect(
      scene([qso(mode: 'repeater', repeater: null)], mode: 'repeater').routes,
      isEmpty,
    );
  });

  test(
    'all-frequency toggle affects routes only, while hidden stations remain visible',
    () {
      final entries = [qso(), qso(callsign: 'REP', mode: 'repeater')];
      final current = scene(entries);
      final all = scene(entries, all: true);
      expect(current.contacts, hasLength(2));
      expect(all.contacts, hasLength(2));
      expect(
        current.markers.map((m) => m.color),
        all.markers.map((m) => m.color),
      );
      expect(current.routes, hasLength(1));
      expect(all.routes, hasLength(2));
      expect(scene(entries, all: true, lines: false).routes, isEmpty);
      expect(scene(entries, all: true, lines: false).contacts, hasLength(2));
    },
  );
}
