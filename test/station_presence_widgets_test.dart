import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usra_r3/data/database.dart';
import 'package:usra_r3/main.dart';
import 'package:usra_r3/time_display.dart';

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

void main() {
  testWidgets(
    'warnings respect switch, refresh copies the last session contact, submit renews presence and close hides warnings',
    (tester) async {
      final now = DateTime.now().toUtc();
      final started = now.subtract(const Duration(hours: 6));
      SharedPreferences.setMockInitialValues({
        'network.startedAt': started.toIso8601String(),
        'contact.frequency': 'simplex',
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 2200);
      final db = UsraDatabase.test(NativeDatabase.memory());
      addTearDown(() async {
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.runAsync(db.close);
      });
      Future<void> insert({
        required String call,
        required DateTime date,
        String mode = 'simplex',
        DateTime? session,
        String name = 'Maria',
        double watts = 25,
        String grid = 'GG30CH',
      }) => db
          .into(db.logEntries)
          .insert(
            LogEntriesCompanion.insert(
              createdAt: date,
              callsign: call,
              networkStartedAt: Value(session ?? started),
              frequency: Value(mode),
              via: const Value('PY3VIA'),
              energy: const Value('G'),
              operatorName: name,
              location: grid,
              operatorGrid: 'GG30DH',
              powerWatts: watts,
              stationType: 'F',
              traffic: 'C',
              trafficMessage: const Value('Mensagem anterior'),
            ),
          )
          .then((_) {});
      final last = now.subtract(const Duration(hours: 2, minutes: 45));
      await insert(
        call: 'PY3AA',
        date: last.subtract(const Duration(minutes: 10)),
        name: 'Antigo',
      );
      await insert(call: 'PY3AA', date: last);
      await insert(
        call: 'PY3AA',
        date: now.subtract(const Duration(minutes: 10)),
        mode: 'repeater',
        name: 'Outra frequência',
        watts: 100,
        grid: 'GG30AA',
      );
      await insert(call: 'PY3REP', date: last, mode: 'repeater');
      await insert(
        call: 'PY3OLD',
        date: last,
        session: started.subtract(const Duration(days: 1)),
      );
      final original = await db.allLogs();
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            profile: const OperatorProfile(
              callsign: 'PY3SELF',
              name: 'Operador',
              grid: 'GG30DH',
            ),
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
      final warnings = find.text('Estações sem contato recente');
      expect(warnings, findsOneWidget);
      expect(
        tester.getTopLeft(warnings).dy,
        lessThan(tester.getTopLeft(find.text('Registros salvos')).dy),
      );
      expect(
        find.byTooltip('Preencher novo contato com PY3AA'),
        findsOneWidget,
      );
      expect(find.byTooltip('Preencher novo contato com PY3REP'), findsNothing);
      expect(find.byTooltip('Preencher novo contato com PY3OLD'), findsNothing);
      expect(
        find.text(DisplayTimeZone.brasilia.format(last, compact: true)),
        findsWidgets,
      );

      await tester.tap(find.text('Repetidora').first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Preencher novo contato com PY3AA'), findsNothing);
      expect(
        find.byTooltip('Preencher novo contato com PY3REP'),
        findsOneWidget,
      );
      await tester.tap(find.text('Simplex').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Preencher novo contato com PY3AA'));
      await tester.pumpAndSettle();
      String value(String label) =>
          tester.widget<TextField>(field(label)).controller!.text;
      expect(value('Indicativo'), 'PY3AA');
      expect(value('Via'), 'PY3VIA');
      expect(value('Nome do operador'), 'Maria');
      expect(value('Localização ou grid'), 'GG30CH');
      expect(value('Potência (W)'), '25.0');
      expect(value('Estação'), 'F');
      expect(value('Energia'), 'G');
      expect(value('Tráfego'), 'C');
      expect(value('Mensagem (tráfego)'), 'Mensagem anterior');
      // Leaving callsign must not replace these values with another frequency.
      await tester.tap(field('Via'));
      await tester.pumpAndSettle();
      expect(value('Nome do operador'), 'Maria');
      expect(value('Potência (W)'), '25.0');
      expect(await db.allLogs(), original);
      await tester.tap(find.text('Registrar log'));
      await tester.pumpAndSettle();
      expect(warnings, findsNothing);
      final saved = (await db.allLogs()).last;
      expect(saved.callsign, 'PY3AA');
      expect(saved.networkStartedAt, started);
      expect(saved.frequency, 'simplex');
      expect(saved.trafficMessage, 'Mensagem anterior');
      expect((await db.allLogs()).where((e) => e.id != saved.id), original);

      await tester.tap(find.text('Repetidora').first);
      await tester.pumpAndSettle();
      expect(warnings, findsOneWidget);
      await tester.tap(find.text('Fazer encerramento da rede'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Encerrar'));
      await tester.pumpAndSettle();
      expect(warnings, findsNothing);
      await tester.tap(find.text('Fazer abertura da rede'));
      await tester.pumpAndSettle();
      expect(warnings, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'settings exposes warning minutes, rejects invalid limits and returns both values',
    (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'USRA R3',
        packageName: 'org.usra.r3',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      final db = UsraDatabase.test(NativeDatabase.memory());
      addTearDown(() async => tester.runAsync(db.close));
      dynamic saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(
                      profile: const OperatorProfile(),
                      theme: AppTheme.system,
                      mergePrecision: true,
                      lastOnly: false,
                      mapMaxAgeHours: 3,
                      keepScreenOn: true,
                      showCompass: true,
                      database: db,
                    ),
                  ),
                );
              },
              child: const Text('Configurar'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Configurar'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        field('Antecedência do aviso (minutos)'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<TextField>(field('Expiração sem contato (horas)'))
            .controller!
            .text,
        '3',
      );
      expect(
        tester
            .widget<TextField>(field('Antecedência do aviso (minutos)'))
            .controller!
            .text,
        '30',
      );
      await tester.enterText(field('Antecedência do aviso (minutos)'), '180');
      await tester.scrollUntilVisible(
        find.text('Salvar alterações'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.byType(SettingsPage), findsOneWidget);
      await tester.scrollUntilVisible(
        field('Antecedência do aviso (minutos)'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(field('Antecedência do aviso (minutos)'), '15');
      await tester.scrollUntilVisible(
        find.text('Salvar alterações'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      expect(saved.mapMaxAgeHours, 3);
      expect(saved.mapWarningMinutes, 15);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
