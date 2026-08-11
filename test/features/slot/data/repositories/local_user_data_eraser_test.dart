import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/data/repositories/local_first_launch_disclaimer_repository.dart';
import 'package:winner_spin/features/slot/data/repositories/local_game_history_repository.dart';
import 'package:winner_spin/features/slot/data/repositories/local_user_data_coordinator.dart';
import 'package:winner_spin/features/slot/data/repositories/local_user_data_eraser.dart';
import 'package:winner_spin/features/slot/domain/models/game_history_entry.dart';

void main() {
  test('covers every per-user file the app writes', () {
    final names = LocalUserDataEraser.fileNamesFor('user-1');

    // These match the names the local repositories build. A repository that
    // renames its file without updating this list would quietly start leaving
    // a deleted player's data on the device.
    expect(names, contains('game_history_user-1.json'));
    expect(names, contains('pending_spin_recovery_user-1.json'));
    expect(names, contains('first_launch_disclaimer_user-1.txt'));
  });

  test('includes the half-written files', () {
    // Both repositories write to `.tmp` and rename. A crash mid-save leaves
    // the temporary file behind, holding the same data as the real one.
    final names = LocalUserDataEraser.fileNamesFor('user-1');

    expect(names, contains('game_history_user-1.json.tmp'));
    expect(names, contains('pending_spin_recovery_user-1.json.tmp'));
  });

  test('names are scoped to the account', () {
    final mine = LocalUserDataEraser.fileNamesFor('user-1');
    final theirs = LocalUserDataEraser.fileNamesFor('user-2');

    // Deleting one account must not be able to reach another one's files.
    expect(mine.toSet().intersection(theirs.toSet()), isEmpty);
  });

  test('drains an active write and blocks every write after erasure', () async {
    final directory = await Directory.systemTemp.createTemp(
      'winner-spin-local-erasure-',
    );
    final coordinator = LocalUserDataCoordinator();
    final writeStarted = Completer<void>();
    final releaseWrite = Completer<void>();
    final repository = LocalGameHistoryRepository(
      coordinator: coordinator,
      directoryProvider: () async {
        if (!writeStarted.isCompleted) writeStarted.complete();
        await releaseWrite.future;
        return directory;
      },
    );
    final eraser = LocalUserDataEraser(
      coordinator: coordinator,
      directoryProvider: () async => directory,
    );
    const userId = 'racing-user';
    final entry = GameHistoryEntry(
      id: 'spin-1',
      playedAt: DateTime.utc(2026, 8, 11),
      newBalance: 9900,
      bet: 100,
      winAmount: 0,
    );

    try {
      final activeSave = repository.save(userId, [entry]);
      await writeStarted.future;
      final erase = eraser.eraseFor(userId);
      releaseWrite.complete();
      await Future.wait([activeSave, erase]);

      expect(await directory.list().toList(), isEmpty);

      await repository.save(userId, [entry]);
      expect(await directory.list().toList(), isEmpty);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('keeps the tombstone when cleanup fails', () async {
    final coordinator = LocalUserDataCoordinator();

    await expectLater(
      coordinator.erase('user-1', () => Future<void>.error(StateError('disk'))),
      throwsStateError,
    );

    var operationRan = false;
    final result = await coordinator.run('user-1', () async {
      operationRan = true;
      return 'written';
    }, whenBlocked: () => 'blocked');
    expect(result, 'blocked');
    expect(operationRan, isFalse);
  });

  test(
    'directory lookup failure is surfaced and keeps later writes blocked',
    () async {
      final coordinator = LocalUserDataCoordinator();
      final eraser = LocalUserDataEraser(
        coordinator: coordinator,
        directoryProvider: () => Future<Directory>.error(
          const FileSystemException('documents directory unavailable'),
        ),
      );

      await expectLater(
        eraser.eraseFor('user-1'),
        throwsA(isA<FileSystemException>()),
      );

      var directoryRequested = false;
      final repository = LocalGameHistoryRepository(
        coordinator: coordinator,
        directoryProvider: () async {
          directoryRequested = true;
          return Directory.systemTemp;
        },
      );
      await repository.save('user-1', [
        GameHistoryEntry(
          id: 'blocked-spin',
          playedAt: DateTime.utc(2026, 8, 11),
          newBalance: 9900,
          bet: 100,
          winAmount: 0,
        ),
      ]);

      expect(directoryRequested, isFalse);
    },
  );

  test('a tombstone is isolated to its own uid', () async {
    final coordinator = LocalUserDataCoordinator();
    await coordinator.erase('deleted-user', () async {});

    var otherUserRan = false;
    await coordinator.run(
      'active-user',
      () async => otherUserRan = true,
      whenBlocked: () => false,
    );

    expect(otherUserRan, isTrue);
  });

  test('shared coordinator blocks disclaimer writes after erasure', () async {
    final directory = await Directory.systemTemp.createTemp(
      'winner-spin-disclaimer-erasure-',
    );
    final coordinator = LocalUserDataCoordinator();
    final repository = LocalFirstLaunchDisclaimerRepository(
      coordinator: coordinator,
      directoryProvider: () async => directory,
    );
    final eraser = LocalUserDataEraser(
      coordinator: coordinator,
      directoryProvider: () async => directory,
    );

    try {
      await eraser.eraseFor('user-1');
      await repository.markDisclaimerSeen('user-1');

      final file = File('${directory.path}/first_launch_disclaimer_user-1.txt');
      expect(await file.exists(), isFalse);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
