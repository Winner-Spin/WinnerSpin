class GameRulesPayoutFormatter {
  const GameRulesPayoutFormatter._();

  static String rangeText(int threshold, List<int> sortedThresholds) {
    final index = sortedThresholds.indexOf(threshold);
    if (index == 0) return '$threshold+';

    final nextHigher = sortedThresholds[index - 1];
    return '$threshold - ${nextHigher - 1}';
  }

  static String scatterRangeText(int threshold, List<int> sortedThresholds) {
    return sortedThresholds.indexOf(threshold) == 0
        ? '$threshold+'
        : '$threshold';
  }

  static String payoutValue(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    return '${parts[0]},${parts[1]}';
  }
}
