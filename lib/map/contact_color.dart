import 'package:flutter/material.dart';

enum MarkerKind {
  operator,
  selectedContact,
  otherContact,
  currentRepeater,
  historicalRepeater,
}

/// The station palette used by contact markers on the map.
String contactStationColorHex(String stationType, String energy) {
  return switch (stationType.trim().toUpperCase()) {
    'F' when energy.trim().toUpperCase() == 'AC' => '#4CAF50',
    // Yellow 600 keeps fixed stations distinct from orange mobile stations.
    'F' => '#FDD835',
    'P' => '#F44336',
    'M' => '#FF9800',
    _ => '#9E9E9E',
  };
}

/// Returns exactly the color a map marker receives for its kind.
String contactMarkerColorHex(
  MarkerKind kind, {
  String stationType = '',
  String energy = '',
}) {
  return switch (kind) {
    MarkerKind.operator => '#2196F3',
    MarkerKind.selectedContact => contactStationColorHex(stationType, energy),
    MarkerKind.otherContact => '#9E9E9E',
    MarkerKind.currentRepeater => '#7E57C2',
    MarkerKind.historicalRepeater => '#7E57C2',
  };
}

Color contactMarkerColorValue(String hex) =>
    Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
