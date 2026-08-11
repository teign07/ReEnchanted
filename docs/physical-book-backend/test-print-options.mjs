// The deliberately empty upsell catalogue.
//
// Cover authorship is included, and a binding upgrade is represented by the
// actual print variant. These tests pin that policy and the server refusal of
// invented paid extras.
//
//   node test-print-options.mjs

import { webcrypto } from "node:crypto";
import worker from "./lulu-quote-worker.mjs";

if (!globalThis.crypto) globalThis.crypto = webcrypto;

const apiToken = "test-api-token";
const installationID = "test-installation-0001";
const networkID = "203.0.113.10";

const env = {
  PHYSICAL_BOOK_API_TOKEN: apiToken,
  PHYSICAL_BOOK_ADMIN_TOKEN: "test-admin-token",
  STRIPE_SECRET_KEY: "sk_test_mock",
  STRIPE_WEBHOOK_SECRET: "whsec_test_mock",
  LULU_CLIENT_KEY: "lulu-client",
  LULU_CLIENT_SECRET: "lulu-secret",
  LULU_AUTH_URL: "https://api.sandbox.lulu.com/auth/realms/glasstree/protocol/openid-connect/token",
  LULU_API_BASE_URL: "https://api.sandbox.lulu.com",
  CHECKOUT_MODE: "test",
  PHYSICAL_BOOK_ORDERING_ENABLED: "true",
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
};

let failures = 0;
function check(condition, label) {
  if (condition) {
    console.log(`  ok   ${label}`);
  } else {
    failures += 1;
    console.error(`  FAIL ${label}`);
  }
}

async function session() {
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

async function options(token, variantID) {
  const response = await worker.fetch(
    new Request(`https://example.test/options?variantID=${encodeURIComponent(variantID)}`, {
      headers: {
        Authorization: `Bearer ${token}`,
        "X-Installation-ID": installationID,
        "CF-Connecting-IP": networkID,
      },
    }),
    env,
  );
  return { status: response.status, body: await response.json() };
}

const token = await session();

console.log("Catalogue:");
const softcover = await options(token, "perfect-bound-softcover-6x9");
check(softcover.status === 200, "softcover has a catalogue");
const softcoverIDs = softcover.body.options.map((o) => o.id);
check(softcoverIDs.length === 0, "cover authorship is not sold as an extra");

const cloth = await options(token, "cloth-foil-hardcover-6x9");
const clothIDs = cloth.body.options.map((o) => o.id);
check(clothIDs.length === 0, "cloth and foil is chosen as a binding, not stacked as an extra");

console.log("\nRefusals:");
const unknownVariant = await options(token, "not-a-binding");
check(unknownVariant.status === 400, "an unknown binding has no catalogue");

const rejected = await worker.fetch(
  new Request("https://example.test/options?variantID=", {
    headers: {
      Authorization: `Bearer ${token}`,
      "X-Installation-ID": installationID,
      "CF-Connecting-IP": networkID,
    },
  }),
  env,
);
check(rejected.status === 400, "a missing binding is refused rather than defaulted");

const anonymous = await worker.fetch(new Request("https://example.test/options?variantID=perfect-bound-softcover-6x9"), env);
check(anonymous.status === 401, "the catalogue still needs a session");


console.log("\nPricing (through the real quote path):");

globalThis.fetch = async (url) => {
  const href = String(url);
  if (href === env.LULU_AUTH_URL) {
    return new Response(JSON.stringify({ access_token: "lulu-token" }), {
      status: 200, headers: { "Content-Type": "application/json" },
    });
  }
  if (href.includes("/print-job-cost-calculations/")) {
    return new Response(JSON.stringify({ shipping_cost: "7.99", print_cost: "19.51" }), {
      status: 200, headers: { "Content-Type": "application/json" },
    });
  }
  if (href.endsWith("/cover-dimensions/")) {
    return new Response(JSON.stringify({ width: "882", height: "666" }), {
      status: 200, headers: { "Content-Type": "application/json" },
    });
  }
  throw new Error(`Unexpected request: ${href}`);
};

function quoteBody(selectedOptionIDs) {
  return {
    apiVersion: 1,
    editionID: "edition-2026-06",
    variant: {
      id: "perfect-bound-softcover-6x9",
      displayName: "Softcover",
      luluPackageID: "0600X0900.FC.STD.PB.060UW444.MXX",
      coverTreatment: "perfectBound",
      manufacturingBasePriceCentsUSD: 1,
      manufacturingPerPagePriceTenThousandthsUSD: 1,
    },
    pageCount: 120,
    quantity: 1,
    shipTo: {
      countryCode: "US", stateCode: "ME", postalCode: "04915",
      city: "Belfast", street1: "1 Harbor St", phoneNumber: "844-212-0689",
    },
    currencyCode: "USD",
    selectedOptionIDs,
  };
}

async function quote(selectedOptionIDs) {
  return quoteRequest(quoteBody(selectedOptionIDs));
}

async function quoteRequest(body) {
  const response = await worker.fetch(
    new Request("https://example.test/quote", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "X-Installation-ID": installationID,
        "CF-Connecting-IP": networkID,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    }),
    env,
  );
  return { status: response.status, body: await response.json() };
}

const plain = await quote([]);
check(plain.status === 200, "a quote with no extras still works");
check(plain.body.coverDimensions?.widthPoints === 882, "a quote carries Lulu's exact cover canvas");

const invented = await quote(["free-gold-plating"]);
check(invented.status === 400, "an invented option is refused, not priced at zero");

const disguisedBinding = await quote(["upgrade-hardcover"]);
check(disguisedBinding.status === 400, "a binding change cannot be smuggled in as an extra");

console.log("\nWeekly issue binding:");
const weeklyBody = {
  ...quoteBody([]),
  editionID: "weekly-issue-12",
  pageCount: 48,
  variant: {
    ...quoteBody([]).variant,
    id: "saddle-stitched-weekly-6x9",
    displayName: "6 x 9 Weekly Issue, saddle stitched",
    luluPackageID: "0600X0900.FC.PRE.SS.060UW444.MXX",
    coverTreatment: "saddleStitch",
  },
};
const weekly = await quoteRequest(weeklyBody);
check(weekly.status === 200, "a 48-page weekly issue can be quoted a la carte");
check(weekly.body.coverDimensions?.heightPoints === 666, "a weekly quote carries its saddle-stitch cover canvas");
const standardWeekly = await quoteRequest({ ...weeklyBody, editionID: "weekly-standard", pageCount: 32 });
check(standardWeekly.status === 200, "the standard 32-page weekly issue can be quoted a la carte");
const thinWeekly = await quoteRequest({ ...weeklyBody, editionID: "weekly-thin", pageCount: 8 });
check(thinWeekly.status === 200, "a small eight-page weekly issue is not forced into book geometry");
const weeklyTooLong = await quoteRequest({ ...weeklyBody, editionID: "weekly-too-long", pageCount: 52 });
check(weeklyTooLong.status === 400, "a weekly issue over 48 pages is refused before checkout");
const weeklyBadFold = await quoteRequest({ ...weeklyBody, editionID: "weekly-bad-fold", pageCount: 46 });
check(weeklyBadFold.status === 400, "a saddle-stitched issue must fold in groups of four pages");

console.log("\nInternational customs:");
const brazilWithoutTaxID = await quoteRequest({
  ...quoteBody([]),
  editionID: "brazil-missing-customs-id",
  shipTo: {
    ...quoteBody([]).shipTo,
    countryCode: "BR",
    stateCode: "SP",
    postalCode: "01001-000",
    city: "Sao Paulo",
  },
});
check(brazilWithoutTaxID.status === 400, "Brazil is refused before pricing when its customs ID is missing");
const brazilWithTaxID = await quoteRequest({
  ...quoteBody([]),
  editionID: "brazil-with-customs-id",
  shipTo: {
    ...quoteBody([]).shipTo,
    countryCode: "BR",
    stateCode: "SP",
    postalCode: "01001-000",
    city: "Sao Paulo",
    recipientTaxID: "123.456.789-01",
  },
});
check(brazilWithTaxID.status === 200, "Brazil can be priced when its customs ID is present");
check(brazilWithTaxID.body.request?.shipTo?.recipientTaxID === "12345678901", "the customs ID is compacted before its short-lived quote is stored");

console.log(failures === 0 ? "\nPrint option catalogue tests passed." : `\n${failures} failed.`);
if (failures > 0) process.exit(1);
