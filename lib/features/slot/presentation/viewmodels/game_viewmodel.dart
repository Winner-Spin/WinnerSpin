import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/local_game_history_repository.dart';
import '../../domain/models/pending_spin_recovery.dart';
import '../../domain/repositories/spin_recovery_repository.dart';
import '../../domain/models/game_history_entry.dart';
import '../../domain/models/spin_result.dart';
import '../../domain/models/symbol_registry.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../audio/game_music_service.dart';
import '../../domain/repositories/game_history_repository.dart';
import '../../domain/repositories/pool_repository.dart';
import '../../domain/engine/slot_engine.dart';
import '../../domain/models/cluster_win.dart';
import '../models/pending_free_spin_award.dart';
import 'controllers/ante_controller.dart';
import 'controllers/auto_spin_controller.dart';
import 'controllers/balance_controller.dart';
import 'controllers/free_spins_controller.dart';
import 'controllers/game_feedback_controller.dart';
import 'controllers/game_history_controller.dart';
import 'controllers/grid_controller.dart';
import 'controllers/insufficient_funds_hint_controller.dart';
import 'controllers/player_session_controller.dart';
import 'controllers/slot_auto_spin_flow_controller.dart';
import 'controllers/slot_player_controls_controller.dart';
import 'controllers/slot_persistence_controller.dart';
import 'controllers/slot_pool_controller.dart';
import 'controllers/slot_session_hydration_controller.dart';
import 'controllers/slot_session_lifecycle_controller.dart';
import 'controllers/slot_spin_completion_controller.dart';
import 'controllers/slot_spin_flow_controller.dart';
import 'controllers/slot_spin_start_controller.dart';
import 'controllers/spin_availability_controller.dart';
import 'controllers/spin_execution_controller.dart';
import 'controllers/spin_lifecycle_controller.dart';
import 'controllers/spin_result_settlement_controller.dart';
import 'controllers/spin_round_controller.dart';
import 'controllers/tumble_sequence_controller.dart';

class GameViewModel extends ChangeNotifier {
  GameViewModel({
    AuthRepository? authRepository,
    PoolRepository? poolRepository,
    GameHistoryRepository? gameHistoryRepository,
    SpinRecoveryRepository? spinRecoveryRepository,
    GameMusicService? musicService,
    SpinExecutionController? spinExecutionController,
  }) : _historyCtrl = GameHistoryController(
         gameHistoryRepository ?? LocalGameHistoryRepository(),
       ),
       _feedbackCtrl = GameFeedbackController(musicService: musicService),
       _spinExecutionCtrl =
           spinExecutionController ?? SpinExecutionController() {
    _persistenceCtrl = SlotPersistenceController.withDefaults(
      authRepository: authRepository,
      poolRepository: poolRepository,
      spinRecoveryRepository: spinRecoveryRepository,
    );
    final result = SlotEngine.spin(_poolCtrl.pool, 0);
    _gridCtrl = GridController(result.initialGrid);
    unawaited(_feedbackCtrl.initializeMusic());
  }

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
  final SpinRoundController _roundCtrl = SpinRoundController();
  final SlotPoolController _poolCtrl = SlotPoolController();
  final SlotSessionHydrationController _hydrationCtrl =
      SlotSessionHydrationController();
  final SlotPlayerControlsController _playerControlsCtrl =
      SlotPlayerControlsController();
  final SlotAutoSpinFlowController _autoSpinFlowCtrl =
      SlotAutoSpinFlowController();
  final SlotSessionLifecycleController _sessionLifecycleCtrl =
      SlotSessionLifecycleController();
  final SlotSpinFlowController _spinFlowCtrl = SlotSpinFlowController();
  final SpinLifecycleController _spinLifecycleCtrl = SpinLifecycleController();
  final SlotSpinStartController _spinStartCtrl = SlotSpinStartController();
  final SlotSpinCompletionController _spinCompletionCtrl =
      SlotSpinCompletionController();
  late final GridController _gridCtrl;
  final Map<String, ({String userId, PendingSpinRecovery recovery})>
  _preparedSpinRecoveries = {};
  Future<void> _recoveryPersistenceTail = Future<void>.value();
  final Set<String> _acknowledgedRecoveryAwards = {};
  final Set<String> _failedRecoveryFinalizations = {};
  ({String userId, String spinId})? _pendingAwardRecovery;
  PendingFreeSpinAward? _recoveredPendingFreeSpinAward;
  double? _expectedRemoteUserBalance;
  bool _balanceSyncLocked = false;

  BalanceController get balanceCtrl => _balanceCtrl;
  AnteController get anteCtrl => _anteCtrl;
  FreeSpinsController get fsCtrl => _fsCtrl;
  GridController get gridCtrl => _gridCtrl;

  String get username => _sessionCtrl.username;

  String get email => _sessionCtrl.email;

  String get profileAvatarId => _sessionCtrl.profileAvatarId;

  bool get isLoading => _sessionCtrl.isLoading;

  bool get loggedOut => _sessionCtrl.loggedOut;

  PendingFreeSpinAward? takeRecoveredFreeSpinAward() {
    final pending = _recoveredPendingFreeSpinAward;
    _recoveredPendingFreeSpinAward = null;
    return pending;
  }

  static const int columns = SlotEngine.columns;
  static const int rows = SlotEngine.rows;

  List<List<String>> get grid => _gridCtrl.grid;
  List<List<String>> get previousGrid => _gridCtrl.previousGrid;
  Set<String> get fadingPaths => _gridCtrl.fadingPaths;
  List<ClusterWin> get activeExplosions => _gridCtrl.activeExplosions;
  Set<int> get winningPositions => _gridCtrl.winningPositions;
  Set<int> get clearedPositions => _gridCtrl.clearedPositions;

  bool get isTumbling => _tumbleCtrl.isTumbling;

  bool get isSpinning => _roundCtrl.isSpinning;

  bool get isAutoSpinning => _autoSpinCtrl.active;

  bool get lastSpinWasFreeSpin => _roundCtrl.lastSpinWasFreeSpin;

  int get autoSpinsRemaining => _autoSpinCtrl.remaining;

  bool get isBusy => _roundCtrl.isSpinning || _tumbleCtrl.isTumbling;

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

  double get freeSpinAccumulatedWin => _fsCtrl.accumulatedWin;

  int get freeSpinsAwardedThisRound => _fsCtrl.awardedThisRound;

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

  bool get isCurrentSpinFromBuy => _roundCtrl.currentSpinFromBuy;
  List<GameHistoryEntry> get gameHistory => _historyCtrl.entries;

  SpinResult? get lastSpinResult => _roundCtrl.lastSpinResult;
  bool get shouldPulseLandingScatters =>
      _availabilityCtrl.shouldPulseLandingScatters(
        isInFreeSpins: isInFreeSpins,
        pendingResult: _roundCtrl.pendingResult,
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

  void startAutoSpin(int spinCount, {int speedMultiplier = 1}) {
    _autoSpinFlowCtrl.start(
      autoSpinController: _autoSpinCtrl,
      balanceController: _balanceCtrl,
      insufficientHintController: _insufficientHintCtrl,
      isBusy: isBusy,
      isInFreeSpins: isInFreeSpins,
      effectiveBetCost: effectiveBetCost,
      spinCount: spinCount,
      speedMultiplier: speedMultiplier,
      spin: spin,
      notifyListeners: notifyListeners,
    );
  }

  void stopAutoSpin() {
    if (!_autoSpinFlowCtrl.stop(autoSpinController: _autoSpinCtrl)) return;
    notifyListeners();
  }

  void toggleAutoSpin() {
    _autoSpinFlowCtrl.toggle(
      autoSpinController: _autoSpinCtrl,
      start: startAutoSpin,
      stop: stopAutoSpin,
    );
  }

  void continueAutoSpinIfReady({
    Duration delay = const Duration(milliseconds: 600),
  }) {
    _autoSpinFlowCtrl.continueIfReady(
      autoSpinController: _autoSpinCtrl,
      isBusy: () => isBusy,
      spin: spin,
      delay: delay,
    );
  }

  void toggleSpeed() {
    if (!_playerControlsCtrl.toggleSpeed(
      availabilityController: _availabilityCtrl,
      autoSpinController: _autoSpinCtrl,
      isBusy: isBusy,
    )) {
      return;
    }
    notifyListeners();
  }

  void toggleAnteBet() {
    if (!_playerControlsCtrl.toggleAnte(
      availabilityController: _availabilityCtrl,
      anteController: _anteCtrl,
      autoSpinController: _autoSpinCtrl,
      balanceController: _balanceCtrl,
      isBusy: isBusy,
      isInFreeSpins: isInFreeSpins,
    )) {
      return;
    }
  }

  void increaseBet() {
    _playerControlsCtrl.increaseBet(
      availabilityController: _availabilityCtrl,
      autoSpinController: _autoSpinCtrl,
      balanceController: _balanceCtrl,
      isInFreeSpins: isInFreeSpins,
    );
  }

  void decreaseBet() {
    _playerControlsCtrl.decreaseBet(
      availabilityController: _availabilityCtrl,
      autoSpinController: _autoSpinCtrl,
      balanceController: _balanceCtrl,
      isInFreeSpins: isInFreeSpins,
    );
  }

  Future<void> purchaseGameMoney(double amount) async {
    if (!_playerControlsCtrl.depositGameMoney(
      amount: amount,
      balanceController: _balanceCtrl,
      insufficientHintController: _insufficientHintCtrl,
    )) {
      return;
    }
    notifyListeners();

    await _sessionLifecycleCtrl.savePlayerState(
      persistenceController: _persistenceCtrl,
      balanceController: _balanceCtrl,
      freeSpinsController: _fsCtrl,
      debugLabel: 'Deposit money save',
    );
  }

  Future<void> fetchUserData() async {
    await _hydrationCtrl.hydrate(
      persistenceController: _persistenceCtrl,
      historyController: _historyCtrl,
      poolController: _poolCtrl,
      sessionController: _sessionCtrl,
      balanceController: _balanceCtrl,
      freeSpinsController: _fsCtrl,
      recoverPendingSpin: _recoverPendingSpin,
      applyRemoteUserBalance: _applyRemoteUserBalance,
      savePlayerState: () => _sessionLifecycleCtrl.savePlayerStateSilently(
        persistenceController: _persistenceCtrl,
        balanceController: _balanceCtrl,
        freeSpinsController: _fsCtrl,
      ),
    );
    notifyListeners();
  }

  Future<void> spin() async {
    if (isLoading) return;
    _balanceSyncLocked = true;
    try {
      await _spinFlowCtrl.spin(
        startController: _spinStartCtrl,
        lifecycleController: _spinLifecycleCtrl,
        executionController: _spinExecutionCtrl,
        balanceController: _balanceCtrl,
        freeSpinsController: _fsCtrl,
        autoSpinController: _autoSpinCtrl,
        insufficientHintController: _insufficientHintCtrl,
        poolController: _poolCtrl,
        roundController: _roundCtrl,
        anteController: _anteCtrl,
        tumbleController: _tumbleCtrl,
        gridController: _gridCtrl,
        isBusy: isBusy,
        isInFreeSpins: isInFreeSpins,
        betAmount: betAmount,
        vibrationEnabled: vibration,
        prepareRecovery: _prepareSpinRecovery,
        commitPendingFreeSpinConsume: commitPendingFsConsume,
        notifyListeners: notifyListeners,
      );
    } finally {
      if (!_roundCtrl.isSpinning) _balanceSyncLocked = false;
    }
  }

  Future<void> buyFreeSpins() async {
    if (isLoading) return;
    _balanceSyncLocked = true;
    try {
      await _spinFlowCtrl.buyFreeSpins(
        startController: _spinStartCtrl,
        lifecycleController: _spinLifecycleCtrl,
        executionController: _spinExecutionCtrl,
        balanceController: _balanceCtrl,
        autoSpinController: _autoSpinCtrl,
        insufficientHintController: _insufficientHintCtrl,
        poolController: _poolCtrl,
        roundController: _roundCtrl,
        anteController: _anteCtrl,
        tumbleController: _tumbleCtrl,
        gridController: _gridCtrl,
        isBusy: isBusy,
        isInFreeSpins: isInFreeSpins,
        betAmount: betAmount,
        buyFeaturePrice: buyFeaturePrice,
        vibrationEnabled: vibration,
        notifyListeners: notifyListeners,
      );
    } finally {
      if (!_roundCtrl.isSpinning) _balanceSyncLocked = false;
    }
  }

  Future<void> _prepareSpinRecovery(SpinResult result) async {
    final userId = _persistenceCtrl.currentUserId;
    if (userId == null) return;

    final playedAt = DateTime.now().toUtc();
    final recovery = _settlementCtrl.createRecovery(
      spinId: '$userId-${playedAt.microsecondsSinceEpoch}',
      playedAt: playedAt,
      result: result,
      roundController: _roundCtrl,
      balanceController: _balanceCtrl,
      freeSpinsController: _fsCtrl,
      anteController: _anteCtrl,
      poolController: _poolCtrl,
    );
    try {
      await _persistenceCtrl.saveSpinRecovery(recovery);
      _preparedSpinRecoveries[recovery.spinId] = (
        userId: userId,
        recovery: recovery,
      );
      _expectedRemoteUserBalance = recovery.userBalance;
      if (recovery.pendingFreeSpinAward > 0) {
        _pendingAwardRecovery = (userId: userId, spinId: recovery.spinId);
      }
      _roundCtrl.attachRecovery(recovery.spinId);
    } catch (error) {
      debugPrint('Spin recovery preparation error: $error');
    }
  }

  void _finalizeSpinRecovery(String spinId) {
    final prepared = _preparedSpinRecoveries.remove(spinId);
    if (prepared == null) return;

    _recoveryPersistenceTail = _recoveryPersistenceTail.then((_) async {
      try {
        await Future.wait([
          _persistenceCtrl.persistSpinRecoveryPlayer(
            userId: prepared.userId,
            recovery: prepared.recovery,
          ),
          _historyCtrl.recordOnce(
            userId: prepared.userId,
            id: prepared.recovery.spinId,
            playedAt: prepared.recovery.playedAt,
            newBalance: prepared.recovery.userBalance,
            bet: prepared.recovery.historyBet,
            winAmount: prepared.recovery.winAmount,
          ),
        ]);
        _failedRecoveryFinalizations.remove(spinId);
        final awardAcknowledged = _acknowledgedRecoveryAwards.remove(spinId);
        if (prepared.recovery.pendingFreeSpinAward == 0 || awardAcknowledged) {
          await _persistenceCtrl.clearSpinRecovery(
            spinId,
            userId: prepared.userId,
          );
        }
      } catch (error) {
        _failedRecoveryFinalizations.add(spinId);
        debugPrint('Spin recovery finalization error: $error');
      }
    });
  }

  void acknowledgePendingFreeSpinAward() {
    final pending = _pendingAwardRecovery;
    if (pending == null) return;
    _pendingAwardRecovery = null;

    if (_preparedSpinRecoveries.containsKey(pending.spinId)) {
      _acknowledgedRecoveryAwards.add(pending.spinId);
      return;
    }
    _enqueueRecoveryClear(pending);
  }

  void _enqueueRecoveryClear(({String userId, String spinId}) pending) {
    _recoveryPersistenceTail = _recoveryPersistenceTail.then((_) async {
      if (_failedRecoveryFinalizations.contains(pending.spinId)) return;
      try {
        await _persistenceCtrl.clearSpinRecovery(
          pending.spinId,
          userId: pending.userId,
        );
      } catch (error) {
        debugPrint('Spin recovery acknowledgement error: $error');
      }
    });
  }

  Future<bool> _recoverPendingSpin() async {
    final recovery = await _persistenceCtrl.loadSpinRecovery();
    if (recovery == null) return false;
    final userId = _persistenceCtrl.currentUserId;
    if (userId == null) {
      throw StateError('A signed-in player is required for spin recovery.');
    }

    _expectedRemoteUserBalance = recovery.userBalance;
    await _persistRecoveredSpin(userId: userId, recovery: recovery);
    if (recovery.pendingFreeSpinAward > 0) {
      _pendingAwardRecovery = (userId: userId, spinId: recovery.spinId);
      _recoveredPendingFreeSpinAward = PendingFreeSpinAward(
        value: recovery.pendingFreeSpinAward,
        isRetrigger: recovery.pendingFreeSpinAward == 5,
        winAmount: recovery.winAmount,
      );
    } else {
      await _persistenceCtrl.clearSpinRecovery(recovery.spinId, userId: userId);
    }
    _settlementCtrl.restoreRecovery(
      recovery: recovery,
      balanceController: _balanceCtrl,
      freeSpinsController: _fsCtrl,
      anteController: _anteCtrl,
      poolController: _poolCtrl,
    );
    return true;
  }

  Future<void> _persistRecoveredSpin({
    required String userId,
    required PendingSpinRecovery recovery,
  }) async {
    await Future.wait([
      _persistenceCtrl.persistRecoveredSpin(userId: userId, recovery: recovery),
      _historyCtrl.recordOnce(
        userId: userId,
        id: recovery.spinId,
        playedAt: recovery.playedAt,
        newBalance: recovery.userBalance,
        bet: recovery.historyBet,
        winAmount: recovery.winAmount,
      ),
    ]);
  }

  void clearMultiplierResidues() {
    _spinLifecycleCtrl.clearMultiplierResidues(gridController: _gridCtrl);
  }

  Future<void> onSpinComplete() async {
    try {
      await _spinCompletionCtrl.complete(
        lifecycleController: _spinLifecycleCtrl,
        roundController: _roundCtrl,
        tumbleController: _tumbleCtrl,
        settlementController: _settlementCtrl,
        balanceController: _balanceCtrl,
        historyController: _historyCtrl,
        gridController: _gridCtrl,
        freeSpinsController: _fsCtrl,
        anteController: _anteCtrl,
        poolController: _poolCtrl,
        autoSpinController: _autoSpinCtrl,
        userId: _persistenceCtrl.currentUserId,
        vibrationEnabled: vibration,
        isInFreeSpins: () => isInFreeSpins,
        savePlayerState: () => _sessionLifecycleCtrl.savePlayerStateSilently(
          persistenceController: _persistenceCtrl,
          balanceController: _balanceCtrl,
          freeSpinsController: _fsCtrl,
        ),
        savePoolIfNeeded: () => _sessionLifecycleCtrl.savePoolIfNeeded(
          poolController: _poolCtrl,
          persistenceController: _persistenceCtrl,
          balanceController: _balanceCtrl,
          freeSpinsController: _fsCtrl,
        ),
        finalizeRecovery: _finalizeSpinRecovery,
        notifyListeners: notifyListeners,
      );
    } finally {
      _balanceSyncLocked = false;
    }
  }

  void _applyRemoteUserBalance(double remoteValue) {
    final expectedValue = _expectedRemoteUserBalance;
    if (expectedValue != null) {
      if ((expectedValue * 100).round() == (remoteValue * 100).round()) {
        _expectedRemoteUserBalance = null;
      }
      return;
    }
    if (_balanceSyncLocked) return;
    _balanceCtrl.applyRemoteUserBalance(remoteValue);
  }

  void commitPendingFsConsume() {
    if (!_fsCtrl.commitPendingConsume()) return;
    if (_roundCtrl.pendingRecoveryId != null) return;
    _sessionLifecycleCtrl.savePlayerStateSilently(
      persistenceController: _persistenceCtrl,
      balanceController: _balanceCtrl,
      freeSpinsController: _fsCtrl,
    );
  }

  void releaseFsRoundHold() {
    if (!_fsCtrl.releaseRoundHold()) return;
    if (!_fsCtrl.isActive) {
      _fsCtrl.finishRound();
      _sessionLifecycleCtrl.savePlayerStateSilently(
        persistenceController: _persistenceCtrl,
        balanceController: _balanceCtrl,
        freeSpinsController: _fsCtrl,
      );
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await _sessionLifecycleCtrl.signOut(
      sessionController: _sessionCtrl,
      poolController: _poolCtrl,
      persistenceController: _persistenceCtrl,
      balanceController: _balanceCtrl,
      freeSpinsController: _fsCtrl,
    );
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await _sessionLifecycleCtrl.deleteAccount(
      sessionController: _sessionCtrl,
      persistenceController: _persistenceCtrl,
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

  Future<bool> selectProfileAvatar(String avatarId) async {
    if (!SymbolRegistry.isProfileAvatar(avatarId)) return false;
    final previousAvatarId = _sessionCtrl.profileAvatarId;
    if (previousAvatarId == avatarId) return true;

    _sessionCtrl.setProfileAvatarId(avatarId);
    notifyListeners();
    try {
      await _persistenceCtrl.updateProfileAvatar(avatarId);
      return true;
    } catch (error) {
      debugPrint('Profile avatar save error: $error');
      _sessionCtrl.setProfileAvatarId(previousAvatarId);
      notifyListeners();
      return false;
    }
  }

  Future<void> sendPasswordResetEmail() {
    return _persistenceCtrl.sendPasswordResetEmail(email);
  }

  Future<void> onAppLifecycleEvent() async {
    await _sessionLifecycleCtrl.onAppLifecycleEvent(
      poolController: _poolCtrl,
      persistenceController: _persistenceCtrl,
      balanceController: _balanceCtrl,
      freeSpinsController: _fsCtrl,
    );
  }

  Future<bool> validateSessionOnResume() async {
    final isSessionActive = await _sessionLifecycleCtrl.validateSessionOnResume(
      sessionController: _sessionCtrl,
      persistenceController: _persistenceCtrl,
    );
    if (!isSessionActive) notifyListeners();
    return isSessionActive;
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
