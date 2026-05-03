import 'package:fitness_timer/models/exercise_item.dart';
import 'package:fitness_timer/models/history.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/services/database_service.dart';

/// Concrete subclass of [DatabaseService] that stores data in memory.
/// All overridden methods bypass SQLite.
class FakeDatabaseService extends DatabaseService {
  final List<Routine> _routines;
  final Map<String, List<ExerciseItem>> _items;
  final List<History> _histories;

  int upsertCallCount = 0;
  int insertHistoryCallCount = 0;
  int deleteCallCount = 0;

  FakeDatabaseService({
    List<Routine>? routines,
    Map<String, List<ExerciseItem>>? items,
    List<History>? histories,
  })  : _routines = routines ?? [],
        _items = items ?? {},
        _histories = histories ?? [],
        super(dbPath: ':memory:'); // not actually used

  @override
  Future<List<Routine>> getAllRoutines() async => List.from(_routines);

  @override
  Future<Routine?> getRoutine(String id) async {
    try {
      return _routines.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ExerciseItem>> getExerciseItems(String routineId) async {
    return List.from(_items[routineId] ?? []);
  }

  @override
  Future<void> upsertRoutineWithItems(
    Routine routine,
    List<ExerciseItem> items,
  ) async {
    upsertCallCount++;
    final idx = _routines.indexWhere((r) => r.id == routine.id);
    if (idx >= 0) {
      _routines[idx] = routine;
    } else {
      _routines.add(routine);
    }
    _items[routine.id] = List.from(items);
  }

  @override
  Future<void> deleteRoutine(String id) async {
    deleteCallCount++;
    _routines.removeWhere((r) => r.id == id);
    _items.remove(id);
  }

  @override
  Future<void> insertHistory(String routineId) async {
    insertHistoryCallCount++;
    _histories.add(History(
      id: 'fake-history-${_histories.length}',
      routineId: routineId,
      completedAt: DateTime.now().toUtc(),
    ));
  }

  @override
  Future<List<History>> getHistories({int? limit}) async {
    final sorted = List<History>.from(_histories)
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    if (limit != null && sorted.length > limit) {
      return sorted.sublist(0, limit);
    }
    return sorted;
  }
}
