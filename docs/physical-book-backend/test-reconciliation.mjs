import test from 'node:test';
import assert from 'node:assert/strict';
import {webcrypto} from 'node:crypto';
import worker, {PhysicalBookOrderCoordinator} from './lulu-quote-worker.mjs';
if (!globalThis.crypto) globalThis.crypto = webcrypto;

function fixture(t) {
  const quoteID='quote_reconcile', paymentIntentID='pi_reconcile';
  const record={paymentIntentID, contactEmail:'private@example.com',quote:{id:quoteID,request:{shipTo:{street1:'Private street',countryCode:'US'}}}};
  const kv=new Map([[`physical-book-quotes/${quoteID}`,JSON.stringify(record)],
    [`reconciliation/paid/${quoteID}`,JSON.stringify({quoteID,paymentIntentID,paidAt:new Date().toISOString()})]]);
  const durable=new Map();let failKey;let failKV;let refundStatus='succeeded';let chargeRefunded=true;let piLive=false;let badQuote=false;let hasMore=false;let posts=0;let fetches=0;
  const state={storage:{async get(k){return durable.get(k)},async put(k,v){if(k===failKey)throw Error('durable unavailable');durable.set(k,v)}}};
  const env={CHECKOUT_MODE:'test',STRIPE_SECRET_KEY:'sk_test_fixture',PHYSICAL_BOOK_ADMIN_TOKEN:'admin',
    LULU_API_BASE_URL:'https://api.sandbox.lulu.com',LULU_AUTH_URL:'https://api.sandbox.lulu.com/auth/realms/glasstree/protocol/openid-connect/token',
    PHYSICAL_BOOK_ORDERS:{async get(k){return kv.get(k)??null},async put(k,v){if(k===failKV)throw Error('KV unavailable');kv.set(k,v)},async delete(k){if(k===failKV)throw Error('KV unavailable');kv.delete(k)},async list({prefix}){return {keys:[...kv.keys()].filter(k=>k.startsWith(prefix)).map(name=>({name})),list_complete:true}}}};
  let object=new PhysicalBookOrderCoordinator(state,env);
  env.PHYSICAL_BOOK_ORDER_COORDINATOR={idFromName:n=>n,get:n=>{assert.equal(n,paymentIntentID);return {fetch:(url,init)=>object.fetch(new Request(url,init))}}};
  const original=globalThis.fetch;t.after(()=>{globalThis.fetch=original});
  globalThis.fetch=async(url,init={})=>{
    fetches++;if(init.method==='POST')posts++;
    const u=new URL(url);
    if(u.pathname===`/v1/payment_intents/${paymentIntentID}`)return Response.json({id:paymentIntentID,status:'succeeded',amount:1000,amount_received:1000,currency:'usd',livemode:piLive,client_secret:'private_secret',metadata:{quote_id:badQuote?'foreign_quote':quoteID},latest_charge:{id:'ch_reconcile',payment_intent:paymentIntentID,amount:1000,amount_refunded:chargeRefunded?1000:0,currency:'usd',livemode:piLive,paid:true,refunded:chargeRefunded,disputed:false}});
    if(u.pathname==='/v1/refunds')return Response.json({data:[{id:'re_one',charge:'ch_reconcile',payment_intent:paymentIntentID,currency:'usd',amount:1000,status:refundStatus}],has_more:hasMore});
    throw Error('Unexpected external request');
  };
  async function call(action='',auth='admin'){
    const response=await worker.fetch(new Request(`https://example.test/admin/reconciliation/${quoteID}${action?'/'+action:''}`,{method:action?'POST':'GET',headers:{Authorization:'Bearer '+auth}}),env);
    return {status:response.status,body:await response.json()};
  }
  return {quoteID,paymentIntentID,record,kv,durable,env,call,state,
    restart(){object=new PhysicalBookOrderCoordinator(state,env);return object},
    object:()=>object, fetches:()=>fetches,posts:()=>posts,
    failWrite:k=>{failKey=k},failKV:k=>{failKV=k},refundStatus:s=>{refundStatus=s},chargeRefunded:s=>{chargeRefunded=s},piLive:v=>{piLive=v},badQuote:v=>{badQuote=v},hasMore:v=>{hasMore=v}};
}

test('operator routes require admin authorization before reads or network access',async t=>{
 const f=fixture(t);for(const action of ['', 'hold','close-refunded'])assert.equal((await f.call(action,'wrong')).status,401);
 assert.equal(f.fetches(),0);assert.equal(f.durable.size,0);
});
test('inspection exposes only payment facts; holding stops fulfillment after restart',async t=>{
 const f=fixture(t);const inspected=await f.call();assert.equal(inspected.status,200);assert.equal(f.durable.size,0);
 assert.equal(inspected.body.payment.fullyRefunded,true);assert.ok(!JSON.stringify(inspected).includes('private'));
 assert.equal((await f.call('hold')).status,200);
 const result=await f.restart().fetch(new Request('https://internal/fulfill',{method:'POST',body:JSON.stringify({orderRequest:{quoteID:f.quoteID,paymentIntentID:f.paymentIntentID}})}));
 assert.equal(result.status,409);assert.equal((await result.json()).error,'order_on_hold');assert.equal(f.posts(),0);
});
test('closure requires a hold and a completed full refund; partial and pending stay open',async t=>{
 const f=fixture(t);assert.equal((await f.call('close-refunded')).body.error,'order_hold_required');
 await f.call('hold');f.chargeRefunded(false);assert.equal((await f.call('close-refunded')).body.error,'refund_not_settled');
 f.chargeRefunded(true);f.refundStatus('pending');assert.equal((await f.call('close-refunded')).body.error,'refund_not_settled');
 assert.ok(f.kv.has(`reconciliation/paid/${f.quoteID}`));assert.ok(!f.durable.has('refund-resolution'));
 f.refundStatus('succeeded');assert.equal((await f.call('close-refunded')).status,200);
 assert.ok(!f.kv.has(`reconciliation/paid/${f.quoteID}`));assert.ok(f.durable.has('operator-hold'));
 assert.ok(!f.kv.get(`physical-book-quotes/${f.quoteID}`).includes('Private street'));assert.equal(f.posts(),0);
});
test('refund resolution retains the uncertain printer attempt and repairs a failed KV publication',async t=>{
 const f=fixture(t);const attempt={payloadHash:'digest',externalID:f.quoteID,startedAt:'2026-09-08T00:00:00Z'};f.durable.set('lulu-submission',attempt);
 await f.call('hold');f.failKV(`reconciliation/refunded/${f.quoteID}`);assert.equal((await f.call('close-refunded')).status,500);
 assert.ok(f.kv.has(`reconciliation/paid/${f.quoteID}`));assert.ok(f.durable.has('refund-resolution'));
 f.failKV(null);f.restart();const closed=await f.call('close-refunded');assert.equal(closed.status,200);assert.equal(closed.body.submission.requiresPrinterReview,true);
 assert.deepEqual(f.durable.get('lulu-submission'),attempt);assert.ok(f.durable.has('operator-hold'));
 assert.equal((await f.call('close-refunded')).body.resolution.resolvedAt,closed.body.resolution.resolvedAt);
});
test('durable hold failure does not report a hold or close the queue',async t=>{
 const f=fixture(t);f.failWrite('operator-hold');assert.equal((await f.call('hold')).status,500);assert.ok(!f.durable.has('operator-hold'));assert.equal(f.fetches(),0);
});
test('holds and in-flight fulfillment serialize in both arrival orders',async t=>{
 const f=fixture(t);let release;const started=new Promise(r=>{release=r});let finish;const gate=new Promise(r=>{finish=r});
 const original=f.object().runOrderOperation.bind(f.object());
 f.object().runOrderOperation=async p=>{if(p.fulfillmentKind==='test-delay'){release();await gate;f.durable.set('fulfilled-order',{id:'existing'}) ;return {id:'existing'}}return original(p)};
 const running=f.object().fetch(new Request('https://internal',{method:'POST',body:JSON.stringify({fulfillmentKind:'test-delay'})}));
 await started;const holding=f.call('hold');finish();await running;assert.equal((await holding).status,200);
 const retry=await f.restart().fetch(new Request('https://internal',{method:'POST',body:'{}'}));assert.equal(retry.status,409);
});
test('foreign payments, wrong modes, duplicate refund pages and gifts cannot be resolved',async t=>{
 const f=fixture(t);f.piLive(true);assert.equal((await f.call()).body.error,'payment_quote_mismatch');f.piLive(false);
 f.badQuote(true);assert.equal((await f.call()).body.error,'payment_quote_mismatch');f.badQuote(false);
 f.hasMore(true);assert.equal((await f.call()).body.error,'refund_proof_invalid');f.hasMore(false);
 f.env.STRIPE_SECRET_KEY='sk_live_wrong';assert.equal((await f.call()).status,503);f.env.STRIPE_SECRET_KEY='sk_test_fixture';
 // Use the production helper's actual gift index namespace.
 f.kv.set(`book-gifts/payment/${f.paymentIntentID}`,'gift');
 assert.equal((await f.call('hold')).body.error,'gift_reconciliation_required');assert.ok(!f.durable.has('operator-hold'));
});

test('a stale paid marker cannot reopen a resolved reconciliation alert',async t=>{
 const f=fixture(t);await f.call('hold');await f.call('close-refunded');
 f.kv.set(`reconciliation/paid/${f.quoteID}`,JSON.stringify({quoteID:f.quoteID,paymentIntentID:f.paymentIntentID,paidAt:'2020-01-01T00:00:00Z'}));
 const response=await worker.fetch(new Request('https://example.test/admin/reconciliation',{headers:{Authorization:'Bearer admin'}}),f.env);
 assert.equal(response.status,200);assert.equal((await response.json()).pendingCount,0);
});

test('failure to clear an alert is repaired by repeated closure without dropping the hold',async t=>{
 const f=fixture(t);await f.call('hold');f.failKV(`reconciliation/paid/${f.quoteID}`);
 assert.equal((await f.call('close-refunded')).status,500);assert.ok(f.durable.has('operator-hold'));
 f.failKV(null);f.restart();assert.equal((await f.call('close-refunded')).status,200);
 assert.ok(!f.kv.has(`reconciliation/paid/${f.quoteID}`));assert.equal(f.posts(),0);
});
