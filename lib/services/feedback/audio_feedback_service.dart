import 'package:just_audio/just_audio.dart';

/// Owns [AudioPlayer] instances and plays WAV assets for timer events.
/// All platform calls are wrapped in try/catch — failures are NO-OPs.
class AudioFeedbackService {
  AudioPlayer? _startPlayer;
  AudioPlayer? _endingPlayer;

  /// Creates and configures [AudioPlayer] instances.
  /// Call once at app boot before first playback.
  Future<void> initialize() async {
    try {
      _startPlayer = AudioPlayer();
      await _startPlayer!.setAudioSource(
        AudioSource.asset('assets/audio/start.wav'),
      );
    } catch (_) {
      _startPlayer = null;
    }

    try {
      _endingPlayer = AudioPlayer();
      await _endingPlayer!.setAudioSource(
        AudioSource.asset('assets/audio/ending.wav'),
      );
    } catch (_) {
      _endingPlayer = null;
    }
  }

  /// Plays the start beep asset.
  Future<void> playStartBeep() async {
    try {
      final player = _startPlayer;
      if (player == null) return;
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {}
  }

  /// Plays the ending-soon beep asset.
  Future<void> playEndingSoonBeep() async {
    try {
      final player = _endingPlayer;
      if (player == null) return;
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {}
  }

  /// Releases all [AudioPlayer] resources.
  Future<void> dispose() async {
    try {
      await _startPlayer?.dispose();
    } catch (_) {}
    try {
      await _endingPlayer?.dispose();
    } catch (_) {}
    _startPlayer = null;
    _endingPlayer = null;
  }
}
