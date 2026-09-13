import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usra_r3/data/database.dart';

import 'package:usra_r3/main.dart';

void main() {
  testWidgets('Ctrl+N clears the contact and focuses callsign without saving', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({'contact.frequency': 'simplex'});
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
}
