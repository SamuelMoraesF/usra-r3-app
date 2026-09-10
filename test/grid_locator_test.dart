import 'package:flutter_test/flutter_test.dart';
import 'package:usra_r3/grid_locator.dart';

void main() {
  group('GridLocator', () {
    test('accepts valid locators from four to ten characters', () {
      for (final value in ['GG30', 'gg30ch', 'GG30CH90', 'gg30ch90nh']) {
        expect(GridLocator.inspect(value).isValid, isTrue, reason: value);
      }
    });

    test('rejects invalid field, square, sub-square and lengths', () {
      for (final value in [
        'SG30',
        'GS30',
        'GGAA',
        'GG30CY',
        'GG30CH90N',
        'GG30CH90ZZ',
      ]) {
        expect(GridLocator.inspect(value).isValid, isFalse, reason: value);
      }
    });

    test('normalizes valid values to uppercase', () {
      expect(GridLocator.inspect('gg30ch90nh').normalized, 'GG30CH90NH');
    });

    test('reports decreasing precision', () {
      expect(
        GridLocator.inspect('GG30').accuracy!.label,
        'precisão de 2000 km',
      );
      expect(
        GridLocator.inspect('GG30CH').accuracy!.label,
        'precisão de 10 km',
      );
      expect(
        GridLocator.inspect('GG30CH90').accuracy!.label,
        'precisão de 900 m',
      );
      expect(
        GridLocator.inspect('GG30CH90NH').accuracy!.label,
        'precisão de 40 m',
      );
    });
  });
}
