import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/history.dart';
import '../providers/database_provider.dart';

final _historiesProvider = FutureProvider<List<History>>((ref) async {
  return ref.watch(databaseServiceProvider).getHistories(limit: 100);
});

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final historiesAsync = ref.watch(_historiesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.history)),
      body: historiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorLoadData)),
        data: (histories) => histories.isEmpty
            ? Center(child: Text(l10n.emptyHistory))
            : _HistoryList(histories: histories),
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  final List<History> histories;

  const _HistoryList({required this.histories});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseServiceProvider);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return ListView.builder(
      itemCount: histories.length,
      itemBuilder: (context, index) {
        final h = histories[index];
        return FutureBuilder(
          future: db.getRoutine(h.routineId),
          builder: (context, snapshot) {
            final title = snapshot.data?.title ?? h.routineId;
            final dateStr = dateFormat.format(h.completedAt.toLocal());
            return ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(title),
              subtitle: Text(dateStr),
            );
          },
        );
      },
    );
  }
}
