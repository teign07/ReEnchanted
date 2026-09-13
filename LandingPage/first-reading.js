/* A composed first reading. Every branch is authored; no AI or remote ink. */
(() => {
  'use strict';
  const edition=window.PublicEdition;
  if(!edition)return;
  const manuscript=document.querySelector('#manuscript');
  const original=[...manuscript.children].filter(section=>section.dataset.kind!=='cover');
  // The title page and the opening chapter are the Book introducing itself.
  // The composed reading follows them; everything after that is reference.
  const opening=new Set(['frontispiece','about','between-how']);
  original.forEach(section=>{if(!opening.has(section.id))section.dataset.reference='true';});
  const mark=name=>`<img class="reading-mark" src="./assets/book/${name}.webp" alt="" width="130" height="130">`;
  const link=(id,text)=>`<a class="reading-option" href="#${id}">${text} <span aria-hidden="true">↗</span></a>`;
  const plate=(file,alt)=>`<img class="reading-plate" src="./assets/book/${file}.webp" alt="${alt}" loading="lazy">`;
  const leaves=[];
  function leaf(id,title,html,theme='ink') { leaves.push({id,title,html,theme}); }
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
  leaf('first-anyway','What your sky is doing',`${mark('MarginaliaStar')}<p class="eyebrow">There’s a real day outside this tab</p><h2>Let me look<br>at your sky.</h2><p>I can’t see you from here. I can see what the weather’s doing where you are, if you point me at it once.</p><p>That’s the kind of thing I keep: real, dated, yours. It goes on the Page beside whatever you write.</p><p class="kept-sentence" data-sky-line hidden></p><button type="button" class="reading-option" data-read-sky>Let this Page read my weather</button><p class="reading-whisper">Only if you choose: your browser’s location is sent to Open-Meteo for the weather. It isn’t kept by this website.</p><p class="capture-receipt" data-sky-status role="status"></p>`,'day');
  encounter('write');
  hush('first-hush',0);
  encounter('cats');
  encounter('remembered');
  leaf('first-how','Find it. Keep it.',`${mark('MarginaliaFeather')}<p class="eyebrow">How the app works</p><h2>Bring me something<br>that happened.</h2><ol class="reading-steps"><li><strong>Notice.</strong> A detail from your life, or the world around you.</li><li><strong>Capture.</strong> One sentence, a photograph, an audio note, or something shared from another app.</li><li><strong>Keep.</strong> It becomes part of your Book. Or trash it and let it go.</li></ol><p>Nothing big has to happen. Breakfast is allowed in.</p>${link('how','All the ways to begin')}`);
  leaf('first-night','The day becomes a tale',`${mark('MarginaliaGoblinSleeping')}<p class="eyebrow">While you’re asleep</p><h2>At night I<br>braid your day.</h2><p>I take everything you kept. Your sentence, the photograph, the weather, whatever you chose in the story I was telling you.</p><p>I set them beside each other, see what they know about one another, and write the day out as a scene. It’s here by morning.</p><p>Never the same shape twice. A portrait of somebody you kept mentioning. A vigil, if you spent the day waiting.</p><p class="reading-whisper">This website uses prepared Pages. Your sentence stays in this tab and returns unchanged.</p>${link('nightly-braid','Read about the nightly braid')}`,'night');
  encounter('dare');
  hush('first-wait',4);
  leaf('first-wicker-echo','A scrap from Wicker',`${mark('MarginaliaScrap')}<p class="eyebrow">Wicker left this</p><div data-echo="dare"><div data-if-done hidden><h2><span data-dare-word-echo>The word</span> got out.</h2><p>Good. Keep the door shut a moment. It has never been outside by itself before.</p><p>You can have your respectable voice back now.</p></div><div data-if-waiting><h2>Still in there?</h2><p>Your word, I mean.</p><p>Keep it until there’s a good place to let it loose. I’m not collecting obedience.</p></div></div><p class="reading-whisper">An authored reply, written for this public edition. Wicker hasn’t heard or interpreted your word.</p>${link('note-wicker-eddies','Who let Wicker in?')}`,'wicker');
  leaf('first-world','Somewhere to wander',`${plate('GreatHall','The app’s illustrated Academy Great Hall')}<p class="eyebrow">The Academy</p><h2>The rooms have opinions.</h2><p>So do the professors. Wicker lives here too, when he isn’t getting out. There are lessons, dares, stories, and a Radio you can leave on while you wander.</p><p>Come in whenever you like. Then take something useful back outside.</p><div class="reading-links">${link('academy','Visit the Academy')}${link('radio-player','Turn the Radio on')}</div>`,'world');
  leaf('first-compass','The Wonder Compass',`${mark('MarginaliaCompass')}<p class="eyebrow">A whole book inside me</p><h2>There are reasons<br>for the mischief.</h2><p>I carry the whole <em>Wonder Compass</em>: 26 chapters about getting back into wonder, with more than 300 citations. It’s already in here. You don’t pay for it.</p><p>Read it offline. Try something. Argue with it. A field guide should get muddy.</p>${link('ebook','Open the Wonder Compass chapter')}`);
  leaf('first-paper','A life, bound in paper',`${mark('MarginaliaSeal')}<p class="eyebrow">The Bindery</p><h2>You can close<br>the screen.</h2><p>What you keep can become a paper Book. A week. A month. A season. A year.</p><p>Something with weight. Something you can put into another pair of hands.</p><p>The digital Book is free. Printed editions and optional extras have their own prices.</p><div class="reading-links">${link('editions','See the editions')}${link('plans','What costs what')}</div>`,'paper');
  leaf('first-privacy','What stays yours',`${mark('MarginaliaGoblinShushing')}<p class="eyebrow">A boundary in the binding</p><h2>Your life<br>isn’t the display.</h2><p>The ordinary sentences here came out of the maker’s own Book. He lent them to me so I’d have something true to show you.</p><p>Yours stays where you put it. The sentence you left is kept only in this browser tab. It isn’t sent to a model or added to anybody else’s Book, and Capture will erase it the moment you ask.</p><p>A souvenir is yours to download if you choose.</p>${link('privacy','Read the app’s privacy details')}`);
  leaf('first-parting','Take something with you',`${mark('MarginaliaGoblinWritingCrouched')}<p class="eyebrow">That’ll do for a beginning</p><h2>The next Page<br>is outside.</h2><p>Look at one familiar thing until it stops being only its name.</p><p>Take a little Page with you. It’ll hold your sentence, if you left one. If you didn’t, I’ve put an invitation on it instead.</p><button type="button" class="ink-button" data-souvenir>Take this Page</button><p class="capture-receipt" data-souvenir-status role="status"></p><div class="reading-links">${link('invitation','Tell me when the app opens')}${link('contents','There’s more in the binding')}</div>`,'parting');
  const fragment=document.createDocumentFragment();
  for(const item of leaves){const section=document.createElement('section');section.id=item.id;section.dataset.chapter=item.title;section.dataset.kind=item.theme==='hush'?'quiet':'composed';section.dataset.reading='true';section.dataset.theme=item.theme;section.innerHTML=item.theme==='encounter'?item.html:`<div class="reading-composition">${item.html}</div>`;fragment.append(section);}
  (manuscript.querySelector('#between-how')||original[0]).after(fragment);
  original[0].querySelector('.ink-button').href='#about';
  const contents=document.querySelector('#contents');
  const nav=contents.querySelector('nav');
  const details=document.createElement('details');details.className='full-contents';details.innerHTML='<summary>All the chapters · the complete information Book</summary>';nav.before(details);details.append(nav);
  const route=document.createElement('nav');route.setAttribute('aria-label','A first reading');route.innerHTML=[['first-arrival','Begin here'],['first-how','How the app works'],['first-dare','Take a little dare'],['first-world','The Academy & Radio'],['first-paper','Paper Books & prices'],['first-privacy','What stays yours'],['first-parting','Take a Page with you']].map(([id,text])=>`<a href="#${id}"><strong>${text}</strong><span aria-hidden="true">↗</span></a>`).join('');details.before(route);
  const back=document.createElement('a');back.className='reading-return';back.href='#first-arrival';back.textContent='↶ Back to the first reading';back.hidden=true;document.querySelector('#reading-room').append(back);
  edition.hydrate();
})();
