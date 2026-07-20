"use strict";

const {randomInt, randomBytes} = require("node:crypto");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const {
  CODE_LENGTH,
  CODE_TTL_MS,
  RESEND_COOLDOWN_MS,
  MAX_FAILED_ATTEMPTS,
  UNVERIFIED_ACCOUNT_LIFETIME_MS,
  TOMBSTONE_TTL_MS,
  normalizeEmail,
  emailHash,
  hashCode,
  codesMatch,
} = require("./verification_policy");

initializeApp();
setGlobalOptions({region: "europe-west1", maxInstances: 10});

const db = getFirestore();
const auth = getAuth();

function requireUid(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentication is required.");
  return uid;
}

function asTimestamp(value, fallback) {
  return value instanceof Timestamp ? value : fallback;
}

function verificationEmail({code}) {
  return {
    subject: "Winner Spin email verification code",
    text:
      `Your Winner Spin verification code is ${code}. ` +
      "It expires in 15 minutes. Do not share this code with anyone.",
    html: `
      <div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:24px;color:#2c2530">
        <div style="background:#f6d7eb;border-radius:22px;padding:28px;text-align:center">
          <h1 style="margin:0 0 12px">Verify your email</h1>
          <p style="margin:0 0 20px">Enter this code in Winner Spin:</p>
          <div style="font-size:38px;font-weight:800;letter-spacing:10px;background:#fff;border-radius:14px;padding:18px">
            ${code}
          </div>
          <p style="margin:20px 0 0;font-size:13px">This code expires in 15 minutes. Do not share it.</p>
        </div>
      </div>`,
  };
}

exports.requestEmailVerification = onCall(async (request) => {
  const uid = requireUid(request);
  const user = await auth.getUser(uid);
  const email = normalizeEmail(user.email);
  if (!email) throw new HttpsError("failed-precondition", "The account has no email address.");
  if (user.emailVerified) return {alreadyVerified: true};

  const now = Timestamp.now();
  const code = randomInt(0, 10 ** CODE_LENGTH).toString().padStart(CODE_LENGTH, "0");
  const salt = randomBytes(24).toString("hex");
  const verificationRef = db.collection("emailVerifications").doc(uid);
  const mailRef = db.collection("mail").doc();

  const result = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(verificationRef);
    const current = snapshot.data() ?? {};
    const status = current.status;
    const createdAt = asTimestamp(current.createdAt, now);

    if (status === "locked") {
      return {
        locked: true,
        deleteEligibleAt: asTimestamp(
          current.deleteEligibleAt,
          Timestamp.fromMillis(createdAt.toMillis() + UNVERIFIED_ACCOUNT_LIFETIME_MS),
        ),
      };
    }

    const lastSentAt = current.lastSentAt;
    if (lastSentAt instanceof Timestamp) {
      const retryAtMs = lastSentAt.toMillis() + RESEND_COOLDOWN_MS;
      if (now.toMillis() < retryAtMs) {
        throw new HttpsError(
          "resource-exhausted",
          "A verification code was sent recently.",
          {retryAtMillis: retryAtMs},
        );
      }
    }

    transaction.set(
      verificationRef,
      {
        uid,
        email,
        emailHash: emailHash(email),
        codeHash: hashCode(code, salt),
        codeSalt: salt,
        createdAt,
        lastSentAt: now,
        expiresAt: Timestamp.fromMillis(now.toMillis() + CODE_TTL_MS),
        failedAttempts: Number(current.failedAttempts ?? 0),
        status: "pending",
      },
      {merge: true},
    );
    transaction.set(mailRef, {
      to: [email],
      message: verificationEmail({code}),
      verificationUid: uid,
      createdAt: now,
    });
    return {locked: false};
  });

  if (result.locked) {
    throw new HttpsError(
      "permission-denied",
      "Too many incorrect verification codes were entered.",
      {deleteEligibleAtMillis: result.deleteEligibleAt.toMillis()},
    );
  }

  return {expiresAtMillis: now.toMillis() + CODE_TTL_MS};
});

exports.verifyEmailCode = onCall(async (request) => {
  const uid = requireUid(request);
  const code = String(request.data?.code ?? "").trim();
  if (!/^\d{6}$/.test(code)) {
    throw new HttpsError("invalid-argument", "Enter the 6-digit verification code.");
  }

  const now = Timestamp.now();
  const verificationRef = db.collection("emailVerifications").doc(uid);
  const transactionResult = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(verificationRef);
    if (!snapshot.exists) return {kind: "missing"};

    const current = snapshot.data();
    if (current.status === "verified") return {kind: "verified"};
    if (current.status === "locked") {
      return {
        kind: "locked",
        deleteEligibleAt: current.deleteEligibleAt,
      };
    }

    const expiresAt = current.expiresAt;
    if (!(expiresAt instanceof Timestamp) || now.toMillis() > expiresAt.toMillis()) {
      transaction.update(verificationRef, {status: "expired"});
      return {kind: "expired"};
    }

    const actualHash = hashCode(code, current.codeSalt ?? "");
    if (!codesMatch(current.codeHash, actualHash)) {
      const failedAttempts = Number(current.failedAttempts ?? 0) + 1;
      const locked = failedAttempts >= MAX_FAILED_ATTEMPTS;
      const createdAt = asTimestamp(current.createdAt, now);
      const deleteEligibleAt = Timestamp.fromMillis(
        createdAt.toMillis() + UNVERIFIED_ACCOUNT_LIFETIME_MS,
      );
      transaction.update(verificationRef, {
        failedAttempts,
        status: locked ? "locked" : "pending",
        ...(locked ? {deleteEligibleAt, lockedAt: now} : {}),
      });
      return {
        kind: locked ? "locked" : "invalid",
        attemptsRemaining: Math.max(0, MAX_FAILED_ATTEMPTS - failedAttempts),
        deleteEligibleAt,
      };
    }

    transaction.update(verificationRef, {status: "verifying", verifyingAt: now});
    return {kind: "valid"};
  });

  if (transactionResult.kind === "missing") {
    throw new HttpsError("failed-precondition", "Request a verification code first.");
  }
  if (transactionResult.kind === "expired") {
    throw new HttpsError("deadline-exceeded", "The verification code has expired.");
  }
  if (transactionResult.kind === "invalid") {
    throw new HttpsError("invalid-argument", "The verification code is incorrect.", {
      attemptsRemaining: transactionResult.attemptsRemaining,
    });
  }
  if (transactionResult.kind === "locked") {
    const deleteEligibleAt = asTimestamp(transactionResult.deleteEligibleAt, now);
    if (deleteEligibleAt.toMillis() <= now.toMillis()) {
      await deleteLockedAccount(uid, now);
    }
    throw new HttpsError(
      "permission-denied",
      "Too many incorrect verification codes were entered.",
      {deleteEligibleAtMillis: deleteEligibleAt.toMillis()},
    );
  }
  if (transactionResult.kind === "verified") return {verified: true};

  try {
    await auth.updateUser(uid, {emailVerified: true});
    const batch = db.batch();
    batch.set(
      db.collection("users").doc(uid),
      {emailVerified: true, emailVerifiedAt: now},
      {merge: true},
    );
    batch.set(
      verificationRef,
      {status: "verified", verifiedAt: now, codeHash: null, codeSalt: null},
      {merge: true},
    );
    await batch.commit();
    return {verified: true};
  } catch (error) {
    await verificationRef.set({status: "pending"}, {merge: true});
    logger.error("Email verification finalization failed", {uid, error});
    throw new HttpsError("internal", "Email verification could not be completed.");
  }
});

exports.getDeletedUnverifiedAccountStatus = onCall(async (request) => {
  const email = normalizeEmail(request.data?.email);
  if (!email || email.length > 320) return {deleted: false};

  const ref = db.collection("deletedUnverifiedAccounts").doc(emailHash(email));
  const snapshot = await ref.get();
  if (!snapshot.exists) return {deleted: false};

  const expiresAt = snapshot.data()?.expiresAt;
  if (expiresAt instanceof Timestamp && expiresAt.toMillis() <= Date.now()) {
    await ref.delete();
    return {deleted: false};
  }
  return {deleted: true};
});

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

async function deleteLockedAccount(uid, now = Timestamp.now()) {
  const verificationRef = db.collection("emailVerifications").doc(uid);
  const snapshot = await verificationRef.get();
  if (!snapshot.exists || snapshot.data()?.status !== "locked") return false;

  const data = snapshot.data();
  try {
    const user = await auth.getUser(uid);
    if (user.emailVerified) {
      await verificationRef.set({status: "verified", verifiedAt: now}, {merge: true});
      return false;
    }
    await auth.deleteUser(uid);
  } catch (error) {
    if (error?.code !== "auth/user-not-found") throw error;
  }

  const hashedEmail = data.emailHash || emailHash(data.email ?? "");
  const batch = db.batch();
  batch.delete(db.collection("users").doc(uid));
  batch.delete(verificationRef);
  batch.set(db.collection("deletedUnverifiedAccounts").doc(hashedEmail), {
    deletedAt: now,
    expiresAt: Timestamp.fromMillis(now.toMillis() + TOMBSTONE_TTL_MS),
    reason: "too-many-invalid-verification-codes",
  });
  await batch.commit();
  return true;
}

exports.cleanupLockedUnverifiedAccounts = onSchedule("every 5 minutes", async () => {
  const now = Timestamp.now();
  const snapshots = await db
    .collection("emailVerifications")
    .where("status", "==", "locked")
    .where("deleteEligibleAt", "<=", now)
    .limit(100)
    .get();

  const results = await Promise.allSettled(
    snapshots.docs.map((snapshot) => deleteLockedAccount(snapshot.id, now)),
  );
  const failures = results.filter((result) => result.status === "rejected");
  if (failures.length > 0) {
    logger.error("Some locked accounts could not be deleted", {failures});
  }
});
