import 'dart:convert';

import 'package:flutter/material.dart';

/// Styles the bundled vector map without changing its offline source URLs.
String themedMapStyle(String source, ColorScheme colors) {
  final dark = colors.brightness == Brightness.dark;
  final style = jsonDecode(source) as Map<String, dynamic>;
  final layers = style['layers'] as List<dynamic>;
  final palette = <String, String>{
    'background': dark ? '#17120F' : '#FFFBF7',
    'water': dark ? '#243E45' : '#BAD8DC',
    'landuse': dark ? '#283127' : '#E1E8D8',
    'buildings': dark ? '#372B24' : '#EADFD5',
    'roads': dark ? '#665044' : '#FFFFFF',
    'boundaries': mapColor(colors.primary),
  };
  for (final layer in layers.cast<Map<String, dynamic>>()) {
    final color = palette[layer['id']];
    if (color == null) continue;
    final paint = layer['paint'] as Map<String, dynamic>;
    final type = layer['type'] as String;
    paint['$type-color'] = color;
    if (layer['id'] == 'buildings') {
      paint['fill-outline-color'] = dark ? '#48372C' : '#DACBBE';
      paint['fill-opacity'] = 0.8;
    }
    if (layer['id'] == 'boundaries') {
      paint['line-opacity'] = 0.35;
      paint['line-width'] = 1;
    }
    if (layer['id'] == 'roads') {
      layer['layout'] = {'line-cap': 'round', 'line-join': 'round'};
      paint['line-width'] = [
        'interpolate',
        ['linear'],
        ['zoom'],
        8,
        0.6,
        12,
        1.8,
        15,
        5,
        17,
        10,
      ];
    }
  }
  final roadIndex = layers.indexWhere((layer) => layer['id'] == 'roads');
  if (roadIndex >= 0) {
    final roads = layers[roadIndex] as Map<String, dynamic>;
    layers.insert(roadIndex, {
      ...roads,
      'id': 'road-casing',
      'paint': {
        'line-color': dark ? '#211A15' : '#DED0C3',
        'line-width': [
          'interpolate',
          ['linear'],
          ['zoom'],
          8,
          1,
          12,
          3,
          15,
          7,
          17,
          13,
        ],
        'line-opacity': 0.8,
      },
    });
  }
  // Land sits below water so mixed polygons cannot tint lakes and rivers.
  final landIndex = layers.indexWhere((layer) => layer['id'] == 'landuse');
  final waterIndex = layers.indexWhere((layer) => layer['id'] == 'water');
  if (landIndex > waterIndex && waterIndex >= 0) {
    layers.insert(waterIndex, layers.removeAt(landIndex));
  }
  style['name'] = 'USRA R3 ${dark ? 'night' : 'day'}';
  return jsonEncode(style);
}

String mapColor(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
