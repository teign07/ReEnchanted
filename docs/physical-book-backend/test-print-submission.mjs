import test from "node:test";
import assert from "node:assert/strict";
import { webcrypto } from "node:crypto";
import { PhysicalBookOrderCoordinator } from "./lulu-quote-worker.mjs";

if (!globalThis.crypto) globalThis.crypto = webcrypto;
const env = { LULU_API_BASE_URL: "https://api.sandbox.lulu.com" };
const payload = { external_id: "parcel-test", shipping_address: { street1: "Private street" }, line_items: [] };

function fixture(t) {
  const values = new Map();
  let writesFail = false;
  let receiptWritesFail = false;
  let creates = 0;
  let createResponse;
  const diagnostics = [];
  let searchResult = { count: 0, next: null, results: [] };
  const state = { storage: {
    async get(key) { return values.get(key); },
    async put(key, value) {
      if (writesFail || (receiptWritesFail && value.receipt)) throw new Error("Storage unavailable");
      values.set(key, value);
    },
  } };
  const originalFetch = globalThis.fetch;
  const originalWarn = console.warn;
  console.warn = (...args) => diagnostics.push(args);
  t.after(() => { globalThis.fetch = originalFetch; console.warn = originalWarn; });
  globalThis.fetch = async (_url, init) => {
    if (init.method === "POST") {
      creates += 1;
      if (createResponse) return createResponse();
      return Response.json({ id: "lulu-1", status: { name: "CREATED" }, shipping_address: payload.shipping_address });
    }
    return Response.json(searchResult);
  };
  return {
    values,
    diagnostics,
    restart: () => new PhysicalBookOrderCoordinator(state, env),
    creates: () => creates,
    failWrites: value => { writesFail = value; },
    failReceiptWrites: value => { receiptWritesFail = value; },
    setSearch: value => { searchResult = value; },
    setCreate: value => { createResponse = value; },
  };
}

test("a failed durable attempt write never contacts the printer", async t => {
  const f = fixture(t);
  f.failWrites(true);
  await assert.rejects(f.restart().submitPrintJob("token", payload));
  assert.equal(f.creates(), 0);
  f.failWrites(false);
  assert.equal((await f.restart().submitPrintJob("token", payload)).id, "lulu-1");
  assert.equal(f.creates(), 1);
});

test("a lost durable receipt does not authorize another print after restart", async t => {
  const f = fixture(t);
  f.failReceiptWrites(true);
  await assert.rejects(f.restart().submitPrintJob("token", payload));
  f.failReceiptWrites(false);
  await assert.rejects(f.restart().submitPrintJob("token", payload), { code: "print_submission_uncertain" });
  assert.equal(f.creates(), 1);
  f.setSearch({ count: 1, next: null, results: [{ id: "lulu-1", external_id: payload.external_id }] });
  assert.equal((await f.restart().submitPrintJob("token", payload)).id, "lulu-1");
  assert.equal(f.creates(), 1);
});

test("incomplete search results cannot reconcile an uncertain print", async t => {
  const f = fixture(t);
  f.failReceiptWrites(true);
  await assert.rejects(f.restart().submitPrintJob("token", payload));
  f.failReceiptWrites(false);
  for (const result of [
    { count: 2, next: "https://untrusted.example/next", results: [{ id: "lulu-1", external_id: payload.external_id }] },
    { count: 2, next: null, results: [{ id: "lulu-1", external_id: payload.external_id }] },
    { results: [{ id: "lulu-1", external_id: payload.external_id }] },
  ]) {
    f.setSearch(result);
    await assert.rejects(f.restart().submitPrintJob("token", payload), { code: "print_submission_uncertain" });
  }
  assert.equal(f.creates(), 1);
});

test("a saved submission cannot be repurposed with a new address or files", async t => {
  const f = fixture(t);
  await f.restart().submitPrintJob("token", payload);
  await assert.rejects(f.restart().submitPrintJob("token", { ...payload, shipping_address: { street1: "Changed street" } }),
    { code: "print_submission_changed" });
  assert.equal(f.creates(), 1);
  assert.ok(!JSON.stringify([...f.values]).includes("Private street"));
});

test("provider rejection preserves useful schema fields without private error data or a replacement POST", async t => {
  const f = fixture(t);
  f.setCreate(() => Response.json({
    contact_email: ["Invalid email: private-reader@example.invalid"],
    shipping_address: { street1: ["Private street"] },
    line_items: [{ interior: { source_url: ["https://private.example/capability-token"] } }],
    private_reader_identifier: { contact_email: ["Must not traverse unknown keys"] },
  }, { status: 400 }));
  await assert.rejects(f.restart().submitPrintJob("token", payload), { code: "print_submission_uncertain" });
  const diagnostic = f.values.get("lulu-submission").diagnostic;
  assert.deepEqual(diagnostic, {
    kind: "http_error", httpStatus: 400,
    fields: ["contact_email", "line_items", "line_items[].interior", "line_items[].interior.source_url", "shipping_address", "shipping_address.street1"],
  });
  assert.deepEqual(f.diagnostics, [["lulu_print_submission_uncertain", diagnostic]]);
  const persistedAndLogged = JSON.stringify([[...f.values], f.diagnostics]);
  for (const privateText of ["private-reader", "Private street", "capability-token", "private_reader_identifier", "Must not traverse"]) {
    assert.ok(!persistedAndLogged.includes(privateText));
  }
  await assert.rejects(f.restart().submitPrintJob("token", payload), { code: "print_submission_uncertain" });
  assert.equal(f.creates(), 1);
  f.setSearch({ count: 1, next: null, results: [{ id: "recovered-1", external_id: payload.external_id }] });
  assert.equal((await f.restart().submitPrintJob("token", payload)).id, "recovered-1");
  assert.deepEqual(f.values.get("lulu-submission").diagnostic, diagnostic);
  assert.equal(f.creates(), 1);
});

test("unreadable responses and transport failures stay uncertain with bounded diagnostics", async t => {
  const f = fixture(t);
  const cases = [
    [() => new Response("Private upstream HTML", { status: 502 }), { kind: "http_error", httpStatus: 502, fields: [] }],
    [() => new Response("Private malformed receipt", { status: 201 }), { kind: "invalid_receipt", httpStatus: 201 }],
    [() => Response.json({ shipping_address: payload.shipping_address }), { kind: "invalid_receipt" }],
    [() => { throw new Error("Private network details"); }, { kind: "transport_or_receipt" }],
  ];
  for (let i = 0; i < cases.length; i++) {
    // Each case represents a distinct parcel with fresh durable storage.
    f.values.clear();
    f.setCreate(cases[i][0]);
    await assert.rejects(f.restart().submitPrintJob("token", payload), { code: "print_submission_uncertain" });
    assert.deepEqual(f.values.get("lulu-submission").diagnostic, cases[i][1]);
    await assert.rejects(f.restart().submitPrintJob("token", payload), { code: "print_submission_uncertain" });
    assert.equal(f.creates(), i + 1);
  }
  assert.ok(!JSON.stringify(f.diagnostics).includes("Private"));
});

test("a failed diagnostic write leaves the pre-request duplicate guard intact", async t => {
  const f = fixture(t);
  f.setCreate(() => {
    f.failWrites(true);
    return Response.json({ contact_email: ["Rejected"] }, { status: 400 });
  });
  await assert.rejects(f.restart().submitPrintJob("token", payload), { code: "print_submission_uncertain" });
  assert.ok(f.values.get("lulu-submission"));
  assert.equal(f.values.get("lulu-submission").diagnostic, undefined);
  f.failWrites(false);
  await assert.rejects(f.restart().submitPrintJob("token", payload), { code: "print_submission_uncertain" });
  assert.equal(f.creates(), 1);
});
