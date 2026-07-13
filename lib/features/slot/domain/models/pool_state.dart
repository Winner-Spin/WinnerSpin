import 'dart:math';
import '../enums/game_mode.dart';

class PoolState {
  double totalBetsPlaced;
  double totalPaidOut;
  int totalSpins;
  int _spinsSinceLastSave;

  static const double targetRTP = 0.965;

  static const int saveInterval = 10;

  GameMode? _sessionMode;
  int _sessionExpiresAtSpin = 0;

  static const int _minSessionSpins = 50;
  static const int _maxSessionExtraSpins = 200;

  final Random _modeRandom;

  PoolState({
    this.totalBetsPlaced = 0,
    this.totalPaidOut = 0,
    this.totalSpins = 0,
    int spinsSinceLastSave = 0,
    Random? modeRandom,
  }) : _spinsSinceLastSave = spinsSinceLastSave,
       _modeRandom = modeRandom ?? Random();

  double get poolBalance => totalBetsPlaced - totalPaidOut;

  double get expectedPool => totalBetsPlaced * (1 - targetRTP);

  double get _rtpDeficit {
    if (totalBetsPlaced <= 0) return 0;
    final actualRTP = totalPaidOut / totalBetsPlaced;
    return targetRTP - actualRTP;
  }

  GameMode get currentMode {
    if (totalSpins < 50) return GameMode.normal;
    final deficit = _rtpDeficit;

    if (deficit > 0.10) return GameMode.jackpot;
    if (deficit < -0.10) return GameMode.recovery;

    if (_sessionMode != null && totalSpins < _sessionExpiresAtSpin) {
      return _sessionMode!;
    }

    final roll = _modeRandom.nextDouble();
    GameMode mode;
    if (roll < 0.65) {
      mode = GameMode.normal;
    } else if (roll < 0.82) {
      mode = GameMode.generous;
    } else if (roll < 0.95) {
      mode = GameMode.tight;
    } else if (roll < 0.98) {
      mode = GameMode.jackpot;
    } else {
      mode = GameMode.recovery;
    }

    _sessionMode = mode;
    _sessionExpiresAtSpin =
        totalSpins +
        _minSessionSpins +
        _modeRandom.nextInt(_maxSessionExtraSpins + 1);
    return mode;
  }

  void recordBet(double amount) {
    totalBetsPlaced += amount;
    totalSpins++;
    _spinsSinceLastSave++;
  }

  void recordPayout(double amount) {
    totalPaidOut += amount;
  }

  bool get shouldSave => _spinsSinceLastSave >= saveInterval;

  void markSaved() {
    _spinsSinceLastSave = 0;
  }

  Map<String, dynamic> toMap() => {
    'totalBetsPlaced': totalBetsPlaced,
    'totalPaidOut': totalPaidOut,
    'totalSpins': totalSpins,
  };

  factory PoolState.fromMap(Map<String, dynamic> map) => PoolState(
    totalBetsPlaced: (map['totalBetsPlaced'] ?? 0).toDouble(),
    totalPaidOut: (map['totalPaidOut'] ?? 0).toDouble(),
    totalSpins: (map['totalSpins'] ?? 0) as int,
  );
}
