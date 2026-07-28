import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Removes everything this device stores for one account.
///
/// Deleting the account clears Firestore and Firebase Auth, but the device
/// keeps its own copies — the game history, the pending-spin recovery file and
/// the disclaimer acceptance. They are named after a uid that will never exist
/// again, so nothing would ever read them, yet leaving a deleted player's data
/// sitting on the phone is not what "delete my account" promises.
class LocalUserDataEraser {
  const LocalUserDataEraser();

  /// File names, without the directory, that belong to [userId].
  ///
  /// Kept in one place so a repository that changes its naming is one grep
  /// away from being noticed here.
  @visibleForTesting
  static List<String> fileNamesFor(String userId) {
    return [
      'game_history_$userId.json',
      // Both repositories write to a `.tmp` and rename. A crash mid-save
      // leaves the temporary file holding the same data.
      'game_history_$userId.json.tmp',
      'pending_spin_recovery_$userId.json',
      'pending_spin_recovery_$userId.json.tmp',
      'first_launch_disclaimer_$userId.txt',
    ];
  }

  /// Best effort: a file that refuses to go is not a reason to tell the player
  /// their account survived, since the account itself is already gone.
  Future<void> eraseFor(String userId) async {
    final Directory directory;
    try {
      directory = await getApplicationDocumentsDirectory();
    } catch (error) {
      debugPrint('Local user data could not be located: $error');
      return;
    }

    for (final name in fileNamesFor(userId)) {
      try {
        final file = File('${directory.path}/$name');
        if (await file.exists()) await file.delete();
      } catch (error) {
        debugPrint('Local user data could not be erased: $error');
      }
    }
  }
}
