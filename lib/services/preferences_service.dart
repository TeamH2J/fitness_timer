import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around [SharedPreferences].
/// Call [init] once in main() before runApp.
class PreferencesService {
  static PreferencesService? _instance;
  final SharedPreferences _prefs;

  PreferencesService._(this._prefs);

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

  static PreferencesService get instance {
    assert(_instance != null,
        'PreferencesService.init() must be called before accessing instance.');
    return _instance!;
  }

  // --- localeCode ---
  String? get localeCode => _prefs.getString(_keyLocaleCode);
  void setLocaleCode(String? v) {
    if (v == null) {
      _prefs.remove(_keyLocaleCode).then((ok) {
        if (!ok) debugPrint('PreferencesService: remove $_keyLocaleCode failed');
      });
    } else {
      _prefs.setString(_keyLocaleCode, v).then((ok) {
        if (!ok) debugPrint('PreferencesService: set $_keyLocaleCode failed');
      });
    }
  }

  // --- tts ---
  bool get tts => _prefs.getBool(_keyTts) ?? true;
  void setTts(bool v) {
    _prefs.setBool(_keyTts, v).then((ok) {
      if (!ok) debugPrint('PreferencesService: set $_keyTts failed');
    });
  }

  // --- beep ---
  bool get beep => _prefs.getBool(_keyBeep) ?? true;
  void setBeep(bool v) {
    _prefs.setBool(_keyBeep, v).then((ok) {
      if (!ok) debugPrint('PreferencesService: set $_keyBeep failed');
    });
  }

  // --- haptic ---
  bool get haptic => _prefs.getBool(_keyHaptic) ?? true;
  void setHaptic(bool v) {
    _prefs.setBool(_keyHaptic, v).then((ok) {
      if (!ok) debugPrint('PreferencesService: set $_keyHaptic failed');
    });
  }

  // --- displayFormat ---
  String get displayFormat => _prefs.getString(_keyDisplayFormat) ?? 'mmss';
  void setDisplayFormat(String v) {
    _prefs.setString(_keyDisplayFormat, v).then((ok) {
      if (!ok) debugPrint('PreferencesService: set $_keyDisplayFormat failed');
    });
  }

  // --- lastRoutineId ---
  String? get lastRoutineId => _prefs.getString(_keyLastRoutineId);
  void setLastRoutineId(String? v) {
    if (v == null) {
      _prefs.remove(_keyLastRoutineId).then((ok) {
        if (!ok) {
          debugPrint('PreferencesService: remove $_keyLastRoutineId failed');
        }
      });
    } else {
      _prefs.setString(_keyLastRoutineId, v).then((ok) {
        if (!ok) {
          debugPrint('PreferencesService: set $_keyLastRoutineId failed');
        }
      });
    }
  }
}
