// Test entry point only: never imported by the deployed Worker. All storage is
// local, billing responses are fixtures, and the clock is controlled by the test.
import { issueMonthlySession, recordMonthlyMembershipOwner, serveMonthlyContent } from '../monthly-issues.mjs';
const origin = 'https://monthly-rehearsal.invalid';
let publicKey;
export default {
  async fetch(request, bindings) {
    const path = new URL(request.url).pathname;
    const now = Date.parse(request.headers.get('X-Rehearsal-Clock'));
    const env = { ...bindings, CHECKOUT_MODE: 'test',
      MONTHLY_ISSUE_SESSION_SECRET: 'isolated-local-test-session-secret-no-production-use',
      MONTHLY_ISSUE_MANIFEST_PUBLIC_KEY: publicKey,
      STRIPE_BOUND_YEAR_MONTHLY_PRICE: 'price_rehearsal' };
    try {
      if (path === '/seed') {
        const data = await request.json();
        publicKey = data.publicKey;
        await env.MONTHLY_ISSUE_FILES.put('manifest.envelope.json', JSON.stringify(data.envelope));
        for (const [key, bytes] of Object.entries(data.assets)) {
          await env.MONTHLY_ISSUE_FILES.put(key, Uint8Array.from(atob(bytes), c => c.charCodeAt(0)));
        }
        await recordMonthlyMembershipOwner(env, 'sub_rehearsal', 'reader-a');
        return Response.json({ seeded: Object.keys(data.assets).length });
      }
      const reader = request.headers.get('X-Rehearsal-Reader') ?? 'reader-a';
      if (path === '/monthly-issues/session') {
        const body = await request.json();
        const session = await issueMonthlySession(body, env, reader, async () => ({
          status: request.headers.get('X-Rehearsal-Membership') === 'expired' ? 'canceled' : 'active',
          current_period_end: (now + 3600_000) / 1000,
          latest_invoice: { status: 'paid', paid: true, amount_paid: 1000,
            payment_intent: { status: 'succeeded', latest_charge: {
              paid: true, amount: 1000, amount_refunded: 0, refunded: false, disputed: false } } },
          metadata: { reenchanted_physical_fulfillment: 'accepted' },
          items: { data: [{ price: { id: 'price_rehearsal' } }] }
        }), now);
        return Response.json(session);
      }
      // Local HTTP transport wraps the exact origin that the prepared manifest
      // names. This is not an app transport override or production auth bypass.
      const routed = new Request(origin + path, { headers: request.headers });
      return await serveMonthlyContent(routed, env, reader, path, now);
    } catch (error) {
      return Response.json({ error: error.code ?? error.message }, { status: error.status ?? 500 });
    }
  }
};
