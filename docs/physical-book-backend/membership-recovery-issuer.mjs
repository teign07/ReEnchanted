import { createRecoveryChallenge } from './membership-recovery.mjs';
import { coordinateMembershipOwnership, MembershipOwnershipError } from './membership-ownership.mjs';
import { recoveryMessage } from './gmail-recovery-delivery.mjs';
const DAY = 86400000, COOLDOWN = 15 * 60000;
const fail = (status, code) => { throw new MembershipOwnershipError(status, code); };

// Internal orchestration only. The caller MUST serialize this entire operation
// in the membership ownership Durable Object, including verification and send.
// verifyRecipient must read trusted billing provenance, reject gifts and return
// the stored contact. Neither that callback nor recipient is public input.
export async function issueMembershipRecovery({ storage, legacyOwners, env, payload,
  verifyRecipient, deliver, now = Date.now }) {
  if (env.MEMBERSHIP_RECOVERY_ENABLED !== 'true' || env.GMAIL_RECOVERY_DELIVERY_ENABLED !== 'true')
    fail(503, 'membership_recovery_disabled');
  const { membershipID, installationHash, attemptID } = payload;
  if (!/^sub_[A-Za-z0-9]{1,128}$/.test(membershipID || '')
      || !/^[a-f0-9]{64}$/.test(installationHash || '')
      || !/^\d{13}_[A-Za-z0-9_-]{16,96}$/.test(attemptID || '')) fail(400, 'invalid_recovery_request');
  const timestamp = now();
  // The timestamp is part of the immutable retry ID. Expired IDs cannot become
  // new deliveries after their bounded deduplication records are pruned.
  const requestedAt = Number(attemptID.slice(0, 13));
  if (requestedAt <= timestamp - DAY || requestedAt > timestamp + 60_000)
    fail(400, 'recovery_attempt_expired');
  const previous = await storage.get('membership-recovery-issuance');
  if (previous && previous.membershipID !== membershipID) fail(409, 'membership_ownership_record_mismatch');
  const history = (previous?.attempts ?? []).filter(item => item.requestedAt > timestamp - DAY);
  const replay = previous?.attemptID === attemptID ? previous : history.find(item => item.attemptID === attemptID);
  if (replay) {
    if (replay.installationHash !== installationHash) fail(409, 'recovery_attempt_changed');
    // A crash after reservation may have happened before OR after Gmail accepted.
    // No replay sends, even when the saved outcome is still pending.
    return { status: replay.status === 'pending' ? 'uncertain' : replay.status };
  }
  const recent = (previous?.issuedAt ?? []).filter(time => time > timestamp - DAY);
  if (recent.length >= 3 || recent.some(time => time > timestamp - COOLDOWN))
    fail(429, 'membership_recovery_rate_limited');
  const recipient = await verifyRecipient(membershipID);
  const challenge = await createRecoveryChallenge(now());
  // Validate before reserving a proof or consuming the delivery allowance.
  recoveryMessage({ recipient, membershipID, secret: challenge.secret });
  await coordinateMembershipOwnership(storage, legacyOwners, {
    action: 'prepare-recovery', membershipID, installationHash,
    challengeHash: challenge.challengeHash, expiresAt: challenge.expiresAt,
  }, now());
  const entry = { installationHash, attemptID, requestedAt, status: 'pending' };
  const attempt = { membershipID, ...entry,
    issuedAt: [...recent, now()], attempts: [...history, entry] };
  // Durable reservation precedes the first possible mail side effect. Contains
  // neither contact address nor plaintext proof. Retain only a bounded history.
  await storage.put('membership-recovery-issuance', attempt);
  let status;
  try {
    const result = await deliver({ recipient, membershipID, secret: challenge.secret });
    status = result?.status === 'accepted' ? 'accepted' : 'uncertain';
  } catch (error) {
    status = ['recovery_mail_rejected', 'recovery_mail_authorization_failed',
      'recovery_mail_disabled', 'recovery_mail_not_configured'].includes(error?.code)
      ? 'rejected' : 'uncertain';
  }
  // If this write fails, the durable pending reservation still forbids resend.
  await storage.put('membership-recovery-issuance', { ...attempt, status,
    attempts: attempt.attempts.map(item => item.attemptID === attemptID ? { ...item, status } : item) });
  return { status };
}
