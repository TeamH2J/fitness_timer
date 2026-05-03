import 'package:fake_async/fake_async.dart';
import 'package:fitness_timer/models/exercise_item.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/services/timer/clock.dart';
import 'package:fitness_timer/services/timer/timer_engine.dart';
import 'package:fitness_timer/services/timer/timer_event.dart';
import 'package:fitness_timer/services/timer/timer_state.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Routine _routine({
  int prepTime = 0,
  int cooldownTime = 0,
  int totalCycles = 1,
}) =>
    Routine(
      id: 'r1',
      title: 'Test',
      prepTime: prepTime,
      cooldownTime: cooldownTime,
      totalCycles: totalCycles,
    );

ExerciseItem _workItem({
  int duration = 10,
  int orderIndex = 0,
  String id = 'e1',
}) =>
    ExerciseItem(
      id: id,
      routineId: 'r1',
      orderIndex: orderIndex,
      type: ExerciseType.WORK_TIME,
      duration: duration,
      name: 'Push-up',
    );

ExerciseItem _workRepsItem({
  int duration = 30,
  int targetReps = 10,
  int orderIndex = 0,
}) =>
    ExerciseItem(
      id: 'e_reps',
      routineId: 'r1',
      orderIndex: orderIndex,
      type: ExerciseType.WORK_REPS,
      duration: duration,
      targetReps: targetReps,
      name: 'Squat',
    );

ExerciseItem _restItem({
  int duration = 5,
  int orderIndex = 1,
  String id = 'e_rest',
}) =>
    ExerciseItem(
      id: id,
      routineId: 'r1',
      orderIndex: orderIndex,
      type: ExerciseType.REST,
      duration: duration,
      name: 'Rest',
    );

// Advance both fakeAsync and FakeClock together in 250ms steps so that
// the FakeClock is in sync when Timer.periodic fires its callbacks.
void advance(FakeAsync async, FakeClock clock, Duration total) {
  const step = Duration(milliseconds: 250);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    final remaining = total - elapsed;
    final next = remaining < step ? remaining : step;
    clock.advance(next);
    async.elapse(next);
    elapsed += next;
  }
}

// ---------------------------------------------------------------------------
// T1 — Drift-free 5 s background simulation
// ---------------------------------------------------------------------------

void main() {
  group('T1 — Drift-free 5s simulation', () {
    test('prepTime=10s routine; advance 5s → remainingMs ≈ 5000 (±50)', () {
      fakeAsync((async) {
        final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(0));
        final engine = TimerEngine(
          routine: _routine(prepTime: 10),
          items: [],
          clock: clock,
        );

        TimerSnapshot? lastSnapshot;
        engine.snapshots.listen((s) => lastSnapshot = s);

        engine.start();
        async.flushMicrotasks();

        // Advance 5 seconds — 10s prep phase, so 5s remaining
        advance(async, clock, const Duration(seconds: 5));

        expect(lastSnapshot, isNotNull);
        expect(lastSnapshot!.remainingMs, closeTo(5000, 50));
        expect(lastSnapshot!.state, TimerState.running);
        expect(lastSnapshot!.phase, TimerPhase.prep);

        engine.dispose();
      });
    });
  });

  // -------------------------------------------------------------------------
  // T2 — Pause/Resume preserves remaining time
  // -------------------------------------------------------------------------

  group('T2 — Pause/Resume', () {
    test('10s phase; advance 3s; pause; advance 5min; resume; advance 4s → remaining ≈ 3000', () {
      fakeAsync((async) {
        final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(0));
        final engine = TimerEngine(
          routine: _routine(),
          items: [_workItem(duration: 10)],
          clock: clock,
        );

        TimerSnapshot? lastSnapshot;
        engine.snapshots.listen((s) => lastSnapshot = s);

        engine.start();
        async.flushMicrotasks();

        // Advance 3 s → 7s remaining
        advance(async, clock, const Duration(seconds: 3));
        expect(engine.current.state, TimerState.running);

        engine.pause();
        expect(engine.current.state, TimerState.paused);

        // While paused, only advance fakeAsync time (not the FakeClock),
        // because the engine is paused — the wall clock doesn't matter.
        async.elapse(const Duration(minutes: 5));
        expect(engine.current.state, TimerState.paused);

        engine.resume();
        // After resume: _targetAt = clock.now() + remainingAtPause (≈7000ms)
        expect(engine.current.state, TimerState.running);

        // Advance 4 more seconds → 7 - 4 = 3s remaining
        advance(async, clock, const Duration(seconds: 4));

        expect(lastSnapshot, isNotNull);
        expect(lastSnapshot!.remainingMs, closeTo(3000, 50));
        expect(lastSnapshot!.state, TimerState.running);

        engine.dispose();
      });
    });
  });

  // -------------------------------------------------------------------------
  // T3 — Reps mode metadata in PhaseStarted event
  // -------------------------------------------------------------------------

  group('T3 — Reps mode metadata', () {
    test('WORK_REPS item → first PhaseStarted.targetReps == item.targetReps', () {
      fakeAsync((async) {
        final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(0));
        final item = _workRepsItem(targetReps: 15);
        final engine = TimerEngine(
          routine: _routine(),
          items: [item],
          clock: clock,
        );

        final events = <TimerEvent>[];
        engine.events.listen(events.add);

        engine.start();
        async.flushMicrotasks();

        final phaseStarted = events.whereType<PhaseStarted>().firstOrNull;
        expect(phaseStarted, isNotNull);
        expect(phaseStarted!.targetReps, 15);
        expect(phaseStarted.phase, TimerPhase.work);

        engine.dispose();
      });
    });
  });

  // -------------------------------------------------------------------------
  // T4 — Phase sequence order
  // -------------------------------------------------------------------------

  group('T4 — Phase sequence order', () {
    test('prep + work + rest + cooldown → PhaseStarted events in correct order', () {
      fakeAsync((async) {
        final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(0));
        final engine = TimerEngine(
          routine: _routine(prepTime: 5, cooldownTime: 3),
          items: [
            _workItem(duration: 10, orderIndex: 0),
            _restItem(duration: 5, orderIndex: 1),
          ],
          clock: clock,
        );

        final events = <TimerEvent>[];
        engine.events.listen(events.add);

        engine.start();
        async.flushMicrotasks();

        // Advance through all phases: prep(5s) + work(10s) + rest(5s) + cooldown(3s)
        advance(async, clock, const Duration(seconds: 5));   // end prep
        advance(async, clock, const Duration(seconds: 10));  // end work
        advance(async, clock, const Duration(seconds: 5));   // end rest
        advance(async, clock, const Duration(seconds: 3));   // end cooldown

        final started = events.whereType<PhaseStarted>().toList();
        expect(started.length, greaterThanOrEqualTo(4));
        expect(started[0].phase, TimerPhase.prep);
        expect(started[1].phase, TimerPhase.work);
        expect(started[2].phase, TimerPhase.rest);
        expect(started[3].phase, TimerPhase.cooldown);

        engine.dispose();
      });
    });
  });

  // -------------------------------------------------------------------------
  // T5 — PhaseEndingSoon fires exactly once
  // -------------------------------------------------------------------------

  group('T5 — PhaseEndingSoon fires exactly once', () {
    test('10s phase; advance 7s → exactly 1 PhaseEndingSoon; advance more → still 1', () {
      fakeAsync((async) {
        final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(0));
        final engine = TimerEngine(
          routine: _routine(),
          items: [_workItem(duration: 10)],
          clock: clock,
        );

        final events = <TimerEvent>[];
        engine.events.listen(events.add);

        engine.start();
        async.flushMicrotasks();

        // At 7s elapsed: 3s remaining — within the PhaseEndingSoon window
        // (remainingMs <= 3000 && remainingMs > 2750)
        // The tick at exactly 7000ms sees remainingMs = 3000, which is in window.
        advance(async, clock, const Duration(seconds: 7));

        final endingSoonCount1 = events.whereType<PhaseEndingSoon>().length;
        expect(endingSoonCount1, 1);

        // Advance a bit more — should not emit another PhaseEndingSoon
        advance(async, clock, const Duration(milliseconds: 100));

        final endingSoonCount2 = events.whereType<PhaseEndingSoon>().length;
        expect(endingSoonCount2, 1);

        engine.dispose();
      });
    });
  });

  // -------------------------------------------------------------------------
  // T6 — totalCycles repetition
  // -------------------------------------------------------------------------

  group('T6 — totalCycles repetition', () {
    test('cycles=3, items=[work, rest] → 6 PhaseStarted events for work/rest', () {
      fakeAsync((async) {
        final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(0));
        final engine = TimerEngine(
          routine: _routine(totalCycles: 3),
          items: [
            _workItem(duration: 5, orderIndex: 0, id: 'w1'),
            _restItem(duration: 3, orderIndex: 1, id: 'r1'),
          ],
          clock: clock,
        );

        final events = <TimerEvent>[];
        engine.events.listen(events.add);

        engine.start();
        async.flushMicrotasks();

        // 3 cycles × (5s work + 3s rest) = 24 seconds total
        advance(async, clock, const Duration(seconds: 5));  // work cycle 1
        advance(async, clock, const Duration(seconds: 3));  // rest cycle 1
        advance(async, clock, const Duration(seconds: 5));  // work cycle 2
        advance(async, clock, const Duration(seconds: 3));  // rest cycle 2
        advance(async, clock, const Duration(seconds: 5));  // work cycle 3
        advance(async, clock, const Duration(seconds: 3));  // rest cycle 3

        final started = events.whereType<PhaseStarted>().toList();
        final workEvents =
            started.where((e) => e.phase == TimerPhase.work).toList();
        final restEvents =
            started.where((e) => e.phase == TimerPhase.rest).toList();

        expect(workEvents.length, 3);
        expect(restEvents.length, 3);

        // Verify interleaved order: work, rest, work, rest, work, rest
        final workRestEvents = started
            .where((e) =>
                e.phase == TimerPhase.work || e.phase == TimerPhase.rest)
            .toList();
        expect(workRestEvents.length, 6);
        for (var i = 0; i < workRestEvents.length; i++) {
          if (i.isEven) {
            expect(workRestEvents[i].phase, TimerPhase.work);
          } else {
            expect(workRestEvents[i].phase, TimerPhase.rest);
          }
        }

        engine.dispose();
      });
    });
  });

  // -------------------------------------------------------------------------
  // T7 — RoutineCompleted at end
  // -------------------------------------------------------------------------

  group('T7 — RoutineCompleted at end', () {
    test('complete all phases → state == completed + RoutineCompleted emitted once', () {
      fakeAsync((async) {
        final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(0));
        final engine = TimerEngine(
          routine: _routine(),
          items: [_workItem(duration: 5)],
          clock: clock,
        );

        final events = <TimerEvent>[];
        engine.snapshots.listen((_) {});
        engine.events.listen(events.add);

        engine.start();
        async.flushMicrotasks();

        // Advance 5s to complete the single work phase
        advance(async, clock, const Duration(seconds: 5));

        expect(engine.current.state, TimerState.completed);
        final completedEvents = events.whereType<RoutineCompleted>().length;
        expect(completedEvents, 1);

        engine.dispose();
      });
    });
  });

  // -------------------------------------------------------------------------
  // T8 — reset() from any state → idle
  // -------------------------------------------------------------------------

  group('T8 — reset() from any state', () {
    test('reset from running → idle', () {
      fakeAsync((async) {
        final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(0));
        final engine = TimerEngine(
          routine: _routine(),
          items: [_workItem(duration: 10)],
          clock: clock,
        );
        engine.snapshots.listen((_) {});

        engine.start();
        async.flushMicrotasks();
        expect(engine.current.state, TimerState.running);

        engine.reset();

        expect(engine.current.state, TimerState.idle);
        expect(engine.current.remainingMs, 0);
        expect(engine.current.phase, isNull);

        engine.dispose();
      });
    });

    test('reset from paused → idle', () {
      fakeAsync((async) {
        final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(0));
        final engine = TimerEngine(
          routine: _routine(),
          items: [_workItem(duration: 10)],
          clock: clock,
        );
        engine.snapshots.listen((_) {});

        engine.start();
        async.flushMicrotasks();
        engine.pause();
        expect(engine.current.state, TimerState.paused);

        engine.reset();

        expect(engine.current.state, TimerState.idle);
        expect(engine.current.remainingMs, 0);
        expect(engine.current.phase, isNull);

        engine.dispose();
      });
    });

    test('reset from completed → idle', () {
      fakeAsync((async) {
        final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(0));
        final engine = TimerEngine(
          routine: _routine(),
          items: [_workItem(duration: 5)],
          clock: clock,
        );
        engine.snapshots.listen((_) {});
        engine.events.listen((_) {});

        engine.start();
        async.flushMicrotasks();

        // Advance 5s to complete the routine
        advance(async, clock, const Duration(seconds: 5));
        expect(engine.current.state, TimerState.completed);

        engine.reset();

        expect(engine.current.state, TimerState.idle);
        expect(engine.current.remainingMs, 0);
        expect(engine.current.phase, isNull);

        engine.dispose();
      });
    });
  });

  // -------------------------------------------------------------------------
  // Additional: Empty queue completes immediately
  // -------------------------------------------------------------------------

  group('Edge case — empty phase queue', () {
    test('no prep, no items, no cooldown → RoutineCompleted emitted, state == completed', () {
      fakeAsync((async) {
        final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(0));
        final engine = TimerEngine(
          routine: _routine(),
          items: [],
          clock: clock,
        );

        final events = <TimerEvent>[];
        engine.snapshots.listen((_) {});
        engine.events.listen(events.add);

        engine.start();
        async.flushMicrotasks();

        expect(engine.current.state, TimerState.completed);
        expect(events.whereType<RoutineCompleted>().length, 1);

        engine.dispose();
      });
    });
  });

  // -------------------------------------------------------------------------
  // Additional: start() from non-idle throws StateError
  // -------------------------------------------------------------------------

  group('Edge case — start() from non-idle', () {
    test('start() from running throws StateError', () {
      fakeAsync((async) {
        final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(0));
        final engine = TimerEngine(
          routine: _routine(),
          items: [_workItem()],
          clock: clock,
        );
        engine.snapshots.listen((_) {});

        engine.start();
        async.flushMicrotasks();

        expect(() => engine.start(), throwsStateError);

        engine.dispose();
      });
    });
  });

  // -------------------------------------------------------------------------
  // Additional: togglePlayPause
  // -------------------------------------------------------------------------

  group('togglePlayPause', () {
    test('running → paused → running via toggle', () {
      fakeAsync((async) {
        final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(0));
        final engine = TimerEngine(
          routine: _routine(),
          items: [_workItem()],
          clock: clock,
        );
        engine.snapshots.listen((_) {});

        engine.start();
        async.flushMicrotasks();
        expect(engine.current.state, TimerState.running);

        engine.togglePlayPause();
        expect(engine.current.state, TimerState.paused);

        engine.togglePlayPause();
        expect(engine.current.state, TimerState.running);

        engine.dispose();
      });
    });
  });

  // -------------------------------------------------------------------------
  // Clock tests
  // -------------------------------------------------------------------------

  group('FakeClock', () {
    test('advance moves time forward', () {
      final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(1000));
      clock.advance(const Duration(seconds: 5));
      expect(clock.now().millisecondsSinceEpoch, 6000);
    });

    test('setNow sets time directly', () {
      final clock = FakeClock(DateTime.fromMillisecondsSinceEpoch(0));
      clock.setNow(DateTime.fromMillisecondsSinceEpoch(9000));
      expect(clock.now().millisecondsSinceEpoch, 9000);
    });
  });

  // -------------------------------------------------------------------------
  // TimerSnapshot tests
  // -------------------------------------------------------------------------

  group('TimerSnapshot', () {
    test('idle snapshot has correct defaults', () {
      expect(TimerSnapshot.idle.state, TimerState.idle);
      expect(TimerSnapshot.idle.phase, isNull);
      expect(TimerSnapshot.idle.remainingMs, 0);
      expect(TimerSnapshot.idle.totalMs, 0);
      expect(TimerSnapshot.idle.currentCycle, 0);
    });

    test('copyWith replaces fields', () {
      const base = TimerSnapshot(
        state: TimerState.idle,
        remainingMs: 5000,
        totalMs: 10000,
        currentCycle: 1,
      );
      final updated =
          base.copyWith(state: TimerState.running, remainingMs: 4000);
      expect(updated.state, TimerState.running);
      expect(updated.remainingMs, 4000);
      expect(updated.totalMs, 10000);
      expect(updated.currentCycle, 1);
    });

    test('copyWith clearPhase sets phase to null', () {
      const snap = TimerSnapshot(
        state: TimerState.running,
        phase: TimerPhase.work,
        remainingMs: 5000,
        totalMs: 10000,
      );
      final cleared = snap.copyWith(clearPhase: true);
      expect(cleared.phase, isNull);
    });
  });
}
