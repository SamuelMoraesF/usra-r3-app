import 'package:flutter_test/flutter_test.dart';
import 'package:usra_r3/quick_contact_parser.dart';

void main() {
  test('interprets callsign, name, via and grid', () {
    final draft = parseQuickContact(
      'PY3SC SAMUEL GG30CH 5W PORT BAT ST VIA PY3MM',
    );

    expect(draft.callsign, 'PY3SC');
    expect(draft.name, 'SAMUEL');
    expect(draft.via, 'PY3MM');
    expect(draft.grid, 'GG30CH');
    expect(draft.canRegister, isTrue);
  });

  test('accepts power with or without a space and aliases', () {
    final draft = parseQuickContact(
      'PY3SC SAMUEL GG30CH 5 W HT GER ST VIA PY3MM',
    );
    expect(draft.powerWatts, 5);
    expect(draft.station, 'P');
    expect(draft.energy, 'G');

    final mobile = parseQuickContact(
      'PY3SC SAMUEL GG30CH 10W MOV BAT ST VIA PY3MM',
    );
    expect(mobile.powerWatts, 10);
    expect(mobile.station, 'M');
    expect(mobile.energy, 'B');
  });

  test('separates traffic and accepts VIA after the message', () {
    final draft = parseQuickContact(
      'PY3SC SAMUEL GG30CH 5W PORT BAT X MENSAGEM DO TRAFEGO X VIA PY3MM',
    );
    expect(draft.traffic, 'C');
    expect(draft.trafficMessage, 'MENSAGEM DO TRAFEGO');
    expect(draft.via, 'PY3MM');
    expect(draft.canRegister, isTrue);

    final ending = parseQuickContact(
      'PY3SC SAMUEL GG30CH 5W PORT BAT X MENSAGEM X VIA PY3MM',
    );
    expect(ending.trafficMessage, 'MENSAGEM');
    expect(ending.via, 'PY3MM');

    final viaInsideMessage = parseQuickContact(
      'PY3SC SAMUEL GG30CH 5W PORT BAT X MENSAGEM VIA PY3MM',
    );
    expect(viaInsideMessage.trafficMessage, 'MENSAGEM VIA PY3MM');
    expect(viaInsideMessage.via, isEmpty);

    final literalMessage = parseQuickContact(
      'PY3SC SAMUEL GG30CH 5W PORT BAT X VIA ST 10W GG30CH FIXA X VIA PY3MM',
    );
    expect(literalMessage.trafficMessage, 'VIA ST 10W GG30CH FIXA');
    expect(literalMessage.via, 'PY3MM');
    expect(literalMessage.station, 'P');
    expect(literalMessage.energy, 'B');
  });

  test('does not register until every required field is present', () {
    final draft = parseQuickContact('PY3SC SAMUEL GG30CH 5W');
    expect(draft.canRegister, isFalse);
    expect(draft.hasVia, isFalse);
    expect(draft.hasStation, isFalse);
    expect(draft.hasEnergy, isFalse);
    expect(draft.hasTraffic, isFalse);
  });

  test('allows via and grid to be omitted', () {
    final draft = parseQuickContact('PY3SC SAMUEL 5W PORT BAT ST');

    expect(draft.via, isEmpty);
    expect(draft.grid, isEmpty);
    expect(draft.canRegister, isTrue);
  });

  test('rejects VIA without an indicativo', () {
    final draft = parseQuickContact('PY3SC SAMUEL 5W PORT BAT ST VIA');

    expect(draft.errors, contains('Informe o indicativo após VIA.'));
    expect(draft.canRegister, isFalse);
  });

  test('rejects an invalid Maidenhead grid', () {
    final draft = parseQuickContact('PY3SC SAMUEL GG30ZZ 5W');
    expect(draft.errors, isNotEmpty);
    expect(draft.canRegister, isFalse);
  });
}
