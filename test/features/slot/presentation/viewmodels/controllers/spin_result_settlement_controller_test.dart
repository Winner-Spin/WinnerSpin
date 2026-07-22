import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/engine/slot_engine.dart';
import 'package:winner_spin/features/slot/domain/models/pending_spin_recovery.dart';
import 'package:winner_spin/features/slot/domain/models/spin_result.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/ante_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/balance_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/free_spins_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/slot_pool_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/spin_result_settlement_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/spin_round_controller.dart';

void main() {
  test('normal spin recovery stores the final multiplier-inclusive win', () {
    final fixture = _RecoveryFixture()..beginNormalSpin();

    final recovery = fixture.createRecovery(_result(totalWin: 150));

    expect(recovery.historyBet, 100);
    expect(recovery.userBalance, 1050);
    expect(recovery.winAmount, 150);
    expect(recovery.poolTotalBetsPlaced, 100);
    expect(recovery.poolTotalPaidOut, 150);
    expect(recovery.poolTotalSpins, 1);
    expect(recovery.pendingFreeSpinAward, 0);
    fixture.dispose();
  });

  test('last Free Spin recovery closes the round without losing its win', () {
    final fixture = _RecoveryFixture()
      ..hydrateFreeSpins(remaining: 1, accumulatedWin: 80, awarded: 10)
      ..beginFreeSpin();

    final recovery = fixture.createRecovery(_result(totalWin: 40));

    expect(recovery.userBalance, 1040);
    expect(recovery.freeSpinsRemaining, 0);
    expect(recovery.freeSpinAccumulatedWin, 0);
    expect(recovery.freeSpinsAwardedThisRound, 0);
    fixture.dispose();
  });

  test(
    'retrigger recovery applies the win and defers the +5 acknowledgement',
    () {
      final fixture = _RecoveryFixture()
        ..hydrateFreeSpins(remaining: 1, accumulatedWin: 80, awarded: 10)
        ..beginFreeSpin();

      final recovery = fixture.createRecovery(
        _result(totalWin: 40, freeSpinsTriggered: true, isRetrigger: true),
      );

      expect(recovery.userBalance, 1040);
      expect(recovery.freeSpinsRemaining, 5);
      expect(recovery.freeSpinAccumulatedWin, 120);
      expect(recovery.freeSpinsAwardedThisRound, 15);
      expect(recovery.pendingFreeSpinAward, 5);
      fixture.dispose();
    },
  );
}

class _RecoveryFixture {
  final settlementController = SpinResultSettlementController();
  final roundController = SpinRoundController();
  final balanceController = BalanceController()
    ..hydrate({'userBalance': 1000.0});
  final freeSpinsController = FreeSpinsController();
  final anteController = AnteController();
  final poolController = SlotPoolController();

  void beginNormalSpin() {
    roundController.beginNormalSpin(100);
    balanceController.charge(100);
    poolController.recordBet(100);
  }

  void hydrateFreeSpins({
    required int remaining,
    required double accumulatedWin,
    required int awarded,
  }) {
    freeSpinsController.hydrate({
      'freeSpinsRemaining': remaining,
      'freeSpinAccumulatedWin': accumulatedWin,
      'freeSpinsAwardedThisRound': awarded,
    });
  }

  void beginFreeSpin() {
    roundController.beginFreeSpin();
  }

  PendingSpinRecovery createRecovery(SpinResult result) {
    return settlementController.createRecovery(
      spinId: 'spin-1',
      playedAt: DateTime.utc(2026, 7, 23),
      result: result,
      roundController: roundController,
      balanceController: balanceController,
      freeSpinsController: freeSpinsController,
      anteController: anteController,
      poolController: poolController,
    );
  }

  void dispose() {
    balanceController.dispose();
    freeSpinsController.dispose();
    anteController.dispose();
  }
}

SpinResult _result({
  required double totalWin,
  bool freeSpinsTriggered = false,
  bool isRetrigger = false,
}) {
  return SpinResult(
    initialGrid: List.generate(
      SlotEngine.columns,
      (_) => List.filled(SlotEngine.rows, 'H1'),
    ),
    tumbles: const [],
    totalWin: totalWin,
    tumbleCount: 0,
    freeSpinsTriggered: freeSpinsTriggered,
    isRetrigger: isRetrigger,
    scatterCount: 0,
    scatterPayout: 0,
  );
}
