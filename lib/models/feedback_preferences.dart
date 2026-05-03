/// Immutable value object that holds user feedback toggle state.
/// Persistence is deferred to Phase 5 (SharedPreferences).
class FeedbackPreferences {
  final bool tts;
  final bool beep;
  final bool haptic;
  final String language;

  const FeedbackPreferences({
    this.tts = true,
    this.beep = true,
    this.haptic = true,
    this.language = 'ko-KR',
  });

  FeedbackPreferences copyWith({
    bool? tts,
    bool? beep,
    bool? haptic,
    String? language,
  }) {
    return FeedbackPreferences(
      tts: tts ?? this.tts,
      beep: beep ?? this.beep,
      haptic: haptic ?? this.haptic,
      language: language ?? this.language,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeedbackPreferences &&
        other.tts == tts &&
        other.beep == beep &&
        other.haptic == haptic &&
        other.language == language;
  }

  @override
  int get hashCode => Object.hash(tts, beep, haptic, language);
}
