import { expectedStripeLivemode } from './checkout-mode.mjs';
import { acceptedBoundYearPriceIDs } from './bound-year-prices.mjs';
import { MembershipOwnershipError } from './membership-ownership.mjs';
const deny = () => { throw new MembershipOwnershipError(403, 'membership_recovery_unavailable'); };
// Reads only. Email ownership is proved by redemption, never by the request.
export async function verifiedRecoveryContact(env, membershipID, readSubscription, readCustomer) {
  const subscription = await readSubscription(membershipID);
  const metadata = subscription?.metadata;
  const prices = acceptedBoundYearPriceIDs(env, metadata?.reenchanted_cadence);
  if (subscription?.id !== membershipID || !prices.size
      || subscription.livemode !== expectedStripeLivemode(env)
      || metadata?.reenchanted_physical_fulfillment !== 'accepted'
      || (metadata.reenchanted_gift != null && metadata.reenchanted_gift !== 'false')
      || !subscription.items?.data?.some(item => prices.has(item.price?.id))
      || typeof subscription.customer !== 'string' || !/^cus_[A-Za-z0-9]+$/.test(subscription.customer)) deny();
  const customer = await readCustomer(subscription.customer);
  if (customer?.id !== subscription.customer || customer.deleted
      || customer.livemode !== subscription.livemode
      || typeof customer.email !== 'string' || customer.email.length > 254
      || !/^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$/.test(customer.email)) deny();
  // Recovery restores ownership only, including access to managing a cancelled
  // membership. Payment/entitlement checks remain independently authoritative.
  return customer.email;
}
