import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/data/repositories/local_game_history_repository.dart';
import 'package:winner_spin/features/slot/domain/engine/slot_engine.dart';
import 'package:winner_spin/features/slot/domain/engine/spin_task.dart';
import 'package:winner_spin/features/slot/domain/models/pool_state.dart';
import 'package:winner_spin/features/slot/domain/models/spin_result.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/ante_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/auto_spin_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/balance_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/free_spins_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/game_history_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/grid_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/insufficient_funds_hint_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/slot_pool_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/slot_spin_completion_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/slot_spin_flow_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/slot_spin_start_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/spin_execution_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/spin_lifecycle_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/spin_result_settlement_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/spin_round_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/tumble_sequence_controller.dart';

void main() {
  test('reel completion waits for a delayed spin result', () async {
    final roundController = SpinRoundController();
    final balanceController = BalanceController();
    final freeSpinsController = FreeSpinsController()..awardInitial();
    final gridController = GridController(_emptyGrid());
    final anteController = AnteController();
    final autoSpinController = AutoSpinController();
    final poolController = SlotPoolController();
    final tumbleController = TumbleSequenceController();
    final lifecycleController = SpinLifecycleController();
    final executionController = _DelayedSpinExecutionController();
    var completionFinished = false;
    var playerStateSaveCount = 0;

    final spin = SlotSpinFlowController().spin(
      startController: SlotSpinStartController(),
      lifecycleController: lifecycleController,
      executionController: executionController,
      balanceController: balanceController,
      freeSpinsController: freeSpinsController,
      autoSpinController: autoSpinController,
      insufficientHintController: InsufficientFundsHintController(),
      poolController: poolController,
      roundController: roundController,
      anteController: anteController,
      tumbleController: tumbleController,
      gridController: gridController,
      isBusy: false,
      isInFreeSpins: true,
      betAmount: balanceController.betAmount,
      vibrationEnabled: false,
      prepareRecovery: (_) async {},
      commitPendingFreeSpinConsume: freeSpinsController.commitPendingConsume,
      notifyListeners: () {},
    );

    final completion = SlotSpinCompletionController()
        .complete(
          lifecycleController: lifecycleController,
          roundController: roundController,
          tumbleController: tumbleController,
          settlementController: SpinResultSettlementController(),
          balanceController: balanceController,
          historyController: GameHistoryController(
            LocalGameHistoryRepository(),
          ),
          gridController: gridController,
          freeSpinsController: freeSpinsController,
          anteController: anteController,
          poolController: poolController,
          autoSpinController: autoSpinController,
          userId: null,
          vibrationEnabled: false,
          isInFreeSpins: () => freeSpinsController.isInRound,
          savePlayerState: () => playerStateSaveCount++,
          savePoolIfNeeded: () {},
          finalizeRecovery: (_) {},
          notifyListeners: () {},
        )
        .then((_) => completionFinished = true);

    await Future<void>.delayed(Duration.zero);
    expect(completionFinished, isFalse);
    expect(roundController.isSpinning, isTrue);

    final result = SpinResult(
      initialGrid: _emptyGrid(),
      tumbles: const [],
      totalWin: 42.5,
      tumbleCount: 0,
      freeSpinsTriggered: false,
      scatterCount: 0,
      scatterPayout: 0,
    );
    executionController.complete(result, poolController.pool);
    await spin;
    await completion;

    expect(completionFinished, isTrue);
    expect(roundController.isSpinning, isFalse);
    expect(roundController.lastSpinResult, same(result));
    expect(roundController.pendingResult, isNull);
    expect(freeSpinsController.remaining, 9);
    expect(freeSpinsController.accumulatedWin, 42.5);
    expect(playerStateSaveCount, 1);

    balanceController.dispose();
    freeSpinsController.dispose();
    gridController.dispose();
    anteController.dispose();
  });
}

class _DelayedSpinExecutionController extends SpinExecutionController {
  final Completer<SpinTaskOutput> _result = Completer<SpinTaskOutput>();

  @override
  Future<SpinTaskOutput> run({
    required PoolState pool,
    required double betAmount,
    required bool isFreeSpins,
    required bool anteBet,
    required bool buyFs,
    bool forceFsTrigger = false,
  }) {
    return _result.future;
  }

  void complete(SpinResult result, PoolState pool) {
    _result.complete(SpinTaskOutput(result: result, pool: pool));
  }
}

List<List<String>> _emptyGrid() {
  return List.generate(
    SlotEngine.columns,
    (_) => List.filled(SlotEngine.rows, 'H1'),
  );
}
