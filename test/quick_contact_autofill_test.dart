import 'package:flutter_test/flutter_test.dart';
import 'package:usra_r3/quick_contact_autofill.dart';
import 'package:usra_r3/quick_contact_parser.dart';

const record = QuickContactAutofillRecord(
  operatorName: 'Samuel Moraes',
  location: 'GG30CH',
  stationType: 'F',
  energy: 'AC',
  powerWatts: 25,
);

void main() {
  test('suggests missing fields using the same normal-form sources', () {
    final completion = QuickContactCompletion.from(
      draft: parseQuickContact('PY3SC '),
      latest: record,
      latestOnFrequency: record,
    );

    expect(completion?.text, 'SAMUEL MORAES GG30CH 25W FIXA AC ST');
    expect(completion?.fields, [
      'nome',
      'grid',
      'potência',
      'estação',
      'energia',
      'tráfego',
    ]);
  });

  test('does not overwrite fields already typed', () {
    final completion = QuickContactCompletion.from(
      draft: parseQuickContact('PY3SC 6W PORT BAT ST VIA PY3MM '),
      latest: record,
      latestOnFrequency: record,
    );

    expect(completion?.text, 'SAMUEL MORAES GG30CH');
    expect(completion?.fields, ['nome', 'grid']);
  });

  test('uses power from the selected frequency only', () {
    final completion = QuickContactCompletion.from(
      draft: parseQuickContact('PY3SC '),
      latest: record,
      latestOnFrequency: null,
    );

    expect(completion?.text, 'SAMUEL MORAES GG30CH FIXA AC ST');
    expect(completion?.text.contains('25W'), isFalse);
  });

  test('does not suggest an invalid or free-text location as a grid', () {
    final completion = QuickContactCompletion.from(
      draft: parseQuickContact('PY3SC '),
      latest: const QuickContactAutofillRecord(
        operatorName: 'Samuel',
        location: 'Santa Maria',
        stationType: 'P',
        energy: 'B',
      ),
      latestOnFrequency: null,
    );

    expect(completion?.text, 'SAMUEL PORT BAT ST');
  });

  test('does not fill via, traffic message, or an existing traffic block', () {
    final completion = QuickContactCompletion.from(
      draft: parseQuickContact('PY3SC X APOIO X VIA PY3MM '),
      latest: record,
      latestOnFrequency: record,
    );

    expect(completion?.text, 'SAMUEL MORAES GG30CH 25W FIXA AC');
    expect(completion?.text.contains('VIA'), isFalse);
    expect(completion?.text.contains('ST'), isFalse);
  });
}
