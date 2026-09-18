import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:usra_r3/data/database.dart';
import 'package:usra_r3/map/offline_map.dart';
import 'package:usra_r3/map/map_settings.dart';

import 'support/map_platform.dart';

void main() {
  for (final count in [1, 100]) {
    testWidgets(
      'theme redraw batches $count contacts and preserves map sources',
      (tester) async {
        rootBundle.clear();
        final originalFactory = MapLibrePlatform.createInstance;
        final platform = TestMapPlatform();
        MapLibrePlatform.createInstance = () => platform;
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final directory = Directory.systemTemp.createTempSync(
          'map-theme-test-',
        );
        File('${directory.path}/santa-maria-rs.pmtiles').writeAsBytesSync([]);
        const channel = MethodChannel('plugins.flutter.io/path_provider');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => directory.path,
        );
        addTearDown(() async {
          MapLibrePlatform.createInstance = originalFactory;
          debugDefaultTargetPlatformOverride = null;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
          directory.deleteSync(recursive: true);
        });
        final now = DateTime.now();
        final entries = [
          for (var i = 0; i < count; i++)
            LogEntry(
              id: i + 1,
              networkStartedAt: now,
              createdAt: now,
              callsign: 'PY3TEST$i',
              via: '',
              frequency: 'simplex',
              frequencyMhz: 146.52,
              energy: 'B',
              operatorName: 'Teste',
              location:
                  'GG31${String.fromCharCode(65 + i ~/ 10)}${String.fromCharCode(65 + i % 10)}',
              operatorGrid: 'GG30DH',
              powerWatts: 5,
              stationType: 'P',
              traffic: 'S',
              trafficMessage: '',
            ),
        ];
        Widget app(Brightness brightness) => MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: OfflineContactsMap(
              entries: entries,
              operatorGrid: 'GG30DH',
              sessionStartedAt: now,
              selectedMode: 'simplex',
              selectedFrequencyMhz: 146.52,
              settings: const MapSettings(showPrecision: true),
            ),
          ),
        );

        await tester.pumpWidget(app(Brightness.light));
        for (var attempt = 0; attempt < 100 && !platform.created; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(platform.created, isTrue);
        platform.onMapStyleLoadedPlatform(null);
        await tester.pumpAndSettle();
        final initialSources = jsonDecode(jsonEncode(platform.sources));
        final sourceIds = platform.sources.keys.toList();
        final initialCameraMoves = platform.cameraMoves;
        final points = platform.sources.values
            .expand((source) => source['features'] as List)
            .where((feature) => feature['geometry']['type'] == 'Point');
        expect(points.length, greaterThanOrEqualTo(2));
        expect(platform.batchProjections, greaterThan(0));
        expect(platform.singleProjections, 0);

        for (final brightness in [
          Brightness.dark,
          Brightness.light,
          Brightness.dark,
        ]) {
          final beforeWrites = Map<String, int>.of(platform.sourceWrites);
          await tester.pumpWidget(app(brightness));
          await tester.pumpAndSettle();
          expect(platform.styleReplacements, 0);
          // A redraw clears and repopulates each annotation source in bulk,
          // regardless of the number of contacts (no growing N writes).
          for (final entry in platform.sourceWrites.entries) {
            expect(
              entry.value - (beforeWrites[entry.key] ?? 0),
              lessThanOrEqualTo(2),
              reason: entry.key,
            );
          }
          expect(platform.sources.keys, sourceIds);
          // Annotation IDs can change on redraw, so compare coordinates.
          for (final id in sourceIds) {
            Iterable<dynamic> geometries(Map source) =>
                (source['features'] as List).map(
                  (feature) => feature['geometry'],
                );
            expect(
              geometries(platform.sources[id]!),
              geometries(initialSources[id] as Map),
            );
          }
          expect(platform.cameraMoves, initialCameraMoves);
          expect(
            platform.paint['background']!['background-color'],
            brightness == Brightness.dark ? '#17120F' : '#FFFBF7',
          );
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
}
