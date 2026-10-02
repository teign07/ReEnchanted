/* The original Feedback Board's draft links, beside the public Book. */
(() => {
  document.querySelector('#feedback-board')?.addEventListener('toggle', event => {
    window.BookSounds?.play(event.target.open ? 'peek' : 'close');
  });
  const slip = document.querySelector('.contact-note');
  const embers = document.querySelector('.contact-embers');
  if (slip && embers) {
    // Loose letters from the note, carried behind the paper into the dark.
    const alphabet = 'DEARMAKERHELLOSTORY';
    for (let i = 0; i < 22; i++) {
      const letter = document.createElement('span');
      letter.textContent = alphabet[i % alphabet.length];
      letter.style.setProperty('--ember-x', `${18 + (i * 37 % 76)}%`);
      letter.style.setProperty('--ember-y', `${8 + (i * 13 % 28)}%`);
      letter.style.setProperty('--ember-size', `${12 + i * 7 % 15}px`);
      letter.style.setProperty('--ember-time', `${8 + i * 3 % 7}s`);
      letter.style.setProperty('--ember-delay', `${-(i * 1.73 % 14)}s`);
      letter.style.setProperty('--ember-drift', `${-45 - i * 17 % 100}px`);
      letter.style.setProperty('--ember-rise', `${-145 - i * 11 % 100}px`);
      letter.style.setProperty('--ember-turn', `${-45 + i * 13 % 90}deg`);
      embers.append(letter);
    }
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(([entry]) => {
        slip.classList.toggle('is-ember-visible', entry.isIntersecting && !document.hidden);
      }).observe(slip);
      document.addEventListener('visibilitychange', () => {
        const rect = slip.getBoundingClientRect();
        slip.classList.toggle('is-ember-visible', !document.hidden && rect.bottom > 0 && rect.top < innerHeight);
      });
    } else {
      slip.classList.add('is-ember-visible');
    }
  }

  const note = document.querySelector('#feedback-note');
  const count = document.querySelector('#feedback-count');
  const submit = document.querySelector('#feedback-submit');
  const email = document.querySelector('#feedback-email');
  const form = document.querySelector('#feedback-draft');
  if (!note || !count || !submit || !email || !form) return;

  const storageKey = 'reenchanted-feedback-draft';
  try { note.value = (localStorage.getItem(storageKey) || '').slice(0, note.maxLength); } catch (_) {}

  function updateDraft() {
    const text = note.value.trim();
    const title = text
      ? `App feedback: ${text.split(/\s+/).slice(0, 7).join(' ')}`
      : 'App feedback: ';
    const body = [
      'What happened or what would you like?', '', text || '(Write the note here.)', '',
      'Where in the app:', '', 'What did you expect?', '', 'Device / iOS version:', '',
      'Contact email, if you want a reply:', '', `Sent from: ${location.href}`,
    ].join('\n');
    const query = `subject=${encodeURIComponent(title)}&body=${encodeURIComponent(body)}`;
    count.textContent = `${note.value.length} / ${note.maxLength}`;
    submit.href = `https://github.com/teign07/ReEnchanted/issues/new?title=${encodeURIComponent(title)}&body=${encodeURIComponent(body)}`;
    email.href = `mailto:hello@reenchanted.app?${query}`;
    try { localStorage.setItem(storageKey, note.value); } catch (_) {}
  }

  note.addEventListener('input', updateDraft);
  form.addEventListener('submit', event => event.preventDefault());
  updateDraft();
})();
