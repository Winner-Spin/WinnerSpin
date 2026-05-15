import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../../../../core/audio/app_audio_context.dart';

class UiClickSound {
  static const _assetPath = 'audio/Items/UI_Click.wav';
  static const _volume = 0.42;

  static Future<AudioPool>? _poolFuture;
  static bool enabled = true;
  static int _lastPlayMs = 0;

  static Future<void> preload() async {
    try {
      await (_poolFuture ??= AudioPool.create(
        source: AssetSource(_assetPath),
        minPlayers: 3,
        maxPlayers: 8,
        playerMode: PlayerMode.mediaPlayer,
        audioContext: AppAudioContext.game,
      ));
    } catch (_) {

    }
  }

  static Future<void> play({bool force = false}) async {
    if (!enabled) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _lastPlayMs < 35) return;
    _lastPlayMs = now;

    try {
      final pool = await (_poolFuture ??= AudioPool.create(
        source: AssetSource(_assetPath),
        minPlayers: 3,
        maxPlayers: 8,
        playerMode: PlayerMode.mediaPlayer,
        audioContext: AppAudioContext.game,
      ));
      await pool.start(volume: _volume);
    } catch (_) {

    }
  }
}
