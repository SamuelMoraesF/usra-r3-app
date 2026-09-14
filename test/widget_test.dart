import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usra_r3/data/database.dart';

import 'package:usra_r3/main.dart';

void main() {
  testWidgets('closed network shows empty logs when switching to simplex', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({
      'contact.frequency': 'repeater',
      'network.startedAt': '2026-09-14T10:00:00Z',
      'network.closedAt': '2026-09-14T11:00:00Z',
    });
    final database = UsraDatabase.test(NativeDatabase.memory());
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await tester.runAsync(database.close);
    });
    await database.saveLog(
      callsign: 'PY3REP',
      operatorName: 'Operador',
      location: 'GG30CH',
      operatorGrid: 'GG30DH',
      powerWatts: 5,
      stationType: 'P',
      traffic: 'S',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          profile: const OperatorProfile(),
          database: database,
          onOpenSettings: () {},
          mergePrecision: true,
          lastOnly: false,
          mapMaxAgeHours: 24,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Registros salvos'), findsOneWidget);
    expect(find.text('Não há registros recentes.'), findsNothing);
    await tester.tap(find.text('Simplex'));
    await tester.pumpAndSettle();
    expect(find.text('Registros salvos'), findsOneWidget);
    expect(find.text('Não há registros recentes.'), findsOneWidget);
    expect(find.text('Ainda não houve nenhum contato.'), findsNothing);
    await tester.tap(find.text('Repetidora'));
    await tester.pumpAndSettle();
    expect(find.text('Não há registros recentes.'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('open network remains visible before its first contact', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final started = DateTime.utc(2026, 9, 14, 10);
    SharedPreferences.setMockInitialValues({
      'network.startedAt': started.toIso8601String(),
    });
    final database = UsraDatabase.test(NativeDatabase.memory());
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.runAsync(database.close);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          profile: const OperatorProfile(),
          database: database,
          onOpenSettings: () {},
          mergePrecision: true,
          lastOnly: false,
          mapMaxAgeHours: 24,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Registros salvos'), findsOneWidget);
    expect(find.text('Ainda não houve nenhum contato.'), findsOneWidget);
    expect(find.textContaining('Rede 14/09'), findsOneWidget);
    Future<void> save(DateTime session) => database.saveLog(
      callsign: 'PY3TEST',
      operatorName: 'Operador',
      location: 'GG30CH',
      operatorGrid: 'GG30DH',
      powerWatts: 5,
      stationType: 'P',
      traffic: 'S',
      networkStartedAt: session,
    );
    await save(started.subtract(const Duration(days: 1)));
    await tester.pumpAndSettle();
    expect(find.text('Ainda não houve nenhum contato.'), findsOneWidget);
    await save(started);
    await tester.pumpAndSettle();
    expect(find.text('Ainda não houve nenhum contato.'), findsNothing);
    expect(find.textContaining('Rede 14/09'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  test('capitalizes every operator-name word initial', () {
    final formatter = CapitalizeWordsFormatter();
    final pasted = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(text: 'joão da silva'),
    );
    expect(pasted.text, 'João da Silva');

    final typedAfterSpace = formatter.formatEditUpdate(
      const TextEditingValue(text: 'João '),
      const TextEditingValue(text: 'João d'),
    );
    expect(typedAfterSpace.text, 'João D');

    final uppercaseConnectors = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(text: 'JOÃO DAS SILVA E SANTOS'),
    );
    expect(uppercaseConnectors.text, 'JOÃO das SILVA e SANTOS');
  });

  testWidgets('Ctrl+N clears the contact and focuses callsign without saving', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({
      'contact.frequency': 'simplex',
      'network.startedAt': '2026-09-13T10:00:00.000Z',
    });
    final database = UsraDatabase.test(NativeDatabase.memory());
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await tester.runAsync(database.close);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          profile: const OperatorProfile(),
          database: database,
          onOpenSettings: () {},
          mergePrecision: true,
          lastOnly: false,
          mapMaxAgeHours: 24,
        ),
      ),
    );
    await tester.pumpAndSettle();
    Finder field(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );
    // Read the rendered TextFields to access the shared form controllers.
    TextField input(String label) => tester.widget<TextField>(field(label));
    input('Indicativo').controller!.text = 'PY3ABC';
    input('Via').controller!.text = 'PY3DEF';
    input('Estação').controller!.text = 'F - Fixa';
    input('Energia').controller!.text = 'AC - Rede elétrica';
    await tester.enterText(field('Nome do operador'), 'Operador');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(input('Indicativo').controller!.text, isEmpty);
    expect(input('Via').controller!.text, isEmpty);
    expect(input('Nome do operador').controller!.text, isEmpty);
    expect(input('Estação').controller!.text, 'P - Portátil');
    expect(input('Energia').controller!.text, 'B - Bateria');
    expect(input('Tráfego').controller!.text, 'S - Sem tráfego');
    expect(input('Indicativo').focusNode!.hasFocus, isTrue);
    expect(
      tester
          .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
          .selected,
      {'simplex'},
    );
    expect(await database.allLogs(), isEmpty);
    await tester.tap(find.text('Registrar log'));
    await tester.pumpAndSettle();
    for (final label in ['Indicativo', 'Nome do operador', 'Potência (W)']) {
      expect(input(label).decoration!.errorText, 'Campo obrigatório');
      await tester.enterText(
        field(label),
        label == 'Potência (W)' ? '5' : 'TESTE',
      );
      await tester.pump();
      expect(input(label).decoration!.errorText, isNull);
      await tester.enterText(field(label), '');
      await tester.pump();
      expect(input(label).decoration!.errorText, 'Campo obrigatório');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('renders the setup wizard', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SetupWizard(onComplete: (_) {})));
    await tester.pump();

    expect(find.text('USRA R3'), findsOneWidget);
    expect(find.text('Configure seu perfil'), findsOneWidget);
    expect(find.text('Usar GPS'), findsOneWidget);
  });

  testWidgets('shows only saved contacts from the selected network', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({
      'contact.frequency': 'simplex',
      'network.startedAt': '2026-09-13T10:00:00.000Z',
    });
    final database = UsraDatabase.test(NativeDatabase.memory());
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await tester.runAsync(database.close);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    await database.saveLog(
      callsign: 'PY3SIM',
      frequency: 'simplex',
      operatorName: 'Operador Simplex',
      location: 'GG13AA',
      operatorGrid: 'GG13AB',
      powerWatts: 5,
      stationType: 'P',
      traffic: 'S',
    );
    await database.saveLog(
      callsign: 'PY3REP',
      frequency: 'repeater',
      operatorName: 'Operador Repetidora',
      location: 'GG13AC',
      operatorGrid: 'GG13AD',
      powerWatts: 5,
      stationType: 'P',
      traffic: 'S',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          profile: const OperatorProfile(),
          database: database,
          onOpenSettings: () {},
          mergePrecision: true,
          lastOnly: false,
          mapMaxAgeHours: 24,
        ),
      ),
    );
    await tester.pumpAndSettle();
    Finder contactTitle(String callsign) => find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains(callsign),
    );
    expect(contactTitle('PY3SIM'), findsOneWidget);
    expect(contactTitle('PY3REP'), findsNothing);

    await tester.tap(find.text('Repetidora'));
    await tester.pumpAndSettle();
    expect(contactTitle('PY3SIM'), findsNothing);
    expect(contactTitle('PY3REP'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });
}
