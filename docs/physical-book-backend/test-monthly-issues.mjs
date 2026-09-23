import assert from 'node:assert/strict';
import { test } from 'node:test';
import { webcrypto, generateKeyPairSync, sign } from 'node:crypto';
import { SignedDataVerifier, Environment } from '@apple/app-store-server-library';
import worker, { PhysicalBookOrderCoordinator } from './lulu-quote-worker.mjs';
import { MonthlyIssueError, issueMonthlySession, recordMonthlyMembershipOwner, readMonthlyMembershipOwner, membershipOwnerKey,
  requireMonthlySession, verifyAppleAccess, serveMonthlyContent, availableMonthlyAssets } from './monthly-issues.mjs';
if (!globalThis.crypto) globalThis.crypto = webcrypto;
const now = Date.parse('2027-11-08T12:00:00Z');
function env() {
  const rows = new Map();
  const e = { MONTHLY_ISSUE_SESSION_SECRET: 'test-only-secret-with-at-least-32-characters', CHECKOUT_MODE: 'test',
    STRIPE_BOUND_YEAR_MONTHLY_PRICE: 'price_monthly',
    PHYSICAL_BOOK_ORDERS: { async get(key) { return rows.get(key); }, async put(key,value) { rows.set(key,value); } },
    PHYSICAL_BOOK_RATE_LIMITER: { async limit() { return { success:true }; } } };
  const objects = new Map();
  e.PHYSICAL_BOOK_ORDER_COORDINATOR = { idFromName: id => id, get(id) {
    if (!objects.has(id)) {
      const state = new Map();
      objects.set(id, new PhysicalBookOrderCoordinator({ storage: {
        async get(k) { return state.get(k); }, async put(k,v) { state.set(k,v); }
      } }, e));
    }
    return { fetch: (url, init) => objects.get(id).fetch(new Request(url, init)) };
  } };
  return e;
}
const membership = () => ({livemode:false,status:'active',current_period_end:(now+60_000)/1000,
  latest_invoice:{status:'paid',paid:true,amount_paid:1200,payment_intent:{status:'succeeded',latest_charge:{paid:true,amount:1200,amount_refunded:0,refunded:false,disputed:false}}},
  metadata:{reenchanted_physical_fulfillment:'accepted'},items:{data:[{price:{id:'price_monthly'}}]}});
const body={signedTransactions:[],membershipID:'sub_owned'};
async function grant(e,owner='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa') {
  await recordMonthlyMembershipOwner(e,'sub_owned',owner);
  return issueMonthlySession(body,e,owner,async()=>membership(),now);
}
const request=token=>new Request('https://issues.example/monthly-issues/manifest',{headers:{Authorization:`Bearer ${token}`}});
const rejects=(fn,status)=>assert.rejects(fn,e=>e instanceof MonthlyIssueError && e.status===status);

test('membership ID alone grants nothing and does not query Stripe',async()=>{
  let calls=0;
  await rejects(()=>issueMonthlySession(body,env(),'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',async()=>{calls++;return membership();},now),403);
  assert.equal(calls,0);
});
test('a checkout mode that is neither test nor live accepts no Stripe livemode',async()=>{
  const owner='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  for(const mode of [' Test ','LIVE']){const e=env();e.CHECKOUT_MODE=mode;await recordMonthlyMembershipOwner(e,'sub_owned',owner);
    await issueMonthlySession(body,e,owner,async()=>({...membership(),livemode:mode.trim().toLowerCase()==='live'}),now);}
  for(const mode of ['disabled',undefined,'']){
    for(const livemode of [true,false]){
      const e=env();e.CHECKOUT_MODE=mode;await recordMonthlyMembershipOwner(e,'sub_owned',owner);
      await rejects(()=>issueMonthlySession(body,e,owner,async()=>({...membership(),livemode}),now),403);
    }
  }
});
test('while the Digital Standing Order is retired any installation reads the shelf, still bound to itself',async()=>{
  const e=env();e.MONTHLY_ISSUES_OPEN_TO_ALL='true';
  let calls=0;
  const s=await issueMonthlySession({signedTransactions:[]},e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    async()=>{calls++;return membership();},now,async()=>{calls++;throw Error();});
  assert.equal(calls,0);
  assert.equal(Date.parse(s.expiresAt),now+600_000);
  await requireMonthlySession(request(s.token),e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',now);
  await rejects(()=>requireMonthlySession(request(s.token),e,'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',now),401);
  await rejects(()=>issueMonthlySession({signedTransactions:'x'},e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',async()=>membership(),now),400);
});
test('ownership cannot be reassigned by another installation',async()=>{
  const e=env();await grant(e);
  await rejects(()=>recordMonthlyMembershipOwner(e,'sub_owned','bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'),403);
  assert.equal(await readMonthlyMembershipOwner(e, 'sub_owned'),'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
});
test('token is bounded by paid-through date and installation',async()=>{
  const e=env(),s=await grant(e);
  assert.equal(Date.parse(s.expiresAt),now+60_000);
  await requireMonthlySession(request(s.token),e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',now);
  await rejects(()=>requireMonthlySession(request(s.token),e,'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',now),401);
  await rejects(()=>requireMonthlySession(request(s.token),e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',now+60_000),401);
});
test('tampered malformed and anonymous tokens fail closed',async()=>{
  const e=env(),s=await grant(e);const [p,sig]=s.token.split('.');
  const c=JSON.parse(Buffer.from(p,'base64url'));c.sub='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  await rejects(()=>requireMonthlySession(request(Buffer.from(JSON.stringify(c)).toString('base64url')+'.'+sig),e,'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',now),401);
  for(const value of ['invalid','.',s.token+'.extra']) await rejects(()=>requireMonthlySession(request(value),e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',now),401);
  await rejects(()=>requireMonthlySession(new Request('https://issues.example'),e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',now),401);
});
test('Stripe expiry unpaid state wrong product and test receipts in live fail',async()=>{
  const e=env();await grant(e);
  for(const change of [{status:'past_due'},{status:'canceled'},{current_period_end:now/1000},{items:{data:[{price:{id:'other'}}]}}]) {
    await rejects(()=>issueMonthlySession(body,e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',async()=>({...membership(),...change}),now),403);
  }
  e.CHECKOUT_MODE='live';await rejects(()=>issueMonthlySession(body,e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',async()=>membership(),now),403);
});
test('providers can independently grant access during the others outage',async()=>{
  const e=env();await grant(e);const both={...body,signedTransactions:['signed']};
  const s=await issueMonthlySession(both,e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',async()=>{throw Error();},now,async()=>now+120_000);
  await requireMonthlySession(request(s.token),e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',now);
  let calls=0;await issueMonthlySession(both,e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',async()=>membership(),now,async()=>{calls++;throw Error();});
  assert.equal(calls,0);
});
test('unpaid refunded and disputed Bound Year payments cannot mint access',async()=>{
  const e=env();await grant(e);
  for(const change of ['unpaid','refunded','disputed','missing-payment']) {
    const m=membership();
    if(change==='unpaid')m.latest_invoice.status='open';
    if(change==='refunded')m.latest_invoice.payment_intent.latest_charge.refunded=true;
    if(change==='disputed')m.latest_invoice.payment_intent.latest_charge.disputed=true;
    if(change==='missing-payment')delete m.latest_invoice.payment_intent;
    await rejects(()=>issueMonthlySession(body,e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',async()=>m,now),403);
  }
});
test('provider outage is retriable and signing misconfiguration cannot mint access',async()=>{
  const e=env();await grant(e);
  await rejects(()=>issueMonthlySession(body,e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',async()=>{throw Error();},now),503);
  delete e.MONTHLY_ISSUE_SESSION_SECRET;
  await rejects(()=>issueMonthlySession(body,e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',async()=>membership(),now),503);
});
function appleClients(overrides={}) {
  const tx={bundleId:'com.openclaw.enchantify.insidecover',productId:'com.openclaw.enchantify.insidecover.pass.standing-order.monthly',
    originalTransactionId:'original',expiresDate:now+600_000,purchaseDate:now-60_000,...overrides};
  return {verifier:{async verifyAndDecodeTransaction(proof){if(proof==='bad')throw Error();return tx;}},
    api:{async getAllSubscriptionStatuses(){return {data:[{lastTransactions:[{status:1,signedTransactionInfo:'current'}]}]};}}};
}
test('Apple signed proof and current server state are both required',async()=>{
  assert.equal(await verifyAppleAccess(env(),['presented'],now,appleClients()),now+600_000);
  for(const o of [{productId:'other'},{bundleId:'other'},{expiresDate:now},{revocationDate:now-1},{isUpgraded:true},{purchaseDate:now+1}])
    assert.equal(await verifyAppleAccess(env(),['presented'],now,appleClients(o)),null);
  assert.equal(await verifyAppleAccess(env(),['bad'],now,appleClients()),null);
  const c=appleClients();c.api.getAllSubscriptionStatuses=async()=>({data:[{lastTransactions:[{status:5,signedTransactionInfo:'current'}]}]});
  assert.equal(await verifyAppleAccess(env(),['presented'],now,c),null);
});
test('Apple current transaction cannot switch subscriber identity',async()=>{
  const c=appleClients(),original=c.verifier.verifyAndDecodeTransaction;
  c.verifier.verifyAndDecodeTransaction=async p=>({...await original(p),originalTransactionId:p==='current'?'other':'original'});
  assert.equal(await verifyAppleAccess(env(),['presented'],now,c),null);
});
test('real Apple verifier rejects unsigned local JSON',async()=>{
  const v=new SignedDataVerifier([],true,Environment.SANDBOX,'com.openclaw.enchantify.insidecover');
  await assert.rejects(()=>v.verifyAndDecodeTransaction(Buffer.from(JSON.stringify({expiresDate:now+99999})).toString('base64url')));
});
function issue(id,start,end) {return {id,foreshadowStartsAt:start,liveStartsAt:start,liveEndsAt:end,residueEndsAt:end,casebookAvailableAt:end,
  assets:[{id:id+'-asset',scope:'runtime',byteCount:3,remoteURL:`https://issues.example/monthly-issues/assets/${id}-asset`}]};}
test('download shelf bounds current next retired and published casebook assets',()=>{
  const old=issue('old','2027-10-01','2027-11-01'),current=issue('current','2027-11-01','2027-12-01'),next=issue('next','2027-12-01','2028-01-01'),future=issue('future','2028-01-01','2028-02-01');
  old.assets.push({id:'old-casebook',scope:'casebook'});
  assert.deepEqual(availableMonthlyAssets([old,current,next,future],now).map(a=>a.id),['old-casebook','current-asset','next-asset']);
  current.assets[0].retiresAt=new Date(now).toISOString();assert.equal(availableMonthlyAssets([current],now).length,0);
});
async function shelfEnv() {
  const e=env(),keys=generateKeyPairSync('ed25519');
  const payload=Buffer.from(JSON.stringify({schemaVersion:1,issues:[issue('current','2027-11-01','2027-12-01')]}));
  const envelope=Buffer.from(JSON.stringify({keyID:'test',payload:payload.toString('base64'),signature:sign(null,payload,keys.privateKey).toString('base64')}));
  e.MONTHLY_ISSUE_MANIFEST_PUBLIC_KEY=keys.publicKey.export({format:'der',type:'spki'}).subarray(-32).toString('base64');
  let reads=0;e.MONTHLY_ISSUE_FILES={async get(key){reads++;const b=key==='manifest.envelope.json'?envelope:key==='assets/current-asset'?Buffer.from('abc'):null;
    return b?{size:b.length,async arrayBuffer(){return Uint8Array.from(b).buffer;},body:b}:null;}};
  return {e,reads:()=>reads,envelope};
}
test('private manifest and bytes require session before touching storage',async()=>{
  const {e,reads,envelope}=await shelfEnv();
  await rejects(()=>serveMonthlyContent(new Request('https://issues.example/monthly-issues/manifest'),e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','/monthly-issues/manifest',now),401);
  assert.equal(reads(),0);const s=await grant(e);
  const r=await serveMonthlyContent(request(s.token),e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','/monthly-issues/manifest',now);
  assert.equal(await r.text(),envelope.toString());assert.equal(r.headers.get('Cache-Control'),'private, no-store');
  assert.equal(await (await serveMonthlyContent(request(s.token),e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','/monthly-issues/assets/current-asset',now)).text(),'abc');
  await rejects(()=>serveMonthlyContent(request(s.token),e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','/monthly-issues/assets/unknown',now),404);
});
test('schema 2 serves dotted media IDs but a signed traversal ID still closes the shelf',async()=>{
  const owner='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  for(const [id,status] of [['count-unbound.seasonal.black-cat',200],['..',503],['.hidden',503],['a..b',503],['a/b',503]]){
    const e=env(),keys=generateKeyPairSync('ed25519'),s=await grant(e),current=issue('current','2027-11-01','2027-12-01');
    current.assets=[{id,scope:'runtime',byteCount:3,remoteURL:`https://issues.example/monthly-issues/assets/${id}`}];
    const payload=Buffer.from(JSON.stringify({schemaVersion:2,issues:[current]}));
    const envelope=Buffer.from(JSON.stringify({keyID:'test',payload:payload.toString('base64'),signature:sign(null,payload,keys.privateKey).toString('base64')}));
    e.MONTHLY_ISSUE_MANIFEST_PUBLIC_KEY=keys.publicKey.export({format:'der',type:'spki'}).subarray(-32).toString('base64');
    e.MONTHLY_ISSUE_FILES={async get(key){const b=key==='manifest.envelope.json'?envelope:Buffer.from('abc');return {size:b.length,async arrayBuffer(){return Uint8Array.from(b).buffer;},body:b};}};
    const path=`/monthly-issues/assets/${id}`;
    if(status===200) assert.equal(await (await serveMonthlyContent(request(s.token),e,owner,path,now)).text(),'abc');
    else await rejects(()=>serveMonthlyContent(request(s.token),e,owner,path,now),status);
  }
});
test('invalid publisher signature cannot authorize asset inventory',async()=>{
  const {e}=await shelfEnv(),s=await grant(e);
  e.MONTHLY_ISSUE_FILES={async get(){const b=Buffer.from(JSON.stringify({payload:'e30=',signature:'broken'}));return {size:b.length,async arrayBuffer(){return b;}};}};
  await rejects(()=>serveMonthlyContent(request(s.token),e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','/monthly-issues/manifest',now),503);
});
test('production HTTP asset routes allow a complete pack beyond twelve files',async()=>{
  const e=env(),clock=Date.now(),installation='monthly-route-test-installation';
  const owner=Buffer.from(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(installation))).toString('hex');
  await recordMonthlyMembershipOwner(e,'sub_owned',owner);
  const session=await issueMonthlySession(body,e,owner,async()=>({...membership(),current_period_end:(clock+600_000)/1000}),clock);
  const keys=generateKeyPairSync('ed25519');
  const current=issue('current',new Date(clock-3600_000).toISOString(),new Date(clock+3600_000).toISOString());
  current.assets=Array.from({length:17},(_,i)=>({id:`asset-${i}`,scope:'runtime',byteCount:3,
    remoteURL:`https://issues.example/monthly-issues/assets/asset-${i}`}));
  const payload=Buffer.from(JSON.stringify({schemaVersion:1,issues:[current]}));
  const envelope=Buffer.from(JSON.stringify({keyID:'test',payload:payload.toString('base64'),signature:sign(null,payload,keys.privateKey).toString('base64')}));
  e.MONTHLY_ISSUE_MANIFEST_PUBLIC_KEY=keys.publicKey.export({format:'der',type:'spki'}).subarray(-32).toString('base64');
  e.MONTHLY_ISSUE_FILES={async get(key){const bytes=key==='manifest.envelope.json'?envelope:Buffer.from('abc');
    return {size:bytes.length,arrayBuffer:async()=>bytes,body:bytes};}};
  let limiterCalls=0;e.PHYSICAL_BOOK_RATE_LIMITER={async limit(){limiterCalls++;return {success:false};}};
  for(const asset of current.assets){
    const response=await worker.fetch(new Request(asset.remoteURL,{headers:{
      'X-Installation-ID':installation,Authorization:`Bearer ${session.token}`}}),e);
    assert.equal(response.status,200);assert.equal(await response.text(),'abc');
  }
  assert.equal(limiterCalls,0);
  const denied=await worker.fetch(new Request(current.assets[0].remoteURL,{headers:{'X-Installation-ID':installation}}),e);
  assert.equal(denied.status,401);
});
test('HTTP exchange verifies print session ownership and Stripe; input is bounded',async()=>{
  const e=env(),installation='monthly-test-installation-12345',headers={'X-Installation-ID':installation,'CF-Connecting-IP':'127.0.0.1','Content-Type':'application/json'};
  const r=await worker.fetch(new Request('https://issues.example/sessions',{method:'POST',headers}),e);
  const token=(await r.json()).token;
  const owner=Buffer.from(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(installation))).toString('hex');
  await recordMonthlyMembershipOwner(e,'sub_owned',owner);e.STRIPE_SECRET_KEY='sk_test_mock';
  const original=globalThis.fetch;
  globalThis.fetch=async(url,options)=>{
    assert.equal(options.headers['Stripe-Version'],'2024-06-20');
    assert(String(url).includes('latest_invoice.payment_intent.latest_charge'));
    return new Response(JSON.stringify({...membership(),current_period_end:Math.floor(Date.now()/1000)+300}));
  };
  try {
    const result=await worker.fetch(new Request('https://issues.example/monthly-issues/session',{method:'POST',headers:{...headers,Authorization:`Bearer ${token}`},body:JSON.stringify(body)}),e);
    assert.equal(result.status,200);assert.equal(result.headers.get('Cache-Control'),'private, no-store');
    await requireMonthlySession(request((await result.json()).token),e,owner);
    const large=await worker.fetch(new Request('https://issues.example/monthly-issues/session',{method:'POST',headers:{...headers,Authorization:`Bearer ${token}`},body:'x'.repeat(70_000)}),e);
    assert.equal(large.status,413);
  } finally {globalThis.fetch=original;}
});


test('monthly access rejects zero-paid invoices, negative refund amounts and mismatched mode',async()=>{
  const e=env();await grant(e);
  for(const change of ['zero-paid','negative-refund','live-in-test','missing-mode']) {
    const m=membership();
    if(change==='zero-paid')m.latest_invoice.amount_paid=0;
    if(change==='negative-refund')m.latest_invoice.payment_intent.latest_charge.amount_refunded=-1;
    if(change==='live-in-test')m.livemode=true;
    if(change==='missing-mode')delete m.livemode;
    await rejects(()=>issueMonthlySession(body,e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',async()=>m,now),403);
  }
});

test('refund blocks renewal of access while an existing session expires at ten minutes',async()=>{
  const e=env();await recordMonthlyMembershipOwner(e,'sub_owned','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
  const m=membership();m.current_period_end=(now+86_400_000)/1000;
  const issued=await issueMonthlySession(body,e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',async()=>m,now);
  assert.equal(Date.parse(issued.expiresAt),now+600_000);
  m.latest_invoice.payment_intent.latest_charge.refunded=true;
  m.latest_invoice.payment_intent.latest_charge.amount_refunded=1200;
  await rejects(()=>issueMonthlySession(body,e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',async()=>m,now+1_000),403);
  await requireMonthlySession(request(issued.token),e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',now+599_999);
  await rejects(()=>requireMonthlySession(request(issued.token),e,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',now+600_000),401);
});

test('ownership coordinator outage denies Stripe access but preserves independent Apple proof', async () => {
  const e = env(); await grant(e);
  delete e.PHYSICAL_BOOK_ORDER_COORDINATOR;
  let stripeCalls = 0;
  const read = async () => { stripeCalls++; return membership(); };
  await rejects(() => issueMonthlySession(body, e, 'a'.repeat(64), read, now), 503);
  const access = await issueMonthlySession({ ...body, signedTransactions: ['proof'] }, e, 'a'.repeat(64), read, now,
    async () => now + 60000);
  assert.equal(Date.parse(access.expiresAt), now + 60000);
  assert.equal(stripeCalls, 0);
});
