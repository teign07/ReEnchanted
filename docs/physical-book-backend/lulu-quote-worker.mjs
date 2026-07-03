const DEFAULT_SHIPPING_LEVELS = [
  { id: "MAIL", displayName: "Mail", estimatedDaysMin: 5, estimatedDaysMax: 10 },
  { id: "PRIORITY_MAIL", displayName: "Priority Mail", estimatedDaysMin: 3, estimatedDaysMax: 5 },
  { id: "EXPRESS", displayName: "Express", estimatedDaysMin: 1, estimatedDaysMax: 3 },
];

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return corsResponse(null, { status: 204 });
    }

    try {
      return await routeRequest(request, env);
    } catch (error) {
      if (error instanceof HTTPError) {
        return jsonResponse(
          { error: error.code, message: error.message },
          { status: error.status },
        );
      }
      return jsonResponse(
        { error: "physical_book_request_failed", message: error instanceof Error ? error.message : String(error) },
        { status: 400 },
      );
    }
  },
};

async function routeRequest(request, env) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";

  if ((path === "/" || path === "/quote" || path === "/api/physical-books/quote") && request.method === "POST") {
    return jsonResponse(await createQuote(await request.json(), env));
  }

  if ((path === "/health" || path === "/api/physical-books/health") && request.method === "GET") {
    return jsonResponse(healthCheck(env));
  }

  if ((path === "/orders" || path === "/api/physical-books/orders") && request.method === "POST") {
    requireAPIToken(request, env);
    return jsonResponse(await createOrder(await request.json(), env), { status: 201 });
  }

  if ((path === "/orders/preview" || path === "/api/physical-books/orders/preview") && request.method === "POST") {
    requireAPIToken(request, env);
    return jsonResponse(await previewOrder(await request.json(), env));
  }

  const uploadMatch = path.match(/^\/(?:api\/physical-books\/)?print-files\/(interior|cover)$/);
  if (uploadMatch && request.method === "POST") {
    requireAPIToken(request, env);
    return jsonResponse(await uploadPrintFile(request, env, uploadMatch[1]), { status: 201 });
  }

  if (
    (path === "/payment-intents" || path === "/api/physical-books/payment-intents") &&
    request.method === "POST"
  ) {
    requireAPIToken(request, env);
    return jsonResponse(await createPaymentIntent(await request.json(), env), { status: 201 });
  }

  const orderMatch = path.match(/^\/(?:api\/physical-books\/)?orders\/([^/]+)$/);
  if (orderMatch && request.method === "GET") {
    requireAPIToken(request, env);
    return jsonResponse(await getOrderStatus(orderMatch[1], env));
  }

  return jsonResponse({ error: "not_found" }, { status: 404 });
}

function healthCheck(env) {
  const luluCredentialsConfigured = Boolean(env.LULU_AUTH_URL && env.LULU_API_BASE_URL && env.LULU_CLIENT_KEY && env.LULU_CLIENT_SECRET);
  const stripeConfigured = Boolean(env.STRIPE_SECRET_KEY);
  const apiTokenConfigured = Boolean(env.PHYSICAL_BOOK_API_TOKEN);
  const publicPrintFileBaseURLConfigured = Boolean(env.PUBLIC_PRINT_FILE_BASE_URL);
  const r2Configured = Boolean(env.PHYSICAL_BOOK_FILES);
  const orderStorageConfigured = Boolean(env.PHYSICAL_BOOK_ORDERS);
  const productionReady = luluCredentialsConfigured &&
    stripeConfigured &&
    apiTokenConfigured &&
    publicPrintFileBaseURLConfigured &&
    r2Configured &&
    orderStorageConfigured;

  return {
    ok: true,
    productionReady,
    checks: {
      luluCredentialsConfigured,
      stripeConfigured,
      apiTokenConfigured,
      publicPrintFileBaseURLConfigured,
      r2Configured,
      orderStorageConfigured,
    },
    shippingLevels: configuredShippingLevels(env).map((level) => ({
      id: level.id,
      displayName: level.displayName,
      estimatedDaysMin: level.estimatedDaysMin,
      estimatedDaysMax: level.estimatedDaysMax,
    })),
  };
}

async function createQuote(quoteRequest, env) {
  validateQuoteRequest(quoteRequest);

  const token = await fetchLuluAccessToken(env);
  const quoteRequestWithCity = {
    ...quoteRequest,
    shipTo: {
      ...quoteRequest.shipTo,
      city: quoteRequest.shipTo.city || await lookupCityFromPostalCode(env, quoteRequest.shipTo),
    },
  };
  const shippingLevels = configuredShippingLevels(env);
  const luluQuotes = await Promise.all(
    shippingLevels.map((level) => fetchLuluCost(env, token, quoteRequestWithCity, level.id)),
  );

  const shippingOptions = luluQuotes.map((quote, index) => {
    const level = shippingLevels[index];
    return {
      id: level.id,
      displayName: level.displayName,
      estimatedDaysMin: level.estimatedDaysMin,
      estimatedDaysMax: level.estimatedDaysMax,
      price: {
        currencyCode: quoteRequest.currencyCode || "USD",
        cents: moneyToCents(readLuluMoney(quote, ["shipping_cost", "shippingCost", "shipping"])),
      },
    };
  });

  const manufacturingCents = moneyToCents(
    readLuluMoney(luluQuotes[0], ["print_cost", "printCost", "manufacturing_cost", "manufacturingCost"]),
  );

  return {
    id: crypto.randomUUID(),
    request: quoteRequestWithCity,
    manufacturingSubtotal: {
      currencyCode: quoteRequest.currencyCode || "USD",
      cents: manufacturingCents,
    },
    shippingOptions,
    pricingPolicy: standardPricingPolicy(),
    expiresAt: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
  };
}

async function createPaymentIntent(paymentRequest, env) {
  validatePaymentIntentRequest(paymentRequest);
  const amount = priceBreakdown(
    paymentRequest.quoteRequest,
    paymentRequest.selectedShippingOption.price.cents,
    0,
    standardPricingPolicy(),
  ).total;
  const stripePaymentIntent = await fetchStripePaymentIntentCreate(env, {
    amount: amount.cents,
    currency: amount.currencyCode.toLowerCase(),
    receipt_email: paymentRequest.contactEmail,
    metadata: {
      quote_id: paymentRequest.quoteID,
      edition_id: paymentRequest.quoteRequest.editionID,
      variant_id: paymentRequest.quoteRequest.variant.id,
      lulu_package_id: paymentRequest.quoteRequest.variant.luluPackageID,
      shipping_option_id: paymentRequest.selectedShippingOption.id,
    },
  });

  return {
    id: stripePaymentIntent.id,
    clientSecret: stripePaymentIntent.client_secret,
    amount,
    quoteID: paymentRequest.quoteID,
    selectedShippingOptionID: paymentRequest.selectedShippingOption.id,
  };
}

async function createOrder(orderRequest, env) {
  validateOrderRequest(orderRequest);
  const storageKey = orderStorageKey(orderRequest);
  const storedOrder = await readStoredOrder(env, storageKey);
  if (storedOrder) {
    return storedOrder;
  }

  await verifyPaidPaymentIntent(orderRequest, env);

  const token = await fetchLuluAccessToken(env);
  const luluPayload = toLuluPrintJobPayload(orderRequest);
  const luluPrintJob = await fetchLuluPrintJobCreate(env, token, luluPayload);

  const order = {
    id: orderRequest.quoteID,
    quoteID: orderRequest.quoteID,
    luluPrintJobID: String(luluPrintJob.id ?? luluPrintJob.print_job_id ?? luluPrintJob.url ?? ""),
    status: mapLuluPrintJobStatus(luluPrintJob.status?.name),
    trackingURL: luluPrintJob.tracking_url ?? null,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  await storeOrder(env, storageKey, order);
  return order;
}

async function previewOrder(orderRequest, env) {
  validateOrderRequest(orderRequest);
  const luluPayload = toLuluPrintJobPayload(orderRequest);

  return {
    mode: "preview",
    quoteID: orderRequest.quoteID,
    luluPrintJobPayload: luluPayload,
  };
}

async function uploadPrintFile(request, env, kind) {
  requireEnv(env, "PUBLIC_PRINT_FILE_BASE_URL");
  if (!env.PHYSICAL_BOOK_FILES) {
    throw new Error("PHYSICAL_BOOK_FILES R2 binding is not configured");
  }

  const editionID = requiredHeader(request, "X-Edition-ID");
  const sourceMD5 = requiredHeader(request, "X-Source-MD5").toLowerCase();
  if (!isMD5(sourceMD5)) {
    throw new Error("X-Source-MD5 must be a 32-character hex MD5");
  }

  const contentType = request.headers.get("Content-Type") || "application/pdf";
  if (contentType !== "application/pdf") {
    throw new Error("Print-file uploads must use Content-Type: application/pdf");
  }

  const body = await request.arrayBuffer();
  if (body.byteLength === 0) {
    throw new Error("Uploaded PDF is empty");
  }
  const maxBytes = Number(env.MAX_PRINT_FILE_BYTES || 100 * 1024 * 1024);
  if (body.byteLength > maxBytes) {
    throw new Error(`Uploaded PDF exceeds MAX_PRINT_FILE_BYTES (${maxBytes})`);
  }

  const key = [
    "physical-books",
    sanitizeObjectPathSegment(editionID),
    `${kind}-${sourceMD5}.pdf`,
  ].join("/");
  await env.PHYSICAL_BOOK_FILES.put(key, body, {
    httpMetadata: {
      contentType: "application/pdf",
    },
    customMetadata: {
      editionID,
      kind,
      sourceMD5,
    },
  });

  return {
    kind,
    sourceURL: `${env.PUBLIC_PRINT_FILE_BASE_URL.replace(/\/+$/, "")}/${key}`,
    md5: sourceMD5,
    byteCount: body.byteLength,
  };
}

async function getOrderStatus(printJobID, env) {
  const token = await fetchLuluAccessToken(env);
  const luluPrintJob = await fetchLuluPrintJobStatus(env, token, printJobID);
  return {
    id: printJobID,
    quoteID: "",
    luluPrintJobID: printJobID,
    status: mapLuluPrintJobStatus(luluPrintJob.status?.name),
    trackingURL: luluPrintJob.tracking_url ?? null,
    createdAt: luluPrintJob.created ?? new Date().toISOString(),
    updatedAt: luluPrintJob.status?.changed ?? new Date().toISOString(),
  };
}

async function fetchLuluAccessToken(env) {
  requireEnv(env, "LULU_AUTH_URL");
  requireEnv(env, "LULU_CLIENT_KEY");
  requireEnv(env, "LULU_CLIENT_SECRET");

  const credentials = btoa(`${env.LULU_CLIENT_KEY}:${env.LULU_CLIENT_SECRET}`);
  const response = await fetch(env.LULU_AUTH_URL, {
    method: "POST",
    headers: {
      Authorization: `Basic ${credentials}`,
      "Content-Type": "application/x-www-form-urlencoded",
      Accept: "application/json",
    },
    body: new URLSearchParams({ grant_type: "client_credentials" }).toString(),
  });

  if (!response.ok) {
    throw new Error(`Lulu auth failed with HTTP ${response.status}`);
  }
  const body = await response.json();
  if (!body.access_token) {
    throw new Error("Lulu auth response did not include access_token");
  }
  return body.access_token;
}

async function fetchLuluCost(env, token, quoteRequest, shippingLevel) {
  requireEnv(env, "LULU_API_BASE_URL");
  if (!quoteRequest.shipTo.street1) {
    throw new Error("shipTo.street1 is required for Lulu cost quotes");
  }
  if (!quoteRequest.shipTo.phoneNumber) {
    throw new Error("shipTo.phoneNumber is required for Lulu cost quotes");
  }
  const response = await fetch(`${env.LULU_API_BASE_URL}/print-job-cost-calculations/`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({
      line_items: [
        {
          pod_package_id: quoteRequest.variant.luluPackageID,
          page_count: quoteRequest.pageCount,
          quantity: quoteRequest.quantity || 1,
        },
      ],
      shipping_address: {
        city: quoteRequest.shipTo.city,
        street1: quoteRequest.shipTo.street1,
        street2: quoteRequest.shipTo.street2 || undefined,
        country_code: quoteRequest.shipTo.countryCode,
        state_code: quoteRequest.shipTo.stateCode || undefined,
        postcode: quoteRequest.shipTo.postalCode,
        phone_number: quoteRequest.shipTo.phoneNumber,
      },
      shipping_level: shippingLevel,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Lulu cost quote failed with HTTP ${response.status}: ${body.slice(0, 300)}`);
  }
  return response.json();
}

async function lookupCityFromPostalCode(env, shipTo) {
  const countryCode = String(shipTo.countryCode || "").trim().toLowerCase();
  const postalCode = String(shipTo.postalCode || "").trim();
  if (!countryCode || !postalCode) {
    throw new Error("shipTo.countryCode and shipTo.postalCode are required for city lookup");
  }

  try {
    const baseURL = env.ZIP_CITY_LOOKUP_BASE_URL || "https://api.zippopotam.us";
    const response = await fetch(`${baseURL}/${encodeURIComponent(countryCode)}/${encodeURIComponent(postalCode)}`, {
      headers: { Accept: "application/json" },
    });
    if (!response.ok) {
      throw new Error(`city lookup returned HTTP ${response.status}`);
    }
    const body = await response.json();
    const place = Array.isArray(body.places) ? body.places[0] : null;
    const city = place?.["place name"] || place?.placeName;
    if (!city) {
      throw new Error("city lookup did not return a city");
    }
    return city;
  } catch (error) {
    throw new Error(`Could not resolve city from ZIP/postal code: ${error instanceof Error ? error.message : String(error)}`);
  }
}

async function fetchStripePaymentIntentCreate(env, fields) {
  requireEnv(env, "STRIPE_SECRET_KEY");
  const response = await fetch("https://api.stripe.com/v1/payment_intents", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.STRIPE_SECRET_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
      Accept: "application/json",
    },
    body: stripeFormBody({
      amount: fields.amount,
      currency: fields.currency,
      receipt_email: fields.receipt_email,
      "automatic_payment_methods[enabled]": "true",
      ...Object.fromEntries(
        Object.entries(fields.metadata || {}).map(([key, value]) => [`metadata[${key}]`, value]),
      ),
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Stripe payment intent failed with HTTP ${response.status}: ${body.slice(0, 300)}`);
  }
  return response.json();
}

async function fetchStripePaymentIntent(env, paymentIntentID) {
  requireEnv(env, "STRIPE_SECRET_KEY");
  const response = await fetch(`https://api.stripe.com/v1/payment_intents/${encodeURIComponent(paymentIntentID)}`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${env.STRIPE_SECRET_KEY}`,
      Accept: "application/json",
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Stripe payment intent lookup failed with HTTP ${response.status}: ${body.slice(0, 300)}`);
  }
  return response.json();
}

async function fetchLuluPrintJobCreate(env, token, luluPayload) {
  requireEnv(env, "LULU_API_BASE_URL");
  const response = await fetch(`${env.LULU_API_BASE_URL}/print-jobs/`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify(luluPayload),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Lulu print-job create failed with HTTP ${response.status}: ${body.slice(0, 300)}`);
  }
  return response.json();
}

async function fetchLuluPrintJobStatus(env, token, printJobID) {
  requireEnv(env, "LULU_API_BASE_URL");
  const response = await fetch(`${env.LULU_API_BASE_URL}/print-jobs/${encodeURIComponent(printJobID)}/`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Lulu print-job status failed with HTTP ${response.status}: ${body.slice(0, 300)}`);
  }
  return response.json();
}

function configuredShippingLevels(env) {
  if (!env.LULU_SHIPPING_LEVELS_JSON) {
    return DEFAULT_SHIPPING_LEVELS;
  }
  const parsed = JSON.parse(env.LULU_SHIPPING_LEVELS_JSON);
  if (!Array.isArray(parsed) || parsed.length === 0) {
    throw new Error("LULU_SHIPPING_LEVELS_JSON must be a non-empty array");
  }
  return parsed;
}

function readLuluMoney(body, keys) {
  for (const key of keys) {
    const value = findNestedValue(body, key);
    if (value != null) {
      return value;
    }
  }
  const lineItemCosts = body?.line_item_costs ?? body?.lineItemCosts ?? body?.line_items ?? body?.lineItems;
  if (Array.isArray(lineItemCosts) && keys.some((key) => key.includes("print") || key.includes("manufacturing"))) {
    const lineItemTotal = lineItemCosts
      .map((item) => normalizeMoney(item?.total_cost_excl_tax ?? item?.totalCostExclTax ?? item?.total_cost_incl_tax ?? item?.totalCostInclTax ?? item))
      .reduce((sum, amount) => sum + amount, 0);
    if (Number.isFinite(lineItemTotal) && lineItemTotal > 0) {
      return lineItemTotal;
    }
  }
  const totalCost = body?.total_cost_excl_tax ?? body?.totalCostExclTax ?? body?.total_cost_incl_tax ?? body?.totalCostInclTax;
  const shippingCost = findNestedValue(body, "shipping_cost") ?? findNestedValue(body, "shippingCost") ?? findNestedValue(body, "shipping");
  if (totalCost != null && shippingCost != null && keys.some((key) => key.includes("print") || key.includes("manufacturing"))) {
    return normalizeMoney(totalCost) - normalizeMoney(shippingCost);
  }
  throw new Error(`Could not find expected money field in Lulu response: ${JSON.stringify(body).slice(0, 300)}`);
}

function moneyToCents(value) {
  const amount = normalizeMoney(value);
  if (!Number.isFinite(amount)) {
    throw new Error(`Could not parse Lulu money value: ${JSON.stringify(value).slice(0, 120)}`);
  }
  return Math.round(amount * 100);
}

function normalizeMoney(value) {
  if (typeof value === "object" && value !== null && "amount" in value) {
    return Number(value.amount);
  }
  if (typeof value === "object" && value !== null) {
    const nestedAmount = value.total_cost_excl_tax ??
      value.totalCostExclTax ??
      value.total_cost_incl_tax ??
      value.totalCostInclTax ??
      value.cost_excl_tax ??
      value.costExclTax ??
      value.value;
    if (nestedAmount != null) {
      return normalizeMoney(nestedAmount);
    }
  }
  return Number(value);
}

function findNestedValue(value, key) {
  if (value == null || typeof value !== "object") {
    return undefined;
  }
  if (Object.prototype.hasOwnProperty.call(value, key)) {
    return value[key];
  }
  if (Array.isArray(value)) {
    for (const item of value) {
      const found = findNestedValue(item, key);
      if (found !== undefined) {
        return found;
      }
    }
    return undefined;
  }
  for (const item of Object.values(value)) {
    const found = findNestedValue(item, key);
    if (found !== undefined) {
      return found;
    }
  }
  return undefined;
}

function validateQuoteRequest(request) {
  if (!request?.editionID) throw new Error("editionID is required");
  if (!request?.variant?.luluPackageID) throw new Error("variant.luluPackageID is required");
  if (!Number.isInteger(request.pageCount) || request.pageCount <= 0) throw new Error("pageCount must be positive");
  if (!request?.shipTo?.countryCode) throw new Error("shipTo.countryCode is required");
  if (!request?.shipTo?.postalCode) throw new Error("shipTo.postalCode is required");
}

function validateOrderRequest(request) {
  if (!request?.quoteID) throw new Error("quoteID is required");
  if (!request?.paymentIntentID) throw new Error("paymentIntentID is required");
  if (!request?.contactEmail) throw new Error("contactEmail is required");
  if (!request?.selectedShippingOptionID) throw new Error("selectedShippingOptionID is required");
  if (!request?.selectedShippingOption?.id) throw new Error("selectedShippingOption.id is required");
  if (request.selectedShippingOption.id !== request.selectedShippingOptionID) {
    throw new Error("selectedShippingOption.id must match selectedShippingOptionID");
  }
  if (!Number.isInteger(request.selectedShippingOption?.price?.cents)) {
    throw new Error("selectedShippingOption.price.cents is required");
  }
  if (!request?.shippingAddress?.name) throw new Error("shippingAddress.name is required");
  if (!request?.shippingAddress?.street1) throw new Error("shippingAddress.street1 is required");
  if (!request?.shippingAddress?.city) throw new Error("shippingAddress.city is required");
  if (!request?.shippingAddress?.countryCode) throw new Error("shippingAddress.countryCode is required");
  if (!request?.shippingAddress?.postalCode) throw new Error("shippingAddress.postalCode is required");
  if (!request?.printFiles?.interiorSourceURL) throw new Error("printFiles.interiorSourceURL is required");
  if (!isURLLike(request.printFiles.interiorSourceURL)) throw new Error("printFiles.interiorSourceURL must be a URL");
  if (!isMD5(request.printFiles.interiorMD5)) throw new Error("printFiles.interiorMD5 must be a 32-character hex MD5");
  if (!request?.printFiles?.coverSourceURL) throw new Error("printFiles.coverSourceURL is required");
  if (!isURLLike(request.printFiles.coverSourceURL)) throw new Error("printFiles.coverSourceURL must be a URL");
  if (!isMD5(request.printFiles.coverMD5)) throw new Error("printFiles.coverMD5 must be a 32-character hex MD5");
}

function isURLLike(value) {
  try {
    const url = new URL(String(value));
    return url.protocol === "https:" || url.protocol === "http:";
  } catch {
    return false;
  }
}

function isMD5(value) {
  return /^[a-fA-F0-9]{32}$/.test(String(value || ""));
}

function requiredHeader(request, name) {
  const value = request.headers.get(name);
  if (!value) {
    throw new Error(`${name} header is required`);
  }
  return value;
}

function sanitizeObjectPathSegment(value) {
  return String(value || "")
    .trim()
    .replace(/[^a-zA-Z0-9._-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 96) || "unknown";
}

function orderStorageKey(orderRequest) {
  return `physical-book-orders/${sanitizeObjectPathSegment(orderRequest.paymentIntentID)}`;
}

async function readStoredOrder(env, key) {
  if (!env.PHYSICAL_BOOK_ORDERS) {
    return null;
  }
  const stored = await env.PHYSICAL_BOOK_ORDERS.get(key);
  if (!stored) {
    return null;
  }
  return JSON.parse(stored);
}

async function storeOrder(env, key, order) {
  if (!env.PHYSICAL_BOOK_ORDERS) {
    return;
  }
  await env.PHYSICAL_BOOK_ORDERS.put(key, JSON.stringify(order), {
    metadata: {
      quoteID: order.quoteID,
      luluPrintJobID: order.luluPrintJobID,
      status: order.status,
    },
  });
}

function validatePaymentIntentRequest(request) {
  if (!request?.quoteID) throw new Error("quoteID is required");
  if (!request?.quoteRequest) throw new Error("quoteRequest is required");
  validateQuoteRequest(request.quoteRequest);
  if (!request?.selectedShippingOption?.id) throw new Error("selectedShippingOption.id is required");
  if (!Number.isInteger(request.selectedShippingOption?.price?.cents)) {
    throw new Error("selectedShippingOption.price.cents is required");
  }
  if (!request?.contactEmail) throw new Error("contactEmail is required");
}

async function verifyPaidPaymentIntent(orderRequest, env) {
  const stripePaymentIntent = await fetchStripePaymentIntent(env, orderRequest.paymentIntentID);
  if (stripePaymentIntent.status !== "succeeded") {
    throw new HTTPError(402, "payment_not_captured", "PaymentIntent has not succeeded.");
  }

  const expectedTotal = expectedOrderTotal(orderRequest);
  if (Number(stripePaymentIntent.amount) !== expectedTotal.cents) {
    throw new HTTPError(409, "payment_amount_mismatch", "PaymentIntent amount does not match the order total.");
  }
  if (String(stripePaymentIntent.currency || "").toUpperCase() !== expectedTotal.currencyCode.toUpperCase()) {
    throw new HTTPError(409, "payment_currency_mismatch", "PaymentIntent currency does not match the order currency.");
  }

  const metadata = stripePaymentIntent.metadata || {};
  if (metadata.quote_id !== orderRequest.quoteID) {
    throw new HTTPError(409, "payment_quote_mismatch", "PaymentIntent quote metadata does not match the order.");
  }
  if (metadata.edition_id !== orderRequest.quoteRequest.editionID) {
    throw new HTTPError(409, "payment_edition_mismatch", "PaymentIntent edition metadata does not match the order.");
  }
  if (metadata.variant_id !== orderRequest.quoteRequest.variant.id) {
    throw new HTTPError(409, "payment_variant_mismatch", "PaymentIntent variant metadata does not match the order.");
  }
  if (metadata.lulu_package_id !== orderRequest.quoteRequest.variant.luluPackageID) {
    throw new HTTPError(409, "payment_package_mismatch", "PaymentIntent package metadata does not match the order.");
  }
  if (metadata.shipping_option_id !== orderRequest.selectedShippingOptionID) {
    throw new HTTPError(409, "payment_shipping_mismatch", "PaymentIntent shipping metadata does not match the order.");
  }
}

function expectedOrderTotal(orderRequest) {
  const shippingCents = orderRequest.selectedShippingOption.price.cents;
  return priceBreakdown(orderRequest.quoteRequest, shippingCents, 0, standardPricingPolicy()).total;
}

function toLuluPrintJobPayload(orderRequest) {
  const quoteRequest = orderRequest.quoteRequest;
  if (!quoteRequest) {
    throw new Error("quoteRequest is required to create a Lulu print job");
  }
  validateQuoteRequest(quoteRequest);

  return {
    external_id: orderRequest.quoteID,
    contact_email: orderRequest.contactEmail,
    shipping_level: orderRequest.selectedShippingOptionID,
    line_items: [
      {
        external_id: `${orderRequest.quoteID}-item-1`,
        pod_package_id: quoteRequest.variant.luluPackageID,
        quantity: quoteRequest.quantity || 1,
        interior: {
          source_url: orderRequest.printFiles.interiorSourceURL,
          source_md5sum: orderRequest.printFiles.interiorMD5,
        },
        cover: {
          source_url: orderRequest.printFiles.coverSourceURL,
          source_md5sum: orderRequest.printFiles.coverMD5,
        },
      },
    ],
    shipping_address: {
      name: orderRequest.shippingAddress.name,
      street1: orderRequest.shippingAddress.street1,
      street2: orderRequest.shippingAddress.street2 || undefined,
      city: orderRequest.shippingAddress.city,
      state_code: orderRequest.shippingAddress.stateCode || undefined,
      country_code: orderRequest.shippingAddress.countryCode,
      postcode: orderRequest.shippingAddress.postalCode,
      phone_number: orderRequest.shippingAddress.phoneNumber || undefined,
    },
  };
}

function mapLuluPrintJobStatus(name) {
  switch (name) {
    case "CREATED":
    case "UNPAID":
      return "paymentPending";
    case "PRODUCTION_READY":
    case "IN_PRODUCTION":
      return "submittedToLulu";
    case "SHIPPED":
      return "shipped";
    case "REJECTED":
    case "CANCELED":
    case "CANCELLED":
      return "failed";
    default:
      return "submittedToLulu";
  }
}

function standardPricingPolicy() {
  return {
    markupPerCopyCents: 1200,
    paymentFeeBasisPoints: 290,
    paymentFeeFixedCents: 30,
  };
}

function priceBreakdown(quoteRequest, shippingCents, estimatedTaxCents = 0, policy = standardPricingPolicy()) {
  const manufacturing = rawManufacturingSubtotalCents(
    quoteRequest.variant,
    quoteRequest.pageCount,
    quoteRequest.quantity || 1,
  );
  const markup = policy.markupPerCopyCents * Math.max(0, quoteRequest.quantity || 1);
  const subtotalBeforeProcessing = manufacturing + shippingCents + estimatedTaxCents + markup;
  const processing = paymentProcessingFeeCents(subtotalBeforeProcessing, policy);
  const currencyCode = quoteRequest.currencyCode || "USD";
  return {
    manufacturingSubtotal: { currencyCode, cents: manufacturing },
    shipping: { currencyCode, cents: shippingCents },
    estimatedTax: { currencyCode, cents: estimatedTaxCents },
    markup: { currencyCode, cents: markup },
    paymentProcessingFee: { currencyCode, cents: processing },
    total: { currencyCode, cents: subtotalBeforeProcessing + processing },
  };
}

function rawManufacturingSubtotalCents(variant, pageCount, quantity) {
  const perCopyTenThousandths =
    variant.manufacturingBasePriceCentsUSD * 100 + pageCount * variant.manufacturingPerPagePriceTenThousandthsUSD;
  const perCopyCents = Math.floor((perCopyTenThousandths + 50) / 100);
  return perCopyCents * Math.max(0, quantity);
}

function paymentProcessingFeeCents(chargeSubtotalCents, policy = standardPricingPolicy()) {
  if (chargeSubtotalCents <= 0) return 0;
  const denominator = 10000 - policy.paymentFeeBasisPoints;
  if (denominator <= 0) return policy.paymentFeeFixedCents;
  const grossTotal = Math.floor(
    ((chargeSubtotalCents + policy.paymentFeeFixedCents) * 10000 + denominator - 1) / denominator,
  );
  return grossTotal - chargeSubtotalCents;
}

function stripeFormBody(fields) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(fields)) {
    if (value !== undefined && value !== null && value !== "") {
      params.set(key, String(value));
    }
  }
  return params.toString();
}

function requireEnv(env, key) {
  if (!env?.[key]) {
    throw new Error(`${key} is not configured`);
  }
}

class HTTPError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function requireAPIToken(request, env) {
  if (!env?.PHYSICAL_BOOK_API_TOKEN) {
    return;
  }
  const header = request.headers.get("Authorization") || "";
  const expected = `Bearer ${env.PHYSICAL_BOOK_API_TOKEN}`;
  if (header !== expected) {
    throw new HTTPError(401, "unauthorized", "A valid physical book API token is required.");
  }
}

function jsonResponse(body, init = {}) {
  return corsResponse(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init.headers || {}),
    },
  });
}

function corsResponse(body, init = {}) {
  return new Response(body, {
    ...init,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Edition-ID, X-Source-MD5",
      ...(init.headers || {}),
    },
  });
}
