import 'dart:async';
import 'dart:math';

import '../../models/exercise_item.dart';
import '../../models/routine.dart';
import 'clock.dart';
import 'timer_event.dart';
import 'timer_state.dart';

class _QueueEntry {
  final TimerPhase phase;
  final int durationMs;
  final ExerciseItem? item;
  final int cycleIndex;

  const _QueueEntry({
    required this.phase,
    required this.durationMs,
    this.item,
    required this.cycleIndex,
  });
}

class TimerEngine {
  final Routine _routine;
  final List<ExerciseItem> _items;
  final Clock _clock;

  final StreamController<TimerSnapshot> _snapshotController =
      StreamController<TimerSnapshot>.broadcast();
  final StreamController<TimerEvent> _eventController =
      StreamController<TimerEvent>.broadcast();

  TimerState _state = TimerState.idle;
  TimerPhase? _currentPhase;
  List<_QueueEntry> _queue = [];
  int _queueIndex = 0;
  _QueueEntry? _currentEntry;
  DateTime _targetAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _remainingAtPause = 0;
  bool _announcedEnding = false;
  Timer? _ticker;

  TimerSnapshot _current = TimerSnapshot.idle;

  TimerEngine({
    required Routine routine,
    required List<ExerciseItem> items,
    Clock? clock,
  })  : _routine = routine,
        _items = items,
        _clock = clock ?? SystemClock();

  Stream<TimerSnapshot> get snapshots => _snapshotController.stream;
  Stream<TimerEvent> get events => _eventController.stream;
  TimerSnapshot get current => _current;

  void start() {
    if (_state != TimerState.idle) {
      throw StateError('start() can only be called from idle state, current: $_state');
    }

    _queue = _buildPhaseQueue();
    _queueIndex = 0;
    _state = TimerState.running;

    if (_queue.isEmpty) {
      _completeRoutine();
      return;
    }

    _enterPhase(_queue[0]);
  }

  void pause() {
    if (_state != TimerState.running) return;

    _remainingAtPause = max(0, _targetAt.difference(_clock.now()).inMilliseconds);
    _ticker?.cancel();
    _ticker = null;
    _state = TimerState.paused;
    _emitSnapshot(_remainingAtPause);
  }

  void resume() {
    if (_state != TimerState.paused) return;

    _targetAt = _clock.now().add(Duration(milliseconds: _remainingAtPause));
    _state = TimerState.running;
    _emitSnapshot(_remainingAtPause);
    _startTicker();
  }

  void togglePlayPause() {
    if (_state == TimerState.running) {
      pause();
    } else if (_state == TimerState.paused) {
      resume();
    }
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _state = TimerState.idle;
    _currentPhase = null;
    _currentEntry = null;
    _queue = [];
    _queueIndex = 0;
    _remainingAtPause = 0;
    _announcedEnding = false;
    _current = TimerSnapshot.idle;
    _safeAddSnapshot(_current);
  }

  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    if (!_snapshotController.isClosed) {
      _snapshotController.close();
    }
    if (!_eventController.isClosed) {
      _eventController.close();
    }
  }

  List<_QueueEntry> _buildPhaseQueue() {
    final queue = <_QueueEntry>[];

    if (_routine.prepTime > 0) {
      queue.add(_QueueEntry(
        phase: TimerPhase.prep,
        durationMs: _routine.prepTime * 1000,
        item: null,
        cycleIndex: 0,
      ));
    }

    final sortedItems = List<ExerciseItem>.from(_items)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    for (var cycle = 1; cycle <= _routine.totalCycles; cycle++) {
      for (final item in sortedItems) {
        final phase =
            item.type == ExerciseType.REST ? TimerPhase.rest : TimerPhase.work;
        queue.add(_QueueEntry(
          phase: phase,
          durationMs: max(0, item.duration * 1000),
          item: item,
          cycleIndex: cycle,
        ));
      }
    }

    if (_routine.cooldownTime > 0) {
      queue.add(_QueueEntry(
        phase: TimerPhase.cooldown,
        durationMs: _routine.cooldownTime * 1000,
        item: null,
        cycleIndex: 0,
      ));
    }

    return queue;
  }

  void _enterPhase(_QueueEntry entry) {
    _currentEntry = entry;
    _currentPhase = entry.phase;
    _targetAt = _clock.now().add(Duration(milliseconds: entry.durationMs));
    _announcedEnding = false;

    _safeAddEvent(PhaseStarted(
      phase: entry.phase,
      item: entry.item,
      targetReps: entry.item?.type == ExerciseType.WORK_REPS
          ? entry.item?.targetReps
          : null,
    ));

    _emitSnapshot(entry.durationMs);
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), _onTick);
  }

  void _onTick(Timer _) {
    if (_state != TimerState.running) return;

    final remainingMs =
        max(0, _targetAt.difference(_clock.now()).inMilliseconds);

    if (remainingMs <= 3000 && remainingMs > 2750 && !_announcedEnding) {
      _announcedEnding = true;
      _safeAddEvent(PhaseEndingSoon(
        phase: _currentEntry!.phase,
        secondsRemaining: 3,
      ));
    }

    _emitSnapshot(remainingMs);

    if (remainingMs <= 0) {
      _ticker?.cancel();
      _ticker = null;
      _safeAddEvent(PhaseEnded(phase: _currentEntry!.phase));

      if (_queueIndex + 1 < _queue.length) {
        _queueIndex++;
        _enterPhase(_queue[_queueIndex]);
      } else {
        _completeRoutine();
      }
    }
  }

  void _completeRoutine() {
    _state = TimerState.completed;
    _currentPhase = null;
    _safeAddEvent(RoutineCompleted());
    _emitSnapshot(0);
  }

  void _emitSnapshot(int remainingMs) {
    final entry = _currentEntry;
    final nextEntry = (_queueIndex + 1 < _queue.length)
        ? _queue[_queueIndex + 1]
        : null;

    _current = TimerSnapshot(
      state: _state,
      phase: _currentPhase,
      currentItem: entry?.item,
      currentCycle: entry?.cycleIndex ?? 0,
      remainingMs: remainingMs,
      totalMs: entry?.durationMs ?? 0,
      nextItem: nextEntry?.item,
      targetReps: entry?.item?.type == ExerciseType.WORK_REPS
          ? entry?.item?.targetReps
          : null,
    );
    _safeAddSnapshot(_current);
  }

  void _safeAddSnapshot(TimerSnapshot snapshot) {
    if (!_snapshotController.isClosed) {
      _snapshotController.add(snapshot);
    }
  }

  void _safeAddEvent(TimerEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }
}
