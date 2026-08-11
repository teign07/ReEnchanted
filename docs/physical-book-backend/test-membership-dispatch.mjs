import { createHash, webcrypto } from "node:crypto";
import worker, { PhysicalBookOrderCoordinator } from "./lulu-quote-worker.mjs";

if (!globalThis.crypto) globalThis.crypto = webcrypto;

const installationID = "test-installation-0001";
const networkID = "203.0.113.10";
const kvValues = new Map();
const r2Values = new Map();
const coordinators = new Map();
let luluCreates = 0;
let coverDimensionRequests = 0;
const luluPayloads = [];
let failures = 0;
let membershipStatus = "active";

const kv = {
  async get(key) { return kvValues.get(key) ?? null; },
  async put(key, value) { kvValues.set(key, value); },
  async delete(key) { kvValues.delete(key); },
  async list() { return { keys: [], list_complete: true }; },
};
const r2 = {
  async put(key, body) { r2Values.set(key, new Uint8Array(body)); },
  async get(key) {
    const body = r2Values.get(key);
    return body ? { body } : null;
  },
};
const env = {
  STRIPE_SECRET_KEY: "sk_test_mock",
  STRIPE_WEBHOOK_SECRET: "whsec_test_mock",
  LULU_CLIENT_KEY: "lulu-client",
  LULU_CLIENT_SECRET: "lulu-secret",
  LULU_AUTH_URL: "https://api.sandbox.lulu.com/auth/realms/glasstree/protocol/openid-connect/token",
  LULU_API_BASE_URL: "https://api.sandbox.lulu.com",
  CHECKOUT_MODE: "test",
  PHYSICAL_BOOK_ORDERING_ENABLED: "true",
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
      coordinators.set(id, new PhysicalBookOrderCoordinator({
        storage: {
          async get(key) { return storage.get(key); },
          async put(key, value) { storage.set(key, value); },
        },
      }, env));
    }
    return { fetch: (url, init) => coordinators.get(id).fetch(new Request(url, init)) };
  },
};

const stripeShipping = {
  name: "Reader Example",
  phone: "207-555-0100",
  address: {
    line1: "1 Harbor St",
    city: "Belfast",
    state: "ME",
    country: "US",
    postal_code: "04915",
  },
};

globalThis.fetch = async (url, init = {}) => {
  const href = String(url);
  if (href.endsWith("/v1/subscriptions/sub_member")) return json({
    id: "sub_member",
    status: membershipStatus,
    customer: "cus_member",
    current_period_end: 1815000000,
    metadata: {
      reenchanted_cadence: "annual",
      reenchanted_physical_fulfillment: "accepted",
      reenchanted_start_month: "2026-08",
    },
  });
  if (href.endsWith("/v1/customers/cus_member")) return json({
    id: "cus_member", email: "reader@example.com", shipping: stripeShipping,
  });
  if (href === env.LULU_AUTH_URL) return json({ access_token: "lulu-token" });
  if (href.endsWith("/cover-dimensions/")) {
    coverDimensionRequests += 1;
    const request = JSON.parse(init.body);
    return json({
      width: request.pod_package_id.includes(".LW.") ? "1192.000" : "910.000",
      height: request.pod_package_id.includes(".CW.") ? "756.000" : "666.000",
      unit: "pt",
    });
  }
  if (href.endsWith("/print-jobs/")) {
    luluCreates += 1;
    luluPayloads.push(JSON.parse(init.body));
    return json({ id: `print-job-${luluCreates}`, status: { name: "PRODUCTION_READY" } });
  }
  throw new Error(`Unexpected request: ${href}`);
};

function json(body) {
  return new Response(JSON.stringify(body), { status: 200, headers: { "Content-Type": "application/json" } });
}
function check(condition, label) {
  if (condition) console.log(`  ok   ${label}`);
  else { failures += 1; console.error(`  FAIL ${label}`); }
}
async function openSession() {
  const response = await worker.fetch(new Request("https://example.test/sessions", {
    method: "POST",
    headers: { "X-Installation-ID": installationID, "CF-Connecting-IP": networkID },
  }), env);
  return (await response.json()).token;
}
function headers(token, extra = {}) {
  return {
    Authorization: `Bearer ${token}`,
    "X-Installation-ID": installationID,
    "CF-Connecting-IP": networkID,
    ...extra,
  };
}
async function send(path, token, init = {}) {
  const response = await worker.fetch(new Request(`https://example.test${path}`, {
    ...init,
    headers: headers(token, init.headers),
  }), env);
  return { response, body: await response.json() };
}

const token = await openSession();
const request = {
  editionID: "seasonal-dispatch-2026-S08-perfect-bound-softcover-6x9",
  variant: {
    id: "perfect-bound-softcover-6x9",
    displayName: "6 x 9 Softcover",
    luluPackageID: "0600X0900.FC.STD.PB.060UW444.MXX",
    coverTreatment: "perfectBound",
    manufacturingBasePriceCentsUSD: 0,
    manufacturingPerPagePriceTenThousandthsUSD: 0,
  },
  pageCount: 32,
  selectedOptionIDs: [],
};

console.log("Preparing the earned season:");
membershipStatus = "past_due";
const pastDue = await send("/memberships/sub_member/dispatches/2026-S08", token, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(request),
});
check(pastDue.response.status === 402, "a failed renewal cannot masquerade as paid-through entitlement");
membershipStatus = "active";
const prepared = await send("/memberships/sub_member/dispatches/2026-S08", token, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(request),
});
check(prepared.response.status === 201, "an earned season prepares");
check(Boolean(prepared.body.dispatchToken), "the preparation returns a parcel-scoped token");
check(prepared.body.coverDimensions?.widthPoints === 910, "the preparation returns Lulu's exact cover canvas");
check(prepared.body.shippingAddressSummary.includes("Belfast"), "only a coarse address summary returns to the app");

const wrongBinding = await send("/memberships/sub_member/dispatches/2026-S11", token, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ ...request, editionID: "wrong", variant: { ...request.variant, id: "cloth-foil-hardcover-6x9" } }),
});
check(wrongBinding.response.status === 400, "the server fixes the prepaid binding instead of trusting the app");

const annualCasewrap = await send("/memberships/sub_member/dispatches/2027-S05", token, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    ...request,
    editionID: "annual-photo-cover",
    variant: {
      ...request.variant,
      id: "illustrated-hardcover-6x9",
      luluPackageID: "0600X0900.FC.STD.CW.060UW444.MXX",
      coverTreatment: "caseWrap",
    },
  }),
});
check(
  annualCasewrap.response.status === 201,
  "the annual may use its included illustrated hardcase for a photograph or plate",
);

const annualLinen = await send("/memberships/sub_member/dispatches/2027-S05", token, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    ...request,
    editionID: "annual-linen-jacket",
    variant: {
      ...request.variant,
      id: "cloth-foil-hardcover-6x9",
      luluPackageID: "0600X0900.FC.STD.LW.060UW444.MNG",
      coverTreatment: "linenWrap",
    },
    foilStampTitleText: "BOOK OF YOU",
    foilStampAuthorText: "READER EXAMPLE",
  }),
});
check(annualLinen.response.status === 201, "the annual linen-and-jacket binding prepares");
check(annualLinen.body.coverDimensions?.widthPoints === 1192, "the jacket uses Lulu's flap-inclusive canvas");

const pdf = new TextEncoder().encode("%PDF-1.7\nseasonal test\n%%EOF");
const md5 = createHash("md5").update(pdf).digest("hex");
const sha256 = createHash("sha256").update(pdf).digest("hex");
for (const kind of ["interior", "cover"]) {
  const uploaded = await send(`/memberships/sub_member/dispatches/2026-S08/print-files/${kind}`, token, {
    method: "POST",
    headers: {
      "Content-Type": "application/pdf",
      "X-Edition-ID": request.editionID,
      "X-Membership-Dispatch-Token": prepared.body.dispatchToken,
      "X-Source-MD5": md5,
      "X-Source-SHA256": sha256,
    },
    body: pdf,
  });
  check(uploaded.response.status === 201, `${kind} PDF is accepted`);
}

console.log("Submitting without another charge:");
const submitted = await send("/memberships/sub_member/dispatches/2026-S08/orders", token, {
  method: "POST",
  headers: { "X-Membership-Dispatch-Token": prepared.body.dispatchToken },
  body: "{}",
});
check(submitted.response.status === 201, "the prepaid parcel reaches Lulu");
check(submitted.body.luluPrintJobID === "print-job-1", "the Lulu receipt returns");

for (const kind of ["interior", "cover"]) {
  const uploaded = await send(`/memberships/sub_member/dispatches/2027-S05/print-files/${kind}`, token, {
    method: "POST",
    headers: {
      "Content-Type": "application/pdf",
      "X-Edition-ID": "annual-linen-jacket",
      "X-Membership-Dispatch-Token": annualLinen.body.dispatchToken,
      "X-Source-MD5": md5,
      "X-Source-SHA256": sha256,
    },
    body: pdf,
  });
  check(uploaded.response.status === 201, `annual ${kind} PDF is accepted`);
}
const annualSubmitted = await send("/memberships/sub_member/dispatches/2027-S05/orders", token, {
  method: "POST",
  headers: { "X-Membership-Dispatch-Token": annualLinen.body.dispatchToken },
  body: "{}",
});
check(annualSubmitted.response.status === 201, "the linen annual reaches Lulu");
check(luluPayloads[1].line_items[0].foil_stamp_title_text === "BOOK OF YOU", "the cloth title reaches Lulu's foil fields");
check(luluPayloads[1].line_items[0].foil_stamp_author_text === "READER EXAMPLE", "the reader name reaches the cloth spine");

const preparedAgain = await send("/memberships/sub_member/dispatches/2026-S08", token, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(request),
});
check(preparedAgain.body.alreadySubmitted === true, "a relaunch finds the submitted parcel");
check(luluCreates === 2, "each parcel creates exactly one Lulu job");
check(coverDimensionRequests >= 3, "every prepared binding asks Lulu for its own cover dimensions");

console.log(failures === 0 ? "\nBound Year dispatch tests passed." : `\n${failures} failed.`);
if (failures > 0) process.exit(1);
