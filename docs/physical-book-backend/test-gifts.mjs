import { webcrypto } from "node:crypto";
import worker, { PhysicalBookOrderCoordinator } from "./lulu-quote-worker.mjs";

if (!globalThis.crypto) globalThis.crypto = webcrypto;

const installationID = "gift-buyer-installation";
const networkID = "203.0.113.22";
const kvValues = new Map();
const r2Values = new Map();
const coordinators = new Map();
let sessionToken = "";
let paymentCounter = 0;
const payments = new Map();
let luluCreates = 0;
let failures = 0;

const variants = {
  cloth: {
    id: "cloth-foil-hardcover-6x9",
    displayName: "6 × 9 Hardcover, cloth & foil",
    luluPackageID: "0600X0900.FC.STD.LW.060UW444.MNG",
    coverTreatment: "linenWrap",
  },
  illustrated: {
    id: "illustrated-hardcover-6x9",
    displayName: "6 × 9 Hardcover, illustrated cover",
    luluPackageID: "0600X0900.FC.STD.CW.060UW444.MXX",
    coverTreatment: "caseWrap",
  },
  softcover: {
    id: "perfect-bound-softcover-6x9",
    displayName: "6 × 9 Softcover, perfect bound",
    luluPackageID: "0600X0900.FC.STD.PB.060UW444.MXX",
    coverTreatment: "perfectBound",
  },
  weekly: {
    id: "saddle-stitched-weekly-6x9",
    displayName: "6 × 9 Weekly Issue, saddle stitched",
    luluPackageID: "0600X0900.FC.PRE.SS.060UW444.MXX",
    coverTreatment: "saddleStitch",
  },
};

const kv = {
  async get(key) { return kvValues.get(key) ?? null; },
  async put(key, value) { kvValues.set(key, value); },
  async delete(key) { kvValues.delete(key); },
  async list(options = {}) {
    const keys = [...kvValues.keys()]
      .filter((key) => !options.prefix || key.startsWith(options.prefix))
      .map((name) => ({ name }));
    return { keys, list_complete: true };
  },
};

const r2 = {
  async put(key, body, options) { r2Values.set(key, { body: new Uint8Array(body), options }); },
  async get(key) {
    const stored = r2Values.get(key);
    return stored ? { body: stored.body } : null;
  },
};

const env = {
  PHYSICAL_BOOK_API_TOKEN: "test-bootstrap-token",
  PHYSICAL_BOOK_ADMIN_TOKEN: "test-admin-token",
  STRIPE_SECRET_KEY: "sk_test_mock",
  STRIPE_WEBHOOK_SECRET: "whsec_test_mock",
  LULU_CLIENT_KEY: "lulu-client",
  LULU_CLIENT_SECRET: "lulu-secret",
  LULU_AUTH_URL: "https://api.sandbox.lulu.com/auth/realms/glasstree/protocol/openid-connect/token",
  LULU_API_BASE_URL: "https://api.sandbox.lulu.com",
  CHECKOUT_MODE: "test",
  PHYSICAL_BOOK_ORDERING_ENABLED: "true",
  STRIPE_TAX_ENABLED: "false",
  PRINT_FILE_DELIVERY_BASE_URL: "https://print-files.example.test",
  PHYSICAL_BOOK_FILES: r2,
  PHYSICAL_BOOK_ORDERS: kv,
  PHYSICAL_BOOK_RATE_LIMITER: { async limit() { return { success: true }; } },
};

env.PHYSICAL_BOOK_ORDER_COORDINATOR = {
  idFromName(name) { return name; },
  get(id) {
    if (!coordinators.has(id)) {
      const storage = new Map();
      const state = { storage: {
        async get(key) { return storage.get(key); },
        async put(key, value) { storage.set(key, value); },
      } };
      coordinators.set(id, new PhysicalBookOrderCoordinator(state, env));
    }
    return { fetch(url, init) { return coordinators.get(id).fetch(new Request(url, init)); } };
  },
};

const originalFetch = globalThis.fetch;
globalThis.fetch = async (url, init = {}) => {
  const href = String(url);
  if (href === env.LULU_AUTH_URL) return json({ access_token: "lulu-token" });
  if (href === "https://api.zippopotam.us/us/04915") {
    return json({ places: [{ "place name": "Belfast", "state abbreviation": "ME" }] });
  }
  if (href.includes("/print-job-cost-calculations/")) {
    return json({ shipping_cost: "7.50", print_cost: "18.76", tax: "0.80" });
  }
  if (href.endsWith("/cover-dimensions/")) return json({ width: "882", height: "666" });
  if (href === "https://api.stripe.com/v1/payment_intents") {
    const fields = Object.fromEntries(new URLSearchParams(init.body));
    const id = `pi_gift_${++paymentCounter}`;
    payments.set(id, {
      id,
      status: "succeeded",
      amount: Number(fields.amount),
      currency: fields.currency,
      metadata: {
        quote_id: fields["metadata[quote_id]"],
        edition_id: fields["metadata[edition_id]"],
        variant_id: fields["metadata[variant_id]"],
        lulu_package_id: fields["metadata[lulu_package_id]"],
        shipping_option_id: fields["metadata[shipping_option_id]"],
        tax_calculation_id: fields["metadata[tax_calculation_id]"],
      },
    });
    return json({ id, client_secret: `${id}_secret_test` });
  }
  const paymentMatch = href.match(/\/v1\/payment_intents\/(pi_gift_\d+)$/);
  if (paymentMatch) return json(payments.get(paymentMatch[1]));
  if (href.endsWith("/print-jobs/")) {
    luluCreates += 1;
    return json({ id: "gift-print-job", status: { name: "PRODUCTION_READY" } });
  }
  console.error(`Unexpected external request: ${href}`);
  throw new Error(`Unexpected external request: ${href}`);
};

try {
  sessionToken = await createSession(installationID);

  const allowanceQuote = await quote({
    editionID: "gift-pass-monthly-first",
    editionKind: "monthly",
    pageCount: 200,
    variant: variants.cloth,
    shipTo: {
      countryCode: "US",
      stateCode: "ME",
      postalCode: "04915",
      city: "Belfast",
      street1: "1 Harbor Street",
      phoneNumber: "207-555-0100",
    },
  });
  check(allowanceQuote.response.status === 200, "a maximum-size gift receives a live quote");
  if (!allowanceQuote.response.ok) {
    throw new Error(`gift quote failed: ${JSON.stringify(allowanceQuote.body)}`);
  }

  const payment = await requestJSON("/payment-intents", post({
    quoteID: allowanceQuote.body.id,
    quoteRequest: allowanceQuote.body.request,
    selectedShippingOption: allowanceQuote.body.shippingOptions[0],
    contactEmail: "giver@example.com",
  }, allowanceQuote.body.checkoutToken));
  check(payment.response.status === 201, "the giver can pay the existing secure till");

  const purchase = {
    quoteID: allowanceQuote.body.id,
    paymentIntentID: payment.body.id,
    contactEmail: "giver@example.com",
    selectedShippingOptionID: allowanceQuote.body.shippingOptions[0].id,
    senderName: "Giver",
    recipientName: "Reader",
    message: "Make something only you could make.",
  };
  const gift = await requestJSON("/gifts/books", post(purchase, allowanceQuote.body.checkoutToken));
  check(gift.response.status === 201, "a settled payment becomes a sealed gift");
  check(gift.body.gift.kind === "bookOfRecipient", "the public gift has the right kind");
  check(gift.body.gift.includedEditionKind === "monthly", "the gift declares the chosen edition span");
  check(gift.body.gift.includedVariantID === variants.cloth.id, "the gift declares the chosen cloth-and-foil binding");
  check(gift.body.gift.includedPageCount === 200, "the gift declares its page ceiling");
  check(!JSON.stringify(gift.body).includes("street1"), "the gift response carries no street address");
  check(gift.body.shareURL.endsWith(`#${gift.body.claimToken}`), "the claim token stays in the URL fragment");
  const sealedQuote = JSON.parse(kvValues.get(`physical-book-quotes/${allowanceQuote.body.id}`));
  check(!sealedQuote.quote.request.shipTo.street1, "the full quote address is erased once the gift is sealed");
  check(!sealedQuote.contactEmail, "the sealed quote drops the purchaser email too");
  check(kvValues.has(`book-gifts/payment/${payment.body.id}`), "support can locate the gift from its Stripe receipt without PII");

  const repeated = await requestJSON("/gifts/books", post(purchase, allowanceQuote.body.checkoutToken));
  check(repeated.body.claimToken === gift.body.claimToken, "finalization retry returns the same claim key");
  check(repeated.body.gift.id === gift.body.gift.id, "finalization retry cannot mint a second gift");

  const summary = await requestJSON(`/gifts/${gift.body.claimToken}`, { method: "GET", headers: headers() });
  check(summary.body.status === "readyToClaim", "the recipient can inspect the sealed gift before accepting");
  check(summary.body.message === purchase.message, "only the sender's explicit note crosses the doorway");

  const claim = await requestJSON(`/gifts/${gift.body.claimToken}/claim`, post({}));
  check(claim.response.status === 200, "the recipient claims in one request");
  check(claim.body.pressPass.includedEditionKind === "monthly", "the claimed pass keeps the chosen edition span");
  check(claim.body.pressPass.includedVariantID === variants.cloth.id, "the claimed pass keeps the chosen binding");
  check(claim.body.pressPass.maximumPageCount === 200, "the claimed press pass keeps the paid ceiling");
  const suggestedAddress = await openDeliveryEnvelope(
    claim.body.pressPass.deliveryEnvelope,
    gift.body.claimToken,
  );
  check(suggestedAddress.street1 === "1 Harbor Street", "the claim key locally opens the suggested parcel label");
  check(!JSON.stringify(kvValues.get(`physical-book-quotes/${allowanceQuote.body.id}`)).includes("1 Harbor Street"), "the readable server quote stays erased");

  const otherSession = await createSession("different-installation");
  const stolen = await worker.fetch(new Request(`https://example.test/gifts/${gift.body.claimToken}/claim`, {
    method: "POST",
    headers: headers(otherSession, "different-installation"),
    body: "{}",
  }), env);
  check(stolen.status === 409, "a claimed gift cannot move to a different installation");

  const redemptionQuote = await quote({
    editionID: "recipient-edition",
    editionKind: "monthly",
    pageCount: 120,
    variant: variants.cloth,
    shipTo: {
      countryCode: "US",
      stateCode: "ME",
      postalCode: "04915",
      city: "Belfast",
      street1: "1 Harbor Street",
      phoneNumber: "207-555-0100",
    },
  });
  check(redemptionQuote.response.status === 200, "the recipient gets a fresh quote for the real book");

  const pdf = new TextEncoder().encode("%PDF-1.7\nrecipient-private-pages\n%%EOF");
  const sha256 = await digestHex(pdf);
  for (const kind of ["interior", "cover"]) {
    const upload = await worker.fetch(new Request(`https://example.test/print-files/${kind}`, {
      method: "POST",
      headers: headers(sessionToken, installationID, redemptionQuote.body.checkoutToken, {
        "Content-Type": "application/pdf",
        "X-Edition-ID": "recipient-edition",
        "X-Quote-ID": redemptionQuote.body.id,
        "X-Source-MD5": "0123456789abcdef0123456789abcdef",
        "X-Source-SHA256": sha256,
      }),
      body: pdf,
    }), env);
    check(upload.status === 201, `the recipient uploads the ${kind} only after claiming`);
  }

  const shippingOption = redemptionQuote.body.shippingOptions[0];
  const orderRequest = {
    quoteID: redemptionQuote.body.id,
    quoteRequest: redemptionQuote.body.request,
    paymentIntentID: `gift:${gift.body.gift.id}`,
    contactEmail: "reader@example.com",
    shippingAddress: {
      name: "Reader",
      street1: "1 Harbor Street",
      city: "Belfast",
      stateCode: "ME",
      countryCode: "US",
      postalCode: "04915",
      phoneNumber: "207-555-0100",
    },
    selectedShippingOptionID: shippingOption.id,
    selectedShippingOption: shippingOption,
    printFiles: {
      interiorSourceURL: "https://untrusted.example/interior.pdf",
      interiorMD5: "00000000000000000000000000000000",
      coverSourceURL: "https://untrusted.example/cover.pdf",
      coverMD5: "00000000000000000000000000000000",
    },
  };
  const order = await requestJSON(
    `/gifts/${gift.body.claimToken}/orders`,
    post(orderRequest, redemptionQuote.body.checkoutToken),
  );
  check(order.response.status === 201, "the claimed gift goes to Lulu without a second payment");
  check(order.body.luluPrintJobID === "gift-print-job", "the printer receipt returns");
  check(luluCreates === 1, "the gift creates one print job");

  const repeatedOrder = await requestJSON(
    `/gifts/${gift.body.claimToken}/orders`,
    post(orderRequest, redemptionQuote.body.checkoutToken),
  );
  check(repeatedOrder.body.luluPrintJobID === "gift-print-job", "a lost response can retrieve the same receipt");
  check(luluCreates === 1, "a redemption retry cannot print twice");

  const redeemed = await requestJSON(`/gifts/${gift.body.claimToken}`, { method: "GET", headers: headers() });
  check(redeemed.body.status === "redeemed", "the seal closes after its one pressing");
  check(redeemed.body.redeemedAt, "the gift records when it went to press");

  const giftableShapes = [
    { kind: "weekly", pageCount: 48, variants: [variants.weekly] },
    { kind: "monthly", pageCount: 200, variants: [variants.softcover, variants.illustrated, variants.cloth] },
    { kind: "seasonal", pageCount: 400, variants: [variants.softcover, variants.illustrated, variants.cloth] },
    { kind: "annual", pageCount: 800, variants: [variants.softcover, variants.illustrated, variants.cloth] },
  ];
  for (const shape of giftableShapes) {
    for (const variant of shape.variants) {
      const matrixGift = await buyGiftShape(shape.kind, shape.pageCount, variant);
      check(matrixGift.response.status === 201, `${shape.kind} ${variant.id} can be gifted`);
      check(matrixGift.body.gift.includedEditionKind === shape.kind, `${shape.kind} keeps its edition entitlement`);
      check(matrixGift.body.gift.includedVariantID === variant.id, `${shape.kind} keeps its ${variant.id} binding`);
      check(matrixGift.body.gift.includedPageCount === shape.pageCount, `${shape.kind} keeps its page allowance`);
    }
  }

  console.log(failures === 0 ? "\nGift flow tests passed." : `\n${failures} gift tests failed.`);
  if (failures) process.exitCode = 1;
} finally {
  globalThis.fetch = originalFetch;
}

function check(condition, label) {
  if (condition) console.log(`  ok   ${label}`);
  else { failures += 1; console.error(`  FAIL ${label}`); }
}

async function createSession(id) {
  const response = await worker.fetch(new Request("https://example.test/sessions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.PHYSICAL_BOOK_API_TOKEN}`,
      "X-Installation-ID": id,
      "CF-Connecting-IP": networkID,
    },
  }), env);
  return (await response.json()).token;
}

function headers(token = sessionToken, id = installationID, checkoutToken, extra = {}) {
  return {
    Authorization: `Bearer ${token}`,
    "X-Installation-ID": id,
    "CF-Connecting-IP": networkID,
    ...(checkoutToken ? { "X-Checkout-Token": checkoutToken } : {}),
    ...extra,
  };
}

function post(body, checkoutToken) {
  return {
    method: "POST",
    headers: headers(sessionToken, installationID, checkoutToken, { "Content-Type": "application/json" }),
    body: JSON.stringify(body),
  };
}

async function quote({ editionID, editionKind, pageCount, variant, shipTo }) {
  return requestJSON("/quote", post({
    apiVersion: 1,
    editionID,
    editionKind,
    variant: {
      ...variant,
      manufacturingBasePriceCentsUSD: 1,
      manufacturingPerPagePriceTenThousandthsUSD: 1,
    },
    pageCount,
    quantity: 1,
    shipTo,
    currencyCode: "USD",
    selectedOptionIDs: [],
  }));
}

async function buyGiftShape(editionKind, pageCount, variant) {
  const giftQuote = await quote({
    editionID: `gift-pass-${editionKind}-matrix-${variant.id}`,
    editionKind,
    pageCount,
    variant,
    shipTo: {
      countryCode: "US",
      stateCode: "ME",
      postalCode: "04915",
      city: "Belfast",
      street1: "1 Harbor Street",
      phoneNumber: "207-555-0100",
    },
  });
  if (!giftQuote.response.ok) return giftQuote;
  const payment = await requestJSON("/payment-intents", post({
    quoteID: giftQuote.body.id,
    quoteRequest: giftQuote.body.request,
    selectedShippingOption: giftQuote.body.shippingOptions[0],
    contactEmail: "giver@example.com",
  }, giftQuote.body.checkoutToken));
  if (!payment.response.ok) return payment;
  return requestJSON("/gifts/books", post({
    quoteID: giftQuote.body.id,
    paymentIntentID: payment.body.id,
    contactEmail: "giver@example.com",
    selectedShippingOptionID: giftQuote.body.shippingOptions[0].id,
    senderName: "Giver",
    recipientName: "Reader",
    message: `${editionKind} ${variant.id}`,
  }, giftQuote.body.checkoutToken));
}

async function requestJSON(path, init) {
  const response = await worker.fetch(new Request(`https://example.test${path}`, init), env);
  return { response, body: await response.json() };
}

async function digestHex(bytes) {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function openDeliveryEnvelope(envelope, claimToken) {
  const keyMaterial = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(claimToken));
  const key = await crypto.subtle.importKey("raw", keyMaterial, { name: "AES-GCM" }, false, ["decrypt"]);
  const nonce = fromBase64URL(envelope.nonce);
  const sealed = fromBase64URL(envelope.sealedAddress);
  const clear = await crypto.subtle.decrypt({
    name: "AES-GCM",
    iv: nonce,
    additionalData: new TextEncoder().encode("reenchanted-gift-address-v1"),
  }, key, sealed);
  return JSON.parse(new TextDecoder().decode(clear));
}

function fromBase64URL(value) {
  const base64 = value.replace(/-/g, "+").replace(/_/g, "/");
  return Uint8Array.from(atob(base64), (character) => character.charCodeAt(0));
}

function json(body) {
  return new Response(JSON.stringify(body), { status: 200, headers: { "Content-Type": "application/json" } });
}
