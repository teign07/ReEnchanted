import test from "node:test";
import assert from "node:assert/strict";
import { cashOperation, fundingTransaction, normalizedFunding, printerLiability } from "./payout-gate.mjs";
import worker, { PhysicalBookOrderCoordinator } from "./lulu-quote-worker.mjs";
import { webcrypto } from "node:crypto";
if (!globalThis.crypto) globalThis.crypto = webcrypto;

function fixture({ amount = 9680, net = amount } = {}) {
  const values = new Map();
  const storage = { async get(key) { return values.get(key); }, async put(key, value) { values.set(key, structuredClone(value)); } };
  const payout = { id: "po_1", amount, currency: "usd", livemode: false, status: "paid", automatic: true, type: "bank_account", method: "standard", reconciliation_status: "completed" };
  let unavailable = false;
  const charge = { paid: true, livemode: false, amount: net + 320, amount_refunded: 0, currency: "usd" };
  const calls = [];
  const get = async path => {
    calls.push(path);
    if (unavailable) throw new Error("Stripe unavailable");
    if (path === "payouts/po_1") return structuredClone(payout);
    if (path.startsWith("balance_transactions/txn_1?")) return { id: "txn_1", net, currency: "usd", source: structuredClone(charge) };
    if (path.startsWith("balance_transactions?")) return { data: [
      { id: "txn_1", net, currency: "usd", type: "charge" },
      ...(net > amount ? [{ id: "txn_refund", net: amount - net, currency: "usd", type: "refund" }] : []),
    ], has_more: false };
    throw new Error(`Unexpected Stripe read ${path}`);
  };
  return { values, storage, payout, charge, get, calls,
    outage(value) { unavailable = value; },
    op: input => cashOperation(storage, get, false, input),
    confirm: changes => cashOperation(storage, get, false, { action: "confirm-deposit", payoutID: "po_1", receiptReference: "receipt_test_1", depositedCents: amount, printingCents: amount, protectedForPrinting: true, ...changes }),
  };
}
const reserve = (parcel = "a", cost = 1279, extra = {}) => ({ action: "reserve", funding: ["txn_1"], parcelKey: parcel.repeat(64), fingerprint: "f".repeat(64), costCents: cost, currency: "usd", ...extra });

test("funding IDs and complete tax-inclusive printer totals fail closed", () => {
  assert.equal(fundingTransaction({ balance_transaction: { id: "txn_1" } }), "txn_1");
  assert.equal(fundingTransaction({ balance_transaction: "txn_../escape" }), null);
  for (const value of [null, [], ["txn_1", null], ["bad"]]) assert.equal(normalizedFunding(value), null);
  assert.deepEqual(normalizedFunding(["txn_2", "txn_1", "txn_1"]), ["txn_1", "txn_2"]);
  assert.deepEqual(printerLiability({ currency: "USD", total_cost_incl_tax: "12.79001" }), { cents: 1280, currency: "usd" });
  for (const quote of [{ print_cost: "1.00", shipping_cost: "2.00" }, { currency: "eur", total_cost_incl_tax: "1.00" }, { currency: "usd", total_cost_incl_tax: "0" }, { currency: "usd", total_cost_incl_tax: "NaN" }]) assert.throws(() => printerLiability(quote));
});
test("paid without an authenticated bank receipt does not fund a book", async () => {
  const f = fixture();
  assert.equal((await f.op(reserve())).reserved, false);
  assert.equal((await f.op({ action: "eligible", funding: ["txn_1"] })).eligible, false);
  await f.confirm();
  assert.equal((await f.op(reserve())).reserved, true);
});
test("paid then failed revokes a historical deposit before release and stays revoked", async () => {
  const f = fixture(); await f.confirm();
  f.payout.status = "failed";
  assert.equal((await f.op(reserve())).reserved, false);
  assert.equal(f.values.get("printing-cash-v1").deposits.po_1.revoked, true);
  f.payout.status = "paid";
  assert.equal((await f.op(reserve())).reserved, false);
  await assert.rejects(f.confirm(), { code: "bank_confirmation_conflict" });
});
test("a $1 deposited payout cannot pay a $12.79 bill from a $96.80 net charge", async () => {
  const f = fixture({ amount: 100, net: 9680 }); await f.confirm();
  assert.equal((await f.op(reserve())).reserved, false);
  assert.equal((await f.op({ action: "inspect" })).committedCents, 0);
});
test("protected printing cash excludes other liabilities, and replay cannot refill it", async () => {
  const f = fixture(); await f.confirm({ printingCents: 1500 });
  assert.equal((await f.op(reserve())).reserved, true);
  await f.confirm({ printingCents: 1500 });
  assert.equal((await f.op(reserve("b"))).reserved, false);
  await assert.rejects(f.confirm(), { code: "bank_confirmation_conflict" });
});
test("serial coordinator requests cannot spend the same cents, including after restart", async t => {
  const f = fixture({ amount: 2000 }); await f.confirm();
  const originalFetch = globalThis.fetch; t.after(() => { globalThis.fetch = originalFetch; });
  globalThis.fetch = async url => Response.json(await f.get(String(url).replace("https://api.stripe.com/v1/", "")));
  const env = { CHECKOUT_MODE: "test", STRIPE_SECRET_KEY: "test_fixture" };
  const state = { storage: f.storage };
  let coordinator = new PhysicalBookOrderCoordinator(state, env);
  const call = input => coordinator.fetch(new Request("https://internal/printing-cash", { method: "POST", body: JSON.stringify({ ...input, fulfillmentKind: "printing-cash" }) })).then(r => r.json());
  const results = await Promise.all([call(reserve("a")), call(reserve("b"))]);
  assert.equal(results.filter(r => r.reserved).length, 1);
  assert.equal((await f.op({ action: "inspect" })).committedCents, 1279);
  coordinator = new PhysicalBookOrderCoordinator(state, env);
  assert.equal((await call(reserve("a"))).reserved, true);
  assert.equal((await call(reserve("b"))).reserved, false);
});
test("annual funding stays finite across welcome and later earned parcels", async () => {
  const f = fixture({ amount: 4000 }); await f.confirm();
  for (const parcel of ["a", "b", "c"]) assert.equal((await f.op(reserve(parcel))).reserved, true);
  assert.equal((await f.op(reserve("d"))).reserved, false);
  assert.equal((await f.op({ action: "inspect" })).committedCents, 3837);
});
test("unknown, manual, wrong-mode, unreconciled, reversed and unsupported-currency deposits cannot be confirmed", async () => {
  for (const changes of [{ status: "in_transit" }, { automatic: false }, { method: "instant" }, { livemode: true }, { reconciliation_status: "in_progress" }, { reversed_by: "po_reverse" }, { currency: "eur" }, { type: "card" }]) {
    const f = fixture(); Object.assign(f.payout, changes);
    await assert.rejects(f.confirm(), { code: "payout_not_confirmable" });
    assert.equal((await f.op(reserve())).reserved, false);
  }
  const f = fixture();
  await assert.rejects(f.confirm({ protectedForPrinting: false }), { code: "invalid_bank_confirmation" });
  await assert.rejects(f.confirm({ depositedCents: 9999 }), { code: "payout_not_confirmable" });
});
test("outages block release, and cost increases need additional cash without releasing old reservations", async () => {
  const f = fixture({ amount: 1500 }); await f.confirm();
  await f.op(reserve()); f.outage(true);
  await assert.rejects(f.op(reserve("b")));
  f.outage(false);
  assert.equal((await f.op(reserve("a", 1600))).reserved, false);
  assert.equal((await f.op(reserve("a", 1400))).reserved, true);
  await f.op(reserve("a", 1000));
  assert.equal((await f.op({ action: "inspect" })).committedCents, 1400);
  await assert.rejects(f.op(reserve("a", 1000, { fingerprint: "e".repeat(64) })), { code: "cash_reservation_changed" });
});
test("a failed durable cash write denies the reservation", async () => {
  const f = fixture(); await f.confirm();
  f.storage.put = async () => { throw new Error("Storage unavailable"); };
  await assert.rejects(f.op(reserve()));
  assert.deepEqual(f.values.get("printing-cash-v1").reservations, {});
});
test("public callers cannot confirm deposits or choose internal cash actions", async () => {
  for (const authorization of [undefined, "Bearer wrong"]) {
    const response = await worker.fetch(new Request("https://test/admin/printing-cash/confirm-deposit", { method: "POST", headers: authorization ? { Authorization: authorization } : {}, body: JSON.stringify({ action: "reserve" }) }), { PHYSICAL_BOOK_ADMIN_TOKEN: "test-admin" });
    assert.equal(response.status, 401);
  }
});

test("original charge refunds or disputes cannot be bypassed by retrying an existing reservation", async () => {
  const f = fixture({ amount: 2000 }); await f.confirm(); await f.op(reserve());
  f.charge.amount_refunded = 1500;
  assert.equal((await f.op(reserve())).reserved, false);
  f.charge.amount_refunded = 0; f.charge.disputed = true;
  assert.equal((await f.op(reserve("b"))).reserved, false);
  assert.equal((await f.op({ action: "inspect" })).committedCents, 1279);
});
test("incomplete transaction pagination and mismatched net totals never confirm a deposit", async () => {
  const f = fixture();
  const confirm = { action: "confirm-deposit", payoutID: "po_1", receiptReference: "receipt_bad_paging", depositedCents: 9680, printingCents: 9680, protectedForPrinting: true };
  await assert.rejects(cashOperation(f.storage, async path => path.startsWith("payouts/") ? f.payout : { data: [], has_more: true }, false, confirm), { code: "payout_transactions_unverified" });
  await assert.rejects(cashOperation(f.storage, async path => path.startsWith("payouts/") ? f.payout : { data: [{ id: "txn_1", net: 9000, currency: "usd", type: "charge" }], has_more: false }, false, confirm), { code: "payout_net_mismatch" });
  assert.equal((await f.op(reserve())).reserved, false);
});
test("unverified printer costs hold a parcel before it reaches the printer", async t => {
  const values = new Map();
  const state = { storage: { async get(key) { return values.get(key); }, async put(key, value) { values.set(key, value); } } };
  const env = { LULU_API_BASE_URL: "https://api.sandbox.lulu.com", CHECKOUT_MODE: "test", PHYSICAL_BOOK_ORDER_COORDINATOR: {
    idFromName: name => name, get: () => ({ fetch: async () => Response.json({ eligible: true }) }),
  } };
  const originalFetch = globalThis.fetch; t.after(() => { globalThis.fetch = originalFetch; });
  let creates = 0;
  const coordinator = new PhysicalBookOrderCoordinator(state, env);
  for (const response of [
    () => Response.json({ currency: "usd", total_cost_excl_tax: "10.00" }),
    () => new Response("Unreadable cost", { status: 200 }),
    () => new Response("Upstream unavailable", { status: 503 }),
    () => { throw new Error("Network outage"); },
  ]) {
    globalThis.fetch = async (url, init) => {
      if (String(url).includes("cost-calculations")) {
        const input = JSON.parse(init.body);
        assert.equal(input.shipping_option, "MAIL");
        assert.equal(input.line_items[0].page_count, 32);
        return response();
      }
      creates++; throw new Error("Unexpected print POST");
    };
    await assert.rejects(coordinator.submitFundedPrintJob("token", { external_id: "test-parcel", shipping_level: "MAIL", line_items: [{ quantity: 1 }] }, ["txn_1"], null, 32), error => error.funding?.[0] === "txn_1");
  }
  assert.equal(creates, 0);
  assert.equal(values.has("lulu-submission"), false);
});
