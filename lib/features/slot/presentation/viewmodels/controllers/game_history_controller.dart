import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/models/game_history_entry.dart';
import '../../../domain/repositories/game_history_repository.dart';

/// Owns the in-memory game history list.
///
/// Local persistence happens after every recorded spin so an unexpected kill
/// never loses the session, and it keeps the player's *entire* history. The
/// Firestore mirror is written only through [flushRemote], which the app calls
/// when it is going to the background or closing, and holds at most
/// [kMaxRemoteGameHistoryEntries] entries — enough to give a reinstalled device
/// its recent spins back without paying for a write per spin.
class GameHistoryController {
  GameHistoryController(this._repository, {GameHistoryRepository? remote})
    : _remoteRepository = remote;

  final GameHistoryRepository _repository;
  final GameHistoryRepository? _remoteRepository;
  final List<GameHistoryEntry> _entries = [];
  final Map<String, Future<void>> _pendingRecordSaves = {};
  final Set<String> _restoredIds = {};
  Future<void> _remoteFlush = Future<void>.value();

  /// IDs last observed in the bounded Firestore mirror.
  List<String> _mirroredIds = const [];

  List<GameHistoryEntry> get entries => List.unmodifiable(_entries);

  /// True while the list still shows entries that came from the Firestore
  /// backup rather than from this device.
  ///
  /// That only happens on a device with no local history — a fresh install or a
  /// reinstall — and it is the one case where the list is knowingly incomplete,
  /// since the backup keeps just the last [kMaxRemoteGameHistoryEntries] spins.
  /// The history screen uses this to explain the gap instead of letting the
  /// player assume the rest was lost silently.
  bool get isRestoredFromBackup =>
      _entries.any((entry) => _restoredIds.contains(entry.id));

  /// Restores the history for [userId].
  ///
  /// The local copy is authoritative whenever it exists, because it is written
  /// synchronously on every spin and every delete. The Firestore mirror is only
  /// consulted when this device has no local copy at all — a fresh install or a
  /// reinstall — which is exactly the case the backup exists for.
  ///
  /// Preferring local over a union of both is what keeps deletions deleted: a
  /// merge would resurrect entries that were removed locally but not yet
  /// mirrored (the app can be killed before the close-time flush runs).
  Future<void> load(String userId) async {
    final localEntries = await _loadLocal(userId);
    final hasLocalCopy = localEntries.isNotEmpty || await _hasLocalCopy(userId);

    if (hasLocalCopy) {
      final ordered = _newestFirst(localEntries);
      _entries
        ..clear()
        ..addAll(ordered);
      _restoredIds.clear();
      final mirrored = _newestFirst(await _loadRemote(userId));
      _mirroredIds = _idsOf(_remoteSlice(mirrored));
      return;
    }

    final remoteEntries = _newestFirst(await _loadRemote(userId));
    _entries
      ..clear()
      ..addAll(remoteEntries);
    _restoredIds
      ..clear()
      ..addAll(remoteEntries.map((entry) => entry.id));
    _mirroredIds = _idsOf(remoteEntries);
  }

  Future<bool> _hasLocalCopy(String userId) async {
    final repository = _repository;
    if (repository is! StoredHistoryProbe) return false;
    // An explicit cast is required: `StoredHistoryProbe` is a standalone
    // interface, not a subtype of `GameHistoryRepository`, so the type test
    // above cannot promote `repository` on its own.
    final probe = repository as StoredHistoryProbe;
    try {
      return await probe.hasStoredHistory(userId);
    } catch (e) {
      debugPrint('Game history probe error: $e');
      return false;
    }
  }

  Future<List<GameHistoryEntry>> _loadLocal(String userId) async {
    try {
      return await _repository.load(userId);
    } catch (e) {
      debugPrint('Game history load error: $e');
      return const [];
    }
  }

  Future<List<GameHistoryEntry>> _loadRemote(String userId) async {
    final remote = _remoteRepository;
    if (remote == null) return const [];
    try {
      return await remote.load(userId);
    } catch (e) {
      debugPrint('Game history remote load error: $e');
      return const [];
    }
  }

  List<GameHistoryEntry> _newestFirst(List<GameHistoryEntry> entries) {
    return List.of(entries)..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  }

  /// The part of the history that fits in the Firestore mirror.
  List<GameHistoryEntry> _remoteSlice(List<GameHistoryEntry> entries) {
    return entries.take(kMaxRemoteGameHistoryEntries).toList(growable: false);
  }

  List<String> _idsOf(List<GameHistoryEntry> entries) {
    return entries.map((entry) => entry.id).toList(growable: false);
  }

  bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void record({
    required String? userId,
    required double newBalance,
    required double bet,
    required double winAmount,
    String? id,
    DateTime? playedAt,
  }) {
    final timestamp = playedAt ?? DateTime.now();
    final entryId = id ?? timestamp.microsecondsSinceEpoch.toString();
    if (_entries.any((entry) => entry.id == entryId)) return;

    _entries.insert(
      0,
      GameHistoryEntry(
        id: entryId,
        playedAt: timestamp,
        newBalance: newBalance,
        bet: bet,
        winAmount: winAmount,
      ),
    );
    if (userId == null) return;

    final save = _repository.save(userId, List.of(_entries));
    _pendingRecordSaves[entryId] = save;
    unawaited(
      save.then<void>(
        (_) {
          if (identical(_pendingRecordSaves[entryId], save)) {
            _pendingRecordSaves.remove(entryId);
          }
        },
        onError: (Object error, StackTrace _) {
          debugPrint('Game history save error: $error');
        },
      ),
    );
  }

  Future<void> recordOnce({
    required String? userId,
    required String id,
    required DateTime playedAt,
    required double newBalance,
    required double bet,
    required double winAmount,
  }) async {
    if (_entries.any((entry) => entry.id == id)) {
      final pendingSave = _pendingRecordSaves[id];
      if (pendingSave != null) await pendingSave;
      return;
    }

    final nextEntries = <GameHistoryEntry>[
      GameHistoryEntry(
        id: id,
        playedAt: playedAt,
        newBalance: newBalance,
        bet: bet,
        winAmount: winAmount,
      ),
      ..._entries,
    ];
    if (userId != null) {
      await _repository.save(userId, nextEntries);
    }
    _entries
      ..clear()
      ..addAll(nextEntries);
  }

  void delete({required String? userId, required Set<String> ids}) {
    if (ids.isEmpty) return;
    _entries.removeWhere((entry) => ids.contains(entry.id));
    _saveIfPossible(userId);
  }

  /// Mirrors the current history to Firestore. Called when the app goes to the
  /// background / closes and on sign-out — never per spin.
  Future<void> flushRemote(String? userId) {
    final remote = _remoteRepository;
    if (remote == null || userId == null) return Future<void>.value();

    // Only the newest entries are mirrored; the rest stay on the device.
    final snapshot = _remoteSlice(_entries);
    final snapshotIds = _idsOf(snapshot);
    // Deleting a round the mirror never held — anything past the newest
    // [kMaxRemoteGameHistoryEntries] — leaves this slice untouched, so there is
    // nothing to upload. Comparing here is what keeps that case free.
    if (_sameIds(snapshotIds, _mirroredIds)) return Future<void>.value();

    final flush = _remoteFlush.then((_) async {
      try {
        await remote.save(userId, snapshot);
        _mirroredIds = snapshotIds;
      } catch (error) {
        debugPrint('Game history remote flush error: $error');
      }
    });
    _remoteFlush = flush;
    return flush;
  }

  void _saveIfPossible(String? userId) {
    if (userId == null) return;
    unawaited(
      _save(userId).catchError((Object error) {
        debugPrint('Game history save error: $error');
      }),
    );
  }

  Future<void> _save(String userId) async {
    await _repository.save(userId, List.of(_entries));
  }
}
