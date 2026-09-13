/* Paper, tint and illumination, dealt the way the app deals them.
 *
 * Every leaf on the site was printed on one photograph of blank paper. The app
 * keeps five paper stocks, thirty-three page tints, fourteen watermarks and
 * seventy-eight edge marks, and it keeps the rules too. Three of those rules
 * are load-bearing here:
 *
 *   A stock belongs to the Page, not the leaf. "Every leaf in one Page
 *   therefore came from the same bundle of paper." So paper and tint are dealt
 *   per chapter and every leaf of that chapter shares them.
 *
 *   `allowsTextOverlap` decides where a mark may go. The fourteen watermarks
 *   are printed under the prose. The seventy-eight edge marks may not touch it,
 *   so they are placed outside `.leaf-content`'s own margins and nowhere else.
 *
 *   The app draws these far fainter than the plates themselves are:
 *   watermarkOpacity 0.10, cornerMarginaliaOpacity 0.34, sideMarginaliaOpacity
 *   0.38. Those are its numbers, not mine.
 */
(() => {
  'use strict';
  const shelf = window.PublicIllumination;
  if (!shelf || !Array.isArray(shelf.stocks) || !shelf.stocks.length) return;

  const edition = window.PublicEdition;
  let state = (edition && Number.isInteger(edition.seed) ? edition.seed : Math.floor(Math.random() * 0x7fffffff)) >>> 0;
  const random = () => (state = (Math.imul(state, 1664525) + 1013904223) >>> 0) / 0x100000000;
  const shuffle = (list) => {
    const items = list.slice();
    for (let i = items.length - 1; i > 0; i--) {
      const j = Math.floor(random() * (i + 1));
      [items[i], items[j]] = [items[j], items[i]];
    }
    return items;
  };

  const watermarks = shuffle(shelf.watermarks);
  const edgeMarks = shuffle(shelf.edgeMarks);
  const stocks = shuffle(shelf.stocks);
  const tints = shuffle(shelf.tints);

  // Anchors the site can honour. A leaf's text box leaves a margin on each
  // side; anything here sits in that margin and nowhere else.
  const ANCHORS = ['lowerField', 'upperTrailing', 'upperLeading',
                   'lowerTrailing', 'lowerLeading', 'middleTrailing', 'middleLeading'];

  // Where a leaf on the site is the same thing as a Page in the app, it is
  // printed on that Page's own paper rather than whatever the shuffle deals.
  // Everything else takes its turn from the deck.
  const KEYED = {
    'first-arrival': 'welcome', 'first-anyway': 'weather', 'first-night': 'diary',
    'first-dare': 'elective', 'first-wicker-echo': 'elective',
    'first-world': 'academyClass', 'academy': 'academyClass',
    'first-paper': 'taleBound', 'editions': 'taleBound',
    'first-compass': 'wonderCompass', 'ebook': 'wonderCompass',
    'first-parting': 'souvenir', 'first-privacy': 'plainPage', 'privacy': 'plainPage',
    'first-curse': 'lore', 'curse': 'lore', 'radio': 'radio', 'body': 'body',
    'pages': 'packPage', 'colophon': 'letter', 'plans': 'inventory'
  };
  const byId = new Map(shelf.tints.map(wash => [wash.id, wash]));
  const claimed = new Set(Object.values(KEYED).filter(id => byId.has(id)));
  const dealable = tints.filter(wash => !claimed.has(wash.id));

  const paper = new Map();
  let watermark = 0, edge = 0, stock = 0, tint = 0;

  function bundle(chapter) {
    // One bundle of paper per Page, cut differently for each of its leaves.
    if (!paper.has(chapter)) {
      const keyed = byId.get(KEYED[chapter]);
      paper.set(chapter, {
        stock: stocks[stock++ % stocks.length],
        tint: keyed || dealable[tint++ % dealable.length] || tints[0]
      });
    }
    return paper.get(chapter);
  }

  function illuminate(leaf) {
    if (!leaf || leaf.dataset.illuminated) return;
    const chapter = leaf.dataset.chapter || 'unbound';
    leaf.dataset.illuminated = chapter;

    // The paper goes on a child, not on the leaf. StPageFlip writes
    // `element.style.cssText = "display: none"` over every leaf that is not
    // currently drawn, which would take these custom properties with it.
    const { stock: sheet, tint: wash } = bundle(chapter);
    const sheetLayer = document.createElement('div');
    sheetLayer.className = 'leaf-paper';
    sheetLayer.style.setProperty('--leaf-stock', 'url("' + sheet.src + '")');
    sheetLayer.style.setProperty('--leaf-top', wash.top);
    sheetLayer.style.setProperty('--leaf-middle', wash.middle);
    sheetLayer.style.setProperty('--leaf-bottom', wash.bottom);
    leaf.insertBefore(sheetLayer, leaf.firstChild);
    leaf.dataset.stock = sheet.id;
    leaf.dataset.tint = wash.id;

    const under = watermarks[watermark++ % watermarks.length];
    if (under) {
      const mark = new Image();
      mark.className = 'leaf-illumination leaf-watermark';
      mark.src = under.src;
      mark.alt = '';
      mark.loading = 'lazy';
      mark.decoding = 'async';
      mark.style.setProperty('--turn', (random() * 16 - 8).toFixed(2) + 'deg');
      leaf.insertBefore(mark, leaf.firstChild);
    }

    const beside = edgeMarks[edge++ % edgeMarks.length];
    if (beside) {
      const anchor = (beside.anchors || []).find(name => ANCHORS.includes(name)) || 'lowerField';
      const ornament = new Image();
      ornament.className = 'leaf-illumination leaf-edge-mark';
      ornament.dataset.anchor = anchor;
      ornament.src = beside.src;
      ornament.alt = '';
      ornament.loading = 'lazy';
      ornament.decoding = 'async';
      // The plate's own alpha is already baked in; this is the page's opacity
      // for a mark in the margin, which the app sets far lower.
      ornament.style.opacity = anchor.startsWith('middle') ? 0.38 : 0.34;
      leaf.insertBefore(ornament, leaf.firstChild);
    }
  }

  function illuminateAll(root) {
    (root || document).querySelectorAll('.folio-leaf').forEach(illuminate);
  }

  window.PublicIlluminationDeck = {
    illuminate, illuminateAll,
    counts: { watermarks: watermarks.length, edgeMarks: edgeMarks.length, stocks: stocks.length, tints: tints.length }
  };
})();
