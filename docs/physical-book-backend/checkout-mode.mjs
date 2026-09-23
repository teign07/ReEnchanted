// The one answer to "which Stripe mode may this Worker accept?". Only an exact
// "live" or "test" names one; any other CHECKOUT_MODE (including "disabled" or
// unset) returns null, which never equals an object's boolean livemode, so
// every payment check fails closed.
export function expectedStripeLivemode(env) {
  const mode = String(env.CHECKOUT_MODE || '').trim().toLowerCase();
  return mode === 'live' ? true : mode === 'test' ? false : null;
}
