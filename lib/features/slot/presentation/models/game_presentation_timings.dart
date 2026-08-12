class GamePresentationTimings {
  const GamePresentationTimings._();

  static double flightSpeedFactorFor(int speedMultiplier) {
    return switch (speedMultiplier.clamp(1, 3)) {
      2 => 1.125,
      3 => 1.25,
      _ => 1.0,
    };
  }

  static Duration flightDurationForSpeed(
    Duration baseDuration,
    int speedMultiplier,
  ) {
    final microseconds =
        (baseDuration.inMicroseconds / flightSpeedFactorFor(speedMultiplier))
            .round();
    return Duration(microseconds: microseconds.clamp(1, 1 << 31).toInt());
  }

  static const celebrationLockMaxHold = Duration(seconds: 20);
  static const freeSpinVisualRevealDelay = Duration(milliseconds: 900);
  static const freeSpinTransitionDuration = Duration(milliseconds: 1500);
  static const scatterPulseDuration = Duration(milliseconds: 1050);
  static const normalBigWinDelay = Duration(milliseconds: 800);
  static const freeSpinNoSequenceWinDelay = Duration(milliseconds: 600);
  static const freeSpinAutoPlayDelay = Duration(milliseconds: 600);
  static const freeSpinPostWinPulse = Duration(milliseconds: 500);
  static const freeSpinPostWinHold = Duration(milliseconds: 700);
  static const lingeringClusterHold = Duration(seconds: 1);
  static const flyingTumbleDuration = Duration(milliseconds: 700);
  static const flyingTumbleReleaseDelay = Duration(milliseconds: 700);
  static const deferredSymbolPrecacheDelay = Duration(milliseconds: 300);
  static const symbolPrecacheBatchDelay = Duration(milliseconds: 24);
  static const freeSpinPopupShowDuration = Duration(milliseconds: 520);
  static const freeSpinPopupDismissDuration = Duration(milliseconds: 220);
  static const statusFreeSpinWinCount = Duration(milliseconds: 700);
  static const statusTumbleWinCount = Duration(milliseconds: 900);
  static const tumbleLineLiveCount = Duration(milliseconds: 350);
}
