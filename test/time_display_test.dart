import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usra_r3/time_display.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('formats UTC and fixed GMT-3 across day and year boundaries', () {
    final instant = DateTime.utc(2026, 1, 1, 1, 2, 3);
    expect(DisplayTimeZone.utc.format(instant), '01/01/2026 01:02:03 UTC');
    expect(
      DisplayTimeZone.brasilia.format(instant),
      '31/12/2025 22:02:03 GMT-3',
    );
    expect(
      DisplayTimeZone.brasilia.format(instant.toLocal()),
      '31/12/2025 22:02:03 GMT-3',
    );
    // The requested GMT-3 is fixed, including dates formerly in DST.
    expect(
      DisplayTimeZone.brasilia.format(DateTime.utc(2018, 12, 1, 12)),
      '01/12/2018 09:00:00 GMT-3',
    );
  });

  test('today is evaluated in the selected display zone', () {
    final instant = DateTime.utc(2026, 1, 1, 1);
    final now = DateTime.utc(2026, 1, 1, 4);
    expect(
      DisplayTimeZone.utc.format(instant, compact: true, now: now),
      '01:00:00 UTC',
    );
    expect(
      DisplayTimeZone.brasilia.format(instant, compact: true, now: now),
      '31/12/2025 22:00:00 GMT-3',
    );
  });

  test('display zone defaults to Brasilia and survives reloads', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(DisplayTimeZone.read(prefs), DisplayTimeZone.brasilia);
    for (final zone in DisplayTimeZone.values) {
      await zone.save(prefs);
      await prefs.reload();
      expect(DisplayTimeZone.read(prefs), zone);
    }
  });

  testWidgets('changing display zone updates existing consumers', (
    tester,
  ) async {
    final child = Builder(
      builder: (context) => Text(
        TimeDisplay.of(context).format(DateTime.utc(2026, 1, 1, 1)),
        textDirection: TextDirection.ltr,
      ),
    );
    await tester.pumpWidget(
      TimeDisplay(zone: DisplayTimeZone.utc, child: child),
    );
    expect(find.text('01/01/2026 01:00:00 UTC'), findsOneWidget);
    await tester.pumpWidget(
      TimeDisplay(zone: DisplayTimeZone.brasilia, child: child),
    );
    expect(find.text('31/12/2025 22:00:00 GMT-3'), findsOneWidget);
  });
}
