import '../data/database.dart';
import '../grid_locator.dart';
import 'contact_aggregation.dart';
import 'contact_color.dart';
import 'station_presence.dart';
export 'contact_color.dart' show MarkerKind;
export 'station_presence.dart' show contactFrequencyMhz;

class ContactMarker {
  const ContactMarker(
    this.grid,
    this.kind, {
    this.contactIndex,
    this.stationType = '',
    this.energy = '',
    this.warning = false,
    this.orbitIndex = 0,
    this.orbitCount = 1,
  });
  final String grid;
  final MarkerKind kind;
  final int? contactIndex;
  final String stationType;
  final String energy;
  final bool warning;
  final int orbitIndex;
  final int orbitCount;
  double get radius => contactIndex == null ? 8 : 6;
  String get color =>
      contactMarkerColorHex(kind, stationType: stationType, energy: energy);
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

  /// The color of the marker currently representing each station.
  ///
  /// A selected marker wins when a callsign has more than one marker. This
  /// mirrors the map's visual priority and lets the contact history use the
  /// same station-level result instead of re-evaluating individual logs.
  Map<String, String> get markerColorsByCallsign {
    final colors = <String, String>{};
    for (final marker in markers) {
      final index = marker.contactIndex;
      if (index == null || index >= contacts.length) continue;
      final callsign = contacts[index].latest.callsign.trim().toUpperCase();
      if (callsign.isEmpty) continue;
      if (marker.kind == MarkerKind.selectedContact ||
          !colors.containsKey(callsign)) {
        colors[callsign] = marker.color;
      }
    }
    return colors;
  }
}

String formatCallsigns(Iterable<String> values) {
  final callsigns =
      values
          .map((value) => value.trim().toUpperCase())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  if (callsigns.length < 2) return callsigns.join();
  if (callsigns.length == 2) return '${callsigns[0]} e ${callsigns[1]}';
  return '${callsigns.sublist(0, callsigns.length - 1).join(', ')} e ${callsigns.last}';
}

String formatCallsignsLimited(Iterable<String> values, {int limit = 3}) {
  final callsigns =
      values
          .map((value) => value.trim().toUpperCase())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  if (callsigns.length <= limit) return formatCallsigns(callsigns);
  final shown = callsigns.take(limit).toList();
  final remaining = callsigns.length - shown.length;
  return '${shown.join(', ')} e +$remaining outras';
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
  DateTime? asOf,
  bool includeClosedSession = false,
}) {
  final presence = stationPresence(
    entries,
    now: asOf ?? now,
    sessionStartedAt: sessionStartedAt,
    mode: selectedMode,
    frequencyMhz: selectedFrequencyMhz,
    maxAgeHours: maxAgeHours,
    warningMinutes: warningMinutes,
    disconnections: disconnections,
    includeAllFrequencies: true,
    includeClosedSession: includeClosedSession,
  );
  if (sessionStartedAt == null) return const ContactScene([], [], []);
  final recent = presence.entries;
  final warningKeys = presence.warnings.map(stationPresenceKey).toSet();
  bool selected(LogEntry e) =>
      e.frequency.trim().toLowerCase() == selectedMode.trim().toLowerCase() &&
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
  final contactsByGrid = <String, List<int>>{};
  final displayedContacts = <int>[];
  final displayedStationKeys = <String, int>{};
  bool preferredContact(int candidate, int current) {
    final candidateSelected = selected(contacts[candidate].latest);
    final currentSelected = selected(contacts[current].latest);
    if (candidateSelected != currentSelected) return candidateSelected;
    final candidateDate = contacts[candidate].latest.createdAt;
    final currentDate = contacts[current].latest.createdAt;
    return candidateDate.isAfter(currentDate) ||
        (candidateDate == currentDate &&
            contacts[candidate].latest.id > contacts[current].latest.id);
  }

  for (var i = 0; i < contacts.length; i++) {
    final latest = contacts[i].latest;
    final stationKey =
        '${latest.callsign.trim().toUpperCase()}|${normalized(latest.location)}';
    final previous = displayedStationKeys[stationKey];
    if (previous == null) {
      displayedStationKeys[stationKey] = i;
      displayedContacts.add(i);
    } else if (preferredContact(i, previous)) {
      displayedStationKeys[stationKey] = i;
      displayedContacts[displayedContacts.indexOf(previous)] = i;
    }
  }
  for (final i in displayedContacts) {
    final grid = normalized(contacts[i].latest.location);
    contactsByGrid.putIfAbsent(grid, () => []).add(i);
  }
  // At lower zoom levels only orbitIndex 0 is rendered. Keep the selected
  // frequency at the center when contacts from different frequencies share
  // the same grid, so a gray background contact cannot hide the active one.
  for (final indices in contactsByGrid.values) {
    indices.sort((a, b) {
      final selectedA = selected(contacts[a].latest) ? 0 : 1;
      final selectedB = selected(contacts[b].latest) ? 0 : 1;
      return selectedA.compareTo(selectedB);
    });
  }
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
  for (final i in displayedContacts) {
    final contact = contacts[i];
    markers.add(
      ContactMarker(
        contact.latest.location,
        selected(contact.latest)
            ? MarkerKind.selectedContact
            : MarkerKind.otherContact,
        contactIndex: i,
        stationType: contact.latest.stationType,
        energy: contact.latest.energy,
        warning: warningKeys.contains(stationPresenceKey(contact.latest)),
        orbitIndex: contactsByGrid[normalized(contact.latest.location)]!
            .indexOf(i),
        orbitCount: contactsByGrid[normalized(contact.latest.location)]!.length,
      ),
    );
  }

  if (showLines && GridLocator.bounds(operatorGrid) != null) {
    final routeKeys = <String>{};
    final routeEntries = lastOnly
        ? contacts
              .where((contact) => showAll || selected(contact.latest))
              .map((contact) => contact.latest)
        : visible.where(
            (e) =>
                (showAll || selected(e)) &&
                GridLocator.bounds(e.location) != null,
          );
    for (final entry in routeEntries) {
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
      final grids = [operatorGrid, ?middle, entry.location];
      if (routeKeys.add(grids.map(normalized).join('|'))) {
        routes.add(ContactRoute(grids, missingVia: missingVia));
      }
    }
  }
  return ContactScene(contacts, markers, routes);
}
