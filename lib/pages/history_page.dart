import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/stopwatch_session.dart';
import '../providers/stopwatch_provider.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final historyAsync = ref.watch(mergedHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.history)),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorLoadData)),
        data: (entries) => entries.isEmpty
            ? Center(child: Text(l10n.emptyHistory))
            : _HistoryList(entries: entries, l10n: l10n),
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
