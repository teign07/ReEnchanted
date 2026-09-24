// Serves a prepared, signed monthly release through the real Worker code
// (local workerd, local R2/KV, fixture billing) at every lifecycle edge of
// every issue, and checks what a reader's installation would receive.
//
//   node rehearse-release.mjs RELEASE_DIR PUBLIC_KEY_BASE64
//
// Called by `scripts/monthly_issue.py rehearse`. Nothing leaves the machine.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { unstable_dev } from 'wrangler';

const [releaseDir, publicKey] = process.argv.slice(2);
if (!releaseDir || !publicKey) {
  console.error('usage: node rehearse-release.mjs RELEASE_DIR PUBLIC_KEY_BASE64');
  process.exit(64);
}
const backend = fileURLToPath(new URL('.', import.meta.url));
const manifest = JSON.parse(await readFile(`${releaseDir}/manifest.json`));
const envelope = JSON.parse(await readFile(`${releaseDir}/manifest.envelope.json`));
const origin = `https://${manifest.allowedAssetHosts[0]}`;
const assets = {};
for (const issue of manifest.issues) {
  for (const asset of issue.assets) {
    assets[`assets/${asset.id}`] = (await readFile(`${releaseDir}/assets/${asset.id}`)).toString('base64');
  }
}

const hour = 3_600_000;
const at = (value, offset = hour) => new Date(Date.parse(value) + offset).toISOString();
const worker = await unstable_dev(`${backend}tests/monthly-delivery-probe.mjs`, {
  config: `${backend}tests/monthly-delivery-probe.toml`, local: true, persist: false,
  port: 0, inspectorPort: 0, logLevel: 'error',
  experimental: { disableExperimentalWarning: true, watch: false, disableDevRegistry: true }
});
let failures = 0;
try {
  const call = (path, clock, { token, body } = {}) => worker.fetch(path, {
    method: body ? 'POST' : 'GET',
    headers: { 'X-Rehearsal-Clock': clock, 'X-Rehearsal-Open-Shelf': 'true', 'X-Rehearsal-Origin': origin,
      ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {})
  });
  const seeded = await call('/seed', manifest.generatedAt, { body: { envelope, assets, publicKey } });
  assert.equal(seeded.status, 200, await seeded.text());

  for (const issue of manifest.issues) {
    const edges = [
      ['foreshadow', at(issue.foreshadowStartsAt)],
      ['live', at(issue.liveStartsAt, (Date.parse(issue.liveEndsAt) - Date.parse(issue.liveStartsAt)) / 2)],
      ['residue', at(issue.liveEndsAt)],
      ['after residue', at(issue.residueEndsAt)],
      ['casebook', at(issue.casebookAvailableAt)]
    ];
    console.log(`\n${issue.id} (${issue.title})`);
    for (const [name, clock] of edges) {
      const session = await call('/monthly-issues/session', clock, { body: { signedTransactions: [] } });
      assert.equal(session.status, 200, `${name}: session ${session.status}`);
      const { token } = await session.json();
      const listed = await call('/monthly-issues/manifest', clock, { token });
      assert.equal(listed.status, 200, `${name}: manifest ${listed.status} ${await listed.text()}`);
      let runtime = 0, casebook = 0;
      for (const asset of issue.assets) {
        const response = await call(`/monthly-issues/assets/${asset.id}`, clock, { token });
        if (response.status === 404) continue;
        assert.equal(response.status, 200, `${name}: ${asset.id} ${response.status}`);
        assert.deepEqual(Buffer.from(await response.arrayBuffer()),
          Buffer.from(assets[`assets/${asset.id}`], 'base64'), `${name}: ${asset.id} bytes differ`);
        if (asset.scope === 'casebook') casebook++; else runtime++;
      }
      const runtimeTotal = issue.assets.filter(asset => asset.scope === 'runtime').length;
      const casebookTotal = issue.assets.length - runtimeTotal;
      const problems = [];
      if (name === 'live' && runtime !== runtimeTotal) problems.push(`only ${runtime}/${runtimeTotal} runtime files while live`);
      if (Date.parse(clock) >= Date.parse(issue.residueEndsAt) && runtime > 0) problems.push('runtime files after residue ended');
      if (Date.parse(clock) < Date.parse(issue.casebookAvailableAt) && casebook > 0) problems.push('casebook before publication');
      if (name === 'casebook' && casebook !== casebookTotal) problems.push(`casebook missing (${casebook}/${casebookTotal})`);
      failures += problems.length;
      console.log(`  ${name.padEnd(13)} ${clock}  runtime ${String(runtime).padStart(3)}/${runtimeTotal}  `
        + `casebook ${casebook}/${casebookTotal}  ${problems.length ? 'FAIL: ' + problems.join('; ') : 'ok'}`);
    }
  }
} finally {
  await worker.stop();
}
if (failures) {
  console.error(`\n${failures} delivery problem(s).`);
  process.exit(1);
}
console.log('\nPASS: every file byte-identical; windows, retirement and casebook timing as manifested.');
