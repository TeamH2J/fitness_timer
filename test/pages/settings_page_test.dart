import 'package:fitness_timer/l10n/app_localizations.dart';
import 'package:fitness_timer/pages/settings_page.dart';
import 'package:fitness_timer/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Widget _buildApp(GoRouter router) {
  return ProviderScope(
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
}
