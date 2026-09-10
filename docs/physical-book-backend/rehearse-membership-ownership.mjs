// Read-only billing rehearsal: creates short client/content sessions, never payments or ownership mappings.
import assert from 'node:assert/strict';
import { readFileSync, statSync } from 'node:fs';
import { randomUUID } from 'node:crypto';

const [fixtureFile, expectedPayment] = process.argv.slice(2);
assert.ok(fixtureFile && ['paid', 'refunded'].includes(expectedPayment),
  'Usage: node rehearse-membership-ownership.mjs PRIVATE_FIXTURE_FILE paid|refunded');
assert.equal(statSync(fixtureFile).mode & 0o077, 0, 'Fixture must have owner-only permissions.');
const fixture = JSON.parse(readFileSync(fixtureFile, 'utf8'));
const membershipID = fixture.membership?.membershipID;
assert.ok(/^sub_[A-Za-z0-9]+$/.test(membershipID || ''), 'Missing fixture membership ID.');
assert.ok(typeof fixture.installation === 'string' && fixture.installation.length >= 16, 'Missing fixture installation.');
const origin = 'https://reenchanted-physical-books.snow-potions.workers.dev';
async function request(path, installation, token, body) {
  const response = await fetch(origin + path, {
    method: body === undefined ? 'GET' : 'POST', redirect: 'error', signal: AbortSignal.timeout(45000),
    headers: { 'Content-Type': 'application/json', 'X-Installation-ID': installation,
      ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  return { status: response.status, body: await response.json() };
}
const health = await request('/health', fixture.installation);
assert.equal(health.status, 200);
assert.equal(health.body.checks.checkoutMode, 'test');
assert.equal(health.body.checks.checkoutEnvironmentAligned, true);
const results = [];
async function check(installation, owner) {
  const session = await request('/sessions', installation, undefined, {});
  assert.equal(session.status, 201);
  const token = session.body.token;
  const status = await request(`/memberships/${membershipID}`, installation, token);
  assert.equal(status.status, owner ? 200 : 403);
  if (owner) assert.equal(status.body.paymentVerified, expectedPayment === 'paid');
  else assert.equal(status.body.error, 'membership_not_owned');
  const access = await request('/monthly-issues/session', installation, token,
    { membershipID, signedTransactions: [] });
  const allowed = owner && expectedPayment === 'paid';
  assert.equal(access.status, allowed ? 200 : 403);
  if (allowed) {
    assert.ok(Date.parse(access.body.expiresAt) > Date.now());
    assert.ok(Date.parse(access.body.expiresAt) <= Date.now() + 600000);
  } else assert.equal(access.body.error, 'monthly_subscription_required');
  results.push({ owner, membershipStatus: status.status, accessStatus: access.status });
}
await check(fixture.installation, true);
await check(`sandbox-recovery-${randomUUID()}`, false);
// A failed claim must not change the original owner's binding.
await check(fixture.installation, true);
console.log(JSON.stringify({ checkedAt: new Date().toISOString(), mode: 'test', expectedPayment, results }, null, 2));
