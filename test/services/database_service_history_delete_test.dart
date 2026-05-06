import 'package:fitness_timer/models/history.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/models/stopwatch_session.dart';
import 'package:fitness_timer/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const uuid = Uuid();

  DatabaseService freshDb() =>
      DatabaseService(dbPath: 'file:${uuid.v4()}?mode=memory&cache=shared');

  // Helpers
  Future<Routine> seedRoutine(DatabaseService db) async {
    final routine = Routine(
      id: uuid.v4(),
      title: 'Test Routine',
      prepTime: 0,
      cooldownTime: 0,
      totalCycles: 1,
    );
    await db.upsertRoutineWithItems(routine, []);
    return routine;
  }

  Future<History> seedHistory(DatabaseService db, String routineId) async {
    await db.insertHistory(routineId);
    final histories = await db.getHistories();
    return histories.first;
  }

  Future<StopwatchSession> seedSession(
      DatabaseService db, List<LapRecord> laps) async {
    final session = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 5, 9, 0, 0),
      endedAt: DateTime.utc(2026, 5, 5, 9, 5, 0),
      totalMs: 300000,
      laps: laps,
    );
    await db.insertStopwatchSession(session);
    return session;
  }

  // -------------------------------------------------------------------------
  // T-DB1: deleteHistory — insert then delete by id
  // -------------------------------------------------------------------------
  test('T-DB1: deleteHistory removes the history row', () async {
    final db = freshDb();
    final routine = await seedRoutine(db);
    final h = await seedHistory(db, routine.id);

    await db.deleteHistory(h.id);

    final histories = await db.getHistories();
    expect(histories, isEmpty);
    await db.close();
  });

  // -------------------------------------------------------------------------
  // T-DB2: deleteHistory — delete absent id is a no-op
  // -------------------------------------------------------------------------
  test('T-DB2: deleteHistory with absent id does not throw', () async {
    final db = freshDb();
    final routine = await seedRoutine(db);
    await seedHistory(db, routine.id);

    // Should not throw
    await db.deleteHistory('nonexistent-id');

    final histories = await db.getHistories();
    expect(histories.length, 1); // original entry untouched
    await db.close();
  });

  // -------------------------------------------------------------------------
  // T-DB3: getHistoryById — insert then query
  // -------------------------------------------------------------------------
  test('T-DB3: getHistoryById returns matching history', () async {
    final db = freshDb();
    final routine = await seedRoutine(db);
    final h = await seedHistory(db, routine.id);

    final found = await db.getHistoryById(h.id);

    expect(found, isNotNull);
    expect(found!.id, h.id);
    expect(found.routineId, routine.id);
    await db.close();
  });

  // -------------------------------------------------------------------------
  // T-DB4: getHistoryById — absent id returns null
  // -------------------------------------------------------------------------
  test('T-DB4: getHistoryById returns null for absent id', () async {
    final db = freshDb();

    final found = await db.getHistoryById('no-such-id');

    expect(found, isNull);
    await db.close();
  });

  // -------------------------------------------------------------------------
  // T-DB5: insertHistoryRecord — id and completedAt preserved exactly
  // -------------------------------------------------------------------------
  test('T-DB5: insertHistoryRecord preserves id and completedAt', () async {
    final db = freshDb();
    final routine = await seedRoutine(db);
    final fixedId = uuid.v4();
    final fixedTime = DateTime.utc(2026, 1, 15, 12, 0, 0);
    final h = History(id: fixedId, routineId: routine.id, completedAt: fixedTime);

    await db.insertHistoryRecord(h);
    final found = await db.getHistoryById(fixedId);

    expect(found, isNotNull);
    expect(found!.id, fixedId);
    expect(found.completedAt, fixedTime);
    await db.close();
  });

  // -------------------------------------------------------------------------
  // T-DB6: deleteStopwatchSession — CASCADE removes laps
  // -------------------------------------------------------------------------
  test('T-DB6: deleteStopwatchSession removes session and cascades laps',
      () async {
    final db = freshDb();
    final session = await seedSession(db, [
      const LapRecord(number: 1, lapMs: 100000, totalMs: 100000),
      const LapRecord(number: 2, lapMs: 100000, totalMs: 200000),
      const LapRecord(number: 3, lapMs: 100000, totalMs: 300000),
    ]);

    await db.deleteStopwatchSession(session.id);

    final found = await db.getStopwatchSessionById(session.id);
    expect(found, isNull);

    // Verify laps were cascade-deleted via raw query
    final rawDb = await db.database;
    final lapRows = await rawDb.rawQuery(
      'SELECT * FROM stopwatch_laps WHERE session_id = ?',
      [session.id],
    );
    expect(lapRows, isEmpty);
    await db.close();
  });

  // -------------------------------------------------------------------------
  // T-DB7: deleteStopwatchSession — absent id is no-op
  // -------------------------------------------------------------------------
  test('T-DB7: deleteStopwatchSession with absent id does not throw', () async {
    final db = freshDb();
    // No session seeded
    await db.deleteStopwatchSession('nonexistent-id');
    // No exception = pass
    await db.close();
  });

  // -------------------------------------------------------------------------
  // T-DB8: deleteAllHistories — clears histories + sessions, routines untouched
  // -------------------------------------------------------------------------
  test('T-DB8: deleteAllHistories clears histories and sessions; routines preserved',
      () async {
    final db = freshDb();
    final routine = await seedRoutine(db);

    // Seed 2 histories
    await db.insertHistory(routine.id);
    await db.insertHistory(routine.id);

    // Seed 2 sessions with laps
    final s1 = await seedSession(db, [
      const LapRecord(number: 1, lapMs: 60000, totalMs: 60000),
    ]);
    final s2 = await seedSession(db, [
      const LapRecord(number: 1, lapMs: 90000, totalMs: 90000),
    ]);

    await db.deleteAllHistories();

    expect(await db.getHistories(), isEmpty);
    expect(await db.getStopwatchSessions(), isEmpty);

    // Verify laps cascade-deleted
    final rawDb = await db.database;
    for (final sid in [s1.id, s2.id]) {
      final lapRows = await rawDb.rawQuery(
        'SELECT * FROM stopwatch_laps WHERE session_id = ?',
        [sid],
      );
      expect(lapRows, isEmpty);
    }

    // Routines must remain
    final routines = await db.getAllRoutines();
    expect(routines.length, 1);
    expect(routines.first.id, routine.id);
    await db.close();
  });

  // -------------------------------------------------------------------------
  // T-DB9: deleteAllHistories — no-op on empty DB
  // -------------------------------------------------------------------------
  test('T-DB9: deleteAllHistories on empty DB does not throw', () async {
    final db = freshDb();
    await db.deleteAllHistories();
    // No exception = pass
    await db.close();
  });
}
