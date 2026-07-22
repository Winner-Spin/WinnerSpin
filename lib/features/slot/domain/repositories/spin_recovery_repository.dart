import '../models/pending_spin_recovery.dart';

abstract class SpinRecoveryRepository {
  Future<PendingSpinRecovery?> load(String userId);

  Future<void> save(String userId, PendingSpinRecovery recovery);

  Future<void> clear(String userId, String spinId);
}
