import 'dart:async';

import '../../../../../core/audio/ambient_music_preference.dart';
import '../../audio/game_music_service.dart';
import '../../audio/ui_click_sound.dart';

class GameFeedbackController {
  GameFeedbackController({GameMusicService? musicService})
    : _musicService = musicService ?? GameMusicService();

  final GameMusicService _musicService;

  bool _vibration = true;
  bool get vibration => _vibration;

  bool _ambientMusic = AmbientMusicPreference.enabled;
  bool get ambientMusic => _ambientMusic;

  bool _soundEffects = true;
  bool get soundEffects => _soundEffects;

  Future<void> initializeMusic() {
    return _musicService.initialize(playWhenReady: _ambientMusic);
  }

  bool setVibration(bool value) {
    if (_vibration == value) return false;
    _vibration = value;
    return true;
  }

  bool setAmbientMusic(bool value) {
    if (_ambientMusic == value) return false;
    _ambientMusic = value;
    unawaited(_musicService.setEnabled(_ambientMusic));
    return true;
  }

  void setSoundEffects(bool value) {
    _soundEffects = value;
    UiClickSound.enabled = value;
    if (value) unawaited(UiClickSound.preload());
  }

  void dispose() {
    unawaited(_musicService.dispose());
  }
}
