"use strict";

const fs = require("node:fs");
const path = require("node:path");
const {after, before, beforeEach, describe, test} = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  Timestamp,
  collection,
  deleteField,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require("firebase/firestore");

const projectId = "demo-winner-spin-rules";
const ownerId = "owner-user";
const otherUserId = "other-user";
const ownerEmail = "owner@example.com";
const otherUserEmail = "other@example.com";

let testEnvironment;

function userDocument({uid, email}) {
  return {
    uid,
    username: `${uid}-name`,
    email,
    emailVerified: false,
    profileAvatarId: "pink_bear",
    createdAt: Timestamp.fromMillis(1),
    balance: 10000,
    userBalance: 10000,
    lastWin: 0,
    freeSpinsRemaining: 0,
    freeSpinAccumulatedWin: 0,
    freeSpinsAwardedThisRound: 0,
  };
}

function historyEntries(count) {
  return Array.from({length: count}, (unused, index) => ({
    id: `spin-${index}`,
    playedAt: new Date(Date.UTC(2026, 6, 23, 0, index)).toISOString(),
    newBalance: 10000 - index,
    bet: 10,
    winAmount: 0,
  }));
}

function authenticatedFirestore(
    uid,
    email,
    emailVerified = false,
    {authTime = Math.floor(Date.now() / 1000)} = {},
) {
  const claims = {
    email,
    email_verified: emailVerified,
  };
  if (authTime !== null) claims.auth_time = authTime;
  return testEnvironment.authenticatedContext(uid, claims).firestore();
}

async function seedUsers() {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    await setDoc(
        doc(database, "users", ownerId),
        userDocument({uid: ownerId, email: ownerEmail}),
    );
    await setDoc(
        doc(database, "users", otherUserId),
        userDocument({uid: otherUserId, email: otherUserEmail}),
    );
  });
}

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
          path.resolve(__dirname, "../../firestore.rules"),
          "utf8",
      ),
    },
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await seedUsers();
});

after(async () => {
  await testEnvironment.cleanup();
});

describe("users collection ownership", () => {
  test("allows an authenticated user to read their own document", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);

    await assertSucceeds(getDoc(doc(database, "users", ownerId)));
  });

  test("denies unauthenticated user access", async () => {
    const database = testEnvironment.unauthenticatedContext().firestore();

    await assertFails(getDoc(doc(database, "users", ownerId)));
    await assertFails(setDoc(doc(database, "users", "anonymous"), {
      email: "anonymous@example.com",
    }));
  });

  test("denies reads and writes against another user document", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);
    const otherUserReference = doc(database, "users", otherUserId);

    await assertFails(getDoc(otherUserReference));
    await assertFails(updateDoc(otherUserReference, {userBalance: 50000}));
    await assertFails(deleteDoc(otherUserReference));
  });

  test("denies collection-wide user queries", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);

    await assertFails(getDocs(collection(database, "users")));
  });

  test("allows creation only at the authenticated user document", async () => {
    const uid = "new-user";
    const email = "new-user@example.com";
    const database = authenticatedFirestore(uid, email);

    await assertSucceeds(setDoc(doc(database, "users", uid), {
      ...userDocument({uid, email}),
      createdAt: serverTimestamp(),
    }));
    await assertFails(setDoc(doc(database, "users", "different-user"), {
      ...userDocument({uid: "different-user", email}),
      createdAt: serverTimestamp(),
    }));
  });

  test("denies creation when the profile email differs from the token", async () => {
    const uid = "mismatched-email-user";
    const database = authenticatedFirestore(uid, "token@example.com");

    await assertFails(setDoc(doc(database, "users", uid), {
      ...userDocument({uid, email: "profile@example.com"}),
      createdAt: serverTimestamp(),
    }));
  });

  test("denies creation with forged initial profile data", async () => {
    const uid = "forged-profile-user";
    const email = "forged-profile@example.com";
    const database = authenticatedFirestore(uid, email);
    const reference = doc(database, "users", uid);

    await assertFails(setDoc(reference, {
      ...userDocument({uid: "different-user", email}),
      createdAt: serverTimestamp(),
    }));
    await assertFails(setDoc(reference, {
      ...userDocument({uid, email}),
      emailVerified: true,
      createdAt: serverTimestamp(),
    }));
    await assertFails(setDoc(reference, {
      ...userDocument({uid, email}),
      userBalance: 50000,
      createdAt: serverTimestamp(),
    }));
    await assertFails(setDoc(reference, {
      ...userDocument({uid, email}),
      createdAt: serverTimestamp(),
      unexpectedField: true,
    }));
  });

  test("allows the owner to persist supported gameplay state", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);

    await assertSucceeds(updateDoc(doc(database, "users", ownerId), {
      userBalance: 9875.5,
      lastWin: 25.5,
      freeSpinsRemaining: 8,
      freeSpinAccumulatedWin: 125.75,
      freeSpinsAwardedThisRound: 10,
      pool: {
        totalBetsPlaced: 250,
        totalPaidOut: 225,
        totalSpins: 25,
      },
    }));
  });

  test("allows the owner to mirror a bounded game history", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);

    await assertSucceeds(updateDoc(doc(database, "users", ownerId), {
      gameHistory: historyEntries(10),
    }));
    await assertSucceeds(updateDoc(doc(database, "users", ownerId), {
      gameHistory: [],
    }));
  });

  test("denies a game history longer than ten entries", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);

    await assertFails(updateDoc(doc(database, "users", ownerId), {
      gameHistory: historyEntries(11),
    }));
  });

  test("denies a game history that is not a list", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);

    await assertFails(updateDoc(doc(database, "users", ownerId), {
      gameHistory: {id: "spin-1"},
    }));
  });

  test("denies writing game history to another user document", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);

    await assertFails(updateDoc(doc(database, "users", otherUserId), {
      gameHistory: historyEntries(1),
    }));
  });

  test("denies changes to immutable identity fields", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);
    const ownerReference = doc(database, "users", ownerId);

    await assertFails(updateDoc(ownerReference, {email: "changed@example.com"}));
    await assertFails(updateDoc(ownerReference, {username: "changed-name"}));
    await assertFails(updateDoc(ownerReference, {unexpectedField: true}));
  });

  test("allows a profile update", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);

    await assertSucceeds(updateDoc(doc(database, "users", ownerId), {
      profileAvatarId: "heart",
    }));
  });

  test("records a password reset with the server clock", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);

    await assertSucceeds(updateDoc(doc(database, "users", ownerId), {
      passwordResetRequestedAt: serverTimestamp(),
      passwordResetRequestId: "owner-user-1000",
    }));
  });

  test("denies a password reset stamped by the client", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);

    // A device clock can be set to anything, so a self-stamped time would let
    // the player backdate the record and skip the wait.
    await assertFails(updateDoc(doc(database, "users", ownerId), {
      passwordResetRequestedAt: Timestamp.fromMillis(1000),
      passwordResetRequestId: "owner-user-1000",
    }));
  });

  test("denies a second password reset within the day", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);
    const ownerReference = doc(database, "users", ownerId);

    await assertSucceeds(updateDoc(ownerReference, {
      passwordResetRequestedAt: serverTimestamp(),
      passwordResetRequestId: "owner-user-1000",
    }));
    await assertFails(updateDoc(ownerReference, {
      passwordResetRequestedAt: serverTimestamp(),
      passwordResetRequestId: "owner-user-2000",
    }));
  });

  test("denies clearing the password-reset record", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);
    const ownerReference = doc(database, "users", ownerId);

    await assertSucceeds(updateDoc(ownerReference, {
      passwordResetRequestedAt: serverTimestamp(),
      passwordResetRequestId: "owner-user-1000",
    }));
    // Removing the record would be a way to clear one's own cooldown, which
    // is the whole thing the window is meant to prevent.
    await assertFails(updateDoc(ownerReference, {
      passwordResetRequestedAt: deleteField(),
      passwordResetRequestId: deleteField(),
    }));
  });

  test("records a disclaimer acceptance, once", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);
    const ownerReference = doc(database, "users", ownerId);

    await assertSucceeds(updateDoc(ownerReference, {
      disclaimerVersion: 1,
      disclaimerAcceptedAt: serverTimestamp(),
      disclaimerAppVersion: "1.0.0+1",
    }));
    // A changed app version makes this a definite write even if two emulator
    // server timestamps resolve identically; the disclaimer version must still
    // advance before acceptance evidence can be replaced.
    await assertFails(updateDoc(ownerReference, {
      disclaimerVersion: 1,
      disclaimerAcceptedAt: serverTimestamp(),
      disclaimerAppVersion: "1.0.0+2",
    }));
    // A genuinely newer text may be accepted again.
    await assertSucceeds(updateDoc(ownerReference, {
      disclaimerVersion: 2,
      disclaimerAcceptedAt: serverTimestamp(),
      disclaimerAppVersion: "1.0.0+1",
    }));
  });

  test("denies a backdated disclaimer acceptance", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);

    await assertFails(updateDoc(doc(database, "users", ownerId), {
      disclaimerVersion: 1,
      disclaimerAcceptedAt: Timestamp.fromMillis(1000),
      disclaimerAppVersion: "1.0.0+1",
    }));
  });

  test("allows owner deletion required by the account-deletion flow", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);

    await assertSucceeds(deleteDoc(doc(database, "users", ownerId)));
  });

  test("denies profile deletion with stale, future, or missing auth_time", async () => {
    const now = Math.floor(Date.now() / 1000);
    for (const authTime of [now - 301, now + 30, null]) {
      const database = authenticatedFirestore(
          ownerId,
          ownerEmail,
          false,
          {authTime},
      );
      await assertFails(deleteDoc(doc(database, "users", ownerId)));
    }
  });
});

describe("disclaimer acceptance archive", () => {
  async function acceptedDisclaimer(database) {
    const userReference = doc(database, "users", ownerId);
    await updateDoc(userReference, {
      disclaimerVersion: 1,
      disclaimerAcceptedAt: serverTimestamp(),
      disclaimerAppVersion: "1.0.0+1",
    });
    const snapshot = await getDoc(userReference);
    return snapshot.data();
  }

  function archiveData(profile, overrides = {}) {
    return {
      email: ownerEmail,
      disclaimerVersion: profile.disclaimerVersion,
      disclaimerAcceptedAt: profile.disclaimerAcceptedAt,
      disclaimerAppVersion: profile.disclaimerAppVersion,
      archivedAt: serverTimestamp(),
      ...overrides,
    };
  }

  test("allows only the owner to create a matching server-stamped archive", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);
    const profile = await acceptedDisclaimer(database);
    const archiveReference = doc(database, "disclaimerAcceptances", ownerId);

    await assertSucceeds(setDoc(archiveReference, archiveData(profile)));
  });

  test("requires recent authentication to create the archive", async () => {
    const freshDatabase = authenticatedFirestore(ownerId, ownerEmail);
    const profile = await acceptedDisclaimer(freshDatabase);
    const now = Math.floor(Date.now() / 1000);

    for (const authTime of [now - 301, now + 30, null]) {
      const database = authenticatedFirestore(
          ownerId,
          ownerEmail,
          false,
          {authTime},
      );
      await assertFails(setDoc(
          doc(database, "disclaimerAcceptances", ownerId),
          archiveData(profile),
      ));
    }
  });

  test("denies forged past and future archive timestamps", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);
    const profile = await acceptedDisclaimer(database);
    const archiveReference = doc(database, "disclaimerAcceptances", ownerId);

    await assertFails(setDoc(archiveReference, archiveData(profile, {
      archivedAt: Timestamp.fromMillis(1),
    })));
    await assertFails(setDoc(archiveReference, archiveData(profile, {
      archivedAt: Timestamp.fromDate(new Date("2099-01-01T00:00:00Z")),
    })));
  });

  test("denies another user creating the owner's archive", async () => {
    const ownerDatabase = authenticatedFirestore(ownerId, ownerEmail);
    const profile = await acceptedDisclaimer(ownerDatabase);
    const otherDatabase = authenticatedFirestore(otherUserId, otherUserEmail);

    await assertFails(setDoc(
        doc(otherDatabase, "disclaimerAcceptances", ownerId),
        archiveData(profile, {email: otherUserEmail}),
    ));
  });

  test("denies client-controlled retention fields", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);
    const profile = await acceptedDisclaimer(database);
    const archiveReference = doc(database, "disclaimerAcceptances", ownerId);

    for (const extra of [
      {expiresAt: serverTimestamp()},
      {retentionDays: 1824},
      {legalHold: true},
    ]) {
      await assertFails(setDoc(
          archiveReference,
          archiveData(profile, extra),
      ));
    }
  });

  test("denies reads, updates, deletes, and a second create", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);
    const profile = await acceptedDisclaimer(database);
    const archiveReference = doc(database, "disclaimerAcceptances", ownerId);

    await assertSucceeds(setDoc(archiveReference, archiveData(profile)));

    await assertFails(getDoc(archiveReference));
    await assertFails(updateDoc(archiveReference, {disclaimerVersion: 2}));
    await assertFails(deleteDoc(archiveReference));
    await assertFails(setDoc(archiveReference, archiveData(profile)));
  });
});

describe("email verification claim", () => {
  test("denies verification without a verified authentication token", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);

    await assertFails(updateDoc(doc(database, "users", ownerId), {
      emailVerified: true,
    }));
  });

  test("allows a verified token to synchronize verification", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail, true);

    await assertSucceeds(updateDoc(doc(database, "users", ownerId), {
      emailVerified: true,
    }));
  });

  test("denies reverting verification to false", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), "users", ownerId), {
        emailVerified: true,
      });
    });
    const database = authenticatedFirestore(ownerId, ownerEmail, true);

    await assertFails(updateDoc(doc(database, "users", ownerId), {
      emailVerified: false,
    }));
  });
});

describe("forced-update config", () => {
  test("is readable while signed out, so the gate works before login", async () => {
    const database = testEnvironment.unauthenticatedContext().firestore();

    await assertSucceeds(getDoc(doc(database, "config", "appVersion")));
  });

  test("is readable by a signed-in user", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);

    await assertSucceeds(getDoc(doc(database, "config", "appVersion")));
  });

  test("cannot be raised by a client, which would lock everyone out", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);
    const reference = doc(database, "config", "appVersion");

    await assertFails(setDoc(reference, {minimumVersion: "99.0.0"}));
    await assertFails(updateDoc(reference, {minimumVersion: "99.0.0"}));
    await assertFails(deleteDoc(reference));
  });

  test("cannot be written by an anonymous client either", async () => {
    const database = testEnvironment.unauthenticatedContext().firestore();

    await assertFails(setDoc(doc(database, "config", "appVersion"), {
      minimumVersion: "99.0.0",
    }));
  });
});

describe("server-owned collections", () => {
  for (const collectionName of [
    "deletedUnverifiedAccounts",
    "mail",
  ]) {
    test(`denies client access to ${collectionName}`, async () => {
      const database = authenticatedFirestore(ownerId, ownerEmail);
      const reference = doc(database, collectionName, ownerId);

      await assertFails(getDoc(reference));
      await assertFails(setDoc(reference, {ownerId}));
      await assertFails(deleteDoc(reference));
    });
  }

  test("keeps email verification data opaque but lets its owner delete it", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);
    const reference = doc(database, "emailVerifications", ownerId);

    await assertFails(getDoc(reference));
    await assertFails(setDoc(reference, {ownerId}));
    await assertSucceeds(deleteDoc(reference));
  });

  test("requires recent authentication to delete email verification data", async () => {
    const now = Math.floor(Date.now() / 1000);
    for (const authTime of [now - 301, now + 30, null]) {
      const database = authenticatedFirestore(
          ownerId,
          ownerEmail,
          false,
          {authTime},
      );
      await assertFails(deleteDoc(
          doc(database, "emailVerifications", ownerId),
      ));
    }
  });

  test("denies access to collections without an explicit rule", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);
    const reference = doc(database, "internal", "configuration");

    await assertFails(getDoc(reference));
    await assertFails(setDoc(reference, {enabled: true}));
  });
});
