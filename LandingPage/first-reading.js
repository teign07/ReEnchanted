/* A composed first reading. Every branch is authored; no AI or remote ink. */
(() => {
  'use strict';
  const edition=window.PublicEdition;
  if(!edition)return;
  const manuscript=document.querySelector('#manuscript');
  const original=[...manuscript.children].filter(section=>section.dataset.kind!=='cover');
  original.slice(1).forEach(section=>section.dataset.reference='true');
  const mark=name=>`<img class="reading-mark" src="./assets/book/${name}.webp" alt="" width="130" height="130">`;
  const link=(id,text)=>`<a class="reading-option" href="#${id}">${text} <span aria-hidden="true">↗</span></a>`;
  const plate=(file,alt)=>`<img class="reading-plate" src="./assets/book/${file}.webp" alt="${alt}" loading="lazy">`;
  const leaves=[];
  function leaf(id,title,html,theme='ink') { leaves.push({id,title,html,theme}); }
  function encounter(type){leaf('first-'+type,({write:'A little room for your ink',kept:'A morning, kept',remembered:'Something came back',mission:'Find a border',dare:'Wicker has got in',map:'The guards'})[type],edition.composition(type),'encounter');}
  const quietPool=[
    ['MarginaliaGoblinSleeping','The paper has stopped talking. Let it.'],
    ['MarginaliaLavender','Something outside this Book is moving.'],
    ['MarginaliaGoblinShushing','A small silence. I found it between two words.'],
    ['MarginaliaFeather','You may look away. I know where we are.'],
    ['MarginaliaStar','The ceiling is also available for looking at.'],
    ['MarginaliaScrap','There is no question on this Page.']
  ];
  function hush(id,offset){const [art,words]=quietPool[(edition.seed+offset)%quietPool.length];leaf(id,'Between the Pages',`${mark(art)}<p class="hush-line">${words}</p>`,'hush');}
  leaf('first-arrival','I have a quarrel with Routine',`${mark('MarginaliaGoblinReading')}<p class="eyebrow">Hello. I’m ReEnchanted.</p><h2>I have a quarrel<br>with Routine.</h2><p>It keeps telling you that you’ve seen all this before.</p><p>Your street. Your breakfast. The people you love. As if knowing their names meant you were finished looking.</p><p>I’m a Book for your iPhone or iPad. Give me little pieces of your life. I’ll help you look again.</p><p class="reading-whisper">The digital Book is free. These Pages will show you a little of what I do.</p>`,'arrival');
  encounter('write');
  hush('first-hush',0);
  leaf('first-curse','The Curse of the Grey',`<p class="eyebrow">Who we’re up against</p><h2>The world didn’t<br>go grey.</h2><p>You got very good at getting through it.</p><p>Useful skill. Terrible landlord. Soon every day is paying rent to the next thing that needs doing.</p><p>I call that the Curse of the Grey. I mean the habit of walking past your own life.</p><p>We can interrupt it. A sentence is a small enough crowbar.</p>${link('curse','More about the Curse')}`,'curse');
  encounter('kept');
  leaf('first-how','Find it. Keep it.',`${mark('MarginaliaFeather')}<p class="eyebrow">How the app works</p><h2>Bring me something<br>that happened.</h2><ol class="reading-steps"><li><strong>Notice.</strong> A thing that caught you looking.</li><li><strong>Capture.</strong> Write, speak, take a picture, or bring something in from another app.</li><li><strong>Keep.</strong> Make a Page. Your own words stay yours. There is room for what I make beside them.</li></ol><p>No grand revelation required. Breakfast is allowed in.</p>${link('how','All the ways to begin')}`);
  hush('first-breath',2);
  encounter('remembered');
  encounter('mission');
  encounter('map');
  leaf('first-border-echo','A note at the crossing',`${mark('MarginaliaCompass')}<div data-echo="mission"><div data-if-done hidden><p class="eyebrow">About that border you found</p><h2>You went and looked.</h2><p>Before, it was a patch of warmer or colder air. Now you know where the crossing is.</p><p>That is how a place begins to have a story.</p><p>You needn’t tell me who guards yours. The cats on the last Page belong to the maker’s Book.</p></div><div data-if-waiting><p class="eyebrow">The border can wait</p><h2>A mission is<br>an invitation.</h2><p>You don’t owe this Book a completed errand.</p><p>The invitation can come with you. Next time the air changes against your arm, you might remember it.</p></div></div>${link('mechanics','Missions, spells, and small weapons')}`);
  leaf('first-night','The day becomes a tale',`${mark('MarginaliaGoblinSleeping')}<p class="eyebrow">In the app, after the day</p><h2>I gather the<br>loose ends.</h2><p>The things you kept can become a tale. People, places, and small moments find each other across the Pages.</p><p>The app uses AI to help make those connections and write beside you. Your original contributions remain their own things.</p><p class="reading-whisper">This website uses prepared Pages. Your sentence stays in this tab and returns unchanged.</p>${link('nightly-braid','Read about the nightly braid')}`,'night');
  encounter('dare');
  hush('first-wait',4);
  leaf('first-wicker-echo','A scrap from Wicker',`${mark('MarginaliaScrap')}<p class="eyebrow">Wicker left this</p><div data-echo="dare"><div data-if-done hidden><h2>The word got out.</h2><p>Good. Keep the door shut a moment. It has never been outside by itself before.</p><p>You can have your respectable voice back now.</p></div><div data-if-waiting><h2>Still in there?</h2><p>Your word, I mean.</p><p>Keep it until there’s a good place to let it loose. I’m not collecting obedience.</p></div></div><p class="reading-whisper">An authored reply for this public Book. Wicker hasn’t heard or interpreted your word.</p>${link('note-wicker-eddies','Who let Wicker in?')}`,'wicker');
  leaf('first-world','Somewhere to wander',`${plate('GreatHall','The app’s illustrated Academy Great Hall')}<p class="eyebrow">The Academy</p><h2>The rooms have opinions.</h2><p>So do the professors. There are lessons, dares, stories, and a Radio that you can leave on while you wander.</p><p>Come in. Then take something useful back outside.</p><div class="reading-links">${link('academy','Visit the Academy')}${link('radio-player','Turn the Radio on')}</div>`,'world');
  leaf('first-paper','A life, bound in paper',`${mark('MarginaliaSeal')}<p class="eyebrow">The Bindery</p><h2>You can close<br>the screen.</h2><p>Your kept life can become a paper Book. Weekly issues. Monthly volumes. A season. A year.</p><p>Something with weight. Something you can put into another pair of hands.</p><p>The digital Book is free. Printed editions and optional extras have their own prices.</p><div class="reading-links">${link('editions','See the editions')}${link('plans','What costs what')}</div>`,'paper');
  leaf('first-privacy','What stays yours',`${mark('MarginaliaGoblinShushing')}<p class="eyebrow">A boundary in the binding</p><h2>Your life<br>is not the display.</h2><p>The ordinary sentences here came from the maker’s Book, chosen for this public edition.</p><p>Your trial sentence is kept only in this browser tab. It isn’t sent to a model or added to anybody else’s Book.</p><p>Capture lets you erase it. A souvenir is yours to download if you choose.</p>${link('privacy','Read the app’s privacy details')}`);
  leaf('first-compass','The Wonder Compass',`${mark('MarginaliaCompass')}<p class="eyebrow">A whole book inside the Book</p><h2>There are reasons<br>for the mischief.</h2><p>The app includes the whole <em>Wonder Compass</em>: 26 chapters about getting back into wonder, with more than 300 citations.</p><p>Read it offline. Try something. Argue with it. A field guide should get muddy.</p>${link('ebook','Open the Wonder Compass chapter')}`);
  leaf('first-parting','Take something with you',`${mark('MarginaliaGoblinWritingCrouched')}<p class="eyebrow">That will do for a beginning</p><h2>The next Page<br>is outside.</h2><p>Look at one familiar thing until it stops being only its name.</p><p>You can take a little Page with you. It will hold your sentence, if you left one. Otherwise, I’ve put an invitation on it.</p><button type="button" class="ink-button" data-souvenir>Take this Page</button><p class="capture-receipt" data-souvenir-status role="status"></p><div class="reading-links">${link('invitation','Tell me when the app opens')}${link('contents','There’s more in the binding')}</div>`,'parting');
  const fragment=document.createDocumentFragment();
  for(const item of leaves){const section=document.createElement('section');section.id=item.id;section.dataset.chapter=item.title;section.dataset.kind=item.theme==='hush'?'quiet':'composed';section.dataset.reading='true';section.dataset.theme=item.theme;section.innerHTML=item.theme==='encounter'?item.html:`<div class="reading-composition">${item.html}</div>`;fragment.append(section);}
  original[0].after(fragment);
  original[0].querySelector('.ink-button').href='#first-arrival';
  const contents=document.querySelector('#contents');
  const nav=contents.querySelector('nav');
  const details=document.createElement('details');details.className='full-contents';details.innerHTML='<summary>All the chapters · the complete information Book</summary>';nav.before(details);details.append(nav);
  const route=document.createElement('nav');route.setAttribute('aria-label','A first reading');route.innerHTML=[['first-arrival','Begin here'],['first-how','How the app works'],['first-mission','Take a little mission'],['first-world','The Academy & Radio'],['first-paper','Paper Books & prices'],['first-privacy','What stays yours'],['first-parting','Take a Page with you']].map(([id,text])=>`<a href="#${id}"><strong>${text}</strong><span aria-hidden="true">↗</span></a>`).join('');details.before(route);
  const back=document.createElement('a');back.className='reading-return';back.href='#first-arrival';back.textContent='↶ Back to the first reading';back.hidden=true;document.querySelector('#reading-room').append(back);
  edition.hydrate();
})();
