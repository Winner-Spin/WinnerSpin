/// Tracks Ante Bet state — both the player's toggle and the per-round
/// flag that propagates the ante economics across an FS round.
class AnteController {
  bool _active = false;
  bool _currentRoundFromAnte = false;

  /// True while the Ante Bet toggle is on (player-facing setting).
  bool get active => _active;

  /// True while the in-progress FS round was triggered by an ante base spin.
  /// The engine reads this to apply the ante multiplier scale across the
  /// entire round, including retriggers.
  bool get currentRoundFromAnte => _currentRoundFromAnte;

  /// Flips the toggle. Callers should guard against busy/in-FS states.
  void toggle() {
    _active = !_active;
  }

  /// Captures the toggle state when a base spin triggers FS so the round
  /// stays flagged as ante-triggered for its entire duration.
  void captureForNewRound() {
    _currentRoundFromAnte = _active;
  }

  /// Clears the round flag. Called when the FS round ends.
  void clearRoundFlag() {
    _currentRoundFromAnte = false;
  }
}
