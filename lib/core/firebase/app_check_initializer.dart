import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Activates App Check so Firebase can tell requests from this app apart from
/// requests forged by someone holding the (public) API key.
///
/// Apple platforms use App Attest, which needs iOS 14+; this app targets iOS 15
/// so there is no DeviceCheck fallback to maintain. Without this call the
/// Firebase SDK still asks for a token, falls back to DeviceCheck on its own,
/// and logs `App not registered` — which is what the console error was.
Future<void> initializeFirebaseAppCheck() async {
  if (kIsWeb) return;
  if (!_supportedPlatforms.contains(defaultTargetPlatform)) return;

  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: androidAppCheckProvider(isRelease: kReleaseMode),
      providerApple: appleAppCheckProvider(isRelease: kReleaseMode),
    );
  } catch (error, stackTrace) {
    debugPrint(
      'Firebase App Check could not be activated: $error\n$stackTrace',
    );
  }
}

const Set<TargetPlatform> _supportedPlatforms = {
  TargetPlatform.android,
  TargetPlatform.iOS,
  TargetPlatform.macOS,
};

@visibleForTesting
AndroidAppCheckProvider androidAppCheckProvider({required bool isRelease}) {
  return isRelease
      ? const AndroidPlayIntegrityProvider()
      : const AndroidDebugProvider();
}

/// App Attest for shipped builds, the debug provider otherwise.
///
/// The debug provider is not a weaker attestation, it is a different one: it
/// prints a token that has to be registered by hand in the Firebase console.
/// That is the only thing that works on the simulator, where App Attest has no
/// hardware to attest with.
@visibleForTesting
AppleAppCheckProvider appleAppCheckProvider({required bool isRelease}) {
  return isRelease
      ? const AppleAppAttestProvider()
      : const AppleDebugProvider();
}
