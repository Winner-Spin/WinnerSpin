"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  CODE_LENGTH,
  CODE_TTL_MS,
  MAX_FAILED_ATTEMPTS,
  UNVERIFIED_ACCOUNT_LIFETIME_MS,
  normalizeEmail,
  emailHash,
  hashCode,
  codesMatch,
} = require("./verification_policy");

test("normalizes email addresses before creating deletion tombstones", () => {
  assert.equal(normalizeEmail(" Player@Example.COM "), "player@example.com");
  assert.equal(emailHash("Player@Example.com"), emailHash(" player@example.COM "));
});

test("stores and compares only salted verification-code hashes", () => {
  const storedHash = hashCode("123456", "unique-salt");

  assert.equal(codesMatch(storedHash, hashCode("123456", "unique-salt")), true);
  assert.equal(codesMatch(storedHash, hashCode("654321", "unique-salt")), false);
  assert.equal(storedHash.includes("123456"), false);
});

test("keeps the required verification limits fixed", () => {
  assert.equal(CODE_LENGTH, 6);
  assert.equal(CODE_TTL_MS, 15 * 60 * 1000);
  assert.equal(MAX_FAILED_ATTEMPTS, 5);
  assert.equal(UNVERIFIED_ACCOUNT_LIFETIME_MS, 60 * 60 * 1000);
});
