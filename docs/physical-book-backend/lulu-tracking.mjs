// Whitelist shipment fields: never retain Lulu's address-bearing full response.
const list = value => Array.isArray(value) ? value : [];
const label = value => typeof value === 'string' && value.trim() ? value.trim().slice(0, 256) : null;
export function safeTrackingURL(value) {
  if (typeof value !== 'string' || value.length > 4096) return null;
  try {
    const url = new URL(value);
    return ['https:', 'http:'].includes(url.protocol) && url.hostname && !url.username && !url.password ? url.href : null;
  } catch { return null; }
}
export function luluTracking(job) {
  const shipments = [], seen = new Set();
  const items = [...list(job.line_items), ...list(job.line_item_statuses), ...list(job.status?.line_item_statuses), ...list(job.shipments)];
  for (const item of items) {
    if (!item || typeof item !== "object") continue;
    const messages = item.status?.messages ?? item.messages ?? {};
    const raw = item.trackingURLs ?? item.tracking_urls ?? messages.tracking_urls;
    const trackingURLs = [...new Set((typeof raw === 'string' ? [raw] : list(raw)).map(safeTrackingURL).filter(Boolean))];
    const trackingID = label(item.trackingID ?? item.tracking_id ?? messages.tracking_id);
    const carrierName = label(item.carrierName ?? item.carrier_name ?? messages.carrier_name);
    if (!trackingURLs.length && !trackingID) continue;
    const shipment = { trackingID, carrierName, trackingURLs };
    const key = JSON.stringify(shipment);
    if (!seen.has(key)) { seen.add(key); shipments.push(shipment); }
  }
  const legacy = safeTrackingURL(job.tracking_url ?? job.trackingURL);
  if (!shipments.length && legacy) shipments.push({ trackingID: null, carrierName: null, trackingURLs: [legacy] });
  return { shipments, trackingURL: shipments.flatMap(item => item.trackingURLs)[0] ?? legacy };
}

// Provider refreshes may mention only the parcel that changed. Omission is not
// a retraction: preserve the other parcels and enrich matching receipts in place.
export function mergeLuluTracking(saved, update) {
  const shipments = luluTracking(saved).shipments;
  for (const incoming of luluTracking(update).shipments) {
    const match = shipments.find(existing => {
      if (existing.trackingID && incoming.trackingID) {
        return existing.trackingID === incoming.trackingID
          && (!existing.carrierName || !incoming.carrierName
            || existing.carrierName.toLowerCase() === incoming.carrierName.toLowerCase());
      }
      return existing.trackingURLs.some(url => incoming.trackingURLs.includes(url));
    });
    if (!match) { shipments.push(incoming); continue; }
    match.trackingID = incoming.trackingID ?? match.trackingID;
    match.carrierName = incoming.carrierName ?? match.carrierName;
    match.trackingURLs = [...new Set([...incoming.trackingURLs, ...match.trackingURLs])];
  }
  return { shipments, trackingURL: shipments.flatMap(item => item.trackingURLs)[0] ?? null };
}
