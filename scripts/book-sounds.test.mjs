import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const code = readFileSync(new URL('../LandingPage/book-sounds.js', import.meta.url), 'utf8');
const manifest = JSON.parse(readFileSync(new URL('../LandingPage/assets/sounds/manifest.json', import.meta.url), 'utf8'));

function browser({ saved = 'on', deferred = false } = {}) {
  const events = new Map(), clicks = [], fetched = [], started = [], contexts = [], pending = [];
  const storage = new Map([['reenchanted-book-sounds', saved]]);
  const button = { hidden: true, attributes: {}, classList: { add() {}, remove() {} }, setAttribute(k, v) { this.attributes[k] = v; }, addEventListener(_, f) { clicks.push(f); } };
  const document = { hidden: false, querySelector: s => s === '#book-sound-toggle' ? button : null,
    addEventListener(name, f) { if (!events.has(name)) events.set(name, []); events.get(name).push(f); } };
  let now = 1000;
  class AudioContext {
    state = 'suspended'; currentTime = 0;
    constructor() { contexts.push(this); }
    createGain() { return { gain: { value: 0, setValueAtTime() {} }, connect() {} }; }
    resume() { this.state = 'running'; return Promise.resolve(); }
    suspend() { this.state = 'suspended'; return Promise.resolve(); }
    decodeAudioData() { return Promise.resolve({}); }
    createBufferSource() { return { connect() {}, disconnect() {}, start() { started.push(this); }, stop() { this.onended?.(); } }; }
  }
  const window = { BookSoundCatalogue: manifest, AudioContext };
  vm.runInNewContext(code, { window, document, localStorage: { getItem: k => storage.get(k), setItem: (k, v) => storage.set(k, v) },
    performance: { now: () => now }, Date, Math, Map, Set, fetch: url => {
      fetched.push(url);
      const response = { ok: true, arrayBuffer: () => Promise.resolve(new ArrayBuffer(8)) };
      if (!deferred) return Promise.resolve(response);
      return new Promise(resolve => pending.push(() => resolve(response)));
    } });
  const event = { isTrusted: true };
  return { window, document, button, fetched, started, contexts, pending, storage,
    emit: (name, value = event) => events.get(name)?.forEach(f => f(value)),
    toggle() { events.get('click')?.forEach(f => f(event)); clicks.forEach(f => f(event)); },
    advance(ms = 200) { now += ms; },
  };
}
const settle = () => new Promise(resolve => setImmediate(resolve));

test('no context, audio download, or autoplay before a trusted interaction', async () => {
  const b = browser();
  await b.window.BookSounds.play('open');
  b.emit('click', { isTrusted: false });
  assert.equal(b.contexts.length, 0);
  assert.equal(b.fetched.length, 0);
  b.emit('click');
  await b.window.BookSounds.play('open');
  assert.equal(b.contexts.length, 1);
  assert.equal(b.started.length, 1);
});

test('muting cancels a cue still downloading and persists the choice', async () => {
  const b = browser({ deferred: true });
  b.emit('click');
  const cue = b.window.BookSounds.play('open');
  b.toggle();
  b.pending[0]();
  await cue;
  assert.equal(b.started.length, 0);
  assert.equal(b.storage.get('reenchanted-book-sounds'), 'off');
  assert.equal(b.button.attributes['aria-pressed'], 'false');
});

test('a remembered mute stays quiet until explicitly enabled', async () => {
  const b = browser({ saved: 'off' });
  b.emit('pointerdown');
  await b.window.BookSounds.play('turn');
  assert.equal(b.contexts.length, 0);
  assert.equal(b.fetched.length, 0);
  b.toggle();
  await settle();
  assert.equal(b.started.length, 1);
  assert.match(b.fetched[0], /toggle-[01]\.wav/);
});

test('turn direction, nonrepeating variants, and duplicate suppression', async () => {
  const b = browser(); b.emit('click');
  await b.window.BookSounds.turn(true);
  await b.window.BookSounds.turn(true);
  assert.equal(b.fetched.length, 1);
  b.advance();
  await b.window.BookSounds.turn(true);
  assert.notEqual(b.fetched[0], b.fetched[1]);
  await b.window.BookSounds.turn(false);
  assert.match(b.fetched[2], /turnback-/);
});

test('tab hiding stops playback and invalidates pending audio', async () => {
  const b = browser(); b.emit('click');
  await b.window.BookSounds.play('open');
  b.document.hidden = true; b.emit('visibilitychange');
  assert.equal(b.window.BookSounds.state.active, 0);
  assert.equal(b.contexts[0].state, 'suspended');
  await b.window.BookSounds.play('keep');
  assert.equal(b.fetched.length, 1);
});
