import 'package:audioplayers/audioplayers.dart';

import '../../../../core/audio/app_audio_context.dart';
import '../../../../core/audio/bounded_audio_pool.dart';

class MultiplierBombExplosionSound {
  static const _assetPath = 'audio/Items/Bomb_Explosion.wav';
  static const _volume = 0.72;
  static const _playbackDuration = Duration(milliseconds: 200);

  static final BoundedAudioPool _pool = BoundedAudioPool(
    debugLabel: 'bomb explosion',
    source: AssetSource(_assetPath),
    releaseAfter: _playbackDuration,
    minPlayers: 1,
    maxPlayers: 8,
    maxConcurrent: 8,
    playerMode: PlayerMode.lowLatency,
    audioContext: AppAudioContext.game,
  );

  static Future<void> preload() => _pool.preload();

  static Future<void> play() => _pool.play(volume: _volume);
}
