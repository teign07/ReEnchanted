import test from 'node:test';
import assert from 'node:assert/strict';
import { recoveryRehearsalScope } from './membership-recovery-rehearsal.mjs';
test('rehearsal restricts membership, device, email, environment and expiry', () => {
 const now=Date.now(), payload={membershipID:'sub_test',installationHash:'a'.repeat(64)};
 const scope={...payload,recipient:'operator@example.test',expiresAt:now+1800000};
 const env={CHECKOUT_MODE:'test',GMAIL_RECOVERY_SENDER:'operator@example.test',MEMBERSHIP_RECOVERY_REHEARSAL_JSON:JSON.stringify(scope)};
 assert.deepEqual(recoveryRehearsalScope(env,payload,now),scope);
 for(const change of [{membershipID:'sub_other'},{installationHash:'b'.repeat(64)},{recipient:'other@example.com'},{expiresAt:now},{expiresAt:now+7200000}]) {
 assert.throws(()=>recoveryRehearsalScope({...env,MEMBERSHIP_RECOVERY_REHEARSAL_JSON:JSON.stringify({...scope,...change})},payload,now));
 }
 assert.throws(()=>recoveryRehearsalScope({...env,CHECKOUT_MODE:'live'},payload,now));
 assert.throws(()=>recoveryRehearsalScope({...env,GMAIL_RECOVERY_SENDER:undefined},payload,now));
 assert.throws(()=>recoveryRehearsalScope({...env,MEMBERSHIP_RECOVERY_REHEARSAL_JSON:'broken'},payload,now));
 assert.equal(recoveryRehearsalScope({},payload),null);
});
