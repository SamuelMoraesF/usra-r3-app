import 'package:shared_preferences/shared_preferences.dart';

const defaultRepeaterGrid = 'GG30BG78WC';

class MapSettings {
  const MapSettings({
    this.showLines = false,
    this.showAll = false,
    this.showCompass = true,
    this.repeaterGrid = defaultRepeaterGrid,
  });

  final bool showLines;
  final bool showAll;
  final bool showCompass;
  final String repeaterGrid;

  static MapSettings read(SharedPreferences preferences) => MapSettings(
    showLines: preferences.getBool('map.showLines') ?? false,
    showAll: preferences.getBool('map.showAll') ?? false,
    showCompass: preferences.getBool('map.showCompass') ?? true,
    repeaterGrid:
        preferences.getString('map.repeaterGrid') ?? defaultRepeaterGrid,
  );

  Future<void> save(SharedPreferences preferences) async {
    await preferences.setBool('map.showLines', showLines);
    await preferences.setBool('map.showAll', showAll);
    await preferences.setBool('map.showCompass', showCompass);
    await preferences.setString('map.repeaterGrid', repeaterGrid);
  }
}
