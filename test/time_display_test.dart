import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usra_r3/time_display.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('network titles show end or open state with compact dates', () {
    final now = DateTime.utc(2026, 9, 14);
    String title(DateTime start, DateTime? end) =>
        DisplayTimeZone.utc.formatNetworkTitle(start, end, now: now);
    final start = DateTime.utc(2026, 9, 14, 10);
    expect(title(start, null), 'Rede 14/09 10:00 — em aberto');
    expect(
      title(start, DateTime.utc(2026, 9, 14, 12, 30)),
      'Rede 14/09 10:00 — 12:30',
    );
    expect(
      title(start, DateTime.utc(2026, 9, 15, 1)),
      'Rede 14/09 10:00 — 15/09 01:00',
    );
    expect(
      title(DateTime.utc(2025, 12, 31, 23), DateTime.utc(2026, 1, 1, 1)),
      'Rede 31/12/2025 23:00 — 01/01 01:00',
    );
    expect(
      title(DateTime.utc(2024, 12, 31, 23), DateTime.utc(2025, 1, 1, 1)),
      'Rede 31/12/2024 23:00 — 01/01/2025 01:00',
    );
    expect(
      title(DateTime.utc(2025, 9, 14, 10), null),
      'Rede 14/09/2025 10:00 — em aberto',
    );
    expect(
      DisplayTimeZone.brasilia.formatNetworkTitle(
        DateTime.utc(2026, 9, 14, 2),
        DateTime.utc(2026, 9, 14, 4),
        now: now,
      ),
      'Rede 13/09 23:00 — 14/09 01:00',
    );
  });

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

  test('formats the landscape header clock and date in Portuguese', () {
    final instant = DateTime.utc(2026, 8, 15, 15, 4, 9);
    expect(DisplayTimeZone.utc.formatClock(instant), '15:04:09');
    expect(DisplayTimeZone.utc.formatLongDate(instant), 'sábado, 15 de agosto');
    expect(
      DisplayTimeZone.brasilia.formatLongDate(instant),
      'sábado, 15 de agosto',
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

  test(
    'compact contact warnings retain seconds and omit only redundant date parts',
    () {
      final now = DateTime.utc(2026, 9, 14, 12);
      String format(DateTime date) =>
          DisplayTimeZone.utc.format(date, compact: true, now: now);
      expect(format(DateTime.utc(2026, 9, 14, 9, 10, 11)), '09:10:11 UTC');
      expect(
        format(DateTime.utc(2026, 9, 13, 9, 10, 11)),
        '13/09 09:10:11 UTC',
      );
      expect(
        format(DateTime.utc(2025, 9, 13, 9, 10, 11)),
        '13/09/2025 09:10:11 UTC',
      );
    },
  );

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
