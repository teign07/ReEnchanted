// Internal coordinator operation only. No public recovery or ownership-transfer endpoint.
// The caller must serialize operations through one Durable Object per membership.
export class MembershipOwnershipError extends Error {
  constructor(status, code) { super(code); this.status = status; this.code = code; }
}
const fail = (status, code) => { throw new MembershipOwnershipError(status, code); };

export async function coordinateMembershipOwnership(storage, legacyOwners, payload, now = Date.now()) {
  const { membershipID, action, installationHash } = payload;
  if (!/^sub_[A-Za-z0-9]+$/.test(membershipID || '') || !['read', 'register', 'mark-gift', 'prepare-recovery', 'redeem-recovery'].includes(action))
    fail(400, 'invalid_membership_ownership_operation');
  if (!['read', 'mark-gift'].includes(action) && !/^[a-f0-9]{64}$/.test(installationHash || ''))
    fail(400, 'invalid_membership_owner');
  let record = await storage.get('membership-owner');
  if (record && (record.membershipID !== membershipID || !/^[a-f0-9]{64}$/.test(record.installationHash || '')))
    fail(409, 'membership_ownership_record_mismatch');
  // A permanent, non-PII marker shares the owner's serialized coordinator.
  // It can precede recipient registration and cannot be cleared by stale KV.
  if (action === 'mark-gift') {
    const gift = await storage.get('membership-gift');
    if (gift && gift.membershipID !== membershipID) fail(409, 'membership_ownership_record_mismatch');
    if (!gift) await storage.put('membership-gift', { membershipID });
    return { membershipID, installationHash: record?.installationHash ?? null, generation: record?.generation ?? 0 };
  }
  if (!record) {
    const legacy = await legacyOwners.get(`monthly-issues/membership-owner/${membershipID}`);
    if (legacy) {
      if (!/^[a-f0-9]{64}$/.test(legacy)) fail(409, 'membership_ownership_record_mismatch');
      record = { membershipID, installationHash: legacy, generation: 1 };
      // Persist before acknowledging migration. Never delete or rewrite legacy data.
      await storage.put('membership-owner', record);
    }
  }
  if (action === 'register') {
    if (record && record.installationHash !== installationHash) fail(403, 'membership_owned_elsewhere');
    if (!record) {
      record = { membershipID, installationHash, generation: 1 };
      await storage.put('membership-owner', record);
    }
  }
  if (action === 'prepare-recovery' || action === 'redeem-recovery') {
    if (!record) fail(403, 'membership_recovery_unavailable');
    // Billing-contact recovery must never let a giver reclaim a recipient's Book.
    // Gift recovery needs verified recipient identity, which is not available yet.
    if (await storage.get('membership-gift'))
      fail(403, 'membership_recovery_unavailable');
    if (await legacyOwners.get(`book-gifts/membership/${membershipID}`)) {
      await storage.put('membership-gift', { membershipID });
      fail(403, 'membership_recovery_unavailable');
    }
    const { challengeHash } = payload;
    if (!/^[a-f0-9]{64}$/.test(challengeHash || '')) fail(400, 'invalid_recovery_proof');
    if (action === 'prepare-recovery') {
      if (!Number.isSafeInteger(payload.expiresAt) || payload.expiresAt <= now || payload.expiresAt > now + 15 * 60_000)
        fail(400, 'invalid_recovery_expiry');
      // One active challenge. Replacement supersedes any earlier link.
      record = { ...record, recovery: { challengeHash, destination: installationHash,
        generation: record.generation, expiresAt: payload.expiresAt } };
      await storage.put('membership-owner', record);
    } else {
      const recovery = record.recovery;
      if (!recovery || recovery.challengeHash !== challengeHash || recovery.destination !== installationHash
          || recovery.expiresAt <= now) fail(403, 'invalid_recovery_proof');
      if (recovery.redeemed) {
        // Lost-response retry is allowed only while this exact transfer remains current.
        if (record.generation !== recovery.generation + 1 || record.installationHash !== installationHash)
          fail(403, 'invalid_recovery_proof');
      } else {
        if (record.generation !== recovery.generation) fail(403, 'invalid_recovery_proof');
        // Owner change and consumed proof share one durable write: no crash window.
        record = { ...record, installationHash, generation: record.generation + 1,
          recovery: { ...recovery, redeemed: true } };
        await storage.put('membership-owner', record);
      }
    }
  }
  return { membershipID, installationHash: record?.installationHash ?? null, generation: record?.generation ?? 0 };
}
