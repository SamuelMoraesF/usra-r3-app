import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usra_r3/data/database.dart';
import 'package:usra_r3/main.dart';
import 'package:usra_r3/time_display.dart';

void main() {
  testWidgets(
    'saved contact timestamps follow the selected zone without changing data',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final database = UsraDatabase.test(NativeDatabase.memory());
      addTearDown(() async {
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.runAsync(database.close);
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 1800);
      final instant = DateTime.utc(2000, 1, 1, 1, 2, 3);
      await database.importLogs([
        LogEntriesCompanion.insert(
          createdAt: instant,
          callsign: 'PY3AA',
          operatorName: 'Operador',
          location: 'GG30CH',
          operatorGrid: 'GG30DH',
          powerWatts: 5,
          stationType: 'P',
          traffic: 'S',
        ),
      ]);
      final home = HomePage(
        profile: const OperatorProfile(),
        database: database,
        onOpenSettings: () {},
        mergePrecision: true,
        lastOnly: false,
        mapMaxAgeHours: 24,
      );
      for (final zone in DisplayTimeZone.values) {
        await tester.pumpWidget(
          TimeDisplay(
            zone: zone,
            child: MaterialApp(home: home),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            zone == DisplayTimeZone.utc
                ? '01/01/2000 01:02:03 UTC'
                : '31/12/1999 22:02:03 GMT-3',
          ),
          findsOneWidget,
        );
        expect((await database.allLogs()).single.createdAt, instant);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('settings returns the chosen display zone when saved', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'USRA R3',
      packageName: 'org.usra.r3',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final database = UsraDatabase.test(NativeDatabase.memory());
    addTearDown(() async => tester.runAsync(database.close));
    DisplayTimeZone? savedZone;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final dynamic result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    profile: const OperatorProfile(),
                    theme: AppTheme.system,
                    mergePrecision: true,
                    lastOnly: false,
                    mapMaxAgeHours: 24,
                    keepScreenOn: true,
                    showCompass: true,
                    database: database,
                  ),
                ),
              );
              savedZone = result.displayTimeZone as DisplayTimeZone;
            },
            child: const Text('Abrir configurações'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir configurações'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<DisplayTimeZone>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UTC').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Salvar alterações'),
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(savedZone, DisplayTimeZone.utc);
  });
}
