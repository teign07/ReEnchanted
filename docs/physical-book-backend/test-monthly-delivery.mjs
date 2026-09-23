import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { generateKeyPairSync, sign } from 'node:crypto';
import { unstable_dev } from 'wrangler';

const backend = fileURLToPath(new URL('.', import.meta.url));
const repository = resolve(backend, '../..');
const temporary = await mkdtemp(join(tmpdir(), 'monthly-local-delivery-'));
let worker;
try {
  const fixture = join(repository, 'docs/fixtures/monthly-rehearsal');
  const template = JSON.parse(await readFile(join(fixture, 'delivery-manifest.json')));
  const issue = template.issues[0];
  const source = join(temporary, 'sources', issue.id);
  await mkdir(source, { recursive: true });
  await writeFile(join(source, issue.assets[0].fileName), await readFile(join(fixture, issue.assets[0].fileName)));
  // More than twelve files catches accidental reuse of the checkout limiter.
  for (let i = 0; i < 16; i++) {
    const fileName = `rehearsal-${i}.txt`;
    await writeFile(join(source, fileName), `Local rehearsal bytes ${i}`);
    issue.assets.push({ id: `rehearsal-media-${i}`, kind: 'media', scope: 'runtime', fileName, isRequired: true });
  }
  // Schema 2 carries dotted, namespaced media IDs from native packs.
  template.schemaVersion = 2;
  await writeFile(join(source, 'seasonal.txt'), 'Local rehearsal seasonal bytes');
  issue.assets.push({ id: 'count-unbound.seasonal.rehearsal', kind: 'media', scope: 'runtime', fileName: 'seasonal.txt', isRequired: true });
  issue.assets[1].retiresAt = '2027-11-09T00:00:00Z';
  await writeFile(join(temporary, 'template.json'), JSON.stringify(template));
  execFileSync('python3', [join(repository, 'scripts/prepare_monthly_release.py'), join(temporary, 'template.json'),
    '--asset-root', join(temporary, 'sources'), '--origin', 'https://monthly-rehearsal.invalid',
    '--first-release', '--output', join(temporary, 'release')]);
  const payload = await readFile(join(temporary, 'release/manifest.json'));
  const manifest = JSON.parse(payload);
  const { privateKey, publicKey } = generateKeyPairSync('ed25519');
  const envelope = { keyID: 'local-rehearsal', payload: payload.toString('base64'),
    signature: sign(null, payload, privateKey).toString('base64') };
  const assets = {};
  for (const asset of manifest.issues[0].assets) {
    assets[`assets/${asset.id}`] = (await readFile(join(temporary, 'release/assets', asset.id))).toString('base64');
  }
  worker = await unstable_dev(join(backend, 'tests/monthly-delivery-probe.mjs'), {
    config: join(backend, 'tests/monthly-delivery-probe.toml'), local: true, persist: false,
    port: 0, inspectorPort: 0, logLevel: 'error',
    experimental: { disableExperimentalWarning: true, watch: false, disableDevRegistry: true }
  });
  let clock = '2027-11-08T12:00:00Z';
  const fetch = (path, { token, reader, membership, body, openShelf } = {}) => worker.fetch(path, {
    method: body ? 'POST' : 'GET',
    headers: { 'X-Rehearsal-Clock': clock, ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(reader ? { 'X-Rehearsal-Reader': reader } : {}), ...(membership ? { 'X-Rehearsal-Membership': membership } : {}),
      ...(openShelf ? { 'X-Rehearsal-Open-Shelf': 'true' } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {})
  });
  assert.equal((await fetch('/seed', { body: { envelope, assets,
    publicKey: publicKey.export({ format: 'der', type: 'spki' }).subarray(-32).toString('base64') } })).status, 200);
  assert.equal((await fetch('/monthly-issues/manifest')).status, 401);
  const proof = { signedTransactions: [], membershipID: 'sub_rehearsal' };
  assert.equal((await fetch('/monthly-issues/session', { reader: 'stranger', body: proof })).status, 403);
  assert.equal((await fetch('/monthly-issues/session', { membership: 'expired', body: proof })).status, 403);
  const session = await fetch('/monthly-issues/session', { body: proof });
  assert.equal(session.status, 200);
  let { token } = await session.json();
  assert.deepEqual(await (await fetch('/monthly-issues/manifest', { token })).json(), envelope);
  for (const asset of manifest.issues[0].assets) {
    const response = await fetch(`/monthly-issues/assets/${asset.id}`, { token });
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('cache-control'), 'private, no-store');
    assert.deepEqual(Buffer.from(await response.arrayBuffer()), Buffer.from(assets[`assets/${asset.id}`], 'base64'));
  }
  assert.equal((await fetch('/monthly-issues/assets/unlisted', { token })).status, 404);
  assert.equal((await fetch('/monthly-issues/manifest', { token, reader: 'stranger' })).status, 401);
  // With the free shelf open, an unpaid installation reads it, bound to itself.
  const open = await fetch('/monthly-issues/session', { reader: 'stranger', body: { signedTransactions: [] }, openShelf: true });
  assert.equal(open.status, 200);
  const { token: openToken } = await open.json();
  assert.equal((await fetch('/monthly-issues/manifest', { token: openToken, reader: 'stranger' })).status, 200);
  assert.equal((await fetch('/monthly-issues/manifest', { token: openToken })).status, 401);
  clock = '2027-11-08T12:11:00Z';
  assert.equal((await fetch('/monthly-issues/manifest', { token })).status, 401);
  ({ token } = await (await fetch('/monthly-issues/session', { body: proof })).json());
  assert.equal((await fetch('/monthly-issues/manifest', { token })).status, 200);
  clock = '2027-11-09T00:00:00Z';
  ({ token } = await (await fetch('/monthly-issues/session', { body: proof })).json());
  assert.equal((await fetch('/monthly-issues/assets/rehearsal-media-0', { token })).status, 404);
  assert.equal((await fetch('/monthly-issues/assets/rehearsal-media-1', { token })).status, 200);
  clock = issue.residueEndsAt;
  ({ token } = await (await fetch('/monthly-issues/session', { body: proof })).json());
  assert.equal((await fetch(`/monthly-issues/assets/${issue.assets[0].id}`, { token })).status, 404);
  console.log('PASS: publisher -> signed manifest -> workerd/KV/R2 -> 18 exact downloads (schema 2), open shelf, ownership, lapse, token expiry/renewal, and retirement. Billing fixtures only.');
} finally {
  if (worker) await worker.stop();
  await rm(temporary, { recursive: true, force: true });
}
