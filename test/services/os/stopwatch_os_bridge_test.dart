import 'dart:async';

import 'package:fitness_timer/models/stopwatch_session.dart';
import 'package:fitness_timer/services/os/foreground_service_controller.dart';
import 'package:fitness_timer/services/os/notification_throttler.dart';
import 'package:fitness_timer/services/os/platform_info.dart';
import 'package:fitness_timer/services/os/stopwatch_os_bridge.dart';
import 'package:fitness_timer/services/os/wakelock_manager.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Future<void> startService({
    required String notificationTitle,
    required String notificationText,
  }) async {
    startCalls++;
    lastContent = notificationText;
  }

  @override
  Future<void> updateService({
    required String notificationTitle,
    required String notificationText,
  }) async {
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

StopwatchSnapshot _snapshot(StopwatchState state, {int elapsedMs = 5000}) =>
    StopwatchSnapshot(
      state: state,
      elapsedMs: elapsedMs,
      currentLapMs: 0,
      laps: const [],
    );

void main() {
  late _FakeWakelockBackend wakelockBackend;
  late WakelockManager wakelock;
  late _FakeForegroundBackend foregroundBackend;
  late ForegroundServiceController foregroundService;
  late StopwatchOsBridge bridge;
  late StreamController<StopwatchSnapshot> snapshotCtrl;

  setUp(() {
    wakelockBackend = _FakeWakelockBackend();
    wakelock = WakelockManager(backend: wakelockBackend);

    foregroundBackend = _FakeForegroundBackend();
    foregroundService = ForegroundServiceController(
      platform: FakePlatformInfo(isAndroid: true, isIOS: false),
      throttler: _InstantThrottler(),
      backend: foregroundBackend,
    );

    bridge = StopwatchOsBridge(
      wakelock: wakelock,
      foregroundService: foregroundService,
    );

    snapshotCtrl = StreamController<StopwatchSnapshot>.broadcast();
    bridge.attach(snapshotCtrl.stream);
  });

  tearDown(() {
    snapshotCtrl.close();
  });

  // ---------------------------------------------------------------------------
  // Wakelock
  // ---------------------------------------------------------------------------
  group('StopwatchOsBridge — wakelock', () {
    test('running snapshot → wakelock.enable called once', () async {
      snapshotCtrl.add(_snapshot(StopwatchState.running));
      await Future<void>.delayed(Duration.zero);

      expect(wakelockBackend.enableCalls, 1);
    });

    test('second running snapshot → wakelock.enable NOT called again (_wakelockActive guard)',
        () async {
      snapshotCtrl.add(_snapshot(StopwatchState.running));
      await Future<void>.delayed(Duration.zero);
      final countAfterFirst = wakelockBackend.enableCalls;

      snapshotCtrl.add(_snapshot(StopwatchState.running));
      await Future<void>.delayed(Duration.zero);

      expect(wakelockBackend.enableCalls, countAfterFirst); // no extra call
    });

    test('paused snapshot after running → wakelock.disable called', () async {
      snapshotCtrl.add(_snapshot(StopwatchState.running));
      await Future<void>.delayed(Duration.zero);

      snapshotCtrl.add(_snapshot(StopwatchState.paused));
      await Future<void>.delayed(Duration.zero);

      expect(wakelockBackend.disableCalls, 1);
    });

    test('paused snapshot when never running → wakelock.disable NOT called', () async {
      snapshotCtrl.add(_snapshot(StopwatchState.paused));
      await Future<void>.delayed(Duration.zero);

      expect(wakelockBackend.disableCalls, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // Foreground service start / update ordering
  // ---------------------------------------------------------------------------
  group('StopwatchOsBridge — foreground service start/update ordering', () {
    test('first running snapshot → start() called once, updateNotification() not called',
        () async {
      snapshotCtrl.add(_snapshot(StopwatchState.running));
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.startCalls, 1);
      expect(foregroundBackend.updateCalls, 0);
    });

    test('second running snapshot → start() not called again, updateNotification() called',
        () async {
      snapshotCtrl.add(_snapshot(StopwatchState.running));
      await Future<void>.delayed(Duration.zero);
      expect(foregroundBackend.startCalls, 1);

      snapshotCtrl.add(_snapshot(StopwatchState.running, elapsedMs: 6000));
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.startCalls, 1); // not called again
      expect(foregroundBackend.updateCalls, 1);
    });

    test('notification content on first running snapshot starts with "Stopwatch — "', () async {
      snapshotCtrl.add(_snapshot(StopwatchState.running, elapsedMs: 5000));
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.lastContent, startsWith('Stopwatch — '));
    });

    test('notification content on update reflects elapsed time', () async {
      snapshotCtrl.add(_snapshot(StopwatchState.running, elapsedMs: 5000));
      await Future<void>.delayed(Duration.zero);

      snapshotCtrl.add(_snapshot(StopwatchState.running, elapsedMs: 10000));
      await Future<void>.delayed(Duration.zero);

      // 10 000 ms = 10 s = "00:10"
      expect(foregroundBackend.lastContent, 'Stopwatch — 00:10');
    });
  });

  // ---------------------------------------------------------------------------
  // Running → paused transition
  // ---------------------------------------------------------------------------
  group('StopwatchOsBridge — running → paused transition', () {
    test('running → paused → updateNotification with "Paused — " prefix', () async {
      snapshotCtrl.add(_snapshot(StopwatchState.running, elapsedMs: 5000));
      await Future<void>.delayed(Duration.zero);

      snapshotCtrl.add(_snapshot(StopwatchState.paused));
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.updateCalls, greaterThanOrEqualTo(1));
      expect(foregroundBackend.lastContent, startsWith('Paused — '));
    });

    test('paused content contains the last elapsed from running', () async {
      snapshotCtrl.add(_snapshot(StopwatchState.running, elapsedMs: 65000)); // 1m 5s
      await Future<void>.delayed(Duration.zero);

      snapshotCtrl.add(_snapshot(StopwatchState.paused));
      await Future<void>.delayed(Duration.zero);

      // 65 000 ms = 1 min 5 s = "01:05"
      expect(foregroundBackend.lastContent, 'Paused — 01:05');
    });

    test('idle → paused (no prior running) → no updateNotification for Paused', () async {
      // paused snapshot without a prior running one: prev is null
      snapshotCtrl.add(_snapshot(StopwatchState.paused));
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.updateCalls, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // Detach
  // ---------------------------------------------------------------------------
  group('StopwatchOsBridge — detach', () {
    test('detach() — further snapshots do not trigger wakelock', () async {
      bridge.detach();

      snapshotCtrl.add(_snapshot(StopwatchState.running));
      await Future<void>.delayed(Duration.zero);

      expect(wakelockBackend.enableCalls, 0);
    });

    test('detach() — further snapshots do not trigger foreground service', () async {
      bridge.detach();

      snapshotCtrl.add(_snapshot(StopwatchState.running));
      await Future<void>.delayed(Duration.zero);

      expect(foregroundBackend.startCalls, 0);
      expect(foregroundBackend.updateCalls, 0);
    });

    test('detach() disables wakelock if it was active', () async {
      snapshotCtrl.add(_snapshot(StopwatchState.running));
      await Future<void>.delayed(Duration.zero);
      expect(wakelockBackend.enableCalls, 1);

      bridge.detach();
      expect(wakelockBackend.disableCalls, 1);
    });

    test('detach() when service started → stop() called once', () async {
      snapshotCtrl.add(_snapshot(StopwatchState.running));
      await Future<void>.delayed(Duration.zero);
      expect(foregroundBackend.startCalls, 1);

      bridge.detach();
      expect(foregroundBackend.stopCalls, 1);
    });

    test('detach() when service NOT started → stop() not called', () async {
      bridge.detach();
      expect(foregroundBackend.stopCalls, 0);
    });

    test('detach() resets state so re-attach starts fresh', () async {
      // First cycle: start service.
      snapshotCtrl.add(_snapshot(StopwatchState.running));
      await Future<void>.delayed(Duration.zero);
      expect(foregroundBackend.startCalls, 1);

      bridge.detach();

      // Second cycle with a new stream.
      final snap2 = StreamController<StopwatchSnapshot>.broadcast();
      bridge.attach(snap2.stream);

      snap2.add(_snapshot(StopwatchState.running));
      await Future<void>.delayed(Duration.zero);

      // start() must be called again for the new cycle.
      expect(foregroundBackend.startCalls, 2);
      expect(foregroundBackend.updateCalls, 0);

      snap2.close();
    });

    test('attach() cancels prior subscription before re-attaching', () async {
      final snap2 = StreamController<StopwatchSnapshot>.broadcast();
      bridge.attach(snap2.stream);

      // Old controller's snapshots should not trigger any calls.
      snapshotCtrl.add(_snapshot(StopwatchState.running));
      await Future<void>.delayed(Duration.zero);
      expect(wakelockBackend.enableCalls, 0);

      // New controller works.
      snap2.add(_snapshot(StopwatchState.running));
      await Future<void>.delayed(Duration.zero);
      expect(wakelockBackend.enableCalls, 1);

      snap2.close();
    });
  });

  // ---------------------------------------------------------------------------
  // iOS: foreground service is a no-op
  // ---------------------------------------------------------------------------
  group('StopwatchOsBridge — iOS platform', () {
    test('iOS platform + running snapshot → no start or update calls', () async {
      final iosForegroundBackend = _FakeForegroundBackend();
      final iosForegroundService = ForegroundServiceController(
        platform: FakePlatformInfo(isAndroid: false, isIOS: true),
        throttler: _InstantThrottler(),
        backend: iosForegroundBackend,
      );
      final iosBridge = StopwatchOsBridge(
        wakelock: wakelock,
        foregroundService: iosForegroundService,
      );

      final snapIos = StreamController<StopwatchSnapshot>.broadcast();
      iosBridge.attach(snapIos.stream);

      snapIos.add(_snapshot(StopwatchState.running));
      await Future<void>.delayed(Duration.zero);

      expect(iosForegroundBackend.startCalls, 0);
      expect(iosForegroundBackend.updateCalls, 0);

      iosBridge.detach();
      snapIos.close();
    });
  });
}
