/// Validation and precision helpers for Maidenhead (QTH) grid locators.
class GridLocator {
  const GridLocator._();

  static final _pattern = RegExp(
    r'^([A-Ra-r]{2}[0-9]{2})([A-Xa-x]{2})?([0-9]{2})?([A-Xa-x]{2})?$',
  );

  static GridLocatorInfo inspect(String value) {
    final normalized = value.trim().toUpperCase();
    final valid = _pattern.hasMatch(normalized) && _isAllowedLength(normalized);
    if (!valid) return const GridLocatorInfo.invalid();

    final pairLength = normalized.length;
    final accuracy = switch (pairLength) {
      4 => const GridLocatorAccuracy(kilometers: 2000),
      6 => const GridLocatorAccuracy(kilometers: 10),
      8 => const GridLocatorAccuracy(meters: 900),
      10 => const GridLocatorAccuracy(meters: 40),
      _ => null,
    };

    return GridLocatorInfo(
      normalized: normalized,
      isValid: true,
      accuracy: accuracy,
    );
  }

  static String fromCoordinates(
    double latitude,
    double longitude, {
    int length = 10,
  }) {
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Coordinates out of range');
    }
    var lon = longitude + 180;
    var lat = latitude + 90;
    final result = StringBuffer();
    final fieldLon = (lon / 20).floor().clamp(0, 17);
    final fieldLat = (lat / 10).floor().clamp(0, 17);
    result
      ..write(String.fromCharCode(65 + fieldLon))
      ..write(String.fromCharCode(65 + fieldLat));
    lon %= 20;
    lat %= 10;
    final squareLon = (lon / 2).floor().clamp(0, 9);
    final squareLat = lat.floor().clamp(0, 9);
    result
      ..write(squareLon)
      ..write(squareLat);
    lon %= 2;
    lat %= 1;
    if (length >= 6) {
      final subLon = (lon * 12).floor().clamp(0, 23);
      final subLat = (lat * 24).floor().clamp(0, 23);
      result
        ..write(String.fromCharCode(65 + subLon))
        ..write(String.fromCharCode(65 + subLat));
      lon = lon * 12 - subLon;
      lat = lat * 24 - subLat;
    }
    if (length >= 8) {
      final extLon = (lon * 10).floor().clamp(0, 9);
      final extLat = (lat * 10).floor().clamp(0, 9);
      result
        ..write(extLon)
        ..write(extLat);
      lon = lon * 10 - extLon;
      lat = lat * 10 - extLat;
    }
    if (length >= 10) {
      final superLon = (lon * 24).floor().clamp(0, 23);
      final superLat = (lat * 24).floor().clamp(0, 23);
      result
        ..write(String.fromCharCode(65 + superLon))
        ..write(String.fromCharCode(65 + superLat));
    }
    return result.toString();
  }

  static GridLocatorBounds? bounds(String value) {
    final info = inspect(value);
    if (!info.isValid) return null;
    final grid = info.normalized;
    var lon = (grid.codeUnitAt(0) - 65).toDouble();
    var lat = (grid.codeUnitAt(1) - 65).toDouble();
    var lonSize = 20.0;
    var latSize = 10.0;
    lon = lon * 20;
    lat = lat * 10;
    lon += int.parse(grid[2]) * 2;
    lat += int.parse(grid[3]);
    lonSize = 2;
    latSize = 1;
    if (grid.length >= 6) {
      lon += (grid.codeUnitAt(4) - 65) * (2 / 24);
      lat += (grid.codeUnitAt(5) - 65) * (1 / 24);
      lonSize = 2 / 24;
      latSize = 1 / 24;
    }
    if (grid.length >= 8) {
      lon += int.parse(grid[6]) * (lonSize / 10);
      lat += int.parse(grid[7]) * (latSize / 10);
      lonSize /= 10;
      latSize /= 10;
    }
    if (grid.length >= 10) {
      lon += (grid.codeUnitAt(8) - 65) * (lonSize / 24);
      lat += (grid.codeUnitAt(9) - 65) * (latSize / 24);
      lonSize /= 24;
      latSize /= 24;
    }
    return GridLocatorBounds(
      minLongitude: lon - 180,
      minLatitude: lat - 90,
      maxLongitude: lon + lonSize - 180,
      maxLatitude: lat + latSize - 90,
    );
  }

  static bool _isAllowedLength(String value) =>
      value.length == 4 ||
      value.length == 6 ||
      value.length == 8 ||
      value.length == 10;
}

class GridLocatorBounds {
  const GridLocatorBounds({
    required this.minLatitude,
    required this.minLongitude,
    required this.maxLatitude,
    required this.maxLongitude,
  });
  final double minLatitude;
  final double minLongitude;
  final double maxLatitude;
  final double maxLongitude;
  double get centerLatitude => (minLatitude + maxLatitude) / 2;
  double get centerLongitude => (minLongitude + maxLongitude) / 2;
}

class GridLocatorInfo {
  const GridLocatorInfo({
    required this.normalized,
    required this.isValid,
    this.accuracy,
  });

  const GridLocatorInfo.invalid()
    : normalized = '',
      isValid = false,
      accuracy = null;

  final String normalized;
  final bool isValid;
  final GridLocatorAccuracy? accuracy;
}

class GridLocatorAccuracy {
  const GridLocatorAccuracy({this.kilometers, this.meters});

  final double? kilometers;
  final double? meters;

  String get label {
    if (meters != null) {
      return meters == meters!.roundToDouble()
          ? 'precisão de ${meters!.round().toString()} m'
          : 'precisão de ${meters!.toStringAsFixed(1)} m';
    }
    final value = kilometers!;
    return value == value.roundToDouble()
        ? 'precisão de ${value.round().toString()} km'
        : 'precisão de ${value.toStringAsFixed(1)} km';
  }
}
