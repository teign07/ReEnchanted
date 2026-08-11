// The Bound Year membership endpoints.
//
// Subscribing is a physical-goods purchase, so it belongs outside in-app
// purchase — the same rule that already sends the one-off books through Stripe.
// Cancelling is not a purchase at all, so it needs nobody's permission and must
// work even when the shop is shut.
//
//   node test-memberships.mjs

import { webcrypto } from "node:crypto";
import worker from "./lulu-quote-worker.mjs";

if (!globalThis.crypto) globalThis.crypto = webcrypto;

const apiToken = "test-api-token";
const installationID = "test-installation-0001";
const networkID = "203.0.113.10";

function makeEnv(overrides = {}) {
  return {
    PHYSICAL_BOOK_API_TOKEN: apiToken,
    PHYSICAL_BOOK_ADMIN_TOKEN: "test-admin-token",
    STRIPE_SECRET_KEY: "sk_test_mock",
    STRIPE_WEBHOOK_SECRET: "whsec_test_mock",
    STRIPE_BOUND_YEAR_MONTHLY_PRICE: "price_monthly_mock",
    STRIPE_BOUND_YEAR_ANNUAL_PRICE: "price_annual_mock",
    MEMBERSHIP_CUSTOMS_ENCRYPTION_KEY: "test-only-customs-encryption-key-00000001",
    LULU_CLIENT_KEY: "lulu-client",
    LULU_CLIENT_SECRET: "lulu-secret",
    LULU_AUTH_URL: "https://api.sandbox.lulu.com/auth/realms/glasstree/protocol/openid-connect/token",
    LULU_API_BASE_URL: "https://api.sandbox.lulu.com",
    CHECKOUT_MODE: "test",
    PHYSICAL_BOOK_ORDERING_ENABLED: "true",
    STRIPE_TAX_ENABLED: "true",
    PRINT_FILE_DELIVERY_BASE_URL: "https://print-files.example.test",
    PHYSICAL_BOOK_FILES: { async put() {}, async get() { return null; } },
    PHYSICAL_BOOK_ORDERS: {
      store: new Map(),
      async get(key) { return this.store.get(key) ?? null; },
      async put(key, value) { this.store.set(key, value); },
      async delete(key) { this.store.delete(key); },
      async list() { return { keys: [], list_complete: true }; },
    },
    PHYSICAL_BOOK_RATE_LIMITER: { async limit() { return { success: true }; } },
    ...overrides,
  };
}

let failures = 0;
let stripeCalls = [];
function check(condition, label) {
  if (condition) console.log(`  ok   ${label}`);
  else { failures += 1; console.error(`  FAIL ${label}`); }
}

function json(body) {
  return new Response(JSON.stringify(body), {
    status: 200, headers: { "Content-Type": "application/json" },
  });
}

globalThis.fetch = async (url, init = {}) => {
  const href = String(url);
  stripeCalls.push({ href, body: init.body ? String(init.body) : "" });
  if (href.endsWith("/v1/customers")) return json({
    id: "cus_mock", email: "reader@example.com", shipping: stripeShipping,
  });
  if (href.endsWith("/v1/customers/cus_mock")) return json({
    id: "cus_mock", email: "reader@example.com", shipping: stripeShipping,
  });
  if (href.endsWith("/v1/subscriptions")) {
    return json({
      id: "sub_mock",
      status: "incomplete",
      current_period_end: 1799999999,
      customer: "cus_mock",
      metadata: {
        reenchanted_cadence: "annual",
        reenchanted_physical_fulfillment: "accepted",
        reenchanted_start_month: "2026-08",
      },
      latest_invoice: { payment_intent: { client_secret: "pi_mock_secret" } },
    });
  }
  if (href.includes("/v1/subscriptions/sub_mock")) {
    const body = init.body ? String(init.body) : "";
    return json({
      id: "sub_mock",
      status: "active",
      cancel_at_period_end: body.includes("cancel_at_period_end=true"),
      current_period_end: 1799999999,
      customer: "cus_mock",
    });
  }
  throw new Error(`Unexpected request: ${href}`);
};

const shippingAddress = {
  name: "Reader Example",
  street1: "1 Harbor St",
  city: "Belfast",
  stateCode: "ME",
  countryCode: "US",
  postalCode: "04915",
  phoneNumber: "207-555-0100",
};
const stripeShipping = {
  name: shippingAddress.name,
  phone: shippingAddress.phoneNumber,
  address: {
    line1: shippingAddress.street1,
    city: shippingAddress.city,
    state: shippingAddress.stateCode,
    country: shippingAddress.countryCode,
    postal_code: shippingAddress.postalCode,
  },
};

function membershipBody(cadence = "annual", contactEmail = "reader@example.com", address = shippingAddress) {
  return JSON.stringify({ cadence, contactEmail, shippingAddress: address, acceptsLuluFulfillment: true });
}

async function session(env) {
  const response = await worker.fetch(
    new Request("https://example.test/sessions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiToken}`,
        "X-Installation-ID": installationID,
        "CF-Connecting-IP": networkID,
      },
    }),
    env,
  );
  return (await response.json()).token;
}

function headers(token) {
  return {
    Authorization: `Bearer ${token}`,
    "X-Installation-ID": installationID,
    "CF-Connecting-IP": networkID,
    "Content-Type": "application/json",
  };
}

const env = makeEnv();
const token = await session(env);

console.log("Opening a membership:");
stripeCalls = [];
const created = await worker.fetch(
  new Request("https://example.test/memberships", {
    method: "POST",
    headers: headers(token),
    body: membershipBody(),
  }),
  env,
);
const createdBody = await created.json();
check(created.status === 201, "a membership opens");
check(createdBody.clientSecret === "pi_mock_secret", "it hands back a payment to confirm in the app");
check(createdBody.cadence === "annual", "the cadence is recorded");
check(
  stripeCalls.some((c) => c.body.includes("payment_behavior=default_incomplete")),
  "the subscription waits for the reader to pay rather than assuming a card",
);
check(
  stripeCalls.some((c) => c.body.includes("price_annual_mock")),
  "the annual price is the one asked for",
);
check(
  stripeCalls.some((c) => c.body.includes("shipping%5Baddress%5D%5Bline1%5D=1+Harbor+St")),
  "the parcel address is attached to Stripe rather than returned to the Book archive",
);
check(
  stripeCalls.some((c) => c.body.includes("tax%5Bvalidate_location%5D=immediately")),
  "Stripe validates the tax location before opening the subscription",
);
check(
  stripeCalls.some((c) => c.body.includes("automatic_tax%5Benabled%5D=true")),
  "every Bound Year invoice uses destination-aware automatic tax",
);

console.log("\nBoth cadences:");
const monthly = await worker.fetch(
  new Request("https://example.test/memberships", {
    method: "POST", headers: headers(token),
    body: membershipBody("monthly"),
  }),
  env,
);
check(monthly.status === 201, "monthly opens too");

const nonsense = await worker.fetch(
  new Request("https://example.test/memberships", {
    method: "POST", headers: headers(token),
    body: membershipBody("weekly"),
  }),
  env,
);
check(nonsense.status === 400, "an invented cadence is refused");

const noEmail = await worker.fetch(
  new Request("https://example.test/memberships", {
    method: "POST", headers: headers(token),
    body: membershipBody("annual", "nope"),
  }),
  env,
);
check(noEmail.status === 400, "parcels need a working email");

const noAddress = await worker.fetch(
  new Request("https://example.test/memberships", {
    method: "POST", headers: headers(token),
    body: JSON.stringify({ cadence: "annual", contactEmail: "reader@example.com", acceptsLuluFulfillment: true }),
  }),
  env,
);
check(noAddress.status === 400, "a prepaid parcel cannot open without a delivery address");

const noConsent = await worker.fetch(
  new Request("https://example.test/memberships", {
    method: "POST", headers: headers(token),
    body: JSON.stringify({ cadence: "annual", contactEmail: "reader@example.com", shippingAddress }),
  }),
  env,
);
check(noConsent.status === 400, "Lulu fulfillment consent is explicit");

console.log("\nCustoms identity:");
const brazilAddress = {
  ...shippingAddress,
  city: "Sao Paulo",
  stateCode: "SP",
  countryCode: "BR",
  postalCode: "01001-000",
};
const brazilMissingID = await worker.fetch(
  new Request("https://example.test/memberships", {
    method: "POST", headers: headers(token),
    body: membershipBody("annual", "reader@example.com", brazilAddress),
  }),
  env,
);
check(brazilMissingID.status === 400, "a Bound Year cannot promise Brazilian parcels without a customs ID");
const brazilWithID = await worker.fetch(
  new Request("https://example.test/memberships", {
    method: "POST", headers: headers(token),
    body: membershipBody("annual", "reader@example.com", {
      ...brazilAddress,
      recipientTaxID: "123.456.789-01",
    }),
  }),
  env,
);
check(brazilWithID.status === 201, "a Brazilian Bound Year can open with its customs ID");
const protectedCustomsRecord = env.PHYSICAL_BOOK_ORDERS.store.get("bound-year-customs/cus_mock");
check(Boolean(protectedCustomsRecord), "the future-parcel customs record is retained server-side");
check(!String(protectedCustomsRecord).includes("12345678901"), "the retained customs ID is encrypted at rest");

console.log("\nAddress management:");
const statusResponse = await worker.fetch(
  new Request("https://example.test/memberships/sub_mock", { method: "GET", headers: headers(token) }),
  env,
);
const statusBody = await statusResponse.json();
check(statusBody.shippingAddressPresent === true, "membership status knows a parcel address exists");
check(!JSON.stringify(statusBody).includes("1 Harbor"), "membership status never returns the street address");

const updatedAddress = await worker.fetch(
  new Request("https://example.test/memberships/sub_mock/shipping", {
    method: "POST", headers: headers(token), body: JSON.stringify({ shippingAddress }),
  }),
  env,
);
check(updatedAddress.status === 200, "the parcel address can be changed in the app");

console.log("\nCancelling:");
stripeCalls = [];
const cancelled = await worker.fetch(
  new Request("https://example.test/memberships/sub_mock/cancel", {
    method: "POST", headers: headers(token),
  }),
  env,
);
const cancelBody = await cancelled.json();
check(cancelled.status === 200, "a membership can be stopped");
check(cancelBody.cancelAtPeriodEnd === true, "it stops at the end of the period");
check(
  stripeCalls.every((c) => !c.href.includes("DELETE")),
  "the subscription is never deleted outright",
);
check(
  cancelBody.status === "active",
  "and stays active until then — they paid for those months and the volumes they earn",
);

/// A reader must be able to stop paying even when the shop is shut.
const shutEnv = makeEnv({ PHYSICAL_BOOK_ORDERING_ENABLED: "false" });
const shutToken = await session(shutEnv);
const cancelWhileShut = await worker.fetch(
  new Request("https://example.test/memberships/sub_mock/cancel", {
    method: "POST", headers: headers(shutToken),
  }),
  shutEnv,
);
check(cancelWhileShut.status === 200, "cancelling works even with ordering switched off");

const subscribeWhileShut = await worker.fetch(
  new Request("https://example.test/memberships", {
    method: "POST", headers: headers(shutToken),
    body: membershipBody(),
  }),
  shutEnv,
);
check(subscribeWhileShut.status !== 201, "but subscribing does not");

const guardedLiveEnv = makeEnv({
  STRIPE_SECRET_KEY: "sk_live_mock",
  CHECKOUT_MODE: "live",
  LULU_API_BASE_URL: "https://api.lulu.com",
  LULU_AUTH_URL: "https://api.lulu.com/auth/realms/glasstree/protocol/openid-connect/token",
  BOUND_YEAR_LIVE_SALES_ENABLED: "false",
});
const guardedLiveToken = await session(guardedLiveEnv);
const guardedLiveSale = await worker.fetch(
  new Request("https://example.test/memberships", {
    method: "POST", headers: headers(guardedLiveToken), body: membershipBody(),
  }),
  guardedLiveEnv,
);
check(guardedLiveSale.status === 503, "live membership money stays shut behind its own launch gate");

console.log("\nNot configured:");
const bareEnv = makeEnv({ STRIPE_BOUND_YEAR_ANNUAL_PRICE: undefined });
const bareToken = await session(bareEnv);
const unconfigured = await worker.fetch(
  new Request("https://example.test/memberships", {
    method: "POST", headers: headers(bareToken),
    body: membershipBody(),
  }),
  bareEnv,
);
check(unconfigured.status === 503, "with no price configured it fails closed rather than guessing");

console.log("\nAuthorisation:");
const anonymous = await worker.fetch(
  new Request("https://example.test/memberships/sub_mock/cancel", { method: "POST" }),
  env,
);
check(anonymous.status === 401, "cancelling still needs a session");

console.log(failures === 0 ? "\nBound Year membership tests passed." : `\n${failures} failed.`);
if (failures > 0) process.exit(1);
