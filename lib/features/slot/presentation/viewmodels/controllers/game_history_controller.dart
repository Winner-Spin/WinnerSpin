import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/models/game_history_entry.dart';
import '../../../domain/repositories/game_history_repository.dart';

class GameHistoryController {
  GameHistoryController(this._repository);

  final GameHistoryRepository _repository;
  final List<GameHistoryEntry> _entries = [];
  final Map<String, Future<void>> _pendingRecordSaves = {};

  List<GameHistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> load(String userId) async {
    try {
      _entries
        ..clear()
        ..addAll(await _repository.load(userId));
    } catch (e) {
      debugPrint('Game history load error: $e');
    }
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
    if (_entries.length > 30) {
      _entries.removeLast();
    }
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
    ].take(30).toList(growable: false);
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
