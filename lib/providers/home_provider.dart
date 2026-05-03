import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/routine.dart';
import 'database_provider.dart';

final allRoutinesProvider = FutureProvider<List<Routine>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return db.getAllRoutines();
});

/// Returns item count for a given routineId.
final routineItemCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, routineId) async {
  final db = ref.watch(databaseServiceProvider);
  final items = await db.getExerciseItems(routineId);
  return items.length;
});

/// Returns total estimated seconds for a given routineId.
final routineTotalSecondsProvider =
    FutureProvider.autoDispose.family<int, String>((ref, routineId) async {
  final db = ref.watch(databaseServiceProvider);
  final items = await db.getExerciseItems(routineId);
  return items.fold<int>(0, (sum, item) => sum + item.duration);
});

/// Provider to force-refresh the routines list (toggle a counter).
final routinesRefreshProvider = StateProvider<int>((ref) => 0);

/// Refreshable routines — watches [routinesRefreshProvider] to allow manual
/// invalidation from the HomePage after add / delete.
final refreshableRoutinesProvider = FutureProvider<List<Routine>>((ref) async {
  ref.watch(routinesRefreshProvider);
  final db = ref.watch(databaseServiceProvider);
  return db.getAllRoutines();
});
