import test from "node:test";
import assert from "node:assert/strict";
import { webcrypto } from "node:crypto";
import worker, { PhysicalBookOrderCoordinator } from "./lulu-quote-worker.mjs";
if (!globalThis.crypto) globalThis.crypto = webcrypto;

const purchase = {
  cadence: "annual", contactEmail: "reader@example.com", acceptsLuluFulfillment: true,
  shippingAddress: { name: "Reader", street1: "1 Private Street", city: "Belfast", stateCode: "ME", countryCode: "US", postalCode: "04915", phoneNumber: "207-555-0100" },
};

async function fixture(t) {
  const kv = new Map(), storage = new Map(), objects = new Map(), subscriptions = new Map(), stripeReplies = new Map();
  const posts = [], customers = [];
  let failKV = "", loseResponse = "", failReceipt = "", paymentWinsVoid = false;
  const env = {
    CHECKOUT_MODE: "test", PHYSICAL_BOOK_ORDERING_ENABLED: "true",
    STRIPE_SECRET_KEY: "sk_test_mock", STRIPE_BOUND_YEAR_MONTHLY_PRICE: "price_month", STRIPE_BOUND_YEAR_ANNUAL_PRICE: "price_year",
    LULU_API_BASE_URL: "https://api.sandbox.lulu.com", LULU_AUTH_URL: "https://api.sandbox.lulu.com/auth/realms/glasstree/protocol/openid-connect/token", LULU_CLIENT_KEY: "mock", LULU_CLIENT_SECRET: "mock",
    PHYSICAL_BOOK_RATE_LIMITER: { async limit() { return { success: true }; } },
    PHYSICAL_BOOK_ORDERS: {
      async get(key) { return kv.get(key) ?? null; },
      async put(key, value) {
        if (failKV && key.startsWith(failKV)) { failKV = ""; throw new Error("KV unavailable"); }
        kv.set(key, value);
      },
      async delete(key) { kv.delete(key); },
    },
  };
  env.PHYSICAL_BOOK_ORDER_COORDINATOR = {
    idFromName: id => id,
    get(id) {
      if (!storage.has(id)) storage.set(id, new Map());
      if (!objects.has(id)) objects.set(id, new PhysicalBookOrderCoordinator({ storage: {
        async get(key) { return storage.get(id).get(key); },
        async put(key, value) {
          if (key === failReceipt && (value.id || key === "gift-claim-decision")) { failReceipt = ""; throw new Error("Receipt write interrupted"); }
          storage.get(id).set(key, value);
        },
      } }, env));
      return { fetch: (url, init) => objects.get(id).fetch(new Request(url, init)) };
    },
  };
  const originalFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = originalFetch; });
  globalThis.fetch = async (url, init = {}) => {
    const path = new URL(url).pathname.replace("/v1/", "");
    if (init.method !== "POST") {
      if (path.startsWith("subscriptions/")) return Response.json(subscriptions.get(path.split("/")[1]));
      if (path.startsWith("customers/")) return Response.json({ id: path.split("/")[1] });
      throw new Error(`Unexpected GET ${path}`);
    }
    const key = init.headers["Idempotency-Key"];
    assert.ok(key, "every checkout Stripe mutation carries a stable key");
    posts.push({ path, key, body: init.body });
    let result = stripeReplies.get(key);
    if (!result) {
      if (path === "customers") {
        result = { id: `cus_${customers.length + 1}` };
        customers.push(result);
      } else if (path === "subscriptions") {
        const fields = new URLSearchParams(init.body);
        result = {
          id: `sub_${subscriptions.size + 1}`, customer: fields.get("customer"), status: "incomplete", livemode: false,
          current_period_end: Math.floor(Date.now() / 1000) + 365 * 86400,
          items: { data: [{ price: { id: fields.get("items[0][price]") } }] },
          metadata: { reenchanted_cadence: fields.get("metadata[reenchanted_cadence]"), reenchanted_physical_fulfillment: "accepted" },
          latest_invoice: { id: `in_${subscriptions.size + 1}`, subscription: `sub_${subscriptions.size + 1}`,
            status: "open", paid: false, amount_paid: 0, payment_intent: { client_secret: "pi_test_secret", status: "requires_payment_method" } },
        };
        subscriptions.set(result.id, result);
      } else if (path.startsWith("invoices/") && path.endsWith("/void")) {
        const sub = [...subscriptions.values()].find(sub => sub.latest_invoice.id === path.split("/")[1]);
        if (paymentWinsVoid) {
          paymentWinsVoid = false;
          pay(sub.id);
          return new Response("Invoice is already paid", { status: 400 });
        }
        assert.equal(sub.status, "incomplete");
        sub.status = "incomplete_expired";
        sub.latest_invoice.status = "void";
        sub.latest_invoice.payment_intent.status = "canceled";
        result = sub.latest_invoice;
      } else throw new Error(`Unexpected POST ${path}`);
      stripeReplies.set(key, result);
    }
    if (loseResponse === path) { loseResponse = ""; throw new Error("Response lost after Stripe accepted"); }
    return Response.json(result);
  };
  const installation = "checkout-test-installation";
  const sessionResponse = await worker.fetch(new Request("https://example.test/sessions", {
    method: "POST", headers: { "X-Installation-ID": installation, "CF-Connecting-IP": "203.0.113.1" },
  }), env);
  const token = (await sessionResponse.json()).token;
  const tokens = new Map([[installation, token]]);
  async function send(path, body, attemptID = crypto.randomUUID(), method = "POST", reader = installation) {
    if (!tokens.has(reader)) {
      const opened = await worker.fetch(new Request("https://example.test/sessions", {
        method: "POST", headers: { "X-Installation-ID": reader, "CF-Connecting-IP": "203.0.113.1" },
      }), env);
      tokens.set(reader, (await opened.json()).token);
    }
    const response = await worker.fetch(new Request(`https://example.test${path}`, {
      method, headers: { Authorization: `Bearer ${tokens.get(reader)}`, "X-Installation-ID": reader, "CF-Connecting-IP": "203.0.113.1", "X-Purchase-Attempt-ID": attemptID, "Content-Type": "application/json" },
      ...(body ? { body: JSON.stringify(body) } : {}),
    }), env);
    return { status: response.status, body: await response.json() };
  }
  function pay(id) {
    const sub = subscriptions.get(id);
    sub.status = "active";
    sub.latest_invoice = { id: sub.latest_invoice.id, subscription: id, paid: true, status: "paid", amount_paid: 100,
      payment_intent: { client_secret: "pi_test_secret", status: "succeeded", latest_charge: { paid: true, amount: 100, amount_refunded: 0, refunded: false, disputed: false } } };
  }
  return { send, pay, kv, storage, posts, customers, subscriptions, restart: () => objects.clear(),
    failKV: prefix => { failKV = prefix; }, loseResponse: path => { loseResponse = path; }, failReceipt: key => { failReceipt = key; },
    paymentWinsVoid: () => { paymentWinsVoid = true; } };
}

test("concurrent and restarted membership checkout creates one customer and subscription", async t => {
  const f = await fixture(t), id = crypto.randomUUID();
  const results = await Promise.all([f.send("/memberships", purchase, id), f.send("/memberships", purchase, id)]);
  assert.deepEqual(results.map(result => result.status), [201, 201]);
  assert.equal(f.customers.length, 1); assert.equal(f.subscriptions.size, 1);
  f.pay(results[0].body.membershipID); f.restart();
  for (const records of f.storage.values()) {
    records.get("checkout-stripe/customers").startedAt -= 48 * 3600 * 1000;
    records.get("checkout-stripe/subscriptions").startedAt -= 48 * 3600 * 1000;
  }
  const resumed = await f.send("/memberships", purchase, id);
  assert.equal(resumed.body.paymentVerified, true);
  assert.equal(resumed.body.membershipID, results[0].body.membershipID);
  assert.equal(f.posts.length, 2);
  assert.equal((await f.send("/memberships", { ...purchase, contactEmail: "changed@example.com" }, id)).body.error, "checkout_attempt_changed");
  assert.equal(f.posts.length, 2);
  assert.ok(!JSON.stringify([...f.storage.values()].map(value => [...value])).includes("Private Street"));
});

for (const path of ["customers", "subscriptions"]) test(`lost ${path} response reuses Stripe's idempotency key`, async t => {
  const f = await fixture(t), id = crypto.randomUUID();
  f.loseResponse(path);
  assert.equal((await f.send("/memberships", purchase, id)).status, 500);
  f.restart();
  assert.equal((await f.send("/memberships", purchase, id)).status, 201);
  const attempts = f.posts.filter(post => post.path === path);
  assert.equal(attempts.length, 2); assert.equal(attempts[0].key, attempts[1].key);
  assert.equal(f.customers.length, 1); assert.equal(f.subscriptions.size, 1);
});

test("missing durable Stripe receipt and failed ownership writes resume without another subscription", async t => {
  const f = await fixture(t), id = crypto.randomUUID();
  f.failReceipt("checkout-stripe/subscriptions");
  assert.equal((await f.send("/memberships", purchase, id)).status, 500);
  f.restart(); f.failKV("monthly-issues/membership-owner/");
  assert.equal((await f.send("/memberships", purchase, id)).status, 500);
  f.restart();
  assert.equal((await f.send("/memberships", purchase, id)).status, 201);
  assert.equal(f.subscriptions.size, 1); assert.equal(f.customers.length, 1);
});

test("an unresolved old attempt never reuses an expired Stripe key", async t => {
  const f = await fixture(t), id = crypto.randomUUID();
  f.loseResponse("subscriptions");
  await f.send("/memberships", purchase, id);
  for (const records of f.storage.values()) records.get("checkout-stripe/subscriptions").startedAt -= 24 * 3600 * 1000;
  f.restart(); const before = f.posts.length;
  assert.equal((await f.send("/memberships", purchase, id)).body.error, "checkout_recovery_required");
  assert.equal(f.posts.length, before);
});

test("gift index failure repairs the same gift and refunded gifts cannot be claimed", async t => {
  const f = await fixture(t), id = crypto.randomUUID();
  const giftPurchase = { ...purchase, senderName: "Sender", recipientName: "Recipient", message: "For your shelf." };
  f.failKV("book-gifts/membership/");
  assert.equal((await f.send("/gifts/bound-year", giftPurchase, id)).status, 500);
  const originalGift = [...f.kv.entries()].find(([key]) => key.startsWith("book-gifts/claim/"))[1];
  f.restart();
  const result = await f.send("/gifts/bound-year", giftPurchase, id);
  assert.equal(result.status, 201); assert.equal(result.body.gift.gift.id, JSON.parse(originalGift).id);
  assert.equal(f.subscriptions.size, 1);
  const path = `/gifts/${result.body.gift.claimToken}`;
  assert.equal((await f.send(path + "/claim")).status, 402);
  f.pay(result.body.membership.membershipID);
  assert.equal((await f.send(path, null, undefined, "GET")).body.status, "readyToClaim");
  f.subscriptions.get(result.body.membership.membershipID).latest_invoice.payment_intent.latest_charge.refunded = true;
  assert.equal((await f.send(path, null, undefined, "GET")).body.status, "paymentPending");
  assert.equal((await f.send(path + "/claim")).status, 402);
  assert.ok(![...f.kv.keys()].some(key => key.startsWith("monthly-issues/membership-owner/")));
});

test("gift claims require a settled payment for the correct subscription and price", async t => {
  const f = await fixture(t);
  const result = await f.send("/gifts/bound-year", { ...purchase, senderName: "Sender", recipientName: "Recipient" });
  const id = result.body.membership.membershipID;
  const path = `/gifts/${result.body.gift.claimToken}/claim`;
  for (const change of [
    sub => { sub.status = "trialing"; },
    sub => { sub.latest_invoice.amount_paid = 0; },
    sub => { sub.latest_invoice.payment_intent.latest_charge.disputed = true; },
    sub => { sub.latest_invoice.payment_intent.status = "processing"; },
    sub => { sub.latest_invoice.subscription = "sub_foreign"; },
    sub => { sub.items.data[0].price.id = "price_other"; },
  ]) {
    f.pay(id); f.subscriptions.get(id).items.data[0].price.id = "price_year";
    change(f.subscriptions.get(id));
    assert.equal((await f.send(path)).status, 402);
  }
  f.pay(id); f.subscriptions.get(id).items.data[0].price.id = "price_year";
  const claimed = await f.send(path);
  assert.equal(claimed.status, 200);
  assert.equal(claimed.body.membershipID, id);
});

test("concurrent changed details cannot receive the original checkout response", async t => {
  const f = await fixture(t), id = crypto.randomUUID();
  const results = await Promise.all([
    f.send("/memberships", purchase, id),
    f.send("/memberships", { ...purchase, contactEmail: "another@example.com" }, id),
  ]);
  assert.equal(results.filter(result => result.status === 201).length, 1);
  assert.equal(results.filter(result => result.body.error === "checkout_attempt_changed").length, 1);
  assert.equal(f.customers.length, 1); assert.equal(f.subscriptions.size, 1);
});

test("invalid purchase fields and missing attempts never reach Stripe", async t => {
  const f = await fixture(t);
  assert.equal((await f.send("/memberships", purchase, "invalid")).status, 400);
  assert.equal((await f.send("/memberships", { ...purchase, acceptsLuluFulfillment: false })).body.error, "fulfillment_consent_required");
  assert.equal((await f.send("/gifts/bound-year", { ...purchase, senderName: "", recipientName: "Reader" })).status, 400);
  assert.equal(f.posts.length, 0);
});

async function paidGift(f) {
  const result = await f.send("/gifts/bound-year", { ...purchase, senderName: "Sender", recipientName: "Recipient" });
  f.pay(result.body.membership.membershipID);
  return `/gifts/${result.body.gift.claimToken}`;
}

test("two installations racing for one gift produce exactly one durable owner", async t => {
  const f = await fixture(t), path = await paidGift(f);
  const results = await Promise.all([
    f.send(path + "/claim"),
    f.send(path + "/claim", null, undefined, "POST", "another-gift-reader"),
  ]);
  assert.deepEqual(results.map(result => result.status).sort(), [200, 409]);
  const loser = results[0].status === 200 ? "another-gift-reader" : "checkout-test-installation";
  f.restart();
  assert.equal((await f.send(path + "/claim", null, undefined, "POST", loser)).body.error, "gift_already_claimed");
  assert.equal((await f.send(path + "/decline")).body.error, "gift_already_claimed");
});

test("claim reservation survives failed KV publication and stale reads after restart", async t => {
  const f = await fixture(t), path = await paidGift(f);
  f.failKV("book-gifts/claim/");
  assert.equal((await f.send(path + "/claim")).status, 500);
  f.restart();
  assert.equal((await f.send(path + "/claim", null, undefined, "POST", "another-gift-reader")).status, 409);
  assert.equal((await f.send(path + "/decline")).status, 409);
  assert.equal((await f.send(path + "/claim")).status, 200);
});

test("gift decisions require durable storage before publishing a claim", async t => {
  const f = await fixture(t), path = await paidGift(f);
  f.failReceipt("gift-claim-decision");
  assert.equal((await f.send(path + "/claim")).status, 500);
  const gift = JSON.parse([...f.kv.entries()].find(([key]) => key.startsWith("book-gifts/claim/"))[1]);
  assert.equal(gift.claimedInstallationHash, undefined);
  assert.ok(![...f.kv.keys()].some(key => key.startsWith("monthly-issues/membership-owner/")));
  assert.equal((await f.send(path + "/claim")).status, 200);
});

test("decline and claim cannot both win, including a restarted decline publication failure", async t => {
  const f = await fixture(t), path = await paidGift(f);
  f.failKV("book-gifts/claim/");
  assert.equal((await f.send(path + "/decline")).status, 500);
  f.restart();
  assert.equal((await f.send(path + "/claim")).status, 410);
  assert.equal((await f.send(path + "/decline")).body.status, "declined");
  const other = await paidGift(f);
  const race = await Promise.all([f.send(other + "/decline"), f.send(other + "/claim")]);
  assert.equal(race.filter(result => result.status === 200).length, 1);
});

test("checking gift readiness never overwrites the stored lifecycle", async t => {
  const f = await fixture(t), path = await paidGift(f);
  const [key, before] = [...f.kv.entries()].find(([key]) => key.startsWith("book-gifts/claim/"));
  assert.equal((await f.send(path, null, undefined, "GET")).body.status, "readyToClaim");
  assert.equal(f.kv.get(key), before);
});

for (const endpoint of ["/memberships", "/gifts/bound-year"]) test(`${endpoint} unpaid checkout closes without leaving a chargeable invoice`, async t => {
  const f = await fixture(t), id = crypto.randomUUID();
  const body = { ...purchase, senderName: "Sender", recipientName: "Reader" };
  const opened = await f.send(endpoint, body, id);
  const membershipID = opened.body.membershipID || opened.body.membership.membershipID;
  const canceled = await f.send(endpoint + "/checkout/cancel", null, id);
  assert.equal(canceled.body.canceled, true);
  assert.equal(f.subscriptions.get(membershipID).status, "incomplete_expired");
  f.restart();
  assert.equal((await f.send(endpoint + "/checkout/cancel", null, id)).body.canceled, true);
  assert.equal((await f.send(endpoint, body, id)).body.error, "checkout_closed");
  assert.equal(f.posts.filter(post => post.path.endsWith("/void")).length, 1);
});

test("payment that wins the cancellation race remains recoverable and is never voided", async t => {
  const f = await fixture(t), id = crypto.randomUUID();
  const opened = await f.send("/memberships", purchase, id);
  f.paymentWinsVoid();
  assert.equal((await f.send("/memberships/checkout/cancel", null, id)).status, 502);
  f.restart();
  assert.equal((await f.send("/memberships", purchase, id)).body.paymentVerified, true);
  assert.equal((await f.send("/memberships/checkout/cancel", null, id)).body.error, "checkout_payment_not_cancelable");
  assert.equal(f.subscriptions.get(opened.body.membershipID).status, "active");
});

test("lost void response recovers from Stripe terminal status after restart", async t => {
  const f = await fixture(t), id = crypto.randomUUID();
  const opened = await f.send("/memberships", purchase, id);
  const invoiceID = f.subscriptions.get(opened.body.membershipID).latest_invoice.id;
  f.loseResponse(`invoices/${invoiceID}/void`);
  assert.equal((await f.send("/memberships/checkout/cancel", null, id)).status, 500);
  f.restart();
  assert.equal((await f.send("/memberships/checkout/cancel", null, id)).body.canceled, true);
  assert.equal(f.posts.filter(post => post.path.endsWith("/void")).length, 1);
});

test("unknown or processing subscription cannot be discarded as unpaid", async t => {
  const f = await fixture(t), id = crypto.randomUUID();
  f.loseResponse("subscriptions");
  await f.send("/memberships", purchase, id);
  assert.equal((await f.send("/memberships/checkout/cancel", null, id)).body.error, "checkout_recovery_required");
  const recovered = await f.send("/memberships", purchase, id);
  f.subscriptions.get(recovered.body.membershipID).latest_invoice.payment_intent.status = "processing";
  assert.equal((await f.send("/memberships/checkout/cancel", null, id)).body.error, "checkout_payment_not_cancelable");
  assert.equal(f.posts.filter(post => post.path.endsWith("/void")).length, 0);
});

test("cancel before opening prevents a delayed request from creating a subscription", async t => {
  const f = await fixture(t), id = crypto.randomUUID();
  assert.equal((await f.send("/memberships/checkout/cancel", null, id)).body.canceled, true);
  assert.equal((await f.send("/memberships", purchase, id)).body.error, "checkout_closed");
  assert.equal(f.posts.length, 0);
});
