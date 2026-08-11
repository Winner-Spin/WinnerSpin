import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/game_history_entry.dart';
import '../../domain/repositories/game_history_repository.dart';
import 'local_user_data_coordinator.dart';

class LocalGameHistoryRepository
    implements GameHistoryRepository, StoredHistoryProbe {
  LocalGameHistoryRepository({
    LocalUserDataCoordinator? coordinator,
    Future<Directory> Function()? directoryProvider,
  }) : _coordinator = coordinator ?? LocalUserDataCoordinator.shared,
       _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory;

  final LocalUserDataCoordinator _coordinator;
  final Future<Directory> Function() _directoryProvider;

  Future<File> _historyFile(String userId) async {
    final directory = await _directoryProvider();
    return File('${directory.path}/game_history_$userId.json');
  }

  /// True once a history file exists for [userId], even if it holds an empty
  /// list. Used to tell a deleted-everything history from a fresh install.
  @override
  Future<bool> hasStoredHistory(String userId) {
    return _coordinator.run(userId, () async {
      final file = await _historyFile(userId);
      if (await file.exists()) return true;
      return File('${file.path}.tmp').exists();
    }, whenBlocked: () => false);
  }

  @override
  Future<List<GameHistoryEntry>> load(String userId) {
    return _coordinator.run(
      userId,
      () => _load(userId),
      whenBlocked: () => const <GameHistoryEntry>[],
    );
  }

  Future<List<GameHistoryEntry>> _load(String userId) async {
    final file = await _historyFile(userId);
    final temporaryFile = File('${file.path}.tmp');
    if (await temporaryFile.exists()) {
      try {
        final entries = await _readEntries(temporaryFile);
        if (await file.exists()) await file.delete();
        await temporaryFile.rename(file.path);
        return entries;
      } catch (_) {
        if (!await file.exists()) rethrow;
      }
    }
    if (!await file.exists()) return const [];
    return _readEntries(file);
  }

  /// Reads every stored entry. Unlike the Firestore mirror this copy is not
  /// capped: the player's full history lives here.
  Future<List<GameHistoryEntry>> _readEntries(File file) async {
    final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(_entryFromJson)
        .toList(growable: false);
  }

  @override
  Future<void> save(String userId, List<GameHistoryEntry> entries) {
    return _coordinator.run(
      userId,
      () => _save(userId, entries),
      whenBlocked: () {},
    );
  }

  Future<void> _save(String userId, List<GameHistoryEntry> entries) async {
    final file = await _historyFile(userId);
    final temporaryFile = File('${file.path}.tmp');
    await temporaryFile.writeAsString(
      jsonEncode(entries.map(_entryToJson).toList(growable: false)),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporaryFile.rename(file.path);
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
