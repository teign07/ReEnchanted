import { createHash, webcrypto } from "node:crypto";
import worker, { PhysicalBookOrderCoordinator } from "./lulu-quote-worker.mjs";
import { recordMonthlyMembershipOwner } from "./monthly-issues.mjs";

if (!globalThis.crypto) globalThis.crypto = webcrypto;

// Every new Bound Year member gets their first full week bound and posted, on
// the house: once per membership, never charged, never sent twice.

const installationID = "test-installation-0001";
const networkID = "203.0.113.10";
const kvValues = new Map();
const r2Values = new Map();
const coordinators = new Map();
const coordinatorStorage = new Map();
const luluPayloads = [];
const stripePosts = [];
let luluCreates = 0;
let loseNextLuluResponse = false;
let recoveredLuluJobs = [];
let failures = 0;
// Stripe's paid payouts, oldest first, each with the balance transactions it carried.
const paidPayouts = [];

const now = Math.floor(Date.now() / 1000);
const memberships = new Map();
function member(id, changes = {}) {
  // The first month's payout has already landed in the bank.
  kvValues.set(`funds-in-bank/txn_${id}`, "{}");
  memberships.set(id, {
    id,
    status: "active",
    livemode: false,
    customer: `cus_${id}`,
    current_period_end: now + 25 * 24 * 60 * 60,
    cancel_at_period_end: false,
    items: { data: [{ price: { id: "price_monthly" } }] },
    metadata: {
      reenchanted_cadence: "monthly",
      reenchanted_physical_fulfillment: "accepted",
      reenchanted_start_month: new Date().toISOString().slice(0, 7),
    },
    latest_invoice: {
      subscription: id, status: "paid", paid: true, amount_paid: 2499,
      payment_intent: { status: "succeeded", latest_charge: { paid: true, amount: 2499, amount_refunded: 0, refunded: false, disputed: false, balance_transaction: `txn_${id}` } },
    },
    ...changes,
  });
  return memberships.get(id);
}

const kv = {
  async get(key) { return kvValues.get(key) ?? null; },
  async put(key, value) { kvValues.set(key, value); },
  async delete(key) { kvValues.delete(key); },
  async list({ prefix = "" } = {}) {
    return { keys: [...kvValues.keys()].filter(key => key.startsWith(prefix)).map(name => ({ name })), list_complete: true };
  },
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
          async delete(key) { storage.delete(key); },
        },
      }, env));
    }
    return { fetch: (url, init) => coordinators.get(id).fetch(new Request(url, init)) };
  },
};

const stripeShipping = {
  name: "Reader Example",
  phone: "207-555-0100",
  address: { line1: "1 Harbor St", city: "Belfast", state: "ME", country: "US", postal_code: "04915" },
};

globalThis.fetch = async (url, init = {}) => {
  const href = String(url);
  if (href.startsWith("https://api.stripe.com/")) {
    if ((init.method || "GET") !== "GET") stripePosts.push(href);
    const path = new URL(href).pathname;
    const subscription = /^\/v1\/subscriptions\/([^/]+)$/.exec(path);
    if (subscription) {
      const record = memberships.get(decodeURIComponent(subscription[1]));
      return record ? json(record) : json({ error: { message: "No such subscription" } }, 404);
    }
    if (path === "/v1/payouts") return json({ data: [...paidPayouts].reverse(), has_more: false });
    if (path === "/v1/balance_transactions") {
      const payout = paidPayouts.find(entry => entry.id === new URL(href).searchParams.get("payout"));
      return json({ data: (payout?.transactions || []).map(id => ({ id })), has_more: false });
    }
    const customer = /^\/v1\/customers\/(cus_[^/]+)$/.exec(path);
    if (customer) return json({ id: customer[1], email: "reader@example.com", shipping: stripeShipping });
  }
  if (href === env.LULU_AUTH_URL) return json({ access_token: "lulu-token" });
  if (href.includes("/print-jobs/?")) return json({ count: recoveredLuluJobs.length, next: null, results: recoveredLuluJobs });
  if (href.endsWith("/cover-dimensions/")) {
    const request = JSON.parse(init.body);
    check(request.pod_package_id === "0600X0900.FC.PRE.SS.060UW444.MXX", "the cover canvas is asked for the saddle-stitched weekly");
    return json({ width: "891.000", height: "666.000", unit: "pt" });
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

function json(body, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
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
async function send(path, init = {}) {
  const response = await worker.fetch(new Request(`https://example.test${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      "X-Installation-ID": installationID,
      "CF-Connecting-IP": networkID,
      ...init.headers,
    },
  }), env);
  return { response, body: await response.json() };
}
async function own(membershipID) {
  await recordMonthlyMembershipOwner(env, membershipID, createHash("sha256").update(installationID).digest("hex"));
}

const token = await openSession();
const weekly = {
  editionID: "welcome-weekly-issue-3",
  editionTitle: "The Week the Kettle Sang",
  variant: {
    id: "saddle-stitched-weekly-6x9",
    displayName: "6 x 9 Weekly",
    luluPackageID: "0600X0900.FC.PRE.SS.060UW444.MXX",
    coverTreatment: "saddleStitch",
    manufacturingBasePriceCentsUSD: 0,
    manufacturingPerPagePriceTenThousandthsUSD: 0,
  },
  pageCount: 20,
  selectedOptionIDs: [],
};
const prepare = (id, body = weekly) => send(`/memberships/${id}/welcome-weekly`, {
  method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body),
});
const pdf = new TextEncoder().encode("%PDF-1.7\nwelcome weekly\n%%EOF");
const md5 = createHash("md5").update(pdf).digest("hex");
const sha256 = createHash("sha256").update(pdf).digest("hex");
const upload = (id, kind, dispatchToken, editionID = weekly.editionID) => send(`/memberships/${id}/welcome-weekly/print-files/${kind}`, {
  method: "POST",
  headers: {
    "Content-Type": "application/pdf", "X-Edition-ID": editionID,
    "X-Membership-Dispatch-Token": dispatchToken, "X-Source-MD5": md5, "X-Source-SHA256": sha256,
  },
  body: pdf,
});
const submit = (id, dispatchToken) => send(`/memberships/${id}/welcome-weekly/orders`, {
  method: "POST", headers: { "X-Membership-Dispatch-Token": dispatchToken }, body: "{}",
});
async function prepareAndUpload(id) {
  const prepared = await prepare(id);
  check(prepared.response.status === 201 && prepared.body.seasonKey === "welcome-weekly", `${id}: the welcome issue prepares in its own slot`);
  for (const kind of ["interior", "cover"]) {
    check((await upload(id, kind, prepared.body.dispatchToken)).response.status === 201, `${id}: the ${kind} uploads`);
  }
  return prepared.body.dispatchToken;
}

console.log("Refusals:");
member("sub_stranger");
const stranger = await prepare("sub_stranger");
check(stranger.response.status === 403 && stranger.body.error === "membership_not_owned",
  "a reader who does not hold the membership cannot claim its welcome");

await own("sub_lapsed");
for (const [label, changes] of [
  ["a canceled membership", { status: "canceled" }],
  ["a past-due membership", { status: "past_due" }],
  ["an unpaid first invoice", { status: "incomplete" }],
  ["a paid-through date already behind it", { current_period_end: now - 60 }],
  ["a refunded first payment", m => { m.latest_invoice.payment_intent.latest_charge.refunded = true; m.latest_invoice.payment_intent.latest_charge.amount_refunded = 2499; }],
  ["a disputed first payment", m => { m.latest_invoice.payment_intent.latest_charge.disputed = true; }],
  ["a subscription with no physical consent", m => { m.metadata.reenchanted_physical_fulfillment = "declined"; }],
  ["a subscription that is not a Bound Year price", m => { m.items.data[0].price.id = "price_other"; }],
]) {
  const record = member("sub_lapsed", typeof changes === "function" ? {} : changes);
  if (typeof changes === "function") changes(record);
  const refused = await prepare("sub_lapsed");
  check(refused.response.status === 402 && refused.body.error === "welcome_weekly_requires_active_membership",
    `${label} is refused`);
}
check(luluCreates === 0, "no refusal reaches the print house");

await own("sub_member");
member("sub_member");
const wrongBinding = await prepare("sub_member", { ...weekly, variant: { ...weekly.variant, id: "perfect-bound-softcover-6x9", luluPackageID: "0600X0900.FC.PRE.PB.060UW444.MXX" } });
check(wrongBinding.response.status === 400, "the welcome is a weekly, not a softcover season");
const tooThick = await prepare("sub_member", { ...weekly, pageCount: 52 });
check(tooThick.response.status === 400, "the welcome cannot run past the weekly page cap");
const oddSignature = await prepare("sub_member", { ...weekly, pageCount: 22 });
check(oddSignature.response.status === 400, "a saddle stitch needs pages in fours");
const extras = await prepare("sub_member", { ...weekly, selectedOptionIDs: ["extra-copy"] });
check(extras.response.status === 402, "paid extras cannot ride along on the free parcel");

console.log("Claim:");
const before = await send("/memberships/sub_member", { method: "GET" });
check(before.body.welcomeWeekly?.claimed === false, "the membership reports its welcome as unclaimed");
const dispatchToken = await prepareAndUpload("sub_member");
const sent = await submit("sub_member", dispatchToken);
check(sent.response.status === 201, "the welcome issue reaches Lulu");
check(sent.body.luluPrintJobID === "print-job-1", "the Lulu receipt returns");
const payload = luluPayloads[0];
check(payload.external_id === "bound-year-sub_member-welcome-weekly", "the parcel is named for its membership slot");
check(payload.line_items[0].pod_package_id === "0600X0900.FC.PRE.SS.060UW444.MXX", "it is printed as the saddle-stitched weekly");
check(payload.line_items[0].title === weekly.editionTitle, "the week's own title reaches Lulu");
check(payload.shipping_address.street1 === "1 Harbor St" && payload.shipping_address.postcode === "04915",
  "it ships to the membership's address on file, not one the app supplied");
check(payload.shipping_level === "MAIL", "it posts by ordinary mail");
check(stripePosts.length === 0, "nothing is charged: no Stripe write happens at all");
const after = await send("/memberships/sub_member", { method: "GET" });
check(after.body.welcomeWeekly?.claimed === true && after.body.welcomeWeekly.luluPrintJobID === "print-job-1",
  "the membership reports its welcome as claimed");

console.log("Idempotence:");
const resent = await submit("sub_member", dispatchToken);
check(resent.response.status === 201 && resent.body.luluPrintJobID === "print-job-1", "a retried submission returns the same parcel");
const preparedAgain = await prepare("sub_member");
check(preparedAgain.body.alreadySubmitted === true && preparedAgain.body.order?.luluPrintJobID === "print-job-1",
  "preparing again finds the claimed welcome instead of opening a second");
check(!preparedAgain.body.dispatchToken, "a claimed welcome hands out no new parcel token");
const lateUpload = await upload("sub_member", "interior", dispatchToken);
check(lateUpload.response.status === 409 && lateUpload.body.error === "welcome_weekly_already_claimed",
  "already claimed: new print files are refused");
coordinators.clear();
check((await submit("sub_member", dispatchToken)).body.luluPrintJobID === "print-job-1", "a restarted coordinator still returns the original parcel");
memberships.get("sub_member").status = "canceled";
const claimedThenLapsed = await prepare("sub_member");
check(claimedThenLapsed.body.alreadySubmitted === true, "a welcome already posted stays posted after the membership ends");
check(luluCreates === 1, "one membership, one welcome issue, one Lulu job");

console.log("Lapsing mid-flight:");
await own("sub_flight");
member("sub_flight");
const flightToken = await prepareAndUpload("sub_flight");
memberships.get("sub_flight").status = "canceled";
const lapsedSubmit = await submit("sub_flight", flightToken);
check(lapsedSubmit.response.status === 402, "a membership that lapsed after preparing is refused at the press");
check(luluCreates === 1, "the lapsed parcel never reaches Lulu");
memberships.get("sub_flight").status = "active";
check((await submit("sub_flight", flightToken)).response.status === 201, "the same parcel goes once the membership is current again");

console.log("Print submission interruptions:");
await own("sub_lost");
member("sub_lost");
const lostToken = await prepareAndUpload("sub_lost");
loseNextLuluResponse = true;
const uncertain = await submit("sub_lost", lostToken);
check(uncertain.body.error === "print_submission_uncertain", "a lost Lulu response needs reconciliation, not a second job");
const createsAfterLoss = luluCreates;
coordinators.clear();
check((await submit("sub_lost", lostToken)).body.error === "print_submission_uncertain", "the uncertain attempt survives a restart");
recoveredLuluJobs = [{ id: `print-job-${createsAfterLoss}`, external_id: "bound-year-sub_lost-welcome-weekly", status: { name: "PRODUCTION_READY" } }];
const recovered = await submit("sub_lost", lostToken);
check(recovered.body.luluPrintJobID === `print-job-${createsAfterLoss}`, "one exact Lulu match recovers the receipt");
check(luluCreates === createsAfterLoss, "recovery never sends a replacement parcel");
const durableJSON = JSON.stringify([...coordinatorStorage.values()].map(value => [...value]));
check(!durableJSON.includes("1 Harbor St"), "durable receipts omit the shipping address");

console.log("Waiting for the payout:");
// A brand-new member: the first month is captured, but its payout has not
// reached the bank. Lulu bills on job creation, so nothing may print yet.
await own("sub_fresh");
member("sub_fresh");
kvValues.delete("funds-in-bank/txn_sub_fresh");
const freshToken = await prepareAndUpload("sub_fresh");
const createsBeforeFresh = luluCreates;
const held = await submit("sub_fresh", freshToken);
check(held.response.status === 409 && held.body.error === "awaiting_payout", "a captured but unpaid-out charge is held, not printed");
check(luluCreates === createsBeforeFresh, "the held parcel never reaches Lulu");
check(kvValues.has("awaiting-payout/membership:sub_fresh:welcome-weekly"), "the hold is indexed for the cron");
check((await submit("sub_fresh", freshToken)).body.error === "awaiting_payout", "asking again before the payout is still a hold");
// A second, still-pending invoice becomes the latest. The parcel stays paid
// for by the first month, so that payout alone releases it.
memberships.get("sub_fresh").latest_invoice.payment_intent.latest_charge.balance_transaction = "txn_sub_fresh_month_two";

const cron = async () => {
  const pending = [];
  await worker.scheduled({}, env, { waitUntil: promise => pending.push(promise) });
  await Promise.all(pending);
};
paidPayouts.push({ id: "po_unrelated", status: "paid", automatic: true, arrival_date: now, transactions: ["txn_someone_else"] });
await cron();
check(luluCreates === createsBeforeFresh, "a payout that did not carry this charge releases nothing");
paidPayouts.push({ id: "po_manual", status: "paid", automatic: false, arrival_date: now, transactions: ["txn_sub_fresh"] });
await cron();
check(luluCreates === createsBeforeFresh, "a manual payout cannot be attributed, so it releases nothing");
paidPayouts.push({ id: "po_first_month", status: "paid", automatic: true, arrival_date: now, transactions: ["txn_sub_fresh"] });
await cron();
check(luluCreates === createsBeforeFresh + 1, "the payout landing sends the parcel to Lulu on the cron, without the app");
check(luluPayloads.at(-1).external_id === "bound-year-sub_fresh-welcome-weekly", "the released job is this member's welcome");
check(!kvValues.has("awaiting-payout/membership:sub_fresh:welcome-weekly"), "the hold index clears once submitted");
check(![...coordinatorStorage.get("membership:sub_fresh:welcome-weekly").keys()].includes("awaiting-payout"), "the held request is deleted once submitted");
await cron();
check(luluCreates === createsBeforeFresh + 1, "a later cron sends nothing twice");
const afterRelease = await submit("sub_fresh", freshToken);
check(afterRelease.response.status === 201 && afterRelease.body.luluPrintJobID === `print-job-${createsBeforeFresh + 1}`,
  "the app's next ask returns the parcel the cron sent");

console.log("A payout that never comes:");
await own("sub_stuck");
member("sub_stuck");
kvValues.delete("funds-in-bank/txn_sub_stuck");
const stuckToken = await prepareAndUpload("sub_stuck");
check((await submit("sub_stuck", stuckToken)).body.error === "awaiting_payout", "a parcel with no payout yet is held");
const sentAlerts = [];
env.SECURITY_ALERT_EMAIL = { async send(message) { sentAlerts.push(message); } };
env.SECURITY_ALERT_EMAIL_TO = "operator@example.test";
await cron();
check(sentAlerts.length === 0, "a fresh hold is waiting on purpose, not an alert");
const stuckIndex = "awaiting-payout/membership:sub_stuck:welcome-weekly";
kvValues.set(stuckIndex, JSON.stringify({ ...JSON.parse(kvValues.get(stuckIndex)), heldAt: new Date(Date.now() - 15 * 24 * 60 * 60 * 1000).toISOString() }));
await cron();
check(sentAlerts.length === 1, "a parcel held past two weeks alerts the Bindery");
check(!JSON.stringify(sentAlerts).includes("sub_stuck") && !JSON.stringify(sentAlerts).includes("Harbor"), "the alert names no membership or address");
await cron();
check(sentAlerts.length === 1, "the alert does not repeat inside its cooldown");
check(luluCreates === createsBeforeFresh + 1, "the stuck parcel still never reaches Lulu");

console.log(failures === 0 ? "\nWelcome weekly tests passed." : `\n${failures} failed.`);
if (failures > 0) process.exit(1);
