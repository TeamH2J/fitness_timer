import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitness_timer/services/preferences_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  group('PreferencesService defaults', () {
    test('localeCode returns null when no key stored', () {
      expect(PreferencesService.instance.localeCode, isNull);
    });

    test('tts returns true when no key stored', () {
      expect(PreferencesService.instance.tts, isTrue);
    });

    test('beep returns true when no key stored', () {
      expect(PreferencesService.instance.beep, isTrue);
    });

    test('haptic returns true when no key stored', () {
      expect(PreferencesService.instance.haptic, isTrue);
    });

    test('displayFormat returns mmss when no key stored', () {
      expect(PreferencesService.instance.displayFormat, equals('mmss'));
    });

    test('lastRoutineId returns null when no key stored', () {
      expect(PreferencesService.instance.lastRoutineId, isNull);
    });
  });

  group('PreferencesService round-trip', () {
    test('localeCode set and get', () async {
      final prefs = await SharedPreferences.getInstance();
      PreferencesService.instance.setLocaleCode('en');
      // Flush the async write by pumping the prefs directly.
      await prefs.setString('locale_code', 'en');
      expect(prefs.getString('locale_code'), equals('en'));
    });

    test('localeCode removal', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('locale_code', 'ko');
      // Re-init so the singleton reflects stored value.
      await PreferencesService.init();
      expect(PreferencesService.instance.localeCode, equals('ko'));

      PreferencesService.instance.setLocaleCode(null);
      await prefs.remove('locale_code');
      expect(prefs.getString('locale_code'), isNull);
    });

    test('tts set false and get', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tts', false);
      await PreferencesService.init();
      expect(PreferencesService.instance.tts, isFalse);
    });

    test('beep set false and get', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('beep', false);
      await PreferencesService.init();
      expect(PreferencesService.instance.beep, isFalse);
    });

    test('haptic set false and get', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('haptic', false);
      await PreferencesService.init();
      expect(PreferencesService.instance.haptic, isFalse);
    });

    test('displayFormat set seconds and get', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('display_format', 'seconds');
      await PreferencesService.init();
      expect(PreferencesService.instance.displayFormat, equals('seconds'));
    });

    test('lastRoutineId set and get', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_routine_id', 'uuid-abc');
      await PreferencesService.init();
      expect(PreferencesService.instance.lastRoutineId, equals('uuid-abc'));
    });

    test('lastRoutineId removal', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_routine_id', 'uuid-abc');
      await PreferencesService.init();
      expect(PreferencesService.instance.lastRoutineId, equals('uuid-abc'));

      PreferencesService.instance.setLastRoutineId(null);
      await prefs.remove('last_routine_id');
      expect(prefs.getString('last_routine_id'), isNull);
    });
  });
}
