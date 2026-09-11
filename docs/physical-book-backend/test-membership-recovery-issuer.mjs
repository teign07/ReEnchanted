import test from 'node:test';
import assert from 'node:assert/strict';
import { issueMembershipRecovery } from './membership-recovery-issuer.mjs';
function fixture() {
  const rows = new Map([['membership-owner', { membershipID: 'sub_test', installationHash: 'a'.repeat(64), generation: 1 }]]);
  let clock = Date.now(), sends = 0, puts = 0;
  const options = { storage: { async get(key) { return structuredClone(rows.get(key)); },
    async put(key, value) { puts++; rows.set(key, structuredClone(value)); } },
    legacyOwners: { async get() { return null; } },
    env: { MEMBERSHIP_RECOVERY_ENABLED: 'true', GMAIL_RECOVERY_DELIVERY_ENABLED: 'true' },
    payload: { membershipID: 'sub_test', installationHash: 'b'.repeat(64), attemptID: `${clock}_attempt_number_0001` },
    verifyRecipient: async () => 'reader@example.com',
    deliver: async () => { sends++; return { status: 'accepted' }; }, now: () => clock };
  return { rows, options, issue: () => issueMembershipRecovery(options), sends: () => sends,
    puts: () => puts, newID: suffix => `${clock}_attempt_number_${suffix}`, advance: ms => { clock += ms; } };
}
test('accepted send is recorded without contact or proof; replay never sends again', async () => {
  const f = fixture(); let secret;
  const send = f.options.deliver;
  f.options.deliver = async message => { secret = message.secret; return send(message); };
  assert.deepEqual(await f.issue(), { status: 'accepted' });
  assert.deepEqual(await f.issue(), { status: 'accepted' });
  assert.equal(f.sends(), 1);
  const saved = JSON.stringify([...f.rows]);
  assert.equal(saved.includes('reader@example.com'), false);
  assert.equal(saved.includes(secret), false);
});
test('lost outcome write retains pending reservation and retry reports uncertain without resend', async () => {
  const f = fixture(), put = f.options.storage.put;
  f.options.storage.put = async (key, value) => {
    if (value.status === 'accepted') throw Error('disk failure');
    return put(key, value);
  };
  await assert.rejects(f.issue(), /disk failure/);
  assert.deepEqual(await f.issue(), { status: 'uncertain' });
  assert.equal(f.sends(), 1);
});
test('failed reservation prevents sending', async () => {
  const f = fixture(), put = f.options.storage.put;
  f.options.storage.put = async (key, value) => {
    if (value.status === 'pending') throw Error('disk failure');
    return put(key, value);
  };
  await assert.rejects(f.issue(), /disk failure/); assert.equal(f.sends(), 0);
});
test('timeout is uncertain and rejected delivery is not automatically retried', async () => {
  for (const [code, status] of [['recovery_mail_delivery_uncertain', 'uncertain'], ['recovery_mail_rejected', 'rejected']]) {
    const f = fixture(); let calls = 0;
    f.options.deliver = async () => { calls++; throw Object.assign(Error('private details'), { code }); };
    assert.deepEqual(await f.issue(), { status });
    assert.deepEqual(await f.issue(), { status }); assert.equal(calls, 1);
  }
});
test('cooldown and rolling daily cap survive fresh issuer calls', async () => {
  const f = fixture(); await f.issue();
  f.options.payload.attemptID = f.newID('0002');
  await assert.rejects(f.issue(), { code: 'membership_recovery_rate_limited' });
  f.advance(900000); await f.issue();
  f.advance(900000); f.options.payload.attemptID = f.newID('0003'); await f.issue();
  f.advance(900000); f.options.payload.attemptID = f.newID('0004');
  await assert.rejects(f.issue(), { code: 'membership_recovery_rate_limited' });
  f.advance(86400000); f.options.payload.attemptID = f.newID('0005'); await f.issue(); assert.equal(f.sends(), 4);
});
test('untrusted contact, gift, changed destination and disabled gates cannot send', async () => {
  const f = fixture();
  f.options.env.MEMBERSHIP_RECOVERY_ENABLED = 'false';
  await assert.rejects(f.issue(), { code: 'membership_recovery_disabled' });
  f.options.env.MEMBERSHIP_RECOVERY_ENABLED = 'true';
  f.options.verifyRecipient = async () => { throw Error('unverified'); };
  await assert.rejects(f.issue(), /unverified/); assert.equal(f.puts(), 0);
  f.options.verifyRecipient = async () => 'reader@example.com';
  f.rows.set('membership-gift', { membershipID: 'sub_test' });
  await assert.rejects(f.issue(), { code: 'membership_recovery_unavailable' });
  assert.equal(f.sends(), 0);
  f.rows.delete('membership-gift'); await f.issue();
  f.options.payload.installationHash = 'c'.repeat(64);
  await assert.rejects(f.issue(), { code: 'recovery_attempt_changed' }); assert.equal(f.sends(), 1);
});

test('older request replay after a newer delivery never sends or replaces its proof', async () => {
  const f = fixture(), firstID = f.options.payload.attemptID;
  await f.issue(); f.advance(900000);
  f.options.payload.attemptID = f.newID('0002'); await f.issue();
  const proof = structuredClone(f.rows.get('membership-owner').recovery);
  f.advance(900000); f.options.payload.attemptID = firstID;
  assert.deepEqual(await f.issue(), { status: 'accepted' });
  assert.equal(f.sends(), 2);
  assert.deepEqual(f.rows.get('membership-owner').recovery, proof);
  f.options.payload.installationHash = 'c'.repeat(64);
  await assert.rejects(f.issue(), { code: 'recovery_attempt_changed' });
});
test('expired or future retry IDs fail before verification and storage', async () => {
  const f = fixture(), originalID = f.options.payload.attemptID;
  f.advance(86400000);
  await assert.rejects(f.issue(), { code: 'recovery_attempt_expired' });
  f.options.payload.attemptID = `${Number(originalID.slice(0, 13)) + 2 * 86400000}_attempt_number_0002`;
  await assert.rejects(f.issue(), { code: 'recovery_attempt_expired' });
  assert.equal(f.puts(), 0); assert.equal(f.sends(), 0);
});
