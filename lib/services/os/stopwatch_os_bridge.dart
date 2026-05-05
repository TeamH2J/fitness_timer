import 'dart:async';

import '../../models/stopwatch_session.dart';
import 'foreground_service_controller.dart';
import 'wakelock_manager.dart';

/// Adapter connecting [StopwatchEngine] snapshot stream to OS-level services.
///
/// Mirrors [TimerOsBridge], but responds to [StopwatchSnapshot] stream.
class StopwatchOsBridge {
  StopwatchOsBridge({
    required WakelockManager wakelock,
    required ForegroundServiceController foregroundService,
  })  : _wakelock = wakelock,
        _foregroundService = foregroundService;

  final WakelockManager _wakelock;
  final ForegroundServiceController _foregroundService;

  StreamSubscription<StopwatchSnapshot>? _sub;
  bool _foregroundServiceStarted = false;
  String _lastElapsedContent = '';
  StopwatchState? _lastSnapshotState;
  bool _wakelockActive = false;

  /// Cancels any prior subscription; subscribes to the new snapshot stream.
  void attach(Stream<StopwatchSnapshot> snapshots) {
    _sub?.cancel();
    _sub = snapshots.listen(_onSnapshot);
  }

  /// Cancels subscription; disables wakelock; stops Android foreground service.
  void detach() {
    _sub?.cancel();
    _sub = null;

    if (_wakelockActive) {
      _wakelock.disable();
      _wakelockActive = false;
    }

    if (_foregroundServiceStarted) {
      _foregroundService.stop();
      _foregroundServiceStarted = false;
    }
    _lastElapsedContent = '';
    _lastSnapshotState = null;
  }

  void _onSnapshot(StopwatchSnapshot snapshot) {
    final running = snapshot.state == StopwatchState.running;

    // Wakelock: enable while running, disable otherwise.
    if (running && !_wakelockActive) {
      _wakelockActive = true;
      _wakelock.enable();
    } else if (!running && _wakelockActive) {
      _wakelockActive = false;
      _wakelock.disable();
    }

    final prev = _lastSnapshotState;
    final current = snapshot.state;
    _lastSnapshotState = current;

    if (running) {
      final elapsedStr = _formatElapsed(snapshot.elapsedMs);
      _lastElapsedContent = elapsedStr;

      if (!_foregroundServiceStarted) {
        _foregroundServiceStarted = true;
        _foregroundService.start(
          title: 'Fitness Timer',
          content: 'Stopwatch — $elapsedStr',
        );
      } else {
        _foregroundService.updateNotification(
          title: 'Fitness Timer',
          content: 'Stopwatch — $elapsedStr',
        );
      }
    } else if (current == StopwatchState.paused &&
        prev == StopwatchState.running) {
      _foregroundService.updateNotification(
        title: 'Fitness Timer',
        content: 'Paused — $_lastElapsedContent',
      );
    }
  }

  String _formatElapsed(int ms) {
    final total = ms ~/ 1000;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
