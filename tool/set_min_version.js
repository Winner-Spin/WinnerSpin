#!/usr/bin/env node
'use strict';

/**
 * Sets the minimum app version that the forced-update gate enforces.
 *
 * Writes `config/appVersion` in Firestore — the document the app reads on every
 * entry. Clients can only read it (see `firestore.rules`), so it has to be
 * written with admin credentials, which is what this script uses.
 *
 * Usage:
 *   node tool/set_min_version.js 1.1.0 --platform android
 *   node tool/set_min_version.js 1.1.0 --platform ios --store-url https://apps.apple.com/app/id6795310235
 *   node tool/set_min_version.js --show
 *
 * Credentials — either works:
 *   1. gcloud auth application-default login
 *   2. GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
 *
 * Never commit a service account key. `.gitignore` already excludes *.json keys
 * placed at the repo root, but the safest place is outside the repo entirely.
 */

const path = require('node:path');

const COLLECTION = 'config';
const DOCUMENT = 'appVersion';

function parseArgs(argv) {
  const args = {
    version: null,
    storeUrl: null,
    platform: null,
    show: false,
    projectId: null,
  };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--show') args.show = true;
    else if (arg === '--store-url') args.storeUrl = argv[++i];
    else if (arg === '--platform') args.platform = argv[++i];
    else if (arg === '--project') args.projectId = argv[++i];
    else if (!arg.startsWith('-') && args.version === null) args.version = arg;
  }
  return args;
}

/** Matches the Dart side: dotted numbers, nothing else. */
function isValidVersion(value) {
  return typeof value === 'string' && /^\d+(\.\d+)*$/.test(value);
}

function compare(a, b) {
  const pa = a.split('.').map(Number);
  const pb = b.split('.').map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const diff = (pa[i] || 0) - (pb[i] || 0);
    if (diff !== 0) return diff;
  }
  return 0;
}

/** The version this repo currently ships, for a sanity check. */
function shippedVersion() {
  const fs = require('node:fs');
  const file = path.join(__dirname, '..', 'pubspec.yaml');
  const match = /^version:\s*(\S+)\s*$/m.exec(fs.readFileSync(file, 'utf8'));
  return match ? match[1].split('+')[0] : null;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  let admin;
  try {
    admin = require(path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin'));
  } catch (_) {
    console.error('firebase-admin not found. Run: cd functions && npm install');
    process.exit(1);
  }

  try {
    admin.initializeApp(
        args.projectId ? {projectId: args.projectId} : undefined,
    );
  } catch (error) {
    console.error('Could not initialise firebase-admin:', error.message);
    console.error('Authenticate with: gcloud auth application-default login');
    process.exit(1);
  }

  const reference = admin.firestore().collection(COLLECTION).doc(DOCUMENT);

  if (args.show || args.version === null) {
    const snapshot = await reference.get();
    if (!snapshot.exists) {
      console.log(`${COLLECTION}/${DOCUMENT} does not exist yet.`);
      console.log('Nothing is enforced until it does — the app fails open.');
    } else {
      console.log(`${COLLECTION}/${DOCUMENT}:`);
      console.log(JSON.stringify(snapshot.data(), null, 2));
    }
    if (args.version === null && !args.show) {
      console.log(
          '\nTo set Android:  node tool/set_min_version.js 1.1.0 --platform android',
      );
    }
    process.exit(0);
  }

  if (!isValidVersion(args.version)) {
    console.error(`"${args.version}" is not a version like 1.1.0.`);
    process.exit(1);
  }
  if (args.platform !== null && !['android', 'ios'].includes(args.platform)) {
    console.error('--platform must be android or ios.');
    process.exit(1);
  }

  // Guard against the mistake that actually hurts: demanding a version that
  // does not exist yet locks out every player, including you.
  const shipped = shippedVersion();
  if (shipped && compare(args.version, shipped) > 0) {
    console.warn('');
    console.warn(`  WARNING: pubspec.yaml ships ${shipped}, and you are`);
    console.warn(`  demanding ${args.version}.`);
    console.warn('');
    console.warn('  Everyone on the current build will be locked out. Only do');
    console.warn(`  this once ${args.version} is downloadable from the store.`);
    console.warn('');
  }

  const versionField = args.platform === null
      ? 'minimumVersion'
      : `${args.platform}MinimumVersion`;
  const storeUrlField = args.platform === null
      ? 'storeUrl'
      : `${args.platform}StoreUrl`;
  const payload = {[versionField]: args.version};
  if (args.storeUrl) payload[storeUrlField] = args.storeUrl;

  await reference.set(payload, {merge: true});

  const written = (await reference.get()).data();
  console.log(`Wrote ${COLLECTION}/${DOCUMENT}:`);
  console.log(JSON.stringify(written, null, 2));
  console.log('\nTakes effect the next time a player enters the app.');
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
