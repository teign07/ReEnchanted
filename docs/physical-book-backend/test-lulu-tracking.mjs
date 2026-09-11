import test from 'node:test';
import assert from 'node:assert/strict';
import { luluTracking } from './lulu-tracking.mjs';
test('multiple parcels survive receipt normalization without PII', () => {
 const result = luluTracking({ shipping_address: 'PRIVATE', line_items: [
 { tracking_id: 'A', carrier_name: 'UPS', tracking_urls: ['https://example.com/a'] },
 { tracking_id: 'B', tracking_urls: ['https://example.com/b'] }] });
 assert.equal(result.shipments.length, 2);
 assert.equal(result.shipments[0].carrierName, 'UPS');
 assert.equal(JSON.stringify(result).includes('PRIVATE'), false);
 assert.deepEqual(luluTracking(result), result);
});
test('status messages support string and array URLs', () => {
 for (const tracking_urls of ['https://example.com/a', ['https://example.com/a']]) {
 const result = luluTracking({ line_item_statuses: [{ messages: { tracking_urls, tracking_id: 'ABC' } }] });
 assert.equal(result.trackingURL, 'https://example.com/a');
 assert.equal(result.shipments[0].trackingID, 'ABC');
 }
});
test('unsafe links rejected, duplicate parcels collapsed, legacy retained', () => {
 const item = { tracking_urls: ['javascript:alert(1)', 'https://user:pass@example.com', 'https://example.com/a'] };
 assert.equal(luluTracking({ line_items: [item, item] }).shipments.length, 1);
 assert.deepEqual(luluTracking({ line_items: [item] }).shipments[0].trackingURLs, ['https://example.com/a']);
 assert.equal(luluTracking({ tracking_url: 'https://example.com/old' }).shipments.length, 1);
 assert.deepEqual(luluTracking({}), { shipments: [], trackingURL: null });
});
