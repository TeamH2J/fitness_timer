import 'package:fitness_timer/l10n/app_localizations.dart';
import 'package:fitness_timer/models/history.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/models/stopwatch_session.dart';
import 'package:fitness_timer/pages/history_page.dart';
import 'package:fitness_timer/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_database_service.dart';

Widget buildHistoryPage(FakeDatabaseService fakeDb,
    {HistoryFilter filter = HistoryFilter.all}) {
  return ProviderScope(
    overrides: [
      databaseServiceProvider.overrideWithValue(fakeDb),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HistoryPage(filter: filter),
    ),
  );
}

void main() {
  group('T3 — HistoryPage', () {
    testWidgets('T3.1 empty state: shows empty-history message', (tester) async {
      final fakeDb = FakeDatabaseService();

      await tester.pumpWidget(buildHistoryPage(fakeDb));
      await tester.pumpAndSettle();

      expect(find.text('No completed workouts yet'), findsOneWidget);
    });

    testWidgets('T3.2 3 history rows are rendered', (tester) async {
      final now = DateTime.now().toUtc();
      final fakeDb = FakeDatabaseService(
        routines: [
          const Routine(
            id: 'r1',
            title: 'Routine A',
            prepTime: 0,
            cooldownTime: 0,
            totalCycles: 1,
          ),
        ],
        histories: [
          History(id: 'h1', routineId: 'r1', completedAt: now),
          History(
              id: 'h2',
              routineId: 'r1',
              completedAt: now.subtract(const Duration(hours: 1))),
          History(
              id: 'h3',
              routineId: 'r1',
              completedAt: now.subtract(const Duration(hours: 2))),
        ],
      );

      await tester.pumpWidget(buildHistoryPage(fakeDb));
      await tester.pumpAndSettle();

      // All three history entries should be visible (check for 3 check icons)
      expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(3));
    });

    testWidgets('T3.3 history shows routine title', (tester) async {
      final now = DateTime.now().toUtc();
      final fakeDb = FakeDatabaseService(
        routines: [
          const Routine(
            id: 'r1',
            title: 'My Routine',
            prepTime: 0,
            cooldownTime: 0,
            totalCycles: 1,
          ),
        ],
        histories: [
          History(id: 'h1', routineId: 'r1', completedAt: now),
        ],
      );

      await tester.pumpWidget(buildHistoryPage(fakeDb));
      await tester.pumpAndSettle();

      expect(find.text('My Routine'), findsOneWidget);
    });
  });

  group('HistoryFilter — interval', () {
    StopwatchSession makeSession(String id, DateTime endedAt) =>
        StopwatchSession(
          id: id,
          startedAt: endedAt.subtract(const Duration(minutes: 5)),
          endedAt: endedAt,
          totalMs: 300000,
          laps: [],
        );

    FakeDatabaseService makeDb() {
      final now = DateTime.now().toUtc();
      return FakeDatabaseService(
        routines: [
          const Routine(
            id: 'r1',
            title: 'My Routine',
            prepTime: 0,
            cooldownTime: 0,
            totalCycles: 1,
          ),
        ],
        histories: [
          History(id: 'h1', routineId: 'r1', completedAt: now),
        ],
        stopwatchSessions: [
          makeSession('sw1', now.subtract(const Duration(hours: 1))),
        ],
      );
    }

    testWidgets('T-F1: interval filter shows interval icon and hides stopwatch icon',
        (tester) async {
      await tester.pumpWidget(
          buildHistoryPage(makeDb(), filter: HistoryFilter.interval));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsNothing);
    });

    testWidgets('T-F2: interval filter with only stopwatch sessions shows emptyHistoryTimer',
        (tester) async {
      final now = DateTime.now().toUtc();
      final fakeDb = FakeDatabaseService(
        stopwatchSessions: [
          makeSession('sw1', now),
        ],
      );
      await tester.pumpWidget(
          buildHistoryPage(fakeDb, filter: HistoryFilter.interval));
      await tester.pumpAndSettle();

      expect(find.text('No completed routines yet'), findsOneWidget);
    });

    testWidgets('T-F3: interval filter AppBar title is "Routine History"',
        (tester) async {
      await tester.pumpWidget(
          buildHistoryPage(makeDb(), filter: HistoryFilter.interval));
      await tester.pumpAndSettle();

      expect(find.text('Routine History'), findsOneWidget);
    });
  });

  group('HistoryFilter — stopwatch', () {
    StopwatchSession makeSession(String id, DateTime endedAt) =>
        StopwatchSession(
          id: id,
          startedAt: endedAt.subtract(const Duration(minutes: 5)),
          endedAt: endedAt,
          totalMs: 300000,
          laps: [],
        );

    FakeDatabaseService makeDb() {
      final now = DateTime.now().toUtc();
      return FakeDatabaseService(
        routines: [
          const Routine(
            id: 'r1',
            title: 'My Routine',
            prepTime: 0,
            cooldownTime: 0,
            totalCycles: 1,
          ),
        ],
        histories: [
          History(id: 'h1', routineId: 'r1', completedAt: now),
        ],
        stopwatchSessions: [
          makeSession('sw1', now.subtract(const Duration(hours: 1))),
        ],
      );
    }

    testWidgets('T-F4: stopwatch filter shows stopwatch icon and hides interval icon',
        (tester) async {
      await tester.pumpWidget(
          buildHistoryPage(makeDb(), filter: HistoryFilter.stopwatch));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });

    testWidgets('T-F5: stopwatch filter with only interval entries shows emptyHistoryStopwatch',
        (tester) async {
      final now = DateTime.now().toUtc();
      final fakeDb = FakeDatabaseService(
        routines: [
          const Routine(
            id: 'r1',
            title: 'My Routine',
            prepTime: 0,
            cooldownTime: 0,
            totalCycles: 1,
          ),
        ],
        histories: [
          History(id: 'h1', routineId: 'r1', completedAt: now),
        ],
      );
      await tester.pumpWidget(
          buildHistoryPage(fakeDb, filter: HistoryFilter.stopwatch));
      await tester.pumpAndSettle();

      expect(find.text('No stopwatch sessions yet'), findsOneWidget);
    });

    testWidgets('T-F6: stopwatch filter AppBar title is "Stopwatch History"',
        (tester) async {
      await tester.pumpWidget(
          buildHistoryPage(makeDb(), filter: HistoryFilter.stopwatch));
      await tester.pumpAndSettle();

      expect(find.text('Stopwatch History'), findsOneWidget);
    });
  });
}
