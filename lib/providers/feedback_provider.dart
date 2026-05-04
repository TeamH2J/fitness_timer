import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feedback_preferences.dart';
import '../services/feedback/audio_feedback_service.dart';
import '../services/feedback/audio_session_configurator.dart';
import '../services/feedback/feedback_controller.dart';
import '../services/feedback/haptic_service.dart';
import '../services/feedback/tts_service.dart';
import 'settings_provider.dart';

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(service.dispose);
  return service;
});

final audioFeedbackServiceProvider = Provider<AudioFeedbackService>((ref) {
  final service = AudioFeedbackService();
  ref.onDispose(service.dispose);
  return service;
});

final hapticServiceProvider = Provider<HapticService>((ref) {
  return HapticService();
});

final audioSessionConfiguratorProvider =
    Provider<AudioSessionConfigurator>((ref) {
  return AudioSessionConfigurator();
});

/// Derived from [settingsProvider] so live settings changes propagate immediately.
final feedbackPreferencesProvider = Provider<FeedbackPreferences>((ref) {
  final s = ref.watch(settingsProvider);
  return FeedbackPreferences(
    tts: s.tts,
    beep: s.beep,
    haptic: s.haptic,
    language: s.localeCode == 'en' ? 'en-US' : 'ko-KR',
  );
});

final feedbackControllerProvider =
    Provider.autoDispose<FeedbackController>((ref) {
  final prefs = ref.watch(feedbackPreferencesProvider);
  final controller = FeedbackController(
    tts: ref.read(ttsServiceProvider),
    audio: ref.read(audioFeedbackServiceProvider),
    haptic: ref.read(hapticServiceProvider),
    session: ref.read(audioSessionConfiguratorProvider),
    prefs: prefs,
  );
  ref.onDispose(controller.detach);
  return controller;
});
