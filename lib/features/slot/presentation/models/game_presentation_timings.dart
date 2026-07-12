class GamePresentationTimings {
  const GamePresentationTimings._();

  static const celebrationLockMaxHold = Duration(seconds: 20);
  static const freeSpinVisualRevealDelay = Duration(milliseconds: 900);
  static const freeSpinTransitionDuration = Duration(milliseconds: 1500);
  static const scatterPulseDuration = Duration(milliseconds: 1050);
  static const normalBigWinDelay = Duration(milliseconds: 800);
  static const freeSpinNoSequenceWinDelay = Duration(milliseconds: 600);
  static const freeSpinAutoPlayDelay = Duration(milliseconds: 600);
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
