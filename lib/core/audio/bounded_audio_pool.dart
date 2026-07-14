import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

typedef _StartPlayback = Future<StopFunction> Function(double volume);

class _ActivePlayback {
  const _ActivePlayback(this.stop);

  final StopFunction stop;
}

/// Caps active playback because AudioPool.maxPlayers only limits idle players.
class BoundedAudioPool {
  factory BoundedAudioPool({
    required String debugLabel,
    required Source source,
    required Duration releaseAfter,
    required int maxConcurrent,
    required int minPlayers,
    required int maxPlayers,
    required PlayerMode playerMode,
    AudioContext? audioContext,
  }) {
    Future<AudioPool>? poolFuture;

    Future<AudioPool> getPool() async {
      final existing = poolFuture;
      if (existing != null) return existing;

      final created = AudioPool.create(
        source: source,
        minPlayers: minPlayers,
        maxPlayers: maxPlayers,
        playerMode: playerMode,
        audioContext: audioContext,
      );
      poolFuture = created;
      try {
        return await created;
      } catch (_) {
        if (identical(poolFuture, created)) poolFuture = null;
        rethrow;
      }
    }

    return BoundedAudioPool._(
      debugLabel: debugLabel,
      releaseAfter: releaseAfter,
      maxConcurrent: maxConcurrent,
      preloadBackend: () async {
        await getPool();
      },
      startBackend: (volume) async {
        final pool = await getPool();
        return pool.start(volume: volume);
      },
      disposeBackend: () async {
        final existing = poolFuture;
        poolFuture = null;
        if (existing != null) await (await existing).dispose();
      },
    );
  }

  @visibleForTesting
  BoundedAudioPool.forTesting({
    required Duration releaseAfter,
    required int maxConcurrent,
    required Future<StopFunction> Function(double volume) start,
    Future<void> Function()? preload,
    Future<void> Function()? dispose,
  }) : this._(
         debugLabel: 'test audio',
         releaseAfter: releaseAfter,
         maxConcurrent: maxConcurrent,
         preloadBackend: preload ?? _noop,
         startBackend: start,
         disposeBackend: dispose ?? _noop,
       );

  BoundedAudioPool._({
    required this.debugLabel,
    required this.releaseAfter,
    required this.maxConcurrent,
    required Future<void> Function() preloadBackend,
    required _StartPlayback startBackend,
    required Future<void> Function() disposeBackend,
  }) : assert(releaseAfter > Duration.zero),
       assert(maxConcurrent > 0),
       _preloadBackend = preloadBackend,
       _startBackend = startBackend,
       _disposeBackend = disposeBackend;

  static const _failureLogThrottle = Duration(seconds: 5);

  final String debugLabel;
  final Duration releaseAfter;
  final int maxConcurrent;
  final Future<void> Function() _preloadBackend;
  final _StartPlayback _startBackend;
  final Future<void> Function() _disposeBackend;

  final Set<_ActivePlayback> _activePlaybacks = {};
  final Set<Timer> _releaseTimers = {};
  final Set<Future<void>> _startOperations = {};

  int _inUse = 0;
  bool _disposed = false;
  DateTime? _lastFailureLog;

  @visibleForTesting
  int get activeCount => _inUse;

  Future<void> preload() async {
    if (_disposed) return;
    try {
      await _preloadBackend();
    } catch (error, stackTrace) {
      _reportFailure('preload', error, stackTrace);
    }
  }

  Future<void> play({double volume = 1.0}) {
    if (_disposed || _inUse >= maxConcurrent) return Future.value();

    _inUse++;
    final operation = _startPlayback(volume);
    _startOperations.add(operation);
    unawaited(
      operation.whenComplete(() {
        _startOperations.remove(operation);
      }),
    );
    return operation;
  }

  Future<void> _startPlayback(double volume) async {
    try {
      final stop = await _startBackend(volume);
      if (_disposed) {
        await _stopSafely(stop);
        _inUse--;
        return;
      }

      final playback = _ActivePlayback(stop);
      _activePlaybacks.add(playback);
      late final Timer releaseTimer;
      releaseTimer = Timer(releaseAfter, () {
        _releaseTimers.remove(releaseTimer);
        unawaited(_release(playback));
      });
      _releaseTimers.add(releaseTimer);
    } catch (error, stackTrace) {
      _inUse--;
      _reportFailure('play', error, stackTrace);
    }
  }

  Future<void> _release(_ActivePlayback playback) async {
    if (!_activePlaybacks.remove(playback)) return;
    try {
      await playback.stop();
    } catch (error, stackTrace) {
      _reportFailure('stop', error, stackTrace);
    } finally {
      _inUse--;
    }
  }

  Future<void> _stopSafely(StopFunction stop) async {
    try {
      await stop();
    } catch (error, stackTrace) {
      _reportFailure('stop', error, stackTrace);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    for (final timer in _releaseTimers) {
      timer.cancel();
    }
    _releaseTimers.clear();

    await Future.wait(_startOperations.toList());
    await Future.wait(_activePlaybacks.toList().map(_release));

    try {
      await _disposeBackend();
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
    debugPrint('Audio "$debugLabel" failed to $operation: $error\n$stackTrace');
  }

  static Future<void> _noop() => Future.value();
}
