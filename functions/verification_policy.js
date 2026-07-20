"use strict";

const {createHash, timingSafeEqual} = require("node:crypto");

const CODE_LENGTH = 6;
const CODE_TTL_MS = 15 * 60 * 1000;
const RESEND_COOLDOWN_MS = 60 * 1000;
const MAX_FAILED_ATTEMPTS = 5;
const UNVERIFIED_ACCOUNT_LIFETIME_MS = 60 * 60 * 1000;
const TOMBSTONE_TTL_MS = 30 * 24 * 60 * 60 * 1000;

function normalizeEmail(value) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function emailHash(email) {
  return createHash("sha256").update(normalizeEmail(email)).digest("hex");
}

function hashCode(code, salt) {
  return createHash("sha256").update(`${salt}:${code}`).digest("hex");
}

function codesMatch(expectedHash, actualHash) {
  const expected = Buffer.from(expectedHash ?? "", "hex");
  const actual = Buffer.from(actualHash, "hex");
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

module.exports = {
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
};
