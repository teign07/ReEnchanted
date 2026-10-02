/* The opening Story Pages: two you can actually play, then a braid of what you chose.
 *
 * A stranger meets these before they know a single name in the Academy, so the
 * page introduces everybody itself and then lets them talk. Wicker Eddies
 * (doubts everything) and Serenity Brown (distracts everyone) are arguing about
 * the sentence YOU just left on the page, quoted word for word. Is it a
 * sentence or a spell? You're the tiebreaker, and then they test it: a spell
 * survives being said back. Wicker has bet his brass key it won't. Serenity has
 * bet her sea charm it will.
 *
 * That is the product's whole claim played on the visitor's own words: the
 * ordinary thing has a story in it, noticing changes it, your choice changes
 * what happens, and the Book remembers (the stance you take is echoed on later
 * leaves, and the braid ends on a rematch for tomorrow's sentence).
 *
 * Three rules this file keeps:
 *  - Nothing is generated. The only part of the reader's text that appears is
 *    the sentence itself, set with textContent. Every line the characters speak
 *    is authored to be true of ANY sentence, and none of it mocks the content.
 *  - A sentence that reads as grief is never argued over. The characters borrow
 *    a different one and the page says "yours stays with me".
 *  - The real sky is a bonus the reader opts into (button on the braid leaf).
 *    Nothing here asks for a location by itself.
 *
 * No model, no network, nothing leaves the tab -- the same rule the encounters keep.
 */
(() => {
  'use strict';
  const KEY = 'reenchanted-public-story-v4';
  let chosen = {};
  try { chosen = JSON.parse(sessionStorage.getItem(KEY) || '{}') || {}; } catch {}
  const remember = () => { try { sessionStorage.setItem(KEY, JSON.stringify(chosen)); } catch {} };

  const mark = (name) => '<img class="reading-mark" src="./assets/book/' + name +
    '.webp" alt="" width="130" height="130">';

  // Who is in the room, at a glance, before a word has been read.
  const CAST = {
    wicker: 'Wicker doubts everything.',
    serenity: 'Serenity distracts everyone.'
  };
  const faces = () => '<span class="story-faces"><span class="story-faces-art" aria-hidden="true">'
    + Object.keys(CAST).map(name => '<img src="./assets/book/face-' + name + '.webp" alt="" width="100" height="100">').join('')
    + '</span><span class="story-cast">' + Object.values(CAST).join('<br>') + '</span></span>';

  // Lent to the characters when the reader left nothing, or left something the
  // page would rather not argue over. It is a real sentence from the maker's Book.
  const BORROWED = 'The cats are staring at me.';
  const HEAVY = /\b(died|dying|(is|was|are|were) dead|funeral|grief|grieving|mourning|passed away|cancer|hospice|chemo|miscarriage|suicide|suicidal|kill myself|self[- ]harm|abuse[ds]?|assault(ed)?|overdose|panic attack|can'?t (breathe|go on)|want to die|wish i (was|were) dead|lost (my|our) (mum|mom|dad|father|mother|husband|wife|son|daughter|baby|brother|sister|friend|dog|cat))\b/i;
  // The sentence the story uses, and why (so the lead-in can be honest about it).
  function subject() {
    const mine = String(window.PublicEdition?.getSentence?.() || '').trim();
    if (!mine) return { text: BORROWED, why: 'empty' };
    if (HEAVY.test(mine)) return { text: BORROWED, why: 'kept' };
    return { text: mine, why: 'own' };
  }
  const LEAD = {
    own: 'They’re fighting about what you wrote:',
    empty: 'You left it empty, so I lent them one:',
    kept: 'Yours stays with me. I lent them another:'
  };

  // Entries are strings, or { quote: true } for the sentence under dispute.
  const SCENES = {
    magic: {
      id: 'magic',
      title: 'Is it magic?',
      theme: 'story',
      faces: true,
      eyebrow: 'A Story Page · 1 of 2 · you’re the tiebreaker',
      heading: 'Is it magic?',
      opening: () => [
        LEAD[subject().why],
        { quote: true },
        '“It’s a sentence,” says Wicker. “It’s a spell,” says Serenity.'
      ],
      ask: 'Who’s right?',
      choices: [
        { id: 'wicker', label: '“It’s a sentence.”',
          said: 'You sided with Wicker.',
          body: 'Wicker held out his hand like a man collecting a debt. “Write that down.” I did. Serenity just smiled. “Then you won’t mind a test,” she said. He minded.',
          tale: 'You said it was only a sentence. Wicker asked for that in writing.',
          hook: 'Wicker lost his key anyway. He says it was a bad sentence to bet on, and he wants another tomorrow.',
          stance: 'You sided with him once. He hasn’t forgotten, and he’s hoping it wasn’t a fluke.' },
        { id: 'serenity', label: '“It’s a spell.”',
          said: 'You sided with Serenity.',
          body: 'Serenity shrieked and hugged you. Wicker looked at you like a table that had just spoken. “What did she give you?” “Nothing.” “Suspicious,” he said. “Then it won’t mind a test.”',
          tale: 'You said it was a spell. Wicker wrote your name on a very short list.',
          hook: 'Wicker handed over his key. He wants a rematch tomorrow, with a harder sentence.',
          stance: 'You sided with Serenity once. He’s keeping a list, and you’re on it.' },
        { id: 'read', label: '“Has either of you read it?”',
          said: 'You asked if they’d read it.',
          body: 'They hadn’t. They’d been arguing about the idea of it. Wicker cleared his throat. Serenity sat on my margin. “A test, then,” said Wicker. “Properly.”',
          tale: 'You asked if either of them had actually read it. Neither had.',
          hook: 'Wicker handed over his key. Serenity says you cheated by reading it. He wants a rematch tomorrow.',
          stance: 'You made him read a thing before arguing about it once. He’s still annoyed.' }
      ],
      fallbackTale: 'Somewhere between two friends who won’t stop arguing, a sentence is waiting to be read.',
      receipt: ''
    },

    back: {
      id: 'back',
      title: 'Say it back',
      theme: 'story',
      faces: true,
      eyebrow: 'A Story Page · 2 of 2',
      heading: 'Say it back.',
      after: 'magic',
      // The test is the same whichever side you took. Only who's gloating changes.
      openings: {
        wicker: 'You sided with Wicker, so Wicker is insufferable.',
        serenity: 'You sided with Serenity, so Serenity is bouncing.',
        read: 'You made them read it, so now they’re competing to read it best.'
      },
      fallbackOpening: 'They’ve decided to settle it.',
      opening: (scene) => [
        scene.openings[chosen[scene.after]] || scene.fallbackOpening,
        '“A spell survives being said back,” says Wicker. “My key says this one won’t.” “My charm says it will,” says Serenity. “You judge.”'
      ],
      ask: 'Who reads it?',
      choices: [
        { id: 'flat', label: 'Wicker reads it, flat',
          said: 'Wicker read it, flat.',
          body: 'He read it like a witness. Nothing happened. Then Serenity said, very quietly, that it was the best thing read in this building all day, and he lowered the paper. “Irritating,” he said. “It held.” He pushed the key across the desk.',
          tale: 'Wicker read it flat, like evidence, and it held.' },
        { id: 'secret', label: 'Serenity reads it, like a secret',
          said: 'Serenity read it, like a secret.',
          body: 'She leaned in and read it so softly the lamp leaned with her. Wicker, who had bet against it, found he was whispering too. He saw that, and was furious, and handed over the key.',
          tale: 'Serenity read it like a secret, and the lamp leaned in.' },
        { id: 'aloud', label: 'I’ll say it out loud',
          said: 'You said it out loud.',
          body: 'To whatever room you’re in. Nobody heard but us, and the room, which has opinions. Wicker said nothing, which from him is a standing ovation. I don’t know what it sounds like when you say it. Only you do.',
          tale: 'You said it out loud, to the room, and the room kept it.' }
      ],
      receipt: ''
    },

    bargain: {
      id: 'bargain',
      title: 'A bargain, offered',
      theme: 'bargain',
      mark: 'MarginaliaSeal',
      eyebrow: 'Something has already happened',
      heading: 'She got here first.',
      opening: () => [
        'A pixie who lives in punctuation left a comma in my margin. The sentence above it is holding its breath.'
      ],
      terms: 'Open her bargain: owe her one real place that works as a pause. Leave it closed: owe nothing.',
      ask: 'What do you do?',
      choices: [
        { id: 'open', label: 'Open it',
          said: 'You opened it.',
          body: 'Then it’s owed, and that’s the whole rule. Being offered a thing costs nothing. Opening it costs the noticing. She wants her comma before the light goes, and she’ll know if you bring her something you didn’t actually see.' },
        { id: 'closed', label: 'Leave it closed',
          said: 'You left it closed.',
          body: 'And nothing happened. I’m not being kind. An unopened bargain was never a debt. She’ll be back, because they always are, and she won’t hold it against you. Refusing the Folk politely is older than all of us.' }
      ],
      receipt: ''
    }
  };

  // What the reader's real sky did to tonight's page. Only ever shown after they
  // press the button on the braid leaf (or the sky leaf) themselves.
  const SKY = {
    clear: 'Your sky was clear tonight. Plenty of room for a sentence to get out.',
    cloud: 'Your sky was all cloud, so the sentence had something soft to land on.',
    fog: 'Your sky was fog. The sentence went through it without a map, which Serenity says is the best way.',
    rain: 'It was raining where you are. The sentence got a little wet, and Wicker pretended not to notice.',
    snow: 'It was snowing where you are. Serenity put the sentence out to catch some.',
    storm: 'There was thunder where you are. Wicker says he arranged that. He didn’t.'
  };

  const escaped = (text) => String(text == null ? '' : text)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

  const openingHTML = (scene) => scene.opening(scene).map(line => line.quote
    ? '<blockquote class="story-quote" data-story-quote>' + escaped(subject().text) + '</blockquote>'
    : '<p>' + escaped(line) + '</p>').join('');

  function composition(id) {
    const scene = SCENES[id];
    if (!scene) return '';
    const terms = scene.terms ? '<p class="story-terms">' + escaped(scene.terms) + '</p>' : '';
    const buttons = scene.choices.map(choice =>
      '<button type="button" class="reading-option" data-story="' + scene.id +
      '" data-choice="' + choice.id + '">' + escaped(choice.label) + '</button>').join('');
    return '<div class="reading-composition story-page" data-story-page="' + scene.id + '">'
      + (scene.faces ? faces() : mark(scene.mark))
      + '<p class="eyebrow">' + escaped(scene.eyebrow) + '</p>'
      + '<h2>' + escaped(scene.heading) + '</h2>'
      + '<div data-story-opening>' + openingHTML(scene) + terms + '</div>'
      + '<div data-story-ask><p class="story-ask">' + escaped(scene.ask) + '</p>'
      + '<div class="story-choices">' + buttons + '</div></div>'
      + '<div data-story-said tabindex="-1" hidden></div>'
      + '</div>';
  }

  function render(root) {
    (root || document).querySelectorAll('[data-story-page]').forEach(page => {
      const scene = SCENES[page.dataset.storyPage];
      if (!scene) return;
      const picked = scene.choices.find(choice => choice.id === chosen[scene.id]);
      const ask = page.querySelector('[data-story-ask]');
      const said = page.querySelector('[data-story-said]');
      const opening = page.querySelector('[data-story-opening]');
      if (!ask || !said || !opening) return;
      // The opening follows the reader's sentence and, on page 2, their first choice.
      // Rebuilt only when it would read differently, so a pressed button keeps focus.
      const fresh = openingHTML(scene) + (scene.terms ? '<p class="story-terms">' + escaped(scene.terms) + '</p>' : '');
      if (opening.dataset.rendered !== fresh) {
        opening.innerHTML = fresh;
        opening.dataset.rendered = fresh;
      }
      ask.hidden = !!picked;
      said.hidden = !picked;
      opening.hidden = !!picked;
      if (picked) {
        said.innerHTML = '<p class="story-said">' + escaped(picked.said) + '</p>'
          + '<p>' + escaped(picked.body) + '</p>'
          + (scene.receipt ? '<p class="capture-receipt">' + escaped(scene.receipt) + '</p>' : '')
          + '<button type="button" class="reading-option" data-story-reconsider="' + scene.id + '">Try another choice</button>';
      }
    });
    // The braid promises it braids what you chose. Now it can show it.
    const pick = (id) => SCENES[id].choices.find(choice => choice.id === chosen[id]);
    const first = pick('magic'), second = pick('back');
    document.querySelectorAll('[data-story-echo="magic"]').forEach(slot => {
      slot.hidden = !first;
      if (first) slot.textContent = 'Tonight that includes Wicker’s key.';
    });
    document.querySelectorAll('[data-story-quote-slot]').forEach(slot => {
      if (slot.textContent !== subject().text) slot.textContent = subject().text;
    });
    document.querySelectorAll('[data-story-tale="magic"]').forEach(slot => {
      slot.textContent = first ? first.tale : SCENES.magic.fallbackTale;
    });
    document.querySelectorAll('[data-story-tale="back"]').forEach(slot => {
      slot.hidden = !second;
      if (second) slot.textContent = second.tale;
    });
    // The rematch is only earned once both pages are played.
    document.querySelectorAll('[data-story-tale="hook"]').forEach(slot => {
      slot.hidden = !(first && second);
      if (first && second) slot.textContent = first.hook;
    });
    // Later leaves remember which side you took.
    document.querySelectorAll('[data-story-stance]').forEach(slot => {
      slot.hidden = !first;
      if (first) slot.textContent = first.stance;
    });
    // And, only if the reader pressed the button, the real sky.
    const sky = SKY[window.PublicSky?.kind?.()] || '';
    document.querySelectorAll('[data-story-sky]').forEach(slot => {
      slot.hidden = !sky;
      slot.textContent = sky;
    });
  }

  document.addEventListener('public-sky', () => render());

  document.addEventListener('click', event => {
    const reconsider = event.target.closest('[data-story-reconsider]');
    if (reconsider) {
      const page = reconsider.closest('[data-story-page]');
      const id = reconsider.dataset.storyReconsider;
      delete chosen[id];
      // A different side means a different test.
      Object.values(SCENES).filter(scene => scene.after === id).forEach(scene => { delete chosen[scene.id]; });
      remember();
      render();
      page.querySelector('[data-choice]')?.focus({ preventScroll: true });
      return;
    }
    const button = event.target.closest('[data-story][data-choice]');
    if (!button) return;
    window.BookSounds?.select();
    chosen[button.dataset.story] = button.dataset.choice;
    remember();
    render();
    button.closest('[data-story-page]').querySelector('[data-story-said]').focus({ preventScroll: true });
  });

  window.PublicStoryPages = { composition, render, chosen: () => Object.assign({}, chosen) };
  render();
})();
