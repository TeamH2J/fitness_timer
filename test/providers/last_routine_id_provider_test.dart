import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitness_timer/providers/settings_provider.dart';
import 'package:fitness_timer/services/preferences_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer();
  }

  group('LastRoutineIdNotifier', () {
    test('initial state is null when nothing stored', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      expect(container.read(lastRoutineIdProvider), isNull);
    });

    test('initial state reads persisted value', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_routine_id', 'existing-uuid');
      await PreferencesService.init();

      final container = makeContainer();
      addTearDown(container.dispose);

      expect(container.read(lastRoutineIdProvider), equals('existing-uuid'));
    });

    test('set updates state', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container.read(lastRoutineIdProvider.notifier).set('uuid-abc');
      expect(container.read(lastRoutineIdProvider), equals('uuid-abc'));
    });

    test('clear resets state to null', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container.read(lastRoutineIdProvider.notifier).set('uuid-abc');
      container.read(lastRoutineIdProvider.notifier).clear();
      expect(container.read(lastRoutineIdProvider), isNull);
    });

    test('set then clear then set again', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container.read(lastRoutineIdProvider.notifier).set('uuid-1');
      container.read(lastRoutineIdProvider.notifier).clear();
      container.read(lastRoutineIdProvider.notifier).set('uuid-2');
      expect(container.read(lastRoutineIdProvider), equals('uuid-2'));
    });

    test('PreferencesService.lastRoutineId updated after set', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container.read(lastRoutineIdProvider.notifier).set('uuid-abc');
      // The in-memory state reflects the value immediately.
      expect(
        PreferencesService.instance.lastRoutineId,
        equals('uuid-abc'),
      );
    });
  });
}
