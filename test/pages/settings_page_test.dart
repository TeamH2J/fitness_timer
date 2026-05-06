import 'package:fitness_timer/l10n/app_localizations.dart';
import 'package:fitness_timer/pages/settings_page.dart';
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
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) =>
              const Scaffold(body: Text('all-history-stub')),
        ),
      ],
    );

Widget _buildApp(GoRouter router, {FakeDatabaseService? fakeDb}) {
  return ProviderScope(
    overrides: [
      if (fakeDb != null)
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

  group('SettingsPage — Data section', () {
    testWidgets('T-Se1: Data section has a ListTile with Icons.history and correct title',
        (tester) async {
      final router = _buildRouter();
      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      // Scroll down to ensure the Data section is visible
      await tester.scrollUntilVisible(find.text('View all history'), 100);
      await tester.pump();

      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.text('View all history'), findsOneWidget);
    });

    testWidgets('T-Se2: tapping "View all history" tile navigates to /history',
        (tester) async {
      final router = _buildRouter();
      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      // Scroll down to ensure the Data section is visible
      await tester.scrollUntilVisible(find.text('View all history'), 100);
      await tester.pump();

      await tester.tap(find.text('View all history'));
      await tester.pumpAndSettle();

      expect(find.text('all-history-stub'), findsOneWidget);
    });
  });

  group('SettingsPage — delete all history', () {
    testWidgets('T-Se3: delete-all tile exists with Icons.delete_outline and correct title',
        (tester) async {
      final router = _buildRouter();
      await tester.pumpWidget(_buildApp(router, fakeDb: FakeDatabaseService()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
          find.text('Delete all history'), 100);
      await tester.pump();

      expect(find.text('Delete all history'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('T-Se4: tapping delete-all tile shows AlertDialog with correct title',
        (tester) async {
      final router = _buildRouter();
      await tester.pumpWidget(_buildApp(router, fakeDb: FakeDatabaseService()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
          find.text('Delete all history'), 100);
      await tester.pump();

      await tester.tap(find.text('Delete all history'));
      await tester.pumpAndSettle();

      expect(find.text('Delete all history?'), findsOneWidget);
    });

    testWidgets('T-Se5: tapping Cancel closes dialog without calling deleteAllHistories',
        (tester) async {
      final fakeDb = FakeDatabaseService();
      final router = _buildRouter();
      await tester.pumpWidget(_buildApp(router, fakeDb: fakeDb));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
          find.text('Delete all history'), 100);
      await tester.pump();

      await tester.tap(find.text('Delete all history'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fakeDb.deleteAllHistoriesCallCount, 0);
      expect(find.text('Delete all history?'), findsNothing);
    });

    testWidgets('T-Se6: tapping Delete calls deleteAllHistories once and shows SnackBar',
        (tester) async {
      final fakeDb = FakeDatabaseService();
      final router = _buildRouter();
      await tester.pumpWidget(_buildApp(router, fakeDb: fakeDb));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
          find.text('Delete all history'), 100);
      await tester.pump();

      await tester.tap(find.text('Delete all history'));
      await tester.pumpAndSettle();

      // Tap the Delete button (action button in dialog)
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(fakeDb.deleteAllHistoriesCallCount, 1);
      expect(find.text('All history deleted'), findsOneWidget);
    });
  });
}
