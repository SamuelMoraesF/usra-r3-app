import 'package:flutter_test/flutter_test.dart';
import 'package:usra_r3/main.dart';

void main() {
  test('sidebar uses all available width when the map would be too narrow', () {
    expect(homeSidebarWidth(527), 527);
    expect(homeSidebarWidth(899), 899);
    expect(homeSidebarWidth(1000), 480);
  });
}
