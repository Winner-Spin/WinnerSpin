import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/audio/bounded_audio_pool.dart';

void main() {
  testWidgets('caps concurrent starts and releases playback slots', (
    tester,
  ) async {
    final pendingStarts = <Completer<StopFunction>>[];
    var stopCount = 0;

    final pool = BoundedAudioPool.forTesting(
      releaseAfter: const Duration(milliseconds: 100),
      maxConcurrent: 2,
      start: (_) {
        final completer = Completer<StopFunction>();
        pendingStarts.add(completer);
        return completer.future;
      },
    );

    final first = pool.play();
    final second = pool.play();
    final rejected = pool.play();

    expect(pendingStarts, hasLength(2));
    expect(pool.activeCount, 2);

    for (final pendingStart in pendingStarts) {
      pendingStart.complete(() async {
        stopCount++;
      });
    }
    await Future.wait([first, second, rejected]);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(stopCount, 2);
    expect(pool.activeCount, 0);

    await pool.dispose();
  });

  testWidgets('dispose stops active playback and rejects later starts', (
    tester,
  ) async {
    var startCount = 0;
    var stopCount = 0;
    var backendDisposed = false;

    final pool = BoundedAudioPool.forTesting(
      releaseAfter: const Duration(minutes: 1),
      maxConcurrent: 2,
      start: (_) async {
        startCount++;
        return () async {
          stopCount++;
        };
      },
      dispose: () async {
        backendDisposed = true;
      },
    );

    await Future.wait([pool.play(), pool.play()]);
    await pool.dispose();
    await pool.play();

    expect(startCount, 2);
    expect(stopCount, 2);
    expect(pool.activeCount, 0);
    expect(backendDisposed, isTrue);
  });

  testWidgets('repeated playback cycles do not accumulate active players', (
    tester,
  ) async {
    var startCount = 0;
    var stopCount = 0;

    final pool = BoundedAudioPool.forTesting(
      releaseAfter: const Duration(milliseconds: 10),
      maxConcurrent: 4,
      start: (_) async {
        startCount++;
        return () async {
          stopCount++;
        };
      },
    );

    for (var cycle = 0; cycle < 25; cycle++) {
      await Future.wait(List.generate(4, (_) => pool.play()));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();
      expect(pool.activeCount, 0);
    }

    expect(startCount, 100);
    expect(stopCount, 100);

    await pool.dispose();
  });
}
