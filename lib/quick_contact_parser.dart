import 'grid_locator.dart';

class QuickContactDraft {
  const QuickContactDraft({
    this.callsign = '',
    this.name = '',
    this.via = '',
    this.grid = '',
    this.powerWatts,
    this.station = 'P',
    this.energy = 'B',
    this.traffic = 'S',
    this.trafficMessage = '',
    this.hasVia = false,
    this.hasStation = false,
    this.hasEnergy = false,
    this.hasTraffic = false,
    this.errors = const [],
  });

  final String callsign;
  final String name;
  final String via;
  final String grid;
  final double? powerWatts;
  final String station;
  final String energy;
  final String traffic;
  final String trafficMessage;
  final bool hasVia;
  final bool hasStation;
  final bool hasEnergy;
  final bool hasTraffic;
  final List<String> errors;

  bool get hasValidGrid => grid.isNotEmpty && GridLocator.inspect(grid).isValid;

  bool get canRegister =>
      callsign.isNotEmpty &&
      name.isNotEmpty &&
      hasVia &&
      hasValidGrid &&
      powerWatts != null &&
      powerWatts!.isFinite &&
      powerWatts! > 0 &&
      hasStation &&
      hasEnergy &&
      hasTraffic &&
      (traffic != 'C' || trafficMessage.isNotEmpty) &&
      errors.isEmpty;
}

QuickContactDraft parseQuickContact(String source) {
  final trimmed = source.trim();
  if (trimmed.isEmpty) return const QuickContactDraft();
  final tokens = trimmed.split(RegExp(r'\s+'));
  final callsign = tokens.first.toUpperCase();
  final name = <String>[];
  final message = <String>[];
  final errors = <String>[];
  var via = '';
  var grid = '';
  double? power;
  var station = 'P';
  var energy = 'B';
  var traffic = 'S';
  var inMessage = false;
  var hasVia = false;
  var hasStation = false;
  var hasEnergy = false;
  var hasTraffic = false;

  String? stationCode(String token) => switch (token) {
    'MOVEL' || 'MOV' => 'M',
    'PORT' || 'POR' || 'PORTATIL' || 'HT' => 'P',
    'FIXA' || 'BASE' => 'F',
    _ => null,
  };

  String? energyCode(String token) => switch (token) {
    'BAT' => 'B',
    'GER' => 'G',
    'AC' => 'AC',
    _ => null,
  };

  for (var index = 1; index < tokens.length; index++) {
    final raw = tokens[index];
    final token = raw.toUpperCase();
    if (token == 'X') {
      traffic = 'C';
      hasTraffic = true;
      inMessage = !inMessage;
      continue;
    }
    if (inMessage) {
      message.add(raw);
      continue;
    }
    if (token == 'VIA') {
      if (index + 1 < tokens.length && tokens[index + 1].toUpperCase() != 'X') {
        via = tokens[++index].toUpperCase();
        hasVia = true;
      } else {
        errors.add('Informe o indicativo após VIA.');
      }
      continue;
    }
    if (GridLocator.looksLikeGrid(raw)) {
      final info = GridLocator.inspect(raw);
      if (!info.isValid) {
        errors.add('Grid inválido: $raw.');
      } else {
        grid = info.normalized;
      }
      continue;
    }
    final compactPower = RegExp(r'^\d+(?:[.,]\d+)?W$').hasMatch(token);
    final separatedPower =
        RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(token) &&
        index + 1 < tokens.length &&
        tokens[index + 1].toUpperCase() == 'W';
    if (compactPower || separatedPower) {
      final value = compactPower ? token.substring(0, token.length - 1) : token;
      power = double.tryParse(value.replaceAll(',', '.'));
      if (separatedPower) index++;
      continue;
    }
    if (token == 'ST') {
      traffic = 'S';
      hasTraffic = true;
      inMessage = false;
      continue;
    }
    final parsedStation = stationCode(token);
    if (parsedStation != null) {
      station = parsedStation;
      hasStation = true;
      continue;
    }
    final parsedEnergy = energyCode(token);
    if (parsedEnergy != null) {
      energy = parsedEnergy;
      hasEnergy = true;
      continue;
    }
    name.add(raw);
  }

  if (traffic == 'C' && message.isEmpty) {
    errors.add('Informe a mensagem após X.');
  }
  return QuickContactDraft(
    callsign: callsign,
    name: name.join(' '),
    via: via,
    grid: grid,
    powerWatts: power,
    station: station,
    energy: energy,
    traffic: traffic,
    trafficMessage: message.join(' '),
    hasVia: hasVia,
    hasStation: hasStation,
    hasEnergy: hasEnergy,
    hasTraffic: hasTraffic,
    errors: errors,
  );
}
