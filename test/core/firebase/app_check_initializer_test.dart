import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/firebase/app_check_initializer.dart';

void main() {
  test('uses the debug provider for Android development builds', () {
    final provider = androidAppCheckProvider(isRelease: false);

    expect(provider, isA<AndroidDebugProvider>());
  });

  test('uses Play Integrity for Android release builds', () {
    final provider = androidAppCheckProvider(isRelease: true);

    expect(provider, isA<AndroidPlayIntegrityProvider>());
  });

  test('uses the debug provider for Apple development builds', () {
    // App Attest cannot run on the simulator, so development has to use the
    // debug token instead.
    final provider = appleAppCheckProvider(isRelease: false);

    expect(provider, isA<AppleDebugProvider>());
  });

  test('uses App Attest for Apple release builds', () {
    final provider = appleAppCheckProvider(isRelease: true);

    expect(provider, isA<AppleAppAttestProvider>());
    expect(
      provider,
      isNot(isA<AppleDeviceCheckProvider>()),
      reason: 'DeviceCheck is the SDK default and the weaker attestation',
    );
  });
}
