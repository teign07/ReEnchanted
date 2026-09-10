import test from 'node:test';
import assert from 'node:assert/strict';
import worker, { PhysicalBookOrderCoordinator } from './lulu-quote-worker.mjs';
import { createRecoveryChallenge, readRecoveryRedemption } from './membership-recovery.mjs';
const request = body => new Request('https://example.test', { method: 'POST', body });
test('issuer generates independent secrets; boundary accepts only the secret, never a supplied hash', async () => {
  const a = await createRecoveryChallenge(), b = await createRecoveryChallenge();
  assert.notEqual(a.secret, b.secret); assert.notEqual(a.challengeHash, a.secret);
  assert.deepEqual(await readRecoveryRedemption(request(JSON.stringify({membershipID:'sub_test',secret:a.secret}))),
    {membershipID:'sub_test',challengeHash:a.challengeHash});
  for (const body of ['null','[]','{}','broken',JSON.stringify({membershipID:'sub_test',challengeHash:a.challengeHash}),
    JSON.stringify({membershipID:'sub_test',secret:a.secret,installationHash:'forged'})]) {
    await assert.rejects(() => readRecoveryRedemption(request(body)), e => e.status === 400);
  }
  await assert.rejects(() => readRecoveryRedemption(request(' '.repeat(2049))), e => e.status === 413);
});
test('public recovery stays disabled by default', async () => {
  const response = await worker.fetch(new Request('https://example.test/memberships/recovery/redeem',{method:'POST'}),{});
  assert.equal(response.status,503);
  assert.equal((await response.json()).error,'membership_recovery_disabled');
});
test('HTTP redemption requires client authentication and bound device, consumes proof without granting payment', async () => {
  const kv = new Map(), durable = new Map(), objects = new Map();
  const env = { MEMBERSHIP_RECOVERY_ENABLED:'true',
    PHYSICAL_BOOK_ORDERS:{async get(k){return kv.get(k)},async put(k,v){kv.set(k,v)}},
    PHYSICAL_BOOK_RATE_LIMITER:{async limit(){return {success:true}}} };
  env.PHYSICAL_BOOK_ORDER_COORDINATOR={idFromName:id=>id,get(id){
    if(!objects.has(id)) {
      const rows = new Map();durable.set(id,rows);
      objects.set(id,new PhysicalBookOrderCoordinator({storage:{async get(k){return structuredClone(rows.get(k))},async put(k,v){rows.set(k,structuredClone(v))}}},env));
    }
    return {fetch:(url,init)=>objects.get(id).fetch(new Request(url,init))};
  }};
  const owner='original-reader-installation', destination='replacement-reader-installation';
  const hash=async s=>Buffer.from(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s))).toString('hex');
  const stub=env.PHYSICAL_BOOK_ORDER_COORDINATOR.get('membership-owner:sub_test');
  const internal=async(action,installationHash,extra={})=>stub.fetch('https://internal',{method:'POST',body:JSON.stringify({fulfillmentKind:'membership-ownership',membershipID:'sub_test',action,installationHash,...extra})});
  await internal('register',await hash(owner));
  const challenge=await createRecoveryChallenge();
  await internal('prepare-recovery',await hash(destination),{challengeHash:challenge.challengeHash,expiresAt:challenge.expiresAt});
  async function session(installation){
    const response=await worker.fetch(new Request('https://example.test/sessions',{method:'POST',headers:{'X-Installation-ID':installation}}),env);
    assert.equal(response.status,201);return (await response.json()).token;
  }
  async function redeem(installation,token){return worker.fetch(new Request('https://example.test/memberships/recovery/redeem',{method:'POST',headers:{'X-Installation-ID':installation,...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify({membershipID:'sub_test',secret:challenge.secret})}),env)}
  assert.equal((await redeem(destination)).status,401);
  assert.equal((await redeem(owner,await session(owner))).status,403);
  const token=await session(destination),result=await redeem(destination,token);
  assert.equal(result.status,200);assert.equal(result.headers.get('Cache-Control'),'private, no-store');
  assert.deepEqual(await result.json(),{membershipID:'sub_test',recovered:true});
  assert.equal((await redeem(destination,token)).status,200);
  const record=durable.get('membership-owner:sub_test').get('membership-owner');
  assert.equal(record.installationHash,await hash(destination));assert.equal(record.generation,2);
  assert.ok(!JSON.stringify([...durable.values()].map(x=>[...x])).includes(challenge.secret));
});
