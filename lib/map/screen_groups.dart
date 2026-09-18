import 'dart:math';

/// Seed-based grouping using neighboring screen cells only. Preserves input
/// seed priority and the previous descending member order.
List<List<int>> screenGroups(List<Point<num>> points, double radius) {
  final cells = <(int, int), Set<int>>{};
  (int, int) cell(Point<num> p) =>
      ((p.x / radius).floor(), (p.y / radius).floor());
  for (var i = 0; i < points.length; i++) {
    cells.putIfAbsent(cell(points[i]), () => <int>{}).add(i);
  }
  final assigned = <int>{};
  final groups = <List<int>>[];
  for (var seed = 0; seed < points.length; seed++) {
    if (assigned.contains(seed)) continue;
    final p = points[seed];
    final (x, y) = cell(p);
    final members = <int>[];
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final i in cells[(x + dx, y + dy)] ?? <int>{}) {
          if (i == seed) continue;
          final delta = points[i] - p;
          if (delta.x * delta.x + delta.y * delta.y <= radius * radius) {
            members.add(i);
          }
        }
      }
    }
    members.sort((a, b) => b.compareTo(a));
    final group = [seed, ...members];
    for (final i in group) {
      assigned.add(i);
      cells[cell(points[i])]!.remove(i);
    }
    groups.add(group);
  }
  return groups;
}
