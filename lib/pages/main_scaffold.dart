import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import 'home_page.dart';
import 'settings_page.dart';
import 'stopwatch_page.dart';
import 'timer_tab_page.dart';

class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentIndex = ref.watch(tabIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: const [
          HomePage(),
          TimerTabPage(),
          StopwatchPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) =>
            ref.read(tabIndexProvider.notifier).state = index,
        selectedItemColor: const Color(0xFFFF5252),
        unselectedItemColor: Colors.white54,
        backgroundColor: Colors.black,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.list_alt),
            label: l10n.tabRoutines,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.timer),
            label: l10n.tabTimer,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.timer_outlined),
            label: l10n.tabStopwatch,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: l10n.tabSettings,
          ),
        ],
      ),
    );
  }
}
