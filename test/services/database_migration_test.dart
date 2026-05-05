import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:fitness_timer/services/database_service.dart';

/// Verifies the v1 → v2 migration:
///   * REST rows are absorbed into the preceding work item's `rest_seconds`.
///   * Leading REST rows (no preceding work) fold into `routines.prep_time`,
///     clamped at 60.
///   * Surviving rows have `order_index` renumbered 0..N-1.
///
/// Uses temporary file-backed databases so that schema and data persist
/// across the close/reopen boundary required to trigger onUpgrade.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const uuid = Uuid();
  late Directory tempDir;
  final services = <DatabaseService>[];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fitness_timer_mig_');
    services.clear();
  });

  tearDown(() async {
    for (final svc in services) {
      await svc.close();
    }
    services.clear();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {
      // Best-effort cleanup; OS will reclaim temp files later.
    }
  });

  String tempPath() => p.join(tempDir.path, '${uuid.v4()}.db');

  DatabaseService trackedService(String path) {
    final svc = DatabaseService(dbPath: path);
    services.add(svc);
    return svc;
  }

  /// Creates a v1-schema database at [path] and inserts the given seed data
  /// in a single open/close cycle. Each item map keys: id, routineId,
  /// orderIndex, type, duration, name, targetReps?
  Future<void> seedV1({
    required String path,
    required List<Map<String, Object?>> routines,
    required List<Map<String, Object?>> items,
  }) async {
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
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
              FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_exercise_items_routine_id ON exercise_items(routine_id)',
          );
          await db.execute('''
            CREATE TABLE histories (
              id TEXT PRIMARY KEY,
              routine_id TEXT NOT NULL,
              completed_at TEXT NOT NULL,
              FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_histories_routine_id ON histories(routine_id)',
          );
        },
      ),
    );
    for (final r in routines) {
      await db.rawInsert(
        'INSERT INTO routines (id, title, prep_time, cooldown_time, total_cycles) VALUES (?, ?, ?, 0, 1)',
        [r['id'], r['title'], r['prepTime'] ?? 0],
      );
    }
    for (final i in items) {
      await db.rawInsert(
        'INSERT INTO exercise_items (id, routine_id, order_index, type, duration, target_reps, name) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          i['id'],
          i['routineId'],
          i['orderIndex'],
          i['type'],
          i['duration'],
          i['targetReps'],
          i['name'] ?? 'item',
        ],
      );
    }
    await db.close();
  }

  test('v1 → v2: REST row absorbed into preceding work item', () async {
    final path = tempPath();
    final routineId = uuid.v4();
    await seedV1(
      path: path,
      routines: [
        {'id': routineId, 'title': 'r'},
      ],
      items: [
        {
          'id': 'w1',
          'routineId': routineId,
          'orderIndex': 0,
          'type': 'WORK_TIME',
          'duration': 30,
          'name': 'Push-up',
        },
        {
          'id': 'rest1',
          'routineId': routineId,
          'orderIndex': 1,
          'type': 'REST',
          'duration': 10,
          'name': 'Rest',
        },
        {
          'id': 'w2',
          'routineId': routineId,
          'orderIndex': 2,
          'type': 'WORK_TIME',
          'duration': 20,
          'name': 'Squat',
        },
      ],
    );

    // Open via DatabaseService → triggers onUpgrade v1→v2.
    final svc = trackedService(path);
    final items = await svc.getExerciseItems(routineId);

    expect(items.length, 2);
    expect(items[0].id, 'w1');
    expect(items[0].orderIndex, 0);
    expect(items[0].restSeconds, 10);
    expect(items[1].id, 'w2');
    expect(items[1].orderIndex, 1);
    expect(items[1].restSeconds, 0);
  });

  test(
      'v1 → v2: leading REST without preceding work folds into prep_time, clamped to 60',
      () async {
    final path = tempPath();
    final routineId = uuid.v4();
    await seedV1(
      path: path,
      routines: [
        {'id': routineId, 'title': 'r', 'prepTime': 5},
      ],
      items: [
        // 70s of leading REST → prep_time should clamp at 60.
        {
          'id': 'rest_lead',
          'routineId': routineId,
          'orderIndex': 0,
          'type': 'REST',
          'duration': 70,
          'name': 'Rest',
        },
        {
          'id': 'w1',
          'routineId': routineId,
          'orderIndex': 1,
          'type': 'WORK_TIME',
          'duration': 30,
          'name': 'Push-up',
        },
      ],
    );

    final svc = trackedService(path);

    final routines = await svc.getAllRoutines();
    expect(routines.first.prepTime, 60);

    final items = await svc.getExerciseItems(routineId);
    expect(items.length, 1);
    expect(items[0].id, 'w1');
    expect(items[0].orderIndex, 0);
    expect(items[0].restSeconds, 0);
  });

  // ---------------------------------------------------------------------------
  // Helper: seed a v3 database with one stopwatch session (no label column)
  // ---------------------------------------------------------------------------
  Future<String> seedV3({List<Map<String, Object?>>? sessions}) async {
    final path = tempPath();
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
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
          // v3 stopwatch tables — without label column
          await db.execute('''
            CREATE TABLE stopwatch_sessions (
              id TEXT PRIMARY KEY,
              started_at TEXT NOT NULL,
              ended_at TEXT NOT NULL,
              total_ms INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE stopwatch_laps (
              id TEXT PRIMARY KEY,
              session_id TEXT NOT NULL,
              lap_number INTEGER NOT NULL,
              lap_ms INTEGER NOT NULL,
              total_ms INTEGER NOT NULL,
              FOREIGN KEY (session_id) REFERENCES stopwatch_sessions(id) ON DELETE CASCADE
            )
          ''');
        },
      ),
    );
    for (final s in sessions ?? []) {
      await db.rawInsert(
        'INSERT INTO stopwatch_sessions (id, started_at, ended_at, total_ms) VALUES (?, ?, ?, ?)',
        [s['id'], s['started_at'], s['ended_at'], s['total_ms']],
      );
    }
    await db.close();
    return path;
  }

  // ---------------------------------------------------------------------------
  // MIG-V4-1: Fresh install — label column exists
  // ---------------------------------------------------------------------------
  test('MIG-V4-1: fresh v4 install has label column in stopwatch_sessions',
      () async {
    final path = tempPath();
    final svc = trackedService(path);
    // Trigger DB init.
    await svc.getStopwatchSessions();
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true),
    );
    final cols = await db.rawQuery(
      "PRAGMA table_info(stopwatch_sessions)",
    );
    await db.close();
    final colNames = cols.map((c) => c['name'] as String).toList();
    expect(colNames, contains('label'));
  });

  // ---------------------------------------------------------------------------
  // MIG-V4-2: v3 DB with sessions upgraded to v4 — label IS NULL, data intact
  // ---------------------------------------------------------------------------
  test(
      'MIG-V4-2: v3→v4 migration: label column added, existing rows have null label, other columns intact',
      () async {
    final sessionId = uuid.v4();
    final path = await seedV3(sessions: [
      {
        'id': sessionId,
        'started_at': '2026-05-01T09:00:00.000Z',
        'ended_at': '2026-05-01T09:05:00.000Z',
        'total_ms': 300000,
      },
    ]);

    // Open via v4 DatabaseService to trigger migration.
    final svc = trackedService(path);
    final sessions = await svc.getStopwatchSessions();
    expect(sessions.length, 1);
    expect(sessions.first.id, sessionId);
    expect(sessions.first.totalMs, 300000);
    expect(sessions.first.label, isNull);
  });

  // ---------------------------------------------------------------------------
  // MIG-V4-3: Already-upgraded v4 DB reopened — no error
  // ---------------------------------------------------------------------------
  test('MIG-V4-3: already-v4 DB can be reopened without error', () async {
    final path = tempPath();
    // First open upgrades to v4.
    final svc1 = trackedService(path);
    await svc1.getStopwatchSessions();
    await svc1.close();
    services.remove(svc1);

    // Second open should succeed silently.
    final svc2 = trackedService(path);
    final sessions = await svc2.getStopwatchSessions();
    expect(sessions, isEmpty);
  });

  test('v1 → v2: multiple consecutive REST rows accumulate into one work item',
      () async {
    final path = tempPath();
    final routineId = uuid.v4();
    await seedV1(
      path: path,
      routines: [
        {'id': routineId, 'title': 'r'},
      ],
      items: [
        {
          'id': 'w1',
          'routineId': routineId,
          'orderIndex': 0,
          'type': 'WORK_TIME',
          'duration': 30,
          'name': 'Push-up',
        },
        {
          'id': 'rest_a',
          'routineId': routineId,
          'orderIndex': 1,
          'type': 'REST',
          'duration': 5,
          'name': 'Rest',
        },
        {
          'id': 'rest_b',
          'routineId': routineId,
          'orderIndex': 2,
          'type': 'REST',
          'duration': 7,
          'name': 'Rest',
        },
      ],
    );

    final svc = trackedService(path);
    final items = await svc.getExerciseItems(routineId);

    expect(items.length, 1);
    expect(items[0].id, 'w1');
    expect(items[0].restSeconds, 12);
  });
}
