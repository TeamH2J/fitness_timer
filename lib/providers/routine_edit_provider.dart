import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/exercise_item.dart';
import '../models/routine.dart';
import '../services/database_service.dart';
import 'database_provider.dart';

class RoutineEditState {
  final String routineId;
  final String title;
  final int prepTime;
  final int cooldownTime;
  final int totalCycles;
  final List<ExerciseItem> items;
  final bool isSaving;
  final String? error;

  const RoutineEditState({
    required this.routineId,
    required this.title,
    required this.prepTime,
    required this.cooldownTime,
    required this.totalCycles,
    required this.items,
    this.isSaving = false,
    this.error,
  });

  RoutineEditState copyWith({
    String? routineId,
    String? title,
    int? prepTime,
    int? cooldownTime,
    int? totalCycles,
    List<ExerciseItem>? items,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return RoutineEditState(
      routineId: routineId ?? this.routineId,
      title: title ?? this.title,
      prepTime: prepTime ?? this.prepTime,
      cooldownTime: cooldownTime ?? this.cooldownTime,
      totalCycles: totalCycles ?? this.totalCycles,
      items: items ?? this.items,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RoutineEditNotifier extends StateNotifier<RoutineEditState> {
  final DatabaseService _db;

  RoutineEditNotifier(this._db, String? existingRoutineId)
      : super(RoutineEditState(
          routineId: existingRoutineId ?? const Uuid().v4(),
          title: '',
          prepTime: 0,
          cooldownTime: 0,
          totalCycles: 1,
          items: const [],
        )) {
    if (existingRoutineId != null) {
      _loadExisting(existingRoutineId);
    }
  }

  Future<void> _loadExisting(String routineId) async {
    try {
      final routine = await _db.getRoutine(routineId);
      if (routine == null) return;
      final items = await _db.getExerciseItems(routineId);
      state = state.copyWith(
        routineId: routine.id,
        title: routine.title,
        prepTime: routine.prepTime,
        cooldownTime: routine.cooldownTime,
        totalCycles: routine.totalCycles,
        items: items,
      );
    } catch (_) {
      // Silent — editing proceeds with defaults.
    }
  }

  void setTitle(String value) => state = state.copyWith(title: value);

  void setPrepTime(int value) =>
      state = state.copyWith(prepTime: value.clamp(0, 60));

  void setCooldownTime(int value) =>
      state = state.copyWith(cooldownTime: value.clamp(0, 120));

  void setTotalCycles(int value) =>
      state = state.copyWith(totalCycles: value.clamp(1, 10));

  void addItem() {
    final newItem = ExerciseItem(
      id: const Uuid().v4(),
      routineId: state.routineId,
      orderIndex: state.items.length,
      type: ExerciseType.WORK_TIME,
      duration: 30,
      name: '',
    );
    state = state.copyWith(items: [...state.items, newItem]);
  }

  void updateItem(int index, ExerciseItem item) {
    final updated = List<ExerciseItem>.from(state.items);
    updated[index] = item;
    state = state.copyWith(items: updated);
  }

  void removeItem(int index) {
    final updated = List<ExerciseItem>.from(state.items)..removeAt(index);
    final reindexed = [
      for (var i = 0; i < updated.length; i++)
        updated[i].copyWith(orderIndex: i),
    ];
    state = state.copyWith(items: reindexed);
  }

  void reorderItems(int oldIndex, int newIndex) {
    final updated = List<ExerciseItem>.from(state.items);
    if (newIndex > oldIndex) newIndex--;
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    final reindexed = [
      for (var i = 0; i < updated.length; i++)
        updated[i].copyWith(orderIndex: i),
    ];
    state = state.copyWith(items: reindexed);
  }

  /// Returns true on success, false on failure.
  Future<bool> save() async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final routine = Routine(
        id: state.routineId,
        title: state.title.trim(),
        prepTime: state.prepTime,
        cooldownTime: state.cooldownTime,
        totalCycles: state.totalCycles,
      );
      final items = [
        for (var i = 0; i < state.items.length; i++)
          state.items[i].copyWith(routineId: state.routineId, orderIndex: i),
      ];
      await _db.upsertRoutineWithItems(routine, items);
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }
}

final routineEditProvider = StateNotifierProvider.autoDispose
    .family<RoutineEditNotifier, RoutineEditState, String?>(
  (ref, routineId) {
    final db = ref.read(databaseServiceProvider);
    return RoutineEditNotifier(db, routineId);
  },
);
