"use strict";

const {createHash} = require("node:crypto");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

initializeApp();
setGlobalOptions({region: "europe-west1", maxInstances: 10});

const db = getFirestore();
const auth = getAuth();

function requireUid(request) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return uid;
}

function normalizeEmail(value) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function emailHash(email) {
  return createHash("sha256").update(normalizeEmail(email)).digest("hex");
}

exports.deleteAccount = onCall(async (request) => {
  const uid = requireUid(request);
  const email = normalizeEmail(request.auth?.token?.email);
  await deleteVerificationMail(uid);
  const batch = db.batch();

  batch.delete(db.collection("users").doc(uid));
  batch.delete(db.collection("emailVerifications").doc(uid));
  if (email) {
    batch.delete(db.collection("deletedUnverifiedAccounts").doc(emailHash(email)));
  }
  await batch.commit();

  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if (error?.code !== "auth/user-not-found") {
      logger.error("Firebase Auth account deletion failed", {uid, error});
      throw new HttpsError("internal", "The account could not be deleted.");
    }
  }

  return {deleted: true};
});

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
