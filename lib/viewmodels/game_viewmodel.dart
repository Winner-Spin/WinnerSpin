import 'dart:async';

import 'package:flutter/material.dart';

import '../models/pool_state.dart';
import '../models/spin_result.dart';
import '../repositories/auth_repository.dart';
import '../repositories/firebase_auth_repository.dart';
import '../repositories/firestore_pool_repository.dart';
import '../repositories/pool_repository.dart';
import '../services/slot_engine.dart';

class GameViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;
  final PoolRepository _poolRepository;
  StreamSubscription<Map<String, dynamic>?>? _userSubscription;

  // ── User data ──

  String _username = 'Yükleniyor...';
  String get username => _username;

  String _email = 'Yükleniyor...';
  String get email => _email;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _loggedOut = false;
  bool get loggedOut => _loggedOut;

  // ── Grid state (6 cols × 5 rows) ──

  static const int columns = SlotEngine.columns;
  static const int rows = SlotEngine.rows;

  /// `grid[col][row]` = asset path of the cell.
  late List<List<String>> _grid;
  List<List<String>> get grid => _grid;

  /// Previous grid snapshot used for drop-out animation.
  List<List<String>> _previousGrid = [];
  List<List<String>> get previousGrid => _previousGrid;

  /// Asset paths whose cells should fade out during a cascade tumble.
  Set<String> _fadingPaths = const {};
  Set<String> get fadingPaths => _fadingPaths;

  /// True while cascade tumbles are playing back (post initial reel drop-in).
  bool _isTumbling = false;
  bool get isTumbling => _isTumbling;

  /// True while any spin or its cascade is still animating. UI disables the
  /// spin button when this is true.
  bool get isBusy => _isSpinning || _isTumbling;

  // ── Balance & bet ──

  double _balance = 10000.0;
  double get balance => _balance;

  double _userBalance = 10000.0;
  double get userBalance => _userBalance;

  double _betAmount = 100.0;
  double get betAmount => _betAmount;

  double _lastWin = 0.0;
  double get lastWin => _lastWin;

  static const double _minBet = 10.0;
  static const double _maxBet = 5000.0;

  bool _isSpinning = false;
  bool get isSpinning => _isSpinning;

  /// When true, the player pays 1.25× per base spin and the engine doubles
  /// the FS trigger rate for that spin. Payout math still uses the 1.0× bet.
  bool _anteBetActive = false;
  bool get anteBetActive => _anteBetActive;

  /// Per-base-spin cost (1.25× when ante is active, 1.0× otherwise).
  double get effectiveBetCost =>
      _anteBetActive ? _betAmount * 1.25 : _betAmount;

  /// Buy Free Spins price in TL at the current bet level.
  double get buyFeaturePrice =>
      _betAmount * SlotEngine.buyFeaturePriceMultiplier;

  /// True only when the buy CTA can fire — not busy, not in FS, balance
  /// available, and the pool guard greenlights the purchase.
  bool get canBuyFreeSpins =>
      !isBusy &&
      !isInFreeSpins &&
      _userBalance >= buyFeaturePrice &&
      SlotEngine.canAffordBuyFs(_pool, _betAmount);

  /// Winning cell positions from the last spin. Encoded as `col * 100 + row`.
  Set<int> _winningPositions = {};
  Set<int> get winningPositions => _winningPositions;

  int _speedMultiplier = 1;
  int get speedMultiplier => _speedMultiplier;

  void toggleSpeed() {
    if (_isSpinning || _isTumbling) return;
    _speedMultiplier = (_speedMultiplier % 3) + 1;
    notifyListeners();
  }

  /// Flips Ante Bet on/off. Blocked while spinning, cascading, or in FS.
  void toggleAnteBet() {
    if (isBusy || isInFreeSpins) return;
    _anteBetActive = !_anteBetActive;
    notifyListeners();
  }

  // ── Pool state ──

  PoolState _pool = PoolState();

  /// Pre-calculated spin result waiting for the UI animation to play it back.
  SpinResult? _pendingResult;

  // ── Free Spins state ──

  int _freeSpinsRemaining = 0;
  int get freeSpinsRemaining => _freeSpinsRemaining;
  bool get isInFreeSpins => _freeSpinsRemaining > 0;

  /// True for the duration of an ante-triggered FS round so the engine
  /// applies the ante multiplier scale on every spin (incl. retriggers).
  bool _currentFsRoundFromAnte = false;

  /// True for the duration of a bought FS round so the engine applies the
  /// buy multiplier boost on every spin (incl. retriggers).
  bool _currentFsRoundFromBuy = false;

  GameViewModel({
    AuthRepository? authRepository,
    PoolRepository? poolRepository,
  })  : _authRepository = authRepository ?? FirebaseAuthRepository(),
        _poolRepository = poolRepository ?? FirestorePoolRepository() {
    // Bootstrap display grid via a zero-bet spin (engine returns a safe grid).
    final result = SlotEngine.spin(_pool, 0);
    _grid = result.initialGrid;
    _previousGrid = List.generate(columns, (col) => List.from(_grid[col]));
  }

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
          _balance = (userData['balance'] ?? 10000.0).toDouble();
          _userBalance = (userData['userBalance'] ?? 10000.0).toDouble();
          _freeSpinsRemaining = userData['freeSpinsRemaining'] ?? 0;

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
      _userBalance = (data['userBalance'] ?? 10000.0).toDouble();
      notifyListeners();
    });
  }

  // ── Spin ──

  /// Deducts the bet, runs the engine, and stages the result for animation.
  void spin() {
    if (_isSpinning || _isTumbling) return;

    final bool isFreeSpin = isInFreeSpins;

    if (!isFreeSpin) {
      final cost = effectiveBetCost;
      if (_userBalance < cost) return;
      _balance -= cost;
      _userBalance -= cost;
      _pool.recordBet(cost);
    } else {
      _freeSpinsRemaining--;
    }

    _isSpinning = true;
    _lastWin = 0.0;
    _fadingPaths = const {};
    _winningPositions = {};

    _previousGrid = List.generate(columns, (col) => List.from(_grid[col]));

    // Engine call. anteBet/buyFs flags propagate the round's origin so
    // multiplier scaling stays consistent across every spin of the round.
    final bool anteFlag = isFreeSpin ? _currentFsRoundFromAnte : _anteBetActive;
    final bool buyFlag = isFreeSpin && _currentFsRoundFromBuy;
    _pendingResult = SlotEngine.spin(
      _pool,
      _betAmount,
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
    _balance -= price;
    _userBalance -= price;
    _pool.recordBet(price);
    _freeSpinsRemaining += 10;
    _currentFsRoundFromBuy = true;

    notifyListeners();
  }

  /// Fade-out duration for matched cells in a cascade tumble.
  static const Duration _tumbleFadeDuration = Duration(milliseconds: 350);

  /// Settle duration after each tumble — gives drop-in animations room.
  static const Duration _tumbleSettleDuration = Duration(milliseconds: 450);

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
        notifyListeners();
        await Future.delayed(_tumbleFadeDuration);

        _grid = tumble.gridAfter;
        _fadingPaths = const {};
        notifyListeners();
        await Future.delayed(_tumbleSettleDuration);
      }
      _isTumbling = false;
    }

    _lastWin = result.totalWin;
    _balance += _lastWin;
    _userBalance += _lastWin;
    _winningPositions = result.winningPositions;

    if (result.freeSpinsTriggered) {
      _freeSpinsRemaining += result.isRetrigger ? 5 : 10;
      // Only an initial trigger captures ante state — retriggers inherit
      // the existing round's flag.
      if (!result.isRetrigger) {
        _currentFsRoundFromAnte = _anteBetActive;
      }
    }

    if (_freeSpinsRemaining == 0) {
      if (_currentFsRoundFromAnte) _currentFsRoundFromAnte = false;
      if (_currentFsRoundFromBuy) _currentFsRoundFromBuy = false;
    }

    _pool.recordPayout(_lastWin);
    _savePoolIfNeeded();
    _savePlayerState();

    _pendingResult = null;
    notifyListeners();
  }

  // ── Bet controls ──

  void increaseBet() {
    if (_betAmount < _maxBet) {
      _betAmount = (_betAmount * 2).clamp(_minBet, _maxBet);
      notifyListeners();
    }
  }

  void decreaseBet() {
    if (_betAmount > _minBet) {
      _betAmount = (_betAmount / 2).clamp(_minBet, _maxBet);
      notifyListeners();
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

  /// Resets the loggedOut flag once navigation has consumed it.
  void resetLoggedOut() {
    _loggedOut = false;
  }

  // ── Persistence ──

  void _savePlayerState() {
    final uid = _authRepository.currentUserId;
    if (uid != null) {
      _authRepository.savePlayerState(
        uid,
        userBalance: _userBalance,
        freeSpinsRemaining: _freeSpinsRemaining,
      );
    }
  }

  /// Fire-and-forget pool save once the save interval has elapsed.
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
        userBalance: _userBalance,
        freeSpinsRemaining: _freeSpinsRemaining,
      );
    }
  }

  Future<void> onAppPaused() async {
    await _forceSavePool();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
