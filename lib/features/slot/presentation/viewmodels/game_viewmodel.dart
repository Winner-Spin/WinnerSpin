import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models/pool_state.dart';
import '../../domain/models/spin_result.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/data/repositories/firebase_auth_repository.dart';
import '../../data/repositories/firestore_pool_repository.dart';
import '../../domain/repositories/pool_repository.dart';
import '../../domain/engine/slot_engine.dart';
import 'controllers/ante_controller.dart';
import 'controllers/balance_controller.dart';
import 'controllers/free_spins_controller.dart';
import '../../domain/models/cluster_win.dart';

/// Top-level orchestrator for the slot screen. Composes three focused
/// controllers (balance, ante, free spins) and coordinates the engine,
/// repositories, and animation lifecycle. The View listens to this single
/// ChangeNotifier; getters delegate to the underlying controllers.
class GameViewModel extends ChangeNotifier {
  GameViewModel({
    AuthRepository? authRepository,
    PoolRepository? poolRepository,
  })  : _authRepository = authRepository ?? FirebaseAuthRepository(),
        _poolRepository = poolRepository ?? FirestorePoolRepository() {
    final result = SlotEngine.spin(_pool, 0);
    _grid = result.initialGrid;
    _previousGrid = List.generate(columns, (col) => List.from(_grid[col]));
  }

  final AuthRepository _authRepository;
  final PoolRepository _poolRepository;
  StreamSubscription<Map<String, dynamic>?>? _userSubscription;

  // ── Composed controllers ──
  final BalanceController _balanceCtrl = BalanceController();
  final AnteController _anteCtrl = AnteController();
  final FreeSpinsController _fsCtrl = FreeSpinsController();

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

  late List<List<String>> _grid;
  List<List<String>> get grid => _grid;

  List<List<String>> _previousGrid = [];
  List<List<String>> get previousGrid => _previousGrid;

  Set<String> _fadingPaths = const {};
  Set<String> get fadingPaths => _fadingPaths;

  List<ClusterWin> _activeExplosions = const [];
  List<ClusterWin> get activeExplosions => _activeExplosions;

  bool _isTumbling = false;
  bool get isTumbling => _isTumbling;

  bool _isSpinning = false;
  bool get isSpinning => _isSpinning;

  bool _isAutoSpinning = false;
  bool get isAutoSpinning => _isAutoSpinning;

  /// True while any spin or its cascade is still animating.
  bool get isBusy => _isSpinning || _isTumbling;

  Set<int> _winningPositions = {};
  Set<int> get winningPositions => _winningPositions;

  int _speedMultiplier = 1;
  int get speedMultiplier => _speedMultiplier;

  // ── Balance & bet (delegated to BalanceController) ──

  double get balance => _balanceCtrl.balance;
  double get userBalance => _balanceCtrl.userBalance;
  double get betAmount => _balanceCtrl.betAmount;
  double get lastWin => _balanceCtrl.lastWin;
  double get effectiveBetCost => _balanceCtrl.effectiveBetCost;
  double get buyFeaturePrice => _balanceCtrl.buyFeaturePrice;

  // ── Ante (delegated to AnteController) ──

  bool get anteBetActive => _anteCtrl.active;

  // ── Free spins (delegated to FreeSpinsController) ──

  int get freeSpinsRemaining => _fsCtrl.remaining;
  bool get isInFreeSpins => _fsCtrl.isActive;

  /// True only when the buy CTA can fire.
  bool get canBuyFreeSpins =>
      !isBusy &&
      !_isAutoSpinning &&
      !isInFreeSpins &&
      _balanceCtrl.canAfford(buyFeaturePrice) &&
      SlotEngine.canAffordBuyFs(_pool, betAmount);

  // ── Pool + pending result ──

  PoolState _pool = PoolState();
  SpinResult? _pendingResult;

  // ── Tumble animation timing ──
  /// Window for the winning-cell glow + fade. First half is the gold-glow
  /// celebration, second half is the symbol fade-out — see [TumbleCell].
  static const Duration _tumbleFadeDuration = Duration(milliseconds: 600);
  static const Duration _tumbleSettleDuration = Duration(milliseconds: 450);

  // ── User actions ──

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
    notifyListeners();
  }

  void increaseBet() {
    if (_isAutoSpinning) return;
    if (_balanceCtrl.increaseBet()) notifyListeners();
  }

  void decreaseBet() {
    if (_isAutoSpinning) return;
    if (_balanceCtrl.decreaseBet()) notifyListeners();
  }

  // ── User data lifecycle ──

  Future<void> fetchUserData() async {
    try {
      final uid = _authRepository.currentUserId;
      if (uid != null) {
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
      notifyListeners();
    });
  }

  // ── Spin ──

  /// Deducts the bet, runs the engine, and stages the result for animation.
  void spin() {
    if (isBusy) return;

    final bool isFreeSpin = isInFreeSpins;

    if (!isFreeSpin) {
      final cost = _balanceCtrl.effectiveBetCost;
      if (!_balanceCtrl.canAfford(cost)) {
        if (_isAutoSpinning) {
          _isAutoSpinning = false;
          notifyListeners();
        }
        return;
      }
      _balanceCtrl.charge(cost);
      _pool.recordBet(cost);
    } else {
      _fsCtrl.consumeOne();
    }

    _isSpinning = true;
    _balanceCtrl.resetLastWin();
    _fadingPaths = const {};
    _activeExplosions = const [];
    _winningPositions = {};

    _previousGrid = List.generate(columns, (col) => List.from(_grid[col]));

    // anteBet/buyFs flags propagate the round's origin so multiplier scaling
    // stays consistent across every spin (incl. retriggers).
    final bool anteFlag =
        isFreeSpin ? _anteCtrl.currentRoundFromAnte : _anteCtrl.active;
    final bool buyFlag = isFreeSpin && _fsCtrl.currentRoundFromBuy;
    _pendingResult = SlotEngine.spin(
      _pool,
      betAmount,
      isFreeSpins: isFreeSpin,
      anteBet: anteFlag,
      buyFs: buyFlag,
    );

    _grid = _pendingResult!.initialGrid;
    notifyListeners();
  }

  /// Buys an FS round at 100× bet. Charges the fee, queues 10 free spins,
  /// and flags the round as bought so the engine applies the buy boost.
  void buyFreeSpins() {
    if (!canBuyFreeSpins) return;

    final price = buyFeaturePrice;
    _balanceCtrl.charge(price);
    _pool.recordBet(price);
    _fsCtrl.awardBoughtRound();

    notifyListeners();
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
      for (final tumble in result.tumbles) {
        _fadingPaths = tumble.winningPaths;
        _activeExplosions = tumble.clusterWins;
        notifyListeners();
        await Future.delayed(_tumbleFadeDuration);

        _grid = tumble.gridAfter;
        _fadingPaths = const {};
        _activeExplosions = const [];
        notifyListeners();
        await Future.delayed(_tumbleSettleDuration);
      }
      _isTumbling = false;
    }

    _balanceCtrl.awardWin(result.totalWin);
    _winningPositions = result.winningPositions;

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
    notifyListeners();

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
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
