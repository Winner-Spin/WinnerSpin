import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/slot_engine.dart';
import '../services/pool_service.dart';
import '../models/pool_state.dart';

class GameViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // ─── USER DATA ──────────────────────────────────────────────

  String _username = 'Yükleniyor...';
  String get username => _username;

  String _email = 'Yükleniyor...';
  String get email => _email;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _loggedOut = false;
  bool get loggedOut => _loggedOut;

  // ─── SLOT GRID STATE (6 columns × 5 rows) ──────────────────

  static const int columns = SlotEngine.columns;
  static const int rows = SlotEngine.rows;

  /// The 6×5 grid: grid[col][row] = asset path.
  late List<List<String>> _grid;
  List<List<String>> get grid => _grid;

  /// The previous grid (used for drop-out animation).
  List<List<String>> _previousGrid = [];
  List<List<String>> get previousGrid => _previousGrid;

  /// During a tumble, asset paths whose cells should fade out.
  /// Empty when no tumble is in progress.
  Set<String> _fadingPaths = const {};
  Set<String> get fadingPaths => _fadingPaths;

  /// True while we are stepping through cascade tumbles
  /// (after the initial reel drop-in completes).
  bool _isTumbling = false;
  bool get isTumbling => _isTumbling;

  /// True if a spin or its cascade tumbles are still in progress.
  /// UI uses this to disable the spin button and keep the "spinning" visuals.
  bool get isBusy => _isSpinning || _isTumbling;

  // ─── BALANCE & BET ──────────────────────────────────────────

  double _balance = 10000.0;
  double get balance => _balance;

  double _betAmount = 100.0;
  double get betAmount => _betAmount;

  double _lastWin = 0.0;
  double get lastWin => _lastWin;

  static const double _minBet = 10.0;
  static const double _maxBet = 5000.0;

  bool _isSpinning = false;
  bool get isSpinning => _isSpinning;

  /// Ante Bet: when active, the player pays 1.25× their base bet and the
  /// engine doubles the FS trigger rate for that spin. Payouts are still
  /// computed against the 1.0× base bet (per project spec).
  bool _anteBetActive = false;
  bool get anteBetActive => _anteBetActive;

  /// Effective amount deducted per non-FS spin (1.25× when ante is active).
  double get effectiveBetCost =>
      _anteBetActive ? _betAmount * 1.25 : _betAmount;

  /// Cost in TL of the Buy Free Spins feature at the current bet level.
  double get buyFeaturePrice =>
      _betAmount * SlotEngine.buyFeaturePriceMultiplier;

  /// Whether the player can currently buy a FS round.
  /// Blocks during spin/tumble, while already in FS, when balance is short,
  /// and when the pool's Virtual Cost guard says it can't accommodate one.
  bool get canBuyFreeSpins =>
      !isBusy &&
      !isInFreeSpins &&
      _balance >= buyFeaturePrice &&
      SlotEngine.canAffordBuyFs(_pool, _betAmount);

  int _speedMultiplier = 1;
  int get speedMultiplier => _speedMultiplier;

  void toggleSpeed() {
    if (_isSpinning || _isTumbling) return;
    _speedMultiplier = (_speedMultiplier % 3) + 1;
    notifyListeners();
  }

  /// Flips the Ante Bet on/off. Disallowed during a spin, a cascade,
  /// or while inside a Free Spins round.
  void toggleAnteBet() {
    if (isBusy || isInFreeSpins) return;
    _anteBetActive = !_anteBetActive;
    notifyListeners();
  }

  // ─── POOL STATE ─────────────────────────────────────────────

  PoolState _pool = PoolState();

  /// Cached spin result (pre-calculated by the engine).
  SpinResult? _pendingResult;

  // ─── FREE SPINS STATE ───────────────────────────────────────
  
  int _freeSpinsRemaining = 0;
  int get freeSpinsRemaining => _freeSpinsRemaining;
  bool get isInFreeSpins => _freeSpinsRemaining > 0;

  // ─── CONSTRUCTOR ────────────────────────────────────────────

  GameViewModel() {
    // Generate initial display grid using normal mode weights.
    final result = SlotEngine.spin(_pool, 0);
    _grid = result.initialGrid;
    _previousGrid = List.generate(columns, (col) => List.from(_grid[col]));
  }

  // ─── FETCH USER DATA + POOL ─────────────────────────────────

  Future<void> fetchUserData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Fetch user profile and pool state in parallel.
        final results = await Future.wait([
          _authService.getUserData(user.uid),
          PoolService.load(user.uid),
        ]);

        final userData = results[0] as Map<String, dynamic>?;
        _pool = results[1] as PoolState;

        if (userData != null) {
          _username = userData['username'] ?? 'Kullanıcı';
          _email = userData['email'] ?? 'Email Yok';
          _balance = (userData['balance'] ?? 10000.0).toDouble();
          _freeSpinsRemaining = userData['freeSpinsRemaining'] ?? 0;
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

  // ─── SPIN ───────────────────────────────────────────────────

  /// Prepares the spin: deducts bet, runs the math engine,
  /// and sets the new target grid for animation.
  void spin() {
    if (_isSpinning || _isTumbling) return;

    // Check if we are in free spins mode
    final bool isFreeSpin = isInFreeSpins;

    // Normal spin: check and deduct balance (1.25× when ante is active).
    // Inside FS rounds, ante is ignored (FS spins are always free).
    if (!isFreeSpin) {
      final cost = effectiveBetCost;
      if (_balance < cost) return;
      _balance -= cost;
      _pool.recordBet(cost); // Pool sees the full ante-inflated wager.
    } else {
      // Consume one free spin
      _freeSpinsRemaining--;
    }

    _isSpinning = true;
    _lastWin = 0.0;
    _fadingPaths = const {};

    // Snapshot the current grid for drop-out animation.
    _previousGrid = List.generate(columns, (col) => List.from(_grid[col]));

    // Run the engine synchronously.
    //   - betAmount: ALWAYS the 1.0× base; the +25% from ante is overhead
    //     paid into the pool, NOT part of the payout calculation.
    //   - anteBet: doubles the FS trigger rate for this base spin only.
    _pendingResult = SlotEngine.spin(
      _pool,
      _betAmount,
      isFreeSpins: isFreeSpin,
      anteBet: _anteBetActive && !isFreeSpin,
    );

    // Set the initial grid the UI will animate towards via reel drop-in.
    // Tumbles are played back AFTER drop-in completes (in onSpinComplete).
    _grid = _pendingResult!.initialGrid;

    notifyListeners();
  }

  /// Player-initiated Buy Free Spins.
  /// Charges 100× base bet to the player and pool, then queues a 10-spin
  /// FS round. The next [spin] call (or the auto-spin loop, if enabled)
  /// consumes the first free spin.
  ///
  /// Blocked when [canBuyFreeSpins] is false (busy, in FS, short balance,
  /// or pool can't safely accommodate it per the Virtual Cost guard).
  void buyFreeSpins() {
    if (!canBuyFreeSpins) return;

    final price = buyFeaturePrice;
    _balance -= price;
    // Pool gets the full 100× fee credited as wagered.
    _pool.recordBet(price);
    _freeSpinsRemaining += 10;

    notifyListeners();
  }

  /// Duration that matched cells take to fade out before being replaced.
  static const Duration _tumbleFadeDuration = Duration(milliseconds: 350);

  /// Time the new (refilled) grid is held visible before the next tumble starts.
  /// Also gives the per-cell drop-in animation time to settle.
  static const Duration _tumbleSettleDuration = Duration(milliseconds: 450);

  /// Called when the final SlotReel completes its initial drop-in animation.
  /// Plays back any cascade tumbles, then awards the win.
  Future<void> onSpinComplete() async {
    final result = _pendingResult;
    if (result == null) {
      _isSpinning = false;
      notifyListeners();
      return;
    }

    // The reels finished their initial spin animation.
    _isSpinning = false;

    // Play cascade tumbles (matched fade out → next grid drops new symbols).
    if (result.tumbles.isNotEmpty) {
      _isTumbling = true;

      for (final tumble in result.tumbles) {
        // 1) Fade out the cells whose paths matched this tumble.
        _fadingPaths = tumble.winningPaths;
        notifyListeners();
        await Future.delayed(_tumbleFadeDuration);

        // 2) Swap to the post-tumble grid; SlotReel drops new symbols
        //    into cells whose paths changed.
        _grid = tumble.gridAfter;
        _fadingPaths = const {};
        notifyListeners();
        await Future.delayed(_tumbleSettleDuration);
      }

      _isTumbling = false;
    }

    // Award the final win (already includes multipliers + scatter bonus).
    _lastWin = result.totalWin;
    _balance += _lastWin;

    if (result.freeSpinsTriggered) {
      _freeSpinsRemaining += result.isRetrigger ? 5 : 10;
    }

    _pool.recordPayout(_lastWin);
    _savePoolIfNeeded();

    _pendingResult = null;
    notifyListeners();
  }

  // ─── BET CONTROLS ───────────────────────────────────────────

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

  // ─── SIGN OUT ───────────────────────────────────────────────

  Future<void> signOut() async {
    // Force save pool state before logging out.
    await _forceSavePool();
    await _authService.signOut();
    _loggedOut = true;
    notifyListeners();
  }

  /// Resets the loggedOut flag after navigation is handled.
  void resetLoggedOut() {
    _loggedOut = false;
  }

  // ─── POOL PERSISTENCE ──────────────────────────────────────

  /// Saves player state (balance, free spins) to Firestore
  void _savePlayerState() {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).set({
        'balance': _balance,
        'freeSpinsRemaining': _freeSpinsRemaining,
      }, SetOptions(merge: true));
    }
  }

  /// Saves pool to Firestore if the save interval has been reached.
  void _savePoolIfNeeded() {
    if (_pool.shouldSave) {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        // Fire-and-forget — non-blocking async write.
        PoolService.save(uid, _pool);
        _savePlayerState();
      }
    }
  }

  /// Forces an immediate pool save (used on logout/background).
  Future<void> _forceSavePool() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      await PoolService.save(uid, _pool);
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'balance': _balance,
        'freeSpinsRemaining': _freeSpinsRemaining,
      }, SetOptions(merge: true));
    }
  }

  /// Call this when the app goes to background to persist pool data.
  Future<void> onAppPaused() async {
    await _forceSavePool();
  }
}
