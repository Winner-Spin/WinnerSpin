class RemoteSpinSyncCadenceController {
  RemoteSpinSyncCadenceController({this.syncInterval = 10})
    : assert(syncInterval > 0);

  final int syncInterval;

  int _completedNormalSpins = 0;
  int _completedFreeSpins = 0;

  int get completedNormalSpins => _completedNormalSpins;

  int get completedFreeSpins => _completedFreeSpins;

  void recordCompleted({required bool isFreeSpin}) {
    if (isFreeSpin) {
      _completedFreeSpins++;
    } else {
      _completedNormalSpins++;
    }
  }

  bool isSyncDue({required bool isFreeSpin}) {
    final completed = isFreeSpin ? _completedFreeSpins : _completedNormalSpins;
    return completed >= syncInterval;
  }

  void markSynced({required bool isFreeSpin}) {
    if (isFreeSpin) {
      _completedFreeSpins = 0;
    } else {
      _completedNormalSpins = 0;
    }
  }

  void reset() {
    _completedNormalSpins = 0;
    _completedFreeSpins = 0;
  }
}
