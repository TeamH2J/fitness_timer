import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/stopwatch_session.dart';
import '../providers/stopwatch_provider.dart';

class StopwatchPage extends ConsumerWidget {
  const StopwatchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final snapshot = ref.watch(stopwatchEngineProvider);
    final notifier = ref.read(stopwatchEngineProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabStopwatch)),
      body: Column(
        children: [
          const SizedBox(height: 32),
          _ElapsedDisplay(snapshot: snapshot),
          const SizedBox(height: 16),
          _ButtonRow(snapshot: snapshot, notifier: notifier, l10n: l10n),
          const SizedBox(height: 16),
          Expanded(child: _LapList(snapshot: snapshot, l10n: l10n)),
        ],
      ),
    );
  }
}

class _ElapsedDisplay extends StatelessWidget {
  final StopwatchSnapshot snapshot;

  const _ElapsedDisplay({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _formatElapsed(snapshot.elapsedMs),
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w300,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        if (snapshot.state != StopwatchState.idle)
          Text(
            _formatElapsed(snapshot.currentLapMs),
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white54,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }

  String _formatElapsed(int ms) {
    final centiseconds = (ms ~/ 10) % 100;
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${centiseconds.toString().padLeft(2, '0')}';
  }
}

class _ButtonRow extends StatelessWidget {
  final StopwatchSnapshot snapshot;
  final StopwatchEngineNotifier notifier;
  final AppLocalizations l10n;

  const _ButtonRow({
    required this.snapshot,
    required this.notifier,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    switch (snapshot.state) {
      case StopwatchState.idle:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionButton(
              label: l10n.stopwatchStart,
              onPressed: notifier.start,
              primary: true,
            ),
            const SizedBox(width: 16),
            _ActionButton(
              label: l10n.stopwatchReset,
              onPressed: null,
            ),
          ],
        );
      case StopwatchState.running:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionButton(
              label: l10n.stopwatchStop,
              onPressed: notifier.stop,
              primary: true,
            ),
            const SizedBox(width: 16),
            _ActionButton(
              label: l10n.stopwatchLap,
              onPressed: notifier.lap,
            ),
          ],
        );
      case StopwatchState.paused:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionButton(
              label: l10n.stopwatchStart,
              onPressed: notifier.start,
              primary: true,
            ),
            const SizedBox(width: 16),
            _ActionButton(
              label: l10n.stopwatchReset,
              onPressed: notifier.reset,
            ),
          ],
        );
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            primary ? const Color(0xFFFF5252) : Colors.white24,
        foregroundColor: Colors.white,
        minimumSize: const Size(120, 48),
      ),
      child: Text(label),
    );
  }
}

class _LapList extends StatelessWidget {
  final StopwatchSnapshot snapshot;
  final AppLocalizations l10n;

  const _LapList({required this.snapshot, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final laps = snapshot.laps;
    if (laps.isEmpty) {
      return Center(
        child: Text(
          l10n.stopwatchEmptyLaps,
          style: const TextStyle(color: Colors.white38),
        ),
      );
    }
    return ListView.builder(
      itemCount: laps.length,
      itemBuilder: (context, index) {
        // Newest lap first.
        final lap = laps[laps.length - 1 - index];
        return ListTile(
          leading: Text(
            '${l10n.stopwatchLapLabel} ${lap.number}',
            style: const TextStyle(color: Colors.white70),
          ),
          trailing: Text(
            _formatLap(lap.lapMs),
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        );
      },
    );
  }

  String _formatLap(int ms) {
    final centiseconds = (ms ~/ 10) % 100;
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${centiseconds.toString().padLeft(2, '0')}';
  }
}
