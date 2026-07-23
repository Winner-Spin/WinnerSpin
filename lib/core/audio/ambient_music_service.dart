import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'ambient_music_preference.dart';
import 'app_audio_context.dart';

abstract interface class AmbientMusicLifecycle {
  Future<void> pauseForLifecycle();

  Future<void> resumeAfterLifecycle();
}

@visibleForTesting
abstract interface class AmbientMusicPlayer {
  Stream<dynamic> get eventStream;

  PlayerState get state;

  Future<void> initialize();

  Future<void> play();

  Future<void> pause();

  Future<void> resume();

  Future<void> dispose();
}

class AmbientMusicService implements AmbientMusicLifecycle {
  AmbientMusicService._({
    AmbientMusicPlayer Function()? playerFactory,
    Duration recoveryDelay = _defaultRecoveryDelay,
  }) : _playerFactory = playerFactory ?? _AudioplayersAmbientMusicPlayer.new,
       _recoveryDelay = recoveryDelay;

  @visibleForTesting
  AmbientMusicService.forTesting({
    required AmbientMusicPlayer Function() playerFactory,
    Duration recoveryDelay = _defaultRecoveryDelay,
  }) : this._(playerFactory: playerFactory, recoveryDelay: recoveryDelay);

  static final AmbientMusicService instance = AmbientMusicService._();

  static const double _volume = 0.48;
  static const String _assetPath = 'audio/Items/Basin_of_Light.mp3';
  static const Duration _defaultRecoveryDelay = Duration(seconds: 1);
  static const Duration _failureLogThrottle = Duration(seconds: 5);

  final AmbientMusicPlayer Function() _playerFactory;
  final Duration _recoveryDelay;

  AmbientMusicPlayer? _audioPlayer;
  Future<void>? _initialization;
  Future<void>? _synchronization;
  StreamSubscription<dynamic>? _eventSubscription;
  Timer? _recoveryTimer;
  bool _synchronizationRequested = false;
  bool _recoveryRequested = false;
  bool _playbackRequested = false;
  bool _hasStarted = false;
  bool _isPausedForLifecycle = false;
  DateTime? _lastFailureLog;

  bool get _shouldPlay =>
      _playbackRequested &&
      AmbientMusicPreference.enabled &&
      !_isPausedForLifecycle;

  Future<void> ensurePlaying() {
    _playbackRequested = true;
    return _requestSynchronization();
  }

  Future<void> setEnabled(bool enabled) async {
    final persistence = AmbientMusicPreference.setEnabled(enabled);
    if (enabled) {
      _playbackRequested = true;
    } else {
      _cancelRecovery();
    }
    await Future.wait([persistence, _requestSynchronization()]);
  }

  @override
  Future<void> pauseForLifecycle() {
    _isPausedForLifecycle = true;
    _cancelRecovery();
    return _requestSynchronization();
  }

  @override
  Future<void> resumeAfterLifecycle() {
    _isPausedForLifecycle = false;
    if (!_playbackRequested) return Future.value();
    return _requestSynchronization();
  }

  // Coalesces lifecycle, preference, and recovery changes into one operation.
  Future<void> _requestSynchronization() {
    _synchronizationRequested = true;
    final currentSynchronization = _synchronization;
    if (currentSynchronization != null) return currentSynchronization;

    late final Future<void> synchronization;
    synchronization = Future<void>.sync(_synchronizePlayback).whenComplete(() {
      if (identical(_synchronization, synchronization)) {
        _synchronization = null;
      }
      if (_synchronizationRequested) {
        unawaited(_requestSynchronization());
      }
    });
    _synchronization = synchronization;
    return synchronization;
  }

  Future<void> _synchronizePlayback() async {
    while (_synchronizationRequested) {
      _synchronizationRequested = false;

      if (!_shouldPlay) {
        _recoveryRequested = false;
        await _pausePlayer();
        continue;
      }

      if (_recoveryRequested) {
        _recoveryRequested = false;
        await _resetPlayer();
        if (!_shouldPlay) continue;
      }

      await _ensurePlaying();
    }
  }

  Future<void> _ensurePlaying() async {
    if (!_shouldPlay) return;

    try {
      await _ensureInitialized();
      if (!_shouldPlay) return;

      final player = _audioPlayer!;
      if (player.state == PlayerState.playing) {
        _hasStarted = true;
        _cancelRecoveryTimer();
        return;
      }
      if (_hasStarted) {
        if (player.state == PlayerState.paused) {
          await player.resume();
        } else if (player.state != PlayerState.playing &&
            player.state != PlayerState.completed) {
          _hasStarted = false;
        }
        if (_hasStarted) {
          _cancelRecoveryTimer();
          return;
        }
      }

      await player.play();
      _hasStarted = true;
      _cancelRecoveryTimer();
    } catch (error, stackTrace) {
      _hasStarted = false;
      _reportFailure('play', error, stackTrace);
      _scheduleRecovery();
    }
  }

  Future<void> _pausePlayer() async {
    final player = _audioPlayer;
    if (player == null || player.state != PlayerState.playing) return;

    try {
      await player.pause();
    } catch (error, stackTrace) {
      _reportFailure('pause', error, stackTrace);
    }
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
    final player = _playerFactory();
    _audioPlayer = player;
    final eventSubscription = player.eventStream.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        if (!identical(_audioPlayer, player)) return;
        _hasStarted = false;
        _reportFailure('stream', error, stackTrace);
        _scheduleRecovery();
      },
    );
    _eventSubscription = eventSubscription;

    try {
      await player.initialize();
    } catch (_) {
      if (identical(_audioPlayer, player)) _audioPlayer = null;
      if (identical(_eventSubscription, eventSubscription)) {
        _eventSubscription = null;
      }
      await eventSubscription.cancel();
      await _discardPlayer(player);
      rethrow;
    }
  }

  void _scheduleRecovery() {
    if (!_shouldPlay || _recoveryTimer?.isActive == true) return;

    _recoveryTimer = Timer(_recoveryDelay, () {
      _recoveryTimer = null;
      if (!_shouldPlay) return;
      _recoveryRequested = true;
      unawaited(_requestSynchronization());
    });
  }

  void _cancelRecovery() {
    _recoveryRequested = false;
    _cancelRecoveryTimer();
  }

  void _cancelRecoveryTimer() {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
  }

  Future<void> _resetPlayer() async {
    final player = _audioPlayer;
    _audioPlayer = null;
    _initialization = null;
    _hasStarted = false;

    final eventSubscription = _eventSubscription;
    _eventSubscription = null;
    try {
      await eventSubscription?.cancel();
    } catch (error, stackTrace) {
      _reportFailure('unsubscribe', error, stackTrace);
    }

    if (player != null) await _discardPlayer(player);
  }

  Future<void> _discardPlayer(AmbientMusicPlayer player) async {
    try {
      await player.dispose();
    } catch (error, stackTrace) {
      _reportFailure('dispose', error, stackTrace);
    }
  }

  @visibleForTesting
  Future<void> disposeForTesting() async {
    _playbackRequested = false;
    _isPausedForLifecycle = true;
    _cancelRecovery();
    await _requestSynchronization();
    await _resetPlayer();
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

class _AudioplayersAmbientMusicPlayer implements AmbientMusicPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Stream<dynamic> get eventStream => _player.eventStream;

  @override
  PlayerState get state => _player.state;

  @override
  Future<void> initialize() async {
    await _player.setAudioContext(AppAudioContext.game);
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(AmbientMusicService._volume);
  }

  @override
  Future<void> play() {
    return _player.play(AssetSource(AmbientMusicService._assetPath));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> dispose() => _player.dispose();
}
