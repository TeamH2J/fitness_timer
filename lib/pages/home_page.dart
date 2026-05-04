import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/routine.dart';
import '../providers/database_provider.dart';
import '../providers/home_provider.dart';
import '../providers/settings_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final routinesAsync = ref.watch(refreshableRoutinesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: l10n.history,
            onPressed: () => context.push('/history'),
          ),
        ],
      ),
      body: routinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: l10n.errorLoadData,
          onRetry: () => ref.invalidate(refreshableRoutinesProvider),
        ),
        data: (routines) => routines.isEmpty
            ? _EmptyState(l10n: l10n)
            : _RoutineList(routines: routines, l10n: l10n),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/routine/new').then((_) {
          ref.read(routinesRefreshProvider.notifier).state++;
        }),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fitness_center, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            l10n.emptyHome,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.emptyHomeSubtitle,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _RoutineList extends ConsumerWidget {
  final List<Routine> routines;
  final AppLocalizations l10n;

  const _RoutineList({required this.routines, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      itemCount: routines.length,
      itemBuilder: (context, index) {
        final routine = routines[index];
        return _RoutineCard(routine: routine, l10n: l10n);
      },
    );
  }
}

class _RoutineCard extends ConsumerWidget {
  final Routine routine;
  final AppLocalizations l10n;

  const _RoutineCard({required this.routine, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemCountAsync = ref.watch(routineItemCountProvider(routine.id));
    final totalSecondsAsync =
        ref.watch(routineTotalSecondsProvider(routine.id));

    final itemCount = itemCountAsync.valueOrNull ?? 0;
    final totalSecs = totalSecondsAsync.valueOrNull ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(routine.title),
        subtitle: Text('$itemCount items  •  ${totalSecs}s'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              await context.push('/routine/${routine.id}/edit');
              ref.read(routinesRefreshProvider.notifier).state++;
            } else if (value == 'delete') {
              final confirmed = await _confirmDelete(context);
              if (confirmed == true) {
                try {
                  await ref
                      .read(databaseServiceProvider)
                      .deleteRoutine(routine.id);
                  ref.read(routinesRefreshProvider.notifier).state++;
                } catch (_) {
                  // Ignore deletion errors silently.
                }
              }
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
            PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
          ],
        ),
        onTap: () {
                ref.read(lastRoutineIdProvider.notifier).set(routine.id);
                ref.read(tabIndexProvider.notifier).state = 1;
              },
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.delete),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
