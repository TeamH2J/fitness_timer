// T6 — timer-phase-color: _phaseColor branch coverage
//
// Strategy: pump TimerRunPage with ProviderScope overrides so that:
//   - databaseServiceProvider returns a FakeDatabaseService holding one routine
//   - timerEngineProvider(routineData) returns a FakeTimerEngineNotifier that
//     holds a pre-built TimerSnapshot and ignores start() calls
//   - feedbackControllerProvider and timerOsBridgeProvider return no-op stubs
//     that avoid platform channel calls (vibration, TTS, wakelock, etc.)
//
// After pump, locate the CustomPaint whose painter is a CircularProgressPainter
// and assert painter.foreground equals the expected Color for each phase.

import 'package:fitness_timer/l10n/app_localizations.dart';
import 'package:fitness_timer/models/exercise_item.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/pages/timer_run_page.dart';
import 'package:fitness_timer/providers/database_provider.dart';
import 'package:fitness_timer/providers/feedback_provider.dart';
import 'package:fitness_timer/providers/os_provider.dart';
import 'package:fitness_timer/providers/timer_engine_provider.dart';
import 'package:fitness_timer/services/feedback/audio_feedback_service.dart';
import 'package:fitness_timer/services/feedback/audio_session_configurator.dart';
import 'package:fitness_timer/services/feedback/feedback_controller.dart';
import 'package:fitness_timer/services/feedback/haptic_service.dart';
import 'package:fitness_timer/services/feedback/tts_service.dart';
import 'package:fitness_timer/services/os/foreground_service_controller.dart';
import 'package:fitness_timer/services/os/notification_throttler.dart';
import 'package:fitness_timer/services/os/platform_info.dart' show FakePlatformInfo;
import 'package:fitness_timer/services/os/timer_os_bridge.dart';
import 'package:fitness_timer/services/os/wakelock_manager.dart';
import 'package:fitness_timer/services/preferences_service.dart';
import 'package:fitness_timer/services/timer/timer_state.dart';
import 'package:fitness_timer/widgets/circular_progress_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_database_service.dart';

// ---------------------------------------------------------------------------
// Fake wakelock backend — all calls are no-ops in tests.
// ---------------------------------------------------------------------------
class FakeWakelockBackend implements WakelockBackend {
  @override
  Future<void> enable() async {}
  @override
  Future<void> disable() async {}
  @override
  Future<bool> isEnabled() async => false;
}

// ---------------------------------------------------------------------------
// Fake foreground service backend — all calls are no-ops in tests.
// ---------------------------------------------------------------------------
class FakeForegroundBackend implements ForegroundBackend {
  @override
  Future<void> startService({
    required String notificationTitle,
    required String notificationText,
  }) async {}

  @override
  Future<void> updateService({
    required String notificationTitle,
    required String notificationText,
  }) async {}

  @override
  Future<void> stopService() async {}
}


// ---------------------------------------------------------------------------
// FakeTimerEngineNotifier — holds a fixed snapshot; ignores start/pause/reset.
// ---------------------------------------------------------------------------
class FakeTimerEngineNotifier extends TimerEngineNotifier {
  FakeTimerEngineNotifier(TimerSnapshot fixedSnapshot, RoutineWithItems data)
      : super(data) {
    state = fixedSnapshot;
  }

  @override
  void start() {}
  @override
  void pause() {}
  @override
  void resume() {}
  @override
  void togglePlayPause() {}
  @override
  void reset() {}
}

// ---------------------------------------------------------------------------
// Shared test data
// ---------------------------------------------------------------------------
const _routine = Routine(
  id: 'r-color',
  title: 'Color Test Routine',
  prepTime: 5,
  cooldownTime: 5,
  totalCycles: 1,
);
const _item = ExerciseItem(
  id: 'i-color',
  routineId: 'r-color',
  orderIndex: 0,
  type: ExerciseType.WORK_TIME,
  duration: 10,
  name: 'Push-up',
);

RoutineWithItems _routineData() =>
    const RoutineWithItems(routine: _routine, items: [_item]);

// ---------------------------------------------------------------------------
// Build the test harness for a given TimerSnapshot.
// ---------------------------------------------------------------------------
Widget _buildHarness(TimerSnapshot snapshot) {
  final routineData = _routineData();

  final fakeDb = FakeDatabaseService(
    routines: [_routine],
    items: {'r-color': [_item]},
  );

  final fakeFeedback = FeedbackController(
    tts: TtsService(),
    audio: AudioFeedbackService(),
    haptic: HapticService(),
    session: AudioSessionConfigurator(),
  );

  final fakeOsBridge = TimerOsBridge(
    wakelock: WakelockManager(backend: FakeWakelockBackend()),
    foregroundService: ForegroundServiceController(
      platform: FakePlatformInfo(isAndroid: false, isIOS: false),
      throttler: NotificationThrottler(),
      backend: FakeForegroundBackend(),
    ),
  );

  final router = GoRouter(
    initialLocation: '/routine/r-color/run',
    routes: [
      GoRoute(
        path: '/routine/:id/run',
        builder: (context, state) =>
            TimerRunPage(routineId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/routine/:id/complete',
        builder: (context, state) => const Scaffold(body: Text('CompletePage')),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      databaseServiceProvider.overrideWithValue(fakeDb),
      timerEngineProvider(routineData).overrideWith(
        (ref) => FakeTimerEngineNotifier(snapshot, routineData),
      ),
      feedbackControllerProvider.overrideWithValue(fakeFeedback),
      timerOsBridgeProvider.overrideWithValue(fakeOsBridge),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

// ---------------------------------------------------------------------------
// Helper: pump harness and extract CircularProgressPainter.
// ---------------------------------------------------------------------------
Future<CircularProgressPainter> _getPainter(
    WidgetTester tester, TimerSnapshot snapshot) async {
  await tester.pumpWidget(_buildHarness(snapshot));
  // Allow FutureProvider to resolve and post-frame callbacks to fire.
  await tester.pump();
  await tester.pump();

  final elements = find.byType(CustomPaint).evaluate();
  for (final element in elements) {
    final widget = element.widget as CustomPaint;
    if (widget.painter is CircularProgressPainter) {
      return widget.painter as CircularProgressPainter;
    }
  }
  throw TestFailure('No CustomPaint with CircularProgressPainter found');
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  group('T6 — _phaseColor: ring foreground tint per phase', () {
    testWidgets('T6.1 prep phase → amber Color(0xFFFFB300)', (tester) async {
      final painter = await _getPainter(
        tester,
        const TimerSnapshot(
          state: TimerState.running,
          phase: TimerPhase.prep,
          currentCycle: 1,
          remainingMs: 5000,
          totalMs: 5000,
        ),
      );
      expect(painter.foreground, const Color(0xFFFFB300));
    });

    testWidgets('T6.2 work phase → red Color(0xFFFF5252)', (tester) async {
      final painter = await _getPainter(
        tester,
        const TimerSnapshot(
          state: TimerState.running,
          phase: TimerPhase.work,
          currentCycle: 1,
          remainingMs: 10000,
          totalMs: 10000,
        ),
      );
      expect(painter.foreground, const Color(0xFFFF5252));
    });

    testWidgets('T6.3 rest phase → green Color(0xFF4CAF50)', (tester) async {
      final painter = await _getPainter(
        tester,
        const TimerSnapshot(
          state: TimerState.running,
          phase: TimerPhase.rest,
          currentCycle: 1,
          remainingMs: 3000,
          totalMs: 3000,
        ),
      );
      expect(painter.foreground, const Color(0xFF4CAF50));
    });

    testWidgets('T6.4 cooldown phase → cyan Color(0xFF26C6DA)', (tester) async {
      final painter = await _getPainter(
        tester,
        const TimerSnapshot(
          state: TimerState.running,
          phase: TimerPhase.cooldown,
          currentCycle: 1,
          remainingMs: 5000,
          totalMs: 5000,
        ),
      );
      expect(painter.foreground, const Color(0xFF26C6DA));
    });

    testWidgets('T6.5 null phase (idle) → fallback red Color(0xFFFF5252)',
        (tester) async {
      final painter = await _getPainter(
        tester,
        const TimerSnapshot(
          state: TimerState.idle,
          phase: null,
          currentCycle: 0,
          remainingMs: 0,
          totalMs: 0,
        ),
      );
      expect(painter.foreground, const Color(0xFFFF5252));
    });
  });
}
