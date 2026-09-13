import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra_r3/map/map_palette.dart';

void main() {
  final source = File('assets/maps/santa-maria-style.json').readAsStringSync();

  for (final brightness in Brightness.values) {
    test('$brightness keeps offline sources and coherent layer ordering', () {
      final colors = ColorScheme.fromSeed(
        seedColor: const Color(0xFFF36F21),
        brightness: brightness,
      );
      final original = jsonDecode(source) as Map<String, dynamic>;
      final result =
          jsonDecode(themedMapStyle(source, colors)) as Map<String, dynamic>;
      expect(result['sources'], original['sources']);
      final layers = result['layers'] as List<dynamic>;
      final ids = layers.map((layer) => layer['id']).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.indexOf('landuse'), lessThan(ids.indexOf('water')));
      expect(ids.indexOf('water'), lessThan(ids.indexOf('waterway')));
      expect(ids.indexOf('waterway'), lessThan(ids.indexOf('buildings')));
      final water = layers.firstWhere((layer) => layer['id'] == 'water');
      expect(water['filter'], ['==', '\$type', 'Polygon']);
      final waterway = layers.firstWhere(
        (layer) => layer['id'] == 'waterway',
      );
      expect(waterway['type'], 'line');
      expect(waterway['filter'], ['==', '\$type', 'LineString']);
      expect(
        waterway['paint']['line-color'],
        brightness == Brightness.dark ? '#243E45' : '#BAD8DC',
      );
      expect(ids.indexOf('road-casing') + 1, ids.indexOf('roads'));
      expect(
        layers.first['paint']['background-color'],
        brightness == Brightness.dark ? '#17120F' : '#FFFBF7',
      );
      expect(result.containsKey('glyphs'), isFalse);
      expect(result.containsKey('sprite'), isFalse);
    });
  }

  test('preserves native file source when switching themes', () {
    final native = jsonDecode(source) as Map<String, dynamic>;
    native['sources']['basemap']['url'] = 'pmtiles://file:///maps/city.pmtiles';
    final result = jsonDecode(
      themedMapStyle(
        jsonEncode(native),
        ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
    );
    expect(result['sources'], native['sources']);
  });
}
