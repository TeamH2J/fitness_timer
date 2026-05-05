import 'package:fitness_timer/l10n/app_localizations.dart';
import 'package:fitness_timer/models/stopwatch_session.dart';
import 'package:fitness_timer/pages/stopwatch_detail_page.dart';
import 'package:fitness_timer/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_database_service.dart';

// Convenience session builder.
StopwatchSession makeSession({
  required String id,
  int totalMs = 300000,
  String? label,
  List<LapRecord> laps = const [],
  DateTime? endedAt,
}) {
  return StopwatchSession(
    id: id,
    startedAt: DateTime.utc(2026, 5, 1, 9, 0),
    endedAt: endedAt ?? DateTime.utc(2026, 5, 1, 9, 5),
    totalMs: totalMs,
    laps: laps,
    label: label,
  );
}

Widget buildDetailPage(
  FakeDatabaseService fakeDb, {
  required String sessionId,
}) {
  return ProviderScope(
    overrides: [
      databaseServiceProvider.overrideWithValue(fakeDb),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StopwatchDetailPage(sessionId: sessionId),
    ),
  );
}

void main() {
  group('StopwatchDetailPage', () {
    // WGT-1: session with no label — shows hint, no comparison block
    testWidgets('WGT-1: no-label session shows hint, hides comparison block',
        (tester) async {
      final session = makeSession(id: 's1');
      final fakeDb = FakeDatabaseService(stopwatchSessions: [session]);

      await tester.pumpWidget(buildDetailPage(fakeDb, sessionId: 's1'));
      await tester.pumpAndSettle();

      expect(find.text('Add a label to compare with previous sessions.'),
          findsOneWidget);
      // PB badge, sparkline title, no-prior text should be absent.
      expect(find.text('PB'), findsNothing);
      expect(find.text('Trend'), findsNothing);
      expect(find.text('First session with this label.'), findsNothing);
    });

    // WGT-2: session with label, 1 session in group — shows no-prior hint
    testWidgets(
        'WGT-2: single session in label group shows no-prior text and sparkline title',
        (tester) async {
      final session = makeSession(id: 's1', label: 'run');
      final fakeDb = FakeDatabaseService(stopwatchSessions: [session]);

      await tester.pumpWidget(buildDetailPage(fakeDb, sessionId: 's1'));
      await tester.pumpAndSettle();

      expect(find.text('First session with this label.'), findsOneWidget);
      expect(find.text('Trend'), findsOneWidget);
      // No lap-diff table header since only 1 session.
      expect(find.text('Δ vs prev'), findsNothing);
    });

    // WGT-3: 2 sessions in group — aggregates and lap diff visible; PB badge
    testWidgets(
        'WGT-3: two sessions in group shows aggregates, lap diff, and PB badge for faster session',
        (tester) async {
      // current = 250000 ms (faster = PB), prior = 300000 ms
      final current = makeSession(
        id: 's2',
        totalMs: 250000,
        label: 'run',
        endedAt: DateTime.utc(2026, 5, 2, 9, 5),
        laps: const [
          LapRecord(number: 1, lapMs: 120000, totalMs: 120000),
          LapRecord(number: 2, lapMs: 130000, totalMs: 250000),
        ],
      );
      final prior = makeSession(
        id: 's1',
        totalMs: 300000,
        label: 'run',
        endedAt: DateTime.utc(2026, 5, 1, 9, 5),
        laps: const [
          LapRecord(number: 1, lapMs: 150000, totalMs: 150000),
          LapRecord(number: 2, lapMs: 150000, totalMs: 300000),
        ],
      );
      final fakeDb = FakeDatabaseService(stopwatchSessions: [prior, current]);

      await tester.pumpWidget(buildDetailPage(fakeDb, sessionId: 's2'));
      await tester.pumpAndSettle();

      // PB badge visible since current.totalMs (250000) == min(250000, 300000)
      expect(find.text('PB'), findsOneWidget);
      // Aggregate column labels
      expect(find.text('Total'), findsOneWidget);
      // Lap diff table column header
      expect(find.text('Δ vs prev'), findsOneWidget);
    });

    // WGT-4: PB badge absent when current is not fastest
    testWidgets('WGT-4: PB badge absent when current is not personal best',
        (tester) async {
      final current = makeSession(
        id: 's2',
        totalMs: 350000,
        label: 'run',
        endedAt: DateTime.utc(2026, 5, 2, 9, 5),
        laps: const [],
      );
      final prior = makeSession(
        id: 's1',
        totalMs: 300000,
        label: 'run',
        endedAt: DateTime.utc(2026, 5, 1, 9, 5),
        laps: const [],
      );
      final fakeDb = FakeDatabaseService(stopwatchSessions: [prior, current]);

      await tester.pumpWidget(buildDetailPage(fakeDb, sessionId: 's2'));
      await tester.pumpAndSettle();

      expect(find.text('PB'), findsNothing);
    });

    // WGT-5: Lap diff '—' for missing prior lap
    testWidgets(
        'WGT-5: lap diff shows dash for laps that have no matching prior lap',
        (tester) async {
      final current = makeSession(
        id: 's2',
        totalMs: 270000,
        label: 'run',
        endedAt: DateTime.utc(2026, 5, 2, 9, 5),
        laps: const [
          LapRecord(number: 1, lapMs: 90000, totalMs: 90000),
          LapRecord(number: 2, lapMs: 90000, totalMs: 180000),
          LapRecord(number: 3, lapMs: 90000, totalMs: 270000),
        ],
      );
      final prior = makeSession(
        id: 's1',
        totalMs: 200000,
        label: 'run',
        endedAt: DateTime.utc(2026, 5, 1, 9, 5),
        laps: const [
          LapRecord(number: 1, lapMs: 100000, totalMs: 100000),
          LapRecord(number: 2, lapMs: 100000, totalMs: 200000),
          // no lap 3 — delta cell for lap 3 should show '—'
        ],
      );
      final fakeDb = FakeDatabaseService(stopwatchSessions: [prior, current]);

      await tester.pumpWidget(buildDetailPage(fakeDb, sessionId: 's2'));
      await tester.pumpAndSettle();

      expect(find.text('—'), findsOneWidget);
    });

    // WGT-6: Delta colour — green for faster, red for slower
    testWidgets('WGT-6: negative delta text rendered in green, positive in red',
        (tester) async {
      final current = makeSession(
        id: 's2',
        totalMs: 250000,
        label: 'run',
        endedAt: DateTime.utc(2026, 5, 2, 9, 5),
        laps: const [
          LapRecord(number: 1, lapMs: 80000, totalMs: 80000), // faster: delta < 0
          LapRecord(number: 2, lapMs: 170000, totalMs: 250000), // slower: delta > 0
        ],
      );
      final prior = makeSession(
        id: 's1',
        totalMs: 300000,
        label: 'run',
        endedAt: DateTime.utc(2026, 5, 1, 9, 5),
        laps: const [
          LapRecord(number: 1, lapMs: 100000, totalMs: 100000),
          LapRecord(number: 2, lapMs: 100000, totalMs: 200000),
        ],
      );
      final fakeDb = FakeDatabaseService(stopwatchSessions: [prior, current]);

      await tester.pumpWidget(buildDetailPage(fakeDb, sessionId: 's2'));
      await tester.pumpAndSettle();

      // Find delta text widgets in lap compare table.
      final richTexts = tester.widgetList<Text>(find.byType(Text)).toList();
      final deltaTexts = richTexts
          .where((t) =>
              t.data != null &&
              (t.data!.startsWith('-') || t.data!.startsWith('+')))
          .toList();

      // At least two delta cells should be present.
      expect(deltaTexts.length, greaterThanOrEqualTo(2));

      // Find the green (negative delta) text.
      final greenText = deltaTexts.firstWhere(
        (t) => t.style?.color == Colors.green,
        orElse: () => throw Exception('No green delta text found'),
      );
      expect(greenText.data, startsWith('-'));

      // Find the red (positive delta) text.
      final redText = deltaTexts.firstWhere(
        (t) => t.style?.color == Colors.red,
        orElse: () => throw Exception('No red delta text found'),
      );
      expect(redText.data, startsWith('+'));
    });

    // WGT-7: Save triggers DB update and normalizes label (FR-4.1.3)
    testWidgets(
        'WGT-7a: tapping Save with normal text calls updateStopwatchSessionLabel once',
        (tester) async {
      final session = makeSession(id: 's1');
      final fakeDb = FakeDatabaseService(stopwatchSessions: [session]);

      await tester.pumpWidget(buildDetailPage(fakeDb, sessionId: 's1'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'morning run');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fakeDb.updateLabelCallCount, 1);
      expect(fakeDb.lastUpdatedLabel, 'morning run');
    });

    testWidgets(
        'WGT-7b: whitespace-only label is normalized to null before DB write',
        (tester) async {
      final session = makeSession(id: 's1');
      final fakeDb = FakeDatabaseService(stopwatchSessions: [session]);

      await tester.pumpWidget(buildDetailPage(fakeDb, sessionId: 's1'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fakeDb.updateLabelCallCount, 1);
      // FR-4.1.3: whitespace-only → stored as null
      expect(fakeDb.lastUpdatedLabel, isNull);
    });

    testWidgets(
        'WGT-7c: label with surrounding whitespace is trimmed before DB write',
        (tester) async {
      final session = makeSession(id: 's1');
      final fakeDb = FakeDatabaseService(stopwatchSessions: [session]);

      await tester.pumpWidget(buildDetailPage(fakeDb, sessionId: 's1'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  run  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fakeDb.updateLabelCallCount, 1);
      // FR-4.1.3: surrounding whitespace trimmed
      expect(fakeDb.lastUpdatedLabel, 'run');
    });
  });
}
