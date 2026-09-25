import test from 'node:test';
import assert from 'node:assert/strict';
import { createGmailRecoveryDelivery, recoveryMessage } from './gmail-recovery-delivery.mjs';
const sender = 'operator@example.test';
const env = () => ({GMAIL_RECOVERY_DELIVERY_ENABLED:'true',GMAIL_CLIENT_ID:'fixture-client',GMAIL_CLIENT_SECRET:'fixture-secret',GMAIL_REFRESH_TOKEN:'fixture-refresh',GMAIL_RECOVERY_SENDER:sender});
const message = {recipient:'reader@example.invalid',membershipID:'sub_fixture',secret:Buffer.alloc(32,1).toString('base64url')};
const token = () => Response.json({access_token:'fixture-access',token_type:'Bearer',expires_in:3600});
test('configured sender, reply address, encoded body and input reject header injection', () => {
  const mime = Buffer.from(recoveryMessage({...message,sender}),'base64url').toString();
  assert.ok(mime.includes('From: ReEnchanted <operator@example.test>\r\n'));
  assert.ok(mime.includes('Reply-To: help@reenchanted.app\r\n'));
  assert.ok(Buffer.from(mime.split('\r\n\r\n')[1],'base64').toString().includes(message.secret));
  for(const change of [{recipient:'reader@example.invalid\r\nBcc: attacker@example.invalid'},{recipient:'a@example.invalid,b@example.invalid'},{membershipID:'sub_bad\n'},{secret:'invalid'},{sender:'operator@example.test\r\nBcc: attacker@example.invalid'},{sender:undefined}])
    assert.throws(()=>recoveryMessage({...message,sender,...change}), /invalid_recovery_message/);
});
test('disabled or unconfigured delivery performs no network calls', async () => {
  for(const e of [{}, {...env(),GMAIL_REFRESH_TOKEN:''}, {...env(),GMAIL_RECOVERY_SENDER:''}]) {
    const send=createGmailRecoveryDelivery(e,()=>{throw Error('must not fetch')});
    await assert.rejects(()=>send(message), /recovery_mail_disabled|recovery_mail_not_configured/);
  }
});
test('concurrent delivery shares refresh, pins the mailbox and caches until expiry',async()=>{
  let refreshes=0,sends=0,clock=0;
  const send=createGmailRecoveryDelivery(env(),async(url,init)=>{
    assert.equal(init.redirect,'manual');
    if(url.includes('oauth2.')) {refreshes++;return token();}
    sends++;assert.ok(url.includes('operator%40example.test/messages/send'));
    assert.equal(init.headers.Authorization,'Bearer fixture-access');return Response.json({id:`message_${sends}`});
  },()=>clock);
  await Promise.all([send(message),send(message)]);assert.equal(refreshes,1);assert.equal(sends,2);
  clock=3600000;await send(message);assert.equal(refreshes,2);
});
test('refresh failures do not leak provider details or attempt sending',async()=>{
  let calls=0;
  const send=createGmailRecoveryDelivery(env(),async()=>{calls++;return Response.json({error:'PRIVATE PROVIDER DETAIL'},{status:400})});
  await assert.rejects(()=>send(message),e=>e.code==='recovery_mail_authorization_failed'&&!e.message.includes('PRIVATE'));
  assert.equal(calls,1);
});
for(const kind of ['timeout','server-error','malformed-success','missing-id']) test(`${kind} is uncertain and never retried`,async()=>{
  let sends=0;
  const send=createGmailRecoveryDelivery(env(),async url=>{
    if(url.includes('oauth2.'))return token();sends++;
    if(kind==='timeout')throw Error('PRIVATE TOKEN');
    if(kind==='server-error')return new Response('PRIVATE',{status:503});
    if(kind==='malformed-success')return new Response('PRIVATE');
    return Response.json({});
  });
  await assert.rejects(()=>send(message),e=>e.code==='recovery_mail_delivery_uncertain');assert.equal(sends,1);
});
test('rejected authorization clears cached token for a later deliberate attempt',async()=>{
  let refreshes=0;
  const send=createGmailRecoveryDelivery(env(),async url=>{
    if(url.includes('oauth2.')){refreshes++;return token();}return new Response('',{status:401});
  });
  await assert.rejects(()=>send(message),/recovery_mail_rejected/);
  await assert.rejects(()=>send(message),/recovery_mail_rejected/);assert.equal(refreshes,2);
});

test('default transport retains runtime fetch receiver and authorization probe never sends mail', async t => {
  const original = globalThis.fetch; let calls = 0;
  t.after(() => { globalThis.fetch = original; });
  globalThis.fetch = function(url) {
    assert.equal(this, globalThis); calls++;
    assert.equal(url, 'https://oauth2.googleapis.com/token'); return Promise.resolve(token());
  };
  const send = createGmailRecoveryDelivery(env());
  assert.deepEqual(await send.checkAuthorization(), { authorized: true });
  assert.equal(calls, 1);
});

test('redirects are returned and rejected without forwarding credentials or sending mail', async () => {
 let calls=0;
 const send=createGmailRecoveryDelivery(env(),async(url,init)=>{
   calls++; assert.equal(init.redirect,'manual');
   return new Response(null,{status:302,headers:{Location:'https://other.example/'}});
 });
 await assert.rejects(()=>send(message),/recovery_mail_authorization_failed/);
 assert.equal(calls,1);
});
