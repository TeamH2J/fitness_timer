import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around [SharedPreferences].
///
/// Call [init] once in main() before runApp. If [init] is never called the
/// service falls back to an in-memory map so that widgets and providers that
/// run before [init] (e.g. in tests) don't crash. A debug warning is printed
/// when the fallback is used.
class PreferencesService {
  static PreferencesService? _instance;

  /// Backing store — either a real [SharedPreferences] or null when using the
  /// in-memory fallback.
  final SharedPreferences? _prefs;

  /// In-memory fallback used when [_prefs] is null.
  final Map<String, Object> _memory;

  PreferencesService._(this._prefs) : _memory = {};

  /// Creates an in-memory-only instance used as a fallback when [init] was
  /// never called.
  PreferencesService._inMemory()
      : _prefs = null,
        _memory = {};

  static const String _keyLocaleCode = 'locale_code';
  static const String _keyTts = 'tts';
  static const String _keyBeep = 'beep';
  static const String _keyHaptic = 'haptic';
  static const String _keyDisplayFormat = 'display_format';
  static const String _keyLastRoutineId = 'last_routine_id';

  /// Must be called once in main() before runApp.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _instance = PreferencesService._(prefs);
  }

  /// Returns the singleton. If [init] was never called an in-memory fallback
  /// is returned and a warning is printed in debug mode.
  static PreferencesService get instance {
    if (_instance == null) {
      debugPrint(
        'PreferencesService: init() was not called before accessing instance. '
        'Using in-memory fallback — data will not be persisted.',
      );
      _instance = PreferencesService._inMemory();
    }
    return _instance!;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  String? _getString(String key) =>
      _prefs != null ? _prefs.getString(key) : _memory[key] as String?;

  bool _getBool(String key, {required bool defaultValue}) =>
      _prefs != null
          ? (_prefs.getBool(key) ?? defaultValue)
          : (_memory[key] as bool? ?? defaultValue);

  Future<void> _setString(String key, String value) async {
    if (_prefs != null) {
      final ok = await _prefs.setString(key, value);
      if (!ok) debugPrint('PreferencesService: set $key failed');
    } else {
      _memory[key] = value;
    }
  }

  Future<void> _removeKey(String key) async {
    if (_prefs != null) {
      final ok = await _prefs.remove(key);
      if (!ok) debugPrint('PreferencesService: remove $key failed');
    } else {
      _memory.remove(key);
    }
  }

  Future<void> _setBool(String key, bool value) async {
    if (_prefs != null) {
      final ok = await _prefs.setBool(key, value);
      if (!ok) debugPrint('PreferencesService: set $key failed');
    } else {
      _memory[key] = value;
    }
  }

  // ---------------------------------------------------------------------------
  // localeCode
  // ---------------------------------------------------------------------------

  String? get localeCode => _getString(_keyLocaleCode);

  void setLocaleCode(String? v) {
    if (v == null) {
      _removeKey(_keyLocaleCode);
    } else {
      _setString(_keyLocaleCode, v);
    }
  }

  // ---------------------------------------------------------------------------
  // tts
  // ---------------------------------------------------------------------------

  bool get tts => _getBool(_keyTts, defaultValue: true);

  void setTts(bool v) => _setBool(_keyTts, v);

  // ---------------------------------------------------------------------------
  // beep
  // ---------------------------------------------------------------------------

  bool get beep => _getBool(_keyBeep, defaultValue: true);

  void setBeep(bool v) => _setBool(_keyBeep, v);

  // ---------------------------------------------------------------------------
  // haptic
  // ---------------------------------------------------------------------------

  bool get haptic => _getBool(_keyHaptic, defaultValue: true);

  void setHaptic(bool v) => _setBool(_keyHaptic, v);

  // ---------------------------------------------------------------------------
  // displayFormat
  // ---------------------------------------------------------------------------

  String get displayFormat => _getString(_keyDisplayFormat) ?? 'mmss';

  void setDisplayFormat(String v) => _setString(_keyDisplayFormat, v);

  // ---------------------------------------------------------------------------
  // lastRoutineId
  // ---------------------------------------------------------------------------

  String? get lastRoutineId => _getString(_keyLastRoutineId);

  void setLastRoutineId(String? v) {
    if (v == null) {
      _removeKey(_keyLastRoutineId);
    } else {
      _setString(_keyLastRoutineId, v);
    }
  }
}
