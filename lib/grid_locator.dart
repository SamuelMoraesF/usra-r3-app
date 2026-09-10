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
      8 => const GridLocatorAccuracy(meters: 1000),
      10 => const GridLocatorAccuracy(meters: 50),
      _ => null,
    };

    return GridLocatorInfo(
      normalized: normalized,
      isValid: true,
      accuracy: accuracy,
    );
  }

  static bool _isAllowedLength(String value) =>
      value.length == 4 ||
      value.length == 6 ||
      value.length == 8 ||
      value.length == 10;
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
