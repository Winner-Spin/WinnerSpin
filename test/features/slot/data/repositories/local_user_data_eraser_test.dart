import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/data/repositories/local_user_data_eraser.dart';

void main() {
  test('covers every per-user file the app writes', () {
    final names = LocalUserDataEraser.fileNamesFor('user-1');

    // These match the names the local repositories build. A repository that
    // renames its file without updating this list would quietly start leaving
    // a deleted player's data on the device.
    expect(names, contains('game_history_user-1.json'));
    expect(names, contains('pending_spin_recovery_user-1.json'));
    expect(names, contains('first_launch_disclaimer_user-1.txt'));
  });

  test('includes the half-written files', () {
    // Both repositories write to `.tmp` and rename. A crash mid-save leaves
    // the temporary file behind, holding the same data as the real one.
    final names = LocalUserDataEraser.fileNamesFor('user-1');

    expect(names, contains('game_history_user-1.json.tmp'));
    expect(names, contains('pending_spin_recovery_user-1.json.tmp'));
  });

  test('names are scoped to the account', () {
    final mine = LocalUserDataEraser.fileNamesFor('user-1');
    final theirs = LocalUserDataEraser.fileNamesFor('user-2');

    // Deleting one account must not be able to reach another one's files.
    expect(mine.toSet().intersection(theirs.toSet()), isEmpty);
  });
}
