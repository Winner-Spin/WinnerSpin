import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/repositories/local_game_history_repository.dart';
import '../../domain/models/game_history_entry.dart';
import '../../domain/models/pool_state.dart';
import '../../domain/models/spin_result.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/data/repositories/firebase_auth_repository.dart';
import '../audio/game_music_service.dart';
import '../../data/repositories/firestore_pool_repository.dart';
import '../../domain/repositories/game_history_repository.dart';
import '../../domain/repositories/pool_repository.dart';
import '../../domain/engine/slot_engine.dart';
import '../../domain/engine/spin_task.dart';
import '../../domain/models/cluster_win.dart';
import 'controllers/ante_controller.dart';
import 'controllers/auto_spin_controller.dart';
import 'controllers/balance_controller.dart';
import 'controllers/free_spins_controller.dart';
import 'controllers/game_feedback_controller.dart';
import 'controllers/game_history_controller.dart';
import 'controllers/grid_controller.dart';
import 'controllers/insufficient_funds_hint_controller.dart';
import 'controllers/player_session_controller.dart';
import 'controllers/slot_persistence_controller.dart';
import 'controllers/spin_availability_controller.dart';
import 'controllers/spin_execution_controller.dart';
import 'controllers/spin_result_settlement_controller.dart';
import 'controllers/tumble_sequence_controller.dart';

class GameViewModel extends ChangeNotifier {
  GameViewModel({
    AuthRepository? authRepository,
    PoolRepository? poolRepository,
    GameHistoryRepository? gameHistoryRepository,
    GameMusicService? musicService,
    SpinExecutionController? spinExecutionController,
  }) : _authRepository = authRepository ?? FirebaseAuthRepository(),
       _poolRepository = poolRepository ?? FirestorePoolRepository(),
       _historyCtrl = GameHistoryController(
         gameHistoryRepository ?? LocalGameHistoryRepository(),
       ),
       _feedbackCtrl = GameFeedbackController(musicService: musicService),
       _spinExecutionCtrl =
           spinExecutionController ?? SpinExecutionController() {
    _persistenceCtrl = SlotPersistenceController(
      authRepository: _authRepository,
      poolRepository: _poolRepository,
    );
    final result = SlotEngine.spin(_pool, 0);
    _gridCtrl = GridController(result.initialGrid);
    unawaited(_feedbackCtrl.initializeMusic());
  }

  final AuthRepository _authRepository;
  final PoolRepository _poolRepository;
  final GameFeedbackController _feedbackCtrl;
  final GameHistoryController _historyCtrl;
  final SpinExecutionController _spinExecutionCtrl;
  late final SlotPersistenceController _persistenceCtrl;

  final BalanceController _balanceCtrl = BalanceController();
  final AnteController _anteCtrl = AnteController();
  final FreeSpinsController _fsCtrl = FreeSpinsController();
  final AutoSpinController _autoSpinCtrl = AutoSpinController();
  final PlayerSessionController _sessionCtrl = PlayerSessionController();
  final TumbleSequenceController _tumbleCtrl = TumbleSequenceController();
  final SpinResultSettlementController _settlementCtrl =
      SpinResultSettlementController();
  final SpinAvailabilityController _availabilityCtrl =
      SpinAvailabilityController();
  late final GridController _gridCtrl;

  BalanceController get balanceCtrl => _balanceCtrl;
  AnteController get anteCtrl => _anteCtrl;
  FreeSpinsController get fsCtrl => _fsCtrl;
  GridController get gridCtrl => _gridCtrl;

  String get username => _sessionCtrl.username;

  String get email => _sessionCtrl.email;

  bool get isLoading => _sessionCtrl.isLoading;

  bool get loggedOut => _sessionCtrl.loggedOut;

  static const int columns = SlotEngine.columns;
  static const int rows = SlotEngine.rows;

  List<List<String>> get grid => _gridCtrl.grid;
  List<List<String>> get previousGrid => _gridCtrl.previousGrid;
  Set<String> get fadingPaths => _gridCtrl.fadingPaths;
  List<ClusterWin> get activeExplosions => _gridCtrl.activeExplosions;
  Set<int> get winningPositions => _gridCtrl.winningPositions;
  Set<int> get clearedPositions => _gridCtrl.clearedPositions;

  bool get isTumbling => _tumbleCtrl.isTumbling;

  bool _isSpinning = false;
  bool get isSpinning => _isSpinning;

  bool get isAutoSpinning => _autoSpinCtrl.active;

  bool _lastSpinWasFreeSpin = false;
  bool get lastSpinWasFreeSpin => _lastSpinWasFreeSpin;

  int get autoSpinsRemaining => _autoSpinCtrl.remaining;

  bool get isBusy => _isSpinning || _tumbleCtrl.isTumbling;

  int get speedMultiplier => _autoSpinCtrl.speedMultiplier;

  final InsufficientFundsHintController _insufficientHintCtrl =
      InsufficientFundsHintController();
  bool get showInsufficientFundsHint => _insufficientHintCtrl.visible;

  double get liveTumbleWin => _tumbleCtrl.liveWin;

  double get balance => _balanceCtrl.balance;
  double get userBalance => _balanceCtrl.userBalance;
  double get betAmount => _balanceCtrl.betAmount;
  double get lastWin => _balanceCtrl.lastWin;
  double get effectiveBetCost => _balanceCtrl.effectiveBetCost;
  double get anteCost => _balanceCtrl.anteCost;
  double get buyFeaturePrice => _balanceCtrl.buyFeaturePrice;
  bool get canDecreaseBet => _balanceCtrl.canDecreaseBet;
  bool get canIncreaseBet => _balanceCtrl.canIncreaseBet;

  bool get anteBetActive => _anteCtrl.active;

  int get freeSpinsRemaining => _fsCtrl.remaining;

  bool get isInFreeSpins => _fsCtrl.isInRound;

  bool get canBuyFreeSpins => _availabilityCtrl.canBuyFreeSpins(
    isBusy: isBusy,
    isAutoSpinning: _autoSpinCtrl.active,
    isInFreeSpins: isInFreeSpins,
    canAffordBuyFeature: _balanceCtrl.canAffordDisplayed(buyFeaturePrice),
  );

  bool get canBuyFreeSpinsForUi => _availabilityCtrl.canBuyFreeSpins(
    isBusy: isBusy,
    isAutoSpinning: _autoSpinCtrl.active,
    isInFreeSpins: isInFreeSpins,
    canAffordBuyFeature: _balanceCtrl.canAffordDisplayed(buyFeaturePrice),
  );

  bool get canSpinForUi => _availabilityCtrl.canSpinForUi(
    isInFreeSpins: isInFreeSpins,
    canAffordDisplayedBet: _balanceCtrl.canAffordDisplayed(effectiveBetCost),
  );

  bool get canSpin => _availabilityCtrl.canSpin(
    isInFreeSpins: isInFreeSpins,
    canAffordBet: _balanceCtrl.canAfford(effectiveBetCost),
  );

  PoolState _pool = PoolState();
  SpinResult? _pendingResult;
  double _pendingHistoryBet = 0;

  bool _currentSpinFromBuy = false;
  bool get isCurrentSpinFromBuy => _currentSpinFromBuy;
  List<GameHistoryEntry> get gameHistory => _historyCtrl.entries;

  SpinResult? _lastSpinResult;
  SpinResult? get lastSpinResult => _lastSpinResult;
  bool get shouldPulseLandingScatters =>
      _availabilityCtrl.shouldPulseLandingScatters(
        isInFreeSpins: isInFreeSpins,
        pendingResult: _pendingResult,
      );

  bool get vibration => _feedbackCtrl.vibration;
  void setVibration(bool value) {
    if (!_feedbackCtrl.setVibration(value)) return;
    notifyListeners();
  }

  bool get ambientMusic => _feedbackCtrl.ambientMusic;
  void setAmbientMusic(bool value) {
    if (!_feedbackCtrl.setAmbientMusic(value)) return;
    notifyListeners();
  }

  bool get soundEffects => _feedbackCtrl.soundEffects;
  void setSoundEffects(bool value) {
    _feedbackCtrl.setSoundEffects(value);
    notifyListeners();
  }

  void _flashInsufficientFundsHint() {
    _insufficientHintCtrl.flash(notifyListeners);
  }

  void startAutoSpin(int spinCount, {int speedMultiplier = 1}) {
    if (isBusy || spinCount <= 0) return;
    if (!isInFreeSpins && !_balanceCtrl.canAfford(effectiveBetCost)) {
      _flashInsufficientFundsHint();
      return;
    }

    if (!_autoSpinCtrl.start(spinCount, speedMultiplier: speedMultiplier)) {
      return;
    }
    spin();
  }

  void stopAutoSpin() {
    if (!_autoSpinCtrl.stop()) return;
    notifyListeners();
  }

  void toggleAutoSpin() {
    if (_autoSpinCtrl.active) {
      stopAutoSpin();
    } else {
      startAutoSpin(100, speedMultiplier: _autoSpinCtrl.speedMultiplier);
    }
  }

  void continueAutoSpinIfReady({
    Duration delay = const Duration(milliseconds: 600),
  }) {
    if (!_autoSpinCtrl.canContinue(isBusy: isBusy)) return;
    Future.delayed(delay, () {
      if (_autoSpinCtrl.canContinue(isBusy: isBusy)) {
        spin();
      }
    });
  }

  void _consumeAutoSpinAtStart() {
    _autoSpinCtrl.consumeAtSpinStart();
  }

  void _stopAutoSpinSilently() {
    _autoSpinCtrl.stopSilently();
  }

  void toggleSpeed() {
    if (isBusy && !_autoSpinCtrl.active) return;
    _autoSpinCtrl.nextSpeed();
    notifyListeners();
  }

  void toggleAnteBet() {
    if (isBusy || isInFreeSpins || _autoSpinCtrl.active) return;
    _anteCtrl.toggle();
    _balanceCtrl.anteActiveShadow = _anteCtrl.active;
  }

  void increaseBet() {
    if (_autoSpinCtrl.active || isInFreeSpins) return;
    _balanceCtrl.increaseBet();
  }

  void decreaseBet() {
    if (_autoSpinCtrl.active || isInFreeSpins) return;
    _balanceCtrl.decreaseBet();
  }

  Future<void> purchaseGameMoney(double amount) async {
    if (amount <= 0) return;
    _balanceCtrl.depositGameMoney(amount);
    _insufficientHintCtrl.clear();
    notifyListeners();

    await _persistenceCtrl.savePlayerState(
      userId: _persistenceCtrl.currentUserId,
      userBalance: userBalance,
      freeSpinsRemaining: freeSpinsRemaining,
      debugLabel: 'Deposit money save',
    );
  }

  Future<void> fetchUserData() async {
    try {
      final uid = _persistenceCtrl.currentUserId;
      if (uid != null) {
        await _historyCtrl.load(uid);

        final results = await Future.wait([
          _persistenceCtrl.getUserData(uid),
          _persistenceCtrl.loadPool(uid),
        ]);

        final userData = results[0] as Map<String, dynamic>?;
        _pool = results[1] as PoolState;
        _sessionCtrl.listenToUserBalance(
          stream: _persistenceCtrl.watchUserData(uid),
          onBalanceChanged: _balanceCtrl.applyRemoteUserBalance,
        );

        if (userData != null) {
          _sessionCtrl.applyUserData(userData);
          _balanceCtrl.hydrate(userData);
          _fsCtrl.hydrate(userData);

          if (!userData.containsKey('userBalance')) {
            _savePlayerState();
          }
        } else {
          _sessionCtrl.applyUserData(null);
        }
      }
    } catch (e) {
      debugPrint('Data fetch error: $e');
      _sessionCtrl.markError();
    } finally {
      _sessionCtrl.finishLoading();
      notifyListeners();
    }
  }

  Future<void> spin() async {
    if (isBusy) return;

    _currentSpinFromBuy = false;

    final bool isFreeSpin = isInFreeSpins;
    _lastSpinWasFreeSpin = isFreeSpin;

    if (!isFreeSpin) {
      final cost = _balanceCtrl.effectiveBetCost;
      if (!_balanceCtrl.canAfford(cost)) {
        if (_autoSpinCtrl.active) {
          _stopAutoSpinSilently();
        }
        _flashInsufficientFundsHint();
        return;
      }
      _pendingHistoryBet = cost;
      _balanceCtrl.charge(cost);
      _pool.recordBet(cost);
    } else {
      _pendingHistoryBet = 0;
      _fsCtrl.beginSpinRound();
    }

    _consumeAutoSpinAtStart();
    _prepareSpinStart();

    final bool anteFlag = isFreeSpin
        ? _anteCtrl.currentRoundFromAnte
        : _anteCtrl.active;
    final bool buyFlag = isFreeSpin && _fsCtrl.currentRoundFromBuy;

    final taskOutput = await _spinExecutionCtrl.run(
      pool: _pool,
      betAmount: betAmount,
      isFreeSpins: isFreeSpin,
      anteBet: anteFlag,
      buyFs: buyFlag,
    );

    _applySpinTaskOutput(taskOutput);

    if (isFreeSpin) {
      commitPendingFsConsume();
    }
    _gridCtrl.setGrid(_pendingResult!.initialGrid);
  }

  Future<void> buyFreeSpins() async {
    if (_autoSpinCtrl.active) {
      _stopAutoSpinSilently();
    }
    if (_anteCtrl.active) return;
    if (isBusy || isInFreeSpins) return;
    if (!_balanceCtrl.canAffordDisplayed(buyFeaturePrice)) {
      _flashInsufficientFundsHint();
      return;
    }

    _lastSpinWasFreeSpin = false;
    final price = buyFeaturePrice;
    _balanceCtrl.charge(price);
    _pool.recordBet(price);
    _currentSpinFromBuy = true;
    _pendingHistoryBet = 0;

    _prepareSpinStart();

    final taskOutput = await _spinExecutionCtrl.run(
      pool: _pool,
      betAmount: betAmount,
      isFreeSpins: false,
      anteBet: false,
      buyFs: false,
      forceFsTrigger: true,
    );

    _applySpinTaskOutput(taskOutput);
    _gridCtrl.setGrid(_pendingResult!.initialGrid);
  }

  void _prepareSpinStart() {
    _isSpinning = true;
    _balanceCtrl.resetLastWin();
    _tumbleCtrl.resetForNewSpin();
    _gridCtrl.capturePreviousGrid();
    _gridCtrl.resetForNewSpin();
    if (vibration) HapticFeedback.lightImpact();
    notifyListeners();
  }

  void _applySpinTaskOutput(SpinTaskOutput taskOutput) {
    _pool = taskOutput.pool;
    _pendingResult = taskOutput.result;
  }

  void clearMultiplierResidues() {
    _gridCtrl.clearMultiplierResidues();
  }

  Future<void> onSpinComplete() async {
    final result = _pendingResult;
    _gridCtrl.clearMultiplierResidues();
    if (result == null) {
      _isSpinning = false;
      notifyListeners();
      return;
    }

    _isSpinning = false;

    await _tumbleCtrl.play(
      result: result,
      gridController: _gridCtrl,
      vibrationEnabled: vibration,
      notifyListeners: notifyListeners,
    );

    _settlementCtrl.awardWinAndRecordHistory(
      result: result,
      balanceController: _balanceCtrl,
      historyController: _historyCtrl,
      userId: _persistenceCtrl.currentUserId,
      pendingHistoryBet: _pendingHistoryBet,
      vibrationEnabled: vibration,
    );
    _settlementCtrl.showWinningPositions(
      result: result,
      gridController: _gridCtrl,
    );
    _lastSpinResult = result;

    final freeSpinAwarded = _settlementCtrl.applyFreeSpinAward(
      result: result,
      freeSpinsController: _fsCtrl,
      anteController: _anteCtrl,
      currentSpinFromBuy: _currentSpinFromBuy,
    );
    if (freeSpinAwarded) {
      _savePlayerState();
    }

    _settlementCtrl.clearRoundFlagsIfNeeded(
      isInFreeSpins: isInFreeSpins,
      anteController: _anteCtrl,
      freeSpinsController: _fsCtrl,
    );

    _settlementCtrl.recordPayout(pool: _pool, amount: result.totalWin);
    _savePoolIfNeeded();

    _pendingResult = null;
    _pendingHistoryBet = 0;

    if (_autoSpinCtrl.active) {
      _autoSpinCtrl.stopIfCompleted();
      notifyListeners();
    }
  }

  void commitPendingFsConsume() {
    if (!_fsCtrl.commitPendingConsume()) return;
    _savePlayerState();
  }

  void releaseFsRoundHold() {
    if (!_fsCtrl.releaseRoundHold()) return;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _sessionCtrl.signOut(
      forceSave: _forceSavePool,
      signOut: _persistenceCtrl.signOut,
    );
    notifyListeners();
  }

  void resetLoggedOut() {
    _sessionCtrl.resetLoggedOut();
  }

  void deleteGameHistoryEntries(Set<String> ids) {
    if (ids.isEmpty) return;
    _historyCtrl.delete(userId: _persistenceCtrl.currentUserId, ids: ids);
    notifyListeners();
  }

  void _savePlayerState() {
    _persistenceCtrl.savePlayerStateSilently(
      userId: _persistenceCtrl.currentUserId,
      userBalance: userBalance,
      freeSpinsRemaining: freeSpinsRemaining,
    );
  }

  void _savePoolIfNeeded() {
    _persistenceCtrl.savePoolIfNeeded(
      userId: _persistenceCtrl.currentUserId,
      pool: _pool,
      userBalance: userBalance,
      freeSpinsRemaining: freeSpinsRemaining,
    );
  }

  Future<void> _forceSavePool() async {
    await _persistenceCtrl.forceSavePool(
      userId: _persistenceCtrl.currentUserId,
      pool: _pool,
      userBalance: userBalance,
      freeSpinsRemaining: freeSpinsRemaining,
    );
  }

  Future<void> onAppLifecycleEvent() async {
    await _feedbackCtrl.pauseForLifecycle();
    await _forceSavePool();
  }

  void onAppResumed() {
    _feedbackCtrl.resumeAfterLifecycle();
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    _sessionCtrl.dispose();
    _insufficientHintCtrl.dispose();
    _balanceCtrl.dispose();
    _anteCtrl.dispose();
    _fsCtrl.dispose();
    _gridCtrl.dispose();
    super.dispose();
  }
}
