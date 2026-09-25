import test from 'node:test';
import assert from 'node:assert/strict';
import { PhysicalBookOrderCoordinator } from './lulu-quote-worker.mjs';
import { hashRecoverySecret } from './membership-recovery.mjs';
test('coordinator verifies contact, sends once under concurrent retries, and redeems delivered proof after restart', async t => {
 const rows = new Map([['membership-owner', { membershipID: 'sub_one', installationHash: 'a'.repeat(64), generation: 1 }]]);
 const env = { CHECKOUT_MODE: 'test', MEMBERSHIP_RECOVERY_ENABLED: 'true', GMAIL_RECOVERY_DELIVERY_ENABLED: 'true', GMAIL_RECOVERY_SENDER: 'operator@example.test',
 STRIPE_SECRET_KEY: 'sk_test_fixture', STRIPE_BOUND_YEAR_MONTHLY_PRICE: 'price_month',
 GMAIL_CLIENT_ID: 'fixture', GMAIL_CLIENT_SECRET: 'fixture', GMAIL_REFRESH_TOKEN: 'fixture',
 PHYSICAL_BOOK_ORDERS: { async get() { return null; } } };
 const state = { storage: { async get(key) { return structuredClone(rows.get(key)); }, async put(key,value) { rows.set(key, structuredClone(value)); } } };
 let coordinator = new PhysicalBookOrderCoordinator(state, env), sends = 0, secret;
 const original = globalThis.fetch; t.after(() => { globalThis.fetch = original; });
 globalThis.fetch = async (url, init) => {
   const parsed = new URL(url);
   if (parsed.hostname === 'api.stripe.com') {
     assert.equal(init.method ?? 'GET', 'GET');
     if (parsed.pathname === '/v1/subscriptions/sub_one') return Response.json({ id: 'sub_one', customer: 'cus_one', livemode: false,
       metadata: { reenchanted_cadence: 'monthly', reenchanted_physical_fulfillment: 'accepted' }, items: { data: [{ price: { id: 'price_month' } }] } });
     if (parsed.pathname === '/v1/customers/cus_one') return Response.json({ id: 'cus_one', livemode: false, email: 'reader@example.com' });
   }
   if (parsed.hostname === 'oauth2.googleapis.com') return Response.json({ access_token: 'fixture', token_type: 'Bearer', expires_in: 3600 });
   if (parsed.hostname === 'gmail.googleapis.com') {
     sends++;
     const mime = Buffer.from(JSON.parse(init.body).raw, 'base64url').toString();
     assert.ok(mime.includes('To: reader@example.com\r\n'));
     const body = Buffer.from(mime.split('\r\n\r\n')[1].replaceAll('\r\n', ''), 'base64').toString();
     secret = body.match(/sub_one\.([A-Za-z0-9_-]{43})/)[1];
     return Response.json({ id: 'message_fixture' });
   }
   throw Error('Unexpected network call');
 };
 const invoke = (action, extra) => coordinator.fetch(new Request('https://internal', { method: 'POST', body: JSON.stringify({
   fulfillmentKind: 'membership-ownership', membershipID: 'sub_one', installationHash: 'b'.repeat(64), action, ...extra }) }));
 const attempt = { attemptID: `${Date.now()}_request_number_0001` };
 const responses = await Promise.all([invoke('issue-recovery', attempt), invoke('issue-recovery', attempt)]);
 assert.deepEqual(responses.map(r => r.status), [200,200]); assert.equal(sends, 1);
 coordinator = new PhysicalBookOrderCoordinator(state, env);
 assert.equal((await invoke('issue-recovery', attempt)).status, 200); assert.equal(sends, 1);
 assert.equal((await invoke('redeem-recovery', { challengeHash: await hashRecoverySecret(secret) })).status, 200);
 assert.equal(rows.get('membership-owner').installationHash, 'b'.repeat(64));
 const serialized = JSON.stringify([...rows]);
 assert.equal(serialized.includes(secret), false); assert.equal(serialized.includes('reader@example.com'), false);
});
