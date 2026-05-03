import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_timer/services/os/notification_throttler.dart';

/// Fake clock that can be manually advanced.
class _FakeClock {
  DateTime _now;

  _FakeClock(this._now);

  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);
}

void main() {
  group('NotificationThrottler', () {
    test('first call is always forwarded', () async {
      final throttler = NotificationThrottler();
      int callCount = 0;

      await throttler.throttle(() async => callCount++);

      expect(callCount, 1);
    });

    test('second call within 1s window is dropped', () async {
      final clock = _FakeClock(DateTime(2024));
      final throttler = NotificationThrottler(now: clock.now);
      int callCount = 0;

      await throttler.throttle(() async => callCount++);
      expect(callCount, 1);

      clock.advance(const Duration(milliseconds: 500));
      await throttler.throttle(() async => callCount++);
      expect(callCount, 1); // dropped
    });

    test('10 calls at 100ms intervals → only first is forwarded', () async {
      final clock = _FakeClock(DateTime(2024));
      final throttler = NotificationThrottler(now: clock.now);
      int callCount = 0;

      for (int i = 0; i < 10; i++) {
        await throttler.throttle(() async => callCount++);
        clock.advance(const Duration(milliseconds: 100));
      }

      // After 9 advances of 100ms, we're at 900ms — still within window.
      // Only the first call (at t=0) passes; all subsequent are within 1s.
      expect(callCount, 1);
    });

    test('call after 1 second window is forwarded again', () async {
      final clock = _FakeClock(DateTime(2024));
      final throttler = NotificationThrottler(now: clock.now);
      int callCount = 0;

      await throttler.throttle(() async => callCount++);
      expect(callCount, 1);

      clock.advance(const Duration(milliseconds: 500));
      await throttler.throttle(() async => callCount++);
      expect(callCount, 1); // within window — dropped

      clock.advance(const Duration(milliseconds: 600)); // total: 1100ms
      await throttler.throttle(() async => callCount++);
      expect(callCount, 2); // 1100ms elapsed — passes
    });

    test('burst of calls within 1s — only first passes', () async {
      final clock = _FakeClock(DateTime(2024));
      final throttler = NotificationThrottler(now: clock.now);
      int callCount = 0;

      for (int i = 0; i < 5; i++) {
        await throttler.throttle(() async => callCount++);
        clock.advance(const Duration(milliseconds: 50));
      }

      // 5 * 50ms = 250ms total — all within 1s window.
      expect(callCount, 1);
    });

    test('custom minInterval is respected', () async {
      final clock = _FakeClock(DateTime(2024));
      final throttler = NotificationThrottler(now: clock.now);
      int callCount = 0;
      const interval = Duration(milliseconds: 500);

      await throttler.throttle(() async => callCount++, minInterval: interval);
      expect(callCount, 1);

      clock.advance(const Duration(milliseconds: 300));
      await throttler.throttle(() async => callCount++, minInterval: interval);
      expect(callCount, 1); // still within 500ms

      clock.advance(const Duration(milliseconds: 300)); // total: 600ms
      await throttler.throttle(() async => callCount++, minInterval: interval);
      expect(callCount, 2); // 600ms elapsed — passes
    });

    test('multiple independent throttlers do not interfere', () async {
      final clock = _FakeClock(DateTime(2024));
      final t1 = NotificationThrottler(now: clock.now);
      final t2 = NotificationThrottler(now: clock.now);
      int c1 = 0;
      int c2 = 0;

      await t1.throttle(() async => c1++);
      await t2.throttle(() async => c2++);

      expect(c1, 1);
      expect(c2, 1);
    });
  });
}
