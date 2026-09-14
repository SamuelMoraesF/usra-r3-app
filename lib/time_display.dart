import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DisplayTimeZone {
  utc('UTC', Duration.zero, 'UTC'),
  brasilia('Brasília (GMT-3)', Duration(hours: -3), 'GMT-3');

  const DisplayTimeZone(this.label, this.offset, this.suffix);
  final String label;
  final Duration offset;
  final String suffix;

  static DisplayTimeZone read(SharedPreferences preferences) =>
      preferences.getString('display.timeZone') == 'utc' ? utc : brasilia;

  Future<void> save(SharedPreferences preferences) =>
      preferences.setString('display.timeZone', name);

  String formatNetworkTitle(
    DateTime? startedAt,
    DateTime? endedAt, {
    DateTime? now,
  }) {
    if (startedAt == null) return 'Rede sem sessão';
    final start = startedAt.toUtc().add(offset);
    final end = endedAt?.toUtc().add(offset);
    final currentYear = (now ?? DateTime.now()).toUtc().add(offset).year;
    String two(int value) => value.toString().padLeft(2, '0');
    String date(DateTime value) =>
        '${two(value.day)}/${two(value.month)}'
        '${value.year == currentYear ? '' : '/${value.year}'}';
    String time(DateTime value) => '${two(value.hour)}:${two(value.minute)}';
    final beginning = 'Rede ${date(start)} ${time(start)}';
    if (end == null) return '$beginning — em aberto';
    final sameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    return '$beginning — ${sameDay ? '' : '${date(end)} '}${time(end)}';
  }

  String format(DateTime value, {bool compact = false, DateTime? now}) {
    final wallTime = value.toUtc().add(offset);
    final today = (now ?? DateTime.now()).toUtc().add(offset);
    String two(int n) => n.toString().padLeft(2, '0');
    final time =
        '${two(wallTime.hour)}:${two(wallTime.minute)}:${two(wallTime.second)} $suffix';
    if (compact &&
        wallTime.year == today.year &&
        wallTime.month == today.month &&
        wallTime.day == today.day) {
      return time;
    }
    final year = compact && wallTime.year == today.year
        ? ''
        : '/${wallTime.year}';
    return '${two(wallTime.day)}/${two(wallTime.month)}$year $time';
  }
}

class TimeDisplay extends InheritedWidget {
  const TimeDisplay({super.key, required this.zone, required super.child});
  final DisplayTimeZone zone;

  static DisplayTimeZone of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TimeDisplay>()?.zone ??
      DisplayTimeZone.brasilia;

  @override
  bool updateShouldNotify(TimeDisplay oldWidget) => zone != oldWidget.zone;
}
