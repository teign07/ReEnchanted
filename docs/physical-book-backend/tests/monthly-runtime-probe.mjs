// Local workerd probe only. Not the deployable Worker's entry point.
import '../monthly-issues.mjs';
export default {
  async fetch() {
    const { SignedDataVerifier, Environment } = await import('@apple/app-store-server-library');
    const verifier = new SignedDataVerifier([], true, Environment.SANDBOX, 'com.openclaw.enchantify.insidecover');
    try { await verifier.verifyAndDecodeTransaction('unsigned'); }
    catch { return Response.json({ libraryLoadedInRequest: true, unsignedProofRejected: true }); }
    return new Response('Unsigned proof was accepted', { status: 500 });
  }
};
