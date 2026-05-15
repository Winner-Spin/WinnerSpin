import '../models/game_history_entry.dart';

abstract class GameHistoryRepository {
  Future<List<GameHistoryEntry>> load(String userId);

  Future<void> save(String userId, List<GameHistoryEntry> entries);
}
