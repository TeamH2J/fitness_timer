import '../../models/exercise_item.dart';

enum TimerState { idle, running, paused, completed }

enum TimerPhase { prep, work, rest, cooldown }

class TimerSnapshot {
  final TimerState state;
  final TimerPhase? phase;
  final ExerciseItem? currentItem;
  final int currentCycle;
  final int remainingMs;
  final int totalMs;
  final ExerciseItem? nextItem;
  final TimerPhase? nextPhase;
  final int? targetReps;

  const TimerSnapshot({
    required this.state,
    this.phase,
    this.currentItem,
    this.currentCycle = 0,
    this.remainingMs = 0,
    this.totalMs = 0,
    this.nextItem,
    this.nextPhase,
    this.targetReps,
  });

  static const idle = TimerSnapshot(
    state: TimerState.idle,
    currentCycle: 0,
    remainingMs: 0,
    totalMs: 0,
  );

  TimerSnapshot copyWith({
    TimerState? state,
    TimerPhase? phase,
    ExerciseItem? currentItem,
    int? currentCycle,
    int? remainingMs,
    int? totalMs,
    ExerciseItem? nextItem,
    TimerPhase? nextPhase,
    int? targetReps,
    bool clearPhase = false,
    bool clearCurrentItem = false,
    bool clearNextItem = false,
    bool clearNextPhase = false,
    bool clearTargetReps = false,
  }) {
    return TimerSnapshot(
      state: state ?? this.state,
      phase: clearPhase ? null : (phase ?? this.phase),
      currentItem: clearCurrentItem ? null : (currentItem ?? this.currentItem),
      currentCycle: currentCycle ?? this.currentCycle,
      remainingMs: remainingMs ?? this.remainingMs,
      totalMs: totalMs ?? this.totalMs,
      nextItem: clearNextItem ? null : (nextItem ?? this.nextItem),
      nextPhase: clearNextPhase ? null : (nextPhase ?? this.nextPhase),
      targetReps: clearTargetReps ? null : (targetReps ?? this.targetReps),
    );
  }
}
