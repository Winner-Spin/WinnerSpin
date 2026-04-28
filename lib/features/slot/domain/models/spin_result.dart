import 'tumble_step.dart';

/// Result of a single spin (including all tumble rounds).
class SpinResult {
  /// The grid that drops in initially (before any tumbles).
  final List<List<String>> initialGrid;

  /// Ordered tumble steps. Empty if the initial grid had no winning matches.
  final List<TumbleStep> tumbles;

  final double totalWin;
  final int tumbleCount;
  final bool freeSpinsTriggered;

  /// True if this trigger occurred while the player was already in a Free
  /// Spins round. ViewModel should award +5 spins instead of +10.
  final bool isRetrigger;

  final int scatterCount;
  final double scatterPayout;
  final Set<int> winningPositions;

  const SpinResult({
    required this.initialGrid,
    required this.tumbles,
    required this.totalWin,
    required this.tumbleCount,
    required this.freeSpinsTriggered,
    required this.scatterCount,
    required this.scatterPayout,
    this.winningPositions = const {},
    this.isRetrigger = false,
  });
}
