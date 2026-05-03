import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'notification_throttler.dart';
import 'platform_info.dart';

/// Abstract backend for foreground service calls — enables test injection.
abstract class ForegroundBackend {
  Future<void> startService({
    required String notificationTitle,
    required String notificationText,
  });

  Future<void> updateService({
    required String notificationTitle,
    required String notificationText,
  });

  Future<void> stopService();
}

/// Production backend that delegates to [FlutterForegroundTask].
class RealForegroundBackend implements ForegroundBackend {
  const RealForegroundBackend();

  @override
  Future<void> startService({
    required String notificationTitle,
    required String notificationText,
  }) async {
    await FlutterForegroundTask.startService(
      notificationTitle: notificationTitle,
      notificationText: notificationText,
    );
  }

  @override
  Future<void> updateService({
    required String notificationTitle,
    required String notificationText,
  }) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: notificationTitle,
      notificationText: notificationText,
    );
  }

  @override
  Future<void> stopService() async {
    await FlutterForegroundTask.stopService();
  }
}

/// Controls the Android foreground service lifecycle.
///
/// All methods are no-ops on iOS (per v1.0 scope — iOS uses
/// UIBackgroundModes:audio instead of a foreground service).
/// All platform calls are wrapped in try/catch and never throw.
class ForegroundServiceController {
  ForegroundServiceController({
    required PlatformInfo platform,
    required NotificationThrottler throttler,
    ForegroundBackend? backend,
  })  : _platform = platform,
        _throttler = throttler,
        _backend = backend ?? const RealForegroundBackend();

  final PlatformInfo _platform;
  final NotificationThrottler _throttler;
  final ForegroundBackend _backend;

  /// Starts the foreground service. Android-only; no-op on iOS.
  Future<void> start({
    required String title,
    required String content,
  }) async {
    if (!_platform.isAndroid) return;
    try {
      await _backend.startService(
        notificationTitle: title,
        notificationText: content,
      );
    } catch (_) {
      // Silent — service unavailable or permission denied.
    }
  }

  /// Updates the ongoing notification, rate-limited to once per second.
  /// Android-only; no-op on iOS.
  Future<void> updateNotification({
    required String title,
    required String content,
  }) async {
    if (!_platform.isAndroid) return;
    try {
      await _throttler.throttle(() async {
        await _backend.updateService(
          notificationTitle: title,
          notificationText: content,
        );
      });
    } catch (_) {
      // Silent — service unavailable or permission denied.
    }
  }

  /// Stops the foreground service. Android-only; no-op on iOS.
  Future<void> stop() async {
    if (!_platform.isAndroid) return;
    try {
      await _backend.stopService();
    } catch (_) {
      // Silent — service may already be stopped.
    }
  }
}
