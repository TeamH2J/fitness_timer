import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/database_provider.dart';

class CompletePage extends ConsumerStatefulWidget {
  final String routineId;

  const CompletePage({super.key, required this.routineId});

  @override
  ConsumerState<CompletePage> createState() => _CompletePageState();
}

class _CompletePageState extends ConsumerState<CompletePage> {
  @override
  void initState() {
    super.initState();
    _recordHistory();
  }

  Future<void> _recordHistory() async {
    try {
      await ref
          .read(databaseServiceProvider)
          .insertHistory(widget.routineId);
    } catch (_) {
      // Non-blocking — navigation is unaffected.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              size: 100,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.completeTitle,
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () =>
                      context.replace('/routine/${widget.routineId}/run'),
                  icon: const Icon(Icons.replay),
                  label: Text(l10n.repeatRoutine),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home),
                  label: Text(l10n.goHome),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
