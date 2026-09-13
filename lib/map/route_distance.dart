import 'dart:math' as math;

import '../grid_locator.dart';
import 'contact_scene.dart';

String formatDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

class RouteDistance {
  const RouteDistance(this.latitude, this.longitude, this.meters);
  final double latitude;
  final double longitude;
  final double meters;
  String get label => formatDistance(meters);
}

List<RouteDistance> routeDistances(Iterable<ContactRoute> routes) {
  const radians = math.pi / 180;
  final result = <RouteDistance>[];
  final seen = <String>{};
  for (final route in routes) {
    for (var i = 1; i < route.grids.length; i++) {
      final a = GridLocator.bounds(route.grids[i - 1]);
      final b = GridLocator.bounds(route.grids[i]);
      if (a == null || b == null) continue;
      final endpoints = [
        '${a.centerLatitude},${a.centerLongitude}',
        '${b.centerLatitude},${b.centerLongitude}',
      ]..sort();
      if (!seen.add(endpoints.join('|'))) continue;
      final latA = a.centerLatitude * radians;
      final latB = b.centerLatitude * radians;
      final deltaLat = latB - latA;
      final deltaLon = (b.centerLongitude - a.centerLongitude) * radians;
      final h =
          math.pow(math.sin(deltaLat / 2), 2) +
          math.cos(latA) * math.cos(latB) * math.pow(math.sin(deltaLon / 2), 2);
      final meters = 6371008.8 * 2 * math.asin(math.sqrt(h.clamp(0, 1)));
      if (meters < 0.01) continue;
      // Center of the straight segment in the map's Mercator projection.
      double mercator(double lat) =>
          math.log(math.tan(math.pi / 4 + lat.clamp(-1.4844, 1.4844) / 2));
      final midY = (mercator(latA) + mercator(latB)) / 2;
      var lonB = b.centerLongitude;
      if (lonB - a.centerLongitude > 180) lonB -= 360;
      if (lonB - a.centerLongitude < -180) lonB += 360;
      result.add(
        RouteDistance(
          (2 * math.atan(math.exp(midY)) - math.pi / 2) / radians,
          ((a.centerLongitude + lonB) / 2 + 180) % 360 - 180,
          meters,
        ),
      );
    }
  }
  return result;
}
