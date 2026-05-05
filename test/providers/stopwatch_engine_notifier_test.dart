/// Integration tests: StopwatchEngineNotifier + DatabaseService.
///
/// Covers TRD §7 integration test cases:
///   - Start → lap × 2 → stop → reset → verify session with 2 laps saved.
///   - reset() when elapsedMs == 0 → verify no session inserted.
library;

import 'package:fitness_timer/models/stopwatch_session.dart';
import 'package:fitness_timer/providers/database_provider.dart';
import 'package:fitness_timer/providers/stopwatch_provider.dart';
import 'package:fitness_timer/services/database_service.dart';
import 'package:fitness_timer/services/os/foreground_service_controller.dart';
import 'package:fitness_timer/services/os/notification_throttler.dart';
import 'package:fitness_timer/services/os/platform_info.dart';
import 'package:fitness_timer/services/os/stopwatch_os_bridge.dart';
import 'package:fitness_timer/services/os/wakelock_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _NoOpWakelockBackend implements WakelockBackend {
  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}

  @override
  Future<bool> isEnabled() async => false;
}

class _NoOpForegroundBackend implements ForegroundBackend {
  @override
  Future<void> startService(
      {required String notificationTitle,
      required String notificationText}) async {}

  @override
  Future<void> updateService(
      {required String notificationTitle,
      required String notificationText}) async {}

  @override
  Future<void> stopService() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _uuid = Uuid();

/// Creates a real in-memory [DatabaseService] (unique URI per call).
DatabaseService _freshDb() =>
    DatabaseService(dbPath: 'file:${_uuid.v4()}?mode=memory&cache=shared');

/// Creates a [StopwatchOsBridge] backed entirely by no-op stubs.
StopwatchOsBridge _noOpBridge() {
  final wakelock = WakelockManager(backend: _NoOpWakelockBackend());
  final foregroundService = ForegroundServiceController(
    platform: FakePlatformInfo(isAndroid: false, isIOS: false),
    throttler: NotificationThrottler(),
    backend: _NoOpForegroundBackend(),
  );
  return StopwatchOsBridge(
    wakelock: wakelock,
    foregroundService: foregroundService,
  );
}

/// Builds a [ProviderContainer] that overrides the database and OS bridge
/// providers with the given instances, so [StopwatchEngineNotifier] gets
/// injected dependencies without touching platform channels.
ProviderContainer _buildContainer({
  required DatabaseService db,
  required StopwatchOsBridge bridge,
}) {
  return ProviderContainer(
    overrides: [
      databaseServiceProvider.overrideWithValue(db),
      stopwatchOsBridgeProvider.overrideWithValue(bridge),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('StopwatchEngineNotifier + DatabaseService integration', () {
    test(
        'Start → lap × 2 → stop → reset: session with 2 laps is persisted',
        () async {
      final db = _freshDb();
      final bridge = _noOpBridge();
      final container = _buildContainer(db: db, bridge: bridge);
      addTearDown(container.dispose);

      final notifier = container.read(stopwatchEngineProvider.notifier);

      // Start the stopwatch.
      notifier.start();

      // Let two ticks fire so elapsedMs is non-zero before each lap.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      notifier.lap();

      await Future<void>.delayed(const Duration(milliseconds: 150));
      notifier.lap();

      // Stop and reset to trigger DB persistence.
      notifier.stop();
      await notifier.reset();

      // Verify the session was persisted with 2 laps.
      final sessions = await db.getStopwatchSessions();
      expect(sessions.length, 1);

      final session = sessions.first;
      expect(session.totalMs, greaterThan(0));
      expect(session.laps.length, 2);
      expect(session.laps[0].number, 1);
      expect(session.laps[1].number, 2);
      // Each lap's lapMs should be positive.
      expect(session.laps[0].lapMs, greaterThan(0));
      expect(session.laps[1].lapMs, greaterThan(0));
    });

    test(
        'reset() when elapsedMs == 0 (never started): no session inserted',
        () async {
      final db = _freshDb();
      final bridge = _noOpBridge();
      final container = _buildContainer(db: db, bridge: bridge);
      addTearDown(container.dispose);

      final notifier = container.read(stopwatchEngineProvider.notifier);

      // Immediately reset without ever starting.
      await notifier.reset();

      final sessions = await db.getStopwatchSessions();
      expect(sessions.isEmpty, isTrue);
    });

    test(
        'engine state is idle and elapsedMs == 0 after reset',
        () async {
      final db = _freshDb();
      final bridge = _noOpBridge();
      final container = _buildContainer(db: db, bridge: bridge);
      addTearDown(container.dispose);

      final notifier = container.read(stopwatchEngineProvider.notifier);

      notifier.start();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      notifier.stop();
      await notifier.reset();

      final snap = container.read(stopwatchEngineProvider);
      expect(snap.state, StopwatchState.idle);
      expect(snap.elapsedMs, 0);
      expect(snap.laps, isEmpty);
    });

    test(
        'Start → stop → reset: session with 0 laps is persisted when elapsedMs > 0',
        () async {
      final db = _freshDb();
      final bridge = _noOpBridge();
      final container = _buildContainer(db: db, bridge: bridge);
      addTearDown(container.dispose);

      final notifier = container.read(stopwatchEngineProvider.notifier);

      notifier.start();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      notifier.stop();
      await notifier.reset();

      final sessions = await db.getStopwatchSessions();
      expect(sessions.length, 1);
      expect(sessions.first.laps.isEmpty, isTrue);
      expect(sessions.first.totalMs, greaterThan(0));
    });
  });
}
