import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/pool_state.dart';
import '../../domain/models/spin_result.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/data/repositories/firebase_auth_repository.dart';
import '../../data/repositories/firestore_pool_repository.dart';
import '../../domain/repositories/pool_repository.dart';
import '../../domain/engine/slot_engine.dart';
import '../../domain/engine/spin_task.dart';
import '../../domain/models/cluster_win.dart';
import 'controllers/ante_controller.dart';
import 'controllers/balance_controller.dart';
import 'controllers/free_spins_controller.dart';
import 'controllers/grid_controller.dart';

class GameHistoryEntry {
  const GameHistoryEntry({
    required this.id,
    required this.playedAt,
    required this.newBalance,
    required this.bet,
    required this.winAmount,
  });

  factory GameHistoryEntry.fromJson(Map<String, dynamic> json) {
    final playedAt = DateTime.parse(json['playedAt'] as String);
    return GameHistoryEntry(
      id: json['id'] as String? ?? playedAt.microsecondsSinceEpoch.toString(),
      playedAt: playedAt,
      newBalance: (json['newBalance'] as num).toDouble(),
      bet: (json['bet'] as num).toDouble(),
      winAmount: (json['winAmount'] as num).toDouble(),
    );
  }

  final String id;
  final DateTime playedAt;
  final double newBalance;
  final double bet;
  final double winAmount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playedAt': playedAt.toIso8601String(),
      'newBalance': newBalance,
      'bet': bet,
      'winAmount': winAmount,
    };
  }
}

/// Top-level orchestrator for the slot screen. Composes four focused
/// sub-controllers (balance, ante, free spins, grid) and coordinates the
/// engine, repositories, and animation lifecycle. Each sub-controller is
/// itself a ChangeNotifier and is exposed via a public getter so views
/// can subscribe only to the slice of state they care about. This
/// ViewModel notifies for state it owns directly: spinning/tumbling
/// flags, auto-spin, speed, and user-profile fields.
class GameViewModel extends ChangeNotifier {
  GameViewModel({
    AuthRepository? authRepository,
    PoolRepository? poolRepository,
  }) : _authRepository = authRepository ?? FirebaseAuthRepository(),
       _poolRepository = poolRepository ?? FirestorePoolRepository() {
    final result = SlotEngine.spin(_pool, 0);
    _gridCtrl = GridController(result.initialGrid);
    _initMusic();
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isMusicInitialized = false;

  Future<void> _initMusic() async {
    _isMusicInitialized = true;
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    if (_ambientMusic) {
      await _audioPlayer.play(AssetSource('audio/bg_music.mp3'));
    }
  }

  final AuthRepository _authRepository;
  final PoolRepository _poolRepository;
  StreamSubscription<Map<String, dynamic>?>? _userSubscription;

  // ── Composed controllers ──
  final BalanceController _balanceCtrl = BalanceController();
  final AnteController _anteCtrl = AnteController();
  final FreeSpinsController _fsCtrl = FreeSpinsController();
  late final GridController _gridCtrl;

  BalanceController get balanceCtrl => _balanceCtrl;
  AnteController get anteCtrl => _anteCtrl;
  FreeSpinsController get fsCtrl => _fsCtrl;
  GridController get gridCtrl => _gridCtrl;

  // ── User profile ──

  String _username = 'Yükleniyor...';
  String get username => _username;

  String _email = 'Yükleniyor...';
  String get email => _email;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _loggedOut = false;
  bool get loggedOut => _loggedOut;

  // ── Grid + animation state ──

  static const int columns = SlotEngine.columns;
  static const int rows = SlotEngine.rows;

  /// Grid state (delegated to [GridController]).
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

  /// True while any spin or its cascade is still animating.
  bool get isBusy => _isSpinning || _isTumbling;

  int _speedMultiplier = 1;
  int get speedMultiplier => _speedMultiplier;

  bool _showInsufficientFundsHint = false;
  bool get showInsufficientFundsHint => _showInsufficientFundsHint;
  Timer? _insufficientHintTimer;

  /// Running cluster-win total reported live as each tumble step pops.
  /// Drives the status-bar counter so the player watches the value
  /// climb in lock-step with each cluster's celebration animation,
  /// instead of the old behaviour where the counter only ticked up
  /// once after every tumble had finished.
  double _liveTumbleWin = 0;
  double get liveTumbleWin => _liveTumbleWin;

  // ── Balance & bet (delegated to BalanceController) ──

  double get balance => _balanceCtrl.balance;
  double get userBalance => _balanceCtrl.userBalance;
  double get betAmount => _balanceCtrl.betAmount;
  double get lastWin => _balanceCtrl.lastWin;
  double get effectiveBetCost => _balanceCtrl.effectiveBetCost;
  double get anteCost => _balanceCtrl.anteCost;
  double get buyFeaturePrice => _balanceCtrl.buyFeaturePrice;
  bool get canDecreaseBet => _balanceCtrl.canDecreaseBet;
  bool get canIncreaseBet => _balanceCtrl.canIncreaseBet;

  // ── Ante (delegated to AnteController) ──

  bool get anteBetActive => _anteCtrl.active;

  // ── Free spins (delegated to FreeSpinsController) ──

  /// TEMPORARY testing flag — when true the spin always runs in
  /// free-spin mode so multipliers land far more often (engine boosts
  /// hit rate + multiplier weights inside FS). Bypasses balance
  /// charge AND FS counter consumption. Flip back to `false` before
  /// shipping anything.
  static const bool kTestForceFreeSpins = true;

  int get freeSpinsRemaining => _fsCtrl.remaining;
  bool get isInFreeSpins => kTestForceFreeSpins || _fsCtrl.isActive;

  /// True only when the buy CTA can fire.
  bool get canBuyFreeSpins =>
      !isBusy &&
      !_isAutoSpinning &&
      !isInFreeSpins &&
      _balanceCtrl.canAfford(buyFeaturePrice) &&
      SlotEngine.canAffordBuyFs(_pool, betAmount);

  /// User-facing buy availability. Mirrors the displayed credit (not
  /// the canonical balance) so the button doesn't go grey while the
  /// player still sees enough credit to cover the buy. Skips the
  /// engine pool guard for the same reason — the actual buyFreeSpins()
  /// call still re-runs the full canBuyFreeSpins check before charging.
  bool get canBuyFreeSpinsForUi =>
      !isBusy &&
      !_isAutoSpinning &&
      !isInFreeSpins &&
      _balanceCtrl.canAffordDisplayed(buyFeaturePrice);

  /// User-facing spin availability. Same rationale as
  /// [canBuyFreeSpinsForUi] — uses the displayed balance.
  bool get canSpinForUi =>
      isInFreeSpins || _balanceCtrl.canAffordDisplayed(effectiveBetCost);

  /// True when the spin CTA can fire — free spins always allow it
  /// (cost-free), otherwise the player must cover the per-spin cost.
  bool get canSpin => isInFreeSpins || _balanceCtrl.canAfford(effectiveBetCost);

  // ── Pool + pending result ──

  PoolState _pool = PoolState();
  SpinResult? _pendingResult;
  double _pendingHistoryBet = 0;
  String? _historyUserId;
  final List<GameHistoryEntry> _gameHistory = [];
  List<GameHistoryEntry> get gameHistory => List.unmodifiable(_gameHistory);

  /// Exposed result of the most recently completed spin. The win
  /// presentation layer reads `baseWin`, `finalMultipliers`, and
  /// `totalWin` off this to drive the staged collect-and-multiply
  /// reveal.
  SpinResult? _lastSpinResult;
  SpinResult? get lastSpinResult => _lastSpinResult;

  // ── Tumble animation timing ──
  /// Window for the winning-cell glow + fade. First half is the gold-glow
  /// celebration, second half is the symbol fade-out — see [TumbleCell].
  static const Duration _tumbleFadeDuration = Duration(milliseconds: 900);
  static const Duration _tumbleSettleDuration = Duration(milliseconds: 450);

  // ── Settings ──
  bool _vibration = true;
  bool get vibration => _vibration;
  void setVibration(bool value) {
    if (_vibration == value) return;
    _vibration = value;
    notifyListeners();
  }

  bool _ambientMusic = true;
  bool get ambientMusic => _ambientMusic;
  void setAmbientMusic(bool value) {
    if (_ambientMusic == value) return;
    _ambientMusic = value;
    if (_ambientMusic) {
      if (!_isMusicInitialized) {
        _initMusic();
      } else {
        _audioPlayer.resume();
      }
    } else {
      _audioPlayer.pause();
    }
    notifyListeners();
  }

  bool _soundEffects = true;
  bool get soundEffects => _soundEffects;
  void setSoundEffects(bool value) {
    _soundEffects = value;
    notifyListeners();
  }

  // ── User actions ──

  /// Flashes a transient "deposit funds" hint in the status bar for a
  /// couple of seconds. Used when the player taps spin without enough
  /// credit — the spin button stays visually enabled so the tap can
  /// surface this guidance instead of silently no-op'ing.
  void _flashInsufficientFundsHint() {
    _showInsufficientFundsHint = true;
    notifyListeners();
    _insufficientHintTimer?.cancel();
    _insufficientHintTimer = Timer(const Duration(seconds: 2), () {
      _showInsufficientFundsHint = false;
      notifyListeners();
    });
  }

  void toggleAutoSpin() {
    if (_isAutoSpinning) {
      _isAutoSpinning = false;
      notifyListeners();
    } else {
      if (isBusy) return;
      if (!isInFreeSpins && !_balanceCtrl.canAfford(effectiveBetCost)) return;
      _isAutoSpinning = true;
      notifyListeners();
      spin();
    }
  }

  void toggleSpeed() {
    if (isBusy || _isAutoSpinning) return;
    _speedMultiplier = (_speedMultiplier % 3) + 1;
    notifyListeners();
  }

  /// Flips Ante Bet on/off. Blocked while spinning, cascading, or in FS.
  void toggleAnteBet() {
    if (isBusy || isInFreeSpins || _isAutoSpinning) return;
    _anteCtrl.toggle();
    _balanceCtrl.anteActiveShadow = _anteCtrl.active;
  }

  void increaseBet() {
    if (_isAutoSpinning) return;
    _balanceCtrl.increaseBet();
  }

  void decreaseBet() {
    if (_isAutoSpinning) return;
    _balanceCtrl.decreaseBet();
  }

  // ── User data lifecycle ──

  Future<void> fetchUserData() async {
    try {
      final uid = _authRepository.currentUserId;
      if (uid != null) {
        _historyUserId = uid;
        await _loadGameHistory();

        final results = await Future.wait([
          _authRepository.getUserData(uid),
          _poolRepository.load(uid),
        ]);

        final userData = results[0] as Map<String, dynamic>?;
        _pool = results[1] as PoolState;
        _listenToUserBalance(uid);

        if (userData != null) {
          _username = userData['username'] ?? 'Kullanıcı';
          _email = userData['email'] ?? 'Email Yok';
          _balanceCtrl.hydrate(userData);
          _fsCtrl.hydrate(userData);

          if (!userData.containsKey('userBalance')) {
            _savePlayerState();
          }
        } else {
          _username = 'Bilinmiyor';
          _email = 'Bilinmiyor';
        }
      }
    } catch (e) {
      debugPrint('Data fetch error: $e');
      _username = 'Hata oluştu';
      _email = 'Hata oluştu';
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

  // ── Spin ──

  /// Deducts the bet, runs the engine, and stages the result for animation.
  Future<void> spin() async {
    if (isBusy) return;

    final bool isFreeSpin = isInFreeSpins;

    if (!isFreeSpin) {
      final cost = _balanceCtrl.effectiveBetCost;
      if (!_balanceCtrl.canAfford(cost)) {
        if (_isAutoSpinning) {
          _isAutoSpinning = false;
        }
        _flashInsufficientFundsHint();
        return;
      }
      _pendingHistoryBet = cost;
      _balanceCtrl.charge(cost);
      _pool.recordBet(cost);
<<<<<<< Updated upstream
    } else if (!kTestForceFreeSpins) {
      // Real FS round — consume one. Skipped under the test flag so
      // testing isn't bottlenecked by an FS counter that drains.
=======
    } else {
      _pendingHistoryBet = 0;
>>>>>>> Stashed changes
      _fsCtrl.consumeOne();
    }

    _isSpinning = true;
    _balanceCtrl.resetLastWin();
    _liveTumbleWin = 0;
    _gridCtrl.capturePreviousGrid();
    _gridCtrl.resetForNewSpin();
    if (_vibration) HapticFeedback.lightImpact();
    notifyListeners();

    // anteBet/buyFs flags propagate the round's origin so multiplier scaling
    // stays consistent across every spin (incl. retriggers).
    final bool anteFlag = isFreeSpin
        ? _anteCtrl.currentRoundFromAnte
        : _anteCtrl.active;
    final bool buyFlag = isFreeSpin && _fsCtrl.currentRoundFromBuy;

    // Engine runs on a background isolate so the rejection-sampling loop
    // (up to 150 simulated cascades on jackpot/FS spins) doesn't block the
    // tap-down ripple or any in-flight cascade animation.
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

    // Replace the pool reference so the isolate-side session-mode mutation
    // survives the boundary.
    _pool = taskOutput.pool;
    _pendingResult = taskOutput.result;

    _gridCtrl.setGrid(_pendingResult!.initialGrid);
  }

  /// Buys an FS round at 100× bet. Charges the fee, queues 10 free spins,
  /// and flags the round as bought so the engine applies the buy boost.
  void buyFreeSpins() {
    if (!canBuyFreeSpins) return;

    final price = buyFeaturePrice;
    _balanceCtrl.charge(price);
    _pool.recordBet(price);
    _fsCtrl.awardBoughtRound();
  }

  /// Plays back cascade tumbles, awards the win, and persists state.
  /// Called by SlotReel once the initial drop-in animation completes.
  Future<void> onSpinComplete() async {
    final result = _pendingResult;
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
        // Bump the live counter target right when the cluster starts
        // popping so the bar climbs in lock-step with the cell
        // celebration instead of waiting for every tumble to finish.
        _liveTumbleWin += tumble.winAmount;
        _gridCtrl.startTumble(
          fadingPaths: tumble.winningPaths,
          activeExplosions: tumble.clusterWins,
        );
<<<<<<< Updated upstream
        notifyListeners();
=======
        if (_vibration) HapticFeedback.mediumImpact();
>>>>>>> Stashed changes
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
        // Only an initial trigger captures ante state — retriggers inherit
        // the existing round's flag.
        _anteCtrl.captureForNewRound();
      }
    }

    // Round ended? Clear the FS-source flags.
    if (!isInFreeSpins) {
      _anteCtrl.clearRoundFlag();
      _fsCtrl.clearRoundFlag();
    }

    _pool.recordPayout(result.totalWin);
    // Player state is persisted on the same cadence as the pool (every 10
    // base spins). Lifecycle hooks force-save the latest state on background,
    // app close, and logout to cover edge cases between save intervals.
    _savePoolIfNeeded();

    _pendingResult = null;
    _pendingHistoryBet = 0;

    if (_isAutoSpinning) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (_isAutoSpinning && !isBusy) {
          spin();
        }
      });
    }
  }

  // ── Sign out ──

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

  // ── Persistence ──

  Future<File?> _gameHistoryFile() async {
    final uid = _historyUserId;
    if (uid == null) return null;
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/game_history_$uid.json');
  }

  Future<void> _loadGameHistory() async {
    try {
      final file = await _gameHistoryFile();
      if (file == null || !await file.exists()) return;

      final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
      _gameHistory
        ..clear()
        ..addAll(
          decoded
              .cast<Map<String, dynamic>>()
              .map(GameHistoryEntry.fromJson)
              .take(30),
        );
    } catch (e) {
      debugPrint('Game history load error: $e');
    }
  }

  Future<void> _saveGameHistory() async {
    try {
      final file = await _gameHistoryFile();
      if (file == null) return;
      await file.writeAsString(
        jsonEncode(_gameHistory.map((entry) => entry.toJson()).toList()),
      );
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

  /// Fire-and-forget pool + player save once the save interval has elapsed
  /// (every [PoolState.saveInterval] base spins).
  void _savePoolIfNeeded() {
    if (_pool.shouldSave) {
      final uid = _authRepository.currentUserId;
      if (uid != null) {
        _poolRepository.save(uid, _pool);
        _savePlayerState();
      }
    }
  }

  /// Awaited pool save used at logout / app background.
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

  /// Force-save hook for app lifecycle transitions (background, hidden,
  /// detached/killed). Ensures the latest balance + pool state are persisted
  /// even if fewer than [PoolState.saveInterval] spins have elapsed since
  /// the last incremental save.
  Future<void> onAppLifecycleEvent() async {
    await _forceSavePool();
    // Pause music if backgrounded
    if (_ambientMusic) {
      await _audioPlayer.pause();
    }
  }

  void onAppResumed() {
    // Resume music if it should be playing
    if (_ambientMusic) {
      _audioPlayer.resume();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _userSubscription?.cancel();
    _insufficientHintTimer?.cancel();
    _balanceCtrl.dispose();
    _anteCtrl.dispose();
    _fsCtrl.dispose();
    _gridCtrl.dispose();
    super.dispose();
  }
}
