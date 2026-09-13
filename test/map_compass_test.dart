import 'package:flutter_test/flutter_test.dart';
import 'package:usra_r3/map/map_compass.dart';

void main() {
  test('normalizes map bearings to the 0-359 degree range', () {
    expect(normalizeBearing(0), 0);
    expect(normalizeBearing(360), 0);
    expect(normalizeBearing(725), 5);
    expect(normalizeBearing(-90), 270);
    expect(normalizeBearing(double.nan), 0);
  });
}
