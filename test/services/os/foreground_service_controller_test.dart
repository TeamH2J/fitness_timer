import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_timer/services/os/foreground_service_controller.dart';
import 'package:fitness_timer/services/os/notification_throttler.dart';
import 'package:fitness_timer/services/os/platform_info.dart';

/// Spy backend that records calls.
class _SpyForegroundBackend implements ForegroundBackend {
  final List<String> calls = [];
  String? lastStartTitle;
  String? lastStartText;
  String? lastUpdateTitle;
  String? lastUpdateText;

  @override
  Future<void> startService({
    required String notificationTitle,
    required String notificationText,
  }) async {
    calls.add('start');
    lastStartTitle = notificationTitle;
    lastStartText = notificationText;
  }

  @override
  Future<void> updateService({
    required String notificationTitle,
    required String notificationText,
  }) async {
    calls.add('update');
    lastUpdateTitle = notificationTitle;
    lastUpdateText = notificationText;
  }

  @override
  Future<void> stopService() async {
    calls.add('stop');
  }
}

void main() {
  group('ForegroundServiceController — iOS no-op', () {
    late _SpyForegroundBackend backend;
    late ForegroundServiceController controller;

    setUp(() {
      backend = _SpyForegroundBackend();
      controller = ForegroundServiceController(
        platform: FakePlatformInfo(isAndroid: false, isIOS: true),
        throttler: NotificationThrottler(),
        backend: backend,
      );
    });

    test('start() does not call backend on iOS', () async {
      await controller.start(title: 'T', content: 'C');
      expect(backend.calls, isEmpty);
    });

    test('updateNotification() does not call backend on iOS', () async {
      await controller.updateNotification(title: 'T', content: 'C');
      expect(backend.calls, isEmpty);
    });

    test('stop() does not call backend on iOS', () async {
      await controller.stop();
      expect(backend.calls, isEmpty);
    });
  });

  group('ForegroundServiceController — Android', () {
    late _SpyForegroundBackend backend;
    late ForegroundServiceController controller;

    setUp(() {
      backend = _SpyForegroundBackend();
      controller = ForegroundServiceController(
        platform: FakePlatformInfo(isAndroid: true, isIOS: false),
        throttler: NotificationThrottler(),
        backend: backend,
      );
    });

    test('start() calls backend.startService with correct args', () async {
      await controller.start(title: 'Fitness Timer', content: 'Push-ups');

      expect(backend.calls, contains('start'));
      expect(backend.lastStartTitle, 'Fitness Timer');
      expect(backend.lastStartText, 'Push-ups');
    });

    test('stop() calls backend.stopService', () async {
      await controller.stop();
      expect(backend.calls, contains('stop'));
    });

    test('updateNotification() calls backend.updateService (first call passes)',
        () async {
      await controller.updateNotification(
          title: 'Fitness Timer', content: 'Rest');

      expect(backend.calls, contains('update'));
      expect(backend.lastUpdateTitle, 'Fitness Timer');
      expect(backend.lastUpdateText, 'Rest');
    });

    test('updateNotification() throttles rapid calls — second call dropped',
        () async {
      await controller.updateNotification(title: 'T1', content: 'C1');
      await controller.updateNotification(title: 'T2', content: 'C2');

      // Only the first call goes through because throttle window hasn't elapsed.
      expect(backend.calls.where((c) => c == 'update').length, 1);
    });

    test('backend exception in start() is swallowed', () async {
      final throwingBackend = _ThrowingForegroundBackend();
      final ctrl = ForegroundServiceController(
        platform: FakePlatformInfo(isAndroid: true, isIOS: false),
        throttler: NotificationThrottler(),
        backend: throwingBackend,
      );
      await expectLater(
          ctrl.start(title: 'T', content: 'C'), completes);
    });

    test('backend exception in stop() is swallowed', () async {
      final throwingBackend = _ThrowingForegroundBackend();
      final ctrl = ForegroundServiceController(
        platform: FakePlatformInfo(isAndroid: true, isIOS: false),
        throttler: NotificationThrottler(),
        backend: throwingBackend,
      );
      await expectLater(ctrl.stop(), completes);
    });
  });
}

class _ThrowingForegroundBackend implements ForegroundBackend {
  @override
  Future<void> startService(
          {required String notificationTitle,
          required String notificationText}) async =>
      throw Exception('platform error');

  @override
  Future<void> updateService(
          {required String notificationTitle,
          required String notificationText}) async =>
      throw Exception('platform error');

  @override
  Future<void> stopService() async => throw Exception('platform error');
}
