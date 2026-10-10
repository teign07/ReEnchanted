/* A composed first reading. Every branch is authored; no AI or remote ink. */
(() => {
  'use strict';
  const edition=window.PublicEdition;
  if(!edition)return;
  const manuscript=document.querySelector('#manuscript');
  const original=[...manuscript.children].filter(section=>section.dataset.kind!=='cover');
  // The full information chapters and authored Book Pages share one binding.
  const mark=name=>{
    const id=name.replace(/([a-z])([A-Z])/g,'$1-$2').toLowerCase();
    const src=window.PublicMarginalia?.marks.find(drawing=>drawing.id===id)?.src || `./assets/book/${name}.webp`;
    return `<img class="reading-mark" src="${src}" alt="" width="130" height="130">`;
  };
  const link=(id,text)=>`<a class="reading-option" href="#${id}">${text} <span aria-hidden="true">↗</span></a>`;
  const plate=(file,alt)=>`<img class="reading-plate" src="./assets/book/${file}.webp" alt="${alt}" loading="lazy">`;
  const leaves=[];
  function leaf(id,title,html,theme='ink') { leaves.push({id,title,html,theme}); }
  function story(id,title){leaf('first-'+id,title,window.PublicStoryPages?window.PublicStoryPages.composition(id):'','story');}
  function encounter(type){leaf('first-'+type,({write:'A little room for your ink',kept:'A morning, kept',cats:'Something looked back',remembered:'Something came back',mission:'Find a border',dare:'Wicker has got in',map:'The guards'})[type],edition.composition(type),'encounter');}
  const quietPool=[
    ['MarginaliaGoblinSleeping','The paper has stopped talking. Let it.'],
    ['MarginaliaLavender','Something outside me is moving.'],
    ['MarginaliaGoblinShushing','A small silence. I found it between two words.'],
    ['MarginaliaFeather','You may look away. I know where we are.'],
    ['MarginaliaStar','The ceiling is also available for looking at.'],
    ['MarginaliaScrap','There’s no question on this Page.']
  ];
  // A Page whose whole job is the TestFlight list. Same Buttondown list as #invitation;
  // the source tells us which Page the Reader said yes on.
  function invite(id,title,art,html,button){
    leaf(id,title,`${mark(art)}${html}<form class="invite-leaf-form" data-invite-form action="https://buttondown.com/api/emails/embed-subscribe/potions" method="post" target="_blank"><input type="hidden" name="embed" value="1"><input type="hidden" name="tag" value="testflight"><input type="hidden" name="metadata__source" value="public-edition-${id}"><label for="${id}-email">Your email</label><input id="${id}-email" type="email" name="email" required autocomplete="email" placeholder="you@example.com"><button class="ink-button" type="submit">${button} ↗</button></form><p class="capture-receipt" data-invite-status role="status"></p>`+
      /* slip:start */`<p class="reading-whisper">Free TestFlight invite, iPhone &amp; iPad. Your email goes to Buttondown, only for that. <a href="#invitation">What you’ll need</a></p>`/* slip:end */,'invite');
  }
  function hush(id,offset){const [art,words]=quietPool[(edition.seed+offset)%quietPool.length];leaf(id,'Between the Pages',`${mark(art)}<p class="hush-line">${words}</p>`,'hush');}
  leaf('first-anyway','What your sky is doing',`${mark('MarginaliaStar')}<p class="eyebrow">There’s a real day outside this tab</p><h2>Let me look<br>at your sky.</h2><p>Point me at your sky once. I’ll put its weather beside whatever you write.</p><p class="kept-sentence" data-sky-line hidden></p><button type="button" class="reading-option" data-read-sky>Let this Page read my weather</button><p class="reading-whisper">Only if you choose: your browser’s location is sent to Open-Meteo for the weather. It isn’t kept by this website.</p><p class="capture-receipt" data-sky-status role="status"></p>`,'day');
  encounter('write');
  leaf('first-return','Tonight, braided',`<p class="eyebrow">That night</p><h2>Tonight, I braid it.</h2><div class="story-tale"><blockquote class="story-quote" data-story-quote-slot></blockquote><p data-story-tale="magic"></p><p data-story-tale="back" hidden></p><p data-story-tale="hook" hidden></p><p data-story-sky hidden></p></div><div data-sky-once class="story-sky-offer"><button type="button" class="reading-option" data-read-sky data-sky-label="Add my real sky">Add my real sky</button><span class="reading-whisper">Only if you choose. Your location goes to Open-Meteo once, for the weather.</span><span class="capture-receipt" data-sky-status role="status"></span></div><p class="reading-whisper" data-opening-source>An authored scene. Only in this tab.</p><div class="story-actions"><a class="reading-option" href="#invitation">Send me the app invite ↗</a><span data-opening-ink hidden><button type="button" class="reading-option" data-erase-ink>Erase my ink</button></span></div>`,'return');
  // Use the saved October simulation from the public demonstration. Its receipts
  // and excerpt come from the full braid chapter, not a second copy of it.
  const proofSource=manuscript.querySelector('#nightly-braid');
  const proofDay=[...proofSource.querySelectorAll('.braid-receipt-list > li')];
  const memory=proofSource.querySelector('.braid-memory-slip');
  const today=proofDay.find(receipt=>receipt.hasAttribute('data-proof-receipt'));
  const receipts=`<li><span class="proof-time">${memory.querySelector('span').textContent}</span>${memory.querySelector('p').innerHTML}</li><li><span class="proof-time">${today.querySelector('span').textContent}</span>${today.querySelector('p').innerHTML}</li>`;
  const tale=`<p>${proofSource.querySelector('.braid-night-copy [data-proof-excerpt]').innerHTML}</p>`;
  leaf('first-proof','A Friday, braided',`<p class="eyebrow">What the app makes of a day</p><h2>A Friday, braided.</h2><p class="reading-whisper proof-provenance">From our October app simulation. Your trial sentence isn’t used in it.</p><div data-proof-panel="before"><p class="proof-label">What the Reader kept</p><ul class="opening-receipts">${receipts}</ul><button type="button" class="ink-button" data-proof-view="after">Read what came back ↗</button></div><div data-proof-panel="after" hidden><p class="proof-label">A passage from that night’s tale</p>${tale}<div class="reading-links"><button type="button" class="reading-option" data-proof-view="before">Look at the kept Pages again</button>${link('nightly-braid','Read the whole day and its return')}</div></div>`,'proof');
  hush('first-hush',0);
  encounter('cats');
  encounter('remembered');
  story('magic','Is it magic?');
  story('back','Say it back');
  encounter('dare');
  hush('first-wait',4);
  leaf('first-wicker-echo','A scrap from Wicker',`${mark('MarginaliaScrap')}<p class="eyebrow">Wicker left this</p><div data-echo="dare"><div data-if-done hidden><h2><span data-dare-word-echo>The word</span> got out.</h2><p>Good. Keep the door shut a moment. It has never been outside by itself before.</p><p>You can have your respectable voice back now.</p></div><div data-if-waiting><h2>Still in there?</h2><p>Your word, I mean.</p><p>Keep it until there’s a good place to let it loose. I’m not collecting obedience.</p></div></div><p class="story-echo" data-story-stance hidden></p><p class="reading-whisper">An authored reply, written for this public edition. Wicker hasn’t heard or interpreted your word.</p>${link('note-wicker-eddies','Who let Wicker in?')}`,'wicker');
  story('bargain','A bargain, offered');
  invite('first-yes','Say yes','MarginaliaSeal',`<p class="eyebrow">I meant it</p><h2>Let me be<br>your Book.</h2><p>I’m not open yet. A few Readers get to come in first and fight the Curse with me while I’m new. Leave your email. When testing starts, I’ll come and find you.</p>`,'Send me the TestFlight invite');
  invite('first-yours','The next one is yours','MarginaliaFeather',`<p class="eyebrow">That was somebody else’s month</p><h2>The next one<br>could be yours.</h2><p>That was a pretend Reader from our October test. I’d rather make yours: your Tuesdays, your street, your name on the spine. You can have me when testing starts.</p>`,'I want my own Book');
  leaf('first-parting','Take something with you',`<p class="eyebrow">That’ll do for a beginning</p><h2>I want a Tuesday<br>of yours.</h2><p>A sentence was enough to start. Imagine what we could keep in a week.</p><a class="ink-button" href="#invitation">Send me the app invite ↗</a><p class="reading-whisper">In development for iPhone &amp; iPad. Join the list for a free TestFlight invite when it opens.</p><button type="button" class="reading-option" data-souvenir>Take a Page with you</button><p class="capture-receipt" data-souvenir-status role="status"></p><p class="reading-whisper">Your sentence, or an invitation. Yours to keep.</p>${link('contents','Keep wandering through the binding')}`,'parting');
  // Full chapters, with one or two Book Pages between each topic.
  // The science, physical editions, gifts and subscription all come first.
  // Story choices still precede their replies and the braid that remembers them.
  const readingOrder=[
    'frontispiece','about','first-yes','curse','first-write','first-magic',
    'editions','sample-issues','first-yours','gifting','plans','first-back','first-cats',
    'how','first-anyway','first-return',
    'nightly-braid','first-proof','between-nightly-braid',
    'pagewright','between-pagewright','between-editions',
    'film','between-curse','between-how',
    'belief','first-bargain','between-belief',
    'mechanics','first-dare','between-mechanics',
    'craft','first-wicker-echo','between-craft',
    'pages','between-pages',
    'systems','first-remembered','between-systems',
    'academy','between-academy',
    'radio','between-radio',
    'ebook','between-ebook',
    'packs','first-hush','between-packs',
    'search','between-search',
    'community','between-community','between-plans',
    'privacy','between-privacy',
    'promises','between-promises',
    'download','first-wait','between-download',
    'colophon','between-colophon','first-parting'
  ];
  const chapters=new Map(original.map(section=>[section.id,section]));
  for(const item of leaves){const section=document.createElement('section');section.id=item.id;section.dataset.chapter=item.title;section.dataset.kind=item.theme==='hush'?'quiet':'composed';section.dataset.theme=item.theme;section.innerHTML=(item.theme==='encounter'||item.theme==='story')?item.html:`<div class="reading-composition">${item.html}</div>`;chapters.set(item.id,section);}
  if(new Set(readingOrder).size!==readingOrder.length||readingOrder.length!==chapters.size||readingOrder.some(id=>!chapters.has(id)))throw new Error('The reading has a missing, extra or repeated chapter.');
  const fragment=document.createDocumentFragment();
  for(const id of readingOrder){const section=chapters.get(id);delete section.dataset.reference;section.dataset.reading='true';fragment.append(section);}
  manuscript.append(fragment);
  manuscript.querySelector('#frontispiece .ink-button').href='#about';
  const contents=document.querySelector('#contents');
  const nav=contents.querySelector('nav');
  nav.setAttribute('aria-label','Book contents');
  const encounterThemes=new Set(['encounter','story','return','proof','wicker','day','parting']);
  nav.innerHTML=readingOrder.map(id=>chapters.get(id)).filter(section=>section.dataset.kind!=='title'&&section.dataset.kind!=='quiet'&&(section.dataset.kind!=='composed'||encounterThemes.has(section.dataset.theme))).map(section=>`<a href="#${section.id}"><strong>${section.dataset.chapter}</strong><span aria-hidden="true">↗</span></a>`).join('');
  document.addEventListener('click',event=>{
    const button=event.target.closest('[data-proof-view]');if(!button)return;
    const composition=button.closest('.reading-composition');
    composition.querySelectorAll('[data-proof-panel]').forEach(panel=>{panel.hidden=panel.dataset.proofPanel!==button.dataset.proofView;});
    window.BookSounds?.select();
    const shown=composition.querySelector('[data-proof-panel]:not([hidden])');
    shown.querySelector('button')?.focus({preventScroll:true});
  });
  document.addEventListener('submit',event=>{
    const form=event.target.closest('[data-invite-form]');if(!form)return;
    const status=form.parentElement.querySelector('[data-invite-status]');
    if(status)status.textContent='Look in the new tab. Buttondown may ask you to confirm your email first.';
  });
  edition.hydrate();
})();
