import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/remote_spin_sync_cadence_controller.dart';

void main() {
  test('normal spins become due on the tenth completion', () {
    final cadence = RemoteSpinSyncCadenceController();

    for (var spin = 1; spin < 10; spin++) {
      cadence.recordCompleted(isFreeSpin: false);
      expect(cadence.isSyncDue(isFreeSpin: false), isFalse);
    }

    cadence.recordCompleted(isFreeSpin: false);
    expect(cadence.isSyncDue(isFreeSpin: false), isTrue);

    cadence.markSynced(isFreeSpin: false);
    expect(cadence.completedNormalSpins, 0);
    expect(cadence.isSyncDue(isFreeSpin: false), isFalse);
  });

  test('Free Spin cadence is independent from normal spins', () {
    final cadence = RemoteSpinSyncCadenceController();

    for (var spin = 0; spin < 9; spin++) {
      cadence.recordCompleted(isFreeSpin: false);
      cadence.recordCompleted(isFreeSpin: true);
    }

    cadence.recordCompleted(isFreeSpin: true);
    expect(cadence.isSyncDue(isFreeSpin: true), isTrue);
    expect(cadence.isSyncDue(isFreeSpin: false), isFalse);

    cadence.markSynced(isFreeSpin: true);
    expect(cadence.completedFreeSpins, 0);
    expect(cadence.completedNormalSpins, 9);
  });

  test('failed checkpoints remain due until marked as synced', () {
    final cadence = RemoteSpinSyncCadenceController(syncInterval: 2);

    cadence.recordCompleted(isFreeSpin: false);
    cadence.recordCompleted(isFreeSpin: false);
    expect(cadence.isSyncDue(isFreeSpin: false), isTrue);

    cadence.recordCompleted(isFreeSpin: false);
    expect(cadence.isSyncDue(isFreeSpin: false), isTrue);

    cadence.markSynced(isFreeSpin: false);
    expect(cadence.isSyncDue(isFreeSpin: false), isFalse);
  });
}
