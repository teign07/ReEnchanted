import test from "node:test";
import assert from "node:assert/strict";
import { webcrypto } from "node:crypto";
import {
  activeChoicePoll,
  automaticModeration,
  decryptJSON,
  encryptJSON,
  isXImportEnabled,
  normalizePublicText,
  oauth1Authorization,
  publicChoicePolls,
  rotateByDay,
  validateContribution
} from "./public-margins-worker.mjs";
import worker from "./public-margins-worker.mjs";

test("public consent is mandatory", () => {
  assert.throws(() => validateContribution({
    requestID: "request-1",
    eventID: "daily-souvenir",
    kind: "souvenir",
    text: "A sentence.",
    confirmedAt: new Date().toISOString(),
    consent: { publicDisplay: false, moderation: true }
  }), /explicit_public_consent_required/);
});

test("validation keeps only the public contract", () => {
  const validated = validateContribution({
    requestID: "request-1",
    eventID: "daily-souvenir",
    kind: "souvenir",
    text: "  A small light\nunder the door. ",
    confirmedAt: new Date().toISOString(),
    consent: { publicDisplay: true, moderation: true },
    userID: "must-not-pass",
    pageID: "must-not-pass",
    archive: ["must-not-pass"]
  });
  assert.deepEqual(Object.keys(validated).sort(), [
    "category", "choiceID", "confirmedAt", "eventID", "kind", "requestID", "text"
  ]);
  assert.equal(validated.text, "A small light under the door.");
});

test("links and overlong text are rejected", () => {
  assert.throws(() => normalizePublicText("See https://example.com"), /links_not_allowed/);
  assert.throws(() => normalizePublicText("x".repeat(221)), /invalid_text_length/);
});

test("quiet choices must belong to the controlled poll shelf", () => {
  const poll = publicChoicePolls[0];
  const choice = poll.options[0];
  const validated = validateContribution({
    requestID: "choice-request-1",
    eventID: poll.id,
    kind: "choice",
    choiceID: choice.id,
    confirmedAt: new Date().toISOString(),
    consent: { publicDisplay: true, moderation: true }
  });
  assert.equal(validated.category, "quiet-choice");
  assert.equal(validated.choiceID, choice.id);
  assert.throws(() => validateContribution({
    requestID: "choice-request-2",
    eventID: poll.id,
    kind: "choice",
    choiceID: "invented-answer",
    confirmedAt: new Date().toISOString(),
    consent: { publicDisplay: true, moderation: true }
  }), /unknown_choice/);
});

test("daily quiet choice rotation is deterministic", () => {
  assert.deepEqual(activeChoicePoll("2026-07-19"), activeChoicePoll("2026-07-19"));
  assert.equal(activeChoicePoll("2026-07-19").options.length, 5);
});

test("controlled choices auto-approve without AI", async () => {
  const poll = publicChoicePolls[0];
  const result = await automaticModeration({
    kind: "choice",
    eventID: poll.id,
    choiceID: poll.options[0].id
  }, {});
  assert.equal(result.status, "approved");
});

test("sentences auto-approve only after a safe model verdict", async () => {
  const safe = await automaticModeration({ kind: "souvenir", text: "Rain made the pavement shine." }, {
    AI: { run: async () => ({ response: "safe" }) }
  });
  assert.equal(safe.status, "approved");

  const unsafe = await automaticModeration({ kind: "souvenir", text: "A sentence the model rejects." }, {
    AI: { run: async () => ({ response: "unsafe\nS1" }) }
  });
  assert.equal(unsafe.status, "rejected");
});

test("sentence moderation rejects contact details and fails closed", async () => {
  const contact = await automaticModeration({ kind: "souvenir", text: "Write me at reader@example.com." }, {
    AI: { run: async () => ({ response: "safe" }) }
  });
  assert.equal(contact.status, "rejected");
  assert.equal(contact.reason, "private_contact_detail");

  const unavailable = await automaticModeration({ kind: "souvenir", text: "A harmless line." }, {});
  assert.equal(unavailable.status, "rejected");
  assert.equal(unavailable.reason, "moderation_unavailable");
});

test("public text is encrypted with AES-GCM at rest", async () => {
  const key = Buffer.alloc(32, 7).toString("base64");
  const encrypted = await encryptJSON({ text: "A private-until-approved sentence." }, key, webcrypto);
  assert.doesNotMatch(encrypted.ciphertext, /private-until-approved/);
  assert.deepEqual(await decryptJSON(encrypted.ciphertext, encrypted.iv, key, webcrypto), {
    text: "A private-until-approved sentence."
  });
});

test("souvenir rotation is stable within a day", () => {
  const items = Array.from({ length: 12 }, (_, index) => ({ id: `item-${index}` }));
  assert.deepEqual(rotateByDay(items, "2026-07-18"), rotateByDay(items, "2026-07-18"));
  assert.equal(rotateByDay(items, "2026-07-18").length, 6);
});

test("X import is dormant unless deliberately enabled", () => {
  assert.equal(isXImportEnabled({}), false);
  assert.equal(isXImportEnabled({ X_IMPORT_ENABLED: "false" }), false);
  assert.equal(isXImportEnabled({ X_IMPORT_ENABLED: "true" }), true);
});

test("disabled X refresh returns without credentials or a network call", async () => {
  const response = await worker.fetch(new Request("https://community.example/v1/admin/refresh-x", {
    method: "POST",
    headers: { authorization: "Bearer admin-test-token" }
  }), {
    PUBLIC_MARGINS_ADMIN_TOKEN: "admin-test-token",
    X_IMPORT_ENABLED: "false"
  });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { enabled: false, refreshed: 0, creators: [] });
});

test("public writes fail closed without the abuse limiter", async () => {
  const request = new Request("https://community.example/v1/contributions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-installation-id": "test-installation-0001"
    },
    body: JSON.stringify({})
  });
  const response = await worker.fetch(request, {});
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: "server_error" });
});

test("public writes return 429 when the abuse limiter closes", async () => {
  const request = new Request("https://community.example/v1/contributions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-installation-id": "test-installation-0001"
    },
    body: JSON.stringify({})
  });
  const response = await worker.fetch(request, {
    PUBLIC_MARGINS_WRITE_LIMITER: { limit: async () => ({ success: false }) }
  });
  assert.equal(response.status, 429);
  assert.deepEqual(await response.json(), { error: "too_many_requests" });
});

test("X requests use the OAuth 1.0 HMAC-SHA1 signature from RFC 5849", async () => {
  const header = await oauth1Authorization(
    "GET",
    "http://photos.example.net/photos?file=vacation.jpg&size=original",
    {
      consumerKey: "dpf43f3p2l4k3l03",
      consumerSecret: "kd94hf93k423kf44",
      accessToken: "nnch734d00sl2jdk",
      accessTokenSecret: "pfkkdhi9sl3r4s00"
    },
    { nonce: "kllo9940pd9333jh", timestamp: 1191242096, cryptoObject: webcrypto }
  );
  assert.match(header, /oauth_signature="tR3%2BTy81lMeYAr%2FFid0kMTYa%2FWM%3D"/);
});
