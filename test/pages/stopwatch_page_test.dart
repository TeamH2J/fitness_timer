import 'package:fitness_timer/l10n/app_localizations.dart';
import 'package:fitness_timer/pages/stopwatch_page.dart';
import 'package:fitness_timer/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fake_database_service.dart';

GoRouter _buildRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const StopwatchPage(),
        ),
        GoRoute(
          path: '/history/stopwatch',
          builder: (context, state) =>
              const Scaffold(body: Text('stopwatch-history-stub')),
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
  group('StopwatchPage', () {
    testWidgets('T-S1: AppBar contains Icons.history IconButton', (tester) async {
      final router = _buildRouter();
      await tester.pumpWidget(_buildApp(router));
      await tester.pump();

      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets('T-S2: tapping Icons.history navigates to /history/stopwatch',
        (tester) async {
      final router = _buildRouter();
      await tester.pumpWidget(_buildApp(router));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      expect(find.text('stopwatch-history-stub'), findsOneWidget);
    });
  });
}
