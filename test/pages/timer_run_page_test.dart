// T5 — TimerRunPage
//
// DEVIATION: Full integration test (TimerEngine + FeedbackController +
// TimerOsBridge in widget tests) is intractable in a headless test environment
// because TimerOsBridge and FeedbackController depend on platform channels
// (vibration, TTS, wakelock, foreground service) which are not available in
// flutter_test.
//
// Strategy: We test the engine logic through unit tests of TimerEngineNotifier
// (verifying start/togglePlayPause/RoutineCompleted) and test page scaffolding
// (entry, loading states) through widget tests with mocked providers.
//
// The gesture/navigation behavior that requires platform channels is covered
// by manual T8/T9 verification on device.

import 'package:fitness_timer/models/exercise_item.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/providers/timer_engine_provider.dart';
import 'package:fitness_timer/services/timer/timer_event.dart';
import 'package:fitness_timer/services/timer/timer_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T5 — TimerEngineNotifier (TimerRunPage backing logic)', () {
    final routine = Routine(
      id: 'r1',
      title: 'Test',
      prepTime: 0,
      cooldownTime: 0,
      totalCycles: 1,
    );
    final item = ExerciseItem(
      id: 'i1',
      routineId: 'r1',
      orderIndex: 0,
      type: ExerciseType.WORK_TIME,
      duration: 2, // 2 seconds so test completes quickly
      name: 'Push-up',
    );

    RoutineWithItems data() =>
        RoutineWithItems(routine: routine, items: [item]);

    test('T5.1 engine.start() transitions engine current state to running',
        () async {
      final notifier = TimerEngineNotifier(data());
      expect(notifier.engine.current.state, TimerState.idle);
      notifier.start();
      // Allow the snapshot stream to propagate (one microtask cycle).
      await Future.microtask(() {});
      expect(notifier.engine.current.state, TimerState.running);
      notifier.dispose();
    });

    test('T5.2 togglePlayPause() pauses a running engine', () async {
      final notifier = TimerEngineNotifier(data());
      notifier.start();
      await Future.microtask(() {});
      expect(notifier.engine.current.state, TimerState.running);
      notifier.togglePlayPause();
      await Future.microtask(() {});
      expect(notifier.engine.current.state, TimerState.paused);
      notifier.dispose();
    });

    test('T5.3 togglePlayPause() resumes a paused engine', () async {
      final notifier = TimerEngineNotifier(data());
      notifier.start();
      await Future.microtask(() {});
      notifier.togglePlayPause(); // pause
      await Future.microtask(() {});
      notifier.togglePlayPause(); // resume
      await Future.microtask(() {});
      expect(notifier.engine.current.state, TimerState.running);
      notifier.dispose();
    });

    test('T5.4 RoutineCompleted event is emitted after all phases complete',
        () async {
      final notifier = TimerEngineNotifier(data());
      final events = <TimerEvent>[];
      final sub = notifier.engine.events.listen(events.add);

      notifier.start();

      // Wait for the routine to complete (item duration = 2s, poll at 3s max)
      for (var i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (events.any((e) => e is RoutineCompleted)) break;
      }

      expect(events.any((e) => e is RoutineCompleted), isTrue);

      await sub.cancel();
      notifier.dispose();
    });

    test('T5.5 reset() returns engine to idle state', () {
      final notifier = TimerEngineNotifier(data());
      notifier.start();
      notifier.reset();
      expect(notifier.state.state, TimerState.idle);
      notifier.dispose();
    });

    test('T5.6 engine events stream emits PhaseStarted on start', () async {
      final notifier = TimerEngineNotifier(data());
      final events = <TimerEvent>[];
      final sub = notifier.engine.events.listen(events.add);

      notifier.start();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(events.any((e) => e is PhaseStarted), isTrue);

      await sub.cancel();
      notifier.dispose();
    });
  });
}
