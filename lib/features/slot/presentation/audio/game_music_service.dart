import 'package:audioplayers/audioplayers.dart';

import '../../../../core/audio/app_audio_context.dart';

class GameMusicService {
  static const double _ambientMusicVolume = 0.48;
  static const String _ambientMusicPath = 'audio/Items/Basin_of_Light.mp3';

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;

  Future<void> initialize({required bool playWhenReady}) async {
    if (_isInitialized) {
      if (playWhenReady) {
        await _playAmbientTrack();
      }
      return;
    }
    _isInitialized = true;
    await _audioPlayer.setAudioContext(AppAudioContext.game);
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.setVolume(_ambientMusicVolume);
    if (playWhenReady) {
      await _playAmbientTrack();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      if (!_isInitialized) {
        await initialize(playWhenReady: true);
        return;
      }
      await _restartAmbientTrack();
    } else {
      await _audioPlayer.pause();
    }
  }

  Future<void> pauseForLifecycle({required bool enabled}) async {
    if (enabled) {
      await _audioPlayer.pause();
    }
  }

  Future<void> resumeAfterLifecycle({required bool enabled}) async {
    if (enabled) {
      await _restartAmbientTrack();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _restartAmbientTrack();
    }
  }

  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }

  Future<void> _playAmbientTrack() async {
    await _audioPlayer.setVolume(_ambientMusicVolume);
    await _audioPlayer.play(AssetSource(_ambientMusicPath));
  }

  Future<void> _restartAmbientTrack() async {
    await _audioPlayer.setAudioContext(AppAudioContext.game);
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.stop();
    await _playAmbientTrack();
  }
}
