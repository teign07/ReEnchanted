import test from 'node:test';
import assert from 'node:assert/strict';
import worker, { PhysicalBookOrderCoordinator } from './lulu-quote-worker.mjs';

function fixture(t) {
  const hash = 'a'.repeat(64);
  const gift = { allowanceCents: 1000, allowanceCurrencyCode: 'USD', id: 'gift_one', kind: 'bookOfRecipient', paymentIntentID: 'pi_gift', claimTokenHash: hash,
    senderName: 'PRIVATE SENDER', deliveryEnvelope: { sealedAddress: 'PRIVATE ADDRESS' } };
  const dispatch = { membershipID: 'sub_member', seasonKey: '2026-S06', dispatchTokenHash: 'PRIVATE TOKEN', editionTitle: 'PRIVATE TITLE' };
  const kv = new Map([
    ['book-gifts/payment/pi_gift', hash], [`book-gifts/claim/${hash}`, JSON.stringify(gift)],
    ['bound-year-dispatches/sub_member/2026-S06', JSON.stringify(dispatch)],
  ]);
  const stores = new Map(), objects = new Map();
  let failWrite = false, reads = 0, network = 0, provider, failKV = false;
  const env = {
    CHECKOUT_MODE: 'test', STRIPE_SECRET_KEY: 'sk_test_fixture', PHYSICAL_BOOK_ADMIN_TOKEN: 'admin',
    LULU_API_BASE_URL: 'https://api.sandbox.lulu.com',
    LULU_AUTH_URL: 'https://api.sandbox.lulu.com/auth/realms/glasstree/protocol/openid-connect/token',
    PHYSICAL_BOOK_ORDERS: { async get(k) { reads++; return kv.get(k) ?? null; }, async put(k,v) { if (failKV) throw Error('KV unavailable'); kv.set(k,v); } },
  };
  function object(key) {
    if (!stores.has(key)) stores.set(key, new Map());
    if (!objects.has(key)) objects.set(key, new PhysicalBookOrderCoordinator({ storage: {
      async get(k) { return stores.get(key).get(k); },
      async put(k,v) { if (failWrite) throw Error('unavailable'); stores.get(key).set(k,v); },
    } }, env));
    return objects.get(key);
  }
  env.PHYSICAL_BOOK_ORDER_COORDINATOR = {
    idFromName: n => n, get: key => ({ fetch: (url, init) => object(key).fetch(new Request(url, init)) }),
  };
  const original = globalThis.fetch;
  globalThis.fetch = async (url, init) => { network++; if (provider) return provider(new URL(url), init); throw Error('No provider calls are allowed'); };
  t.after(() => { globalThis.fetch = original; });
  const targets = [
    { path: 'gifts/pi_gift', key: 'gift:gift_one', kind: 'gift-book' },
    { path: 'memberships/sub_member/2026-S06', key: 'membership:sub_member:2026-S06', kind: 'membership-dispatch' },
  ];
  async function call(target, action = '', auth = 'admin', prefix = '') {
    const response = await worker.fetch(new Request(`https://example.test${prefix}/admin/parcels/${target.path}${action ? '/' + action : ''}`, {
      method: action ? 'POST' : 'GET', headers: { Authorization: `Bearer ${auth}` },
    }), env);
    return { status: response.status, body: await response.json() };
  }
  const fulfill = target => object(target.key).fetch(new Request('https://internal/fulfill', {
    method: 'POST', body: JSON.stringify({ fulfillmentKind: target.kind }),
  }));
  return { targets, kv, stores, objects, object, call, fulfill, env,
    provider: v => { provider = v; }, failKV: v => { failKV = v; }, failWrite: v => { failWrite = v; }, reads: () => reads, network: () => network };
}

test('gift and membership support require admin credentials before reads', async t => {
  const f = fixture(t);
  for (const target of f.targets) for (const action of ['', 'hold', 'close-refunded']) assert.equal((await f.call(target, action, 'wrong')).status, 401);
  assert.equal(f.reads(), 0); assert.equal(f.network(), 0); assert.equal(f.stores.size, 0);
});

test('inspection is read-only and omits private records, capability URLs and tracking URLs', async t => {
  const f = fixture(t);
  for (const target of f.targets) {
    f.object(target.key);
    const store = f.stores.get(target.key);
    store.set('lulu-submission', { startedAt: '2026-09-08T00:00:00Z', payloadHash: 'PRIVATE HASH',
      receipt: { id: 123, source_url: 'PRIVATE URL' } });
    store.set('fulfilled-order', { id: 'order', luluPrintJobID: '123', status: 'printing', trackingURL: 'PRIVATE TRACKING' });
    const before = structuredClone(store);
    const result = await f.call(target, '', 'admin', '/api/physical-books');
    assert.equal(result.status, 200); assert.equal(result.body.submission.requiresPrinterReview, true);
    assert.equal(result.body.order.luluPrintJobID, '123');
    assert.ok(!JSON.stringify(result.body).includes('PRIVATE')); assert.deepEqual(store, before);
  }
  assert.equal(f.network(), 0);
});

test('holds use the actual fulfillment coordinator, survive restarts, and retain receipts', async t => {
  const f = fixture(t);
  for (const target of f.targets) {
    f.object(target.key);
    const store = f.stores.get(target.key);
    const attempt = { startedAt: '2026-09-08T00:00:00Z', externalID: 'parcel' };
    store.set('lulu-submission', attempt); store.set('fulfilled-order', { id: 'existing' });
    const held = await f.call(target, 'hold'); assert.equal(held.status, 200);
    f.objects.delete(target.key);
    const response = await f.fulfill(target);
    assert.equal(response.status, 409); assert.equal((await response.json()).error, 'order_on_hold');
    assert.equal((await f.call(target, 'hold')).body.hold.heldAt, held.body.hold.heldAt);
    assert.deepEqual(store.get('lulu-submission'), attempt); assert.deepEqual(store.get('fulfilled-order'), { id: 'existing' });
  }
  assert.equal(f.network(), 0);
});

test('hold storage failures fail visibly and can be retried', async t => {
  const f = fixture(t);
  for (const target of f.targets) {
    f.failWrite(true); assert.equal((await f.call(target, 'hold')).status, 500);
    assert.ok(!f.stores.get(target.key).has('operator-hold'));
    f.failWrite(false); assert.equal((await f.call(target, 'hold')).status, 200);
  }
});

test('unknown gifts, wrong index bindings, unprepared seasons, and mismatched environments fail closed', async t => {
  const f = fixture(t);
  for (const path of ['gifts/pi_unknown', 'memberships/sub_member/2026-S09']) assert.equal((await f.call({ path }, 'hold')).status, 404);
  f.kv.set('book-gifts/payment/pi_foreign', 'a'.repeat(64));
  assert.equal((await f.call({ path: 'gifts/pi_foreign' }, 'hold')).status, 404);
  assert.equal(f.stores.size, 0);
  f.env.STRIPE_SECRET_KEY = 'sk_live_wrong';
  for (const target of f.targets) assert.equal((await f.call(target, 'hold')).status, 503);
  assert.equal(f.stores.size, 0); assert.equal(f.network(), 0);
});

test('a hold queues behind an in-flight submission and exposes its resulting receipt', async t => {
  const f = fixture(t);
  for (const target of f.targets) {
    const object = f.object(target.key), original = object.runOrderOperation.bind(object);
    let enter, release;
    const entered = new Promise(r => { enter = r; }), gate = new Promise(r => { release = r; });
    object.runOrderOperation = async p => {
      if (p.fulfillmentKind !== 'test-flight') return original(p);
      enter(); await gate;
      f.stores.get(target.key).set('lulu-submission', { startedAt: '2026-09-08T00:00:00Z', receipt: { id: 123 } });
      return { id: 'submitted' };
    };
    const flight = object.fetch(new Request('https://internal', { method: 'POST', body: JSON.stringify({ fulfillmentKind: 'test-flight' }) }));
    await entered; const holding = f.call(target, 'hold'); release(); await flight;
    const held = await holding;
    assert.equal(held.status, 200); assert.equal(held.body.submission.luluPrintJobID, 123);
    assert.equal((await f.fulfill(target)).status, 409);
  }
});

test('the gift hold does not hold an unrelated membership parcel', async t => {
  const f = fixture(t);
  await f.call(f.targets[0], 'hold');
  assert.equal((await f.call(f.targets[1])).body.hold, null);
});

function refundedPayment(id, invoice = null) {
  return { id, invoice, status: 'succeeded', amount: 1000, amount_received: 1000, currency: 'usd', livemode: false,
    latest_charge: { id: `ch_${id}`, payment_intent: id, amount: 1000, amount_refunded: 1000,
      currency: 'usd', livemode: false, paid: true, refunded: true, disputed: false } };
}
function refundFixture(f, cadence = 'annual') {
  f.env.STRIPE_BOUND_YEAR_ANNUAL_PRICE = 'price_annual';
  f.env.STRIPE_BOUND_YEAR_MONTHLY_PRICE = 'price_monthly';
  const data = { giftPayment: refundedPayment('pi_gift'), refundStatus: 'succeeded', invoices: [], hasMore: false,
    subscription: { id: 'sub_member', livemode: false, items: { data: [{ price: { id: `price_${cadence}` } }] },
      metadata: { reenchanted_cadence: cadence, reenchanted_start_month: '2026-06', reenchanted_physical_fulfillment: 'accepted' } } };
  function invoice(month, suffix = month) {
    const id = `in_${suffix}`, start = Date.UTC(2026, month - 1, 21) / 1000;
    const end = Date.UTC(2026, month - 1 + (cadence === 'annual' ? 12 : 1), 21) / 1000;
    return { id, subscription: 'sub_member', livemode: false, paid: true, status: 'paid', amount_paid: 1000, currency: 'usd',
      payment_intent: refundedPayment(`pi_${suffix}`, id), lines: { has_more: false, data: [{
        type: 'subscription', subscription: 'sub_member', proration: false, price: { id: `price_${cadence}` }, amount: 1000,
        period: { start, end } }] } };
  }
  data.invoices = cadence === 'annual' ? [invoice(6)] : [invoice(6), invoice(7), invoice(8)];
  f.provider((url, init) => {
    assert.ok(!init?.method || init.method === 'GET', 'refund closure must never mutate a provider');
    if (url.pathname === '/v1/payment_intents/pi_gift') return Response.json(data.giftPayment);
    if (url.pathname === '/v1/subscriptions/sub_member') return Response.json(data.subscription);
    if (url.pathname === '/v1/invoices') {
      assert.equal(url.searchParams.get('subscription'), 'sub_member');
      assert.equal(init.headers['Stripe-Version'], '2024-06-20');
      if (data.pages) {
        const cursor = url.searchParams.get('starting_after');
        const index = cursor ? data.pages.findIndex(page => page.at(-1)?.id === cursor) + 1 : 0;
        assert.ok(index >= 0 && index < data.pages.length);
        return Response.json({ data: data.pages[index], has_more: index < data.pages.length - 1 });
      }
      return Response.json({ data: data.invoices, has_more: data.hasMore });
    }
    if (url.pathname === '/v1/refunds') {
      const charge = url.searchParams.get('charge'), pi = charge.slice(3);
      return Response.json({ data: [{ id: `re_${pi}`, charge, payment_intent: pi, amount: 1000, currency: 'usd', status: data.refundStatus }], has_more: false });
    }
    throw Error('Unexpected provider request');
  });
  return { data, invoice };
}

test('refund closure requires a durable hold before any Stripe lookup', async t => {
  const f = fixture(t);
  for (const target of f.targets) assert.equal((await f.call(target, 'close-refunded')).body.error, 'order_hold_required');
  assert.equal(f.network(), 0);
});

test('gift full-refund closure retains attempts and repairs failed KV publication without changing the claim record', async t => {
  const f = fixture(t); refundFixture(f);
  const target = f.targets[0]; await f.call(target, 'hold');
  const store = f.stores.get(target.key), rawGift = f.kv.get(`book-gifts/claim/${'a'.repeat(64)}`);
  store.set('lulu-submission', { startedAt: '2026-09-08T00:00:00Z', receipt: { id: 123 } });
  f.failKV(true);
  assert.equal((await f.call(target, 'close-refunded')).status, 500);
  assert.ok(store.has('refund-resolution')); assert.ok(store.has('operator-hold'));
  f.failKV(false); f.objects.delete(target.key);
  const closed = await f.call(target, 'close-refunded');
  assert.equal(closed.status, 200); assert.equal(closed.body.resolution.kind, 'fully_refunded');
  assert.equal(closed.body.submission.luluPrintJobID, 123);
  assert.equal((await f.call(target, 'close-refunded')).body.resolution.resolvedAt, closed.body.resolution.resolvedAt);
  assert.equal(f.kv.get(`book-gifts/claim/${'a'.repeat(64)}`), rawGift);
  assert.ok(f.kv.has(`reconciliation/parcels/${target.key}`));
  assert.equal((await f.fulfill(target)).status, 409);
});

test('partial, pending, disputed, foreign and wrong-allowance gift refunds stay held and unresolved', async t => {
  const f = fixture(t), { data } = refundFixture(f), target = f.targets[0];
  await f.call(target, 'hold');
  const mutations = [
    () => { data.giftPayment.latest_charge.amount_refunded = 1; },
    () => { data.refundStatus = 'pending'; },
    () => { data.giftPayment.latest_charge.disputed = true; },
    () => { data.giftPayment.id = 'pi_foreign'; },
    () => { data.giftPayment.livemode = true; },
    () => { data.giftPayment.amount = 999; },
    () => { data.giftPayment.latest_charge.payment_intent = 'pi_foreign'; },
  ];
  for (const mutate of mutations) {
    data.giftPayment = refundedPayment('pi_gift'); data.refundStatus = 'succeeded'; mutate();
    assert.equal((await f.call(target, 'close-refunded')).status, 409);
    assert.ok(!f.stores.get(target.key).has('refund-resolution'));
    assert.ok(f.stores.get(target.key).has('operator-hold'));
  }
});

for (const cadence of ['monthly', 'annual']) test(`${cadence} membership closure proves all three months and retains a permanent hold`, async t => {
  const f = fixture(t); refundFixture(f, cadence); const target = f.targets[1];
  await f.call(target, 'hold');
  const closed = await f.call(target, 'close-refunded');
  assert.equal(closed.status, 200); assert.equal(closed.body.resolution.kind, 'fully_refunded');
  const resolution = f.stores.get(target.key).get('refund-resolution');
  assert.equal(resolution.paymentIntentIDs.length, cadence === 'annual' ? 1 : 3);
  f.objects.delete(target.key); assert.equal((await f.fulfill(target)).status, 409);
});

test('a membership season cannot close with a missing month or one unrefunded invoice', async t => {
  const f = fixture(t), { data, invoice } = refundFixture(f, 'monthly'), target = f.targets[1];
  await f.call(target, 'hold');
  data.invoices = [invoice(6), invoice(7)];
  assert.equal((await f.call(target, 'close-refunded')).body.error, 'refund_not_settled');
  data.invoices.push(invoice(8)); data.invoices[2].payment_intent.latest_charge.amount_refunded = 0;
  assert.equal((await f.call(target, 'close-refunded')).body.error, 'refund_not_settled');
  assert.ok(!f.stores.get(target.key).has('refund-resolution'));
});

test('membership proof rejects foreign payments, wrong seasons, prorations and truncated or duplicated invoice lists', async t => {
  const f = fixture(t), { data, invoice } = refundFixture(f), target = f.targets[1];
  await f.call(target, 'hold');
  const mutations = [
    () => { data.invoices[0].payment_intent.invoice = 'in_foreign'; },
    () => { data.invoices[0].subscription = 'sub_foreign'; },
    () => { data.invoices[0].lines.has_more = true; },
    () => { data.invoices[0].lines.data[0].proration = true; },
    () => { data.invoices[0].payment_intent.livemode = true; },
    () => { data.hasMore = true; },
    () => { data.invoices.push(invoice(6)); },
    () => { data.subscription.metadata.reenchanted_start_month = '2026-07'; },
  ];
  for (const mutate of mutations) {
    data.invoices = [invoice(6)]; data.hasMore = false; data.subscription.metadata.reenchanted_start_month = '2026-06'; mutate();
    assert.equal((await f.call(target, 'close-refunded')).status, 409);
    assert.ok(!f.stores.get(target.key).has('refund-resolution'));
  }
});

test('later duplicate coverage with an unrefunded invoice prevents membership closure', async t => {
  const f = fixture(t), { data, invoice } = refundFixture(f), target = f.targets[1];
  await f.call(target, 'hold');
  const duplicate = invoice(6, 'second'); duplicate.payment_intent.latest_charge.amount_refunded = 0;
  data.invoices.push(duplicate);
  assert.equal((await f.call(target, 'close-refunded')).body.error, 'refund_not_settled');
});

test('Stripe outage leaves an existing hold without reporting refund completion', async t => {
  const f = fixture(t);
  for (const target of f.targets) {
    await f.call(target, 'hold');
    assert.equal((await f.call(target, 'close-refunded')).status, 500);
    assert.ok(f.stores.get(target.key).has('operator-hold'));
    assert.ok(!f.stores.get(target.key).has('refund-resolution'));
  }
});

test('membership refund proof follows invoice pagination before acknowledging all three months', async t => {
  const f = fixture(t), { data, invoice } = refundFixture(f, 'monthly'), target = f.targets[1];
  await f.call(target, 'hold');
  data.pages = [[invoice(8)], [invoice(7)], [invoice(6)]];
  const closed = await f.call(target, 'close-refunded');
  assert.equal(closed.status, 200);
  assert.equal(f.stores.get(target.key).get('refund-resolution').paymentIntentIDs.length, 3);
});

for (const index of [0, 1]) test(`${index === 0 ? 'gift' : 'membership'} refund closure survives failure before durable resolution`, async t => {
  const f = fixture(t); refundFixture(f); const target = f.targets[index];
  await f.call(target, 'hold');
  const store = f.stores.get(target.key);
  const submission = { startedAt: '2026-09-08T00:00:00Z', receipt: { id: 123 } };
  store.set('lulu-submission', submission);
  f.failWrite(true);
  assert.equal((await f.call(target, 'close-refunded')).status, 500);
  assert.ok(!store.has('refund-resolution'));
  assert.ok(!f.kv.has(`reconciliation/parcels/${target.key}`));
  f.objects.delete(target.key);
  assert.equal((await f.fulfill(target)).status, 409);
  f.failWrite(false);
  assert.equal((await f.call(target, 'close-refunded')).status, 200);
  assert.deepEqual(store.get('lulu-submission'), submission);
  assert.ok(store.has('operator-hold'));
});

test('membership refund closure repairs failed publication after restart without losing its printer receipt', async t => {
  const f = fixture(t); refundFixture(f, 'monthly'); const target = f.targets[1];
  await f.call(target, 'hold');
  const store = f.stores.get(target.key);
  store.set('lulu-submission', { startedAt: '2026-09-08T00:00:00Z', receipt: { id: 456 } });
  f.failKV(true);
  assert.equal((await f.call(target, 'close-refunded')).status, 500);
  const saved = structuredClone(store.get('refund-resolution'));
  assert.equal(saved.paymentIntentIDs.length, 3);
  f.objects.delete(target.key);
  assert.equal((await f.fulfill(target)).status, 409);
  f.failKV(false);
  const resumed = await f.call(target, 'close-refunded');
  assert.equal(resumed.status, 200);
  assert.equal(resumed.body.submission.luluPrintJobID, 456);
  assert.deepEqual(JSON.parse(f.kv.get(`reconciliation/parcels/${target.key}`)), saved);
  assert.deepEqual(store.get('refund-resolution'), saved);
});
