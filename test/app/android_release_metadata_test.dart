import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/update/app_build_info.dart';

void main() {
  test('Android launcher uses the public application name', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:label="Winner Spin"'));
    expect(manifest, isNot(contains('android:label="winner_spin"')));
  });

  test('runtime build metadata matches pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([^+\s]+)\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(version, isNotNull);
    expect(kAppVersion, version!.group(1));
    expect(kAppBuildNumber, version.group(2));
  });

  test('Android, Play Store, and Firebase package metadata agree', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final appSource = File('lib/app/app.dart').readAsStringSync();
    final firebaseOptions = File(
      'lib/firebase_options.dart',
    ).readAsStringSync();
    final googleServices =
        jsonDecode(File('android/app/google-services.json').readAsStringSync())
            as Map<String, dynamic>;

    final applicationId = RegExp(
      r'applicationId\s*=\s*"([^"]+)"',
    ).firstMatch(gradle)?.group(1);
    final playStorePackage = RegExp(
      r"playStorePackageName\s*=\s*'([^']+)'",
    ).firstMatch(appSource)?.group(1);
    final androidOptions = RegExp(
      r'static const FirebaseOptions android = FirebaseOptions\((.*?)\n\s*\);',
      dotAll: true,
    ).firstMatch(firebaseOptions)?.group(1);
    final firebaseAppId = RegExp(
      r"appId:\s*'([^']+)'",
    ).firstMatch(androidOptions ?? '')?.group(1);

    expect(applicationId, isNotNull);
    expect(playStorePackage, applicationId);
    expect(firebaseAppId, isNotNull);

    final clients = googleServices['client'] as List<dynamic>;
    final matchingClient = clients.cast<Map<String, dynamic>>().where((client) {
      final info = client['client_info'] as Map<String, dynamic>;
      final androidInfo = info['android_client_info'] as Map<String, dynamic>;
      return androidInfo['package_name'] == applicationId &&
          info['mobilesdk_app_id'] == firebaseAppId;
    });

    expect(matchingClient, hasLength(1));
  });
}
