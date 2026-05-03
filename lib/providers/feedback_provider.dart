import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feedback_preferences.dart';
import '../services/feedback/audio_feedback_service.dart';
import '../services/feedback/audio_session_configurator.dart';
import '../services/feedback/feedback_controller.dart';
import '../services/feedback/haptic_service.dart';
import '../services/feedback/tts_service.dart';

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

final feedbackPreferencesProvider =
    StateProvider<FeedbackPreferences>((ref) => const FeedbackPreferences());

final feedbackControllerProvider =
    Provider.autoDispose<FeedbackController>((ref) {
  final controller = FeedbackController(
    tts: ref.read(ttsServiceProvider),
    audio: ref.read(audioFeedbackServiceProvider),
    haptic: ref.read(hapticServiceProvider),
    session: ref.read(audioSessionConfiguratorProvider),
    prefs: ref.read(feedbackPreferencesProvider),
  );
  ref.onDispose(controller.detach);
  return controller;
});
