import 'package:fitness_timer/models/stopwatch_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  const uuid = Uuid();

  group('LapRecord', () {
    test('toMap / fromMap round-trip preserves all fields', () {
      const lap = LapRecord(number: 2, lapMs: 5300, totalMs: 12000);
      final sessionId = uuid.v4();
      final lapId = uuid.v4();
      final map = lap.toMap(sessionId: sessionId, id: lapId);

      expect(map['lap_number'], 2);
      expect(map['lap_ms'], 5300);
      expect(map['total_ms'], 12000);
      expect(map['session_id'], sessionId);
      expect(map['id'], lapId);

      final restored = LapRecord.fromMap(map);
      expect(restored, lap);
    });

    test('equality: two identical LapRecords are equal', () {
      const a = LapRecord(number: 1, lapMs: 1000, totalMs: 1000);
      const b = LapRecord(number: 1, lapMs: 1000, totalMs: 1000);
      expect(a, b);
    });

    test('equality: different fields are not equal', () {
      const a = LapRecord(number: 1, lapMs: 1000, totalMs: 1000);
      const b = LapRecord(number: 2, lapMs: 1000, totalMs: 1000);
      expect(a, isNot(equals(b)));
    });
  });

  group('StopwatchSession', () {
    StopwatchSession makeSession({List<LapRecord>? laps}) {
      return StopwatchSession(
        id: uuid.v4(),
        startedAt: DateTime.utc(2026, 5, 5, 10, 0, 0),
        endedAt: DateTime.utc(2026, 5, 5, 10, 5, 30),
        totalMs: 330000,
        laps: laps ??
            const [
              LapRecord(number: 1, lapMs: 120000, totalMs: 120000),
              LapRecord(number: 2, lapMs: 210000, totalMs: 330000),
            ],
      );
    }

    test('toMap / fromMap round-trip preserves all session fields', () {
      final session = makeSession();
      final map = session.toMap();

      expect(map['id'], session.id);
      expect(map['total_ms'], session.totalMs);

      // Reconstruct from map (laps passed separately — mirrors DB pattern).
      final restored = StopwatchSession.fromMap(map, session.laps);
      expect(restored, session);
    });

    test('fromMap parses ISO 8601 UTC timestamps correctly', () {
      final session = makeSession();
      final map = session.toMap();
      final restored = StopwatchSession.fromMap(map, session.laps);
      expect(restored.startedAt, session.startedAt);
      expect(restored.endedAt, session.endedAt);
    });

    test('equality: same sessions are equal', () {
      final s1 = makeSession();
      final s2 = StopwatchSession.fromMap(s1.toMap(), s1.laps);
      expect(s1, s2);
    });

    test('equality: different laps make sessions unequal', () {
      final s1 = makeSession(
        laps: const [LapRecord(number: 1, lapMs: 1000, totalMs: 1000)],
      );
      final s2 = makeSession(laps: const []);
      expect(s1, isNot(equals(s2)));
    });

    test('session with no laps round-trips correctly', () {
      final session = makeSession(laps: const []);
      final restored = StopwatchSession.fromMap(session.toMap(), const []);
      expect(restored.laps.isEmpty, isTrue);
      expect(restored, session);
    });
  });

  group('StopwatchSnapshot', () {
    test('initial snapshot has idle state and zeros', () {
      final snap = StopwatchSnapshot.initial;
      expect(snap.state, StopwatchState.idle);
      expect(snap.elapsedMs, 0);
      expect(snap.currentLapMs, 0);
      expect(snap.laps.isEmpty, isTrue);
    });
  });
}
