import { webcrypto } from "node:crypto";
import worker, { PhysicalBookOrderCoordinator } from "./lulu-quote-worker.mjs";

if (!globalThis.crypto) globalThis.crypto = webcrypto;

const apiToken = "test-api-token";
const adminToken = "test-admin-token";
const installationID = "test-installation-0001";
const networkID = "203.0.113.10";
const kvValues = new Map();
const r2Values = new Map();
const coordinatorObjects = new Map();
const externalCalls = [];
const securityAlertEmails = [];
let stripeCreateFields;
let luluCreateCount = 0;

const kv = {
  async get(key) { return kvValues.get(key) ?? null; },
  async put(key, value) { kvValues.set(key, value); },
  async delete(key) { kvValues.delete(key); },
  async list(options = {}) {
    const keys = Array.from(kvValues.keys())
      .filter((key) => !options.prefix || key.startsWith(options.prefix))
      .sort()
      .map((name) => ({ name }));
    return { keys, list_complete: true };
  },
};

const r2 = {
  async put(key, body, options) {
    r2Values.set(key, { body: new Uint8Array(body), options });
  },
  async get(key) {
    const stored = r2Values.get(key);
    return stored ? { body: stored.body } : null;
  },
};

const env = {
  PHYSICAL_BOOK_API_TOKEN: apiToken,
  PHYSICAL_BOOK_ADMIN_TOKEN: adminToken,
  STRIPE_SECRET_KEY: "sk_test_mock",
  STRIPE_WEBHOOK_SECRET: "whsec_test_mock",
  LULU_CLIENT_KEY: "lulu-client",
  LULU_CLIENT_SECRET: "lulu-secret",
  LULU_AUTH_URL: "https://api.sandbox.lulu.com/auth/realms/glasstree/protocol/openid-connect/token",
  LULU_API_BASE_URL: "https://api.sandbox.lulu.com",
  CHECKOUT_MODE: "test",
  PHYSICAL_BOOK_ORDERING_ENABLED: "true",
  STRIPE_TAX_ENABLED: "true",
  PRINT_FILE_DELIVERY_BASE_URL: "https://print-files.example.test",
  PHYSICAL_BOOK_FILES: r2,
  PHYSICAL_BOOK_ORDERS: kv,
  SECURITY_ALERT_EMAIL: {
    async send(message) {
      securityAlertEmails.push(message);
      return { messageId: "email-alert-test" };
    },
  },
  PHYSICAL_BOOK_RATE_LIMITER: { async limit() { return { success: true }; } },
};

env.PHYSICAL_BOOK_ORDER_COORDINATOR = {
  idFromName(name) { return name; },
  get(id) {
    if (!coordinatorObjects.has(id)) {
      const storage = new Map();
      const state = {
        storage: {
          async get(key) { return storage.get(key); },
          async put(key, value) { storage.set(key, value); },
        },
      };
      coordinatorObjects.set(id, new PhysicalBookOrderCoordinator(state, env));
    }
    return {
      fetch(url, init) {
        return coordinatorObjects.get(id).fetch(new Request(url, init));
      },
    };
  },
};

const originalFetch = globalThis.fetch;
globalThis.fetch = async (url, init = {}) => {
  const href = String(url);
  externalCalls.push({ href, init });
  if (href === env.LULU_AUTH_URL) return jsonResponse({ access_token: "lulu-token" });
  if (href.includes("/print-job-cost-calculations/")) {
    return jsonResponse({ shipping_cost: "7.99", print_cost: "19.51", tax: "1.25" });
  }
  if (href.endsWith("/cover-dimensions/")) {
    return jsonResponse({ width: "882", height: "666" });
  }
  if (href === "https://api.stripe.com/v1/tax/calculations") {
    const fields = Object.fromEntries(new URLSearchParams(init.body));
    return jsonResponse({
      id: `taxcalc_${externalCalls.length}`,
      currency: fields.currency,
      tax_amount_exclusive: 420,
      expires_at: Math.floor(Date.now() / 1000) + 3600,
    });
  }
  if (href === "https://api.stripe.com/v1/tax/transactions/create_from_calculation") {
    return jsonResponse({ id: "tax_transaction_123" });
  }
  if (href === "https://api.stripe.com/v1/payment_intents") {
    stripeCreateFields = Object.fromEntries(new URLSearchParams(init.body));
    return jsonResponse({
      id: "pi_123",
      client_secret: "pi_123_secret_test",
    });
  }
  if (href.endsWith("/v1/payment_intents/pi_123")) {
    return jsonResponse({
      id: "pi_123",
      status: "succeeded",
      amount: 11713,
      currency: "usd",
      metadata: {
        quote_id: currentQuote.id,
        edition_id: "edition-2026-06",
        variant_id: "cloth-foil-hardcover-6x9",
        lulu_package_id: "0600X0900.FC.STD.LW.060UW444.MNG",
        shipping_option_id: "MAIL",
        tax_calculation_id: currentQuote.shippingOptions[0].taxCalculationID,
      },
    });
  }
  if (href.endsWith("/print-jobs/print-job-123/")) {
    return jsonResponse({
      id: "print-job-123",
      created: "2026-08-08T12:00:00Z",
      status: { name: "SHIPPED", changed: "2026-08-09T12:00:00Z" },
      tracking_url: "https://tracking.example.test/print-job-123",
    });
  }
  if (href.endsWith("/print-jobs/")) {
    luluCreateCount += 1;
    return jsonResponse({ id: "print-job-123", status: { name: "PRODUCTION_READY" } });
  }
  throw new Error(`Unexpected external request: ${href}`);
};

let currentQuote;
let clientSessionToken;

try {
  const health = await requestJSON("/health", { method: "GET" }, env);
  assertEqual(health.body.readyForConfiguredMode, true, "configured checkout health");
  assertEqual(health.body.testReady, true, "test checkout health");
  assertEqual(health.body.productionReady, false, "test checkout is not reported as production");
  assertEqual(health.body.checks.alertEmailConfigured, true, "PII-free alert email is configured");

  const sessionResponse = await requestJSON("/sessions", {
    method: "POST",
    headers: bootstrapHeaders(),
  }, { ...env, PHYSICAL_BOOK_API_TOKEN: undefined });
  assertEqual(sessionResponse.response.status, 201, "client session status");
  assertEqual(sessionResponse.body.error, undefined, "client session needs no extractable app secret");
  assertTruthy(sessionResponse.body.token.length >= 40, "short-lived client session capability");
  clientSessionToken = sessionResponse.body.token;

  const rateLimitKeys = [];
  const limitedSession = await requestJSON("/sessions", {
    method: "POST",
    headers: bootstrapHeaders(),
  }, {
    ...env,
    PHYSICAL_BOOK_RATE_LIMITER: {
      async limit({ key }) {
        rateLimitKeys.push(key);
        return { success: !key.includes(":network:") };
      },
    },
  });
  assertEqual(limitedSession.response.status, 429, "network rate limit cannot be bypassed by rotating installation ID");
  assertEqual(rateLimitKeys.some((key) => key.includes(":installation:")), true, "installation rate limit applied");
  assertEqual(rateLimitKeys.some((key) => key.includes(":network:")), true, "network rate limit applied");

  const staticTokenReplay = await requestJSON("/quote", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiToken}`,
      "X-Installation-ID": installationID,
      "CF-Connecting-IP": networkID,
      "Content-Type": "application/json",
    },
    body: "{}",
  }, env);
  assertEqual(staticTokenReplay.response.status, 401, "app-wide bootstrap token cannot call checkout endpoints");

  const mismatchedSession = await requestJSON("/quote", {
    method: "POST",
    headers: authenticatedHeaders(undefined, {
      "CF-Connecting-IP": "203.0.113.99",
      "Content-Type": "application/json",
    }),
    body: "{}",
  }, env);
  assertEqual(mismatchedSession.response.status, 401, "client session is network-bound");

  const unconfigured = await worker.fetch(new Request("https://example.test/quote", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({}),
  }), {});
  assertEqual(unconfigured.status, 503, "missing secure storage fails closed");

  const quoteRequest = {
    apiVersion: 1,
    editionID: "edition-2026-06",
    variant: {
      id: "cloth-foil-hardcover-6x9",
      displayName: "Cloth foil hardcover",
      luluPackageID: "0600X0900.FC.STD.LW.060UW444.MNG",
      coverTreatment: "linenWrap",
      manufacturingBasePriceCentsUSD: 1,
      manufacturingPerPagePriceTenThousandthsUSD: 1,
    },
    pageCount: 120,
    quantity: 1,
    shipTo: {
      countryCode: "US",
      stateCode: "ME",
      postalCode: "04915",
      city: "Belfast",
      street1: "1 Harbor St",
      phoneNumber: "844-212-0689",
    },
    currencyCode: "USD",
  };
  const quoteResponse = await requestJSON("/quote", postOptions(quoteRequest), env);
  currentQuote = quoteResponse.body;
  assertEqual(quoteResponse.response.status, 200, "quote status");
  assertEqual(currentQuote.manufacturingSubtotal.cents, 1951, "Lulu owns manufacturing price");
  assertEqual(currentQuote.request.variant.manufacturingBasePriceCentsUSD, 1951, "client price replaced");
  assertEqual(currentQuote.shippingOptions[0].price.cents, 924, "printer tax is folded into fulfillment cost");
  assertEqual(currentQuote.shippingOptions[0].estimatedTax.cents, 420, "Stripe Tax owns reader-facing tax");
  assertTruthy(currentQuote.shippingOptions[0].taxCalculationID, "tax calculation is bound to shipping option");
  assertTruthy(currentQuote.checkoutToken.length >= 40, "quote checkout capability");

  const taxOffQuote = await requestJSON("/quote", postOptions({
    ...quoteRequest,
    editionID: "edition-2026-06-tax-off",
  }), { ...env, STRIPE_TAX_ENABLED: "false" });
  assertEqual(taxOffQuote.response.status, 200, "sandbox can exercise a tax-off quote");
  assertEqual(taxOffQuote.body.shippingOptions[0].estimatedTax.cents, 0, "printer tax is never mislabeled as reader sales tax");

  const disabledCheckout = await requestJSON("/payment-intents", postOptions({}, currentQuote.checkoutToken), {
    ...env,
    PHYSICAL_BOOK_ORDERING_ENABLED: "false",
  });
  assertEqual(disabledCheckout.response.status, 503, "checkout launch switch fails closed");

  const mismatchedCheckout = await requestJSON("/payment-intents", postOptions({}, currentQuote.checkoutToken), {
    ...env,
    CHECKOUT_MODE: "live",
  });
  assertEqual(mismatchedCheckout.response.status, 503, "Stripe and Lulu environment mismatch fails closed");

  const selectedShippingOption = {
    ...currentQuote.shippingOptions[0],
    price: { currencyCode: "USD", cents: 1 },
  };
  const paymentResponse = await requestJSON("/payment-intents", postOptions({
    quoteID: currentQuote.id,
    quoteRequest: { ...currentQuote.request, pageCount: 800 },
    selectedShippingOption,
    contactEmail: "reader@example.com",
  }, currentQuote.checkoutToken), env);
  assertEqual(paymentResponse.response.status, 201, "payment intent status");
  assertEqual(Number(stripeCreateFields.amount), 11713, "tampered client prices ignored");
  assertEqual(
    externalCalls.find((call) => call.href === "https://api.stripe.com/v1/payment_intents").init.headers["Idempotency-Key"],
    `physical-book:${currentQuote.id}:MAIL`,
    "Stripe idempotency key",
  );

  const missingSignature = await worker.fetch(new Request("https://example.test/stripe/webhook", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "{}",
  }), env);
  assertEqual(missingSignature.status, 400, "webhook requires Stripe signature");

  const invalidSignature = await sendStripeEvent(stripePaymentIntentEvent({
    id: "evt_invalid_signature_001",
  }), { signature: "0".repeat(64) });
  assertEqual(invalidSignature.response.status, 400, "invalid webhook signature rejected");

  const staleTimestamp = Math.floor(Date.now() / 1000) - 600;
  const staleEvent = await sendStripeEvent(stripePaymentIntentEvent({
    id: "evt_stale_signature_001",
  }), { timestamp: staleTimestamp });
  assertEqual(staleEvent.response.status, 400, "stale webhook signature rejected");

  const tamperedPaymentEvent = await sendStripeEvent(stripePaymentIntentEvent({
    id: "evt_tampered_amount_001",
    amount: 1,
  }));
  assertEqual(tamperedPaymentEvent.response.status, 409, "tampered webhook amount rejected");

  const successfulPaymentEvent = stripePaymentIntentEvent({ id: "evt_payment_succeeded_001" });
  const successfulWebhook = await sendStripeEvent(successfulPaymentEvent);
  assertEqual(successfulWebhook.response.status, 200, "signed payment webhook accepted");
  const paidQuoteRecord = JSON.parse(kvValues.get(`physical-book-quotes/${currentQuote.id}`));
  assertEqual(paidQuoteRecord.paymentStatus, "succeeded", "webhook records authoritative payment state");
  assertEqual(paidQuoteRecord.paymentStatusEventID, successfulPaymentEvent.id, "webhook event provenance recorded");
  assertTruthy(paidQuoteRecord.paymentSucceededAt, "webhook records payment success time");
  assertEqual(paidQuoteRecord.taxTransactionID, "tax_transaction_123", "paid tax is committed to Stripe's tax ledger");
  assertTruthy(kvValues.get(`reconciliation/paid/${currentQuote.id}`), "paid order enters reconciliation ledger");

  const pendingReconciliation = await requestJSON("/admin/reconciliation", {
    method: "GET",
    headers: { Authorization: `Bearer ${adminToken}` },
  }, env);
  assertEqual(pendingReconciliation.body.pendingCount, 1, "admin reconciliation reports paid order awaiting print");

  const overdueMarkerKey = `reconciliation/paid/${currentQuote.id}`;
  const overdueMarker = JSON.parse(kvValues.get(overdueMarkerKey));
  overdueMarker.paidAt = new Date(Date.now() - 31 * 60 * 1000).toISOString();
  kvValues.set(overdueMarkerKey, JSON.stringify(overdueMarker));
  let scheduledAudit;
  await worker.scheduled({}, env, { waitUntil(promise) { scheduledAudit = promise; } });
  await scheduledAudit;
  assertTruthy(kvValues.get(`reconciliation/alerts/${currentQuote.id}`), "scheduled audit records overdue paid order alert");
  assertEqual(securityAlertEmails.length, 1, "scheduled audit sends one alert email");
  assertEqual(securityAlertEmails[0].to, "snow.potions@gmail.com", "alert has a fixed recipient");
  assertEqual(securityAlertEmails[0].from.email, "print-desk-alerts@reenchanted.app", "alert uses the managed sender domain");
  const serializedAlertEmail = JSON.stringify(securityAlertEmails[0]);
  assertEqual(serializedAlertEmail.includes(currentQuote.id), false, "alert email omits quote ID");
  assertEqual(serializedAlertEmail.includes("pi_123"), false, "alert email omits payment ID");
  assertEqual(serializedAlertEmail.includes("reader@example.com"), false, "alert email omits customer email");
  assertEqual(serializedAlertEmail.includes("1 Harbor St"), false, "alert email omits street address");

  const replayedWebhook = await sendStripeEvent(successfulPaymentEvent);
  assertEqual(replayedWebhook.response.status, 200, "webhook replay acknowledged");
  assertEqual(replayedWebhook.body.duplicate, true, "webhook replay deduplicated");

  const canceledAfterSuccess = await sendStripeEvent(stripePaymentIntentEvent({
    id: "evt_payment_canceled_001",
    type: "payment_intent.canceled",
    status: "canceled",
  }));
  assertEqual(canceledAfterSuccess.response.status, 200, "out-of-order terminal event acknowledged");
  const stillPaidQuoteRecord = JSON.parse(kvValues.get(`physical-book-quotes/${currentQuote.id}`));
  assertEqual(stillPaidQuoteRecord.paymentStatus, "succeeded", "payment success is not downgraded");

  const unrelatedWebhook = await sendStripeEvent(stripePaymentIntentEvent({
    id: "evt_unrelated_payment_001",
    metadata: {},
  }));
  assertEqual(unrelatedWebhook.response.status, 200, "unrelated Stripe payment acknowledged without state");

  const pdf = new Uint8Array([0x25, 0x50, 0x44, 0x46]);
  const sha256 = await digestHex(pdf);
  const interior = await upload("interior", pdf, sha256);
  const cover = await upload("cover", pdf, sha256);
  assertTruthy(interior.body.sourceURL.startsWith("https://print-files.example.test/print-files/delivery/"), "private delivery URL");
  assertEqual(interior.body.sourceURL.includes("edition-2026-06"), false, "delivery URL is not predictable");

  const orderRequest = {
    quoteID: currentQuote.id,
    quoteRequest: { ...currentQuote.request, pageCount: 800 },
    paymentIntentID: "pi_123",
    contactEmail: "reader@example.com",
    shippingAddress: {
      name: "Reader",
      street1: "1 Harbor St",
      city: "Belfast",
      stateCode: "ME",
      countryCode: "US",
      postalCode: "04915",
      phoneNumber: "844-212-0689",
    },
    selectedShippingOptionID: "MAIL",
    selectedShippingOption,
    printFiles: {
      interiorSourceURL: "https://attacker.example/interior.pdf",
      interiorMD5: "0123456789abcdef0123456789abcdef",
      coverSourceURL: "https://attacker.example/cover.pdf",
      coverMD5: "abcdef0123456789abcdef0123456789",
    },
  };

  const [firstOrder, repeatedOrder] = await Promise.all([
    requestJSON("/orders", postOptions(orderRequest, currentQuote.checkoutToken), env),
    requestJSON("/orders", postOptions(orderRequest, currentQuote.checkoutToken), env),
  ]);
  if (!firstOrder.response.ok || !repeatedOrder.response.ok) {
    throw new Error(`fulfillment failed: ${JSON.stringify([firstOrder.body, repeatedOrder.body])}`);
  }
  assertEqual(firstOrder.body.luluPrintJobID, "print-job-123", "first fulfillment");
  assertEqual(repeatedOrder.body.luluPrintJobID, "print-job-123", "concurrent fulfillment receipt");
  assertEqual(luluCreateCount, 1, "concurrent fulfillment created once");

  const fulfilledQuoteRecordJSON = kvValues.get(`physical-book-quotes/${currentQuote.id}`);
  const fulfilledQuoteRecord = JSON.parse(fulfilledQuoteRecordJSON);
  assertTruthy(fulfilledQuoteRecord.piiRedactedAt, "fulfilled quote records PII redaction time");
  assertEqual(fulfilledQuoteRecord.contactEmail, undefined, "fulfilled quote drops contact email");
  assertEqual(fulfilledQuoteRecord.quote.request.shipTo.street1, undefined, "fulfilled quote drops street address");
  assertEqual(fulfilledQuoteRecord.quote.request.shipTo.postalCode, undefined, "fulfilled quote drops postal code");
  assertEqual(fulfilledQuoteRecord.quote.request.shipTo.phoneNumber, undefined, "fulfilled quote drops phone number");
  assertEqual(fulfilledQuoteRecordJSON.includes("reader@example.com"), false, "fulfilled quote JSON contains no contact email");
  assertEqual(fulfilledQuoteRecordJSON.includes("1 Harbor St"), false, "fulfilled quote JSON contains no street address");
  assertEqual(kvValues.has(`reconciliation/paid/${currentQuote.id}`), false, "fulfilled order leaves reconciliation ledger");

  const clearReconciliation = await requestJSON("/admin/reconciliation", {
    method: "GET",
    headers: { Authorization: `Bearer ${adminToken}` },
  }, env);
  assertEqual(clearReconciliation.body.pendingCount, 0, "admin reconciliation clears fulfilled order");

  const status = await requestJSON(`/orders/print-job-123`, {
    method: "GET",
    headers: authenticatedHeaders(currentQuote.checkoutToken, { "X-Payment-Intent-ID": "pi_123" }),
  }, env);
  assertEqual(status.body.quoteID, currentQuote.id, "status is bound to quote");
  assertEqual(status.body.status, "shipped", "status mapping");

  const delivered = await worker.fetch(new Request(interior.body.sourceURL), env);
  assertEqual(delivered.status, 200, "capability file delivery");
  assertEqual(delivered.headers.get("Cache-Control"), "private, no-store, max-age=0", "delivery cache policy");

  const badDigest = await upload("interior", pdf, "0".repeat(64));
  assertEqual(badDigest.response.status, 409, "upload digest mismatch rejected");

  console.log("Physical-book security smoke tests passed.");
} finally {
  globalThis.fetch = originalFetch;
}

async function upload(kind, body, sha256) {
  return requestJSON(`/print-files/${kind}`, {
    method: "POST",
    headers: authenticatedHeaders(currentQuote.checkoutToken, {
      "Content-Type": "application/pdf",
      "X-Edition-ID": "edition-2026-06",
      "X-Quote-ID": currentQuote.id,
      "X-Source-MD5": "0123456789abcdef0123456789abcdef",
      "X-Source-SHA256": sha256,
    }),
    body,
  }, env);
}

function postOptions(body, checkoutToken) {
  return {
    method: "POST",
    headers: authenticatedHeaders(checkoutToken, { "Content-Type": "application/json" }),
    body: JSON.stringify(body),
  };
}

function authenticatedHeaders(checkoutToken, extra = {}) {
  return {
    Authorization: `Bearer ${clientSessionToken}`,
    "X-Installation-ID": installationID,
    "CF-Connecting-IP": networkID,
    ...(checkoutToken ? { "X-Checkout-Token": checkoutToken } : {}),
    ...extra,
  };
}

function bootstrapHeaders(extra = {}) {
  return {
    "X-Installation-ID": installationID,
    "CF-Connecting-IP": networkID,
    ...extra,
  };
}

async function requestJSON(path, init, targetEnv) {
  const response = await worker.fetch(new Request(`https://example.test${path}`, init), targetEnv);
  return { response, body: await response.json() };
}

async function digestHex(bytes) {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function stripePaymentIntentEvent(overrides = {}) {
  const metadata = overrides.metadata ?? {
    quote_id: currentQuote.id,
    edition_id: "edition-2026-06",
    variant_id: "cloth-foil-hardcover-6x9",
    lulu_package_id: "0600X0900.FC.STD.LW.060UW444.MNG",
    shipping_option_id: "MAIL",
    tax_calculation_id: currentQuote.shippingOptions[0].taxCalculationID,
  };
  return {
    id: overrides.id || "evt_payment_succeeded_default",
    type: overrides.type || "payment_intent.succeeded",
    data: {
      object: {
        object: "payment_intent",
        id: "pi_123",
        status: overrides.status || "succeeded",
        amount: overrides.amount ?? 11713,
        currency: overrides.currency || "usd",
        metadata,
      },
    },
  };
}

async function sendStripeEvent(event, options = {}) {
  const rawBody = JSON.stringify(event);
  const timestamp = options.timestamp ?? Math.floor(Date.now() / 1000);
  const signature = options.signature || await webhookSignature(rawBody, timestamp, env.STRIPE_WEBHOOK_SECRET);
  return requestJSON("/stripe/webhook", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Stripe-Signature": `t=${timestamp},v1=${signature}`,
    },
    body: rawBody,
  }, env);
}

async function webhookSignature(rawBody, timestamp, secret) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${timestamp}.${rawBody}`),
  );
  return Array.from(new Uint8Array(signature), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function assertEqual(actual, expected, label) {
  if (actual !== expected) throw new Error(`${label}: expected ${expected}, got ${actual}`);
}

function assertTruthy(value, label) {
  if (!value) throw new Error(`${label}: expected a truthy value`);
}
