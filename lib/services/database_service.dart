import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/exercise_item.dart';
import '../models/history.dart';
import '../models/routine.dart';

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
      version: 1,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
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
            (id, routine_id, order_index, type, duration, target_reps, name)
          VALUES (?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            map['id'],
            map['routine_id'],
            map['order_index'],
            map['type'],
            map['duration'],
            map['target_reps'],
            map['name'],
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
}
