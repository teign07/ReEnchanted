import { Buffer } from 'node:buffer';
import { MembershipOwnershipError } from './membership-ownership.mjs';
const fail = (status, code) => { throw new MembershipOwnershipError(status, code); };
export async function hashRecoverySecret(secret) {
  if (typeof secret !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(secret)
      || Buffer.from(secret, 'base64url').toString('base64url') !== secret)
    fail(400, 'invalid_recovery_proof');
  return Buffer.from(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(secret))).toString('hex');
}
// Trusted issuer only: the returned secret goes to verified delivery, never to
// the requesting client. No issuer or email-delivery route is enabled yet.
export async function createRecoveryChallenge(now = Date.now()) {
  const secret = Buffer.from(crypto.getRandomValues(new Uint8Array(32))).toString('base64url');
  return { secret, challengeHash: await hashRecoverySecret(secret), expiresAt: now + 15 * 60_000 };
}
async function readRecoveryBody(request, fields) {
  const reader = request.body?.getReader();
  if (!reader) fail(400, 'invalid_recovery_proof');
  const chunks = []; let size = 0;
  while (true) {
    const { value, done } = await reader.read(); if (done) break;
    size += value.byteLength;
    if (size > 2048) { await reader.cancel(); fail(413, 'recovery_request_too_large'); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  let body;
  try { body = JSON.parse(new TextDecoder().decode(bytes)); } catch { fail(400, 'invalid_recovery_proof'); }
  if (!body || Array.isArray(body) || Object.keys(body).some(key => !fields.includes(key))
      || !/^sub_[A-Za-z0-9]{1,128}$/.test(body.membershipID || '')) fail(400, 'invalid_recovery_proof');
  return body;
}
export async function readRecoveryRedemption(request) {
  const body = await readRecoveryBody(request, ['membershipID', 'secret']);
  return { membershipID: body.membershipID, challengeHash: await hashRecoverySecret(body.secret) };
}
export async function readRecoveryIssuance(request) {
  const body = await readRecoveryBody(request, ['membershipID', 'attemptID']);
  if (typeof body.attemptID !== 'string' || !/^\d{13}_[A-Za-z0-9_-]{16,96}$/.test(body.attemptID))
    fail(400, 'invalid_recovery_request');
  return { membershipID: body.membershipID, attemptID: body.attemptID };
}
export async function requestMembershipRecovery(env, installationHash, input) {
  if (env.MEMBERSHIP_RECOVERY_ENABLED !== 'true' || env.GMAIL_RECOVERY_DELIVERY_ENABLED !== 'true')
    fail(503, 'membership_recovery_disabled');
  const coordinator = env.PHYSICAL_BOOK_ORDER_COORDINATOR;
  if (!coordinator) fail(503, 'membership_ownership_unavailable');
  const response = await coordinator.get(coordinator.idFromName(`membership-owner:${input.membershipID}`)).fetch(
    'https://internal/membership-ownership', { method: 'POST', body: JSON.stringify({
      fulfillmentKind: 'membership-ownership', action: 'issue-recovery', ...input, installationHash,
    }) });
  // Do not expose membership existence, gift provenance, or provider acceptance.
  // Authorization/configuration/outage errors still surface for actionable retry.
  if (!response.ok && response.status !== 403) {
    const result = await response.json();
    fail(response.status, result.error || 'membership_recovery_unavailable');
  }
  return { requested: true };
}
export async function redeemMembershipRecovery(env, installationHash, proof) {
  if (env.MEMBERSHIP_RECOVERY_ENABLED !== 'true') fail(503, 'membership_recovery_disabled');
  const coordinator = env.PHYSICAL_BOOK_ORDER_COORDINATOR;
  if (!coordinator) fail(503, 'membership_ownership_unavailable');
  const response = await coordinator.get(coordinator.idFromName(`membership-owner:${proof.membershipID}`)).fetch(
    'https://internal/membership-ownership', { method: 'POST', body: JSON.stringify({
      fulfillmentKind: 'membership-ownership', action: 'redeem-recovery',
      membershipID: proof.membershipID, challengeHash: proof.challengeHash, installationHash,
    }) });
  const result = await response.json();
  if (!response.ok) fail(response.status, result.error || 'membership_recovery_unavailable');
  if (result.membershipID !== proof.membershipID || result.installationHash !== installationHash)
    fail(503, 'membership_ownership_unavailable');
  // Ownership is not payment verification. The app must fetch current status.
  return { membershipID: result.membershipID, recovered: true };
}
