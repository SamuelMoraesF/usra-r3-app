import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> prepareNativeOfflineMapStyle() async {
  final directory = await getApplicationSupportDirectory();
  final mapFile = File('${directory.path}/santa-maria-rs.pmtiles');
  if (!await mapFile.exists()) {
    final data = await rootBundle.load('assets/maps/santa-maria-rs.pmtiles');
    await mapFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
  }

  final style = jsonDecode(
    await rootBundle.loadString('assets/maps/santa-maria-style.json'),
  ) as Map<String, dynamic>;
  final sources = style['sources'] as Map<String, dynamic>;
  final basemap = sources['basemap'] as Map<String, dynamic>;
  basemap['url'] = 'pmtiles://file://${mapFile.path}';
  return jsonEncode(style);
}
