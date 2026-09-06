import { Buffer } from 'node:buffer';

const BUNDLE_ID = 'com.openclaw.enchantify.insidecover';
const PRODUCTS = new Set(['monthly', 'annual', 'weekly'].map(period => `${BUNDLE_ID}.pass.standing-order.${period}`));
const SESSION_SECONDS = 600;
const encoder = new TextEncoder();
const clientCache = new WeakMap();
let cachedShelf;

export class MonthlyIssueError extends Error {
  constructor(status, code) { super(code); this.status = status; this.code = code; }
}
const reject = (status, code) => { throw new MonthlyIssueError(status, code); };
const base64 = bytes => Buffer.from(bytes).toString('base64url');
const decode = value => Buffer.from(value, 'base64url');

export function membershipOwnerKey(id) { return `monthly-issues/membership-owner/${id}`; }
export async function recordMonthlyMembershipOwner(env, id, installationHash) {
  if (!/^sub_[A-Za-z0-9]+$/.test(id) || !installationHash) reject(400, 'invalid_membership_owner');
  const key = membershipOwnerKey(id);
  const old = await env.PHYSICAL_BOOK_ORDERS.get(key);
  // An existing owner is never replaced through a guessed membership ID.
  if (old && old !== installationHash) reject(403, 'membership_owned_elsewhere');
  await env.PHYSICAL_BOOK_ORDERS.put(key, installationHash);
}

async function appleClients(env) {
  if (clientCache.has(env)) return clientCache.get(env);
  const sandbox = env.MONTHLY_APPLE_ENVIRONMENT === 'Sandbox';
  if (!sandbox && env.MONTHLY_APPLE_ENVIRONMENT !== 'Production') reject(503, 'apple_access_not_configured');
  if (sandbox && env.CHECKOUT_MODE !== 'test') reject(503, 'sandbox_access_disabled');
  if (!env.MONTHLY_APPLE_PRIVATE_KEY || !env.MONTHLY_APPLE_KEY_ID || !env.MONTHLY_APPLE_ISSUER_ID
      || !env.MONTHLY_APPLE_ROOT_CERTIFICATES || (!sandbox && !Number.isSafeInteger(Number(env.MONTHLY_APPLE_APP_ID)))) {
    reject(503, 'apple_access_not_configured');
  }
  try {
    // jsrsasign initializes randomness on import. Workers permits that only
    // inside a request, not while evaluating the Worker's global module.
    const { AppStoreServerAPIClient, Environment, SignedDataVerifier, VerificationStatus } = await import('@apple/app-store-server-library');
    const roots = JSON.parse(env.MONTHLY_APPLE_ROOT_CERTIFICATES).map(value => Buffer.from(value, 'base64'));
    if (!roots.length) reject(503, 'apple_access_not_configured');
    const environment = sandbox ? Environment.SANDBOX : Environment.PRODUCTION;
    const value = {
      retryableVerificationStatus: VerificationStatus.RETRYABLE_VERIFICATION_FAILURE,
      verifier: new SignedDataVerifier(roots, true, environment, BUNDLE_ID, sandbox ? undefined : Number(env.MONTHLY_APPLE_APP_ID)),
      api: new AppStoreServerAPIClient(env.MONTHLY_APPLE_PRIVATE_KEY, env.MONTHLY_APPLE_KEY_ID, env.MONTHLY_APPLE_ISSUER_ID, BUNDLE_ID, environment),
    };
    clientCache.set(env, value);
    return value;
  } catch { reject(503, 'apple_access_not_configured'); }
}

// Dependency injection is a test seam, not a switch exposed through env/HTTP.
export async function verifyAppleAccess(env, proofs, now, clients) {
  clients ??= await appleClients(env);
  let unavailable = false;
  for (const proof of proofs) {
    let presented;
    try { presented = await clients.verifier.verifyAndDecodeTransaction(proof); }
    catch (error) {
      if (clients.retryableVerificationStatus != null && error.status === clients.retryableVerificationStatus) unavailable = true;
      continue;
    }
    if (!PRODUCTS.has(presented.productId) || presented.bundleId !== BUNDLE_ID || !presented.originalTransactionId) continue;
    try {
      const status = await clients.api.getAllSubscriptionStatuses(presented.originalTransactionId);
      for (const group of status.data ?? []) {
        for (const item of group.lastTransactions ?? []) {
          if (item.status !== 1) continue; // Same paid-through policy as the app.
          const current = await clients.verifier.verifyAndDecodeTransaction(item.signedTransactionInfo);
          if (current.originalTransactionId !== presented.originalTransactionId || !PRODUCTS.has(current.productId)
              || current.bundleId !== BUNDLE_ID || current.revocationDate != null || current.isUpgraded === true
              || !Number.isFinite(current.expiresDate) || current.expiresDate <= now
              || !Number.isFinite(current.purchaseDate) || current.purchaseDate > now) continue;
          return current.expiresDate;
        }
      }
    } catch { unavailable = true; }
  }
  if (unavailable) reject(503, 'apple_access_temporarily_unavailable');
  return null;
}

async function signingKey(env) {
  if (typeof env.MONTHLY_ISSUE_SESSION_SECRET !== 'string' || env.MONTHLY_ISSUE_SESSION_SECRET.length < 32) {
    reject(503, 'monthly_access_not_configured');
  }
  return crypto.subtle.importKey('raw', encoder.encode(env.MONTHLY_ISSUE_SESSION_SECRET), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);
}

export async function issueMonthlySession(body, env, installationHash, readMembership, now = Date.now(), appleVerifier = verifyAppleAccess) {
  if (!body || !Array.isArray(body.signedTransactions) || body.signedTransactions.length > 2
      || body.signedTransactions.some(value => typeof value !== 'string' || value.length > 24_000)
      || (body.membershipID != null && !/^sub_[A-Za-z0-9]+$/.test(body.membershipID))) reject(400, 'invalid_monthly_proof');
  let paidThrough;
  let unavailable = false;
  // Either independent entitlement can grant access even if the other provider
  // is down. No ownership mapping is created at this redemption endpoint.
  if (body.membershipID) {
    const owner = await env.PHYSICAL_BOOK_ORDERS.get(membershipOwnerKey(body.membershipID));
    if (owner === installationHash) {
      try {
        const membership = await readMembership(body.membershipID);
        const prices = new Set([env.STRIPE_BOUND_YEAR_MONTHLY_PRICE, env.STRIPE_BOUND_YEAR_ANNUAL_PRICE].filter(Boolean));
        const priceMatches = (membership.items?.data ?? []).some(item => prices.has(item.price?.id));
        const periodEnd = Number(membership.current_period_end) * 1000;
        const invoice = membership.latest_invoice;
        const payment = invoice?.payment_intent;
        const charge = payment?.latest_charge;
        const paid = invoice?.status === 'paid' && invoice?.paid === true
          && (invoice.amount_paid === 0 || (payment?.status === 'succeeded' && charge?.paid === true
            && charge.refunded !== true && charge.disputed !== true
            && Number.isFinite(charge.amount) && Number.isFinite(charge.amount_refunded)
            && charge.amount_refunded < charge.amount));
        if (membership.status === 'active' && membership.metadata?.reenchanted_physical_fulfillment === 'accepted'
            && priceMatches && paid && Number.isFinite(periodEnd) && periodEnd > now
            && (env.CHECKOUT_MODE === 'test' || membership.livemode === true)) paidThrough = periodEnd;
      } catch { unavailable = true; }
    }
  }
  if (!paidThrough && body.signedTransactions.length) {
    try { paidThrough = await appleVerifier(env, body.signedTransactions, now); }
    catch (error) { if (error.status >= 500) unavailable = true; else throw error; }
  }
  if (!paidThrough) reject(unavailable ? 503 : 403, unavailable ? 'monthly_access_temporarily_unavailable' : 'monthly_subscription_required');
  const expires = Math.min(Math.floor(paidThrough / 1000), Math.floor(now / 1000) + SESSION_SECONDS);
  const payload = base64(encoder.encode(JSON.stringify({ v: 1, scope: 'monthly-issues', sub: installationHash, exp: expires, nonce: crypto.randomUUID() })));
  const signature = await crypto.subtle.sign('HMAC', await signingKey(env), encoder.encode(payload));
  return { token: `${payload}.${base64(signature)}`, expiresAt: new Date(expires * 1000).toISOString() };
}

export async function requireMonthlySession(request, env, installationHash, now = Date.now()) {
  const value = request.headers.get('Authorization') ?? '';
  if (!value.startsWith('Bearer ') || value.length > 2048) reject(401, 'monthly_session_required');
  const pieces = value.slice(7).split('.');
  if (pieces.length !== 2) reject(401, 'invalid_monthly_session');
  try {
    const valid = await crypto.subtle.verify('HMAC', await signingKey(env), decode(pieces[1]), encoder.encode(pieces[0]));
    const claims = JSON.parse(decode(pieces[0]).toString('utf8'));
    if (!valid || claims.v !== 1 || claims.scope !== 'monthly-issues' || claims.sub !== installationHash
        || !Number.isSafeInteger(claims.exp) || claims.exp * 1000 <= now || claims.exp * 1000 > now + SESSION_SECONDS * 1000) {
      reject(401, 'invalid_monthly_session');
    }
  } catch (error) {
    if (error.status === 503) throw error;
    reject(401, 'invalid_monthly_session');
  }
}

async function shelf(env, now) {
  if (!env.MONTHLY_ISSUE_FILES || !env.MONTHLY_ISSUE_MANIFEST_PUBLIC_KEY) reject(503, 'monthly_shelf_not_configured');
  if (cachedShelf?.bucket === env.MONTHLY_ISSUE_FILES && cachedShelf.key === env.MONTHLY_ISSUE_MANIFEST_PUBLIC_KEY && now < cachedShelf.until) return cachedShelf;
  const object = await env.MONTHLY_ISSUE_FILES.get('manifest.envelope.json');
  if (!object || object.size > 2 * 1024 * 1024) reject(503, 'monthly_manifest_unavailable');
  const envelopeBytes = await object.arrayBuffer();
  try {
    const envelope = JSON.parse(new TextDecoder().decode(envelopeBytes));
    const payload = Buffer.from(envelope.payload, 'base64');
    const publicKey = await crypto.subtle.importKey('raw', Buffer.from(env.MONTHLY_ISSUE_MANIFEST_PUBLIC_KEY, 'base64'), 'Ed25519', false, ['verify']);
    if (!await crypto.subtle.verify('Ed25519', publicKey, Buffer.from(envelope.signature, 'base64'), payload)) throw new Error();
    const manifest = JSON.parse(payload.toString('utf8'));
    if (manifest.schemaVersion !== 1 || !Array.isArray(manifest.issues)) throw new Error();
    const ids = new Set();
    const issues = [...manifest.issues].sort((a, b) => Date.parse(a.liveStartsAt) - Date.parse(b.liveStartsAt));
    let previousEnd = -Infinity;
    for (const issue of issues) {
      const boundaries = ['foreshadowStartsAt', 'liveStartsAt', 'liveEndsAt', 'residueEndsAt', 'casebookAvailableAt'].map(key => Date.parse(issue[key]));
      if (boundaries.some(value => !Number.isFinite(value)) || boundaries.some((value, i) => i && value < boundaries[i-1])
          || boundaries[1] >= boundaries[2] || boundaries[1] < previousEnd || !Array.isArray(issue.assets)) throw new Error();
      previousEnd = boundaries[2];
      for (const asset of issue.assets) {
        if (!/^[A-Za-z0-9_-]{1,160}$/.test(asset.id) || ids.has(asset.id) || !['runtime', 'casebook'].includes(asset.scope)
            || !Number.isSafeInteger(asset.byteCount) || asset.byteCount <= 0 || asset.byteCount > 180 * 1024 * 1024
            || (asset.retiresAt != null && (asset.scope !== 'runtime' || !Number.isFinite(Date.parse(asset.retiresAt))
              || Date.parse(asset.retiresAt) <= boundaries[0] || Date.parse(asset.retiresAt) > boundaries[3]))) throw new Error();
        ids.add(asset.id);
      }
    }
    cachedShelf = { bucket: env.MONTHLY_ISSUE_FILES, key: env.MONTHLY_ISSUE_MANIFEST_PUBLIC_KEY, until: now + 30_000, envelopeBytes, issues };
    return cachedShelf;
  } catch { reject(503, 'invalid_monthly_manifest'); }
}

export function availableMonthlyAssets(issues, now) {
  const upcoming = issues.filter(issue => Date.parse(issue.liveStartsAt) > now)
    .sort((a,b) => Date.parse(a.liveStartsAt) - Date.parse(b.liveStartsAt))[0]?.id;
  return issues.flatMap(issue => issue.assets.filter(asset => asset.scope === 'casebook'
    ? Date.parse(issue.casebookAvailableAt) <= now
    : (issue.id === upcoming || (Date.parse(issue.foreshadowStartsAt) <= now && now < Date.parse(issue.residueEndsAt)))
      && (asset.retiresAt == null || now < Date.parse(asset.retiresAt))));
}

export async function serveMonthlyContent(request, env, installationHash, path, now = Date.now()) {
  await requireMonthlySession(request, env, installationHash, now);
  const current = await shelf(env, now);
  const origin = new URL(request.url).origin;
  // Every delivered byte stays behind this origin's authorization boundary.
  for (const issue of current.issues) for (const asset of issue.assets) {
    if (asset.remoteURL !== `${origin}/monthly-issues/assets/${asset.id}`) reject(503, 'monthly_asset_route_mismatch');
  }
  if (path === '/monthly-issues/manifest') {
    return new Response(current.envelopeBytes, { headers: { 'Content-Type': 'application/json', 'Cache-Control': 'private, no-store' } });
  }
  const id = path.slice('/monthly-issues/assets/'.length);
  const asset = availableMonthlyAssets(current.issues, now).find(asset => asset.id === id);
  if (!asset) reject(404, 'monthly_asset_unavailable');
  const object = await env.MONTHLY_ISSUE_FILES.get(`assets/${asset.id}`);
  if (!object || object.size !== asset.byteCount) reject(503, 'monthly_asset_unavailable');
  return new Response(object.body, { headers: { 'Content-Type': 'application/octet-stream', 'Content-Length': String(object.size), 'Cache-Control': 'private, no-store' } });
}
