import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/database_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/timer_engine_provider.dart';
import 'timer_run_page.dart';

/// FutureProvider that loads the routine for the timer tab.
final _timerTabRoutineProvider = FutureProvider.autoDispose
    .family<RoutineWithItems?, String>((ref, routineId) async {
  final db = ref.read(databaseServiceProvider);
  final routine = await db.getRoutine(routineId);
  if (routine == null) return null;
  final items = await db.getExerciseItems(routineId);
  return RoutineWithItems(routine: routine, items: items);
});

class TimerTabPage extends ConsumerWidget {
  const TimerTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final lastId = ref.watch(lastRoutineIdProvider);

    if (lastId == null) {
      return _Placeholder(l10n: l10n);
    }

    final routineAsync = ref.watch(_timerTabRoutineProvider(lastId));

    return routineAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _Placeholder(l10n: l10n),
      data: (data) {
        if (data == null) {
          // Routine was deleted — clear the stored id and show placeholder.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(lastRoutineIdProvider.notifier).clear();
          });
          return _Placeholder(l10n: l10n);
        }
        return TimerRunPage(
          key: ValueKey(lastId),
          routineId: lastId,
          embedded: true,
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  final AppLocalizations l10n;

  const _Placeholder({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  l10n.timerTabPlaceholder,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(tabIndexProvider.notifier).state = 0,
                  child: Text(l10n.goToRoutines),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
