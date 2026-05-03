import 'dart:async';

import '../../models/feedback_preferences.dart';
import '../../services/timer/timer_event.dart';
import 'audio_feedback_service.dart';
import 'audio_session_configurator.dart';
import 'haptic_service.dart';
import 'tts_service.dart';

/// Orchestration layer: subscribes to [Stream<TimerEvent>] and dispatches
/// to audio, haptic, and TTS services based on [FeedbackPreferences] gating.
class FeedbackController {
  final TtsService tts;
  final AudioFeedbackService audio;
  final HapticService haptic;
  final AudioSessionConfigurator session;

  StreamSubscription<TimerEvent>? _sub;

  /// User preference flags — update via the setter to take effect immediately.
  FeedbackPreferences prefs;

  FeedbackController({
    required this.tts,
    required this.audio,
    required this.haptic,
    required this.session,
    FeedbackPreferences? prefs,
  }) : prefs = prefs ?? const FeedbackPreferences();

  /// Subscribes to [events]; cancels any prior subscription first.
  void attach(Stream<TimerEvent> events) {
    _sub?.cancel();
    _sub = events.listen(_onEvent);
  }

  /// Cancels the active stream subscription.
  void detach() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> _onEvent(TimerEvent e) async {
    try {
      switch (e) {
        case PhaseStarted(:final item):
          if (prefs.haptic) await haptic.phaseStart();
          if (prefs.tts && item != null) await tts.speak(item.name);
        case PhaseEndingSoon():
          if (prefs.beep) await audio.playEndingSoonBeep();
          if (prefs.haptic) await haptic.phaseEnd();
        case PhaseEnded():
          // No default feedback action for PhaseEnded in this phase.
          break;
        case RoutineCompleted():
          if (prefs.haptic) await haptic.routineComplete();
          await session.deactivateDucking();
      }
    } catch (_) {
      // An exception in one event must not cancel the subscription.
    }
  }
}
