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
    title: "The Weather Page has opened.",
    body: "Now: 60° · fog, high 71°, low 56°. Outer weather is translated into story mood while the real forecast stays legible.",
    source: "Public reference",
    shot: "./assets/screens/home.jpg",
    braid: "The sky held a clear promise, and a soft weeping waited in the wings.",
  },
  {
    kicker: "One-Sentence Souvenir",
    title: "A single true line from the day.",
    body: "“The walk at Moose Point, with a small hand in mine, and the waves rolling into the afternoon.” One moment, kept in one durable sentence.",
    source: "Kept from the margins",
    shot: "./assets/screens/margins.jpg",
    braid: "There was the walk at Moose Point, a small hand in mine, the waves rolling in.",
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
    body: "The current belief state is steady and gently luminous. Open a Compass Run or let an Enchantment reveal the spellbook nature of an ordinary subject.",
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
  elBody.textContent = p.body;
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
  const keptLines = PAGES.filter((_, i) => choices[i] === "keep").map((p) => p.braid);
  if (keptLines.length === 0) {
    braidIntro.textContent = "You let every page wait.";
    return "An honest month: nothing demanded to be kept, and the Book waited with you. The shelf is patient. Come back when something catches a real edge.";
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
    hint.textContent = "This is one month. A year of kept pages becomes an edition you can hold.";
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

/* ───────────────────────── ReEnchanted Radio ─────────────────────────
   Stations mirror the app's RadioStationRegistry. To add audio: drop a file
   in assets/audio/ and set `src` on a track (null = signal carries no
   recording yet). Add a whole station by appending to STATIONS.          */
const STATIONS = [
  {
    id: "fae-fi",
    name: "Fae-Fi",
    freq: 88.3,
    signal: "The signal arrives giggling, tasting of clover honey and warm afternoons.",
    tagline: "Sun-dappled beats and dandelion synths from faeries who have plainly had too much nectar.",
    effect: "Wonder Compass +8 · Souvenir +8 · Festival +6",
    tracks: [
      { title: "Mossy Footsteps", artist: "Fae-Fi", src: "./assets/audio/fae-fi-mossy-footsteps.m4a" },
      { title: "Folktronica", artist: "Fae-Fi", src: "./assets/audio/fae-fi-folktronica.m4a" },
      { title: "Mossy Groove", artist: "Fae-Fi", src: "./assets/audio/fae-fi-mossy-groove.m4a" },
    ],
  },
  {
    id: "mothlight",
    name: "Mothlight Beats",
    freq: 90.9,
    signal: "The static flutters at the glass like it remembers being a summer you lost.",
    tagline: "Dusk-soft loops for the ache of lovely things ending, lit by wings against the lamp.",
    effect: "Book Remembered +10 · Mood +7 · Diary +6",
    tracks: [
      { title: "The Page Came Through", artist: "Mothlight Beats", src: "./assets/audio/mothlight-the-page-came-through.m4a" },
      { title: "Fae Dust", artist: "Mothlight Beats", src: "./assets/audio/mothlight-fae-dust.m4a" },
      { title: "Porchlight, Fading", artist: "Mothlight Beats", src: null },
    ],
  },
  {
    id: "thornwave",
    name: "Thornwave",
    freq: 103.7,
    signal: "The bass moves like something with antlers stepping between the trees.",
    tagline: "Bramble bass, broken-glass garage, and bargains struck in the low end after midnight.",
    effect: "Book Fae +10 · Narrative OS +8 · Gossip +6",
    tracks: [
      { title: "Bramble Bass", artist: "Thornwave", src: "./assets/audio/thornwave-bramble-bass.m4a" },
      { title: "Nocturnal Faerie Lounge", artist: "Thornwave", src: "./assets/audio/thornwave-nocturnal-faerie-lounge.m4a" },
    ],
  },
];

(function initRadio() {
  const dial = document.querySelector("#dial");
  if (!dial) return;

  const elFreq = document.querySelector("#radio-freq");
  const elName = document.querySelector("#radio-name");
  const onair = document.querySelector("#onair-btn");
  const onairLabel = onair.querySelector(".onair-label");
  const elSignal = document.querySelector("#radio-signal-text");
  const elTagline = document.querySelector("#radio-tagline");
  const elEffect = document.querySelector("#radio-effect");
  const trackList = document.querySelector("#track-list");
  const elNote = document.querySelector("#radio-note");
  const card = document.querySelector("#radio-card");
  const scale = document.querySelector("#dial-scale");

  const TOLERANCE = 0.5; // FM units within which a station "locks in"
  const FMIN = 88, FMAX = 108;
  const audio = new Audio();
  let tuned = STATIONS[0];
  let onAir = false;
  let trackIndex = 0;

  // build the station labels along the scale
  STATIONS.forEach((s) => {
    const mark = document.createElement("span");
    mark.className = "scale-mark";
    mark.style.left = `${((s.freq - FMIN) / (FMAX - FMIN)) * 100}%`;
    mark.innerHTML = `<i></i>${s.freq.toFixed(1)}`;
    mark.title = s.name;
    mark.addEventListener("click", () => { dial.value = s.freq; onDial(); });
    scale.appendChild(mark);
  });

  function nearest(freq) {
    let best = null, dist = Infinity;
    for (const s of STATIONS) {
      const d = Math.abs(s.freq - freq);
      if (d < dist) { dist = d; best = s; }
    }
    return dist <= TOLERANCE ? best : null;
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
  }

  function play() {
    const t = tuned.tracks[trackIndex];
    if (!t || !t.src) { audio.pause(); return; }
    if (audio.src.indexOf(t.src.replace("./", "")) === -1) audio.src = t.src;
    audio.play().catch(() => {});
    setOnAir(true);
    renderTracks();
  }

  function firstPlayableIndex() {
    return tuned.tracks.findIndex((t) => t.src);
  }

  audio.addEventListener("ended", () => {
    // advance through this station's playable tracks, then loop
    const playable = tuned.tracks.map((t, i) => (t.src ? i : -1)).filter((i) => i >= 0);
    if (playable.length === 0) return;
    const pos = playable.indexOf(trackIndex);
    trackIndex = playable[(pos + 1) % playable.length];
    play();
  });

  function tuneTo(station, betweenFreq) {
    const wasOnAir = onAir;
    elFreq.textContent = `${(station ? station.freq : betweenFreq).toFixed(1)} FM`;
    if (!station) {
      tuned = null;
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
    if (changed) { trackIndex = Math.max(0, firstPlayableIndex()); audio.pause(); }
    elName.textContent = station.name;
    elSignal.textContent = station.signal;
    elTagline.textContent = station.tagline;
    elEffect.textContent = `World effect · ${station.effect}`;
    const hasAudio = firstPlayableIndex() >= 0;
    elNote.textContent = hasAudio
      ? ""
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
    if (onAir) { audio.pause(); setOnAir(false); renderTracks(); return; }
    if (firstPlayableIndex() >= 0) { trackIndex = firstPlayableIndex(); play(); }
    else { setOnAir(true); renderTracks(); } // silent broadcast — still goes on air
  });

  dial.addEventListener("input", onDial);
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

/* ───────────────────────── ambient gold-dust field (three.js) ───────────────────────── */
async function initField() {
  if (reduceMotion) return;
  const canvas = document.querySelector("#spell-field");
  if (!canvas) return;
  try {
    const THREE = await import("https://unpkg.com/three@0.161.0/build/three.module.js");
    const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(55, 1, 0.1, 100);
    camera.position.z = 9;

    const count = 220;
    const positions = new Float32Array(count * 3);
    const colors = new Float32Array(count * 3);
    const gold = new THREE.Color("#ffc874");
    const teal = new THREE.Color("#4cc0bd");
    const violet = new THREE.Color("#8a72c4");

    for (let i = 0; i < count; i++) {
      const r = 2.4 + Math.random() * 7;
      const a = Math.random() * Math.PI * 2;
      positions[i * 3] = Math.cos(a) * r;
      positions[i * 3 + 1] = Math.sin(a) * r * 0.7;
      positions[i * 3 + 2] = -Math.random() * 6;
      const roll = Math.random();
      const c = roll > 0.84 ? teal : roll > 0.74 ? violet : gold;
      colors[i * 3] = c.r; colors[i * 3 + 1] = c.g; colors[i * 3 + 2] = c.b;
    }

    const geo = new THREE.BufferGeometry();
    geo.setAttribute("position", new THREE.BufferAttribute(positions, 3));
    geo.setAttribute("color", new THREE.BufferAttribute(colors, 3));
    const mat = new THREE.PointsMaterial({
      size: 0.05, vertexColors: true, transparent: true,
      opacity: 0.8, depthWrite: false, blending: THREE.AdditiveBlending,
    });
    const points = new THREE.Points(geo, mat);
    scene.add(points);

    function resize() {
      const w = window.innerWidth, h = window.innerHeight;
      renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
      renderer.setSize(w, h, false);
      camera.aspect = w / h;
      camera.updateProjectionMatrix();
    }
    function tick(t) {
      points.rotation.z = t * 0.00004 + window.scrollY * 0.00006;
      points.rotation.x = Math.sin(t * 0.00016) * 0.06;
      camera.position.x = parseFloat(root.style.getPropertyValue("--mx") || 0) * 0.8;
      camera.position.y = -parseFloat(root.style.getPropertyValue("--my") || 0) * 0.8;
      camera.lookAt(0, 0, 0);
      renderer.render(scene, camera);
      requestAnimationFrame(tick);
    }
    window.addEventListener("resize", resize);
    resize();
    requestAnimationFrame(tick);
  } catch {
    canvas.remove();
  }
}
initField();
