import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../services/preferences_service.dart';

// ---------------------------------------------------------------------------
// tabIndexProvider — 0: Routines, 1: Timer, 2: Settings
// ---------------------------------------------------------------------------

final tabIndexProvider = StateProvider<int>((ref) => 0);

// ---------------------------------------------------------------------------
// SettingsNotifier + settingsProvider
// ---------------------------------------------------------------------------

class SettingsNotifier extends StateNotifier<AppSettings> {
  final PreferencesService _prefs;

  SettingsNotifier(this._prefs)
      : super(AppSettings(
          localeCode: _prefs.localeCode,
          tts: _prefs.tts,
          beep: _prefs.beep,
          haptic: _prefs.haptic,
          displayFormat: _prefs.displayFormat,
        ));

  void setLocale(String? code) {
    _prefs.setLocaleCode(code);
    state = state.copyWith(localeCode: code);
  }

  void setTts(bool v) {
    _prefs.setTts(v);
    state = state.copyWith(tts: v);
  }

  void setBeep(bool v) {
    _prefs.setBeep(v);
    state = state.copyWith(beep: v);
  }

  void setHaptic(bool v) {
    _prefs.setHaptic(v);
    state = state.copyWith(haptic: v);
  }

  void setDisplayFormat(String format) {
    _prefs.setDisplayFormat(format);
    state = state.copyWith(displayFormat: format);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(PreferencesService.instance);
});

// ---------------------------------------------------------------------------
// LastRoutineIdNotifier + lastRoutineIdProvider
// ---------------------------------------------------------------------------

class LastRoutineIdNotifier extends StateNotifier<String?> {
  final PreferencesService _prefs;

  LastRoutineIdNotifier(this._prefs) : super(_prefs.lastRoutineId);

  void set(String id) {
    _prefs.setLastRoutineId(id);
    state = id;
  }

  void clear() {
    _prefs.setLastRoutineId(null);
    state = null;
  }
}

final lastRoutineIdProvider =
    StateNotifierProvider<LastRoutineIdNotifier, String?>((ref) {
  return LastRoutineIdNotifier(PreferencesService.instance);
});
