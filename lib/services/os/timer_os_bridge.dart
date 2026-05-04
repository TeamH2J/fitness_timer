import 'dart:async';

import '../timer/timer_event.dart';
import '../timer/timer_state.dart';
import 'foreground_service_controller.dart';
import 'wakelock_manager.dart';

/// Adapter that connects [TimerEngine] stream output to OS-level services.
///
/// Call [attach] when a routine starts and [detach] when it ends or is reset.
class TimerOsBridge {
  TimerOsBridge({
    required WakelockManager wakelock,
    required ForegroundServiceController foregroundService,
  })  : _wakelock = wakelock,
        _foregroundService = foregroundService;

  final WakelockManager _wakelock;
  final ForegroundServiceController _foregroundService;

  StreamSubscription<TimerSnapshot>? _snapshotSub;
  StreamSubscription<TimerEvent>? _eventSub;
  bool _wakelockActive = false;

  // FR-2 / FR-3 / FR-4 / FR-5 state
  bool _foregroundServiceStarted = false;
  String _lastNotificationContent = '';
  TimerState? _lastSnapshotState;

  /// Subscribes to [snapshots] and [events] from a TimerEngine.
  ///
  /// Cancels any prior subscriptions before subscribing, so calling [attach]
  /// twice is safe.
  void attach({
    required Stream<TimerSnapshot> snapshots,
    required Stream<TimerEvent> events,
  }) {
    _snapshotSub?.cancel();
    _eventSub?.cancel();

    _snapshotSub = snapshots.listen(_onSnapshot);
    _eventSub = events.listen(_onEvent);
  }

  /// Cancels subscriptions and stops the foreground service.
  void detach() {
    _snapshotSub?.cancel();
    _snapshotSub = null;
    _eventSub?.cancel();
    _eventSub = null;

    if (_wakelockActive) {
      _wakelock.disable();
      _wakelockActive = false;
    }

    // FR-5: stop only if service was started; then reset all per-cycle state.
    if (_foregroundServiceStarted) {
      _foregroundService.stop();
      _foregroundServiceStarted = false;
    }
    _lastSnapshotState = null;
    _lastNotificationContent = '';
  }

  void _onSnapshot(TimerSnapshot snapshot) {
    final running = snapshot.state == TimerState.running;
    if (running && !_wakelockActive) {
      _wakelockActive = true;
      _wakelock.enable();
    } else if (!running && _wakelockActive) {
      _wakelockActive = false;
      _wakelock.disable();
    }

    // FR-3: detect running ↔ paused transitions and update notification.
    final prev = _lastSnapshotState;
    final current = snapshot.state;
    _lastSnapshotState = current;

    if (prev == current) return; // same-state tick — no notification spam

    if (_foregroundServiceStarted && _lastNotificationContent.isNotEmpty) {
      if (prev == TimerState.running && current == TimerState.paused) {
        _foregroundService.updateNotification(
          title: 'Fitness Timer',
          content: 'Paused — $_lastNotificationContent',
        );
      } else if (prev == TimerState.paused && current == TimerState.running) {
        _foregroundService.updateNotification(
          title: 'Fitness Timer',
          content: _lastNotificationContent,
        );
      }
    }
  }

  void _onEvent(TimerEvent event) {
    if (event is PhaseStarted) {
      final phaseName = event.phase.name;
      final itemName = event.item?.name ?? phaseName;
      final content = '$itemName — $phaseName';

      // FR-4: cache content for pause/resume notification.
      _lastNotificationContent = content;

      // FR-2: first PhaseStarted → start(); subsequent ones → updateNotification().
      if (!_foregroundServiceStarted) {
        _foregroundServiceStarted = true;
        _foregroundService.start(title: 'Fitness Timer', content: content);
      } else {
        _foregroundService.updateNotification(
          title: 'Fitness Timer',
          content: content,
        );
      }
    } else if (event is RoutineCompleted) {
      _foregroundService.updateNotification(
        title: 'Fitness Timer',
        content: 'Workout complete!',
      );
    }
  }
}
