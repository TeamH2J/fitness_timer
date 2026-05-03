import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'providers/feedback_provider.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure audio session at boot (lightweight; required before audio plays).
  // Failures are silent — app boots normally without ducking support.
  try {
    final container = ProviderContainer();
    await container.read(audioSessionConfiguratorProvider).configure();
    runApp(UncontrolledProviderScope(
      container: container,
      child: const FitnessTimerApp(),
    ));
  } catch (_) {
    // Fallback — feedback may not work but the app always boots.
    runApp(const ProviderScope(child: FitnessTimerApp()));
  }
}

class FitnessTimerApp extends StatelessWidget {
  const FitnessTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fitness_timer',
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _BootstrapScreen(),
    );
  }
}

/// Placeholder home screen — replaced in Phase 5.
class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold();
  }
}
