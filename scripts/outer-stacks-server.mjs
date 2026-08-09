#!/usr/bin/env node

import { createServer } from "node:http";
import { randomBytes, randomUUID } from "node:crypto";
import { readFile, rename, stat, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const DEFAULT_PORT = Number(process.env.OUTER_STACKS_PORT || 50124);
const DEFAULT_HOST = process.env.OUTER_STACKS_HOST || "127.0.0.1";
const DEFAULT_STATIC_ROOT = path.resolve(process.cwd(), "LandingPage");
const DEFAULT_STATE_PATH = process.env.OUTER_STACKS_STATE_PATH
  || "/private/tmp/reenchanted-outer-stacks-state.json";

const WORLD = Object.freeze({ width: 2200, height: 1400 });
const BASIN = Object.freeze({ x: 1110, y: 690, radius: 126 });
const PLAYER_TIMEOUT_MS = 22_000;
const ALLOWED_GESTURES = new Set(["bow", "beckon", "call", "sit", "curl", "offer", "refuse", "hide"]);
const WORD_CATALOG = Object.freeze([
  { text: "WAIT", temperament: "heavy" },
  { text: "AGAIN", temperament: "springy" },
  { text: "FOLLOW", temperament: "restless" },
  { text: "HOME", temperament: "settling" },
  { text: "NOT", temperament: "sharp" },
  { text: "YET", temperament: "shy" },
  { text: "HERE", temperament: "rooted" },
  { text: "LOOK", temperament: "bright" },
  { text: "HUSH", temperament: "soft" },
  { text: "TOGETHER", temperament: "warm" },
]);
const GLYPH_PARTS = ["⌁", "⌇", "◌", "⋮", "∴", "⌑", "◇", "∵", "≀", "⊹", "◜", "◝"];
const SPAWNS = [
  [570, 780], [740, 470], [950, 1040], [1280, 1040],
  [1510, 770], [1420, 430], [1040, 330], [760, 950],
];

const MIME = Object.freeze({
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".webp": "image/webp",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".m4a": "audio/mp4",
  ".mp3": "audio/mpeg",
  ".woff2": "font/woff2",
});

function clamp(value, minimum, maximum) {
  return Math.min(maximum, Math.max(minimum, Number.isFinite(value) ? value : minimum));
}

function cleanNumber(value, fallback = 0) {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
}

function stableHash(value) {
  let hash = 2166136261;
  for (const character of value) {
    hash ^= character.codePointAt(0);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function glyphFor(id) {
  const seed = stableHash(id);
  return [0, 1, 2].map((offset) => GLYPH_PARTS[(seed >>> (offset * 5)) % GLYPH_PARTS.length]).join("");
}

function publicPlayer(player) {
  return {
    id: player.id,
    glyph: player.glyph,
    x: player.x,
    y: player.y,
    vx: player.vx,
    vy: player.vy,
    facing: player.facing,
    pose: player.pose,
    gesture: player.gesture,
    gestureUntil: player.gestureUntil,
    carriedWord: player.carriedWord,
    joinedAt: player.joinedAt,
  };
}

function freshWord(index, nonce = randomUUID()) {
  const spec = WORD_CATALOG[index % WORD_CATALOG.length];
  const angle = (index / WORD_CATALOG.length) * Math.PI * 2 + 0.37;
  const radius = 290 + (index % 3) * 130;
  return {
    id: `word-${nonce}`,
    text: spec.text,
    temperament: spec.temperament,
    x: Math.round(BASIN.x + Math.cos(angle) * radius),
    y: Math.round(BASIN.y + Math.sin(angle) * radius * 0.72),
    phase: (stableHash(nonce) % 628) / 100,
  };
}

function initialWords() {
  return WORD_CATALOG.map((_, index) => freshWord(index, `seed-${index}`));
}

export class ClearingState {
  constructor(persisted = {}) {
    this.players = new Map();
    this.streams = new Map();
    this.words = initialWords();
    this.world = {
      offerings: Math.max(0, Number(persisted.offerings) || 0),
      chases: Math.max(0, Number(persisted.chases) || 0),
      acceptedWords: Array.isArray(persisted.acceptedWords)
        ? persisted.acceptedWords.filter((value) => typeof value === "string").slice(-24)
        : [],
      rememberedPath: Array.isArray(persisted.rememberedPath)
        ? persisted.rememberedPath.filter((point) => Number.isFinite(point?.x) && Number.isFinite(point?.y)).slice(-48)
        : [],
      memoryLine: typeof persisted.memoryLine === "string" && persisted.memoryLine.length <= 240
        ? persisted.memoryLine
        : "The clearing has not decided what sort of place you are yet.",
      revision: Math.max(0, Number(persisted.revision) || 0),
    };
    this.pairChase = new Map();
  }

  join(candidate = {}) {
    const candidateID = typeof candidate.playerId === "string" ? candidate.playerId : "";
    const candidateToken = typeof candidate.token === "string" ? candidate.token : "";
    const existing = candidateID ? this.players.get(candidateID) : null;
    if (existing && candidateToken && candidateToken === existing.token) {
      existing.lastSeen = Date.now();
      return { player: existing, reconnected: true };
    }

    const id = randomUUID();
    const token = randomBytes(24).toString("base64url");
    const spawn = SPAWNS[this.players.size % SPAWNS.length];
    const player = {
      id,
      token,
      glyph: glyphFor(id),
      x: spawn[0],
      y: spawn[1],
      vx: 0,
      vy: 0,
      facing: 1,
      pose: "idle",
      gesture: null,
      gestureUntil: 0,
      carriedWord: null,
      joinedAt: Date.now(),
      lastSeen: Date.now(),
    };
    this.players.set(id, player);
    return { player, reconnected: false };
  }

  authenticate(playerId, token) {
    const player = this.players.get(playerId);
    if (!player || !token || token !== player.token) return null;
    player.lastSeen = Date.now();
    return player;
  }

  snapshot(now = Date.now()) {
    return {
      now,
      worldBounds: WORLD,
      basin: BASIN,
      players: Array.from(this.players.values(), publicPlayer),
      words: this.words,
      world: this.world,
    };
  }

  apply(player, action, now = Date.now()) {
    if (!action || typeof action.type !== "string") return { ok: false, reason: "bad-action" };
    player.lastSeen = now;

    switch (action.type) {
      case "move": {
        player.x = clamp(cleanNumber(action.x, player.x), 80, WORLD.width - 80);
        player.y = clamp(cleanNumber(action.y, player.y), 110, WORLD.height - 90);
        player.vx = clamp(cleanNumber(action.vx), -520, 520);
        player.vy = clamp(cleanNumber(action.vy), -520, 520);
        player.facing = cleanNumber(action.facing, player.facing) < 0 ? -1 : 1;
        player.pose = ["idle", "walk", "run", "skid", "crouch", "sleep", "offer"].includes(action.pose)
          ? action.pose
          : "idle";
        return { ok: true };
      }
      case "gesture": {
        if (!ALLOWED_GESTURES.has(action.gesture)) return { ok: false, reason: "bad-gesture" };
        player.gesture = action.gesture;
        player.gestureUntil = now + (action.gesture === "curl" ? 12_000 : 3_600);
        return { ok: true };
      }
      case "pickup": {
        if (player.carriedWord) return { ok: false, reason: "hands-full" };
        const index = this.words.findIndex((word) => word.id === action.wordId);
        if (index < 0) return { ok: false, reason: "word-gone" };
        const word = this.words[index];
        if (Math.hypot(word.x - player.x, word.y - player.y) > 112) {
          return { ok: false, reason: "word-too-far" };
        }
        player.carriedWord = { text: word.text, temperament: word.temperament };
        this.words.splice(index, 1);
        return { ok: true, word: player.carriedWord };
      }
      case "drop": {
        if (!player.carriedWord) return { ok: false, reason: "empty" };
        const x = clamp(cleanNumber(action.x, player.x), player.x - 150, player.x + 150);
        const y = clamp(cleanNumber(action.y, player.y + 54), player.y - 150, player.y + 150);
        const word = {
          id: `word-${randomUUID()}`,
          text: player.carriedWord.text,
          temperament: player.carriedWord.temperament,
          x: clamp(x, 70, WORLD.width - 70),
          y: clamp(y, 90, WORLD.height - 70),
          phase: (stableHash(randomUUID()) % 628) / 100,
        };
        player.carriedWord = null;
        player.gesture = "offer";
        player.gestureUntil = now + 2_600;

        if (Math.hypot(word.x - BASIN.x, word.y - BASIN.y) <= BASIN.radius) {
          this.world.offerings += 1;
          this.world.acceptedWords.push(word.text);
          this.world.acceptedWords = this.world.acceptedWords.slice(-24);
          this.world.revision += 1;
          this.world.memoryLine = this.memoryLineForOffering(word.text);
          return { ok: true, offered: true, word };
        }

        this.words.push(word);
        return { ok: true, offered: false, word };
      }
      case "heartbeat":
        return { ok: true };
      default:
        return { ok: false, reason: "unknown-action" };
    }
  }

  memoryLineForOffering(word) {
    const count = this.world.offerings;
    if (count === 1) return `The basin has accepted ${word}. It is pretending this means nothing.`;
    if (count === 2) return `${word} sank beside the first offering. Something underneath has begun sorting them.`;
    if (count === 3) return `Three words were given freely. The roots have stopped barring the little door.`;
    const recent = this.world.acceptedWords.slice(-3).join(", ");
    return `The clearing keeps ${recent}. It has begun using them when nobody is here.`;
  }

  observeChases(now = Date.now()) {
    const players = Array.from(this.players.values());
    for (let leftIndex = 0; leftIndex < players.length; leftIndex += 1) {
      for (let rightIndex = leftIndex + 1; rightIndex < players.length; rightIndex += 1) {
        const left = players[leftIndex];
        const right = players[rightIndex];
        const key = [left.id, right.id].sort().join(":");
        const speedLeft = Math.hypot(left.vx, left.vy);
        const speedRight = Math.hypot(right.vx, right.vy);
        const close = Math.hypot(left.x - right.x, left.y - right.y) < 155;
        const lively = speedLeft > 185 && speedRight > 185;
        const record = this.pairChase.get(key) || { beganAt: 0, lastCountedAt: 0 };

        if (close && lively) {
          if (!record.beganAt) record.beganAt = now;
          if (now - record.beganAt > 1_800 && now - record.lastCountedAt > 8_000) {
            record.lastCountedAt = now;
            this.world.chases += 1;
            this.world.revision += 1;
            this.world.rememberedPath.push({
              x: Math.round((left.x + right.x) / 2),
              y: Math.round((left.y + right.y) / 2),
            });
            this.world.rememberedPath = this.world.rememberedPath.slice(-48);
            this.world.memoryLine = this.world.chases === 1
              ? "Two Paperwings made a game of pursuit. The floor has kept the turn they both nearly missed."
              : `The clearing has witnessed ${this.world.chases} chases. It is beginning to grow a favorite route.`;
          }
        } else {
          record.beganAt = 0;
        }
        this.pairChase.set(key, record);
      }
    }
  }

  removeStalePlayers(now = Date.now()) {
    let changed = false;
    for (const [id, player] of this.players.entries()) {
      if (now - player.lastSeen <= PLAYER_TIMEOUT_MS) continue;
      if (player.carriedWord) {
        this.words.push({
          id: `word-${randomUUID()}`,
          ...player.carriedWord,
          x: player.x,
          y: player.y,
          phase: 0,
        });
      }
      this.players.delete(id);
      this.streams.delete(id);
      changed = true;
    }
    return changed;
  }

  replenishWords() {
    if (this.words.length >= 7) return false;
    const index = (this.world.offerings + this.words.length + this.world.chases) % WORD_CATALOG.length;
    this.words.push(freshWord(index));
    return true;
  }

  persistedWorld() {
    return {
      offerings: this.world.offerings,
      chases: this.world.chases,
      acceptedWords: this.world.acceptedWords,
      rememberedPath: this.world.rememberedPath,
      memoryLine: this.world.memoryLine,
      revision: this.world.revision,
    };
  }
}

async function readJSONBody(request) {
  const chunks = [];
  let length = 0;
  for await (const chunk of request) {
    length += chunk.length;
    if (length > 32_768) throw new Error("request-too-large");
    chunks.push(chunk);
  }
  if (!chunks.length) return {};
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

function sendJSON(response, statusCode, value) {
  response.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "X-Frame-Options": "DENY",
  });
  response.end(JSON.stringify(value));
}

function apiCredentials(request, requestBody = {}) {
  const authorization = request.headers.authorization || "";
  return {
    playerId: request.headers["x-player-id"] || requestBody.playerId || "",
    token: authorization.replace(/^Bearer\s+/i, "") || requestBody.token || "",
  };
}

function assertSameOrigin(request) {
  const origin = request.headers.origin;
  if (!origin) return;
  const expected = `http://${request.headers.host || "localhost"}`;
  const expectedSecure = `https://${request.headers.host || "localhost"}`;
  if (origin !== expected && origin !== expectedSecure) throw new Error("origin-not-allowed");
}

async function loadPersistedState(statePath) {
  try {
    return JSON.parse(await readFile(statePath, "utf8"));
  } catch {
    return {};
  }
}

function safeStaticPath(staticRoot, pathname) {
  let relative = decodeURIComponent(pathname);
  if (relative === "/") relative = "/index.html";
  if (relative.endsWith("/")) relative += "index.html";
  const resolved = path.resolve(staticRoot, `.${relative}`);
  return resolved.startsWith(`${staticRoot}${path.sep}`) ? resolved : null;
}

async function serveStatic(staticRoot, pathname, response) {
  const filePath = safeStaticPath(staticRoot, pathname);
  if (!filePath) {
    response.writeHead(403);
    response.end("The shelf refuses that route.");
    return;
  }
  try {
    const info = await stat(filePath);
    if (!info.isFile()) throw new Error("not-file");
    response.writeHead(200, {
      "Content-Type": MIME[path.extname(filePath).toLowerCase()] || "application/octet-stream",
      "Cache-Control": filePath.includes(`${path.sep}outer-stacks${path.sep}`) ? "no-cache" : "public, max-age=600",
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "no-referrer",
      "X-Frame-Options": "DENY",
      "Content-Security-Policy": "default-src 'self'; base-uri 'none'; frame-ancestors 'none'; object-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; media-src 'self'; connect-src 'self'",
      "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
    });
    response.end(await readFile(filePath));
  } catch {
    response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    response.end("That page has moved deeper into the Stacks.");
  }
}

export async function createOuterStacksServer({
  staticRoot = DEFAULT_STATIC_ROOT,
  statePath = DEFAULT_STATE_PATH,
  broadcastIntervalMs = 100,
} = {}) {
  const clearing = new ClearingState(await loadPersistedState(statePath));
  const rateWindows = new Map();
  let lastPersistedRevision = clearing.world.revision;
  let persistenceChain = Promise.resolve();

  function persistIfNeeded() {
    if (clearing.world.revision === lastPersistedRevision) return;
    lastPersistedRevision = clearing.world.revision;
    const document = JSON.stringify(clearing.persistedWorld(), null, 2);
    const temporary = `${statePath}.next`;
    persistenceChain = persistenceChain
      .then(() => writeFile(temporary, document))
      .then(() => rename(temporary, statePath))
      .catch((error) => console.error("The clearing could not keep its memory:", error.message));
  }

  function broadcast() {
    const payload = `event: clearing\ndata: ${JSON.stringify(clearing.snapshot())}\n\n`;
    for (const [playerId, response] of clearing.streams.entries()) {
      if (!clearing.players.has(playerId) || response.destroyed) {
        clearing.streams.delete(playerId);
        continue;
      }
      response.write(payload);
    }
  }

  function requireRateLimit(key, limit, windowMs) {
    const now = Date.now();
    const recent = (rateWindows.get(key) || []).filter((timestamp) => now - timestamp < windowMs);
    if (recent.length >= limit) throw new Error("too-many-requests");
    recent.push(now);
    rateWindows.set(key, recent);
    if (rateWindows.size > 2_000) {
      for (const [candidate, timestamps] of rateWindows) {
        if (!timestamps.some((timestamp) => now - timestamp < 60_000)) rateWindows.delete(candidate);
      }
    }
  }

  const server = createServer(async (request, response) => {
    const requestURL = new URL(request.url || "/", `http://${request.headers.host || "localhost"}`);
    const pathname = requestURL.pathname;

    try {
      if (request.method === "GET" && pathname === "/outer-stacks/api/health") {
        sendJSON(response, 200, { ok: true, players: clearing.players.size, revision: clearing.world.revision });
        return;
      }

      if (request.method === "POST" && pathname === "/outer-stacks/api/join") {
        assertSameOrigin(request);
        requireRateLimit(`join:${request.socket.remoteAddress || "unknown"}`, 12, 60_000);
        const body = await readJSONBody(request);
        const result = clearing.join(body);
        sendJSON(response, 200, {
          playerId: result.player.id,
          token: result.player.token,
          glyph: result.player.glyph,
          reconnected: result.reconnected,
          snapshot: clearing.snapshot(),
        });
        broadcast();
        return;
      }

      if (request.method === "GET" && pathname === "/outer-stacks/api/stream") {
        const credentials = apiCredentials(request);
        requireRateLimit(`stream:${credentials.playerId || request.socket.remoteAddress || "unknown"}`, 12, 60_000);
        const player = clearing.authenticate(credentials.playerId, credentials.token);
        if (!player) {
          sendJSON(response, 401, { ok: false, reason: "unknown-paperwing" });
          return;
        }
        response.writeHead(200, {
          "Content-Type": "text/event-stream; charset=utf-8",
          "Cache-Control": "no-store",
          Connection: "keep-alive",
          "X-Accel-Buffering": "no",
        });
        response.write(`event: clearing\ndata: ${JSON.stringify(clearing.snapshot())}\n\n`);
        clearing.streams.get(player.id)?.end();
        clearing.streams.set(player.id, response);
        request.on("close", () => {
          if (clearing.streams.get(player.id) === response) clearing.streams.delete(player.id);
        });
        return;
      }

      if (request.method === "POST" && pathname === "/outer-stacks/api/action") {
        assertSameOrigin(request);
        const body = await readJSONBody(request);
        const credentials = apiCredentials(request, body);
        const player = clearing.authenticate(credentials.playerId, credentials.token);
        if (!player) {
          sendJSON(response, 401, { ok: false, reason: "unknown-paperwing" });
          return;
        }
        requireRateLimit(`action:${player.id}`, 120, 10_000);
        const result = clearing.apply(player, body.action);
        sendJSON(response, result.ok ? 200 : 409, result);
        persistIfNeeded();
        broadcast();
        return;
      }

      if (request.method !== "GET" && request.method !== "HEAD") {
        response.writeHead(405, { Allow: "GET, HEAD, POST" });
        response.end();
        return;
      }

      await serveStatic(staticRoot, pathname, response);
    } catch (error) {
      sendJSON(response, error.message === "request-too-large" ? 413 : 400, {
        ok: false,
        reason: error.message || "the-stacks-refused",
      });
    }
  });

  const interval = setInterval(() => {
    const now = Date.now();
    for (const player of clearing.players.values()) {
      if (player.gestureUntil && player.gestureUntil < now) {
        player.gesture = null;
        player.gestureUntil = 0;
      }
    }
    clearing.observeChases(now);
    clearing.removeStalePlayers(now);
    clearing.replenishWords();
    persistIfNeeded();
    broadcast();
  }, broadcastIntervalMs);
  interval.unref();

  server.on("close", () => clearInterval(interval));
  return { server, clearing, flushPersistence: () => persistenceChain };
}

async function main() {
  const { server } = await createOuterStacksServer();
  server.listen(DEFAULT_PORT, DEFAULT_HOST, () => {
    console.log(`The shared Outer Stacks are awake at http://${DEFAULT_HOST}:${DEFAULT_PORT}/outer-stacks/`);
    console.log(`Clearing memory: ${DEFAULT_STATE_PATH}`);
  });
}

const isDirectRun = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isDirectRun) main();
