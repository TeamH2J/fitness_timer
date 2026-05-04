enum ExerciseType {
  // ignore: constant_identifier_names
  WORK_TIME,
  // ignore: constant_identifier_names
  WORK_REPS,
  // ignore: constant_identifier_names
  REST;

  /// Returns the DB storage string ('WORK_TIME', 'WORK_REPS', 'REST').
  String toDb() => name;

  static ExerciseType fromDb(String value) => ExerciseType.values.byName(value);
}

class ExerciseItem {
  final String id;
  final String routineId;
  final int orderIndex;
  final ExerciseType type;
  final int duration;
  final int? targetReps;
  final String name;
  final int restSeconds;

  const ExerciseItem({
    required this.id,
    required this.routineId,
    required this.orderIndex,
    required this.type,
    required this.duration,
    this.targetReps,
    required this.name,
    this.restSeconds = 0,
  });

  factory ExerciseItem.fromMap(Map<String, dynamic> map) {
    return ExerciseItem(
      id: map['id'] as String,
      routineId: map['routine_id'] as String,
      orderIndex: map['order_index'] as int,
      type: ExerciseType.fromDb(map['type'] as String),
      duration: map['duration'] as int,
      targetReps: map['target_reps'] as int?,
      name: map['name'] as String,
      restSeconds: (map['rest_seconds'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'routine_id': routineId,
      'order_index': orderIndex,
      'type': type.toDb(),
      'duration': duration,
      'target_reps': targetReps,
      'name': name,
      'rest_seconds': restSeconds,
    };
  }

  ExerciseItem copyWith({
    String? id,
    String? routineId,
    int? orderIndex,
    ExerciseType? type,
    int? duration,
    int? targetReps,
    String? name,
    int? restSeconds,
  }) {
    return ExerciseItem(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      orderIndex: orderIndex ?? this.orderIndex,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      targetReps: targetReps ?? this.targetReps,
      name: name ?? this.name,
      restSeconds: restSeconds ?? this.restSeconds,
    );
  }
}
