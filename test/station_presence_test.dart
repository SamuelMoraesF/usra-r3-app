import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usra_r3/map/contact_scene.dart';
import 'package:usra_r3/map/station_presence.dart';
import 'package:usra_r3/data/database.dart';

final session = DateTime.utc(2026, 9, 14);
final now = session.add(const Duration(hours: 12));

LogEntry contact({
  int id = 1,
  String callsign = 'PY3AA',
  String mode = 'simplex',
  double? mhz,
  Duration age = const Duration(hours: 2, minutes: 45),
  DateTime? started,
  DateTime? ended,
  String location = 'GG30CH',
}) => LogEntry(
  id: id,
  createdAt: now.subtract(age),
  callsign: callsign,
  frequency: mode,
  frequencyMhz: mhz,
  networkStartedAt: started ?? session,
  networkEndedAt: ended,
  via: '',
  energy: 'AC',
  operatorName: 'Maria',
  location: location,
  operatorGrid: 'GG30DH',
  powerWatts: 25,
  stationType: 'F',
  traffic: 'S',
  trafficMessage: '',
);

StationPresence presence(
  List<LogEntry> entries, {
  DateTime? at,
  DateTime? currentSession,
  int minutes = 30,
  String mode = 'simplex',
  double mhz = 146.52,
  StationDisconnections? disconnected,
}) => stationPresence(
  entries,
  now: at ?? now,
  sessionStartedAt: currentSession ?? session,
  mode: mode,
  frequencyMhz: mhz,
  warningMinutes: minutes,
  disconnections: disconnected,
);

ContactScene scene(
  List<LogEntry> entries, {
  DateTime? at,
  DateTime? currentSession,
  StationDisconnections? disconnected,
  bool closed = false,
  bool all = false,
}) => buildContactScene(
  entries,
  now: at ?? now,
  maxAgeHours: 3,
  operatorGrid: 'GG30DH',
  repeaterGrid: 'GG30BG',
  selectedMode: 'simplex',
  selectedFrequencyMhz: 146.52,
  sessionStartedAt: closed ? null : currentSession ?? session,
  disconnections: disconnected,
  showLines: true,
  showAll: all,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults are three hours and thirty warning minutes', () {
    expect(defaultContactMaxAgeHours, 3);
    expect(defaultContactWarningMinutes, 30);
    expect(presence([contact(age: const Duration(hours: 4))]).entries, isEmpty);
  });

  test(
    'closed session is completely empty including operator, towers and routes',
    () {
      final result = scene([contact()], closed: true);
      expect(result.contacts, isEmpty);
      expect(result.markers, isEmpty);
      expect(result.routes, isEmpty);
      expect(
        stationPresence(
          [contact()],
          now: now,
          sessionStartedAt: null,
          mode: 'simplex',
          frequencyMhz: 146.52,
        ).warnings,
        isEmpty,
      );
    },
  );

  test(
    'another session, closed records, unassigned records and future contacts are excluded',
    () {
      final entry = contact();
      final entries = [
        contact(started: session.subtract(const Duration(days: 1))),
        contact(ended: now),
        entry.copyWith(networkStartedAt: const Value(null)),
        contact(age: const Duration(minutes: -1)),
      ];
      expect(presence(entries).entries, isEmpty);
      expect(presence(entries).warnings, isEmpty);
      expect(scene([entry], currentSession: now).contacts, isEmpty);
    },
  );

  test(
    'strict warning threshold, exact expiration, and next timer transitions',
    () {
      final entry = contact(age: const Duration(hours: 2, minutes: 30));
      final warningAt = now.add(const Duration(milliseconds: 1));
      expect(presence([entry]).warnings, isEmpty);
      expect(presence([entry]).nextChange, warningAt);
      final warning = presence([entry], at: warningAt);
      expect(warning.warnings, [entry]);
      expect(warning.entries, [entry]);
      expect(warning.nextChange, now.add(const Duration(minutes: 30)));
      final expired = presence([
        entry,
      ], at: now.add(const Duration(minutes: 30)));
      expect(expired.entries, isEmpty);
      expect(expired.warnings, isEmpty);
      expect(expired.nextChange, isNull);
      final expiredScene = scene([
        entry,
      ], at: now.add(const Duration(minutes: 30)));
      expect(expiredScene.contacts, isEmpty);
      expect(
        expiredScene.markers.where((marker) => marker.contactIndex != null),
        isEmpty,
      );
    },
  );

  test('warning can be disabled without disabling expiration', () {
    expect(presence([contact()], minutes: 0).warnings, isEmpty);
    expect(
      presence([contact(age: const Duration(hours: 3))], minutes: 0).entries,
      isEmpty,
    );
  });

  test(
    'latest contact per normalized station controls warning across locations',
    () {
      final old = contact();
      final recent = contact(
        id: 2,
        callsign: ' py3aa ',
        age: const Duration(minutes: 5),
        location: 'GG30AA',
      );
      expect(presence([old, recent]).warnings, isEmpty);
      expect(presence([recent, old]).warnings, isEmpty);
      expect(scene([old, recent]).markers.every((m) => !m.warning), isTrue);
      expect(presence([old, old.copyWith(id: 3)]).warnings.single.id, 3);
    },
  );

  test(
    'warning shape preserves station color and does not affect operator',
    () {
      final result = scene([contact()]);
      final marker = result.markers.singleWhere((m) => m.contactIndex != null);
      expect(marker.warning, isTrue);
      expect(marker.color, '#4CAF50');
      expect(result.markers.first.warning, isFalse);
    },
  );

  test(
    'switch filters warnings and selects marker colors by mode and actual MHz',
    () {
      final simplex = contact();
      final repeater = contact(mode: 'repeater', id: 2);
      final otherMhz = contact(mhz: 146.55, id: 3);
      final entries = [simplex, repeater, otherMhz];
      expect(presence(entries).warnings, [simplex]);
      final result = scene(entries);
      expect(result.contacts, hasLength(3));
      final selectedMarker = result.markers.singleWhere(
        (m) => m.kind == MarkerKind.selectedContact,
      );
      expect(result.contacts[selectedMarker.contactIndex!].latest, simplex);
      expect(
        result.markers.where((m) => m.kind == MarkerKind.otherContact),
        hasLength(2),
      );
      expect(presence(entries, mode: 'repeater', mhz: 145.37).warnings, [
        repeater,
      ]);
      expect(presence(entries, mhz: 146.55).warnings, [otherMhz]);
    },
  );

  test(
    'hidden stations use warning triangles regardless of the all-frequency lines toggle',
    () {
      final hidden = contact(mode: 'repeater', location: 'GG30AA');
      final fresh = contact(age: const Duration(minutes: 5));
      for (final all in [false, true]) {
        final result = scene([hidden, fresh], all: all);
        final hiddenMarker = result.markers.singleWhere(
          (m) => m.kind == MarkerKind.otherContact,
        );
        final currentMarker = result.markers.singleWhere(
          (m) => m.kind == MarkerKind.selectedContact,
        );
        expect(hiddenMarker.color, '#9E9E9E');
        expect(hiddenMarker.warning, isTrue);
        expect(currentMarker.warning, isFalse);
        expect(presence([hidden, fresh]).warnings, isEmpty);
        expect(
          scene([
            contact(mode: 'repeater', age: const Duration(hours: 3)),
          ], all: all).contacts,
          isEmpty,
        );
        final disconnected = StationDisconnections().disconnect(hidden, now);
        expect(
          scene(
            [hidden, fresh],
            all: all,
            disconnected: disconnected,
          ).contacts.single.latest,
          fresh,
        );
      }
    },
  );

  test(
    'old individual locations expire even when latest contact stays active',
    () {
      final old = contact(age: const Duration(hours: 2, minutes: 59));
      final recent = contact(id: 2, age: const Duration(minutes: 5));
      expect(
        presence([old, recent]).nextChange,
        now.add(const Duration(minutes: 1)),
      );
      expect(
        presence([
          old,
          recent,
        ], at: now.add(const Duration(minutes: 1))).entries,
        [recent],
      );
    },
  );

  test(
    'disconnect removes all station points, routes and warnings without mutating logs',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final entry = contact();
      final entries = [
        entry,
        contact(
          id: 2,
          age: const Duration(hours: 2, minutes: 50),
          location: 'GG30AA',
        ),
      ];
      final before = entries.map((e) => e.toJson()).toList();
      expect(presence(entries).warnings, [entry]);
      expect(scene(entries).contacts, isNotEmpty);
      final disconnected = StationDisconnections().disconnect(entry, now);
      await disconnected.save(prefs);
      await prefs.reload();
      final restored = StationDisconnections.read(prefs);
      expect(presence(entries, disconnected: restored).warnings, isEmpty);
      final result = scene(entries, disconnected: restored);
      expect(result.contacts, isEmpty);
      expect(result.routes, isEmpty);
      expect(result.markers.where((m) => m.contactIndex != null), isEmpty);
      expect(entries.map((e) => e.toJson()).toList(), before);
    },
  );

  test(
    'only a later contact revives a disconnected station; scope is session and frequency',
    () {
      final entry = contact();
      final disconnected = StationDisconnections().disconnect(
        entry,
        now.subtract(const Duration(minutes: 2)),
      );
      final recent = contact(id: 2, age: const Duration(minutes: 1));
      expect(presence([entry, recent], disconnected: disconnected).entries, [
        recent,
      ]);
      expect(
        presence([entry, recent], disconnected: disconnected).warnings,
        isEmpty,
      );
      expect(
        disconnected.includes(entry.copyWith(operatorName: 'Nome editado')),
        isTrue,
      );
      expect(disconnected.includes(contact(mode: 'repeater')), isFalse);
      expect(disconnected.includes(contact(mhz: 146.55)), isFalse);
      expect(disconnected.includes(contact(started: now)), isFalse);
    },
  );

  test('invalid saved presence data is tolerated', () async {
    for (final raw in ['broken', '[]', '{"key": 5}']) {
      SharedPreferences.setMockInitialValues({
        StationDisconnections.preferenceKey: raw,
      });
      expect(
        StationDisconnections.read(
          await SharedPreferences.getInstance(),
        ).values,
        isEmpty,
      );
    }
  });
}
