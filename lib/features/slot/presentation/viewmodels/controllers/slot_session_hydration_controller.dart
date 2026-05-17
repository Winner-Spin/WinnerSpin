import 'package:flutter/foundation.dart';

import 'balance_controller.dart';
import 'free_spins_controller.dart';
import 'game_history_controller.dart';
import 'player_session_controller.dart';
import 'slot_persistence_controller.dart';
import 'slot_pool_controller.dart';

class SlotSessionHydrationController {
  Future<void> hydrate({
    required SlotPersistenceController persistenceController,
    required GameHistoryController historyController,
    required SlotPoolController poolController,
    required PlayerSessionController sessionController,
    required BalanceController balanceController,
    required FreeSpinsController freeSpinsController,
    required VoidCallback savePlayerState,
  }) async {
    try {
      final userId = persistenceController.currentUserId;
      if (userId == null) return;

      await historyController.load(userId);

      final sessionData = await persistenceController.loadUserSession(userId);
      final userData = sessionData.userData;
      poolController.hydrate(sessionData.pool);

      sessionController.listenToUserBalance(
        stream: persistenceController.watchUserData(userId),
        onBalanceChanged: balanceController.applyRemoteUserBalance,
      );

      if (userData == null) {
        sessionController.applyUserData(null);
        return;
      }

      sessionController.applyUserData(userData);
      balanceController.hydrate(userData);
      freeSpinsController.hydrate(userData);

      if (!userData.containsKey('userBalance')) {
        savePlayerState();
      }
    } catch (error) {
      debugPrint('Data fetch error: $error');
      sessionController.markError();
    } finally {
      sessionController.finishLoading();
    }
  }
}
