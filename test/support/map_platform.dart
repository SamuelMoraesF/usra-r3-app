import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

// Exercise the real widget/controller/annotation managers, with a platform
// that records the sources and paint which would be sent to the renderer.
class TestMapPlatform extends MapLibrePlatform {
  final sources = <String, Map<String, dynamic>>{};
  final paint = <String, Map<String, dynamic>>{};
  int styleReplacements = 0;
  int cameraMoves = 0;
  int batchProjections = 0;
  int singleProjections = 0;
  Future<void> Function(String sourceId)? beforeSourceWrite;
  int waveLayerAdds = 0;
  int wavePaintWrites = 0;
  int waveSourceAdds = 0;
  final sourceWrites = <String, int>{};
  @override
  Future<List<Point>> toScreenLocationBatch(Iterable<LatLng> positions) async {
    batchProjections++;
    return positions
        .map((p) => Point(p.longitude * 100000, p.latitude * 100000))
        .toList();
  }

  @override
  Future<Point> toScreenLocation(LatLng position) async {
    singleProjections++;
    return Point(position.longitude * 100000, position.latitude * 100000);
  }

  @override
  Future<LatLng> toLatLng(Point screenLocation) async =>
      LatLng(screenLocation.y / 100000, screenLocation.x / 100000);

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    bool enableInteraction = true,
  }) async {
    if (sourceId == 'contact-hover-waves') {
      waveLayerAdds++;
      if (enableInteraction) {
        throw StateError('Waves must not intercept clicks');
      }
    }
  }

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
    if (sourceId == 'contact-hover-waves') waveSourceAdds++;
    sources[sourceId] = geojson;
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {
    await beforeSourceWrite?.call(sourceId);
    if (!sources.containsKey(sourceId)) {
      throw StateError('Missing map source: $sourceId');
    }
    sources[sourceId] = geojson;
    sourceWrites.update(sourceId, (count) => count + 1, ifAbsent: () => 1);
  }

  @override
  Future<void> setLayerProperties(
    String layerId,
    Map<String, dynamic> properties,
  ) async {
    if (layerId.startsWith('contact-hover-waves')) wavePaintWrites++;
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
