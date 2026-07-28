import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/game_history_entry.dart';
import '../../domain/repositories/game_history_repository.dart';

/// Firestore implementation of [GameHistoryRepository].
///
/// The history is stored as a bounded array field on the user document so a
/// full sync costs a single read and a single write. Writes are only issued
/// when the app is closing (see `GameHistoryController.flushRemote`), never on
/// every spin.
class FirestoreGameHistoryRepository implements GameHistoryRepository {
  FirestoreGameHistoryRepository({FirebaseFirestore? firestore})
    : _injectedDb = firestore;

  final FirebaseFirestore? _injectedDb;

  /// Resolved lazily so constructing the repository never requires an
  /// initialized Firebase app (keeps widget tests cheap).
  FirebaseFirestore get _db => _injectedDb ?? FirebaseFirestore.instance;

  static const String _collection = 'users';
  static const String _field = 'gameHistory';

  @override
  Future<List<GameHistoryEntry>> load(String userId) async {
    final doc = await _db.collection(_collection).doc(userId).get();
    if (!doc.exists) return const [];

    final data = doc.data();
    final raw = data?[_field];
    if (raw is! List) return const [];

    final entries = <GameHistoryEntry>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final entry = _entryFromMap(Map<String, dynamic>.from(item));
      if (entry != null) entries.add(entry);
    }
    entries.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return entries.take(kMaxRemoteGameHistoryEntries).toList(growable: false);
  }

  @override
  Future<void> save(String userId, List<GameHistoryEntry> entries) {
    final payload = entries
        .take(kMaxRemoteGameHistoryEntries)
        .map(_entryToMap)
        .toList(growable: false);
    return _db.collection(_collection).doc(userId).set({
      _field: payload,
    }, SetOptions(merge: true));
  }

  GameHistoryEntry? _entryFromMap(Map<String, dynamic> map) {
    final playedAt = _parsePlayedAt(map['playedAt']);
    if (playedAt == null) return null;

    final newBalance = map['newBalance'];
    final bet = map['bet'];
    final winAmount = map['winAmount'];
    if (newBalance is! num || bet is! num || winAmount is! num) return null;

    return GameHistoryEntry(
      id: map['id'] as String? ?? playedAt.microsecondsSinceEpoch.toString(),
      playedAt: playedAt,
      newBalance: newBalance.toDouble(),
      bet: bet.toDouble(),
      winAmount: winAmount.toDouble(),
    );
  }

  DateTime? _parsePlayedAt(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> _entryToMap(GameHistoryEntry entry) {
    return {
      'id': entry.id,
      'playedAt': entry.playedAt.toIso8601String(),
      'newBalance': entry.newBalance,
      'bet': entry.bet,
      'winAmount': entry.winAmount,
    };
  }
}
