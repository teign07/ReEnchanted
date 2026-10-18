// Paid is Stripe's status, not proof of a bank deposit. All printing cash is
// held in one mode-specific Durable Object, never in eventually consistent KV.
export const AWAITING_PAYOUT_INDEX_PREFIX = "awaiting-payout/";
export class AwaitingPayoutError extends Error {
  constructor(funding) { super("This parcel needs verified, reserved printing cash"); this.funding = funding; }
}
export class CashGateError extends Error {
  constructor(code, status = 409) { super(code); this.code = code; this.status = status; }
}
const fail = (code, status) => { throw new CashGateError(code, status); };
const cents = value => Number.isSafeInteger(value) && value > 0;
const validID = (value, prefix) => typeof value === "string" && new RegExp(`^${prefix}_[A-Za-z0-9_]+$`).test(value);
export function fundingTransaction(charge) {
  const transaction = charge && typeof charge === "object" ? charge.balance_transaction : null;
  const id = typeof transaction === "string" ? transaction : transaction?.id;
  return validID(id, "txn") ? id : null;
}
export function normalizedFunding(transactions) {
  if (!Array.isArray(transactions) || !transactions.length || transactions.some(id => !validID(id, "txn"))) return null;
  return [...new Set(transactions)].sort();
}
export function awaitingPayoutIndexKey(key) { return `${AWAITING_PAYOUT_INDEX_PREFIX}${key}`; }

// Only a complete tax-inclusive Lulu total in our supported settlement currency
// is usable. Decimal parsing rounds UP and never relies on floating point money.
export function printerLiability(quote) {
  const total = String(quote?.total_cost_incl_tax ?? "");
  if (String(quote?.currency ?? "").toLowerCase() !== "usd" || !/^\d+(?:\.\d{1,6})?$/.test(total)) fail("printer_cost_unverified");
  const [whole, fraction = ""] = total.split(".");
  const micros = BigInt(whole) * 1000000n + BigInt(fraction.padEnd(6, "0"));
  const amount = Number((micros + 9999n) / 10000n);
  if (!cents(amount)) fail("printer_cost_unverified");
  return { cents: amount, currency: "usd" };
}
function usablePayout(payout, live) {
  return payout?.status === "paid" && payout.automatic === true && payout.type === "bank_account" && payout.method === "standard" &&
    payout.reconciliation_status === "completed" && payout.livemode === live && payout.currency === "usd" &&
    cents(payout.amount) && !payout.failure_code && !payout.failure_balance_transaction && !payout.reversed_by;
}
async function transactionsForPayout(get, id) {
  const data = [];
  let cursor;
  for (let page = 0; page < 100; page++) {
    const query = new URLSearchParams({ payout: id, limit: "100", ...(cursor ? { starting_after: cursor } : {}) });
    const result = await get(`balance_transactions?${query}`);
    if (!Array.isArray(result?.data) || typeof result.has_more !== "boolean" || (result.has_more && !result.data.length)) fail("payout_transactions_unverified");
    for (const tx of result.data) {
      if (!validID(tx.id, "txn") || tx.currency !== "usd" || !Number.isSafeInteger(tx.net) || data.some(old => old.id === tx.id)) fail("payout_transactions_unverified");
      data.push(tx);
    }
    if (!result.has_more) return data;
    cursor = result.data.at(-1).id;
  }
  fail("payout_transactions_unverified");
}
function usage(ledger) {
  const payouts = {}, transactions = {};
  let total = 0;
  for (const reservation of Object.values(ledger.reservations)) {
    for (const allocation of reservation.allocations) {
      payouts[allocation.payoutID] = (payouts[allocation.payoutID] || 0) + allocation.cents;
      transactions[allocation.transactionID] = (transactions[allocation.transactionID] || 0) + allocation.cents;
      total += allocation.cents;
    }
  }
  return { payouts, transactions, total };
}
function summary(ledger) {
  const used = usage(ledger);
  const verifiedCents = Object.values(ledger.deposits).reduce((sum, deposit) => sum + (deposit.revoked ? 0 : deposit.printingCents), 0);
  return { verifiedCents, committedCents: used.total, availableCents: Math.max(0, verifiedCents - used.total),
    deposits: Object.entries(ledger.deposits).map(([payoutID, d]) => ({ payoutID, printingCents: d.printingCents, committedCents: used.payouts[payoutID] || 0, revoked: d.revoked })),
    reservations: Object.keys(ledger.reservations).length };
}
async function refresh(ledger, get, live) {
  // Re-read EVERY confirmed payout, including old ones. A paid-only scan or a
  // recorded cursor cannot detect a later failure. Failure revokes permanently.
  for (const [id, deposit] of Object.entries(ledger.deposits)) {
    if (deposit.revoked) continue;
    try {
      const payout = await get(`payouts/${id}`);
      if (payout.id !== id || !usablePayout(payout, live) || payout.amount !== deposit.depositedCents) deposit.revoked = true;
    } catch (error) {
      // An outage denies this operation but does not manufacture a reversal.
      throw error;
    }
  }
}

// Caller MUST serialize this operation through the singleton cash coordinator.
// One durable write contains the complete allocation, before any printer POST.
// Reservations never expire or automatically release, including uncertain jobs.
export async function cashOperation(storage, get, live, input) {
  if (typeof live !== "boolean") fail("cash_mode_unavailable", 503);
  const ledger = structuredClone(await storage.get("printing-cash-v1") || { deposits: {}, reservations: {} });
  try {
    if (input.action === "confirm-deposit") {
      const { payoutID, receiptReference, depositedCents, printingCents, protectedForPrinting } = input;
      if (!validID(payoutID, "po") || !/^[A-Za-z0-9_-]{8,128}$/.test(receiptReference || "") ||
          !cents(depositedCents) || !cents(printingCents) || printingCents > depositedCents || protectedForPrinting !== true) fail("invalid_bank_confirmation", 400);
      const previous = ledger.deposits[payoutID];
      if (previous) {
        if (previous.revoked || previous.receiptReference !== receiptReference || previous.depositedCents !== depositedCents || previous.printingCents !== printingCents) fail("bank_confirmation_conflict");
        await refresh(ledger, get, live);
        return summary(ledger);
      }
      if (Object.values(ledger.deposits).some(d => d.receiptReference === receiptReference)) fail("bank_receipt_already_used");
      const payout = await get(`payouts/${payoutID}`);
      if (payout.id !== payoutID || !usablePayout(payout, live) || payout.amount !== depositedCents) fail("payout_not_confirmable");
      const transactions = await transactionsForPayout(get, payoutID);
      // The reconciled payout's net, including refunds/adjustments, is the cap.
      const net = transactions.reduce((sum, tx) => sum + tx.net, 0);
      if (!Number.isSafeInteger(net) || net !== payout.amount) fail("payout_net_mismatch");
      const charges = transactions.filter(tx => tx.type === "charge" || tx.type === "payment");
      if (charges.some(tx => Object.values(ledger.deposits).some(d => d.transactions[tx.id]))) fail("funding_already_attributed");
      ledger.deposits[payoutID] = { receiptReference, depositedCents, printingCents, revoked: false,
        confirmedAt: new Date().toISOString(), transactions: Object.fromEntries(charges.filter(tx => tx.net > 0).map(tx => [tx.id, tx.net])) };
      return summary(ledger);
    }
    if (input.action === "revoke-deposit") {
      if (!validID(input.payoutID, "po") || !ledger.deposits[input.payoutID]) fail("deposit_not_found", 404);
      ledger.deposits[input.payoutID].revoked = true;
      return summary(ledger);
    }
    await refresh(ledger, get, live);
    if (input.action === "inspect" || input.action === "refresh") return summary(ledger);
    const funding = normalizedFunding(input.funding);
    if (input.action === "eligible") return { eligible: Boolean(funding && funding.every(id => Object.values(ledger.deposits).some(d => !d.revoked && d.transactions[id] > 0))) };
    if (input.action !== "reserve") fail("invalid_cash_action", 400);
    if (!funding || !cents(input.costCents) || input.currency !== "usd" ||
        !/^[a-f0-9]{64}$/.test(input.parcelKey || "") || !/^[a-f0-9]{64}$/.test(input.fingerprint || "")) fail("invalid_cash_reservation", 400);
    const previous = ledger.reservations[input.parcelKey];
    if (previous && (previous.fingerprint !== input.fingerprint || JSON.stringify(previous.funding) !== JSON.stringify(funding))) fail("cash_reservation_changed");
    const deposits = funding.map(id => Object.entries(ledger.deposits).find(([, d]) => !d.revoked && d.transactions[id] > 0));
    if (deposits.some(d => !d)) return { reserved: false, reason: "deposit_unverified" };
    const used = usage(ledger);
    const chargeCaps = {};
    for (let i = 0; i < funding.length; i++) {
      // A held welcome book must recheck its ORIGINAL charge, even when a new
      // invoice is now latest. Cancellation alone does not revoke earned cash.
      const tx = await get(`balance_transactions/${funding[i]}?expand%5B%5D=source`);
      const charge = tx?.source;
      if (tx?.id !== funding[i] || tx.currency !== "usd" || !cents(tx.net) ||
          charge?.paid !== true || charge.livemode !== live || charge.currency !== "usd" ||
          charge.refunded || charge.disputed || !cents(charge.amount) ||
          !Number.isSafeInteger(charge.amount_refunded) || charge.amount_refunded < 0) return { reserved: false, reason: "charge_unavailable" };
      chargeCaps[funding[i]] = Math.max(0, Math.min(deposits[i][1].transactions[funding[i]], tx.net - charge.amount_refunded));
    }
    if (funding.some(id => (used.transactions[id] || 0) > chargeCaps[id])) return { reserved: false, reason: "charge_cash_insufficient" };
    let needed = Math.max(0, input.costCents - (previous?.costCents || 0));
    if (summary(ledger).verifiedCents - used.total < needed) return { reserved: false, reason: "cash_insufficient" };
    const allocations = [];
    for (let i = 0; i < funding.length && needed > 0; i++) {
      const [payoutID, d] = deposits[i];
      const transactionID = funding[i];
      const available = Math.min(d.printingCents - (used.payouts[payoutID] || 0), chargeCaps[transactionID] - (used.transactions[transactionID] || 0));
      const amount = Math.max(0, Math.min(needed, available));
      if (!amount) continue;
      allocations.push({ payoutID, transactionID, cents: amount });
      used.payouts[payoutID] = (used.payouts[payoutID] || 0) + amount;
      needed -= amount;
    }
    if (needed > 0) return { reserved: false, reason: "cash_insufficient" };
    ledger.reservations[input.parcelKey] = { fingerprint: input.fingerprint, funding,
      costCents: Math.max(previous?.costCents || 0, input.costCents), allocations: [...(previous?.allocations || []), ...allocations] };
    return { reserved: true };
  } finally {
    // This also persists observed reversals when a later verification fails.
    await storage.put("printing-cash-v1", ledger);
  }
}
