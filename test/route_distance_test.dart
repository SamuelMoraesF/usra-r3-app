import 'package:flutter_test/flutter_test.dart';
import 'package:usra_r3/grid_locator.dart';
import 'package:usra_r3/map/contact_scene.dart';
import 'package:usra_r3/map/route_distance.dart';

void main() {
  test(
    'formats meters below 1000 and kilometers from 1000 with one decimal',
    () {
      expect(formatDistance(32.4), '32 m');
      expect(formatDistance(999), '999 m');
      expect(formatDistance(1000), '1,0 km');
      expect(formatDistance(1250), '1,3 km');
      expect(formatDistance(12345), '12,3 km');
    },
  );

  test('distance and midpoint of a one-degree equatorial segment', () {
    final a = GridLocator.fromCoordinates(0, 0);
    final b = GridLocator.fromCoordinates(0, 1);
    final label = routeDistances([
      ContactRoute([a, b]),
    ]).single;
    expect(label.meters, closeTo(111195, 40));
    expect(label.latitude, closeTo(0, .001));
    expect(label.longitude, closeTo(.5, .001));
  });

  test('via routes label both legs and shared or reversed legs only once', () {
    const a = 'GG30BG78WC';
    const b = 'GG30DH31GH';
    const c = 'GG30CH90NH';
    final labels = routeDistances([
      const ContactRoute([a, b, c]),
      const ContactRoute([b, a]),
    ]);
    expect(labels, hasLength(2));
    expect(labels.every((label) => label.meters > 0), isTrue);
    expect(routeDistances([]), isEmpty);
    expect(
      routeDistances([
        const ContactRoute([a, a]),
      ]),
      isEmpty,
    );
  });
}
