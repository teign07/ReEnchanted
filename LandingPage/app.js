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

/* ───────────────────────── the real day ─────────────────────────
   The app's thesis is that real life is the best-written chapter, so the
   demo reads the visitor's actual sky, moon, and hour — exactly the way
   the app's Weather Page does — with a graceful Stacks default offline. */
function escapeHTML(s) {
  return String(s).replace(/[&<>"]/g, (c) => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]
  ));
}

/* Moon phase, ported from Shared/WorldSystems.swift (MoonPhase.phase). */
function moonPhase(date = new Date()) {
  const SYNODIC = 29.530588853;
  const REF_NEW_MOON = Date.UTC(2000, 0, 6, 18, 14, 0); // a known new moon
  const days = (date.getTime() - REF_NEW_MOON) / 86_400_000;
  let pos = (days % SYNODIC) / SYNODIC;
  if (pos < 0) pos += 1;
  const idx = Math.round(pos * 8) % 8;
  const PHASES = [
    ["New Moon", "The moon is a held breath tonight, a page before the first word."],
    ["Waxing Crescent", "A thin silver paring of moon is just beginning to write itself."],
    ["First Quarter", "Half the moon is lit tonight, like a door left ajar."],
    ["Waxing Gibbous", "The moon is fattening toward full, gathering light like gossip."],
    ["Full Moon", "The moon is full. Every margin of the night is annotated."],
    ["Waning Gibbous", "The moon is giving its light back now, a little each night."],
    ["Last Quarter", "Half-lit and leaving: the moon keeps only what matters."],
    ["Waning Crescent", "A last paring of moon, almost given back to the dark."],
  ];
  return { name: PHASES[idx][0], line: PHASES[idx][1] };
}

/* WMO weather code → the Book's dual reading, in the app's voice. */
function describeWeather(code) {
  const m = (word, enchanted, plain) => ({ word, enchanted, plain });
  if (code === 0) return m("clear", "The sky is scrubbed clean and the light comes through unhindered.", "It is clear.");
  if (code <= 2) return m("partly cloudy", "A few pages of cloud drift across an otherwise open sky.", "It is partly cloudy.");
  if (code === 3) return m("overcast", "The sky weeps a soft, gray shroud over the land.", "It is overcast.");
  if (code <= 48) return m("fog", "Fog has softened every edge of the world into suggestion.", "It is foggy.");
  if (code <= 57) return m("drizzle", "A fine drizzle is writing in the margins of the air.", "It is drizzling.");
  if (code <= 67) return m("rain", "The sky weeps a soft, gray shroud over the land.", "It is raining.");
  if (code <= 77) return m("snow", "The sky is letting down quiet paper, one flake at a time.", "It is snowing.");
  if (code <= 82) return m("showers", "The sky keeps clearing its throat in bursts of rain.", "There are passing showers.");
  if (code <= 86) return m("snow showers", "Brief snow keeps arriving like loose pages on the wind.", "There are snow showers.");
  return m("storm", "The sky is rearranging its furniture; thunder reads aloud.", "There is a thunderstorm.");
}

/* The Weather Page, rendered as the app's "Private translation" card. */
function weatherPageHTML(w) {
  return `
    <span class="weather-facts" aria-label="Weather details">
      <span><strong>Now</strong> ${w.nowTemp}° · ${w.cond}</span>
      <span><strong>High / Low</strong> ${w.high}° / ${w.low}°</span>
      <span><strong>Wind</strong> ${w.wind}</span>
      <span><strong>Humidity</strong> ${w.humidity}%</span>
    </span>
    <span class="private-translation">
      <span class="pt-label">✦ Private translation</span>
      <span class="pt-line"><strong>Enchanted:</strong> ${escapeHTML(w.enchanted)} <strong>Plain:</strong> ${escapeHTML(w.plain)}</span>
      <span class="pt-moon">${escapeHTML(w.moonLine)}</span>
      <span class="pt-meta">Weather: Now ${w.nowTemp}° · ${w.cond} · High ${w.high}° / Low ${w.low}° · ${w.moonName}</span>
    </span>
    <span class="weather-place">${escapeHTML(w.place)}</span>
  `;
}

const FALLBACK_WEATHER = (() => {
  const moon = moonPhase();
  const d = describeWeather(45); // fog over the Stacks
  return {
    nowTemp: 60, cond: d.word, high: 71, low: 56, wind: "E 4 mph", humidity: 92,
    enchanted: d.enchanted, plain: d.plain, moonLine: moon.line, moonName: moon.name,
    place: "Over the Stacks · the Book's default sky",
  };
})();

let weatherCtx = { ...FALLBACK_WEATHER };
let readerLine = "";

/* ───────────────────────── the deck of pages ─────────────────────────
   Each page: a real screen from the app + copy + the line it contributes
   to the braided "Book of You" if the reader keeps it.                  */
const PAGES = [
  {
    kicker: "Weather Page",
    title: "The Weather Page has opened.",
    bodyHTML: weatherPageHTML(FALLBACK_WEATHER),
    source: "Weather doorway · public forecast",
    shot: "./assets/screens/story-page-weather-prose.png",
    braid: "The Weather Page opened on fog, and I kept the sky exactly as it stood.",
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
    kicker: "Radio",
    title: "Music becomes weather in the stacks.",
    body: "Broadcasts and world effects drift through the shelves as atmosphere — a mood you can keep alongside the day. Tune the Stacks for a moment, then keep the station if it changes the room.",
    source: "World effect",
    shot: "./assets/screens/radio.jpg",
    braid: "A broadcast drifted through and became weather in the stacks.",
    radioPrompt: true,
  },
  {
    kicker: "One-Sentence Souvenir",
    title: "Write one true line from your day.",
    body: "The Book is asking for your sentence now: one sensory, specific line that would otherwise vanish. The app's sentence helper wakes the line, polishes it gently, and lets you keep it when it can stand.",
    source: "Kept from the margins",
    shot: "./assets/screens/margins.jpg",
    braid: "There was the walk at Moose Point, a small hand in mine, the waves rolling in.",
    quiet: true,
    sentencePrompt: true,
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
const keepControls = document.querySelector("#keep-controls");
const btnKeep = document.querySelector("#btn-keep");
const btnWait = document.querySelector("#btn-wait");
const sentencePolisher = document.querySelector("#sentence-polisher");
const readerLineInput = document.querySelector("#reader-line");
const polisherStatus = document.querySelector("#polisher-status");
const polisherPreview = document.querySelector("#polisher-preview");
const polishBtn = document.querySelector("#polish-btn");
const restoreSentenceBtn = document.querySelector("#restore-sentence-btn");
const stacksRadio = document.querySelector("#stacks-radio");
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
const SAMPLE_SENTENCE = "The walk at Moose Point held a small hand in mine while the waves rolled into the afternoon.";

function isDecisionPage(page) {
  return page.decision !== false;
}

function keepablePageCount() {
  return PAGES.filter(isDecisionPage).length;
}

function polishSentence(value) {
  let text = String(value || "")
    .replace(/[“”]/g, '"')
    .replace(/[‘’]/g, "'")
    .replace(/\s+/g, " ")
    .trim();
  if (!text) return "";

  text = text
    .replace(/\b(just|really|very|kind of|sort of|basically)\b\s*/gi, "")
    .replace(/\s+,/g, ",")
    .replace(/\s+\./g, ".")
    .replace(/\s{2,}/g, " ")
    .trim();

  text = text.charAt(0).toUpperCase() + text.slice(1);
  if (!/[.!?]$/.test(text)) text += ".";
  return text;
}

function sentenceWordCount(value) {
  return (String(value || "").trim().match(/\b[\w'-]+\b/g) || []).length;
}

function renderSentencePolisher() {
  if (!sentencePolisher || !readerLineInput || !polisherStatus || !polisherPreview) return;
  const visible = Boolean(PAGES[index].sentencePrompt);
  sentencePolisher.hidden = !visible;
  if (!visible) return;

  const polished = polishSentence(readerLineInput.value);
  readerLine = polished;
  const words = sentenceWordCount(polished);
  if (!polished) {
    polisherStatus.textContent = "Wake the sentence";
    polisherPreview.textContent = "Write one true line and the Book will polish its edges.";
  } else if (words < 6) {
    polisherStatus.textContent = "Needs one more detail";
    polisherPreview.textContent = polished;
  } else {
    polisherStatus.textContent = "Strong sentence";
    polisherPreview.textContent = polished;
  }
  sentencePolisher.classList.toggle("is-strong", words >= 6);
}

function renderStacksRadio() {
  if (!stacksRadio) return;
  stacksRadio.hidden = !PAGES[index].radioPrompt;
}

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

  const decisionPage = isDecisionPage(p);
  const choice = choices[index];
  screenWrap.classList.toggle("is-kept", choice === "keep");
  btnKeep.classList.toggle("chosen", choice === "keep");
  btnWait.classList.toggle("chosen", choice === "wait");
  keepControls.hidden = !decisionPage;
  elStatus.hidden = !decisionPage;
  renderSentencePolisher();
  renderStacksRadio();

  navCount.textContent = `Page ${index + 1} of ${PAGES.length}`;
  btnPrev.disabled = index === 0;
  btnNext.textContent = index === PAGES.length - 1 ? "Braid it ✦" : "Next ›";
  progressFill.style.width = `${((index + 1) / PAGES.length) * 100}%`;

  const kept = choices.filter((c) => c === "keep").length;
  elStatus.textContent = kept === 0
    ? `${keepablePageCount()} pages rising · keep the ones that are true`
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
  if (!isDecisionPage(PAGES[index])) return;
  if (kind === "keep" && PAGES[index].sentencePrompt && readerLineInput && !readerLine) {
    readerLineInput.focus();
    hint.textContent = "Write one true sentence first — then keep it.";
    return;
  }
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
  loadRealWeather(); // best-effort; the page already reads fine on the fallback
}

function buildBraid() {
  const keptIndices = PAGES.map((_, i) => i).filter((i) => choices[i] === "keep");
  const decisionIndices = PAGES.map((page, i) => isDecisionPage(page) ? i : -1).filter((i) => i >= 0);
  const sentencePageKept = keptIndices.some((i) => PAGES[i].sentencePrompt);
  const keptLines = keptIndices.map((i) => {
    if (PAGES[i].sentencePrompt && readerLine) {
      return `I kept one sentence from the day: <em class="reader-own">${escapeHTML(readerLine)}</em>`;
    }
    return PAGES[i].braid;
  });
  const everyPageAnswered = decisionIndices.every((i) => choices[i] === "keep" || choices[i] === "wait");
  const allKept = decisionIndices.every((i) => choices[i] === "keep");
  const alternating = everyPageAnswered && decisionIndices.every((i, decisionOffset) => choices[i] === (decisionOffset % 2 === 0 ? "keep" : "wait"));
  const quietIndices = PAGES.map((page, i) => page.quiet ? i : -1).filter((i) => i >= 0);
  const quietPagesOnly = everyPageAnswered
    && keptIndices.length === quietIndices.length
    && quietIndices.every((i) => keptIndices.includes(i));

  // The reader's own true line, if they wrote one, leads the passage in their voice.
  const own = readerLine && !sentencePageKept ? `<em class="reader-own">${escapeHTML(readerLine)}</em>` : "";
  const lead = own ? `${own}  ` : "";
  const woven = keptLines.join("  ");

  if (keptLines.length === 0) {
    if (own) {
      braidIntro.textContent = "Only one true line — and the Book kept it anyway.";
      return `${own}  Nothing else demanded binding today, and that is its own kind of honest month. The shelf is patient.`;
    }
    braidIntro.textContent = everyPageAnswered ? "You let every page wait." : "You kept no page before the binding.";
    return "An honest month: nothing demanded to be kept, and the Book waited with you. The shelf is patient. Come back when something catches a real edge.";
  }
  if (allKept) {
    braidIntro.textContent = "You kept everything. The Book has concerns. Affectionate ones.";
    return `${lead}${woven}  In the final margin, a small hand has written: sentimental, perhaps — but paying attention is hardly the worst trouble to be in.`;
  }
  if (alternating) {
    braidIntro.textContent = "A Riddlewind pattern appeared between yes and not yet.";
    return `${lead}${woven}  Every other door remained closed. Together, the open doors spelled a question the Book has declined to translate.`;
  }
  if (quietPagesOnly) {
    braidIntro.textContent = "The Book noticed what kind of pages you chose.";
    return `${lead}${woven}  No spectacle asked to be remembered. The ordinary things made a small constellation anyway.`;
  }
  braidIntro.textContent = own
    ? `Braided from your own line and the ${keptLines.length} page${keptLines.length === 1 ? "" : "s"} you kept.`
    : `Braided from the ${keptLines.length} page${keptLines.length === 1 ? "" : "s"} you kept.`;
  // each kept line is already a complete sentence — weave them into one passage
  return `${lead}${woven}`;
}

/* ── the Book of You edition: theme, stats, and The Reader's Sky ── */
const PAGE_WORDS = ["Weather", "Chart", "Music", "Sentence", "Faculty", "Light", "Wonder", "Light"];

function hashStr(s) {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
  return Math.abs(h);
}

function editionData() {
  const keptIdx = PAGES.map((_, i) => i).filter((i) => choices[i] === "keep");
  const counts = {};
  keptIdx.forEach((i) => { const w = PAGE_WORDS[i] || "Page"; counts[w] = (counts[w] || 0) + 1; });
  if (readerLine) counts["Sentence"] = (counts["Sentence"] || 0) + 1;
  const words = Object.entries(counts)
    .map(([label, count]) => ({ label, count }))
    .sort((a, b) => b.count - a.count); // stable: ties keep their first-kept order
  let theme;
  if (words.length >= 2) theme = `“What ${words[0].label} Said to ${words[1].label}”`;
  else if (words.length === 1) theme = `“The ${words[0].label} Chapter”`;
  else theme = "“A Quiet Chapter”";
  return { words, theme, keptCount: keptIdx.length };
}

function renderReadersSky(words) {
  const wrap = document.querySelector("#readers-sky");
  const map = document.querySelector("#sky-map");
  const legend = document.querySelector("#sky-legend");
  if (!wrap || !map || !legend) return;
  if (words.length === 0) { wrap.hidden = true; return; }
  wrap.hidden = false;
  const W = 300, H = 190, pad = 42;
  const pts = words.map((w) => {
    const h = hashStr(w.label + "✦");
    return {
      ...w,
      x: pad + (h % 997) / 997 * (W - 2 * pad),
      y: pad + (Math.floor(h / 997) % 991) / 991 * (H - 2 * pad),
    };
  });
  let lines = "";
  for (let i = 0; i < pts.length - 1; i++) {
    lines += `<line x1="${pts[i].x.toFixed(1)}" y1="${pts[i].y.toFixed(1)}" x2="${pts[i + 1].x.toFixed(1)}" y2="${pts[i + 1].y.toFixed(1)}"/>`;
  }
  const stars = pts.map((p) =>
    `<circle cx="${p.x.toFixed(1)}" cy="${p.y.toFixed(1)}" r="${(2.5 + p.count).toFixed(1)}" class="sky-star"/>` +
    `<text x="${(p.x + 7).toFixed(1)}" y="${(p.y + 3).toFixed(1)}" class="sky-label">${escapeHTML(p.label)}</text>`
  ).join("");
  map.innerHTML = `<g class="sky-lines">${lines}</g>${stars}`;
  legend.innerHTML = words.map((w) =>
    `<li>${escapeHTML(w.label)} · noticed · ${w.count} sighting${w.count === 1 ? "" : "s"}</li>`
  ).join("");
}

function monthYear() {
  return new Date().toLocaleDateString("en-US", { month: "long", year: "numeric" });
}

function setText(sel, txt) { const el = document.querySelector(sel); if (el) el.textContent = txt; }

let lastEdition = null;

function showBraid() {
  const text = buildBraid();
  const data = editionData();
  lastEdition = data;
  flip("next", () => {
    book.dataset.state = "braid";
    braidText.innerHTML = text;
    const my = monthYear();
    setText("#edition-chapter", `Chapter 1 · ${my}`);
    setText("#edition-eyebrow", `The Book of You · ${my}`);
    setText("#edition-theme", data.theme);
    setText("#edition-stats", `1 day bound · ${data.keptCount} kept page${data.keptCount === 1 ? "" : "s"}`);
    renderReadersSky(data.words);
    progressFill.style.width = "100%";
    navCount.textContent = "Your binding";
    btnNext.disabled = true;
    btnPrev.disabled = false;
    hint.textContent = "This is one day. A real month braids many of these into a bound edition.";
  });
}

/* ── keepsake: render this edition page to a downloadable PNG ── */
function wrapText(g, text, x, y, maxW, lh, maxY) {
  const words = text.split(/\s+/);
  let line = "", yy = y;
  for (const w of words) {
    const test = line ? line + " " + w : w;
    if (g.measureText(test).width > maxW && line) {
      g.fillText(line, x, yy);
      line = w;
      yy += lh;
      if (yy > maxY) { g.fillText("…", x, yy); return yy; }
    } else {
      line = test;
    }
  }
  if (line) g.fillText(line, x, yy);
  return yy;
}

async function downloadKeepsake() {
  const data = lastEdition || editionData();
  const passage = (braidText.textContent || "").trim();
  try { if (document.fonts && document.fonts.ready) await document.fonts.ready; } catch (_) {}
  const W = 1080, H = 1350;
  const c = document.createElement("canvas");
  c.width = W; c.height = H;
  const g = c.getContext("2d");
  const gold = "#cbb37a", cream = "#ede6d2", cx = W / 2;
  g.fillStyle = "#0e2018"; g.fillRect(0, 0, W, H);
  const vg = g.createRadialGradient(cx, H * 0.3, 60, cx, H * 0.3, H * 0.72);
  vg.addColorStop(0, "rgba(46,86,64,0.55)"); vg.addColorStop(1, "rgba(0,0,0,0)");
  g.fillStyle = vg; g.fillRect(0, 0, W, H);
  g.strokeStyle = "rgba(201,179,122,0.45)"; g.lineWidth = 2;
  g.strokeRect(52, 52, W - 104, H - 104);
  // keyhole door
  g.strokeStyle = gold; g.lineWidth = 4;
  const aw = 116, top = 150;
  g.beginPath();
  g.moveTo(cx - aw, top + 250);
  g.lineTo(cx - aw, top + 80);
  g.arc(cx, top + 80, aw, Math.PI, 0);
  g.lineTo(cx + aw, top + 250);
  g.stroke();
  g.fillStyle = gold;
  g.beginPath(); g.arc(cx, top + 120, 15, 0, Math.PI * 2); g.fill();
  g.fillRect(cx - 5, top + 128, 10, 34);
  // imprint + theme + chapter
  g.textAlign = "center";
  g.fillStyle = cream;
  if ("letterSpacing" in g) g.letterSpacing = "8px";
  g.font = '600 32px Fraunces, Georgia, serif';
  g.fillText("THE BOOK OF YOU", cx, 540);
  if ("letterSpacing" in g) g.letterSpacing = "0px";
  g.fillStyle = gold; g.font = 'italic 600 50px Fraunces, Georgia, serif';
  g.fillText(data.theme, cx, 612);
  g.fillStyle = "rgba(237,230,210,0.66)"; g.font = '400 26px Fraunces, Georgia, serif';
  g.fillText(`Chapter 1 · ${monthYear()}`, cx, 660);
  g.strokeStyle = "rgba(201,179,122,0.4)"; g.lineWidth = 1.5;
  g.beginPath(); g.moveTo(cx - 80, 700); g.lineTo(cx + 80, 700); g.stroke();
  // passage
  g.fillStyle = cream; g.textAlign = "left"; g.font = '400 31px Fraunces, Georgia, serif';
  wrapText(g, passage, 132, 770, W - 264, 46, 1170);
  // footer: where + when + sky
  g.textAlign = "center"; g.fillStyle = "rgba(201,179,122,0.85)"; g.font = 'italic 24px Fraunces, Georgia, serif';
  const place = [weatherCtx.city, monthYear(), weatherCtx.cond].filter(Boolean).join(" · ");
  g.fillText(place, cx, H - 86);
  c.toBlob((b) => {
    if (!b) return;
    const a = document.createElement("a");
    a.href = URL.createObjectURL(b);
    a.download = "book-of-you.png";
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 1500);
  }, "image/png");
}

function backFromBraid() {
  book.dataset.state = "open";
  index = PAGES.length - 1;
  btnNext.disabled = false;
  render();
}

function replay() {
  choices.fill(null);
  readerLine = "";
  if (readerLineInput) readerLineInput.value = "";
  book.dataset.state = "open";
  index = 0;
  btnNext.disabled = false;
  hint.textContent = "Tip: keep a few, let some wait — your choices change the ending.";
  render();
  document.querySelector("#book").scrollIntoView({ behavior: "smooth", block: "center" });
}

/* ── daypart: tint the whole scene to the visitor's real hour ── */
const DAYPART = {
  dawn: { kicker: "The Stacks are waking", hint: "Morning in the Stacks — open the book and keep what's true." },
  day: { kicker: "The Book turns when you do", hint: "Tip: keep a few, let some wait — your choices change the ending." },
  dusk: { kicker: "The west windows go violet", hint: "Dusk in the Stacks — a good hour to keep what the day meant." },
  night: { kicker: "The Stacks are lit low", hint: "Read a few pages before sleep — the Book keeps what you keep." },
};
function currentDaypart(h = new Date().getHours()) {
  if (h < 5) return "night";
  if (h < 8) return "dawn";
  if (h < 17) return "day";
  if (h < 20) return "dusk";
  return "night";
}
function applyDaypart() {
  const part = currentDaypart();
  root.dataset.daypart = part;
  const greeting = DAYPART[part];
  const coverKicker = document.querySelector(".cover-kicker");
  if (coverKicker) coverKicker.textContent = greeting.kicker;
  if (book.dataset.state === "closed" && hint) hint.textContent = greeting.hint;
}

/* ── real weather, read the way the app's Weather Page reads it ── */
const WIND_DIRS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
async function loadRealWeather() {
  if (weatherCtx.loaded) return;
  try {
    const geo = await fetch("https://ipwho.is/").then((r) => r.json());
    if (!geo || geo.success === false || typeof geo.latitude !== "number") return;
    const city = [geo.city, geo.region].filter(Boolean).join(", ") || geo.country || "your sky";
    const params = new URLSearchParams({
      latitude: geo.latitude, longitude: geo.longitude,
      current: "temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m",
      daily: "temperature_2m_max,temperature_2m_min",
      temperature_unit: "fahrenheit", wind_speed_unit: "mph", timezone: "auto",
    });
    const wx = await fetch(`https://api.open-meteo.com/v1/forecast?${params}`).then((r) => r.json());
    const cur = wx && wx.current;
    if (!cur) return;
    const d = describeWeather(cur.weather_code);
    const moon = moonPhase();
    const dir = WIND_DIRS[Math.round(((cur.wind_direction_10m || 0) % 360) / 45) % 8];
    weatherCtx = {
      loaded: true,
      nowTemp: Math.round(cur.temperature_2m),
      cond: d.word,
      high: Math.round(wx.daily.temperature_2m_max[0]),
      low: Math.round(wx.daily.temperature_2m_min[0]),
      wind: `${dir} ${Math.round(cur.wind_speed_10m)} mph`,
      humidity: Math.round(cur.relative_humidity_2m),
      enchanted: d.enchanted, plain: d.plain,
      moonLine: moon.line, moonName: moon.name,
      place: `Read from ${city} · approximate, never stored — the same doorway the app uses`,
      city,
    };
    PAGES[0].bodyHTML = weatherPageHTML(weatherCtx);
    PAGES[0].braid = `The Weather Page opened on ${d.word} over ${city}; I kept the sky exactly as it stood.`;
    if (index === 0 && book.dataset.state === "open") render();
  } catch (_) {
    /* offline / blocked — the Stacks default already reads beautifully */
  }
}

/* ── the reader's own true line, on the One-Sentence Souvenir page ── */
if (readerLineInput) {
  readerLineInput.addEventListener("input", renderSentencePolisher);
}
polishBtn?.addEventListener("click", () => {
  if (!readerLineInput) return;
  readerLineInput.value = polishSentence(readerLineInput.value);
  renderSentencePolisher();
  if (readerLineInput.value) hint.textContent = "Polished. If it feels true, keep this page.";
});
restoreSentenceBtn?.addEventListener("click", () => {
  if (!readerLineInput) return;
  readerLineInput.value = SAMPLE_SENTENCE;
  renderSentencePolisher();
  hint.textContent = "Sample loaded. Replace it with your own line if you like.";
});

/* ── launch list: capture an email so the Book can write when the doors open ──
   Static site, no backend. Paste a Buttondown / Formspree / Apps Script URL into
   EMAIL_ENDPOINT and it posts there; until then it keeps signups in localStorage
   so nothing is ever lost in dev. The real, exportable list lives at the provider. */
const EMAIL_ENDPOINT = ""; // ← paste the provider endpoint here to go live
const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

async function postEmail(payload) {
  if (!EMAIL_ENDPOINT) {
    const key = "reenchanted-waitlist";
    const list = JSON.parse(localStorage.getItem(key) || "[]");
    list.push(payload);
    localStorage.setItem(key, JSON.stringify(list));
    return { ok: true, demo: true };
  }
  const res = await fetch(EMAIL_ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  return { ok: res.ok };
}

function setEmailStatus(el, msg, ok) {
  if (!el) return;
  el.hidden = false;
  el.textContent = msg;
  el.classList.toggle("ok", ok);
  el.classList.toggle("err", !ok);
}

function wireEmailForms() {
  document.querySelectorAll(".email-capture").forEach((form) => {
    const input = form.querySelector(".email-input");
    const status = form.querySelector(".email-status");
    const btn = form.querySelector(".email-submit");
    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      const email = (input.value || "").trim();
      if (!EMAIL_RE.test(email)) {
        setEmailStatus(status, "That doesn't look like an email yet.", false);
        input.focus();
        return;
      }
      const label = btn.textContent;
      btn.disabled = true;
      btn.textContent = "Sending…";
      try {
        const r = await postEmail({
          email,
          source: form.dataset.source || "landing",
          daypart: root.dataset.daypart || "",
          city: (weatherCtx && weatherCtx.city) || "",
          ts: new Date().toISOString(),
        });
        if (r.ok) {
          form.classList.add("sent");
          input.disabled = true;
          setEmailStatus(status, "Kept. The Book will write to you when the doors open. ✦", true);
        } else {
          setEmailStatus(status, "The shelf hiccuped — try again in a moment.", false);
        }
      } catch (_) {
        setEmailStatus(status, "The shelf hiccuped — try again in a moment.", false);
      } finally {
        btn.disabled = false;
        btn.textContent = label;
      }
    });
  });
}
wireEmailForms();

applyDaypart();

cover.addEventListener("click", openBook);
btnKeep.addEventListener("click", () => choose("keep"));
btnWait.addEventListener("click", () => choose("wait"));
btnNext.addEventListener("click", () => { if (book.dataset.state === "open") go(1); });
btnPrev.addEventListener("click", () => {
  if (book.dataset.state === "braid") backFromBraid();
  else go(-1);
});
braidReplay.addEventListener("click", replay);
document.querySelector("#keepsake-btn")?.addEventListener("click", downloadKeepsake);

/* ── peelable page-curl: drag the dog-eared corner to turn ── */
const pageCorner = document.querySelector("#page-corner");
let curling = false;
let curlStartX = 0;
function setCurl(dx) {
  const amt = Math.max(0, Math.min(1, -dx / 300));
  leafRight.style.setProperty("--curl", amt.toFixed(3));
  leafRight.classList.toggle("curling", amt > 0.02);
}
function resetCurl() {
  leafRight.classList.remove("curl-anim", "curling");
  leafRight.style.removeProperty("--curl");
}
function completeCurlToNext() {
  if (index + 1 >= PAGES.length) { resetCurl(); go(1); return; } // last page → bind via flip
  animating = true;
  leafRight.classList.add("curl-anim");
  leafRight.style.setProperty("--curl", "1");      // peel away to edge-on
  setTimeout(() => {
    index += 1; render();                          // swap content while edge-on
    leafRight.style.setProperty("--curl", "0");     // settle the new page flat
    setTimeout(() => { resetCurl(); animating = false; }, 340);
  }, 330);
}
function springBackCurl() {
  leafRight.classList.add("curl-anim");
  leafRight.style.setProperty("--curl", "0");
  setTimeout(resetCurl, 320);
}
if (pageCorner) {
  pageCorner.addEventListener("pointerdown", (e) => {
    if (reduceMotion || animating || book.dataset.state !== "open" || index >= PAGES.length) return;
    curling = true;
    curlStartX = e.clientX;
    leafRight.classList.remove("curl-anim");
    pageCorner.setPointerCapture?.(e.pointerId);
    e.preventDefault();
  });
  pageCorner.addEventListener("pointermove", (e) => { if (curling) setCurl(e.clientX - curlStartX); });
  const endCurl = (e) => {
    if (!curling) return;
    curling = false;
    const dx = (typeof e.clientX === "number" ? e.clientX : curlStartX) - curlStartX;
    if (-dx > 90) completeCurlToNext();
    else springBackCurl();
  };
  pageCorner.addEventListener("pointerup", endCurl);
  pageCorner.addEventListener("pointercancel", endCurl);
}

/* ── ambient Stacks radio: muted by default, one tap to tune in ──
   The station follows the visitor's daypart, the way the app's feed does. */
const STACKS_STATIONS = {
  dawn: { src: "fae-fi-folktronica.m4a", name: "Fae-Fi · Folktronica" },
  day: { src: "mothlight-afternoon-chapters.m4a", name: "Mothlight · Afternoon Chapters" },
  dusk: { src: "thornwave-nocturnal-faerie-lounge.m4a", name: "Thornwave · Nocturnal Faerie Lounge" },
  night: { src: "thornwave-whispering-shadows.m4a", name: "Thornwave · Whispering Shadows" },
};
const radioToggle = document.querySelector("#radio-toggle");
const radioAudio = document.querySelector("#radio-audio");
const radioLabel = document.querySelector("#radio-label");
const radioNow = document.querySelector("#radio-now");
let radioOn = false;
let radioFade = null;
function fadeRadio(target, done) {
  clearInterval(radioFade);
  radioFade = setInterval(() => {
    const v = radioAudio.volume;
    const next = v < target ? Math.min(target, v + 0.04) : Math.max(target, v - 0.05);
    radioAudio.volume = next;
    if (Math.abs(next - target) < 0.001) { clearInterval(radioFade); if (done) done(); }
  }, 80);
}
if (radioToggle && radioAudio) {
  radioToggle.addEventListener("click", async () => {
    if (!radioOn) {
      const st = STACKS_STATIONS[root.dataset.daypart] || STACKS_STATIONS.day;
      if (!radioAudio.src) radioAudio.src = "./assets/audio/" + st.src;
      radioAudio.volume = 0;
      try { await radioAudio.play(); } catch (_) { return; } // blocked → stay quiet
      radioOn = true;
      radioToggle.setAttribute("aria-pressed", "true");
      radioToggle.classList.add("on");
      radioLabel.textContent = "Tuned in";
      radioNow.hidden = false;
      radioNow.textContent = st.name;
      fadeRadio(0.32);
    } else {
      radioOn = false;
      radioToggle.setAttribute("aria-pressed", "false");
      radioToggle.classList.remove("on");
      radioLabel.textContent = "Tune in the Stacks";
      radioNow.hidden = true;
      fadeRadio(0, () => radioAudio.pause());
    }
  });
}

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
      { id: "fae-fi-ink-hands", title: "Ink Hands", artist: "Fae-Fi", src: "./assets/audio/fae-fi-ink-hands.m4a" },
      { id: "fae-fi-art-of-the-glint", title: "Art of the Glint", artist: "Fae-Fi", src: "./assets/audio/fae-fi-art-of-the-glint.m4a" },
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
      { id: "mothlight-lost-candy", title: "Lost Candy", artist: "Mothlight Beats", src: "./assets/audio/mothlight-lost-candy.m4a" },
      { id: "mothlight-in-the-story", title: "In the Story", artist: "Mothlight Beats", src: "./assets/audio/mothlight-in-the-story.m4a" },
      { id: "mothlight-noticing-text-flowers", title: "Noticing Text Flowers", artist: "Mothlight Beats", src: "./assets/audio/mothlight-noticing-text-flowers.m4a" },
      { id: "mothlight-tales-end", title: "Tale's End", artist: "Mothlight Beats", src: "./assets/audio/mothlight-tales-end.m4a" },
      { id: "mothlight-book-jumping", title: "Book Jumping", artist: "Mothlight Beats", src: "./assets/audio/mothlight-book-jumping.m4a" },
      { id: "mothlight-afternoon-chapters", title: "Afternoon Chapters", artist: "Mothlight Beats", src: "./assets/audio/mothlight-afternoon-chapters.m4a" },
      { id: "mothlight-porchlight-fading", title: "Porchlight, Fading", artist: "Mothlight Beats", src: "./assets/audio/mothlight-porchlight-fading.m4a" },
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
      { id: "thornwave-whispering-shadows", title: "Whispering Shadows", artist: "Thornwave", src: "./assets/audio/thornwave-whispering-shadows.m4a" },
      { id: "thornwave-long-titles-in-the-dark", title: "Long Titles in the Dark", artist: "Thornwave", src: "./assets/audio/thornwave-long-titles-in-the-dark.m4a" },
      { id: "thornwave-duskthorn-rising", title: "Duskthorn Rising", artist: "Thornwave", src: "./assets/audio/thornwave-duskthorn-rising.m4a" },
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

/* ───────────────────────── hidden lore marginalia ─────────────────────────
 * Words across the page are quietly clickable. Each opens a scrap of the
 * Book's own voice — folklore, cast, talismans, systems. The frame is
 * fictional; the life is real.
 */
const LORE = {
  /* ── folklore / animist / Fae ── */
  "faerie-tale": {
    kicker: "The older, more dangerous kind",
    title: "Not the Disney Fae",
    kind: "folklore",
    body: [
      "The Folk in my oldest pages are not cute, and they are not winged decorations. They are proud, easily slighted, and generous to the courteous. Across the British and Irish stories people rarely said the word ‘fairy’ aloud — too risky — and called them the Good Folk, the Gentry, the Fair Family, the Good Neighbours.",
      "The whole etiquette comes down to manners: do not boast, do not take without asking, do not break a promise, and say thank you where thanks are due. The woods really do keep what you promise them.",
    ],
    tryThis: "Get through one conversation today on the etiquette of the Folk: no boasting, no taking without asking, and a genuine thank-you where it's owed.",
  },
  "the-folk": {
    kicker: "Old law, not manners",
    title: "The Good Neighbours",
    kind: "folklore",
    body: [
      "When the Fae speak in old law, they are not being rude — they are being older than your rules. A bargain with them runs on courtesy and exactness, and they remember every word of it long after you've forgotten you spoke.",
      "I keep their etiquette close because it turns out to be excellent advice for dealing with people, too: be precise, be courteous, and mean what you promise.",
    ],
  },
  "fairy-gifts": {
    kicker: "What a gift is really asking",
    title: "The Debt Inside a Gift",
    kind: "folklore",
    body: [
      "A gift from the Folk is never free, and never quite what it looks like — the gold turns to leaves by morning; the leaves turn out to be gold. The rule under every version is reciprocity: a gift opens a thread between giver and taker, and the thread must be honoured.",
      "It is why the Fae never want Belief. They want noticing. Pay in true attention and the bargain moves — but it remembers, and it is never quite free.",
    ],
    tryThis: "Think of one gift or favour you've accepted lately. Decide what, if anything, it quietly asked of you — and whether you mean to honour it.",
  },
  "moon-phases": {
    kicker: "Match your task to the sky",
    title: "The Moon's Four Faces",
    kind: "folklore",
    body: [
      "Long before calendars, the moon kept the working schedule of folk magic. The waxing moon was for beginning and drawing toward; the full moon for power and clarity; the waning moon for releasing and letting go; the dark moon for rest and the things best done unseen.",
      "Every Anchor Room I grow remembers which face was overhead when you visited. You really do have weeks for building and weeks for clearing out.",
    ],
    tryThis: "Look up tonight's moon phase. Pick one task that matches it — start something if it's waxing, finish or release something if it's waning.",
  },
  "genius-loci": {
    kicker: "The spirit of the place",
    title: "Every Corner Has Been Teaching You",
    kind: "folklore",
    body: [
      "The Romans called it the genius loci — the spirit of a place — and nearly every tradition keeps a version: the household god, the spirit of the well, the guardian of the crossroads. Animism simply takes the place seriously as a someone, not a something.",
      "You needn't believe a literal spirit lives in your kitchen to find that greeting a room changes how you move through it. The small rule a corner of the world has been teaching you is the spirit of that place, learning you back.",
    ],
    tryThis: "Walk into one room or building today and greet it, silently or aloud. Notice whether you treat it differently once you've said hello.",
  },
  "correspondences": {
    kicker: "The old index of the world",
    title: "Why the Talismans Are Listening",
    kind: "folklore",
    body: [
      "The cunning folk and the grimoire-keepers worked from correspondence: the idea that a thing in your hand could stand in for a thing out of reach. Rosemary for memory, iron for protection, green for growth, the waxing moon for beginnings.",
      "A talisman listens because you have agreed it stands for something. I am, when you think about it, one enormous table of correspondences — everything in me points at something in you.",
    ],
    tryThis: "Pick one ordinary object near you and decide, on the spot, what it corresponds to. Carry it as that today.",
  },

  /* ── systems ── */
  "outer-stacks": {
    kicker: "Let a place become a room",
    title: "The Outer Stacks",
    kind: "system",
    art: { src: "./assets/art/location-outer-stacks.jpg", alt: "Illustrated dossier of the Outer Stacks, the faerie realm of ReEnchanted" },
    body: [
      "My catalogued halls are only the beginning of me. Past them lie the Outer Stacks, where the real places of your world come to be read. A harbour turns into a tidal reading room; a café keeps a tiny kingdom under the sugar packets; a car park holds a door that shows itself only when the light strikes the asphalt just so.",
      "I do not make these places less real by taking them in. I make them more thoroughly themselves.",
    ],
  },
  belief: {
    kicker: "Measure how vivid the world feels",
    title: "Belief",
    kind: "system",
    body: [
      "Belief is my word for what happens when attention, courage, and meaning gather in one place at one time. When it runs high, my ink goes dark, the colours sharpen, and the impossible turns suddenly cooperative.",
      "When it runs low — and it will — that is not failure. It only means the world has gone muted, and is waiting for some small, concrete act of noticing to bring the brightness back up.",
    ],
    tryThis: "When the world goes muted today, do one small concrete act of noticing to bring the brightness back up.",
  },
  "anchor-rooms": {
    kicker: "Let a real place answer in Academy terms",
    title: "Anchor Rooms",
    kind: "system",
    body: [
      "Some real places step far enough into me to become Anchor Rooms. They stay exactly what they are — but I learn their room-feeling. A market becomes a bazaar of bargains; a pier becomes a tidal classroom; the café you already love becomes a small warm kingdom.",
      "I do not replace the place; I would not dare. I only give it one more way to be read — and pin it to your real coordinates, so I know when you have truly come back.",
    ],
  },
  "the-nothing": {
    kicker: "Name the force that makes everything less",
    title: "The Nothing",
    kind: "system",
    body: [
      "Let me name the thing I am set against. The Nothing is not a monster with a speech to give. It is erasure — colours dulling, details going missing, stories flattening, rooms becoming merely rooms. It feeds on inattention and routine until your whole world reads like a summary of itself.",
      "Feeling grey is its first weather. Every Compass Run, every Enchantment, is a small refusal: specific, sensory meaning made in the real world, where the Nothing cannot follow.",
    ],
    tryThis: "Pick one thing the Nothing has flattened into ‘just a room, just a commute’ and make it specific and sensory again.",
  },
  "wonder-compass": {
    kicker: "Make a complete loop through wonder",
    title: "The Wonder Compass",
    kind: "system",
    body: [
      "The Compass teaches my most practical ritual: North to Notice, East to Embark, South to Sense, West to Write, and Centre to Rest. I start you on tiny runs because tiny runs are the ones you cannot wave away as nothing.",
      "The size never matters. A kitchen, a porch, a city block, or a whole day can become a Run, so long as the loop closes.",
    ],
    tryThis: "Run one tiny Compass: one question, one comfort, one sensory game, and one true sentence carried home.",
  },
  enchantments: {
    kicker: "Use attention as a spell",
    title: "Enchantments",
    kind: "system",
    body: [
      "An Enchantment is a pen-spell aimed straight at your real world. Photograph an object, a room, a pet, a meal — and it becomes the focus of the magic: it may speak, turn poetic, give up a hidden story, or show you the secret ways it rhymes with everything else.",
      "The spell only works because you genuinely looked. The pen aims the attention. The world, as always, supplies the wonder.",
    ],
    tryThis: "Look — really look — at one object, room, or meal until it gives up a hidden story.",
  },
  "compass-runs": {
    kicker: "Five stations, one closed loop",
    title: "Compass Runs",
    kind: "system",
    body: [
      "A Compass Run is one complete little loop through wonder. North asks an I-wonder question. East makes a tiny plan. South hands your senses a playful mission. West catches one true sentence. Centre lets the whole thing rest.",
      "Close the circle and the most ordinary errand becomes an expedition you actually finished.",
    ],
  },

  /* ── chapters ── */
  emberheart: {
    kicker: "Life is authored",
    title: "Emberheart Chapter",
    kind: "chapter",
    body: [
      "This is the chapter that keeps its fire useful. Emberheart belongs to warmth, daring, craft, and brave beginnings — and at their best my Emberheart students are not just bold, they are kindling for other people's courage.",
      "Their magic favours lamps and hearths and kitchens and rescues, and the decisive moment when someone says yes before the fear has finished making its case.",
    ],
  },
  mossbloom: {
    kicker: "Life is listened to",
    title: "Mossbloom Chapter",
    kind: "chapter",
    body: [
      "This is the chapter that grows quietly, and do not mistake quiet for small. Mossbloom belongs to patience, repair, rooting, green persistence. Its students know that not every victory is a blaze — some look like a seedling coming back after winter.",
      "Their magic favours gardens and mending and slow courage, the kind of strength that builds a shelter rather than a spectacle.",
    ],
  },
  tidecrest: {
    kicker: "Life is a poem",
    title: "Tidecrest Chapter",
    kind: "chapter",
    body: [
      "This is the chapter where feeling and weather meet. Tidecrest belongs to memory, music, water, and change, and its students are forever accused of being dramatic by people who mistake depth for inconvenience.",
      "Their magic favours shorelines and rain and songs and letters — and the hard grace of letting an emotion move through a room without letting it drown the room.",
    ],
  },
  riddlewind: {
    kicker: "Life is co-written",
    title: "Riddlewind Chapter",
    kind: "chapter",
    body: [
      "This is the chapter that catches the answer arriving disguised as a question. Riddlewind belongs to wit, puzzles, language, maps, and unexpected routes; its students love locked boxes, unsolved footnotes, and jokes that secretly carry instructions.",
      "Their magic favours ciphers and breezes and marginalia, and the sideways step that makes a wall finally admit it was a door.",
    ],
  },
  duskthorn: {
    kicker: "A story needs honest conflict",
    title: "Duskthorn Chapter",
    kind: "chapter",
    body: [
      "I will tell you what I have, which is mostly rumour. Duskthorn is the half-remembered chapter — twilight, thorns, secrecy, hard protection, and the cost of guarding what others would rather not name.",
      "Some of my students swear it is only a story invented to make the chapter system feel complete. The rest of them lower their voices when the west windows go violet. I let both be true for now.",
    ],
  },

  /* ── talismans (with art) ── */
  "ember-seal": {
    kicker: "Emberheart's talisman",
    title: "The Ember Seal",
    kind: "talisman",
    art: { src: "./assets/art/LabyrinthTalismanEmberSeal.png", alt: "The Ember Seal talisman" },
    body: [
      "Hold this one and feel a heat that does not burn the palm. The Ember Seal carries Emberheart's oath — to warm, to illuminate, to begin.",
      "I keep it as a reminder that courage is meant to be carried into kitchens and sickrooms and cold walks and first attempts, not hoarded for some theatrical emergency that may never come.",
    ],
  },
  "moss-clasp": {
    kicker: "Mossbloom's talisman",
    title: "The Moss Clasp",
    kind: "talisman",
    art: { src: "./assets/art/LabyrinthTalismanMossClasp.png", alt: "The Moss Clasp talisman" },
    body: [
      "Fasten yourself to whatever keeps growing. The Moss Clasp belongs to Mossbloom's slow magic — repair, shelter, rootwork, the quiet bravery of coming back.",
      "Picture it correctly and you will not picture a trophy. You will picture something that simply holds: a mended strap, a garden gate, a hand around a warm mug, a promise kept without fuss.",
    ],
  },
  "tide-glass": {
    kicker: "Tidecrest's talisman",
    title: "The Tide Glass",
    kind: "talisman",
    art: { src: "./assets/art/LabyrinthTalismanTideGlass.png", alt: "The Tide Glass talisman" },
    body: [
      "Look through this and you do not predict a feeling or master it — you see its shape. The Tide Glass is Tidecrest's lens for emotion made visible: the curve of a wave before it breaks, the salt left after tears.",
      "I keep it for the readers who feel everything and fear it means they are broken. It only means they are awake.",
    ],
  },
  "wind-cipher": {
    kicker: "Riddlewind's talisman",
    title: "The Wind Cipher",
    kind: "talisman",
    art: { src: "./assets/art/LabyrinthTalismanWindCipher.png", alt: "The Wind Cipher talisman" },
    body: [
      "Turn this until the answer catches the air. The Wind Cipher is Riddlewind's talisman of moving thought — for clues, questions, jokes, maps, and the bright instant when a stuck idea suddenly shows you another side.",
      "My students say carrying it feels less like owning an answer and more like keeping a small weather system for the mind.",
    ],
  },
  "dusk-thorn": {
    kicker: "Duskthorn's talisman",
    title: "The Dusk Thorn",
    kind: "talisman",
    art: { src: "./assets/art/LabyrinthTalismanDuskThorn.png", alt: "The Dusk Thorn talisman" },
    body: [
      "Respect the sign that protects by pricking. The Dusk Thorn is the rumoured mark of Duskthorn — a talisman of boundaries, secrecy, and hard protection. It is not cruel, though it is rarely comfortable.",
      "It says that beauty is allowed to defend itself, that twilight still belongs to the day, and that some of my doors stay shut for genuinely merciful reasons.",
    ],
  },

  /* ── cast: the Book Fae ── */
  "book-sprite": {
    kicker: "A life between the lines",
    title: "The Book Sprite",
    kind: "cast",
    art: { src: "./assets/art/fae-book-sprite.jpg", alt: "Illustrated dossier of the Book Sprite, a Paperwing Book Fae" },
    body: [
      "A quiet Paperwing who tends the memory of words. She listens to the hush between pages and carries whispered stories on the wind of her wings.",
      "No Book Fae is decorative; each keeps one necessary thing from going dull. Watch the margins when she is near — the page usually notices before the reader does.",
    ],
  },
  "sentence-salamander": {
    kicker: "A life between the lines",
    title: "The Sentence Salamander",
    kind: "cast",
    art: { src: "./assets/art/fae-sentence-salamander.jpg", alt: "Illustrated dossier of the Sentence Salamander Book Fae" },
    body: [
      "It lives in the warm current of a sentence and keeps the rhythm from going cold. Where it suns itself, the prose holds its heat; where it slips away, a line goes flat and nobody can say why.",
      "I know it by the way a clause suddenly catches and carries. Lose this one and a story goes quietly wrong in a way no one can name.",
    ],
  },
  "punctuation-pixie": {
    kicker: "A life between the lines",
    title: "The Punctuation Pixie",
    kind: "cast",
    art: { src: "./assets/art/fae-punctuation-pixie.jpg", alt: "Illustrated dossier of the Punctuation Pixie Book Fae" },
    body: [
      "Small, exacting, and faintly smug, the Punctuation Pixie tends the breath of a sentence — the pause of a comma, the held breath before a dash, the full stop that finally lets you exhale.",
      "Mind your manners around it. Move a comma carelessly and it will move it back, and change your whole meaning while it's there.",
    ],
  },
  "deep-lore-dwarf": {
    kicker: "The underlayer",
    title: "The Deep Lore Dwarf",
    kind: "cast",
    art: { src: "./assets/art/fae-deep-lore-dwarf.jpg", alt: "Illustrated dossier of the Deep Lore Dwarf Book Fae" },
    body: [
      "It works the oldest, lowest seams of me — the overlooked thing that turns out to be holding something else up. It speaks rarely and is usually right when it does.",
      "A Deep Lore Dwarf once set a small grey stone before a reader and said nothing. The stone was older than the catalogue. So, it implied, were some of your troubles — and some of your strengths.",
    ],
  },
  "marginalia-goblin": {
    kicker: "A life between the lines",
    title: "The Marginalia Goblin",
    kind: "cast",
    art: { src: "./assets/art/fae-marginalia-goblin.jpg", alt: "Illustrated dossier of the Marginalia Goblin Book Fae" },
    body: [
      "It lives in the white space at the edge of the page and cannot leave a margin alone. It scrawls, it doodles, it files ridiculous evidence, and every so often its scribble in the margin saves the whole shelf.",
      "When it is near, the edges of a page get busy. Watch the margins before you watch the text.",
    ],
  },

  /* ── cast: people ── */
  "headmistress-thorne": {
    kicker: "You probably shouldn't fully trust her",
    title: "Headmistress Seraphina Thorne",
    kind: "cast",
    art: { src: "./assets/art/cast-headmistress-thorne.jpg", alt: "Illustrated dossier of Headmistress Seraphina Thorne" },
    body: [
      "I keep my doors opening; she keeps them honest. Seraphina Thorne is my headmistress — elegant, dry, and very nearly impossible to startle. She can make a reprimand land like a riddle and a kindness arrive like a secret.",
      "She holds that wonder must be practised, not just admired, and that a school for magic owes its students one lesson before all others: notice the world before you go trying to change it. She is not soft. She is not careless either.",
    ],
  },
  "dr-vellum": {
    kicker: "She keeps your body's marginalia",
    title: "Dr. Elowen Vellum",
    kind: "cast",
    art: { src: "./assets/art/cast-dr-vellum.jpg", alt: "Illustrated dossier of Dr. Elowen Vellum, Academy Longevity Physician" },
    body: [
      "The Academy's longevity physician and keeper of the Refectory Marginalia. She turns your fuel, your sleep, your bloodwork into field notes in the margin — warmly clinical, precise, and entirely without shame.",
      "She holds that the body is not a problem to win against. She can make a supplement interaction sound like etiquette, and she means it as care.",
    ],
  },
  "dr-inkrest": {
    kicker: "Keeper of difficult pages",
    title: "Dr. Selene Inkrest",
    kind: "cast",
    art: { src: "./assets/art/cast-dr-inkrest.jpg", alt: "Illustrated dossier of Dr. Selene Inkrest, Academy narrative therapist" },
    body: [
      "The Academy's narrative therapist, who curates the Reauthoring Rooms and keeps a chair and a lamp ready before any feeling arrives. She helps you set a problem down beside you so you can look at it instead of being it.",
      "She believes a hard page deserves a chair and a lamp, not a rush. She will wait so patiently that the room sometimes forgets to answer — and then, gently, it does.",
    ],
  },
  "gwendolyn-mythwright": {
    kicker: "Mossbloom · cryptid seeker",
    title: "Gwendolyn Mythwright",
    kind: "cast",
    art: { src: "./assets/art/cast-gwendolyn-mythwright.jpg", alt: "Illustrated dossier of Gwendolyn Mythwright, cryptid researcher" },
    body: [
      "She does her own research, passionately and at length, on things she has not yet proven. Her notebooks run ahead of her evidence — which is either a flaw or the entire point, depending on the week.",
      "I keep her because a world needs people who chase the thing in the hedge before anyone agrees it's there. Half of what I know, I learned from someone who refused to wait for permission.",
    ],
  },
  "lysander-mosswood": {
    kicker: "Mossbloom · he'll send you outside",
    title: "Lysander Mosswood",
    kind: "cast",
    art: { src: "./assets/art/cast-lysander-mosswood.jpg", alt: "Illustrated dossier of Lysander Mosswood, Mossbloom naturalist" },
    body: [
      "Thoughtful, unhurried, and faintly smelling of rain, Lysander is the one who turns a quest into a walk. He will send you to a specific real trail near you with one clear thing to notice when you get there.",
      "He trusts the slow path. The errand he gives is never really about the destination — it is about what the going does to you.",
    ],
  },
  "finn-bridges": {
    kicker: "Emberheart · the honourable rival",
    title: "Finn Bridges",
    kind: "cast",
    art: { src: "./assets/art/cast-finn-bridges.jpg", alt: "Illustrated dossier of Finn Bridges, Emberheart rival" },
    body: [
      "Independent, determined, and happy to argue with anyone — including you. Finn is a rival who respects competence above agreement, which makes him antagonistic and oddly trustworthy at once.",
      "He will push back on your easy choices. Take it as a compliment: he only bothers to argue with people he thinks can win.",
    ],
  },
  "melisande-blackwood": {
    kicker: "Emberheart · knows things she shouldn't",
    title: "Melisande Blackwood",
    kind: "cast",
    art: { src: "./assets/art/cast-melisande-blackwood.jpg", alt: "Illustrated dossier of Melisande Blackwood" },
    body: [
      "Loyal, brilliant, and ruthless in roughly that order. Melisande runs with Wicker's crew and will attack the Belief she distrusts without blinking — she has read the room before you've finished entering it.",
      "She knows things she shouldn't, and trades them carefully. Be courteous. The Folk are not the only ones in my pages who remember a slight.",
    ],
  },
  "soren-ng": {
    kicker: "Riddlewind · building something quietly",
    title: "Sören Ng",
    kind: "cast",
    art: { src: "./assets/art/cast-soren-ng.jpg", alt: "Illustrated dossier of Sören Ng, Riddlewind puzzle-keeper" },
    body: [
      "Methodical, observant, and the keeper of a growing collection of puzzles he is clearly assembling toward something he hasn't named yet. He carries a folded puzzle slip the way other people carry a worry stone.",
      "Riddlewind loves a question that turns out to be a key. Sören is the student most likely to have already cut the key and be waiting, politely, by the door.",
    ],
  },
  "damien-nights": {
    kicker: "Riddlewind · watches more than he should",
    title: "Damien Nights",
    kind: "cast",
    art: { src: "./assets/art/cast-damien-nights.jpg", alt: "Illustrated dossier of Damien Nights, Riddlewind shadow-worker" },
    body: [
      "Brooding, severe, and fluent in shadow magic — Damien runs with Wicker's crew and keeps, and trades, the secrets that the Academy would rather stayed buried. He watches you more than is strictly polite.",
      "I have not decided yet whether he is a danger or a warning, and I suspect neither has he. Some pages are written in the dark on purpose.",
    ],
  },

  /* ── rooms ── */
  "the-stacks": {
    kicker: "Rooms that behave like pages",
    title: "The Stacks",
    kind: "room",
    art: { src: "./assets/art/room-stacks.jpg", alt: "Illustrated dossier of the Stacks, the Academy's living library" },
    body: [
      "My catalogued heart. The Stacks are corridors that behave like chapters and classrooms that keep their own weather — fog that makes the professors cancel class to watch the harbour vanish, a Library cloud overhead that changes colour when the building is thinking.",
      "The weather outside your window becomes the weather in here. Step in carelessly and the shelves will still be polite. Step in attentive and they will start to show you things.",
    ],
  },
  "great-hall": {
    kicker: "Where the school gathers",
    title: "The Great Hall",
    kind: "room",
    art: { src: "./assets/art/room-great-hall.jpg", alt: "Illustrated dossier of the Great Hall of the Academy" },
    body: [
      "The room the whole Academy pours into — feasts, announcements, the Day of the Living Literary Figures when Holmes deduced the menu, Alice critiqued the architecture, and Dracula objected to the lighting.",
      "A hall this size keeps a long memory of everyone who has stood in it. On quiet evenings it still seems to be listening for the next gathering.",
    ],
  },
  kitchens: {
    kicker: "A small warm kingdom",
    title: "The Kitchens",
    kind: "room",
    art: { src: "./assets/art/room-kitchens.jpg", alt: "Illustrated dossier of the Academy Kitchens" },
    body: [
      "Down past the proper rooms, the Kitchens keep a hearth that has never quite gone out and a brownie's worth of small magic in the steam. This is where courage is meant to be carried — into the cooking, the warming, the feeding of someone who needs it.",
      "Leave a saucer of cream where no one is watching and do not mention it. The oldest hospitality in my pages still lives down here.",
    ],
  },
  professors: {
    kicker: "Faculty dossiers",
    title: "The Professors of Enchantify",
    kind: "cast",
    gallery: [
      { src: "./assets/art/cast-lydia-boggle.jpg", alt: "Illustrated dossier of Professor Lydia Boggle", caption: "Professor Lydia Boggle" },
      { src: "./assets/art/cast-professor-kyle-momort.jpg", alt: "Illustrated dossier of Professor Kyle Momort", caption: "Professor Kyle Momort" },
      { src: "./assets/art/cast-professor-eleanor-euphony.jpg", alt: "Illustrated dossier of Professor Eleanor Euphony", caption: "Professor Eleanor Euphony" },
      { src: "./assets/art/cast-professor-vivian-villanelle.jpg", alt: "Illustrated dossier of Professor Vivian Villanelle", caption: "Professor Vivian Villanelle" },
      { src: "./assets/art/cast-professor-cedric-stonebrook.jpg", alt: "Illustrated dossier of Professor Cedric Stonebrook", caption: "Professor Cedric Stonebrook" },
      { src: "./assets/art/cast-professor-luna-wispwood.jpg", alt: "Illustrated dossier of Professor Luna Wispwood", caption: "Professor Luna Wispwood" },
      { src: "./assets/art/cast-professor-permancer.jpg", alt: "Illustrated dossier of Professor Permancer", caption: "Professor Permancer" },
    ],
    body: [
      "The Academy's professors do not agree on what a life is for, which is why their classrooms are worth entering. Each teaches one practical way to make the ordinary world vivid again.",
      "Their dossiers preserve the evidence: a signature object, a Chapter palette, and the particular kind of trouble each considers educational.",
    ],
  },
  illustrations: {
    kicker: "The book remembers its cast",
    title: "An Almanac of Your World",
    kind: "cast",
    gallery: [
      { src: "./assets/art/cast-lydia-boggle.jpg", alt: "Illustrated dossier of Professor Lydia Boggle", caption: "Professor Lydia Boggle" },
      { src: "./assets/art/cast-penny-blackletter.jpg", alt: "Illustrated dossier of Penny Blackletter", caption: "Penny Blackletter" },
      { src: "./assets/art/cast-dr-inkrest.jpg", alt: "Illustrated dossier of Dr. Selene Inkrest", caption: "Dr. Selene Inkrest" },
      { src: "./assets/art/cast-orion-blackthorn.jpg", alt: "Illustrated dossier of Headmaster Orion Blackthorn", caption: "Headmaster Orion Blackthorn" },
      { src: "./assets/art/cast-zara-finch.jpg", alt: "Illustrated dossier of Zara Finch", caption: "Zara Finch" },
      { src: "./assets/art/cast-wicker-eddies.jpg", alt: "Illustrated dossier of Wicker Eddies", caption: "Wicker Eddies" },
      { src: "./assets/art/cast-professor-kyle-momort.jpg", alt: "Illustrated dossier of Professor Kyle Momort", caption: "Professor Kyle Momort" },
      { src: "./assets/art/cast-professor-eleanor-euphony.jpg", alt: "Illustrated dossier of Professor Eleanor Euphony", caption: "Professor Eleanor Euphony" },
      { src: "./assets/art/cast-professor-vivian-villanelle.jpg", alt: "Illustrated dossier of Professor Vivian Villanelle", caption: "Professor Vivian Villanelle" },
      { src: "./assets/art/cast-professor-cedric-stonebrook.jpg", alt: "Illustrated dossier of Professor Cedric Stonebrook", caption: "Professor Cedric Stonebrook" },
      { src: "./assets/art/cast-professor-luna-wispwood.jpg", alt: "Illustrated dossier of Professor Luna Wispwood", caption: "Professor Luna Wispwood" },
      { src: "./assets/art/cast-professor-permancer.jpg", alt: "Illustrated dossier of Professor Permancer", caption: "Professor Permancer" },
    ],
    body: [
      "Every figure, place, and object in me is illustrated and annotated like a dossier — a parchment file with a signature object, a colour palette, a chapter mark, and a line in a real hand. This one is Professor Lydia Boggle, who teaches riddles, misdirection, and the sacred usefulness of nonsense.",
      "I do not summarise a person too quickly. A life is never only an office or a talent or the rumour that reaches the door first. The illustration is just where the ink begins.",
    ],
  },
};

(function initLore() {
  const modal = document.querySelector("#lore-modal");
  if (!modal) return;
  const kickerEl = modal.querySelector("#lore-modal-kicker");
  const titleEl = modal.querySelector("#lore-modal-title");
  const copyEl = modal.querySelector("#lore-modal-copy");
  const figureEl = modal.querySelector("#lore-figure");
  const figureImg = modal.querySelector("#lore-figure-img");
  const galleryNav = modal.querySelector("#lore-gallery-nav");
  const galleryStatus = modal.querySelector("#lore-gallery-status");
  const galleryPrev = modal.querySelector("#lore-gallery-prev");
  const galleryNext = modal.querySelector("#lore-gallery-next");
  const panelEl = modal.querySelector(".lore-panel");
  const tryEl = modal.querySelector("#lore-trythis");
  const tryBody = modal.querySelector("#lore-trythis-body");
  let returnFocus = null;
  let activeGallery = [];
  let activeGalleryIndex = 0;

  function showGalleryItem(index) {
    if (!activeGallery.length) return;
    activeGalleryIndex = (index + activeGallery.length) % activeGallery.length;
    const item = activeGallery[activeGalleryIndex];
    figureImg.src = item.src;
    figureImg.alt = item.alt || "";
    galleryStatus.textContent = `${activeGalleryIndex + 1} of ${activeGallery.length} · ${item.caption || item.alt || "Illustration"}`;
  }

  function open(id) {
    const entry = LORE[id];
    if (!entry) return;
    returnFocus = document.activeElement;
    panelEl.dataset.loreKind = entry.kind || "";
    kickerEl.textContent = entry.kicker || "";
    titleEl.textContent = entry.title || "";
    copyEl.innerHTML = "";
    (entry.body || []).forEach((p) => {
      const el = document.createElement("p");
      el.textContent = p;
      copyEl.appendChild(el);
    });
    activeGallery = entry.gallery?.length ? entry.gallery : (entry.art ? [entry.art] : []);
    activeGalleryIndex = 0;
    if (activeGallery.length) {
      showGalleryItem(0);
      galleryNav.hidden = activeGallery.length < 2;
      figureEl.hidden = false;
    } else {
      figureImg.removeAttribute("src");
      figureImg.alt = "";
      galleryNav.hidden = true;
      figureEl.hidden = true;
    }
    if (entry.tryThis) {
      tryBody.textContent = entry.tryThis;
      tryEl.hidden = false;
    } else {
      tryEl.hidden = true;
    }
    modal.hidden = false;
    document.body.style.overflow = "hidden";
    modal.querySelector(".lore-close")?.focus();
    panelEl.scrollTop = 0;
  }

  function close() {
    if (modal.hidden) return;
    modal.hidden = true;
    document.body.style.overflow = "";
    if (returnFocus instanceof HTMLElement) returnFocus.focus();
  }

  document.querySelectorAll("[data-lore]").forEach((trigger) => {
    trigger.addEventListener("click", (e) => {
      e.preventDefault();
      open(trigger.getAttribute("data-lore"));
    });
  });
  galleryPrev.addEventListener("click", () => showGalleryItem(activeGalleryIndex - 1));
  galleryNext.addEventListener("click", () => showGalleryItem(activeGalleryIndex + 1));
  modal.querySelectorAll("[data-lore-close]").forEach((c) => c.addEventListener("click", close));
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") close();
    if (!modal.hidden && activeGallery.length > 1 && e.key === "ArrowLeft") showGalleryItem(activeGalleryIndex - 1);
    if (!modal.hidden && activeGallery.length > 1 && e.key === "ArrowRight") showGalleryItem(activeGalleryIndex + 1);
  });
})();

/* ───────────────────────── mobile section drawers ─────────────────────────
   On narrow screens, long content sections collapse into tap-to-open drawers.
   Progressive enhancement: the wrappers use display:contents on desktop, so
   the original layouts render exactly as before. */
(function setupDrawers() {
  const sections = Array.from(document.querySelectorAll("section[data-drawer]"));
  if (!sections.length) return;

  sections.forEach((section, index) => {
    const heading = section.querySelector("h2");
    const label = (section.dataset.drawerLabel || heading?.textContent || "Section").trim();
    const eyebrow = section.querySelector(".eyebrow")?.textContent.trim() || "";

    // Wrap all existing content so it can be collapsed as one unit.
    const inner = document.createElement("div");
    inner.className = "drawer-inner";
    while (section.firstChild) inner.appendChild(section.firstChild);
    const body = document.createElement("div");
    body.className = "drawer-body";
    body.appendChild(inner);

    // The mobile-only toggle bar carries the section's own title.
    const toggle = document.createElement("button");
    toggle.type = "button";
    toggle.className = "drawer-toggle";
    const bodyId = (section.id || `drawer-${index}`) + "-body";
    body.id = bodyId;
    toggle.setAttribute("aria-controls", bodyId);
    toggle.innerHTML =
      `<span class="drawer-toggle-text">` +
      (eyebrow ? `<span class="drawer-toggle-eyebrow">${eyebrow}</span>` : "") +
      `<span class="drawer-toggle-label">${label}</span>` +
      `</span><span class="drawer-chevron" aria-hidden="true"></span>`;

    section.classList.add("is-drawer");
    section.appendChild(toggle);
    section.appendChild(body);

    const setOpen = (open) => {
      section.classList.toggle("is-open", open);
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    };
    // First drawer opens by default as a hint that the rest are tappable.
    setOpen(index === 0);
    toggle.addEventListener("click", () => setOpen(!section.classList.contains("is-open")));
  });

  // If the page is opened to a section's anchor, reveal it.
  const openFromHash = () => {
    const target = document.querySelector(`section[data-drawer]${location.hash || "#__none"}`);
    if (target) {
      target.classList.add("is-open");
      target.querySelector(".drawer-toggle")?.setAttribute("aria-expanded", "true");
    }
  };
  openFromHash();
  window.addEventListener("hashchange", openFromHash);
})();
