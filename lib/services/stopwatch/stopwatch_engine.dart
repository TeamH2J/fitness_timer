import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../models/stopwatch_session.dart';

/// Core count-up timing engine with lap recording.
///
/// Drive a 100 ms [Timer.periodic] ticker when running; emit
/// [StopwatchSnapshot] on each tick via a broadcast stream.
class StopwatchEngine {
  StopwatchEngine() : _controller = StreamController<StopwatchSnapshot>.broadcast();

  final StreamController<StopwatchSnapshot> _controller;

  StopwatchState _state = StopwatchState.idle;
  int _elapsedMs = 0;
  int _lapStartMs = 0;
  final List<LapRecord> _laps = [];
  DateTime? _startedAt;
  DateTime? _tickStart;
  Timer? _ticker;
  bool _disposed = false;

  Stream<StopwatchSnapshot> get snapshots => _controller.stream;

  StopwatchSnapshot get current => StopwatchSnapshot(
        state: _state,
        elapsedMs: _elapsedMs,
        currentLapMs: _elapsedMs - _lapStartMs,
        laps: List.unmodifiable(_laps),
      );

  /// idle → running OR paused → running.
  void start() {
    if (_state == StopwatchState.running) {
      throw StateError('StopwatchEngine.start() called when already running');
    }
    if (_state == StopwatchState.idle) {
      _startedAt = DateTime.now().toUtc();
      _lapStartMs = 0;
    }
    _tickStart = DateTime.now();
    _state = StopwatchState.running;
    _ticker = Timer.periodic(const Duration(milliseconds: 100), _onTick);
    _emit();
  }

  /// running → paused.
  void stop() {
    if (_state != StopwatchState.running) return;
    _ticker?.cancel();
    _ticker = null;
    _flushElapsed();
    _state = StopwatchState.paused;
    _emit();
  }

  /// Records a lap; no-op if not running.
  void lap() {
    if (_state != StopwatchState.running) return;
    _flushElapsed();
    final lapMs = _elapsedMs - _lapStartMs;
    _laps.add(LapRecord(
      number: _laps.length + 1,
      lapMs: lapMs,
      totalMs: _elapsedMs,
    ));
    _lapStartMs = _elapsedMs;
    _emit();
  }

  /// paused/idle → idle. Returns [StopwatchSession] if elapsed > 0, else null.
  /// No-op if running.
  StopwatchSession? reset() {
    if (_state == StopwatchState.running) return null;
    _ticker?.cancel();
    _ticker = null;

    StopwatchSession? session;
    if (_elapsedMs > 0) {
      final endedAt = DateTime.now().toUtc();
      session = StopwatchSession(
        id: const Uuid().v4(),
        startedAt: _startedAt ?? endedAt,
        endedAt: endedAt,
        totalMs: _elapsedMs,
        laps: List.unmodifiable(List.of(_laps)),
      );
    }

    _state = StopwatchState.idle;
    _elapsedMs = 0;
    _lapStartMs = 0;
    _laps.clear();
    _startedAt = null;
    _tickStart = null;
    _emit();

    return session;
  }

  /// Cancel ticker and close stream.
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _ticker = null;
    _controller.close();
  }

  void _onTick(Timer _) {
    if (_disposed) return;
    _flushElapsed();
    _emit();
  }

  void _flushElapsed() {
    final start = _tickStart;
    if (start == null) return;
    final now = DateTime.now();
    _elapsedMs += now.difference(start).inMilliseconds;
    _tickStart = now;
  }

  void _emit() {
    if (_disposed || _controller.isClosed) return;
    _controller.add(current);
  }
}
