import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/audio/ambient_music_preference.dart';
import '../../data/repositories/local_game_history_repository.dart';
import '../../domain/models/game_history_entry.dart';
import '../../domain/models/pool_state.dart';
import '../../domain/models/spin_result.dart';
import '../../domain/models/symbol_registry.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/data/repositories/firebase_auth_repository.dart';
import '../audio/game_music_service.dart';
import '../audio/ui_click_sound.dart';
import '../../data/repositories/firestore_pool_repository.dart';
import '../../domain/repositories/game_history_repository.dart';
import '../../domain/repositories/pool_repository.dart';
import '../../domain/engine/slot_engine.dart';
import '../../domain/engine/spin_task.dart';
import '../../domain/models/cluster_win.dart';
import 'controllers/ante_controller.dart';
import 'controllers/balance_controller.dart';
import 'controllers/free_spins_controller.dart';
import 'controllers/grid_controller.dart';

class GameViewModel extends ChangeNotifier {
  GameViewModel({
    AuthRepository? authRepository,
    PoolRepository? poolRepository,
    GameHistoryRepository? gameHistoryRepository,
    GameMusicService? musicService,
  }) : _authRepository = authRepository ?? FirebaseAuthRepository(),
       _poolRepository = poolRepository ?? FirestorePoolRepository(),
       _gameHistoryRepository =
           gameHistoryRepository ?? LocalGameHistoryRepository(),
       _musicService = musicService ?? GameMusicService() {
    final result = SlotEngine.spin(_pool, 0);
    _gridCtrl = GridController(result.initialGrid);
    _initMusic();
  }

  final GameMusicService _musicService;

  Future<void> _initMusic() async {
    await _musicService.initialize(playWhenReady: _ambientMusic);
  }

  final AuthRepository _authRepository;
  final PoolRepository _poolRepository;
  final GameHistoryRepository _gameHistoryRepository;
  StreamSubscription<Map<String, dynamic>?>? _userSubscription;

  final BalanceController _balanceCtrl = BalanceController();
  final AnteController _anteCtrl = AnteController();
  final FreeSpinsController _fsCtrl = FreeSpinsController();
  late final GridController _gridCtrl;

  BalanceController get balanceCtrl => _balanceCtrl;
  AnteController get anteCtrl => _anteCtrl;
  FreeSpinsController get fsCtrl => _fsCtrl;
  GridController get gridCtrl => _gridCtrl;

  String _username = 'Loading...';
  String get username => _username;

  String _email = 'Loading...';
  String get email => _email;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _loggedOut = false;
  bool get loggedOut => _loggedOut;

  static const int columns = SlotEngine.columns;
  static const int rows = SlotEngine.rows;

  List<List<String>> get grid => _gridCtrl.grid;
  List<List<String>> get previousGrid => _gridCtrl.previousGrid;
  Set<String> get fadingPaths => _gridCtrl.fadingPaths;
  List<ClusterWin> get activeExplosions => _gridCtrl.activeExplosions;
  Set<int> get winningPositions => _gridCtrl.winningPositions;
  Set<int> get clearedPositions => _gridCtrl.clearedPositions;

  bool _isTumbling = false;
  bool get isTumbling => _isTumbling;

  bool _isSpinning = false;
  bool get isSpinning => _isSpinning;

  bool _isAutoSpinning = false;
  bool get isAutoSpinning => _isAutoSpinning;

  bool _lastSpinWasFreeSpin = false;
  bool get lastSpinWasFreeSpin => _lastSpinWasFreeSpin;

  int _autoSpinsRemaining = 0;
  int get autoSpinsRemaining => _autoSpinsRemaining;

  bool get isBusy => _isSpinning || _isTumbling;

  int _speedMultiplier = 1;
  int get speedMultiplier => _speedMultiplier;

  bool _showInsufficientFundsHint = false;
  bool get showInsufficientFundsHint => _showInsufficientFundsHint;
  Timer? _insufficientHintTimer;

  double _liveTumbleWin = 0;
  double get liveTumbleWin => _liveTumbleWin;

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

  bool _fsRoundHoldActive = false;

  bool get isInFreeSpins => _fsCtrl.isActive || _fsRoundHoldActive;

  bool get canBuyFreeSpins =>
      !isBusy &&
      !_isAutoSpinning &&
      !isInFreeSpins &&
      _balanceCtrl.canAffordDisplayed(buyFeaturePrice);

  bool get canBuyFreeSpinsForUi =>
      !isBusy &&
      !_isAutoSpinning &&
      !isInFreeSpins &&
      _balanceCtrl.canAffordDisplayed(buyFeaturePrice);

  bool get canSpinForUi =>
      isInFreeSpins || _balanceCtrl.canAffordDisplayed(effectiveBetCost);

  bool get canSpin => isInFreeSpins || _balanceCtrl.canAfford(effectiveBetCost);

  PoolState _pool = PoolState();
  SpinResult? _pendingResult;
  double _pendingHistoryBet = 0;
  bool _pendingFsConsume = false;

  bool _currentSpinFromBuy = false;
  bool get isCurrentSpinFromBuy => _currentSpinFromBuy;
  final List<GameHistoryEntry> _gameHistory = [];
  List<GameHistoryEntry> get gameHistory => List.unmodifiable(_gameHistory);

  SpinResult? _lastSpinResult;
  SpinResult? get lastSpinResult => _lastSpinResult;
  bool get shouldPulseLandingScatters {
    if (isInFreeSpins) return false;

    final pending = _pendingResult;
    if (pending == null || pending.freeSpinsTriggered) return false;

    final grid = pending.initialGrid;
    final scatterPath = SymbolRegistry.all
        .firstWhere((s) => s.isScatter)
        .assetPath;
    final scatterCount = grid
        .expand((column) => column)
        .where((path) => path == scatterPath)
        .length;

    return scatterCount >= 4;
  }

  static const Duration _tumbleFadeDuration = Duration(milliseconds: 1750);
  static const Duration _tumbleSettleDuration = Duration(milliseconds: 450);

  bool _vibration = true;
  bool get vibration => _vibration;
  void setVibration(bool value) {
    if (_vibration == value) return;
    _vibration = value;
    notifyListeners();
  }

  bool _ambientMusic = AmbientMusicPreference.enabled;
  bool get ambientMusic => _ambientMusic;
  void setAmbientMusic(bool value) {
    if (_ambientMusic == value) return;
    _ambientMusic = value;
    AmbientMusicPreference.enabled = value;
    unawaited(_musicService.setEnabled(_ambientMusic));
    notifyListeners();
  }

  bool _soundEffects = true;
  bool get soundEffects => _soundEffects;
  void setSoundEffects(bool value) {
    _soundEffects = value;
    UiClickSound.enabled = value;
    if (value) unawaited(UiClickSound.preload());
    notifyListeners();
  }

  void _flashInsufficientFundsHint() {
    _showInsufficientFundsHint = true;
    notifyListeners();
    _insufficientHintTimer?.cancel();
    _insufficientHintTimer = Timer(const Duration(seconds: 2), () {
      _showInsufficientFundsHint = false;
      notifyListeners();
    });
  }

  void startAutoSpin(int spinCount, {int speedMultiplier = 1}) {
    if (_isAutoSpinning || isBusy || spinCount <= 0) return;
    if (!isInFreeSpins && !_balanceCtrl.canAfford(effectiveBetCost)) {
      _flashInsufficientFundsHint();
      return;
    }

    _autoSpinsRemaining = spinCount;
    _speedMultiplier = speedMultiplier.clamp(1, 3).toInt();
    _isAutoSpinning = true;
    spin();
  }

  void stopAutoSpin() {
    if (!_isAutoSpinning && _autoSpinsRemaining == 0) return;
    _isAutoSpinning = false;
    _autoSpinsRemaining = 0;
    notifyListeners();
  }

  void toggleAutoSpin() {
    if (_isAutoSpinning) {
      stopAutoSpin();
    } else {
      startAutoSpin(100, speedMultiplier: _speedMultiplier);
    }
  }

  void continueAutoSpinIfReady({
    Duration delay = const Duration(milliseconds: 600),
  }) {
    if (!_isAutoSpinning || isBusy) return;
    Future.delayed(delay, () {
      if (_isAutoSpinning && !isBusy) {
        spin();
      }
    });
  }

  void _consumeAutoSpinAtStart() {
    if (!_isAutoSpinning) return;
    _autoSpinsRemaining = (_autoSpinsRemaining - 1).clamp(0, 9999).toInt();
  }

  void toggleSpeed() {
    if (isBusy && !_isAutoSpinning) return;
    _speedMultiplier = (_speedMultiplier % 3) + 1;
    notifyListeners();
  }

  void toggleAnteBet() {
    if (isBusy || isInFreeSpins || _isAutoSpinning) return;
    _anteCtrl.toggle();
    _balanceCtrl.anteActiveShadow = _anteCtrl.active;
  }

  void increaseBet() {
    if (_isAutoSpinning || isInFreeSpins) return;
    _balanceCtrl.increaseBet();
  }

  void decreaseBet() {
    if (_isAutoSpinning || isInFreeSpins) return;
    _balanceCtrl.decreaseBet();
  }

  Future<void> purchaseGameMoney(double amount) async {
    if (amount <= 0) return;
    _balanceCtrl.depositGameMoney(amount);
    _showInsufficientFundsHint = false;
    notifyListeners();

    final uid = _authRepository.currentUserId;
    if (uid == null) return;
    try {
      await _authRepository.savePlayerState(
        uid,
        userBalance: userBalance,
        freeSpinsRemaining: freeSpinsRemaining,
      );
    } catch (e) {
      debugPrint('Deposit money save error: $e');
    }
  }

  Future<void> fetchUserData() async {
    try {
      final uid = _authRepository.currentUserId;
      if (uid != null) {
        await _loadGameHistory(uid);

        final results = await Future.wait([
          _authRepository.getUserData(uid),
          _poolRepository.load(uid),
        ]);

        final userData = results[0] as Map<String, dynamic>?;
        _pool = results[1] as PoolState;
        _listenToUserBalance(uid);

        if (userData != null) {
          _username = userData['username'] ?? 'Player';
          _email = userData['email'] ?? 'No Email';
          _balanceCtrl.hydrate(userData);
          _fsCtrl.hydrate(userData);

          if (!userData.containsKey('userBalance')) {
            _savePlayerState();
          }
        } else {
          _username = 'Unknown';
          _email = 'Unknown';
        }
      }
    } catch (e) {
      debugPrint('Data fetch error: $e');
      _username = 'Error';
      _email = 'Error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _listenToUserBalance(String uid) {
    _userSubscription?.cancel();
    _userSubscription = _authRepository.watchUserData(uid).listen((data) {
      if (data == null || !data.containsKey('userBalance')) return;
      _balanceCtrl.applyRemoteUserBalance(
        (data['userBalance'] ?? 10000.0).toDouble(),
      );
    });
  }

  Future<void> spin() async {
    if (isBusy) return;

    _currentSpinFromBuy = false;

    final bool isFreeSpin = isInFreeSpins;
    _lastSpinWasFreeSpin = isFreeSpin;

    if (!isFreeSpin) {
      final cost = _balanceCtrl.effectiveBetCost;
      if (!_balanceCtrl.canAfford(cost)) {
        if (_isAutoSpinning) {
          _isAutoSpinning = false;
          _autoSpinsRemaining = 0;
        }
        _flashInsufficientFundsHint();
        return;
      }
      _pendingHistoryBet = cost;
      _balanceCtrl.charge(cost);
      _pool.recordBet(cost);
    } else {
      _pendingHistoryBet = 0;
      _pendingFsConsume = true;
      _fsRoundHoldActive = true;
    }

    _consumeAutoSpinAtStart();
    _isSpinning = true;
    _balanceCtrl.resetLastWin();
    _liveTumbleWin = 0;
    _gridCtrl.capturePreviousGrid();
    _gridCtrl.resetForNewSpin();
    if (_vibration) HapticFeedback.lightImpact();
    notifyListeners();

    final bool anteFlag = isFreeSpin
        ? _anteCtrl.currentRoundFromAnte
        : _anteCtrl.active;
    final bool buyFlag = isFreeSpin && _fsCtrl.currentRoundFromBuy;

    // Run engine off UI isolate.
    final taskOutput = await compute(
      runSlotSpinTask,
      SpinTaskInput(
        pool: _pool,
        betAmount: betAmount,
        isFreeSpins: isFreeSpin,
        anteBet: anteFlag,
        buyFs: buyFlag,
      ),
    );

    _pool = taskOutput.pool;
    _pendingResult = taskOutput.result;

    if (isFreeSpin) {
      commitPendingFsConsume();
    }
    _gridCtrl.setGrid(_pendingResult!.initialGrid);
  }

  Future<void> buyFreeSpins() async {
    if (_isAutoSpinning) {
      _isAutoSpinning = false;
      _autoSpinsRemaining = 0;
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

    _isSpinning = true;
    _balanceCtrl.resetLastWin();
    _liveTumbleWin = 0;
    _gridCtrl.capturePreviousGrid();
    _gridCtrl.resetForNewSpin();
    if (_vibration) HapticFeedback.lightImpact();
    notifyListeners();

    final taskOutput = await compute(
      runSlotSpinTask,
      SpinTaskInput(
        pool: _pool,
        betAmount: betAmount,
        isFreeSpins: false,
        anteBet: false,
        buyFs: false,
        forceFsTrigger: true,
      ),
    );

    _pool = taskOutput.pool;
    _pendingResult = taskOutput.result;
    _gridCtrl.setGrid(_pendingResult!.initialGrid);
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

    if (result.tumbles.isNotEmpty) {
      _isTumbling = true;
      notifyListeners();
      for (final tumble in result.tumbles) {
        _liveTumbleWin += tumble.winAmount;
        _gridCtrl.startTumble(
          fadingPaths: tumble.winningPaths,
          activeExplosions: tumble.clusterWins,
        );
        notifyListeners();
        if (_vibration) HapticFeedback.mediumImpact();
        await Future.delayed(_tumbleFadeDuration);

        _gridCtrl.endTumble(newGrid: tumble.gridAfter);
        await Future.delayed(_tumbleSettleDuration);
      }
      _isTumbling = false;
      notifyListeners();
    }

    _balanceCtrl.awardWin(result.totalWin);
    final playedAt = DateTime.now();
    _gameHistory.insert(
      0,
      GameHistoryEntry(
        id: playedAt.microsecondsSinceEpoch.toString(),
        playedAt: playedAt,
        newBalance: userBalance,
        bet: _pendingHistoryBet,
        winAmount: result.totalWin,
      ),
    );
    if (_gameHistory.length > 30) {
      _gameHistory.removeLast();
    }
    _saveGameHistory();
    if (_vibration && result.totalWin > 0) HapticFeedback.heavyImpact();
    _gridCtrl.setWinningPositions(result.winningPositions);
    _lastSpinResult = result;

    if (result.freeSpinsTriggered) {
      if (result.isRetrigger) {
        _fsCtrl.awardRetrigger();
      } else {
        _fsCtrl.awardInitial();
        _anteCtrl.captureForNewRound();
        if (_currentSpinFromBuy) {
          _fsCtrl.markCurrentRoundFromBuy();
        }
      }
      _savePlayerState();
    }

    if (!isInFreeSpins) {
      _anteCtrl.clearRoundFlag();
      _fsCtrl.clearRoundFlag();
    }

    _pool.recordPayout(result.totalWin);
    _savePoolIfNeeded();

    _pendingResult = null;
    _pendingHistoryBet = 0;

    if (_isAutoSpinning) {
      if (_autoSpinsRemaining == 0) {
        _isAutoSpinning = false;
      }
      notifyListeners();
    }
  }

  void commitPendingFsConsume() {
    if (!_pendingFsConsume) return;
    _pendingFsConsume = false;
    _fsCtrl.consumeOne();
    _savePlayerState();
  }

  void releaseFsRoundHold() {
    if (!_fsRoundHoldActive) return;
    _fsRoundHoldActive = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _forceSavePool();
    await _userSubscription?.cancel();
    _userSubscription = null;
    await _authRepository.signOut();
    _loggedOut = true;
    notifyListeners();
  }

  void resetLoggedOut() {
    _loggedOut = false;
  }

  Future<void> _loadGameHistory(String userId) async {
    try {
      _gameHistory
        ..clear()
        ..addAll(await _gameHistoryRepository.load(userId));
    } catch (e) {
      debugPrint('Game history load error: $e');
    }
  }

  Future<void> _saveGameHistory() async {
    final uid = _authRepository.currentUserId;
    if (uid == null) return;
    try {
      await _gameHistoryRepository.save(uid, _gameHistory);
    } catch (e) {
      debugPrint('Game history save error: $e');
    }
  }

  void deleteGameHistoryEntries(Set<String> ids) {
    if (ids.isEmpty) return;
    _gameHistory.removeWhere((entry) => ids.contains(entry.id));
    _saveGameHistory();
    notifyListeners();
  }

  void _savePlayerState() {
    final uid = _authRepository.currentUserId;
    if (uid != null) {
      _authRepository.savePlayerState(
        uid,
        userBalance: userBalance,
        freeSpinsRemaining: freeSpinsRemaining,
      );
    }
  }

  void _savePoolIfNeeded() {
    if (_pool.shouldSave) {
      final uid = _authRepository.currentUserId;
      if (uid != null) {
        _poolRepository.save(uid, _pool);
        _savePlayerState();
      }
    }
  }

  Future<void> _forceSavePool() async {
    final uid = _authRepository.currentUserId;
    if (uid != null) {
      await _poolRepository.save(uid, _pool);
      await _authRepository.savePlayerState(
        uid,
        userBalance: userBalance,
        freeSpinsRemaining: freeSpinsRemaining,
      );
    }
  }

  Future<void> onAppLifecycleEvent() async {
    await _musicService.pauseForLifecycle(enabled: _ambientMusic);
    await _forceSavePool();
  }

  void onAppResumed() {
    unawaited(_musicService.resumeAfterLifecycle(enabled: _ambientMusic));
  }

  @override
  void dispose() {
    unawaited(_musicService.dispose());
    _userSubscription?.cancel();
    _insufficientHintTimer?.cancel();
    _balanceCtrl.dispose();
    _anteCtrl.dispose();
    _fsCtrl.dispose();
    _gridCtrl.dispose();
    super.dispose();
  }
}
