import '../data/database.dart';
import '../grid_locator.dart';

class MapContact {
  const MapContact({
    required this.latest,
    required this.first,
    required this.last,
  });
  final LogEntry latest;
  final LogEntry first;
  final LogEntry last;
  GridLocatorBounds? get bounds => GridLocator.bounds(latest.location);
}

List<MapContact> aggregateMapContacts(
  Iterable<LogEntry> entries, {
  bool mergePrecision = true,
  bool lastOnlyByCallsign = false,
}) {
  final valid = entries
      .where((entry) => GridLocator.bounds(entry.location) != null)
      .toList();
  if (lastOnlyByCallsign) {
    final groups = <String, List<LogEntry>>{};
    for (final entry in valid) {
      groups.putIfAbsent(entry.callsign.toUpperCase(), () => []).add(entry);
    }
    return groups.values.map(_contact).toList();
  }
  final groups = <String, List<LogEntry>>{};
  for (final entry in valid) {
    final normalized = GridLocator.inspect(entry.location).normalized;
    final key = mergePrecision
        ? _precisionKey(entry.callsign, normalized, valid)
        : '${entry.callsign.toUpperCase()}|$normalized';
    groups.putIfAbsent(key, () => []).add(entry);
  }
  return groups.values.map(_contact).toList();
}

String _precisionKey(String callsign, String grid, List<LogEntry> all) {
  final sameCall = all.where(
    (e) => e.callsign.toUpperCase() == callsign.toUpperCase(),
  );
  final parent = sameCall
      .map((e) => GridLocator.inspect(e.location).normalized)
      .where((other) => grid.startsWith(other) || other.startsWith(grid))
      .fold<String?>(
        null,
        (best, value) =>
            best == null || value.length > best.length ? value : best,
      );
  return '${callsign.toUpperCase()}|${parent ?? grid}';
}

MapContact _contact(List<LogEntry> entries) {
  entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return MapContact(
    first: entries.first,
    last: entries.last,
    latest: entries.last,
  );
}
