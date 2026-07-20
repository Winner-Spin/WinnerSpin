import 'balance_controller.dart';
import 'free_spins_controller.dart';
import 'game_feedback_controller.dart';
import 'player_session_controller.dart';
import 'slot_persistence_controller.dart';
import 'slot_pool_controller.dart';

class SlotSessionLifecycleController {
  Future<void> savePlayerState({
    required SlotPersistenceController persistenceController,
    required BalanceController balanceController,
    required FreeSpinsController freeSpinsController,
    String debugLabel = 'Player state save',
  }) {
    return persistenceController.savePlayerState(
      userId: persistenceController.currentUserId,
      userBalance: balanceController.userBalance,
      lastWin: balanceController.lastWin,
      freeSpinsRemaining: freeSpinsController.remaining,
      freeSpinAccumulatedWin: freeSpinsController.accumulatedWin,
      freeSpinsAwardedThisRound: freeSpinsController.awardedThisRound,
      debugLabel: debugLabel,
    );
  }

  void savePlayerStateSilently({
    required SlotPersistenceController persistenceController,
    required BalanceController balanceController,
    required FreeSpinsController freeSpinsController,
  }) {
    persistenceController.savePlayerStateSilently(
      userId: persistenceController.currentUserId,
      userBalance: balanceController.userBalance,
      lastWin: balanceController.lastWin,
      freeSpinsRemaining: freeSpinsController.remaining,
      freeSpinAccumulatedWin: freeSpinsController.accumulatedWin,
      freeSpinsAwardedThisRound: freeSpinsController.awardedThisRound,
    );
  }

  void savePoolIfNeeded({
    required SlotPoolController poolController,
    required SlotPersistenceController persistenceController,
    required BalanceController balanceController,
    required FreeSpinsController freeSpinsController,
  }) {
    poolController.saveIfNeeded(
      persistenceController: persistenceController,
      userBalance: balanceController.userBalance,
      lastWin: balanceController.lastWin,
      freeSpinsRemaining: freeSpinsController.remaining,
      freeSpinAccumulatedWin: freeSpinsController.accumulatedWin,
      freeSpinsAwardedThisRound: freeSpinsController.awardedThisRound,
    );
  }

  Future<void> forceSavePool({
    required SlotPoolController poolController,
    required SlotPersistenceController persistenceController,
    required BalanceController balanceController,
    required FreeSpinsController freeSpinsController,
  }) {
    return poolController.forceSave(
      persistenceController: persistenceController,
      userBalance: balanceController.userBalance,
      lastWin: balanceController.lastWin,
      freeSpinsRemaining: freeSpinsController.remaining,
      freeSpinAccumulatedWin: freeSpinsController.accumulatedWin,
      freeSpinsAwardedThisRound: freeSpinsController.awardedThisRound,
    );
  }

  Future<void> signOut({
    required PlayerSessionController sessionController,
    required SlotPoolController poolController,
    required SlotPersistenceController persistenceController,
    required BalanceController balanceController,
    required FreeSpinsController freeSpinsController,
  }) {
    return sessionController.signOut(
      forceSave: () => forceSavePool(
        poolController: poolController,
        persistenceController: persistenceController,
        balanceController: balanceController,
        freeSpinsController: freeSpinsController,
      ),
      signOut: persistenceController.signOut,
    );
  }

  Future<void> deleteAccount({
    required PlayerSessionController sessionController,
    required SlotPersistenceController persistenceController,
  }) {
    return sessionController.deleteAccount(
      deleteAccount: persistenceController.deleteAccount,
    );
  }

  Future<void> onAppLifecycleEvent({
    required GameFeedbackController feedbackController,
    required SlotPoolController poolController,
    required SlotPersistenceController persistenceController,
    required BalanceController balanceController,
    required FreeSpinsController freeSpinsController,
  }) async {
    await Future.wait([
      feedbackController.pauseForLifecycle(),
      forceSavePool(
        poolController: poolController,
        persistenceController: persistenceController,
        balanceController: balanceController,
        freeSpinsController: freeSpinsController,
      ),
    ]);
  }

  void onAppResumed({required GameFeedbackController feedbackController}) {
    feedbackController.resumeAfterLifecycle();
  }

  Future<bool> validateSessionOnResume({
    required PlayerSessionController sessionController,
    required SlotPersistenceController persistenceController,
  }) async {
    final isSessionActive = await persistenceController.refreshCurrentSession();
    if (isSessionActive) return true;

    await sessionController.markSessionExpired();
    return false;
  }
}
