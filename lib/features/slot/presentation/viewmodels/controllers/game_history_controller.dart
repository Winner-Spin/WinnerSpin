import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/models/game_history_entry.dart';
import '../../../domain/repositories/game_history_repository.dart';

class GameHistoryController {
  GameHistoryController(this._repository);

  final GameHistoryRepository _repository;
  final List<GameHistoryEntry> _entries = [];

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
  }) {
    final playedAt = DateTime.now();
    _entries.insert(
      0,
      GameHistoryEntry(
        id: playedAt.microsecondsSinceEpoch.toString(),
        playedAt: playedAt,
        newBalance: newBalance,
        bet: bet,
        winAmount: winAmount,
      ),
    );
    if (_entries.length > 30) {
      _entries.removeLast();
    }
    _saveIfPossible(userId);
  }

  void delete({required String? userId, required Set<String> ids}) {
    if (ids.isEmpty) return;
    _entries.removeWhere((entry) => ids.contains(entry.id));
    _saveIfPossible(userId);
  }

  void _saveIfPossible(String? userId) {
    if (userId == null) return;
    unawaited(_save(userId));
  }

  Future<void> _save(String userId) async {
    try {
      await _repository.save(userId, _entries);
    } catch (e) {
      debugPrint('Game history save error: $e');
    }
  }
}
