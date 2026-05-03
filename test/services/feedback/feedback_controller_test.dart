import 'dart:async';

import 'package:fitness_timer/models/exercise_item.dart';
import 'package:fitness_timer/models/feedback_preferences.dart';
import 'package:fitness_timer/services/feedback/audio_feedback_service.dart';
import 'package:fitness_timer/services/feedback/audio_session_configurator.dart';
import 'package:fitness_timer/services/feedback/feedback_controller.dart';
import 'package:fitness_timer/services/feedback/haptic_service.dart';
import 'package:fitness_timer/services/feedback/tts_service.dart';
import 'package:fitness_timer/services/timer/timer_event.dart';
import 'package:fitness_timer/services/timer/timer_state.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Hand-rolled fakes — no platform channels involved
// ---------------------------------------------------------------------------

class FakeTtsService extends TtsService {
  int speakCallCount = 0;
  String? lastSpokenText;

  @override
  Future<void> speak(String text) async {
    speakCallCount++;
    lastSpokenText = text;
  }
}

class FakeAudioFeedbackService extends AudioFeedbackService {
  int startBeepCallCount = 0;
  int endingSoonCallCount = 0;

  @override
  Future<void> playStartBeep() async {
    startBeepCallCount++;
  }

  @override
  Future<void> playEndingSoonBeep() async {
    endingSoonCallCount++;
  }
}

class FakeHapticService extends HapticService {
  int phaseStartCallCount = 0;
  int phaseEndCallCount = 0;
  int routineCompleteCallCount = 0;

  @override
  Future<void> phaseStart() async {
    phaseStartCallCount++;
  }

  @override
  Future<void> phaseEnd() async {
    phaseEndCallCount++;
  }

  @override
  Future<void> routineComplete() async {
    routineCompleteCallCount++;
  }
}

class FakeAudioSessionConfigurator extends AudioSessionConfigurator {
  int activateDuckingCallCount = 0;
  int deactivateDuckingCallCount = 0;

  @override
  Future<void> activateDucking() async {
    activateDuckingCallCount++;
  }

  @override
  Future<void> deactivateDucking() async {
    deactivateDuckingCallCount++;
  }
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

ExerciseItem _makeItem(String name) => ExerciseItem(
      id: 'test-id',
      routineId: 'routine-id',
      orderIndex: 0,
      type: ExerciseType.WORK_TIME,
      duration: 30,
      name: name,
    );

/// Pumps the [StreamController] and waits for all microtasks to settle.
Future<void> _pump(StreamController<TimerEvent> sc, TimerEvent event) async {
  sc.add(event);
  // Yield to the event loop so the listener's async chain completes.
  await Future<void>.delayed(Duration.zero);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeTtsService fakeTts;
  late FakeAudioFeedbackService fakeAudio;
  late FakeHapticService fakeHaptic;
  late FakeAudioSessionConfigurator fakeSession;
  late StreamController<TimerEvent> sc;
  late FeedbackController controller;

  setUp(() {
    fakeTts = FakeTtsService();
    fakeAudio = FakeAudioFeedbackService();
    fakeHaptic = FakeHapticService();
    fakeSession = FakeAudioSessionConfigurator();
    sc = StreamController<TimerEvent>.broadcast();
    controller = FeedbackController(
      tts: fakeTts,
      audio: fakeAudio,
      haptic: fakeHaptic,
      session: fakeSession,
    );
    controller.attach(sc.stream);
  });

  tearDown(() async {
    controller.detach();
    await sc.close();
  });

  // -------------------------------------------------------------------------
  // T1: PhaseStarted event routing
  // -------------------------------------------------------------------------
  group('T1 – PhaseStarted routes to tts.speak and haptic.phaseStart', () {
    test('PhaseStarted with item fires speak and phaseStart once', () async {
      final item = _makeItem('푸쉬업');
      await _pump(sc, PhaseStarted(phase: TimerPhase.work, item: item));

      expect(fakeTts.speakCallCount, equals(1));
      expect(fakeTts.lastSpokenText, equals('푸쉬업'));
      expect(fakeHaptic.phaseStartCallCount, equals(1));
    });

    test('PhaseEndingSoon fires playEndingSoonBeep and haptic.phaseEnd', () async {
      await _pump(
        sc,
        PhaseEndingSoon(phase: TimerPhase.work, secondsRemaining: 3),
      );

      expect(fakeAudio.endingSoonCallCount, equals(1));
      expect(fakeHaptic.phaseEndCallCount, equals(1));
    });

    test('PhaseStarted without item does not call tts.speak', () async {
      await _pump(sc, PhaseStarted(phase: TimerPhase.prep));

      expect(fakeTts.speakCallCount, equals(0));
      expect(fakeHaptic.phaseStartCallCount, equals(1));
    });
  });

  // -------------------------------------------------------------------------
  // T2: FeedbackPreferences gating
  // -------------------------------------------------------------------------
  group('T2 – FeedbackPreferences gating', () {
    test('tts=false prevents tts.speak', () async {
      controller.prefs = const FeedbackPreferences(tts: false);
      final item = _makeItem('스쿼트');
      await _pump(sc, PhaseStarted(phase: TimerPhase.work, item: item));

      expect(fakeTts.speakCallCount, equals(0));
    });

    test('haptic=false prevents haptic calls', () async {
      controller.prefs = const FeedbackPreferences(haptic: false);
      final item = _makeItem('스쿼트');
      await _pump(sc, PhaseStarted(phase: TimerPhase.work, item: item));
      await _pump(
        sc,
        PhaseEndingSoon(phase: TimerPhase.work, secondsRemaining: 3),
      );

      expect(fakeHaptic.phaseStartCallCount, equals(0));
      expect(fakeHaptic.phaseEndCallCount, equals(0));
    });

    test('beep=false prevents audio.playEndingSoonBeep', () async {
      controller.prefs = const FeedbackPreferences(beep: false);
      await _pump(
        sc,
        PhaseEndingSoon(phase: TimerPhase.work, secondsRemaining: 3),
      );

      expect(fakeAudio.endingSoonCallCount, equals(0));
    });

    test('all disabled: no feedback fires for PhaseStarted or PhaseEndingSoon',
        () async {
      controller.prefs =
          const FeedbackPreferences(tts: false, beep: false, haptic: false);
      final item = _makeItem('플랭크');
      await _pump(sc, PhaseStarted(phase: TimerPhase.work, item: item));
      await _pump(
        sc,
        PhaseEndingSoon(phase: TimerPhase.work, secondsRemaining: 3),
      );

      expect(fakeTts.speakCallCount, equals(0));
      expect(fakeAudio.endingSoonCallCount, equals(0));
      expect(fakeHaptic.phaseStartCallCount, equals(0));
      expect(fakeHaptic.phaseEndCallCount, equals(0));
    });
  });

  // -------------------------------------------------------------------------
  // T3: RoutineCompleted
  // -------------------------------------------------------------------------
  group('T3 – RoutineCompleted handling', () {
    test('fires routineComplete haptic and deactivateDucking', () async {
      await _pump(sc, RoutineCompleted());

      expect(fakeHaptic.routineCompleteCallCount, equals(1));
      expect(fakeSession.deactivateDuckingCallCount, equals(1));
    });

    test('haptic=false skips routineComplete but still deactivates ducking',
        () async {
      controller.prefs = const FeedbackPreferences(haptic: false);
      await _pump(sc, RoutineCompleted());

      expect(fakeHaptic.routineCompleteCallCount, equals(0));
      // deactivateDucking is always called regardless of prefs
      expect(fakeSession.deactivateDuckingCallCount, equals(1));
    });
  });

  // -------------------------------------------------------------------------
  // T4: FeedbackPreferences copyWith (also covered in model test, tested here
  //     as integration to confirm prefs setter on controller works)
  // -------------------------------------------------------------------------
  group('T4 – prefs setter on controller', () {
    test('updating prefs mid-stream takes effect immediately', () async {
      final item = _makeItem('버피');

      // First event with default prefs (tts=true)
      await _pump(sc, PhaseStarted(phase: TimerPhase.work, item: item));
      expect(fakeTts.speakCallCount, equals(1));

      // Disable TTS
      controller.prefs = controller.prefs.copyWith(tts: false);
      await _pump(sc, PhaseStarted(phase: TimerPhase.work, item: item));

      // Still 1 — no new speak call
      expect(fakeTts.speakCallCount, equals(1));
    });
  });

  // -------------------------------------------------------------------------
  // attach/detach safety
  // -------------------------------------------------------------------------
  group('attach/detach', () {
    test('calling attach twice does not create duplicate subscriptions', () async {
      // Attach a second time (should cancel first)
      controller.attach(sc.stream);
      final item = _makeItem('런지');
      await _pump(sc, PhaseStarted(phase: TimerPhase.work, item: item));

      // Should still fire exactly once per event
      expect(fakeTts.speakCallCount, equals(1));
    });

    test('detach stops events from being processed', () async {
      controller.detach();
      final item = _makeItem('마운틴클라이머');
      await _pump(sc, PhaseStarted(phase: TimerPhase.work, item: item));

      expect(fakeTts.speakCallCount, equals(0));
      expect(fakeHaptic.phaseStartCallCount, equals(0));
    });
  });
}
