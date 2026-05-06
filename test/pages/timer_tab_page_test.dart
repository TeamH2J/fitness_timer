import 'package:fitness_timer/l10n/app_localizations.dart';
import 'package:fitness_timer/models/exercise_item.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/pages/timer_tab_page.dart';
import 'package:fitness_timer/providers/database_provider.dart';
import 'package:fitness_timer/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_database_service.dart';

GoRouter _buildRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const TimerTabPage(),
        ),
        GoRoute(
          path: '/history/timer',
          builder: (context, state) =>
              const Scaffold(body: Text('timer-history-stub')),
        ),
      ],
    );

Widget _buildApp(GoRouter router, {FakeDatabaseService? fakeDb}) {
  return ProviderScope(
    overrides: [
      databaseServiceProvider.overrideWithValue(fakeDb ?? FakeDatabaseService()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  group('TimerTabPage._Placeholder', () {
    testWidgets('T-T1: placeholder has AppBar with Icons.history when no routine selected',
        (tester) async {
      // lastRoutineIdProvider reads from prefs; with empty prefs it returns null
      final router = _buildRouter();
      await tester.pumpWidget(_buildApp(router));
      await tester.pump();

      // Should show the placeholder with an AppBar history icon
      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets('T-T2: tapping Icons.history navigates to /history/timer',
        (tester) async {
      final router = _buildRouter();
      await tester.pumpWidget(_buildApp(router));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      expect(find.text('timer-history-stub'), findsOneWidget);
    });
  });

  group('TimerTabPage — TimerRunPage embedded', () {
    testWidgets(
        'T-T3: TimerRunPage embedded view has no history icon',
        (tester) async {
      const routineId = 'test-routine-1';
      final routine = const Routine(
        id: routineId,
        title: 'Test Routine',
        prepTime: 0,
        cooldownTime: 0,
        totalCycles: 1,
      );
      final item = ExerciseItem(
        id: 'item-1',
        routineId: routineId,
        orderIndex: 0,
        type: ExerciseType.WORK_TIME,
        duration: 30,
        name: 'Push-up',
      );
      final fakeDb = FakeDatabaseService(
        routines: [routine],
        items: {routineId: [item]},
      );

      // Seed SharedPreferences with the routine id so lastRoutineIdProvider
      // initialises to a non-null value.
      SharedPreferences.setMockInitialValues({'last_routine_id': routineId});
      await PreferencesService.init();

      final router = _buildRouter();
      await tester.pumpWidget(_buildApp(router, fakeDb: fakeDb));
      // Pump once to build, then a second time to let the FutureProvider
      // (_timerTabRoutineProvider) resolve its async callback.
      // Cannot use pumpAndSettle because TimerRunPage has a repeating
      // AnimationController that never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // TimerRunPage is shown in embedded mode — it has no Icons.history.
      expect(find.byIcon(Icons.history), findsNothing);
    });
  });
}
