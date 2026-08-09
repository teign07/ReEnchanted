// The upsell catalogue.
//
// The catalogue lives on the server so a new cover ships without an App Store
// release — and, less negotiably, because this Worker refuses client-supplied
// prices. These tests pin the refusals: a client must not be able to invent an
// option, apply one to a binding it was never offered for, or stack two that
// fight over the SKU.
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
check(softcoverIDs.includes("photo-cover"), "a photo cover is offered on the softcover");
check(softcoverIDs.includes("upgrade-hardcover"), "the softcover can be bound hard");

const cloth = await options(token, "cloth-foil-hardcover-6x9");
const clothIDs = cloth.body.options.map((o) => o.id);
check(
  !clothIDs.includes("upgrade-cloth-foil"),
  "cloth and foil is not offered to a book that is already cloth and foil",
);
check(clothIDs.includes("photo-cover"), "a photo cover is offered on every binding");

check(
  softcover.body.options.every((o) => Number.isInteger(o.priceDeltaCents)),
  "every option carries a price the server owns",
);
check(
  softcover.body.options.every((o) => typeof o.pitch === "string" && o.pitch.length > 0),
  "every option says something in the Book's voice",
);

console.log("\nThe zero-cost ones:");
const photo = softcover.body.options.find((o) => o.id === "photo-cover");
check(photo.requires.includes("photo"), "a photo cover asks for a photo");
check(photo.resultingVariantID === null, "a cover change does not change the binding");

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
  const response = await worker.fetch(
    new Request("https://example.test/quote", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "X-Installation-ID": installationID,
        "CF-Connecting-IP": networkID,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(quoteBody(selectedOptionIDs)),
    }),
    env,
  );
  return { status: response.status, body: await response.json() };
}

const plain = await quote([]);
check(plain.status === 200, "a quote with no extras still works");

const invented = await quote(["free-gold-plating"]);
check(invented.status === 400, "an invented option is refused, not priced at zero");

const wrongBinding = await quote(["upgrade-cloth-foil", "upgrade-hardcover"]);
check(wrongBinding.status === 400, "two binding changes cannot be stacked");

console.log(failures === 0 ? "\nPrint option catalogue tests passed." : `\n${failures} failed.`);
if (failures > 0) process.exit(1);
