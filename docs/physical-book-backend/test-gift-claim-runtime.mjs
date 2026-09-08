import assert from 'node:assert/strict';
import { unstable_dev } from 'wrangler';
const worker = await unstable_dev('tests/gift-claim-runtime-probe.mjs', {
  config: 'tests/gift-claim-runtime-probe.toml', local: true, persist: false,
  port: 0, inspectorPort: 0, logLevel: 'error',
  experimental: { disableExperimentalWarning: true, watch: false, disableDevRegistry: true },
});
try {
  const response = await worker.fetch();
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    raceStatuses: [409, 500], originalWinnerResumes: true,
    otherReaderRefused: true, claimedGiftCannotDecline: true,
  });
  console.log('Real workerd Durable Object reserves one gift owner through concurrent claims and a failed publication.');
} finally { await worker.stop(); }
