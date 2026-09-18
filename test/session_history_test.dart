import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra_r3/data/database.dart';
import 'package:usra_r3/widgets/session_history.dart';

class CountingDatabase extends UsraDatabase {
  CountingDatabase() : super.test(NativeDatabase.memory());
  int pages = 0;
  @override
  Future<List<LogEntry>> sessionPage({
    required DateTime? startedAt,
    required String frequency,
    LogEntry? before,
    int limit = 50,
  }) {
    pages++;
    return super.sessionPage(
      startedAt: startedAt,
      frequency: frequency,
      before: before,
      limit: limit,
    );
  }
}

void main() {
  testWidgets(
    'history loads on expansion, pages on scroll and builds visible cards only',
    (tester) async {
      final db = CountingDatabase();
      final session = DateTime.utc(2026, 9, 1);
      addTearDown(() async => tester.runAsync(db.close));
      for (var i = 0; i < 105; i++) {
        await db.saveLog(
          callsign: 'PY3T$i',
          operatorName: 'Teste',
          location: 'GG30CH',
          operatorGrid: 'GG30DH',
          powerWatts: 5,
          stationType: 'P',
          traffic: 'S',
          networkStartedAt: session,
        );
      }
      await db.closeNetwork(session, session.add(const Duration(hours: 1)));
      var built = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionHistory(
              database: db,
              frequency: 'repeater',
              activeSession: null,
              title: (_, _) => 'Histórico',
              export: (_) {},
              card: (entry, entries) {
                built++;
                return SizedBox(height: 100, child: Text(entry.callsign));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(db.pages, 0);
      expect(built, 0);
      expect(find.text('105 contatos'), findsOneWidget);
      await tester.tap(find.text('Histórico'));
      await tester.pumpAndSettle();
      expect(db.pages, 1);
      expect(built, lessThan(20));
      final list = find.byType(ListView);
      tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)),
          )
          .position
          .jumpTo(4900);
      await tester.pumpAndSettle();
      expect(db.pages, 2);
      // Export remains independent of the two pages loaded in the UI.
      expect(await db.logsForNetwork(session), hasLength(105));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  test(
    'session pages preserve ties, frequency, UTC and legacy null sessions',
    () async {
      final db = CountingDatabase();
      addTearDown(db.close);
      final session = DateTime.utc(2026, 9, 1);
      for (var i = 0; i < 7; i++) {
        await db.saveLog(
          callsign: 'PY3T$i',
          operatorName: 'Teste',
          location: 'GG30CH',
          operatorGrid: 'GG30DH',
          powerWatts: 5,
          stationType: 'P',
          traffic: 'S',
          networkStartedAt: i == 6 ? null : session,
        );
      }
      await db.customStatement('UPDATE log_entries SET created_at_utc = ?', [
        session.microsecondsSinceEpoch,
      ]);
      final ids = <int>[];
      LogEntry? cursor;
      while (true) {
        final page = await db.sessionPage(
          startedAt: session,
          frequency: 'repeater',
          before: cursor,
          limit: 2,
        );
        if (page.isEmpty) break;
        ids.addAll(page.map((e) => e.id));
        cursor = page.last;
      }
      expect(ids, [6, 5, 4, 3, 2, 1]);
      expect(
        await db.sessionPage(startedAt: session, frequency: 'simplex'),
        isEmpty,
      );
      expect(
        await db.sessionPage(startedAt: null, frequency: 'repeater'),
        hasLength(1),
      );
      final summaries = await db.watchSessionSummaries('repeater').first;
      expect(
        summaries.firstWhere((s) => s.startedAt != null).startedAt,
        session,
      );
      expect(await db.watchActiveNetwork(null).first, isEmpty);
      expect(await db.watchActiveNetwork(session).first, hasLength(6));
      expect(await db.allLogs(), hasLength(7));
    },
  );
}
