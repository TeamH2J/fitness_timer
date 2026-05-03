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

/// Fake foreground backend with call counters.
class _FakeForegroundBackend implements ForegroundBackend {
  int startCalls = 0;
  int updateCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> startService(
      {required String notificationTitle,
      required String notificationText}) async =>
      startCalls++;

  @override
  Future<void> updateService(
      {required String notificationTitle,
      required String notificationText}) async =>
      updateCalls++;

  @override
  Future<void> stopService() async => stopCalls++;
}

TimerSnapshot _snapshot(TimerState state) => TimerSnapshot(
      state: state,
      remainingMs: 5000,
      totalMs: 30000,
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
      throttler: NotificationThrottler(),
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

  group('TimerOsBridge — foreground service', () {
    test('PhaseStarted event → updateNotification called', () async {
      eventCtrl.add(PhaseStarted(
        phase: TimerPhase.work,
        item: const ExerciseItem(
          id: '1',
          routineId: 'r1',
          orderIndex: 0,
          type: ExerciseType.WORK_TIME,
          duration: 30,
          name: 'Push-ups',
        ),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.updateCalls, 1);
    });

    test('RoutineCompleted event → updateNotification called', () async {
      // Advance time to ensure throttle window passes.
      await Future<void>.delayed(const Duration(seconds: 2));
      eventCtrl.add(RoutineCompleted());
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.updateCalls, greaterThanOrEqualTo(1));
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

      eventCtrl.add(PhaseStarted(phase: TimerPhase.work));
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.updateCalls, 0);
    });

    test('detach() disables wakelock if it was active', () async {
      snapshotCtrl.add(_snapshot(TimerState.running));
      await Future<void>.delayed(Duration.zero);
      expect(wakelockBackend.enableCalls, 1);

      bridge.detach();
      expect(wakelockBackend.disableCalls, 1);
    });

    test('detach() calls foreground service stop', () async {
      bridge.detach();
      expect(foregroundBackend.stopCalls, 1);
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
}
