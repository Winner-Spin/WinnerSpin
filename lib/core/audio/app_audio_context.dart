import 'package:audioplayers/audioplayers.dart';

class AppAudioContext {
  static final AudioContext game = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
    respectSilence: false,
  ).build();

  static Future<void> configure() {
    return AudioPlayer.global.setAudioContext(game);
  }
}
