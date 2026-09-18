import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra_r3/map/screen_groups.dart';

void main() {
  test(
    'spatial grouping matches reference across boundaries, duplicates and negative coordinates',
    () {
      final random = Random(42);
      final points = <Point<num>>[
        const Point(0, 0),
        const Point(0, 0),
        const Point(48, 0),
        for (var i = 0; i < 500; i++)
          Point(
            random.nextDouble() * 2000 - 1000,
            random.nextDouble() * 2000 - 1000,
          ),
      ];
      for (final radius in [48.0, 72.0]) {
        final remaining = List.generate(points.length, (i) => i);
        final expected = <List<int>>[];
        while (remaining.isNotEmpty) {
          final seed = remaining.removeAt(0);
          final group = [seed];
          for (var i = remaining.length - 1; i >= 0; i--) {
            if (points[remaining[i]].distanceTo(points[seed]) <= radius) {
              group.add(remaining.removeAt(i));
            }
          }
          expected.add(group);
        }
        expect(screenGroups(points, radius), expected);
      }
    },
  );
  test('large separated input retains all points and seed order', () {
    final points = List.generate(10000, (i) => Point<num>(i * 100, 0));
    final groups = screenGroups(points, 48);
    expect(groups.length, points.length);
    expect(groups.expand((g) => g), List.generate(points.length, (i) => i));
  });
}
