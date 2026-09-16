// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:package_info_plus/package_info_plus.dart';

Future<void> openAndroidApk(PackageInfo info) async {
  final version = info.version;
  if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) return;
  final tag = 'v$version';
  final uri = Uri.https(
    'usra-r3-releases.s3.us-east-1.amazonaws.com',
    '/$tag/usra-r3-app-$tag.apk',
  );
  html.window.open(uri.toString(), '_blank');
}
