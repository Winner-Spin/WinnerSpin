/// Version of the disclaimer text the player is asked to accept.
///
/// Raise this whenever the wording changes in a way that matters — a consent
/// recorded against version 1 is not consent to a version 2 text. Everyone
/// whose stored acceptance is older than this is asked again.
const int kDisclaimerVersion = 1;

/// Device-side record of the acceptance, kept per account.
///
/// Per account rather than per device because consent is personal: a second
/// person signing up on the same phone has agreed to nothing, and would
/// otherwise walk straight past the notice on someone else's tick.
abstract class FirstLaunchDisclaimerRepository {
  Future<bool> hasSeenDisclaimer(String userId);

  Future<void> markDisclaimerSeen(String userId);
}

/// Durable record of who accepted the disclaimer, when, and which text.
///
/// The local flag alone is not evidence: it lives in a file the player can
/// clear by reinstalling, and it says nothing about *which* wording was shown.
/// This one is written to the account, so it survives reinstalls and can be
/// produced later if the acceptance is ever disputed.
abstract class DisclaimerAcceptanceRepository {
  /// True when [userId] has already accepted version [version] or newer.
  Future<bool> hasAccepted({required String userId, required int version});

  Future<void> recordAcceptance({
    required String userId,
    required int version,
    required String appVersion,
  });

  /// Copies the acceptance somewhere the account deletion cannot reach.
  ///
  /// The record normally lives on the user document, which is exactly what
  /// deleting an account removes — so without this the evidence disappears at
  /// the moment it is most likely to be asked for. Called just before the
  /// account goes, while the source record is still readable.
  ///
  /// Does nothing when there is no acceptance to copy.
  Future<void> archiveAcceptance({
    required String userId,
    required String email,
  });
}
