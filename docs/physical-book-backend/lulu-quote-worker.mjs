import { issueMembershipRecovery } from './membership-recovery-issuer.mjs';
import { verifiedRecoveryContact } from './membership-recovery-contact.mjs';
import { createGmailRecoveryDelivery } from './gmail-recovery-delivery.mjs';
import { luluTracking } from './lulu-tracking.mjs';
import { readRecoveryIssuance, requestMembershipRecovery, readRecoveryRedemption, redeemMembershipRecovery } from './membership-recovery.mjs';
import { coordinateMembershipOwnership, MembershipOwnershipError } from './membership-ownership.mjs';
import { MonthlyIssueError, readMonthlyMembershipOwner, recordMonthlyMembershipOwner, markMonthlyMembershipGift, issueMonthlySession, serveMonthlyContent } from './monthly-issues.mjs';

const DEFAULT_SHIPPING_LEVELS = [
  { id: "MAIL", displayName: "Mail", estimatedDaysMin: 5, estimatedDaysMax: 10 },
  { id: "PRIORITY_MAIL", displayName: "Priority Mail", estimatedDaysMin: 3, estimatedDaysMax: 5 },
  { id: "EXPRESS", displayName: "Express", estimatedDaysMin: 1, estimatedDaysMax: 3 },
];

const QUOTE_TTL_SECONDS = 15 * 60;
const PRINT_FILE_TTL_SECONDS = 48 * 60 * 60;
const CLIENT_SESSION_TTL_SECONDS = 15 * 60;
const PAYMENT_PENDING_TTL_SECONDS = 24 * 60 * 60;
const ORDER_ACCESS_TTL_SECONDS = 90 * 24 * 60 * 60;
const RECONCILIATION_TTL_SECONDS = 30 * 24 * 60 * 60;
const PAID_WITHOUT_PRINT_ALERT_SECONDS = 30 * 60;
const RECONCILIATION_ALERT_COOLDOWN_SECONDS = 24 * 60 * 60;
const MEMBERSHIP_DISPATCH_TTL_SECONDS = 120 * 24 * 60 * 60;
const MEMBERSHIP_CUSTOMS_TTL_SECONDS = 500 * 24 * 60 * 60;
const SECURITY_ALERT_EMAIL_TO = "snow.potions@gmail.com";
const SECURITY_ALERT_EMAIL_FROM = "print-desk-alerts@reenchanted.app";
const DEFAULT_PRINTED_BOOK_TAX_CODE = "txcd_35010000";
const DEFAULT_PERIODICAL_TAX_CODE = "txcd_35020200";
const DEFAULT_SHIPPING_TAX_CODE = "txcd_92010001";
// Membership responses use pre-Basil invoice/payment and period fields.
const STRIPE_API_VERSION = "2024-06-20";
// The Bound Year membership.
//
// Sold here rather than through in-app purchase because it is four printed
// books: Apple's own rule requires physical goods to use a payment method other
// than IAP, which is the same reason the one-off books already check out
// through Stripe. Cancelling is not a purchase at all, so it needs no
// permission from anybody and belongs in the app where the reader can find it.
//
// Price ids come from the environment. Absent, the endpoints fail closed rather
// than guessing — the same posture as every other secret here.
const BOUND_YEAR_CADENCES = new Map([
  ["monthly", { envKey: "STRIPE_BOUND_YEAR_MONTHLY_PRICE", interval: "month" }],
  ["annual", { envKey: "STRIPE_BOUND_YEAR_ANNUAL_PRICE", interval: "year" }],
]);

function boundYearPriceID(env, cadence) {
  const config = BOUND_YEAR_CADENCES.get(cadence);
  if (!config) {
    throw new HTTPError(400, "unsupported_cadence", "The Bound Year is billed monthly or yearly.");
  }
  const priceID = env[config.envKey];
  if (!priceID) {
    throw new HTTPError(503, "membership_not_configured", "The Bound Year is not open yet.");
  }
  return priceID;
}

function canonicalCheckoutJSON(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalCheckoutJSON).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${canonicalCheckoutJSON(value[key])}`).join(",")}}`;
  return JSON.stringify(value);
}

function readMembershipPayment(id, env) {
  return stripeGet(env, `subscriptions/${encodeURIComponent(id)}?expand%5B%5D=latest_invoice.payment_intent.latest_charge`);
}

function verifiedMembershipPayment(subscription, env) {
  const invoice = subscription?.latest_invoice;
  const payment = invoice?.payment_intent;
  const charge = payment?.latest_charge;
  const cadence = subscription?.metadata?.reenchanted_cadence;
  const price = BOUND_YEAR_CADENCES.get(cadence);
  return Boolean(price && env[price.envKey] && subscription.status === "active" &&
    subscription.livemode === (env.CHECKOUT_MODE !== "test") &&
    subscription.metadata?.reenchanted_physical_fulfillment === "accepted" &&
    subscription.items?.data?.some(item => item.price?.id === env[price.envKey]) &&
    Number(subscription.current_period_end) * 1000 > Date.now() &&
    invoice?.subscription === subscription.id && invoice.status === "paid" && invoice.paid === true && invoice.amount_paid > 0 &&
    payment?.status === "succeeded" && charge?.paid === true && !charge.refunded && !charge.disputed &&
    Number.isFinite(charge.amount) && Number.isFinite(charge.amount_refunded) &&
    charge.amount_refunded >= 0 && charge.amount_refunded < charge.amount);
}

async function openMembershipCheckout(request, env, gift = false, action = "open") {
  const attemptID = requiredHeader(request, "X-Purchase-Attempt-ID");
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(attemptID)) {
    throw new HTTPError(400, "invalid_purchase_attempt", "This purchase needs a valid saved attempt.");
  }
  if (!env.PHYSICAL_BOOK_ORDER_COORDINATOR) throw new HTTPError(503, "order_coordinator_unavailable", "The secure print desk is not configured.");
  const { installationHash } = await clientFingerprint(request);
  const attemptKey = await sha256Hex(`${env.CHECKOUT_MODE}:${installationHash}:${gift ? "gift" : "membership"}:${attemptID.toLowerCase()}`);
  const stub = env.PHYSICAL_BOOK_ORDER_COORDINATOR.get(env.PHYSICAL_BOOK_ORDER_COORDINATOR.idFromName(`checkout:${attemptKey}`));
  const response = await stub.fetch("https://order-coordinator.internal/checkout", {
    method: "POST", body: JSON.stringify({ fulfillmentKind: "membership-checkout", attemptKey, installationHash, gift, action, purchase: action === "open" ? await request.json() : null }),
  });
  const body = await response.json();
  if (!response.ok) throw new HTTPError(response.status, body.error, body.message);
  return body;
}

/// Opens a membership as an incomplete subscription and hands back the client
/// secret for its first payment. The app confirms it with the same Stripe sheet
/// the one-off books use, so there is one checkout in the product, not two.
async function createBoundYearMembership(request, env, options = {}) {
  const post = options.post || ((path, fields) => stripePost(env, path, fields));
  const cadence = String(request?.cadence || "");
  const priceID = boundYearPriceID(env, cadence);
  const email = String(request?.contactEmail || "").trim();
  if (!email.includes("@")) {
    throw new HTTPError(400, "invalid_contact_email", "A working email is needed for the parcels.");
  }
  const shippingAddress = canonicalShippingAddress(request?.shippingAddress);
  requireRecipientTaxID(shippingAddress);
  if (request?.acceptsLuluFulfillment !== true) {
    throw new HTTPError(400, "fulfillment_consent_required", "The print house disclosure must be accepted before opening a Bound Year.");
  }

  const openedAt = new Date(options.openedAt || Date.now());
  const startMonth = openedAt.toISOString().slice(0, 7);
  // Noon UTC on the first keeps every supported local calendar in the same
  // month. The app already counts seasons from the membership month, not its
  // day-of-month; returning the normalized anchor prevents a month mismatch
  // for a reader subscribing near midnight at either edge of the world.
  const startedAt = Math.floor(Date.UTC(
    openedAt.getUTCFullYear(), openedAt.getUTCMonth(), 1, 12,
  ) / 1000);
  const customer = await post("customers", {
    email,
    "address[line1]": shippingAddress.street1,
    "address[line2]": shippingAddress.street2,
    "address[city]": shippingAddress.city,
    "address[state]": shippingAddress.stateCode,
    "address[country]": shippingAddress.countryCode,
    "address[postal_code]": shippingAddress.postalCode,
    "tax[validate_location]": "immediately",
    ...stripeCustomerShippingFields(shippingAddress),
  });
  await storeMembershipCustomsID(env, customer.id, shippingAddress);
  let subscription;
  try {
    subscription = await post("subscriptions", {
      customer: customer.id,
      "items[0][price]": priceID,
      "automatic_tax[enabled]": "true",
      payment_behavior: "default_incomplete",
      "payment_settings[save_default_payment_method]": "on_subscription",
      "expand[0]": "latest_invoice.payment_intent",
      "metadata[reenchanted_cadence]": cadence,
      "metadata[reenchanted_physical_fulfillment]": "accepted",
      "metadata[reenchanted_start_month]": startMonth,
      ...(options.prepaidGift ? {
        // A gift is one already-paid year, never a bill that follows the giver
        // forever. Stripe keeps the subscription active through the paid year
        // and closes it at that boundary.
        cancel_at_period_end: "true",
        "metadata[reenchanted_gift]": "true",
      } : {}),
    });
  } catch (error) {
    await env.PHYSICAL_BOOK_ORDERS.delete(membershipCustomsStorageKey(customer.id));
    throw error;
  }

  const intent = subscription?.latest_invoice?.payment_intent;
  if (!intent?.client_secret) {
    throw new HTTPError(502, "membership_payment_unavailable", "Stripe did not open a payment for that membership.");
  }
  return {
    membershipID: subscription.id,
    customerID: customer.id,
    cadence,
    status: subscription.status,
    clientSecret: intent.client_secret,
    currentPeriodEnd: subscription.current_period_end ?? null,
    startedAt,
    paymentVerified: verifiedMembershipPayment(subscription, env),
  };
}

async function createBoundYearGift(request, env, options = {}) {
  const senderName = giftName(request?.senderName, "senderName");
  const recipientName = giftName(request?.recipientName, "recipientName");
  const message = giftMessage(request?.message);
  const membership = await createBoundYearMembership({
    cadence: "annual",
    contactEmail: request?.contactEmail,
    shippingAddress: request?.shippingAddress,
    acceptsLuluFulfillment: request?.acceptsLuluFulfillment,
  }, env, { ...options, prepaidGift: true });

  await markMonthlyMembershipGift(env, membership.membershipID);
  const created = await storeNewGift(env, {
    kind: "boundYear",
    status: "paymentPending",
    senderName,
    recipientName,
    message,
    membershipID: membership.membershipID,
    membershipStartedAt: membership.startedAt,
    membershipPaidThrough: membership.currentPeriodEnd,
    destinationCountryCode: String(request?.shippingAddress?.countryCode || "").trim().toUpperCase(),
    destinationPostalCode: String(request?.shippingAddress?.postalCode || "").trim(),
  }, options.claimToken);
  return { membership, gift: created };
}

async function createBookGift(request, env, checkoutToken) {
  const senderName = giftName(request?.senderName, "senderName");
  const recipientName = giftName(request?.recipientName, "recipientName");
  const message = giftMessage(request?.message);
  const contactEmail = normalizeEmail(request?.contactEmail);
  if (!isPlausibleEmail(contactEmail)) {
    throw new HTTPError(400, "invalid_contact_email", "A working email is needed for the gift receipt.");
  }
  const quoteID = String(request?.quoteID || "");
  const paymentIntentID = String(request?.paymentIntentID || "");
  const claimToken = await sha256Hex(`book-gift:${checkoutToken}:${paymentIntentID}`);
  const existingGift = await storedGiftCreated(claimToken, env);
  if (existingGift) return existingGift;
  const record = await requireQuoteRecord(env, quoteID, checkoutToken, { allowExpiredAfterPayment: true });
  const quote = record.quote;
  const includedEditionKind = quote.request.editionKind;
  const includedPageCount = GIFT_PRESS_PAGE_COUNTS.get(includedEditionKind);
  const giftableVariants = GIFT_PRESS_VARIANTS.get(includedEditionKind);
  if (
    !includedPageCount ||
    !giftableVariants?.has(quote.request.variant.id) ||
    quote.request.pageCount !== includedPageCount ||
    !String(quote.request.editionID || "").startsWith(`gift-pass-${includedEditionKind}-`)
  ) {
    throw new HTTPError(409, "gift_quote_mismatch", "That checkout is not the edition and binding chosen for this gift.");
  }
  if (record.paymentIntentID !== paymentIntentID || record.contactEmail !== contactEmail) {
    throw new HTTPError(409, "gift_payment_mismatch", "That payment does not belong to this gift.");
  }
  const selectedShippingOption = quote.shippingOptions.find(
    (option) => option.id === request?.selectedShippingOptionID,
  );
  if (!selectedShippingOption || record.selectedShippingOptionID !== selectedShippingOption.id) {
    throw new HTTPError(409, "shipping_option_mismatch", "That delivery choice does not belong to this gift.");
  }
  const paymentShape = {
    quoteID,
    quoteRequest: quote.request,
    paymentIntentID,
    contactEmail,
    selectedShippingOptionID: selectedShippingOption.id,
    selectedShippingOption,
  };
  await verifyPaidPaymentIntent(paymentShape, record, env);
  const allowance = priceBreakdownFromStoredQuote(quote, selectedShippingOption).total;
  const deliveryEnvelope = await sealGiftDeliveryAddress({
    name: recipientName,
    street1: quote.request.shipTo.street1,
    street2: quote.request.shipTo.street2,
    city: quote.request.shipTo.city,
    stateCode: quote.request.shipTo.stateCode,
    countryCode: quote.request.shipTo.countryCode,
    postalCode: quote.request.shipTo.postalCode,
    phoneNumber: quote.request.shipTo.phoneNumber,
    recipientTaxID: quote.request.shipTo.recipientTaxID,
  }, claimToken);
  const created = await storeNewGift(env, {
    kind: "bookOfRecipient",
    status: "readyToClaim",
    senderName,
    recipientName,
    message,
    paymentIntentID,
    allowanceCents: allowance.cents,
    allowanceCurrencyCode: allowance.currencyCode,
    includedEditionKind,
    includedVariantID: quote.request.variant.id,
    includedPageCount,
    destinationCountryCode: quote.request.shipTo.countryCode,
    destinationPostalCode: quote.request.shipTo.postalCode,
    deliveryEnvelope,
  }, claimToken);
  // This payment bought a promise that will go to press later. It is not a
  // stuck paid order, so remove it from the paid-without-print alarm ledger.
  await clearPaymentAwaitingPrint(env, quoteID);
  // The destination was needed to price postage, not to become a gift memory.
  // Keep only the country/postal allowance on the gift record and shed the
  // full quote address as soon as the paid promise exists.
  await redactFulfilledQuoteRecord(env, record);
  return created;
}

function giftName(value, field) {
  const name = String(value || "").trim().replace(/\s+/g, " ");
  if (!name || name.length > 80) {
    throw new HTTPError(400, `invalid_${field}`, `${field} must be between 1 and 80 characters.`);
  }
  return name;
}

function giftMessage(value) {
  const message = cleanOptionalString(value);
  if (message && message.length > 280) {
    throw new HTTPError(400, "invalid_gift_message", "A gift note may be at most 280 characters.");
  }
  return message || null;
}

async function sealGiftDeliveryAddress(address, claimToken) {
  const keyMaterial = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(claimToken),
  );
  const key = await crypto.subtle.importKey(
    "raw",
    keyMaterial,
    { name: "AES-GCM" },
    false,
    ["encrypt"],
  );
  const nonce = new Uint8Array(12);
  crypto.getRandomValues(nonce);
  const sealed = await crypto.subtle.encrypt(
    {
      name: "AES-GCM",
      iv: nonce,
      additionalData: new TextEncoder().encode("reenchanted-gift-address-v1"),
    },
    key,
    new TextEncoder().encode(JSON.stringify(address)),
  );
  return {
    algorithm: "A256GCM",
    nonce: bytesToBase64URL(nonce),
    sealedAddress: bytesToBase64URL(new Uint8Array(sealed)),
  };
}

function giftStorageKey(tokenHash) {
  return `book-gifts/claim/${tokenHash}`;
}

function giftPaymentIndexKey(paymentIntentID) {
  return `book-gifts/payment/${paymentIntentID}`;
}

function giftMembershipIndexKey(membershipID) {
  return `book-gifts/membership/${membershipID}`;
}

async function storedGiftCreated(claimToken, env) {
  requireOrderStorage(env);
  const serialized = await env.PHYSICAL_BOOK_ORDERS.get(
    giftStorageKey(await sha256Hex(claimToken)),
  );
  if (!serialized) return null;
  const record = JSON.parse(serialized);
  return {
    gift: publicGiftSummary(await refreshGiftReadiness(await giftWithRefundStatus(record, env), env)),
    claimToken,
    shareURL: `https://reenchanted.app/gift.html#${encodeURIComponent(claimToken)}`,
  };
}

async function storeNewGift(env, fields, suppliedClaimToken = null) {
  requireOrderStorage(env);
  const claimToken = suppliedClaimToken || randomToken();
  const claimTokenHash = await sha256Hex(claimToken);
  const existing = await env.PHYSICAL_BOOK_ORDERS.get(giftStorageKey(claimTokenHash));
  if (existing) {
    const record = JSON.parse(existing);
    // The gift may have been saved just before its receipt index write failed.
    if (record.membershipID) await env.PHYSICAL_BOOK_ORDERS.put(giftMembershipIndexKey(record.membershipID), claimTokenHash);
    if (record.paymentIntentID) await env.PHYSICAL_BOOK_ORDERS.put(giftPaymentIndexKey(record.paymentIntentID), claimTokenHash);
    return {
      gift: publicGiftSummary(record),
      claimToken,
      shareURL: `https://reenchanted.app/gift.html#${encodeURIComponent(claimToken)}`,
    };
  }
  const createdAt = new Date().toISOString();
  const record = {
    id: crypto.randomUUID(),
    ...fields,
    claimTokenHash,
    createdAt,
    claimedAt: null,
    redeemedAt: null,
  };
  await env.PHYSICAL_BOOK_ORDERS.put(giftStorageKey(claimTokenHash), JSON.stringify(record));
  if (record.paymentIntentID) {
    await env.PHYSICAL_BOOK_ORDERS.put(giftPaymentIndexKey(record.paymentIntentID), claimTokenHash);
  }
  if (record.membershipID) {
    await env.PHYSICAL_BOOK_ORDERS.put(giftMembershipIndexKey(record.membershipID), claimTokenHash);
  }
  return {
    gift: publicGiftSummary(record),
    claimToken,
    // The token stays in the URL fragment. Browsers do not send fragments to
    // the web server, so the landing page can open the app without logging it.
    shareURL: `https://reenchanted.app/gift.html#${encodeURIComponent(claimToken)}`,
  };
}

async function readGiftRecord(claimToken, env) {
  requireOrderStorage(env);
  const serialized = await env.PHYSICAL_BOOK_ORDERS.get(
    giftStorageKey(await sha256Hex(String(claimToken || ""))),
  );
  if (!serialized) {
    throw new HTTPError(404, "gift_not_found", "That gift doorway was not found.");
  }
  return giftWithRefundStatus(JSON.parse(serialized), env);
}

async function giftWithRefundStatus(record, env) {
  if (record.kind === "bookOfRecipient" &&
      await env.PHYSICAL_BOOK_ORDERS.get(parcelRefundResolutionKey(`gift:${record.id}`))) {
    return { ...record, status: "refunded" };
  }
  return record;
}

async function saveGiftRecord(record, env) {
  await env.PHYSICAL_BOOK_ORDERS.put(giftStorageKey(record.claimTokenHash), JSON.stringify(record));
}

async function refreshGiftReadiness(record, env) {
  if (record.kind === "bookOfRecipient" && ["readyToClaim", "claimed"].includes(record.status)) {
    try {
      await verifyBookGiftPayment(record, env);
    } catch (error) {
      // A dispute or partial refund is not proof of a full refund. Show a
      // payment hold without rewriting ownership or losing a printer receipt.
      if (error instanceof HTTPError && error.code === "payment_not_available") {
        return { ...record, status: "paymentPending" };
      }
      throw error;
    }
    return record;
  }
  if (record.kind !== "boundYear" || !record.membershipID || !["paymentPending", "readyToClaim"].includes(record.status)) {
    return record;
  }
  const subscription = await readMembershipPayment(record.membershipID, env);
  if (verifiedMembershipPayment(subscription, env)) {
    const updated = {
      ...record,
      status: "readyToClaim",
      membershipPaidThrough: subscription.current_period_end ?? record.membershipPaidThrough,
    };
    return updated;
  }
  if (record.status === "readyToClaim") {
    const updated = { ...record, status: "paymentPending", membershipPaidThrough: null };
    return updated;
  }
  return record;
}

function publicGiftSummary(record) {
  return {
    id: record.id,
    kind: record.kind,
    status: record.status,
    senderName: record.senderName,
    recipientName: record.recipientName,
    message: record.message || null,
    createdAt: record.createdAt,
    claimedAt: record.claimedAt || null,
    redeemedAt: record.redeemedAt || null,
    includedEditionKind: record.includedEditionKind || null,
    includedVariantID: record.includedVariantID || null,
    includedPageCount: record.includedPageCount || null,
    destinationCountryCode: record.destinationCountryCode || null,
    destinationPostalCode: record.destinationPostalCode || null,
  };
}

async function readGiftSummary(claimToken, env) {
  const record = await refreshGiftReadiness(await readGiftRecord(claimToken, env), env);
  return publicGiftSummary(record);
}

async function claimGift(claimToken, installationHash, env, reserve) {
  let record = await readGiftRecord(claimToken, env);
  let subscription;
  if (record.kind === "boundYear") {
    subscription = await readMembershipPayment(record.membershipID, env);
    if (!verifiedMembershipPayment(subscription, env)) throw new HTTPError(402, "gift_payment_pending", "That gift does not have a verified payment yet.");
    if (record.status === "paymentPending") record = { ...record, status: "readyToClaim" };
  }
  if (record.status === "paymentPending") {
    throw new HTTPError(402, "gift_payment_pending", "That gift has not finished paying yet.");
  }
  if (["declined", "refunded"].includes(record.status)) {
    throw new HTTPError(410, "gift_closed", "That gift doorway has closed.");
  }
  if (
    record.claimedInstallationHash &&
    !constantTimeEqual(record.claimedInstallationHash, installationHash)
  ) {
    throw new HTTPError(409, "gift_already_claimed", "That gift already belongs to another Book.");
  }
  if (record.kind === "bookOfRecipient" && record.status !== "redeemed") {
    await verifyBookGiftPayment(record, env);
  }
  // The durable decision is the authority across restarts and KV propagation.
  // Reserve before publishing either the gift or monthly ownership record.
  await reserve({ action: "claim", installationHash });
  if (!record.claimedInstallationHash) {
    record = {
      ...record,
      status: "claimed",
      claimedAt: new Date().toISOString(),
      claimedInstallationHash: installationHash,
    };
    await saveGiftRecord(record, env);
  }

  const response = { gift: publicGiftSummary(record), pressPass: null };
  if (record.kind === "bookOfRecipient") {
    response.pressPass = {
      giftID: record.id,
      senderName: record.senderName,
      recipientName: record.recipientName,
      message: record.message || null,
      includedEditionKind: record.includedEditionKind || "monthly",
      includedVariantID: record.includedVariantID,
      maximumPageCount: record.includedPageCount,
      allowance: {
        currencyCode: record.allowanceCurrencyCode,
        cents: record.allowanceCents,
      },
      destinationCountryCode: record.destinationCountryCode,
      destinationPostalCode: record.destinationPostalCode,
      deliveryEnvelope: record.deliveryEnvelope || null,
    };
  } else if (record.kind === "boundYear") {
    await markMonthlyMembershipGift(env, record.membershipID);
    await recordMonthlyMembershipOwner(env, record.membershipID, installationHash);
    response.membershipID = record.membershipID;
    response.membershipCadence = "annual";
    response.membershipStatus = subscription.status;
    response.membershipStartedAt = record.membershipStartedAt;
    response.membershipPaidThrough = subscription.current_period_end ?? record.membershipPaidThrough;
  }
  return response;
}

async function declineGift(claimToken, env, reserve) {
  const record = await readGiftRecord(claimToken, env);
  if (record.claimedInstallationHash || ["claimed", "redeemed"].includes(record.status)) {
    throw new HTTPError(409, "gift_already_claimed", "A claimed gift cannot be declined from its opening link.");
  }
  if (record.status === "refunded") throw new HTTPError(410, "gift_closed", "That gift doorway has closed.");
  await reserve({ action: "decline" });
  const updated = { ...record, status: "declined", declinedAt: new Date().toISOString() };
  await saveGiftRecord(updated, env);
  return publicGiftSummary(updated);
}

async function changeGiftClaim(claimToken, request, env, action) {
  if (!env.PHYSICAL_BOOK_ORDER_COORDINATOR) throw new HTTPError(503, "order_coordinator_unavailable", "The secure gift desk is not configured.");
  const { installationHash } = await clientFingerprint(request);
  const id = env.PHYSICAL_BOOK_ORDER_COORDINATOR.idFromName(`gift-claim:${await sha256Hex(claimToken)}`);
  const response = await env.PHYSICAL_BOOK_ORDER_COORDINATOR.get(id).fetch("https://order-coordinator.internal/gift-claim", {
    method: "POST", body: JSON.stringify({ fulfillmentKind: "gift-claim", claimToken, installationHash, action }),
  });
  const body = await response.json();
  if (!response.ok) throw new HTTPError(response.status, body.error, body.message);
  return body;
}

async function readBoundYearMembership(membershipID, env) {
  const subscription = await readMembershipPayment(membershipID, env);
  const customer = await membershipCustomer(subscription, env);
  const startMonth = /^(\d{4})-(0[1-9]|1[0-2])$/.exec(subscription.metadata?.reenchanted_start_month || "");
  return {
    cadence: subscription.metadata?.reenchanted_cadence ?? null,
    startedAt: startMonth ? Math.floor(Date.UTC(Number(startMonth[1]), Number(startMonth[2]) - 1, 1, 12) / 1000) : null,
    membershipID: subscription.id,
    status: subscription.status,
    cancelAtPeriodEnd: Boolean(subscription.cancel_at_period_end),
    currentPeriodEnd: subscription.current_period_end ?? null,
    paymentVerified: verifiedMembershipPayment(subscription, env),
    shippingAddressPresent: Boolean(customer?.shipping?.address?.line1),
    shippingAddressSummary: shippingAddressSummary(customer?.shipping),
  };
}

async function updateBoundYearShippingAddress(membershipID, request, env) {
  const subscription = await stripeGet(env, `subscriptions/${encodeURIComponent(membershipID)}`);
  const customerID = stripeCustomerID(subscription.customer);
  if (!customerID) {
    throw new HTTPError(502, "membership_customer_unavailable", "Stripe did not return the parcel record for that membership.");
  }
  const shippingAddress = canonicalShippingAddress(request?.shippingAddress);
  requireRecipientTaxID(shippingAddress);
  const customer = await stripePost(env, `customers/${encodeURIComponent(customerID)}`, {
    ...stripeCustomerShippingFields(shippingAddress),
  });
  await storeMembershipCustomsID(env, customerID, shippingAddress);
  return {
    membershipID: subscription.id,
    shippingAddressPresent: Boolean(customer?.shipping?.address?.line1),
    shippingAddressSummary: shippingAddressSummary(customer?.shipping),
  };
}

/// Stops a membership **at the end of the period already paid for**, never
/// immediately. The reader bought those months and the volumes they earn; a
/// cancellation that voided them on the spot would be taking back something
/// already paid for, which is the debt this whole design refuses to create.
async function cancelBoundYearMembership(membershipID, env) {
  const subscription = await stripePost(env, `subscriptions/${encodeURIComponent(membershipID)}`, {
    cancel_at_period_end: "true",
  });
  return {
    membershipID: subscription.id,
    status: subscription.status,
    cancelAtPeriodEnd: Boolean(subscription.cancel_at_period_end),
    currentPeriodEnd: subscription.current_period_end ?? null,
  };
}

async function stripePost(env, path, fields, idempotencyKey = null) {
  requireEnv(env, "STRIPE_SECRET_KEY");
  const response = await fetch(`https://api.stripe.com/v1/${path}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.STRIPE_SECRET_KEY}`,
      "Stripe-Version": STRIPE_API_VERSION,
      ...(idempotencyKey ? { "Idempotency-Key": idempotencyKey } : {}),
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: stripeFormBody(fields),
  });
  if (!response.ok) {
    throw new HTTPError(502, "stripe_error", "The payment desk could not complete that request. Try again shortly.");
  }
  return response.json();
}

async function stripeGet(env, path, apiVersion = STRIPE_API_VERSION) {
  requireEnv(env, "STRIPE_SECRET_KEY");
  const response = await fetch(`https://api.stripe.com/v1/${path}`, {
    headers: { Authorization: `Bearer ${env.STRIPE_SECRET_KEY}`, ...(apiVersion ? { "Stripe-Version": apiVersion } : {}) },
  });
  if (!response.ok) {
    throw new HTTPError(502, "stripe_error", "The payment desk could not check that record. Try again shortly.");
  }
  return response.json();
}

async function createStripeTaxCalculation(env, input) {
  const address = input.quoteRequest.shipTo;
  const calculation = await stripePost(env, "tax/calculations", {
    currency: input.quoteRequest.currencyCode.toLowerCase(),
    "customer_details[address][line1]": address.street1,
    "customer_details[address][line2]": address.street2,
    "customer_details[address][city]": address.city,
    "customer_details[address][state]": address.stateCode,
    "customer_details[address][postal_code]": address.postalCode,
    "customer_details[address][country]": address.countryCode,
    "customer_details[address_source]": "shipping",
    "line_items[0][amount]": input.productCents,
    "line_items[0][quantity]": input.quoteRequest.quantity,
    "line_items[0][reference]": input.reference,
    "line_items[0][tax_behavior]": "exclusive",
    "line_items[0][tax_code]": input.quoteRequest.variant.id === "saddle-stitched-weekly-6x9"
      ? (env.STRIPE_PERIODICAL_TAX_CODE || DEFAULT_PERIODICAL_TAX_CODE)
      : (env.STRIPE_PRINTED_BOOK_TAX_CODE || DEFAULT_PRINTED_BOOK_TAX_CODE),
    "shipping_cost[amount]": input.shippingCents,
    "shipping_cost[tax_behavior]": "exclusive",
    "shipping_cost[tax_code]": env.STRIPE_SHIPPING_TAX_CODE || DEFAULT_SHIPPING_TAX_CODE,
  });
  if (!calculation?.id || calculation.currency !== input.quoteRequest.currencyCode.toLowerCase()) {
    throw new HTTPError(502, "tax_calculation_invalid", "Stripe returned an unusable tax calculation.");
  }
  return calculation;
}

function stripeTaxAmountCents(calculation) {
  const amount = Number(calculation?.tax_amount_exclusive || 0);
  if (!Number.isSafeInteger(amount) || amount < 0) {
    throw new HTTPError(502, "tax_calculation_invalid", "Stripe returned an unusable tax amount.");
  }
  return amount;
}

async function createStripeTaxTransaction(env, calculationID, quoteID) {
  requireEnv(env, "STRIPE_SECRET_KEY");
  const response = await fetch("https://api.stripe.com/v1/tax/transactions/create_from_calculation", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.STRIPE_SECRET_KEY}`,
      "Idempotency-Key": `physical-book-tax:${quoteID}`,
      "Content-Type": "application/x-www-form-urlencoded",
      Accept: "application/json",
    },
    body: stripeFormBody({
      calculation: calculationID,
      reference: `physical-book:${quoteID}`,
      "metadata[quote_id]": quoteID,
    }),
  });
  if (!response.ok) {
    const body = await response.text();
    throw new HTTPError(502, "tax_transaction_failed", `Stripe Tax transaction failed: ${body.slice(0, 200)}`);
  }
  return response.json();
}

function canonicalShippingAddress(value) {
  const address = {
    name: cleanOptionalString(value?.name),
    street1: cleanOptionalString(value?.street1),
    street2: cleanOptionalString(value?.street2),
    city: cleanOptionalString(value?.city),
    stateCode: cleanOptionalString(value?.stateCode)?.toUpperCase(),
    countryCode: cleanOptionalString(value?.countryCode)?.toUpperCase(),
    postalCode: cleanOptionalString(value?.postalCode),
    phoneNumber: cleanOptionalString(value?.phoneNumber),
    recipientTaxID: canonicalRecipientTaxID(value?.recipientTaxID),
  };
  if (!address.name || !address.street1 || !address.city || !address.countryCode || !address.postalCode) {
    throw new HTTPError(400, "invalid_shipping_address", "A complete delivery address is needed for the seasonal books.");
  }
  if (!RECIPIENT_TAX_ID_COUNTRIES.has(address.countryCode)) address.recipientTaxID = undefined;
  return address;
}

const RECIPIENT_TAX_ID_COUNTRIES = new Set(["BR", "CL", "MX"]);

function canonicalRecipientTaxID(value) {
  const compact = cleanOptionalString(value)?.toUpperCase().replace(/[.\-\/\s]/g, "");
  if (!compact) return undefined;
  if (!/^[A-Z0-9]{5,32}$/.test(compact)) {
    throw new HTTPError(400, "invalid_recipient_tax_id", "That customs tax identifier is not in a form the printer can use.");
  }
  return compact;
}

function requireRecipientTaxID(address) {
  if (RECIPIENT_TAX_ID_COUNTRIES.has(String(address?.countryCode || "").toUpperCase()) && !address?.recipientTaxID) {
    throw new HTTPError(400, "recipient_tax_id_required", "This destination requires the recipient's customs tax identifier before a parcel can be priced.");
  }
}

function membershipCustomsStorageKey(customerID) {
  return `bound-year-customs/${sanitizeObjectPathSegment(customerID)}`;
}

async function membershipCustomsEncryptionKey(env) {
  requireEnv(env, "MEMBERSHIP_CUSTOMS_ENCRYPTION_KEY");
  if (String(env.MEMBERSHIP_CUSTOMS_ENCRYPTION_KEY).length < 32) {
    throw new HTTPError(503, "membership_customs_not_configured", "The protected customs ledger is not configured.");
  }
  const material = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(String(env.MEMBERSHIP_CUSTOMS_ENCRYPTION_KEY)),
  );
  return crypto.subtle.importKey("raw", material, { name: "AES-GCM" }, false, ["encrypt", "decrypt"]);
}

async function encryptMembershipCustomsID(env, recipientTaxID) {
  const key = await membershipCustomsEncryptionKey(env);
  const iv = new Uint8Array(12);
  crypto.getRandomValues(iv);
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    new TextEncoder().encode(recipientTaxID),
  );
  return JSON.stringify({
    version: 1,
    iv: bytesToBase64URL(iv),
    ciphertext: bytesToBase64URL(new Uint8Array(ciphertext)),
  });
}

function base64URLToBytes(value) {
  const base64 = String(value || "").replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
  return Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
}

async function decryptMembershipCustomsID(env, serialized) {
  const envelope = JSON.parse(serialized);
  if (envelope?.version !== 1 || !envelope.iv || !envelope.ciphertext) {
    throw new HTTPError(500, "membership_customs_unreadable", "The protected customs ledger could not be read.");
  }
  const key = await membershipCustomsEncryptionKey(env);
  try {
    const plaintext = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: base64URLToBytes(envelope.iv) },
      key,
      base64URLToBytes(envelope.ciphertext),
    );
    return new TextDecoder().decode(plaintext);
  } catch {
    throw new HTTPError(500, "membership_customs_unreadable", "The protected customs ledger could not be read.");
  }
}

async function storeMembershipCustomsID(env, customerID, address) {
  requireOrderStorage(env);
  const key = membershipCustomsStorageKey(customerID);
  if (!RECIPIENT_TAX_ID_COUNTRIES.has(address.countryCode)) {
    await env.PHYSICAL_BOOK_ORDERS.delete(key);
    return;
  }
  requireRecipientTaxID(address);
  await env.PHYSICAL_BOOK_ORDERS.put(
    key,
    await encryptMembershipCustomsID(env, address.recipientTaxID),
    { expirationTtl: MEMBERSHIP_CUSTOMS_TTL_SECONDS },
  );
}

async function readMembershipCustomsID(env, customerID, countryCode) {
  if (!RECIPIENT_TAX_ID_COUNTRIES.has(String(countryCode || "").toUpperCase())) return undefined;
  requireOrderStorage(env);
  const key = membershipCustomsStorageKey(customerID);
  const serialized = await env.PHYSICAL_BOOK_ORDERS.get(key);
  if (!serialized) {
    throw new HTTPError(409, "membership_customs_missing", "This parcel needs its recipient customs tax identifier before it can be posted.");
  }
  const recipientTaxID = await decryptMembershipCustomsID(env, serialized);
  await env.PHYSICAL_BOOK_ORDERS.put(key, serialized, { expirationTtl: MEMBERSHIP_CUSTOMS_TTL_SECONDS });
  return recipientTaxID;
}

function stripeCustomerShippingFields(address) {
  return {
    "shipping[name]": address.name,
    "shipping[address][line1]": address.street1,
    "shipping[address][line2]": address.street2,
    "shipping[address][city]": address.city,
    "shipping[address][state]": address.stateCode,
    "shipping[address][country]": address.countryCode,
    "shipping[address][postal_code]": address.postalCode,
    "shipping[phone]": address.phoneNumber,
  };
}

function stripeCustomerID(customer) {
  if (typeof customer === "string") return customer;
  return customer?.id || null;
}

async function membershipCustomer(subscription, env) {
  const customerID = stripeCustomerID(subscription?.customer);
  return customerID ? stripeGet(env, `customers/${encodeURIComponent(customerID)}`) : null;
}

function shippingAddressSummary(shipping) {
  const address = shipping?.address;
  if (!address?.line1) return null;
  return [address.city, address.state, address.postal_code, address.country]
    .map(cleanOptionalString)
    .filter(Boolean)
    .join(", ");
}

// The deliberately empty upsell catalogue. If the house later offers an extra
// copy or commissioned art with a real incremental cost, its price must live
// here because the Worker rejects client-supplied amounts.
//
// Cover authorship is part of the book: the reader's photograph, a rotating
// Bindery plate, or the Book's own choice are all included. Binding is chosen
// once, as the real print variant, so a paid "upgrade" can never disagree with
// the geometry of the uploaded cover. This catalogue stays empty until an
// option with a real incremental fulfilment cost (such as an additional copy)
// is implemented end to end.
const PRINT_OPTIONS = [];

function printOptionsFor(variantID) {
  return PRINT_OPTIONS.filter(
    (option) => !option.appliesToVariantIDs || option.appliesToVariantIDs.includes(variantID),
  );
}

/// Resolves selected ids against the catalogue for a given binding. An id the
/// catalogue does not recognise — or one that does not apply to this binding —
/// is refused outright, exactly like an unknown print variant. A client cannot
/// invent an option any more than it can invent a price.
function resolvePrintOptions(selectedOptionIDs, variantID) {
  const ids = Array.isArray(selectedOptionIDs) ? selectedOptionIDs : [];
  const unique = [...new Set(ids)].sort();
  const available = new Map(printOptionsFor(variantID).map((option) => [option.id, option]));
  const resolved = [];
  for (const id of unique) {
    const option = available.get(id);
    if (!option) {
      throw new HTTPError(400, "unsupported_print_option", "That extra is not offered for this binding.");
    }
    resolved.push(option);
  }
  // Two options that both change the binding would fight over the SKU.
  const rebinds = resolved.filter((option) => option.resultingVariantID);
  if (rebinds.length > 1) {
    throw new HTTPError(400, "conflicting_print_options", "Only one binding change at a time.");
  }
  return resolved;
}

function printOptionsSubtotalCents(options, quantity) {
  const perCopy = options.reduce((sum, option) => sum + option.priceDeltaCents, 0);
  return perCopy * Math.max(0, quantity || 1);
}

// Must match PhysicalBookVariant.id(for:) and the PrintSpec luluPackageIDs in
// Shared. This map is the authority: a variant absent here is refused, so a
// binding added on the client without a line here simply cannot be ordered.
const ALLOWED_VARIANTS = new Map([
  ["cloth-foil-hardcover-6x9", "0600X0900.FC.STD.LW.060UW444.MNG"],
  ["illustrated-hardcover-6x9", "0600X0900.FC.STD.CW.060UW444.MXX"],
  // The Bound Year's seasonal volume.
  ["perfect-bound-softcover-6x9", "0600X0900.FC.STD.PB.060UW444.MXX"],
  ["saddle-stitched-weekly-6x9", "0600X0900.FC.PRE.SS.060UW444.MXX"],
]);

const VARIANT_PAGE_LIMITS = new Map([
  ["cloth-foil-hardcover-6x9", { minimum: 24, maximum: 800, multiple: 2 }],
  ["illustrated-hardcover-6x9", { minimum: 24, maximum: 800, multiple: 2 }],
  ["perfect-bound-softcover-6x9", { minimum: 32, maximum: 800, multiple: 2 }],
  ["saddle-stitched-weekly-6x9", { minimum: 4, maximum: 48, multiple: 4 }],
]);

// These two maps are the server-side twin of BookGiftEditionAllowance and
// PrintSpec.printableVariants(for:). A gift is an exact physical promise, so a
// forged client cannot turn a paid weekly issue into an annual hardcase.
const GIFT_PRESS_PAGE_COUNTS = new Map([
  ["weekly", 48],
  ["monthly", 200],
  ["seasonal", 400],
  ["annual", 800],
]);

const CALENDAR_BOOK_VARIANTS = new Set([
  "perfect-bound-softcover-6x9",
  "illustrated-hardcover-6x9",
  "cloth-foil-hardcover-6x9",
]);

const GIFT_PRESS_VARIANTS = new Map([
  ["weekly", new Set(["saddle-stitched-weekly-6x9"])],
  ["monthly", CALENDAR_BOOK_VARIANTS],
  ["seasonal", CALENDAR_BOOK_VARIANTS],
  ["annual", CALENDAR_BOOK_VARIANTS],
]);

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204 });
    }

    try {
      return await routeRequest(request, env);
    } catch (error) {
      if (error instanceof HTTPError || error instanceof MonthlyIssueError || error instanceof MembershipOwnershipError) {
        return jsonResponse(
          { error: error.code, message: error.message },
          { status: error.status },
        );
      }
      return jsonResponse(
        { error: "physical_book_request_failed", message: "The print desk could not complete that request." },
        { status: 500 },
      );
    }
  },
  async scheduled(_controller, env, ctx) {
    ctx.waitUntil(auditPaidOrdersAwaitingPrint(env));
  },
};

export class PhysicalBookOrderCoordinator {
  constructor(state, env) {
    this.state = state;
    this.env = env;
  }

  async fetch(request) {
    try {
      const payload = await request.json();
      if (payload.fulfillmentKind === "membership-ownership") {
        if (["prepare-recovery", "redeem-recovery", "issue-recovery"].includes(payload.action)
            && this.env.MEMBERSHIP_RECOVERY_ENABLED !== "true") {
          throw new HTTPError(503, "membership_recovery_disabled", "Membership recovery is not available yet.");
        }
        const task = (this.ownershipInflight || Promise.resolve()).catch(() => {}).then(() => {
          if (payload.action === "issue-recovery") {
            this.recoveryDelivery ??= createGmailRecoveryDelivery(this.env);
            return issueMembershipRecovery({ storage: this.state.storage,
              legacyOwners: this.env.PHYSICAL_BOOK_ORDERS, env: this.env, payload,
              verifyRecipient: id => verifiedRecoveryContact(this.env, id,
                membershipID => readMembershipPayment(membershipID, this.env),
                customerID => stripeGet(this.env, `customers/${encodeURIComponent(customerID)}`)),
              deliver: this.recoveryDelivery });
          }
          return coordinateMembershipOwnership(this.state.storage, this.env.PHYSICAL_BOOK_ORDERS, payload);
        });
        this.ownershipInflight = task;
        try { return jsonResponse(await task); }
        finally { if (this.ownershipInflight === task) this.ownershipInflight = null; }
      }
      if (payload.fulfillmentKind === "gift-claim") {
        const task = (this.giftClaimInflight || Promise.resolve()).catch(() => {}).then(() => this.changeGiftClaim(payload));
        this.giftClaimInflight = task;
        try { return jsonResponse(await task); }
        finally { if (this.giftClaimInflight === task) this.giftClaimInflight = null; }
      }
      if (payload.fulfillmentKind === "membership-checkout") {
        // Queue rather than sharing a response: a different body using the same
        // attempt ID must reach the fingerprint check, even while one is open.
        const task = (this.checkoutInflight || Promise.resolve()).catch(() => {}).then(() => payload.action === "cancel"
          ? this.cancelMembershipCheckout(payload) : this.openMembershipCheckout(payload));
        this.checkoutInflight = task;
        try { return jsonResponse(await task, { status: 201 }); }
        finally { if (this.checkoutInflight === task) this.checkoutInflight = null; }
      }
      // Operator holds and fulfillment share one queue. Checking a flag outside
      // this queue would let an order slip through during an awaited write.
      const task = (this.orderQueue || Promise.resolve()).catch(() => {}).then(() => this.runOrderOperation(payload));
      this.orderQueue = task;
      try { return jsonResponse(await task, { status: ["reconciliation", "parcel-support"].includes(payload.fulfillmentKind) ? 200 : 201 }); }
      finally { if (this.orderQueue === task) this.orderQueue = null; }
    } catch (error) {
      if (error instanceof MembershipOwnershipError) {
        return jsonResponse({ error: error.code }, { status: error.status });
      }
      if (error instanceof HTTPError) {
        return jsonResponse({ error: error.code, message: error.message }, { status: error.status });
      }
      return jsonResponse(
        { error: "physical_book_request_failed", message: "The print desk could not complete that request." },
        { status: 500 },
      );
    }
  }

  async runOrderOperation(payload) {
    if (payload.fulfillmentKind === "parcel-support") return this.inspectOrHoldParcel(payload);
    if (payload.fulfillmentKind === "reconciliation") return this.reconcileOneOff(payload);
    if (await this.state.storage.get("operator-hold")) {
      throw new HTTPError(409, "order_on_hold", "The Bindery has stopped this parcel to check its payment and printing record.");
    }
    const existing = await this.state.storage.get("fulfilled-order");
    if (existing) return existing;
    const submitPrintJob = (token, job) => this.submitPrintJob(token, job);
    const order = await (payload.fulfillmentKind === "membership-dispatch"
      ? fulfillMembershipDispatch(payload.membershipID, payload.seasonKey, payload.dispatchToken, this.env, submitPrintJob)
      : payload.fulfillmentKind === "gift-book"
        ? fulfillGiftBookOrder(payload.claimToken, payload.orderRequest, this.env, payload.checkoutToken, submitPrintJob)
        : fulfillOrder(payload.orderRequest, this.env, payload.checkoutToken, submitPrintJob));
    await this.state.storage.put("fulfilled-order", order);
    return order;
  }

  async inspectOrHoldParcel({ target, action }) {
    if (!["inspect", "hold", "close-refunded"].includes(action)) throw new HTTPError(400, "invalid_support_action", "That support action is not available.");
    const parcel = await requireSupportParcel(this.env, target);
    let hold = await this.state.storage.get("operator-hold");
    if (hold && hold.parcelKey !== parcel.coordinatorKey) {
      throw new HTTPError(409, "parcel_hold_mismatch", "This hold belongs to another parcel.");
    }
    if (action === "hold" && !hold) {
      hold = { parcelKey: parcel.coordinatorKey, heldAt: new Date().toISOString() };
      await this.state.storage.put("operator-hold", hold);
    }
    let resolution = await this.state.storage.get("refund-resolution");
    if (action === "close-refunded") {
      if (!hold) throw new HTTPError(409, "order_hold_required", "Hold this parcel before resolving its refund.");
      const proof = await readParcelRefundProof(this.env, parcel);
      if (!proof.fullyRefunded) throw new HTTPError(409, "refund_not_settled", "The full refund for this parcel could not be verified. It remains on hold.");
      resolution ||= { kind: "fully_refunded", resolvedAt: new Date().toISOString(), target: parcel.target, paymentIntentIDs: proof.paymentIntentIDs };
      // The permanent fulfillment hold is already durable. Publish a separate
      // closure marker; never overwrite a gift record racing with a claim.
      await this.state.storage.put("refund-resolution", resolution);
      await this.env.PHYSICAL_BOOK_ORDERS.put(parcelRefundResolutionKey(parcel.coordinatorKey), JSON.stringify(resolution));
    }
    // Inspect the same durable attempt used by fulfillment. A missing receipt
    // never means that it is safe to submit again, or that Lulu canceled a job.
    const submission = await this.state.storage.get("lulu-submission");
    const order = await this.state.storage.get("fulfilled-order");
    return {
      target: parcel.target, mode: this.env.CHECKOUT_MODE,
      resolution: resolution ? { kind: resolution.kind, resolvedAt: resolution.resolvedAt } : null,
      hold: hold ? { heldAt: hold.heldAt } : null,
      submission: submission ? {
        startedAt: submission.startedAt,
        luluPrintJobID: submission.receipt?.id ?? null,
        diagnostic: submission.diagnostic ?? null,
        requiresPrinterReview: true,
      } : null,
      order: order ? {
        id: order.id, luluPrintJobID: order.luluPrintJobID,
        status: order.status, createdAt: order.createdAt, updatedAt: order.updatedAt,
      } : null,
    };
  }

  async reconcileOneOff({ quoteID, paymentIntentID, action }) {
    const record = await requireReconciliationQuote(this.env, quoteID, paymentIntentID);
    let hold = await this.state.storage.get("operator-hold");
    if (hold && (hold.quoteID !== quoteID || hold.paymentIntentID !== paymentIntentID)) {
      throw new HTTPError(409, "payment_quote_mismatch", "The hold belongs to another checkout.");
    }
    if (action === "hold" && !hold) {
      hold = { quoteID, paymentIntentID, heldAt: new Date().toISOString() };
      await this.state.storage.put("operator-hold", hold);
    }
    if (action === "close-refunded" && !hold) {
      throw new HTTPError(409, "order_hold_required", "Hold this order before resolving its refund.");
    }
    const payment = await readReconciliationPayment(this.env, record);
    const submission = await this.state.storage.get("lulu-submission");
    let resolution = await this.state.storage.get("refund-resolution");
    if (action === "close-refunded") {
      if (!payment.fullyRefunded) {
        throw new HTTPError(409, "refund_not_settled", "Stripe has not confirmed a full, successful refund. The order remains on hold.");
      }
      // This resolves the payment only. It never deletes or changes the printer
      // attempt, even when no receipt was returned or a parcel was canceled.
      resolution ||= { quoteID, paymentIntentID, resolvedAt: new Date().toISOString(), kind: "fully_refunded" };
      await this.state.storage.put("refund-resolution", resolution);
      // Publish before clearing alerts. Retries repair either failed KV write;
      // late payment webhooks also consult this marker instead of reopening it.
      await this.env.PHYSICAL_BOOK_ORDERS.put(refundResolutionKey(quoteID), JSON.stringify(resolution));
      await clearPaymentAwaitingPrint(this.env, quoteID);
      await redactFulfilledQuoteRecord(this.env, record);
    }
    return {
      quoteID, paymentIntentID, mode: this.env.CHECKOUT_MODE,
      hold: hold ? { heldAt: hold.heldAt } : null,
      payment,
      submission: submission ? {
        startedAt: submission.startedAt,
        luluPrintJobID: submission.receipt?.id ?? null,
        diagnostic: submission.diagnostic ?? null,
        requiresPrinterReview: true,
      } : null,
      resolution: resolution ? { kind: resolution.kind, resolvedAt: resolution.resolvedAt } : null,
    };
  }

  async changeGiftClaim(payload) {
    const check = decision => {
      if (!decision) return;
      if (decision.action === "decline" && payload.action === "claim") {
        throw new HTTPError(410, "gift_closed", "That gift doorway has closed.");
      }
      if (decision.action === "claim" && (payload.action !== "claim" || decision.installationHash !== payload.installationHash)) {
        throw new HTTPError(409, "gift_already_claimed", "That gift already belongs to another Book.");
      }
    };
    check(await this.state.storage.get("gift-claim-decision"));
    const reserve = async decision => {
      const previous = await this.state.storage.get("gift-claim-decision");
      check(previous);
      if (!previous) await this.state.storage.put("gift-claim-decision", decision);
    };
    return payload.action === "claim"
      ? claimGift(payload.claimToken, payload.installationHash, this.env, reserve)
      : declineGift(payload.claimToken, this.env, reserve);
  }

  async openMembershipCheckout(payload) {
    if (await this.state.storage.get("checkout-closed")) throw new HTTPError(409, "checkout_closed", "That unpaid purchase has closed. You can open a new one.");
    const requestHash = await sha256Hex(canonicalCheckoutJSON(payload.purchase));
    let attempt = await this.state.storage.get("membership-checkout");
    if (attempt && attempt.requestHash !== requestHash) {
      throw new HTTPError(409, "checkout_attempt_changed", "This purchase is already open with different details. Resume the original purchase before opening another.");
    }
    if (!attempt) {
      attempt = { requestHash, openedAt: Date.now(), claimToken: randomToken() };
      await this.state.storage.put("membership-checkout", attempt);
    }
    const post = async (path, fields) => {
      const key = `checkout-stripe/${path}`;
      let step = await this.state.storage.get(key);
      const fieldsHash = await sha256Hex(canonicalCheckoutJSON(fields));
      if (step && step.fieldsHash !== fieldsHash) {
        throw new HTTPError(409, "checkout_configuration_changed", "The purchase settings changed while this payment was opening. The Bindery needs to check it.");
      }
      if (step?.id) {
        return path === "subscriptions"
          ? readMembershipPayment(step.id, this.env)
          : { id: step.id };
      }
      if (step && Date.now() - step.startedAt >= 23 * 60 * 60 * 1000) {
        throw new HTTPError(409, "checkout_recovery_required", "This interrupted purchase needs a check at the Bindery before another payment can open.");
      }
      if (!step) {
        step = { fieldsHash, startedAt: Date.now() };
        await this.state.storage.put(key, step);
      }
      const result = await stripePost(this.env, path, fields, `bound-year:${payload.attemptKey}:${path}`);
      if (!result?.id) throw new HTTPError(502, "checkout_receipt_missing", "The payment desk did not return its receipt. Resume this purchase to check again.");
      // Keep IDs, never Stripe's address-bearing customer/subscription response.
      await this.state.storage.put(key, { ...step, id: result.id });
      return result;
    };
    const options = { post, openedAt: attempt.openedAt, claimToken: attempt.claimToken };
    if (payload.gift) return createBoundYearGift(payload.purchase, this.env, options);
    const membership = await createBoundYearMembership(payload.purchase, this.env, options);
    await recordMonthlyMembershipOwner(this.env, membership.membershipID, payload.installationHash);
    return membership;
  }

  async cancelMembershipCheckout(payload) {
    if (await this.state.storage.get("checkout-closed")) return { canceled: true };
    const step = await this.state.storage.get("checkout-stripe/subscriptions");
    if (step) {
      if (!step.id) throw new HTTPError(409, "checkout_recovery_required", "The payment desk needs to locate this interrupted purchase before it can close.");
      let subscription = await readMembershipPayment(step.id, this.env);
      if (subscription.status !== "incomplete_expired") {
        const invoice = subscription.latest_invoice;
        const payment = invoice?.payment_intent;
        if (subscription.status !== "incomplete" || invoice?.subscription !== step.id ||
            invoice.status !== "open" || invoice.amount_paid !== 0 || invoice.paid !== false ||
            !["requires_payment_method", "requires_confirmation", "requires_action"].includes(payment?.status) || !invoice.id) {
          throw new HTTPError(409, "checkout_payment_not_cancelable", "This payment may already be moving or paid. Continue the saved purchase to check its receipt.");
        }
        // Voiding the initial invoice cancels its PaymentIntent and expires an
        // incomplete subscription. Stripe must reject a race won by payment.
        await stripePost(this.env, `invoices/${encodeURIComponent(invoice.id)}/void`, {}, `bound-year:${payload.attemptKey}:void`);
        subscription = await readMembershipPayment(step.id, this.env);
        if (subscription.status !== "incomplete_expired") {
          throw new HTTPError(409, "checkout_recovery_required", "The payment desk has not confirmed this purchase closed. Keep it saved until it can be checked.");
        }
      }
    }
    // No subscription step means no subscription POST was ever attempted.
    // This also blocks a delayed opening request that arrives after cancellation.
    await this.state.storage.put("checkout-closed", { closedAt: Date.now() });
    return { canceled: true };
  }

  async submitPrintJob(token, payload) {
    // KV expiry and an in-memory lock cannot protect an external side effect
    // across a restart. Persist the attempt BEFORE contacting the print house.
    // A lost response must never be interpreted as permission to print again.
    const payloadHash = await sha256Hex(JSON.stringify(payload));
    const previous = await this.state.storage.get("lulu-submission");
    if (previous) {
      if (previous.payloadHash !== payloadHash) {
        throw new HTTPError(409, "print_submission_changed", "This parcel already has a submission on record. The Bindery needs to check it before its files or address can change.");
      }
      if (previous.receipt) return previous.receipt;
      // Search is not an idempotency guarantee. A single exact match can
      // recover a receipt; no match must NEVER authorize a replacement POST.
      const recovered = await findSubmittedLuluPrintJob(this.env, token, previous.externalID);
      if (recovered) return this.savePrintReceipt(previous, recovered);
      throw new HTTPError(409, "print_submission_uncertain", "The print house may already have this parcel. The Bindery needs to check before it can be sent again.");
    }
    const attempt = { payloadHash, externalID: payload.external_id, startedAt: new Date().toISOString() };
    await this.state.storage.put("lulu-submission", attempt);
    let result;
    try {
      result = await fetchLuluPrintJobCreate(this.env, token, payload);
      if (!result?.id) throw new LuluPrintSubmissionError({ kind: "invalid_receipt" });
    } catch (error) {
      // Network errors, malformed receipts and upstream failures may follow an
      // accepted job. Leave the durable attempt intact for reconciliation.
      // Keep only controlled categories and schema field names, never Lulu's
      // error prose: it can echo an address, email or private PDF capability.
      const diagnostic = error instanceof LuluPrintSubmissionError
        ? error.diagnostic : { kind: "transport_or_receipt" };
      console.warn("lulu_print_submission_uncertain", diagnostic);
      try {
        await this.state.storage.put("lulu-submission", { ...attempt, diagnostic });
      } catch {
        // The original pre-request marker still prevents a second POST.
      }
      throw new HTTPError(409, "print_submission_uncertain", "The print house may already have this parcel. The Bindery needs to check before it can be sent again.");
    }
    return this.savePrintReceipt(attempt, result);
  }

  async savePrintReceipt(attempt, result) {
    // Do not persist Lulu's full response: it can contain the shipping address.
    const receipt = {
      id: result.id,
      status: { name: result.status?.name },
      ...luluTracking(result),
    };
    await this.state.storage.put("lulu-submission", { ...attempt, receipt });
    return receipt;
  }
}

async function routeRequest(request, env) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";

  if (["/memberships/recovery/request", "/api/physical-books/memberships/recovery/request"].includes(path)
      && request.method === "POST") {
    if (env.MEMBERSHIP_RECOVERY_ENABLED !== "true" || env.GMAIL_RECOVERY_DELIVERY_ENABLED !== "true")
      throw new HTTPError(503, "membership_recovery_disabled", "Membership recovery is not available yet.");
    await requireClientSession(request, env);
    await requireRateLimit(request, env, "membership-recovery-request");
    const input = await readRecoveryIssuance(request);
    const { installationHash } = await clientFingerprint(request);
    return jsonResponse(await requestMembershipRecovery(env, installationHash, input),
      { status: 202, headers: { "Cache-Control": "private, no-store" } });
  }

  if (["/memberships/recovery/redeem", "/api/physical-books/memberships/recovery/redeem"].includes(path)
      && request.method === "POST") {
    if (env.MEMBERSHIP_RECOVERY_ENABLED !== "true")
      throw new HTTPError(503, "membership_recovery_disabled", "Membership recovery is not available yet.");
    await requireClientSession(request, env);
    await requireRateLimit(request, env, "membership-recovery");
    const proof = await readRecoveryRedemption(request);
    const { installationHash } = await clientFingerprint(request);
    return jsonResponse(await redeemMembershipRecovery(env, installationHash, proof),
      { headers: { "Cache-Control": "private, no-store" } });
  }

  if (path === "/monthly-issues/session" && request.method === "POST") {
    await requireClientSession(request, env);
    await requireRateLimit(request, env, "monthly-session");
    const reader = request.body?.getReader();
    if (!reader) throw new MonthlyIssueError(400, "invalid_monthly_proof");
    let size = 0;
    const chunks = [];
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 64 * 1024) { await reader.cancel(); throw new MonthlyIssueError(413, "monthly_proof_too_large"); }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let cursor = 0;
    for (const chunk of chunks) { bytes.set(chunk, cursor); cursor += chunk.length; }
    let body;
    try { body = JSON.parse(new TextDecoder().decode(bytes)); }
    catch { throw new MonthlyIssueError(400, "invalid_monthly_proof"); }
    const fingerprint = await clientFingerprint(request);
    const result = await issueMonthlySession(body, env, fingerprint.installationHash,
      // Pin the fields this proof validates; Stripe moved period/payment
      // fields in Basil. Do not inherit a changing account API version.
      id => stripeGet(env, `subscriptions/${encodeURIComponent(id)}?expand%5B%5D=latest_invoice.payment_intent.latest_charge`, "2024-06-20"));
    return jsonResponse(result, { headers: { "Cache-Control": "private, no-store" } });
  }
  if (request.method === "GET" && (path === "/monthly-issues/manifest" || path.startsWith("/monthly-issues/assets/"))) {
    // Rate-limit the expensive proof exchange, not each file with the print
    // desk's 12/minute limit: that would strand any atomic pack with 13 files.
    // Every file still requires a short-lived installation-bound token.
    const fingerprint = await clientFingerprint(request);
    return serveMonthlyContent(request, env, fingerprint.installationHash, path);
  }

  if (
    (path === "/stripe/webhook" || path === "/api/physical-books/stripe/webhook") &&
    request.method === "POST"
  ) {
    return handleStripeWebhook(request, env);
  }

  if ((path === "/sessions" || path === "/api/physical-books/sessions") && request.method === "POST") {
    await requireRateLimit(request, env, "session");
    return jsonResponse(await createClientSession(request, env), { status: 201 });
  }

  if ((path === "/" || path === "/quote" || path === "/api/physical-books/quote") && request.method === "POST") {
    await requireClientSession(request, env);
    await requireRateLimit(request, env, "quote");
    return jsonResponse(await createQuote(await request.json(), env));
  }

  if ((path === "/health" || path === "/api/physical-books/health") && request.method === "GET") {
    return jsonResponse(healthCheck(env));
  }

  // The Bound Year. Subscribing is a physical-goods purchase and so belongs
  // outside in-app purchase; cancelling is not a purchase at all.
  const checkoutCancel = path.match(/^\/(?:api\/physical-books\/)?(memberships|gifts\/bound-year)\/checkout\/cancel$/);
  if (checkoutCancel && request.method === "POST") {
    await requireClientSession(request, env);
    await requireRateLimit(request, env, "checkout-cancel");
    // Like subscription cancellation, this remains available with sales shut.
    return jsonResponse(await openMembershipCheckout(request, env, checkoutCancel[1] === "gifts/bound-year", "cancel"));
  }
  if ((path === "/memberships" || path === "/api/physical-books/memberships") && request.method === "POST") {
    await requireClientSession(request, env);
    requireCheckoutEnabled(env);
    requireBoundYearSalesEnabled(env);
    await requireRateLimit(request, env, "membership");
    return jsonResponse(await openMembershipCheckout(request, env), { status: 201 });
  }

  // Gifts are wrappers around the existing press and membership ledgers. They
  // never contain Book pages; the recipient's app creates print files only when
  // the claimed object is ready to go to Lulu.
  if ((path === "/gifts/books" || path === "/api/physical-books/gifts/books") && request.method === "POST") {
    await requireClientSession(request, env);
    requireCheckoutEnabled(env);
    await requireRateLimit(request, env, "gift-book");
    return jsonResponse(await createBookGift(
      await request.json(),
      env,
      requiredHeader(request, "X-Checkout-Token"),
    ), { status: 201 });
  }

  if ((path === "/gifts/bound-year" || path === "/api/physical-books/gifts/bound-year") && request.method === "POST") {
    await requireClientSession(request, env);
    requireCheckoutEnabled(env);
    requireBoundYearSalesEnabled(env);
    await requireRateLimit(request, env, "gift-bound-year");
    return jsonResponse(await openMembershipCheckout(request, env, true), { status: 201 });
  }

  const giftMatch = path.match(/^\/(?:api\/physical-books\/)?gifts\/([A-Za-z0-9_-]{40,128})$/);
  if (giftMatch && request.method === "GET") {
    await requireClientSession(request, env);
    await requireRateLimit(request, env, "gift-read");
    return jsonResponse(await readGiftSummary(giftMatch[1], env));
  }

  const giftClaimMatch = path.match(/^\/(?:api\/physical-books\/)?gifts\/([A-Za-z0-9_-]{40,128})\/claim$/);
  if (giftClaimMatch && request.method === "POST") {
    await requireClientSession(request, env);
    await requireRateLimit(request, env, "gift-claim");
    return jsonResponse(await changeGiftClaim(giftClaimMatch[1], request, env, "claim"));
  }

  const giftDeclineMatch = path.match(/^\/(?:api\/physical-books\/)?gifts\/([A-Za-z0-9_-]{40,128})\/decline$/);
  if (giftDeclineMatch && request.method === "POST") {
    await requireClientSession(request, env);
    await requireRateLimit(request, env, "gift-decline");
    return jsonResponse(await changeGiftClaim(giftDeclineMatch[1], request, env, "decline"));
  }

  const giftOrderMatch = path.match(/^\/(?:api\/physical-books\/)?gifts\/([A-Za-z0-9_-]{40,128})\/orders$/);
  if (giftOrderMatch && request.method === "POST") {
    await requireClientSession(request, env);
    requireCheckoutEnabled(env);
    await requireRateLimit(request, env, "gift-order");
    return jsonResponse(await createGiftBookOrder(
      giftOrderMatch[1],
      await request.json(),
      request,
      env,
      requiredHeader(request, "X-Checkout-Token"),
    ), { status: 201 });
  }

  const membershipMatch = path.match(/^\/(?:api\/physical-books\/)?memberships\/([A-Za-z0-9_]+)$/);
  if (membershipMatch && request.method === "GET") {
    await requireClientSession(request, env);
    await requireBoundYearOwner(request, env, membershipMatch[1]);
    await requireRateLimit(request, env, "membership");
    return jsonResponse(await readBoundYearMembership(membershipMatch[1], env));
  }

  const cancelMatch = path.match(/^\/(?:api\/physical-books\/)?memberships\/([A-Za-z0-9_]+)\/cancel$/);
  if (cancelMatch && request.method === "POST") {
    await requireClientSession(request, env);
    await requireBoundYearOwner(request, env, cancelMatch[1]);
    // Deliberately not behind `requireCheckoutEnabled`: a reader must be able
    // to stop paying even when the shop is shut.
    await requireRateLimit(request, env, "membership");
    return jsonResponse(await cancelBoundYearMembership(cancelMatch[1], env));
  }

  const membershipShippingMatch = path.match(/^\/(?:api\/physical-books\/)?memberships\/([A-Za-z0-9_]+)\/shipping$/);
  if (membershipShippingMatch && request.method === "POST") {
    await requireClientSession(request, env);
    await requireBoundYearOwner(request, env, membershipShippingMatch[1]);
    await requireRateLimit(request, env, "membership");
    return jsonResponse(await updateBoundYearShippingAddress(
      membershipShippingMatch[1],
      await request.json(),
      env,
    ));
  }

  const dispatchPrepareMatch = path.match(/^\/(?:api\/physical-books\/)?memberships\/([A-Za-z0-9_]+)\/dispatches\/([0-9]{4}-S(?:0[1-9]|1[0-2]))$/);
  if (dispatchPrepareMatch && request.method === "POST") {
    await requireClientSession(request, env);
    await requireBoundYearOwner(request, env, dispatchPrepareMatch[1]);
    requireCheckoutEnabled(env);
    await requireRateLimit(request, env, "membership-dispatch");
    return jsonResponse(await prepareMembershipDispatch(
      dispatchPrepareMatch[1],
      dispatchPrepareMatch[2],
      await request.json(),
      env,
    ), { status: 201 });
  }

  const dispatchUploadMatch = path.match(/^\/(?:api\/physical-books\/)?memberships\/([A-Za-z0-9_]+)\/dispatches\/([0-9]{4}-S(?:0[1-9]|1[0-2]))\/print-files\/(interior|cover)$/);
  if (dispatchUploadMatch && request.method === "POST") {
    await requireClientSession(request, env);
    await requireBoundYearOwner(request, env, dispatchUploadMatch[1]);
    requireCheckoutEnabled(env);
    await requireRateLimit(request, env, "membership-dispatch-upload");
    return jsonResponse(await uploadMembershipDispatchPrintFile(
      request,
      env,
      dispatchUploadMatch[1],
      dispatchUploadMatch[2],
      dispatchUploadMatch[3],
    ), { status: 201 });
  }

  const dispatchSubmitMatch = path.match(/^\/(?:api\/physical-books\/)?memberships\/([A-Za-z0-9_]+)\/dispatches\/([0-9]{4}-S(?:0[1-9]|1[0-2]))\/orders$/);
  if (dispatchSubmitMatch && request.method === "POST") {
    await requireClientSession(request, env);
    await requireBoundYearOwner(request, env, dispatchSubmitMatch[1]);
    requireCheckoutEnabled(env);
    await requireRateLimit(request, env, "membership-dispatch-order");
    return jsonResponse(await createMembershipDispatchOrder(
      dispatchSubmitMatch[1],
      dispatchSubmitMatch[2],
      requiredHeader(request, "X-Membership-Dispatch-Token"),
      env,
    ), { status: 201 });
  }

  // The upsell catalogue for a given binding. Read-only and price-bearing, so
  // it needs a session like everything else, but no checkout capability — the
  // reader is still deciding.
  if ((path === "/options" || path === "/api/physical-books/options") && request.method === "GET") {
    await requireClientSession(request, env);
    await requireRateLimit(request, env, "options");
    const variantID = url.searchParams.get("variantID") || "";
    if (!ALLOWED_VARIANTS.has(variantID)) {
      throw new HTTPError(400, "unsupported_print_variant", "That print binding is not offered.");
    }
    return jsonResponse({ variantID, options: printOptionsFor(variantID) });
  }

  if ((path === "/orders" || path === "/api/physical-books/orders") && request.method === "POST") {
    await requireClientSession(request, env);
    requireCheckoutEnabled(env);
    await requireRateLimit(request, env, "order");
    return jsonResponse(
      await createOrder(await request.json(), env, requiredHeader(request, "X-Checkout-Token")),
      { status: 201 },
    );
  }

  if ((path === "/orders/preview" || path === "/api/physical-books/orders/preview") && request.method === "POST") {
    await requireClientSession(request, env);
    requireCheckoutEnabled(env);
    await requireRateLimit(request, env, "preview");
    return jsonResponse(
      await previewOrder(await request.json(), env, requiredHeader(request, "X-Checkout-Token")),
    );
  }

  const deliveryMatch = path.match(/^\/(?:api\/physical-books\/)?print-files\/delivery\/([a-zA-Z0-9_-]+)$/);
  if (deliveryMatch && request.method === "GET") {
    return servePrintFile(deliveryMatch[1], env);
  }

  const uploadMatch = path.match(/^\/(?:api\/physical-books\/)?print-files\/(interior|cover)$/);
  if (uploadMatch && request.method === "POST") {
    await requireClientSession(request, env);
    requireCheckoutEnabled(env);
    await requireRateLimit(request, env, "upload");
    return jsonResponse(await uploadPrintFile(request, env, uploadMatch[1]), { status: 201 });
  }

  if (
    (path === "/payment-intents" || path === "/api/physical-books/payment-intents") &&
    request.method === "POST"
  ) {
    await requireClientSession(request, env);
    requireCheckoutEnabled(env);
    await requireRateLimit(request, env, "payment-intent");
    return jsonResponse(
      await createPaymentIntent(await request.json(), env, requiredHeader(request, "X-Checkout-Token")),
      { status: 201 },
    );
  }

  const orderMatch = path.match(/^\/(?:api\/physical-books\/)?orders\/([^/]+)$/);
  if (orderMatch && request.method === "GET") {
    await requireClientSession(request, env);
    await requireRateLimit(request, env, "status");
    return jsonResponse(await getOrderStatus(
      orderMatch[1],
      requiredHeader(request, "X-Payment-Intent-ID"),
      requiredHeader(request, "X-Checkout-Token"),
      env,
    ));
  }

  if ((path === "/admin/reconciliation" || path === "/api/physical-books/admin/reconciliation") && request.method === "GET") {
    requireAdminToken(request, env);
    return jsonResponse(await reconciliationStatus(env));
  }

  const supportMatch = path.match(/^\/(?:api\/physical-books\/)?admin\/parcels\/(?:gifts\/(pi_[A-Za-z0-9_]+)|memberships\/(sub_[A-Za-z0-9_]+)\/(\d{4}-S(?:0[1-9]|1[0-2])))(?:\/(hold|close-refunded))?$/);
  if (supportMatch && request.method === (supportMatch[4] ? "POST" : "GET")) {
    requireAdminToken(request, env);
    const target = supportMatch[1]
      ? { kind: "gift", paymentIntentID: supportMatch[1] }
      : { kind: "membership", membershipID: supportMatch[2], seasonKey: supportMatch[3] };
    const parcel = await requireSupportParcel(env, target);
    if (!env.PHYSICAL_BOOK_ORDER_COORDINATOR) throw new HTTPError(503, "order_coordinator_unavailable", "The secure print desk is not configured.");
    const stub = env.PHYSICAL_BOOK_ORDER_COORDINATOR.get(env.PHYSICAL_BOOK_ORDER_COORDINATOR.idFromName(parcel.coordinatorKey));
    const response = await stub.fetch("https://order-coordinator.internal/parcel-support", {
      method: "POST", body: JSON.stringify({ fulfillmentKind: "parcel-support", target, action: supportMatch[4] || "inspect" }),
    });
    return jsonResponse(await response.json(), { status: response.status });
  }

  const reconcileMatch = path.match(/^\/(?:api\/physical-books\/)?admin\/reconciliation\/([A-Za-z0-9_-]+)(?:\/(hold|close-refunded))?$/);
  if (reconcileMatch && request.method === (reconcileMatch[2] ? "POST" : "GET")) {
    requireAdminToken(request, env);
    const record = await requireReconciliationQuote(env, reconcileMatch[1]);
    if (!env.PHYSICAL_BOOK_ORDER_COORDINATOR) throw new HTTPError(503, "order_coordinator_unavailable", "The secure print desk is not configured.");
    const stub = env.PHYSICAL_BOOK_ORDER_COORDINATOR.get(env.PHYSICAL_BOOK_ORDER_COORDINATOR.idFromName(record.paymentIntentID));
    const response = await stub.fetch("https://order-coordinator.internal/reconciliation", {
      method: "POST", body: JSON.stringify({ fulfillmentKind: "reconciliation", quoteID: record.quote.id,
        paymentIntentID: record.paymentIntentID, action: reconcileMatch[2] || "inspect" }),
    });
    const body = await response.json();
    return jsonResponse(body, { status: response.status });
  }

  return jsonResponse({ error: "not_found" }, { status: 404 });
}

function healthCheck(env) {
  const luluCredentialsConfigured = Boolean(env.LULU_AUTH_URL && env.LULU_API_BASE_URL && env.LULU_CLIENT_KEY && env.LULU_CLIENT_SECRET);
  const stripeConfigured = Boolean(env.STRIPE_SECRET_KEY);
  const stripeWebhookConfigured = Boolean(env.STRIPE_WEBHOOK_SECRET);
  const legacyBootstrapTokenConfigured = Boolean(env.PHYSICAL_BOOK_API_TOKEN);
  const adminTokenConfigured = Boolean(env.PHYSICAL_BOOK_ADMIN_TOKEN);
  const alertEmailConfigured = Boolean(env.SECURITY_ALERT_EMAIL);
  const alertWebhookURLValid = !env.SECURITY_ALERT_WEBHOOK_URL || isHTTPSURL(env.SECURITY_ALERT_WEBHOOK_URL);
  const printFileDeliveryBaseURLConfigured = !env.PRINT_FILE_DELIVERY_BASE_URL ||
    isHTTPSURL(env.PRINT_FILE_DELIVERY_BASE_URL);
  const r2Configured = Boolean(env.PHYSICAL_BOOK_FILES);
  const orderStorageConfigured = Boolean(env.PHYSICAL_BOOK_ORDERS);
  const rateLimiterConfigured = Boolean(env.PHYSICAL_BOOK_RATE_LIMITER);
  const orderCoordinatorConfigured = Boolean(env.PHYSICAL_BOOK_ORDER_COORDINATOR);
  const checkout = checkoutRuntimeStatus(env);
  const stripeTaxConfigured = stripeTaxEnabled(env);
  const membershipCustomsEncryptionConfigured = String(env.MEMBERSHIP_CUSTOMS_ENCRYPTION_KEY || "").length >= 32;
  const boundYearLiveSalesEnabled = String(env.BOUND_YEAR_LIVE_SALES_ENABLED || "false").trim().toLowerCase() === "true";
  const boundYearMonthlyPriceConfigured = /^price_[A-Za-z0-9_]+$/.test(String(env.STRIPE_BOUND_YEAR_MONTHLY_PRICE || ""));
  const boundYearAnnualPriceConfigured = /^price_[A-Za-z0-9_]+$/.test(String(env.STRIPE_BOUND_YEAR_ANNUAL_PRICE || ""));
  const infrastructureReady = luluCredentialsConfigured &&
    stripeConfigured &&
    stripeWebhookConfigured &&
    adminTokenConfigured &&
    alertEmailConfigured &&
    alertWebhookURLValid &&
    printFileDeliveryBaseURLConfigured &&
    r2Configured &&
    orderStorageConfigured &&
    rateLimiterConfigured &&
    orderCoordinatorConfigured;
  const testReady = infrastructureReady &&
    checkout.orderingEnabled &&
    checkout.mode === "test" &&
    checkout.environmentAligned;
  const productionReady = infrastructureReady &&
    stripeTaxConfigured &&
    checkout.orderingEnabled &&
    checkout.mode === "live" &&
    checkout.environmentAligned;

  return {
    ok: true,
    readyForConfiguredMode: testReady || productionReady,
    testReady,
    productionReady,
    // Configuration presence only; provider acceptance is a separate rehearsal.
    boundYearTestReady: testReady && boundYearMonthlyPriceConfigured && boundYearAnnualPriceConfigured,
    pricing: {
      weeklyIssueFloorCents: 1_999,
      monthlySoftcoverFloorCents: 4_999,
      seasonalSoftcoverFloorCents: 6_999,
      illustratedHardcoverFloorCents: 8_999,
      clothFoilHardcoverFloorCents: 9_999,
    },
    checks: {
      luluCredentialsConfigured,
      stripeConfigured,
      stripeWebhookConfigured,
      stripeTaxConfigured,
      membershipCustomsEncryptionConfigured,
      boundYearMonthlyPriceConfigured,
      boundYearAnnualPriceConfigured,
      legacyBootstrapTokenConfigured,
      adminTokenConfigured,
      alertEmailConfigured,
      alertWebhookConfigured: Boolean(env.SECURITY_ALERT_WEBHOOK_URL),
      alertWebhookURLValid,
      printFileDeliveryBaseURLConfigured,
      r2Configured,
      orderStorageConfigured,
      rateLimiterConfigured,
      orderCoordinatorConfigured,
      orderingEnabled: checkout.orderingEnabled,
      checkoutMode: checkout.mode,
      checkoutEnvironmentAligned: checkout.environmentAligned,
      boundYearLiveSalesEnabled,
    },
    shippingLevels: configuredShippingLevels(env).map((level) => ({
      id: level.id,
      displayName: level.displayName,
      estimatedDaysMin: level.estimatedDaysMin,
      estimatedDaysMax: level.estimatedDaysMax,
    })),
  };
}

async function handleStripeWebhook(request, env) {
  requireOrderStorage(env);
  requireEnv(env, "STRIPE_WEBHOOK_SECRET");

  const rawBody = await request.text();
  const signatureHeader = request.headers.get("Stripe-Signature");
  if (!signatureHeader) {
    throw new HTTPError(400, "invalid_webhook_signature", "The Stripe-Signature header is required.");
  }
  const event = await verifiedStripeWebhookEvent(
    rawBody,
    signatureHeader,
    env.STRIPE_WEBHOOK_SECRET,
  );
  const eventKey = stripeEventStorageKey(event.id);
  if (await env.PHYSICAL_BOOK_ORDERS.get(eventKey)) {
    return jsonResponse({ received: true, duplicate: true });
  }

  switch (event.type) {
    case "payment_intent.succeeded":
    case "payment_intent.payment_failed":
    case "payment_intent.canceled":
      await reconcileStripePaymentIntentEvent(event, env);
      break;
    default:
      break;
  }

  await env.PHYSICAL_BOOK_ORDERS.put(eventKey, event.type, {
    expirationTtl: 30 * 24 * 60 * 60,
  });
  return jsonResponse({ received: true });
}

async function verifiedStripeWebhookEvent(rawBody, signatureHeader, endpointSecret, now = Date.now()) {
  const signature = parseStripeSignature(signatureHeader);
  const toleranceSeconds = 5 * 60;
  const nowSeconds = Math.floor(now / 1000);
  if (Math.abs(nowSeconds - signature.timestamp) > toleranceSeconds) {
    throw new HTTPError(400, "invalid_webhook_signature", "The webhook signature is outside its allowed time window.");
  }

  const expected = await hmacSHA256Hex(endpointSecret, `${signature.timestamp}.${rawBody}`);
  if (!signature.v1.some((candidate) => constantTimeEqual(candidate, expected))) {
    throw new HTTPError(400, "invalid_webhook_signature", "The webhook signature could not be verified.");
  }

  let event;
  try {
    event = JSON.parse(rawBody);
  } catch {
    throw new HTTPError(400, "invalid_webhook_payload", "The webhook payload is not valid JSON.");
  }
  if (
    !event ||
    typeof event.id !== "string" ||
    !/^evt_[A-Za-z0-9_]+$/.test(event.id) ||
    typeof event.type !== "string" ||
    !event.data ||
    typeof event.data.object !== "object"
  ) {
    throw new HTTPError(400, "invalid_webhook_payload", "The webhook event is missing required fields.");
  }
  return event;
}

function parseStripeSignature(header) {
  const values = new Map();
  for (const component of String(header || "").split(",")) {
    const separator = component.indexOf("=");
    if (separator <= 0) continue;
    const key = component.slice(0, separator).trim();
    const value = component.slice(separator + 1).trim();
    if (!values.has(key)) values.set(key, []);
    values.get(key).push(value);
  }
  const timestamp = Number(values.get("t")?.[0]);
  const v1 = (values.get("v1") || []).filter((value) => /^[a-f0-9]{64}$/i.test(value));
  if (!Number.isSafeInteger(timestamp) || timestamp <= 0 || v1.length === 0) {
    throw new HTTPError(400, "invalid_webhook_signature", "The webhook signature header is malformed.");
  }
  return { timestamp, v1 };
}

async function reconcileStripePaymentIntentEvent(event, env) {
  const paymentIntent = event.data.object;
  if (
    paymentIntent.object !== "payment_intent" ||
    typeof paymentIntent.id !== "string" ||
    !/^pi_[A-Za-z0-9_]+$/.test(paymentIntent.id)
  ) {
    throw new HTTPError(400, "invalid_webhook_payload", "The webhook does not contain a PaymentIntent.");
  }
  const quoteID = String(paymentIntent.metadata?.quote_id || "");
  if (!quoteID) {
    // The Stripe account may deliver unrelated PaymentIntents to this endpoint.
    // Acknowledge them without creating any ReEnchanted state.
    return;
  }
  const record = await readQuoteRecord(env, quoteID);
  if (!record || record.paymentIntentID !== paymentIntent.id) {
    throw new HTTPError(409, "payment_quote_mismatch", "The PaymentIntent is not bound to this quote.");
  }
  if (record.paymentSucceededAt && event.type !== "payment_intent.succeeded") {
    // Stripe can retry events out of order. A terminal success must never be
    // downgraded by an older failure or cancellation event.
    return;
  }
  const selectedShippingOption = record.quote.shippingOptions.find(
    (option) => option.id === record.selectedShippingOptionID,
  );
  if (!selectedShippingOption) {
    throw new HTTPError(409, "shipping_option_mismatch", "The stored shipping option is unavailable.");
  }
  assertPaymentIntentMatchesQuote(paymentIntent, {
    quoteID,
    paymentIntentID: paymentIntent.id,
    quoteRequest: record.quote.request,
    selectedShippingOptionID: record.selectedShippingOptionID,
    selectedShippingOption,
  }, record, { requireSucceeded: event.type === "payment_intent.succeeded" });

  let taxTransactionID = record.taxTransactionID || null;
  if (event.type === "payment_intent.succeeded" && selectedShippingOption.taxCalculationID) {
    const transaction = await createStripeTaxTransaction(
      env,
      selectedShippingOption.taxCalculationID,
      quoteID,
    );
    taxTransactionID = transaction.id;
  }

  const updatedAt = new Date().toISOString();
  const updatedRecord = {
    ...record,
    paymentStatus: String(paymentIntent.status || "unknown"),
    paymentStatusEventID: event.id,
    paymentStatusUpdatedAt: updatedAt,
    ...(taxTransactionID ? { taxTransactionID } : {}),
    ...(event.type === "payment_intent.succeeded"
      ? { paymentSucceededAt: updatedAt }
      : {}),
  };
  await storeQuoteRecord(env, updatedRecord);
  if (event.type === "payment_intent.succeeded") {
    await markPaymentAwaitingPrint(env, {
      quoteID,
      paymentIntentID: paymentIntent.id,
      paidAt: updatedRecord.paymentSucceededAt,
    });
  }
}

function stripeEventStorageKey(eventID) {
  return `stripe-events/${eventID}`;
}

async function createQuote(quoteRequest, env) {
  const canonicalRequest = canonicalQuoteRequest(quoteRequest);
  requireOrderStorage(env);

  const token = await fetchLuluAccessToken(env);
  const quoteRequestWithCity = {
    ...canonicalRequest,
    shipTo: {
      ...canonicalRequest.shipTo,
      city: canonicalRequest.shipTo.city || await lookupCityFromPostalCode(env, canonicalRequest.shipTo),
    },
  };
  const shippingLevels = configuredShippingLevels(env);
  const luluQuotes = await Promise.all(
    shippingLevels.map((level) => fetchLuluCost(env, token, quoteRequestWithCity, level.id)),
  );
  // Quote the object and its cover canvas from the same SKU/page-count pair.
  // The app may have drawn a local proof before it knew the destination, but
  // it must recompose that proof against this authority before checkout.
  const coverDimensions = await fetchLuluCoverDimensions(
    env,
    token,
    quoteRequestWithCity.variant.luluPackageID,
    quoteRequestWithCity.pageCount,
  );

  const manufacturingCents = moneyToCents(
    readLuluMoney(luluQuotes[0], ["print_cost", "printCost", "manufacturing_cost", "manufacturingCost"]),
  );
  const pricingPolicy = standardPricingPolicy();
  const quoteOptions = resolvePrintOptions(
    quoteRequestWithCity.selectedOptionIDs,
    quoteRequestWithCity.variant.id,
  );
  const quoteMarkupCents = retailMarkupSubtotalCents(
    quoteRequestWithCity.variant,
    manufacturingCents,
    quoteRequestWithCity.quantity,
    pricingPolicy,
    quoteRequestWithCity.editionKind,
  ) + printOptionsSubtotalCents(quoteOptions, quoteRequestWithCity.quantity);
  const shippingOptions = await Promise.all(luluQuotes.map(async (quote, index) => {
    const level = shippingLevels[index];
    const shippingCents = moneyToCents(readLuluMoney(quote, ["shipping_cost", "shippingCost", "shipping"]));
    // Lulu's tax is one of our fulfillment costs. It is not the sales tax or
    // VAT ReEnchanted may owe to collect from the reader, so it rides inside
    // delivery instead of being mislabeled at the till.
    const fulfillmentTaxCents = moneyToCents(
      readOptionalLuluMoney(quote, ["tax", "tax_cost", "taxCost", "total_tax", "totalTax"]) || 0,
    );
    const deliveryCents = shippingCents + fulfillmentTaxCents;
    const taxCalculation = stripeTaxEnabled(env)
      ? await createStripeTaxCalculation(env, {
          quoteRequest: quoteRequestWithCity,
          productCents: manufacturingCents + quoteMarkupCents,
          shippingCents: deliveryCents,
          reference: `${quoteRequestWithCity.editionID}:${level.id}`,
        })
      : null;
    return {
      id: level.id,
      displayName: level.displayName,
      estimatedDaysMin: level.estimatedDaysMin,
      estimatedDaysMax: level.estimatedDaysMax,
      price: {
        currencyCode: canonicalRequest.currencyCode,
        cents: deliveryCents,
      },
      estimatedTax: {
        currencyCode: canonicalRequest.currencyCode,
        cents: taxCalculation ? stripeTaxAmountCents(taxCalculation) : 0,
      },
      taxCalculationID: taxCalculation?.id ?? null,
      taxCalculationExpiresAt: taxCalculation?.expires_at ?? null,
    };
  }));
  // The returned request remains compatible with the iOS pricing renderer, but
  // its manufacturing figures now come from Lulu rather than from the caller.
  quoteRequestWithCity.variant = {
    ...quoteRequestWithCity.variant,
    manufacturingBasePriceCentsUSD: manufacturingCents,
    manufacturingPerPagePriceTenThousandthsUSD: 0,
  };

  const id = crypto.randomUUID();
  const checkoutToken = randomToken();
  const quote = {
    id,
    checkoutToken,
    request: quoteRequestWithCity,
    manufacturingSubtotal: {
      currencyCode: canonicalRequest.currencyCode,
      cents: manufacturingCents,
    },
    shippingOptions,
    pricingPolicy,
    expiresAt: new Date(Date.now() + QUOTE_TTL_SECONDS * 1000).toISOString(),
    coverDimensions,
  };
  const { checkoutToken: _, ...storedQuote } = quote;
  await storeQuoteRecord(env, {
    quote: storedQuote,
    checkoutTokenHash: await sha256Hex(checkoutToken),
    createdAt: new Date().toISOString(),
  });
  return quote;
}

async function createPaymentIntent(paymentRequest, env, checkoutToken) {
  validatePaymentIntentRequest(paymentRequest);
  const record = await requireQuoteRecord(env, paymentRequest.quoteID, checkoutToken);
  if (record.piiRedactedAt) {
    throw new HTTPError(409, "order_already_fulfilled", "That paid order has already gone to the printer.");
  }
  const quote = record.quote;
  const selectedShippingOption = quote.shippingOptions.find(
    (option) => option.id === paymentRequest.selectedShippingOption.id,
  );
  if (!selectedShippingOption) {
    throw new HTTPError(409, "shipping_option_mismatch", "That shipping option is not part of this quote.");
  }
  const amount = priceBreakdownFromStoredQuote(quote, selectedShippingOption).total;
  if (stripeTaxEnabled(env) && !selectedShippingOption.taxCalculationID) {
    throw new HTTPError(503, "tax_calculation_unavailable", "Tax could not be calculated for that destination.");
  }
  const stripePaymentIntent = await fetchStripePaymentIntentCreate(env, {
    amount: amount.cents,
    currency: amount.currencyCode.toLowerCase(),
    receipt_email: paymentRequest.contactEmail,
    metadata: {
      quote_id: quote.id,
      edition_id: quote.request.editionID,
      variant_id: quote.request.variant.id,
      lulu_package_id: quote.request.variant.luluPackageID,
      shipping_option_id: selectedShippingOption.id,
      tax_calculation_id: selectedShippingOption.taxCalculationID || "not-configured",
    },
  }, `physical-book:${quote.id}:${selectedShippingOption.id}`);

  await storeQuoteRecord(env, {
    ...record,
    paymentIntentID: stripePaymentIntent.id,
    selectedShippingOptionID: selectedShippingOption.id,
    contactEmail: normalizeEmail(paymentRequest.contactEmail),
  });

  return {
    id: stripePaymentIntent.id,
    clientSecret: stripePaymentIntent.client_secret,
    amount,
    quoteID: quote.id,
    selectedShippingOptionID: selectedShippingOption.id,
  };
}

async function requireBoundYearOwner(request, env, membershipID) {
  requireOrderStorage(env);
  const { installationHash } = await clientFingerprint(request);
  const owner = await readMonthlyMembershipOwner(env, membershipID);
  if (!owner || !constantTimeEqual(owner, installationHash)) {
    throw new HTTPError(403, "membership_not_owned", "That Bound Year belongs to another Book or needs verified recovery.");
  }
}

function membershipDispatchStorageKey(membershipID, seasonKey) {
  return `bound-year-dispatches/${sanitizeObjectPathSegment(membershipID)}/${sanitizeObjectPathSegment(seasonKey)}`;
}

function membershipDispatchPrintFileKey(membershipID, seasonKey, kind) {
  return `${membershipDispatchStorageKey(membershipID, seasonKey)}/print-files/${kind}`;
}

function addUTCMonths(date, months) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + months, 1));
}

async function requireEarnedMembershipSeason(membershipID, seasonKey, env) {
  const subscription = await stripeGet(env, `subscriptions/${encodeURIComponent(membershipID)}`, "2024-06-20");
  const metadata = subscription.metadata || {};
  if (metadata.reenchanted_physical_fulfillment !== "accepted") {
    throw new HTTPError(403, "membership_fulfillment_not_authorized", "That membership has no physical fulfillment consent on record.");
  }
  const cadence = metadata.reenchanted_cadence;
  if (!BOUND_YEAR_CADENCES.has(cadence)) {
    throw new HTTPError(409, "membership_cadence_unknown", "The membership cadence could not be verified.");
  }
  const startMonthText = metadata.reenchanted_start_month;
  const startMatch = String(startMonthText || "").match(/^(\d{4})-(0[1-9]|1[0-2])$/);
  const seasonMatch = String(seasonKey).match(/^(\d{4})-S(0[1-9]|1[0-2])$/);
  if (!startMatch || !seasonMatch) {
    throw new HTTPError(409, "membership_season_unknown", "That season does not belong to this Bound Year.");
  }
  const start = new Date(Date.UTC(Number(startMatch[1]), Number(startMatch[2]) - 1, 1));
  const seasonStart = new Date(Date.UTC(Number(seasonMatch[1]), Number(seasonMatch[2]) - 1, 1));
  const monthOffset = (seasonStart.getUTCFullYear() - start.getUTCFullYear()) * 12 +
    seasonStart.getUTCMonth() - start.getUTCMonth();
  if (monthOffset < 0 || monthOffset % 3 !== 0) {
    throw new HTTPError(403, "membership_season_not_earned", "That season was not earned by this membership.");
  }
  const seasonIndex = monthOffset / 3;
  const seasonEnd = addUTCMonths(seasonStart, 3);
  if (seasonEnd.getTime() > Date.now()) {
    throw new HTTPError(403, "membership_season_not_closed", "That season has not finished yet.");
  }
  await requirePaidMembershipMonths(subscription, cadence, seasonStart, env);
  const customer = await membershipCustomer(subscription, env);
  const shippingAddress = stripeShippingToPhysicalAddress(customer?.shipping);
  shippingAddress.recipientTaxID = await readMembershipCustomsID(
    env,
    stripeCustomerID(customer),
    shippingAddress.countryCode,
  );
  requireRecipientTaxID(shippingAddress);
  return { subscription, customer, shippingAddress, cadence, seasonIndex };
}

async function requirePaidMembershipMonths(subscription, cadence, seasonStart, env) {
  const priceID = boundYearPriceID(env, cadence);
  const live = env.CHECKOUT_MODE !== "test";
  if (subscription.livemode !== live ||
      !(subscription.items?.data || []).some(item => item.price?.id === priceID)) {
    throw new HTTPError(403, "membership_price_mismatch", "That subscription is not the configured Bound Year.");
  }
  const firstMonth = seasonStart.getUTCFullYear() * 12 + seasonStart.getUTCMonth();
  const covered = new Set();
  let cursor;
  // A Bound Year is billed at most monthly. Bound the exceptional long-history
  // walk, and stop as soon as three months are proved. No per-frame work or
  // stored invoice/address copies are added to the Book or the Worker.
  for (let page = 0; page < 12; page += 1) {
    const query = new URLSearchParams({
      subscription: subscription.id, status: "paid", limit: "100",
      "expand[]": "data.payment_intent.latest_charge",
      ...(cursor ? { starting_after: cursor } : {}),
    });
    const invoices = await stripeGet(env, `invoices?${query}`, "2024-06-20");
    if (!Array.isArray(invoices.data)) {
      throw new HTTPError(502, "membership_payment_unavailable", "The paid months could not be checked. Try again shortly.");
    }
    for (const invoice of invoices.data) {
      const payment = invoice.payment_intent;
      const charge = payment?.latest_charge;
      // A future period end, free trial, unpaid renewal or marked-paid invoice
      // is not proof of a settled payment. Full refunds and disputes revoke it.
      if (invoice.subscription !== subscription.id || invoice.livemode !== live ||
          invoice.status !== "paid" || invoice.paid !== true || !(invoice.amount_paid > 0) ||
          payment?.status !== "succeeded" || charge?.paid !== true ||
          charge.refunded === true || charge.disputed === true ||
          !Number.isFinite(charge.amount) || !Number.isFinite(charge.amount_refunded) ||
          charge.amount_refunded < 0 || charge.amount_refunded >= charge.amount) continue;
      for (const line of invoice.lines?.data || []) {
        if (line.type !== "subscription" || line.subscription !== subscription.id ||
            line.proration !== false || line.price?.id !== priceID || !(line.amount > 0)) continue;
        const start = new Date(Number(line.period?.start) * 1000);
        const end = new Date(Number(line.period?.end) * 1000);
        const from = start.getUTCFullYear() * 12 + start.getUTCMonth();
        const until = end.getUTCFullYear() * 12 + end.getUTCMonth();
        // Match the app's calendar-month membership anchor even when Stripe
        // bills on the 21st. Prorated or malformed periods cannot earn a book.
        if (until - from !== (cadence === "annual" ? 12 : 1)) continue;
        for (let month = firstMonth; month < firstMonth + 3; month += 1) {
          if (month >= from && month < until) covered.add(month);
        }
      }
    }
    if (covered.size === 3) return;
    if (!invoices.has_more) break;
    const next = invoices.data.at(-1)?.id;
    if (!next || next === cursor) break;
    cursor = next;
  }
  // Current status does not erase a paid historical season. A canceled or
  // later-past-due membership still gets any three months proved above.
  throw new HTTPError(402, "membership_payment_not_current", "That membership has not paid for all three months of this season.");
}

function stripeShippingToPhysicalAddress(shipping) {
  const address = shipping?.address || {};
  return canonicalShippingAddress({
    name: shipping?.name,
    street1: address.line1,
    street2: address.line2,
    city: address.city,
    stateCode: address.state,
    countryCode: address.country,
    postalCode: address.postal_code,
    phoneNumber: shipping?.phone,
  });
}

async function prepareMembershipDispatch(membershipID, seasonKey, request, env) {
  requireOrderStorage(env);
  const storageKey = membershipDispatchStorageKey(membershipID, seasonKey);
  const existing = await readStoredOrder(env, `${storageKey}/order`);
  if (existing) return { membershipID, seasonKey, alreadySubmitted: true, order: existing };
  const entitlement = await requireEarnedMembershipSeason(membershipID, seasonKey, env);
  const isAnnualVolume = entitlement.seasonIndex % 4 === 3;
  const expectedVariantIDs = isAnnualVolume
    ? ["cloth-foil-hardcover-6x9", "illustrated-hardcover-6x9"]
    : ["perfect-bound-softcover-6x9"];
  const variant = request?.variant || {};
  const expectedVariantID = expectedVariantIDs.includes(variant.id) ? variant.id : null;
  const packageID = expectedVariantID ? ALLOWED_VARIANTS.get(expectedVariantID) : null;
  if (!expectedVariantID || variant.luluPackageID !== packageID) {
    throw new HTTPError(400, "membership_binding_mismatch", "That season has a different prepaid binding.");
  }
  if (Array.isArray(request?.selectedOptionIDs) && request.selectedOptionIDs.length > 0) {
    throw new HTTPError(402, "membership_extras_require_checkout", "Paid extras need their own checkout before this prepaid volume can use them.");
  }
  const editionID = sanitizeObjectPathSegment(request?.editionID);
  if (!request?.editionID || !Number.isInteger(request?.pageCount) || request.pageCount < 24 || request.pageCount > 800 || request.pageCount % 2 !== 0) {
    throw new HTTPError(400, "invalid_membership_dispatch", "That seasonal volume is not ready for the press.");
  }

  const foilStamp = validatedMembershipFoilStamp(request, expectedVariantID);
  const editionTitle = canonicalPrintTitle(request.editionTitle);
  // Cover width is not a client-side estimate: paper bulk, page count, binding,
  // boards and jacket flaps all belong to Lulu's selected SKU. The app renders
  // the cover only after this authoritative canvas comes back.
  const luluToken = await fetchLuluAccessToken(env);
  const coverDimensions = await fetchLuluCoverDimensions(
    env,
    luluToken,
    packageID,
    request.pageCount,
  );

  const dispatchToken = randomToken();
  const record = {
    membershipID,
    seasonKey,
    editionID,
    editionTitle,
    pageCount: request.pageCount,
    variant: {
      id: expectedVariantID,
      luluPackageID: packageID,
    },
    coverDimensions,
    foilStamp,
    dispatchTokenHash: await sha256Hex(dispatchToken),
    preparedAt: new Date().toISOString(),
  };
  await env.PHYSICAL_BOOK_ORDERS.put(storageKey, JSON.stringify(record), {
    expirationTtl: MEMBERSHIP_DISPATCH_TTL_SECONDS,
  });
  return {
    membershipID,
    seasonKey,
    editionID,
    dispatchToken,
    alreadySubmitted: false,
    shippingAddressSummary: shippingAddressSummary(entitlement.customer?.shipping),
    coverDimensions,
  };
}

function normalizedFoilText(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toUpperCase()
    .replace(/\s+/g, " ")
    .trim();
}

function validatedMembershipFoilStamp(request, variantID) {
  if (variantID !== "cloth-foil-hardcover-6x9") return null;
  const title = normalizedFoilText(request?.foilStampTitleText);
  const author = normalizedFoilText(request?.foilStampAuthorText);
  const supported = /^[A-Z0-9 ;',./!`^&*()~+:?"\-]*$/;
  if (!title || !supported.test(title) || !supported.test(author)) {
    throw new HTTPError(400, "invalid_foil_stamp", "The cloth spine contains a character Lulu cannot stamp.");
  }
  if (title.length + author.length > 42) {
    throw new HTTPError(400, "foil_stamp_too_long", "The two cloth-spine lines cannot exceed 42 characters together.");
  }
  return { title, author };
}

async function requireMembershipDispatchRecord(env, membershipID, seasonKey, dispatchToken) {
  requireOrderStorage(env);
  const serialized = await env.PHYSICAL_BOOK_ORDERS.get(membershipDispatchStorageKey(membershipID, seasonKey));
  if (!serialized) {
    throw new HTTPError(404, "membership_dispatch_not_prepared", "That seasonal parcel has not been prepared.");
  }
  const record = JSON.parse(serialized);
  const suppliedHash = await sha256Hex(dispatchToken);
  if (!constantTimeEqual(record.dispatchTokenHash, suppliedHash)) {
    throw new HTTPError(401, "invalid_membership_dispatch_token", "That parcel token does not belong to this season.");
  }
  return record;
}

async function uploadMembershipDispatchPrintFile(request, env, membershipID, seasonKey, kind) {
  if (!env.PHYSICAL_BOOK_FILES) {
    throw new HTTPError(503, "file_storage_unavailable", "Print-file storage is unavailable.");
  }
  const record = await requireMembershipDispatchRecord(
    env, membershipID, seasonKey, requiredHeader(request, "X-Membership-Dispatch-Token"),
  );
  const editionID = requiredHeader(request, "X-Edition-ID");
  if (record.editionID !== editionID) {
    throw new HTTPError(409, "upload_edition_mismatch", "The print file does not belong to this seasonal parcel.");
  }
  const sourceMD5 = requiredHeader(request, "X-Source-MD5").toLowerCase();
  const sourceSHA256 = requiredHeader(request, "X-Source-SHA256").toLowerCase();
  if (!isMD5(sourceMD5) || !/^[a-f0-9]{64}$/.test(sourceSHA256)) {
    throw new HTTPError(400, "invalid_print_file_digest", "The print-file checksums are invalid.");
  }
  if ((request.headers.get("Content-Type") || "") !== "application/pdf") {
    throw new HTTPError(400, "invalid_print_file_type", "Print-file uploads must use Content-Type: application/pdf.");
  }
  const body = await request.arrayBuffer();
  const maxBytes = Number(env.MAX_PRINT_FILE_BYTES || 100 * 1024 * 1024);
  if (body.byteLength === 0 || body.byteLength > maxBytes) {
    throw new HTTPError(400, "invalid_print_file_size", "The print file is empty or too large.");
  }
  const computedSHA256 = await sha256Hex(body);
  if (!constantTimeEqual(sourceSHA256, computedSHA256)) {
    throw new HTTPError(409, "upload_digest_mismatch", "The uploaded print file failed its integrity check.");
  }

  const deliveryBaseURL = printFileDeliveryBaseURL(request, env);
  const deliveryID = randomToken();
  const key = `physical-books/memberships/${sanitizeObjectPathSegment(membershipID)}/${sanitizeObjectPathSegment(seasonKey)}/${kind}-${deliveryID}.pdf`;
  await env.PHYSICAL_BOOK_FILES.put(key, body, {
    httpMetadata: { contentType: "application/pdf" },
    customMetadata: {
      editionID,
      kind,
      sourceMD5,
      sha256: computedSHA256,
      expiresAt: new Date(Date.now() + PRINT_FILE_TTL_SECONDS * 1000).toISOString(),
    },
  });
  const deliveryRecord = {
    key,
    kind,
    md5: sourceMD5,
    expiresAt: new Date(Date.now() + PRINT_FILE_TTL_SECONDS * 1000).toISOString(),
    sourceURL: `${deliveryBaseURL}/print-files/delivery/${deliveryID}`,
  };
  await env.PHYSICAL_BOOK_ORDERS.put(printFileDeliveryKey(deliveryID), JSON.stringify(deliveryRecord), {
    expirationTtl: PRINT_FILE_TTL_SECONDS,
  });
  await env.PHYSICAL_BOOK_ORDERS.put(
    membershipDispatchPrintFileKey(membershipID, seasonKey, kind),
    JSON.stringify(deliveryRecord),
    { expirationTtl: PRINT_FILE_TTL_SECONDS },
  );
  return { kind, sourceURL: deliveryRecord.sourceURL, md5: sourceMD5, byteCount: body.byteLength };
}

async function createMembershipDispatchOrder(membershipID, seasonKey, dispatchToken, env) {
  if (!env.PHYSICAL_BOOK_ORDER_COORDINATOR) {
    throw new HTTPError(503, "order_coordinator_unavailable", "The secure print desk is not configured.");
  }
  const id = env.PHYSICAL_BOOK_ORDER_COORDINATOR.idFromName(`membership:${membershipID}:${seasonKey}`);
  const stub = env.PHYSICAL_BOOK_ORDER_COORDINATOR.get(id);
  const response = await stub.fetch("https://order-coordinator.internal/fulfill", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ fulfillmentKind: "membership-dispatch", membershipID, seasonKey, dispatchToken }),
  });
  const body = await response.json();
  if (!response.ok) {
    throw new HTTPError(response.status, body.error || "membership_dispatch_failed", body.message || "The seasonal parcel could not be sent.");
  }
  return body;
}

async function fulfillMembershipDispatch(membershipID, seasonKey, dispatchToken, env, submitPrintJob) {
  const record = await requireMembershipDispatchRecord(env, membershipID, seasonKey, dispatchToken);
  const storageKey = `${membershipDispatchStorageKey(membershipID, seasonKey)}/order`;
  const existing = await readStoredOrder(env, storageKey);
  if (existing) return existing;
  const entitlement = await requireEarnedMembershipSeason(membershipID, seasonKey, env);
  const [interior, cover] = await Promise.all([
    readStoredOrder(env, membershipDispatchPrintFileKey(membershipID, seasonKey, "interior")),
    readStoredOrder(env, membershipDispatchPrintFileKey(membershipID, seasonKey, "cover")),
  ]);
  if (!interior || !cover) {
    throw new HTTPError(409, "print_files_missing", "Both seasonal print files must be uploaded first.");
  }
  const externalID = sanitizeObjectPathSegment(`bound-year-${membershipID}-${seasonKey}`);
  const payload = {
    external_id: externalID,
    contact_email: entitlement.customer?.email,
    shipping_level: configuredShippingLevels(env)[0].id,
    line_items: [{
      external_id: `${externalID}-item-1`,
      title: canonicalPrintTitle(record.editionTitle),
      pod_package_id: record.variant.luluPackageID,
      quantity: 1,
      interior: { source_url: interior.sourceURL, source_md5sum: interior.md5 },
      cover: { source_url: cover.sourceURL, source_md5sum: cover.md5 },
      ...(record.foilStamp ? {
        foil_stamp_title_text: record.foilStamp.title,
        foil_stamp_author_text: record.foilStamp.author,
      } : {}),
    }],
    shipping_address: {
      name: entitlement.shippingAddress.name,
      street1: entitlement.shippingAddress.street1,
      street2: entitlement.shippingAddress.street2,
      city: entitlement.shippingAddress.city,
      state_code: entitlement.shippingAddress.stateCode,
      country_code: entitlement.shippingAddress.countryCode,
      postcode: entitlement.shippingAddress.postalCode,
      phone_number: entitlement.shippingAddress.phoneNumber,
    },
    recipient_tax_id: entitlement.shippingAddress.recipientTaxID || undefined,
  };
  const token = await fetchLuluAccessToken(env);
  const luluPrintJob = await submitPrintJob(token, payload);
  const order = {
    id: externalID,
    quoteID: externalID,
    luluPrintJobID: String(luluPrintJob.id ?? luluPrintJob.print_job_id ?? luluPrintJob.url ?? ""),
    status: mapLuluPrintJobStatus(luluPrintJob.status?.name),
    ...luluTracking(luluPrintJob),
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  await storeOrder(env, storageKey, order);
  return order;
}

async function createOrder(orderRequest, env, checkoutToken) {
  validateOrderRequest(orderRequest);
  // Authenticate even a cached coordinator receipt. A known PaymentIntent ID
  // is not a capability to retrieve another reader's parcel or tracking link.
  const quoteRecord = await requireQuoteRecord(env, orderRequest.quoteID, checkoutToken, { allowExpiredAfterPayment: true });
  if (quoteRecord.paymentIntentID !== orderRequest.paymentIntentID) {
    throw new HTTPError(409, "payment_quote_mismatch", "That payment does not belong to this quote.");
  }
  if (!env.PHYSICAL_BOOK_ORDER_COORDINATOR) {
    throw new HTTPError(503, "order_coordinator_unavailable", "The secure print desk is not configured.");
  }
  const id = env.PHYSICAL_BOOK_ORDER_COORDINATOR.idFromName(orderRequest.paymentIntentID);
  const stub = env.PHYSICAL_BOOK_ORDER_COORDINATOR.get(id);
  const response = await stub.fetch("https://order-coordinator.internal/fulfill", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ orderRequest, checkoutToken }),
  });
  const body = await response.json();
  if (!response.ok) {
    throw new HTTPError(response.status, body.error || "order_creation_failed", body.message || "The order could not be created.");
  }
  return body;
}

async function createGiftBookOrder(claimToken, orderRequest, clientRequest, env, checkoutToken) {
  validateOrderRequest(orderRequest);
  const gift = await readGiftRecord(claimToken, env);
  const fingerprint = await clientFingerprint(clientRequest);
  if (
    !gift.claimedInstallationHash ||
    !constantTimeEqual(gift.claimedInstallationHash, fingerprint.installationHash)
  ) {
    throw new HTTPError(401, "gift_claim_mismatch", "This Book did not claim that gift.");
  }
  if (gift.kind !== "bookOfRecipient" || !["claimed", "redeemed"].includes(gift.status)) {
    throw new HTTPError(409, "gift_not_pressable", "That gift is not waiting for a Book.");
  }
  if (!env.PHYSICAL_BOOK_ORDER_COORDINATOR) {
    throw new HTTPError(503, "order_coordinator_unavailable", "The secure print desk is not configured.");
  }
  const id = env.PHYSICAL_BOOK_ORDER_COORDINATOR.idFromName(`gift:${gift.id}`);
  const stub = env.PHYSICAL_BOOK_ORDER_COORDINATOR.get(id);
  const response = await stub.fetch("https://order-coordinator.internal/fulfill", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      fulfillmentKind: "gift-book",
      claimToken,
      claimedInstallationHash: fingerprint.installationHash,
      orderRequest,
      checkoutToken,
    }),
  });
  const body = await response.json();
  if (!response.ok) {
    throw new HTTPError(response.status, body.error || "gift_order_failed", body.message || "The gift could not go to press.");
  }
  return body;
}

async function canonicalGiftOrderRequest(orderRequest, quoteRecord, gift, env) {
  const quote = quoteRecord.quote;
  if (
    quote.request.editionKind !== (gift.includedEditionKind || "monthly") ||
    quote.request.variant.id !== gift.includedVariantID ||
    quote.request.pageCount > gift.includedPageCount ||
    quote.request.quantity !== 1
  ) {
    throw new HTTPError(
      409,
      "gift_press_limit",
      `This gift holds one ${gift.includedEditionKind || "monthly"} edition in its chosen binding, up to ${gift.includedPageCount} pages.`,
    );
  }
  const selectedShippingOption = quote.shippingOptions.find(
    (option) => option.id === orderRequest.selectedShippingOptionID,
  );
  if (!selectedShippingOption || orderRequest.selectedShippingOption?.id !== selectedShippingOption.id) {
    throw new HTTPError(409, "shipping_option_mismatch", "That delivery choice is not part of this quote.");
  }
  assertShippingAddressMatchesQuote(orderRequest.shippingAddress, quote.request.shipTo);
  const total = priceBreakdownFromStoredQuote(quote, selectedShippingOption).total;
  if (
    total.currencyCode !== gift.allowanceCurrencyCode ||
    total.cents > gift.allowanceCents
  ) {
    throw new HTTPError(
      409,
      "gift_allowance_exceeded",
      "That destination costs more than the gift covers. Ask the giver to contact the Bindery before paying anything else.",
    );
  }
  const [interior, cover] = await Promise.all([
    readStoredPrintFile(env, orderRequest.quoteID, "interior"),
    readStoredPrintFile(env, orderRequest.quoteID, "cover"),
  ]);
  if (!interior || !cover) {
    throw new HTTPError(409, "print_files_missing", "Both quote-bound print files must be uploaded first.");
  }
  return {
    ...orderRequest,
    quoteRequest: quote.request,
    paymentIntentID: `gift:${gift.id}`,
    selectedShippingOptionID: selectedShippingOption.id,
    selectedShippingOption,
    printFiles: {
      interiorSourceURL: interior.sourceURL,
      interiorMD5: interior.md5,
      coverSourceURL: cover.sourceURL,
      coverMD5: cover.md5,
    },
  };
}

async function fulfillGiftBookOrder(claimToken, orderRequest, env, checkoutToken, submitPrintJob) {
  validateOrderRequest(orderRequest);
  let gift = await readGiftRecord(claimToken, env);
  if (gift.kind !== "bookOfRecipient" || gift.status !== "claimed") {
    throw new HTTPError(409, "gift_not_pressable", "That gift is not waiting for a Book.");
  }
  const quoteRecord = await requireQuoteRecord(env, orderRequest.quoteID, checkoutToken);
  const canonicalRequest = await canonicalGiftOrderRequest(orderRequest, quoteRecord, gift, env);
  const storageKey = orderStorageKey(canonicalRequest);
  const storedOrder = await readStoredOrder(env, storageKey);
  if (storedOrder) return storedOrder;

  await verifyBookGiftPayment(gift, env);
  const token = await fetchLuluAccessToken(env);
  const luluPrintJob = await submitPrintJob(token, toLuluPrintJobPayload(canonicalRequest));
  const now = new Date().toISOString();
  const order = {
    id: canonicalRequest.quoteID,
    quoteID: canonicalRequest.quoteID,
    paymentIntentID: canonicalRequest.paymentIntentID,
    luluPrintJobID: String(luluPrintJob.id ?? luluPrintJob.print_job_id ?? luluPrintJob.url ?? ""),
    status: mapLuluPrintJobStatus(luluPrintJob.status?.name),
    ...luluTracking(luluPrintJob),
    createdAt: now,
    updatedAt: now,
  };
  await storeOrder(env, storageKey, order);
  gift = { ...gift, status: "redeemed", redeemedAt: now };
  await saveGiftRecord(gift, env);
  // Mark the redemption quote as fulfilled so its capability remains usable for
  // status refresh long enough to follow the parcel, then shed its address.
  await storeQuoteRecord(env, {
    ...quoteRecord,
    paymentIntentID: canonicalRequest.paymentIntentID,
    selectedShippingOptionID: canonicalRequest.selectedShippingOptionID,
    contactEmail: normalizeEmail(canonicalRequest.contactEmail),
    paymentSucceededAt: now,
  });
  await redactFulfilledQuoteRecord(env, await readQuoteRecord(env, canonicalRequest.quoteID));
  return order;
}

async function fulfillOrder(orderRequest, env, checkoutToken, submitPrintJob) {
  validateOrderRequest(orderRequest);
  const quoteRecord = await requireQuoteRecord(env, orderRequest.quoteID, checkoutToken, { allowExpiredAfterPayment: true });
  const storageKey = orderStorageKey(orderRequest);
  const storedOrder = await readStoredOrder(env, storageKey);
  if (storedOrder) {
    if (storedOrder.quoteID !== orderRequest.quoteID || storedOrder.paymentIntentID !== orderRequest.paymentIntentID) {
      throw new HTTPError(409, "payment_quote_mismatch", "That payment does not belong to this quote.");
    }
    await redactFulfilledQuoteRecord(env, quoteRecord);
    await clearPaymentAwaitingPrint(env, orderRequest.quoteID);
    return storedOrder;
  }

  const canonicalRequest = await canonicalOrderRequest(orderRequest, quoteRecord, env);

  await verifyPaidPaymentIntent(canonicalRequest, quoteRecord, env);
  await markPaymentAwaitingPrint(env, {
    quoteID: canonicalRequest.quoteID,
    paymentIntentID: canonicalRequest.paymentIntentID,
    paidAt: quoteRecord.paymentSucceededAt || new Date().toISOString(),
  });

  const token = await fetchLuluAccessToken(env);
  const luluPayload = toLuluPrintJobPayload(canonicalRequest);
  const luluPrintJob = await submitPrintJob(token, luluPayload);

  const order = {
    id: canonicalRequest.quoteID,
    quoteID: canonicalRequest.quoteID,
    paymentIntentID: canonicalRequest.paymentIntentID,
    luluPrintJobID: String(luluPrintJob.id ?? luluPrintJob.print_job_id ?? luluPrintJob.url ?? ""),
    status: mapLuluPrintJobStatus(luluPrintJob.status?.name),
    ...luluTracking(luluPrintJob),
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  await storeOrder(env, storageKey, order);
  await redactFulfilledQuoteRecord(env, quoteRecord);
  await clearPaymentAwaitingPrint(env, canonicalRequest.quoteID);
  return order;
}

async function previewOrder(orderRequest, env, checkoutToken) {
  validateOrderRequest(orderRequest);
  const quoteRecord = await requireQuoteRecord(env, orderRequest.quoteID, checkoutToken, { allowExpiredAfterPayment: true });
  const canonicalRequest = await canonicalOrderRequest(orderRequest, quoteRecord, env);
  const luluPayload = toLuluPrintJobPayload(canonicalRequest);

  return {
    mode: "preview",
    quoteID: orderRequest.quoteID,
    luluPrintJobPayload: luluPayload,
  };
}

async function uploadPrintFile(request, env, kind) {
  requireOrderStorage(env);
  if (!env.PHYSICAL_BOOK_FILES) {
    throw new Error("PHYSICAL_BOOK_FILES R2 binding is not configured");
  }

  const editionID = requiredHeader(request, "X-Edition-ID");
  const quoteID = requiredHeader(request, "X-Quote-ID");
  const quoteRecord = await requireQuoteRecord(
    env,
    quoteID,
    requiredHeader(request, "X-Checkout-Token"),
    { allowExpiredAfterPayment: true },
  );
  if (quoteRecord.quote.request.editionID !== editionID) {
    throw new HTTPError(409, "upload_edition_mismatch", "The print file does not belong to this quote.");
  }
  const sourceMD5 = requiredHeader(request, "X-Source-MD5").toLowerCase();
  if (!isMD5(sourceMD5)) {
    throw new Error("X-Source-MD5 must be a 32-character hex MD5");
  }
  const sourceSHA256 = requiredHeader(request, "X-Source-SHA256").toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(sourceSHA256)) {
    throw new Error("X-Source-SHA256 must be a 64-character hex digest");
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
  const computedSHA256 = await sha256Hex(body);
  if (!constantTimeEqual(sourceSHA256, computedSHA256)) {
    throw new HTTPError(409, "upload_digest_mismatch", "The uploaded print file failed its integrity check.");
  }

  const deliveryBaseURL = printFileDeliveryBaseURL(request, env);
  const deliveryID = randomToken();
  const key = [
    "physical-books",
    sanitizeObjectPathSegment(quoteID),
    `${kind}-${deliveryID}.pdf`,
  ].join("/");
  await env.PHYSICAL_BOOK_FILES.put(key, body, {
    httpMetadata: {
      contentType: "application/pdf",
    },
    customMetadata: {
      editionID,
      kind,
      sourceMD5,
      sha256: computedSHA256,
      expiresAt: new Date(Date.now() + PRINT_FILE_TTL_SECONDS * 1000).toISOString(),
    },
  });

  const deliveryRecord = {
    key,
    quoteID,
    kind,
    md5: sourceMD5,
    expiresAt: new Date(Date.now() + PRINT_FILE_TTL_SECONDS * 1000).toISOString(),
  };
  await env.PHYSICAL_BOOK_ORDERS.put(printFileDeliveryKey(deliveryID), JSON.stringify(deliveryRecord), {
    expirationTtl: PRINT_FILE_TTL_SECONDS,
  });
  await env.PHYSICAL_BOOK_ORDERS.put(printFileQuoteKey(quoteID, kind), JSON.stringify({
    ...deliveryRecord,
    sourceURL: `${deliveryBaseURL}/print-files/delivery/${deliveryID}`,
  }), { expirationTtl: PRINT_FILE_TTL_SECONDS });

  return {
    kind,
    sourceURL: `${deliveryBaseURL}/print-files/delivery/${deliveryID}`,
    md5: sourceMD5,
    byteCount: body.byteLength,
  };
}

async function servePrintFile(deliveryID, env) {
  requireOrderStorage(env);
  if (!env.PHYSICAL_BOOK_FILES) {
    throw new HTTPError(503, "file_storage_unavailable", "Print-file storage is unavailable.");
  }
  const serialized = await env.PHYSICAL_BOOK_ORDERS.get(printFileDeliveryKey(deliveryID));
  if (!serialized) {
    throw new HTTPError(404, "print_file_not_found", "That print-file doorway has closed.");
  }
  const record = JSON.parse(serialized);
  if (Date.parse(record.expiresAt) <= Date.now()) {
    throw new HTTPError(410, "print_file_expired", "That print-file doorway has expired.");
  }
  const object = await env.PHYSICAL_BOOK_FILES.get(record.key);
  if (!object) {
    throw new HTTPError(404, "print_file_not_found", "That print file is no longer available.");
  }
  return new Response(object.body, {
    headers: {
      "Content-Type": "application/pdf",
      "Cache-Control": "private, no-store, max-age=0",
      "Content-Disposition": "inline; filename=print-file.pdf",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

async function getOrderStatus(printJobID, paymentIntentID, checkoutToken, env) {
  const storedOrder = await readStoredOrder(env, orderStorageKey({ paymentIntentID }));
  if (!storedOrder || storedOrder.luluPrintJobID !== printJobID) {
    throw new HTTPError(404, "order_not_found", "That print order was not found.");
  }
  await requireQuoteRecord(env, storedOrder.quoteID, checkoutToken, { allowExpiredAfterPayment: true });
  const token = await fetchLuluAccessToken(env);
  const luluPrintJob = await fetchLuluPrintJobStatus(env, token, printJobID);
  const tracking = luluTracking(luluPrintJob);
  const order = {
    ...storedOrder,
    quoteID: storedOrder.quoteID,
    luluPrintJobID: printJobID,
    status: mapLuluPrintJobStatus(luluPrintJob.status?.name),
    ...(tracking.shipments.length ? tracking : luluTracking(storedOrder)),
    createdAt: storedOrder.createdAt,
    updatedAt: luluPrintJob.status?.changed ?? new Date().toISOString(),
  };
  await storeOrder(env, orderStorageKey({ paymentIntentID }), order);
  return order;
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

async function fetchLuluCoverDimensions(env, token, podPackageID, pageCount) {
  requireEnv(env, "LULU_API_BASE_URL");
  const baseURL = String(env.LULU_API_BASE_URL).replace(/\/+$/, "");
  const response = await fetch(`${baseURL}/cover-dimensions/`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({
      pod_package_id: podPackageID,
      interior_page_count: pageCount,
      unit: "pt",
    }),
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Lulu cover dimensions failed with HTTP ${response.status}: ${body.slice(0, 300)}`);
  }
  const body = await response.json();
  const widthPoints = Number(body.width);
  const heightPoints = Number(body.height);
  if (!(widthPoints > 0) || !(heightPoints > 0)) {
    throw new Error("Lulu cover dimensions response was missing a usable width or height");
  }
  return { widthPoints, heightPoints };
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

async function fetchStripePaymentIntentCreate(env, fields, idempotencyKey) {
  requireEnv(env, "STRIPE_SECRET_KEY");
  const response = await fetch("https://api.stripe.com/v1/payment_intents", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.STRIPE_SECRET_KEY}`,
      "Idempotency-Key": idempotencyKey,
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

class LuluPrintSubmissionError extends Error {
  constructor(diagnostic) {
    super("Lulu print submission did not return a usable receipt");
    this.diagnostic = diagnostic;
  }
}

function luluSubmissionErrorFields(body) {
  // Inspect only known schema keys. Even JSON object keys can contain private
  // input; a syntax filter alone would not make arbitrary upstream keys safe.
  const allowed = new Set([
    "non_field_errors", "contact_email", "external_id", "shipping_level",
    "shipping_address", "name", "street1", "street2", "city", "state_code",
    "country_code", "postcode", "phone_number", "recipient_tax_id",
    "line_items", "title", "quantity", "pod_package_id", "printable_id",
    "printable_normalization", "interior", "cover", "source_url",
    "source_md5_sum", "source_md5sum",
  ]);
  const fields = new Set();
  function visit(value, path = "", depth = 0) {
    if (depth > 6 || !value || typeof value !== "object") return;
    if (Array.isArray(value)) {
      for (const item of value.slice(0, 20)) visit(item, `${path}[]`, depth + 1);
    } else {
      for (const key of Object.keys(value)) {
        if (!allowed.has(key)) continue;
        const field = path ? `${path}.${key}` : key;
        fields.add(field);
        visit(value[key], field, depth + 1);
      }
    }
  }
  try { visit(JSON.parse(body)); } catch { /* Non-JSON errors carry no fields. */ }
  return [...fields].sort().slice(0, 40);
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
    let fields = [];
    try { fields = luluSubmissionErrorFields((await response.text()).slice(0, 16384)); } catch { /* Preserve the HTTP status if the body is lost. */ }
    throw new LuluPrintSubmissionError({ kind: "http_error", httpStatus: response.status, fields });
  }
  try { return await response.json(); } catch {
    throw new LuluPrintSubmissionError({ kind: "invalid_receipt", httpStatus: response.status });
  }
}

async function findSubmittedLuluPrintJob(env, token, externalID) {
  if (!externalID) return null;
  const url = new URL(`${env.LULU_API_BASE_URL}/print-jobs/`);
  url.search = new URLSearchParams({ search: externalID, page_size: "100", exclude_line_items: "true" }).toString();
  try {
    const response = await fetch(url.toString(), {
      headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
    });
    if (!response.ok) return null;
    const result = await response.json();
    // A truncated list or multiple exact matches needs an operator. Do not
    // follow upstream pagination URLs or guess which parcel was intended.
    if (!Array.isArray(result.results) || result.next || result.count !== result.results.length) return null;
    const matches = result.results.filter(job => job.external_id === externalID);
    return matches.length === 1 && matches[0].id ? matches[0] : null;
  } catch {
    return null;
  }
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

function readOptionalLuluMoney(body, keys) {
  for (const key of keys) {
    const value = findNestedValue(body, key);
    if (value != null) return value;
  }
  return null;
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
  if (request.apiVersion !== 1) throw new Error("apiVersion must be 1");
  if (!request?.variant?.id) throw new Error("variant.id is required");
  if (!Number.isInteger(request.pageCount) || request.pageCount < 4 || request.pageCount > 800) {
    throw new Error("pageCount must be between 4 and 800");
  }
  if (request.pageCount % 2 !== 0) throw new Error("pageCount must be even");
  if (request.quantity !== 1) throw new Error("quantity must be 1");
  if (!request?.shipTo?.countryCode) throw new Error("shipTo.countryCode is required");
  if (!request?.shipTo?.postalCode) throw new Error("shipTo.postalCode is required");
  requireRecipientTaxID({
    countryCode: String(request.shipTo.countryCode).trim().toUpperCase(),
    recipientTaxID: canonicalRecipientTaxID(request.shipTo.recipientTaxID),
  });
}

const PUBLICATION_EDITION_KINDS = new Set(["weekly", "monthly", "seasonal", "annual", "special"]);

function canonicalEditionKind(value) {
  const kind = cleanOptionalString(value);
  if (!kind) return null;
  if (!PUBLICATION_EDITION_KINDS.has(kind)) {
    throw new HTTPError(400, "unsupported_edition_kind", "That kind of printed edition is not offered.");
  }
  return kind;
}

function canonicalPrintTitle(value) {
  // Old clients and gift passes may not have a recipient edition title yet.
  if (value == null) return "ReEnchanted";
  if (typeof value !== "string") {
    throw new HTTPError(400, "invalid_edition_title", "The printed book needs a title.");
  }
  const title = value.replace(/\s+/gu, " ").trim();
  if (!title || [...title].length > 255 || /[\u0000-\u001f\u007f]/u.test(title)) {
    throw new HTTPError(400, "invalid_edition_title", "The printed book needs a title of at most 255 characters.");
  }
  return title;
}

function canonicalQuoteRequest(request) {
  validateQuoteRequest(request);
  const packageID = ALLOWED_VARIANTS.get(request.variant.id);
  if (!packageID || request.variant.luluPackageID !== packageID) {
    throw new HTTPError(400, "unsupported_print_variant", "That print binding is not offered.");
  }
  const pageLimits = VARIANT_PAGE_LIMITS.get(request.variant.id);
  if (
    !pageLimits ||
    request.pageCount < pageLimits.minimum ||
    request.pageCount > pageLimits.maximum ||
    request.pageCount % pageLimits.multiple !== 0
  ) {
    throw new HTTPError(400, "unsupported_page_count", "That binding cannot hold this many pages.");
  }
  if (String(request.currencyCode || "").toUpperCase() !== "USD") {
    throw new HTTPError(400, "unsupported_currency", "Physical Books are currently quoted in USD.");
  }
  // Extras are checked here as well as at pricing time. Payment-intent
  // creation would catch an invented option anyway, but only after the reader
  // has filled in an address and reached for a card — the quote is where they
  // asked what it costs, so it is where they should be told.
  const options = resolvePrintOptions(request.selectedOptionIDs, request.variant.id);
  return {
    ...request,
    selectedOptionIDs: options.map((option) => option.id),
    editionID: sanitizeObjectPathSegment(request.editionID),
    editionTitle: canonicalPrintTitle(request.editionTitle),
    editionKind: canonicalEditionKind(request.editionKind),
    quantity: 1,
    currencyCode: "USD",
    variant: {
      ...request.variant,
      luluPackageID: packageID,
      manufacturingBasePriceCentsUSD: 0,
      manufacturingPerPagePriceTenThousandthsUSD: 0,
    },
    shipTo: {
      ...request.shipTo,
      countryCode: String(request.shipTo.countryCode).trim().toUpperCase(),
      stateCode: cleanOptionalString(request.shipTo.stateCode)?.toUpperCase(),
      postalCode: String(request.shipTo.postalCode).trim(),
      city: cleanOptionalString(request.shipTo.city),
      street1: cleanOptionalString(request.shipTo.street1),
      street2: cleanOptionalString(request.shipTo.street2),
      phoneNumber: cleanOptionalString(request.shipTo.phoneNumber),
      recipientTaxID: RECIPIENT_TAX_ID_COUNTRIES.has(String(request.shipTo.countryCode).trim().toUpperCase())
        ? canonicalRecipientTaxID(request.shipTo.recipientTaxID)
        : undefined,
    },
  };
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
  requireRecipientTaxID({
    countryCode: String(request.shippingAddress.countryCode).trim().toUpperCase(),
    recipientTaxID: canonicalRecipientTaxID(request.shippingAddress.recipientTaxID),
  });
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

function isHTTPSURL(value) {
  try {
    return new URL(String(value)).protocol === "https:";
  } catch {
    return false;
  }
}

function printFileDeliveryBaseURL(request, env) {
  const configured = cleanOptionalString(env.PRINT_FILE_DELIVERY_BASE_URL);
  const baseURL = configured || new URL(request.url).origin;
  if (!isHTTPSURL(baseURL)) {
    throw new HTTPError(503, "invalid_delivery_origin", "The secure print-file doorway is not configured.");
  }
  return baseURL.replace(/\/+$/, "");
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

function quoteStorageKey(quoteID) {
  return `physical-book-quotes/${sanitizeObjectPathSegment(quoteID)}`;
}

function clientSessionStorageKey(tokenHash) {
  return `physical-book-sessions/${tokenHash}`;
}

function reconciliationStorageKey(quoteID) {
  return `reconciliation/paid/${sanitizeObjectPathSegment(quoteID)}`;
}

function reconciliationAlertStorageKey(quoteID) {
  return `reconciliation/alerts/${sanitizeObjectPathSegment(quoteID)}`;
}

function printFileQuoteKey(quoteID, kind) {
  return `physical-book-quote-files/${sanitizeObjectPathSegment(quoteID)}/${kind}`;
}

function printFileDeliveryKey(deliveryID) {
  return `physical-book-file-delivery/${sanitizeObjectPathSegment(deliveryID)}`;
}

function requireOrderStorage(env) {
  if (!env.PHYSICAL_BOOK_ORDERS) {
    throw new HTTPError(503, "secure_storage_unavailable", "The secure print desk is not configured.");
  }
}

async function storeQuoteRecord(env, record) {
  requireOrderStorage(env);
  const remainingSeconds = Math.max(
    60,
    Math.ceil((Date.parse(record.quote.expiresAt) - Date.now()) / 1000),
  );
  const ttl = record.paymentSucceededAt
    ? Math.max(ORDER_ACCESS_TTL_SECONDS, remainingSeconds)
    : record.paymentIntentID
      ? Math.max(PAYMENT_PENDING_TTL_SECONDS, remainingSeconds)
      : remainingSeconds;
  await env.PHYSICAL_BOOK_ORDERS.put(quoteStorageKey(record.quote.id), JSON.stringify(record), {
    expirationTtl: ttl,
  });
}

async function redactFulfilledQuoteRecord(env, record) {
  if (record.piiRedactedAt) return;
  const { contactEmail: _contactEmail, ...recordWithoutEmail } = record;
  const shipTo = record.quote.request.shipTo || {};
  await storeQuoteRecord(env, {
    ...recordWithoutEmail,
    piiRedactedAt: new Date().toISOString(),
    quote: {
      ...record.quote,
      request: {
        ...record.quote.request,
        shipTo: {
          countryCode: shipTo.countryCode,
          stateCode: shipTo.stateCode,
        },
      },
    },
  });
}

async function requireQuoteRecord(env, quoteID, checkoutToken, options = {}) {
  requireOrderStorage(env);
  const record = await readQuoteRecord(env, quoteID);
  if (!record) {
    throw new HTTPError(404, "quote_not_found", "That quote has closed. Ask the print desk for a fresh one.");
  }
  const suppliedHash = await sha256Hex(checkoutToken);
  if (!constantTimeEqual(record.checkoutTokenHash, suppliedHash)) {
    throw new HTTPError(401, "invalid_checkout_token", "That checkout does not belong to this quote.");
  }
  if (Date.parse(record.quote.expiresAt) <= Date.now() && !(options.allowExpiredAfterPayment && record.paymentIntentID)) {
    throw new HTTPError(410, "quote_expired", "That quote has expired. Ask the print desk for a fresh one.");
  }
  return record;
}

async function readQuoteRecord(env, quoteID) {
  requireOrderStorage(env);
  const serialized = await env.PHYSICAL_BOOK_ORDERS.get(quoteStorageKey(quoteID));
  return serialized ? JSON.parse(serialized) : null;
}

async function readStoredOrder(env, key) {
  requireOrderStorage(env);
  const stored = await env.PHYSICAL_BOOK_ORDERS.get(key);
  if (!stored) {
    return null;
  }
  return JSON.parse(stored);
}

async function storeOrder(env, key, order) {
  requireOrderStorage(env);
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
  if (!request?.selectedShippingOption?.id) throw new Error("selectedShippingOption.id is required");
  if (!isPlausibleEmail(request?.contactEmail)) throw new Error("contactEmail is invalid");
}

async function canonicalOrderRequest(orderRequest, quoteRecord, env) {
  if (quoteRecord.paymentIntentID !== orderRequest.paymentIntentID) {
    throw new HTTPError(409, "payment_quote_mismatch", "That payment does not belong to this quote.");
  }
  if (quoteRecord.contactEmail !== normalizeEmail(orderRequest.contactEmail)) {
    throw new HTTPError(409, "payment_contact_mismatch", "The order contact does not match the paid checkout.");
  }
  const selectedShippingOption = quoteRecord.quote.shippingOptions.find(
    (option) => option.id === quoteRecord.selectedShippingOptionID,
  );
  if (!selectedShippingOption || orderRequest.selectedShippingOptionID !== selectedShippingOption.id) {
    throw new HTTPError(409, "shipping_option_mismatch", "The order shipping option does not match the paid quote.");
  }
  assertShippingAddressMatchesQuote(orderRequest.shippingAddress, quoteRecord.quote.request.shipTo);

  const [interior, cover] = await Promise.all([
    readStoredPrintFile(env, orderRequest.quoteID, "interior"),
    readStoredPrintFile(env, orderRequest.quoteID, "cover"),
  ]);
  if (!interior || !cover) {
    throw new HTTPError(409, "print_files_missing", "Both quote-bound print files must be uploaded first.");
  }

  return {
    ...orderRequest,
    quoteRequest: quoteRecord.quote.request,
    selectedShippingOptionID: selectedShippingOption.id,
    selectedShippingOption,
    printFiles: {
      interiorSourceURL: interior.sourceURL,
      interiorMD5: interior.md5,
      coverSourceURL: cover.sourceURL,
      coverMD5: cover.md5,
    },
  };
}

async function readStoredPrintFile(env, quoteID, kind) {
  requireOrderStorage(env);
  const serialized = await env.PHYSICAL_BOOK_ORDERS.get(printFileQuoteKey(quoteID, kind));
  return serialized ? JSON.parse(serialized) : null;
}

function assertShippingAddressMatchesQuote(address, quotedDestination) {
  const comparisons = [
    [address.street1, quotedDestination.street1],
    [address.street2, quotedDestination.street2],
    [address.city, quotedDestination.city],
    [address.stateCode, quotedDestination.stateCode],
    [address.countryCode, quotedDestination.countryCode],
    [address.postalCode, quotedDestination.postalCode],
    [address.phoneNumber, quotedDestination.phoneNumber],
    [canonicalRecipientTaxID(address.recipientTaxID), quotedDestination.recipientTaxID],
  ];
  if (comparisons.some(([actual, expected]) => normalizedComparable(actual) !== normalizedComparable(expected))) {
    throw new HTTPError(409, "shipping_address_mismatch", "The delivery address changed after the quote. Ask for a fresh quote.");
  }
}

async function verifyPaidPaymentIntent(orderRequest, quoteRecord, env) {
  const stripePaymentIntent = await stripeGet(env, `payment_intents/${encodeURIComponent(orderRequest.paymentIntentID)}?expand%5B%5D=latest_charge`);
  assertPaymentIntentMatchesQuote(stripePaymentIntent, orderRequest, quoteRecord, { requireSucceeded: true });
  assertPaymentAvailableForPrinting(stripePaymentIntent, orderRequest.paymentIntentID, env);
}

async function verifyBookGiftPayment(gift, env) {
  if (!/^pi_[A-Za-z0-9_]+$/.test(gift.paymentIntentID || "")) {
    throw new HTTPError(402, "payment_not_available", "The Bindery needs to check this gift's payment.");
  }
  const payment = await stripeGet(env, `payment_intents/${encodeURIComponent(gift.paymentIntentID)}?expand%5B%5D=latest_charge`);
  assertPaymentAvailableForPrinting(payment, gift.paymentIntentID, env);
  // Gift records retain the paid allowance after the original address/quote
  // expires. Validate against that server record, never the recipient's quote.
  if (payment.amount !== gift.allowanceCents ||
      payment.currency !== String(gift.allowanceCurrencyCode || "").toLowerCase()) {
    throw new HTTPError(402, "payment_not_available", "The Bindery needs to check this gift's payment.");
  }
}

function assertPaymentAvailableForPrinting(stripePaymentIntent, paymentIntentID, env) {
  const charge = stripePaymentIntent.latest_charge;
  if (stripePaymentIntent.id !== paymentIntentID ||
      stripePaymentIntent.status !== "succeeded" ||
      !Number.isSafeInteger(stripePaymentIntent.amount) || stripePaymentIntent.amount <= 0 ||
      stripePaymentIntent.livemode !== (env.CHECKOUT_MODE === "live") ||
      !charge || typeof charge !== "object" || charge.payment_intent !== stripePaymentIntent.id ||
      charge.livemode !== stripePaymentIntent.livemode || charge.paid !== true ||
      charge.refunded !== false || charge.disputed !== false || charge.amount_refunded !== 0 ||
      charge.amount !== stripePaymentIntent.amount || charge.currency !== stripePaymentIntent.currency ||
      stripePaymentIntent.amount_received !== stripePaymentIntent.amount) {
    throw new HTTPError(402, "payment_not_available", "This payment is not available for printing. The Bindery needs to check its refund or dispute record.");
  }
}

function assertPaymentIntentMatchesQuote(stripePaymentIntent, orderRequest, quoteRecord, options = {}) {
  if (options.requireSucceeded && stripePaymentIntent.status !== "succeeded") {
    throw new HTTPError(402, "payment_not_captured", "PaymentIntent has not succeeded.");
  }

  const expectedTotal = priceBreakdownFromStoredQuote(
    quoteRecord.quote,
    orderRequest.selectedShippingOption,
  ).total;
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
  const expectedTaxCalculationID = orderRequest.selectedShippingOption.taxCalculationID || "not-configured";
  if (metadata.tax_calculation_id !== expectedTaxCalculationID) {
    throw new HTTPError(409, "payment_tax_mismatch", "PaymentIntent tax metadata does not match the order.");
  }
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
        title: canonicalPrintTitle(quoteRequest.editionTitle),
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
    recipient_tax_id: canonicalRecipientTaxID(orderRequest.shippingAddress.recipientTaxID) || undefined,
  };
}

function mapLuluPrintJobStatus(name) {
  switch (name) {
    case "CREATED":
    case "UNPAID":
      return "paymentPending";
    case "PRODUCTION_READY":
      return "submittedToLulu";
    case "IN_PRODUCTION":
      return "inProduction";
    case "SHIPPED":
      return "shipped";
    case "DELIVERED":
      return "delivered";
    case "REJECTED":
    case "ERROR":
      return "failed";
    case "CANCELED":
    case "CANCELLED":
      return "cancelled";
    default:
      return "submittedToLulu";
  }
}

// MUST stay in lockstep with PhysicalBookPricingPolicy.standardUS in
// Shared/PhysicalBookOrders.swift. The order endpoint rejects any PaymentIntent
// whose amount does not equal the total computed here, so a drift between the
// two silently fails every order.
function standardPricingPolicy() {
  return {
    markupPerCopyCents: 3500,
    paymentFeeBasisPoints: 290,
    paymentFeeFixedCents: 30,
  };
}

function minimumProductPriceCentsPerCopy(variant, editionKind = null) {
  switch (variant?.coverTreatment) {
    case "saddleStitch": return 1999;
    case "perfectBound":
      switch (editionKind) {
        case "monthly": return 4999;
        case "seasonal":
        case "annual":
        case "special": return 6999;
        case "weekly": return 4999;
        default: return 7999; // Legacy quotes retain their original floor.
      }
    case "caseWrap": return 8999;
    case "linenWrap": return 9999;
    default:
      return null;
  }
}

function retailMarkupSubtotalCents(variant, manufacturingCents, quantity, policy, editionKind = null) {
  const contributionPerCopy = variant?.coverTreatment === "saddleStitch"
    ? 1500
    : policy.markupPerCopyCents;
  const contributionFloor = contributionPerCopy * quantity;
  const productFloor = minimumProductPriceCentsPerCopy(variant, editionKind);
  if (!Number.isInteger(productFloor)) return contributionFloor;
  return Math.max(contributionFloor, productFloor * quantity - manufacturingCents);
}

function priceBreakdown(quoteRequest, shippingCents, estimatedTaxCents = 0, policy = standardPricingPolicy()) {
  const manufacturing = rawManufacturingSubtotalCents(
    quoteRequest.variant,
    quoteRequest.pageCount,
    quoteRequest.quantity || 1,
  );
  const quantity = Math.max(0, quoteRequest.quantity || 1);
  // Options are resolved against the catalogue here rather than trusted from
  // the request, so a client cannot invent an extra any more than it can invent
  // a price. They ride in the markup line: an option that changes what is
  // actually printed changes the variant instead, and Lulu's live quote covers
  // that difference on its own.
  const options = resolvePrintOptions(quoteRequest.selectedOptionIDs, quoteRequest.variant?.id);
  const extras = printOptionsSubtotalCents(options, quantity);
  const markup = retailMarkupSubtotalCents(
    quoteRequest.variant,
    manufacturing,
    quantity,
    policy,
    quoteRequest.editionKind,
  ) + extras;
  const subtotalBeforeProcessing = manufacturing + shippingCents + estimatedTaxCents + markup;
  const processing = paymentProcessingFeeCents(subtotalBeforeProcessing, policy);
  const currencyCode = quoteRequest.currencyCode || "USD";
  return {
    manufacturingSubtotal: { currencyCode, cents: manufacturing },
    shipping: { currencyCode, cents: shippingCents },
    estimatedTax: { currencyCode, cents: estimatedTaxCents },
    markup: { currencyCode, cents: markup },
    // Itemised separately so the till can show what the extras cost. Money
    // stays simple, clear and fair, and that includes the upsells.
    printOptions: { currencyCode, cents: extras },
    selectedOptionIDs: options.map((option) => option.id),
    paymentProcessingFee: { currencyCode, cents: processing },
    total: { currencyCode, cents: subtotalBeforeProcessing + processing },
  };
}

function priceBreakdownFromStoredQuote(quote, selectedShippingOption) {
  const manufacturing = Number(quote.manufacturingSubtotal?.cents);
  const shipping = Number(selectedShippingOption?.price?.cents);
  const estimatedTaxCents = Number(selectedShippingOption?.estimatedTax?.cents || 0);
  if (!Number.isInteger(manufacturing) || manufacturing < 0 || !Number.isInteger(shipping) || shipping < 0) {
    throw new HTTPError(409, "invalid_stored_quote", "The stored quote is not usable.");
  }
  const policy = quote.pricingPolicy || standardPricingPolicy();
  const quantity = quote.request.quantity;
  const options = resolvePrintOptions(quote.request.selectedOptionIDs, quote.request.variant?.id);
  const extras = printOptionsSubtotalCents(options, quantity);
  const markup = retailMarkupSubtotalCents(
    quote.request.variant,
    manufacturing,
    quantity,
    policy,
    quote.request.editionKind,
  ) + extras;
  const subtotalBeforeProcessing = manufacturing + shipping + estimatedTaxCents + markup;
  const processing = paymentProcessingFeeCents(subtotalBeforeProcessing, policy);
  const currencyCode = quote.manufacturingSubtotal.currencyCode;
  return {
    manufacturingSubtotal: { currencyCode, cents: manufacturing },
    shipping: { currencyCode, cents: shipping },
    estimatedTax: { currencyCode, cents: estimatedTaxCents },
    markup: { currencyCode, cents: markup },
    printOptions: { currencyCode, cents: extras },
    selectedOptionIDs: options.map((option) => option.id),
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

function cleanOptionalString(value) {
  const cleaned = String(value || "").trim();
  return cleaned || undefined;
}

function normalizedComparable(value) {
  return String(value || "").trim().replace(/\s+/g, " ").toLocaleLowerCase("en-US");
}

function normalizeEmail(value) {
  return String(value || "").trim().toLocaleLowerCase("en-US");
}

function isPlausibleEmail(value) {
  const normalized = normalizeEmail(value);
  return normalized.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized);
}

function randomToken() {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return bytesToBase64URL(bytes);
}

async function sha256Hex(value) {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function hmacSHA256Hex(secret, value) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(signature), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function bytesToBase64URL(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function constantTimeEqual(left, right) {
  const a = String(left || "");
  const b = String(right || "");
  let mismatch = a.length ^ b.length;
  const length = Math.max(a.length, b.length);
  for (let index = 0; index < length; index += 1) {
    mismatch |= (a.charCodeAt(index % Math.max(a.length, 1)) || 0) ^
      (b.charCodeAt(index % Math.max(b.length, 1)) || 0);
  }
  return mismatch === 0;
}

class HTTPError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function requireAdminToken(request, env) {
  if (!env?.PHYSICAL_BOOK_ADMIN_TOKEN) {
    throw new HTTPError(503, "service_not_configured", "The reconciliation desk is not configured.");
  }
  const header = request.headers.get("Authorization") || "";
  const expected = `Bearer ${env.PHYSICAL_BOOK_ADMIN_TOKEN}`;
  if (!constantTimeEqual(header, expected)) {
    throw new HTTPError(401, "unauthorized", "A valid reconciliation token is required.");
  }
}

async function createClientSession(request, env) {
  requireOrderStorage(env);
  const fingerprint = await clientFingerprint(request);
  const token = randomToken();
  const tokenHash = await sha256Hex(token);
  const expiresAt = new Date(Date.now() + CLIENT_SESSION_TTL_SECONDS * 1000).toISOString();
  await env.PHYSICAL_BOOK_ORDERS.put(clientSessionStorageKey(tokenHash), JSON.stringify({
    installationHash: fingerprint.installationHash,
    networkHash: fingerprint.networkHash,
    createdAt: new Date().toISOString(),
    expiresAt,
  }), { expirationTtl: CLIENT_SESSION_TTL_SECONDS });
  return { token, expiresAt };
}

async function requireClientSession(request, env) {
  requireOrderStorage(env);
  const header = request.headers.get("Authorization") || "";
  const match = header.match(/^Bearer ([A-Za-z0-9_-]{40,128})$/);
  if (!match) {
    throw new HTTPError(401, "invalid_client_session", "A fresh print-desk session is required.");
  }
  const serialized = await env.PHYSICAL_BOOK_ORDERS.get(clientSessionStorageKey(await sha256Hex(match[1])));
  if (!serialized) {
    throw new HTTPError(401, "invalid_client_session", "That print-desk session has closed.");
  }
  const record = JSON.parse(serialized);
  if (Date.parse(record.expiresAt) <= Date.now()) {
    throw new HTTPError(401, "invalid_client_session", "That print-desk session has closed.");
  }
  const fingerprint = await clientFingerprint(request);
  if (
    !constantTimeEqual(record.installationHash, fingerprint.installationHash) ||
    !constantTimeEqual(record.networkHash, fingerprint.networkHash)
  ) {
    throw new HTTPError(401, "client_session_mismatch", "That print-desk session belongs to another reader doorway.");
  }
}

async function clientFingerprint(request) {
  const installationID = request.headers.get("X-Installation-ID") || "";
  if (!/^[A-Za-z0-9._-]{16,96}$/.test(installationID)) {
    throw new HTTPError(400, "invalid_installation_id", "A valid installation identifier is required.");
  }
  const networkID = request.headers.get("CF-Connecting-IP") || "unknown-client";
  return {
    installationHash: await sha256Hex(installationID),
    networkHash: await sha256Hex(networkID),
  };
}

function requireCheckoutEnabled(env) {
  const checkout = checkoutRuntimeStatus(env);
  if (!checkout.orderingEnabled) {
    throw new HTTPError(503, "checkout_disabled", "The physical-book checkout is not accepting orders.");
  }
  if (!checkout.environmentAligned) {
    throw new HTTPError(503, "checkout_environment_mismatch", "The payment and print environments are not aligned.");
  }
  if (checkout.mode === "live" && !stripeTaxEnabled(env)) {
    throw new HTTPError(503, "tax_not_configured", "Live ordering is waiting for the tax desk to be configured.");
  }
}

function stripeTaxEnabled(env) {
  return String(env.STRIPE_TAX_ENABLED || "false").trim().toLowerCase() === "true";
}

function requireBoundYearSalesEnabled(env) {
  const checkout = checkoutRuntimeStatus(env);
  const liveSalesEnabled = String(env.BOUND_YEAR_LIVE_SALES_ENABLED || "false").trim().toLowerCase() === "true";
  if (checkout.mode === "live" && !liveSalesEnabled) {
    throw new HTTPError(503, "bound_year_live_sales_disabled", "The Bound Year is still at the proofing press.");
  }
}

function checkoutRuntimeStatus(env) {
  const mode = String(env.CHECKOUT_MODE || "disabled").trim().toLowerCase();
  const orderingEnabled = String(env.PHYSICAL_BOOK_ORDERING_ENABLED || "false").trim().toLowerCase() === "true";
  const stripeKey = String(env.STRIPE_SECRET_KEY || "");
  const stripeMode = /^(?:sk|rk)_live_/.test(stripeKey)
    ? "live"
    : /^(?:sk|rk)_test_/.test(stripeKey)
      ? "test"
      : "unknown";
  const luluAPIBaseURL = String(env.LULU_API_BASE_URL || "").replace(/\/+$/, "");
  const luluAuthURL = String(env.LULU_AUTH_URL || "").replace(/\/+$/, "");
  const luluMode = luluAPIBaseURL === "https://api.lulu.com" &&
      luluAuthURL === "https://api.lulu.com/auth/realms/glasstree/protocol/openid-connect/token"
    ? "live"
    : luluAPIBaseURL === "https://api.sandbox.lulu.com" &&
        luluAuthURL === "https://api.sandbox.lulu.com/auth/realms/glasstree/protocol/openid-connect/token"
      ? "test"
      : "unknown";
  return {
    mode,
    orderingEnabled,
    environmentAligned: (mode === "test" || mode === "live") && stripeMode === mode && luluMode === mode,
  };
}

async function requireRateLimit(request, env, operation) {
  if (!env.PHYSICAL_BOOK_RATE_LIMITER) {
    throw new HTTPError(503, "rate_limiter_unavailable", "The secure print desk is not configured.");
  }
  const fingerprint = await clientFingerprint(request);
  const [installationResult, networkResult] = await Promise.all([
    env.PHYSICAL_BOOK_RATE_LIMITER.limit({ key: `${operation}:installation:${fingerprint.installationHash}` }),
    env.PHYSICAL_BOOK_RATE_LIMITER.limit({ key: `${operation}:network:${fingerprint.networkHash}` }),
  ]);
  if (!installationResult.success || !networkResult.success) {
    throw new HTTPError(429, "too_many_requests", "The print desk is busy. Try again shortly.");
  }
}

async function markPaymentAwaitingPrint(env, marker) {
  requireOrderStorage(env);
  if (await env.PHYSICAL_BOOK_ORDERS.get(refundResolutionKey(marker.quoteID))) return;
  await env.PHYSICAL_BOOK_ORDERS.put(
    reconciliationStorageKey(marker.quoteID),
    JSON.stringify(marker),
    { expirationTtl: RECONCILIATION_TTL_SECONDS },
  );
}

function refundResolutionKey(quoteID) {
  return `reconciliation/refunded/${sanitizeObjectPathSegment(quoteID)}`;
}

async function requireSupportParcel(env, target) {
  requireOrderStorage(env);
  if (!checkoutRuntimeStatus(env).environmentAligned) {
    throw new HTTPError(503, "checkout_environment_mismatch", "The payment and print environments must match.");
  }
  if (target?.kind === "gift" && /^pi_[A-Za-z0-9_]+$/.test(target.paymentIntentID || "")) {
    const hash = await env.PHYSICAL_BOOK_ORDERS.get(giftPaymentIndexKey(target.paymentIntentID));
    const serialized = /^[a-f0-9]{64}$/.test(hash || "")
      ? await env.PHYSICAL_BOOK_ORDERS.get(giftStorageKey(hash)) : null;
    const gift = serialized ? JSON.parse(serialized) : null;
    if (gift?.kind === "bookOfRecipient" && gift.paymentIntentID === target.paymentIntentID &&
        gift.claimTokenHash === hash && /^[A-Za-z0-9_-]+$/.test(gift.id || "")) {
      return { record: gift, coordinatorKey: `gift:${gift.id}`, target: { kind: "gift", paymentIntentID: gift.paymentIntentID, giftID: gift.id } };
    }
  } else if (target?.kind === "membership" && /^sub_[A-Za-z0-9_]+$/.test(target.membershipID || "") &&
      /^\d{4}-S(0[1-9]|1[0-2])$/.test(target.seasonKey || "")) {
    const serialized = await env.PHYSICAL_BOOK_ORDERS.get(membershipDispatchStorageKey(target.membershipID, target.seasonKey));
    const dispatch = serialized ? JSON.parse(serialized) : null;
    if (dispatch?.membershipID === target.membershipID && dispatch.seasonKey === target.seasonKey) {
      return { record: dispatch, coordinatorKey: `membership:${target.membershipID}:${target.seasonKey}`,
        target: { kind: "membership", membershipID: target.membershipID, seasonKey: target.seasonKey } };
    }
  }
  throw new HTTPError(404, "parcel_not_found", "That gift or prepared membership parcel was not found.");
}

function parcelRefundResolutionKey(coordinatorKey) {
  return `reconciliation/parcels/${coordinatorKey}`;
}

async function readParcelRefundProof(env, parcel) {
  if (parcel.target.kind === "gift") {
    const gift = parcel.record;
    const pi = await stripeGet(env, `payment_intents/${encodeURIComponent(gift.paymentIntentID)}?expand%5B%5D=latest_charge`);
    if (pi.id !== gift.paymentIntentID || pi.amount !== gift.allowanceCents ||
        pi.currency !== String(gift.allowanceCurrencyCode || "").toLowerCase()) {
      throw new HTTPError(409, "refund_proof_invalid", "The refund payment does not match this gift's paid allowance.");
    }
    return { ...await readPaymentRefundProof(env, pi), paymentIntentIDs: [pi.id] };
  }
  return readMembershipSeasonRefundProof(env, parcel.target);
}

async function readMembershipSeasonRefundProof(env, { membershipID, seasonKey }) {
  const invalid = () => new HTTPError(409, "refund_proof_invalid", "The refunded invoices could not be verified for this membership season.");
  const subscription = await stripeGet(env, `subscriptions/${encodeURIComponent(membershipID)}`, STRIPE_API_VERSION);
  const metadata = subscription.metadata || {};
  const cadence = metadata.reenchanted_cadence;
  const start = /^(\d{4})-(0[1-9]|1[0-2])$/.exec(metadata.reenchanted_start_month || "");
  const season = /^(\d{4})-S(0[1-9]|1[0-2])$/.exec(seasonKey);
  const live = env.CHECKOUT_MODE === "live";
  if (subscription.id !== membershipID || subscription.livemode !== live ||
      metadata.reenchanted_physical_fulfillment !== "accepted" || !BOUND_YEAR_CADENCES.has(cadence) || !start || !season) throw invalid();
  const priceID = boundYearPriceID(env, cadence);
  if (!subscription.items?.data?.some(item => item.price?.id === priceID)) throw invalid();
  const firstMonth = Number(season[1]) * 12 + Number(season[2]) - 1;
  const offset = firstMonth - (Number(start[1]) * 12 + Number(start[2]) - 1);
  if (offset < 0 || offset % 3 !== 0 || Date.UTC(Number(season[1]), Number(season[2]) + 2, 1) > Date.now()) throw invalid();
  const covered = new Set(), seenInvoices = new Set(), seenPayments = new Set();
  const paymentIntentIDs = [];
  let cursor;
  // Operator-only proof, bounded to the same historical invoice budget as
  // fulfillment. Scan through the end so a second, unrefunded payment covering
  // the same month cannot be hidden behind an earlier refunded invoice.
  for (let page = 0; page < 12; page++) {
    const query = new URLSearchParams({ subscription: membershipID, status: "paid", limit: "100",
      "expand[]": "data.payment_intent.latest_charge", ...(cursor ? { starting_after: cursor } : {}) });
    const invoices = await stripeGet(env, `invoices?${query}`, STRIPE_API_VERSION);
    if (!Array.isArray(invoices.data) || typeof invoices.has_more !== "boolean") throw invalid();
    for (const invoice of invoices.data) {
      if (!/^in_[A-Za-z0-9_]+$/.test(invoice.id || "") || seenInvoices.has(invoice.id) ||
          invoice.subscription !== membershipID || invoice.livemode !== live ||
          !Array.isArray(invoice.lines?.data) || invoice.lines.has_more !== false) throw invalid();
      seenInvoices.add(invoice.id);
      const months = new Set();
      for (const line of invoice.lines.data) {
        if (line.type !== "subscription" || line.subscription !== membershipID || line.price?.id !== priceID) continue;
        if (!Number.isSafeInteger(line.period?.start) || !Number.isSafeInteger(line.period?.end)) throw invalid();
        const fromDate = new Date(line.period.start * 1000), untilDate = new Date(line.period.end * 1000);
        const from = fromDate.getUTCFullYear() * 12 + fromDate.getUTCMonth();
        const until = untilDate.getUTCFullYear() * 12 + untilDate.getUTCMonth();
        if (!Number.isFinite(from) || !Number.isFinite(until)) throw invalid();
        if (until <= firstMonth || from >= firstMonth + 3) continue;
        if (line.proration !== false || !Number.isSafeInteger(line.amount) || line.amount <= 0 ||
            until - from !== (cadence === "annual" ? 12 : 1)) throw invalid();
        for (let month = firstMonth; month < firstMonth + 3; month++) if (month >= from && month < until) months.add(month);
      }
      if (!months.size) continue;
      const pi = invoice.payment_intent;
      if (invoice.status !== "paid" || invoice.paid !== true || !Number.isSafeInteger(invoice.amount_paid) || invoice.amount_paid <= 0 ||
          !pi || typeof pi !== "object" || pi.invoice !== invoice.id || pi.amount !== invoice.amount_paid ||
          pi.currency !== invoice.currency || !/^pi_[A-Za-z0-9_]+$/.test(pi.id || "") || seenPayments.has(pi.id) ||
          seenPayments.size >= 24) throw invalid();
      seenPayments.add(pi.id);
      const proof = await readPaymentRefundProof(env, pi);
      if (!proof.fullyRefunded) return { fullyRefunded: false, paymentIntentIDs: [] };
      paymentIntentIDs.push(pi.id);
      for (const month of months) covered.add(month);
    }
    if (!invoices.has_more) return { fullyRefunded: covered.size === 3, paymentIntentIDs };
    if (!invoices.data.length) throw invalid();
    cursor = invoices.data.at(-1).id;
  }
  throw invalid();
}

async function requireReconciliationQuote(env, quoteID, paymentIntentID = null) {
  requireOrderStorage(env);
  const mode = checkoutRuntimeStatus(env);
  if (!mode.environmentAligned) throw new HTTPError(503, "checkout_environment_mismatch", "The payment and print environments must match.");
  const record = await readQuoteRecord(env, quoteID);
  if (!record || record.quote?.id !== quoteID || !/^pi_[A-Za-z0-9_]+$/.test(record.paymentIntentID || "") ||
      (paymentIntentID && paymentIntentID !== record.paymentIntentID)) {
    throw new HTTPError(404, "order_not_found", "A paid checkout record was not found.");
  }
  // Gift redemption has a different coordinator and entitlement lifecycle.
  // Do not pretend a hold on the purchaser's quote would stop a recipient.
  if (await env.PHYSICAL_BOOK_ORDERS.get(giftPaymentIndexKey(record.paymentIntentID))) {
    throw new HTTPError(409, "gift_reconciliation_required", "This payment funds a gift and needs the gift reconciliation workflow.");
  }
  return record;
}

async function readReconciliationPayment(env, record) {
  const id = record.paymentIntentID;
  const pi = await stripeGet(env, `payment_intents/${encodeURIComponent(id)}?expand%5B%5D=latest_charge`);
  if (pi.id !== id || pi.metadata?.quote_id !== record.quote.id || pi.livemode !== (env.CHECKOUT_MODE === "live")) {
    throw new HTTPError(409, "payment_quote_mismatch", "Stripe's payment does not match this checkout and environment.");
  }
  return readPaymentRefundProof(env, pi);
}

async function readPaymentRefundProof(env, pi) {
  const id = pi.id;
  if (!/^pi_[A-Za-z0-9_]+$/.test(id || "") || pi.livemode !== (env.CHECKOUT_MODE === "live")) {
    throw new HTTPError(409, "refund_proof_invalid", "The refund payment does not match this environment.");
  }
  const charge = pi.latest_charge;
  const validCharge = charge && typeof charge === "object" && /^ch_[A-Za-z0-9_]+$/.test(charge.id || "") &&
    charge.payment_intent === id && charge.livemode === pi.livemode && charge.paid === true &&
    charge.currency === pi.currency && Number.isSafeInteger(charge.amount) && charge.amount > 0 &&
    charge.amount === pi.amount && charge.amount === pi.amount_received && Number.isSafeInteger(charge.amount_refunded) &&
    charge.amount_refunded >= 0 && charge.amount_refunded <= charge.amount;
  let refunded = 0;
  let complete = false;
  let allRefundsSettled = true;
  if (validCharge && charge.refunded === true && charge.amount_refunded === charge.amount) {
    let cursor;
    const seen = new Set();
    for (let page = 0; page < 10; page++) {
      const query = new URLSearchParams({ charge: charge.id, limit: "100", ...(cursor ? { starting_after: cursor } : {}) });
      const refunds = await stripeGet(env, `refunds?${query}`);
      if (!Array.isArray(refunds.data) || typeof refunds.has_more !== "boolean") break;
      for (const refund of refunds.data) {
        if (!/^re_[A-Za-z0-9_]+$/.test(refund.id || "") || seen.has(refund.id) ||
            refund.charge !== charge.id || refund.currency !== pi.currency ||
            (refund.payment_intent != null && refund.payment_intent !== id) ||
            !Number.isSafeInteger(refund.amount) || refund.amount <= 0) {
          throw new HTTPError(409, "refund_proof_invalid", "Stripe's refund records could not be verified.");
        }
        seen.add(refund.id);
        if (refund.status === "succeeded") refunded += refund.amount;
        else if (!["failed", "canceled"].includes(refund.status)) allRefundsSettled = false;
      }
      if (!refunds.has_more) { complete = true; break; }
      if (!refunds.data.length) break;
      cursor = refunds.data.at(-1).id;
    }
  }
  return {
    status: pi.status, amountCents: pi.amount, currency: pi.currency,
    refundedCents: validCharge ? charge.amount_refunded : null,
    fullyRefunded: Boolean(pi.status === "succeeded" && validCharge && charge.disputed === false && complete && allRefundsSettled && refunded === charge.amount),
  };
}

async function clearPaymentAwaitingPrint(env, quoteID) {
  requireOrderStorage(env);
  await Promise.all([
    env.PHYSICAL_BOOK_ORDERS.delete(reconciliationStorageKey(quoteID)),
    env.PHYSICAL_BOOK_ORDERS.delete(reconciliationAlertStorageKey(quoteID)),
  ]);
}

async function reconciliationStatus(env) {
  requireOrderStorage(env);
  const markers = await listReconciliationMarkers(env);
  const now = Date.now();
  return {
    ok: true,
    checkedAt: new Date(now).toISOString(),
    pendingCount: markers.length,
    overdueCount: markers.filter((marker) => now - Date.parse(marker.paidAt) >= PAID_WITHOUT_PRINT_ALERT_SECONDS * 1000).length,
    pending: markers.map((marker) => ({
      quoteID: marker.quoteID,
      paymentIntentID: marker.paymentIntentID,
      paidAt: marker.paidAt,
      ageSeconds: Math.max(0, Math.floor((now - Date.parse(marker.paidAt)) / 1000)),
    })),
  };
}

async function listReconciliationMarkers(env) {
  const markers = [];
  let cursor;
  do {
    const page = await env.PHYSICAL_BOOK_ORDERS.list({
      prefix: "reconciliation/paid/",
      ...(cursor ? { cursor } : {}),
    });
    for (const key of page.keys || []) {
      const serialized = await env.PHYSICAL_BOOK_ORDERS.get(key.name);
      if (serialized) {
        const marker = JSON.parse(serialized);
        if (!await env.PHYSICAL_BOOK_ORDERS.get(refundResolutionKey(marker.quoteID))) markers.push(marker);
      }
    }
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);
  return markers;
}

async function auditPaidOrdersAwaitingPrint(env) {
  requireOrderStorage(env);
  const status = await reconciliationStatus(env);
  for (const marker of status.pending.filter((entry) => entry.ageSeconds >= PAID_WITHOUT_PRINT_ALERT_SECONDS)) {
    const alertKey = reconciliationAlertStorageKey(marker.quoteID);
    if (await env.PHYSICAL_BOOK_ORDERS.get(alertKey)) continue;
    const fingerprint = (await sha256Hex(`${marker.quoteID}:${marker.paymentIntentID}`)).slice(0, 16);
    console.error(`physical_book_paid_without_print fingerprint=${fingerprint} age_seconds=${marker.ageSeconds}`);
    await sendPaidWithoutPrintEmail(env, {
      fingerprint,
      paidAt: marker.paidAt,
      ageSeconds: marker.ageSeconds,
    });
    if (env.SECURITY_ALERT_WEBHOOK_URL && isHTTPSURL(env.SECURITY_ALERT_WEBHOOK_URL)) {
      const response = await fetch(env.SECURITY_ALERT_WEBHOOK_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          event: "physical_book_paid_without_print",
          fingerprint,
          paidAt: marker.paidAt,
          ageSeconds: marker.ageSeconds,
        }),
      });
      if (!response.ok) {
        throw new Error(`Security alert webhook returned HTTP ${response.status}`);
      }
    }
    await env.PHYSICAL_BOOK_ORDERS.put(alertKey, new Date().toISOString(), {
      expirationTtl: RECONCILIATION_ALERT_COOLDOWN_SECONDS,
    });
  }
  await env.PHYSICAL_BOOK_ORDERS.put("reconciliation/last-audit", JSON.stringify(status), {
    expirationTtl: RECONCILIATION_TTL_SECONDS,
  });
}

async function sendPaidWithoutPrintEmail(env, alert) {
  if (!env.SECURITY_ALERT_EMAIL) {
    throw new Error("Security alert email binding is not configured");
  }
  const checkoutMode = env.CHECKOUT_MODE === "live" ? "live" : "sandbox";
  const ageMinutes = Math.max(0, Math.floor(alert.ageSeconds / 60));
  await env.SECURITY_ALERT_EMAIL.send({
    to: SECURITY_ALERT_EMAIL_TO,
    from: {
      email: SECURITY_ALERT_EMAIL_FROM,
      name: "ReEnchanted Print Desk",
    },
    subject: `[ReEnchanted ${checkoutMode}] paid order waiting for print`,
    text: [
      "The print desk found a paid order without a recorded Lulu print submission.",
      "",
      `Incident fingerprint: ${alert.fingerprint}`,
      `Paid at: ${alert.paidAt}`,
      `Waiting: ${ageMinutes} minutes`,
      `Checkout mode: ${checkoutMode}`,
      "",
      "This alert deliberately contains no customer email, shipping address, quote ID, or payment ID.",
      "Use the protected reconciliation endpoint to investigate.",
    ].join("\n"),
  });
}

function jsonResponse(body, init = {}) {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init.headers || {}),
    },
  });
}

export { minimumProductPriceCentsPerCopy, priceBreakdown };
