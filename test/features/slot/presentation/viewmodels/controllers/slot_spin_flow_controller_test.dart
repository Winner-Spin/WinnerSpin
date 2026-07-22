import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/engine/slot_engine.dart';
import 'package:winner_spin/features/slot/domain/engine/spin_task.dart';
import 'package:winner_spin/features/slot/domain/models/pool_state.dart';
import 'package:winner_spin/features/slot/domain/models/spin_result.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/ante_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/auto_spin_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/balance_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/free_spins_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/grid_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/insufficient_funds_hint_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/slot_pool_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/slot_spin_flow_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/slot_spin_start_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/spin_execution_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/spin_lifecycle_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/spin_round_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/tumble_sequence_controller.dart';

void main() {
  test('free spins do not consume the paid autoplay counter', () async {
    final fixture = _SpinFlowFixture();
    fixture.freeSpinsController.awardInitial();
    fixture.autoSpinController.start(7, speedMultiplier: 1);

    await fixture.spin(isInFreeSpins: true);

    expect(fixture.executionController.lastSpinWasFree, isTrue);
    expect(fixture.autoSpinController.remaining, 7);
    expect(fixture.freeSpinsController.remaining, 9);

    fixture.dispose();
  });

  test('normal autoplay spins still consume one autoplay entry', () async {
    final fixture = _SpinFlowFixture();
    fixture.autoSpinController.start(7, speedMultiplier: 1);

    await fixture.spin(isInFreeSpins: false);

    expect(fixture.executionController.lastSpinWasFree, isFalse);
    expect(fixture.autoSpinController.remaining, 6);

    fixture.dispose();
  });
}

class _SpinFlowFixture {
  final flowController = SlotSpinFlowController();
  final startController = SlotSpinStartController();
  final lifecycleController = SpinLifecycleController();
  final executionController = _FakeSpinExecutionController();
  final balanceController = BalanceController();
  final freeSpinsController = FreeSpinsController();
  final autoSpinController = AutoSpinController();
  final insufficientHintController = InsufficientFundsHintController();
  final poolController = SlotPoolController();
  final roundController = SpinRoundController();
  final anteController = AnteController();
  final tumbleController = TumbleSequenceController();
  final gridController = GridController(_emptyGrid());

  Future<void> spin({required bool isInFreeSpins}) {
    return flowController.spin(
      startController: startController,
      lifecycleController: lifecycleController,
      executionController: executionController,
      balanceController: balanceController,
      freeSpinsController: freeSpinsController,
      autoSpinController: autoSpinController,
      insufficientHintController: insufficientHintController,
      poolController: poolController,
      roundController: roundController,
      anteController: anteController,
      tumbleController: tumbleController,
      gridController: gridController,
      isBusy: false,
      isInFreeSpins: isInFreeSpins,
      betAmount: balanceController.betAmount,
      vibrationEnabled: false,
      prepareRecovery: (_) async {},
      commitPendingFreeSpinConsume: freeSpinsController.commitPendingConsume,
      notifyListeners: () {},
    );
  }

  void dispose() {
    balanceController.dispose();
    freeSpinsController.dispose();
    insufficientHintController.dispose();
    gridController.dispose();
  }
}

class _FakeSpinExecutionController extends SpinExecutionController {
  bool? lastSpinWasFree;

  @override
  Future<SpinTaskOutput> run({
    required PoolState pool,
    required double betAmount,
    required bool isFreeSpins,
    required bool anteBet,
    required bool buyFs,
    bool forceFsTrigger = false,
  }) async {
    lastSpinWasFree = isFreeSpins;
    return SpinTaskOutput(
      pool: pool,
      result: SpinResult(
        initialGrid: _emptyGrid(),
        tumbles: const [],
        totalWin: 0,
        tumbleCount: 0,
        freeSpinsTriggered: false,
        scatterCount: 0,
        scatterPayout: 0,
      ),
    );
  }
}

List<List<String>> _emptyGrid() {
  return List.generate(
    SlotEngine.columns,
    (_) => List.filled(SlotEngine.rows, 'H1'),
  );
}
