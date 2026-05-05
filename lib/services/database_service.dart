import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/exercise_item.dart';
import '../models/history.dart';
import '../models/routine.dart';
import '../models/stopwatch_session.dart';

class DatabaseService {
  /// Optional override path — used in tests only (pass inMemoryDatabasePath).
  /// When null, production path is resolved via path_provider.
  final String? _dbPath;

  Database? _database;

  DatabaseService({String? dbPath}) : _dbPath = dbPath;

  Future<Database> get database async {
    _database ??= await _initDb();
    return _database!;
  }

  /// Closes the underlying SQLite connection. Tests use this to release
  /// file handles before deleting temporary database files.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  Future<Database> _initDb() async {
    final String path;
    if (_dbPath != null) {
      // Test injection: use the provided path directly.
      path = _dbPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = join(dir.path, 'fitness_timer.db');
    }
    return openDatabase(
      path,
      version: 3,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
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

    await _createStopwatchTables(db);
  }

  Future<void> _createStopwatchTables(DatabaseExecutor db) async {
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
  }

  /// v1 → v2: add `rest_seconds` column and absorb REST rows into the
  /// preceding work item. REST rows at the start of a routine (no preceding
  /// work) get folded into the routine's `prep_time`, clamped to 60s.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.transaction((txn) async {
        await txn.execute(
          'ALTER TABLE exercise_items ADD COLUMN rest_seconds INTEGER NOT NULL DEFAULT 0',
        );

        final routineRows = await txn.rawQuery(
          'SELECT id, prep_time FROM routines',
        );

        for (final routineRow in routineRows) {
          final routineId = routineRow['id'] as String;
          var prepTime = routineRow['prep_time'] as int;

          final itemRows = await txn.rawQuery(
            'SELECT id, order_index, type, duration FROM exercise_items '
            'WHERE routine_id = ? ORDER BY order_index ASC',
            [routineId],
          );

          String? lastWorkId;
          var leadingRestSum = 0;
          final restIdsToDelete = <String>[];

          for (final row in itemRows) {
            final id = row['id'] as String;
            final type = row['type'] as String;
            final duration = row['duration'] as int;

            if (type == 'REST') {
              if (lastWorkId != null) {
                await txn.rawUpdate(
                  'UPDATE exercise_items SET rest_seconds = rest_seconds + ? WHERE id = ?',
                  [duration, lastWorkId],
                );
              } else {
                leadingRestSum += duration;
              }
              restIdsToDelete.add(id);
            } else {
              lastWorkId = id;
            }
          }

          if (leadingRestSum > 0) {
            final newPrep = (prepTime + leadingRestSum).clamp(0, 60);
            await txn.rawUpdate(
              'UPDATE routines SET prep_time = ? WHERE id = ?',
              [newPrep, routineId],
            );
            prepTime = newPrep;
          }

          for (final id in restIdsToDelete) {
            await txn.rawDelete('DELETE FROM exercise_items WHERE id = ?', [
              id,
            ]);
          }

          final remaining = await txn.rawQuery(
            'SELECT id FROM exercise_items WHERE routine_id = ? ORDER BY order_index ASC',
            [routineId],
          );
          for (var i = 0; i < remaining.length; i++) {
            await txn.rawUpdate(
              'UPDATE exercise_items SET order_index = ? WHERE id = ?',
              [i, remaining[i]['id']],
            );
          }
        }
      });
    }
    if (oldVersion < 3) {
      await _createStopwatchTables(db);
    }
  }

  // ---------------------------------------------------------------------------
  // Routine CRUD
  // ---------------------------------------------------------------------------

  Future<List<Routine>> getAllRoutines() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT * FROM routines ORDER BY title ASC');
    return rows.map(Routine.fromMap).toList();
  }

  Future<Routine?> getRoutine(String id) async {
    final db = await database;
    final rows = await db.rawQuery('SELECT * FROM routines WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return Routine.fromMap(rows.first);
  }

  // ---------------------------------------------------------------------------
  // ExerciseItem CRUD
  // ---------------------------------------------------------------------------

  Future<List<ExerciseItem>> getExerciseItems(String routineId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT * FROM exercise_items WHERE routine_id = ? ORDER BY order_index ASC',
      [routineId],
    );
    return rows.map(ExerciseItem.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // Upsert (transaction)
  // ---------------------------------------------------------------------------

  Future<void> upsertRoutineWithItems(
    Routine routine,
    List<ExerciseItem> items,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawInsert(
        '''
        INSERT OR REPLACE INTO routines
          (id, title, prep_time, cooldown_time, total_cycles)
        VALUES (?, ?, ?, ?, ?)
        ''',
        [
          routine.id,
          routine.title,
          routine.prepTime,
          routine.cooldownTime,
          routine.totalCycles,
        ],
      );

      await txn.rawDelete('DELETE FROM exercise_items WHERE routine_id = ?', [
        routine.id,
      ]);

      for (final item in items) {
        final itemWithRoutineId = item.copyWith(routineId: routine.id);
        final map = itemWithRoutineId.toMap();
        await txn.rawInsert(
          '''
          INSERT INTO exercise_items
            (id, routine_id, order_index, type, duration, target_reps, name, rest_seconds)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            map['id'],
            map['routine_id'],
            map['order_index'],
            map['type'],
            map['duration'],
            map['target_reps'],
            map['name'],
            map['rest_seconds'],
          ],
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  Future<void> deleteRoutine(String id) async {
    final db = await database;
    await db.rawDelete('DELETE FROM routines WHERE id = ?', [id]);
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  Future<void> insertHistory(String routineId) async {
    final db = await database;
    final history = History(
      id: const Uuid().v4(),
      routineId: routineId,
      completedAt: DateTime.now().toUtc(),
    );
    await db.rawInsert(
      'INSERT INTO histories (id, routine_id, completed_at) VALUES (?, ?, ?)',
      [history.id, history.routineId, history.completedAt.toIso8601String()],
    );
  }

  Future<List<History>> getHistories({int? limit}) async {
    final db = await database;
    final sql = StringBuffer(
      'SELECT * FROM histories ORDER BY completed_at DESC',
    );
    final args = <Object?>[];
    if (limit != null) {
      sql.write(' LIMIT ?');
      args.add(limit);
    }
    final rows = await db.rawQuery(sql.toString(), args.isEmpty ? null : args);
    return rows.map(History.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // Stopwatch CRUD
  // ---------------------------------------------------------------------------

  /// Inserts a [StopwatchSession] and all its laps in a single transaction.
  Future<void> insertStopwatchSession(StopwatchSession session) async {
    final db = await database;
    await db.transaction((txn) async {
      final sessionMap = session.toMap();
      await txn.rawInsert(
        'INSERT INTO stopwatch_sessions (id, started_at, ended_at, total_ms) VALUES (?, ?, ?, ?)',
        [
          sessionMap['id'],
          sessionMap['started_at'],
          sessionMap['ended_at'],
          sessionMap['total_ms'],
        ],
      );
      for (final lap in session.laps) {
        final lapMap = lap.toMap(sessionId: session.id, id: const Uuid().v4());
        await txn.rawInsert(
          'INSERT INTO stopwatch_laps (id, session_id, lap_number, lap_ms, total_ms) VALUES (?, ?, ?, ?, ?)',
          [
            lapMap['id'],
            lapMap['session_id'],
            lapMap['lap_number'],
            lapMap['lap_ms'],
            lapMap['total_ms'],
          ],
        );
      }
    });
  }

  /// Returns stopwatch sessions ordered by ended_at DESC. Includes laps.
  Future<List<StopwatchSession>> getStopwatchSessions({int? limit}) async {
    final db = await database;
    final sql = StringBuffer(
      'SELECT * FROM stopwatch_sessions ORDER BY ended_at DESC',
    );
    final args = <Object?>[];
    if (limit != null) {
      sql.write(' LIMIT ?');
      args.add(limit);
    }
    final sessionRows =
        await db.rawQuery(sql.toString(), args.isEmpty ? null : args);
    final sessions = <StopwatchSession>[];
    for (final row in sessionRows) {
      final sessionId = row['id'] as String;
      final lapRows = await db.rawQuery(
        'SELECT * FROM stopwatch_laps WHERE session_id = ? ORDER BY lap_number ASC',
        [sessionId],
      );
      final laps = lapRows.map(LapRecord.fromMap).toList();
      sessions.add(StopwatchSession.fromMap(row, laps));
    }
    return sessions;
  }

  /// Returns a merged list of interval history and stopwatch sessions,
  /// ordered by timestamp DESC.
  Future<List<HistoryEntry>> getMergedHistory({int? limit}) async {
    final db = await database;
    final sql = StringBuffer('''
      SELECT
        h.id AS id,
        'interval' AS type,
        h.completed_at AS ts,
        r.title AS title,
        NULL AS total_ms,
        NULL AS lap_count
      FROM histories h
      LEFT JOIN routines r ON r.id = h.routine_id
      UNION ALL
      SELECT
        s.id AS id,
        'stopwatch' AS type,
        s.ended_at AS ts,
        NULL AS title,
        s.total_ms AS total_ms,
        (SELECT COUNT(*) FROM stopwatch_laps l WHERE l.session_id = s.id) AS lap_count
      FROM stopwatch_sessions s
      ORDER BY ts DESC
    ''');
    if (limit != null) {
      sql.write(' LIMIT ?');
    }
    final rows = await db.rawQuery(
      sql.toString(),
      limit != null ? [limit] : null,
    );
    return rows.map((row) {
      final typeStr = row['type'] as String;
      final type = typeStr == 'interval'
          ? HistoryEntryType.interval
          : HistoryEntryType.stopwatch;
      return HistoryEntry(
        id: row['id'] as String,
        type: type,
        timestamp: DateTime.parse(row['ts'] as String),
        title: row['title'] as String?,
        totalMs: row['total_ms'] as int?,
        lapCount: row['lap_count'] as int?,
      );
    }).toList();
  }
}
