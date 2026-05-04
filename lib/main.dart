import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'providers/feedback_provider.dart';
import 'providers/os_provider.dart';
import 'providers/settings_provider.dart';
import 'routing/app_router.dart';
import 'services/preferences_service.dart';
import 'theme/app_theme.dart';
import 'utils/desktop_db_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initDesktopDb();

  // Load persisted user preferences before runApp.
  try {
    await PreferencesService.init();
  } catch (_) {
    // Silent fallback — default AppSettings used for this session.
  }

  // Initialize FlutterForegroundTask options at boot (Android foreground service).
  // Failures are silent — timer still works without background service.
  try {
    initFlutterForegroundTask();
  } catch (_) {}

  // Configure audio session at boot (lightweight; required before audio plays).
  // Failures are silent — app boots normally without ducking support.
  try {
    final container = ProviderContainer();
    await container.read(audioSessionConfiguratorProvider).configure();

    // Seed initial tab based on last-used routine (cold-start only; runs once).
    final initialTab =
        PreferencesService.instance.lastRoutineId != null ? 1 : 0;
    container.read(tabIndexProvider.notifier).state = initialTab;

    // Register app lifecycle observer so Phase 5 UI can react to background/foreground.
    try {
      final lifecycle = container.read(appLifecycleObserverProvider);
      lifecycle.attach();
    } catch (_) {}

    runApp(UncontrolledProviderScope(
      container: container,
      child: const FitnessTimerApp(),
    ));
  } catch (_) {
    // Fallback — feedback may not work but the app always boots.
    runApp(const ProviderScope(child: FitnessTimerApp()));
  }
}

class FitnessTimerApp extends ConsumerWidget {
  const FitnessTimerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(settingsProvider.select((s) => s.locale));
    return MaterialApp.router(
      title: 'fitness_timer',
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
    );
  }
}
