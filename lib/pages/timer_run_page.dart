import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/exercise_item.dart';
import '../models/routine.dart';
import '../providers/database_provider.dart';
import '../providers/feedback_provider.dart';
import '../providers/os_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/timer_engine_provider.dart';
import '../services/timer/timer_event.dart';
import '../services/timer/timer_state.dart';
import '../theme/fixed_text_styles.dart';
import '../utils/format_time.dart';
import '../widgets/circular_progress_painter.dart';

/// FutureProvider that loads [Routine] + its [ExerciseItem] list.
final _routineDataProvider = FutureProvider.autoDispose
    .family<RoutineWithItems?, String>((ref, routineId) async {
  final db = ref.read(databaseServiceProvider);
  final routine = await db.getRoutine(routineId);
  if (routine == null) return null;
  final items = await db.getExerciseItems(routineId);
  return RoutineWithItems(routine: routine, items: items);
});

class TimerRunPage extends ConsumerStatefulWidget {
  final String routineId;

  /// When true, the X-button navigates to the Routines tab instead of context.go('/').
  final bool embedded;

  const TimerRunPage({
    super.key,
    required this.routineId,
    this.embedded = false,
  });

  @override
  ConsumerState<TimerRunPage> createState() => _TimerRunPageState();
}

class _TimerRunPageState extends ConsumerState<TimerRunPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _animController;
  StreamSubscription<dynamic>? _eventSub;
  RoutineWithItems? _routineData;
  bool _started = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 60fps animation controller — drives AnimatedBuilder for the painter.
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _animController.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (_routineData == null) return;
      final snapshot = ref.read(timerEngineProvider(_routineData!));
      if (snapshot.state == TimerState.running &&
          !_animController.isAnimating) {
        _animController.repeat();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    _animController.dispose();
    _eventSub?.cancel();

    // Detach OS bridge and feedback controller if engine was started.
    if (_routineData != null) {
      try {
        ref.read(timerOsBridgeProvider).detach();
      } catch (_) {}
      try {
        ref.read(feedbackControllerProvider).detach();
      } catch (_) {}
    }
    super.dispose();
  }

  void _onRoutineLoaded(RoutineWithItems data) {
    if (_started || _disposed) return;
    _started = true;
    _routineData = data;

    // Keep last-used updated (covers deep-link entry).
    try {
      ref.read(lastRoutineIdProvider.notifier).set(widget.routineId);
    } catch (_) {}

    // Get the engine notifier for this routine.
    final notifier = ref.read(timerEngineProvider(data).notifier);
    final engine = notifier.engine;

    // Attach feedback and OS bridge.
    try {
      ref.read(feedbackControllerProvider).attach(engine.events);
    } catch (_) {}
    try {
      ref
          .read(timerOsBridgeProvider)
          .attach(snapshots: engine.snapshots, events: engine.events);
    } catch (_) {}

    // Listen for RoutineCompleted to navigate.
    _eventSub = engine.events.listen((event) {
      if (event is RoutineCompleted && !_disposed && mounted) {
        context.replace('/routine/${widget.routineId}/complete');
      }
    });

    // Start the engine.
    try {
      notifier.start();
    } catch (_) {
      // Already started — guard in case of hot reload.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final routineDataAsync =
        ref.watch(_routineDataProvider(widget.routineId));

    return routineDataAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text(l10n.errorLoadRoutine)),
      ),
      data: (data) {
        if (data == null) {
          // Routine not found — go home.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Start engine once data is available.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onRoutineLoaded(data);
        });

        return _TimerRunView(
          routineId: widget.routineId,
          routineData: data,
          animController: _animController,
          l10n: l10n,
          embedded: widget.embedded,
        );
      },
    );
  }
}

class _TimerRunView extends ConsumerWidget {
  final String routineId;
  final RoutineWithItems routineData;
  final AnimationController animController;
  final AppLocalizations l10n;
  final bool embedded;

  const _TimerRunView({
    required this.routineId,
    required this.routineData,
    required this.animController,
    required this.l10n,
    required this.embedded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(timerEngineProvider(routineData));
    final notifier = ref.read(timerEngineProvider(routineData).notifier);
    final displayFormat = ref.watch(settingsProvider.select((s) => s.displayFormat));

    final totalMs = snapshot.totalMs > 0 ? snapshot.totalMs : 1;
    final remainingMs = snapshot.remainingMs;
    final remainingSeconds = (remainingMs / 1000).ceil();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Content layer
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Cycle indicator
                SizedBox(
                  height: 22,
                  child: Center(
                    child: Text(
                      '${l10n.cycle} ${snapshot.currentCycle} / ${routineData.routine.totalCycles}',
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Current exercise name
                SizedBox(
                  height: 32,
                  child: Center(
                    child: Text(
                      _phaseName(snapshot, l10n),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Circular progress + center digit
                AnimatedBuilder(
                  animation: animController,
                  builder: (context, _) {
                    final liveRemainingMs = snapshot.state == TimerState.running
                        ? remainingMs
                        : remainingMs;
                    final progress = totalMs > 0
                        ? 1.0 - (liveRemainingMs / totalMs)
                        : 0.0;

                    return SizedBox(
                      width: 240,
                      height: 240,
                      child: CustomPaint(
                        painter: CircularProgressPainter(
                          progress: progress.clamp(0.0, 1.0),
                          foreground: _phaseColor(snapshot.phase),
                          background: Colors.white12,
                          strokeWidth: 12,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                formatTime(remainingSeconds, displayFormat),
                                style: FixedTextStyles.largeNumber,
                                textScaler: TextScaler.noScaling,
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Reps target (WORK_REPS mode)
                SizedBox(
                  height: 28,
                  child: snapshot.targetReps != null
                      ? Center(
                          child: Text(
                            '${snapshot.targetReps} ${l10n.repsTarget}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 20,
                            ),
                          ),
                        )
                      : null,
                ),

                const SizedBox(height: 24),

                // Next item preview — show "Rest" when the immediately next phase
                // is rest, otherwise show the upcoming exercise's name.
                SizedBox(
                  height: 20,
                  child: Center(
                    child: Text(
                      snapshot.nextPhase == TimerPhase.rest
                          ? '${l10n.next}: ${l10n.typeRest}'
                          : snapshot.nextItem != null
                              ? '${l10n.next}: ${snapshot.nextItem!.name}'
                              : '',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                ),

                // Pause indicator
                SizedBox(
                  height: 48,
                  child: snapshot.state == TimerState.paused
                      ? const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Icon(Icons.pause_circle_outline,
                              color: Colors.white54, size: 32),
                        )
                      : null,
                ),
              ],
            ),
          ),

          // Full-screen invisible tap zone for play/pause
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: notifier.togglePlayPause,
              child: const SizedBox.expand(),
            ),
          ),

          // X button top-left — above the gesture detector
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      try {
                        notifier.reset();
                      } catch (_) {}
                      if (embedded) {
                        ref.read(tabIndexProvider.notifier).state = 0;
                      } else {
                        context.go('/');
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close, color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _phaseName(TimerSnapshot snapshot, AppLocalizations l10n) {
    final item = snapshot.currentItem;
    if (item == null || item.name.isEmpty) {
      return _phaseLabel(snapshot.phase, l10n);
    }
    if (snapshot.phase == TimerPhase.rest) {
      return '${item.name}(${l10n.typeRest})';
    }
    return item.name;
  }

  String _phaseLabel(TimerPhase? phase, AppLocalizations l10n) {
    switch (phase) {
      case TimerPhase.prep:
        return l10n.prepTime;
      case TimerPhase.rest:
        return l10n.typeRest;
      case TimerPhase.cooldown:
        return l10n.cooldownTime;
      case TimerPhase.work:
        return l10n.typeWorkTime;
      case null:
        return '';
    }
  }

  Color _phaseColor(TimerPhase? phase) {
    switch (phase) {
      case TimerPhase.prep:
        return const Color(0xFFFFB300);
      case TimerPhase.work:
        return const Color(0xFFFF5252);
      case TimerPhase.rest:
        return const Color(0xFF4CAF50);
      case TimerPhase.cooldown:
        return const Color(0xFF26C6DA);
      case null:
        return const Color(0xFFFF5252);
    }
  }
}
