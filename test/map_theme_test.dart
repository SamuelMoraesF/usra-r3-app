import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:usra_r3/data/database.dart';
import 'package:usra_r3/map/offline_map.dart';

// Exercise the real widget/controller/annotation managers, with a platform
// that records the sources and paint which would be sent to the renderer.
class _MapPlatform extends MapLibrePlatform {
  final sources = <String, Map<String, dynamic>>{};
  final paint = <String, Map<String, dynamic>>{};
  int styleReplacements = 0;
  int cameraMoves = 0;
  bool created = false;

  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) {
    if (!created) {
      created = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onPlatformViewCreated(1);
      });
    }
    return const SizedBox.expand();
  }

  @override
  Future<void> initPlatform(int id) async {}

  @override
  Future<CameraPosition?> updateMapOptions(Map<String, dynamic> updates) async {
    if (updates.containsKey('styleString')) {
      styleReplacements++;
      sources.clear();
    }
    return null;
  }

  @override
  Future<void> setStyle(String style) async {
    styleReplacements++;
    sources.clear();
  }

  @override
  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson, {
    String? promoteId,
  }) async {
    sources[sourceId] = geojson;
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {
    if (!sources.containsKey(sourceId)) {
      throw StateError('Missing map source: $sourceId');
    }
    sources[sourceId] = geojson;
  }

  @override
  Future<void> setLayerProperties(
    String layerId,
    Map<String, dynamic> properties,
  ) async {
    paint[layerId] = properties;
  }

  @override
  Future<bool?> moveCamera(CameraUpdate cameraUpdate) async {
    cameraMoves++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  testWidgets(
    'repeated theme changes preserve map sources and contact points',
    (tester) async {
      final originalFactory = MapLibrePlatform.createInstance;
      final platform = _MapPlatform();
      MapLibrePlatform.createInstance = () => platform;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final directory = Directory.systemTemp.createTempSync('map-theme-test-');
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
        LogEntry(
          id: 1,
          networkStartedAt: now,
          createdAt: now,
          callsign: 'PY3TEST',
          via: '',
          frequency: 'simplex',
          frequencyMhz: 146.52,
          energy: 'B',
          operatorName: 'Teste',
          location: 'GG30CH',
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

      for (final brightness in [
        Brightness.dark,
        Brightness.light,
        Brightness.dark,
      ]) {
        await tester.pumpWidget(app(brightness));
        await tester.pumpAndSettle();
        expect(platform.styleReplacements, 0);
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
