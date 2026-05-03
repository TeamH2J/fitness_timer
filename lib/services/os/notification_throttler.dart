/// Rate-limits calls to at most once per [minInterval].
///
/// If called more frequently, excess calls are silently dropped.
///
/// [now] is an optional clock factory for testing — defaults to [DateTime.now].
class NotificationThrottler {
  NotificationThrottler({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  DateTime? _lastEmitAt;

  Future<void> throttle(
    Future<void> Function() updateFn, {
    Duration minInterval = const Duration(seconds: 1),
  }) async {
    final now = _now();
    final last = _lastEmitAt;
    if (last != null && now.difference(last) < minInterval) {
      return; // drop — within throttle window
    }
    _lastEmitAt = now;
    await updateFn();
  }
}
