import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/models/game_history_entry.dart';
import 'package:winner_spin/features/slot/domain/repositories/game_history_repository.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/game_history_controller.dart';

void main() {
  test('recordOnce waits for an in-flight write of the same spin', () async {
    final repository = _BlockingHistoryRepository();
    final controller = GameHistoryController(repository);
    final playedAt = DateTime.utc(2026, 7, 23);
    var completed = false;

    controller.record(
      userId: 'user-1',
      id: 'spin-1',
      playedAt: playedAt,
      newBalance: 1050,
      bet: 100,
      winAmount: 150,
    );
    final duplicate = controller
        .recordOnce(
          userId: 'user-1',
          id: 'spin-1',
          playedAt: playedAt,
          newBalance: 1050,
          bet: 100,
          winAmount: 150,
        )
        .then((_) => completed = true);

    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    repository.completeSave();
    await duplicate;
    expect(completed, isTrue);
    expect(controller.entries, hasLength(1));
  });

  test('keeps every spin locally but mirrors only the newest', () async {
    final local = _MemoryHistoryRepository();
    final remote = _MemoryHistoryRepository();
    final controller = GameHistoryController(local, remote: remote);

    const total = kMaxRemoteGameHistoryEntries + 5;
    for (var i = 0; i < total; i++) {
      controller.record(
        userId: 'user-1',
        id: 'spin-$i',
        playedAt: DateTime.utc(2026, 7, 23).add(Duration(minutes: i)),
        newBalance: 1000 + i.toDouble(),
        bet: 10,
        winAmount: 0,
      );
    }
    await Future<void>.delayed(Duration.zero);

    // Nothing is dropped on this device.
    expect(controller.entries, hasLength(total));
    expect(controller.entries.first.id, 'spin-${total - 1}');
    expect(controller.entries.last.id, 'spin-0');
    expect(local.stored, hasLength(total));

    // The backup is capped, keeping the newest spins.
    await controller.flushRemote('user-1');
    expect(remote.stored, hasLength(kMaxRemoteGameHistoryEntries));
    expect(remote.stored.first.id, 'spin-${total - 1}');
    expect(
      remote.stored.last.id,
      'spin-${total - kMaxRemoteGameHistoryEntries}',
    );
  });

  test('a long local history does not force a write on every launch', () async {
    final playedAt = DateTime.utc(2026, 7, 23);
    final all = [
      for (var i = 0; i < kMaxRemoteGameHistoryEntries + 5; i++)
        _entry('spin-$i', playedAt.add(Duration(minutes: i))),
    ].reversed.toList(growable: false);

    final local = _MemoryHistoryRepository()..stored = all;
    final remote = _MemoryHistoryRepository()
      ..stored = all.take(kMaxRemoteGameHistoryEntries).toList();

    final controller = GameHistoryController(local, remote: remote);
    await controller.load('user-1');
    await controller.flushRemote('user-1');

    expect(controller.entries, hasLength(all.length));
    expect(
      remote.saveCalls,
      0,
      reason: 'the mirror already holds the newest entries',
    );
  });

  test('does not write to the remote repository while recording', () async {
    final remote = _MemoryHistoryRepository();
    final controller = GameHistoryController(
      _MemoryHistoryRepository(),
      remote: remote,
    );

    for (var i = 0; i < 3; i++) {
      controller.record(
        userId: 'user-1',
        id: 'spin-$i',
        playedAt: DateTime.utc(2026, 7, 23).add(Duration(minutes: i)),
        newBalance: 1000,
        bet: 10,
        winAmount: 0,
      );
    }
    await Future<void>.delayed(Duration.zero);

    expect(remote.saveCalls, 0, reason: 'spins must not hit Firestore');

    await controller.flushRemote('user-1');
    expect(remote.saveCalls, 1);
    expect(remote.stored, hasLength(3));
  });

  test('flushRemote skips the write when nothing changed', () async {
    final remote = _MemoryHistoryRepository();
    final controller = GameHistoryController(
      _MemoryHistoryRepository(),
      remote: remote,
    )..record(userId: 'user-1', newBalance: 1000, bet: 10, winAmount: 0);
    await Future<void>.delayed(Duration.zero);

    await controller.flushRemote('user-1');
    await controller.flushRemote('user-1');

    expect(remote.saveCalls, 1);
  });

  test('delete removes locally at once and remotely on close', () async {
    final local = _MemoryHistoryRepository();
    final remote = _MemoryHistoryRepository();
    final controller = GameHistoryController(local, remote: remote);
    for (var i = 0; i < 3; i++) {
      controller.record(
        userId: 'user-1',
        id: 'spin-$i',
        playedAt: DateTime.utc(2026, 7, 23).add(Duration(minutes: i)),
        newBalance: 1000,
        bet: 10,
        winAmount: 0,
      );
    }
    await Future<void>.delayed(Duration.zero);
    await controller.flushRemote('user-1');
    expect(remote.stored, hasLength(3));

    controller.delete(userId: 'user-1', ids: {'spin-1'});
    await Future<void>.delayed(Duration.zero);

    // Gone from memory and the local file straight away...
    expect(controller.entries.map((entry) => entry.id), ['spin-2', 'spin-0']);
    expect(local.stored.map((entry) => entry.id), ['spin-2', 'spin-0']);
    // ...but Firestore still holds it until the app closes.
    expect(remote.stored, hasLength(3));

    await controller.flushRemote('user-1');
    expect(remote.stored.map((entry) => entry.id), ['spin-2', 'spin-0']);
  });

  test('deleting a round the mirror never held costs no write', () async {
    final local = _MemoryHistoryRepository();
    final remote = _MemoryHistoryRepository();
    final controller = GameHistoryController(local, remote: remote);

    const total = kMaxRemoteGameHistoryEntries + 5;
    for (var i = 0; i < total; i++) {
      controller.record(
        userId: 'user-1',
        id: 'spin-$i',
        playedAt: DateTime.utc(2026, 7, 23).add(Duration(minutes: i)),
        newBalance: 1000,
        bet: 10,
        winAmount: 0,
      );
    }
    await Future<void>.delayed(Duration.zero);
    await controller.flushRemote('user-1');
    expect(remote.saveCalls, 1);

    // 'spin-0' is one of the oldest rounds, far outside the mirrored slice.
    controller.delete(userId: 'user-1', ids: {'spin-0'});
    await Future<void>.delayed(Duration.zero);
    await controller.flushRemote('user-1');

    expect(local.stored, hasLength(total - 1));
    expect(
      remote.saveCalls,
      1,
      reason: 'the mirrored slice did not change, so nothing to upload',
    );

    // Deleting a round the mirror does hold still triggers the write.
    controller.delete(userId: 'user-1', ids: {'spin-${total - 1}'});
    await Future<void>.delayed(Duration.zero);
    await controller.flushRemote('user-1');

    expect(remote.saveCalls, 2);
    expect(
      remote.stored.map((entry) => entry.id),
      isNot(contains('spin-${total - 1}')),
    );
    expect(
      remote.stored,
      hasLength(kMaxRemoteGameHistoryEntries),
      reason: 'an older round slides up to refill the slice',
    );
  });

  test('load prefers the local copy over the remote mirror', () async {
    final playedAt = DateTime.utc(2026, 7, 23);
    // The player deleted 'remote-only' locally; Firestore has not caught up.
    final local = _MemoryHistoryRepository()
      ..stored = [
        _entry('local-1', playedAt.add(const Duration(minutes: 5))),
        _entry('shared', playedAt.add(const Duration(minutes: 2))),
      ];
    final remote = _MemoryHistoryRepository()
      ..stored = [
        _entry('shared', playedAt.add(const Duration(minutes: 2))),
        _entry('remote-only', playedAt),
      ];

    final controller = GameHistoryController(local, remote: remote);
    await controller.load('user-1');

    expect(
      controller.entries.map((entry) => entry.id),
      ['local-1', 'shared'],
      reason: 'a deleted entry must not come back from the mirror',
    );
  });

  test('a delete that never reached Firestore stays deleted', () async {
    final playedAt = DateTime.utc(2026, 7, 23);
    final local = _MemoryHistoryRepository()
      ..stored = [_entry('kept', playedAt.add(const Duration(minutes: 1)))];
    final remote = _MemoryHistoryRepository()
      ..stored = [
        _entry('kept', playedAt.add(const Duration(minutes: 1))),
        _entry('deleted', playedAt),
      ];

    final controller = GameHistoryController(local, remote: remote);
    await controller.load('user-1');
    // The mismatch must be scheduled for the next close-time flush.
    await controller.flushRemote('user-1');

    expect(remote.stored.map((entry) => entry.id), ['kept']);
  });

  test('a reinstall restores history from the remote copy', () async {
    final playedAt = DateTime.utc(2026, 7, 23);
    final remote = _MemoryHistoryRepository()
      ..stored = [_entry('spin-1', playedAt)];
    // Fresh install: nothing was ever written locally.
    final controller = GameHistoryController(
      _MemoryHistoryRepository(),
      remote: remote,
    );

    await controller.load('user-1');

    expect(controller.entries.map((entry) => entry.id), ['spin-1']);
    expect(controller.isRestoredFromBackup, isTrue);
  });

  test('a local history is never flagged as restored', () async {
    final playedAt = DateTime.utc(2026, 7, 23);
    final local = _MemoryHistoryRepository()
      ..stored = [_entry('spin-1', playedAt)];

    final controller = GameHistoryController(
      local,
      remote: _MemoryHistoryRepository()..stored = [_entry('spin-1', playedAt)],
    );
    await controller.load('user-1');

    expect(controller.isRestoredFromBackup, isFalse);
  });

  test('the restored flag clears once the entries are gone', () async {
    final playedAt = DateTime.utc(2026, 7, 23);
    final remote = _MemoryHistoryRepository()
      ..stored = [_entry('spin-1', playedAt)];
    final controller = GameHistoryController(
      _MemoryHistoryRepository(),
      remote: remote,
    );

    await controller.load('user-1');
    expect(controller.isRestoredFromBackup, isTrue);

    // A new spin sits next to the restored one, so the note still applies.
    controller.record(
      userId: 'user-1',
      id: 'spin-2',
      playedAt: playedAt.add(const Duration(minutes: 1)),
      newBalance: 1000,
      bet: 10,
      winAmount: 0,
    );
    expect(controller.isRestoredFromBackup, isTrue);

    controller.delete(userId: 'user-1', ids: {'spin-1'});
    expect(controller.isRestoredFromBackup, isFalse);
  });

  test('deleting every entry survives a reinstall-free restart', () async {
    // Local saved an empty list; that is NOT a fresh install.
    final local = _MemoryHistoryRepository()..stored = const [];
    local.hasStored = true;
    final remote = _MemoryHistoryRepository()
      ..stored = [_entry('deleted', DateTime.utc(2026, 7, 23))];

    final controller = GameHistoryController(local, remote: remote);
    await controller.load('user-1');

    expect(controller.entries, isEmpty);
  });

  test('load does not schedule a flush when both copies agree', () async {
    final playedAt = DateTime.utc(2026, 7, 23);
    final entries = [_entry('spin-1', playedAt)];
    final local = _MemoryHistoryRepository()..stored = entries;
    final remote = _MemoryHistoryRepository()..stored = entries;

    final controller = GameHistoryController(local, remote: remote);
    await controller.load('user-1');
    await controller.flushRemote('user-1');

    expect(remote.saveCalls, 0, reason: 'nothing changed, so no write');
  });

  test('load survives a remote failure', () async {
    final playedAt = DateTime.utc(2026, 7, 23);
    final local = _MemoryHistoryRepository()
      ..stored = [_entry('spin-1', playedAt)];
    final controller = GameHistoryController(
      local,
      remote: _FailingRepository(),
    );

    await controller.load('user-1');

    expect(controller.entries.map((entry) => entry.id), ['spin-1']);
  });
}

GameHistoryEntry _entry(String id, DateTime playedAt) {
  return GameHistoryEntry(
    id: id,
    playedAt: playedAt,
    newBalance: 1000,
    bet: 10,
    winAmount: 0,
  );
}

class _MemoryHistoryRepository
    implements GameHistoryRepository, StoredHistoryProbe {
  int saveCalls = 0;
  List<GameHistoryEntry> stored = const [];
  bool hasStored = false;

  @override
  Future<List<GameHistoryEntry>> load(String userId) async => stored;

  @override
  Future<bool> hasStoredHistory(String userId) async => hasStored;

  @override
  Future<void> save(String userId, List<GameHistoryEntry> entries) async {
    saveCalls++;
    hasStored = true;
    stored = List.of(entries);
  }
}

class _FailingRepository implements GameHistoryRepository {
  @override
  Future<List<GameHistoryEntry>> load(String userId) async =>
      throw Exception('offline');

  @override
  Future<void> save(String userId, List<GameHistoryEntry> entries) async =>
      throw Exception('offline');
}

class _BlockingHistoryRepository implements GameHistoryRepository {
  final Completer<void> _save = Completer<void>();

  @override
  Future<List<GameHistoryEntry>> load(String userId) async => const [];

  @override
  Future<void> save(String userId, List<GameHistoryEntry> entries) {
    return _save.future;
  }

  void completeSave() => _save.complete();
}
