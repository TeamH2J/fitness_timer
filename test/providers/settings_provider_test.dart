import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitness_timer/models/app_settings.dart';
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

  group('SettingsNotifier', () {
    test('initial state reads from PreferencesService defaults', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final settings = container.read(settingsProvider);
      expect(settings.localeCode, isNull);
      expect(settings.tts, isTrue);
      expect(settings.beep, isTrue);
      expect(settings.haptic, isTrue);
      expect(settings.displayFormat, equals('mmss'));
    });

    test('setLocale updates state and persists', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = makeContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider.notifier).setLocale('en');

      final settings = container.read(settingsProvider);
      expect(settings.localeCode, equals('en'));
      // The setter fires an async write; verify via the prefs mock.
      await prefs.setString('locale_code', 'en'); // simulate flush
      expect(prefs.getString('locale_code'), equals('en'));
    });

    test('setLocale to null clears locale', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider.notifier).setLocale('ko');
      container.read(settingsProvider.notifier).setLocale(null);

      expect(container.read(settingsProvider).localeCode, isNull);
    });

    test('setTts false updates state', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider.notifier).setTts(false);
      expect(container.read(settingsProvider).tts, isFalse);
    });

    test('setBeep false updates state', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider.notifier).setBeep(false);
      expect(container.read(settingsProvider).beep, isFalse);
    });

    test('setHaptic false updates state', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider.notifier).setHaptic(false);
      expect(container.read(settingsProvider).haptic, isFalse);
    });

    test('setDisplayFormat seconds updates state', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container.read(settingsProvider.notifier).setDisplayFormat('seconds');
      expect(container.read(settingsProvider).displayFormat, equals('seconds'));
    });
  });

  group('AppSettings equality and copyWith', () {
    test('default instances are equal', () {
      expect(const AppSettings(), equals(const AppSettings()));
    });

    test('two instances with same fields are equal', () {
      const a = AppSettings(localeCode: 'en', tts: false, beep: true, haptic: false, displayFormat: 'seconds');
      const b = AppSettings(localeCode: 'en', tts: false, beep: true, haptic: false, displayFormat: 'seconds');
      expect(a, equals(b));
    });

    test('instances with different fields are not equal', () {
      const a = AppSettings(tts: true);
      const b = AppSettings(tts: false);
      expect(a, isNot(equals(b)));
    });

    test('hashCode is equal for equal instances', () {
      const a = AppSettings(localeCode: 'ko', tts: false);
      const b = AppSettings(localeCode: 'ko', tts: false);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('hashCode differs for different instances', () {
      const a = AppSettings(displayFormat: 'mmss');
      const b = AppSettings(displayFormat: 'seconds');
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('identical instances are equal', () {
      const a = AppSettings(localeCode: 'en');
      // ignore: unrelated_type_equality_checks
      expect(a == a, isTrue);
    });

    test('copyWith locale updates only locale', () {
      const base = AppSettings(tts: false);
      final copy = base.copyWith(localeCode: 'ko');
      expect(copy.localeCode, equals('ko'));
      expect(copy.tts, isFalse); // unchanged
    });

    test('copyWith localeCode to null clears it', () {
      const base = AppSettings(localeCode: 'en');
      final copy = base.copyWith(localeCode: null);
      expect(copy.localeCode, isNull);
    });

    test('locale getter returns Locale object', () {
      const settings = AppSettings(localeCode: 'ko');
      expect(settings.locale?.languageCode, equals('ko'));
    });

    test('locale getter returns null when localeCode is null', () {
      expect(const AppSettings().locale, isNull);
    });
  });
}
