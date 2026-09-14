import '../data/database.dart';
import '../grid_locator.dart';
import 'contact_aggregation.dart';

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
  });
  final String grid;
  final MarkerKind kind;
  final int? contactIndex;
  final String stationType;
  final String energy;
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
    'F' => '#FFEB3B',
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

double contactFrequencyMhz(LogEntry entry) =>
    entry.frequencyMhz ?? (entry.frequency == 'simplex' ? 146.52 : 145.37);

ContactScene buildContactScene(
  Iterable<LogEntry> entries, {
  required DateTime now,
  required int maxAgeHours,
  required String operatorGrid,
  required String repeaterGrid,
  required String selectedMode,
  required double selectedFrequencyMhz,
  bool showAll = false,
  bool showLines = false,
  bool mergePrecision = true,
  bool lastOnly = false,
}) {
  final cutoff = now.subtract(Duration(hours: maxAgeHours));
  final recent = entries
      .where((e) => !e.createdAt.isBefore(cutoff) && !e.createdAt.isAfter(now))
      .toList();
  bool selected(LogEntry e) =>
      e.frequency == selectedMode &&
      (contactFrequencyMhz(e) - selectedFrequencyMhz).abs() < 0.000001;
  final visible = recent.where((e) => showAll || selected(e)).toList();
  final contacts = aggregateMapContacts(
    visible,
    mergePrecision: mergePrecision,
    lastOnlyByCallsign: lastOnly,
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
  if (selectedMode == 'repeater' || showAll) {
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
    final matching = recent.any(
      (e) =>
          e.callsign.trim().toUpperCase() ==
              contact.latest.callsign.trim().toUpperCase() &&
          selected(e),
    );
    markers.add(
      ContactMarker(
        contact.latest.location,
        matching ? MarkerKind.selectedContact : MarkerKind.otherContact,
        contactIndex: i,
        stationType: contact.latest.stationType,
        energy: contact.latest.energy,
      ),
    );
  }
  if (showLines && GridLocator.bounds(operatorGrid) != null) {
    // Each QSO retains its own route, even when its remote marker is grouped.
    for (final entry in visible.where(
      (e) => GridLocator.bounds(e.location) != null,
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
