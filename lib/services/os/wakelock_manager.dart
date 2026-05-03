import 'package:wakelock_plus/wakelock_plus.dart';

/// Abstract backend for wakelock operations — enables test injection.
abstract class WakelockBackend {
  Future<void> enable();
  Future<void> disable();
  Future<bool> isEnabled();
}

/// Production backend that calls WakelockPlus directly.
class RealWakelockBackend implements WakelockBackend {
  const RealWakelockBackend();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();

  @override
  Future<bool> isEnabled() => WakelockPlus.enabled;
}

/// Thin wrapper over [WakelockBackend] that never throws.
class WakelockManager {
  WakelockManager({WakelockBackend? backend})
      : _backend = backend ?? const RealWakelockBackend();

  final WakelockBackend _backend;

  Future<void> enable() async {
    try {
      await _backend.enable();
    } catch (_) {
      // Platform may not support wakelock — silent no-op.
    }
  }

  Future<void> disable() async {
    try {
      await _backend.disable();
    } catch (_) {
      // Platform may not support wakelock — silent no-op.
    }
  }

  Future<bool> isEnabled() async {
    try {
      return await _backend.isEnabled();
    } catch (_) {
      return false;
    }
  }
}
