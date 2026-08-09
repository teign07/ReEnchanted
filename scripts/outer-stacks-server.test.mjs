import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { ClearingState, createOuterStacksServer } from "./outer-stacks-server.mjs";

function putWordAtPlayer(clearing, player, index = 0) {
  const word = clearing.words[index];
  word.x = player.x;
  word.y = player.y;
  return word;
}

test("a Paperwing can physically gather a nearby word and offer it to the basin", () => {
  const clearing = new ClearingState();
  const { player } = clearing.join();
  const word = putWordAtPlayer(clearing, player);

  const gathered = clearing.apply(player, { type: "pickup", wordId: word.id }, 1_000);
  assert.equal(gathered.ok, true);
  assert.equal(player.carriedWord.text, word.text);
  assert.equal(clearing.words.some((candidate) => candidate.id === word.id), false);

  player.x = 1_110;
  player.y = 690;
  const offered = clearing.apply(player, { type: "drop", x: 1_110, y: 690 }, 2_000);
  assert.deepEqual({ ok: offered.ok, offered: offered.offered }, { ok: true, offered: true });
  assert.equal(player.carriedWord, null);
  assert.equal(clearing.world.offerings, 1);
  assert.deepEqual(clearing.world.acceptedWords, [word.text]);
  assert.match(clearing.world.memoryLine, new RegExp(word.text));
});

test("words cannot be taken from across the clearing", () => {
  const clearing = new ClearingState();
  const { player } = clearing.join();
  const word = clearing.words[0];
  word.x = player.x + 400;
  word.y = player.y + 400;

  assert.deepEqual(
    clearing.apply(player, { type: "pickup", wordId: word.id }),
    { ok: false, reason: "word-too-far" },
  );
});

test("a sustained close run is remembered as a chase", () => {
  const clearing = new ClearingState();
  const first = clearing.join().player;
  const second = clearing.join().player;
  first.x = 900;
  first.y = 700;
  second.x = 980;
  second.y = 700;
  first.vx = 260;
  second.vx = 245;

  clearing.observeChases(10_000);
  clearing.observeChases(12_000);

  assert.equal(clearing.world.chases, 1);
  assert.equal(clearing.world.rememberedPath.length, 1);
  assert.match(clearing.world.memoryLine, /pursuit/i);
});

test("the live server joins two distinct Paperwings and persists a world offering", async (context) => {
  const directory = await mkdtemp(path.join(tmpdir(), "outer-stacks-test-"));
  const statePath = path.join(directory, "memory.json");
  const { server, clearing, flushPersistence } = await createOuterStacksServer({
    statePath,
    broadcastIntervalMs: 20,
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  context.after(() => new Promise((resolve) => server.close(resolve)));
  const address = server.address();
  const base = `http://127.0.0.1:${address.port}`;

  const join = async () => {
    const response = await fetch(`${base}/outer-stacks/api/join`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "{}",
    });
    assert.equal(response.status, 200);
    return response.json();
  };
  const first = await join();
  const second = await join();
  assert.notEqual(first.playerId, second.playerId);
  assert.equal(clearing.players.size, 2);

  const player = clearing.players.get(first.playerId);
  const word = putWordAtPlayer(clearing, player);
  const act = async (action) => {
    const response = await fetch(`${base}/outer-stacks/api/action`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ playerId: first.playerId, token: first.token, action }),
    });
    assert.equal(response.status, 200);
    return response.json();
  };
  await act({ type: "pickup", wordId: word.id });
  await act({ type: "move", x: 1_110, y: 690, vx: 0, vy: 0, pose: "idle" });
  const result = await act({ type: "drop", x: 1_110, y: 690 });
  assert.equal(result.offered, true);

  await new Promise((resolve) => setTimeout(resolve, 45));
  await flushPersistence();
  const memory = JSON.parse(await readFile(statePath, "utf8"));
  assert.equal(memory.offerings, 1);
  assert.deepEqual(memory.acceptedWords, [word.text]);
});
