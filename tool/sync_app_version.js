#!/usr/bin/env node
'use strict';

/**
 * Copies the version and build number from `pubspec.yaml` into
 * `lib/core/update/app_build_info.dart`.
 *
 * The app needs its own version as a Dart value for the forced-update check and
 * for the settings screen. Reading it at runtime would mean `package_info_plus`,
 * a native plugin that drags in a CocoaPods install and has broken the iOS build
 * here before — so the value is a constant instead, and this script keeps it
 * honest.
 *
 * Usage:
 *   node tool/sync_app_version.js          # rewrite the constants
 *   node tool/sync_app_version.js --check  # fail if out of sync, change nothing
 *
 * `--check` is the CI-friendly form; `flutter test` also fails on drift via
 * test/core/update/app_build_info_test.dart.
 */

const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const pubspecPath = path.join(root, 'pubspec.yaml');
const dartPath = path.join(root, 'lib', 'core', 'update', 'app_build_info.dart');

const checkOnly = process.argv.includes('--check');

const pubspec = fs.readFileSync(pubspecPath, 'utf8');
const versionMatch = /^version:\s*(\S+)\s*$/m.exec(pubspec);
if (!versionMatch) {
  console.error('No version: line in pubspec.yaml');
  process.exit(1);
}

// pubspec carries `1.0.0+1`: the marketing version, then the build number.
const [version, buildNumber = '1'] = versionMatch[1].split('+');
if (!/^\d+(\.\d+)*$/.test(version)) {
  console.error(`pubspec version "${version}" is not a dotted number.`);
  process.exit(1);
}
if (!/^\d+$/.test(buildNumber)) {
  console.error(`pubspec build number "${buildNumber}" is not a number.`);
  process.exit(1);
}

const constants = [
  {name: 'kAppVersion', value: version},
  {name: 'kAppBuildNumber', value: buildNumber},
];

let dart = fs.readFileSync(dartPath, 'utf8');
const changes = [];

for (const constant of constants) {
  const pattern = new RegExp(`(const String ${constant.name} = ')([^']*)(';)`);
  const current = pattern.exec(dart);
  if (!current) {
    console.error(`Could not find ${constant.name} in ${dartPath}`);
    process.exit(1);
  }
  if (current[2] === constant.value) continue;
  changes.push({name: constant.name, from: current[2], to: constant.value});
  dart = dart.replace(pattern, `$1${constant.value}$3`);
}

if (changes.length === 0) {
  console.log(`Already in sync: ${version}+${buildNumber}`);
  process.exit(0);
}

if (checkOnly) {
  console.error(`Out of sync with pubspec.yaml (${version}+${buildNumber}):`);
  for (const change of changes) {
    console.error(`  ${change.name}: ${change.from} should be ${change.to}`);
  }
  console.error('Run: node tool/sync_app_version.js');
  process.exit(1);
}

fs.writeFileSync(dartPath, dart);
for (const change of changes) {
  console.log(`Updated ${change.name}: ${change.from} -> ${change.to}`);
}
