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
