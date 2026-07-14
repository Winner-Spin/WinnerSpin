import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';

import '../../../../core/audio/app_audio_context.dart';
import '../../../../core/audio/bounded_audio_pool.dart';

class ItemExplosionPopSound {
  static const _assetPath = 'audio/Items/Item_Explosion_Pop.wav';
  static const _popSpacing = Duration(milliseconds: 42);
  static const _maxQueuedPops = 6;
  static const _volume = 0.38;
  static const _audibleDuration = Duration(milliseconds: 350);

  static final BoundedAudioPool _pool = BoundedAudioPool(
    debugLabel: 'item explosion pop',
    source: AssetSource(_assetPath),
    releaseAfter: _audibleDuration,
    minPlayers: 3,
    maxPlayers: 8,
    maxConcurrent: 8,
    playerMode: PlayerMode.lowLatency,
    audioContext: AppAudioContext.game,
  );
  static int _queuedPops = 0;
  static bool _isDraining = false;

  static Future<void> play() {
    _queuedPops = math.min(_queuedPops + 1, _maxQueuedPops);
    if (!_isDraining) {
      _isDraining = true;
      unawaited(_drainQueue());
    }
    return Future.value();
  }

  static Future<void> _drainQueue() async {
    while (_queuedPops > 0) {
      _queuedPops--;
      await _playOne();
      if (_queuedPops > 0) {
        await Future.delayed(_popSpacing);
      }
    }
    _isDraining = false;
    if (_queuedPops > 0) {
      _isDraining = true;
      unawaited(_drainQueue());
    }
  }

  static Future<void> _playOne() async {
    await _pool.play(volume: _volume);
  }
}
