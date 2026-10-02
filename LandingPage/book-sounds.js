/* The app's BookSoundBank: actual recordings, no sound on page load. */
(() => {
  'use strict';
  const catalogue = window.BookSoundCatalogue;
  const toggle = document.querySelector('#book-sound-toggle');
  const AudioEngine = window.AudioContext || window.webkitAudioContext;
  if (!catalogue || !toggle || !AudioEngine) return;
  const preference = 'reenchanted-book-sounds';
  let enabled = true;
  try { enabled = localStorage.getItem(preference) !== 'off'; } catch {}
  let context = null, master = null, generation = 0;
  let ladderAt = -Infinity, ladderRung = 0, ladderDirection = 1;
  let keepCount = 0, keepDay = '';
  const buffers = new Map(), lastVariant = new Map(), lastPlayed = new Map();
  const voices = new Set();

  function updateControl() {
    toggle.hidden = false;
    toggle.textContent = enabled ? '♪ Sound on' : '♪ Sound off';
    toggle.setAttribute('aria-pressed', String(enabled));
    toggle.setAttribute('aria-label', enabled ? 'Mute Book sounds' : 'Enable Book sounds');
    toggle.title = enabled ? 'The app’s sounds. Click to mute.' : 'Let the Book make a little noise.';
  }
  function unlock(event) {
    if (!event.isTrusted || !enabled || document.hidden) return;
    try {
      if (!context) {
        context = new AudioEngine();
        master = context.createGain();
        master.gain.value = .8;
        master.connect(context.destination);
      }
      if (context.state === 'suspended') context.resume().catch(() => {});
    } catch { /* Audio is optional; all reading controls still work. */ }
  }
  function stop() {
    generation++;
    for (const voice of voices) { try { voice.stop(); } catch {} }
    voices.clear();
    toggle.classList.remove('is-speaking');
  }
  function load(stem) {
    if (!buffers.has(stem)) {
      const promise = fetch(`./assets/sounds/${stem}.wav?v=${catalogue.files[stem]}`)
        .then(response => {
          if (!response.ok) throw new Error('Book sound unavailable');
          return response.arrayBuffer();
        }).then(bytes => context.decodeAudioData(bytes));
      buffers.set(stem, promise);
      promise.catch(() => buffers.delete(stem));
    }
    return buffers.get(stem);
  }
  async function play(family, variant = null) {
    const count = catalogue.counts[family];
    if (!enabled || !context || document.hidden || !count) return;
    const now = performance.now();
    const interval = ['turn', 'turnback'].includes(family) ? 140 : family === 'ink' ? 120 : 45;
    if (now - (lastPlayed.get(family) ?? -Infinity) < interval) return;
    lastPlayed.set(family, now);
    let pick = variant === null ? Math.floor(Math.random() * count) : Math.max(0, Math.min(variant, count - 1));
    if (variant === null && count > 1 && pick === lastVariant.get(family)) pick = (pick + 1) % count;
    lastVariant.set(family, pick);
    const requestGeneration = generation;
    try {
      const buffer = await load(`${family}-${pick}`);
      // A slow fetch must never speak after mute or tab hiding.
      if (!enabled || document.hidden || requestGeneration !== generation || context.state !== 'running' || performance.now() - now > 900) return;
      if (voices.size >= 4) { const oldest = voices.values().next().value; oldest.stop(); voices.delete(oldest); }
      const radio = document.querySelector('#book-audio');
      master.gain.setValueAtTime(radio && !radio.paused ? .35 : .8, context.currentTime);
      const voice = context.createBufferSource();
      voice.buffer = buffer;
      voice.connect(master);
      voices.add(voice);
      toggle.classList.add('is-speaking');
      voice.onended = () => { voices.delete(voice); voice.disconnect(); if (!voices.size) toggle.classList.remove('is-speaking'); };
      voice.start();
    } catch { /* Missing audio never holds up a Page or a reader's ink. */ }
  }
  function select() {
    const now = performance.now(), rungs = catalogue.counts.select;
    if (now - ladderAt > 1300) { ladderRung = Math.floor(Math.random() * 3); ladderDirection = 1; }
    else {
      let next = ladderRung + ladderDirection;
      if (next >= rungs) { ladderDirection = -1; next = rungs - 2; }
      if (next < 0) { ladderDirection = 1; next = 1; }
      ladderRung = next;
    }
    ladderAt = now;
    play('select', ladderRung);
  }
  function keep() {
    const date = new Date(), day = `${date.getFullYear()}-${date.getMonth()+1}-${date.getDate()}`;
    if (day !== keepDay) { keepDay = day; keepCount = 0; }
    play('keep', Math.min(keepCount++, catalogue.counts.keep - 1));
  }
  window.BookSounds = {
    play, select, keep,
    turn: forward => play(forward ? 'turn' : 'turnback'),
    get state() { return { enabled, context: context?.state || 'locked', active: voices.size, loaded: buffers.size }; },
  };
  document.addEventListener('click', unlock, { capture: true });
  document.addEventListener('pointerdown', unlock, { capture: true });
  document.addEventListener('keydown', event => {
    if (['Enter', ' ', 'ArrowLeft', 'ArrowRight', 'PageUp', 'PageDown', 'Home', 'End'].includes(event.key)) unlock(event);
  }, { capture: true });
  document.addEventListener('input', event => {
    if (event.isTrusted && event.target.matches('[data-capture-form] textarea') && event.inputType === 'insertText' && /[.!?]/.test(event.data || '')) play('ink');
  });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) { stop(); if (context?.state === 'running') context.suspend().catch(() => {}); }
  });
  toggle.addEventListener('click', event => {
    enabled = !enabled;
    try { localStorage.setItem(preference, enabled ? 'on' : 'off'); } catch {}
    if (enabled) { unlock(event); play('toggle', Math.floor(Math.random() * 2)); }
    else stop();
    updateControl();
  });
  updateControl();
})();
