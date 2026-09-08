import { createHash, webcrypto } from "node:crypto";
import worker, { PhysicalBookOrderCoordinator } from "./lulu-quote-worker.mjs";
import { recordMonthlyMembershipOwner } from "./monthly-issues.mjs";

if (!globalThis.crypto) globalThis.crypto = webcrypto;

const installationID = "test-installation-0001";
const networkID = "203.0.113.10";
const kvValues = new Map();
const r2Values = new Map();
const coordinators = new Map();
const coordinatorStorage = new Map();
let luluCreates = 0;
let coverDimensionRequests = 0;
const luluPayloads = [];
let failures = 0;
let membershipStatus = "active";
let loseNextLuluResponse = false;
let failNextOrderWrite = false;
let recoveredLuluJobs = [];
let membershipCadence = "annual";
let membershipPrice = "price_annual";
let membershipLive = false;
let invoiceRequests = 0;
function paidInvoice(month, cadence = "annual") {
  const start = new Date(`${month}-21T12:00:00Z`);
  const end = new Date(start);
  end.setUTCMonth(end.getUTCMonth() + (cadence === "annual" ? 12 : 1));
  return {
    id: `in_${month}`, subscription: "sub_member", livemode: false, status: "paid", paid: true, amount_paid: 5000,
    payment_intent: { status: "succeeded", latest_charge: { paid: true, amount: 5000, amount_refunded: 0, refunded: false, disputed: false } },
    lines: { data: [{
      type: "subscription", subscription: "sub_member", proration: false, price: { id: `price_${cadence}` }, amount: 5000,
      period: { start: start.getTime() / 1000, end: end.getTime() / 1000 },
    }] },
  };
}
let paidInvoices = [paidInvoice("2024-08")];
let paginatedInvoices = false;

const kv = {
  async get(key) { return kvValues.get(key) ?? null; },
  async put(key, value) {
    if (failNextOrderWrite && key.endsWith("/order")) {
      failNextOrderWrite = false;
      throw new Error("Simulated KV outage after Lulu accepted the parcel");
    }
    kvValues.set(key, value);
  },
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
  STRIPE_BOUND_YEAR_MONTHLY_PRICE: "price_monthly",
  STRIPE_BOUND_YEAR_ANNUAL_PRICE: "price_annual",
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
      if (!coordinatorStorage.has(id)) coordinatorStorage.set(id, new Map());
      const storage = coordinatorStorage.get(id);
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
    livemode: membershipLive,
    items: { data: [{ price: { id: membershipPrice } }] },
    customer: "cus_member",
    current_period_end: 1815000000,
    metadata: {
      reenchanted_cadence: membershipCadence,
      reenchanted_physical_fulfillment: "accepted",
      reenchanted_start_month: "2024-08",
    },
  });
  if (href.includes("/v1/invoices?")) {
    invoiceRequests += 1;
    check(init.headers["Stripe-Version"] === "2024-06-20", "invoice proof pins the expected Stripe schema");
    const query = new URL(href).searchParams;
    check(query.get("subscription") === "sub_member", "invoice lookup stays on this membership");
    if (paginatedInvoices && !query.has("starting_after")) {
      return json({ data: [paidInvoice("2025-08")], has_more: true });
    }
    return json({ data: paidInvoices, has_more: false });
  }
  if (href.endsWith("/v1/customers/cus_member")) return json({
    id: "cus_member", email: "reader@example.com", shipping: stripeShipping,
  });
  if (href === env.LULU_AUTH_URL) return json({ access_token: "lulu-token" });
  if (href.includes("/print-jobs/?")) return json({ count: recoveredLuluJobs.length, next: null, results: recoveredLuluJobs });
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
    if (loseNextLuluResponse) {
      loseNextLuluResponse = false;
      throw new Error("Connection lost after Lulu created the job");
    }
    return json({ id: `print-job-${luluCreates}`, status: { name: "PRODUCTION_READY" }, shipping_address: stripeShipping });
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
// This fixture starts with a previously purchased membership. Give it the
// same ownership record that checkout/recipient claim writes in production.
await recordMonthlyMembershipOwner(env, "sub_member",
  createHash("sha256").update(installationID).digest("hex"));
const request = {
  editionID: "seasonal-dispatch-2024-S08-perfect-bound-softcover-6x9",
  editionTitle: "The Season of Small Doors",
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
paidInvoices[0].paid = false;
const pastDue = await send("/memberships/sub_member/dispatches/2024-S08", token, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(request),
});
check(pastDue.response.status === 402, "a failed renewal cannot masquerade as paid-through entitlement");
membershipStatus = "active";
paidInvoices[0].paid = true;

async function checkSeason() {
  return send("/memberships/sub_member/dispatches/2024-S08", token, {
    method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(request),
  });
}
console.log("Paid invoice authority:");
for (const [label, change] of [
  ["a full refund", invoice => { invoice.payment_intent.latest_charge.refunded = true; invoice.payment_intent.latest_charge.amount_refunded = 5000; }],
  ["a disputed charge", invoice => { invoice.payment_intent.latest_charge.disputed = true; }],
  ["a trial with a zero invoice", invoice => { invoice.amount_paid = 0; invoice.payment_intent = null; }],
  ["an unsettled payment", invoice => { invoice.payment_intent.status = "processing"; }],
  ["an invoice from another subscription", invoice => { invoice.subscription = "sub_other"; }],
  ["a line from another subscription", invoice => { invoice.lines.data[0].subscription = "sub_other"; }],
  ["an unrelated paid product", invoice => { invoice.lines.data[0].price.id = "price_other"; }],
  ["a prorated fragment", invoice => { invoice.lines.data[0].proration = true; }],
  ["a malformed period", invoice => { invoice.lines.data[0].period.end = null; }],
  ["a different payment environment", invoice => { invoice.livemode = true; }],
]) {
  paidInvoices = [paidInvoice("2024-08")];
  change(paidInvoices[0]);
  check((await checkSeason()).response.status === 402, `${label} cannot earn a season from a future billing date`);
}
paidInvoices = [paidInvoice("2024-08")];
membershipPrice = "price_other";
check((await checkSeason()).body.error === "membership_price_mismatch", "subscription metadata alone cannot impersonate a Bound Year price");
membershipPrice = "price_annual";
membershipLive = true;
check((await checkSeason()).body.error === "membership_price_mismatch", "a subscription from another payment environment is refused");
membershipLive = false;
const beforeFuture = invoiceRequests;
const futureSeason = await send("/memberships/sub_member/dispatches/2099-S08", token, {
  method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(request),
});
check(futureSeason.body.error === "membership_season_not_closed", "prepayment cannot send a season before it closes");
check(invoiceRequests === beforeFuture, "a future season is rejected before fetching invoice history");

membershipCadence = "monthly";
membershipPrice = "price_monthly";
paidInvoices = [paidInvoice("2024-10", "monthly"), paidInvoice("2024-08", "monthly")];
check((await checkSeason()).response.status === 402, "a paid latest month cannot fill an unpaid middle month");
paidInvoices.push(paidInvoice("2024-09", "monthly"));
check((await checkSeason()).response.status === 201, "three settled monthly invoices earn the season even when billed on the 21st");
membershipCadence = "annual";
membershipPrice = "price_annual";
paidInvoices = [paidInvoice("2024-08")];
for (const status of ["canceled", "past_due"]) {
  membershipStatus = status;
  check((await checkSeason()).response.status === 201, `${status} does not erase an already paid historical season`);
}
membershipStatus = "active";
paginatedInvoices = true;
const beforeHistory = invoiceRequests;
check((await checkSeason()).response.status === 201, "a paid historical year is found beyond the newest invoice page");
check(invoiceRequests === beforeHistory + 2, "history lookup stops as soon as the season is proved");
paginatedInvoices = false;
const prepared = await send("/memberships/sub_member/dispatches/2024-S08", token, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(request),
});
check(prepared.response.status === 201, "an earned season prepares");
check(Boolean(prepared.body.dispatchToken), "the preparation returns a parcel-scoped token");
check(prepared.body.coverDimensions?.widthPoints === 910, "the preparation returns Lulu's exact cover canvas");
check(prepared.body.shippingAddressSummary.includes("Belfast"), "only a coarse address summary returns to the app");

const wrongBinding = await send("/memberships/sub_member/dispatches/2024-S11", token, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ ...request, editionID: "wrong", variant: { ...request.variant, id: "cloth-foil-hardcover-6x9" } }),
});
check(wrongBinding.response.status === 400, "the server fixes the prepaid binding instead of trusting the app");

const annualCasewrap = await send("/memberships/sub_member/dispatches/2025-S05", token, {
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

const annualLinen = await send("/memberships/sub_member/dispatches/2025-S05", token, {
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
  const uploaded = await send(`/memberships/sub_member/dispatches/2024-S08/print-files/${kind}`, token, {
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
const submitted = await send("/memberships/sub_member/dispatches/2024-S08/orders", token, {
  method: "POST",
  headers: { "X-Membership-Dispatch-Token": prepared.body.dispatchToken },
  body: "{}",
});
check(submitted.response.status === 201, "the prepaid parcel reaches Lulu");
check(submitted.body.luluPrintJobID === "print-job-1", "the Lulu receipt returns");
check(luluPayloads[0].line_items[0].title === request.editionTitle, "the saved seasonal edition title reaches Lulu");

for (const kind of ["interior", "cover"]) {
  const uploaded = await send(`/memberships/sub_member/dispatches/2025-S05/print-files/${kind}`, token, {
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
const annualSubmitted = await send("/memberships/sub_member/dispatches/2025-S05/orders", token, {
  method: "POST",
  headers: { "X-Membership-Dispatch-Token": annualLinen.body.dispatchToken },
  body: "{}",
});
check(annualSubmitted.response.status === 201, "the linen annual reaches Lulu");
check(luluPayloads[1].line_items[0].foil_stamp_title_text === "BOOK OF YOU", "the cloth title reaches Lulu's foil fields");
check(luluPayloads[1].line_items[0].foil_stamp_author_text === "READER EXAMPLE", "the reader name reaches the cloth spine");

const preparedAgain = await send("/memberships/sub_member/dispatches/2024-S08", token, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(request),
});
check(preparedAgain.body.alreadySubmitted === true, "a relaunch finds the submitted parcel");
check(luluCreates === 2, "each parcel creates exactly one Lulu job");
check(coverDimensionRequests >= 3, "every prepared binding asks Lulu for its own cover dimensions");

async function prepareAndUpload(season) {
  const parcel = await send(`/memberships/sub_member/dispatches/${season}`, token, {
    method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(request),
  });
  check(parcel.response.status === 201, `${season} failure-path parcel prepares`);
  for (const kind of ["interior", "cover"]) {
    const uploaded = await send(`/memberships/sub_member/dispatches/${season}/print-files/${kind}`, token, {
      method: "POST",
      headers: {
        "Content-Type": "application/pdf", "X-Edition-ID": request.editionID,
        "X-Membership-Dispatch-Token": parcel.body.dispatchToken,
        "X-Source-MD5": md5, "X-Source-SHA256": sha256,
      },
      body: pdf,
    });
    check(uploaded.response.status === 201, `${season} ${kind} uploads`);
  }
  return () => send(`/memberships/sub_member/dispatches/${season}/orders`, token, {
    method: "POST", headers: { "X-Membership-Dispatch-Token": parcel.body.dispatchToken }, body: "{}",
  });
}

console.log("Print submission interruptions:");
const sendUncertain = await prepareAndUpload("2024-S11");
loseNextLuluResponse = true;
const uncertain = await sendUncertain();
check(uncertain.body.error === "print_submission_uncertain", "a lost Lulu response requires reconciliation");
const createsAfterLoss = luluCreates;
coordinators.clear(); // New isolate, same durable storage.
const uncertainRetry = await sendUncertain();
check(uncertainRetry.body.error === "print_submission_uncertain", "the uncertain attempt survives an isolate restart");
check(luluCreates === createsAfterLoss, "a restarted retry never sends a second print request");
recoveredLuluJobs = [{ id: "unrelated-job", external_id: "a-different-parcel" }];
check((await sendUncertain()).body.error === "print_submission_uncertain", "a fuzzy search match cannot claim another parcel");
const recoveredJob = {
  id: `print-job-${createsAfterLoss}`, external_id: "bound-year-sub_member-2024-S11",
  status: { name: "PRODUCTION_READY" }, shipping_address: stripeShipping,
};
recoveredLuluJobs = [recoveredJob, { ...recoveredJob, id: "duplicate-job" }];
check((await sendUncertain()).body.error === "print_submission_uncertain", "multiple exact matches require operator reconciliation");
recoveredLuluJobs = [recoveredJob];
coordinators.clear();
const foundReceipt = await sendUncertain();
check(foundReceipt.body.luluPrintJobID === recoveredJob.id, "one exact Lulu match recovers a lost receipt after restart");
check(luluCreates === createsAfterLoss, "search recovery never creates a replacement parcel");

const sendRecoverable = await prepareAndUpload("2025-S02");
failNextOrderWrite = true;
const interrupted = await sendRecoverable();
check(interrupted.response.status === 500, "the test interrupts local recording after Lulu accepts");
const createsAfterReceipt = luluCreates;
coordinators.clear();
const recovered = await sendRecoverable();
check(recovered.response.status === 201, "a saved receipt finishes local recording after restart");
check(recovered.body.luluPrintJobID === `print-job-${createsAfterReceipt}`, "recovery returns the original Lulu receipt");
check(luluCreates === createsAfterReceipt, "receipt recovery never resubmits to Lulu");
const durableJSON = JSON.stringify([...coordinatorStorage.values()].map(value => [...value]));
check(!durableJSON.includes("1 Harbor St"), "durable submission receipts omit Lulu's shipping address");

console.log(failures === 0 ? "\nBound Year dispatch tests passed." : `\n${failures} failed.`);
if (failures > 0) process.exit(1);
