import 'package:fitness_timer/l10n/app_localizations.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/pages/home_page.dart';
import 'package:fitness_timer/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fake_database_service.dart';

/// Helper: wraps a page inside ProviderScope + MaterialApp with go_router.
Widget buildPage({
  required Widget page,
  required FakeDatabaseService fakeDb,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => page),
      GoRoute(
        path: '/routine/new',
        builder: (context, state) => const Scaffold(body: Text('RoutineEditPage')),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const Scaffold(body: Text('HistoryPage')),
      ),
      GoRoute(
        path: '/routine/:id/run',
        builder: (context, state) => const Scaffold(body: Text('TimerRunPage')),
      ),
      GoRoute(
        path: '/routine/:id/edit',
        builder: (context, state) => const Scaffold(body: Text('RoutineEditPage')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      databaseServiceProvider.overrideWithValue(fakeDb),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  group('T1 — HomePage', () {
    testWidgets('T1.1 empty state: shows empty-home message', (tester) async {
      final fakeDb = FakeDatabaseService(); // no routines

      await tester.pumpWidget(buildPage(
        page: const HomePage(),
        fakeDb: fakeDb,
      ));
      await tester.pumpAndSettle();

      // The empty-home l10n key in English is "No routines yet"
      expect(find.text('No routines yet'), findsOneWidget);
    });

    testWidgets('T1.2 list state: shows routine title card', (tester) async {
      final fakeDb = FakeDatabaseService(
        routines: [
          const Routine(
            id: 'r1',
            title: 'Morning Workout',
            prepTime: 10,
            cooldownTime: 5,
            totalCycles: 3,
          ),
        ],
      );

      await tester.pumpWidget(buildPage(
        page: const HomePage(),
        fakeDb: fakeDb,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Morning Workout'), findsOneWidget);
    });

    testWidgets('T1.3 FAB tap navigates to /routine/new', (tester) async {
      final fakeDb = FakeDatabaseService();

      await tester.pumpWidget(buildPage(
        page: const HomePage(),
        fakeDb: fakeDb,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // After FAB tap, should navigate away to /routine/new stub
      expect(find.text('RoutineEditPage'), findsOneWidget);
    });

    testWidgets('T1.4 history icon tap navigates to /history', (tester) async {
      final fakeDb = FakeDatabaseService();

      await tester.pumpWidget(buildPage(
        page: const HomePage(),
        fakeDb: fakeDb,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      expect(find.text('HistoryPage'), findsOneWidget);
    });
  });
}
