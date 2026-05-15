abstract class FirstLaunchDisclaimerRepository {
  Future<bool> hasSeenDisclaimer();

  Future<void> markDisclaimerSeen();
}
