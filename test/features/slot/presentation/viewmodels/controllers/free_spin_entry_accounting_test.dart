import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/engine/slot_engine.dart';
import 'package:winner_spin/features/slot/domain/models/game_history_entry.dart';
import 'package:winner_spin/features/slot/domain/models/pool_state.dart';
import 'package:winner_spin/features/slot/domain/models/spin_result.dart';
import 'package:winner_spin/features/slot/domain/repositories/game_history_repository.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/ante_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/auto_spin_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/balance_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/free_spins_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/game_history_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/grid_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/slot_pool_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/slot_spin_completion_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/spin_lifecycle_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/spin_result_settlement_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/spin_round_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/tumble_sequence_controller.dart';

void main() {
  test(
    'natural entry win reaches balance, pool, history, and FS total',
    () async {
      final fixture = _EntryAccountingFixture(
        balance: 2000,
        pool: PoolState(
          totalBetsPlaced: 10000,
          totalPaidOut: 8500,
          totalSpins: 50,
        ),
      );
      fixture.beginNaturalEntry(bet: 100);

      await fixture.complete(_entryResult(totalWin: 1000, scatterCount: 6));

      expect(fixture.balance.balance, 2900);
      expect(fixture.balance.lastWin, 1000);
      expect(fixture.pool.pool.totalBetsPlaced, 10100);
      expect(fixture.pool.pool.totalPaidOut, 9500);
      expect(fixture.freeSpins.remaining, 10);
      expect(fixture.freeSpins.accumulatedWin, 1000);
      expect(fixture.freeSpins.currentRoundFromBuy, isFalse);
      expect(fixture.history.entries.single.bet, 100);
      expect(fixture.history.entries.single.winAmount, 1000);
      expect(fixture.playerStateSaveCount, 1);
      expect(fixture.poolSaveCount, 1);
      expect(fixture.recoveryFinalizeCount, 0);

      fixture.dispose();
    },
  );

  test(
    'bought entry win reaches balance, pool, history, and FS total',
    () async {
      final fixture = _EntryAccountingFixture(
        balance: 1000000,
        pool: PoolState(
          totalBetsPlaced: 1000000,
          totalPaidOut: 965000,
          totalSpins: 200,
        ),
      );
      fixture.beginBoughtEntry(price: 500000);

      await fixture.complete(_entryResult(totalWin: 50000, scatterCount: 6));

      expect(fixture.balance.balance, 550000);
      expect(fixture.balance.lastWin, 50000);
      expect(fixture.pool.pool.totalBetsPlaced, 1500000);
      expect(fixture.pool.pool.totalPaidOut, 1015000);
      expect(fixture.freeSpins.remaining, 10);
      expect(fixture.freeSpins.accumulatedWin, 50000);
      expect(fixture.freeSpins.currentRoundFromBuy, isTrue);
      expect(fixture.history.entries.single.bet, 0);
      expect(fixture.history.entries.single.winAmount, 50000);
      expect(fixture.playerStateSaveCount, 1);
      expect(fixture.poolSaveCount, 1);
      expect(fixture.recoveryFinalizeCount, 0);

      fixture.dispose();
    },
  );
}

class _EntryAccountingFixture {
  _EntryAccountingFixture({required double balance, required PoolState pool})
    : balance = BalanceController()..hydrate({'userBalance': balance}),
      pool = SlotPoolController()..hydrate(pool),
      history = GameHistoryController(_MemoryHistoryRepository()),
      grid = GridController(_emptyGrid());

  final BalanceController balance;
  final SlotPoolController pool;
  final GameHistoryController history;
  final GridController grid;
  final FreeSpinsController freeSpins = FreeSpinsController();
  final AnteController ante = AnteController();
  final AutoSpinController autoSpin = AutoSpinController();
  final SpinRoundController round = SpinRoundController();
  final TumbleSequenceController tumble = TumbleSequenceController();
  final SpinLifecycleController lifecycle = SpinLifecycleController();
  final SpinResultSettlementController settlement =
      SpinResultSettlementController();

  int playerStateSaveCount = 0;
  int poolSaveCount = 0;
  int recoveryFinalizeCount = 0;

  void beginNaturalEntry({required double bet}) {
    round.beginNormalSpin(bet);
    balance.charge(bet);
    pool.recordBet(bet);
  }

  void beginBoughtEntry({required double price}) {
    round.beginBoughtFreeSpinTrigger();
    balance.charge(price);
    pool.recordBet(price);
  }

  Future<void> complete(SpinResult result) {
    round.applyPendingResult(result);
    round.markSpinResultReady();
    return SlotSpinCompletionController().complete(
      lifecycleController: lifecycle,
      roundController: round,
      tumbleController: tumble,
      settlementController: settlement,
      balanceController: balance,
      historyController: history,
      gridController: grid,
      freeSpinsController: freeSpins,
      anteController: ante,
      poolController: pool,
      autoSpinController: autoSpin,
      userId: null,
      vibrationEnabled: false,
      isInFreeSpins: () => freeSpins.isInRound,
      savePlayerState: () => playerStateSaveCount++,
      savePoolIfNeeded: () => poolSaveCount++,
      finalizeRecovery: (_) => recoveryFinalizeCount++,
      notifyListeners: () {},
    );
  }

  void dispose() {
    balance.dispose();
    freeSpins.dispose();
    grid.dispose();
    ante.dispose();
  }
}

class _MemoryHistoryRepository implements GameHistoryRepository {
  List<GameHistoryEntry> entries = const [];

  @override
  Future<List<GameHistoryEntry>> load(String userId) async => entries;

  @override
  Future<void> save(String userId, List<GameHistoryEntry> entries) async {
    this.entries = List.of(entries);
  }
}

SpinResult _entryResult({required double totalWin, required int scatterCount}) {
  return SpinResult(
    initialGrid: _emptyGrid(),
    tumbles: const [],
    totalWin: totalWin,
    tumbleCount: 0,
    freeSpinsTriggered: true,
    scatterCount: scatterCount,
    scatterPayout: totalWin,
  );
}

List<List<String>> _emptyGrid() {
  return List.generate(
    SlotEngine.columns,
    (_) => List.filled(SlotEngine.rows, ''),
  );
}
