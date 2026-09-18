import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

typedef HoverWaveTarget = ({LatLng position, String color});

/// A separate point source keeps pulses independent of station annotations and
/// precision polygons. Animation changes only two layers' paint/layout values.
class HoverWave {
  HoverWave(this.map, this.imageForColor);

  final MapLibreMapController map;
  final Future<String> Function(String color) imageForColor;
  static const sourceId = 'contact-hover-waves';
  static String layerId(int wave) => '$sourceId-$wave';
  List<HoverWaveTarget> _requested = const [];
  List<HoverWaveTarget> _applied = const [];
  bool _ready = false;
  bool _syncing = false;
  bool _painting = false;
  bool _disposed = false;
  int _revision = 0;
  Timer? _timer;
  final _elapsed = Stopwatch();

  void setTargets(List<HoverWaveTarget> targets) {
    if (_disposed || listEquals(targets, _requested)) return;
    _requested = List.unmodifiable(targets);
    _revision++;
    _elapsed.reset();
    _elapsed.start();
    if (targets.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
    unawaited(_sync());
  }

  Future<void> _sync() async {
    if (_syncing || _disposed) return;
    _syncing = true;
    try {
      while (!_disposed && !listEquals(_requested, _applied)) {
        final targets = _requested;
        final revision = _revision;
        final features = <Map<String, dynamic>>[];
        for (final target in targets) {
          final image = await imageForColor(target.color);
          if (_disposed || revision != _revision) break;
          features.add({
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [
                target.position.longitude,
                target.position.latitude,
              ],
            },
            'properties': {'image': image},
          });
        }
        if (_disposed) return;
        if (revision != _revision) continue;
        final data = <String, dynamic>{
          'type': 'FeatureCollection',
          'features': features,
        };
        if (!_ready) {
          await map.addGeoJsonSource(sourceId, data);
          if (_disposed) return;
          for (var wave = 0; wave < 2; wave++) {
            await map.addSymbolLayer(
              sourceId,
              layerId(wave),
              const SymbolLayerProperties(
                iconImage: ['get', 'image'],
                iconAllowOverlap: true,
                iconIgnorePlacement: true,
                iconSize: 0.25,
                iconOpacity: 0,
              ),
              enableInteraction: false,
            );
            if (_disposed) return;
          }
          _ready = true;
        } else {
          await map.setGeoJsonSource(sourceId, data);
        }
        if (_disposed) return;
        _applied = targets;
      }
      if (!_disposed && _requested.isNotEmpty) {
        _timer ??= Timer.periodic(const Duration(milliseconds: 60), (_) {
          unawaited(_animate());
        });
        await _animate();
      }
    } finally {
      _syncing = false;
    }
    if (!_disposed && !listEquals(_requested, _applied)) {
      unawaited(_sync());
    }
  }

  Future<void> _animate() async {
    if (_disposed || !_ready || _painting || _requested.isEmpty) return;
    _painting = true;
    try {
      final phase = (_elapsed.elapsedMicroseconds / 1700000) % 1;
      await Future.wait([
        for (var wave = 0; wave < 2; wave++)
          map.setLayerProperties(
            layerId(wave),
            SymbolLayerProperties(
              iconImage: const ['get', 'image'],
              iconAllowOverlap: true,
              iconIgnorePlacement: true,
              iconSize: 0.25 + 0.55 * ((phase + wave * 0.5) % 1),
              iconOpacity: 0.75 * (1 - ((phase + wave * 0.5) % 1)),
            ),
          ),
      ]);
    } finally {
      _painting = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _elapsed.stop();
  }
}
