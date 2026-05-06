import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/stopwatch_session.dart';
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
              : _HistoryList(entries: visible, l10n: l10n);
        },
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<HistoryEntry> entries;
  final AppLocalizations l10n;

  const _HistoryList({required this.entries, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final dateStr = dateFormat.format(entry.timestamp.toLocal());

        if (entry.type == HistoryEntryType.interval) {
          return ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(entry.title ?? entry.id),
            subtitle: Text(dateStr),
          );
        } else {
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
      },
    );
  }

  String _formatElapsed(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
