import worker from "./lulu-quote-worker.mjs";

const orderRequest = {
  quoteID: "quote-123",
  quoteRequest: {
    apiVersion: 1,
    editionID: "edition-2026-06",
    variant: {
      id: "cloth-foil-hardcover-6x9",
      displayName: "Cloth foil hardcover",
      luluPackageID: "0600X0900.FC.STD.LW.060UW444.MNG",
      coverTreatment: "linenWrap",
      manufacturingBasePriceCentsUSD: 1441,
      manufacturingPerPagePriceTenThousandthsUSD: 425,
    },
    pageCount: 120,
    quantity: 1,
    shipTo: {
      countryCode: "US",
      stateCode: "ME",
      postalCode: "04915",
    },
    currencyCode: "USD",
  },
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
  selectedShippingOption: {
    id: "MAIL",
    displayName: "Mail",
    estimatedDaysMin: 5,
    estimatedDaysMax: 10,
    price: {
      currencyCode: "USD",
      cents: 799,
    },
  },
  printFiles: {
    interiorSourceURL: "https://cdn.example.com/interior.pdf",
    interiorMD5: "0123456789abcdef0123456789abcdef",
    coverSourceURL: "https://cdn.example.com/cover.pdf",
    coverMD5: "abcdef0123456789abcdef0123456789",
  },
};

const healthResponse = await worker.fetch(
  new Request("https://example.test/health", { method: "GET" }),
  {},
);
if (!healthResponse.ok) {
  throw new Error(`Health request failed with HTTP ${healthResponse.status}: ${await healthResponse.text()}`);
}
const health = await healthResponse.json();
assertEqual(health.ok, true, "health.ok");
assertEqual(health.productionReady, false, "health.productionReady without config");
assertEqual(health.checks.luluCredentialsConfigured, false, "health.luluCredentialsConfigured without config");

const productionHealthResponse = await worker.fetch(
  new Request("https://example.test/api/physical-books/health", { method: "GET" }),
  {
    LULU_CLIENT_KEY: "lulu-client",
    LULU_CLIENT_SECRET: "lulu-secret",
    LULU_AUTH_URL: "https://lulu.test/auth",
    LULU_API_BASE_URL: "https://lulu.test",
    STRIPE_SECRET_KEY: "sk_test_mock",
    PHYSICAL_BOOK_API_TOKEN: "test-token",
    PUBLIC_PRINT_FILE_BASE_URL: "https://files.example.com",
    PHYSICAL_BOOK_FILES: {},
    PHYSICAL_BOOK_ORDERS: {},
  },
);
if (!productionHealthResponse.ok) {
  throw new Error(`Production health request failed with HTTP ${productionHealthResponse.status}: ${await productionHealthResponse.text()}`);
}
const productionHealth = await productionHealthResponse.json();
assertEqual(productionHealth.productionReady, true, "health.productionReady with config");
assertEqual(productionHealth.checks.orderStorageConfigured, true, "health.orderStorageConfigured with config");

console.log("Health smoke test passed.");

const response = await worker.fetch(
  new Request("https://example.test/orders/preview", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer test-token",
    },
    body: JSON.stringify(orderRequest),
  }),
  { PHYSICAL_BOOK_API_TOKEN: "test-token" },
);

if (!response.ok) {
  throw new Error(`Preview request failed with HTTP ${response.status}: ${await response.text()}`);
}

const body = await response.json();
const payload = body.luluPrintJobPayload;

assertEqual(body.mode, "preview", "mode");
assertEqual(payload.external_id, "quote-123", "external_id");
assertEqual(payload.contact_email, "reader@example.com", "contact_email");
assertEqual(payload.shipping_level, "MAIL", "shipping_level");
assertEqual(payload.line_items[0].pod_package_id, "0600X0900.FC.STD.LW.060UW444.MNG", "pod_package_id");
assertEqual(payload.line_items[0].interior.source_url, "https://cdn.example.com/interior.pdf", "interior.source_url");
assertEqual(payload.line_items[0].interior.source_md5sum, "0123456789abcdef0123456789abcdef", "interior.source_md5sum");
assertEqual(payload.line_items[0].cover.source_url, "https://cdn.example.com/cover.pdf", "cover.source_url");
assertEqual(payload.line_items[0].cover.source_md5sum, "abcdef0123456789abcdef0123456789", "cover.source_md5sum");
assertEqual(payload.shipping_address.postcode, "04915", "shipping_address.postcode");

console.log("Order preview smoke test passed.");

const unauthorizedResponse = await worker.fetch(
  new Request("https://example.test/orders/preview", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(orderRequest),
  }),
  { PHYSICAL_BOOK_API_TOKEN: "test-token" },
);

assertEqual(unauthorizedResponse.status, 401, "unauthorized.status");

console.log("Protected endpoint auth smoke test passed.");

const putCalls = [];
const uploadResponse = await worker.fetch(
  new Request("https://example.test/print-files/interior", {
    method: "POST",
    headers: {
      "Content-Type": "application/pdf",
      Authorization: "Bearer test-token",
      "X-Edition-ID": "edition-2026-06",
      "X-Source-MD5": "0123456789abcdef0123456789abcdef",
    },
    body: new Uint8Array([0x25, 0x50, 0x44, 0x46]),
  }),
  {
    PHYSICAL_BOOK_API_TOKEN: "test-token",
    PUBLIC_PRINT_FILE_BASE_URL: "https://files.example.com",
    PHYSICAL_BOOK_FILES: {
      async put(key, body, options) {
        putCalls.push({ key, body, options });
      },
    },
  },
);

if (!uploadResponse.ok) {
  throw new Error(`Upload request failed with HTTP ${uploadResponse.status}: ${await uploadResponse.text()}`);
}

const upload = await uploadResponse.json();
assertEqual(upload.kind, "interior", "upload.kind");
assertEqual(upload.md5, "0123456789abcdef0123456789abcdef", "upload.md5");
assertEqual(upload.sourceURL, "https://files.example.com/physical-books/edition-2026-06/interior-0123456789abcdef0123456789abcdef.pdf", "upload.sourceURL");
assertEqual(upload.byteCount, 4, "upload.byteCount");
assertEqual(putCalls[0].key, "physical-books/edition-2026-06/interior-0123456789abcdef0123456789abcdef.pdf", "r2.key");

console.log("Print-file upload smoke test passed.");

const originalFetch = globalThis.fetch;
const externalCalls = [];
const storedOrders = new Map();
const fakeKV = {
  async get(key) {
    return storedOrders.get(key) ?? null;
  },
  async put(key, value) {
    storedOrders.set(key, value);
  },
};
globalThis.fetch = async (url, init) => {
  externalCalls.push({ url: String(url), init });
  const urlString = String(url);
  if (urlString.includes("api.stripe.com/v1/payment_intents/pi_123")) {
    return jsonFetchResponse({
      id: "pi_123",
      status: "succeeded",
      amount: 4099,
      currency: "usd",
      metadata: {
        quote_id: "quote-123",
        edition_id: "edition-2026-06",
        variant_id: "cloth-foil-hardcover-6x9",
        lulu_package_id: "0600X0900.FC.STD.LW.060UW444.MNG",
        shipping_option_id: "MAIL",
      },
    });
  }
  if (urlString.includes("lulu.test/auth")) {
    return jsonFetchResponse({ access_token: "lulu-token" });
  }
  if (urlString.includes("lulu.test/print-jobs/print-job-123/")) {
    return jsonFetchResponse({
      id: "print-job-123",
      created: "2026-06-30T00:00:00Z",
      status: { name: "SHIPPED", changed: "2026-07-02T12:00:00Z" },
      tracking_url: "https://tracking.example.com/print-job-123",
    });
  }
  if (urlString.includes("lulu.test/print-jobs/")) {
    return jsonFetchResponse({
      id: "print-job-123",
      status: { name: "PRODUCTION_READY", changed: "2026-06-30T00:00:00Z" },
      tracking_url: null,
    });
  }
  throw new Error(`Unexpected external fetch: ${urlString}`);
};

try {
  const liveOrderResponse = await worker.fetch(
    new Request("https://example.test/orders", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer test-token",
      },
      body: JSON.stringify(orderRequest),
    }),
    {
      PHYSICAL_BOOK_API_TOKEN: "test-token",
      STRIPE_SECRET_KEY: "sk_test_mock",
      LULU_CLIENT_KEY: "lulu-client",
      LULU_CLIENT_SECRET: "lulu-secret",
      LULU_AUTH_URL: "https://lulu.test/auth",
      LULU_API_BASE_URL: "https://lulu.test",
      PHYSICAL_BOOK_ORDERS: fakeKV,
    },
  );

  if (!liveOrderResponse.ok) {
    throw new Error(`Live order request failed with HTTP ${liveOrderResponse.status}: ${await liveOrderResponse.text()}`);
  }
  const liveOrder = await liveOrderResponse.json();
  assertEqual(liveOrder.luluPrintJobID, "print-job-123", "liveOrder.luluPrintJobID");
  assertEqual(liveOrder.status, "submittedToLulu", "liveOrder.status");
  assertEqual(externalCalls.some((call) => call.url.includes("api.stripe.com/v1/payment_intents/pi_123")), true, "stripe lookup called");
  assertEqual(externalCalls.some((call) => call.url.includes("lulu.test/print-jobs/")), true, "lulu print job called");

  const callCountAfterFirstSubmit = externalCalls.length;
  const idempotentOrderResponse = await worker.fetch(
    new Request("https://example.test/orders", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer test-token",
      },
      body: JSON.stringify(orderRequest),
    }),
    {
      PHYSICAL_BOOK_API_TOKEN: "test-token",
      STRIPE_SECRET_KEY: "sk_test_mock",
      LULU_CLIENT_KEY: "lulu-client",
      LULU_CLIENT_SECRET: "lulu-secret",
      LULU_AUTH_URL: "https://lulu.test/auth",
      LULU_API_BASE_URL: "https://lulu.test",
      PHYSICAL_BOOK_ORDERS: fakeKV,
    },
  );

  if (!idempotentOrderResponse.ok) {
    throw new Error(`Idempotent order request failed with HTTP ${idempotentOrderResponse.status}: ${await idempotentOrderResponse.text()}`);
  }
  const idempotentOrder = await idempotentOrderResponse.json();
  assertEqual(idempotentOrder.luluPrintJobID, "print-job-123", "idempotentOrder.luluPrintJobID");
  assertEqual(externalCalls.length, callCountAfterFirstSubmit, "idempotent submit external call count");

  const statusResponse = await worker.fetch(
    new Request("https://example.test/orders/print-job-123", {
      method: "GET",
      headers: {
        Authorization: "Bearer test-token",
      },
    }),
    {
      PHYSICAL_BOOK_API_TOKEN: "test-token",
      LULU_CLIENT_KEY: "lulu-client",
      LULU_CLIENT_SECRET: "lulu-secret",
      LULU_AUTH_URL: "https://lulu.test/auth",
      LULU_API_BASE_URL: "https://lulu.test",
    },
  );

  if (!statusResponse.ok) {
    throw new Error(`Order status request failed with HTTP ${statusResponse.status}: ${await statusResponse.text()}`);
  }
  const statusOrder = await statusResponse.json();
  assertEqual(statusOrder.luluPrintJobID, "print-job-123", "statusOrder.luluPrintJobID");
  assertEqual(statusOrder.status, "shipped", "statusOrder.status");
  assertEqual(statusOrder.trackingURL, "https://tracking.example.com/print-job-123", "statusOrder.trackingURL");

  console.log("Paid live-order smoke test passed.");
} finally {
  globalThis.fetch = originalFetch;
}

function assertEqual(actual, expected, label) {
  if (actual !== expected) {
    throw new Error(`${label}: expected ${expected}, got ${actual}`);
  }
}

function jsonFetchResponse(body, init = {}) {
  return new Response(JSON.stringify(body), {
    status: init.status || 200,
    headers: { "Content-Type": "application/json" },
  });
}
