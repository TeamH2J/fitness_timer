import 'package:vibration/vibration.dart';

/// Abstracts OS vibration APIs behind phase-semantic methods.
/// All calls are guarded by [Vibration.hasVibrator] and wrapped in try/catch.
class HapticService {
  /// Short 40 ms pulse on phase start.
  Future<void> phaseStart() async {
    try {
      if (!await Vibration.hasVibrator()) return;
      await Vibration.vibrate(duration: 40);
    } catch (_) {}
  }

  /// Double 80 ms pulses with 80 ms gap on phase end.
  Future<void> phaseEnd() async {
    try {
      if (!await Vibration.hasVibrator()) return;
      await Vibration.vibrate(pattern: [0, 80, 80, 80]);
    } catch (_) {}
  }

  /// Single 200 ms long pulse on routine complete.
  Future<void> routineComplete() async {
    try {
      if (!await Vibration.hasVibrator()) return;
      await Vibration.vibrate(duration: 200);
    } catch (_) {}
  }
}
