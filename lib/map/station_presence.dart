import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';

const defaultContactMaxAgeHours = 3;
const defaultContactWarningMinutes = 30;

double contactFrequencyMhz(LogEntry entry) =>
    entry.frequencyMhz ?? (entry.frequency == 'simplex' ? 146.52 : 145.37);

/// Presence is separate from the immutable contact history, and scoped to
/// the session, mode, frequency and station.
String stationPresenceKey(LogEntry entry) => jsonEncode([
  entry.networkStartedAt?.toUtc().toIso8601String(),
  entry.frequency,
  contactFrequencyMhz(entry).toStringAsFixed(6),
  entry.callsign.trim().toUpperCase(),
]);

class StationDisconnections {
  StationDisconnections([Map<String, DateTime> values = const {}])
    : values = Map.unmodifiable(values);

  final Map<String, DateTime> values;
  static const preferenceKey = 'network.stationDisconnections';

  static StationDisconnections read(SharedPreferences preferences) {
    final raw = preferences.getString(preferenceKey);
    if (raw == null) return StationDisconnections();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return StationDisconnections(
        decoded.map(
          (key, value) =>
              MapEntry(key, DateTime.parse(value as String).toUtc()),
        ),
      );
    } on FormatException {
      return StationDisconnections();
    } on TypeError {
      return StationDisconnections();
    }
  }

  StationDisconnections disconnect(LogEntry entry, DateTime now) =>
      StationDisconnections({
        ...values,
        stationPresenceKey(entry): now.toUtc(),
      });

  bool includes(LogEntry entry) {
    final disconnectedAt = values[stationPresenceKey(entry)];
    return disconnectedAt != null && !entry.createdAt.isAfter(disconnectedAt);
  }

  Future<void> save(SharedPreferences preferences) async {
    await preferences.setString(
      preferenceKey,
      jsonEncode(
        values.map(
          (key, value) => MapEntry(key, value.toUtc().toIso8601String()),
        ),
      ),
    );
  }
}

class StationPresence {
  const StationPresence(this.entries, this.warnings, this.nextChange);
  final List<LogEntry> entries;
  final List<LogEntry> warnings;
  final DateTime? nextChange;
}

StationPresence stationPresence(
  Iterable<LogEntry> entries, {
  required DateTime now,
  required DateTime? sessionStartedAt,
  required String mode,
  required double frequencyMhz,
  int maxAgeHours = defaultContactMaxAgeHours,
  int warningMinutes = defaultContactWarningMinutes,
  StationDisconnections? disconnections,
  bool includeAllFrequencies = false,
}) {
  if (sessionStartedAt == null) return const StationPresence([], [], null);
  final lifetime = Duration(hours: maxAgeHours);
  final warningDelay =
      lifetime - Duration(minutes: warningMinutes.clamp(0, lifetime.inMinutes));
  final eligible = entries
      .where(
        (e) =>
            e.networkStartedAt == sessionStartedAt &&
            e.networkEndedAt == null &&
            !e.createdAt.isAfter(now) &&
            (includeAllFrequencies ||
                (e.frequency == mode &&
                    (contactFrequencyMhz(e) - frequencyMhz).abs() <
                        0.000001)) &&
            !(disconnections?.includes(e) ?? false),
      )
      .toList();
  final latest = <String, LogEntry>{};
  for (final entry in eligible) {
    final key = stationPresenceKey(entry);
    final previous = latest[key];
    if (previous == null ||
        entry.createdAt.isAfter(previous.createdAt) ||
        (entry.createdAt == previous.createdAt && entry.id > previous.id)) {
      latest[key] = entry;
    }
  }
  final active = <String>{};
  final warnings = <LogEntry>[];
  DateTime? nextChange;
  void schedule(DateTime time) {
    if (time.isAfter(now) &&
        (nextChange == null || time.isBefore(nextChange!))) {
      nextChange = time;
    }
  }

  for (final entry in latest.values) {
    final expiration = entry.createdAt.add(lifetime);
    if (now.isBefore(expiration)) active.add(stationPresenceKey(entry));
    schedule(expiration);
    final warning = entry.createdAt.add(warningDelay);
    if (warningMinutes > 0) {
      // Browser clocks have millisecond precision; wake after the strict limit.
      schedule(warning.add(const Duration(milliseconds: 1)));
    }
    if (warningMinutes > 0 &&
        now.isAfter(warning) &&
        now.isBefore(expiration)) {
      warnings.add(entry);
    }
  }
  for (final entry in eligible) {
    schedule(entry.createdAt.add(lifetime));
  }
  warnings.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return StationPresence(
    eligible
        .where(
          (e) =>
              active.contains(stationPresenceKey(e)) &&
              now.isBefore(e.createdAt.add(lifetime)),
        )
        .toList(),
    warnings,
    nextChange,
  );
}
