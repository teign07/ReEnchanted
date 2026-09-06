import assert from 'node:assert/strict';
import { unstable_dev } from 'wrangler';
const worker = await unstable_dev('tests/monthly-runtime-probe.mjs', {
  config: 'tests/monthly-runtime-probe.toml', local: true, persist: false,
  port: 0, inspectorPort: 0, logLevel: 'error',
  experimental: { disableExperimentalWarning: true, watch: false, disableDevRegistry: true }
});
try {
  const response = await worker.fetch();
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { libraryLoadedInRequest: true, unsignedProofRejected: true });
  console.log('Apple verifier loaded inside workerd and rejected unsigned proof.');
} finally { await worker.stop(); }
