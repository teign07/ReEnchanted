import test from 'node:test';
import assert from 'node:assert/strict';
import { verifiedRecoveryContact } from './membership-recovery-contact.mjs';
function fixture() {
 const env = { CHECKOUT_MODE: 'test', STRIPE_BOUND_YEAR_MONTHLY_PRICE: 'price_month' };
 const sub = { id: 'sub_one', customer: 'cus_one', livemode: false,
 metadata: { reenchanted_cadence: 'monthly', reenchanted_physical_fulfillment: 'accepted' },
 items: { data: [{ price: { id: 'price_month' } }] } };
 const customer = { id: 'cus_one', livemode: false, email: 'reader@example.com' };
 let reads = 0;
 return { sub, customer, reads: () => reads, run: () => verifiedRecoveryContact(env, 'sub_one', async () => sub,
 async id => { reads++; assert.equal(id, 'cus_one'); return customer; }) };
}
test('recipient comes from the subscription customer, including cancelled memberships', async () => {
 const f = fixture(); f.sub.status = 'canceled';
 assert.equal(await f.run(), 'reader@example.com');
});
test('gift provenance and unknown products fail before customer lookup', async () => {
 for (const mutate of [f => f.sub.metadata.reenchanted_gift = 'true',
 f => f.sub.metadata.reenchanted_gift = 'unexpected', f => f.sub.livemode = true,
 f => f.sub.id = 'sub_other', f => f.sub.items.data = [], f => f.sub.customer = { id: 'cus_one' }]) {
 const f = fixture(); mutate(f);
 await assert.rejects(f.run(), { code: 'membership_recovery_unavailable' }); assert.equal(f.reads(), 0);
 }
});
test('deleted, mismatched and invalid customer contacts cannot receive codes', async () => {
 for (const mutate of [f => f.customer.deleted = true, f => f.customer.id = 'cus_other',
 f => f.customer.livemode = true, f => f.customer.email = 'a@example.com\r\nBcc: other@example.com',
 f => f.customer.email = null]) {
 const f = fixture(); mutate(f);
 await assert.rejects(f.run(), { code: 'membership_recovery_unavailable' });
 }
});
