const contributionKinds = new Set(["souvenir", "spark", "choice", "detail"]);
const statuses = new Set(["approved", "rejected"]);
const maximumTextCharacters = 220;
const maximumBodyBytes = 8192;
export const publicChoicePolls = [
  {
    id: "where-wonder-caught",
    question: "Where did wonder catch you today?",
    options: [
      { id: "out-in-the-world", label: "Out in the world" },
      { id: "inside-an-ordinary-moment", label: "Inside an ordinary moment" },
      { id: "in-someone-else", label: "In someone else" },
      { id: "in-a-story", label: "In a story" },
      { id: "not-yet", label: "It hasn't — yet" }
    ]
  },
  {
    id: "what-the-page-awakened",
    question: "What did a Page leave you wanting to do?",
    options: [
      { id: "look-again", label: "Look again" },
      { id: "go-outside", label: "Go outside" },
      { id: "make-something", label: "Make something" },
      { id: "tell-someone", label: "Tell someone" },
      { id: "let-it-rest", label: "Let it rest" }
    ]
  },
  {
    id: "what-you-kept",
    question: "What kind of thing did you keep today?",
    options: [
      { id: "a-detail", label: "A detail" },
      { id: "a-feeling", label: "A feeling" },
      { id: "a-question", label: "A question" },
      { id: "a-possibility", label: "A possibility" },
      { id: "a-sentence", label: "A sentence" }
    ]
  },
  {
    id: "alive-doorway",
    question: "Which doorway feels alive right now?",
    options: [
      { id: "notice", label: "Notice" },
      { id: "imagine", label: "Imagine" },
      { id: "connect", label: "Connect" },
      { id: "play", label: "Play" },
      { id: "rest", label: "Rest" }
    ]
  },
  {
    id: "one-degree-change",
    question: "What changed by one degree today?",
    options: [
      { id: "the-room", label: "The room" },
      { id: "my-attention", label: "My attention" },
      { id: "my-mood", label: "My mood" },
      { id: "the-story", label: "The story" },
      { id: "nothing-yet", label: "Nothing — yet" }
    ]
  }
];
export const reviewedCreatorShelf = [
  { slug: "art-of-noticing", username: "notrobwalker", lens: "everyday attention" },
  { slug: "the-marginalian", username: "themarginalian", lens: "meaning through science, philosophy, and art" },
  { slug: "atlas-obscura", username: "atlasobscura", lens: "hidden places and overlooked histories" },
  { slug: "nasa-earth", username: "NASAEarth", lens: "our ordinary planet seen at an uncommon scale" },
  { slug: "on-being", username: "OnBeing", lens: "moral imagination and inner life" }
];
const encoder = new TextEncoder();
const decoder = new TextDecoder();

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return corsPreflight(request, env);

    try {
      const url = new URL(request.url);
      if (request.method === "GET" && url.pathname === "/health") {
        return json({ ok: true });
      }
      if (request.method === "GET" && url.pathname === "/v1/community/snapshot") {
        return publicJSON(await buildSnapshot(env), request, env);
      }
      if (request.method === "GET" && url.pathname === "/v1/broadcasts") {
        const snapshot = await buildSnapshot(env);
        return publicJSON({ generatedAt: snapshot.generatedAt, broadcasts: snapshot.broadcasts }, request, env);
      }
      if (request.method === "POST" && url.pathname === "/v1/contributions") {
        assertAllowedWriteOrigin(request, env);
        return publicJSON(await acceptContribution(request, env), request, env, 202);
      }

      const deletionMatch = url.pathname.match(/^\/v1\/contributions\/([^/]+)$/);
      if (request.method === "DELETE" && deletionMatch) {
        assertAllowedWriteOrigin(request, env);
        return publicJSON(await deleteContribution(decodeURIComponent(deletionMatch[1]), request, env), request, env);
      }

      if (request.method === "GET" && url.pathname === "/v1/admin/submissions") {
        requireAdmin(request, env);
        return json({ submissions: await pendingSubmissions(env) });
      }

      const moderationMatch = url.pathname.match(/^\/v1\/admin\/submissions\/([^/]+)\/moderate$/);
      if (request.method === "POST" && moderationMatch) {
        requireAdmin(request, env);
        return json(await moderateSubmission(decodeURIComponent(moderationMatch[1]), request, env));
      }
      if (request.method === "POST" && url.pathname === "/v1/admin/refresh-x") {
        requireAdmin(request, env);
        return json(await refreshXBroadcasts(env));
      }

      return json({ error: "not_found" }, 404);
    } catch (error) {
      const status = Number(error?.status) || 500;
      if (status >= 500) console.error("Public Margins request failed", error?.message || error);
      return json({ error: status >= 500 ? "server_error" : error.message }, status);
    }
  },

  async scheduled(_controller, env, ctx) {
    ctx.waitUntil(Promise.allSettled([
      refreshXBroadcasts(env),
      purgeExpiredContributions(env.PUBLIC_MARGINS_DB)
    ]));
  }
};

export function validateContribution(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) badRequest("invalid_submission");
  const requestID = safeIdentifier(value.requestID, "requestID");
  const eventID = safeIdentifier(value.eventID, "eventID");
  if (!contributionKinds.has(value.kind)) badRequest("invalid_kind");
  if (value.consent?.publicDisplay !== true || value.consent?.moderation !== true) {
    badRequest("explicit_public_consent_required");
  }
  const confirmedAt = parseTimestamp(value.confirmedAt, "confirmedAt");
  const text = value.text == null ? null : normalizePublicText(value.text);
  let category = optionalIdentifier(value.category, "category");
  const choiceID = optionalIdentifier(value.choiceID, "choiceID");
  if (value.kind === "choice") {
    const poll = publicChoicePolls.find(item => item.id === eventID);
    if (!poll) badRequest("unknown_choice_poll");
    if (!choiceID || !poll.options.some(option => option.id === choiceID)) {
      badRequest("unknown_choice");
    }
    category = "quiet-choice";
  }
  if (value.kind !== "choice" && !text) badRequest("text_required");

  return { requestID, eventID, kind: value.kind, text, category, choiceID, confirmedAt };
}

export function normalizePublicText(value) {
  if (typeof value !== "string") badRequest("invalid_text");
  const text = value.replace(/\s+/g, " ").trim();
  if (!text || [...text].length > maximumTextCharacters) badRequest("invalid_text_length");
  if (/:\/\/|www\.|(?:x|twitter)\.com\//i.test(text)) badRequest("links_not_allowed");
  return text;
}

export async function encryptJSON(value, base64Key, cryptoObject = crypto) {
  const key = await importEncryptionKey(base64Key, cryptoObject);
  const iv = cryptoObject.getRandomValues(new Uint8Array(12));
  const encrypted = await cryptoObject.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    encoder.encode(JSON.stringify(value))
  );
  return { ciphertext: bytesToBase64(new Uint8Array(encrypted)), iv: bytesToBase64(iv) };
}

export async function decryptJSON(ciphertext, iv, base64Key, cryptoObject = crypto) {
  const key = await importEncryptionKey(base64Key, cryptoObject);
  const decrypted = await cryptoObject.subtle.decrypt(
    { name: "AES-GCM", iv: base64ToBytes(iv) },
    key,
    base64ToBytes(ciphertext)
  );
  return JSON.parse(decoder.decode(decrypted));
}

export function rotateByDay(items, day = new Date().toISOString().slice(0, 10), limit = 6) {
  return [...items]
    .sort((left, right) => stableScore(`${day}:${left.id}`) - stableScore(`${day}:${right.id}`))
    .slice(0, limit);
}

export function activeChoicePoll(day = new Date().toISOString().slice(0, 10)) {
  return publicChoicePolls[stableScore(`public-choice:${day}`) % publicChoicePolls.length];
}

export async function automaticModeration(contribution, env) {
  if (contribution.kind === "choice") {
    return { status: "approved", reason: "controlled_choice" };
  }
  if (contribution.kind !== "souvenir" || !contribution.text) {
    return { status: "rejected", reason: "unsupported_public_kind" };
  }

  // Llama Guard is a safety classifier, not a privacy detector. Reject obvious
  // contact details before inference so a sentence cannot accidentally become
  // a public directory entry even when its subject matter is otherwise safe.
  if (containsObviousPrivateContact(contribution.text)) {
    return { status: "rejected", reason: "private_contact_detail" };
  }
  if (!env?.AI?.run) {
    return { status: "rejected", reason: "moderation_unavailable" };
  }

  try {
    const result = await env.AI.run("@cf/meta/llama-guard-3-8b", {
      messages: [{ role: "user", content: contribution.text }],
      temperature: 0,
      max_tokens: 24
    });
    const verdict = String(result?.response ?? result?.result?.response ?? "").trim();
    return /^safe\b/i.test(verdict)
      ? { status: "approved", reason: "safety_model_safe" }
      : { status: "rejected", reason: "safety_model_unsafe" };
  } catch {
    // Public-by-default failure would violate the feature's privacy posture.
    return { status: "rejected", reason: "moderation_unavailable" };
  }
}

function containsObviousPrivateContact(text) {
  const email = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i;
  const phone = /(?:^|\D)(?:\+?1[\s.-]?)?(?:\(?\d{3}\)?[\s.-]?)\d{3}[\s.-]?\d{4}(?:\D|$)/;
  const socialHandle = /(^|\s)@[A-Z0-9_]{2,30}\b/i;
  return email.test(text) || phone.test(text) || socialHandle.test(text);
}

async function acceptContribution(request, env) {
  const contentLength = Number(request.headers.get("content-length") || 0);
  if (contentLength > maximumBodyBytes) throw httpError(413, "submission_too_large");
  const rawText = await request.text();
  if (encoder.encode(rawText).byteLength > maximumBodyBytes) throw httpError(413, "submission_too_large");
  let parsed;
  try { parsed = JSON.parse(rawText); } catch { badRequest("invalid_json"); }
  const contribution = validateContribution(parsed);
  const id = crypto.randomUUID();
  const deletionToken = randomToken();
  const deletionTokenHash = await sha256(deletionToken);
  const createdAt = new Date().toISOString();
  const moderation = await automaticModeration(contribution, env);
  const payload = contribution.text ? await encryptJSON({ text: contribution.text }, required(env, "PUBLIC_MARGINS_ENCRYPTION_KEY")) : null;

  try {
    await env.PUBLIC_MARGINS_DB.prepare(`
      INSERT INTO contributions
        (id, request_id, event_id, kind, category, choice_id, encrypted_payload, payload_iv, status, deletion_token_hash, created_at, moderated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).bind(
      id,
      contribution.requestID,
      contribution.eventID,
      contribution.kind,
      contribution.category,
      contribution.choiceID,
      payload?.ciphertext || null,
      payload?.iv || null,
      moderation.status,
      deletionTokenHash,
      createdAt,
      createdAt
    ).run();
  } catch (error) {
    if (String(error?.message || error).includes("UNIQUE")) throw httpError(409, "request_already_received");
    throw error;
  }

  return { id, status: moderation.status, deletionToken };
}

async function deleteContribution(id, request, env) {
  const token = request.headers.get("x-deletion-token") || "";
  if (!token) throw httpError(401, "deletion_token_required");
  const tokenHash = await sha256(token);
  const result = await env.PUBLIC_MARGINS_DB.prepare(
    "DELETE FROM contributions WHERE id = ? AND deletion_token_hash = ?"
  ).bind(id, tokenHash).run();
  if (!result.meta?.changes) throw httpError(404, "contribution_not_found");
  return { deleted: true };
}

async function pendingSubmissions(env) {
  const result = await env.PUBLIC_MARGINS_DB.prepare(`
    SELECT id, event_id, kind, category, choice_id, encrypted_payload, payload_iv, created_at
    FROM contributions WHERE status = 'pending' ORDER BY created_at ASC LIMIT 100
  `).all();
  return Promise.all((result.results || []).map(async row => ({
    id: row.id,
    eventID: row.event_id,
    kind: row.kind,
    category: row.category,
    choiceID: row.choice_id,
    text: row.encrypted_payload
      ? (await decryptJSON(row.encrypted_payload, row.payload_iv, required(env, "PUBLIC_MARGINS_ENCRYPTION_KEY"))).text
      : null,
    createdAt: row.created_at
  })));
}

async function moderateSubmission(id, request, env) {
  const body = await request.json();
  if (!statuses.has(body?.status)) badRequest("invalid_status");
  const result = await env.PUBLIC_MARGINS_DB.prepare(`
    UPDATE contributions SET status = ?, moderated_at = ? WHERE id = ? AND status = 'pending'
  `).bind(body.status, new Date().toISOString(), id).run();
  if (!result.meta?.changes) throw httpError(404, "pending_submission_not_found");
  return { id, status: body.status };
}

async function buildSnapshot(env) {
  const database = env.PUBLIC_MARGINS_DB;
  const importsX = isXImportEnabled(env);
  const poll = activeChoicePoll();
  const [broadcastRows, creatorRows, souvenirRows, tallyRows, countRow] = await Promise.all([
    importsX ? database.prepare(`
      SELECT post_id, text, author_name, author_username, author_avatar_url, permalink, created_at
      FROM broadcasts ORDER BY created_at DESC LIMIT 8
    `).all() : Promise.resolve({ results: [] }),
    importsX ? database.prepare(`
      SELECT post_id, text, author_name, author_username, author_avatar_url, permalink, created_at
      FROM creator_posts ORDER BY created_at DESC LIMIT 40
    `).all() : Promise.resolve({ results: [] }),
    database.prepare(`
      SELECT id, kind, encrypted_payload, payload_iv, created_at
      FROM contributions
      WHERE status = 'approved' AND encrypted_payload IS NOT NULL
      ORDER BY created_at DESC LIMIT 80
    `).all(),
    database.prepare(`
      SELECT choice_id, COUNT(*) AS tally
      FROM contributions
      WHERE status = 'approved' AND kind = 'choice' AND event_id = ? AND choice_id IS NOT NULL
      GROUP BY choice_id ORDER BY tally DESC LIMIT 12
    `).bind(poll.id).all(),
    database.prepare("SELECT COUNT(*) AS tally FROM contributions WHERE status = 'approved'").first()
  ]);

  const key = required(env, "PUBLIC_MARGINS_ENCRYPTION_KEY");
  const decrypted = [];
  for (const row of souvenirRows.results || []) {
    try {
      const payload = await decryptJSON(row.encrypted_payload, row.payload_iv, key);
      decrypted.push({ id: row.id, text: payload.text, kind: row.kind, createdAt: row.created_at });
    } catch {
      // A malformed row is quarantined from the public response, never leaked.
    }
  }

  const tallyByChoice = new Map((tallyRows.results || []).map(row => [row.choice_id, Number(row.tally || 0)]));
  const tallies = poll.options.map(option => ({
    choiceID: option.id,
    label: option.label,
    count: tallyByChoice.get(option.id) || 0
  }));

  return {
    generatedAt: new Date().toISOString(),
    contributionCount: Number(countRow?.tally || 0),
    broadcasts: (broadcastRows.results || []).map(row => ({
      id: row.post_id,
      text: row.text,
      authorName: row.author_name,
      authorUsername: row.author_username,
      authorAvatarURL: row.author_avatar_url,
      permalink: row.permalink,
      createdAt: row.created_at
    })),
    creatorPosts: rotateByDay((creatorRows.results || []).map(row => ({
      id: row.post_id,
      text: row.text,
      authorName: row.author_name,
      authorUsername: row.author_username,
      authorAvatarURL: row.author_avatar_url,
      permalink: row.permalink,
      createdAt: row.created_at
    })), new Date().toISOString().slice(0, 10), 12),
    souvenirs: rotateByDay(decrypted),
    choicePoll: {
      id: poll.id,
      question: poll.question,
      options: tallies.map(item => ({ id: item.choiceID, label: item.label, count: item.count }))
    },
    tallies
  };
}

async function refreshXBroadcasts(env) {
  if (!isXImportEnabled(env)) {
    return { enabled: false, refreshed: 0, creators: [] };
  }
  const username = (env.X_USERNAME || "Enchantifyink").replace(/^@/, "");
  const account = await resolveXAccount(env, username);

  const postsURL = new URL(`https://api.x.com/2/users/${account.id}/tweets`);
  postsURL.searchParams.set("max_results", "5");
  postsURL.searchParams.set("exclude", "replies,retweets");
  postsURL.searchParams.set("tweet.fields", "created_at");
  const postsResponse = await xFetch(postsURL, env);
  if (!postsResponse.ok) throw new Error(`X post lookup failed: ${postsResponse.status}`);
  const postsPayload = await postsResponse.json();
  const fetchedAt = new Date().toISOString();
  const statements = (postsPayload.data || []).map(post => env.PUBLIC_MARGINS_DB.prepare(`
    INSERT INTO broadcasts
      (post_id, text, author_name, author_username, author_avatar_url, permalink, created_at, fetched_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(post_id) DO UPDATE SET
      text = excluded.text,
      author_name = excluded.author_name,
      author_username = excluded.author_username,
      author_avatar_url = excluded.author_avatar_url,
      permalink = excluded.permalink,
      created_at = excluded.created_at,
      fetched_at = excluded.fetched_at
  `).bind(
    post.id,
    post.text,
    account.name,
    account.username,
    account.profileImageURL,
    `https://x.com/${encodeURIComponent(account.username)}/status/${post.id}`,
    post.created_at,
    fetchedAt
  ));
  if (statements.length) await env.PUBLIC_MARGINS_DB.batch(statements);

  // A successful authoritative refresh removes cached posts the account no
  // longer returns. Failed refreshes leave the last good cache intact.
  const ids = (postsPayload.data || []).map(post => post.id);
  if (ids.length) {
    const placeholders = ids.map(() => "?").join(", ");
    await env.PUBLIC_MARGINS_DB.prepare(
      `DELETE FROM broadcasts WHERE author_username = ? AND post_id NOT IN (${placeholders})`
    ).bind(account.username, ...ids).run();
  }
  const creators = [];
  for (const creator of reviewedCreatorShelf) {
    try {
      creators.push(await refreshReviewedCreator(env, creator));
    } catch (error) {
      console.error(`Reviewed creator refresh failed for ${creator.username}`, error?.message || error);
      creators.push({ username: creator.username, error: "refresh_failed" });
    }
  }
  return { refreshed: statements.length, username: account.username, creators };
}

export function isXImportEnabled(env) {
  return env?.X_IMPORT_ENABLED === "true";
}

async function purgeExpiredContributions(database, now = new Date()) {
  const pendingCutoff = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();
  const approvedCutoff = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000).toISOString();
  return database.prepare(`
    DELETE FROM contributions
    WHERE (status IN ('pending', 'rejected') AND created_at < ?)
       OR (status = 'approved' AND created_at < ?)
  `).bind(pendingCutoff, approvedCutoff).run();
}

async function refreshReviewedCreator(env, creator) {
  const account = await resolveXAccount(env, creator.username);

  const postsURL = new URL(`https://api.x.com/2/users/${account.id}/tweets`);
  postsURL.searchParams.set("max_results", "5");
  postsURL.searchParams.set("exclude", "replies,retweets");
  postsURL.searchParams.set("tweet.fields", "created_at");
  const postsResponse = await xFetch(postsURL, env);
  if (!postsResponse.ok) throw new Error(`X creator posts failed for ${creator.username}: ${postsResponse.status}`);
  const postsPayload = await postsResponse.json();
  const fetchedAt = new Date().toISOString();
  const statements = (postsPayload.data || []).map(post => env.PUBLIC_MARGINS_DB.prepare(`
    INSERT INTO creator_posts
      (post_id, creator_slug, text, author_name, author_username, author_avatar_url, permalink, created_at, fetched_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(post_id) DO UPDATE SET
      creator_slug = excluded.creator_slug,
      text = excluded.text,
      author_name = excluded.author_name,
      author_username = excluded.author_username,
      author_avatar_url = excluded.author_avatar_url,
      permalink = excluded.permalink,
      created_at = excluded.created_at,
      fetched_at = excluded.fetched_at
  `).bind(
    post.id,
    creator.slug,
    post.text,
    account.name,
    account.username,
    account.profileImageURL,
    `https://x.com/${encodeURIComponent(account.username)}/status/${post.id}`,
    post.created_at,
    fetchedAt
  ));
  if (statements.length) await env.PUBLIC_MARGINS_DB.batch(statements);

  const ids = (postsPayload.data || []).map(post => post.id);
  if (ids.length) {
    const placeholders = ids.map(() => "?").join(", ");
    await env.PUBLIC_MARGINS_DB.prepare(
      `DELETE FROM creator_posts WHERE creator_slug = ? AND post_id NOT IN (${placeholders})`
    ).bind(creator.slug, ...ids).run();
  }
  return { username: account.username, refreshed: statements.length };
}

async function resolveXAccount(env, configuredUsername, now = new Date()) {
  const usernameKey = configuredUsername.replace(/^@/, "").toLowerCase();
  const cacheCutoff = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();
  const cached = await env.PUBLIC_MARGINS_DB.prepare(`
    SELECT user_id, username, name, profile_image_url
    FROM x_accounts
    WHERE username_key = ? AND refreshed_at >= ?
  `).bind(usernameKey, cacheCutoff).first();
  if (cached?.user_id) {
    return {
      id: cached.user_id,
      username: cached.username,
      name: cached.name,
      profileImageURL: cached.profile_image_url || null
    };
  }

  const response = await xFetch(
    `https://api.x.com/2/users/by/username/${encodeURIComponent(configuredUsername)}?user.fields=name,username,profile_image_url`,
    env
  );
  if (!response.ok) throw new Error(`X user lookup failed for ${configuredUsername}: ${response.status}`);
  const payload = await response.json();
  if (!payload.data?.id) throw new Error(`X user lookup returned no user for ${configuredUsername}`);
  const refreshedAt = now.toISOString();
  const account = {
    id: payload.data.id,
    username: payload.data.username || configuredUsername,
    name: payload.data.name || configuredUsername,
    profileImageURL: payload.data.profile_image_url || null
  };
  await env.PUBLIC_MARGINS_DB.prepare(`
    INSERT INTO x_accounts
      (username_key, user_id, username, name, profile_image_url, refreshed_at)
    VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT(username_key) DO UPDATE SET
      user_id = excluded.user_id,
      username = excluded.username,
      name = excluded.name,
      profile_image_url = excluded.profile_image_url,
      refreshed_at = excluded.refreshed_at
  `).bind(
    usernameKey,
    account.id,
    account.username,
    account.name,
    account.profileImageURL,
    refreshedAt
  ).run();
  return account;
}

async function xFetch(url, env) {
  const authorization = await oauth1Authorization("GET", url, {
    consumerKey: required(env, "X_CONSUMER_KEY"),
    consumerSecret: required(env, "X_CONSUMER_SECRET"),
    accessToken: required(env, "X_ACCESS_TOKEN"),
    accessTokenSecret: required(env, "X_ACCESS_TOKEN_SECRET")
  });
  return fetch(url, { headers: { authorization } });
}

export async function oauth1Authorization(method, inputURL, credentials, options = {}) {
  const url = new URL(inputURL);
  const cryptoObject = options.cryptoObject || crypto;
  const oauth = {
    oauth_consumer_key: credentials.consumerKey,
    oauth_nonce: options.nonce || cryptoObject.randomUUID().replace(/-/g, ""),
    oauth_signature_method: "HMAC-SHA1",
    oauth_timestamp: String(options.timestamp ?? Math.floor(Date.now() / 1000)),
    oauth_token: credentials.accessToken,
    oauth_version: "1.0"
  };
  const signatureParameters = [...url.searchParams.entries(), ...Object.entries(oauth)]
    .map(([key, value]) => [oauthPercentEncode(key), oauthPercentEncode(value)])
    .sort(([leftKey, leftValue], [rightKey, rightValue]) =>
      leftKey.localeCompare(rightKey) || leftValue.localeCompare(rightValue)
    )
    .map(([key, value]) => `${key}=${value}`)
    .join("&");
  const baseURL = `${url.protocol}//${url.host}${url.pathname}`;
  const signatureBase = [
    String(method).toUpperCase(),
    oauthPercentEncode(baseURL),
    oauthPercentEncode(signatureParameters)
  ].join("&");
  const signingKey = `${oauthPercentEncode(credentials.consumerSecret)}&${oauthPercentEncode(credentials.accessTokenSecret)}`;
  const signingKeyHandle = await cryptoObject.subtle.importKey(
    "raw",
    encoder.encode(signingKey),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"]
  );
  const signature = bytesToBase64(new Uint8Array(await cryptoObject.subtle.sign(
    "HMAC",
    signingKeyHandle,
    encoder.encode(signatureBase)
  )));
  const headerParameters = { ...oauth, oauth_signature: signature };
  return `OAuth ${Object.entries(headerParameters)
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, value]) => `${oauthPercentEncode(key)}="${oauthPercentEncode(value)}"`)
    .join(", ")}`;
}

function oauthPercentEncode(value) {
  return encodeURIComponent(String(value)).replace(/[!'()*]/g, character =>
    `%${character.charCodeAt(0).toString(16).toUpperCase()}`
  );
}

function requireAdmin(request, env) {
  const expected = required(env, "PUBLIC_MARGINS_ADMIN_TOKEN");
  const supplied = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") || "";
  if (!supplied || supplied !== expected) throw httpError(401, "unauthorized");
}

function assertAllowedWriteOrigin(request, env) {
  const origin = request.headers.get("origin");
  if (!origin) return; // Native app requests do not carry a browser Origin.
  if (origin !== (env.PUBLIC_SITE_ORIGIN || "https://reenchanted.app")) {
    throw httpError(403, "origin_not_allowed");
  }
}

function corsPreflight(request, env) {
  const origin = request.headers.get("origin");
  if (origin !== (env.PUBLIC_SITE_ORIGIN || "https://reenchanted.app")) {
    return new Response(null, { status: 403 });
  }
  return new Response(null, { status: 204, headers: corsHeaders(origin) });
}

function publicJSON(value, request, env, status = 200) {
  const origin = request.headers.get("origin");
  const allowed = !origin || origin === (env.PUBLIC_SITE_ORIGIN || "https://reenchanted.app");
  return json(value, status, allowed ? corsHeaders(origin || "*") : {});
}

function corsHeaders(origin) {
  return {
    "access-control-allow-origin": origin,
    "access-control-allow-methods": "GET, POST, DELETE, OPTIONS",
    "access-control-allow-headers": "content-type, x-deletion-token",
    "access-control-max-age": "86400",
    vary: "Origin"
  };
}

function json(value, status = 200, headers = {}) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": status === 200 ? "public, max-age=60" : "no-store",
      "x-content-type-options": "nosniff",
      ...headers
    }
  });
}

function safeIdentifier(value, name) {
  if (typeof value !== "string" || !/^[A-Za-z0-9][A-Za-z0-9._:-]{0,95}$/.test(value)) {
    badRequest(`invalid_${name}`);
  }
  return value;
}

function optionalIdentifier(value, name) {
  return value == null || value === "" ? null : safeIdentifier(value, name);
}

function parseTimestamp(value, name) {
  if (typeof value !== "string" || Number.isNaN(Date.parse(value))) badRequest(`invalid_${name}`);
  return value;
}

function badRequest(message) { throw httpError(400, message); }
function httpError(status, message) { return Object.assign(new Error(message), { status }); }
function required(env, name) {
  const value = env?.[name];
  if (!value) throw new Error(`${name} is not configured`);
  return value;
}
function randomToken() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return bytesToBase64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
async function sha256(value) {
  return bytesToHex(new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(value))));
}
async function importEncryptionKey(base64Key, cryptoObject) {
  const bytes = base64ToBytes(base64Key);
  if (bytes.byteLength !== 32) throw new Error("PUBLIC_MARGINS_ENCRYPTION_KEY must decode to 32 bytes");
  return cryptoObject.subtle.importKey("raw", bytes, "AES-GCM", false, ["encrypt", "decrypt"]);
}
function bytesToBase64(bytes) {
  let binary = "";
  bytes.forEach(byte => { binary += String.fromCharCode(byte); });
  return btoa(binary);
}
function base64ToBytes(value) {
  const binary = atob(value);
  return Uint8Array.from(binary, character => character.charCodeAt(0));
}
function bytesToHex(bytes) { return [...bytes].map(byte => byte.toString(16).padStart(2, "0")).join(""); }
function stableScore(value) {
  let hash = 2166136261;
  for (const character of value) {
    hash ^= character.codePointAt(0);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}
function humanize(value) {
  return String(value || "").replace(/[-_]+/g, " ").replace(/\b\w/g, letter => letter.toUpperCase());
}
