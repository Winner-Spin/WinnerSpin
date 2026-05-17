import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/game_history_entry.dart';
import '../../domain/repositories/game_history_repository.dart';

class LocalGameHistoryRepository implements GameHistoryRepository {
  Future<File> _historyFile(String userId) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/game_history_$userId.json');
  }

  @override
  Future<List<GameHistoryEntry>> load(String userId) async {
    final file = await _historyFile(userId);
    if (!await file.exists()) return const [];

    final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(_entryFromJson)
        .take(30)
        .toList(growable: false);
  }

  @override
  Future<void> save(String userId, List<GameHistoryEntry> entries) async {
    final file = await _historyFile(userId);
    await file.writeAsString(
      jsonEncode(entries.map(_entryToJson).toList(growable: false)),
    );
  }

  GameHistoryEntry _entryFromJson(Map<String, dynamic> json) {
    final playedAt = DateTime.parse(json['playedAt'] as String);
    return GameHistoryEntry(
      id: json['id'] as String? ?? playedAt.microsecondsSinceEpoch.toString(),
      playedAt: playedAt,
      newBalance: (json['newBalance'] as num).toDouble(),
      bet: (json['bet'] as num).toDouble(),
      winAmount: (json['winAmount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> _entryToJson(GameHistoryEntry entry) {
    return {
      'id': entry.id,
      'playedAt': entry.playedAt.toIso8601String(),
      'newBalance': entry.newBalance,
      'bet': entry.bet,
      'winAmount': entry.winAmount,
    };
  }
}
