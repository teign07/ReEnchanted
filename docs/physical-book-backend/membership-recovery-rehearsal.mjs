import { MembershipOwnershipError } from './membership-ownership.mjs';
const deny = () => { throw new MembershipOwnershipError(503, 'membership_recovery_disabled'); };
// Optional, short-lived operational restriction. It never grants authorization;
// normal session, ownership, gift, proof and billing-contact checks still run.
export function recoveryRehearsalScope(env, payload, now = Date.now()) {
  if (env.MEMBERSHIP_RECOVERY_REHEARSAL_JSON == null) return null;
  let scope;
  try { scope = JSON.parse(env.MEMBERSHIP_RECOVERY_REHEARSAL_JSON); } catch { deny(); }
  if (env.CHECKOUT_MODE !== 'test' || !scope || scope.membershipID !== payload.membershipID
      || !/^[a-f0-9]{64}$/.test(scope.installationHash || '') || scope.installationHash !== payload.installationHash
      || !Number.isSafeInteger(scope.expiresAt) || scope.expiresAt <= now || scope.expiresAt > now + 3600000
      || scope.recipient !== 'snow.potions@gmail.com') deny();
  return scope;
}
