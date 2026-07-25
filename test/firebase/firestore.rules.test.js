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

function authenticatedFirestore(uid, email, emailVerified = false) {
  return testEnvironment.authenticatedContext(uid, {
    email,
    email_verified: emailVerified,
  }).firestore();
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

  test("denies changes to immutable identity fields", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);
    const ownerReference = doc(database, "users", ownerId);

    await assertFails(updateDoc(ownerReference, {email: "changed@example.com"}));
    await assertFails(updateDoc(ownerReference, {username: "changed-name"}));
    await assertFails(updateDoc(ownerReference, {unexpectedField: true}));
  });

  test("allows supported profile and password-reset metadata updates", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);
    const ownerReference = doc(database, "users", ownerId);

    await assertSucceeds(updateDoc(ownerReference, {
      profileAvatarId: "heart",
      passwordResetRequestedAt: Timestamp.fromMillis(1000),
      passwordResetRequestId: "owner-user-1000",
    }));
    await assertSucceeds(updateDoc(ownerReference, {
      passwordResetRequestedAt: deleteField(),
      passwordResetRequestId: deleteField(),
    }));
  });

  test("denies client-side deletion of the owner document", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);

    await assertFails(deleteDoc(doc(database, "users", ownerId)));
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

describe("server-owned collections", () => {
  for (const collectionName of [
    "emailVerifications",
    "deletedUnverifiedAccounts",
    "mail",
  ]) {
    test(`denies client access to ${collectionName}`, async () => {
      const database = authenticatedFirestore(ownerId, ownerEmail);
      const reference = doc(database, collectionName, ownerId);

      await assertFails(getDoc(reference));
      await assertFails(setDoc(reference, {ownerId}));
    });
  }

  test("denies access to collections without an explicit rule", async () => {
    const database = authenticatedFirestore(ownerId, ownerEmail);
    const reference = doc(database, "internal", "configuration");

    await assertFails(getDoc(reference));
    await assertFails(setDoc(reference, {enabled: true}));
  });
});
