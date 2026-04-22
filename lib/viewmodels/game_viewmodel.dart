import 'dart:math';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class GameViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final Random _random = Random();

  // ─── USER DATA ──────────────────────────────────────────────

  String _username = 'Yükleniyor...';
  String get username => _username;

  String _email = 'Yükleniyor...';
  String get email => _email;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _loggedOut = false;
  bool get loggedOut => _loggedOut;

  // ─── SLOT ITEMS ─────────────────────────────────────────────

  /// All available slot item asset paths.
  static const List<String> slotItems = [
    'lib/images/slot_main_screen/Items/Apple.png',
    'lib/images/slot_main_screen/Items/cilek.png',
    'lib/images/slot_main_screen/Items/karpuz.png',
    'lib/images/slot_main_screen/Items/muz.png',
    'lib/images/slot_main_screen/Items/seftali.png',
    'lib/images/slot_main_screen/Items/uzum.png',
    'lib/images/slot_main_screen/Items/Kalp.png',
    'lib/images/slot_main_screen/Items/cupCake.png',
    'lib/images/slot_main_screen/Items/pembe_ayi.png',
    'lib/images/slot_main_screen/Items/yesil_ayi.png',
    'lib/images/slot_main_screen/Items/mavi_kare.png',
    'lib/images/slot_main_screen/Items/yesil_kare.png',
  ];

  /// Multiplier items (special symbols).
  static const List<String> multiplierItems = [
    'lib/images/slot_main_screen/Items/2x_carpan.png',
    'lib/images/slot_main_screen/Items/3x_carpan.png',
    'lib/images/slot_main_screen/Items/5x_carpan.png',
    'lib/images/slot_main_screen/Items/10x_carpan.png',
    'lib/images/slot_main_screen/Items/25x_carpan.png',
    'lib/images/slot_main_screen/Items/50x_carpan.png',
    'lib/images/slot_main_screen/Items/100x_carpan.png',
  ];

  /// Combined list of all items for reel generation.
  List<String> get allItems => [...slotItems, ...multiplierItems];

  // ─── SLOT GRID STATE (5 columns × 3 rows) ──────────────────

  static const int columns = 6;
  static const int rows = 5;

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

  // ─── CONSTRUCTOR ────────────────────────────────────────────

  GameViewModel() {
    _grid = _generateRandomGrid();
    _previousGrid = List.generate(columns, (col) => List.from(_grid[col]));
  }

  // ─── FETCH USER DATA ────────────────────────────────────────

  Future<void> fetchUserData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final data = await _authService.getUserData(user.uid);

        if (data != null) {
          _username = data['username'] ?? 'Kullanıcı';
          _email = data['email'] ?? 'Email Yok';
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

  /// Prepares the spin: deducts bet, sets previous grid, and generates the new target grid immediately.
  void spin() {
    if (_isSpinning) return;
    if (_balance < _betAmount) return;

    _isSpinning = true;
    _balance -= _betAmount;
    _lastWin = 0.0;
    
    // Snapshot the current grid
    _previousGrid = List.generate(columns, (col) => List.from(_grid[col]));
    
    // Generate target grid immediately for the UI to use in animations
    _grid = _generateRandomGrid();
    
    notifyListeners();
  }

  /// Called precisely when the final SlotReel completes its drop-in animation.
  void onSpinComplete() {
    _lastWin = _calculateWin();
    _balance += _lastWin;
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
    await _authService.signOut();
    _loggedOut = true;
    notifyListeners();
  }

  /// Resets the loggedOut flag after navigation is handled.
  void resetLoggedOut() {
    _loggedOut = false;
  }

  // ─── HELPERS ────────────────────────────────────────────────

  /// Generates a random 5×3 grid of slot items.
  List<List<String>> _generateRandomGrid() {
    final items = allItems;
    return List.generate(columns, (_) {
      return List.generate(rows, (_) {
        return items[_random.nextInt(items.length)];
      });
    });
  }

  /// Basic win calculation — checks rows for 3+ matching symbols.
  double _calculateWin() {
    double totalWin = 0.0;

    for (int row = 0; row < rows; row++) {
      // Check consecutive matches from left
      int matchCount = 1;
      String firstSymbol = _grid[0][row];

      for (int col = 1; col < columns; col++) {
        if (_grid[col][row] == firstSymbol) {
          matchCount++;
        } else {
          break;
        }
      }

      if (matchCount >= 3) {
        double multiplier = matchCount == 5
            ? 10.0
            : matchCount == 4
                ? 5.0
                : 2.0;
        totalWin += _betAmount * multiplier;
      }
    }

    return totalWin;
  }
}
