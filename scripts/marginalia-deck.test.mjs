import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

const catalogueSource = readFileSync(new URL('../LandingPage/marginalia-catalogue.js', import.meta.url), 'utf8');
const deckSource = readFileSync(new URL('../LandingPage/marginalia-deck.js', import.meta.url), 'utf8');
function cabinet({ seasonal = true } = {}) {
  const context = vm.createContext({ window: { PublicEdition: { seed: 173 } }, document: { querySelectorAll: () => [] } });
  vm.runInContext(catalogueSource, context);
  if (!seasonal) context.window.PublicMarginalia.seasonal = [];
  vm.runInContext(deckSource, context);
  return context.window.PublicMarginaliaDeck;
}
function image() { return { dataset: {}, alt: '' }; }

test('opening, quiet and automatic drawings share a pool without repetition', () => {
  const deck = cabinet();
  const staticImages = Array.from({ length: 40 }, image);
  staticImages.forEach(img => deck.dress(img));
  deck.beginPages();
  const automatic = Array.from({ length: 25 }, () => deck.dealPage());
  const sources = staticImages.map(img => img.src).concat(automatic.map(mark => mark.src));
  assert.equal(new Set(sources).size, sources.length);
  assert.ok(staticImages.some(img => img.src.includes('/monthly-marginalia/')));
  assert.ok(staticImages.some(img => img.src.includes('/marginalia/')));
});

test('resizing reuses the remaining pool and dressing a clone consumes nothing', () => {
  const deck = cabinet();
  const first = image();
  deck.dress(first);
  const second = deck.deal();
  deck.dress(first);
  deck.beginPages();
  const before = Array.from({ length: 20 }, () => deck.dealPage().id);
  deck.beginPages();
  const after = Array.from({ length: 20 }, () => deck.dealPage().id);
  assert.deepEqual(after, before);
  assert.notEqual(second.id, first.dataset.mark);
});

test('both monthly and permanent-only cabinets stop instead of repeating', () => {
  for (const seasonal of [true, false]) {
    const deck = cabinet({ seasonal });
    const seen = new Set();
    for (let i = 0; i < deck.marks; i++) {
      const mark = deck.deal();
      assert.ok(mark);
      assert.ok(!seen.has(mark.id));
      seen.add(mark.id);
    }
    assert.equal(deck.deal(), null);
    deck.beginPages();
    assert.equal(deck.dealPage(), null);
  }
});
