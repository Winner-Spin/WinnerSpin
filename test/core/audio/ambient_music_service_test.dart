import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/audio/ambient_music_preference.dart';
import 'package:winner_spin/core/audio/ambient_music_service.dart';

void main() {
  late DebugPrintCallback originalDebugPrint;

  setUpAll(() {
    originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
  });

  tearDownAll(() {
    debugPrint = originalDebugPrint;
  });

  setUp(() {
    AmbientMusicPreference.enabled = true;
  });

  tearDown(() {
    AmbientMusicPreference.enabled = true;
  });

  test('coalesces concurrent playback requests into one player', () async {
    final players = <_FakeAmbientMusicPlayer>[];
    final service = AmbientMusicService.forTesting(
      playerFactory: () {
        final player = _FakeAmbientMusicPlayer();
        players.add(player);
        return player;
      },
    );

    await Future.wait(List.generate(50, (_) => service.ensurePlaying()));

    expect(players, hasLength(1));
    expect(players.single.initializeCalls, 1);
    expect(players.single.playCalls, 1);
    expect(players.single.state, PlayerState.playing);

    await service.disposeForTesting();
  });

  test('does not start music on resume before playback is requested', () async {
    final players = <_FakeAmbientMusicPlayer>[];
    final service = AmbientMusicService.forTesting(
      playerFactory: () {
        final player = _FakeAmbientMusicPlayer();
        players.add(player);
        return player;
      },
    );

    await service.resumeAfterLifecycle();

    expect(players, isEmpty);
    await service.disposeForTesting();
  });

  test('applies resume after an in-flight lifecycle pause', () async {
    final player = _FakeAmbientMusicPlayer();
    final service = AmbientMusicService.forTesting(playerFactory: () => player);
    await service.ensurePlaying();
    player.pauseGate = Completer<void>();

    final pause = service.pauseForLifecycle();
    await Future<void>.delayed(Duration.zero);
    expect(player.pauseCalls, 1);

    final resume = service.resumeAfterLifecycle();
    player.pauseGate!.complete();
    await Future.wait([pause, resume]);

    expect(player.resumeCalls, 1);
    expect(player.state, PlayerState.playing);

    await service.disposeForTesting();
  });

  test(
    'finishes muted when playback completes after the preference changes',
    () async {
      final player = _FakeAmbientMusicPlayer()..playGate = Completer<void>();
      final service = AmbientMusicService.forTesting(
        playerFactory: () => player,
      );

      final playback = service.ensurePlaying();
      await Future<void>.delayed(Duration.zero);
      expect(player.playCalls, 1);

      final mute = service.setEnabled(false);
      player.playGate!.complete();
      await Future.wait([playback, mute]);

      expect(player.pauseCalls, 1);
      expect(player.state, PlayerState.paused);

      await service.resumeAfterLifecycle();
      expect(player.resumeCalls, 0);
      expect(player.playCalls, 1);

      await service.disposeForTesting();
    },
  );

  test('cancels pending recovery while the app is backgrounded', () async {
    final players = <_FakeAmbientMusicPlayer>[];
    final service = AmbientMusicService.forTesting(
      recoveryDelay: const Duration(milliseconds: 50),
      playerFactory: () {
        final player = _FakeAmbientMusicPlayer();
        players.add(player);
        return player;
      },
    );
    await service.ensurePlaying();

    players.single.emitError();
    await Future<void>.delayed(Duration.zero);
    await service.pauseForLifecycle();
    await Future<void>.delayed(const Duration(milliseconds: 75));

    expect(players, hasLength(1));
    expect(players.single.disposeCalls, 0);
    expect(players.single.state, PlayerState.paused);

    await service.disposeForTesting();
  });

  test('replaces a failed player once after the recovery delay', () async {
    final players = <_FakeAmbientMusicPlayer>[];
    final service = AmbientMusicService.forTesting(
      recoveryDelay: const Duration(milliseconds: 20),
      playerFactory: () {
        final player = _FakeAmbientMusicPlayer();
        players.add(player);
        return player;
      },
    );
    await service.ensurePlaying();

    players.single
      ..emitError()
      ..emitError();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(players, hasLength(2));
    expect(players.first.disposeCalls, 1);
    expect(players.last.initializeCalls, 1);
    expect(players.last.playCalls, 1);
    expect(players.last.state, PlayerState.playing);

    await service.disposeForTesting();
  });

  test('reuses the same player across repeated lifecycle changes', () async {
    final players = <_FakeAmbientMusicPlayer>[];
    final service = AmbientMusicService.forTesting(
      playerFactory: () {
        final player = _FakeAmbientMusicPlayer();
        players.add(player);
        return player;
      },
    );
    await service.ensurePlaying();

    for (var cycle = 0; cycle < 100; cycle++) {
      await service.pauseForLifecycle();
      await service.resumeAfterLifecycle();
    }

    expect(players, hasLength(1));
    expect(players.single.initializeCalls, 1);
    expect(players.single.playCalls, 1);
    expect(players.single.disposeCalls, 0);
    expect(players.single.state, PlayerState.playing);

    await service.disposeForTesting();
  });
}

class _FakeAmbientMusicPlayer implements AmbientMusicPlayer {
  final StreamController<dynamic> _events =
      StreamController<dynamic>.broadcast();

  @override
  Stream<dynamic> get eventStream => _events.stream;

  @override
  PlayerState state = PlayerState.stopped;

  int initializeCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int disposeCalls = 0;
  Completer<void>? playGate;
  Completer<void>? pauseGate;

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Future<void> play() async {
    playCalls++;
    await playGate?.future;
    state = PlayerState.playing;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    await pauseGate?.future;
    state = PlayerState.paused;
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    state = PlayerState.playing;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    state = PlayerState.disposed;
    await _events.close();
  }

  void emitError() {
    _events.addError(StateError('Native playback failed'));
  }
}
