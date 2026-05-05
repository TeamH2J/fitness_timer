import 'package:uuid/uuid.dart';

enum StopwatchState { idle, running, paused }

/// A single completed lap segment.
class LapRecord {
  final int number;
  final int lapMs;
  final int totalMs;

  const LapRecord({
    required this.number,
    required this.lapMs,
    required this.totalMs,
  });

  Map<String, Object?> toMap({String? sessionId, String? id}) => {
        'id': id ?? const Uuid().v4(),
        'session_id': sessionId ?? '',
        'lap_number': number,
        'lap_ms': lapMs,
        'total_ms': totalMs,
      };

  factory LapRecord.fromMap(Map<String, Object?> map) {
    return LapRecord(
      number: map['lap_number'] as int,
      lapMs: map['lap_ms'] as int,
      totalMs: map['total_ms'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LapRecord &&
      number == other.number &&
      lapMs == other.lapMs &&
      totalMs == other.totalMs;

  @override
  int get hashCode => Object.hash(number, lapMs, totalMs);
}

/// In-memory snapshot emitted by [StopwatchEngine] on every tick.
class StopwatchSnapshot {
  final StopwatchState state;
  final int elapsedMs;
  final int currentLapMs;
  final List<LapRecord> laps;

  const StopwatchSnapshot({
    required this.state,
    required this.elapsedMs,
    required this.currentLapMs,
    required this.laps,
  });

  static StopwatchSnapshot get initial => const StopwatchSnapshot(
        state: StopwatchState.idle,
        elapsedMs: 0,
        currentLapMs: 0,
        laps: [],
      );
}

/// Persisted record of a stopwatch session (returned by reset()).
class StopwatchSession {
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int totalMs;
  final List<LapRecord> laps;
  final String? label;

  const StopwatchSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.totalMs,
    required this.laps,
    this.label,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
        'total_ms': totalMs,
        'label': label,
      };

  factory StopwatchSession.fromMap(
    Map<String, Object?> map,
    List<LapRecord> laps,
  ) {
    return StopwatchSession(
      id: map['id'] as String,
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: DateTime.parse(map['ended_at'] as String),
      totalMs: map['total_ms'] as int,
      laps: laps,
      label: map['label'] as String?,
    );
  }

  StopwatchSession copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? endedAt,
    int? totalMs,
    List<LapRecord>? laps,
    Object? label = _sentinel,
  }) {
    return StopwatchSession(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      totalMs: totalMs ?? this.totalMs,
      laps: laps ?? this.laps,
      label: label == _sentinel ? this.label : label as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StopwatchSession &&
      id == other.id &&
      startedAt == other.startedAt &&
      endedAt == other.endedAt &&
      totalMs == other.totalMs &&
      label == other.label &&
      _listsEqual(laps, other.laps);

  @override
  int get hashCode => Object.hash(id, startedAt, endedAt, totalMs, label);

  static bool _listsEqual(List<LapRecord> a, List<LapRecord> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

const Object _sentinel = Object();

/// Unified history entry for the merged history view.
enum HistoryEntryType { interval, stopwatch }

class HistoryEntry {
  final String id;
  final HistoryEntryType type;
  final DateTime timestamp;
  final String? title;
  final int? totalMs;
  final int? lapCount;
  final String? label;

  const HistoryEntry({
    required this.id,
    required this.type,
    required this.timestamp,
    this.title,
    this.totalMs,
    this.lapCount,
    this.label,
  });
}
