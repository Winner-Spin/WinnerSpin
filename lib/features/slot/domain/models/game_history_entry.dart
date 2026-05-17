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
