import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

Future<void> initializeFirebaseAppCheck() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: androidAppCheckProvider(isRelease: kReleaseMode),
    );
  } catch (error, stackTrace) {
    debugPrint('Firebase App Check could not be activated: $error\n$stackTrace');
  }
}

@visibleForTesting
AndroidAppCheckProvider androidAppCheckProvider({required bool isRelease}) {
  return isRelease
      ? const AndroidPlayIntegrityProvider()
      : const AndroidDebugProvider();
}
