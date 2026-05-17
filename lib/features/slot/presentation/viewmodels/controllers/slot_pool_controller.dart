import '../../../domain/models/pool_state.dart';
import 'slot_persistence_controller.dart';

class SlotPoolController {
  PoolState _pool = PoolState();

  PoolState get pool => _pool;

  void hydrate(PoolState pool) {
    _pool = pool;
  }

  void applySpinPool(PoolState pool) {
    _pool = pool;
  }

  void recordBet(double amount) {
    _pool.recordBet(amount);
  }

  void recordPayout(double amount) {
    _pool.recordPayout(amount);
  }

  void saveIfNeeded({
    required SlotPersistenceController persistenceController,
    required double userBalance,
    required int freeSpinsRemaining,
  }) {
    persistenceController.savePoolIfNeeded(
      userId: persistenceController.currentUserId,
      pool: _pool,
      userBalance: userBalance,
      freeSpinsRemaining: freeSpinsRemaining,
    );
  }

  Future<void> forceSave({
    required SlotPersistenceController persistenceController,
    required double userBalance,
    required int freeSpinsRemaining,
  }) {
    return persistenceController.forceSavePool(
      userId: persistenceController.currentUserId,
      pool: _pool,
      userBalance: userBalance,
      freeSpinsRemaining: freeSpinsRemaining,
    );
  }
}
