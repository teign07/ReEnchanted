// Local-only probe. Uses the production coordinator with real workerd Durable
// Object storage and a fake gift ledger. Never contacts Stripe or Lulu.
import { PhysicalBookOrderCoordinator } from '../lulu-quote-worker.mjs';

export class GiftClaimProbe extends PhysicalBookOrderCoordinator {
  constructor(state, env) {
    const gift = {
      id: 'gift-probe', kind: 'bookOfRecipient', status: 'readyToClaim',
      claimTokenHash: 'fixture', senderName: 'Sender', recipientName: 'Reader',
      includedPageCount: 200, allowanceCents: 5000, allowanceCurrencyCode: 'USD',
    };
    super(state, { ...env, PHYSICAL_BOOK_ORDERS: {
      async get() { return await state.storage.get('probe-gift') || JSON.stringify(gift); },
      async put(_key, value) {
        if (!await state.storage.get('probe-failed-write')) {
          await state.storage.put('probe-failed-write', true);
          throw new Error('Publication interrupted after durable reservation');
        }
        await state.storage.put('probe-gift', value);
      },
    } });
  }
}

export default {
  async fetch(_request, env) {
    const stub = env.CLAIMS.get(env.CLAIMS.idFromName(crypto.randomUUID()));
    const send = async (installationHash, action = 'claim') => {
      const response = await stub.fetch('https://claims.internal/', {
        method: 'POST', body: JSON.stringify({ fulfillmentKind: 'gift-claim', claimToken: 'fixture', installationHash, action }),
      });
      return { status: response.status, body: await response.json() };
    };
    const race = await Promise.all([send('reader-a'), send('reader-b')]);
    const winner = race[0].status === 500 ? 'reader-a' : 'reader-b';
    const loser = winner === 'reader-a' ? 'reader-b' : 'reader-a';
    const resumed = await send(winner);
    const refused = await send(loser);
    const decline = await send(winner, 'decline');
    return Response.json({
      raceStatuses: race.map(result => result.status).sort(),
      originalWinnerResumes: resumed.status === 200,
      otherReaderRefused: refused.status === 409 && refused.body.error === 'gift_already_claimed',
      claimedGiftCannotDecline: decline.status === 409,
    });
  },
};
