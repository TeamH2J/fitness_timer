import 'dart:io';

import 'package:fitness_timer/models/exercise_item.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/models/stopwatch_session.dart';
import 'package:fitness_timer/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const uuid = Uuid();

  // Use unique in-memory URI per test for isolation.
  DatabaseService freshDb() =>
      DatabaseService(dbPath: 'file:${uuid.v4()}?mode=memory&cache=shared');

  // ---------------------------------------------------------------------------
  // T-SW1: insertStopwatchSession + getStopwatchSessions round-trip
  // ---------------------------------------------------------------------------
  test('T-SW1: insertStopwatchSession + getStopwatchSessions round-trip',
      () async {
    final db = freshDb();

    final session = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 5, 9, 0, 0),
      endedAt: DateTime.utc(2026, 5, 5, 9, 5, 30),
      totalMs: 330000,
      laps: const [
        LapRecord(number: 1, lapMs: 120000, totalMs: 120000),
        LapRecord(number: 2, lapMs: 210000, totalMs: 330000),
      ],
    );

    await db.insertStopwatchSession(session);
    final sessions = await db.getStopwatchSessions();

    expect(sessions.length, 1);
    final retrieved = sessions.first;
    expect(retrieved.id, session.id);
    expect(retrieved.totalMs, session.totalMs);
    expect(retrieved.startedAt, session.startedAt);
    expect(retrieved.endedAt, session.endedAt);
    expect(retrieved.laps.length, 2);
    expect(retrieved.laps[0].number, 1);
    expect(retrieved.laps[0].lapMs, 120000);
    expect(retrieved.laps[1].number, 2);
    expect(retrieved.laps[1].lapMs, 210000);
  });

  // ---------------------------------------------------------------------------
  // T-SW2: Session with no laps
  // ---------------------------------------------------------------------------
  test('T-SW2: session with no laps inserts and retrieves correctly', () async {
    final db = freshDb();
    final session = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 5, 8, 0, 0),
      endedAt: DateTime.utc(2026, 5, 5, 8, 1, 0),
      totalMs: 60000,
      laps: const [],
    );
    await db.insertStopwatchSession(session);
    final sessions = await db.getStopwatchSessions();
    expect(sessions.length, 1);
    expect(sessions.first.laps.isEmpty, isTrue);
  });

  // ---------------------------------------------------------------------------
  // T-SW3: getStopwatchSessions ordering (newest-first)
  // ---------------------------------------------------------------------------
  test('T-SW3: getStopwatchSessions returns sessions newest-first', () async {
    final db = freshDb();
    final earlier = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 5, 8, 0, 0),
      endedAt: DateTime.utc(2026, 5, 5, 8, 5, 0),
      totalMs: 300000,
      laps: const [],
    );
    final later = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 5, 9, 0, 0),
      endedAt: DateTime.utc(2026, 5, 5, 9, 5, 0),
      totalMs: 300000,
      laps: const [],
    );
    await db.insertStopwatchSession(earlier);
    await db.insertStopwatchSession(later);
    final sessions = await db.getStopwatchSessions();
    expect(sessions.length, 2);
    expect(sessions[0].id, later.id);
    expect(sessions[1].id, earlier.id);
  });

  // ---------------------------------------------------------------------------
  // T-SW4: v2 → v3 migration: existing data survives intact
  // ---------------------------------------------------------------------------
  test('T-SW4: v2->v3 migration preserves routines, exercise_items, histories',
      () async {
    late Directory tempDir;
    tempDir = await Directory.systemTemp.createTemp('fitness_timer_sw_mig_');
    final path = p.join(tempDir.path, '${uuid.v4()}.db');

    // Seed a v2 database.
    final v2Db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE routines (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              prep_time INTEGER NOT NULL DEFAULT 0,
              cooldown_time INTEGER NOT NULL DEFAULT 0,
              total_cycles INTEGER NOT NULL DEFAULT 1
            )
          ''');
          await db.execute('''
            CREATE TABLE exercise_items (
              id TEXT PRIMARY KEY,
              routine_id TEXT NOT NULL,
              order_index INTEGER NOT NULL,
              type TEXT NOT NULL CHECK (type IN ('WORK_TIME','WORK_REPS','REST')),
              duration INTEGER NOT NULL DEFAULT 0,
              target_reps INTEGER,
              name TEXT NOT NULL,
              rest_seconds INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE histories (
              id TEXT PRIMARY KEY,
              routine_id TEXT NOT NULL,
              completed_at TEXT NOT NULL,
              FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE
            )
          ''');
        },
      ),
    );

    final routineId = uuid.v4();
    await v2Db.rawInsert(
      'INSERT INTO routines (id, title, prep_time, cooldown_time, total_cycles) VALUES (?, ?, ?, ?, ?)',
      [routineId, 'Test Routine', 10, 0, 1],
    );
    await v2Db.rawInsert(
      'INSERT INTO exercise_items (id, routine_id, order_index, type, duration, name, rest_seconds) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [uuid.v4(), routineId, 0, 'WORK_TIME', 30, 'Push-up', 10],
    );
    await v2Db.rawInsert(
      'INSERT INTO histories (id, routine_id, completed_at) VALUES (?, ?, ?)',
      [uuid.v4(), routineId, DateTime.utc(2026, 5, 1).toIso8601String()],
    );
    await v2Db.close();

    // Re-open via DatabaseService → triggers v2→v3 migration.
    final svc = DatabaseService(dbPath: path);
    final routines = await svc.getAllRoutines();
    expect(routines.length, 1);
    expect(routines.first.title, 'Test Routine');

    final items = await svc.getExerciseItems(routineId);
    expect(items.length, 1);
    expect(items.first.name, 'Push-up');
    expect(items.first.restSeconds, 10);

    final histories = await svc.getHistories();
    expect(histories.length, 1);

    // New tables should be present and writable.
    final newSession = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 5),
      endedAt: DateTime.utc(2026, 5, 5, 0, 5),
      totalMs: 300000,
      laps: const [],
    );
    await svc.insertStopwatchSession(newSession);
    final sessions = await svc.getStopwatchSessions();
    expect(sessions.length, 1);

    await svc.close();
    await tempDir.delete(recursive: true);
  });

  // ---------------------------------------------------------------------------
  // T-SW5: getMergedHistory returns both interval and stopwatch, newest-first
  // ---------------------------------------------------------------------------
  test('T-SW5: getMergedHistory returns merged entries in timestamp-desc order',
      () async {
    final db = freshDb();

    // Insert a routine + interval history.
    final routine = Routine(id: uuid.v4(), title: 'Morning Run');
    await db.upsertRoutineWithItems(routine, [
      ExerciseItem(
        id: uuid.v4(),
        routineId: routine.id,
        orderIndex: 0,
        type: ExerciseType.WORK_TIME,
        duration: 30,
        name: 'Run',
      ),
    ]);
    await db.insertHistory(routine.id);

    // Insert a stopwatch session with a later timestamp.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final session = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 5, 10, 0, 0),
      endedAt: DateTime.utc(2099, 5, 5, 10, 5, 0), // far future = newest
      totalMs: 300000,
      laps: const [
        LapRecord(number: 1, lapMs: 150000, totalMs: 150000),
      ],
    );
    await db.insertStopwatchSession(session);

    final merged = await db.getMergedHistory();
    expect(merged.length, 2);

    // Stopwatch session (future timestamp) should be first.
    expect(merged[0].type, HistoryEntryType.stopwatch);
    expect(merged[0].id, session.id);
    expect(merged[0].totalMs, 300000);
    expect(merged[0].lapCount, 1);

    // Interval history should be second.
    expect(merged[1].type, HistoryEntryType.interval);
    expect(merged[1].title, 'Morning Run');
    expect(merged[1].totalMs, isNull);
  });

  // ---------------------------------------------------------------------------
  // T-SW6: getMergedHistory with limit
  // ---------------------------------------------------------------------------
  test('T-SW6: getMergedHistory respects limit parameter', () async {
    final db = freshDb();
    final routine = Routine(id: uuid.v4(), title: 'Run');
    await db.upsertRoutineWithItems(routine, []);
    await db.insertHistory(routine.id);

    final session = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 5),
      endedAt: DateTime.utc(2026, 5, 5, 0, 1),
      totalMs: 60000,
      laps: const [],
    );
    await db.insertStopwatchSession(session);

    final merged = await db.getMergedHistory(limit: 1);
    expect(merged.length, 1);
  });

  // ---------------------------------------------------------------------------
  // SW-DB-1: insertStopwatchSession with label — round-trip
  // ---------------------------------------------------------------------------
  test('SW-DB-1: insertStopwatchSession with label survives getStopwatchSessionById',
      () async {
    final db = freshDb();
    final session = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 5, 9, 0),
      endedAt: DateTime.utc(2026, 5, 5, 9, 5),
      totalMs: 300000,
      laps: const [],
      label: '5km run',
    );
    await db.insertStopwatchSession(session);
    final retrieved = await db.getStopwatchSessionById(session.id);
    expect(retrieved, isNotNull);
    expect(retrieved!.label, '5km run');
  });

  // ---------------------------------------------------------------------------
  // SW-DB-2: insertStopwatchSession with null label
  // ---------------------------------------------------------------------------
  test('SW-DB-2: insertStopwatchSession with null label stores null', () async {
    final db = freshDb();
    final session = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 5, 9, 0),
      endedAt: DateTime.utc(2026, 5, 5, 9, 5),
      totalMs: 300000,
      laps: const [],
    );
    await db.insertStopwatchSession(session);
    final retrieved = await db.getStopwatchSessionById(session.id);
    expect(retrieved, isNotNull);
    expect(retrieved!.label, isNull);
  });

  // ---------------------------------------------------------------------------
  // SW-DB-3: getStopwatchSessionById — found with laps
  // ---------------------------------------------------------------------------
  test('SW-DB-3: getStopwatchSessionById returns correct session and laps',
      () async {
    final db = freshDb();
    final session = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 5, 9, 0),
      endedAt: DateTime.utc(2026, 5, 5, 9, 5),
      totalMs: 300000,
      laps: const [
        LapRecord(number: 1, lapMs: 120000, totalMs: 120000),
        LapRecord(number: 2, lapMs: 180000, totalMs: 300000),
      ],
    );
    await db.insertStopwatchSession(session);
    final retrieved = await db.getStopwatchSessionById(session.id);
    expect(retrieved, isNotNull);
    expect(retrieved!.id, session.id);
    expect(retrieved.laps.length, 2);
    expect(retrieved.laps[0].lapMs, 120000);
    expect(retrieved.laps[1].lapMs, 180000);
  });

  // ---------------------------------------------------------------------------
  // SW-DB-4: getStopwatchSessionById — not found
  // ---------------------------------------------------------------------------
  test('SW-DB-4: getStopwatchSessionById returns null for unknown id', () async {
    final db = freshDb();
    final result = await db.getStopwatchSessionById('nonexistent-id');
    expect(result, isNull);
  });

  // ---------------------------------------------------------------------------
  // SW-DB-5: getSessionsByLabel — only matching sessions returned
  // ---------------------------------------------------------------------------
  test('SW-DB-5: getSessionsByLabel returns only sessions with matching label',
      () async {
    final db = freshDb();
    final s1 = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 1),
      endedAt: DateTime.utc(2026, 5, 1, 0, 5),
      totalMs: 300000,
      laps: const [],
      label: 'run',
    );
    final s2 = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 2),
      endedAt: DateTime.utc(2026, 5, 2, 0, 5),
      totalMs: 280000,
      laps: const [],
      label: 'other',
    );
    final s3 = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 3),
      endedAt: DateTime.utc(2026, 5, 3, 0, 5),
      totalMs: 270000,
      laps: const [],
    );
    await db.insertStopwatchSession(s1);
    await db.insertStopwatchSession(s2);
    await db.insertStopwatchSession(s3);

    final results = await db.getSessionsByLabel('run');
    expect(results.length, 1);
    expect(results.first.id, s1.id);
  });

  // ---------------------------------------------------------------------------
  // SW-DB-6: getSessionsByLabel — ordering (newest-first)
  // ---------------------------------------------------------------------------
  test('SW-DB-6: getSessionsByLabel returns results ended_at DESC', () async {
    final db = freshDb();
    final older = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 1),
      endedAt: DateTime.utc(2026, 5, 1, 0, 5),
      totalMs: 300000,
      laps: const [],
      label: 'run',
    );
    final newer = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 2),
      endedAt: DateTime.utc(2026, 5, 2, 0, 5),
      totalMs: 280000,
      laps: const [],
      label: 'run',
    );
    await db.insertStopwatchSession(older);
    await db.insertStopwatchSession(newer);

    final results = await db.getSessionsByLabel('run');
    expect(results.length, 2);
    expect(results[0].id, newer.id);
    expect(results[1].id, older.id);
  });

  // ---------------------------------------------------------------------------
  // SW-DB-7: getSessionsByLabel — limit
  // ---------------------------------------------------------------------------
  test('SW-DB-7: getSessionsByLabel respects limit parameter', () async {
    final db = freshDb();
    for (var i = 0; i < 5; i++) {
      await db.insertStopwatchSession(StopwatchSession(
        id: uuid.v4(),
        startedAt: DateTime.utc(2026, 5, i + 1),
        endedAt: DateTime.utc(2026, 5, i + 1, 0, 5),
        totalMs: 300000 - i * 1000,
        laps: const [],
        label: 'run',
      ));
    }
    final results = await db.getSessionsByLabel('run', limit: 2);
    expect(results.length, 2);
  });

  // ---------------------------------------------------------------------------
  // SW-DB-8: getPersonalBestForLabel — returns minimum total_ms
  // ---------------------------------------------------------------------------
  test('SW-DB-8: getPersonalBestForLabel returns minimum total_ms', () async {
    final db = freshDb();
    for (final ms in [300000, 250000, 280000]) {
      await db.insertStopwatchSession(StopwatchSession(
        id: uuid.v4(),
        startedAt: DateTime.utc(2026, 5, 1),
        endedAt: DateTime.utc(2026, 5, 1, 0, 5),
        totalMs: ms,
        laps: const [],
        label: 'run',
      ));
    }
    final pb = await db.getPersonalBestForLabel('run');
    expect(pb, 250000);
  });

  // ---------------------------------------------------------------------------
  // SW-DB-9: getPersonalBestForLabel — null-label sessions excluded
  // ---------------------------------------------------------------------------
  test('SW-DB-9: getPersonalBestForLabel ignores sessions with null label',
      () async {
    final db = freshDb();
    await db.insertStopwatchSession(StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 1),
      endedAt: DateTime.utc(2026, 5, 1, 0, 5),
      totalMs: 100000,
      laps: const [],
      // no label — should not affect 'run' PB
    ));
    await db.insertStopwatchSession(StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 2),
      endedAt: DateTime.utc(2026, 5, 2, 0, 5),
      totalMs: 300000,
      laps: const [],
      label: 'run',
    ));
    final pb = await db.getPersonalBestForLabel('run');
    expect(pb, 300000);
  });

  // ---------------------------------------------------------------------------
  // SW-DB-10: getPersonalBestForLabel — no sessions returns null
  // ---------------------------------------------------------------------------
  test('SW-DB-10: getPersonalBestForLabel returns null when no sessions', () async {
    final db = freshDb();
    final pb = await db.getPersonalBestForLabel('nonexistent');
    expect(pb, isNull);
  });

  // ---------------------------------------------------------------------------
  // SW-DB-11: updateStopwatchSessionLabel — set label
  // ---------------------------------------------------------------------------
  test('SW-DB-11: updateStopwatchSessionLabel sets label correctly', () async {
    final db = freshDb();
    final session = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 1),
      endedAt: DateTime.utc(2026, 5, 1, 0, 5),
      totalMs: 300000,
      laps: const [],
    );
    await db.insertStopwatchSession(session);
    await db.updateStopwatchSessionLabel(session.id, 'morning run');
    final retrieved = await db.getStopwatchSessionById(session.id);
    expect(retrieved!.label, 'morning run');
  });

  // ---------------------------------------------------------------------------
  // SW-DB-12: updateStopwatchSessionLabel — clear to null
  // ---------------------------------------------------------------------------
  test('SW-DB-12: updateStopwatchSessionLabel clears label to null', () async {
    final db = freshDb();
    final session = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 1),
      endedAt: DateTime.utc(2026, 5, 1, 0, 5),
      totalMs: 300000,
      laps: const [],
      label: 'run',
    );
    await db.insertStopwatchSession(session);
    await db.updateStopwatchSessionLabel(session.id, null);
    final retrieved = await db.getStopwatchSessionById(session.id);
    expect(retrieved!.label, isNull);
  });

  // ---------------------------------------------------------------------------
  // SW-DB-13: getMergedHistory — stopwatch rows carry label
  // ---------------------------------------------------------------------------
  test('SW-DB-13: getMergedHistory populates label for stopwatch entries',
      () async {
    final db = freshDb();
    final session = StopwatchSession(
      id: uuid.v4(),
      startedAt: DateTime.utc(2026, 5, 1),
      endedAt: DateTime.utc(2026, 5, 1, 0, 5),
      totalMs: 300000,
      laps: const [],
      label: 'run',
    );
    await db.insertStopwatchSession(session);
    final merged = await db.getMergedHistory();
    expect(merged.length, 1);
    expect(merged.first.label, 'run');
  });

  // ---------------------------------------------------------------------------
  // SW-DB-14: getMergedHistory — interval rows have null label
  // ---------------------------------------------------------------------------
  test('SW-DB-14: getMergedHistory gives null label to interval entries', () async {
    final db = freshDb();
    final routine = Routine(id: uuid.v4(), title: 'Morning');
    await db.upsertRoutineWithItems(routine, [
      ExerciseItem(
        id: uuid.v4(),
        routineId: routine.id,
        orderIndex: 0,
        type: ExerciseType.WORK_TIME,
        duration: 30,
        name: 'Run',
      ),
    ]);
    await db.insertHistory(routine.id);
    final merged = await db.getMergedHistory();
    final intervalEntry = merged.firstWhere(
        (e) => e.type == HistoryEntryType.interval);
    expect(intervalEntry.label, isNull);
  });
}
