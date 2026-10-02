/* A composed first reading. Every branch is authored; no AI or remote ink. */
(() => {
  'use strict';
  const edition=window.PublicEdition;
  if(!edition)return;
  const manuscript=document.querySelector('#manuscript');
  const original=[...manuscript.children].filter(section=>section.dataset.kind!=='cover');
  // Let the Book introduce itself before asking the Reader for anything.
  // The complete manuscript and longer encounters stay in the binding.
  const opening=new Set(['frontispiece','about']);
  original.forEach(section=>{if(!opening.has(section.id))section.dataset.reference='true';});
  const mark=name=>`<img class="reading-mark" src="./assets/book/${name}.webp" alt="" width="130" height="130">`;
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
  function hush(id,offset){const [art,words]=quietPool[(edition.seed+offset)%quietPool.length];leaf(id,'Between the Pages',`${mark(art)}<p class="hush-line">${words}</p>`,'hush');}
  leaf('first-arrival','I fight Routine',`${mark('MarginaliaGoblinReading')}<p class="eyebrow">Now the part I care about</p><h2>I fight Routine.</h2><p>It keeps telling you that you’ve seen all this before.</p><p>Your street. Your breakfast. The people you love. You know their names. That isn’t the same as looking at them.</p><p>I’m a Book for your iPhone or iPad. Give me little pieces of your life. I’ll help you look again.</p><p class="reading-whisper">The digital Book is free. These Pages will show you a little of what I do.</p>`,'arrival');
  leaf('first-curse','The Rut of Routine',`<p class="eyebrow">Who we’re up against</p><h2>The world didn’t<br>go grey.</h2><p>You got very good at getting through it.</p><p>It’s a useful skill and it eats everything. Soon every day is just the next thing that needs doing.</p><p>That’s the Curse. It’s called the Rut of Routine, and it’s the habit of walking past your own life. Grey is only its weather.</p><p>We can interrupt it. A sentence is a small enough crowbar.</p>${link('curse','More about the Curse')}`,'curse');
  leaf('first-anyway','What your sky is doing',`${mark('MarginaliaStar')}<p class="eyebrow">There’s a real day outside this tab</p><h2>Let me look<br>at your sky.</h2><p>Point me at your sky once. I’ll put its weather beside whatever you write.</p><p class="kept-sentence" data-sky-line hidden></p><button type="button" class="reading-option" data-read-sky>Let this Page read my weather</button><p class="reading-whisper">Only if you choose: your browser’s location is sent to Open-Meteo for the weather. It isn’t kept by this website.</p><p class="capture-receipt" data-sky-status role="status"></p>`,'day');
  encounter('write');
  leaf('first-return','Tonight, braided',`<p class="eyebrow">That night</p><h2>Tonight, I braid it.</h2><div class="story-tale"><blockquote class="story-quote" data-story-quote-slot></blockquote><p data-story-tale="magic"></p><p data-story-tale="back" hidden></p><p data-story-tale="hook" hidden></p><p data-story-sky hidden></p></div><div data-sky-once class="story-sky-offer"><button type="button" class="reading-option" data-read-sky data-sky-label="Add my real sky">Add my real sky</button><span class="reading-whisper">Only if you choose. Your location goes to Open-Meteo once, for the weather.</span><span class="capture-receipt" data-sky-status role="status"></span></div><p class="reading-whisper" data-opening-source>An authored scene. Only in this tab.</p><div class="story-actions"><a class="reading-option" href="#invitation">Send me the app invite ↗</a><span data-opening-ink hidden><button type="button" class="reading-option" data-erase-ink>Erase my ink</button></span></div>`,'return');
  // Use the existing, explicitly invented public demonstration. Its receipts
  // and excerpt come from the full braid chapter, not a second copy of it.
  const proofSource=manuscript.querySelector('#nightly-braid');
  const proofDay=[...proofSource.querySelectorAll('.braid-receipt-list > li')];
  const proofParagraphs=[...proofSource.querySelectorAll('.braid-night-copy > p')];
  const receipts=`<li><span class="proof-time">Eight days earlier</span>${proofSource.querySelector('.braid-memory-slip p').innerHTML}</li><li><span class="proof-time">Today</span>${proofDay[2].querySelector('p').innerHTML}</li>`;
  const tale=proofParagraphs[0].outerHTML;
  leaf('first-proof','A Tuesday, braided',`<p class="eyebrow">What the app makes of a day</p><h2>A Tuesday, braided.</h2><p class="reading-whisper proof-provenance">An invented day from the public example. Your trial sentence isn’t used in it.</p><div data-proof-panel="before"><p class="proof-label">What the Reader kept</p><ul class="opening-receipts">${receipts}</ul><button type="button" class="ink-button" data-proof-view="after">Read what came back ↗</button></div><div data-proof-panel="after" hidden><p class="proof-label">A passage from that night’s tale</p>${tale}<div class="reading-links"><button type="button" class="reading-option" data-proof-view="before">Look at the kept Pages again</button>${link('nightly-braid','Read the whole day and its return')}</div></div>`,'proof');
  hush('first-hush',0);
  encounter('cats');
  encounter('remembered');
  story('magic','Is it magic?');
  story('back','Say it back');
  leaf('first-how','Find it. Keep it.',`${mark('MarginaliaFeather')}<p class="eyebrow">How the app works</p><h2>Bring me something<br>that happened.</h2><ol class="reading-steps"><li><strong>Notice.</strong> A detail from your life, or the world around you.</li><li><strong>Capture.</strong> One sentence, a photograph, an audio note, or something shared from another app.</li><li><strong>Keep.</strong> It becomes part of your Book. Or trash it and let it go.</li></ol><p>Nothing big has to happen. Breakfast is allowed in.</p>${link('how','All the ways to begin')}`);
  leaf('first-night','The day becomes a tale',`${mark('MarginaliaGoblinSleeping')}<p class="eyebrow">While you’re asleep</p><h2>At night I<br>braid your day.</h2><p>I take everything you kept. Your sentence, the photograph, the weather, whatever you chose in the story I was telling you.</p><p>I set them beside each other, see what they know about one another, and write the day out as a scene. It’s here by morning.</p><p class="story-echo" data-story-echo="magic" hidden></p><p>Never the same shape twice. A portrait of somebody you kept mentioning. A vigil, if you spent the day waiting.</p><p class="reading-whisper">This website uses prepared Pages. Your sentence stays in this tab and returns unchanged.</p>${link('nightly-braid','Read about the nightly braid')}`,'night');
  encounter('dare');
  hush('first-wait',4);
  leaf('first-wicker-echo','A scrap from Wicker',`${mark('MarginaliaScrap')}<p class="eyebrow">Wicker left this</p><div data-echo="dare"><div data-if-done hidden><h2><span data-dare-word-echo>The word</span> got out.</h2><p>Good. Keep the door shut a moment. It has never been outside by itself before.</p><p>You can have your respectable voice back now.</p></div><div data-if-waiting><h2>Still in there?</h2><p>Your word, I mean.</p><p>Keep it until there’s a good place to let it loose. I’m not collecting obedience.</p></div></div><p class="story-echo" data-story-stance hidden></p><p class="reading-whisper">An authored reply, written for this public edition. Wicker hasn’t heard or interpreted your word.</p>${link('note-wicker-eddies','Who let Wicker in?')}`,'wicker');
  leaf('first-world','Somewhere to wander',`${plate('GreatHall','The app’s illustrated Academy Great Hall')}<p class="eyebrow">The Academy</p><h2>The rooms have opinions.</h2><p>So do the professors. Wicker lives here too, when he isn’t getting out. There are lessons, dares, stories, and a Radio you can leave on while you wander.</p><p>Come in whenever you like. Then take something useful back outside.</p><div class="reading-links">${link('academy','Visit the Academy')}${link('radio-player','Turn the Radio on')}</div>`,'world');
  story('bargain','A bargain, offered');
  leaf('first-compass','The Wonder Compass',`${mark('MarginaliaCompass')}<p class="eyebrow">A whole book inside me</p><h2>There are reasons<br>for the mischief.</h2><p>I carry the whole <em>Wonder Compass</em>: 26 chapters about getting back into wonder, with more than 300 citations. It’s already in here. You don’t pay for it.</p><p>Read it offline. Try something. Argue with it. A field guide should get muddy.</p>${link('ebook','Open the Wonder Compass chapter')}`);
  leaf('first-paper','A life, bound in paper',`<p class="eyebrow">The same day, given a body</p><h2>And then, paper.</h2><figure class="opening-spread"><button type="button" class="plate-button" data-plate="FirstEdition" aria-label="Look closer at the printed Book"><img src="./assets/editions/open-monthly-braid-spread.jpg" width="1536" height="1024" alt="Product mockup of a monthly Book: a scrapbook Page beside What the Return Slot Gave Back, the braid from the public example"></button><figcaption>A product mockup at the real 6 × 9 trim size.</figcaption></figure><p>A week. A year with your name on the spine. Your days get to stay.</p><p class="reading-whisper">Free digital Books. Optional paid paper. <a href="#editions">See editions &amp; prices.</a></p>${link('invitation','Send me the app invite')}`,'paper');
  leaf('first-privacy','What stays yours',`${mark('MarginaliaGoblinShushing')}<p class="eyebrow">A boundary in the binding</p><h2>Your life<br>isn’t the display.</h2><p>The ordinary sentences here came out of the maker’s own Book. He lent them to me so I’d have something true to show you.</p><p>Yours stays where you put it. The sentence you left is kept only in this browser tab. It isn’t sent to a model or added to anybody else’s Book, and Capture will erase it the moment you ask.</p><p>A souvenir is yours to download if you choose.</p>${link('privacy','Read the app’s privacy details')}`);
  leaf('first-parting','Take something with you',`<p class="eyebrow">That’ll do for a beginning</p><h2>I want a Tuesday<br>of yours.</h2><p>A sentence was enough to start. Imagine what we could keep in a week.</p><a class="ink-button" href="#invitation">Send me the app invite ↗</a><p class="reading-whisper">In development for iPhone &amp; iPad. Join the list for a free TestFlight invite when it opens.</p><button type="button" class="reading-option" data-souvenir>Take a Page with you</button><p class="capture-receipt" data-souvenir-status role="status"></p><p class="reading-whisper">Your sentence, or an invitation. Yours to keep.</p>${link('contents','Keep wandering through the binding')}`,'parting');
  // After the original introduction: participation, consequence,
  // transformation, paper, invitation.
  const readingOrder=[
    'first-write','first-magic','first-back','first-return','first-proof','first-paper','first-parting'
  ];
  const longerOrder=['first-arrival','first-curse','first-how','first-night','first-anyway','first-world','first-cats','first-compass','first-hush','first-remembered','first-privacy','first-dare','first-wicker-echo','first-bargain','first-wait'];
  const orderedLeaves=[...readingOrder,...longerOrder].map(id=>leaves.find(item=>item.id===id));
  if(orderedLeaves.includes(undefined)||orderedLeaves.length!==leaves.length)throw new Error('The first reading has a missing or extra Page.');
  const editions=manuscript.querySelector('#editions');
  const editionsPause=manuscript.querySelector('#between-editions');
  if(!editions||!editionsPause)throw new Error('The illustrated editions chapter is missing.');
  const fragment=document.createDocumentFragment();
  for(const item of orderedLeaves){const section=document.createElement('section');section.id=item.id;section.dataset.chapter=item.title;section.dataset.kind=item.theme==='hush'?'quiet':'composed';const primary=readingOrder.includes(item.id);if(primary)section.dataset.reading='true';else section.dataset.reference='true';section.dataset.theme=item.theme;section.innerHTML=(item.theme==='encounter'||item.theme==='story')?item.html:`<div class="reading-composition">${item.html}</div>`;fragment.append(section);}
  manuscript.querySelector('#about').after(fragment);
  manuscript.querySelector('#frontispiece .ink-button').href='#about';
  const contents=document.querySelector('#contents');
  const nav=contents.querySelector('nav');
  const details=document.createElement('details');details.className='full-contents';details.innerHTML='<summary>All the chapters · the complete information Book</summary>';nav.before(details);details.append(nav);
  const route=document.createElement('nav');route.setAttribute('aria-label','A first reading');route.innerHTML=[['about','Begin · meet the Book'],['first-write','Leave a sentence'],['first-magic','Is it magic?'],['first-return','Your morning, braided'],['first-proof','See a day become a tale'],['first-paper','The day, bound in paper'],['first-parting','The app invite & your Page']].map(([id,text])=>`<a href="#${id}"><strong>${text}</strong><span aria-hidden="true">↗</span></a>`).join('');details.before(route);
  const wander=document.createElement('nav');wander.setAttribute('aria-label','More in the binding');wander.innerHTML=[['first-arrival','Meet the Book'],['first-how','How the app works'],['first-world','The Academy & Radio'],['first-remembered','A real sentence, returned'],['first-dare','Let Wicker get you outside'],['first-bargain','A bargain, offered'],['first-hush','What today is doing'],['first-privacy','What stays yours'],['editions','All the Books & prices']].map(([id,text])=>`<a href="#${id}"><strong>${text}</strong><span aria-hidden="true">↗</span></a>`).join('');details.before(wander);
  const back=document.createElement('a');back.className='reading-return';back.href='#about';back.textContent='↶ Back to the first reading';back.hidden=true;document.querySelector('#reading-room').append(back);
  document.addEventListener('click',event=>{
    const button=event.target.closest('[data-proof-view]');if(!button)return;
    const composition=button.closest('.reading-composition');
    composition.querySelectorAll('[data-proof-panel]').forEach(panel=>{panel.hidden=panel.dataset.proofPanel!==button.dataset.proofView;});
    window.BookSounds?.select();
    const shown=composition.querySelector('[data-proof-panel]:not([hidden])');
    shown.querySelector('button')?.focus({preventScroll:true});
  });
  edition.hydrate();
})();
