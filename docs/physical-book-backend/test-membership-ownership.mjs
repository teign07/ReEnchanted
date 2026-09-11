import test from 'node:test';
import assert from 'node:assert/strict';
import { PhysicalBookOrderCoordinator } from './lulu-quote-worker.mjs';
const alice = 'a'.repeat(64), bob = 'b'.repeat(64);
function fixture(legacy, recoveryEnabled = false) {
  const rows = new Map(), legacyRows = new Map(legacy ? [['monthly-issues/membership-owner/sub_test', legacy]] : []);
  let failRead = false, failWrite = false, coordinator;
  const state = { storage: {
    async get(key) { return structuredClone(rows.get(key)); },
    async put(key, value) { if (failWrite) throw Error('storage unavailable'); rows.set(key, structuredClone(value)); },
  } };
  const env = { MEMBERSHIP_RECOVERY_ENABLED: recoveryEnabled ? "true" : "false", PHYSICAL_BOOK_ORDERS: { async get(key) {
    if (failRead) throw Error('legacy unavailable'); return legacyRows.get(key);
  } } };
  const restart = () => { coordinator = new PhysicalBookOrderCoordinator(state, env); }; restart();
  async function call(action, installationHash, membershipID = 'sub_test', extra = {}) {
    const response = await coordinator.fetch(new Request('https://internal/ownership', {
      method: 'POST', body: JSON.stringify({ fulfillmentKind: 'membership-ownership', membershipID, action, installationHash, ...extra }),
    }));
    return { status: response.status, body: await response.json() };
  }
  return { rows, legacyRows, restart, call, failRead: v => { failRead = v; }, failWrite: v => { failWrite = v; } };
}
test('concurrent registrations have one owner; losing claims cannot overwrite it', async () => {
  const f = fixture();
  const results = await Promise.all([f.call('register', alice), f.call('register', bob)]);
  assert.deepEqual(results.map(r => r.status), [200, 403]);
  assert.equal((await f.call('read')).body.installationHash, alice);
  f.restart(); assert.equal((await f.call('register', alice)).body.generation, 1);
  assert.equal((await f.call('register', bob)).status, 403);
});
test('legacy owner is migrated before competing claim and survives stale KV', async () => {
  const f = fixture(alice);
  assert.equal((await f.call('register', bob)).status, 403);
  assert.equal(f.legacyRows.get('monthly-issues/membership-owner/sub_test'), alice);
  f.legacyRows.set('monthly-issues/membership-owner/sub_test', bob);
  f.restart(); assert.equal((await f.call('read')).body.installationHash, alice);
  f.failRead(true); assert.equal((await f.call('read')).status, 200);
});
test('migration storage failure denies acknowledgment and retry preserves existing owner', async () => {
  const f = fixture(alice); f.failWrite(true);
  assert.equal((await f.call('read')).status, 500); assert.equal(f.rows.size, 0);
  f.failWrite(false); f.restart();
  assert.equal((await f.call('register', bob)).status, 403);
  assert.equal((await f.call('read')).body.installationHash, alice);
});
test('legacy outage cannot be interpreted as unowned', async () => {
  const f = fixture(alice); f.failRead(true);
  assert.equal((await f.call('register', bob)).status, 500); assert.equal(f.rows.size, 0);
  f.failRead(false); assert.equal((await f.call('register', bob)).status, 403);
});
test('unknown reads do not create ownership or touch print records', async () => {
  const f = fixture(); f.rows.set('fulfilled-order', { id: 'existing-printer-receipt' });
  const before = structuredClone(f.rows);
  assert.equal((await f.call('read')).body.installationHash, null);
  assert.deepEqual(f.rows, before);
  await f.call('register', alice);
  assert.deepEqual(f.rows.get('fulfilled-order'), before.get('fulfilled-order'));
});
test('invalid operations and cross-membership routing fail closed', async () => {
  const f = fixture();
  assert.equal((await f.call('transfer', alice)).status, 400);
  assert.equal((await f.call('register', 'not-a-hash')).status, 400);
  await f.call('register', alice);
  assert.equal((await f.call('read', undefined, 'sub_other')).status, 409);
  assert.equal((await f.call('register', bob, 'sub_other')).status, 409);
});
test('corrupt legacy record cannot be replaced by a new registration', async () => {
  const f = fixture('corrupt');
  assert.equal((await f.call('register', alice)).status, 409);
  assert.equal(f.rows.size, 0);
});

const proof = 'c'.repeat(64), secondProof = 'd'.repeat(64);
const prepare = (f, hash = proof, destination = bob) => f.call('prepare-recovery', destination, 'sub_test', {
  challengeHash: hash, expiresAt: Date.now() + 60000,
});
const redeem = (f, hash = proof, destination = bob) => f.call('redeem-recovery', destination, 'sub_test', { challengeHash: hash });
test('recovery is disabled by default even on internal coordinator requests', async () => {
  const f = fixture(alice);
  assert.equal((await prepare(f)).status, 503);
  assert.equal((await redeem(f)).status, 503);
  assert.equal((await f.call('read')).body.installationHash, alice);
});
test('transfer and proof consumption survive restart as one record; retries do not transfer twice', async () => {
  const f = fixture(alice, true); await prepare(f);
  const results = await Promise.all([redeem(f), redeem(f)]);
  assert.deepEqual(results.map(r => r.body.generation), [2, 2]);
  f.restart(); assert.equal((await redeem(f)).body.generation, 2);
  assert.equal((await f.call('read')).body.installationHash, bob);
  assert.equal((await f.call('register', alice)).status, 403);
  assert.equal(f.legacyRows.get('monthly-issues/membership-owner/sub_test'), alice);
});
test('wrong destination, wrong proof, expired proof and replaced proof cannot transfer', async () => {
  const f = fixture(alice, true); await prepare(f);
  assert.equal((await redeem(f, proof, alice)).status, 403);
  assert.equal((await redeem(f, secondProof)).status, 403);
  await prepare(f, secondProof);
  assert.equal((await redeem(f)).status, 403);
  f.rows.get('membership-owner').recovery.expiresAt = Date.now() - 1;
  assert.equal((await redeem(f, secondProof)).status, 403);
  assert.equal((await f.call('read')).body.installationHash, alice);
});
test('failed transfer persistence leaves the former owner and usable proof intact', async () => {
  const f = fixture(alice, true); await prepare(f); f.failWrite(true);
  assert.equal((await redeem(f)).status, 500);
  assert.equal((await f.call('read')).body.installationHash, alice);
  assert.equal(f.rows.get('membership-owner').recovery.redeemed, undefined);
  f.failWrite(false); f.restart(); assert.equal((await redeem(f)).body.installationHash, bob);
});
test('gift index blocks billing-contact recovery, including a gift discovered after issuance', async () => {
  const f = fixture(alice, true); await prepare(f);
  f.legacyRows.set('book-gifts/membership/sub_test', 'gift-record');
  assert.equal((await redeem(f)).status, 403);
  assert.equal((await prepare(f)).status, 403);
  assert.equal((await f.call('read')).body.installationHash, alice);
});
test('old redeemed proof cannot reclaim ownership after a later transfer', async () => {
  const f = fixture(alice, true); await prepare(f); await redeem(f);
  await prepare(f, secondProof, alice); await redeem(f, secondProof, alice);
  assert.equal((await redeem(f)).status, 403);
  assert.equal((await f.call('read')).body.generation, 3);
});
test('proof preparation rejects unowned memberships and excessive lifetimes', async () => {
  const f = fixture(undefined, true);
  assert.equal((await prepare(f)).status, 403);
  await f.call('register', alice);
  assert.equal((await f.call('prepare-recovery', bob, 'sub_test', {
    challengeHash: proof, expiresAt: Date.now() + 3600000,
  })).status, 400);
});

test('gift marker precedes ownership and survives unavailable KV after restart', async () => {
  const f = fixture(undefined, true);
  assert.equal((await f.call('mark-gift')).status, 200);
  assert.equal(f.rows.has('membership-owner'), false);
  await f.call('register', alice);
  f.restart(); f.failRead(true);
  assert.equal((await prepare(f)).status, 403);
  assert.equal((await f.call('read')).body.installationHash, alice);
  assert.equal((await f.call('mark-gift')).status, 200);
});
test('gift marker serializes with recovery and blocks an already issued proof', async () => {
  const f = fixture(alice, true); await prepare(f);
  const results = await Promise.all([f.call('mark-gift'), redeem(f)]);
  assert.deepEqual(results.map(r => r.status), [200, 403]);
  assert.equal((await f.call('read')).body.installationHash, alice);
});
test('legacy gift discovery is permanent even if the KV index disappears', async () => {
  const f = fixture(alice, true); await prepare(f);
  f.legacyRows.set('book-gifts/membership/sub_test', 'gift-record');
  assert.equal((await redeem(f)).status, 403);
  f.legacyRows.delete('book-gifts/membership/sub_test'); f.restart();
  assert.equal((await redeem(f)).status, 403);
});
test('gift marker write failure cannot acknowledge protection; cross-membership marking fails', async () => {
  const f = fixture(undefined, true); f.failWrite(true);
  assert.equal((await f.call('mark-gift')).status, 500);
  assert.equal(f.rows.has('membership-gift'), false);
  f.failWrite(false);
  assert.equal((await f.call('mark-gift')).status, 200);
  assert.equal((await f.call('mark-gift', undefined, 'sub_other')).status, 409);
});
