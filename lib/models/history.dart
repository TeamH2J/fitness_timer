class History {
  final String id;
  final String routineId;
  final DateTime completedAt;

  const History({
    required this.id,
    required this.routineId,
    required this.completedAt,
  });

  factory History.fromMap(Map<String, dynamic> map) {
    return History(
      id: map['id'] as String,
      routineId: map['routine_id'] as String,
      completedAt: DateTime.parse(map['completed_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'routine_id': routineId,
      'completed_at': completedAt.toIso8601String(),
    };
  }
}
