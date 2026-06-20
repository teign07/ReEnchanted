const root = document.documentElement;
const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

/* ───────────────────────── scroll + pointer parallax ───────────────────────── */
function updateScroll() {
  const max = Math.max(1, document.body.scrollHeight - window.innerHeight);
  root.style.setProperty("--scroll", String(Math.min(1, window.scrollY / max)));
}
window.addEventListener("scroll", updateScroll, { passive: true });
updateScroll();

if (!reduceMotion) {
  window.addEventListener("pointermove", (e) => {
    root.style.setProperty("--mx", (e.clientX / window.innerWidth - 0.5).toFixed(3));
    root.style.setProperty("--my", (e.clientY / window.innerHeight - 0.5).toFixed(3));
  }, { passive: true });
}

/* ───────────────────────── the deck of pages ─────────────────────────
   Each page: a real screen from the app + copy + the line it contributes
   to the braided "Book of You" if the reader keeps it.                  */
const PAGES = [
  {
    kicker: "Weather",
    title: "Fog over the Stacks.",
    bodyHTML: `
      <span class="weather-facts" aria-label="Weather details">
        <span><strong>Now</strong> 60° · fog</span>
        <span><strong>High / Low</strong> 71° / 56°</span>
        <span><strong>Wind</strong> E 4 mph</span>
        <span><strong>Humidity</strong> 92%</span>
      </span>
      <span class="weather-omen"><strong>The Book reads it:</strong> Fog has softened the edges of the Stacks. Hidden doors are likelier today; move slowly, carry one warm detail, and let unclear things stay gently unclear.</span>
    `,
    source: "Weather doorway · public forecast",
    shot: "./assets/screens/story-page-weather-prose.png",
    braid: "Fog softened the edges of the Stacks; I moved slowly, carrying one warm detail.",
  },
  {
    kicker: "Story Page · A Choice",
    title: "Choose how the page turns.",
    body: "Professor Villanelle has found a brittle weather chart whose reading does not match its shadow. Examine the paper's texture, align the chart, or listen to the silence — Slice of Life, Arc, and Surprise each make a different future true.",
    source: "Weather in the Stacks · playable fiction",
    shot: "./assets/screens/story-page-weather-choices.png",
    braid: "A brittle chart offered three ways forward; I kept the fact that the page could turn differently.",
  },
  {
    kicker: "One-Sentence Souvenir",
    title: "A single true line from the day.",
    body: "“The walk at Moose Point, with a small hand in mine, and the waves rolling into the afternoon.” One moment, kept in one durable sentence.",
    source: "Kept from the margins",
    shot: "./assets/screens/margins.jpg",
    braid: "There was the walk at Moose Point, a small hand in mine, the waves rolling in.",
    quiet: true,
  },
  {
    kicker: "A Character Arrives",
    title: "Professor Vivian Villanelle.",
    body: "Professor of Ink-Binding and Souvenir Craft — exacting, lyrical, kind. A person is never only the rumor that arrives before them.",
    source: "Faculty letter",
    shot: "./assets/screens/keep-page.jpg",
    braid: "Professor Villanelle taught me to keep one true moment in one durable sentence.",
  },
  {
    kicker: "Spells & Glow",
    title: "Warming Glow.",
    body: "The current belief state is steady and gently luminous. Open Compass Runs, a noticing game, or let an Enchantment reveal the spellbook nature of an ordinary subject.",
    source: "Belief state",
    shot: "./assets/screens/spells.jpg",
    braid: "My belief state ran warm that month — steady, and gently luminous.",
  },
  {
    kicker: "Wonder Compass",
    title: "Let wonder interrupt the usual.",
    body: "Reframe a gray commute, a familiar street, a tired room until it becomes legible again. Walk. Notice. Record. Return.",
    source: "Real-world wonder",
    shot: "./assets/screens/wonder-compass.jpg",
    braid: "On a gray commute I let wonder interrupt the usual, and the street read new.",
  },
  {
    kicker: "Real Life, Kept",
    title: "This quiet scene, the Book kept.",
    body: "Low light holds. The textile shows its surface to the light. An ordinary afternoon, framed and witnessed.",
    source: "Ordinary wonder",
    shot: "./assets/screens/real-life-kept.jpg",
    braid: "A quiet afternoon in low light — ordinary, and the Book kept it anyway.",
    quiet: true,
  },
  {
    kicker: "Radio",
    title: "Music becomes weather in the stacks.",
    body: "Broadcasts and world effects drift through the shelves as atmosphere — a mood you can keep alongside the day.",
    source: "World effect",
    shot: "./assets/screens/radio.jpg",
    braid: "A broadcast drifted through and became weather in the stacks.",
  },
];

/* ───────────────────────── book controller ───────────────────────── */
const book = document.querySelector("#the-book");
const cover = document.querySelector("#book-cover");
const leafRight = document.querySelector("#leaf-right");
const screenWrap = leafRight.querySelector(".leaf-screen");
const elKicker = document.querySelector("#page-kicker");
const elTitle = document.querySelector("#page-title");
const elBody = document.querySelector("#page-body");
const elSource = document.querySelector("#page-source");
const elShot = document.querySelector("#page-shot");
const elStatus = document.querySelector("#keep-status");
const btnKeep = document.querySelector("#btn-keep");
const btnWait = document.querySelector("#btn-wait");
const nav = document.querySelector("#book-nav");
const btnPrev = document.querySelector("#btn-prev");
const btnNext = document.querySelector("#btn-next");
const navCount = document.querySelector("#nav-count");
const progressFill = document.querySelector(".book-progress-fill");
const hint = document.querySelector("#book-hint");
const braid = document.querySelector("#braid");
const braidText = document.querySelector("#braid-text");
const braidIntro = document.querySelector("#braid-intro");
const braidReplay = document.querySelector("#braid-replay");

let index = 0;
let animating = false;
const choices = new Array(PAGES.length).fill(null); // null | "keep" | "wait"

function render() {
  const p = PAGES[index];
  elKicker.textContent = p.kicker;
  elTitle.textContent = p.title;
  if (p.bodyHTML) {
    elBody.innerHTML = p.bodyHTML;
  } else {
    elBody.textContent = p.body;
  }
  elSource.textContent = p.source;
  elShot.src = p.shot;

  const choice = choices[index];
  screenWrap.classList.toggle("is-kept", choice === "keep");
  btnKeep.classList.toggle("chosen", choice === "keep");
  btnWait.classList.toggle("chosen", choice === "wait");

  navCount.textContent = `Page ${index + 1} of ${PAGES.length}`;
  btnPrev.disabled = index === 0;
  btnNext.textContent = index === PAGES.length - 1 ? "Braid it ✦" : "Next ›";
  progressFill.style.width = `${((index + 1) / PAGES.length) * 100}%`;

  const kept = choices.filter((c) => c === "keep").length;
  elStatus.textContent = kept === 0
    ? `${PAGES.length} pages rising · keep the ones that are true`
    : `${kept} page${kept === 1 ? "" : "s"} kept · they'll braid into your book`;
}

function flip(dir, after) {
  if (reduceMotion || animating) { after(); return; }
  animating = true;
  const cls = dir === "next" ? "turn-next" : "turn-prev";
  leafRight.classList.add(cls);
  setTimeout(after, 310); // swap content at mid-turn (90°)
  setTimeout(() => { leafRight.classList.remove(cls); animating = false; }, 640);
}

function go(delta) {
  const target = index + delta;
  if (target < 0) return;
  if (target >= PAGES.length) { showBraid(); return; }
  flip(delta > 0 ? "next" : "prev", () => { index = target; render(); });
}

function choose(kind) {
  choices[index] = kind;
  render();
  // nudge the reader onward without hijacking navigation
  hint.textContent = index < PAGES.length - 1
    ? (kind === "keep" ? "Kept. Turn the page for the next one →" : "Set aside. Turn the page →")
    : "That's the last page — braid your book ✦";
}

function openBook() {
  if (book.dataset.state !== "closed") return;
  book.dataset.state = "open";
  nav.hidden = false;
  index = 0;
  render();
}

function buildBraid() {
  const keptIndices = PAGES.map((_, i) => i).filter((i) => choices[i] === "keep");
  const keptLines = keptIndices.map((i) => PAGES[i].braid);
  const everyPageAnswered = choices.every((choice) => choice === "keep" || choice === "wait");
  const allKept = choices.every((choice) => choice === "keep");
  const alternating = everyPageAnswered && choices.every((choice, i) => choice === (i % 2 === 0 ? "keep" : "wait"));
  const quietIndices = PAGES.map((page, i) => page.quiet ? i : -1).filter((i) => i >= 0);
  const quietPagesOnly = everyPageAnswered
    && keptIndices.length === quietIndices.length
    && quietIndices.every((i) => keptIndices.includes(i));

  if (keptLines.length === 0) {
    braidIntro.textContent = everyPageAnswered ? "You let every page wait." : "You kept no page before the binding.";
    return "An honest month: nothing demanded to be kept, and the Book waited with you. The shelf is patient. Come back when something catches a real edge.";
  }
  if (allKept) {
    braidIntro.textContent = "You kept everything. The Book has concerns. Affectionate ones.";
    return `${keptLines.join("  ")}  In the final margin, a small hand has written: sentimental, perhaps — but paying attention is hardly the worst trouble to be in.`;
  }
  if (alternating) {
    braidIntro.textContent = "A Riddlewind pattern appeared between yes and not yet.";
    return `${keptLines.join("  ")}  Every other door remained closed. Together, the open doors spelled a question the Book has declined to translate.`;
  }
  if (quietPagesOnly) {
    braidIntro.textContent = "The Book noticed what kind of pages you chose.";
    return `${keptLines.join("  ")}  No spectacle asked to be remembered. The ordinary things made a small constellation anyway.`;
  }
  braidIntro.textContent = `Braided from the ${keptLines.length} page${keptLines.length === 1 ? "" : "s"} you kept.`;
  // each kept line is already a complete sentence — weave them into one passage
  return keptLines.join("  ");
}

function showBraid() {
  const text = buildBraid();
  flip("next", () => {
    book.dataset.state = "braid";
    braidText.textContent = text;
    progressFill.style.width = "100%";
    navCount.textContent = "Your binding";
    btnNext.disabled = true;
    btnPrev.disabled = false;
    hint.textContent = "This is one day. Kept pages gather into editions you can hold.";
  });
}

function backFromBraid() {
  book.dataset.state = "open";
  index = PAGES.length - 1;
  btnNext.disabled = false;
  render();
}

function replay() {
  choices.fill(null);
  book.dataset.state = "open";
  index = 0;
  btnNext.disabled = false;
  hint.textContent = "Tip: keep a few, let some wait — your choices change the ending.";
  render();
  document.querySelector("#book").scrollIntoView({ behavior: "smooth", block: "center" });
}

cover.addEventListener("click", openBook);
btnKeep.addEventListener("click", () => choose("keep"));
btnWait.addEventListener("click", () => choose("wait"));
btnNext.addEventListener("click", () => { if (book.dataset.state === "open") go(1); });
btnPrev.addEventListener("click", () => {
  if (book.dataset.state === "braid") backFromBraid();
  else go(-1);
});
braidReplay.addEventListener("click", replay);

// keyboard support
document.addEventListener("keydown", (e) => {
  if (book.dataset.state === "closed") return;
  if (e.key === "ArrowRight") { btnNext.disabled || go(1); }
  if (e.key === "ArrowLeft") { btnPrev.click(); }
});

render();

/* ───────────────────────── the shelf remembers, without keeping score ───────────────────────── */
(function showReturnNote() {
  const note = document.querySelector("#return-note");
  if (!note) return;
  try {
    const key = "reenchanted-last-visit";
    const now = Date.now();
    const lastVisit = Number(localStorage.getItem(key));
    const daysAway = lastVisit ? Math.floor((now - lastVisit) / 86400000) : 0;
    localStorage.setItem(key, String(now));
    if (daysAway < 1) return;
    note.textContent = `You were gone for ${daysAway} day${daysAway === 1 ? "" : "s"}. Nothing broke. The shelf kept your place.`;
    note.hidden = false;
  } catch (_) {
    // Local storage is optional; the promise still holds without it.
  }
})();

/* ───────────────────────── dedication easter egg ───────────────────────── */
const dedicationOpen = document.querySelector("#dedication-open");
const dedicationModal = document.querySelector("#dedication-modal");
const dedicationCloseControls = document.querySelectorAll("[data-dedication-close]");
let dedicationReturnFocus = null;

function openDedication() {
  if (!dedicationModal) return;
  dedicationReturnFocus = document.activeElement;
  dedicationModal.hidden = false;
  document.body.style.overflow = "hidden";
  dedicationModal.querySelector(".dedication-close")?.focus();
}

function closeDedication() {
  if (!dedicationModal || dedicationModal.hidden) return;
  dedicationModal.hidden = true;
  document.body.style.overflow = "";
  if (dedicationReturnFocus instanceof HTMLElement) dedicationReturnFocus.focus();
}

dedicationOpen?.addEventListener("click", openDedication);
dedicationCloseControls.forEach((control) => control.addEventListener("click", closeDedication));
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") closeDedication();
});

/* ───────────────────────── Belief talismans + the hidden Binding ───────────────────────── */
const CHAPTER_BINDINGS = {
  emberheart: {
    name: "Emberheart",
    color: "#e36b3d",
    mark: "✸",
    copy: "The Binding finds an ember in your margin. You lean toward authored doors, brave revisions, and the stubborn belief that the next sentence can still be yours.",
  },
  mossbloom: {
    name: "Mossbloom",
    color: "#8db76f",
    mark: "❦",
    copy: "The Binding finds moss between your pages. You listen before naming, keep what grows slowly, and suspect the world has been speaking longer than anyone admits.",
  },
  tidecrest: {
    name: "Tidecrest",
    color: "#66c5d2",
    mark: "≈",
    copy: "The Binding finds tide marks on the paper. You trust the vivid present: sudden weather, unfinished music, and moments complete before a plot can claim them.",
  },
  riddlewind: {
    name: "Riddlewind",
    color: "#d7a748",
    mark: "⌁",
    copy: "The Binding finds a cipher written in two hands. You make meaning in company, leave room for replies, and know the best doors often require someone on either side.",
  },
  duskthorn: {
    name: "Duskthorn",
    color: "#8d6bb0",
    mark: "†",
    copy: "The Binding finds a thorn protecting the page. You choose the honest edge over the easy answer and know that boundaries are sometimes how a tender thing survives.",
  },
};

(function initChapterBelief() {
  const buttons = [...document.querySelectorAll("[data-chapter]")];
  const whisper = document.querySelector("#chapter-whisper");
  const page = document.querySelector("#binding-page");
  if (!buttons.length || !page) return;

  const scores = Object.fromEntries(buttons.map((button) => [button.dataset.chapter, 0]));
  let touches = 0;
  let latestChapter = buttons[0].dataset.chapter;

  function revealBinding() {
    const highest = Math.max(...Object.values(scores));
    if (highest === 0) return;
    const winners = Object.keys(scores).filter((key) => scores[key] === highest);
    const key = winners.includes(latestChapter) ? latestChapter : winners[0];
    const binding = CHAPTER_BINDINGS[key];
    page.style.setProperty("--binding-color", binding.color);
    page.querySelector("#binding-mark").textContent = binding.mark;
    page.querySelector("#binding-title").textContent = `The Binding recognizes ${binding.name}.`;
    page.querySelector("#binding-copy").textContent = binding.copy;
    page.hidden = false;
  }

  buttons.forEach((button) => {
    button.addEventListener("click", () => {
      const key = button.dataset.chapter;
      const binding = CHAPTER_BINDINGS[key];
      const next = scores[key] >= 2 ? 0 : scores[key] + 1;
      scores[key] = next;
      latestChapter = key;
      touches += 1;

      const card = button.closest("[data-chapter-card]");
      const count = button.querySelector(".chapter-belief-count");
      card?.classList.toggle("has-belief", next > 0);
      count.textContent = next === 0 ? "Give Belief" : `Belief · ${next === 1 ? "I" : "II"}`;
      button.setAttribute("aria-label", next === 0
        ? `Give Belief to ${binding.name}`
        : `${binding.name} holds ${next} Belief. Activate to ${next === 2 ? "release it" : "deepen it"}.`);

      if (whisper) {
        whisper.textContent = next === 0
          ? `${binding.name} releases its claim. The page grows quiet again.`
          : `${binding.name} holds ${next === 1 ? "a little" : "deep"} Belief. The talisman is warmer now.`;
      }
      if (touches >= 5) revealBinding();
    });
  });
})();

/* ───────────────────────── assistant archivists ───────────────────────── */
const footerCats = document.querySelector("#footer-cats");
const catNote = document.querySelector("#cat-note");
footerCats?.addEventListener("click", () => {
  const open = footerCats.getAttribute("aria-expanded") !== "true";
  footerCats.setAttribute("aria-expanded", String(open));
  if (catNote) catNote.hidden = !open;
});

if (footerCats && !reduceMotion) {
  let blinkTimer;

  function blinkOnce() {
    footerCats.classList.remove("is-blinking");
    // Restarting on the next frame keeps an occasional double-blink crisp.
    requestAnimationFrame(() => footerCats.classList.add("is-blinking"));
    window.setTimeout(() => footerCats.classList.remove("is-blinking"), 330);
  }

  function scheduleBlink(delay = 1200 + Math.random() * 1400) {
    window.clearTimeout(blinkTimer);
    blinkTimer = window.setTimeout(() => {
      blinkOnce();

      // Cats rarely keep metronomic time. Sometimes a second thought follows.
      if (Math.random() < 0.28) window.setTimeout(blinkOnce, 390);
      scheduleBlink(2600 + Math.random() * 4300);
    }, delay);
  }

  scheduleBlink();
}

/* ───────────────────────── ReEnchanted Radio ─────────────────────────
   Stations mirror the app's RadioStationRegistry. To add audio: drop a file
   in assets/audio/ and set `src` on a track (null = signal carries no
   recording yet). Add a whole station by appending to STATIONS.          */
const STATIONS = [
  {
    id: "fae-fi",
    name: "Fae-Fi",
    host: "Penny Blackletter",
    freq: 88.3,
    signal: "The signal arrives giggling, tasting of clover honey and warm afternoons.",
    tagline: "Sun-dappled beats and dandelion synths from faeries who have plainly had too much nectar.",
    effect: "Wonder Compass +8 · Souvenir +8 · Festival +6",
    tracks: [
      { id: "fae-fi-mossy-footsteps", title: "Mossy Footsteps", artist: "Fae-Fi", src: "./assets/audio/fae-fi-mossy-footsteps.m4a" },
      { id: "fae-fi-folktronica", title: "Folktronica", artist: "Fae-Fi", src: "./assets/audio/fae-fi-folktronica.m4a" },
      { id: "fae-fi-mossy-groove", title: "Mossy Groove", artist: "Fae-Fi", src: "./assets/audio/fae-fi-mossy-groove.m4a" },
      { id: "fae-fi-to-the-adventure", title: "To the Adventure", artist: "Fae-Fi", src: "./assets/audio/fae-fi-to-the-adventure.m4a" },
      { id: "fae-fi-pages-rising", title: "Pages Rising", artist: "Fae-Fi", src: "./assets/audio/fae-fi-pages-rising.m4a" },
    ],
    /* DJ breaks between songs, voiced by Penny Blackletter. A `track` +
       `placement` (intro/outro) binds a transition to its song; the rest are
       selected by the live curator. Mirrors the app's RadioBanter playout. */
    banters: [
      { id: "faefi-id-01", category: "stationID", src: "./assets/audio/fae-fi-penny-id-01.m4a",
        caption: "You've reached Fae-Fi. Eighty-eight point three on the Academy band. I keep the records here. Today's record is: the pixies are fine, the pixies are too fine, please send help. Anyway. Music." },
      { id: "faefi-id-02", category: "stationID", src: "./assets/audio/fae-fi-penny-id-02.m4a",
        caption: "Penny Blackletter, against my professional judgment, on Fae-Fi. I'm taking notes. For The Bleed. It's mostly exclamation points." },
      { id: "faefi-id-03", category: "stationID", src: "./assets/audio/fae-fi-penny-id-03.m4a",
        caption: "Fae-Fi, eighty-eight point three. One honest detail can save a day. Today's, filed for the record: the light came back. Here's a song about it." },
      { id: "faefi-outro-mossyfootsteps", category: "transition", track: "Mossy Footsteps", placement: "outro",
        src: "./assets/audio/fae-fi-penny-outro-mossyfootsteps.m4a",
        caption: "That was Mossy Footsteps. There was no one there. There is never anyone there. I've started a folder." },
      { id: "faefi-intro-folktronica", category: "transition", track: "Folktronica", placement: "intro",
        src: "./assets/audio/fae-fi-penny-intro-folktronica.m4a",
        caption: "Coming up — Folktronica. A bird wrote the hook. The bird has filed a complaint. We're all very busy here." },
      { id: "faefi-outro-mossygroove", category: "transition", track: "Mossy Groove", placement: "outro",
        src: "./assets/audio/fae-fi-penny-outro-mossygroove.m4a",
        caption: "You just heard Mossy Groove. A patch of clover is dancing and will not stop, and I have, regrettably, transcribed all of it." },
      { id: "faefi-sponsor-thistledown", category: "sponsor", src: "./assets/audio/fae-fi-penny-sponsor-thistledown.m4a",
        caption: "Fae-Fi runs on dandelion synths and Thistledown & Co., purveyors of pocket-sized weather. Caught in the grey? A Thistledown sunbeam fits in any coat. That part, I checked. It's true." },
      { id: "faefi-sponsor-cloverhoney", category: "sponsor", src: "./assets/audio/fae-fi-penny-sponsor-clover-honey.m4a",
        conditions: { timeOfDay: ["dawn", "day"] },
        caption: "Today's brightness is brought to you by the Clover Honey Collective. Their slogan arrived far too polished, so I rewrote it: the afternoon's only as warm as you bothered to taste. It does hum. I have the recording." },
      { id: "faefi-gossip-tuesday", category: "gossip", src: "./assets/audio/fae-fi-penny-gossip-tuesday.m4a",
        conditions: { weekdays: [2] },
        caption: "Somebody traded a perfectly good Tuesday for one more loop of this song. Filed under evidence the music is working. Flawless decision. No notes." },
      { id: "faefi-gossip-window", category: "gossip", src: "./assets/audio/fae-fi-penny-gossip-window.m4a",
        caption: "From my desk at The Bleed: the Wonder Compass has pointed at the same window all week. If it's your window, that's a fact you've been avoiding. Go see." },
      { id: "faefi-news-grey", category: "news", src: "./assets/audio/fae-fi-penny-news-grey.m4a",
        caption: "Filed this morning, off Today's Sky: the grey lost three feet of ground. Somebody noticed one true particular and wrote it down. That's the whole arithmetic of this place." },
      { id: "faefi-news-festival", category: "news", src: "./assets/audio/fae-fi-penny-news-festival.m4a",
        caption: "Festival weather incoming. I'll be in the corner, cataloguing joy as it happens, which is, I'm told, not the point of joy. Bring a souvenir." },
    ],
  },
  {
    id: "mothlight",
    name: "Mothlight Beats",
    host: "Professor Eleanor Euphony",
    freq: 90.9,
    signal: "The static flutters at the glass like it remembers being a summer you lost.",
    tagline: "Dusk-soft loops for the ache of lovely things ending, lit by wings against the lamp.",
    effect: "Book Remembered +10 · Mood +7 · Diary +6",
    tracks: [
      { id: "mothlight-the-page-came-through", title: "The Page Came Through", artist: "Mothlight Beats", src: "./assets/audio/mothlight-the-page-came-through.m4a" },
      { id: "mothlight-fae-dust", title: "Fae Dust", artist: "Mothlight Beats", src: "./assets/audio/mothlight-fae-dust.m4a" },
      { id: "mothlight-afternoon-chapters", title: "Afternoon Chapters", artist: "Mothlight Beats", src: "./assets/audio/mothlight-afternoon-chapters.m4a" },
      { id: "mothlight-porchlight-fading", title: "Porchlight, Fading", artist: "Mothlight Beats", src: null },
    ],
    banters: [
      { id: "mothlight-id-01", category: "stationID", src: "./assets/audio/mothlight-euphony-id-01.m4a",
        caption: "…there. Now the room's in tune. This is Mothlight Beats, ninety point nine — Professor Euphony, holding the lamp for the ache of lovely things ending." },
      { id: "mothlight-id-02", category: "stationID", src: "./assets/audio/mothlight-euphony-id-02.m4a",
        caption: "You're listening in the key of dusk. Mothlight, ninety point nine on the Academy band. I hear what you walked in carrying. We'll set it to music and it'll weigh less." },
      { id: "mothlight-id-03", category: "stationID", src: "./assets/audio/mothlight-euphony-id-03.m4a",
        caption: "Mothlight Beats. The static remembers being a summer you lost — listen, it's a minor seventh. Stay in it with me a while." },
      { id: "mothlight-outro-the-page-came-through", category: "transition", track: "The Page Came Through", placement: "outro",
        src: "./assets/audio/mothlight-euphony-outro-the-page-came-through.m4a",
        caption: "That was “The Page Came Through”… they always do, in the end. The ones you thought were gone. Here's something to let settle on you." },
      { id: "mothlight-outro-fae-dust", category: "transition", track: "Fae Dust", placement: "outro",
        src: "./assets/audio/mothlight-euphony-outro-fae-dust.m4a",
        caption: "“Fae Dust,” just then — yes, that itch behind your eyes is on purpose. Breathe. Mothlight has you." },
      { id: "mothlight-sponsor-porchlight-moth", category: "sponsor",
        src: "./assets/audio/mothlight-euphony-sponsor-porchlight-moth.m4a",
        caption: "Mothlight glows by the grace of Porchlight & Moth, keepers of the lamp left on — for everyone you're still waiting up for. Find them at dusk, where the diary opens." },
      { id: "mothlight-sponsor-the-remembering", category: "sponsor",
        src: "./assets/audio/mothlight-euphony-sponsor-the-remembering.m4a",
        caption: "Tonight's hush is held by The Remembering, a small shop in the Book Remembered. Bring them a page you thought you'd lost. They'll coax it back into the light — no charge." },
      { id: "mothlight-gossip-inner-weather", category: "gossip",
        src: "./assets/audio/mothlight-euphony-gossip-inner-weather.m4a",
        caption: "Penny files The Bleed dry, so let me sing it: somebody's inner weather finally broke into rain. Where you come from, that's not a storm — that's how the garden gets watered. If it's you, it's allowed." },
      { id: "mothlight-gossip-inkrest-lamp", category: "gossip",
        src: "./assets/audio/mothlight-euphony-gossip-inkrest-lamp.m4a",
        caption: "A note carried in on the dusk: Dr. Inkrest left her office lamp on past hours again. If the day sat heavy as a low note, her door is the kind that opens. No appointment. Just weather, and a chair, and a lamp." },
    ],
  },
  {
    id: "thornwave",
    name: "Thornwave",
    host: "Wicker Eddies",
    freq: 103.7,
    signal: "The bass moves like something with antlers stepping between the trees.",
    tagline: "Bramble bass, broken-glass garage, and bargains struck in the low end after midnight.",
    effect: "Book Fae +10 · Narrative OS +8 · Gossip +6",
    tracks: [
      { id: "thornwave-bramble-bass", title: "Bramble Bass", artist: "Thornwave", src: "./assets/audio/thornwave-bramble-bass.m4a" },
      { id: "thornwave-nocturnal-faerie-lounge", title: "Nocturnal Faerie Lounge", artist: "Thornwave", src: "./assets/audio/thornwave-nocturnal-faerie-lounge.m4a" },
      { id: "thornwave-mossy-night", title: "Mossy Night", artist: "Thornwave", src: "./assets/audio/thornwave-mossy-night.m4a" },
    ],
    banters: [
      { id: "thornwave-id-01", category: "stationID", src: "./assets/audio/thornwave-wicker-id-01.m4a",
        conditions: { timeOfDay: ["dusk", "night"] },
        caption: "Thornwave. One-oh-three point seven, after dark. Wicker Eddies, here to test whether anything you believe survives the bassline. Most of it won't. The stuff that does? That's the real magic. Stay tuned." },
      { id: "thornwave-id-02", category: "stationID", src: "./assets/audio/thornwave-wicker-id-02.m4a",
        caption: "You found Thornwave — one-oh-three seven, the frequency the dark fae kept for themselves. I puncture false magic for sport. This station isn't false. Felt that in your chest, didn't you. Good." },
      { id: "thornwave-id-03", category: "stationID", src: "./assets/audio/thornwave-wicker-id-03.m4a",
        conditions: { timeOfDay: ["dusk", "night"] },
        caption: "It's the hour rumors travel best, so I'm exactly where I belong. Wicker, on Thornwave. Keep your name to yourself. I collect those." },
      { id: "thornwave-outro-bramble-bass", category: "transition", track: "Bramble Bass", placement: "outro",
        src: "./assets/audio/thornwave-wicker-outro-bramble-bass.m4a",
        caption: "That was Bramble Bass. No theatrics, no glamour — just a thing that's actually true at a hundred and three point seven. Rare. Coming up, Nocturnal Faerie Lounge. Last call at the only bar the grey won't enter." },
      { id: "thornwave-outro-nocturnal-faerie-lounge", category: "transition", track: "Nocturnal Faerie Lounge", placement: "outro",
        src: "./assets/audio/thornwave-wicker-outro-nocturnal-faerie-lounge.m4a",
        caption: "Nocturnal Faerie Lounge, just now. Somebody in that crowd is making a deal they'll keep for thirty years. I'd talk them out of it — testing it, you understand — but the song's too good. Here's more." },
      { id: "thornwave-intro-bramble-bass", category: "transition", track: "Bramble Bass", placement: "intro",
        src: "./assets/audio/thornwave-wicker-intro-bramble-bass.m4a",
        caption: "The drop sounds like a door you were warned about, opening. I've never met a warning I didn't want to test. So — after this, let's open it. Bramble Bass." },
      { id: "thornwave-sponsor-bramblewine", category: "sponsor",
        src: "./assets/audio/thornwave-wicker-sponsor-bramblewine.m4a",
        caption: "Thornwave runs on favors owed and Bramblewine — aged in the dark, priced in the morning. One sip and the night belongs to you; two, and you belong to it. I've read the small print. There's always small print. That's the only honest thing at the Goblin Market — they tell you, then watch you not listen." },
      { id: "thornwave-sponsor-goblin-market", category: "sponsor",
        src: "./assets/audio/thornwave-wicker-sponsor-goblin-market.m4a",
        conditions: { timeOfDay: ["dusk", "night"] },
        caption: "Tonight's low end is sponsored by the Goblin Market. Open after hours. No refunds. All bargains binding. Tell Melisande over on one-oh-five that Wicker sent you, and she'll overcharge you with a straight face. Respect her for it. I do." },
      { id: "thornwave-gossip-pact", category: "gossip",
        src: "./assets/audio/thornwave-wicker-gossip-pact.m4a",
        caption: "Penny wouldn't print this — too unproven for the record — so I'll say it, because I prefer my truths a little dangerous: a pact came due this week. Somebody paid. The grey leaned one shade closer to whoever let it. Don't be that somebody. Plant the Belief. I'll wait. I'm patient when it matters." },
      { id: "thornwave-gossip-unwritten", category: "gossip",
        src: "./assets/audio/thornwave-wicker-gossip-unwritten.m4a",
        caption: "Rumor under the bassline. There's a chapter in this building nobody can jump into — yours, the Unwritten one. Everybody wants a look. They'd test it, pick it apart, like I would. Don't let us. Write it yourself first." },
      { id: "thornwave-news-nothing", category: "news",
        src: "./assets/audio/thornwave-wicker-news-grey.m4a",
        conditions: { timeOfDay: ["dusk", "night"] },
        caption: "Tonight's reading off Today's Sky: the Nothing made a move at the edges. We held. We always hold — barely, on purpose, which is the only kind of holding worth anything. Believe something out loud. I dare you. That's not mockery. That's the assignment." },
      { id: "thornwave-news-pact-dispatch", category: "news",
        src: "./assets/audio/thornwave-wicker-news-pact-dispatch.m4a",
        conditions: { timeOfDay: ["dusk", "night"] },
        caption: "Pact Dispatch is busy tonight. Three bargains struck, two already regretted, one that'll change a life. I can usually tell which is which — it's my whole talent. Tonight? Can't call it. That's how you know it's real. More Thornwave, after this." },
    ],
  },
  {
    id: "the-bleed",
    name: "THE BLEED // UNAUTHORIZED",
    host: "Unknown Correspondent",
    freq: 97.3,
    hidden: true,
    signal: "The static parts around a voice that was not cleared for broadcast.",
    tagline: "This frequency does not appear on the Academy band. You did not find it, and Penny Blackletter did not leave the transmitter unlocked.",
    effect: "Record compromised · Margins awake · Plausible deniability −12",
    tracks: [
      { id: "the-bleed-intercept", title: "Intercept 97.3", artist: "Unknown Correspondent", src: "./assets/audio/the-bleed-pirate-signal.m4a" },
    ],
  },
];

(function initRadio() {
  const dial = document.querySelector("#dial");
  if (!dial) return;

  const elFreq = document.querySelector("#radio-freq");
  const elName = document.querySelector("#radio-name");
  const onair = document.querySelector("#onair-btn");
  const power = document.querySelector("#radio-power-btn");
  const volume = document.querySelector("#radio-volume");
  const volumeControl = document.querySelector("#radio-volume-control");
  const volumeOutput = document.querySelector("#radio-volume-output");
  const onairLabel = onair.querySelector(".onair-label");
  const elSignal = document.querySelector("#radio-signal-text");
  const elTagline = document.querySelector("#radio-tagline");
  const elEffect = document.querySelector("#radio-effect");
  const trackList = document.querySelector("#track-list");
  const elNote = document.querySelector("#radio-note");
  const card = document.querySelector("#radio-card");
  const scale = document.querySelector("#dial-scale");
  const waveCanvas = document.querySelector("#radio-wave");
  const waveCtx = waveCanvas && waveCanvas.getContext("2d");

  const TOLERANCE = 0.5; // FM units within which a station "locks in"
  const FMIN = 88, FMAX = 108;
  const audio = new Audio();
  const VOLUME_STORAGE_KEY = "reenchanted-radio-volume";
  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  let tuned = STATIONS[0];
  let onAir = false;
  let trackIndex = 0;
  let lastTrackID = null;
  let recentTrackIDs = [];
  let tracksSinceTune = 0;
  let songsSinceBanter = 0;
  let audioCtx = null;
  let analyser = null;
  let audioSource = null;
  let gainNode = null;
  let currentVolume = 0.72;
  let frequencyData = null;
  let waveFrame = null;
  // Banter playout: a DJ break between songs, with a short recent history.
  let playingBanter = false;
  let pendingTrackIndex = null;
  let recentBanterIDs = [];
  let recentBanterCategories = [];
  const BANTER_HISTORY_LIMIT = 6;
  const CURATION_SEED = globalThis.crypto?.randomUUID?.()
    || `${Date.now()}-${Math.random().toString(36).slice(2)}`;

  function storedVolume() {
    try {
      const stored = localStorage.getItem(VOLUME_STORAGE_KEY);
      if (stored === null) return 72;
      const saved = Number(stored);
      return Number.isFinite(saved) && saved >= 0 && saved <= 100 ? saved : 72;
    } catch (_) {
      return 72;
    }
  }

  function setVolume(value, persist = false) {
    const level = Math.max(0, Math.min(100, Math.round(Number(value))));
    currentVolume = level / 100;
    if (gainNode && audioCtx) {
      audio.volume = 1;
      gainNode.gain.setTargetAtTime(currentVolume, audioCtx.currentTime, 0.012);
    } else {
      audio.volume = currentVolume;
    }
    volume.value = String(level);
    volume.setAttribute("aria-valuetext", `${level} percent`);
    volumeControl.style.setProperty("--volume-angle", `${(-120 + level * 2.4).toFixed(1)}deg`);
    volumeControl.classList.toggle("is-muted", level === 0);
    volumeControl.title = `${level === 0 ? "Radio muted" : `Radio volume ${level}%`} · drag up or down`;
    volumeOutput.value = String(level);
    volumeOutput.textContent = String(level);
    if (persist) {
      try { localStorage.setItem(VOLUME_STORAGE_KEY, String(level)); } catch (_) {}
    }
  }

  volume.addEventListener("input", () => setVolume(volume.value));
  volume.addEventListener("change", () => setVolume(volume.value, true));
  volume.addEventListener("keydown", (event) => {
    const level = Number(volume.value);
    const next = {
      ArrowUp: level + 2,
      ArrowRight: level + 2,
      ArrowDown: level - 2,
      ArrowLeft: level - 2,
      PageUp: level + 10,
      PageDown: level - 10,
      Home: 0,
      End: 100,
    }[event.key];
    if (next == null) return;
    event.preventDefault();
    setVolume(next, true);
  });

  let volumeDrag = null;
  volume.addEventListener("pointerdown", (event) => {
    if (event.button !== 0) return;
    event.preventDefault();
    volume.focus({ preventScroll: true });
    volume.setPointerCapture?.(event.pointerId);
    volumeDrag = {
      pointerID: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      startValue: Number(volume.value),
    };
    volumeControl.classList.add("is-adjusting");
  });
  volume.addEventListener("pointermove", (event) => {
    if (!volumeDrag || event.pointerId !== volumeDrag.pointerID) return;
    event.preventDefault();
    const horizontal = event.clientX - volumeDrag.startX;
    const vertical = volumeDrag.startY - event.clientY;
    setVolume(volumeDrag.startValue + (horizontal + vertical) * 1.35);
  });

  function finishVolumeDrag(event) {
    if (!volumeDrag || event.pointerId !== volumeDrag.pointerID) return;
    volume.releasePointerCapture?.(event.pointerId);
    volumeDrag = null;
    volumeControl.classList.remove("is-adjusting");
    setVolume(volume.value, true);
  }

  volume.addEventListener("pointerup", finishVolumeDrag);
  volume.addEventListener("pointercancel", finishVolumeDrag);
  setVolume(storedVolume());

  // build the station labels along the scale
  STATIONS.filter((station) => !station.hidden).forEach((s) => {
    const mark = document.createElement("span");
    mark.className = "scale-mark";
    mark.style.left = `${((s.freq - FMIN) / (FMAX - FMIN)) * 100}%`;
    mark.innerHTML = `<i></i>${s.freq.toFixed(1)}`;
    mark.title = s.name;
    mark.addEventListener("click", () => { dial.value = s.freq; onDial(); });
    scale.appendChild(mark);
  });

  function nearest(freq) {
    const hidden = STATIONS.find((station) => station.hidden && Math.abs(station.freq - freq) < 0.051);
    if (hidden) return hidden;
    let best = null, dist = Infinity;
    for (const s of STATIONS) {
      if (s.hidden) continue;
      const d = Math.abs(s.freq - freq);
      if (d < dist) { dist = d; best = s; }
    }
    return dist <= TOLERANCE ? best : null;
  }

  function stableHash(value) {
    const bytes = new TextEncoder().encode(value);
    let hash = 0xcbf29ce484222325n;
    for (const byte of bytes) {
      hash ^= BigInt(byte);
      hash = BigInt.asUintN(64, hash * 0x100000001b3n);
    }
    return BigInt.asUintN(64, hash);
  }

  function weightedScore(seed, weight = 1) {
    const mask53 = (1n << 53n) - 1n;
    const unit = (Number(stableHash(seed) & mask53) + 1) / (Number(mask53) + 2);
    return -Math.log(unit) / Math.max(0.05, weight);
  }

  function radioContext(value = Date.now()) {
    const date = value instanceof Date ? value : new Date(value);
    const hour = date.getHours();
    return {
      hour,
      minute: date.getMinutes(),
      weekday: date.getDay(),
      isWeekend: date.getDay() === 0 || date.getDay() === 6,
      timeOfDay: hour >= 5 && hour < 8 ? "dawn"
        : hour >= 8 && hour < 17 ? "day"
          : hour >= 17 && hour < 21 ? "dusk" : "night",
    };
  }

  // Optional catalog gates make future tracks and banter world-aware without
  // another playout rewrite. Absent conditions mean "always eligible."
  function conditionsFit(conditions, context) {
    if (!conditions) return true;
    if (conditions.timeOfDay && !conditions.timeOfDay.includes(context.timeOfDay)) return false;
    if (conditions.weekdays && !conditions.weekdays.includes(context.weekday)) return false;
    if (conditions.weekend === true && !context.isWeekend) return false;
    if (conditions.weekend === false && context.isWeekend) return false;
    if (conditions.minHour != null && context.hour < conditions.minHour) return false;
    if (conditions.maxHour != null && context.hour > conditions.maxHour) return false;
    return true;
  }

  function selectCuratedTrackIndex(station, previousTrackID = null, playTurn = 0, now = Date.now()) {
    if (!station || !station.tracks.length) return -1;
    const context = radioContext(now);
    const allPlayable = station.tracks
      .map((track, index) => ({ track, index }))
      .filter((entry) => entry.track.src);
    if (!allPlayable.length) return -1;
    const contextual = allPlayable.filter((entry) => conditionsFit(entry.track.conditions, context));
    const playable = contextual.length ? contextual : allPlayable;
    const fresh = playable.filter((entry) =>
      entry.track.id !== previousTrackID && !recentTrackIDs.includes(entry.track.id));
    const nonRepeating = playable.filter((entry) => entry.track.id !== previousTrackID);
    const pool = fresh.length ? fresh : nonRepeating.length ? nonRepeating : playable;
    const slot = Math.floor((Number(now) / 1000) / 1800);
    const prior = previousTrackID || "start";
    return pool.reduce((best, entry) => {
      const score = weightedScore(
        `${CURATION_SEED}|track|${station.id}|${prior}|${playTurn}|${slot}|${context.timeOfDay}|${entry.track.id}|${entry.index}`,
        entry.track.weight || 1
      );
      return !best || score < best.score ? { ...entry, score } : best;
    }, null).index;
  }

  function selectNextTrackIndex(station) {
    return selectCuratedTrackIndex(station, lastTrackID, tracksSinceTune);
  }

  function resizeWaveCanvas() {
    if (!waveCanvas || !waveCtx) return { width: 0, height: 0 };
    const rect = waveCanvas.getBoundingClientRect();
    const dpr = Math.max(1, Math.min(2, window.devicePixelRatio || 1));
    const width = Math.max(1, Math.floor(rect.width * dpr));
    const height = Math.max(1, Math.floor(rect.height * dpr));
    if (waveCanvas.width !== width || waveCanvas.height !== height) {
      waveCanvas.width = width;
      waveCanvas.height = height;
    }
    waveCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
    return { width: rect.width, height: rect.height };
  }

  function drawWaveIdle() {
    if (!waveCanvas || !waveCtx) return;
    const { width, height } = resizeWaveCanvas();
    if (!width || !height) return;
    waveCtx.clearRect(0, 0, width, height);
    const mid = height / 2;
    waveCtx.strokeStyle = "rgba(28,108,105,0.38)";
    waveCtx.lineWidth = 1;
    waveCtx.beginPath();
    waveCtx.moveTo(16, mid);
    waveCtx.lineTo(width - 16, mid);
    waveCtx.stroke();
    waveCtx.fillStyle = "rgba(28,108,105,0.34)";
    for (let x = 20; x < width - 16; x += 18) {
      waveCtx.beginPath();
      waveCtx.arc(x, mid, 1.6, 0, Math.PI * 2);
      waveCtx.fill();
    }
  }

  function ensureWaveAnalyser() {
    if (!waveCanvas || !waveCtx || !AudioContextClass) return;
    if (!audioCtx) {
      audioCtx = new AudioContextClass();
      analyser = audioCtx.createAnalyser();
      gainNode = audioCtx.createGain();
      analyser.fftSize = 512;
      analyser.smoothingTimeConstant = 0.72;
      gainNode.gain.value = currentVolume;
      frequencyData = new Uint8Array(analyser.frequencyBinCount);
      audioSource = audioCtx.createMediaElementSource(audio);
      audioSource.connect(gainNode);
      gainNode.connect(analyser);
      analyser.connect(audioCtx.destination);
      // The gain node owns output level once the Web Audio graph is live.
      audio.volume = 1;
    }
    if (audioCtx.state === "suspended") audioCtx.resume().catch(() => {});
    startWaveLoop();
  }

  function drawWaveFrame() {
    waveFrame = null;
    if (!waveCanvas || !waveCtx) return;
    const { width, height } = resizeWaveCanvas();
    if (!width || !height) return;

    waveCtx.clearRect(0, 0, width, height);
    const isLiveAudio = Boolean(onAir && analyser && frequencyData && !audio.paused && !audio.ended);
    const mid = height / 2;
    const barCount = Math.max(24, Math.min(56, Math.floor(width / 10)));
    const gap = Math.max(2, width * 0.006);
    const barWidth = Math.max(3, (width - gap * (barCount + 1)) / barCount);
    const primary = tuned?.hidden ? "93,214,104" : playingBanter ? "143,46,43" : "28,108,105";
    const secondary = tuned?.hidden ? "196,255,179" : "255,200,116";

    if (isLiveAudio) {
      analyser.smoothingTimeConstant = playingBanter ? 0.42 : 0.74;
      analyser.getByteFrequencyData(frequencyData);
    }

    for (let i = 0; i < barCount; i++) {
      let level = 0;
      if (isLiveAudio) {
        const usableBins = Math.floor(frequencyData.length * (playingBanter ? 0.44 : 0.72));
        const start = Math.floor((i / barCount) * usableBins);
        const end = Math.max(start + 1, Math.floor(((i + 1) / barCount) * usableBins));
        let total = 0;
        for (let bin = start; bin < end; bin++) total += frequencyData[bin];
        level = total / ((end - start) * 255);
      }
      const shaped = Math.pow(Math.max(0.02, level), playingBanter ? 1.15 : 1.35);
      const barHeight = 4 + shaped * (height * (playingBanter ? 0.66 : 0.78));
      const x = gap + i * (barWidth + gap);
      const y = mid - barHeight / 2;
      const gradient = waveCtx.createLinearGradient(0, y, 0, y + barHeight);
      gradient.addColorStop(0, `rgba(${secondary},0.82)`);
      gradient.addColorStop(0.5, `rgba(${primary},0.94)`);
      gradient.addColorStop(1, `rgba(${secondary},0.62)`);
      waveCtx.fillStyle = gradient;
      waveCtx.fillRect(x, y, barWidth, barHeight);
    }

    waveCtx.strokeStyle = `rgba(${primary},0.28)`;
    waveCtx.lineWidth = 1;
    waveCtx.beginPath();
    waveCtx.moveTo(12, mid);
    waveCtx.lineTo(width - 12, mid);
    waveCtx.stroke();

    if (onAir) {
      waveFrame = requestAnimationFrame(drawWaveFrame);
    } else {
      drawWaveIdle();
    }
  }

  function startWaveLoop() {
    if (!waveCanvas || !waveCtx || waveFrame) return;
    waveFrame = requestAnimationFrame(drawWaveFrame);
  }

  function stopWaveLoop() {
    if (waveFrame) {
      cancelAnimationFrame(waveFrame);
      waveFrame = null;
    }
    drawWaveIdle();
  }

  function renderTracks() {
    trackList.innerHTML = "";
    tuned.tracks.forEach((t, i) => {
      const li = document.createElement("li");
      li.className = "track";
      const playable = Boolean(t.src);
      li.classList.toggle("playable", playable);
      li.classList.toggle("now-playing", onAir && playable && i === trackIndex);
      li.innerHTML = `
        <span class="track-state" aria-hidden="true">${onAir && playable && i === trackIndex ? "♫" : playable ? "▷" : "—"}</span>
        <span class="track-meta"><strong>${t.title}</strong><small>${t.artist}</small></span>
        <span class="track-tag">${playable ? "" : "no recording yet"}</span>`;
      if (playable) li.addEventListener("click", () => { trackIndex = i; play(); });
      trackList.appendChild(li);
    });
  }

  function setOnAir(state) {
    onAir = state;
    onair.setAttribute("aria-pressed", String(state));
    onair.classList.toggle("live", state);
    card.classList.toggle("live", state);
    onairLabel.textContent = state ? "On Air" : "Tune In";
    if (power) power.disabled = !state;
    if (state) startWaveLoop();
    else stopWaveLoop();
  }

  function powerOffBroadcast(message = "Broadcast off. Press Tune In to return to the station.") {
    audio.pause();
    playingBanter = false;
    pendingTrackIndex = null;
    card.classList.remove("on-banter");
    if (tuned) elName.textContent = tuned.name;
    if (elNote) elNote.textContent = message;
    setOnAir(false);
    renderTracks();
  }

  function play() {
    // A real song is starting — clear any DJ-break presentation.
    playingBanter = false;
    card.classList.remove("on-banter");
    if (tuned) { elName.textContent = tuned.name; if (elNote) elNote.textContent = ""; }
    const t = tuned.tracks[trackIndex];
    if (!t || !t.src) { audio.pause(); return; }
    if (audio.src.indexOf(t.src.replace("./", "")) === -1) audio.src = t.src;
    ensureWaveAnalyser();
    audio.play().catch(() => {});
    lastTrackID = t.id || t.title;
    recentTrackIDs = recentTrackIDs.filter((id) => id !== lastTrackID);
    recentTrackIDs.push(lastTrackID);
    const playableCount = tuned.tracks.filter((track) => track.src).length;
    const trackMemory = Math.max(1, Math.floor((playableCount - 1) / 2));
    if (recentTrackIDs.length > trackMemory) {
      recentTrackIDs.splice(0, recentTrackIDs.length - trackMemory);
    }
    setOnAir(true);
    renderTracks();
  }

  function firstPlayableIndex() {
    return tuned.tracks.findIndex((t) => t.src);
  }

  function banterWeight(banter, context) {
    let weight = banter.weight || 1;
    if (banter.category === "stationID") weight *= tracksSinceTune <= 2 ? 2.2 : 0.65;
    if (banter.category === "transition" && banter.track) weight *= 2.1;
    if (banter.category === "sponsor") weight *= 0.72;
    if (banter.category === "gossip" && ["dusk", "night"].includes(context.timeOfDay)) weight *= 1.45;
    if (banter.category === "news" && context.minute < 12) weight *= 1.75;
    return weight;
  }

  // Choose from the whole eligible catalog. Recent clips and categories cool
  // down; context changes weights; bound transitions still land beside the
  // correct song. There is deliberately no category playlist to march through.
  function pickBanter(justTitle, upcomingTitle) {
    const all = tuned.banters || [];
    if (!all.length) return null;
    const context = radioContext();
    const fits = (b) => {
      if (b.category !== "transition" || !b.track) return true;
      if (b.placement === "intro") return b.track === upcomingTitle;
      if (b.placement === "outro") return b.track === justTitle;
      return b.track === justTitle || b.track === upcomingTitle;
    };
    const eligible = all.filter((b) => b.src && fits(b) && conditionsFit(b.conditions, context));
    if (!eligible.length) return null;
    const fresh = eligible.filter((b) => !recentBanterIDs.includes(b.id || b.src));
    let pool = fresh.length
      ? fresh
      : eligible.filter((b) => (b.id || b.src) !== recentBanterIDs.at(-1));
    if (!pool.length) pool = eligible;
    const categoryFresh = pool.filter((b) => !recentBanterCategories.includes(b.category));
    if (categoryFresh.length) pool = categoryFresh;
    const slot = Math.floor(Date.now() / 900000);
    return pool.reduce((best, banter) => {
      const score = weightedScore(
        `${CURATION_SEED}|banter|${tuned.id}|${slot}|${tracksSinceTune}|${justTitle}|${upcomingTitle}|${banter.id || banter.src}`,
        banterWeight(banter, context)
      );
      return !best || score < best.score ? { banter, score } : best;
    }, null)?.banter || null;
  }

  // Cadence breathes too: one or two songs between breaks, with song-bound
  // moments more likely to speak. Two quiet songs always earn a voice break.
  function shouldBanter(justTitle, upcomingTitle) {
    const all = tuned.banters || [];
    if (!all.length) return false;
    if (songsSinceBanter >= 2) return true;
    const hasBoundMoment = all.some((b) => b.track && (
      (b.placement === "intro" && b.track === upcomingTitle)
      || (b.placement === "outro" && b.track === justTitle)
    ));
    const probability = hasBoundMoment ? 0.82 : 0.58;
    const slot = Math.floor(Date.now() / 300000);
    const roll = Number(stableHash(
      `${CURATION_SEED}|cadence|${tuned.id}|${tracksSinceTune}|${slot}`
    ) % 10000n) / 10000;
    return roll < probability;
  }

  function playBanter(b, nextIndex) {
    playingBanter = true;
    pendingTrackIndex = nextIndex;
    const historyID = b.id || b.src;
    recentBanterIDs = recentBanterIDs.filter((id) => id !== historyID);
    recentBanterIDs.push(historyID);
    if (recentBanterIDs.length > BANTER_HISTORY_LIMIT) recentBanterIDs.shift();
    recentBanterCategories.push(b.category);
    if (recentBanterCategories.length > 2) recentBanterCategories.shift();
    songsSinceBanter = 0;
    audio.src = b.src;
    ensureWaveAnalyser();
    audio.play().catch(() => {});
    elName.textContent = b.host || tuned.host || "Station DJ";
    if (elNote) elNote.textContent = "“" + b.caption + "”";
    card.classList.add("on-banter");
    renderTracks();
  }

  audio.addEventListener("ended", () => {
    const playable = tuned.tracks.map((t, i) => (t.src ? i : -1)).filter((i) => i >= 0);
    if (playable.length === 0) return;

    if (playingBanter) {
      // Break finished — play the song held behind it.
      playingBanter = false;
      card.classList.remove("on-banter");
      trackIndex = pendingTrackIndex != null ? pendingTrackIndex : trackIndex;
      pendingTrackIndex = null;
      play();
      return;
    }

    // A song finished. Look both ways for an appropriate banter before the next one.
    tracksSinceTune++;
    songsSinceBanter++;
    const justTitle = tuned.tracks[trackIndex] && tuned.tracks[trackIndex].title;
    const nextIndex = selectNextTrackIndex(tuned);
    const upcomingTitle = tuned.tracks[nextIndex] && tuned.tracks[nextIndex].title;
    const banter = shouldBanter(justTitle, upcomingTitle)
      ? pickBanter(justTitle, upcomingTitle)
      : null;
    if (banter) {
      playBanter(banter, nextIndex);
    } else {
      trackIndex = nextIndex;
      play();
    }
  });

  audio.addEventListener("error", () => {
    if (!tuned?.hidden) return;
    powerOffBroadcast("The frequency is open, but the intercepted recording has not crossed through yet.");
  });

  function tuneTo(station, betweenFreq) {
    const wasOnAir = onAir;
    elFreq.textContent = `${(station ? station.freq : betweenFreq).toFixed(1)} FM`;
    card.classList.toggle("pirate", Boolean(station?.hidden));
    if (!station) {
      tuned = null;
      lastTrackID = null;
      recentTrackIDs = [];
      tracksSinceTune = 0;
      songsSinceBanter = 0;
      audio.pause();
      setOnAir(false);
      elName.textContent = "— — —";
      elSignal.textContent = "Static between stations.";
      elTagline.textContent = "Keep turning the dial.";
      elEffect.textContent = "";
      trackList.innerHTML = "";
      elNote.textContent = "Nudge toward 88.3, 90.9, or 103.7.";
      card.classList.add("between");
      return;
    }
    card.classList.remove("between");
    const changed = !tuned || tuned.id !== station.id;
    tuned = station;
    if (changed) {
      trackIndex = Math.max(0, selectCuratedTrackIndex(station));
      lastTrackID = null;
      recentTrackIDs = [];
      tracksSinceTune = 0;
      songsSinceBanter = 0;
      audio.pause();
      // reset the banter playout for the new station
      playingBanter = false; pendingTrackIndex = null;
      recentBanterIDs = []; recentBanterCategories = [];
      card.classList.remove("on-banter");
    }
    elName.textContent = station.name;
    elSignal.textContent = station.signal;
    elTagline.textContent = station.tagline;
    elEffect.textContent = `World effect · ${station.effect}`;
    const hasAudio = firstPlayableIndex() >= 0;
    elNote.textContent = hasAudio
      ? (station.hidden ? "UNLISTED TRANSMISSION · Signal origin withheld." : "")
      : "This station is broadcasting — the recording hasn't been pressed yet.";
    // keep playing across a re-tune if the station changed but we were live
    if (wasOnAir && hasAudio) { play(); } else { setOnAir(false); }
    renderTracks();
  }

  function onDial() {
    const freq = parseFloat(dial.value);
    const station = nearest(freq);
    tuneTo(station, freq);
  }

  onair.addEventListener("click", () => {
    if (!tuned) return;
    if (onAir) { powerOffBroadcast(); return; }
    if (firstPlayableIndex() >= 0) { trackIndex = Math.max(0, selectCuratedTrackIndex(tuned)); play(); }
    else { setOnAir(true); renderTracks(); } // silent broadcast — still goes on air
  });
  if (power) power.addEventListener("click", () => {
    if (onAir) powerOffBroadcast();
  });

  dial.addEventListener("input", onDial);
  window.addEventListener("resize", drawWaveIdle, { passive: true });
  drawWaveIdle();
  onDial(); // initial tune to 88.3 / Fae-Fi
})();

/* ───────────────────────── anchoring loop showcase ───────────────────────── */
(function initAnchorLoop() {
  const phone = document.querySelector("#anchor-phone");
  const steps = document.querySelectorAll("#anchor-steps li");
  if (!phone) return;
  const slides = phone.querySelectorAll(".anchor-slide");
  if (slides.length === 0) return;

  let i = 0;
  function show(n) {
    slides.forEach((s, k) => s.classList.toggle("is-active", k === n));
    steps.forEach((s, k) => s.classList.toggle("is-active", k === n));
  }
  show(0);
  if (reduceMotion) return;

  let timer = null;
  const advance = () => { i = (i + 1) % slides.length; show(i); };
  const start = () => { if (!timer) timer = setInterval(advance, 2600); };
  const stop = () => { clearInterval(timer); timer = null; };

  phone.addEventListener("pointerenter", stop);
  phone.addEventListener("pointerleave", start);
  // only run while in view
  if ("IntersectionObserver" in window) {
    new IntersectionObserver((entries) => {
      entries.forEach((e) => (e.isIntersecting ? start() : stop()));
    }, { threshold: 0.3 }).observe(phone);
  } else {
    start();
  }
})();

/* ───────────────────────── ambient letter field ───────────────────────── */
function initField() {
  if (reduceMotion) return;
  const canvas = document.querySelector("#spell-field");
  if (!canvas) return;

  const ctx = canvas.getContext("2d");
  if (!ctx) {
    canvas.remove();
    return;
  }

  const glyphs = "REENCHANTEDBOOKOFYOUPAGESKEPTSTORY";
  const colors = [
    [255, 200, 116],
    [255, 216, 154],
    [76, 192, 189],
    [138, 114, 196],
  ];
  const letters = [];
  let width = 0;
  let height = 0;
  let dpr = 1;

  function makeLetter() {
    const color = colors[Math.floor(Math.random() * colors.length)];
    return {
      glyph: glyphs[Math.floor(Math.random() * glyphs.length)],
      x: Math.random(),
      y: Math.random(),
      depth: 0.35 + Math.random() * 0.9,
      size: 5 + Math.random() * 7,
      drift: 0.04 + Math.random() * 0.1,
      orbit: Math.random() * Math.PI * 2,
      spin: (Math.random() - 0.5) * 0.22,
      alpha: 0.08 + Math.random() * 0.18,
      color,
    };
  }

  function resize() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    width = window.innerWidth;
    height = window.innerHeight;
    canvas.width = Math.floor(width * dpr);
    canvas.height = Math.floor(height * dpr);
    canvas.style.width = `${width}px`;
    canvas.style.height = `${height}px`;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    const target = Math.min(180, Math.max(80, Math.floor((width * height) / 12000)));
    while (letters.length < target) letters.push(makeLetter());
    letters.length = target;
  }

  function draw(t) {
    ctx.clearRect(0, 0, width, height);
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";

    const mx = parseFloat(root.style.getPropertyValue("--mx") || 0);
    const my = parseFloat(root.style.getPropertyValue("--my") || 0);
    const scrollDrift = window.scrollY * 0.018;
    const time = t * 0.001;

    for (const letter of letters) {
      const orbitX = Math.cos(time * letter.drift + letter.orbit) * 28 * letter.depth;
      const orbitY = Math.sin(time * letter.drift * 0.8 + letter.orbit) * 18 * letter.depth;
      const x = ((letter.x * width + orbitX + mx * 42 * letter.depth) % (width + 80)) - 40;
      const y = ((letter.y * height + orbitY + scrollDrift * letter.depth - my * 34 * letter.depth) % (height + 80)) - 40;
      const [r, g, b] = letter.color;

      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(Math.sin(time * letter.drift + letter.orbit) * letter.spin);
      ctx.font = `${letter.size * letter.depth}px Fraunces, Georgia, serif`;
      ctx.fillStyle = `rgba(${r}, ${g}, ${b}, ${letter.alpha})`;
      ctx.shadowColor = `rgba(${r}, ${g}, ${b}, ${letter.alpha * 0.35})`;
      ctx.shadowBlur = 4 * letter.depth;
      ctx.fillText(letter.glyph, 0, 0);
      ctx.restore();
    }

    requestAnimationFrame(draw);
  }

  window.addEventListener("resize", resize, { passive: true });
  resize();
  requestAnimationFrame(draw);
}
initField();
