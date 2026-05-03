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
    _foregroundService.stop();
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
  }

  void _onEvent(TimerEvent event) {
    if (event is PhaseStarted) {
      final phaseName = event.phase.name;
      final itemName = event.item?.name ?? phaseName;
      _foregroundService.updateNotification(
        title: 'Fitness Timer',
        content: '$itemName — $phaseName',
      );
    } else if (event is RoutineCompleted) {
      _foregroundService.updateNotification(
        title: 'Fitness Timer',
        content: 'Workout complete!',
      );
    }
  }
}
