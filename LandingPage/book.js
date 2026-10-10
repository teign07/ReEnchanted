/* ReEnchanted's public edition. The HTML manuscript remains the source of truth. */
(() => {
  'use strict';
  const manuscript = document.querySelector('#manuscript');
  const room = document.querySelector('#reading-room');
  const stage = document.querySelector('#book-stage');
  let folio = document.querySelector('#folio');
  const previous = document.querySelector('#previous-page');
  const next = document.querySelector('#next-page');
  const position = document.querySelector('#page-position');
  const modeButton = document.querySelector('#reading-mode');
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const chapters = [...manuscript.querySelectorAll(':scope > [data-chapter]')];
  const pages = [];
  const anchors = new Map();
  const sheetIDs = new Set(['contents','invitation','glow','capture','body','place','radio-player']);
  let pager = null, current = 0, active = false, rebuilding = false;
  let audibleIndex = 0;
  let lastWidth = 0, resizeTimer, dialogReturnFocus = null;
  let closingDialog = null, navigationRunning = false, queuedNavigation = null, finishTurn = null, isRiffling = false;
  const dialog = document.createElement('dialog');
  dialog.className = 'paper-dialog';
  dialog.setAttribute('aria-label', 'Notes in the Book');
  dialog.innerHTML = '<button class="dialog-close" type="button" aria-label="Close and return to the Book">×</button><div class="dialog-body"></div>';
  document.body.append(dialog);
  const dialogBody = dialog.querySelector('.dialog-body');
  let borrowed = null, borrowedPlace = null;
  let sheetEmbers = null, emberBurst = 0;

  function clearSheetEmbers() {
    sheetEmbers?.remove();
    sheetEmbers = null;
  }
  function shedSheetLetters(id) {
    clearSheetEmbers();
    if (reducedMotion.matches || document.hidden || ![...document.querySelectorAll('.binding-tabs a')].some(link => link.hash === '#'+id)) return;
    const embers = document.createElement('div');
    embers.className = 'sheet-embers';
    embers.setAttribute('aria-hidden', 'true');
    sheetEmbers = embers;
    const alphabet = (dialog.querySelector('h2')?.textContent || id).toUpperCase().replace(/[^A-Z]/g, '') || 'INK';
    const seed = [...id].reduce((sum, character) => sum + character.charCodeAt(0), 0) + emberBurst++ * 17;
    const narrow = innerWidth <= 600;
    for (let i = 0; i < (narrow ? 8 : 12); i++) {
      const letter = document.createElement('span');
      const edge = i % 3; // Top, left, right: the letters escape away from the reading area.
      letter.textContent = alphabet[(seed + i * 7) % alphabet.length];
      letter.style.setProperty('--ember-x', `${edge === 0 ? 12 + (seed + i * 23) % 68 : edge === 1 ? 3 : 97}%`);
      letter.style.setProperty('--ember-y', `${edge === 0 ? 2 : 18 + (seed + i * 19) % 68}%`);
      letter.style.setProperty('--ember-size', `${12 + (seed + i * 3) % 8}px`);
      letter.style.setProperty('--ember-drift', `${edge === 0 ? -16 + (seed + i * 11) % 33 : (edge === 1 ? -1 : 1) * (narrow ? 8 : 24)}px`);
      letter.style.setProperty('--ember-rise', `${-55 - (seed + i * 13) % 40}px`);
      letter.style.setProperty('--ember-turn', `${-55 + (seed + i * 17) % 110}deg`);
      letter.style.setProperty('--ember-time', `${1800 + (seed + i * 97) % 550}ms`);
      letter.style.setProperty('--ember-delay', `${180 + (seed + i * 37) % 240}ms`);
      letter.addEventListener('animationend', () => {
        letter.remove();
        if (!embers.childElementCount && sheetEmbers === embers) clearSheetEmbers();
      }, { once: true });
      embers.append(letter);
    }
    dialog.append(embers);
  }
  reducedMotion.addEventListener('change', clearSheetEmbers);
  document.addEventListener('visibilitychange', () => { if (document.hidden) clearSheetEmbers(); });

  function restoreSheet() {
    if (borrowed) { borrowedPlace.replaceWith(borrowed); borrowed = null; }
    document.querySelectorAll('.binding-tabs a').forEach(link=>link.setAttribute('aria-expanded','false'));
  }
  function positionSheet() {
    const rect=stage.getBoundingClientRect();
    const width=Math.min(dialog.classList.contains('is-glow')?370:440,innerWidth-28);
    const left=Math.max(14,Math.min(innerWidth-width-14,rect.right-width+24));
    const top=dialog.dataset.sheet==='invitation' ? 24 : Math.max(20,Math.min(rect.top+12,innerHeight-340));
    dialog.style.setProperty('--sheet-left',left+'px');
    dialog.style.setProperty('--sheet-top',top+'px');
    dialog.style.setProperty('--sheet-width',width+'px');
    dialog.style.setProperty('--tucked-x',(rect.left+rect.width/2-left-width/2)+'px');
  }
  function closeDialog() {
    if(closingDialog) return closingDialog;
    if(!dialog.open) return Promise.resolve();
    clearSheetEmbers();
    window.BookSounds?.play('close');
    closingDialog=(async()=>{
      if(dialog.classList.contains('binding-dialog') && !reducedMotion.matches){
        const animation=dialog.animate([{transform:'translateX(0)',opacity:1},{transform:'translateX(42px)',opacity:1,offset:.3},{transform:'translateX(var(--tucked-x)) scale(.96)',opacity:0}],{duration:390,easing:'ease-in-out',fill:'forwards'});
        await animation.finished.catch(()=>{});
        animation.cancel();
      }
      restoreSheet(); dialog.close(); document.body.style.overflow = '';
    })().finally(()=>{closingDialog=null;});
    return closingDialog;
  }
  dialog.addEventListener('cancel',event=>{event.preventDefault();closeDialog();});
  dialog.querySelector('.dialog-close').addEventListener('click', closeDialog);
  dialog.addEventListener('click', event => { if (event.target === dialog && (event.clientX < dialog.getBoundingClientRect().left || event.clientX > dialog.getBoundingClientRect().right || event.clientY < dialog.getBoundingClientRect().top || event.clientY > dialog.getBoundingClientRect().bottom)) closeDialog(); });
  dialog.addEventListener('close', () => {
    if (dialog.open) return;
    clearSheetEmbers();
    restoreSheet();
    document.body.style.overflow = '';
    dialogReturnFocus?.focus({ preventScroll: true });
  });
  async function openSheet(id, sound = true) {
    const source = document.getElementById(id);
    if (!source) return false;
    if (id==='radio-player') loadRadio();
    if (dialog.open) await closeDialog();
    dialogReturnFocus = document.activeElement;
    borrowed = source;
    borrowedPlace = document.createComment('The open sheet returns here.');
    source.replaceWith(borrowedPlace);
    dialogBody.replaceChildren(source);
    dialog.classList.add('binding-dialog');
    dialog.classList.toggle('is-glow',id==='glow');
    dialog.dataset.sheet = id;
    positionSheet();
    document.querySelectorAll('.binding-tabs a').forEach(link=>link.setAttribute('aria-expanded',String(link.hash==='#'+id)));
    dialog.setAttribute('aria-label', source.querySelector('h2')?.textContent || 'Notes in the Book');
    dialog.showModal();
    if(sound) window.BookSounds?.play(id==='glow'?'glowopen':'peek');
    window.PublicEdition?.hydrate(dialog);
    if(!reducedMotion.matches) dialog.animate([{transform:'translateX(var(--tucked-x)) scale(.96)',opacity:0},{transform:'translateX(56px)',opacity:1,offset:.65},{transform:'translateX(0)',opacity:1}],{duration:560,easing:'cubic-bezier(.2,.7,.2,1)'});
    shedSheetLetters(id);
    dialog.scrollTop = 0;
    dialogBody.scrollTop = 0;
    document.body.style.overflow = 'hidden';
    return true;
  }

  async function openPlate(name) {
    const source = manuscript.querySelector(`[data-plate="${name}"] img`);
    if (!source) return;
    if (window.PublicImageViewer) { window.PublicImageViewer.open(source); return; }
    if (dialog.open) await closeDialog();
    dialog.classList.remove('binding-dialog','is-glow');
    delete dialog.dataset.sheet;
    dialogReturnFocus = document.activeElement;
    const figure = document.createElement('figure'); figure.className='enlarged-plate';
    const img=source.cloneNode();img.loading='eager';figure.append(img);
    const caption=document.createElement('figcaption');caption.textContent=source.alt;figure.append(caption);
    dialogBody.replaceChildren(figure);dialog.setAttribute('aria-label',source.alt);
    dialog.showModal();document.body.style.overflow='hidden';
    window.BookSounds?.play('peek');
  }

  // Blocks are semantic units, not screenshots. Paragraph splits preserve inline links.
  const atomic = new Set(['P','H1','H2','H3','H4','H5','FIGURE','VIDEO','HR']);
  const phrasing = new Set(['A','SPAN','STRONG','EM','B','I','SMALL','BR','CITE','SUP','SUB','IMG']);
  function blocksFrom(element, inherited = []) {
    const ids = [...inherited, ...(element.id ? [element.id] : [])];
    if (element.matches('.opening-beat')) {
      const art = element.querySelector(':scope > .opening-mark');
      const blocks = [...element.children].filter(child => child !== art).flatMap((child, index) => blocksFrom(child, index ? [] : ids));
      blocks.forEach((block, index) => { block.openingArt = art; block.openingStart = index === 0; });
      return blocks;
    }
    if (element.matches('.trust-row') && element.closest('.opening-beat')) return [{ node: element.cloneNode(true), ids }];
    if (atomic.has(element.tagName) || element.matches('.title-page,.monthly-cover-face,.quiet-composition,.reading-composition,.encounter-anchor')) return [{ node: element.cloneNode(true), ids }];
    if (element.matches('ul,ol')) return [...element.children].flatMap((item, index) => {
      const list = element.cloneNode(false);
      list.classList.add('split-list');
      if (element.tagName === 'OL') list.start = Number(element.getAttribute('start') || 1) + index;
      list.append(item.cloneNode(true));
      return [{ node: list, ids: index === 0 ? ids : [] }];
    });
    if (element.tagName === 'DL') return [...element.children].map((item, index) => {
      const list = element.cloneNode(false); list.append(item.cloneNode(true));
      return { node: list, ids: index === 0 ? ids : [] };
    });
    if (element.tagName === 'IMG') {
      const figure = document.createElement('figure'); figure.append(element.cloneNode(true));
      return [{ node: figure, ids }];
    }
    if (!element.children.length || [...element.children].every(child => phrasing.has(child.tagName))) {
      if (!element.textContent.trim() && !element.querySelector('img')) return [];
      const p = document.createElement('p');
      p.className = element.className;
      p.innerHTML = phrasing.has(element.tagName) ? element.outerHTML : element.innerHTML;
      return [{ node: p, ids }];
    }
    const result = [];
    for (const child of element.childNodes) {
      if (child.nodeType === Node.ELEMENT_NODE) result.push(...blocksFrom(child, result.length ? [] : ids));
      else if (child.nodeType === Node.TEXT_NODE && child.textContent.trim()) {
        const p = document.createElement('p'); p.textContent = child.textContent;
        result.push({ node: p, ids: result.length ? [] : ids });
      }
    }
    return result;
  }
  function removeDuplicateIds(node) {
    node.removeAttribute('id');
    node.querySelectorAll('[id]').forEach(child => child.removeAttribute('id'));
    node.querySelectorAll('img').forEach(img => {
      img.draggable = false;
      // Reserve screenshot geometry while its lazy image is still on the way.
      // Otherwise pagination can put two unloaded pictures on the same leaf.
      if (img.closest('figure') && /\/screens\/|\/samples\/pagewright-/.test(img.getAttribute('src') || '')) {
        const width = Number(img.getAttribute('width'));
        const height = Number(img.getAttribute('height'));
        if (width > 0 && height > 0) {
          img.style.aspectRatio = `${width} / ${height}`;
          img.style.width = `min(100%, calc(var(--figure-height, 290px) * ${width / height}))`;
        }
      }
    });
    return node;
  }
  function makeLeaf(chapter, continuation = false) {
    const leaf = document.createElement('section');
    leaf.className = 'folio-leaf' + (chapter.dataset.kind === 'title' ? ' is-title' : '') + (chapter.dataset.kind === 'quiet' ? ' is-quiet' : '');
    if(chapter.dataset.kind==='cover'){leaf.classList.add('is-cover');leaf.dataset.density='hard';}
    leaf.dataset.chapter = chapter.id;
    if(chapter.dataset.kind==='composed')leaf.classList.add('is-composed');
    leaf.dataset.theme=chapter.dataset.theme||'';
    leaf.dataset.reading=chapter.dataset.reading||'';
    leaf.dataset.reference=chapter.dataset.reference||'';
    leaf.dataset.title = chapter.dataset.chapter;
    leaf.setAttribute('aria-label', chapter.dataset.chapter);
    const header = document.createElement('header'); header.className = 'leaf-header';
    const brand = document.createElement('span'); brand.textContent = 'ReEnchanted';
    const title = document.createElement('span'); title.textContent = chapter.dataset.chapter;
    header.append(brand,title);
    const content = document.createElement('div'); content.className = 'leaf-content';
    const footer = document.createElement('footer'); footer.className = 'leaf-footer';
    const mark = document.createElement('span'); mark.textContent = continuation ? 'The public edition · continued' : 'The public edition';
    const number = document.createElement('span'); number.textContent = String(pages.length + 1).padStart(2,'0');
    footer.append(mark,number); leaf.append(header,content,footer);
    return leaf;
  }
  function fits(content) { return content.scrollHeight <= content.clientHeight + 1; }
  function textPoints(node) {
    const walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT);
    let n; const points = [];
    while ((n = walker.nextNode())) {
      for (const match of n.textContent.matchAll(/\s+/g)) points.push({ node:n, offset:match.index + match[0].length });
    }
    return points;
  }
  function rangePart(node, point, before) {
    const range = document.createRange(); range.selectNodeContents(node);
    if (before) range.setEnd(point.node,point.offset); else range.setStart(point.node,point.offset);
    const clone = node.cloneNode(false); clone.append(range.cloneContents()); return clone;
  }
  function splitToFit(node, content) {
    if (node.matches('figure,video,.title-page,.trust-row') || node.querySelector('img,video,input,button')) return null;
    const points = textPoints(node);
    let lo = 0, hi = points.length - 1, best = -1;
    while (lo <= hi) {
      const mid = Math.floor((lo + hi) / 2);
      const candidate = rangePart(node, points[mid], true); content.append(candidate);
      const works = fits(content); candidate.remove();
      if (works) { best = mid; lo = mid + 1; } else hi = mid - 1;
    }
    if (best < 1 || best >= points.length - 1) return null;
    const before = rangePart(node,points[best],true), after = rangePart(node,points[best],false);
    after.classList.add('continued-paragraph');
    return [before,after];
  }
  function collectAnchors(block, pageIndex) {
    for (const id of [...block.ids, ...[...block.node.querySelectorAll('[id]')].map(el=>el.id)]) if (!anchors.has(id)) anchors.set(id,pageIndex);
  }

  function paginate() {
    pages.length = 0; anchors.clear();
    const deck = window.PublicMarginaliaDeck;
    deck?.beginPages();
    const measure = document.createElement('div'); measure.className = 'pagination-measure';
    measure.style.width = stage.style.width; measure.style.height = stage.style.height;
    document.body.append(measure);
    try {
      for (const chapter of chapters) {
        const queue = [...chapter.children].flatMap(child => blocksFrom(child));
        anchors.set(chapter.id,pages.length);
        let leaf = makeLeaf(chapter), content = leaf.querySelector('.leaf-content'), openingArt = null;
        function mount() { leaf.style.width = stage.style.width; leaf.style.height = stage.style.height; measure.replaceChildren(leaf); }
        function addOpeningArt(original = false) {
          if (!openingArt) return;
          leaf.classList.add('is-opening');
          const art = removeDuplicateIds(openingArt.cloneNode(true));
          if (!original) {
            const drawing = deck?.dealPage();
            if (!drawing) return;
            const image = art.querySelector('img');
            image.src = drawing.src; image.width = drawing.w; image.height = drawing.h;
            image.dataset.mark = drawing.id;
          }
          content.append(art);
        }
        function hasText() { return [...content.children].some(child => !child.matches('.opening-mark')); }
        function finish() { if(hasText()) pages.push(leaf); leaf=makeLeaf(chapter,true); content=leaf.querySelector('.leaf-content'); addOpeningArt(); mount(); }
        mount();
        for (let index=0;index<queue.length;index++) {
          const block=queue[index];
          if (block.openingStart) {
            openingArt = null;
            if (hasText()) finish();
            openingArt = block.openingArt;
            addOpeningArt(true);
          }
          const node=removeDuplicateIds(block.node.cloneNode(true));
          // Authored page starts take precedence over the space left on a leaf.
          if (node.dataset.pageBreak === 'before' && hasText()) finish();
          content.append(node);
          if (['cover','title','quiet','composed'].includes(chapter.dataset.kind)) { collectAnchors(block,pages.length); continue; }
          // Keep a heading with its photograph, or the start of the next paragraph.
          if (fits(content) && node.matches('h1,h2,h3,h4,.eyebrow') && queue[index+1]) {
            const following=queue[index+1].node;
            const probe=following.matches('figure,video') ? removeDuplicateIds(following.cloneNode(true)) : document.createElement('p');
            if (!following.matches('figure,video')) probe.textContent=following.textContent.slice(0,110);
            content.append(probe);
            const orphan=!fits(content); probe.remove();
            if(orphan && content.children.length>(openingArt ? 2 : 1)) { node.remove(); finish(); content.append(node); }
          }
          if (!fits(content)) {
            node.remove();
            // A study credit travels with the preceding explanation, rather
            // than becoming an otherwise empty continuation page.
            if (openingArt && node.matches('.opening-source')) {
              const explanation = content.lastElementChild;
              if (explanation && explanation.matches('p:not(.opening-mark)')) {
                explanation.remove(); finish(); content.append(explanation, node);
                collectAnchors(block,pages.length);
                continue;
              }
            }
            if (hasText() && (node.matches('h1,h2,h3,h4,figure,video') || node.textContent.length<250)) finish();
            let split=splitToFit(node,content);
            if(split) {
              collectAnchors(block,pages.length); content.append(split[0]);
              queue.splice(index+1,0,{node:split[1],ids:[],openingArt}); finish(); continue;
            }
            if(hasText()) finish();
            content.append(node);
            if(!fits(content)) {
              node.remove(); split=splitToFit(node,content);
              if(split) { collectAnchors(block,pages.length);content.append(split[0]);queue.splice(index+1,0,{node:split[1],ids:[],openingArt});finish();continue; }
              content.append(node);
              // An unusual indivisible object is scrollable, never silently clipped.
              if(!fits(content)) { content.style.overflowY='auto'; content.tabIndex=0; content.setAttribute('aria-label','Page content, scroll to read the rest'); }
            }
          }
          collectAnchors(block,pages.length);
        }
        if(chapter.dataset.kind==='composed'){
          const composition=content.querySelector('.reading-composition,.encounter-composition');
          if(composition && composition.scrollHeight>composition.clientHeight+1)leaf.classList.add('is-compact');
        }
        if(content.children.length) pages.push(leaf);
      }
      // Like the app's compositor, put a mark only into measured empty paper.
      pages.forEach((page,index)=>{
        if(page.matches('.is-title,.is-quiet,.is-composed,.is-cover,.is-opening') || index%3!==1) return;
        measure.replaceChildren(page);
        const field=page.querySelector('.leaf-content');
        const last=field.lastElementChild;
        if(!last || field.style.overflowY) return;
        const bottom=last.getBoundingClientRect().bottom-field.getBoundingClientRect().top;
        const available=field.clientHeight-bottom-20;
        if(available<65) return;
        const drawing = deck?.dealPage();
        if (!drawing) return;
        const mark=document.createElement('img');mark.className='page-marginalia';
        mark.src=drawing.src;mark.width=drawing.w;mark.alt='';mark.setAttribute('aria-hidden','true');mark.loading='lazy';mark.draggable=false;
        mark.style.height=Math.min(104,available)+'px';
        mark.style.top=(field.offsetTop+bottom+14)+'px';
        mark.style.right=(index%2?35:55)+'px';
        mark.style.rotate=(index%2?-5:4)+'deg';
        page.append(mark);
      });
    } finally { measure.remove(); }
  }
  function voiceNavigation(from, to) {
    if(to===audibleIndex) return;
    audibleIndex=to;
    if(pages[from]?.classList.contains('is-cover')) window.BookSounds?.play('open');
    else if(pages[to]?.classList.contains('is-cover')) window.BookSounds?.play('close');
    else window.BookSounds?.turn(to>from);
  }
  function updateState(index, writeHistory = true) {
    const destination=Math.max(0,Math.min(pages.length-1,index));
    current=destination;
    previous.disabled=current===0; next.disabled=current===pages.length-1;
    next.setAttribute('aria-label','Next page');
    stage.classList.toggle('is-closed',pages[current].classList.contains('is-cover'));
    document.querySelector('#turn-hint').textContent=pages[current].classList.contains('is-cover')?'Open the cover. There’s a Book inside.':'Drag a page corner, or use the arrows. Tap a picture to look closer.';
    // One reading, including the full information chapters and Book Pages.
    position.textContent=pages[current].dataset.title+' · '+String(current+1).padStart(2,'0')+' / '+pages.length;
    if(pages[current].dataset.reading)window.PublicEdition.readingBookmark=pages[current].dataset.chapter;
    if(!isRiffling) window.PublicEdition?.visit(pages[current],current);
    pages.forEach((page,i) => {
      page.inert=i!==current;
      page.setAttribute('aria-hidden',String(i!==current));
      page.classList.toggle('is-current',i===current);
      if(Math.abs(i-current)<=2) page.querySelectorAll('img').forEach(img=>{img.loading='eager';});
    });
    // Portrait page-turn renderers make temporary copies; they are visual only.
    folio.querySelectorAll('.folio-leaf').forEach(page=>{if(!pages.includes(page)){page.inert=true;page.setAttribute('aria-hidden','true');}});
    document.querySelectorAll('.binding-tabs a').forEach(link=>{
      const destinations={body:['editions','plans'],place:['academy','systems'],glow:['how','privacy'], 'radio-player':['radio']};
      if((destinations[link.hash.slice(1)]||[]).includes(pages[current].dataset.chapter)) link.setAttribute('aria-current','page'); else link.removeAttribute('aria-current');
    });
    if(writeHistory) {
      const id=pages[current].dataset.chapter;
      const offset=current-anchors.get(id);
      history.replaceState(null,'','#'+id+(offset?'~'+offset:''));
    }
  }
  // StPageFlip's own hit test spares only <a> and <button>: a mousedown on
  // anything else is preventDefault()ed, and that is what stops the browser
  // focusing it. A reader could never get a caret into the leaf's textarea.
  // Form controls belong to the reader, so the flip never hears about them.
  const readerControls='input,textarea,select,option,label,[contenteditable]';
  function keepForReader(event){
    if(event.target.closest && event.target.closest(readerControls)) event.stopPropagation();
  }

  // A backgrounded tab freezes a WAAPI animation mid-flight: currentTime stops
  // and finished never settles. Without a floor, navigationRunning stays true
  // and the Book is stuck shut. Always let the turn land.
  const settled=(motion,ms)=>Promise.race([
    motion.finished.catch(()=>{}),
    new Promise(done=>setTimeout(done,ms))
  ]);

  async function go(index, animate = true) {
    index=Math.max(0,Math.min(pages.length-1,index));
    if(!active) return;
    if(navigationRunning){queuedNavigation={index,animate};return;}
    if(index===current) return;
    voiceNavigation(current,index);
    if(animate && !reducedMotion.matches && (pages[current].classList.contains('is-cover') || pages[index].classList.contains('is-cover'))){
      navigationRunning=true;
      const opening=pages[current].classList.contains('is-cover');
      const board=pages[opening?current:index].querySelector('.monthly-cover-face').cloneNode(true);
      board.classList.add('cover-flight');board.inert=true;board.setAttribute('aria-hidden','true');stage.append(board);
      stage.classList.add('is-opening-cover');
      if(opening){if(pager)pager.turnToPage(index);else updateState(index,false);}
      // The board stops at 80° and fades through the second half of its swing.
      // Further round, perspective swells the near edge back across the spine
      // and the cover looks as if it rolls back into place. The flight must stay
      // transform-style:flat: under preserve-3d, Safari makes the cover art its
      // own 3D layer, which ignores both the fade and backface-visibility.
      const hinge=[
        {offset:0,transform:'rotateY(0deg)',filter:'brightness(1)',opacity:1},
        {offset:.5,opacity:1},
        {offset:1,transform:'rotateY(-80deg)',filter:'brightness(.5)',opacity:0}
      ];
      const motion=board.animate(opening?hinge:hinge.map(frame=>({...frame,offset:1-frame.offset})).reverse(),{duration:950,easing:'cubic-bezier(.45,.05,.3,1)',fill:'forwards'});
      try{await settled(motion,1600);}finally{
        if(pager)pager.turnToPage(index);updateState(index);
        board.remove();stage.classList.remove('is-opening-cover');navigationRunning=false;
        if(queuedNavigation){const queued=queuedNavigation;queuedNavigation=null;go(queued.index,queued.animate);}
      }
      return;
    }
    if(pager && animate && !reducedMotion.matches && index===current-1){
      navigationRunning=true;
      // StPageFlip cannot fold backwards in portrait: getFlippingPage and
      // getBottomPage hand back the same page, and driving the calculation by
      // hand walks the leaf into a zero-area sliver whichever way you push it,
      // so the reader sees the ruled page-block until turnToPage swaps the real
      // leaf in. The turn back borrows the cover flight's trick instead: the
      // destination leaf itself, cloned, hinged on the spine, unrolling left to
      // right with its own face on it the whole way.
      const flight=pages[index].cloneNode(true);
      flight.removeAttribute('style');
      flight.className=[...pages[index].classList]
        .filter(name=>!name.startsWith('stf__')&&!name.startsWith('--')&&name!=='is-current')
        .concat('leaf-flight').join(' ');
      flight.inert=true;flight.setAttribute('aria-hidden','true');
      stage.append(flight);stage.classList.add('is-turning-back');
      // Same hazard as the cover: the leaf starts past edge-on, back to the
      // reader, so it stays invisible until its own face turns toward them.
      const motion=flight.animate([
        {offset:0,transform:'rotateY(-96deg)',filter:'brightness(.42)',opacity:0},
        {offset:.19,opacity:0},
        {offset:.31,opacity:1},
        {offset:1,transform:'rotateY(0deg)',filter:'brightness(1)',opacity:1}
      ],{duration:720,easing:'cubic-bezier(.22,.5,.17,1)',fill:'forwards'});
      try{await settled(motion,980);}
      finally{
        pager.turnToPage(index);
        flight.remove();stage.classList.remove('is-turning-back');
        navigationRunning=false;updateState(index);
        if(queuedNavigation){const queued=queuedNavigation;queuedNavigation=null;go(queued.index,queued.animate);}
      }
      return;
    }
    if(animate && !reducedMotion.matches && Math.abs(index-current)>1){
      navigationRunning=true;isRiffling=true;
      const forward=index>current;
      stage.dataset.riffleDirection=forward?'right':'left';
      stage.classList.add('is-riffling');
      const flight=document.createElement('div');flight.className='riffle-flight';
      flight.setAttribute('aria-hidden','true');flight.inert=true;stage.append(flight);
      // FolioRiffle's nine overlapping sheets, with the destination changed
      // under the thickest part of the flight. Leaves swing off the spine,
      // so a forward turn sweeps left.
      const animations=Array.from({length:9},(_,i)=>{
        const sheet=document.createElement('div');sheet.className='riffle-sheet';flight.append(sheet);
        const from=forward?0:-172,to=forward?-172:0;
        sheet.style.zIndex=String(forward?i:9-i);
        return sheet.animate([
          {transform:`rotateY(${from}deg) scaleY(1)`,opacity:0},
          {opacity:1,offset:.06},
          {transform:'rotateY(-86deg) scaleY(.98)',opacity:1,offset:.5},
          {opacity:1,offset:.92},
          {transform:`rotateY(${to}deg) scaleY(1)`,opacity:0}
        ],{duration:280,delay:i*43,easing:'cubic-bezier(.28,.02,.16,1)',fill:'both'});
      });
      const reveal=setTimeout(()=>{if(pager)pager.turnToPage(index);else updateState(index,false);},270);
      try { await Promise.all(animations.map(a=>a.finished.catch(()=>{}))); }
      finally {
        clearTimeout(reveal);flight.remove();isRiffling=false;navigationRunning=false;
        stage.classList.remove('is-riffling');
        if(pager && pager.getCurrentPageIndex()!==index)pager.turnToPage(index);
        updateState(index);
        if(queuedNavigation){const queued=queuedNavigation;queuedNavigation=null;go(queued.index,queued.animate);}
      }
      return;
    }
    if(pager && animate && !reducedMotion.matches) {
      // StPageFlip applies its corner-only click guard to API turns too.
      // Its portrait backward-turn point is outside that corner region.
      // Bypass the hit test only while starting an explicit navigation turn;
      // ordinary clicks on the page must still leave the reader in place.
      const settings=pager.getSettings();
      const cornerOnly=settings.disableFlipByClick;
      const duration=settings.flippingTime;
      const distance=index-current, start=current;
      const count=Math.abs(distance)>1?Math.min(6,Math.abs(distance)):1;
      navigationRunning=true;isRiffling=count>1;
      stage.classList.toggle('is-riffling',isRiffling);
      stage.dataset.riffleDirection=distance>0?'right':'left';
      try {
        if(isRiffling) settings.flippingTime=135;
        for(let step=1;step<=count;step++){
          const destination=start+Math.round(distance*step/count);
          await new Promise(resolve=>{
            let timer;
            const complete=()=>{clearTimeout(timer);finishTurn=null;resolve();};
            finishTurn=()=>{if(pager.getCurrentPageIndex()===destination)complete();};
            timer=setTimeout(()=>{
              // A throttled animation must finish before the next riffle leaf.
              // Otherwise its delayed completion can turn past our destination.
              pager.getRender().finishAnimation();
              if(pager.getCurrentPageIndex()!==destination)pager.turnToPage(destination);
              complete();
            },settings.flippingTime+300);
            settings.disableFlipByClick=false;
            try { pager.flip(destination,'bottom'); }
            finally { settings.disableFlipByClick=cornerOnly; }
          });
        }
      } finally {
        settings.disableFlipByClick=cornerOnly;settings.flippingTime=duration;
        navigationRunning=false;isRiffling=false;stage.classList.remove('is-riffling');
        updateState(pager.getCurrentPageIndex());
        if(queuedNavigation){const queued=queuedNavigation;queuedNavigation=null;go(queued.index,queued.animate);}
      }
    }
    else if(pager) pager.turnToPage(index);
    else updateState(index);
  }
  function resolveHash(hash) {
    const raw=hash.replace(/^#/,'') || 'cover';
    let decoded; try { decoded=decodeURIComponent(raw); } catch { return null; }
    const [id,offsetText]=decoded.split('~');
    const aliases={top:'cover',book:'about','first-arrival':'about','first-curse':'curse','first-how':'how','first-night':'nightly-braid','first-world':'academy','first-compass':'ebook','first-paper':'editions','first-privacy':'privacy','encounter-write':'first-write','encounter-mission':'first-mission','encounter-dare':'first-dare','encounter-map':'first-map','encounter-kept':'first-kept','encounter-remembered':'first-remembered'};
    const key=aliases[id] && anchors.has(aliases[id]) ? aliases[id] : id;
    if(!anchors.has(key)) return null;
    const base=anchors.get(key), offset=Number(offsetText)||0;
    const target=Math.min(pages.length-1,base+Math.max(0,offset));
    return pages[target].dataset.chapter===pages[base].dataset.chapter?target:base;
  }
  function initialize(preferredHash = location.hash) {
    rebuilding=true;
    if(pager) { pager.destroy(); pager=null; folio=document.createElement('div'); folio.id='folio'; stage.append(folio); }
    const mobile=innerWidth<=600;
    const height=Math.min(760,Math.max(500,innerHeight-(mobile?215:238)));
    const width=Math.floor(Math.max(220,Math.min(520,innerWidth-(mobile?76:160),height*.74)));
    stage.style.width=width+'px';stage.style.height=height+'px';
    document.documentElement.style.setProperty('--leaf-width',width+'px');
    document.documentElement.style.setProperty('--leaf-height',height+'px');
    document.documentElement.style.setProperty('--figure-height',Math.floor((height-110)*.56)+'px');
    room.hidden=false;
    paginate();
    current=resolveHash(preferredHash)??0;
    audibleIndex=current;
    folio.replaceChildren(...pages);
    const plainMotion=reducedMotion.matches || !window.St?.PageFlip;
    document.body.classList.toggle('is-reduced-motion',plainMotion);
    if(!plainMotion) {
      pager=new St.PageFlip(folio,{width,height,size:'fixed',usePortrait:true,autoSize:false,startPage:current,drawShadow:true,maxShadowOpacity:.4,flippingTime:850,showCover:false,mobileScrollSupport:true,useMouseEvents:true,showPageCorners:true,disableFlipByClick:true,swipeDistance:35,clickEventForward:true});
      pager.on('flip',event=>{ if(!rebuilding) updateState(event.data); });
      pager.on('changeState',event=>{
        if(rebuilding)return;
        // Corner clicks and swipes speak before their animation starts.
        // go() already speaks for explicit navigation; fold() handles drags.
        if(event.data==='flipping' && !navigationRunning){
          const direction=pager.getFlipController().getCalculation()?.getDirection();
          if(direction!==undefined)voiceNavigation(current,current+(direction===0?1:-1));
        }
        if(event.data==='read'){
          updateState(pager.getCurrentPageIndex(),false);
          audibleIndex=current; // A cancelled drag can be lifted again.
          finishTurn?.();
        }
      });
      pager.loadFromHTML(pages);
      // Paper, tint and illumination are dealt once the leaves exist.
      window.PublicIlluminationDeck?.illuminateAll(folio);
      // Cloned leaves carry the markup but not the reader's choices.
      window.PublicStoryPages?.render(folio);
      for(const page of pages){
        page.addEventListener('mousedown',keepForReader);
        page.addEventListener('touchstart',keepForReader,{passive:true});
      }
      // Swipe and left-corner drags use the same returning curl as Previous.
      pager.flipPrev=()=>go(current-1);
      // The cover opens only by its own flight. A hand that drifts 5px on the
      // click is a drag to StPageFlip: it lifted the real board, dropped it back
      // shut on release, and the flight then swung a second, closed cover open.
      // So the board never curls, lifts or folds; any drag on it opens it.
      const onCover=()=>pages[current].classList.contains('is-cover');
      const nativeNext=pager.flipNext.bind(pager);
      pager.flipNext=corner=>onCover()?go(current+1):nativeNext(corner);
      const controller=pager.getFlipController();
      const nativeFold=controller.fold.bind(controller),nativeCorner=controller.showCorner.bind(controller);
      controller.fold=point=>{
        if(navigationRunning)return;
        if(onCover()){go(current+1);return;}
        if(pager.getState()==='user_fold'){nativeFold(point);return;}
        if(controller.getDirectionByPoint(pager.getRender().convertToBook(point))===1)go(current-1);
        else {
          if(controller.checkDirection(0))voiceNavigation(current,current+1);
          nativeFold(point);
        }
      };
      controller.showCorner=point=>{if(!navigationRunning && !onCover() && controller.getDirectionByPoint(pager.getRender().convertToBook(point))!==1)nativeCorner(point);};
      const nativeStop=pager.userStop.bind(pager);
      // A press that ends on the cover opens it by the flight too: StPageFlip
      // turns a hard page on any corner click, disableFlipByClick or not.
      pager.userStop=(point,swipe)=>{
        if(navigationRunning||onCover()){
          const pressed=pager.isUserTouch;pager.isUserTouch=false;pager.isUserMove=false;
          if(pressed&&!navigationRunning)go(current+1);
          return;
        }
        nativeStop(point,swipe);
      };
    }
    active=true;document.body.classList.add('book-active');
    modeButton.hidden=false;modeButton.textContent='Read as one page';
    lastWidth=innerWidth;rebuilding=false;
    updateState(current,false);
  }
  function continuous() {
    window.BookSounds?.select();
    active=false;room.hidden=true;document.body.classList.remove('book-active');
    modeButton.textContent='Read as a Book';
    const id=pages[current]?.dataset.chapter;
    if(id) document.getElementById(id)?.scrollIntoView({block:'start'});
  }
  previous.addEventListener('click',()=>go(current-1));next.addEventListener('click',()=>go(current+1));
  modeButton.addEventListener('click',()=>{if(active) continuous();else{initialize('#'+(pages[current]?.dataset.chapter||'frontispiece'));stage.focus({preventScroll:true});window.scrollTo(0,0);}});
  document.addEventListener('click',async event=>{
    if(event.target.closest('.glow-disclosure > summary')) {
      window.BookSounds?.select();
      return;
    }
    const plate=event.target.closest('[data-plate]');
    if(plate){event.preventDefault();openPlate(plate.dataset.plate);return;}
    if(event.target.closest('[data-reading-mode]')){if(dialog.open)await closeDialog();continuous();return;}
    const link=event.target.closest('a[href^="#"]');
    if(!link || !active || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const glowOption = !!link.closest('.glow-submenu');
    if(glowOption) window.BookSounds?.play('peek');
    const id=link.hash.slice(1);
    if(sheetIDs.has(id) || id.startsWith('note-')) { event.preventDefault();openSheet(id,!glowOption);return; }
    const target=resolveHash(link.hash);
    if(target!==null) { event.preventDefault();if(dialog.open) await closeDialog();go(target);stage.focus({preventScroll:true}); }
    else if(id==='manuscript') { event.preventDefault();stage.focus(); }
  });
  document.addEventListener('keydown',event=>{
    if(!active || dialog.open || window.PublicImageViewer?.isOpen() || event.defaultPrevented || event.altKey || event.ctrlKey || event.metaKey || event.target.closest('input,textarea,select,[contenteditable],video')) return;
    if(event.key==='ArrowRight' || event.key==='PageDown') {event.preventDefault();go(current+1);}
    if(event.key==='ArrowLeft' || event.key==='PageUp') {event.preventDefault();go(current-1);}
    if(event.key==='Home') {event.preventDefault();go(0);}
    if(event.key==='End') {event.preventDefault();go(pages.length-1);}
  });
  window.addEventListener('hashchange',()=>{
    if(!active) return;
    if(sheetIDs.has(location.hash.slice(1)) || location.hash.startsWith('#note-')) {openSheet(location.hash.slice(1));return;}
    const index=resolveHash(location.hash);if(index!==null) go(index,false);
  });
  window.addEventListener('resize',()=>{
    if(dialog.open && dialog.classList.contains('binding-dialog'))positionSheet();
    if(!active || Math.abs(innerWidth-lastWidth)<2) return; // Mobile address-bar height changes must not repaginate.
    clearTimeout(resizeTimer);resizeTimer=setTimeout(function resizeBook(){if(navigationRunning){resizeTimer=setTimeout(resizeBook,180);return;}initialize(location.hash);},180);
  });
  reducedMotion.addEventListener('change',()=>{if(active) initialize(location.hash);});

  async function prepareRadio() {
    const dial=document.querySelector('#radio-frequency');
    const readout=document.querySelector('#radio-frequency-readout');
    const marks=document.querySelector('#radio-station-marks');
    const audio=document.querySelector('#book-audio');
    // Playback survives opening/closing sheets and turning leaves.
    audio.removeAttribute('controls');audio.hidden=true;document.body.append(audio);
    const play=document.querySelector('#radio-play'), skip=document.querySelector('#radio-next');
    const now=document.querySelector('#radio-now'), message=document.querySelector('#radio-message');
    const description=document.querySelector('#station-description'), tracks=document.querySelector('#radio-tracks');
    const pocket=document.querySelector('#radio-pocket');
    const controls=document.createElement('div');controls.className='radio-sliders';
    controls.innerHTML='<label for="radio-seek">Song position <output id="radio-time">0:00</output></label><input id="radio-seek" type="range" min="0" max="100" step="0.1" value="0" aria-label="Song position"><label for="radio-volume">Volume</label><input id="radio-volume" type="range" min="0" max="1" step="0.01" value="0.6">';
    play.parentElement.after(controls);
    const seek=controls.querySelector('#radio-seek'),volume=controls.querySelector('#radio-volume'),time=controls.querySelector('#radio-time');
    let stations=[],stationIndex=-1,trackIndex=0,isBreak=false,powered=false;
    // The playout plan: songs come out of a shuffled bag, a few at a time, and the DJ cuts in between blocks.
    let plan=null,warmer=null;
    const rand=n=>Math.floor(Math.random()*n);
    const clampBlock=size=>Math.min(size,Math.max(1,stations[stationIndex]?.tracks.length||1));
    const openingBlock=()=>clampBlock(2+rand(2));
    const laterBlock=()=>clampBlock([1,2,2,3,3][rand(5)]);
    const dayPart=hour=>hour>=5&&hour<8?'dawn':hour>=8&&hour<17?'day':hour>=17&&hour<21?'dusk':'night';
    function freshPlan(){plan={bag:[],recent:[],blockSize:openingBlock(),sinceBreak:0,heard:new Set(),lastCategory:'',upNext:null};}
    freshPlan();
    audio.volume=.6;play.disabled=true;skip.disabled=true;
    const format=seconds=>Math.floor(seconds/60)+':'+String(Math.floor(seconds%60)).padStart(2,'0');
    function announce() {
      play.textContent=powered?'Switch the Radio off':'Switch the Radio on';
      play.setAttribute('aria-pressed',String(powered));
      pocket.hidden=!powered;
      pocket.querySelector('span').textContent=stations[stationIndex]?.name || 'Radio';
      document.querySelector('.tab-radio').classList.toggle('is-playing',powered);
      skip.disabled=stationIndex<0;
      seek.disabled=stationIndex<0;
    }
    async function listen(item,asBreak=false) {
      isBreak=asBreak;
      message.textContent=stations[stationIndex]?.hidden?'UNLISTED TRANSMISSION · Signal origin withheld.':(asBreak&&item.caption?item.caption:'');
      audio.loop=false;
      audio.src=item.src || item.blessedSrc;
      now.textContent=asBreak?stations[stationIndex].host+' · on air':item.title+' · '+item.artist;
      seek.value=0;time.textContent='0:00';
      tracks.querySelectorAll('button').forEach((button,index)=>{
        if(!asBreak && index===trackIndex)button.setAttribute('aria-current','true');else button.removeAttribute('aria-current');
      });
      try {await audio.play();}catch(error){if(error.name!=='AbortError'){powered=false;message.textContent='The signal couldn’t start. Switch on to try again.';}}
      announce();
    }
    function nearestFrequency(frequency) {
      // The old cabinet's pirate signal lives on one unmarked tenth of FM.
      const hidden=stations.findIndex(station=>station.hidden && Math.abs(station.freq-frequency)<.051);
      if(hidden>=0)return hidden;
      let found=-1,distance=.50001;
      stations.forEach((station,index)=>{
        const gap=Math.abs(station.freq-frequency);
        if(!station.hidden && gap<distance){found=index;distance=gap;}
      });
      return found;
    }
    async function staticSignal() {
      audio.loop=true;isBreak=false;
      audio.src='./assets/audio/radio-free-margin-static.m4a';
      try{await audio.play();}catch(error){if(error.name!=='AbortError'){powered=false;message.textContent='Switch the Radio on to hear the signal.';}}
      announce();
    }
    function startSignal() {
      if(stationIndex<0){staticSignal();return;}
      const station=stations[stationIndex];
      plan.sinceBreak=0;plan.blockSize=openingBlock();plan.upNext=null;
      const ids=(station.banters||[]).filter(b=>b.category==='stationID' && bantersFit(b));
      if(ids.length){const id=ids[rand(ids.length)];plan.lastCategory='stationID';listen(id,true);warm(station.tracks[peekSong()]);}
      else advance();
    }
    function bantersFit(banter){
      const c=banter.conditions;if(!c)return true;
      if(Object.keys(c).some(key=>key!=='timeOfDay' && key!=='weekdays'))return false;
      const now=new Date();
      if(c.timeOfDay && !c.timeOfDay.includes(dayPart(now.getHours())))return false;
      if(c.weekdays && !c.weekdays.includes(now.getDay()+1))return false; // 1 = Sunday, as the app counts
      return true;
    }
    function refillBag(){
      const n=stations[stationIndex].tracks.length,order=[...Array(n).keys()];
      for(let i=n-1;i>0;i--){const j=rand(i+1);[order[i],order[j]]=[order[j],order[i]];}
      // The songs just played sit at the back of the new shuffle, so nothing comes round again at once.
      const recent=plan.recent.slice(-Math.min(2,n-1));
      plan.bag=[...order.filter(i=>recent.includes(i)),...order.filter(i=>!recent.includes(i))];
    }
    function peekSong(){if(!plan.bag.length)refillBag();return plan.bag[plan.bag.length-1];}
    function warm(item){
      // Quietly fetch what comes next so the cut is clean; skipped on Data Saver.
      const src=item?.src || item?.blessedSrc;
      if(!src || navigator.connection?.saveData)return;
      if(!warmer){warmer=new Audio();warmer.preload='auto';}
      if(warmer.getAttribute('src')!==src)warmer.src=src;
    }
    function chooseBreak(justPlayed,upcoming){
      const station=stations[stationIndex];
      const pool=(station.banters||[]).filter(b=>b.category!=='stationID' && bantersFit(b) && (!b.track ||
        (b.placement==='outro' && b.track===justPlayed?.title) || (b.placement==='intro' && b.track===upcoming?.title)));
      if(!pool.length)return null;
      let fresh=pool.filter(b=>!plan.heard.has(b.id));
      if(!fresh.length){pool.forEach(b=>plan.heard.delete(b.id));fresh=pool;}   // the bag emptied: shuffle it again
      const varied=fresh.filter(b=>b.category!==plan.lastCategory);
      if(varied.length)fresh=varied;
      const bound=fresh.filter(b=>b.track);                                      // a break about the song beside it lands best
      if(bound.length && Math.random()<.7)fresh=bound;
      let roll=Math.random()*fresh.reduce((sum,b)=>sum+(b.weight||1),0);
      return fresh.find(b=>(roll-=(b.weight||1))<0) || fresh[fresh.length-1];
    }
    function playSong(index){
      const station=stations[stationIndex];
      plan.bag=plan.bag.filter(i=>i!==index);plan.recent=[...plan.recent.slice(-2),index];plan.sinceBreak++;trackIndex=index;
      const after=peekSong();
      plan.upNext=plan.sinceBreak>=plan.blockSize?chooseBreak(station.tracks[index],station.tracks[after]):null;
      listen(station.tracks[index]);
      warm(plan.upNext||station.tracks[after]);
    }
    function playBreak(banter){
      const station=stations[stationIndex];
      plan.heard.add(banter.id);plan.lastCategory=banter.category;plan.sinceBreak=0;
      plan.blockSize=laterBlock();
      listen(banter,true);warm(station.tracks[peekSong()]);
    }
    function advance(){
      // Whatever just ended or was skipped, the plan decides what's next: a DJ cut, or the next song in the shuffle.
      if(plan.upNext){const banter=plan.upNext;plan.upNext=null;playBreak(banter);return;}
      playSong(peekSong());
    }
    function tuneFrequency() {
      const frequency=Number(dial.value),index=nearestFrequency(frequency);
      readout.textContent=frequency.toFixed(1)+' FM';
      document.querySelector('#station-needle').style.left=((frequency-88)/20*100)+'%';
      dial.setAttribute('aria-valuetext',frequency.toFixed(1)+' FM · '+(stations[index]?.name || 'Static between stations'));
      if(index===stationIndex && dial.dataset.ready)return;
      dial.dataset.ready='true';
      audio.pause();audio.removeAttribute('src');audio.load();
      audio.loop=false;
      stationIndex=index;trackIndex=0;isBreak=false;freshPlan();
      const station=stations[index];
      document.querySelector('#radio-player').classList.toggle('is-pirate',!!station?.hidden);
      description.textContent=station?.tagline || 'Keep turning. Something might be hiding in the noise.';
      now.textContent=station?station.name+' · '+station.host:'Static between stations.';
      message.textContent=station?.hidden?'UNLISTED TRANSMISSION · Signal origin withheld.':'';
      seek.value=0;time.textContent='0:00';
      tracks.replaceChildren(...(station?.tracks || []).map((track,idx)=>{
        const li=document.createElement('li'),button=document.createElement('button');button.type='button';
        button.textContent=track.title;button.addEventListener('click',()=>{window.BookSounds?.select();powered=true;plan.sinceBreak=0;plan.blockSize=openingBlock();playSong(idx);});li.append(button);return li;
      }));
      announce();if(powered)startSignal();
    }
    dial.addEventListener('input',tuneFrequency);
    play.addEventListener('click',async()=>{
      window.BookSounds?.play('tap');
      powered=!powered;
      if(!powered){audio.pause();announce();return;}
      startSignal();
    });
    skip.addEventListener('click',()=>{window.BookSounds?.select();powered=true;advance();});
    audio.addEventListener('ended',()=>{if(!powered || stationIndex<0)return;advance();});
    audio.addEventListener('play',announce);audio.addEventListener('pause',announce);
    audio.addEventListener('error',()=>{powered=false;message.textContent='That recording couldn’t be reached. Try another frequency.';announce();});
    audio.addEventListener('timeupdate',()=>{
      if(stationIndex<0)return;
      if(Number.isFinite(audio.duration) && audio.duration>0){seek.value=String(audio.currentTime/audio.duration*100);time.textContent=format(audio.currentTime)+' / '+format(audio.duration);}
    });
    seek.addEventListener('input',()=>{if(Number.isFinite(audio.duration))audio.currentTime=Number(seek.value)/100*audio.duration;});
    volume.addEventListener('input',()=>{audio.volume=Number(volume.value);});
    pocket.addEventListener('click',()=>{if(active)openSheet('radio-player');else document.querySelector('#radio-player').scrollIntoView();});
    try {
      const response=await fetch('./radio-stations.json');if(!response.ok)throw new Error('Radio catalogue unavailable');
      stations=await response.json();
      stations=stations.map(station=>({...station,tracks:station.tracks.filter(track=>track.src || track.blessedSrc)})).filter(station=>station.tracks.length);
      if(!stations.length)throw new Error('No recordings');
      marks.replaceChildren(...stations.filter(station=>!station.hidden).map(station=>{
        const button=document.createElement('button');button.type='button';button.className='reading-option';
        button.textContent=station.freq.toFixed(1);button.title=station.name;button.setAttribute('aria-label',station.freq.toFixed(1)+' FM · '+station.name);
        button.addEventListener('click',()=>{dial.value=station.freq;window.BookSounds?.select();tuneFrequency();});return button;
      }));
      play.disabled=false;dial.disabled=false;tuneFrequency();
    }catch{dial.disabled=true;message.textContent='The frequencies couldn’t be found. Reload the page to try again.';}
  }
  async function start() {
    try {
      await document.fonts.ready;
      initialize();
      if(sheetIDs.has(location.hash.slice(1)) || location.hash.startsWith('#note-')) openSheet(location.hash.slice(1));
    } catch(error) {
      console.error('The bound edition could not open; the complete reading edition is available.',error);
      room.hidden=true;document.body.classList.remove('book-active');active=false;
    }
  }
  // The Radio costs nothing until someone reaches for it: no catalogue fetch, no audio, no listeners.
  let radioPrepared=null;
  const loadRadio=()=>radioPrepared||(radioPrepared=prepareRadio());
  const radioSheet=document.getElementById('radio-player');
  if(radioSheet && 'IntersectionObserver' in window){
    const watcher=new IntersectionObserver(entries=>{if(entries.some(entry=>entry.isIntersecting)){watcher.disconnect();loadRadio();}},{rootMargin:'300px'});
    watcher.observe(radioSheet);
  }
  const radioTab=document.querySelector('.tab-radio');
  ['pointerenter','focus','touchstart'].forEach(type=>radioTab?.addEventListener(type,loadRadio,{once:true,passive:true}));
  window.addEventListener('hashchange',()=>{if(location.hash==='#radio-player')loadRadio();});
  start();
})();
