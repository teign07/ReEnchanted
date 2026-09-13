/* One mark per leaf, and no leaf wears a face another leaf is already wearing.
 *
 * The markup ships a mark on every quiet leaf, but it only ever named three
 * pictures, so the same goblin turned up five times in twenty-one leaves. The
 * app keeps sixty-seven marks; marginalia-catalogue.js carries them across.
 * This deals them out: whole figures first, then the smaller marks, shuffled
 * from the same seed the reader's session already uses so a visit is stable
 * while two visits differ.
 */
(() => {
  'use strict';
  const catalogue = window.PublicMarginalia;
  if (!catalogue || !Array.isArray(catalogue.marks) || !catalogue.marks.length) return;

  const edition = window.PublicEdition;
  let state = (edition && Number.isInteger(edition.seed) ? edition.seed : Math.floor(Math.random() * 0x7fffffff)) >>> 0;
  const random = () => (state = (Math.imul(state, 1664525) + 1013904223) >>> 0) / 0x100000000;
  const shuffled = (role) => {
    const marks = catalogue.marks.filter(mark => mark.role === role);
    for (let i = marks.length - 1; i > 0; i--) {
      const j = Math.floor(random() * (i + 1));
      [marks[i], marks[j]] = [marks[j], marks[i]];
    }
    return marks;
  };

  // Whole figures go to the leaves a reader turns to first. The punctuation
  // charms are narrow little things, so they wait at the back of the hand and
  // are only reached if every goblin and pixie is already out on a page.
  const hand = [].concat(shuffled('portrait'), shuffled('fieldNote'), shuffled('classic'),
                         shuffled('ornament'), shuffled('sigil'));
  // The Academy's pinned scraps are shuffled on their own, so a leaf's note
  // and its mark never run out together.
  const pinned = catalogue.notes ? catalogue.notes.slice() : [];
  for (let i = pinned.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [pinned[i], pinned[j]] = [pinned[j], pinned[i]];
  }
  let dealt = 0, note = 0;

  function deal() { return hand[dealt++ % hand.length]; }
  function dealNote() { return pinned.length ? pinned[note++ % pinned.length] : null; }

  function dress(image) {
    if (!image || image.dataset.mark) return;
    const mark = deal();
    image.dataset.mark = mark.id;
    image.src = mark.src;
    image.width = mark.w;
    image.height = mark.h;
    // A mark the markup left decorative stays decorative. Where it described
    // the picture, the description has to follow the picture that replaced it.
    if (image.alt) image.alt = mark.alt;
  }

  // The notes carry their wording in the picture and nothing in the repo
  // transcribes it, so they stay decorative rather than claiming to say
  // something they might not.
  function pin(image) {
    if (!image || image.dataset.note) return;
    const scrap = dealNote();
    if (!scrap) return;
    image.dataset.note = scrap.id;
    image.src = scrap.src;
    image.width = scrap.w;
    image.height = scrap.h;
    image.alt = '';
  }

  const marks = '.quiet-mark,.reading-mark,.encounter-mark';
  function dressAll(root) {
    const scope = root || document;
    scope.querySelectorAll(marks).forEach(dress);
    scope.querySelectorAll('.quiet-note').forEach(pin);
  }
  dressAll();

  window.PublicMarginaliaDeck = { deal, dress, dressAll, marks: hand.length, notes: pinned.length };
})();
