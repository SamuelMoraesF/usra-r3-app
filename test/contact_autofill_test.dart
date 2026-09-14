import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usra_r3/data/database.dart';
import 'package:usra_r3/main.dart';

void main() {
  testWidgets(
    'changing an untouched autocompleted callsign clears immediately and completes the next one on blur',
    (tester) async {
      final started = DateTime.now().toUtc();
      SharedPreferences.setMockInitialValues({
        'network.startedAt': started.toIso8601String(),
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      final db = UsraDatabase.test(NativeDatabase.memory());
      addTearDown(() async {
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.runAsync(db.close);
      });
      for (final call in ['PY3AA', 'PY3BB']) {
        await db.saveLog(
          callsign: call,
          operatorName: call == 'PY3AA' ? 'Maria' : 'João',
          location: call == 'PY3AA' ? 'GG30CH' : 'GG30AA',
          operatorGrid: 'GG30DH',
          powerWatts: call == 'PY3AA' ? 25 : 50,
          stationType: 'F',
          energy: 'AC',
          traffic: 'S',
          networkStartedAt: started,
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            profile: const OperatorProfile(grid: 'GG30DH'),
            database: db,
            onOpenSettings: () {},
            mergePrecision: true,
            lastOnly: false,
            mapMaxAgeHours: 3,
            keyboardOptimized: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      TextField input(String label) => tester.widget<TextField>(field(label));
      Future<void> complete(String call) async {
        await tester.enterText(field('Indicativo'), call);
        await tester.tap(field('Via'));
        await tester.pumpAndSettle();
      }

      await complete('PY3AA');
      expect(input('Nome do operador').controller!.text, 'Maria');
      expect(input('Potência (W)').controller!.text, '25.0');
      // Merely tabbing through a choice reformats its label, but is not an edit.
      input('Estação').controller!.text = 'F - Fixa';
      await tester.enterText(field('Indicativo'), 'PY3B');
      await tester.pump();
      expect(input('Indicativo').focusNode!.hasFocus, isTrue);
      expect(input('Indicativo').controller!.text, 'PY3B');
      for (final label in [
        'Nome do operador',
        'Localização ou grid',
        'Potência (W)',
        'Via',
      ]) {
        expect(input(label).controller!.text, isEmpty);
      }
      expect(input('Estação').controller!.text, 'P - Portátil');
      expect(input('Energia').controller!.text, 'B - Bateria');
      expect(input('Tráfego').controller!.text, 'S - Sem tráfego');
      await tester.enterText(field('Indicativo'), 'PY3BB');
      await tester.pump();
      expect(input('Nome do operador').controller!.text, isEmpty);
      await tester.tap(field('Via'));
      await tester.pumpAndSettle();
      expect(input('Nome do operador').controller!.text, 'João');
      expect(input('Localização ou grid').controller!.text, 'GG30AA');
      expect(input('Potência (W)').controller!.text, '50.0');

      // A manual edit must prevent automatic clearing, even if later reverted.
      await tester.enterText(field('Potência (W)'), '75');
      await tester.enterText(field('Potência (W)'), '50');
      await tester.enterText(field('Indicativo'), 'PY3NOVO');
      await tester.pump();
      expect(input('Nome do operador').controller!.text, 'João');
      expect(input('Potência (W)').controller!.text, '50');
      await tester.tap(field('Via'));
      await tester.pumpAndSettle();
      expect(input('Nome do operador').controller!.text, 'João');
      expect(await db.allLogs(), hasLength(2));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
