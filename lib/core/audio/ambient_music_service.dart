import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'ambient_music_preference.dart';
import 'app_audio_context.dart';

class AmbientMusicService {
  AmbientMusicService._();

  static final AmbientMusicService instance = AmbientMusicService._();

  static const double _volume = 0.48;
  static const String _assetPath = 'audio/Items/Basin_of_Light.mp3';
  static const Duration _recoveryDelay = Duration(seconds: 1);
  static const Duration _failureLogThrottle = Duration(seconds: 5);

  AudioPlayer? _audioPlayer;
  Future<void>? _initialization;
  Future<void>? _ensurePlayingOperation;
  StreamSubscription<dynamic>? _eventSubscription;
  Timer? _recoveryTimer;
  bool _hasStarted = false;
  bool _isPausedForLifecycle = false;
  DateTime? _lastFailureLog;

  Future<void> ensurePlaying() {
    final currentOperation = _ensurePlayingOperation;
    if (currentOperation != null) return currentOperation;

    late final Future<void> operation;
    operation = _ensurePlaying().whenComplete(() {
      if (identical(_ensurePlayingOperation, operation)) {
        _ensurePlayingOperation = null;
      }
    });
    _ensurePlayingOperation = operation;
    return operation;
  }

  Future<void> _ensurePlaying() async {
    if (!AmbientMusicPreference.enabled || _isPausedForLifecycle) return;

    try {
      await _ensureInitialized();
      if (!AmbientMusicPreference.enabled || _isPausedForLifecycle) return;

      final player = _audioPlayer!;
      if (_hasStarted) {
        if (player.state == PlayerState.paused) {
          await player.resume();
          return;
        }
        if (player.state == PlayerState.playing ||
            player.state == PlayerState.completed) {
          return;
        }
        _hasStarted = false;
      }

      await player.play(AssetSource(_assetPath));
      _hasStarted = true;
    } catch (error, stackTrace) {
      _hasStarted = false;
      _reportFailure('play', error, stackTrace);
      _scheduleRecovery();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    AmbientMusicPreference.enabled = enabled;
    if (enabled) {
      await ensurePlaying();
    } else {
      _recoveryTimer?.cancel();
      try {
        await _audioPlayer?.pause();
      } catch (error, stackTrace) {
        _reportFailure('pause', error, stackTrace);
      }
    }
  }

  Future<void> pauseForLifecycle() async {
    _isPausedForLifecycle = true;
    _recoveryTimer?.cancel();
    try {
      await _audioPlayer?.pause();
    } catch (error, stackTrace) {
      _reportFailure('pause', error, stackTrace);
    }
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
    final player = AudioPlayer();
    _audioPlayer = player;
    _eventSubscription = player.eventStream.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        _hasStarted = false;
        _reportFailure('stream', error, stackTrace);
        _scheduleRecovery();
      },
    );

    try {
      await player.setAudioContext(AppAudioContext.game);
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_volume);
    } catch (_) {
      if (identical(_audioPlayer, player)) _audioPlayer = null;
      final eventSubscription = _eventSubscription;
      _eventSubscription = null;
      await eventSubscription?.cancel();
      await _discardPlayer(player);
      rethrow;
    }
  }

  void _scheduleRecovery() {
    if (!AmbientMusicPreference.enabled || _isPausedForLifecycle) return;

    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(_recoveryDelay, () {
      _recoveryTimer = null;
      unawaited(_recoverPlayer());
    });
  }

  Future<void> _recoverPlayer() async {
    if (!AmbientMusicPreference.enabled || _isPausedForLifecycle) return;

    await _resetPlayer();
    await ensurePlaying();
  }

  Future<void> _resetPlayer() async {
    final player = _audioPlayer;
    _audioPlayer = null;
    _initialization = null;
    _hasStarted = false;

    final eventSubscription = _eventSubscription;
    _eventSubscription = null;
    await eventSubscription?.cancel();

    if (player != null) await _discardPlayer(player);
  }

  Future<void> _discardPlayer(AudioPlayer player) async {
    try {
      await player.dispose();
    } catch (error, stackTrace) {
      _reportFailure('dispose', error, stackTrace);
    }
  }

  void _reportFailure(String operation, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;

    final now = DateTime.now();
    final lastFailureLog = _lastFailureLog;
    if (lastFailureLog != null &&
        now.difference(lastFailureLog) < _failureLogThrottle) {
      return;
    }
    _lastFailureLog = now;
    debugPrint('Ambient music failed to $operation: $error\n$stackTrace');
  }
}
