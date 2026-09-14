import '../data/database.dart';
import '../grid_locator.dart';
import 'contact_aggregation.dart';
import 'station_presence.dart';
export 'station_presence.dart' show contactFrequencyMhz;

enum MarkerKind {
  operator,
  selectedContact,
  otherContact,
  currentRepeater,
  historicalRepeater,
}

class ContactMarker {
  const ContactMarker(
    this.grid,
    this.kind, {
    this.contactIndex,
    this.stationType = '',
    this.energy = '',
    this.warning = false,
  });
  final String grid;
  final MarkerKind kind;
  final int? contactIndex;
  final String stationType;
  final String energy;
  final bool warning;
  double get radius => contactIndex == null ? 8 : 6;
  String get color => switch (kind) {
    MarkerKind.operator => '#2196F3',
    MarkerKind.selectedContact => _contactColor(stationType, energy),
    MarkerKind.otherContact => '#9E9E9E',
    MarkerKind.currentRepeater => '#7E57C2',
    MarkerKind.historicalRepeater => '#7E57C2',
  };
}

String _contactColor(String stationType, String energy) {
  return switch (stationType.trim().toUpperCase()) {
    'F' when energy.trim().toUpperCase() == 'AC' => '#4CAF50',
    // Yellow 600 keeps fixed stations distinct from orange mobile stations.
    'F' => '#FDD835',
    'P' => '#F44336',
    'M' => '#FF9800',
    _ => '#9E9E9E',
  };
}

class ContactRoute {
  const ContactRoute(this.grids, {this.missingVia = false});
  final List<String> grids;
  final bool missingVia;
  String get color => missingVia ? '#F44336' : '#808080';
  double get opacity => 0.9;
}

class ContactScene {
  const ContactScene(this.contacts, this.markers, this.routes);
  final List<MapContact> contacts;
  final List<ContactMarker> markers;
  final List<ContactRoute> routes;

  Iterable<MapContact> callsignContacts(String operatorCallsign) =>
      contacts.where(
        (contact) =>
            contact.latest.callsign.trim().toUpperCase() !=
            operatorCallsign.trim().toUpperCase(),
      );
}

ContactScene buildContactScene(
  Iterable<LogEntry> entries, {
  required DateTime now,
  required int maxAgeHours,
  required String operatorGrid,
  required String repeaterGrid,
  required String selectedMode,
  required double selectedFrequencyMhz,
  required DateTime? sessionStartedAt,
  int warningMinutes = defaultContactWarningMinutes,
  StationDisconnections? disconnections,
  bool showAll = false,
  bool showLines = false,
  bool mergePrecision = true,
  bool lastOnly = false,
}) {
  final presence = stationPresence(
    entries,
    now: now,
    sessionStartedAt: sessionStartedAt,
    mode: selectedMode,
    frequencyMhz: selectedFrequencyMhz,
    maxAgeHours: maxAgeHours,
    warningMinutes: warningMinutes,
    disconnections: disconnections,
    includeAllFrequencies: true,
  );
  if (sessionStartedAt == null) return const ContactScene([], [], []);
  final recent = presence.entries;
  final warningKeys = presence.warnings.map(stationPresenceKey).toSet();
  bool selected(LogEntry e) =>
      e.frequency == selectedMode &&
      (contactFrequencyMhz(e) - selectedFrequencyMhz).abs() < 0.000001;
  final visible = recent;
  // Never merge contact history from different frequencies: the same station
  // can be current on one frequency and about to expire on another.
  final frequencyGroups = <String, List<LogEntry>>{};
  for (final entry in visible) {
    final key =
        '${entry.frequency}|${contactFrequencyMhz(entry).toStringAsFixed(6)}';
    frequencyGroups.putIfAbsent(key, () => []).add(entry);
  }
  final contacts =
      frequencyGroups.values
          .expand(
            (group) => aggregateMapContacts(
              group,
              mergePrecision: mergePrecision,
              lastOnlyByCallsign: lastOnly,
            ),
          )
          .toList()
        ..sort(
          (a, b) => (selected(a.latest) ? 1 : 0).compareTo(
            selected(b.latest) ? 1 : 0,
          ),
        );
  final markers = <ContactMarker>[];
  final routes = <ContactRoute>[];
  void marker(String grid, MarkerKind kind) {
    if (GridLocator.bounds(grid) != null) {
      markers.add(ContactMarker(grid, kind));
    }
  }

  marker(operatorGrid, MarkerKind.operator);
  final repeaters = <String>{};
  String normalized(String grid) => GridLocator.inspect(grid).normalized;
  if (selectedMode == 'repeater' ||
      visible.any((e) => e.frequency == 'repeater')) {
    marker(repeaterGrid, MarkerKind.currentRepeater);
    if (GridLocator.bounds(repeaterGrid) != null) {
      repeaters.add(normalized(repeaterGrid));
    }
    for (final entry in visible.where((e) => e.frequency == 'repeater')) {
      final grid = entry.repeaterGrid;
      if (grid != null &&
          GridLocator.bounds(grid) != null &&
          repeaters.add(normalized(grid))) {
        marker(grid, MarkerKind.historicalRepeater);
      }
    }
  }
  for (var i = 0; i < contacts.length; i++) {
    final contact = contacts[i];
    final matching = selected(contact.latest);
    markers.add(
      ContactMarker(
        contact.latest.location,
        matching ? MarkerKind.selectedContact : MarkerKind.otherContact,
        contactIndex: i,
        stationType: contact.latest.stationType,
        energy: contact.latest.energy,
        warning: warningKeys.contains(stationPresenceKey(contact.latest)),
      ),
    );
  }
  if (showLines && GridLocator.bounds(operatorGrid) != null) {
    // Each QSO retains its own route, even when its remote marker is grouped.
    for (final entry in visible.where(
      (e) => (showAll || selected(e)) && GridLocator.bounds(e.location) != null,
    )) {
      String? middle;
      var missingVia = false;
      if (entry.frequency == 'repeater') {
        middle = entry.repeaterGrid;
        // Older records have no historical repeater position: do not invent it.
        if (middle == null || GridLocator.bounds(middle) == null) continue;
      } else if (entry.via.trim().isNotEmpty) {
        final candidates =
            recent
                .where(
                  (e) =>
                      e.frequency == entry.frequency &&
                      (contactFrequencyMhz(e) - contactFrequencyMhz(entry))
                              .abs() <
                          0.000001 &&
                      e.callsign.trim().toUpperCase() ==
                          entry.via.trim().toUpperCase() &&
                      GridLocator.bounds(e.location) != null,
                )
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (candidates.isNotEmpty) {
          middle = candidates.first.location;
        } else {
          missingVia = true;
        }
      }
      routes.add(
        ContactRoute([
          operatorGrid,
          ?middle,
          entry.location,
        ], missingVia: missingVia),
      );
    }
  }
  return ContactScene(contacts, markers, routes);
}
