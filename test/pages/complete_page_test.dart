import 'package:fitness_timer/l10n/app_localizations.dart';
import 'package:fitness_timer/pages/complete_page.dart';
import 'package:fitness_timer/providers/database_provider.dart';
import 'package:fitness_timer/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_database_service.dart';

Widget buildCompletePage(FakeDatabaseService fakeDb, {String routineId = 'r1'}) {
  final router = GoRouter(
    initialLocation: '/routine/$routineId/complete',
    routes: [
      GoRoute(
        path: '/routine/:id/complete',
        builder: (_, state) =>
            CompletePage(routineId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/routine/:id/run',
        builder: (context, state) => const Scaffold(body: Text('TimerRunPage')),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('HomePage')),
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
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  group('T4 — CompletePage', () {
    testWidgets('T4.1 on build: insertHistory called exactly once',
        (tester) async {
      final fakeDb = FakeDatabaseService();

      await tester.pumpWidget(buildCompletePage(fakeDb));
      await tester.pumpAndSettle();

      expect(fakeDb.insertHistoryCallCount, 1);
    });

    testWidgets('T4.2 "다시 하기" button navigates to /routine/:id/run',
        (tester) async {
      final fakeDb = FakeDatabaseService();

      await tester.pumpWidget(buildCompletePage(fakeDb, routineId: 'r1'));
      await tester.pumpAndSettle();

      // Tap "Repeat" button (English locale)
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();

      expect(find.text('TimerRunPage'), findsOneWidget);
    });

    testWidgets('T4.3 "홈으로" button navigates to /', (tester) async {
      final fakeDb = FakeDatabaseService();

      await tester.pumpWidget(buildCompletePage(fakeDb));
      await tester.pumpAndSettle();

      // Tap "Home" button (English locale)
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('HomePage'), findsOneWidget);
    });
  });
}
