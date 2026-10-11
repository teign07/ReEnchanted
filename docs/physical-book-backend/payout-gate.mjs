// The payout gate.
//
// No parcel goes to Lulu until the money that pays for it has landed in the
// Bindery's bank. A captured charge is not enough: Stripe holds it as pending,
// then pays it out days later, and Lulu bills its card the moment a print job
// is created. Printing on capture would mean the print bill arrives before the
// reader's money does. bj: "I don't ever want to be fronting my own money."
//
// Stripe never says on a charge which payout carried it, so the cron reads the
// other direction: each paid payout lists its balance transactions, and every
// one of them is marked as banked. A parcel's funding is the balance
// transaction of each charge that pays for it, and it prints only once every
// one is marked. Listing a payout's transactions works for automatic payouts
// only; a manual payout cannot be attributed, so with manual payouts nothing
// prints and the long-hold alert fires. That is the safe failure.

export const AWAITING_PAYOUT_INDEX_PREFIX = "awaiting-payout/";
const BANKED_PREFIX = "funds-in-bank/";
const RECORDED_PAYOUT_PREFIX = "payouts/recorded/";
// An annual Bound Year's last season is paid for by a charge made twelve
// months before it closes, so the banked mark has to outlive that charge.
const BANKED_TTL_SECONDS = 400 * 24 * 60 * 60;
const PAYOUT_PAGE_LIMIT = 100;
const PAYOUT_SCAN_MAX_PAGES = 10;

export class AwaitingPayoutError extends Error {
  constructor(funding) {
    super("This parcel's payment has not reached the bank yet");
    this.funding = funding;
  }
}

// The balance transaction behind a charge, or null when Stripe has not
// attached one yet (that is a parcel that cannot print, not an error).
export function fundingTransaction(charge) {
  const transaction = charge && typeof charge === "object" ? charge.balance_transaction : null;
  const id = typeof transaction === "string" ? transaction : transaction?.id;
  return /^txn_[A-Za-z0-9_]+$/.test(id || "") ? id : null;
}

// Funding is a non-empty list of balance transactions. Anything else, a
// missing transaction included, is unknown funding and never prints.
export function normalizedFunding(transactions) {
  if (!Array.isArray(transactions) || transactions.length === 0 || transactions.some(id => !id)) return null;
  return [...new Set(transactions)].sort();
}

export async function fundingIsBanked(kv, funding) {
  if (!funding) return false;
  const marks = await Promise.all(funding.map(id => kv.get(`${BANKED_PREFIX}${id}`)));
  return marks.every(Boolean);
}

export function awaitingPayoutIndexKey(coordinatorKey) {
  return `${AWAITING_PAYOUT_INDEX_PREFIX}${coordinatorKey}`;
}

// Walk paid payouts newest first until one already recorded, then record the
// new ones oldest first. A failure stops the walk before any newer payout is
// marked recorded, so the next run starts again from the gap.
export async function recordPaidPayouts(kv, stripeGet) {
  const unrecorded = [];
  let cursor = null;
  scan: for (let page = 0; page < PAYOUT_SCAN_MAX_PAGES; page += 1) {
    const query = new URLSearchParams({ status: "paid", limit: String(PAYOUT_PAGE_LIMIT) });
    if (cursor) query.set("starting_after", cursor);
    const payouts = await stripeGet(`payouts?${query}`);
    if (!Array.isArray(payouts?.data)) throw new Error("Stripe payout list was unreadable");
    for (const payout of payouts.data) {
      if (await kv.get(`${RECORDED_PAYOUT_PREFIX}${payout.id}`)) break scan;
      unrecorded.push(payout);
    }
    if (!payouts.has_more || payouts.data.length === 0) break;
    cursor = payouts.data.at(-1).id;
  }
  let banked = 0;
  for (const payout of unrecorded.reverse()) {
    if (payout.status !== "paid") continue;
    if (payout.automatic !== false) banked += await recordPayoutTransactions(kv, stripeGet, payout);
    await kv.put(`${RECORDED_PAYOUT_PREFIX}${payout.id}`, String(payout.arrival_date ?? ""), {
      expirationTtl: BANKED_TTL_SECONDS,
    });
  }
  return { payouts: unrecorded.length, banked };
}

async function recordPayoutTransactions(kv, stripeGet, payout) {
  const mark = JSON.stringify({ payoutID: payout.id, arrivalDate: payout.arrival_date ?? null });
  let cursor = null;
  let count = 0;
  for (;;) {
    const query = new URLSearchParams({ payout: payout.id, limit: String(PAYOUT_PAGE_LIMIT) });
    if (cursor) query.set("starting_after", cursor);
    const transactions = await stripeGet(`balance_transactions?${query}`);
    if (!Array.isArray(transactions?.data)) throw new Error("Stripe payout transactions were unreadable");
    for (const transaction of transactions.data) {
      if (!/^txn_[A-Za-z0-9_]+$/.test(transaction.id || "")) continue;
      await kv.put(`${BANKED_PREFIX}${transaction.id}`, mark, { expirationTtl: BANKED_TTL_SECONDS });
      count += 1;
    }
    if (!transactions.has_more || transactions.data.length === 0) return count;
    cursor = transactions.data.at(-1).id;
  }
}
