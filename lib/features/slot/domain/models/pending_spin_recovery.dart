class PendingSpinRecovery {
  const PendingSpinRecovery({
    required this.spinId,
    required this.playedAt,
    required this.isFreeSpin,
    required this.historyBet,
    required this.winAmount,
    required this.userBalance,
    required this.freeSpinsRemaining,
    required this.freeSpinAccumulatedWin,
    required this.freeSpinsAwardedThisRound,
    required this.pendingFreeSpinAward,
    required this.roundFromAnte,
    required this.roundFromBuy,
    required this.poolTotalBetsPlaced,
    required this.poolTotalPaidOut,
    required this.poolTotalSpins,
  });

  static const int schemaVersion = 2;

  final String spinId;
  final DateTime playedAt;
  final bool isFreeSpin;
  final double historyBet;
  final double winAmount;
  final double userBalance;
  final int freeSpinsRemaining;
  final double freeSpinAccumulatedWin;
  final int freeSpinsAwardedThisRound;
  final int pendingFreeSpinAward;
  final bool roundFromAnte;
  final bool roundFromBuy;
  final double poolTotalBetsPlaced;
  final double poolTotalPaidOut;
  final int poolTotalSpins;

  factory PendingSpinRecovery.fromJson(Map<String, dynamic> json) {
    final version = (json['schemaVersion'] as num?)?.toInt();
    if (version != 1 && version != schemaVersion) {
      throw const FormatException('Unsupported spin recovery schema.');
    }
    final pendingFreeSpinAward = version == 1
        ? 0
        : (json['pendingFreeSpinAward'] as num).toInt();
    if (pendingFreeSpinAward != 0 &&
        pendingFreeSpinAward != 5 &&
        pendingFreeSpinAward != 10) {
      throw const FormatException('Invalid pending Free Spin award.');
    }
    return PendingSpinRecovery(
      spinId: json['spinId'] as String,
      playedAt: DateTime.parse(json['playedAt'] as String).toUtc(),
      isFreeSpin: json['isFreeSpin'] == true,
      historyBet: (json['historyBet'] as num).toDouble(),
      winAmount: (json['winAmount'] as num).toDouble(),
      userBalance: (json['userBalance'] as num).toDouble(),
      freeSpinsRemaining: (json['freeSpinsRemaining'] as num).toInt(),
      freeSpinAccumulatedWin: (json['freeSpinAccumulatedWin'] as num)
          .toDouble(),
      freeSpinsAwardedThisRound: (json['freeSpinsAwardedThisRound'] as num)
          .toInt(),
      pendingFreeSpinAward: pendingFreeSpinAward,
      roundFromAnte: json['roundFromAnte'] == true,
      roundFromBuy: json['roundFromBuy'] == true,
      poolTotalBetsPlaced: (json['poolTotalBetsPlaced'] as num).toDouble(),
      poolTotalPaidOut: (json['poolTotalPaidOut'] as num).toDouble(),
      poolTotalSpins: (json['poolTotalSpins'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'spinId': spinId,
      'playedAt': playedAt.toUtc().toIso8601String(),
      'isFreeSpin': isFreeSpin,
      'historyBet': historyBet,
      'winAmount': winAmount,
      'userBalance': userBalance,
      'freeSpinsRemaining': freeSpinsRemaining,
      'freeSpinAccumulatedWin': freeSpinAccumulatedWin,
      'freeSpinsAwardedThisRound': freeSpinsAwardedThisRound,
      'pendingFreeSpinAward': pendingFreeSpinAward,
      'roundFromAnte': roundFromAnte,
      'roundFromBuy': roundFromBuy,
      'poolTotalBetsPlaced': poolTotalBetsPlaced,
      'poolTotalPaidOut': poolTotalPaidOut,
      'poolTotalSpins': poolTotalSpins,
    };
  }
}
