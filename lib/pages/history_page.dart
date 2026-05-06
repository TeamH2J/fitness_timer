import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/stopwatch_session.dart';
import '../providers/database_provider.dart';
import '../providers/stopwatch_provider.dart';

enum HistoryFilter { all, interval, stopwatch }

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key, this.filter = HistoryFilter.all});

  final HistoryFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final historyAsync = ref.watch(mergedHistoryProvider);

    final title = switch (filter) {
      HistoryFilter.all => l10n.history,
      HistoryFilter.interval => l10n.historyTimerOnly,
      HistoryFilter.stopwatch => l10n.historyStopwatchOnly,
    };

    final emptyMsg = switch (filter) {
      HistoryFilter.all => l10n.emptyHistory,
      HistoryFilter.interval => l10n.emptyHistoryTimer,
      HistoryFilter.stopwatch => l10n.emptyHistoryStopwatch,
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: historyAsync.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorLoadData)),
        data: (entries) {
          final visible = filter == HistoryFilter.all
              ? entries
              : entries
                  .where((e) => filter == HistoryFilter.interval
                      ? e.type == HistoryEntryType.interval
                      : e.type == HistoryEntryType.stopwatch)
                  .toList();
          return visible.isEmpty
              ? Center(child: Text(emptyMsg))
              : _HistoryList(entries: visible, l10n: l10n, ref: ref);
        },
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<HistoryEntry> entries;
  final AppLocalizations l10n;
  final WidgetRef ref;

  const _HistoryList({
    required this.entries,
    required this.l10n,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final dateStr = dateFormat.format(entry.timestamp.toLocal());

        final tile = entry.type == HistoryEntryType.interval
            ? ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(entry.title ?? entry.id),
                subtitle: Text(dateStr),
              )
            : _buildStopwatchTile(context, entry, dateStr);

        return Dismissible(
          key: ValueKey(entry.id),
          direction: DismissDirection.horizontal,
          background: _buildDismissBackground(),
          secondaryBackground: _buildDismissBackground(),
          onDismissed: (direction) {
            // Invalidate synchronously so the provider enters loading state
            // on the next frame, removing this Dismissible from the tree
            // before any async work begins.
            ref.invalidate(mergedHistoryProvider);
            _doDelete(context, entry);
          },
          child: tile,
        );
      },
    );
  }

  Widget _buildStopwatchTile(
      BuildContext context, HistoryEntry entry, String dateStr) {
    final totalMs = entry.totalMs ?? 0;
    final lapCount = entry.lapCount ?? 0;
    final label = entry.label;
    final elapsedStr = _formatElapsed(totalMs);
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: Text(label ?? elapsedStr),
      subtitle: Text(
        label != null
            ? '$elapsedStr  •  $dateStr  •  $lapCount ${l10n.historyLaps}'
            : '$dateStr  •  $lapCount ${l10n.historyLaps}',
      ),
      onTap: () => context.push('/stopwatch/${entry.id}'),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      color: Colors.red,
      alignment: Alignment.center,
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }

  // Called after ref.invalidate(mergedHistoryProvider) fires synchronously.
  // The provider enters loading state on the next frame; this async method
  // does the DB work and shows the SnackBar once done.
  Future<void> _doDelete(BuildContext context, HistoryEntry entry) async {
    final db = ref.read(databaseServiceProvider);

    if (entry.type == HistoryEntryType.interval) {
      // Snapshot BEFORE delete so Undo can re-insert the original record.
      final h = await db.getHistoryById(entry.id);
      await db.deleteHistory(entry.id);
      // Re-invalidate after the actual delete so data is fresh.
      ref.invalidate(mergedHistoryProvider);

      var undoConsumed = false;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.historyDeleted),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: l10n.historyUndo,
            onPressed: () {
              if (undoConsumed) return;
              undoConsumed = true;
              if (h != null) {
                db.insertHistoryRecord(h);
                ref.invalidate(mergedHistoryProvider);
              }
            },
          ),
        ),
      );
    } else {
      // Stopwatch entry: snapshot before delete for Undo.
      final s = await db.getStopwatchSessionById(entry.id);
      await db.deleteStopwatchSession(entry.id);
      // Re-invalidate after the actual delete.
      ref.invalidate(mergedHistoryProvider);
      ref.invalidate(stopwatchSessionByIdProvider(entry.id));
      if (entry.label != null) {
        ref.invalidate(sessionsByLabelProvider(entry.label!));
        ref.invalidate(personalBestProvider(entry.label!));
      }

      var undoConsumed = false;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.historyDeleted),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: l10n.historyUndo,
            onPressed: () {
              if (undoConsumed) return;
              undoConsumed = true;
              if (s != null) {
                db.insertStopwatchSession(s);
                ref.invalidate(mergedHistoryProvider);
              }
            },
          ),
        ),
      );
    }
  }

  String _formatElapsed(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
