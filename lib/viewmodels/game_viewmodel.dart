import 'package:flutter/material.dart';
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
    _grid = result.grid;
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
    if (_isSpinning) return;
    
    // Check if we are in free spins mode
    final bool isFreeSpin = isInFreeSpins;

    // Normal spin: check and deduct balance
    if (!isFreeSpin) {
      if (_balance < _betAmount) return;
      _balance -= _betAmount;
      _pool.recordBet(_betAmount); // Only record bet if it costs money
    } else {
      // Consume one free spin
      _freeSpinsRemaining--;
    }

    _isSpinning = true;
    _lastWin = 0.0;

    // Snapshot the current grid for drop-out animation.
    _previousGrid = List.generate(columns, (col) => List.from(_grid[col]));

    // Run the entire math engine synchronously.
    // Pass the isFreeSpin flag to boost multipliers!
    _pendingResult = SlotEngine.spin(_pool, _betAmount, isFreeSpins: isFreeSpin);

    // Set the grid the UI will animate towards.
    _grid = _pendingResult!.grid;

    notifyListeners();
  }

  /// Called when the final SlotReel completes its drop-in animation.
  void onSpinComplete() {
    if (_pendingResult != null) {
      _lastWin = _pendingResult!.totalWin;
      _balance += _lastWin;

      // Award free spins if triggered
      if (_pendingResult!.freeSpinsTriggered) {
        _freeSpinsRemaining += 10;
      }

      // Record payout in pool.
      _pool.recordPayout(_lastWin);

      // Save to Firestore periodically (every 10 spins).
      _savePoolIfNeeded();

      _pendingResult = null;
    }

    _isSpinning = false;
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

  /// Saves pool to Firestore if the save interval has been reached.
  void _savePoolIfNeeded() {
    if (_pool.shouldSave) {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        // Fire-and-forget — non-blocking async write.
        PoolService.save(uid, _pool);
      }
    }
  }

  /// Forces an immediate pool save (used on logout/background).
  Future<void> _forceSavePool() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      await PoolService.save(uid, _pool);
    }
  }

  /// Call this when the app goes to background to persist pool data.
  Future<void> onAppPaused() async {
    await _forceSavePool();
  }
}
