import 'package:fitness_timer/l10n/app_localizations.dart';
import 'package:fitness_timer/models/history.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/pages/history_page.dart';
import 'package:fitness_timer/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_database_service.dart';

Widget buildHistoryPage(FakeDatabaseService fakeDb) {
  return ProviderScope(
    overrides: [
      databaseServiceProvider.overrideWithValue(fakeDb),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HistoryPage(),
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
}
