import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_timer/services/os/wakelock_manager.dart';

/// Fake backend that tracks call counts and optionally throws.
class _FakeWakelockBackend implements WakelockBackend {
  int enableCalls = 0;
  int disableCalls = 0;
  bool shouldThrow = false;
  bool _enabled = false;

  @override
  Future<void> enable() async {
    if (shouldThrow) throw Exception('platform error');
    enableCalls++;
    _enabled = true;
  }

  @override
  Future<void> disable() async {
    if (shouldThrow) throw Exception('platform error');
    disableCalls++;
    _enabled = false;
  }

  @override
  Future<bool> isEnabled() async {
    if (shouldThrow) throw Exception('platform error');
    return _enabled;
  }
}

void main() {
  group('WakelockManager', () {
    test('enable() delegates to backend', () async {
      final backend = _FakeWakelockBackend();
      final manager = WakelockManager(backend: backend);

      await manager.enable();

      expect(backend.enableCalls, 1);
    });

    test('disable() delegates to backend', () async {
      final backend = _FakeWakelockBackend();
      final manager = WakelockManager(backend: backend);

      await manager.disable();

      expect(backend.disableCalls, 1);
    });

    test('isEnabled() returns true after enable', () async {
      final backend = _FakeWakelockBackend();
      final manager = WakelockManager(backend: backend);

      await manager.enable();
      final result = await manager.isEnabled();

      expect(result, isTrue);
    });

    test('enable() swallows backend exception — does not throw', () async {
      final backend = _FakeWakelockBackend()..shouldThrow = true;
      final manager = WakelockManager(backend: backend);

      // Must not throw.
      await expectLater(manager.enable(), completes);
    });

    test('disable() swallows backend exception — does not throw', () async {
      final backend = _FakeWakelockBackend()..shouldThrow = true;
      final manager = WakelockManager(backend: backend);

      await expectLater(manager.disable(), completes);
    });

    test('isEnabled() returns false when backend throws', () async {
      final backend = _FakeWakelockBackend()..shouldThrow = true;
      final manager = WakelockManager(backend: backend);

      final result = await manager.isEnabled();

      expect(result, isFalse);
    });

    test('multiple enable/disable cycles work correctly', () async {
      final backend = _FakeWakelockBackend();
      final manager = WakelockManager(backend: backend);

      await manager.enable();
      await manager.disable();
      await manager.enable();

      expect(backend.enableCalls, 2);
      expect(backend.disableCalls, 1);
    });
  });
}
