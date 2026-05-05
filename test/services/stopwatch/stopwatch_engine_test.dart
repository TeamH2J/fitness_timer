import 'package:fitness_timer/models/stopwatch_session.dart';
import 'package:fitness_timer/services/stopwatch/stopwatch_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StopwatchEngine', () {
    late StopwatchEngine engine;

    setUp(() {
      engine = StopwatchEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    // -------------------------------------------------------------------------
    // start() from idle
    // -------------------------------------------------------------------------
    test('start() from idle: state becomes running', () async {
      engine.start();
      expect(engine.current.state, StopwatchState.running);
    });

    test('start() from idle: elapsedMs grows over time', () async {
      engine.start();
      // Let the real ticker fire at least once.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(engine.current.elapsedMs, greaterThan(0));
    });

    test('start() from idle: snapshots emitted on stream', () async {
      final snapshots = <StopwatchSnapshot>[];
      final sub = engine.snapshots.listen(snapshots.add);
      engine.start();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      sub.cancel();
      expect(snapshots.length, greaterThan(0));
    });

    test('start() when already running throws StateError', () {
      engine.start();
      expect(() => engine.start(), throwsStateError);
    });

    // -------------------------------------------------------------------------
    // stop() while running
    // -------------------------------------------------------------------------
    test('stop() while running: state becomes paused', () async {
      engine.start();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      engine.stop();
      expect(engine.current.state, StopwatchState.paused);
    });

    test('stop() while running: elapsedMs is frozen after stop', () async {
      engine.start();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      engine.stop();
      final elapsedAtStop = engine.current.elapsedMs;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(engine.current.elapsedMs, elapsedAtStop);
    });

    test('stop() when not running: no-op, state unchanged', () {
      expect(engine.current.state, StopwatchState.idle);
      engine.stop(); // no-op
      expect(engine.current.state, StopwatchState.idle);
    });

    // -------------------------------------------------------------------------
    // start() from paused (resume)
    // -------------------------------------------------------------------------
    test('resume from paused: elapsed continues from frozen value', () async {
      engine.start();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      engine.stop();
      final elapsedAtStop = engine.current.elapsedMs;
      expect(elapsedAtStop, greaterThan(0));

      engine.start();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final elapsedAfterResume = engine.current.elapsedMs;

      expect(engine.current.state, StopwatchState.running);
      expect(elapsedAfterResume, greaterThan(elapsedAtStop));
    });

    // -------------------------------------------------------------------------
    // lap()
    // -------------------------------------------------------------------------
    test('lap() while running: laps list grows by 1', () async {
      engine.start();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      engine.lap();
      expect(engine.current.laps.length, 1);
    });

    test('lap() while running: currentLapMs resets to ~0 after lap', () async {
      engine.start();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      engine.lap();
      // currentLapMs should be near 0 right after lap
      expect(engine.current.currentLapMs, lessThan(50));
    });

    test('lap() while running: lapMs is positive and close to elapsed', () async {
      engine.start();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      engine.lap();
      final recorded = engine.current.laps.first.lapMs;
      // lapMs should reflect ~200ms of elapsed time; allow wide tolerance for CI.
      expect(recorded, greaterThan(0));
      expect(recorded, lessThan(1000));
    });

    test('lap() while paused: no-op', () async {
      engine.start();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      engine.stop();
      engine.lap();
      expect(engine.current.laps.isEmpty, isTrue);
    });

    test('lap() while idle: no-op', () {
      engine.lap();
      expect(engine.current.laps.isEmpty, isTrue);
    });

    test('lap number sequence: multiple laps have numbers 1, 2, 3', () async {
      engine.start();
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        engine.lap();
      }
      final laps = engine.current.laps;
      expect(laps.length, 3);
      expect(laps[0].number, 1);
      expect(laps[1].number, 2);
      expect(laps[2].number, 3);
    });

    // -------------------------------------------------------------------------
    // reset()
    // -------------------------------------------------------------------------
    test('reset() after stop with elapsed > 0: returns StopwatchSession', () async {
      engine.start();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      engine.stop();
      final session = engine.reset();
      expect(session, isNotNull);
      expect(session!.totalMs, greaterThan(0));
      expect(session.id, isNotEmpty);
    });

    test('reset() after stop: engine state is idle', () async {
      engine.start();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      engine.stop();
      engine.reset();
      expect(engine.current.state, StopwatchState.idle);
      expect(engine.current.elapsedMs, 0);
    });

    test('reset() after stop: session has correct laps', () async {
      engine.start();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      engine.lap();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      engine.lap();
      engine.stop();
      final session = engine.reset();
      expect(session!.laps.length, 2);
      expect(session.laps[0].number, 1);
      expect(session.laps[1].number, 2);
    });

    test('reset() when elapsedMs == 0: returns null', () {
      final session = engine.reset();
      expect(session, isNull);
    });

    test('reset() when running: no-op, returns null', () async {
      engine.start();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final result = engine.reset();
      expect(result, isNull);
      expect(engine.current.state, StopwatchState.running);
    });

    // -------------------------------------------------------------------------
    // dispose()
    // -------------------------------------------------------------------------
    test('dispose(): no further snapshots emitted after dispose', () async {
      final snapshots = <StopwatchSnapshot>[];
      final sub = engine.snapshots.listen(snapshots.add);
      engine.start();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      engine.dispose();
      final countAtDispose = snapshots.length;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      sub.cancel();
      expect(snapshots.length, countAtDispose);
    });
  });
}
