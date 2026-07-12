import 'package:audioplayers/audioplayers.dart';

import 'ambient_music_preference.dart';
import 'app_audio_context.dart';

class AmbientMusicService {
  AmbientMusicService._();

  static final AmbientMusicService instance = AmbientMusicService._();

  static const double _volume = 0.48;
  static const String _assetPath = 'audio/Items/Basin_of_Light.mp3';

  AudioPlayer? _audioPlayer;
  Future<void>? _initialization;
  bool _hasStarted = false;
  bool _isPausedForLifecycle = false;

  Future<void> ensurePlaying() async {
    if (!AmbientMusicPreference.enabled || _isPausedForLifecycle) return;

    await _ensureInitialized();
    if (!AmbientMusicPreference.enabled || _isPausedForLifecycle) return;

    final player = _audioPlayer!;
    if (_hasStarted) {
      if (player.state == PlayerState.paused) {
        await player.resume();
      }
      return;
    }

    _hasStarted = true;
    try {
      await player.play(AssetSource(_assetPath));
    } catch (_) {
      _hasStarted = false;
      rethrow;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    AmbientMusicPreference.enabled = enabled;
    if (enabled) {
      await ensurePlaying();
    } else {
      await _audioPlayer?.pause();
    }
  }

  Future<void> pauseForLifecycle() async {
    _isPausedForLifecycle = true;
    await _audioPlayer?.pause();
  }

  Future<void> resumeAfterLifecycle() async {
    _isPausedForLifecycle = false;
    await ensurePlaying();
  }

  Future<void> _ensureInitialized() async {
    final currentInitialization = _initialization;
    if (currentInitialization != null) {
      await currentInitialization;
      return;
    }

    final initialization = _initializePlayer();
    _initialization = initialization;
    try {
      await initialization;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _initializePlayer() async {
    final player = _audioPlayer ??= AudioPlayer();
    await player.setAudioContext(AppAudioContext.game);
    await player.setReleaseMode(ReleaseMode.loop);
    await player.setVolume(_volume);
  }
}
