import 'package:fitness_timer/l10n/app_localizations.dart';
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

Widget _buildApp(GoRouter router) {
  return ProviderScope(
    overrides: [
      databaseServiceProvider.overrideWithValue(FakeDatabaseService()),
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
}
