import 'package:shared_preferences/shared_preferences.dart';

const defaultRepeaterGrid = 'GG30BG78WC';

class MapSettings {
  const MapSettings({
    this.showLines = false,
    this.showAll = false,
    this.showPrecision = false,
    this.showElevation = false,
    this.showCompass = true,
    this.showCallsigns = false,
    this.focusNewRecord = false,
    this.repeaterGrid = defaultRepeaterGrid,
  });

  final bool showLines;

  /// Include routes from other frequencies; their stations are always visible.
  final bool showAll;
  final bool showPrecision;
  final bool showElevation;
  final bool showCompass;
  final bool showCallsigns;
  final bool focusNewRecord;
  final String repeaterGrid;

  static MapSettings read(SharedPreferences preferences) => MapSettings(
    showLines: preferences.getBool('map.showLines') ?? false,
    showAll: preferences.getBool('map.showAll') ?? false,
    showPrecision: preferences.getBool('map.showPrecision') ?? false,
    showElevation: preferences.getBool('map.showElevation') ?? false,
    showCompass: preferences.getBool('map.showCompass') ?? true,
    showCallsigns: preferences.getBool('map.showCallsigns') ?? false,
    focusNewRecord: preferences.getBool('map.focusNewRecord') ?? false,
    repeaterGrid:
        preferences.getString('map.repeaterGrid') ?? defaultRepeaterGrid,
  );

  Future<void> save(SharedPreferences preferences) async {
    await preferences.setBool('map.showLines', showLines);
    await preferences.setBool('map.showAll', showAll);
    await preferences.setBool('map.showPrecision', showPrecision);
    await preferences.setBool('map.showElevation', showElevation);
    await preferences.setBool('map.showCompass', showCompass);
    await preferences.setBool('map.showCallsigns', showCallsigns);
    await preferences.setBool('map.focusNewRecord', focusNewRecord);
    await preferences.setString('map.repeaterGrid', repeaterGrid);
  }
}
