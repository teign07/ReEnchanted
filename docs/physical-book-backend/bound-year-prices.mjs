// New purchases use the current price. Explicit legacy IDs retain paid access
// and fulfillment for memberships opened before a price change.
export function acceptedBoundYearPriceIDs(env, cadence) {
  const key = cadence === 'annual' ? 'STRIPE_BOUND_YEAR_ANNUAL_PRICE'
    : cadence === 'monthly' ? 'STRIPE_BOUND_YEAR_MONTHLY_PRICE' : null;
  const current = key && env[key];
  if (!current) return new Set();
  const legacy = String(env[`${key}_LEGACY`] || '').split(',').map(id => id.trim());
  return new Set([current, ...legacy].filter(id => /^price_[A-Za-z0-9_]+$/.test(id)));
}
