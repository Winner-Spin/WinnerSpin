import '../models/game_history_entry.dart';

/// Maximum number of history entries mirrored to Firestore.
///
/// Only the remote copy is capped. The local file keeps the player's whole
/// history, because it costs nothing to store; the cap exists to bound the
/// single Firestore document the history is written into. The consequence is
/// deliberate: after a reinstall the account can only hand back the most recent
/// [kMaxRemoteGameHistoryEntries] spins.
const int kMaxRemoteGameHistoryEntries = 10;

abstract class GameHistoryRepository {
  Future<List<GameHistoryEntry>> load(String userId);

  Future<void> save(String userId, List<GameHistoryEntry> entries);
}

/// Optional capability for repositories that can tell "nothing was ever saved"
/// apart from "an empty history was saved".
///
/// That distinction is what makes deletions stick: if the player deletes every
/// entry and the app is killed before the Firestore mirror is written, the next
/// launch must keep the empty local history instead of treating it as a fresh
/// install and restoring the deleted entries from the backup.
abstract interface class StoredHistoryProbe {
  Future<bool> hasStoredHistory(String userId);
}
