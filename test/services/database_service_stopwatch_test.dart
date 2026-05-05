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
}
