import { Buffer } from 'node:buffer';
const SENDER = 'snow.potions@gmail.com';
export class RecoveryMailError extends Error {
  constructor(code) { super(code); this.code = code; }
}
const fail = code => { throw new RecoveryMailError(code); };
// Construct only the fixed recovery template. The trusted issuer supplies the
// verified recipient and proof; this is never a general-purpose public mail API.
export function recoveryMessage({ recipient, membershipID, secret }) {
  if (typeof recipient !== 'string' || recipient.length > 254
      || !/^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$/.test(recipient)
      || !/^sub_[A-Za-z0-9]{1,128}$/.test(membershipID || '')
      || !/^[A-Za-z0-9_-]{43}$/.test(secret || '')
      || Buffer.from(secret, 'base64url').toString('base64url') !== secret)
    fail('invalid_recovery_message');
  // A pasteable code avoids inventing an unimplemented link/deep-link handler.
  const code = `${membershipID}.${secret}`;
  const body = [
    'Someone asked to move your ReEnchanted Bound Year to another device.', '',
    'If that was you, return to the device where you requested recovery and paste this code:', '',
    code, '', 'This code expires in 15 minutes. Do not share it.', '',
    'If you did not request this, ignore this email. Your membership has not moved.', '',
    'Need a hand? Reply to this email.', '', 'ReEnchanted',
  ].join('\r\n');
  const encoded = Buffer.from(body).toString('base64').match(/.{1,76}/g).join('\r\n');
  return Buffer.from([
    `From: ReEnchanted <${SENDER}>`, `To: ${recipient}`, 'Reply-To: help@reenchanted.app',
    'Subject: Recover your ReEnchanted Bound Year', 'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=UTF-8', 'Content-Transfer-Encoding: base64', '', encoded,
  ].join('\r\n')).toString('base64url');
}
export function createGmailRecoveryDelivery(env, fetcher = (...args) => globalThis.fetch(...args), now = Date.now) {
  let cached, refreshing;
  async function accessToken() {
    if (cached && cached.expiresAt > now() + 60000) return cached.token;
    if (refreshing) return refreshing;
    refreshing = (async () => {
      let response, diagnostic = "request_setup";
      try {
        const timeoutSignal = AbortSignal.timeout(15000);
        diagnostic = "transport";
        response = await fetcher('https://oauth2.googleapis.com/token', {
          method: 'POST', redirect: 'manual', signal: timeoutSignal,
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ grant_type: 'refresh_token', client_id: env.GMAIL_CLIENT_ID,
            client_secret: env.GMAIL_CLIENT_SECRET, refresh_token: env.GMAIL_REFRESH_TOKEN }),
        });
        diagnostic = `http_${response.status}`;
        if (!response.ok) throw new RecoveryMailError('recovery_mail_authorization_failed');
        const data = await response.json();
        diagnostic = `schema_token_${typeof data.access_token}_type_${typeof data.token_type}_expiry_${typeof data.expires_in}`;
        if (typeof data.access_token !== 'string' || !data.access_token || data.token_type?.toLowerCase() !== 'bearer'
            || !Number.isFinite(data.expires_in) || data.expires_in <= 60) fail('recovery_mail_authorization_failed');
        cached = { token: data.access_token, expiresAt: now() + Math.min(data.expires_in, 3600) * 1000 };
        return cached.token;
      } catch (cause) { const error = new RecoveryMailError('recovery_mail_authorization_failed'); error.diagnostic = diagnostic + ':' + (['TypeError', 'AbortError', 'TimeoutError'].includes(cause?.name) ? cause.name : 'provider_failure'); throw error; }
    })();
    try { return await refreshing; } finally { refreshing = undefined; }
  }
  const deliver = async message => {
    if (env.GMAIL_RECOVERY_DELIVERY_ENABLED !== 'true') fail('recovery_mail_disabled');
    if (![env.GMAIL_CLIENT_ID, env.GMAIL_CLIENT_SECRET, env.GMAIL_REFRESH_TOKEN].every(v => typeof v === 'string' && v.trim()))
      fail('recovery_mail_not_configured');
    const raw = recoveryMessage(message);
    const token = await accessToken();
    // Never retry sends automatically: timeout or malformed success may mean the
    // message was already accepted. The issuer must retain an uncertain outcome.
    let response;
    try {
      response = await fetcher(`https://gmail.googleapis.com/gmail/v1/users/${encodeURIComponent(SENDER)}/messages/send`, {
        method: 'POST', redirect: 'manual', signal: AbortSignal.timeout(15000),
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ raw }),
      });
    } catch { fail('recovery_mail_delivery_uncertain'); }
    if (!response.ok) {
      if (response.status === 401) cached = undefined;
      fail(response.status >= 500 ? 'recovery_mail_delivery_uncertain' : 'recovery_mail_rejected');
    }
    let data; try { data = await response.json(); } catch { fail('recovery_mail_delivery_uncertain'); }
    if (typeof data.id !== 'string' || !/^[A-Za-z0-9_-]{1,256}$/.test(data.id)) fail('recovery_mail_delivery_uncertain');
    return { messageID: data.id, status: 'accepted' };
  };
  deliver.checkAuthorization = async () => {
    if (![env.GMAIL_CLIENT_ID, env.GMAIL_CLIENT_SECRET, env.GMAIL_REFRESH_TOKEN].every(v => typeof v === 'string' && v.trim()))
      fail('recovery_mail_not_configured');
    await accessToken();
    return { authorized: true };
  };
  return deliver;
}
