import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../pages/complete_page.dart';
import '../pages/history_page.dart';
import '../pages/main_scaffold.dart';
import '../pages/routine_edit_page.dart';
import '../pages/timer_run_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  errorBuilder: (context, state) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Text(l10n?.pageNotFound ?? 'Page not found.'),
      ),
    );
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainScaffold(),
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
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return RoutineEditPage(routineId: id);
      },
    ),
    GoRoute(
      path: '/routine/:id/run',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return TimerRunPage(routineId: id);
      },
    ),
    GoRoute(
      path: '/routine/:id/complete',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CompletePage(routineId: id);
      },
    ),
  ],
);
