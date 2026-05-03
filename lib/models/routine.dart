class Routine {
  final String id;
  final String title;
  final int prepTime;
  final int cooldownTime;
  final int totalCycles;

  const Routine({
    required this.id,
    required this.title,
    this.prepTime = 0,
    this.cooldownTime = 0,
    this.totalCycles = 1,
  });

  factory Routine.fromMap(Map<String, dynamic> map) {
    return Routine(
      id: map['id'] as String,
      title: map['title'] as String,
      prepTime: map['prep_time'] as int,
      cooldownTime: map['cooldown_time'] as int,
      totalCycles: map['total_cycles'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'prep_time': prepTime,
      'cooldown_time': cooldownTime,
      'total_cycles': totalCycles,
    };
  }

  Routine copyWith({
    String? id,
    String? title,
    int? prepTime,
    int? cooldownTime,
    int? totalCycles,
  }) {
    return Routine(
      id: id ?? this.id,
      title: title ?? this.title,
      prepTime: prepTime ?? this.prepTime,
      cooldownTime: cooldownTime ?? this.cooldownTime,
      totalCycles: totalCycles ?? this.totalCycles,
    );
  }
}
