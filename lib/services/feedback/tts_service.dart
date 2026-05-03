import 'package:flutter_tts/flutter_tts.dart';

/// Wraps [FlutterTts] with lazy initialization and silent error handling.
/// All platform calls are wrapped in try/catch — failures are NO-OPs.
class TtsService {
  FlutterTts? _tts;

  FlutterTts get _engine {
    _tts ??= FlutterTts();
    return _tts!;
  }

  /// Pre-initialises the TTS engine to reduce first-speak latency.
  Future<void> warmUp() async {
    try {
      await _engine.setLanguage('ko-KR');
      await _engine.setSpeechRate(0.5);
      // Invoke speak with empty string to warm up the engine.
      // Errors are swallowed intentionally.
      await _engine.speak('');
    } catch (_) {
      // Silent NO-OP — warm-up failure does not block app startup.
    }
  }

  /// Stops any current utterance then speaks [text].
  Future<void> speak(String text) async {
    try {
      await _engine.stop();
      await _engine.speak(text);
    } catch (_) {
      // Silent NO-OP.
    }
  }

  /// Halts the current utterance immediately.
  Future<void> stop() async {
    try {
      await _engine.stop();
    } catch (_) {}
  }

  /// Switches TTS language; takes effect on the next [speak] call.
  Future<void> setLanguage(String lang) async {
    try {
      await _engine.setLanguage(lang);
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _tts?.stop();
    } catch (_) {}
    _tts = null;
  }
}
