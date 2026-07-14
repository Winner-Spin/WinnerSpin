import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../../../../core/audio/app_audio_context.dart';
import '../../../../core/audio/bounded_audio_pool.dart';

class UiClickSound {
  static const _assetPath = 'audio/Items/UI_Click.wav';
  static const _volume = 0.42;
  static const _audibleDuration = Duration(milliseconds: 350);

  static final BoundedAudioPool _pool = BoundedAudioPool(
    debugLabel: 'UI click',
    source: AssetSource(_assetPath),
    releaseAfter: _audibleDuration,
    minPlayers: 3,
    maxPlayers: 8,
    maxConcurrent: 8,
    playerMode: PlayerMode.mediaPlayer,
    audioContext: AppAudioContext.game,
  );
  static bool enabled = true;
  static int _lastPlayMs = 0;

  static Future<void> preload() => _pool.preload();

  static Future<void> play({bool force = false}) async {
    if (!enabled) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _lastPlayMs < 35) return;
    _lastPlayMs = now;

    await _pool.play(volume: _volume);
  }
}
