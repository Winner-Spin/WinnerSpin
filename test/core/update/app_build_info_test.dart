import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/update/app_build_info.dart';

void main() {
  test('the constants match the version in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml has no version: line');

    // pubspec carries `1.0.0+1`: marketing version, then build number.
    final parts = match!.group(1)!.split('+');
    final declaredVersion = parts.first;
    final declaredBuild = parts.length > 1 ? parts[1] : '1';

    const fix =
        'Run `node tool/sync_app_version.js` so the settings screen and the '
        'forced-update check report what this build actually ships.';

    expect(
      kAppVersion,
      declaredVersion,
      reason:
          'pubspec.yaml says $declaredVersion but app_build_info.dart says '
          '$kAppVersion. $fix',
    );
    expect(
      kAppBuildNumber,
      declaredBuild,
      reason:
          'pubspec.yaml says build $declaredBuild but app_build_info.dart says '
          '$kAppBuildNumber. $fix',
    );
  });

  test('the reported version is parseable by the update check', () {
    expect(RegExp(r'^\d+(\.\d+)*$').hasMatch(kAppVersion), isTrue);
  });

  test('the build number is a plain number', () {
    // Shown as "VERSION 1.0.0 (1)", and the stores only accept integers here.
    expect(RegExp(r'^\d+$').hasMatch(kAppBuildNumber), isTrue);
  });
}
