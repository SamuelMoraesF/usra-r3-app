import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ElevationSample {
  const ElevationSample(this.latitude, this.longitude, this.meters);
  final double latitude;
  final double longitude;
  final double meters;
}

class ElevationRange {
  const ElevationRange(this.minimum, this.maximum);
  final double minimum;
  final double maximum;
}

class ElevationGrid {
  ElevationGrid._({required Map<String, dynamic> metadata, required this.data})
    : west = (metadata['west'] as num).toDouble(),
      east = (metadata['east'] as num).toDouble(),
      south = (metadata['south'] as num).toDouble(),
      north = (metadata['north'] as num).toDouble(),
      stepLongitude = (metadata['stepLongitude'] as num).toDouble(),
      stepLatitude = (metadata['stepLatitude'] as num).toDouble(),
      columns = (metadata['columns'] as num).toInt(),
      rows = (metadata['rows'] as num).toInt(),
      nodata = (metadata['nodata'] as num?)?.toInt() ?? -32768;

  final double west;
  final double east;
  final double south;
  final double north;
  final double stepLongitude;
  final double stepLatitude;
  final int columns;
  final int rows;
  final int nodata;
  final Uint8List data;

  static Future<ElevationGrid> load({
    String prefix = 'assets/maps/santa-maria-rs-elevation',
  }) async {
    final metadata = jsonDecode(await rootBundle.loadString('$prefix.json'));
    final byteData = await rootBundle.load('$prefix.bin');
    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    return ElevationGrid._(
      metadata: Map<String, dynamic>.from(metadata as Map),
      data: bytes,
    );
  }

  double? elevationAt(double latitude, double longitude) {
    if (latitude < south ||
        latitude > north ||
        longitude < west ||
        longitude > east) {
      return null;
    }
    final column = ((longitude - west) / stepLongitude)
        .round()
        .clamp(0, columns - 1)
        .toInt();
    final row = ((north - latitude) / stepLatitude)
        .round()
        .clamp(0, rows - 1)
        .toInt();
    final offset = (row * columns + column) * 2;
    if (offset < 0 || offset + 2 > data.length) return null;
    final value = ByteData.sublistView(data).getInt16(offset, Endian.little);
    return value == nodata ? null : value.toDouble();
  }

  List<ElevationSample> samplesIn({
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
    int maxSamples = 2200,
  }) {
    final minLat = minLatitude.clamp(south, north).toDouble();
    final maxLat = maxLatitude.clamp(south, north).toDouble();
    final minLon = minLongitude.clamp(west, east).toDouble();
    final maxLon = maxLongitude.clamp(west, east).toDouble();
    if (minLat > maxLat || minLon > maxLon) return const [];
    final firstColumn = ((minLon - west) / stepLongitude)
        .floor()
        .clamp(0, columns - 1)
        .toInt();
    final lastColumn = ((maxLon - west) / stepLongitude)
        .ceil()
        .clamp(0, columns - 1)
        .toInt();
    final firstRow = ((north - maxLat) / stepLatitude)
        .floor()
        .clamp(0, rows - 1)
        .toInt();
    final lastRow = ((north - minLat) / stepLatitude)
        .ceil()
        .clamp(0, rows - 1)
        .toInt();
    final total = (lastColumn - firstColumn + 1) * (lastRow - firstRow + 1);
    final stride = total <= maxSamples
        ? 1
        : math.sqrt(total / maxSamples).ceil();
    final view = ByteData.sublistView(data);
    final result = <ElevationSample>[];
    for (var row = firstRow; row <= lastRow; row += stride) {
      for (var column = firstColumn; column <= lastColumn; column += stride) {
        final offset = (row * columns + column) * 2;
        if (offset < 0 || offset + 2 > data.length) continue;
        final value = view.getInt16(offset, Endian.little);
        if (value == nodata) continue;
        result.add(
          ElevationSample(
            north - (row + .5) * stepLatitude,
            west + (column + .5) * stepLongitude,
            value.toDouble(),
          ),
        );
      }
    }
    return result;
  }
}

const _elevationStops = <Color>[
  Color(0xff1565c0),
  Color(0xff00a9c7),
  Color(0xff43a047),
  Color(0xffffd600),
  Color(0xffd32f2f),
];

String elevationColor(double value, double minimum, double maximum) {
  final t = maximum <= minimum
      ? .5
      : ((value - minimum) / (maximum - minimum)).clamp(0.0, 1.0);
  final scaled = t * (_elevationStops.length - 1);
  final index = scaled.floor().clamp(0, _elevationStops.length - 2);
  final local = scaled - index;
  final a = _elevationStops[index];
  final b = _elevationStops[index + 1];
  int mix(int x, int y) => (x + (y - x) * local).round();
  return '#${mix((a.r * 255).round(), (b.r * 255).round()).toRadixString(16).padLeft(2, '0')}'
      '${mix((a.g * 255).round(), (b.g * 255).round()).toRadixString(16).padLeft(2, '0')}'
      '${mix((a.b * 255).round(), (b.b * 255).round()).toRadixString(16).padLeft(2, '0')}';
}

class ElevationLegend extends StatelessWidget {
  const ElevationLegend({super.key, required this.range});
  final ElevationRange? range;

  @override
  Widget build(BuildContext context) {
    final current = range;
    if (current == null) return const SizedBox.shrink();
    final values = List<double>.generate(
      5,
      (index) =>
          current.minimum + (current.maximum - current.minimum) * index / 4,
    );
    return Material(
      elevation: 3,
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .93),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Altitude (m)',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 5),
            Container(
              width: 170,
              height: 9,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: const LinearGradient(colors: _elevationStops),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: 170,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: values
                    .map(
                      (value) => Text(
                        _formatMeters(value),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMeters(double value) => value.round().toString();
}
