import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_timer/models/exercise_item.dart';
import 'package:fitness_timer/services/os/foreground_service_controller.dart';
import 'package:fitness_timer/services/os/notification_throttler.dart';
import 'package:fitness_timer/services/os/platform_info.dart';
import 'package:fitness_timer/services/os/timer_os_bridge.dart';
import 'package:fitness_timer/services/os/wakelock_manager.dart';
import 'package:fitness_timer/services/timer/timer_event.dart';
import 'package:fitness_timer/services/timer/timer_state.dart';

/// Fake wakelock backend with call counters.
class _FakeWakelockBackend implements WakelockBackend {
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  Future<void> enable() async => enableCalls++;

  @override
  Future<void> disable() async => disableCalls++;

  @override
  Future<bool> isEnabled() async => enableCalls > disableCalls;
}

/// Fake foreground backend with call counters and content tracking.
class _FakeForegroundBackend implements ForegroundBackend {
  int startCalls = 0;
  int updateCalls = 0;
  int stopCalls = 0;
  String lastContent = '';

  @override
  Future<void> startService(
      {required String notificationTitle,
      required String notificationText}) async {
    startCalls++;
    lastContent = notificationText;
  }

  @override
  Future<void> updateService(
      {required String notificationTitle,
      required String notificationText}) async {
    updateCalls++;
    lastContent = notificationText;
  }

  @override
  Future<void> stopService() async => stopCalls++;
}

/// NotificationThrottler that never throttles (zero minInterval).
class _InstantThrottler extends NotificationThrottler {
  _InstantThrottler() : super(now: DateTime.now);

  @override
  Future<void> throttle(
    Future<void> Function() updateFn, {
    Duration minInterval = Duration.zero,
  }) async {
    await updateFn();
  }
}

TimerSnapshot _snapshot(TimerState state) => TimerSnapshot(
      state: state,
      remainingMs: 5000,
      totalMs: 30000,
    );

PhaseStarted _phaseStarted({String itemName = 'Push-ups'}) => PhaseStarted(
      phase: TimerPhase.work,
      item: ExerciseItem(
        id: '1',
        routineId: 'r1',
        orderIndex: 0,
        type: ExerciseType.WORK_TIME,
        duration: 30,
        name: itemName,
      ),
    );

void main() {
  late _FakeWakelockBackend wakelockBackend;
  late WakelockManager wakelock;
  late _FakeForegroundBackend foregroundBackend;
  late ForegroundServiceController foregroundService;
  late TimerOsBridge bridge;

  late StreamController<TimerSnapshot> snapshotCtrl;
  late StreamController<TimerEvent> eventCtrl;

  setUp(() {
    wakelockBackend = _FakeWakelockBackend();
    wakelock = WakelockManager(backend: wakelockBackend);

    foregroundBackend = _FakeForegroundBackend();
    foregroundService = ForegroundServiceController(
      platform: FakePlatformInfo(isAndroid: true, isIOS: false),
      throttler: _InstantThrottler(),
      backend: foregroundBackend,
    );

    bridge = TimerOsBridge(
      wakelock: wakelock,
      foregroundService: foregroundService,
    );

    snapshotCtrl = StreamController<TimerSnapshot>.broadcast();
    eventCtrl = StreamController<TimerEvent>.broadcast();
    bridge.attach(snapshots: snapshotCtrl.stream, events: eventCtrl.stream);
  });

  tearDown(() {
    snapshotCtrl.close();
    eventCtrl.close();
  });

  group('TimerOsBridge — wakelock', () {
    test('running snapshot → wakelock.enable called once', () async {
      snapshotCtrl.add(_snapshot(TimerState.running));
      await Future<void>.delayed(Duration.zero);

      expect(wakelockBackend.enableCalls, 1);
    });

    test('second running snapshot → wakelock.enable NOT called again (_wakelockActive guard)',
        () async {
      snapshotCtrl.add(_snapshot(TimerState.running));
      await Future<void>.delayed(Duration.zero);
      final countAfterFirst = wakelockBackend.enableCalls;

      snapshotCtrl.add(_snapshot(TimerState.running));
      await Future<void>.delayed(Duration.zero);

      expect(wakelockBackend.enableCalls, countAfterFirst); // no extra call
    });

    test('paused snapshot after running → wakelock.disable called', () async {
      snapshotCtrl.add(_snapshot(TimerState.running));
      await Future<void>.delayed(Duration.zero);

      snapshotCtrl.add(_snapshot(TimerState.paused));
      await Future<void>.delayed(Duration.zero);

      expect(wakelockBackend.disableCalls, 1);
    });

    test(
        'completed snapshot when already inactive → wakelock.disable NOT called again',
        () async {
      // Start in paused (wakelock inactive), then completed.
      snapshotCtrl.add(_snapshot(TimerState.paused));
      await Future<void>.delayed(Duration.zero);

      snapshotCtrl.add(_snapshot(TimerState.completed));
      await Future<void>.delayed(Duration.zero);

      expect(wakelockBackend.disableCalls, 0);
    });
  });

  group('TimerOsBridge — foreground service start/update', () {
    test('first PhaseStarted → start() called once, updateNotification() not called',
        () async {
      eventCtrl.add(_phaseStarted());
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.startCalls, 1);
      expect(foregroundBackend.updateCalls, 0);
    });

    test('second PhaseStarted (same attach cycle) → start() not called again, updateNotification() called',
        () async {
      eventCtrl.add(_phaseStarted());
      await Future<void>.delayed(Duration.zero);

      eventCtrl.add(_phaseStarted(itemName: 'Squats'));
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.startCalls, 1);
      expect(foregroundBackend.updateCalls, 1);
    });

    test('RoutineCompleted after PhaseStarted → updateNotification() called, start() not again',
        () async {
      eventCtrl.add(_phaseStarted());
      await Future<void>.delayed(Duration.zero);

      eventCtrl.add(RoutineCompleted());
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.startCalls, 1);
      expect(foregroundBackend.updateCalls, greaterThanOrEqualTo(1));
    });

    test('notification content set to item — phase on first PhaseStarted', () async {
      eventCtrl.add(_phaseStarted(itemName: 'Push-ups'));
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.lastContent, 'Push-ups — work');
    });
  });

  group('TimerOsBridge — paused state notification', () {
    test('running → paused snapshot after service started → updateNotification with Paused prefix',
        () async {
      // Start the service first via PhaseStarted.
      eventCtrl.add(_phaseStarted());
      await Future<void>.delayed(Duration.zero);

      // Simulate running then paused.
      snapshotCtrl.add(_snapshot(TimerState.running));
      await Future<void>.delayed(Duration.zero);
      final updatesBefore = foregroundBackend.updateCalls;

      snapshotCtrl.add(_snapshot(TimerState.paused));
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.updateCalls, updatesBefore + 1);
      expect(foregroundBackend.lastContent, startsWith('Paused — '));
    });

    test('paused → running snapshot → updateNotification with original content (no prefix)',
        () async {
      eventCtrl.add(_phaseStarted());
      await Future<void>.delayed(Duration.zero);

      snapshotCtrl.add(_snapshot(TimerState.running));
      await Future<void>.delayed(Duration.zero);
      snapshotCtrl.add(_snapshot(TimerState.paused));
      await Future<void>.delayed(Duration.zero);

      final updatesBefore = foregroundBackend.updateCalls;
      snapshotCtrl.add(_snapshot(TimerState.running));
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.updateCalls, updatesBefore + 1);
      expect(foregroundBackend.lastContent, isNot(startsWith('Paused — ')));
      expect(foregroundBackend.lastContent, 'Push-ups — work');
    });

    test('multiple identical running snapshots → no additional updateNotification calls',
        () async {
      eventCtrl.add(_phaseStarted());
      await Future<void>.delayed(Duration.zero);

      snapshotCtrl.add(_snapshot(TimerState.running));
      await Future<void>.delayed(Duration.zero);
      final countAfterFirst = foregroundBackend.updateCalls;

      // Same state — should not trigger additional updates.
      snapshotCtrl.add(_snapshot(TimerState.running));
      snapshotCtrl.add(_snapshot(TimerState.running));
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.updateCalls, countAfterFirst);
    });

    test('snapshot transition when service NOT started → no notification calls', () async {
      // No PhaseStarted fired — service never started.
      snapshotCtrl.add(_snapshot(TimerState.running));
      await Future<void>.delayed(Duration.zero);
      snapshotCtrl.add(_snapshot(TimerState.paused));
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.updateCalls, 0);
    });
  });

  group('TimerOsBridge — detach', () {
    test('detach() — further snapshots do not trigger wakelock', () async {
      bridge.detach();

      snapshotCtrl.add(_snapshot(TimerState.running));
      await Future<void>.delayed(Duration.zero);

      expect(wakelockBackend.enableCalls, 0);
    });

    test('detach() — further events do not trigger foreground update', () async {
      bridge.detach();

      eventCtrl.add(_phaseStarted());
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.updateCalls, 0);
      expect(foregroundBackend.startCalls, 0);
    });

    test('detach() disables wakelock if it was active', () async {
      snapshotCtrl.add(_snapshot(TimerState.running));
      await Future<void>.delayed(Duration.zero);
      expect(wakelockBackend.enableCalls, 1);

      bridge.detach();
      expect(wakelockBackend.disableCalls, 1);
    });

    test('detach() when service started → stop() called once', () async {
      eventCtrl.add(_phaseStarted());
      await Future<void>.delayed(Duration.zero);

      bridge.detach();
      expect(foregroundBackend.stopCalls, 1);
    });

    test('detach() when service NOT started (no PhaseStarted fired) → stop() not called',
        () async {
      bridge.detach();
      expect(foregroundBackend.stopCalls, 0);
    });

    test('detach() then re-attach() + PhaseStarted → start() called again (clean cycle)',
        () async {
      // First cycle.
      eventCtrl.add(_phaseStarted());
      await Future<void>.delayed(Duration.zero);
      expect(foregroundBackend.startCalls, 1);

      bridge.detach();

      // Second cycle — new controllers.
      final snap2 = StreamController<TimerSnapshot>.broadcast();
      final event2 = StreamController<TimerEvent>.broadcast();
      bridge.attach(snapshots: snap2.stream, events: event2.stream);

      event2.add(_phaseStarted());
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.startCalls, 2);

      snap2.close();
      event2.close();
    });

    test('attach() cancels prior subscription before re-attaching', () async {
      // Attach a second time with new controllers.
      final snap2 = StreamController<TimerSnapshot>.broadcast();
      final event2 = StreamController<TimerEvent>.broadcast();
      bridge.attach(snapshots: snap2.stream, events: event2.stream);

      // Old controller's events should not trigger any calls.
      snapshotCtrl.add(_snapshot(TimerState.running));
      await Future<void>.delayed(Duration.zero);
      expect(wakelockBackend.enableCalls, 0);

      // New controller works.
      snap2.add(_snapshot(TimerState.running));
      await Future<void>.delayed(Duration.zero);
      expect(wakelockBackend.enableCalls, 1);

      snap2.close();
      event2.close();
    });
  });

  group('TimerOsBridge — iOS platform', () {
    test('iOS platform + PhaseStarted → no start or update calls', () async {
      // Rebuild bridge with iOS platform.
      final iosForegroundBackend = _FakeForegroundBackend();
      final iosForegroundService = ForegroundServiceController(
        platform: FakePlatformInfo(isAndroid: false, isIOS: true),
        throttler: _InstantThrottler(),
        backend: iosForegroundBackend,
      );
      final iosBridge = TimerOsBridge(
        wakelock: wakelock,
        foregroundService: iosForegroundService,
      );

      final snapIos = StreamController<TimerSnapshot>.broadcast();
      final eventIos = StreamController<TimerEvent>.broadcast();
      iosBridge.attach(snapshots: snapIos.stream, events: eventIos.stream);

      eventIos.add(_phaseStarted());
      await Future<void>.delayed(Duration.zero);

      expect(iosForegroundBackend.startCalls, 0);
      expect(iosForegroundBackend.updateCalls, 0);

      iosBridge.detach();
      snapIos.close();
      eventIos.close();
    });
  });
}
