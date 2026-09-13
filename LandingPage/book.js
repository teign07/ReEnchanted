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
  let lastWidth = 0, resizeTimer, dialogReturnFocus = null;
  let closingDialog = null, navigationRunning = false, queuedNavigation = null, finishTurn = null, isRiffling = false;
  const dialog = document.createElement('dialog');
  dialog.className = 'paper-dialog';
  dialog.setAttribute('aria-label', 'Notes in the Book');
  dialog.innerHTML = '<button class="dialog-close" type="button" aria-label="Close and return to the Book">×</button><div class="dialog-body"></div>';
  document.body.append(dialog);
  const dialogBody = dialog.querySelector('.dialog-body');
  let borrowed = null, borrowedPlace = null;

  function restoreSheet() {
    if (borrowed) { borrowedPlace.replaceWith(borrowed); borrowed = null; }
    document.querySelectorAll('.binding-tabs a').forEach(link=>link.setAttribute('aria-expanded','false'));
  }
  function positionSheet() {
    const rect=stage.getBoundingClientRect();
    const width=Math.min(dialog.classList.contains('is-glow')?370:440,innerWidth-28);
    const left=Math.max(14,Math.min(innerWidth-width-14,rect.right-width+24));
    const top=Math.max(20,Math.min(rect.top+12,innerHeight-340));
    dialog.style.setProperty('--sheet-left',left+'px');
    dialog.style.setProperty('--sheet-top',top+'px');
    dialog.style.setProperty('--sheet-width',width+'px');
    dialog.style.setProperty('--tucked-x',(rect.left+rect.width/2-left-width/2)+'px');
  }
  function closeDialog() {
    if(closingDialog) return closingDialog;
    if(!dialog.open) return Promise.resolve();
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
    restoreSheet();
    document.body.style.overflow = '';
    dialogReturnFocus?.focus({ preventScroll: true });
  });
  async function openSheet(id) {
    const source = document.getElementById(id);
    if (!source) return false;
    if (dialog.open) await closeDialog();
    dialogReturnFocus = document.activeElement;
    borrowed = source;
    borrowedPlace = document.createComment('The open sheet returns here.');
    source.replaceWith(borrowedPlace);
    dialogBody.replaceChildren(source);
    dialog.classList.add('binding-dialog');
    dialog.classList.toggle('is-glow',id==='glow');
    positionSheet();
    document.querySelectorAll('.binding-tabs a').forEach(link=>link.setAttribute('aria-expanded',String(link.hash==='#'+id)));
    dialog.setAttribute('aria-label', source.querySelector('h2')?.textContent || 'Notes in the Book');
    dialog.showModal();
    window.PublicEdition?.hydrate(dialog);
    if(!reducedMotion.matches) dialog.animate([{transform:'translateX(var(--tucked-x)) scale(.96)',opacity:0},{transform:'translateX(56px)',opacity:1,offset:.65},{transform:'translateX(0)',opacity:1}],{duration:560,easing:'cubic-bezier(.2,.7,.2,1)'});
    dialog.scrollTop = 0;
    document.body.style.overflow = 'hidden';
    return true;
  }

  async function openPlate(name) {
    const source = manuscript.querySelector(`[data-plate="${name}"] img`);
    if (!source) return;
    if (dialog.open) await closeDialog();
    dialog.classList.remove('binding-dialog','is-glow');
    dialogReturnFocus = document.activeElement;
    const figure = document.createElement('figure'); figure.className='enlarged-plate';
    const img=source.cloneNode();img.loading='eager';figure.append(img);
    const caption=document.createElement('figcaption');caption.textContent=source.alt;figure.append(caption);
    dialogBody.replaceChildren(figure);dialog.setAttribute('aria-label',source.alt);
    dialog.showModal();document.body.style.overflow='hidden';
  }

  // Blocks are semantic units, not screenshots. Paragraph splits preserve inline links.
  const atomic = new Set(['P','H1','H2','H3','H4','H5','FIGURE','VIDEO','HR']);
  const phrasing = new Set(['A','SPAN','STRONG','EM','B','I','SMALL','BR','CITE','SUP','SUB','IMG']);
  function blocksFrom(element, inherited = []) {
    const ids = [...inherited, ...(element.id ? [element.id] : [])];
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
    node.querySelectorAll('img').forEach(img => { img.draggable = false; });
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
    if (node.matches('figure,video,.title-page') || node.querySelector('img,video,input,button')) return null;
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
    const measure = document.createElement('div'); measure.className = 'pagination-measure';
    measure.style.width = stage.style.width; measure.style.height = stage.style.height;
    document.body.append(measure);
    try {
      for (const chapter of chapters) {
        const queue = [...chapter.children].flatMap(child => blocksFrom(child));
        anchors.set(chapter.id,pages.length);
        let leaf = makeLeaf(chapter), content = leaf.querySelector('.leaf-content');
        function mount() { leaf.style.width = stage.style.width; leaf.style.height = stage.style.height; measure.replaceChildren(leaf); }
        function finish() { if(content.children.length) pages.push(leaf); leaf=makeLeaf(chapter,true); content=leaf.querySelector('.leaf-content'); mount(); }
        mount();
        for (let index=0;index<queue.length;index++) {
          const block=queue[index];
          const node=removeDuplicateIds(block.node.cloneNode(true));
          content.append(node);
          if (['cover','title','quiet','composed'].includes(chapter.dataset.kind)) { collectAnchors(block,pages.length); continue; }
          // Keep a heading with the beginning of the following paragraph.
          if (fits(content) && node.matches('h1,h2,h3,h4,.eyebrow') && queue[index+1]) {
            const probe=document.createElement('p'); probe.textContent=queue[index+1].node.textContent.slice(0,110); content.append(probe);
            const orphan=!fits(content); probe.remove();
            if(orphan && content.children.length>1) { node.remove(); finish(); content.append(node); }
          }
          if (!fits(content)) {
            node.remove();
            if (content.children.length && (node.matches('h1,h2,h3,h4,figure,video') || node.textContent.length<250)) finish();
            let split=splitToFit(node,content);
            if(split) {
              collectAnchors(block,pages.length); content.append(split[0]);
              queue.splice(index+1,0,{node:split[1],ids:[]}); finish(); continue;
            }
            if(content.children.length) finish();
            content.append(node);
            if(!fits(content)) {
              node.remove(); split=splitToFit(node,content);
              if(split) { collectAnchors(block,pages.length);content.append(split[0]);queue.splice(index+1,0,{node:split[1],ids:[]});finish();continue; }
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
      const marks=['MarginaliaGoblinReading','MarginaliaFeather','MarginaliaGoblinWritingCrouched','MarginaliaStar','MarginaliaLavender','MarginaliaGoblinSleeping'];
      pages.forEach((page,index)=>{
        if(page.matches('.is-title,.is-quiet,.is-composed,.is-cover') || index%3!==1) return;
        measure.replaceChildren(page);
        const field=page.querySelector('.leaf-content');
        const last=field.lastElementChild;
        if(!last || field.style.overflowY) return;
        const bottom=last.getBoundingClientRect().bottom-field.getBoundingClientRect().top;
        const available=field.clientHeight-bottom-20;
        if(available<65) return;
        const mark=document.createElement('img');mark.className='page-marginalia';
        mark.src='./assets/book/'+marks[index%marks.length]+'.webp';mark.alt='';mark.setAttribute('aria-hidden','true');mark.loading='lazy';mark.draggable=false;
        mark.style.height=Math.min(104,available)+'px';
        mark.style.top=(field.offsetTop+bottom+14)+'px';
        mark.style.right=(index%2?35:55)+'px';
        mark.style.rotate=(index%2?-5:4)+'deg';
        page.append(mark);
      });
    } finally { measure.remove(); }
  }
  function updateState(index, writeHistory = true) {
    current=Math.max(0,Math.min(pages.length-1,index));
    previous.disabled=current===0; next.disabled=current===pages.length-1;
    next.setAttribute('aria-label',pages[current].dataset.chapter==='first-parting'?'Continue into the complete information chapters':'Next page');
    stage.classList.toggle('is-closed',pages[current].classList.contains('is-cover'));
    document.querySelector('#turn-hint').textContent=pages[current].classList.contains('is-cover')?'Open the cover. There’s a Book inside.':'Drag a page corner, or use the arrows.';
    const firstCount=pages.filter(page=>page.dataset.reading || page.matches('.is-title,.is-cover')).length;
    const inReference=pages[current].dataset.reference==='true';
    position.textContent=pages[current].dataset.title+' · '+(inReference?'The complete chapters':String(current+1).padStart(2,'0')+' / '+firstCount);
    const returnLink=document.querySelector('.reading-return');
    if(returnLink){returnLink.hidden=!inReference;returnLink.href='#'+(window.PublicEdition?.readingBookmark||'first-arrival');}
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
  async function go(index, animate = true) {
    index=Math.max(0,Math.min(pages.length-1,index));
    if(!active) return;
    if(navigationRunning){queuedNavigation={index,animate};return;}
    if(index===current) return;
    if(animate && !reducedMotion.matches && (pages[current].classList.contains('is-cover') || pages[index].classList.contains('is-cover'))){
      navigationRunning=true;
      const opening=pages[current].classList.contains('is-cover');
      const board=pages[opening?current:index].querySelector('.monthly-cover-face').cloneNode(true);
      board.classList.add('cover-flight');board.inert=true;board.setAttribute('aria-hidden','true');stage.append(board);
      stage.classList.add('is-opening-cover');
      if(opening){if(pager)pager.turnToPage(index);else updateState(index,false);}
      const motion=board.animate([
        {transform:opening?'rotateY(0deg)':'rotateY(-105deg)',filter:opening?'brightness(1)':'brightness(.45)'},
        {transform:opening?'rotateY(-105deg)':'rotateY(0deg)',filter:opening?'brightness(.45)':'brightness(1)'}
      ],{duration:850,easing:'cubic-bezier(.22,.5,.17,1)',fill:'forwards'});
      try{await motion.finished.catch(()=>{});}finally{
        if(pager)pager.turnToPage(index);updateState(index);
        board.remove();stage.classList.remove('is-opening-cover');navigationRunning=false;
        if(queuedNavigation){const queued=queuedNavigation;queuedNavigation=null;go(queued.index,queued.animate);}
      }
      return;
    }
    if(pager && animate && !reducedMotion.matches && index===current-1){
      navigationRunning=true;
      const render=pager.getRender(),controller=pager.getFlipController();
      const collection=pager.getPageCollection(),spread=collection.getCurrentSpreadIndex();
      const bounds=render.getRect(),w=bounds.pageWidth,h=bounds.height;
      // Reverse the successful forward curl of the PREVIOUS leaf, with the
      // current leaf underneath. The native backward mode translates a phantom
      // left spread across the spine, so it cannot produce this unrolling fold.
      render.finishAnimation();
      collection.setCurrentSpreadIndex(spread-1);
      const nativeCheck=controller.checkDirection;
      let started;
      try{
        controller.checkDirection=()=>true;
        started=controller.start({x:bounds.left+2*w-2,y:h-2});
      }finally{
        controller.checkDirection=nativeCheck;
        collection.setCurrentSpreadIndex(spread);
      }
      folio.classList.add('is-returning-curl');
      try{
        if(started){
          controller.setState('flipping');
          const frames=Array.from({length:90},(_,i)=>()=>{
            const t=i/89,eased=t*t*(3-2*t);
            controller.do({x:-w+(2*w-1)*eased,y:h-Math.sin(Math.PI*eased)*h*.16});
          });
          await new Promise(resolve=>{
            const timer=setTimeout(()=>{render.finishAnimation();resolve();},1150);
            render.startAnimation(frames,850,()=>{clearTimeout(timer);resolve();});
          });
        }
      }finally{
        render.setBottomPage(null);render.setFlippingPage(null);render.clearShadow();controller.reset();
        pager.turnToPage(index);controller.setState('read');
        folio.classList.remove('is-returning-curl');navigationRunning=false;updateState(index);
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
    const aliases={top:'cover',book:'first-arrival','encounter-write':'first-write','encounter-mission':'first-mission','encounter-dare':'first-dare','encounter-map':'first-map','encounter-kept':'first-kept','encounter-remembered':'first-remembered'};
    const key=aliases[id]||id;
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
    folio.replaceChildren(...pages);
    const plainMotion=reducedMotion.matches || !window.St?.PageFlip;
    document.body.classList.toggle('is-reduced-motion',plainMotion);
    if(!plainMotion) {
      pager=new St.PageFlip(folio,{width,height,size:'fixed',usePortrait:true,autoSize:false,startPage:current,drawShadow:true,maxShadowOpacity:.4,flippingTime:850,showCover:false,mobileScrollSupport:true,useMouseEvents:true,showPageCorners:true,disableFlipByClick:true,swipeDistance:35,clickEventForward:true});
      pager.on('flip',event=>{ if(!rebuilding) updateState(event.data); });
      pager.on('changeState',event=>{if(event.data==='read' && !rebuilding) {updateState(pager.getCurrentPageIndex(),false);finishTurn?.();}});
      pager.loadFromHTML(pages);
      // Swipe and left-corner drags use the same returning curl as Previous.
      pager.flipPrev=()=>go(current-1);
      const controller=pager.getFlipController();
      const nativeFold=controller.fold.bind(controller),nativeCorner=controller.showCorner.bind(controller);
      controller.fold=point=>{
        if(navigationRunning)return;
        if(pager.getState()==='user_fold'){nativeFold(point);return;}
        if(controller.getDirectionByPoint(pager.getRender().convertToBook(point))===1)go(current-1);
        else nativeFold(point);
      };
      controller.showCorner=point=>{if(!navigationRunning && controller.getDirectionByPoint(pager.getRender().convertToBook(point))!==1)nativeCorner(point);};
      const nativeStop=pager.userStop.bind(pager);
      pager.userStop=(point,swipe)=>{if(navigationRunning){pager.isUserTouch=false;pager.isUserMove=false;return;}nativeStop(point,swipe);};
    }
    active=true;document.body.classList.add('book-active');
    modeButton.hidden=false;modeButton.textContent='Read as one page';
    lastWidth=innerWidth;rebuilding=false;
    updateState(current,false);
  }
  function continuous() {
    active=false;room.hidden=true;document.body.classList.remove('book-active');
    modeButton.textContent='Read as a Book';
    const id=pages[current]?.dataset.chapter;
    if(id) document.getElementById(id)?.scrollIntoView({block:'start'});
  }
  previous.addEventListener('click',()=>go(current-1));next.addEventListener('click',()=>go(current+1));
  modeButton.addEventListener('click',()=>{if(active) continuous();else{initialize('#'+(pages[current]?.dataset.chapter||'frontispiece'));stage.focus({preventScroll:true});window.scrollTo(0,0);}});
  document.addEventListener('click',async event=>{
    const plate=event.target.closest('[data-plate]');
    if(plate){event.preventDefault();openPlate(plate.dataset.plate);return;}
    if(event.target.closest('[data-reading-mode]')){if(dialog.open)await closeDialog();continuous();return;}
    const link=event.target.closest('a[href^="#"]');
    if(!link || !active || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const id=link.hash.slice(1);
    if(sheetIDs.has(id) || id.startsWith('note-')) { event.preventDefault();openSheet(id);return; }
    const target=resolveHash(link.hash);
    if(target!==null) { event.preventDefault();if(dialog.open) await closeDialog();go(target);stage.focus({preventScroll:true}); }
    else if(id==='manuscript') { event.preventDefault();stage.focus(); }
  });
  document.addEventListener('keydown',event=>{
    if(!active || dialog.open || event.defaultPrevented || event.altKey || event.ctrlKey || event.metaKey || event.target.closest('input,textarea,select,[contenteditable],video')) return;
    if(event.key==='ArrowRight' || event.key==='PageDown') {event.preventDefault();go(current+1);}
    if(event.key==='ArrowLeft' || event.key==='PageUp') {event.preventDefault();go(current-1);}
    if(event.key==='Home') {event.preventDefault();go(0);}
    if(event.key==='End') {event.preventDefault();go(pages[current].dataset.reference?pages.length-1:(anchors.get('first-parting')??pages.length-1));}
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
    const select=document.querySelector('#station-select');
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
    let stations=[],stationIndex=0,trackIndex=0,isBreak=false;
    audio.volume=.6;play.disabled=true;skip.disabled=true;
    const format=seconds=>Math.floor(seconds/60)+':'+String(Math.floor(seconds%60)).padStart(2,'0');
    function announce() {
      const playing=!audio.paused;
      play.textContent=playing?'Pause the Radio':audio.src?'Keep listening':'Tune in';
      play.setAttribute('aria-pressed',String(playing));
      pocket.hidden=!playing;
      pocket.querySelector('span').textContent=stations[stationIndex]?.name || 'Radio';
      document.querySelector('.tab-radio').classList.toggle('is-playing',playing);
    }
    async function listen(item,asBreak=false) {
      isBreak=asBreak;message.textContent='';
      audio.src=item.src || item.blessedSrc;
      now.textContent=asBreak?stations[stationIndex].host+' · on air':item.title+' · '+item.artist;
      seek.value=0;time.textContent='0:00';
      tracks.querySelectorAll('button').forEach((button,index)=>{
        if(!asBreak && index===trackIndex)button.setAttribute('aria-current','true');else button.removeAttribute('aria-current');
      });
      try {await audio.play();}catch(error){if(error.name!=='AbortError')message.textContent='The signal couldn’t start. Press play to try again.';}
      announce();
    }
    function tune(index,resume=false) {
      audio.pause();audio.removeAttribute('src');audio.load();
      stationIndex=index;trackIndex=0;isBreak=false;
      const station=stations[index];
      select.value=String(index);description.textContent=station.tagline;
      document.querySelector('#station-needle').style.left=((station.freq-88)/20*100)+'%';
      now.textContent=station.freq.toFixed(1)+' FM · '+station.host;message.textContent='';
      seek.value=0;time.textContent='0:00';
      tracks.replaceChildren(...station.tracks.map((track,idx)=>{
        const li=document.createElement('li'),button=document.createElement('button');button.type='button';
        button.textContent=track.title;button.addEventListener('click',()=>{trackIndex=idx;listen(track);});li.append(button);return li;
      }));
      announce();if(resume)listen(station.tracks[0]);
    }
    function nextSong(){trackIndex=(trackIndex+1)%stations[stationIndex].tracks.length;listen(stations[stationIndex].tracks[trackIndex]);}
    select.addEventListener('change',()=>tune(Number(select.value),!audio.paused));
    play.addEventListener('click',async()=>{
      if(!audio.paused){audio.pause();return;}
      if(!audio.getAttribute('src')){
        const station=stations[stationIndex];
        const intro=station.banters.find(b=>b.category==='stationID' && !b.conditions);
        listen(intro || station.tracks[trackIndex],!!intro);return;
      }
      try{await audio.play();message.textContent='';}catch{message.textContent='The signal couldn’t start. Try another song.';}
    });
    skip.addEventListener('click',()=>{if(isBreak){listen(stations[stationIndex].tracks[trackIndex]);}else nextSong();});
    audio.addEventListener('ended',()=>{if(isBreak){listen(stations[stationIndex].tracks[trackIndex]);}else nextSong();});
    audio.addEventListener('play',announce);audio.addEventListener('pause',announce);
    audio.addEventListener('error',()=>{message.textContent='That recording couldn’t be reached. Try another song.';announce();});
    audio.addEventListener('timeupdate',()=>{
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
      select.replaceChildren(...stations.map((station,index)=>new Option(station.freq.toFixed(1)+' FM · '+station.name,String(index))));
      play.disabled=false;skip.disabled=false;tune(0);
    }catch{select.replaceChildren(new Option('Radio unavailable',''));select.disabled=true;message.textContent='The frequencies couldn’t be found. Reload the page to try again.';}
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
  prepareRadio();
  start();
})();
