# Public Margins backend

This Cloudflare Worker is the narrow public bridge between ReEnchanted and the
community section on `reenchanted.app`. It is not an account system and it
never receives a reader's Book.

## Privacy contract

- Reading Public Margins and offering something to Public Margins are separate
  opt-ins in the app. Both default off.
- Every outgoing contribution gets a final, exact-text confirmation. There is
  no background upload and no blanket archive permission.
- The request contains a random request ID, public event/kind fields, and only
  the sentence or choice the reader confirmed. It contains no device ID,
  account, Book page ID, archive, location, health, Calendar, contacts, photos,
  Belief, or local-brain data.
- Text is encrypted at rest with AES-256-GCM. Fixed choices auto-approve after
  strict poll/option validation. Sentences auto-approve only after obvious
  contact-detail checks and a fail-closed Llama Guard safety classification.
- A random deletion token is returned once. Only its SHA-256 hash is stored.
- Anonymous contributions are counted as contributions, never as people; the
  service intentionally has no stable identity with which to count people.
- Infrastructure may transiently process an IP address to deliver the HTTPS
  request, but this Worker does not put it in D1, logs, or a profile.

## Endpoints

- `GET /health`
- `GET /v1/community/snapshot`
- `GET /v1/broadcasts`
- `POST /v1/contributions`
- `DELETE /v1/contributions/:id` with `X-Deletion-Token`
- `GET /v1/admin/submissions` with an admin bearer token (legacy diagnostics)
- `POST /v1/admin/submissions/:id/moderate` with `{ "status": "approved" }` (legacy recovery)
- `POST /v1/admin/refresh-x` (dormant unless `X_IMPORT_ENABLED = "true"`)

## Provisioning

```sh
npm install
npx wrangler d1 create reenchanted-public-margins
# Put the returned database_id in wrangler.toml.
npx wrangler d1 execute reenchanted-public-margins --remote --file schema.sql
npx wrangler secret put PUBLIC_MARGINS_ENCRYPTION_KEY
npx wrangler secret put PUBLIC_MARGINS_ADMIN_TOKEN
npx wrangler secret put X_CONSUMER_KEY
npx wrangler secret put X_CONSUMER_SECRET
npx wrangler secret put X_ACCESS_TOKEN
npx wrangler secret put X_ACCESS_TOKEN_SECRET
npm test
npm run deploy
```

Generate the encryption key with a password manager or 32 cryptographically
random bytes encoded as base64. Keep all six secrets in Worker secrets, never
in the app, website, Git repository, or `wrangler.toml`.

After deployment, route `community-api.reenchanted.app` to the Worker and leave
`PUBLIC_SITE_ORIGIN` restricted to `https://reenchanted.app`. The scheduled
trigger still performs community-retention housekeeping, but X import is
intentionally disabled in production. While disabled, the refresh endpoint does
not contact X, and public snapshots return empty compatibility arrays for
`broadcasts` and `creatorPosts`, even if old cache rows exist.

The dormant adapter remains in source so a future product decision can restore
it deliberately. Doing so requires changing `X_IMPORT_ENABLED` to `"true"`,
reviewing the creator shelf and costs again, and redeploying. Outbound posts from
`@Enchantifyink` are a separate marketing operation; this Worker does not
publish to X.

The normal path has no human moderation queue. Controlled poll choices are
validated against the rotating poll catalog. Free sentences pass contact-detail
checks and Cloudflare Workers AI's Llama Guard model. Classification fails
closed: an unavailable or unsafe verdict is rejected, never published. The
admin endpoints remain only for diagnostics and exceptional recovery.

## Quiet choice rotation

The snapshot contains one deterministic daily poll from a five-question shelf:

- Where did wonder catch you today?
- What did a Page leave you wanting to do?
- What kind of thing did you keep today?
- Which doorway feels alive right now?
- What changed by one degree today?

Each question has five fixed, mission-aligned answers. The app fetches the same
poll shown by the website, previews the exact selected answer, and requires its
own confirmation before submitting. Tallies are anonymous contribution counts.

## Dormant reviewed creator shelf

The former `Elsewhere, Someone Noticed` X shelf remains checked into source
control for reversibility, but is not fetched, returned, or curated while the
production flag is off:

- `@notrobwalker` — practical everyday attention, from the author of *The Art
  of Noticing*.
- `@themarginalian` — science, philosophy, art, and the search for meaning.
- `@atlasobscura` — hidden places and overlooked histories.
- `@NASAEarth` — our ordinary home seen at planetary scale.
- `@OnBeing` — inner life, moral imagination, and life together.

These are imported only through the official X API, not scraped. The app shows
the exact post, display name, handle, timestamp, and a `View on X` link. The Book
may respond around that card, but it must never rewrite a creator's post or make
the creator appear to endorse ReEnchanted. Review this list periodically for
account ownership, activity, quality, and fit before adding anyone else.
