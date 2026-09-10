// Operator inspection, holds and verified refund closure. Never creates refunds, cancels Lulu jobs, or resubmits.
import assert from 'node:assert/strict';
import { readFileSync, statSync } from 'node:fs';

const args = process.argv.slice(2);
const allowLive = args.at(-1) === '--allow-live';
if (allowLive) args.pop();
const [action, kind, id, season] = args;
const valid = ['inspect', 'hold', 'close-refunded'].includes(action) && (
  (kind === 'gift' && args.length === 3 && /^pi_[A-Za-z0-9_]+$/.test(id || '')) ||
  (kind === 'membership' && args.length === 4 && /^sub_[A-Za-z0-9_]+$/.test(id || '') && /^\d{4}-S(0[1-9]|1[0-2])$/.test(season || ''))
);
if (!valid) {
  console.error('Usage: PHYSICAL_BOOK_ADMIN_TOKEN_FILE=/private/path node reconcile-parcel.mjs inspect|hold|close-refunded gift PAYMENT_INTENT_ID [--allow-live]\n   or: ... inspect|hold|close-refunded membership SUBSCRIPTION_ID YYYY-SMM [--allow-live]');
  process.exit(2);
}
const tokenFile = process.env.PHYSICAL_BOOK_ADMIN_TOKEN_FILE;
assert.ok(tokenFile, 'Set PHYSICAL_BOOK_ADMIN_TOKEN_FILE to the private operator credential file.');
assert.equal(statSync(tokenFile).mode & 0o077, 0, 'The credential file must be readable only by its owner (chmod 600).');
const token = readFileSync(tokenFile, 'utf8').trim();
assert.ok(token.length >= 16, 'Invalid operator credential file');
const origin = 'https://reenchanted-physical-books.snow-potions.workers.dev';
const health = await fetch(origin + '/health', { redirect: 'error', signal: AbortSignal.timeout(30000) });
assert.equal(health.status, 200);
const info = await health.json();
assert.equal(info.checks.checkoutEnvironmentAligned, true, 'The configured provider environments disagree.');
assert.ok(info.checks.checkoutMode === 'test' || (info.checks.checkoutMode === 'live' && allowLive), 'Live support requires --allow-live.');
const path = kind === 'gift' ? `gifts/${id}` : `memberships/${id}/${season}`;
const response = await fetch(`${origin}/admin/parcels/${path}${action === 'inspect' ? '' : '/' + action}`, {
  method: action === 'inspect' ? 'GET' : 'POST', redirect: 'error', signal: AbortSignal.timeout(45000),
  headers: { Authorization: 'Bearer ' + token },
});
const body = await response.json();
if (!response.ok) {
  console.error(JSON.stringify({ status: response.status, error: body.error, message: body.message }));
  process.exitCode = 1;
} else console.log(JSON.stringify(body, null, 2));
