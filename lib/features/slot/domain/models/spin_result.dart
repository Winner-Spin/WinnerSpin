import 'multiplier_landing.dart';
import 'tumble_step.dart';

class SpinResult {

  final List<List<String>> initialGrid;

  final List<TumbleStep> tumbles;

  final double totalWin;

  /// Sum of cluster wins before multiplier/scatter bonus.
  final double baseWin;

  /// Multiplier symbols on the final grid, tagged with position.
  final List<MultiplierLanding> finalMultipliers;

  final int tumbleCount;
  final bool freeSpinsTriggered;

  /// True if triggered during an active FS round (awards +5 instead of +10).
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
    this.baseWin = 0,
    this.finalMultipliers = const [],
    this.winningPositions = const {},
    this.isRetrigger = false,
  });
}
