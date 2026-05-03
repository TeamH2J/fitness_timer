import 'package:fitness_timer/l10n/app_localizations.dart';
import 'package:fitness_timer/models/exercise_item.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/pages/complete_page.dart';
import 'package:fitness_timer/pages/history_page.dart';
import 'package:fitness_timer/pages/home_page.dart';
import 'package:fitness_timer/pages/routine_edit_page.dart';
import 'package:fitness_timer/pages/timer_run_page.dart';
import 'package:fitness_timer/providers/database_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_database_service.dart';

/// Builds a per-test GoRouter so tests don't share state.
GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('Page not found.')),
    ),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryPage(),
      ),
      GoRoute(
        path: '/routine/new',
        builder: (context, state) => const RoutineEditPage(routineId: null),
      ),
      GoRoute(
        path: '/routine/:id/edit',
        builder: (context, state) =>
            RoutineEditPage(routineId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/routine/:id/run',
        builder: (context, state) =>
            TimerRunPage(routineId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/routine/:id/complete',
        builder: (context, state) =>
            CompletePage(routineId: state.pathParameters['id']!),
      ),
    ],
  );
}

Widget buildRouterApp(FakeDatabaseService fakeDb, GoRouter router) {
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

final fakeRoutine = Routine(
  id: 'abc-123',
  title: 'Test Routine',
  prepTime: 0,
  cooldownTime: 0,
  totalCycles: 1,
);
final fakeItem = ExerciseItem(
  id: 'item-1',
  routineId: 'abc-123',
  orderIndex: 0,
  type: ExerciseType.WORK_TIME,
  duration: 10,
  name: 'Push-up',
);

FakeDatabaseService makeFakeDb() => FakeDatabaseService(
      routines: [fakeRoutine],
      items: {
        'abc-123': [fakeItem],
      },
    );

void main() {
  testWidgets('T7.1 — / resolves to HomePage', (tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(buildRouterApp(makeFakeDb(), router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('T7.2 — /history resolves to HistoryPage', (tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(buildRouterApp(makeFakeDb(), router));
    await tester.pump();
    router.go('/history');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HistoryPage), findsOneWidget);
  });

  testWidgets('T7.3 — /routine/new resolves to RoutineEditPage (new)',
      (tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(buildRouterApp(makeFakeDb(), router));
    await tester.pump();
    router.go('/routine/new');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RoutineEditPage), findsOneWidget);
  });

  testWidgets(
      'T7.4 — /routine/abc-123/edit resolves to RoutineEditPage (edit)',
      (tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(buildRouterApp(makeFakeDb(), router));
    await tester.pump();
    router.go('/routine/abc-123/edit');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RoutineEditPage), findsOneWidget);
  });

  testWidgets('T7.5 — /routine/abc-123/run resolves to TimerRunPage',
      (tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(buildRouterApp(makeFakeDb(), router));
    await tester.pump();
    router.go('/routine/abc-123/run');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TimerRunPage), findsOneWidget);
  });

  testWidgets('T7.6 — /routine/abc-123/complete resolves to CompletePage',
      (tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(buildRouterApp(makeFakeDb(), router));
    await tester.pump();
    router.go('/routine/abc-123/complete');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CompletePage), findsOneWidget);
  });

  testWidgets('T7.7 — unknown path returns the error page', (tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(buildRouterApp(makeFakeDb(), router));
    await tester.pump();
    router.go('/this/does/not/exist');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Page not found.'), findsOneWidget);
  });
}
