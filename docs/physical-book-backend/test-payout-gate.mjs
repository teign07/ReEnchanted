import test from "node:test";
import assert from "node:assert/strict";
import { fundingIsBanked, fundingTransaction, normalizedFunding, recordPaidPayouts } from "./payout-gate.mjs";

function kvStore() {
  const values = new Map();
  return { values, async get(key) { return values.get(key) ?? null; }, async put(key, value) { values.set(key, value); } };
}

// payouts: newest first, as Stripe lists them. transactions: payout id -> pages of ids.
function stripe(payouts, transactions, { failOn } = {}) {
  const calls = [];
  const get = async path => {
    calls.push(path);
    const query = new URLSearchParams(path.split("?")[1]);
    if (path.startsWith("payouts?")) {
      const start = query.has("starting_after") ? payouts.findIndex(p => p.id === query.get("starting_after")) + 1 : 0;
      const page = payouts.slice(start, start + 2);
      return { data: page, has_more: start + 2 < payouts.length };
    }
    const payout = query.get("payout");
    if (payout === failOn) throw new Error("Stripe unavailable");
    const pages = transactions[payout] || [[]];
    const index = query.has("starting_after") ? pages.findIndex(page => page.at(-1) === query.get("starting_after")) + 1 : 0;
    return { data: pages[index].map(id => ({ id })), has_more: index + 1 < pages.length };
  };
  return { get, calls };
}

const paid = (id, automatic = true) => ({ id, status: "paid", automatic, arrival_date: 1 });

test("funding is only ever a real balance transaction", () => {
  assert.equal(fundingTransaction({ balance_transaction: "txn_1" }), "txn_1");
  assert.equal(fundingTransaction({ balance_transaction: { id: "txn_2" } }), "txn_2");
  assert.equal(fundingTransaction({ balance_transaction: null }), null);
  assert.equal(fundingTransaction("ch_unexpanded"), null);
  assert.equal(fundingTransaction({ balance_transaction: "txn_../escape" }), null);
  assert.equal(normalizedFunding([]), null, "a parcel with no charges is unfunded");
  assert.equal(normalizedFunding(["txn_1", null]), null, "one unknown charge makes the whole parcel unfunded");
  assert.deepEqual(normalizedFunding(["txn_2", "txn_1", "txn_2"]), ["txn_1", "txn_2"]);
});

test("a parcel is banked only when every charge behind it is", async () => {
  const kv = kvStore();
  const { get } = stripe([paid("po_1")], { po_1: [["txn_a"]] });
  await recordPaidPayouts(kv, get);
  assert.equal(await fundingIsBanked(kv, ["txn_a"]), true);
  assert.equal(await fundingIsBanked(kv, ["txn_a", "txn_b"]), false);
  assert.equal(await fundingIsBanked(kv, null), false);
});

test("the scan pages through payouts and transactions, and stops at the last recorded payout", async () => {
  const kv = kvStore();
  const first = stripe([paid("po_2"), paid("po_1")], { po_1: [["txn_1a"], ["txn_1b"]], po_2: [["txn_2"]] });
  assert.deepEqual(await recordPaidPayouts(kv, first.get), { payouts: 2, banked: 3 });
  assert.equal(await fundingIsBanked(kv, ["txn_1a", "txn_1b", "txn_2"]), true);
  const later = stripe([paid("po_4"), paid("po_3"), paid("po_2"), paid("po_1")], { po_3: [["txn_3"]], po_4: [["txn_4"]] });
  assert.deepEqual(await recordPaidPayouts(kv, later.get), { payouts: 2, banked: 2 });
  assert.ok(!later.calls.some(path => path.includes("payout=po_1") || path.includes("payout=po_2")), "recorded payouts are not reread");
});

test("a manual payout is recorded but cannot bank anything", async () => {
  const kv = kvStore();
  const { get, calls } = stripe([paid("po_manual", false)], { po_manual: [["txn_m"]] });
  await recordPaidPayouts(kv, get);
  assert.equal(await fundingIsBanked(kv, ["txn_m"]), false);
  assert.ok(!calls.some(path => path.startsWith("balance_transactions")));
});

test("a failed payout read leaves it and every newer payout for the next run", async () => {
  const kv = kvStore();
  const payouts = [paid("po_3"), paid("po_2"), paid("po_1")];
  const transactions = { po_1: [["txn_1"]], po_2: [["txn_2"]], po_3: [["txn_3"]] };
  await assert.rejects(recordPaidPayouts(kv, stripe(payouts, transactions, { failOn: "po_2" }).get));
  assert.equal(await fundingIsBanked(kv, ["txn_1"]), true, "the older payout is recorded");
  assert.equal(await fundingIsBanked(kv, ["txn_3"]), false, "the newer payout is not recorded past the gap");
  await recordPaidPayouts(kv, stripe(payouts, transactions).get);
  assert.equal(await fundingIsBanked(kv, ["txn_2", "txn_3"]), true, "the next run fills the gap");
});
