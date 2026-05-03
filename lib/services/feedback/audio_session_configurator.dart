import 'package:audio_session/audio_session.dart';

/// Configures the OS audio session for ducking and audio focus management.
/// All platform calls are wrapped in try/catch — failures are NO-OPs.
class AudioSessionConfigurator {
  /// Called once at boot to configure iOS and Android audio session settings.
  Future<void> configure() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.duckOthers,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.assistanceSonification,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      ));
    } catch (_) {
      // Silent NO-OP — ducking simply will not occur if configure fails.
    }
  }

  /// Requests audio focus; background music volume lowers.
  Future<void> activateDucking() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (_) {}
  }

  /// Abandons audio focus; background music volume restores.
  Future<void> deactivateDucking() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
  }
}
