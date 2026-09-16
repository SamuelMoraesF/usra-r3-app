import 'grid_locator.dart';
import 'quick_contact_parser.dart';

class QuickContactAutofillRecord {
  const QuickContactAutofillRecord({
    required this.operatorName,
    required this.location,
    required this.stationType,
    required this.energy,
    this.powerWatts,
  });

  final String operatorName;
  final String location;
  final String stationType;
  final String energy;
  final double? powerWatts;
}

class QuickContactCompletion {
  const QuickContactCompletion({required this.text, required this.fields});

  final String text;
  final List<String> fields;

  static QuickContactCompletion? from({
    required QuickContactDraft draft,
    required QuickContactAutofillRecord? latest,
    required QuickContactAutofillRecord? latestOnFrequency,
  }) {
    if (latest == null && latestOnFrequency == null) return null;

    final tokens = <String>[];
    final fields = <String>[];
    void add(String field, String value) {
      final normalized = value.trim().toUpperCase();
      if (normalized.isEmpty) return;
      tokens.add(normalized);
      fields.add(field);
    }

    if (draft.name.isEmpty) {
      add('nome', latest?.operatorName ?? '');
    }
    if (draft.grid.isEmpty && latest != null) {
      final grid = GridLocator.inspect(latest.location);
      if (grid.isValid) add('grid', grid.normalized);
    }
    if (draft.powerWatts == null) {
      final watts = latestOnFrequency?.powerWatts;
      if (watts != null && watts.isFinite && watts > 0) {
        add('potência', '${_formatNumber(watts)}W');
      }
    }
    if (!draft.hasStation) {
      add('estação', _stationToken(latest?.stationType ?? ''));
    }
    if (!draft.hasEnergy) {
      add('energia', _energyToken(latest?.energy ?? ''));
    }
    if (!draft.hasTraffic) add('tráfego', 'ST');

    if (tokens.isEmpty) return null;
    return QuickContactCompletion(
      text: tokens.join(' '),
      fields: List.unmodifiable(fields),
    );
  }

  static String _formatNumber(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toString();

  static String _stationToken(String value) =>
      switch (value.trim().toUpperCase()) {
        'M' => 'MOV',
        'P' => 'PORT',
        'F' => 'FIXA',
        _ => value,
      };

  static String _energyToken(String value) =>
      switch (value.trim().toUpperCase()) {
        'B' => 'BAT',
        'G' => 'GER',
        'AC' => 'AC',
        _ => value,
      };
}
