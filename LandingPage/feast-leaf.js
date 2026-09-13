/* A leaf that is true about today, and different tomorrow.
 *
 * It takes the place of the first breather in the reading. On one of the 47
 * days a year the almanac marks, it carries that day in the Book's own words,
 * exactly as the app says them. On the other 318 it carries the moon, which is
 * always doing something.
 *
 * Eight of the almanac's days are mourning or fasting rather than celebration.
 * The app lowers its voice for those, so the leaf does too: no invitation to
 * make something of the day, and a quieter hand on the page.
 */
(() => {
  'use strict';
  const clock = window.PublicFeastday;
  if (!clock) return;

  const host = document.querySelector('#first-hush');
  if (!host) return;

  const escaped = (text) => String(text == null ? '' : text)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

  const now = clock.today();
  const mark = '<img class="reading-mark" src="./assets/book/MarginaliaStar.webp" alt="" width="130" height="130">';

  let body;
  if (now.feast) {
    const grief = now.feast.carriesGrief;
    // The invitations on the mourning days were written for those days -- "name
    // one thing your people have decided to keep remembering" -- so they stay.
    // What changes is the voice around them, which is what the app changes too.
    body = mark
      + '<p class="eyebrow">' + (grief ? 'Today, somewhere, quietly' : 'Today, somewhere') + '</p>'
      + '<h2>' + escaped(now.feast.academyTitle) + '</h2>'
      + '<p>' + escaped(now.feast.blurb) + '</p>'
      + (now.feast.invitation
          ? '<p class="encounter-permission">' + escaped(now.feast.invitation) + '</p>' : '')
      + '<p class="reading-whisper">' + escaped(now.feast.commonName) + '. '
      + (grief
          ? 'One of the days I keep, and one I keep my voice down for.'
          : 'Fifty-one days, twelve traditions. I never ask which is yours.')
      + '</p>';
  } else {
    const moon = now.moon;
    body = mark
      + '<p class="eyebrow">Tonight</p>'
      + '<h2>' + escaped(moon.name) + '</h2>'
      + '<p>' + escaped(moon.line) + '</p>'
      + '<p class="reading-whisper">Worked out from your own clock, here in this tab. '
      + 'Nothing was asked of anybody and nothing was sent.</p>';
  }

  const composition = host.querySelector('.reading-composition') || host;
  composition.innerHTML = body;
  composition.classList.add('feast-leaf');
  host.dataset.chapter = now.feast
    ? now.feast.commonName
    : 'The moon tonight';
  host.dataset.theme = now.feast ? (now.feast.carriesGrief ? 'quiet' : 'feast') : 'moon';
  if (now.feast && now.feast.carriesGrief) host.dataset.grief = 'true';

  // The mark still comes out of the marginalia deck, like every other leaf's.
  const dealt = host.querySelector('.reading-mark');
  if (dealt && window.PublicMarginaliaDeck) window.PublicMarginaliaDeck.dress(dealt);
})();
