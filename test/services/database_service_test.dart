import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:fitness_timer/models/exercise_item.dart';
import 'package:fitness_timer/models/history.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const uuid = Uuid();

  /// Creates an isolated in-memory DatabaseService for each test.
  /// Uses a unique path per call so tests don't share SQLite state.
  DatabaseService freshDb() =>
      DatabaseService(dbPath: 'file:${uuid.v4()}?mode=memory&cache=shared');

  // -------------------------------------------------------------------------
  // T1: Upsert Routine with 3 ExerciseItems → getAllRoutines + getExerciseItems
  // -------------------------------------------------------------------------
  test('T1: upsert routine with 3 items round-trips correctly', () async {
    final db = freshDb();
    final routineId = uuid.v4();
    final routine = Routine(
      id: routineId,
      title: 'Full Body',
      prepTime: 10,
      cooldownTime: 30,
      totalCycles: 3,
    );
    final items = [
      ExerciseItem(
        id: uuid.v4(),
        routineId: routineId,
        orderIndex: 0,
        type: ExerciseType.WORK_TIME,
        duration: 40,
        name: 'Push-ups',
        restSeconds: 15,
      ),
      ExerciseItem(
        id: uuid.v4(),
        routineId: routineId,
        orderIndex: 1,
        type: ExerciseType.REST,
        duration: 20,
        name: 'Rest',
      ),
      ExerciseItem(
        id: uuid.v4(),
        routineId: routineId,
        orderIndex: 2,
        type: ExerciseType.WORK_TIME,
        duration: 30,
        name: 'Squats',
      ),
    ];

    await db.upsertRoutineWithItems(routine, items);

    final routines = await db.getAllRoutines();
    expect(routines.length, 1);
    expect(routines.first.id, routine.id);
    expect(routines.first.title, routine.title);
    expect(routines.first.prepTime, routine.prepTime);
    expect(routines.first.cooldownTime, routine.cooldownTime);
    expect(routines.first.totalCycles, routine.totalCycles);

    final fetchedItems = await db.getExerciseItems(routineId);
    expect(fetchedItems.length, 3);
    for (int i = 0; i < items.length; i++) {
      expect(fetchedItems[i].id, items[i].id);
      expect(fetchedItems[i].orderIndex, items[i].orderIndex);
      expect(fetchedItems[i].name, items[i].name);
      expect(fetchedItems[i].type, items[i].type);
      expect(fetchedItems[i].duration, items[i].duration);
      expect(fetchedItems[i].restSeconds, items[i].restSeconds);
    }
  });

  // -------------------------------------------------------------------------
  // T2: Re-upsert same routine with 2 different items replaces the 3 old ones
  // -------------------------------------------------------------------------
  test('T2: re-upsert replaces existing items atomically', () async {
    final db = freshDb();
    final routineId = uuid.v4();
    final routine = Routine(id: routineId, title: 'Cardio');

    final originalItems = [
      ExerciseItem(
        id: uuid.v4(),
        routineId: routineId,
        orderIndex: 0,
        type: ExerciseType.WORK_TIME,
        duration: 30,
        name: 'Jumping Jacks',
      ),
      ExerciseItem(
        id: uuid.v4(),
        routineId: routineId,
        orderIndex: 1,
        type: ExerciseType.REST,
        duration: 15,
        name: 'Rest',
      ),
      ExerciseItem(
        id: uuid.v4(),
        routineId: routineId,
        orderIndex: 2,
        type: ExerciseType.WORK_TIME,
        duration: 30,
        name: 'High Knees',
      ),
    ];
    await db.upsertRoutineWithItems(routine, originalItems);

    final newItems = [
      ExerciseItem(
        id: uuid.v4(),
        routineId: routineId,
        orderIndex: 0,
        type: ExerciseType.WORK_TIME,
        duration: 45,
        name: 'Burpees',
      ),
      ExerciseItem(
        id: uuid.v4(),
        routineId: routineId,
        orderIndex: 1,
        type: ExerciseType.REST,
        duration: 20,
        name: 'Rest',
      ),
    ];
    await db.upsertRoutineWithItems(routine, newItems);

    final fetchedItems = await db.getExerciseItems(routineId);
    expect(fetchedItems.length, 2);
    expect(fetchedItems[0].name, 'Burpees');
    expect(fetchedItems[1].name, 'Rest');
    expect(fetchedItems[0].orderIndex, 0);
    expect(fetchedItems[1].orderIndex, 1);
  });

  // -------------------------------------------------------------------------
  // T3: deleteRoutine cascades to exercise_items and histories
  // -------------------------------------------------------------------------
  test('T3: deleteRoutine removes items and history via FK cascade', () async {
    final db = freshDb();
    final routineId = uuid.v4();
    final routine = Routine(id: routineId, title: 'HIIT');
    final items = [
      ExerciseItem(
        id: uuid.v4(),
        routineId: routineId,
        orderIndex: 0,
        type: ExerciseType.WORK_TIME,
        duration: 20,
        name: 'Sprint',
      ),
      ExerciseItem(
        id: uuid.v4(),
        routineId: routineId,
        orderIndex: 1,
        type: ExerciseType.REST,
        duration: 10,
        name: 'Rest',
      ),
    ];

    await db.upsertRoutineWithItems(routine, items);
    await db.insertHistory(routineId);

    await db.deleteRoutine(routineId);

    final routines = await db.getAllRoutines();
    expect(routines, isEmpty);

    final fetchedItems = await db.getExerciseItems(routineId);
    expect(fetchedItems, isEmpty);

    final histories = await db.getHistories();
    expect(histories, isEmpty);
  });

  // -------------------------------------------------------------------------
  // T4: insertHistory × 2 → getHistories returns 2 newest-first
  // -------------------------------------------------------------------------
  test('T4: insertHistory twice returns 2 records newest-first', () async {
    final db = freshDb();
    final routineId = uuid.v4();
    final routine = Routine(id: routineId, title: 'Morning Run');
    await db.upsertRoutineWithItems(routine, []);

    await db.insertHistory(routineId);
    // Small delay so the two timestamps are distinguishable.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await db.insertHistory(routineId);

    final histories = await db.getHistories();
    expect(histories.length, 2);
    // Newest-first: first element must be more recent.
    expect(
      histories[0].completedAt.isAfter(histories[1].completedAt) ||
          histories[0].completedAt.isAtSameMomentAs(histories[1].completedAt),
      isTrue,
    );
    expect(histories[0].routineId, routineId);
    expect(histories[1].routineId, routineId);
  });

  // -------------------------------------------------------------------------
  // T5: WORK_REPS ExerciseItem round-trips targetReps correctly
  // -------------------------------------------------------------------------
  test(
    'T5: WORK_REPS ExerciseItem preserves targetReps on round-trip',
    () async {
      final db = freshDb();
      final routineId = uuid.v4();
      final routine = Routine(id: routineId, title: 'Strength');
      final repsItem = ExerciseItem(
        id: uuid.v4(),
        routineId: routineId,
        orderIndex: 0,
        type: ExerciseType.WORK_REPS,
        duration: 30,
        targetReps: 10,
        name: 'Pull-ups',
      );
      final timeItem = ExerciseItem(
        id: uuid.v4(),
        routineId: routineId,
        orderIndex: 1,
        type: ExerciseType.WORK_TIME,
        duration: 30,
        name: 'Plank',
      );

      await db.upsertRoutineWithItems(routine, [repsItem, timeItem]);

      final fetchedItems = await db.getExerciseItems(routineId);
      expect(fetchedItems.length, 2);

      final fetchedReps = fetchedItems.firstWhere(
        (e) => e.type == ExerciseType.WORK_REPS,
      );
      expect(fetchedReps.targetReps, 10);
      expect(fetchedReps.duration, 30);

      final fetchedTime = fetchedItems.firstWhere(
        (e) => e.type == ExerciseType.WORK_TIME,
      );
      expect(fetchedTime.targetReps, isNull);
    },
  );

  // -------------------------------------------------------------------------
  // Model round-trip tests
  // -------------------------------------------------------------------------
  group('Model round-trip (toMap / fromMap)', () {
    test('Routine round-trip preserves all fields', () {
      final r = Routine(
        id: uuid.v4(),
        title: 'Test Routine',
        prepTime: 5,
        cooldownTime: 10,
        totalCycles: 4,
      );
      final r2 = Routine.fromMap(r.toMap());
      expect(r2.id, r.id);
      expect(r2.title, r.title);
      expect(r2.prepTime, r.prepTime);
      expect(r2.cooldownTime, r.cooldownTime);
      expect(r2.totalCycles, r.totalCycles);
    });

    test(
      'ExerciseItem round-trip preserves all fields including nullable targetReps',
      () {
        final id = uuid.v4();
        final routineId = uuid.v4();

        final eWithReps = ExerciseItem(
          id: id,
          routineId: routineId,
          orderIndex: 0,
          type: ExerciseType.WORK_REPS,
          duration: 20,
          targetReps: 12,
          name: 'Dips',
          restSeconds: 15,
        );
        final e2 = ExerciseItem.fromMap(eWithReps.toMap());
        expect(e2.id, eWithReps.id);
        expect(e2.routineId, eWithReps.routineId);
        expect(e2.orderIndex, eWithReps.orderIndex);
        expect(e2.type, ExerciseType.WORK_REPS);
        expect(e2.duration, eWithReps.duration);
        expect(e2.targetReps, 12);
        expect(e2.name, eWithReps.name);
        expect(e2.restSeconds, 15);

        final eNoReps = ExerciseItem(
          id: uuid.v4(),
          routineId: routineId,
          orderIndex: 1,
          type: ExerciseType.WORK_TIME,
          duration: 30,
          name: 'Plank',
        );
        final e3 = ExerciseItem.fromMap(eNoReps.toMap());
        expect(e3.targetReps, isNull);
        expect(e3.restSeconds, 0);
      },
    );

    test('ExerciseItem.fromMap defaults restSeconds to 0 when key missing', () {
      final map = {
        'id': 'x',
        'routine_id': 'r',
        'order_index': 0,
        'type': 'WORK_TIME',
        'duration': 10,
        'target_reps': null,
        'name': 'Legacy',
        // intentionally no rest_seconds
      };
      final e = ExerciseItem.fromMap(map);
      expect(e.restSeconds, 0);
    });

    test('History round-trip preserves id, routineId, and completedAt', () {
      final h = History(
        id: uuid.v4(),
        routineId: uuid.v4(),
        completedAt: DateTime.utc(2026, 5, 3, 12, 0, 0),
      );
      final h2 = History.fromMap(h.toMap());
      expect(h2.id, h.id);
      expect(h2.routineId, h.routineId);
      // Compare to second precision (ISO 8601 has sub-second, parse is exact).
      expect(h2.completedAt, h.completedAt);
    });
  });
}
