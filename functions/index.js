"use strict";

const {createHash} = require("node:crypto");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

initializeApp();
setGlobalOptions({region: "europe-west1", maxInstances: 10});

const db = getFirestore();
const auth = getAuth();
const MAX_REAUTH_AGE_SECONDS = 5 * 60;

function requireUid(request) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return uid;
}

function requireRecentAuthentication(request) {
  const authenticatedAt = Number(request.auth?.token?.auth_time);
  const age = Math.floor(Date.now() / 1000) - authenticatedAt;
  if (!Number.isFinite(authenticatedAt) || age > MAX_REAUTH_AGE_SECONDS) {
    throw new HttpsError(
        "failed-precondition",
        "Recent authentication is required.",
    );
  }
}

function normalizeEmail(value) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function emailHash(email) {
  return createHash("sha256").update(normalizeEmail(email)).digest("hex");
}

exports.deleteAccount = onCall(async (request) => {
  const uid = requireUid(request);
  requireRecentAuthentication(request);
  const email = normalizeEmail(request.auth?.token?.email);
  const userReference = db.collection("users").doc(uid);
  const verificationReference = db.collection("emailVerifications").doc(uid);
  const archiveReference = db.collection("disclaimerAcceptances").doc(uid);
  const deletedAccountReference = email ?
    db.collection("deletedUnverifiedAccounts").doc(emailHash(email)) : null;
  const [
    userSnapshot,
    verificationSnapshot,
    archiveSnapshot,
    deletedAccountSnapshot,
  ] = await Promise.all([
    userReference.get(),
    verificationReference.get(),
    archiveReference.get(),
    deletedAccountReference?.get() ?? Promise.resolve(null),
  ]);
  const batch = db.batch();

  const userData = userSnapshot.data();
  if (hasDisclaimerAcceptance(userData) && email) {
    batch.set(archiveReference, {
      email,
      disclaimerVersion: userData.disclaimerVersion,
      disclaimerAcceptedAt: userData.disclaimerAcceptedAt,
      disclaimerAppVersion: userData.disclaimerAppVersion,
      archivedAt: FieldValue.serverTimestamp(),
    });
  }

  batch.delete(userReference);
  batch.delete(verificationReference);
  if (deletedAccountReference) batch.delete(deletedAccountReference);
  await batch.commit();

  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if (error?.code !== "auth/user-not-found") {
      try {
        await restoreAccountRecords([
          [userReference, userSnapshot],
          [verificationReference, verificationSnapshot],
          [archiveReference, archiveSnapshot],
          [deletedAccountReference, deletedAccountSnapshot],
        ]);
      } catch (restoreError) {
        logger.error("Account deletion rollback failed", {
          uid,
          error,
          restoreError,
        });
      }
      logger.error("Firebase Auth account deletion failed", {uid, error});
      throw new HttpsError("internal", "The account could not be deleted.");
    }
  }

  try {
    await deleteVerificationMail(uid);
  } catch (error) {
    logger.error("Verification mail cleanup failed", {uid, error});
  }

  return {deleted: true};
});

function hasDisclaimerAcceptance(data) {
  return Number.isInteger(data?.disclaimerVersion) &&
    data.disclaimerVersion > 0 &&
    data.disclaimerAcceptedAt != null &&
    typeof data.disclaimerAppVersion === "string" &&
    data.disclaimerAppVersion.length > 0;
}

async function restoreAccountRecords(records) {
  const batch = db.batch();
  for (const [reference, snapshot] of records) {
    if (!reference || !snapshot) continue;
    if (snapshot.exists) {
      batch.set(reference, snapshot.data());
    } else {
      batch.delete(reference);
    }
  }
  await batch.commit();
}

async function deleteVerificationMail(uid) {
  while (true) {
    const snapshot = await db
      .collection("mail")
      .where("verificationUid", "==", uid)
      .limit(400)
      .get();
    if (snapshot.empty) return;

    const batch = db.batch();
    snapshot.docs.forEach((document) => batch.delete(document.ref));
    await batch.commit();
    if (snapshot.size < 400) return;
  }
}
