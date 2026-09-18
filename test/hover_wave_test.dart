import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:usra_r3/data/database.dart';
import 'package:usra_r3/map/hover_wave.dart';
import 'package:usra_r3/map/map_settings.dart';
import 'package:usra_r3/map/offline_map.dart';

import 'support/map_platform.dart';

List features(TestMapPlatform platform) =>
    platform.sources[HoverWave.sourceId]?['features'] as List? ?? [];

const a = (position: LatLng(-29, -53), color: '#000000');
const b = (position: LatLng(-30, -54), color: '#FF0000');
const c = (position: LatLng(-31, -55), color: '#FF0000');

MapLibreMapController controller(TestMapPlatform platform) =>
    MapLibreMapController(
      maplibrePlatform: platform,
      annotationOrder: const [],
      annotationConsumeTapEvents: const [],
    );

void main() {
  testWidgets('waves reuse source and layers; frames do not rewrite geometry', (
    tester,
  ) async {
    final platform = TestMapPlatform();
    final map = controller(platform);
    final waves = HoverWave(map, (color) async => color);
    waves.setTargets([a]);
    await tester.pump();
    expect(platform.waveSourceAdds, 1);
    expect(platform.waveLayerAdds, 2);
    final paints = platform.wavePaintWrites;
    waves.setTargets([a]);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(platform.wavePaintWrites, greaterThan(paints));
    expect(platform.sourceWrites[HoverWave.sourceId] ?? 0, 0);
    expect(platform.waveLayerAdds, 2);
    expect(platform.paint[HoverWave.layerId(0)]!['icon-allow-overlap'], isTrue);
    waves.setTargets([b]);
    await tester.pump();
    expect(features(platform).single['geometry']['coordinates'], [-54, -30]);
    expect(platform.sourceWrites[HoverWave.sourceId], 1);
    waves.setTargets([]);
    await tester.pump();
    expect(features(platform), isEmpty);
    final stopped = platform.wavePaintWrites;
    await tester.pump(const Duration(seconds: 1));
    expect(platform.wavePaintWrites, stopped);
    waves.dispose();
    map.dispose();
  });

  testWidgets(
    'rapid hover coalesces pending images and source writes to latest target',
    (tester) async {
      final platform = TestMapPlatform();
      final map = controller(platform);
      final image = Completer<String>();
      var first = true;
      final waves = HoverWave(map, (color) {
        if (first) {
          first = false;
          return image.future;
        }
        return Future.value(color);
      });
      waves.setTargets([a]);
      waves.setTargets([b]);
      waves.setTargets([c]);
      image.complete('old-image');
      await tester.pump();
      expect(features(platform).single['geometry']['coordinates'], [-55, -31]);
      expect(features(platform).single['properties']['image'], '#FF0000');
      expect(platform.waveSourceAdds, 1);

      final write = Completer<void>();
      platform.beforeSourceWrite = (_) => write.future;
      waves.setTargets([a]);
      await tester.pump();
      waves.setTargets([b]);
      waves.setTargets([]);
      platform.beforeSourceWrite = null;
      write.complete();
      await tester.pump();
      expect(features(platform), isEmpty);
      expect(platform.sourceWrites[HoverWave.sourceId], 2);
      waves.dispose();
      map.dispose();
    },
  );

  testWidgets('disposing while an image is pending cannot resurrect waves', (
    tester,
  ) async {
    final platform = TestMapPlatform();
    final map = controller(platform);
    final image = Completer<String>();
    final waves = HoverWave(map, (_) => image.future);
    waves.setTargets([a]);
    waves.dispose();
    image.complete('late-image');
    await tester.pump(const Duration(seconds: 1));
    expect(platform.waveSourceAdds, 0);
    expect(platform.wavePaintWrites, 0);
    map.dispose();
  });

  testWidgets(
    'map hover follows clusters, zoom and precision without restarting on idle',
    (tester) async {
      rootBundle.clear();
      final originalFactory = MapLibrePlatform.createInstance;
      final platform = TestMapPlatform();
      MapLibrePlatform.createInstance = () => platform;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final directory = Directory.systemTemp.createTempSync('map-wave-test-');
      File('${directory.path}/santa-maria-rs.pmtiles').writeAsBytesSync([]);
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => directory.path,
      );
      final hover = ValueNotifier('');
      addTearDown(() {
        hover.dispose();
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
        for (var i = 0; i < 3; i++)
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
            location: i < 2 ? 'GG30CH' : 'GG30EH',
            operatorGrid: 'GG30DH',
            powerWatts: 5,
            stationType: 'P',
            traffic: 'S',
            trafficMessage: '',
          ),
      ];
      Widget app(bool precision) => MaterialApp(
        home: Scaffold(
          body: OfflineContactsMap(
            entries: entries,
            operatorGrid: 'GG30DH',
            sessionStartedAt: now,
            selectedMode: 'simplex',
            selectedFrequencyMhz: 146.52,
            hoveredCallsignListenable: hover,
            settings: MapSettings(showPrecision: precision),
          ),
        ),
      );
      Future<void> waitFor(bool Function() ready) async {
        for (var i = 0; i < 100 && !ready(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(ready(), isTrue);
      }

      await tester.pumpWidget(app(true));
      await waitFor(() => platform.created);
      platform.onMapStyleLoadedPlatform(null);
      await tester.pump();
      hover.value = 'PY3TEST1';
      await waitFor(() => features(platform).isNotEmpty);
      final clusterPoint = features(platform).single['geometry']['coordinates'];
      expect(
        features(platform).single['properties']['image'],
        contains('000000'),
      );
      final writes = platform.sourceWrites[HoverWave.sourceId] ?? 0;
      final batches = platform.batchProjections;
      platform.onCameraIdlePlatform(
        const CameraPosition(target: LatLng(-29, -53), zoom: 12),
      );
      await tester.pump();
      expect(platform.batchProjections - batches, 1);
      expect(platform.sourceWrites[HoverWave.sourceId] ?? 0, writes);
      hover.value = 'PY3TEST0';
      await tester.pump();
      expect(platform.sourceWrites[HoverWave.sourceId] ?? 0, writes);
      hover.value = 'PY3TEST2';
      await waitFor(
        () =>
            features(platform).isNotEmpty &&
            !listEquals(
              features(platform).single['geometry']['coordinates'] as List,
              clusterPoint as List,
            ),
      );
      await tester.pumpWidget(app(false));
      await tester.pump();
      expect(features(platform), hasLength(1));
      expect(platform.waveSourceAdds, 1);
      expect(platform.waveLayerAdds, 2);

      hover.value = 'PY3TEST1';
      await tester.pump();
      platform.onCameraIdlePlatform(
        const CameraPosition(target: LatLng(-29, -53), zoom: 16),
      );
      await tester.pump();
      await waitFor(
        () =>
            features(platform).isNotEmpty &&
            !listEquals(
              features(platform).single['geometry']['coordinates'] as List,
              clusterPoint as List,
            ),
      );
      expect(
        features(platform).single['properties']['image'],
        isNot(contains('000000')),
      );
      expect(platform.waveSourceAdds, 1);
      final beforeZoomOut = platform.batchProjections;
      platform.onCameraIdlePlatform(
        const CameraPosition(target: LatLng(-29, -53), zoom: 12),
      );
      await tester.pump();
      expect(platform.batchProjections - beforeZoomOut, 1);
      expect(
        features(platform).single['geometry']['coordinates'],
        clusterPoint,
      );
      hover.value = '';
      await tester.pump();
      expect(features(platform), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
