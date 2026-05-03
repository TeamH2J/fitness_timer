import 'package:fitness_timer/models/feedback_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeedbackPreferences', () {
    test('default constructor has expected field values', () {
      const prefs = FeedbackPreferences();
      expect(prefs.tts, isTrue);
      expect(prefs.beep, isTrue);
      expect(prefs.haptic, isTrue);
      expect(prefs.language, equals('ko-KR'));
    });

    test('copyWith updates only the specified field', () {
      const original = FeedbackPreferences();

      final noTts = original.copyWith(tts: false);
      expect(noTts.tts, isFalse);
      expect(noTts.beep, isTrue);
      expect(noTts.haptic, isTrue);
      expect(noTts.language, equals('ko-KR'));

      final noBeep = original.copyWith(beep: false);
      expect(noBeep.beep, isFalse);
      expect(noBeep.tts, isTrue);

      final noHaptic = original.copyWith(haptic: false);
      expect(noHaptic.haptic, isFalse);
      expect(noHaptic.tts, isTrue);

      final enLang = original.copyWith(language: 'en-US');
      expect(enLang.language, equals('en-US'));
      expect(enLang.tts, isTrue);
    });

    test('copyWith does not mutate the original', () {
      const original = FeedbackPreferences();
      original.copyWith(tts: false, beep: false, haptic: false);
      // Original remains unchanged.
      expect(original.tts, isTrue);
      expect(original.beep, isTrue);
      expect(original.haptic, isTrue);
    });

    test('equality: two instances with same values are equal', () {
      const a = FeedbackPreferences(tts: false, language: 'en-US');
      const b = FeedbackPreferences(tts: false, language: 'en-US');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality: instances with different values are not equal', () {
      const a = FeedbackPreferences();
      const b = FeedbackPreferences(tts: false);
      expect(a, isNot(equals(b)));
    });
  });
}
