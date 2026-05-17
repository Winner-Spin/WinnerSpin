import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';

import '../../../../core/audio/app_audio_context.dart';

class ItemExplosionPopSound {
  static const _assetPath = 'audio/Items/Item_Explosion_Pop.wav';
  static const _popSpacing = Duration(milliseconds: 42);
  static const _maxQueuedPops = 6;
  static const _volume = 0.38;

  static Future<AudioPool>? _poolFuture;
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
    try {
      final pool = await (_poolFuture ??= AudioPool.create(
        source: AssetSource(_assetPath),
        minPlayers: 3,
        maxPlayers: 8,
        playerMode: PlayerMode.lowLatency,
        audioContext: AppAudioContext.game,
      ));
      await pool.start(volume: _volume);
    } catch (_) {
      // Ignore audio failures during animation.
    }
  }
}
