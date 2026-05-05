import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/stopwatch_session.dart';
import '../providers/database_provider.dart';
import '../providers/stopwatch_provider.dart';
import '../widgets/sparkline_painter.dart';

// ---------------------------------------------------------------------------
// Top-level formatting helpers shared by multiple widgets in this file.
// ---------------------------------------------------------------------------

/// Formats [ms] as MM:SS (seconds precision).
String _fmtMmSs(int? ms) {
  if (ms == null) return '—';
  final s = ms ~/ 1000;
  final min = s ~/ 60;
  final sec = s % 60;
  return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
}

/// Formats [ms] as MM:SS.cs (centisecond precision).
String _fmtMmSsCs(int ms) {
  final totalCs = ms ~/ 10;
  final min = totalCs ~/ 6000;
  final sec = (totalCs % 6000) ~/ 100;
  final cs = totalCs % 100;
  return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
}

class StopwatchDetailPage extends ConsumerStatefulWidget {
  const StopwatchDetailPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<StopwatchDetailPage> createState() =>
      _StopwatchDetailPageState();
}

class _StopwatchDetailPageState extends ConsumerState<StopwatchDetailPage> {
  final _labelController = TextEditingController();
  bool _controllerInitialized = false;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _saveLabel(StopwatchSession currentSession) async {
    final oldLabel = currentSession.label;
    final rawText = _labelController.text.trim();
    final newLabel = rawText.isEmpty ? null : rawText;

    try {
      await ref
          .read(databaseServiceProvider)
          .updateStopwatchSessionLabel(widget.sessionId, newLabel);
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.errorSave)));
      }
      return;
    }

    ref.invalidate(stopwatchSessionByIdProvider(widget.sessionId));
    ref.invalidate(mergedHistoryProvider);
    if (oldLabel != null) {
      ref.invalidate(sessionsByLabelProvider(oldLabel));
      ref.invalidate(personalBestProvider(oldLabel));
    }
    if (newLabel != null) {
      ref.invalidate(sessionsByLabelProvider(newLabel));
      ref.invalidate(personalBestProvider(newLabel));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sessionAsync = ref.watch(stopwatchSessionByIdProvider(widget.sessionId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.stopwatchDetailTitle)),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorLoadData)),
        data: (session) {
          if (session == null) {
            return Center(child: Text(l10n.errorLoadData));
          }

          // Initialise the TextField text once when data first arrives.
          if (!_controllerInitialized) {
            _labelController.text = session.label ?? '';
            _controllerInitialized = true;
          }

          return _DetailBody(
            session: session,
            labelController: _labelController,
            onSave: () => _saveLabel(session),
            l10n: l10n,
          );
        },
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.session,
    required this.labelController,
    required this.onSave,
    required this.l10n,
  });

  final StopwatchSession session;
  final TextEditingController labelController;
  final VoidCallback onSave;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Label editor
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: labelController,
                decoration: InputDecoration(
                  hintText: l10n.stopwatchLabelHint,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onSave,
              child: Text(l10n.stopwatchSaveLabel),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (session.label == null) ...[
          Text(l10n.stopwatchCompareNoLabel),
          const SizedBox(height: 16),
          _LapList(laps: session.laps, l10n: l10n),
        ] else ...[
          _CompareBlock(session: session, l10n: l10n),
        ],
      ],
    );
  }
}

class _CompareBlock extends ConsumerWidget {
  const _CompareBlock({required this.session, required this.l10n});

  final StopwatchSession session;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = session.label!;
    final labelSessionsAsync = ref.watch(sessionsByLabelProvider(label));
    final pbAsync = ref.watch(personalBestProvider(label));

    return labelSessionsAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text(l10n.errorLoadData),
      data: (labelSessions) {
        final pb = pbAsync.valueOrNull;

        // Sparkline values: oldest → newest (labelSessions is newest-first).
        final sparkValues =
            labelSessions.reversed.map((s) => s.totalMs).toList();

        // Prior session is labelSessions[1] if it exists (index 0 is current,
        // assuming labelSessions are sorted newest-first and current is newest).
        // However, the current session may not be the most recently saved one
        // (user could be viewing an older session). Find current in list.
        final currentIndex =
            labelSessions.indexWhere((s) => s.id == session.id);
        final StopwatchSession? priorSession =
            currentIndex >= 0 && currentIndex < labelSessions.length - 1
                ? labelSessions[currentIndex + 1]
                : null;

        final isSingleSession = labelSessions.length == 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PB badge
            if (pb != null && session.totalMs == pb)
              Chip(
                label: Text(l10n.stopwatchPbBadge),
                backgroundColor: Colors.amber,
              ),

            // Aggregates row (hidden for single session)
            if (!isSingleSession && priorSession != null) ...[
              const SizedBox(height: 8),
              _AggregatesRow(
                current: session,
                prior: priorSession,
                l10n: l10n,
              ),
            ],

            // Sparkline
            const SizedBox(height: 16),
            Text(l10n.stopwatchTrendTitle),
            const SizedBox(height: 4),
            SizedBox(
              height: 48,
              child: CustomPaint(
                painter: SparklinePainter(
                  values: sparkValues,
                  color: Theme.of(context).colorScheme.primary,
                ),
                size: Size.infinite,
              ),
            ),

            const SizedBox(height: 16),

            // No prior or lap compare
            if (isSingleSession)
              Text(l10n.stopwatchNoPrior)
            else if (priorSession != null)
              _LapCompareTable(
                current: session,
                prior: priorSession,
                l10n: l10n,
              ),
          ],
        );
      },
    );
  }
}

class _AggregatesRow extends StatelessWidget {
  const _AggregatesRow({
    required this.current,
    required this.prior,
    required this.l10n,
  });

  final StopwatchSession current;
  final StopwatchSession prior;
  final AppLocalizations l10n;

  int? _avgLap(StopwatchSession s) {
    if (s.laps.isEmpty) return null;
    return s.totalMs ~/ s.laps.length;
  }

  int? _fastest(StopwatchSession s) {
    if (s.laps.isEmpty) return null;
    return s.laps.map((l) => l.lapMs).reduce((a, b) => a < b ? a : b);
  }

  int? _slowest(StopwatchSession s) {
    if (s.laps.isEmpty) return null;
    return s.laps.map((l) => l.lapMs).reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (l10n.stopwatchAggregateTotal, current.totalMs, prior.totalMs),
      (l10n.stopwatchAggregateAvg, _avgLap(current), _avgLap(prior)),
      (l10n.stopwatchAggregateFastest, _fastest(current), _fastest(prior)),
      (l10n.stopwatchAggregateSlowest, _slowest(current), _slowest(prior)),
    ];

    return Row(
      children: metrics.map((m) {
        final label = m.$1;
        final cur = m.$2;
        final prev = m.$3;
        final delta = (cur != null && prev != null) ? cur - prev : null;
        return Expanded(
          child: Column(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(_fmtMmSs(cur)),
              if (delta != null)
                Text(
                  _fmtDelta(delta),
                  style: TextStyle(
                    color: delta <= 0 ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _fmtDelta(int delta) {
    final sign = delta < 0 ? '-' : (delta > 0 ? '+' : '');
    final abs = delta.abs() ~/ 1000;
    final min = abs ~/ 60;
    final sec = abs % 60;
    return '$sign${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

class _LapCompareTable extends StatelessWidget {
  const _LapCompareTable({
    required this.current,
    required this.prior,
    required this.l10n,
  });

  final StopwatchSession current;
  final StopwatchSession prior;
  final AppLocalizations l10n;

  String _fmtDelta(int delta) {
    final sign = delta < 0 ? '-' : (delta > 0 ? '+' : '');
    final abs = delta.abs();
    final totalCs = abs ~/ 10;
    final min = totalCs ~/ 6000;
    final sec = (totalCs % 6000) ~/ 100;
    final cs = totalCs % 100;
    return '$sign${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: [
        DataColumn(label: const Text('#')),
        DataColumn(label: Text(l10n.stopwatchLapLabel)),
        DataColumn(label: Text(l10n.stopwatchLapDiff)),
      ],
      rows: current.laps.map((lap) {
        final priorLap = lap.number <= prior.laps.length
            ? prior.laps[lap.number - 1]
            : null;
        final delta = priorLap != null ? lap.lapMs - priorLap.lapMs : null;

        return DataRow(cells: [
          DataCell(Text('${lap.number}')),
          DataCell(Text(_fmtMmSsCs(lap.lapMs))),
          DataCell(
            delta == null
                ? const Text('—')
                : Text(
                    _fmtDelta(delta),
                    style: TextStyle(
                      color: delta < 0 ? Colors.green : Colors.red,
                    ),
                  ),
          ),
        ]);
      }).toList(),
    );
  }
}

class _LapList extends StatelessWidget {
  const _LapList({required this.laps, required this.l10n});

  final List<LapRecord> laps;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (laps.isEmpty) return const SizedBox.shrink();
    return Column(
      children: laps
          .map(
            (lap) => ListTile(
              leading: Text('${lap.number}'),
              title: Text(_fmtMmSsCs(lap.lapMs)),
            ),
          )
          .toList(),
    );
  }
}
