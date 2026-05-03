import '../../models/exercise_item.dart';
import 'timer_state.dart';

sealed class TimerEvent {}

class PhaseStarted extends TimerEvent {
  final TimerPhase phase;
  final ExerciseItem? item;
  final int? targetReps;

  PhaseStarted({required this.phase, this.item, this.targetReps});
}

class PhaseEndingSoon extends TimerEvent {
  final TimerPhase phase;
  final int secondsRemaining;

  PhaseEndingSoon({required this.phase, required this.secondsRemaining});
}

class PhaseEnded extends TimerEvent {
  final TimerPhase phase;

  PhaseEnded({required this.phase});
}

class RoutineCompleted extends TimerEvent {}
