import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exercise_item.dart';
import '../models/routine.dart';
import '../services/timer/timer_engine.dart';
import '../services/timer/timer_state.dart';

/// Lightweight parameter bundle for the timer engine provider.
/// Equality is based on [routine.id] so Riverpod caches correctly per routine.
class RoutineWithItems {
  final Routine routine;
  final List<ExerciseItem> items;

  const RoutineWithItems({required this.routine, required this.items});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoutineWithItems && other.routine.id == routine.id;
  }

  @override
  int get hashCode => routine.id.hashCode;
}

class TimerEngineNotifier extends StateNotifier<TimerSnapshot> {
  final TimerEngine _engine;
  StreamSubscription<TimerSnapshot>? _snapshotSub;

  TimerEngineNotifier(RoutineWithItems data)
      : _engine = TimerEngine(routine: data.routine, items: data.items),
        super(TimerSnapshot.idle) {
    _snapshotSub = _engine.snapshots.listen((snapshot) {
      state = snapshot;
    });
  }

  TimerEngine get engine => _engine;

  void start() => _engine.start();
  void pause() => _engine.pause();
  void resume() => _engine.resume();
  void togglePlayPause() => _engine.togglePlayPause();
  void reset() => _engine.reset();
  void preview() => _engine.preview();

  @override
  void dispose() {
    _snapshotSub?.cancel();
    _engine.dispose();
    super.dispose();
  }
}

final timerEngineProvider = StateNotifierProvider.autoDispose
    .family<TimerEngineNotifier, TimerSnapshot, RoutineWithItems>(
  (ref, data) => TimerEngineNotifier(data),
);
