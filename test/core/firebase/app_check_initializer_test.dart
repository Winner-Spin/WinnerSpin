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
}
