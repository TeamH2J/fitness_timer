import 'package:flutter/material.dart';

/// Immutable value object for the complete user settings state.
class AppSettings {
  final String? localeCode; // null = follow system; 'ko' or 'en'
  final bool tts;
  final bool beep;
  final bool haptic;
  final String displayFormat; // 'mmss' | 'seconds'

  const AppSettings({
    this.localeCode,
    this.tts = true,
    this.beep = true,
    this.haptic = true,
    this.displayFormat = 'mmss',
  });

  AppSettings copyWith({
    Object? localeCode = _sentinel,
    bool? tts,
    bool? beep,
    bool? haptic,
    String? displayFormat,
  }) {
    return AppSettings(
      localeCode:
          localeCode == _sentinel ? this.localeCode : localeCode as String?,
      tts: tts ?? this.tts,
      beep: beep ?? this.beep,
      haptic: haptic ?? this.haptic,
      displayFormat: displayFormat ?? this.displayFormat,
    );
  }

  Locale? get locale =>
      localeCode == null ? null : Locale(localeCode!);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.localeCode == localeCode &&
        other.tts == tts &&
        other.beep == beep &&
        other.haptic == haptic &&
        other.displayFormat == displayFormat;
  }

  @override
  int get hashCode =>
      Object.hash(localeCode, tts, beep, haptic, displayFormat);
}

// Sentinel for nullable copyWith parameter
const _sentinel = Object();
