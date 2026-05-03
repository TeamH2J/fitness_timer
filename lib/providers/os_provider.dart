import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/os/app_lifecycle_observer.dart';
import '../services/os/foreground_service_controller.dart';
import '../services/os/notification_throttler.dart';
import '../services/os/platform_info.dart';
import '../services/os/timer_os_bridge.dart';
import '../services/os/wakelock_manager.dart';

final platformInfoProvider = Provider<PlatformInfo>((ref) {
  return const SystemPlatformInfo();
});

final wakelockManagerProvider = Provider<WakelockManager>((ref) {
  return WakelockManager();
});

final notificationThrottlerProvider = Provider<NotificationThrottler>((ref) {
  return NotificationThrottler();
});

final appLifecycleObserverProvider = Provider<AppLifecycleObserver>((ref) {
  final observer = AppLifecycleObserver();
  ref.onDispose(observer.dispose);
  return observer;
});

final foregroundServiceControllerProvider =
    Provider<ForegroundServiceController>((ref) {
  return ForegroundServiceController(
    platform: ref.read(platformInfoProvider),
    throttler: ref.read(notificationThrottlerProvider),
  );
});

final timerOsBridgeProvider = Provider<TimerOsBridge>((ref) {
  final bridge = TimerOsBridge(
    wakelock: ref.read(wakelockManagerProvider),
    foregroundService: ref.read(foregroundServiceControllerProvider),
  );
  ref.onDispose(bridge.detach);
  return bridge;
});

/// Initializes [FlutterForegroundTask] with app-level options.
///
/// Call once at boot inside try/catch. Safe to call on any platform —
/// the underlying plugin is a no-op on non-Android.
void initFlutterForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'fitness_timer_foreground',
      channelName: 'Fitness Timer',
      channelDescription:
          'Shows timer progress while running in background',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      autoRunOnBoot: false,
      allowWakeLock: false,
    ),
  );
}
