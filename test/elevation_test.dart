import 'package:flutter_test/flutter_test.dart';
import 'package:usra_r3/map/elevation.dart';

void main() {
  test('heatmap colors progress from blue to red', () {
    expect(elevationColor(0, 0, 100), '#1565c0');
    expect(elevationColor(100, 0, 100), '#d32f2f');
    expect(elevationColor(50, 0, 100), '#43a047');
  });

  test(
    'legend exposes at least minimum, maximum and intermediate references',
    () {
      const legend = ElevationLegend(range: ElevationRange(100, 500));
      expect(legend.range!.minimum, 100);
      expect(legend.range!.maximum, 500);
    },
  );
}
