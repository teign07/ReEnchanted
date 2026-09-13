/* Small, authored encounters. No model, network request, or archive import.
 * Reader excerpts: maker's sealed Book, 2026-09-11. The two ordinary sentences
 * are reader-authored; “This one…” is Book prose. The map is an adaptation.
 * Mission: saved Temperature Border invitation. Dare: WickerDareRegistry.
 */
(() => {
  'use strict';
  const key='reenchanted-public-ink-v1';
  let saved={};
  try { saved=JSON.parse(sessionStorage.getItem(key)||'{}')||{}; } catch {}
  const seed=Number.isInteger(saved.seed)?saved.seed:Math.floor(Math.random()*0x7fffffff);
  let sentence=typeof saved.sentence==='string'?saved.sentence.slice(0,220):'';
  let draft=sentence, steps=Number(saved.steps)||0, lastVisit='', returnChapter=typeof saved.returnChapter==='string'?saved.returnChapter:'', capturedAt=Number(saved.capturedAt)||0;
  const outcomes=new Map(Array.isArray(saved.outcomes)?saved.outcomes.filter(x=>Array.isArray(x)&&['mission','dare'].includes(x[0])):[]);
  function persist() { try { sessionStorage.setItem(key,JSON.stringify({seed,sentence,steps,capturedAt,returnChapter,outcomes:[...outcomes]})); } catch {} }
  persist();
  const mark=(name)=>`<img class="encounter-mark" src="./assets/book/${name}.webp" alt="" width="110" height="110">`;
  const note=(text)=>`<p class="encounter-source">${text}</p>`;
  const form=`<form data-capture-form><label>One thing you noticed<textarea name="sentence" rows="3" maxlength="220" placeholder="The cats are staring at me." required></textarea></label><button type="submit" class="ink-button">Keep this sentence</button><p data-capture-status role="status" class="capture-receipt"></p></form><p class="encounter-source">Only in this tab. Never sent. Erase it in Capture.</p>`;
  const slips={
    write:{title:'A little room for your ink',html:`${mark('MarginaliaGoblinWritingCrouched')}<p class="eyebrow">Your turn, if you like</p><h2>Catch one bright little thing.</h2><p>A crooked lamp. A suspicious cat. One thing you can see from here.</p>${form}<p class="encounter-permission">Or leave the paper empty. Turn on.</p>`},
    kept:{title:'One ordinary morning',html:`${mark('MarginaliaFeather')}<p class="eyebrow">A sentence from the maker’s Book</p><h2>A morning, kept.</h2><blockquote class="kept-sentence">Just chilling this morning when I would usually be working; it’s amazing.</blockquote>${note('The reader’s own words, kept on a Plain Page.')}<p class="encounter-permission">That was enough to give me.</p>`},
    mission:{title:'Temperature Border',html:`${mark('MarginaliaCompass')}<p class="eyebrow">A Wonder Compass mission</p><h2>Temperature Border</h2><p>Find the spot in your home where the temperature changes. That is a border. Borders have guards; identify yours.</p><p class="encounter-permission">A real invitation from the app. Try it wherever it suits you, or keep reading.</p><button class="ink-button" type="button" data-encounter-done="mission">I found a border</button><p class="capture-receipt" data-outcome="mission" role="status"></p>`},
    dare:{title:'A word for the outside',html:`${mark('MarginaliaScrap')}<p class="eyebrow">Wicker has got in</p><h2>Throw a Word Outside</h2><p>Open a window or door. Say one word you love loudly enough for the outside to hear it. One word. Properly launched. Shut the door before it answers.</p><p class="encounter-permission">Only if it suits where you are. Wicker can bear a refusal.</p><button class="ink-button" type="button" data-encounter-done="dare">The word is out</button><p class="capture-receipt" data-outcome="dare" role="status"></p>${note('An authored dare from the app. — Wicker Eddies')}`},
    map:{title:'A border worth drawing',html:`<p class="eyebrow">An ordinary place, redrawn</p><h2>A toll in treats.</h2><img class="encounter-map" src="./assets/book/temperature-border.svg" alt="An imaginary border on a staircase: cooler air above, warmer air below, and two cats guarding the crossing for treats." width="420" height="390">${note('Illustrated from the maker’s Temperature Border response. A playful adaptation, not a geographic map.')}<p class="encounter-permission">The guards have declined to accept coins.</p>`},
    cats:{title:'Something looked back',html:`${mark('MarginaliaGoblinShushing')}<p class="eyebrow">The reader’s own words</p><blockquote class="kept-sentence large-sentence">The cats are staring at me.</blockquote>${note('A souvenir from the maker’s Book.')}<p class="encounter-permission">One sentence. Nothing needed tidying.</p>`},
    remembered:{title:'I chose a favorite',html:`${mark('MarginaliaSeal')}<p class="eyebrow">I brought this back</p><h2>I chose a favorite.</h2><blockquote class="kept-sentence">Just chilling this morning when I would usually be working; it’s amazing.</blockquote><div class="book-reply"><p>This one.</p><p>It’s small and exact. It doesn’t waste a word.</p></div>${note('A real returned Page: the reader’s sentence above, my response below. Prepared here from the maker’s Book.')}`},
    return:{title:'A sentence can return',html:`${mark('MarginaliaGoblinReading')}<div data-returned-ink><p class="eyebrow">Some things come back</p><h2>A little room kept open.</h2><p>Give me a sentence in Capture. I’ll put it somewhere you weren’t expecting.</p><a class="ink-button" href="#capture">Leave a sentence</a></div>${note('Here, your words return unchanged. The website does not interpret them.')}`}
  };
  function composition(type) { return `<div class="quiet-composition encounter-composition" data-encounter="${type}">${slips[type].html}</div>`; }
  const loose=['mission','dare','map'];
  let random=seed;
  for(let i=loose.length-1;i>0;i--){random=(Math.imul(random,1664525)+1013904223)>>>0;const j=random%(i+1);[loose[i],loose[j]]=[loose[j],loose[i]];}
  const quiet=[...document.querySelectorAll('#manuscript > [data-kind="quiet"]')];
  const placements=[[1,'write'],[3,'kept'],[5,loose[0]],[8,loose[1]],[10,loose[2]],[12,'cats'],[15,'remembered'],[18,'return']];
  for(const [index,type] of placements){
    const source=quiet[index];if(!source)continue;
    // Keep the old quiet-leaf anchors valid for existing bookmarks.
    source.innerHTML=`<span id="encounter-${type}" class="encounter-anchor"></span>`+composition(type);
    source.dataset.chapter=slips[type].title;
    source.dataset.encounter=type;
  }
  function clearReturnedInk(message='I’m keeping a little room here.'){
    document.querySelectorAll('[data-returned-ink]').forEach(el=>{
      el.replaceChildren();
      const eyebrow=document.createElement('p');eyebrow.className='eyebrow';eyebrow.textContent='The paper is yours again';
      const line=document.createElement('p');line.textContent=message;
      el.append(eyebrow,line);
    });
  }
  function hydrate(root=document){
    if(sentence && returnChapter){
      root.querySelectorAll('.folio-leaf.is-quiet').forEach(page=>{if(page.dataset.chapter===returnChapter && !page.querySelector('[data-returned-ink]'))page.querySelector('.leaf-content').innerHTML=composition('return');});
    }
    root.querySelectorAll('[data-capture-form] textarea,[data-capture-form] button').forEach(control=>{control.disabled=false;});
    root.querySelectorAll('[data-capture-form] textarea').forEach(input=>{if(input!==document.activeElement)input.value=draft;});
    root.querySelectorAll('[data-capture-status]').forEach(el=>{el.textContent=sentence?'Kept. Turn a few leaves. I’ll find a place for it.':'';});
    root.querySelectorAll('[data-outcome]').forEach(el=>{el.textContent=outcomes.get(el.dataset.outcome)||'';});
    root.querySelectorAll('[data-echo]').forEach(el=>{
      const done=outcomes.has(el.dataset.echo);
      el.querySelector('[data-if-done]').hidden=!done;
      el.querySelector('[data-if-waiting]').hidden=done;
    });
    root.querySelectorAll('[data-returned-ink]').forEach(el=>{
      if(!sentence || steps-capturedAt<3)return;
      el.replaceChildren();
      const eyebrow=document.createElement('p');eyebrow.className='eyebrow';eyebrow.textContent='Your own words. Back again.';
      const quote=document.createElement('blockquote');quote.className='kept-sentence';quote.textContent=sentence;
      const aside=document.createElement('p');aside.textContent='I kept this corner for you.';
      const erase=document.createElement('button');erase.type='button';erase.className='reading-option';erase.dataset.eraseInk='';erase.textContent='Erase my ink';
      el.append(eyebrow,quote,aside,erase);
    });
  }
  document.addEventListener('input',event=>{if(event.target.matches('[data-capture-form] textarea'))draft=event.target.value.slice(0,220);});
  document.addEventListener('submit',event=>{
    const form=event.target.closest('[data-capture-form]');if(!form)return;
    event.preventDefault();const input=form.querySelector('textarea');if(!input.value.trim()){input.setCustomValidity('A few words will do.');input.reportValidity();return;}
    input.setCustomValidity('');sentence=input.value.slice(0,220);draft=sentence;capturedAt=steps;returnChapter='';clearReturnedInk();persist();hydrate();
  });
  document.addEventListener('input',event=>{if(event.target.matches('[data-capture-form] textarea'))event.target.setCustomValidity('');});
  document.addEventListener('click',event=>{
    const done=event.target.closest('[data-encounter-done]');
    if(done){outcomes.set(done.dataset.encounterDone,done.dataset.encounterDone==='mission'?'A border, then. You can keep the guard to yourself.':'Good. It belongs to the outside now.');persist();hydrate();}
    if(event.target.closest('[data-erase-ink]')){
      sentence='';draft='';returnChapter='';persist();
      clearReturnedInk('Gone. You can leave another sentence in Capture, or let this leaf stay quiet.');
      hydrate();document.querySelectorAll('[data-capture-status]').forEach(el=>el.textContent='Your ink is erased.');
    }
  });
  window.PublicEdition={hydrate,composition,seed,getSentence:()=>sentence,visit(page,index){
    const visit=page.dataset.chapter+'~'+index;
    if(visit!==lastVisit){steps++;lastVisit=visit;}
    if(sentence && steps-capturedAt>=3 && page.classList.contains('is-quiet')){
      const content=page.querySelector('.leaf-content');
      const eligible=!content.querySelector('[data-encounter]') || content.querySelector('[data-encounter="return"]');
      if(eligible && (!returnChapter || returnChapter===page.dataset.chapter)){
        returnChapter=page.dataset.chapter;content.innerHTML=composition('return');
      }
    }
    persist();hydrate(page);
  }};
  hydrate();
})();
