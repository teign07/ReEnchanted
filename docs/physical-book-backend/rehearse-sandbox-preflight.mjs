// Deployed preflight only: no payment confirmation, subscription creation,
// manuscript upload, print-job submission, or email. Uses synthetic data.
import assert from "node:assert/strict";

const origin = "https://reenchanted-physical-books.snow-potions.workers.dev";
const installation = `sandbox-preflight-${crypto.randomUUID()}`;
let token;
async function request(path, body, attemptID) {
  const response = await fetch(`${origin}${path}`, {
    method: body === undefined ? "GET" : "POST", redirect: "error",
    signal: AbortSignal.timeout(45_000),
    headers: {
      "Content-Type": "application/json", "X-Installation-ID": installation,
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(attemptID ? { "X-Purchase-Attempt-ID": attemptID } : {}),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, body: await response.json() };
}

const health = await request("/health");
assert.equal(health.status, 200);
assert.equal(health.body.testReady, true);
assert.equal(health.body.productionReady, false);
assert.equal(health.body.checks.checkoutMode, "test");
assert.equal(health.body.checks.checkoutEnvironmentAligned, true);
assert.equal(health.body.checks.boundYearLiveSalesEnabled, false);
assert.equal(typeof health.body.boundYearTestReady, "boolean", "deploy the matching rehearsal Worker first");
console.log("PASS: aligned Stripe test / Lulu sandbox; live sales closed.");
const session = await request("/sessions", {});
assert.equal(session.status, 201);
assert.match(session.body.token, /^[A-Za-z0-9_-]{40,128}$/);
token = session.body.token; // Never log credentials or capability URLs.

for (const path of ["/memberships", "/gifts/bound-year"]) {
  const attemptID = crypto.randomUUID();
  const closed = await request(`${path}/checkout/cancel`, {}, attemptID);
  assert.equal(closed.status, 200);
  assert.equal(closed.body.canceled, true);
  const repeat = await request(`${path}/checkout/cancel`, {}, attemptID);
  assert.equal(repeat.body.canceled, true);
  // An intentionally incomplete form is also incapable of opening a purchase
  // if the durable closed-attempt guard regresses.
  const delayed = await request(path, { cadence: "annual" }, attemptID);
  assert.equal(delayed.status, 409);
  assert.equal(delayed.body.error, "checkout_closed");
  console.log(`PASS: ${path} durable closure survives repeat and delayed create.`);
}

const quote = await request("/quote", {
  apiVersion: 1, editionID: "sandbox-preflight-synthetic", editionKind: "monthly",
  variant: { id: "cloth-foil-hardcover-6x9", displayName: "Cloth foil hardcover",
    luluPackageID: "0600X0900.FC.STD.LW.060UW444.MNG", coverTreatment: "linenWrap",
    manufacturingBasePriceCentsUSD: 1, manufacturingPerPagePriceTenThousandthsUSD: 1 },
  pageCount: 120, quantity: 1, currencyCode: "USD",
  shipTo: { countryCode: "US", stateCode: "ME", postalCode: "04915", city: "Belfast",
    street1: "1 Test Street", phoneNumber: "207-555-0100" },
});
assert.equal(quote.status, 200, `sandbox quote failed: ${quote.body.error || "unknown"}`);
assert.ok(quote.body.manufacturingSubtotal?.cents > 0);
assert.ok(quote.body.shippingOptions?.length > 0);
console.log("PASS: Lulu sandbox authenticated and returned manufacturing/shipping quotes.");
console.log(JSON.stringify({ boundYearTestReady: health.body.boundYearTestReady,
  monthlyPriceConfigured: health.body.checks.boundYearMonthlyPriceConfigured,
  annualPriceConfigured: health.body.checks.boundYearAnnualPriceConfigured,
  paymentsConfirmed: 0, printJobsSubmitted: 0 }));
