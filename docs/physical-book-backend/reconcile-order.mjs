// Protected operator helper. It never creates a payment, refund, or print job.
// Issue any approved refund in Stripe only after the hold has succeeded.
import assert from 'node:assert/strict';
import {readFileSync,statSync} from 'node:fs';

const [action,quoteID,...rest]=process.argv.slice(2);
if(!['inspect','hold','close-refunded'].includes(action)||!/^[A-Za-z0-9_-]+$/.test(quoteID||'')||rest.some(x=>x!=='--allow-live')){
  console.error('Usage: PHYSICAL_BOOK_ADMIN_TOKEN_FILE=/private/path node reconcile-order.mjs inspect|hold|close-refunded QUOTE_ID [--allow-live]');
  process.exit(2);
}
const tokenFile=process.env.PHYSICAL_BOOK_ADMIN_TOKEN_FILE;
assert.ok(tokenFile,'Set PHYSICAL_BOOK_ADMIN_TOKEN_FILE to the private operator credential file.');
assert.equal(statSync(tokenFile).mode & 0o077,0,'The credential file must be readable only by its owner (chmod 600).');
const token=readFileSync(tokenFile,'utf8').trim();assert.ok(token.length>=16,'Invalid operator credential file');
const origin='https://reenchanted-physical-books.snow-potions.workers.dev';
const health=await fetch(origin+'/health',{redirect:'error',signal:AbortSignal.timeout(30000)});
assert.equal(health.status,200);const info=await health.json();
assert.equal(info.checks.checkoutEnvironmentAligned,true,'The configured provider environments disagree.');
assert.ok(info.checks.checkoutMode==='test'||rest.includes('--allow-live'),'Live reconciliation requires --allow-live.');
const path=`/admin/reconciliation/${quoteID}${action==='inspect'?'':'/'+action}`;
const response=await fetch(origin+path,{method:action==='inspect'?'GET':'POST',redirect:'error',signal:AbortSignal.timeout(45000),headers:{Authorization:'Bearer '+token}});
const body=await response.json();
if(!response.ok){console.error(JSON.stringify({status:response.status,error:body.error,message:body.message}));process.exitCode=1;}
else console.log(JSON.stringify(body,null,2));
