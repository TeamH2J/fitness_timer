import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitness_timer/providers/feedback_provider.dart';
import 'package:fitness_timer/providers/settings_provider.dart';
import 'package:fitness_timer/services/preferences_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  group('feedbackPreferencesProvider derivation', () {
    test('default values match AppSettings defaults', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final prefs = container.read(feedbackPreferencesProvider);
      expect(prefs.tts, isTrue);
      expect(prefs.beep, isTrue);
      expect(prefs.haptic, isTrue);
      expect(prefs.language, equals('ko-KR'));
    });

    test('language is en-US when localeCode is en', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider.notifier).setLocale('en');
      final prefs = container.read(feedbackPreferencesProvider);
      expect(prefs.language, equals('en-US'));
    });

    test('language is ko-KR when localeCode is ko', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider.notifier).setLocale('ko');
      final prefs = container.read(feedbackPreferencesProvider);
      expect(prefs.language, equals('ko-KR'));
    });

    test('language is ko-KR when localeCode is null (system)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider.notifier).setLocale(null);
      final prefs = container.read(feedbackPreferencesProvider);
      expect(prefs.language, equals('ko-KR'));
    });

    test('tts toggle propagates to feedbackPreferences', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider.notifier).setTts(false);
      expect(container.read(feedbackPreferencesProvider).tts, isFalse);
    });

    test('beep toggle propagates to feedbackPreferences', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider.notifier).setBeep(false);
      expect(container.read(feedbackPreferencesProvider).beep, isFalse);
    });

    test('haptic toggle propagates to feedbackPreferences', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider.notifier).setHaptic(false);
      expect(container.read(feedbackPreferencesProvider).haptic, isFalse);
    });
  });
}
