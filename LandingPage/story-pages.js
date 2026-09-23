/* Two Story Pages you can actually play.
 *
 * The site has been describing these. The braid chapter even quotes one as its
 * example -- "Wicker put the brass key on the table. The key objected." -- and
 * the braid leaf promises it braids "whatever you chose in the story I was
 * telling you". Both were claims with nothing behind them. These are the thing
 * itself: a beat, a choice, and a continuation that is genuinely different,
 * remembered afterwards so the braid can say it back.
 *
 * Authored end to end. No model, no network, nothing leaves the tab -- the same
 * rule the encounters keep.
 */
(() => {
  'use strict';
  const KEY = 'reenchanted-public-story-v1';
  let chosen = {};
  try { chosen = JSON.parse(sessionStorage.getItem(KEY) || '{}') || {}; } catch {}
  const remember = () => { try { sessionStorage.setItem(KEY, JSON.stringify(chosen)); } catch {} };

  const mark = (name) => '<img class="reading-mark" src="./assets/book/' + name +
    '.webp" alt="" width="130" height="130">';

  const SCENES = {
    key: {
      id: 'key',
      title: 'The key objected',
      theme: 'story',
      eyebrow: 'A Story Page, and it is your turn in it',
      heading: 'The key objected.',
      opening: [
        'Wicker put a brass key on the table between us. It opens nothing in this building. He was very clear about that, in the tone people use for things that are not true.',
        'Then the key objected. It managed this without moving, which is the worst way for a thing to object.'
      ],
      ask: 'What do you do?',
      choices: [
        { id: 'take', label: 'Take the key',
          said: 'You took it.',
          body: 'It went warm in your hand, the warmth a thing keeps when it has been waiting to be picked up. Wicker looked delighted and a little worried, which is his whole face. Now you have a key and no door. That is how most of this starts.' },
        { id: 'leave', label: 'Leave it on the table',
          said: 'You left it where it was.',
          body: 'It stayed there being a key, getting smugger. Wicker said nothing, which from him is a standing ovation. Not taking a thing is a decision too, and I wrote it down the same as any other.' },
        { id: 'ask', label: 'Ask the key what it wants',
          said: 'You asked it. Out loud.',
          body: 'Wicker put both hands over his mouth. The key did not answer, but the room did the thing a room does when it turns out to have been listening. The answer came later, in the wrong order, and you knew it anyway.' }
      ],
      receipt: ''
    },

    bargain: {
      id: 'bargain',
      title: 'A bargain, offered',
      theme: 'bargain',
      eyebrow: 'Something has already happened',
      heading: 'She got here first.',
      opening: [
        'The Punctuation Pixie has been at this page. There is a comma in the margin I did not put there, and the sentence above it is holding its breath.',
        'She has not asked for anything yet. That is the order her kind work in: something small first, before you can refuse it, and then they wait to be noticed noticing.'
      ],
      terms: 'What she is hungry for: rhythm and pause. A place that feels like a comma. A thing that is an exclamation point.',
      ask: 'The bargain is on the table, unopened.',
      choices: [
        { id: 'open', label: 'Open it',
          said: 'You opened it.',
          body: 'Then it is owed, and that is the whole rule. Being offered a thing costs nothing. Opening it costs the noticing. She wants her comma before the light goes, and she will know if you bring her something you did not actually see.' },
        { id: 'closed', label: 'Leave it closed',
          said: 'You left it closed.',
          body: 'And nothing happened. I am not being kind: an unopened bargain is not a debt, and never was. She will be back, because they always are, and she will not hold it against you. Refusing the Folk politely is older than all of us.' }
      ],
      receipt: ''
    }
  };

  const escaped = (text) => String(text == null ? '' : text)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

  function composition(id) {
    const scene = SCENES[id];
    if (!scene) return '';
    const art = id === 'bargain' ? 'MarginaliaSeal' : 'MarginaliaScrap';
    const opening = scene.opening.map(line => '<p>' + escaped(line) + '</p>').join('');
    const terms = scene.terms ? '<p class="story-terms">' + escaped(scene.terms) + '</p>' : '';
    const buttons = scene.choices.map(choice =>
      '<button type="button" class="reading-option" data-story="' + scene.id +
      '" data-choice="' + choice.id + '">' + escaped(choice.label) + '</button>').join('');
    return '<div class="reading-composition story-page" data-story-page="' + scene.id + '">'
      + mark(art)
      + '<p class="eyebrow">' + escaped(scene.eyebrow) + '</p>'
      + '<h2>' + escaped(scene.heading) + '</h2>'
      + opening + terms
      + '<div data-story-ask><p class="story-ask">' + escaped(scene.ask) + '</p>'
      + '<div class="story-choices">' + buttons + '</div></div>'
      + '<div data-story-said hidden></div>'
      + '</div>';
  }

  function render(root) {
    (root || document).querySelectorAll('[data-story-page]').forEach(page => {
      const scene = SCENES[page.dataset.storyPage];
      if (!scene) return;
      const picked = scene.choices.find(choice => choice.id === chosen[scene.id]);
      const ask = page.querySelector('[data-story-ask]');
      const said = page.querySelector('[data-story-said]');
      if (!ask || !said) return;
      ask.hidden = !!picked;
      said.hidden = !picked;
      if (picked) {
        said.innerHTML = '<p class="story-said">' + escaped(picked.said) + '</p>'
          + '<p>' + escaped(picked.body) + '</p>'
          + (scene.receipt ? '<p class="capture-receipt">' + escaped(scene.receipt) + '</p>' : '');
      }
    });
    // The braid leaf promises it braids what you chose. Now it can show it.
    const keyChoice = SCENES.key.choices.find(choice => choice.id === chosen.key);
    document.querySelectorAll('[data-story-echo="key"]').forEach(slot => {
      slot.hidden = !keyChoice;
      if (keyChoice) slot.textContent = 'Tonight that includes the brass key. ' + keyChoice.said;
    });
  }

  document.addEventListener('click', event => {
    const button = event.target.closest('[data-story][data-choice]');
    if (!button) return;
    chosen[button.dataset.story] = button.dataset.choice;
    remember();
    render();
  });

  window.PublicStoryPages = { composition, render, chosen: () => Object.assign({}, chosen) };
  render();
})();
