/// The version this build reports to the forced-update check, and shows at the
/// bottom of the settings screen.
///
/// Deliberately a plain constant rather than `package_info_plus`: that package
/// is a native plugin, so adding it forces a CocoaPods install and can break
/// the iOS build. Reading the version is the only thing it was needed for, and
/// a constant does that with no native side at all.
///
/// The obvious risk is drift — someone bumps `pubspec.yaml` and forgets this
/// file. `test/core/update/app_build_info_test.dart` reads `pubspec.yaml` and
/// fails when the two disagree, so drift cannot reach a release unnoticed.
///
/// Keep in sync with the `version:` line in `pubspec.yaml`.
const String kAppVersion = '1.0.0';

/// The build number — the part after `+` in the `pubspec.yaml` version.
///
/// Shown next to [kAppVersion] in the settings screen, because two builds can
/// ship the same version while only the build number tells them apart, which is
/// what matters when someone reports a bug against a specific TestFlight build.
///
/// Deliberately kept out of the forced-update comparison: the store gate is
/// about the marketing version, and comparing build numbers would block testers
/// running a newer build of the same version.
const String kAppBuildNumber = '1';
