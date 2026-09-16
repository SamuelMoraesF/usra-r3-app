import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usra_r3/data/database.dart';
import 'package:usra_r3/main.dart';

void main() {
  testWidgets('shows a realtime completion and accepts it with Tab', (
    tester,
  ) async {
    final started = DateTime.now().toUtc();
    SharedPreferences.setMockInitialValues({
      'network.startedAt': started.toIso8601String(),
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    final database = UsraDatabase.test(NativeDatabase.memory());
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.runAsync(database.close);
    });
    await database.saveLog(
      callsign: 'PY3AA',
      operatorName: 'Maria',
      location: 'GG30CH',
      operatorGrid: 'GG30DH',
      powerWatts: 25,
      stationType: 'F',
      energy: 'AC',
      traffic: 'S',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          profile: const OperatorProfile(grid: 'GG30DH'),
          database: database,
          onOpenSettings: () {},
          quickInsertMode: true,
          mergePrecision: true,
          lastOnly: false,
          mapMaxAgeHours: 3,
          keyboardOptimized: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final input = find.byKey(const Key('quick-contact-input'));
    final quickField = tester.widget<TextField>(input);
    expect(quickField.autocorrect, isFalse);
    expect(quickField.enableSuggestions, isFalse);
    final controller = tester.widget<TextField>(input).controller!;
    await tester.enterText(input, 'PY3AA ');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('MARIA GG30CH 25W FIXA AC ST'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controller.text, 'PY3AA MARIA GG30CH 25W FIXA AC ST');
    expect(find.text('MARIA GG30CH 25W FIXA AC ST'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('keeps a manually entered power out of the completion', (
    tester,
  ) async {
    final started = DateTime.now().toUtc();
    SharedPreferences.setMockInitialValues({
      'network.startedAt': started.toIso8601String(),
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    final database = UsraDatabase.test(NativeDatabase.memory());
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.runAsync(database.close);
    });
    await database.saveLog(
      callsign: 'PY3AA',
      operatorName: 'Maria',
      location: 'GG30CH',
      operatorGrid: 'GG30DH',
      powerWatts: 25,
      stationType: 'F',
      energy: 'AC',
      traffic: 'S',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          profile: const OperatorProfile(grid: 'GG30DH'),
          database: database,
          onOpenSettings: () {},
          quickInsertMode: true,
          mergePrecision: true,
          lastOnly: false,
          mapMaxAgeHours: 3,
          keyboardOptimized: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final input = find.byKey(const Key('quick-contact-input'));
    final controller = tester.widget<TextField>(input).controller!;
    await tester.enterText(input, 'PY3AA 6W ');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('MARIA GG30CH FIXA AC ST'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controller.text, 'PY3AA 6W MARIA GG30CH FIXA AC ST');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });
}
