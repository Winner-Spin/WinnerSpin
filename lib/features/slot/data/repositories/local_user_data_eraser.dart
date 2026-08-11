import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'local_user_data_coordinator.dart';

/// Removes everything this device stores for one account.
///
/// Account deletion removes remote profile data first, then calls this eraser
/// while the Firebase Authentication user still exists. A local cleanup
/// failure is surfaced so that final Auth deletion does not run and the player
/// can safely retry.
class LocalUserDataEraser {
  const LocalUserDataEraser({this.coordinator, this.directoryProvider});

  final LocalUserDataCoordinator? coordinator;
  final Future<Directory> Function()? directoryProvider;

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

  /// Tombstones the uid, drains pending writes, and removes all known files.
  ///
  /// Every file is attempted even after one removal fails. Any failure is
  /// rethrown afterward so Firebase Authentication finalization stays blocked
  /// and the deletion can be retried without allowing late local writes.
  Future<void> eraseFor(String userId) async {
    await (coordinator ?? LocalUserDataCoordinator.shared).erase(
      userId,
      () async {
        final Directory directory;
        try {
          directory =
              await (directoryProvider ?? getApplicationDocumentsDirectory)();
        } catch (error, stackTrace) {
          debugPrint(
            'Local user data could not be located: $error\n$stackTrace',
          );
          Error.throwWithStackTrace(error, stackTrace);
        }

        Object? firstError;
        StackTrace? firstStackTrace;
        for (final name in fileNamesFor(userId)) {
          try {
            final file = File('${directory.path}/$name');
            if (await file.exists()) await file.delete();
          } catch (error, stackTrace) {
            firstError ??= error;
            firstStackTrace ??= stackTrace;
            debugPrint(
              'Local user data could not be erased: $error\n$stackTrace',
            );
          }
        }
        if (firstError != null) {
          Error.throwWithStackTrace(firstError, firstStackTrace!);
        }
      },
    );
  }
}
