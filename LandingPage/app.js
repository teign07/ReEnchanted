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
   demo reads the visitor's actual sky, moon, and hour - exactly the way
   the app's Weather Page does - with a graceful Stacks default offline. */
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
  if (code === 0) return m("clear", "The sky is scrubbed clean and the light comes through unhindered.", "It's clear.");
  if (code <= 2) return m("partly cloudy", "A few pages of cloud drift across an otherwise open sky.", "It's partly cloudy.");
  if (code === 3) return m("overcast", "The sky weeps a soft, gray shroud over the land.", "It's overcast.");
  if (code <= 48) return m("fog", "Fog has softened every edge of the world into suggestion.", "It's foggy.");
  if (code <= 57) return m("drizzle", "A fine drizzle is writing in the margins of the air.", "It's drizzling.");
  if (code <= 67) return m("rain", "The sky weeps a soft, gray shroud over the land.", "It's raining.");
  if (code <= 77) return m("snow", "The sky is letting down quiet paper, one flake at a time.", "It's snowing.");
  if (code <= 82) return m("showers", "The sky keeps clearing its throat in bursts of rain.", "Showers are passing through.");
  if (code <= 86) return m("snow showers", "Brief snow keeps arriving like loose pages on the wind.", "Snow showers are passing through.");
  return m("storm", "The sky is rearranging its furniture; thunder reads aloud.", "There's a thunderstorm.");
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

const STACKS_SEARCH_RESULTS = [
  {
    title: "Love",
    group: "The Cast",
    type: "Cast",
    text: "Small Glow. Love.",
    tags: ["love", "glow", "cast"],
  },
  {
    title: "Riddlewind Chapter",
    group: "From the Library",
    type: "Lore",
    text: "Maps, jokes, language, and unexpected routes; its students love locked boxes, unsolved footnotes, and jokes that secretly carry instructions.",
    tags: ["love", "riddlewind", "chapter", "lore", "puzzles"],
  },
  {
    title: "Still Club",
    group: "From the Library",
    type: "Lore",
    text: "A refusal to improve the moment. The exhausted students love the ambitious compassion and the quiet holiness of stopping.",
    tags: ["love", "tired", "rest", "still", "club"],
  },
  {
    title: "Porchlight & Moth",
    group: "Radio",
    type: "Station note",
    text: "A porch lamp left on for everyone you're still waiting up for.",
    tags: ["porch", "mothlight", "love", "radio", "memory"],
  },
  {
    title: "Rain on the Weather Page",
    group: "Kept Pages",
    type: "Weather",
    text: "The sky kept clearing its throat in bursts of rain; the Book saved the soft edge of the afternoon.",
    tags: ["rain", "rainy", "weather", "page", "kept"],
  },
  {
    title: "The Tired Page",
    group: "Kept Pages",
    type: "Inner Weather",
    text: "A hard afternoon named without becoming a verdict.",
    tags: ["tired", "rest", "inner", "weather", "mood"],
  },
  {
    title: "Compass Mission",
    group: "Missions",
    type: "Wonder Compass",
    text: "Go to the nearest threshold and bring back one sensory sentence.",
    tags: ["mission", "missions", "compass", "threshold", "sentence"],
  },
];

const DEFAULT_STACKS_QUERY = "Show me everything with love";

function stacksMatches(query) {
  const normalized = query.toLowerCase().replace(/[“”"?.!,]/g, " ");
  const words = normalized.split(/\s+/).filter((word) => word.length > 2);
  const matches = STACKS_SEARCH_RESULTS
    .map((item) => {
      const haystack = `${item.title} ${item.group} ${item.type} ${item.text} ${item.tags.join(" ")}`.toLowerCase();
      const score = words.reduce((total, word) => total + (haystack.includes(word) ? 1 : 0), 0);
      return { ...item, score };
    })
    .filter((item) => item.score > 0)
    .sort((a, b) => b.score - a.score);
  return matches.length ? matches.slice(0, 4) : STACKS_SEARCH_RESULTS.slice(0, 3);
}

function renderSemanticResults(target, query = DEFAULT_STACKS_QUERY) {
  const wrap = typeof target === "string" ? document.querySelector(target) : target;
  if (!wrap) return [];
  const matches = stacksMatches(query);
  wrap.innerHTML = `
    <p class="semantic-search-count">${matches.length} result${matches.length === 1 ? "" : "s"} for <strong>${escapeHTML(query)}</strong></p>
    ${matches.map((item) => `
      <article class="semantic-result">
        <span>${escapeHTML(item.group)} · ${escapeHTML(item.type)}</span>
        <strong>${escapeHTML(item.title)}</strong>
        <p>${escapeHTML(item.text)}</p>
      </article>
    `).join("")}
  `;
  return matches;
}

function runSemanticSearch(scope, query) {
  const cleanQuery = (query || DEFAULT_STACKS_QUERY).trim() || DEFAULT_STACKS_QUERY;
  if (scope === "section") {
    const input = document.querySelector("#section-search-input");
    if (input) input.value = cleanQuery;
    renderSemanticResults("#section-search-results", cleanQuery);
  } else {
    if (bookSearchInput) bookSearchInput.value = cleanQuery;
    updateSearchPage(cleanQuery);
  }
  earnGlow(`semantic-search-${scope}-${cleanQuery.toLowerCase()}`, 1, "The Stacks answered a plain-language question.");
}

/* ───────────────────────── the deck of pages ─────────────────────────
   Each page: a real screen from the app + copy + the line it contributes
   to the braided "Book of You" if the reader keeps it.                  */
const PAGES = [
  {
    kicker: "The First Door",
    title: "The cover opens.",
    body: "You open the app. The first word lifts from the screen and turns to look at you. Then the sentence breaks its spine. Ink blooms under the glass, cold as rainwater and impossibly wet, and climbs over your fingers. The room tips. Stories rush past in layers: green sea-salt, dragonfire underfoot, a train brake screaming somewhere in another ending. There's no down. Only chapters.",
    source: "First-run onboarding · the fall",
    shot: "./assets/screens/home.jpg",
    braid: "The Book opened like weather, and the first impossible word looked back.",
    decision: false,
    onboardingStep: "fall",
  },
  {
    kicker: "The Great Unwritten",
    title: "Your ordinary world is the chapter.",
    body: "Zara Finch reaches you first. She checks your sleeve for punctuation, then looks behind you for the door that vanished. \"You're from the Great Unwritten,\" she says. \"That means your ordinary world is a chapter of this Book - supposedly the best one. No fixed plot. No narrator cleaning up afterward. What you do next actually matters.\" She says it like a warning and a compliment, which is very Zara.",
    source: "Zara Finch · arrival notes",
    shot: "./assets/screens/character-zara-finch.png",
    braid: "Zara named the Great Unwritten, and the ordinary world stopped pretending it was outside the story.",
    decision: false,
    onboardingStep: "unwritten",
  },
  {
    kicker: "Zara's First Question",
    title: "The Book learns one small texture.",
    body: "\"Before the Book starts choosing pages for you, it needs a few human details,\" Zara says. \"Nothing grand. Grand answers are usually hiding something.\" She studies you, then points at the blank margin. \"What do you eat when you read? Mine's sharp green apples. They keep me awake when the footnotes get predatory.\" She glances at the Book. \"Don't make it impressive. The little answer is the useful one. Specificity is how doors learn handles.\"",
    source: "Onboarding · specificity",
    shot: "./assets/screens/margins.jpg",
    braid: "A snack appeared in the margin like a tiny ration for the road.",
    decision: false,
    onboardingStep: "snack",
  },
  {
    kicker: "The Name the Book Knows",
    title: "Give the page a name it can say kindly.",
    body: "Zara taps a blank line and lowers her voice. \"The Book doesn't need your legal anything. It wants the name that feels like yours when someone says it kindly.\" Later, when someone in the Stacks writes to you, argues with you, misses you, or leaves a note under the wrong door, this is the name the page will reach for.",
    source: "Onboarding · reader name",
    shot: "./assets/screens/book-of-you.jpg",
    braid: "The Book learned the name at the center of the page and darkened the letters so future doors could find it.",
    decision: false,
    onboardingStep: "name",
  },
  {
    kicker: "Belief and Glow",
    title: "Name the stubborn light.",
    body: "At the far end of the aisle, a grey absence worries at the corner of a page. One word vanishes. Then another. Zara raises her compass and the erased letters return in wet black ink. \"That's the Nothing,\" she says. \"It's what happens when attention leaves and the world turns into wallpaper.\" She offers you her Belief - every book is a door - then nods to the blank line. \"Your turn. What matters enough that you want the Book to notice it?\"",
    source: "Onboarding · Belief",
    shot: "./assets/screens/belief-cast.jpg",
    braid: "A named belief warmed under the page, small at first and therefore serious.",
    decision: false,
    onboardingStep: "belief",
  },
  {
    kicker: "Wicker Interrupts",
    title: "Show him what kind of story arrived.",
    body: "You and Zara are almost through the next arch when Wicker Eddies steps out from behind a shelf as if he has been waiting for the exact worst moment. \"So this is the impossible reader,\" he says. \"Tiny bit shorter than the rumors.\" Zara sighs. \"Wicker.\" He smiles like that was the point. \"Show me what kind of story the Unwritten sent us.\" The Book warms under your hand. Zara looks at you, not him. \"Answer in your own shape.\"",
    source: "Onboarding · Belief roll",
    shot: "./assets/screens/character-wicker-eddies.png",
    braid: "Wicker tested the new belief with a crooked smile, and the page rolled its little thunder.",
    decision: false,
    onboardingStep: "wicker",
  },
  {
    kicker: "The First Page Rises",
    title: "Try keeping one true thing.",
    body: "A small page slips from the stack and lands in front of you. \"This is the whole trick,\" Zara says. \"The Book offers pages from your real day: weather, people, memories, questions, little strange invitations. You don't have to keep them all. If a page catches something true, keep it. If it's not for today, let it wait. The archive should be honest before it's impressive.\"",
    source: "Onboarding · keep / wait rehearsal",
    shot: "./assets/screens/keep-page.jpg",
    braid: "The first practice page rose, and the archive learned the difference between yes and not today.",
    onboardingStep: "first-page",
  },
  {
    kicker: "Weather Page",
    title: "The Weather Page has opened.",
    bodyHTML: weatherPageHTML(FALLBACK_WEATHER),
    source: "Weather doorway · public forecast",
    shot: "./assets/screens/story-page-weather-prose.png",
    braid: "Fog pressed its thumb to the Weather Page, softening the streetlights until the whole sky felt made of wool.",
  },
  {
    kicker: "Story Page · A Choice",
    title: "Choose how the page turns.",
    body: "Professor Villanelle has found a brittle weather chart whose reading refuses to match its shadow. How you choose to look - close at the paper, square against the chart, or into the silence - is the hand that decides which future this page tells.",
    source: "Weather in the Stacks · playable fiction",
    shot: "./assets/screens/story-page-weather-choices.png",
    braid: "The brittle chart smelled faintly of dust and rain; three futures lifted their corners like paper wanting wind.",
    storyPrompt: true,
  },
  {
    kicker: "Radio",
    title: "Music becomes weather in the stacks.",
    body: "Broadcasts drift through the shelves like weather. Tune one in and keep it, and I read the rest of your day in its key.",
    source: "World effect",
    shot: "./assets/screens/radio.jpg",
    braid: "A broadcast found the rafters and made the shelves hum, each spine holding a different temperature of song.",
    radioPrompt: true,
  },
  {
    kicker: "Search the Stacks",
    title: "Ask for the feeling, not the filename.",
    body: "The Stacks understand loose human questions. Search for a mood, an image, a person, or a half-remembered thread, and the private index brings back the pages that know what you mean.",
    source: "Semantic search · private archive",
    shot: "./assets/screens/search-stacks-results.jpg",
    braid: "The Stacks answered a plain-language question and proved the archive remembered more than titles.",
    searchPrompt: true,
  },
  {
    kicker: "Fuel Log",
    title: "Dr. Vellum opens a plate note.",
    body: "Tell me what you ate, in plain words. Dr. Vellum pencils the rough numbers into the margin and reads them as care, never a verdict - the body kept honestly, not graded.",
    source: "Dr. Vellum's Chart · nutrition lookup",
    shot: "./assets/art/cast-dr-vellum.jpg",
    braid: "Dr. Vellum set the plate note beside a cranberry pencil and let the numbers cool before they could bite.",
    fuelPrompt: true,
  },
  {
    kicker: "Inner Weather",
    title: "Name the weather inside.",
    body: "Name the nearest weather, then hand me one private detail. Dr. Inkrest keeps it as context, not a problem to solve - a chair and a lamp before any feeling is asked to behave.",
    source: "Dr. Inkrest's Chart · inner weather",
    shot: "./assets/screens/belief-cast.jpg",
    braid: "I named the inward weather and felt the room unclench, as if the ceiling had been waiting for the word.",
    innerWeatherPrompt: true,
  },
  {
    kicker: "One-Sentence Souvenir",
    title: "Write one true line from your day.",
    body: "I'm asking for your sentence now - one sensory, exact line that would otherwise slip away by morning. Borrow a starting line if you're stuck, then bend it toward your real day and keep it.",
    source: "Kept from the margins",
    shot: "./assets/screens/margins.jpg",
    braid: "At Moose Point, a small hand warmed my palm while the waves folded silver over stone.",
    quiet: true,
    sentencePrompt: true,
  },
  {
    kicker: "A Character Arrives",
    title: "Zara Finch, pressed and filed.",
    body: "Zara notices exits before introductions and calls it being prepared. She is loyal enough to find the path that holds, and wary enough to check whether it will hold twice.",
    source: "Riddlewind guide · hidden alcoves",
    shot: "./assets/screens/character-zara-finch.png",
    braid: "Zara Finch stepped out of the file with storm-gray eyes and a satchel full of exits, and the hallway straightened for her.",
    characterPrompt: true,
  },
  {
    kicker: "Spells & Glow",
    title: "Cast an Enchantment.",
    body: "Choose a spell and give it one true photo. I look until the ordinary thing gives up its hidden story - the pen aims the attention, and the world, as always, supplies the wonder.",
    source: "Enchantment · illuminated photo",
    shot: "./assets/screens/enchantment-rabbit.jpeg",
    braid: "I gave the Book an ordinary image; gold ink gathered at its edges and made the real thing answer.",
    enchantmentPrompt: true,
  },
  {
    kicker: "Wonder Compass",
    title: "The Wonder Compass: A Field Guide to Finding Magic in the Mess",
    body: "Included free, to pull you out of routine and into Wonder any day. Pick a chapter below and let it walk you back into the world with sharper attention.",
    source: "Wonder Compass · free field guide",
    shot: "./assets/screens/wonder-compass.jpg",
    braid: "The Compass clicked in my pocket, and the gray commute opened one green eye.",
    wonderPrompt: true,
  },
  {
    kicker: "Real Life, Kept",
    title: "This quiet scene, the Book kept.",
    body: "An illuminated photo is an ordinary picture I've read closely until it answers in its own margins, field-journal style. Penny Blackletter, who edits The Bleed, can surprise you with one pulled from your library - or you choose your own to turn into a story, or take a new photo on the spot.",
    source: "Ordinary wonder",
    shot: "./assets/screens/real-life-kept.jpg",
    braid: "Low light pooled in the fabric, and the afternoon lay down quietly enough for the Book to hear it breathing.",
    quiet: true,
  },
];
const WEATHER_INDEX = PAGES.findIndex((p) => p.kicker === "Weather Page");

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
const onboardingPanel = document.querySelector("#onboarding-panel");
const sentencePolisher = document.querySelector("#sentence-polisher");
const readerLineInput = document.querySelector("#reader-line");
const stacksRadio = document.querySelector("#stacks-radio");
const bookSearchDemo = document.querySelector("#book-search-demo");
const bookSearchInput = document.querySelector("#book-search-input");
const bookSearchResults = document.querySelector("#book-search-results");
const characterChoices = document.querySelector("#character-choices");
const characterOptionsWrap = document.querySelector("#character-options");
const enchantmentLab = document.querySelector("#enchantment-lab");
const enchantmentSpellsWrap = document.querySelector("#enchantment-spells");
const enchantmentSamplesWrap = document.querySelector("#enchantment-samples");
const enchantmentReading = document.querySelector("#enchantment-reading");
const wonderChoices = document.querySelector("#wonder-choices");
const wonderOptionsWrap = document.querySelector("#wonder-options");
const fuelLog = document.querySelector("#fuel-log");
const fuelInput = document.querySelector("#fuel-input");
const fuelSamplesWrap = document.querySelector("#fuel-samples");
const fuelReading = document.querySelector("#fuel-reading");
const innerWeather = document.querySelector("#inner-weather");
const innerWeatherOptionsWrap = document.querySelector("#inner-weather-options");
const innerWeatherInput = document.querySelector("#inner-weather-input");
const innerWeatherReading = document.querySelector("#inner-weather-reading");
const nav = document.querySelector("#book-nav");
const btnPrev = document.querySelector("#btn-prev");
const btnNext = document.querySelector("#btn-next");
const navCount = document.querySelector("#nav-count");
const progressFill = document.querySelector(".book-progress-fill");
const hint = document.querySelector("#book-hint");
const glowPill = document.querySelector("#glow-pill");
const glowMenu = document.querySelector("#glow-menu");
const glowCount = document.querySelector("#glow-count");
const glowFill = document.querySelector("#glow-fill");
const glowSpendNote = document.querySelector("#glow-spend-note");
const glowSheetTitle = document.querySelector("#glow-sheet-title");
const glowSheetTier = document.querySelector("#glow-sheet-tier");
const glowState = document.querySelector("#glow-state");
const glowClose = document.querySelector("#glow-close");
const glowReveal = document.querySelector("#glow-reveal");
const glowRevealTitle = document.querySelector("#glow-reveal-title");
const glowRevealCopy = document.querySelector("#glow-reveal-copy");
const braid = document.querySelector("#braid");
const braidText = document.querySelector("#braid-text");
const braidIntro = document.querySelector("#braid-intro");
const braidReplay = document.querySelector("#braid-replay");
const closeBookBtn = document.querySelector("#close-book-btn");

let index = 0;
let animating = false;
const choices = new Array(PAGES.length).fill(null); // null | "keep" | "wait"

const onboarding = {
  fallChoice: "",
  unwrittenTucked: false,
  snack: "",
  name: "",
  belief: "",
  plantedBelief: null,
  wickerMode: "",
  wickerRoll: null,
  firstSouvenir: "",
};

const FALL_CHOICES = [
  {
    id: "ink",
    label: "Touch the wet ink",
    chosen: "Ink slicks your fingers",
    braid: "wet ink climbed over my fingers",
    hint: "Ink answered under the glass.",
  },
  {
    id: "landing",
    label: "Brace for the landing",
    chosen: "Stone catches your knees",
    braid: "stone caught me at the bottom of the fall",
    hint: "Stone met your knees. The page can hold you.",
  },
];
const WICKER_MODES = [
  {
    id: "slice-of-life",
    title: "Slice of Life",
    detail: "Answer him with one concrete ordinary detail.",
    difficulty: 42,
    success: "Wicker tries to sneer, but the ordinary detail lands too cleanly. Zara looks pleased despite herself.",
    failure: "The detail comes out smaller than you meant. Wicker finds the loose thread, but Zara steps beside you before he can pull it.",
  },
  {
    id: "arc",
    title: "Arc",
    detail: "Turn the interruption into a promise of motion.",
    difficulty: 56,
    success: "You name the direction before Wicker can name the flaw. The hall shifts half a degree toward your next door.",
    failure: "The promise wobbles. Wicker hears it immediately, but the Book keeps the attempt as a beginning.",
  },
  {
    id: "surprise",
    title: "Surprise",
    detail: "Refuse the expected answer and let something odd through.",
    difficulty: 64,
    success: "The answer is so sideways that Wicker forgets to be superior for one entire second.",
    failure: "The surprise misfires into awkward magic. Wicker enjoys that too much. Zara mutters, \"Useful data,\" which somehow helps.",
  },
];

function cleanOnboardingValue(value) {
  return String(value || "").trim().replace(/\s+/g, " ");
}

function wickerMode() {
  return WICKER_MODES.find((mode) => mode.id === onboarding.wickerMode);
}

function fallChoice() {
  return FALL_CHOICES.find((choice) => choice.id === onboarding.fallChoice);
}

function onboardingReady(page = PAGES[index]) {
  switch (page?.onboardingStep) {
    case "fall":
      return Boolean(onboarding.fallChoice);
    case "unwritten":
      return onboarding.unwrittenTucked;
    case "snack":
      return Boolean(cleanOnboardingValue(onboarding.snack));
    case "name":
      return Boolean(cleanOnboardingValue(onboarding.name));
    case "belief":
      return Boolean(cleanOnboardingValue(onboarding.belief)) && onboarding.plantedBelief !== null;
    case "wicker":
      return Boolean(onboarding.wickerRoll);
    case "first-page":
      return choices[index] === "wait" || (choices[index] === "keep" && Boolean(cleanOnboardingValue(onboarding.firstSouvenir)));
    default:
      return true;
  }
}

function updateOnboardingNav() {
  if (btnNext) btnNext.disabled = !onboardingReady();
}

function onboardingButton(action, label, selected = false, extraClass = "") {
  return `<button class="onboarding-action ${extraClass}${selected ? " chosen" : ""}" type="button" data-onboard-action="${action}">${label}</button>`;
}

function renderOnboardingPanel(page) {
  if (!onboardingPanel) return true;
  if (!page.onboardingStep) {
    onboardingPanel.hidden = true;
    onboardingPanel.innerHTML = "";
    return true;
  }

  onboardingPanel.hidden = false;
  const snack = escapeHTML(onboarding.snack);
  const name = escapeHTML(onboarding.name);
  const belief = escapeHTML(onboarding.belief);
  const firstSouvenir = escapeHTML(onboarding.firstSouvenir);
  const mode = wickerMode();
  const roll = onboarding.wickerRoll;
  let html = "";

  if (page.onboardingStep === "fall") {
    const fallButtons = FALL_CHOICES.map((choice) =>
      onboardingButton(`fall:${choice.id}`, onboarding.fallChoice === choice.id ? choice.chosen : choice.label, onboarding.fallChoice === choice.id)
    ).join("");
    html = `
      <p class="onboarding-panel-title">Get your hands into the page</p>
      <p class="onboarding-prompt">The screen is becoming a doorway. Choose the one thing you do as the Book pulls you through.</p>
      <div class="onboarding-actions">${fallButtons}</div>
      <p class="onboarding-result">${onboardingReady(page) ? "Good. The fall has a shape now. Turn the page." : "Choose one way through. The Book only needs one true gesture."}</p>
    `;
  } else if (page.onboardingStep === "unwritten") {
    html = `
      <p class="onboarding-panel-title">File the impossible fact</p>
      <p class="onboarding-prompt">Zara hands you a torn word: UNWRITTEN. It doesn't behave like paper. Put it where the Book can keep track of it.</p>
      <div class="onboarding-actions">
        ${onboardingButton("unwritten", onboarding.unwrittenTucked ? "UNWRITTEN tucked under the rule" : "Tuck UNWRITTEN into the margin", onboarding.unwrittenTucked)}
      </div>
    `;
  } else if (page.onboardingStep === "snack") {
    html = `
      <label class="onboarding-field">
        <span>Favorite reading snack</span>
        <input type="text" data-onboard-input="snack" maxlength="60" autocomplete="off" value="${snack}" placeholder="sharp apples, tea, gummy bears">
      </label>
      <p class="onboarding-result">${onboarding.snack ? `The margin writes: ${snack}. Tiny, serious ink. Specificity gives doors handles.` : "One small true answer is enough. The Book is listening for texture."}</p>
    `;
  } else if (page.onboardingStep === "name") {
    html = `
      <label class="onboarding-field">
        <span>What should the Book call you?</span>
        <input type="text" data-onboard-input="name" maxlength="48" autocomplete="name" value="${name}" placeholder="a kind name, not a form name">
      </label>
      <p class="onboarding-result">${onboarding.name ? `Hello, ${name}. Zara says it once, carefully, and the page darkens the letters.` : "Write the name future pages should use when they mean you kindly."}</p>
    `;
  } else if (page.onboardingStep === "belief") {
    html = `
      <label class="onboarding-field">
        <span>I believe...</span>
        <input type="text" data-onboard-input="belief" maxlength="90" autocomplete="off" value="${belief}" placeholder="in second chances, green places, showing up">
      </label>
      <div class="onboarding-actions">
        ${onboardingButton("plant-belief", "Plant 3 Belief", onboarding.plantedBelief === true)}
        ${onboardingButton("hold-belief", "Hold it for now", onboarding.plantedBelief === false)}
      </div>
      <p class="onboarding-result">${
        onboarding.plantedBelief === true
          ? "Glow wakes in the header. The Book is holding a little weight for this belief now."
          : onboarding.plantedBelief === false
            ? "The belief stays named. The Book respects a careful pocket."
            : "Name the belief, then decide whether to plant a little weight in it. Belief is what you give; Glow is what the Book shows."
      }</p>
    `;
  } else if (page.onboardingStep === "wicker") {
    const modeButtons = WICKER_MODES.map((item) =>
      onboardingButton(`wicker:${item.id}`, `<strong>${item.title}</strong><span>${item.detail}</span>`, onboarding.wickerMode === item.id, "mode")
    ).join("");
    const rollLine = roll && mode
      ? `${roll.total} vs ${mode.difficulty} - ${roll.succeeded ? mode.success : mode.failure}`
      : "Choose your answer, then roll Belief. Planted Belief gives the page a little more weight.";
    html = `
      <p class="onboarding-panel-title">Answer without letting him write you first</p>
      <div class="onboarding-mode-grid">${modeButtons}</div>
      <div class="onboarding-roll">
        ${onboardingButton("roll", roll ? "Roll again" : "Roll Belief", false, "roll")}
        <span>${escapeHTML(rollLine)}</span>
      </div>
      ${roll ? `<p class="onboarding-result">Raw ${roll.raw}${roll.bonus ? ` + ${roll.bonus} planted Belief` : ""}. ${roll.succeeded ? "Success." : "Complicated success. The Book still keeps the attempt."}</p>` : ""}
    `;
  } else if (page.onboardingStep === "first-page") {
    html = `
      <label class="onboarding-field">
        <span>If you keep it, write one true sentence</span>
        <input id="onboarding-first-sentence" type="text" data-onboard-input="firstSouvenir" maxlength="120" autocomplete="off" value="${firstSouvenir}" placeholder="The light in this room is doing something I almost missed.">
      </label>
      <p class="onboarding-result">${
        choices[index] === "keep"
          ? (onboarding.firstSouvenir ? "Kept. The archive has its first true edge." : "Write the sentence before keeping this page.")
          : choices[index] === "wait"
            ? "Good. Letting a weak page pass keeps the archive honest."
            : "Choose Keep or Let it wait below. Both are real answers."
      }</p>
    `;
  }

  onboardingPanel.innerHTML = html;
  return onboardingReady(page);
}

function resetOnboarding() {
  onboarding.fallChoice = "";
  onboarding.unwrittenTucked = false;
  onboarding.snack = "";
  onboarding.name = "";
  onboarding.belief = "";
  onboarding.plantedBelief = null;
  onboarding.wickerMode = "";
  onboarding.wickerRoll = null;
  onboarding.firstSouvenir = "";
}

let glow = 0;
const glowEarned = new Set();
let loreLinkClicks = 0;
let glowTarget = null;
let dialBlessed = false;

const GLOW_EFFECTS = {
  note: {
    title: "Margin Note",
    copy: "The Book notices what you notice. In the app, this is the seed of Belief: attention placed on a page, person, or pattern until it starts showing up more often.",
    target: ".hero-problem",
  },
  margins: {
    title: "Warm Margins",
    copy: "A warmer page edge means the Book is ready to annotate. Spend like this when you want the ordinary day to feel more legible.",
    target: "#book",
  },
  pages: {
    title: "Favored Pages",
    copy: "Page types with more Belief become more likely to matter. You're not buying content here; you're teaching the Book what kinds of noticing feel alive.",
    target: "#pages",
  },
  stacks: {
    title: "Stacks Whisper",
    copy: "Kept pages can be found again by mood, Glow tier, names, and little tags. The Stacks are the memory of what you chose to make real.",
    target: "#privacy",
  },
  bookmark: {
    title: "Bookmark Set",
    copy: "A bookmark is a promise to return. The Book treats return visits as meaning, not as a streak to defend.",
    target: "#how",
  },
  enchantment: {
    title: "Enchantment Waking",
    copy: "Spells turn attention into a playful lens: an object speaks, a photo changes register, a plain errand gets a little more myth in it.",
    target: "#mechanics",
  },
  compass: {
    title: "Compass Spark",
    copy: "Compass Runs are short noticing games: walk, look, sense, record, return. Their job is to make the familiar world readable again.",
    target: "#how",
  },
  dial: {
    title: "Blessed Dial",
    copy: "Belief just unlocked a hidden track on every station. Spin the cabinet to 88.3, 90.9, and 103.7 to hear all three - proof the Book turns attention into atmosphere you can keep.",
    target: "#radio",
  },
};

function glowName(score) {
  const scaled = Math.max(0, Math.min(100, score * 10));
  if (scaled < 10) return "Glow Barely There";
  if (scaled < 20) return "Meager Glow";
  if (scaled < 30) return "Faint Glow";
  if (scaled < 40) return "Small Glow";
  if (scaled < 50) return "Warming Glow";
  if (scaled < 60) return "Steady Glow";
  if (scaled < 70) return "Clear Glow";
  if (scaled < 80) return "Bright Glow";
  if (scaled < 90) return "Radiant Glow";
  return "Glow Too Full";
}

function glowStateText(score) {
  const scaled = Math.max(0, Math.min(100, score * 10));
  if (scaled < 20) return "The current belief state is shy, but listening.";
  if (scaled < 40) return "The current belief state is beginning to warm.";
  if (scaled < 60) return "The current belief state is steady and gently luminous.";
  if (scaled < 80) return "The current belief state is clear enough to light a path.";
  if (scaled < 90) return "The current belief state is bright and hard to ignore.";
  return "The current belief state is almost too full to hold.";
}

function updateGlowUI() {
  const capped = Math.min(12, glow);
  const name = glowName(glow);
  root.style.setProperty("--glow-progress", String(capped / 12));
  if (glowCount) glowCount.textContent = name;
  if (glowSheetTitle) glowSheetTitle.textContent = name;
  if (glowSheetTier) glowSheetTier.textContent = name;
  if (glowState) glowState.textContent = glowStateText(glow);
  glowFill?.style.setProperty("width", `${(capped / 12) * 100}%`);
  glowMenu?.querySelectorAll("[data-glow-cost]").forEach((button) => {
    const spent = button.dataset.glowEffect === "dial" && dialBlessed;
    button.disabled = spent || glow < Number(button.dataset.glowCost || 0);
  });
}

function earnGlow(key, amount = 1, message = "") {
  if (glowEarned.has(key)) return;
  glowEarned.add(key);
  glow += amount;
  updateGlowUI();
  if (message && glowSpendNote) glowSpendNote.textContent = message;
}

function spendGlow(button) {
  const cost = Number(button.dataset.glowCost || 0);
  const effect = button.dataset.glowEffect;
  if (effect === "dial" && dialBlessed) {
    if (glowSpendNote) glowSpendNote.textContent = "The dial is already blessed. Spin the cabinet to 88.3, 90.9, and 103.7 to hear each secret track.";
    return;
  }
  if (glow < cost) {
    if (glowSpendNote) glowSpendNote.textContent = `Needs ${cost} Belief. The Book is patient.`;
    return;
  }
  glow -= cost;
  applyGlowEffect(effect);
  updateGlowUI();
  if (glowSpendNote) glowSpendNote.textContent = button.dataset.glowReward || "The page warms and settles.";
}

const COMPASS_PROMPTS = [
  "Find the oldest thing near you and really look at it.",
  "Name one colour you can see in five different places.",
  "Notice the quietest sound in the room right now.",
  "Find something that was repaired instead of replaced.",
  "Catch the next thing that moves without being touched.",
  "Look for a small kindness already in progress nearby.",
];

function injectMarginNote() {
  const host = document.querySelector(".hero-copy");
  if (!host || host.querySelector(".glow-margin-note")) return;
  const belief = cleanOnboardingValue(onboarding.belief);
  const note = document.createElement("p");
  note.className = "glow-margin-note";
  note.innerHTML = belief
    ? `<span class="glow-margin-quill" aria-hidden="true">✒</span>The Book noted your belief in the margin - <em>“${escapeHTML(belief)}.”</em> It will start looking for it.`
    : `<span class="glow-margin-quill" aria-hidden="true">✒</span>The Book leaves a note in the margin: <em>keep what’s true; let the rest wait.</em>`;
  host.appendChild(note);
  requestAnimationFrame(() => note.classList.add("is-inked"));
}

function injectStacksIndex() {
  const host = document.querySelector("#privacy .privacy-copy");
  if (!host || host.querySelector(".glow-stacks-index")) return;
  const entries = document.querySelectorAll("#privacy .privacy-list li").length;
  const note = document.createElement("p");
  note.className = "glow-stacks-index";
  note.innerHTML = `<span aria-hidden="true">✦</span>Filed to the Stacks - ${entries} entries indexed by mood, name, and Glow tier. Kept pages answer when you call them.`;
  host.appendChild(note);
  requestAnimationFrame(() => note.classList.add("is-filed"));
}

function injectCompassPrompt() {
  const host = document.querySelector("#how");
  if (!host) return;
  let card = host.querySelector(".glow-compass-card");
  if (!card) {
    card = document.createElement("article");
    card.className = "glow-compass-card";
    card.innerHTML = `<span class="glow-compass-rose" aria-hidden="true">✦</span><div><p class="glow-compass-label">Compass Run · today’s noticing</p><p class="glow-compass-prompt"></p></div>`;
    host.appendChild(card);
  }
  card.querySelector(".glow-compass-prompt").textContent =
    COMPASS_PROMPTS[Math.floor(Math.random() * COMPASS_PROMPTS.length)];
  card.classList.remove("is-spinning");
  void card.offsetWidth; // restart the spin animation on every spark
  card.classList.add("is-spinning");
}

function applyGlowEffect(effect) {
  if (!effect) return;
  root.classList.add(`glow-effect-${effect}`);
  if (effect === "bookmark") root.style.setProperty("--bookmark-y", `${Math.max(14, Math.round(window.scrollY || 0))}px`);
  if (effect === "note") injectMarginNote();
  if (effect === "stacks") injectStacksIndex();
  if (effect === "compass") injectCompassPrompt();
  if (effect === "dial") {
    dialBlessed = true;
    if (typeof window.blessRadioDial === "function") window.blessRadioDial();
  }

  const reward = GLOW_EFFECTS[effect];
  if (reward && glowReveal && glowRevealTitle && glowRevealCopy) {
    glowReveal.hidden = false;
    glowRevealTitle.textContent = reward.title;
    glowRevealCopy.textContent = reward.copy;
  }

  if (glowTarget) glowTarget.classList.remove("glow-target");
  glowTarget = reward?.target ? document.querySelector(reward.target) : null;
  glowTarget?.classList.add("glow-target");

  // The menu is a full-screen overlay, so the transformation happens behind it.
  // Close it and bring the changed area into view so the spend actually pays off.
  closeGlowMenu();
  const scrollTargets = {
    note: ".hero-copy",
    pages: "#pages",
    stacks: "#privacy",
    enchantment: "#mechanics",
    compass: "#how",
    dial: "#radio",
  };
  const sel = scrollTargets[effect];
  if (sel) {
    const el = document.querySelector(sel);
    // On mobile these sections live in collapsed drawers - open the one we're
    // about to scroll to so the change is actually visible.
    const drawer = el?.closest("section[data-drawer]");
    if (drawer?.classList.contains("is-drawer") && !drawer.classList.contains("is-open")) {
      drawer.classList.add("is-open");
      drawer.querySelector(".drawer-toggle")?.setAttribute("aria-expanded", "true");
    }
    el?.scrollIntoView({ behavior: "smooth", block: "center" });
  } else {
    window.scrollTo({ top: 0, behavior: "smooth" }); // margins & bookmark read from the top
  }
}

function closeGlowMenu() {
  glowPill?.setAttribute("aria-expanded", "false");
  if (glowMenu) glowMenu.hidden = true;
}

glowPill?.addEventListener("click", () => {
  const open = glowPill.getAttribute("aria-expanded") !== "true";
  glowPill.setAttribute("aria-expanded", String(open));
  if (glowMenu) glowMenu.hidden = !open;
  earnGlow("opened-glow-menu", 1, "You found the Glow pocket. Obviously the Book counts that as Belief.");
});
glowMenu?.querySelectorAll(".glow-nav a").forEach((link) => {
  link.addEventListener("click", () => {
    closeGlowMenu();
  });
});
glowMenu?.querySelectorAll("[data-glow-cost]").forEach((button) => {
  button.addEventListener("click", () => spendGlow(button));
});
glowClose?.addEventListener("click", closeGlowMenu);
glowMenu?.addEventListener("click", (event) => {
  if (event.target === glowMenu) closeGlowMenu();
});
document.addEventListener("click", (event) => {
  if (!glowMenu || glowMenu.hidden || !glowPill) return;
  if (glowMenu.contains(event.target) || glowPill.contains(event.target)) return;
  closeGlowMenu();
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") closeGlowMenu();
});
updateGlowUI();

onboardingPanel?.addEventListener("input", (event) => {
  const key = event.target?.dataset?.onboardInput;
  if (!key || !(key in onboarding)) return;
  onboarding[key] = event.target.value;
  if (key === "belief" && cleanOnboardingValue(onboarding.belief)) {
    earnGlow("belief-named", 1, "A belief has been named. The header Glow wakes.");
  }
  updateOnboardingNav();
});

onboardingPanel?.addEventListener("click", (event) => {
  const button = event.target.closest("[data-onboard-action]");
  if (!button) return;
  const action = button.dataset.onboardAction;

  if (action?.startsWith("fall:")) {
    onboarding.fallChoice = action.split(":")[1] || "";
    hint.textContent = fallChoice()?.hint || "The fall has a shape now.";
  } else if (action === "unwritten") {
    onboarding.unwrittenTucked = true;
    hint.textContent = "The Great Unwritten is tucked into the margin.";
  } else if (action === "plant-belief") {
    if (!cleanOnboardingValue(onboarding.belief)) {
      onboardingPanel.querySelector("[data-onboard-input='belief']")?.focus();
      hint.textContent = "Name the belief first.";
      return;
    }
    onboarding.plantedBelief = true;
    earnGlow("belief-planted", 3, "Three Belief planted. Glow gathers where attention lands.");
    hint.textContent = "Belief planted. Wicker will have to deal with that.";
  } else if (action === "hold-belief") {
    if (!cleanOnboardingValue(onboarding.belief)) {
      onboardingPanel.querySelector("[data-onboard-input='belief']")?.focus();
      hint.textContent = "Name the belief first.";
      return;
    }
    onboarding.plantedBelief = false;
    hint.textContent = "Belief named and held for now.";
  } else if (action?.startsWith("wicker:")) {
    onboarding.wickerMode = action.split(":")[1] || "";
    onboarding.wickerRoll = null;
    hint.textContent = "Answer chosen. Roll Belief.";
  } else if (action === "roll") {
    const mode = wickerMode();
    if (!mode) {
      hint.textContent = "Choose how you answer Wicker first.";
      return;
    }
    const raw = Math.ceil(Math.random() * 100);
    const bonus = onboarding.plantedBelief ? 8 : 0;
    const total = raw + bonus;
    onboarding.wickerRoll = { raw, bonus, total, succeeded: total >= mode.difficulty };
    earnGlow("wicker-roll", 1, "Wicker forced a roll. The Book pays attention to pressure.");
    hint.textContent = onboarding.wickerRoll.succeeded ? "Wicker blinks first. Turn the page." : "The roll complicates things. The page still moves.";
  }

  render();
});

function isDecisionPage(page) {
  return page.decision !== false;
}

function keepablePageCount() {
  return PAGES.filter(isDecisionPage).length;
}

function renderSentencePolisher() {
  if (!sentencePolisher || !readerLineInput) return;
  sentencePolisher.hidden = !PAGES[index].sentencePrompt;
  readerLine = readerLineInput.value.trim();
}

function renderStacksRadio() {
  if (!stacksRadio) return;
  stacksRadio.hidden = !PAGES[index].radioPrompt;
}

function updateSearchPage(query = bookSearchInput?.value || DEFAULT_STACKS_QUERY, options = {}) {
  const matches = renderSemanticResults(bookSearchResults, query);
  const searchIndex = PAGES.findIndex((p) => p.searchPrompt);
  if (searchIndex >= 0) {
    const top = matches[0];
    PAGES[searchIndex].title = top ? `The Stacks found ${top.title}.` : "The Stacks are still looking.";
    PAGES[searchIndex].body = top
      ? `You asked: "${query}". The first shelf to answer was ${top.group.toLowerCase()}: ${top.text}`
      : `You asked: "${query}". The index is still reading the margins.`;
    PAGES[searchIndex].braid = top
      ? `A search for "${query}" opened ${top.title}, and the archive answered in plain language.`
      : `A search for "${query}" taught the Stacks a new shape to remember.`;
  }
  if (!options.quiet && PAGES[index]?.searchPrompt) {
    elTitle.textContent = PAGES[index].title;
    elBody.textContent = PAGES[index].body;
  }
}

function renderBookSearch() {
  if (!bookSearchDemo) return;
  bookSearchDemo.hidden = !PAGES[index].searchPrompt;
  if (PAGES[index].searchPrompt) {
    if (bookSearchInput && !bookSearchInput.value) bookSearchInput.value = DEFAULT_STACKS_QUERY;
    updateSearchPage(bookSearchInput?.value || DEFAULT_STACKS_QUERY, { quiet: true });
  }
}

document.querySelectorAll("[data-search-demo]").forEach((form) => {
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    const scope = form.dataset.searchDemo;
    const input = form.querySelector("input[type='search']");
    runSemanticSearch(scope, input?.value || DEFAULT_STACKS_QUERY);
  });
});

document.querySelectorAll(".semantic-search-suggestions").forEach((wrap) => {
  wrap.addEventListener("click", (event) => {
    const button = event.target.closest("[data-search-suggestion]");
    if (!button) return;
    const demo = button.closest(".semantic-search-demo");
    const form = demo?.querySelector("[data-search-demo]");
    const scope = form?.dataset.searchDemo || "section";
    runSemanticSearch(scope, button.textContent || button.dataset.searchSuggestion);
  });
});

document.querySelector("#section-search-input")?.addEventListener("input", (event) => {
  renderSemanticResults("#section-search-results", event.target.value || DEFAULT_STACKS_QUERY);
});

bookSearchInput?.addEventListener("input", () => updateSearchPage(bookSearchInput.value));
renderSemanticResults("#section-search-results", document.querySelector("#section-search-input")?.value || DEFAULT_STACKS_QUERY);

function renderCharacterChoices() {
  if (!characterChoices) return;
  characterChoices.hidden = !PAGES[index].characterPrompt;
  if (PAGES[index].characterPrompt && !selectedCharacterId) {
    selectCharacter(BOOK_CHARACTERS[0].id, { quiet: true });
  }
}

function renderEnchantmentLab() {
  if (!enchantmentLab) return;
  enchantmentLab.hidden = !PAGES[index].enchantmentPrompt;
  if (PAGES[index].enchantmentPrompt && !selectedEnchantmentId) {
    selectEnchantment(BOOK_ENCHANTMENTS[0].id, { quiet: true });
  }
}

function renderWonderChoices() {
  if (!wonderChoices) return;
  wonderChoices.hidden = !PAGES[index].wonderPrompt;
  if (PAGES[index].wonderPrompt && !selectedWonderChapterId) {
    selectWonderChapter(WONDER_CHAPTERS[0].id, { quiet: true });
  }
}

function renderFuelLog() {
  if (!fuelLog) return;
  fuelLog.hidden = !PAGES[index].fuelPrompt;
  if (PAGES[index].fuelPrompt) updateFuelLog({ quiet: true });
}

function renderInnerWeather() {
  if (!innerWeather) return;
  innerWeather.hidden = !PAGES[index].innerWeatherPrompt;
  if (PAGES[index].innerWeatherPrompt && !selectedInnerWeatherId) {
    selectInnerWeather(INNER_WEATHER_OPTIONS[0].id, { quiet: true });
  } else if (PAGES[index].innerWeatherPrompt) {
    updateInnerWeatherPage({ quiet: true });
  }
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
  const canAdvance = renderOnboardingPanel(p);

  const decisionPage = isDecisionPage(p);
  const choice = choices[index];
  screenWrap.classList.toggle("is-kept", choice === "keep");
  screenWrap.classList.toggle("is-onboarding", Boolean(p.onboardingStep));
  screenWrap.classList.toggle("is-character", Boolean(p.characterPrompt));
  screenWrap.classList.toggle("is-enchantment", Boolean(p.enchantmentPrompt));
  screenWrap.classList.toggle("is-wonder", Boolean(p.wonderPrompt));
  screenWrap.classList.toggle("is-fuel", Boolean(p.fuelPrompt));
  screenWrap.classList.toggle("is-inner-weather", Boolean(p.innerWeatherPrompt));
  btnKeep.classList.toggle("chosen", choice === "keep");
  btnWait.classList.toggle("chosen", choice === "wait");
  keepControls.hidden = !decisionPage;
  elStatus.hidden = !decisionPage;
  renderSentencePolisher();
  renderStacksRadio();
  renderBookSearch();
  renderStoryChoices();
  renderCharacterChoices();
  renderEnchantmentLab();
  renderWonderChoices();
  renderFuelLog();
  renderInnerWeather();

  navCount.textContent = `Page ${index + 1} of ${PAGES.length}`;
  btnPrev.disabled = index === 0;
  btnNext.disabled = !canAdvance;
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
  if (delta > 0 && !onboardingReady()) {
    hint.textContent = "Finish this page's small ritual first.";
    updateOnboardingNav();
    return;
  }
  const target = index + delta;
  if (target < 0) return;
  if (target >= PAGES.length) { showBraid(); return; }
  flip(delta > 0 ? "next" : "prev", () => { index = target; render(); });
}

function choose(kind) {
  if (!isDecisionPage(PAGES[index])) return;
  if (kind === "keep" && PAGES[index].sentencePrompt && readerLineInput && !readerLine) {
    readerLineInput.focus();
    hint.textContent = "Write one true sentence first - then keep it.";
    return;
  }
  if (kind === "keep" && PAGES[index].onboardingStep === "first-page" && !cleanOnboardingValue(onboarding.firstSouvenir)) {
    document.querySelector("#onboarding-first-sentence")?.focus();
    hint.textContent = "Write one true sentence first - then keep it.";
    return;
  }
  choices[index] = kind;
  if (kind === "keep") {
    const keptCount = choices.filter((choice) => choice === "keep").length;
    if (keptCount > 0 && keptCount % 3 === 0) {
      earnGlow(`kept-pages-${keptCount}`, 1, "Three kept pages gathered. The Book adds one Belief to your Glow.");
    } else if (glowSpendNote) {
      const left = 3 - (keptCount % 3);
      glowSpendNote.textContent = `${left} more kept page${left === 1 ? "" : "s"} and the Book adds Belief.`;
    }
  }
  render();
  // nudge the reader onward without hijacking navigation
  hint.textContent = index < PAGES.length - 1
    ? (kind === "keep" ? "Kept. Turn the page for the next one →" : "Set aside. Turn the page →")
    : "That's the last page - braid your book ✦";
}

function onboardingBraidLead() {
  const pieces = [];
  const fall = fallChoice();
  if (fall) pieces.push(`I entered the Book by the way ${fall.braid}`);
  const name = cleanOnboardingValue(onboarding.name);
  const snack = cleanOnboardingValue(onboarding.snack);
  const belief = cleanOnboardingValue(onboarding.belief);
  if (name) pieces.push(`Zara wrote my name as <em class="reader-own">${escapeHTML(name)}</em>`);
  if (snack) pieces.push(`she tucked <em class="reader-own">${escapeHTML(snack)}</em> into the margin`);
  if (belief) pieces.push(`my Belief pointed at <em class="reader-own">${escapeHTML(belief)}</em>`);
  if (onboarding.wickerRoll) {
    pieces.push(`Wicker tested it and the page rolled ${onboarding.wickerRoll.total}`);
  }
  if (!pieces.length) return "";
  return `${pieces.join("; ")}.`;
}

function openBook() {
  if (book.dataset.state !== "closed") return;
  book.dataset.state = "open";
  nav.hidden = false;
  index = 0;
  render();
  earnGlow("opened-book", 2, "The cover opened. Glow gathers at the hinge.");
  loadRealWeather(); // best-effort; the page already reads fine on the fallback
}

function closeBook() {
  resetRadio();
  book.dataset.state = "closed";
  nav.hidden = true;
  index = 0;
  btnNext.disabled = false;
  btnPrev.disabled = true;
  progressFill.style.width = "0%";
  applyDaypart();
  hint.textContent = "The book clicked shut. A bookmark inside whispers: try the big radio now.";
  earnGlow("closed-book", 3, "Closing the book without losing the thread makes the bookmark glow brighter.");
  book.scrollIntoView({ behavior: "smooth", block: "center" });
}

function buildBraid() {
  const keptIndices = PAGES.map((_, i) => i).filter((i) => choices[i] === "keep");
  const decisionIndices = PAGES.map((page, i) => isDecisionPage(page) ? i : -1).filter((i) => i >= 0);
  const sentencePageKept = keptIndices.some((i) => PAGES[i].sentencePrompt);
  const keptLines = keptIndices.map((i) => {
    if (PAGES[i].sentencePrompt && readerLine) {
      return `I wrote one true line and the ink kept its pulse: <em class="reader-own">${escapeHTML(readerLine)}</em>`;
    }
    if (PAGES[i].onboardingStep === "first-page" && onboarding.firstSouvenir) {
      return `The first practice page kept one true line: <em class="reader-own">${escapeHTML(onboarding.firstSouvenir)}</em>`;
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
  const tutorialLead = onboardingBraidLead();
  const lead = [tutorialLead, own].filter(Boolean).join("  ");
  const leadText = lead ? `${lead}  ` : "";
  const woven = keptLines.join("  ");
  const fuelKept = FUEL_INDEX >= 0 && choices[FUEL_INDEX] === "keep";
  const innerWeatherKept = INNER_WEATHER_INDEX >= 0 && choices[INNER_WEATHER_INDEX] === "keep";
  const innerWeatherLabel = INNER_WEATHER_OPTIONS.find((w) => w.id === selectedInnerWeatherId)?.label.toLowerCase() || "the inward sky";
  const supportGuildSurprise = fuelKept && innerWeatherKept
    ? `  Later, Dr. Vellum slid the plate note under Dr. Inkrest's weather glass: ${fuelEstimateLine || "warm fuel"} and ${innerWeatherLabel} fogged the same edge of the lens. Two dialects, one body speaking.`
    : "";

  if (keptLines.length === 0) {
    if (own) {
      braidIntro.textContent = "Only one true line - and the Book kept it anyway.";
      return `${leadText}Nothing else demanded binding today, and that's its own kind of honest month. The shelf is patient.`;
    }
    braidIntro.textContent = everyPageAnswered ? "You let every page wait." : "You kept no page before the binding.";
    return `${leadText}An honest month: nothing demanded to be kept, and the Book waited with you. The shelf is patient. Come back when something catches a real edge.`;
  }
  if (allKept) {
    braidIntro.textContent = "You kept everything. The Book has concerns. Affectionate ones.";
    return `${leadText}${woven}${supportGuildSurprise}  In the final margin, a small hand wrote in brown ink: sentimental, perhaps, but the shelf was warm where you touched it.`;
  }
  if (alternating) {
    braidIntro.textContent = "A Riddlewind pattern appeared between yes and not yet.";
    return `${leadText}${woven}  Every other door stayed shut; together, the open ones breathed keyhole-cold and spelled a question the Book wouldn't translate.`;
  }
  if (quietPagesOnly) {
    braidIntro.textContent = "The Book noticed what kind of pages you chose.";
    return `${leadText}${woven}  No spectacle asked to be remembered. The ordinary things pricked holes in the dark and made a small constellation anyway.`;
  }
  braidIntro.textContent = own
    ? `Braided from your own line and the ${keptLines.length} page${keptLines.length === 1 ? "" : "s"} you kept.`
    : `Braided from the ${keptLines.length} page${keptLines.length === 1 ? "" : "s"} you kept.`;
  // each kept line is already a complete sentence - weave them into one passage
  return `${leadText}${woven}${supportGuildSurprise}`;
}

/* ── the Book of You edition: theme, stats, and The Reader's Sky ── */
const PAGE_WORDS = [
  "Door",
  "Unwritten",
  "Snack",
  "Name",
  "Belief",
  "Wicker",
  "Sentence",
  "Weather",
  "Chart",
  "Music",
  "Archive",
  "Fuel",
  "Inner Weather",
  "Sentence",
  "Character",
  "Light",
  "Wonder",
  "Light",
];

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

/* ── keepsake: bind the whole demo into a downloadable PDF ── */
function plainText(value) {
  const div = document.createElement("div");
  div.innerHTML = String(value || "");
  return div.textContent || div.innerText || "";
}

function pdfClean(value) {
  return String(value || "")
    .replace(/[“”]/g, '"')
    .replace(/[‘’]/g, "'")
    .replace(/[-–]/g, "-")
    .replace(/·/g, "-")
    .replace(/✦/g, "*")
    .replace(/…/g, "...")
    .replace(/[^\x09\x0A\x0D\x20-\x7E]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function pdfEscape(value) {
  return pdfClean(value).replace(/\\/g, "\\\\").replace(/\(/g, "\\(").replace(/\)/g, "\\)");
}

function pdfWrap(text, maxChars) {
  const words = pdfClean(text).split(/\s+/).filter(Boolean);
  const lines = [];
  let line = "";
  words.forEach((word) => {
    const test = line ? `${line} ${word}` : word;
    if (test.length > maxChars && line) {
      lines.push(line);
      line = word;
    } else {
      line = test;
    }
  });
  if (line) lines.push(line);
  return lines;
}

function pageChoiceLabel(i) {
  if (!isDecisionPage(PAGES[i])) return "Shown";
  if (choices[i] === "keep") return "Kept";
  if (choices[i] === "wait") return "Let wait";
  return "Not answered";
}

function pageSummary(page, i) {
  if (page.sentencePrompt && readerLine) return `Reader line: ${readerLine}`;
  if (page.onboardingStep === "snack" && onboarding.snack) return `Reading snack: ${onboarding.snack}`;
  if (page.onboardingStep === "name" && onboarding.name) return `Reader name: ${onboarding.name}`;
  if (page.onboardingStep === "belief" && onboarding.belief) return `Belief: ${onboarding.belief}`;
  if (page.onboardingStep === "wicker" && onboarding.wickerRoll) return `Wicker roll: ${onboarding.wickerRoll.total} vs ${wickerMode()?.difficulty || "?"}`;
  if (page.onboardingStep === "first-page" && onboarding.firstSouvenir) return `First true sentence: ${onboarding.firstSouvenir}`;
  return plainText(page.bodyHTML || page.body || page.braid || `Page ${i + 1}`);
}

function pageBindingNote(page, i) {
  if (page.fuelPrompt) {
    return fuelEstimateLine
      ? `Vellum's margin keeps the estimate humane: ${fuelEstimateLine}. The numbers are present, but the binding treats them as pattern evidence, not judgment.`
      : "Vellum's margin is here to prove the care pages belong in the same book as the uncanny ones: food, rest, medicine, and ordinary upkeep can all become story material without becoming a score.";
  }
  if (page.innerWeatherPrompt) {
    const weather = INNER_WEATHER_OPTIONS.find((w) => w.id === selectedInnerWeatherId);
    return weather
      ? `Inkrest files ${weather.label.toLowerCase()} as weather, not identity. The binding keeps the feeling visible while leaving the reader room to move.`
      : "Inkrest's page keeps feeling as context. It gives the Book a gentler way to remember the day than triumph, failure, or blankness.";
  }
  if (page.sentencePrompt) {
    return "One exact sentence acts like a stitch: small enough to keep, specific enough to pull a whole day back through the binding.";
  }
  if (page.radioPrompt) {
    return "The chosen station colors the final voice of the book. Music is not decoration here; it is weather the archive can hear.";
  }
  if (page.searchPrompt) {
    return "Search proves the private archive is semantic, not merely sorted. The Book can retrieve a feeling, a half-image, or a thread the reader barely knows how to name.";
  }
  if (page.storyPrompt) {
    return "A choice page lets the reader shape the fiction and then carry that shape into the braid, so play leaves a visible thread.";
  }
  if (page.characterPrompt) {
    return "Cast pages give the archive social gravity. A person, rival, guide, or marginal voice can return later with memory attached.";
  }
  if (page.enchantmentPrompt) {
    return "The spell page turns one ordinary image into close reading. It shows how the app treats real life as inspectable, not replaceable.";
  }
  if (page.wonderPrompt) {
    return "The Compass page is the bridge back out of the screen: a short practice, a small errand, a reason to notice the real world again.";
  }
  if (page.onboardingStep) {
    return "This threshold beat teaches the Book one stable rule about the reader before the demo begins asking them to keep or release pages.";
  }
  if (i === WEATHER_INDEX) {
    return "The Weather Page grounds the fantasy in public conditions, letting the day's sky become a factual door into the story.";
  }
  return "This page contributes texture to the sample edition: a source, a choice state, and a thread the final braid can either carry or leave waiting.";
}

function bindingFolioGroups() {
  return [
    { title: "Threshold Folio", subtitle: "The Book learns how the reader arrived.", indices: [0, 1, 2] },
    { title: "Name, Belief, and the First Test", subtitle: "The demo's onboarding threads, condensed for binding.", indices: [3, 4, 5, 6] },
    { title: "Weather, Story, and Radio", subtitle: "World signals that can color a Book of You entry.", indices: [7, 8, 9] },
    { title: "Archive and Care Pages", subtitle: "Search, fuel, and inner weather kept on the same shelf.", indices: [10, 11, 12] },
    { title: "Personal Threads", subtitle: "A sentence, a cast member, and one enchanted image.", indices: [13, 14, 15] },
    { title: "Wonder and the Quiet Proof", subtitle: "The field guide and the ordinary scene it helps keep.", indices: [16, 17] },
  ].map((group) => ({
    ...group,
    indices: group.indices.filter((i) => PAGES[i]),
  })).filter((group) => group.indices.length);
}

function folioParagraphs(group) {
  return group.indices.flatMap((i) => {
    const page = PAGES[i];
    const choice = pageChoiceLabel(i);
    const threadLabel = choices[i] === "keep" ? "Thread braided" : "Thread available";
    return [
      `${i + 1}. ${page.kicker || page.title} - ${choice}`,
      `Opened from ${page.source || "the demo"}: ${pageSummary(page, i)}`,
      `Binding note: ${pageBindingNote(page, i)}`,
      `${threadLabel}: ${plainText(page.braid)}`,
    ];
  });
}

function bindingPages() {
  const data = lastEdition || editionData();
  const passage = pdfClean(braidText.textContent || plainText(buildBraid()));
  const my = monthYear();
  const place = [weatherCtx.city || "the Stacks", weatherCtx.cond].filter(Boolean).join(" - ");
  const kept = PAGES.map((_, i) => i).filter((i) => choices[i] === "keep");
  const answered = PAGES.map((_, i) => i).filter((i) => choices[i] === "keep" || choices[i] === "wait");
  const pages = [];

  pages.push({ kind: "cover", data, my, place });
  pages.push({
    title: "Foreword",
    subtitle: "A one-day sample binding",
    paragraphs: [
      "This little edition was bound from the interactive book demo: every page you opened, every page you kept, and every page you let wait.",
      "The real monthly binding gathers many days. This sample keeps the same promise in miniature: ordinary choices, given a cover, a contents page, and a final braid.",
      "Short practical pages are gathered into folios instead of left thin on the page. Fuel, inner weather, search, and sentence work now sit beside the larger story beats where their context can breathe."
    ],
  });
  pages.push({
    title: "Contents",
    subtitle: `${PAGES.length} pages offered - ${kept.length} kept - ${answered.length} answered`,
    paragraphs: [
      ...bindingFolioGroups().map((group) => {
        const range = `${group.indices[0] + 1}-${group.indices[group.indices.length - 1] + 1}`;
        return `${range}. ${group.title} - ${group.indices.length} demo page${group.indices.length === 1 ? "" : "s"}`;
      }),
      "Braid. The final passage printed in full",
      data.words.length ? "Reader's Sky. The noticed constellations" : "Reader's Sky. No constellations claimed this sample",
      "Colophon. Binding facts and imprint"
    ],
  });

  bindingFolioGroups().forEach((group) => {
    pages.push({
      title: group.title,
      subtitle: group.subtitle,
      paragraphs: folioParagraphs(group),
    });
  });

  pages.push({
    title: "The Braid",
    subtitle: braidIntro.textContent || "Braided from the pages you kept.",
    paragraphs: [passage],
  });

  if (data.words.length) {
    pages.push({
      title: "The Reader's Sky",
      subtitle: "Constellations the Book noticed in this sample.",
      paragraphs: [
        "These are not personality labels. They are the stars this small binding used to navigate: repeated textures, page-types, and kinds of attention that showed up while the reader turned the demo.",
        ...data.words.map((w) => `${w.label} - ${w.count} sighting${w.count === 1 ? "" : "s"}`),
        "In a real monthly edition, this sky grows stranger and more useful. Weather can lean toward music; fuel can sit beside rest; a sentence can become the hinge that explains why a whole week kept opening to the same question."
      ],
    });
  }

  pages.push({
    title: "Colophon",
    subtitle: "The Book of You",
    paragraphs: [
      `Bound as a demo PDF on ${new Date().toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" })}.`,
      `${data.keptCount} kept page${data.keptCount === 1 ? "" : "s"} - ${place || "weather default"} - ${data.theme}`,
      "The final braid is included here as the binding thread, not as an afterword. It is the passage the kept pages become when the Book stops sorting and starts remembering.",
      "A real month braids many days. This one kept the shape of a promise: every practical note, story choice, weather signal, and small true sentence can belong in the same volume."
    ],
  });
  return pages;
}

function createPdfDocument(pages) {
  const W = 612, H = 792;
  const objects = ["<< /Type /Catalog /Pages 2 0 R >>"];
  const pageKids = [];
  const fontObj = 3;
  objects.push(null); // pages tree placeholder
  objects.push("<< /Type /Font /Subtype /Type1 /BaseFont /Times-Roman >>");
  objects.push("<< /Type /Font /Subtype /Type1 /BaseFont /Times-Bold >>");
  objects.push("<< /Type /Font /Subtype /Type1 /BaseFont /Times-Italic >>");
  const fontDict = "<< /F1 3 0 R /F2 4 0 R /F3 5 0 R >>";

  function pushStream(commands) {
    const stream = commands.join("\n");
    objects.push(`<< /Length ${stream.length} >>\nstream\n${stream}\nendstream`);
    return objects.length;
  }
  function pushPage(streamId) {
    objects.push(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${W} ${H}] /Resources << /Font ${fontDict} >> /Contents ${streamId} 0 R >>`);
    const pageId = objects.length;
    pageKids.push(`${pageId} 0 R`);
  }
  function color(hex) {
    const n = hex.replace("#", "");
    return [0, 2, 4].map((i) => parseInt(n.slice(i, i + 2), 16) / 255).map((v) => v.toFixed(3)).join(" ");
  }
  function text(cmds, value, x, y, size = 12, font = "F1", fill = "#1f211b") {
    cmds.push("BT", `/${font} ${size} Tf`, `${color(fill)} rg`, `${x.toFixed(1)} ${y.toFixed(1)} Td`, `(${pdfEscape(value)}) Tj`, "ET");
  }
function center(cmds, value, y, size = 12, font = "F1", fill = "#1f211b") {
  const clean = pdfClean(value);
  const approx = clean.length * size * 0.5;
  text(cmds, clean, (W - approx) / 2, y, size, font, fill);
}
function centerWrapped(cmds, value, y, options = {}) {
  const size = options.size || 18;
  const font = options.font || "F1";
  const fill = options.fill || "#1f211b";
  const maxChars = options.maxChars || 34;
  const lineHeight = options.lineHeight || size + 7;
  const lines = pdfWrap(value, maxChars).slice(0, options.maxLines || 2);
  const startY = y + ((lines.length - 1) * lineHeight) / 2;
  lines.forEach((line, i) => center(cmds, line, startY - i * lineHeight, size, font, fill));
  return y - lines.length * lineHeight;
}
  function rule(cmds, y, fill = "#b89a46") {
    cmds.push(`${color(fill)} RG`, "0.8 w", `210 ${y} m 402 ${y} l S`);
  }
  function writeParagraphs(cmds, paragraphs, startY) {
    let y = startY;
    paragraphs.forEach((paragraph, idx) => {
      const isHeading = /^[0-9]+\.\s/.test(paragraph) || /^[A-Z][A-Za-z ]+$/.test(paragraph);
      const lines = pdfWrap(paragraph, isHeading ? 54 : 68);
      lines.forEach((line, lineIndex) => {
        if (y < 76) return;
        text(cmds, line, 102, y, isHeading && lineIndex === 0 ? 12 : 10.5, isHeading && lineIndex === 0 ? "F2" : "F1", "#20231d");
        y -= isHeading && lineIndex === 0 ? 16 : 14;
      });
      y -= idx === paragraphs.length - 1 ? 0 : 9;
    });
  }
  function composedPage(page, pageNo) {
    const cmds = [
      `${color("#f3ead6")} rg 0 0 ${W} ${H} re f`,
      `${color("#123421")} RG 1.2 w 54 48 ${W - 108} ${H - 96} re S`,
    ];
    text(cmds, `THE BOOK OF YOU - ${monthYear().toUpperCase()}`, 82, 720, 7.5, "F2", "#6c6b58");
    const afterTitle = centerWrapped(cmds, page.title, 664, { size: 24, font: "F2", fill: "#20231d", maxChars: 30, maxLines: 2, lineHeight: 29 });
    if (page.subtitle) centerWrapped(cmds, page.subtitle, afterTitle - 6, { size: 11, font: "F3", fill: "#6f6042", maxChars: 56, maxLines: 2, lineHeight: 14 });
    rule(cmds, 604);
    writeParagraphs(cmds, page.paragraphs || [], 572);
    center(cmds, String(pageNo), 34, 9, "F3", "#766e5b");
    return cmds;
  }
  function coverPage(page) {
    const cmds = [
      `${color("#0e2b1b")} rg 0 0 ${W} ${H} re f`,
      `${color("#173923")} rg 46 46 ${W - 92} ${H - 92} re f`,
      `${color("#c8a64c")} RG 2 w`,
      "245 536 m 245 622 367 622 367 536 c S",
      `${color("#dbe0ce")} rg 300 604 12 12 re f`,
      "303 588 6 18 re f",
    ];
    rule(cmds, 492);
    center(cmds, "THE BOOK OF YOU", 452, 13, "F2", "#dbe0ce");
    center(cmds, "a one-day sample", 426, 17, "F3", "#dbe0ce");
    center(cmds, "Chapter 1", 382, 42, "F2", "#eef0df");
    center(cmds, page.my, 344, 20, "F1", "#dbe0ce");
    centerWrapped(cmds, page.data.theme, 304, { size: 18, font: "F3", fill: "#c8a64c", maxChars: 34, maxLines: 2, lineHeight: 22 });
    rule(cmds, 268);
    center(cmds, `1 day bound - ${page.data.keptCount} kept page${page.data.keptCount === 1 ? "" : "s"}`, 102, 11, "F1", "#b8c0ae");
    center(cmds, "bound in the forest margin style", 82, 10, "F3", "#8fa08e");
    return cmds;
  }

  pages.forEach((page, i) => {
    const commands = page.kind === "cover" ? coverPage(page) : composedPage(page, i + 1);
    const streamId = pushStream(commands);
    pushPage(streamId);
  });
  objects[1] = `<< /Type /Pages /Kids [${pageKids.join(" ")}] /Count ${pageKids.length} >>`;

  let pdf = "%PDF-1.4\n";
  const offsets = [0];
  objects.forEach((obj, i) => {
    offsets.push(pdf.length);
    pdf += `${i + 1} 0 obj\n${obj}\nendobj\n`;
  });
  const xref = pdf.length;
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  offsets.slice(1).forEach((off) => { pdf += `${String(off).padStart(10, "0")} 00000 n \n`; });
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`;
  return new Blob([pdf], { type: "application/pdf" });
}

async function downloadKeepsake() {
  const blob = createPdfDocument(bindingPages());
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "book-of-you-demo-binding.pdf";
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 1500);
}

window.ReEnchantedBindingPDF = {
  createBlob() {
    return createPdfDocument(bindingPages());
  },
};

function backFromBraid() {
  book.dataset.state = "open";
  index = PAGES.length - 1;
  btnNext.disabled = false;
  render();
}

function replay() {
  choices.fill(null);
  resetOnboarding();
  readerLine = "";
  if (readerLineInput) readerLineInput.value = "";
  resetRadio();
  resetStory();
  resetCharacter();
  resetEnchantment();
  resetWonderChapter();
  resetFuelLog();
  resetInnerWeather();
  book.dataset.state = "open";
  index = 0;
  btnNext.disabled = false;
  hint.textContent = "Tip: keep a few, let some wait - your choices change the ending.";
  render();
  book.scrollIntoView({ behavior: "smooth", block: "center" });
}

/* ── daypart: tint the whole scene to the visitor's real hour ── */
const DAYPART = {
  dawn: { kicker: "The Stacks are waking", hint: "Morning in the Stacks - open the book and keep what's true." },
  day: { kicker: "The Book turns when you do", hint: "Tip: keep a few, let some wait - your choices change the ending." },
  dusk: { kicker: "The west windows go violet", hint: "Dusk in the Stacks - a good hour to keep what the day meant." },
  night: { kicker: "The Stacks are lit low", hint: "Read a few pages before sleep - the Book keeps what you keep." },
};
function currentDaypart(h = new Date().getHours()) {
  if (h < 5) return "night";
  if (h < 8) return "dawn";
  if (h < 17) return "day";
  if (h < 20) return "dusk";
  return "night";
}
function sunDaypart(now, sunrise, sunset) {
  const hour = 60 * 60 * 1000;
  if (!(now instanceof Date) || Number.isNaN(now.getTime())) return currentDaypart();
  if (!(sunrise instanceof Date) || Number.isNaN(sunrise.getTime())) return currentDaypart(now.getHours());
  if (!(sunset instanceof Date) || Number.isNaN(sunset.getTime())) return currentDaypart(now.getHours());

  const dawnStart = new Date(sunrise.getTime() - hour);
  const morningEnd = new Date(sunrise.getTime() + 2 * hour);
  const duskStart = new Date(sunset.getTime() - hour);
  const duskEnd = new Date(sunset.getTime() + hour);

  if (now < dawnStart) return "night";
  if (now < morningEnd) return "dawn";
  if (now < duskStart) return "day";
  if (now < duskEnd) return "dusk";
  return "night";
}
function applyDaypart(part = currentDaypart()) {
  root.dataset.daypart = part;
  const greeting = DAYPART[part];
  const coverKicker = document.querySelector(".cover-kicker");
  if (coverKicker) coverKicker.textContent = greeting.kicker;
  if (book.dataset.state === "closed" && hint) hint.textContent = greeting.hint;
}
async function loadLocationDaypart() {
  try {
    const geo = await fetch("https://ipwho.is/").then((r) => r.json());
    if (!geo || geo.success === false || typeof geo.latitude !== "number") return;
    const params = new URLSearchParams({
      latitude: geo.latitude,
      longitude: geo.longitude,
      current: "temperature_2m",
      daily: "sunrise,sunset",
      timezone: "auto",
    });
    const sky = await fetch(`https://api.open-meteo.com/v1/forecast?${params}`).then((r) => r.json());
    const now = new Date(sky?.current?.time);
    const sunrise = new Date(sky?.daily?.sunrise?.[0]);
    const sunset = new Date(sky?.daily?.sunset?.[0]);
    applyDaypart(sunDaypart(now, sunrise, sunset));
  } catch (_) {
    /* offline / blocked - the device-hour fallback has already set the mood */
  }
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
      place: `Read from ${city} · approximate, never stored - the same doorway the app uses`,
      city,
    };
    if (WEATHER_INDEX >= 0) {
      PAGES[WEATHER_INDEX].bodyHTML = weatherPageHTML(weatherCtx);
      PAGES[WEATHER_INDEX].braid = `The Weather Page opened on ${d.word} over ${city}; I kept the sky exactly as it stood.`;
      if (index === WEATHER_INDEX && book.dataset.state === "open") render();
    }
  } catch (_) {
    /* offline / blocked - the Stacks default already reads beautifully */
  }
}

/* ── the reader's own true line, on the One-Sentence Souvenir page ── */
if (readerLineInput) {
  readerLineInput.addEventListener("input", renderSentencePolisher);
}
/* ── One-Sentence Souvenir: ideas + sample lines to borrow ──
   The samples quietly model the craft - sensory, exact, synaesthetic, and a thing
   with a will of its own - without naming any of it. The rotating placeholder
   suggests what to write about. */
const SOUVENIR_SAMPLES = [
  "Rain ticked on the skylight while the kettle made its small argument.",
  "The cold tasted blue, and the streetlight hummed a colour I couldn't name.",
  "My old coat insisted on the long way home, and I let it.",
  "She folded the receipt like a secret, and I pretended not to see.",
];
const SOUVENIR_PROMPTS = [
  "What did today sound like?",
  "One exact colour or object?",
  "What did a feeling taste like?",
  "What did an object want?",
  "What did they leave behind?",
];
const souvenirSamplesWrap = document.querySelector("#souvenir-samples");

function buildSouvenirSamples() {
  if (!souvenirSamplesWrap || souvenirSamplesWrap.dataset.built) return;
  souvenirSamplesWrap.innerHTML = SOUVENIR_SAMPLES.map((s, i) =>
    `<button class="souvenir-sample" type="button" data-i="${i}">${escapeHTML(s)}</button>`).join("");
  souvenirSamplesWrap.dataset.built = "1";
  souvenirSamplesWrap.querySelectorAll(".souvenir-sample").forEach((btn) =>
    btn.addEventListener("click", () => {
      if (!readerLineInput) return;
      readerLineInput.value = SOUVENIR_SAMPLES[Number(btn.dataset.i)];
      renderSentencePolisher();
      readerLineInput.focus();
      hint.textContent = "Borrowed. Now bend it toward your real day, then keep it.";
    }));
}
buildSouvenirSamples();

let souvenirPromptIdx = 0;
function rotateSouvenirPrompt() {
  if (!readerLineInput || !sentencePolisher || sentencePolisher.hidden) return;
  if (readerLineInput.value) return; // don't fight a line the reader is writing
  souvenirPromptIdx = (souvenirPromptIdx + 1) % SOUVENIR_PROMPTS.length;
  readerLineInput.placeholder = SOUVENIR_PROMPTS[souvenirPromptIdx];
}
if (readerLineInput) {
  readerLineInput.placeholder = SOUVENIR_PROMPTS[0];
  setInterval(rotateSouvenirPrompt, 3600);
}

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
          setEmailStatus(status, "The shelf hiccuped - try again in a moment.", false);
        }
      } catch (_) {
        setEmailStatus(status, "The shelf hiccuped - try again in a moment.", false);
      } finally {
        btn.disabled = false;
        btn.textContent = label;
      }
    });
  });
}
wireEmailForms();

applyDaypart();
loadLocationDaypart();

cover.addEventListener("click", openBook);
btnKeep.addEventListener("click", () => choose("keep"));
btnWait.addEventListener("click", () => choose("wait"));
btnNext.addEventListener("click", () => { if (book.dataset.state === "open") go(1); });
btnPrev.addEventListener("click", () => {
  if (book.dataset.state === "braid") backFromBraid();
  else go(-1);
});
braidReplay.addEventListener("click", replay);
closeBookBtn?.addEventListener("click", closeBook);
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

/* ── ambient Stacks radio: pick a station, and keep the one you tuned to ──
   The reader chooses the station; whichever is selected colors the braid line
   the Radio page contributes if they keep it. Muted until a real tap.
   (Named BOOK_STATIONS to avoid clashing with the page's STATIONS registry.) */
const BOOK_STATIONS = [
  { id: "fae-fi", name: "Fae-Fi", introLabel: "Penny intro", track: "Folktronica", intro: "fae-fi-penny-intro-folktronica.m4a", src: "fae-fi-folktronica.m4a",
    braid: "Fae-Fi flickered through Penny's grin; folktronica put green sparks in the rafters and made the afternoon taste like clover soda." },
  { id: "mothlight", name: "Mothlight", introLabel: "Euphony ID", track: "Afternoon Chapters", intro: "mothlight-euphony-id-01.m4a", src: "mothlight-afternoon-chapters.m4a",
    braid: "Mothlight lowered its voice until the shelves breathed paper-dust and lavender; even the hinges turned pages more softly." },
  { id: "thornwave", name: "Thornwave", introLabel: "Wicker ID", track: "Magic Margins", intro: "thornwave-wicker-id-01.m4a", src: "thornwave-magic-margins.m4a",
    braid: "Wicker's Thornwave ID clicked like a black match; bass gathered under the floorboards and made doubt feel velvet-backed." },
];
const RADIO_INDEX = PAGES.findIndex((p) => p.radioPrompt);
const DEFAULT_RADIO_BRAID = RADIO_INDEX >= 0 ? PAGES[RADIO_INDEX].braid : "";
const radioAudio = document.querySelector("#radio-audio");
const radioStationsWrap = document.querySelector("#radio-stations");
const radioNow = document.querySelector("#radio-now");
let selectedStationId = null;
let radioOn = false;
let radioFade = null;
let radioPhase = "idle"; // idle | intro | track

function fadeRadio(target, done) {
  clearInterval(radioFade);
  radioFade = setInterval(() => {
    const v = radioAudio.volume;
    const next = v < target ? Math.min(target, v + 0.04) : Math.max(target, v - 0.05);
    radioAudio.volume = next;
    if (Math.abs(next - target) < 0.001) { clearInterval(radioFade); if (done) done(); }
  }, 80);
}

function updateRadioUI() {
  radioStationsWrap?.querySelectorAll(".radio-station").forEach((btn) => {
    const isSel = btn.dataset.station === selectedStationId;
    btn.classList.toggle("selected", isSel);
    btn.classList.toggle("on", isSel && radioOn);
    btn.setAttribute("aria-pressed", isSel && radioOn ? "true" : "false");
  });
  stacksRadio?.classList.toggle("playing", radioOn);
  if (!radioNow) return;
  const st = BOOK_STATIONS.find((s) => s.id === selectedStationId);
  if (radioOn && st && radioPhase === "intro") radioNow.textContent = `DJ bit · ${st.name}`;
  else if (radioOn && st) radioNow.textContent = `Playing · ${st.name} - ${st.track}`;
  else if (st) radioNow.textContent = `Kept · ${st.name} - paused`;
  else radioNow.textContent = "Nothing playing yet - tap a station.";
}

function stopRadio() {
  radioOn = false;
  radioPhase = "idle";
  fadeRadio(0, () => radioAudio.pause());
  updateRadioUI();
}

async function playStationTrack(st, options = {}) {
  if (!st || !radioAudio) return;
  radioPhase = "track";
  radioAudio.loop = true;
  if (!options.keepSource) radioAudio.src = "./assets/audio/" + st.src;
  else radioAudio.currentTime = 0;
  radioAudio.volume = options.fadeIn ? 0 : radioAudio.volume;
  try { await radioAudio.play(); } catch (_) { updateRadioUI(); return; }
  radioOn = true;
  if (options.fadeIn) fadeRadio(0.32);
  updateRadioUI();
}

async function selectStation(id) {
  const st = BOOK_STATIONS.find((s) => s.id === id);
  if (!st || !radioAudio) return;
  if (selectedStationId === id && radioOn) { stopRadio(); return; } // tap the playing one to pause
  selectedStationId = id;
  earnGlow(`book-radio-${id}`, 2, `${st.name} tuned. The dial pays in shimmer.`);
  if (RADIO_INDEX >= 0) PAGES[RADIO_INDEX].braid = st.braid; // the chosen station shapes the binding
  radioPhase = "intro";
  radioAudio.loop = false;
  radioAudio.src = "./assets/audio/" + (st.intro || st.src);
  radioAudio.volume = 0;
  try { await radioAudio.play(); } catch (_) { updateRadioUI(); return; } // blocked → keep choice, stay quiet
  radioOn = true;
  fadeRadio(0.32);
  updateRadioUI();
}

radioAudio?.addEventListener("ended", () => {
  const st = BOOK_STATIONS.find((s) => s.id === selectedStationId);
  if (!st || !radioOn || radioPhase !== "intro") return;
  if (st.intro === st.src) {
    playStationTrack(st, { keepSource: true, fadeIn: false });
  } else {
    playStationTrack(st, { fadeIn: false });
  }
});

function resetRadio() {
  clearInterval(radioFade);
  radioFade = null;
  radioOn = false;
  radioPhase = "idle";
  if (radioAudio) {
    radioAudio.pause();
    radioAudio.currentTime = 0;
    radioAudio.loop = false;
  }
  selectedStationId = null;
  if (RADIO_INDEX >= 0) PAGES[RADIO_INDEX].braid = DEFAULT_RADIO_BRAID;
  updateRadioUI();
}

function buildStationButtons() {
  if (!radioStationsWrap || radioStationsWrap.dataset.built) return;
  radioStationsWrap.innerHTML = BOOK_STATIONS.map((s) =>
    `<button class="radio-station" type="button" data-station="${s.id}" aria-pressed="false">
       <span class="radio-station-name">${s.name}</span>
       <span class="radio-station-track">${s.introLabel} → ${s.track}</span>
     </button>`).join("");
  radioStationsWrap.dataset.built = "1";
  radioStationsWrap.querySelectorAll(".radio-station").forEach((btn) =>
    btn.addEventListener("click", () => selectStation(btn.dataset.station)));
}
buildStationButtons();

/* ── Fuel Log: a tiny static version of Vellum's nutrition lookup. The app can
   use USDA FoodData; the demo keeps a local pocket table so the page works here. */
const FUEL_INDEX = PAGES.findIndex((p) => p.fuelPrompt);
const DEFAULT_FUEL_PAGE = FUEL_INDEX >= 0
  ? {
      title: PAGES[FUEL_INDEX].title,
      body: PAGES[FUEL_INDEX].body,
      source: PAGES[FUEL_INDEX].source,
      shot: PAGES[FUEL_INDEX].shot,
      braid: PAGES[FUEL_INDEX].braid,
    }
  : null;
const FUEL_SAMPLES = [
  "two eggs, toast with butter, coffee",
  "oatmeal, banana, peanut butter",
  "lentil soup, rice, tea",
];
const FUEL_LOOKUP = [
  { match: ["egg", "eggs"], kcal: 72, protein: 6, carbs: 0, fat: 5 },
  { match: ["toast"], kcal: 95, protein: 3, carbs: 18, fat: 1 },
  { match: ["butter"], kcal: 102, protein: 0, carbs: 0, fat: 12 },
  { match: ["coffee"], kcal: 2, protein: 0, carbs: 0, fat: 0 },
  { match: ["oatmeal", "oats"], kcal: 154, protein: 6, carbs: 27, fat: 3 },
  { match: ["banana"], kcal: 105, protein: 1, carbs: 27, fat: 0 },
  { match: ["peanut butter"], kcal: 188, protein: 8, carbs: 7, fat: 16 },
  { match: ["lentil soup", "lentils"], kcal: 230, protein: 16, carbs: 40, fat: 1 },
  { match: ["rice"], kcal: 205, protein: 4, carbs: 45, fat: 0 },
  { match: ["tea"], kcal: 2, protein: 0, carbs: 0, fat: 0 },
];
let fuelText = "";
let fuelEstimateLine = "";

function estimateFuel(text) {
  const lower = String(text || "").toLowerCase();
  const total = { kcal: 0, protein: 0, carbs: 0, fat: 0, matched: [] };
  FUEL_LOOKUP.forEach((item) => {
    const hit = item.match.find((m) => lower.includes(m));
    if (!hit) return;
    const qtyMatch = lower.match(new RegExp(`(?:two|three|four|2|3|4)\\s+${hit.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`));
    const qtyWord = qtyMatch?.[0]?.split(/\s+/)[0];
    const qty = qtyWord === "two" || qtyWord === "2" ? 2 : qtyWord === "three" || qtyWord === "3" ? 3 : qtyWord === "four" || qtyWord === "4" ? 4 : 1;
    total.kcal += item.kcal * qty;
    total.protein += item.protein * qty;
    total.carbs += item.carbs * qty;
    total.fat += item.fat * qty;
    total.matched.push(hit);
  });
  if (!total.matched.length) return null;
  return {
    ...total,
    line: `~${Math.round(total.kcal)} kcal · P ${Math.round(total.protein)}g · C ${Math.round(total.carbs)}g · F ${Math.round(total.fat)}g`,
  };
}

function updateFuelLog(options = {}) {
  if (!fuelInput || FUEL_INDEX < 0) return;
  fuelText = fuelInput.value.trim();
  const estimate = estimateFuel(fuelText);
  fuelEstimateLine = estimate?.line || "";
  const page = PAGES[FUEL_INDEX];
  if (fuelText && estimate) {
    page.title = "Vellum pencils in the numbers.";
    page.body = `${fuelText}. ${estimate.line} (Vellum's rough arithmetic). Dr. Vellum calls this a body clue, not a moral score.`;
    page.braid = `Dr. Vellum logged ${fuelText}; ${estimate.line} cooled in cranberry ink beside the plate, useful and deliberately toothless.`;
    fuelReading.innerHTML = `<span class="fuel-reading-label">Vellum's assistant</span><p>${escapeHTML(estimate.line)} <em>(rough lookup)</em></p><p class="vellum-note">Dr. Vellum: "Useful enough to notice patterns. Never sharp enough to shame you."</p>`;
  } else if (fuelText) {
    page.title = "Vellum keeps the plate note.";
    page.body = `${fuelText}. The demo lookup didn't recognize enough ingredients, but the real app can use a broader nutrition source when configured.`;
    page.braid = `Dr. Vellum kept the plate note "${fuelText}" unnumbered; the margin accepted it warm, without asking it to become a spreadsheet.`;
    fuelReading.innerHTML = `<span class="fuel-reading-label">Vellum's assistant</span><p>No demo match yet. The note still counts.</p><p class="vellum-note">Dr. Vellum: "Absence of arithmetic isn't absence of care."</p>`;
  } else {
    if (DEFAULT_FUEL_PAGE) Object.assign(page, DEFAULT_FUEL_PAGE);
    fuelReading.innerHTML = `<span class="fuel-reading-label">Vellum's assistant</span><p>Try a plate note, or borrow one below.</p><p class="vellum-note">Dr. Vellum: "Plain language first. Numbers may follow politely."</p>`;
  }
  if (index === FUEL_INDEX) {
    elTitle.textContent = page.title;
    elBody.textContent = page.body;
    elSource.textContent = page.source;
    elShot.src = page.shot;
  }
  if (!options.quiet && fuelText) hint.textContent = "Fuel note filed - keep it to let Vellum compare patterns later.";
}

function resetFuelLog() {
  fuelText = "";
  fuelEstimateLine = "";
  if (fuelInput) fuelInput.value = "";
  if (DEFAULT_FUEL_PAGE && FUEL_INDEX >= 0) Object.assign(PAGES[FUEL_INDEX], DEFAULT_FUEL_PAGE);
  if (fuelReading) fuelReading.innerHTML = "";
}

function buildFuelSamples() {
  if (!fuelSamplesWrap || fuelSamplesWrap.dataset.built) return;
  fuelSamplesWrap.innerHTML = FUEL_SAMPLES.map((sample) =>
    `<button class="fuel-sample" type="button" data-fuel="${escapeHTML(sample)}">${escapeHTML(sample)}</button>`).join("");
  fuelSamplesWrap.dataset.built = "1";
  fuelSamplesWrap.querySelectorAll(".fuel-sample").forEach((btn) =>
    btn.addEventListener("click", () => {
      if (!fuelInput) return;
      fuelInput.value = btn.dataset.fuel || "";
      updateFuelLog();
    }));
  fuelInput?.addEventListener("input", () => updateFuelLog());
}
buildFuelSamples();

/* ── Inner Weather: Inkrest names weather as context, not identity. */
const INNER_WEATHER_INDEX = PAGES.findIndex((p) => p.innerWeatherPrompt);
const DEFAULT_INNER_WEATHER_PAGE = INNER_WEATHER_INDEX >= 0
  ? {
      title: PAGES[INNER_WEATHER_INDEX].title,
      body: PAGES[INNER_WEATHER_INDEX].body,
      source: PAGES[INNER_WEATHER_INDEX].source,
      shot: PAGES[INNER_WEATHER_INDEX].shot,
      braid: PAGES[INNER_WEATHER_INDEX].braid,
    }
  : null;
const INNER_WEATHER_OPTIONS = [
  { id: "fog", label: "Fog", tag: "soft edges", braid: "fog put felt on the edges of the next step and made distance look closer than it was" },
  { id: "rain", label: "Rain", tag: "needed release", braid: "rain gave the pressure a gutter to sing through" },
  { id: "static", label: "Static", tag: "too many signals", braid: "static filled the wires with tin-bright teeth, but one true word still got through" },
  { id: "sunbreak", label: "Sunbreak", tag: "small clearing", braid: "a sunbreak opened for one minute, warm as brass, and the Book believed it" },
];
let selectedInnerWeatherId = null;
let innerWeatherDetail = "";

function updateInnerWeatherUI() {
  innerWeatherOptionsWrap?.querySelectorAll(".inner-weather-option").forEach((btn) => {
    const isSel = btn.dataset.weather === selectedInnerWeatherId;
    btn.classList.toggle("selected", isSel);
    btn.setAttribute("aria-pressed", isSel ? "true" : "false");
  });
}

function updateInnerWeatherPage(options = {}) {
  if (INNER_WEATHER_INDEX < 0) return;
  const weather = INNER_WEATHER_OPTIONS.find((w) => w.id === selectedInnerWeatherId) || INNER_WEATHER_OPTIONS[0];
  innerWeatherDetail = innerWeatherInput?.value.trim() || "";
  const cleanDetail = innerWeatherDetail.replace(/^(because|since)\s+/i, "").replace(/[.!?]$/, "");
  const page = PAGES[INNER_WEATHER_INDEX];
  page.title = `${weather.label} in the inward sky.`;
  page.body = innerWeatherDetail
    ? `Inner weather: ${weather.label.toLowerCase()}. Private detail: ${cleanDetail}. Dr. Inkrest keeps the weather separate from the self, which is how a person gets room to move.`
    : `Inner weather: ${weather.label.toLowerCase()}. Dr. Inkrest keeps the weather separate from the self, which is how a person gets room to move.`;
  page.braid = innerWeatherDetail
    ? `I named ${weather.label.toLowerCase()} inside because ${cleanDetail}; the Book pinned it to the sky, not to my skin.`
    : `I named the inward sky: ${weather.braid}.`;
  if (innerWeatherReading) {
    innerWeatherReading.innerHTML = `<span class="inner-weather-reading-label">Inkrest's margin</span><p>${escapeHTML(weather.label)} is a condition, not a character flaw.</p>`;
  }
  if (index === INNER_WEATHER_INDEX) {
    elTitle.textContent = page.title;
    elBody.textContent = page.body;
    elSource.textContent = page.source;
    elShot.src = page.shot;
  }
  if (!options.quiet) hint.textContent = `${weather.label} named - keep this page to braid the weather honestly.`;
}

function selectInnerWeather(id, options = {}) {
  selectedInnerWeatherId = id;
  updateInnerWeatherUI();
  updateInnerWeatherPage(options);
}

function resetInnerWeather() {
  selectedInnerWeatherId = null;
  innerWeatherDetail = "";
  if (innerWeatherInput) innerWeatherInput.value = "";
  if (DEFAULT_INNER_WEATHER_PAGE && INNER_WEATHER_INDEX >= 0) Object.assign(PAGES[INNER_WEATHER_INDEX], DEFAULT_INNER_WEATHER_PAGE);
  updateInnerWeatherUI();
  if (innerWeatherReading) innerWeatherReading.innerHTML = "";
}

function buildInnerWeatherOptions() {
  if (!innerWeatherOptionsWrap || innerWeatherOptionsWrap.dataset.built) return;
  innerWeatherOptionsWrap.innerHTML = INNER_WEATHER_OPTIONS.map((w) =>
    `<button class="inner-weather-option" type="button" data-weather="${w.id}" aria-pressed="false">
       <span class="inner-weather-name">${escapeHTML(w.label)}</span>
       <span class="inner-weather-tag">${escapeHTML(w.tag)}</span>
     </button>`).join("");
  innerWeatherOptionsWrap.dataset.built = "1";
  innerWeatherOptionsWrap.querySelectorAll(".inner-weather-option").forEach((btn) =>
    btn.addEventListener("click", () => selectInnerWeather(btn.dataset.weather)));
  innerWeatherInput?.addEventListener("input", () => updateInnerWeatherPage({ quiet: true }));
}
buildInnerWeatherOptions();

/* ── Story Page choices: the chosen form colors the braid line, the way the
   app's Story Pages let Slice of Life / Arc / Surprise make a different future true. */
const BOOK_STORY_CHOICES = [
  { id: "slice", label: "Examine the paper's texture", form: "Slice of Life",
    braid: "I held the brittle chart close enough to feel its grain; the day's whole plot was hiding in the rough place under my thumb." },
  { id: "arc", label: "Align the chart", form: "Arc",
    braid: "I aligned the chart with its shadow, and the day bent like a wet branch toward the ending it had been practicing." },
  { id: "surprise", label: "Listen to the silence", form: "Surprise",
    braid: "I listened to the silence around the chart; it clicked its small teeth together and turned the page before I touched it." },
];
const STORY_INDEX = PAGES.findIndex((p) => p.storyPrompt);
const DEFAULT_STORY_BRAID = STORY_INDEX >= 0 ? PAGES[STORY_INDEX].braid : "";
const storyChoices = document.querySelector("#story-choices");
const storyOptionsWrap = document.querySelector("#story-options");
let selectedStoryId = null;

function updateStoryUI() {
  storyOptionsWrap?.querySelectorAll(".story-option").forEach((btn) => {
    const isSel = btn.dataset.story === selectedStoryId;
    btn.classList.toggle("selected", isSel);
    btn.setAttribute("aria-pressed", isSel ? "true" : "false");
  });
}

function selectStory(id) {
  const choice = BOOK_STORY_CHOICES.find((c) => c.id === id);
  if (!choice) return;
  selectedStoryId = id;
  if (STORY_INDEX >= 0) PAGES[STORY_INDEX].braid = choice.braid; // the chosen form shapes the binding
  updateStoryUI();
  hint.textContent = `${choice.form} chosen - keep this page to braid that future in.`;
}

function resetStory() {
  selectedStoryId = null;
  if (STORY_INDEX >= 0) PAGES[STORY_INDEX].braid = DEFAULT_STORY_BRAID;
  updateStoryUI();
}

function buildStoryOptions() {
  if (!storyOptionsWrap || storyOptionsWrap.dataset.built) return;
  storyOptionsWrap.innerHTML = BOOK_STORY_CHOICES.map((c) =>
    `<button class="story-option" type="button" data-story="${c.id}" aria-pressed="false">
       <span class="story-option-label">${c.label}</span>
       <span class="story-option-form">${c.form}</span>
     </button>`).join("");
  storyOptionsWrap.dataset.built = "1";
  storyOptionsWrap.querySelectorAll(".story-option").forEach((btn) =>
    btn.addEventListener("click", () => selectStory(btn.dataset.story)));
}
buildStoryOptions();

function renderStoryChoices() {
  if (!storyChoices) return;
  storyChoices.hidden = !PAGES[index].storyPrompt;
}

/* ── Character Page choices: the chosen person changes the illustration screen
   and the line that enters the reader's binding. */
const BOOK_CHARACTERS = [
  {
    id: "zara-finch",
    name: "Zara Finch",
    tag: "Riddlewind guide",
    title: "Zara Finch, pressed and filed.",
    body: "Zara notices exits before introductions and calls it being prepared. She is loyal enough to find the path that holds, and wary enough to check whether it will hold twice.",
    source: "Riddlewind guide · hidden alcoves",
    shot: "./assets/screens/character-zara-finch.png",
    card: "First friend, house guide, and practical magic in a satchel. Her flaw is mistaking vigilance for care; her gift is coming back anyway.",
    braid: "Zara Finch joined the cast with sea-glass at her throat; the hidden alcove held its breath while she found the stair everyone else missed.",
  },
  {
    id: "lysander-mosswood",
    name: "Lysander Mosswood",
    tag: "Mossbloom naturalist",
    title: "What the ink knows of Lysander Mosswood.",
    body: "Lysander answers with a route before an explanation. He keeps pressed leaves as field punctuation and believes a path becomes magical when walked attentively.",
    source: "Mossbloom field notes · Compass Runs",
    shot: "./assets/screens/character-lysander-mosswood.png",
    card: "Thoughtful, trail-minded, and quietly stubborn about slow wonder. His weakness is making stillness sound easier than it is.",
    braid: "Lysander Mosswood joined the cast by pressing an alder leaf into the margin; the path smelled of moss and old rain, and it waited for slower feet.",
  },
  {
    id: "wicker-eddies",
    name: "Wicker Eddies",
    tag: "Duskthorn · Thornwave DJ",
    title: "What the ink knows of Wicker Eddies.",
    body: "Wicker DJs Thornwave on the Academy dial, where doubt gets a bassline. He punctures false magic for sport, and sometimes wounds the thing he meant to test.",
    source: "Duskthorn index · 103.7 Thornwave",
    shot: "./assets/screens/character-wicker-eddies.png",
    card: "Sharp, funny, dangerously persuasive. He thinks belief should survive contact with doubt, preferably while he is smiling.",
    braid: "Wicker Eddies joined the cast through a wrong-door key and a Thornwave bassline; he smiled while the page flinched, then made every bright claim prove it could survive him.",
  },
  {
    id: "marginalia-goblin",
    name: "Marginalia Goblin",
    tag: "Book Fae · margins",
    title: "Small and entirely necessary: Marginalia Goblin.",
    body: "Marginalia Goblin lives where the page almost stops looking. It files ridiculous evidence, prices attention like currency, and points at the corner your eyes kept sliding past.",
    source: "Book Fae dossier · overlooked evidence",
    shot: "./assets/screens/character-marginalia-goblin.png",
    card: "A mercantile little witness to the unchosen detail: the gap between what a thing is called and what it is.",
    braid: "A Marginalia Goblin joined the cast from the page-corner and offered the Unspoken Pen; the bargain price was three seconds of attention paid to the thing I kept almost noticing.",
  },
];
const CHARACTER_INDEX = PAGES.findIndex((p) => p.characterPrompt);
const DEFAULT_CHARACTER_PAGE = CHARACTER_INDEX >= 0
  ? {
      title: PAGES[CHARACTER_INDEX].title,
      body: PAGES[CHARACTER_INDEX].body,
      source: PAGES[CHARACTER_INDEX].source,
      shot: PAGES[CHARACTER_INDEX].shot,
      braid: PAGES[CHARACTER_INDEX].braid,
    }
  : null;
let selectedCharacterId = null;

function updateCharacterUI() {
  characterOptionsWrap?.querySelectorAll(".character-option").forEach((btn) => {
    const isSel = btn.dataset.character === selectedCharacterId;
    btn.classList.toggle("selected", isSel);
    btn.setAttribute("aria-pressed", isSel ? "true" : "false");
  });
}

function applyCharacter(character) {
  if (!character || CHARACTER_INDEX < 0) return;
  const page = PAGES[CHARACTER_INDEX];
  page.title = character.title;
  page.body = character.body;
  page.source = character.source;
  page.shot = character.shot;
  page.braid = character.braid;
  if (index === CHARACTER_INDEX) {
    elTitle.textContent = character.title;
    elBody.textContent = character.body;
    elSource.textContent = character.source;
    elShot.src = character.shot;
  }
}

function selectCharacter(id, options = {}) {
  const character = BOOK_CHARACTERS.find((c) => c.id === id);
  if (!character) return;
  selectedCharacterId = id;
  applyCharacter(character);
  updateCharacterUI();
  if (!options.quiet) hint.textContent = `${character.name} chosen - keep this page to bind their thread in.`;
}

function resetCharacter() {
  selectedCharacterId = null;
  if (DEFAULT_CHARACTER_PAGE && CHARACTER_INDEX >= 0) Object.assign(PAGES[CHARACTER_INDEX], DEFAULT_CHARACTER_PAGE);
  updateCharacterUI();
}

function buildCharacterOptions() {
  if (!characterOptionsWrap || characterOptionsWrap.dataset.built) return;
  characterOptionsWrap.innerHTML = BOOK_CHARACTERS.map((c) =>
    `<button class="character-option" type="button" data-character="${c.id}" aria-pressed="false">
       <span class="character-option-name">${escapeHTML(c.name)}</span>
       <span class="character-option-tag">${escapeHTML(c.tag)}</span>
       <span class="character-option-copy">${escapeHTML(c.card)}</span>
     </button>`).join("");
  characterOptionsWrap.dataset.built = "1";
  characterOptionsWrap.querySelectorAll(".character-option").forEach((btn) =>
    btn.addEventListener("click", () => selectCharacter(btn.dataset.character)));
}
buildCharacterOptions();

/* ── Enchantment Page: a free, browser-local version of the photo spell system.
   The real app can use richer image understanding; this demo still honors the
   central rule by deriving its reading from visible color, light, and texture. */
const BOOK_ENCHANTMENTS = [
  {
    id: "everything-speaks",
    name: "Everything Speaks",
    tag: "Object voice",
    source: "Enchantment · Everything Speaks",
    title: "Let the image answer.",
    card: "The subject speaks back in the first person, but only from what the picture gives it.",
    braid: "Everything Speaks let the ordinary subject answer back because I finally looked.",
  },
  {
    id: "everything-is-magic",
    name: "Everything's Magic",
    tag: "Correspondences",
    source: "Enchantment · Everything's Magic",
    title: "Read the correspondences.",
    card: "The image becomes practical magic: omens, elements, folk correspondences, and what the rite is for.",
    braid: "Everything's Magic turned the image into a spellbook entry, components and side effects included.",
  },
  {
    id: "everything-is-connected",
    name: "Everything's Connected",
    tag: "Thread finder",
    source: "Enchantment · Everything's Connected",
    title: "Find the larger threads.",
    card: "The spell reads the cultural signal: what this image has learned to mean, and what it's trying not to say.",
    braid: "Everything's Connected found the larger threads tied to the subject I brought.",
  },
];

const ENCHANTMENT_SAMPLES = [
  {
    id: "rabbit",
    label: "Rabbit counsel",
    src: "./assets/screens/enchantment-rabbit.jpeg",
    subject: "the rabbit tucked against a face",
    body: "A rabbit leans into a cheek, all warm fur, glasses, blanket, and the serious privacy of being trusted by something small.",
    readings: {
      "everything-speaks": "\"Yes, I know I'm soft. That isn't my whole profession. I'm here to inspect your breathing, approve one cheek, and remind you that trust is a very bossy kind of love.\"",
      "everything-is-magic": "<strong>Working:</strong> Hearth familiar blessing for gentleness, fertility of attention, and nervous-system repair.<br><strong>Correspondences:</strong> rabbit for abundance and quick intuition; fur for comfort magic; cheek-touch for consent and kinship; gray blanket for lunar shelter; glasses for clear seeing.<br><strong>Element:</strong> Earth held close by Water.<br><strong>Use:</strong> Hold near the heart when you need proof that softness can still be protective.",
      "everything-is-connected": "<strong>What media says:</strong> rabbits carry springtime, vulnerability, luck, speed, fertility, and the old storybook promise that small creatures know secret paths.<br><strong>Unspoken connection:</strong> this photo isn't saying \"cute pet\" so much as \"I'm trusted by something fragile, therefore I must be gentle with myself too.\"",
    },
    braids: {
      "everything-speaks": "The rabbit spoke first, warm-nosed and imperious: breathe softer; I'm conducting the room.",
      "everything-is-magic": "The rabbit became a hearth familiar in gray blanket-moonlight, abundance tucked against a cheek like a living charm.",
      "everything-is-connected": "The rabbit photo carried spring, luck, and small trust; beneath the cuteness, it whispered that gentleness was a form of guardianship.",
    },
  },
  {
    id: "camper",
    label: "Tiny kitchen",
    src: "./assets/screens/enchantment-camper.jpeg",
    subject: "the red and yellow camper kitchen",
    body: "A little kitchen is bright with red walls, yellow panels, flowers, plants, pillows, a sink, and a shining water filter that looks almost ceremonial.",
    readings: {
      "everything-speaks": "\"Don't call me cluttered. I'm compact abundance. I know where the towels live, where the water waits, where the flowers are showing off, and which corner still owes someone a cup of tea.\"",
      "everything-is-magic": "<strong>Working:</strong> Road-hearth charm for provision, cleansing, and cheerful resilience in a small vessel.<br><strong>Correspondences:</strong> red for life-force and protection; yellow for solar luck; sink for purification; flowers for Venusian sweetness; hanging tools for readiness; polished water filter for blessing and flow.<br><strong>Element:</strong> Fire braided with Water.<br><strong>Use:</strong> Consecrate before travel, cooking, or any day that asks a small space to hold a whole life.",
      "everything-is-connected": "<strong>What media says:</strong> tiny homes, van-life kitchens, and bright domestic corners promise freedom without rootlessness: the fantasy of having only what matters, arranged within reach.<br><strong>Unspoken connection:</strong> this image is trying to say \"I can be mobile and still be nourished. I can leave without becoming untethered.\"",
    },
    braids: {
      "everything-speaks": "The tiny kitchen objected to being called clutter; its red walls snapped like flags while the flowers kept inventory.",
      "everything-is-magic": "The camper kitchen turned road-hearth: red for protection, yellow for luck, water shining like a blessing with a spigot.",
      "everything-is-connected": "The tiny kitchen carried the whole van-life promise in one crowded breath: leave, yes, but take nourishment with you.",
    },
  },
  {
    id: "harbor",
    label: "Harbor sky",
    src: "./assets/screens/enchantment-harbor.jpeg",
    subject: "the person stretching toward the sunset harbor",
    body: "A person stands on a dock with arms lifted toward storm clouds, peach light, dark water, boats, and a bridge holding the horizon together.",
    readings: {
      "everything-speaks": "\"I'm not posing; I'm receiving. The clouds came loud, the water copied them, and I lifted my hands because some doors are opened by answering weather with a body.\"",
      "everything-is-magic": "<strong>Working:</strong> Threshold rite for release, weather-listening, and calling courage across water.<br><strong>Correspondences:</strong> sunset for liminal change; storm clouds for charged transformation; harbor water for emotional passage; dock for boundary work; bridge for crossing; raised arms for invocation.<br><strong>Element:</strong> Water crowned by Air and Fire.<br><strong>Use:</strong> Face west at dusk, name what's leaving, then let the horizon carry the rest.",
      "everything-is-connected": "<strong>What media says:</strong> sunset-at-the-water images mean revelation, travel, grief, victory, proposal, vacation, main-character renewal, and the feeling that a life can turn cinematic for one minute.<br><strong>Unspoken connection:</strong> this photo is trying to say \"I'm still here, and the world is large enough to meet me back.\"",
    },
    braids: {
      "everything-speaks": "The harbor sky answered the lifted hands in peach and thunder; the water repeated it until the dock believed.",
      "everything-is-magic": "The harbor became a threshold rite: storm-cloud air, sunset fire, dock wood, and raised arms calling courage across water.",
      "everything-is-connected": "The harbor photo knew every cinematic sunset trick, but underneath it said: I'm still here, and the world is large enough to answer.",
    },
  },
];

const ENCHANTMENT_INDEX = PAGES.findIndex((p) => p.enchantmentPrompt);
const DEFAULT_ENCHANTMENT_PAGE = ENCHANTMENT_INDEX >= 0
  ? {
      title: PAGES[ENCHANTMENT_INDEX].title,
      body: PAGES[ENCHANTMENT_INDEX].body,
      source: PAGES[ENCHANTMENT_INDEX].source,
      shot: PAGES[ENCHANTMENT_INDEX].shot,
      braid: PAGES[ENCHANTMENT_INDEX].braid,
    }
  : null;
let selectedEnchantmentId = null;
let selectedEnchantmentImage = ENCHANTMENT_SAMPLES[0];

function updateEnchantmentButtons() {
  enchantmentSpellsWrap?.querySelectorAll(".enchantment-spell").forEach((btn) => {
    const isSel = btn.dataset.enchantment === selectedEnchantmentId;
    btn.classList.toggle("selected", isSel);
    btn.setAttribute("aria-pressed", isSel ? "true" : "false");
  });
  enchantmentSamplesWrap?.querySelectorAll(".enchantment-sample").forEach((btn) => {
    const isSel = btn.dataset.sample === selectedEnchantmentImage?.id;
    btn.classList.toggle("selected", isSel);
    btn.setAttribute("aria-pressed", isSel ? "true" : "false");
  });
}

function enchantmentText(spell, image) {
  return image?.readings?.[spell.id] || "The spell found the image, then waited for a truer sentence.";
}

function applyEnchantmentPage(spell, image, readingHTML) {
  if (!spell || ENCHANTMENT_INDEX < 0) return;
  const page = PAGES[ENCHANTMENT_INDEX];
  page.title = spell.title;
  page.body = `${spell.name} reads ${image.subject}. ${image.body}`;
  page.source = spell.source;
  page.shot = image?.src || page.shot;
  page.braid = image?.braids?.[spell.id] || spell.braid;
  if (index === ENCHANTMENT_INDEX) {
    elTitle.textContent = page.title;
    elBody.textContent = page.body;
    elSource.textContent = page.source;
    elShot.src = page.shot;
    if (enchantmentReading) {
      enchantmentReading.innerHTML = `<span class="enchantment-reading-label">The spell reads:</span><p>${readingHTML}</p>`;
    }
  }
}

function refreshEnchantmentReading() {
  const spell = BOOK_ENCHANTMENTS.find((s) => s.id === selectedEnchantmentId) || BOOK_ENCHANTMENTS[0];
  const image = selectedEnchantmentImage || ENCHANTMENT_SAMPLES[0];
  applyEnchantmentPage(spell, image, enchantmentText(spell, image));
}

function selectEnchantment(id, options = {}) {
  const spell = BOOK_ENCHANTMENTS.find((s) => s.id === id);
  if (!spell) return;
  selectedEnchantmentId = id;
  updateEnchantmentButtons();
  refreshEnchantmentReading(options);
  if (!options.quiet) hint.textContent = `${spell.name} chosen - keep this page to braid that spell in.`;
}

function selectEnchantmentSample(id) {
  const sample = ENCHANTMENT_SAMPLES.find((s) => s.id === id);
  if (!sample) return;
  selectedEnchantmentImage = sample;
  updateEnchantmentButtons();
  refreshEnchantmentReading();
}

function resetEnchantment() {
  selectedEnchantmentId = null;
  selectedEnchantmentImage = ENCHANTMENT_SAMPLES[0];
  if (DEFAULT_ENCHANTMENT_PAGE && ENCHANTMENT_INDEX >= 0) Object.assign(PAGES[ENCHANTMENT_INDEX], DEFAULT_ENCHANTMENT_PAGE);
  updateEnchantmentButtons();
}

function buildEnchantmentLab() {
  if (!enchantmentLab || enchantmentLab.dataset.built) return;
  if (enchantmentSpellsWrap) {
    enchantmentSpellsWrap.innerHTML = BOOK_ENCHANTMENTS.map((spell) =>
      `<button class="enchantment-spell" type="button" data-enchantment="${spell.id}" aria-pressed="false">
         <span class="enchantment-spell-name">${escapeHTML(spell.name)}</span>
         <span class="enchantment-spell-tag">${escapeHTML(spell.tag)}</span>
         <span class="enchantment-spell-copy">${escapeHTML(spell.card)}</span>
       </button>`).join("");
    enchantmentSpellsWrap.querySelectorAll(".enchantment-spell").forEach((btn) =>
      btn.addEventListener("click", () => selectEnchantment(btn.dataset.enchantment)));
  }
  if (enchantmentSamplesWrap) {
    enchantmentSamplesWrap.innerHTML = ENCHANTMENT_SAMPLES.map((sample) =>
      `<button class="enchantment-sample" type="button" data-sample="${sample.id}" aria-pressed="false">
         ${escapeHTML(sample.label)}
       </button>`).join("");
    enchantmentSamplesWrap.querySelectorAll(".enchantment-sample").forEach((btn) =>
      btn.addEventListener("click", () => selectEnchantmentSample(btn.dataset.sample)));
  }
  enchantmentLab.dataset.built = "1";
  updateEnchantmentButtons();
}
buildEnchantmentLab();

/* ── Wonder Compass chapters: the chosen field-guide chapter changes the page
   and the thread that enters the final Book of You binding. */
const WONDER_CHAPTERS = [
  {
    id: "core-compass",
    name: "Chapter 5",
    title: "The Wonder Compass",
    tag: "Notice · Embark · Sense · Write · Rest",
    pageTitle: "Run the Compass once.",
    body: "This is the core loop, and I keep it small on purpose: notice one spark, embark across one tiny threshold, let your body sense the moment, write a single sentence, then rest at the center. A run this small, you can't wave away as nothing.",
    source: "Wonder Compass · Chapter 5",
    shot: "./assets/screens/wonder-chapters-core.png",
    card: "A low-stakes adventure small enough to do today, but specific enough that the day can't stay wallpaper.",
    braid: "I ran the Compass once: one spark, one threshold, one body-note, one sentence; Rest sat in the center like a warm stone.",
  },
  {
    id: "characters",
    name: "Chapter 8B",
    title: "Characters",
    tag: "Make the world answer back",
    pageTitle: "Let the room join the cast.",
    body: "Here I ask you to let objects and rooms join the cast - the kettle with opinions, the hallway in a mood, the desk that knows exactly what you're avoiding. Greet them, and the ordinary world starts answering back.",
    source: "Wonder Compass · Chapter 8B",
    shot: "./assets/screens/wonder-chapters-rest.png",
    card: "A practice for loneliness, decision fatigue, and boring tasks: make the inanimate world collaborative again.",
    braid: "I gave the ordinary world a cast list, and the kettle, hallway, and desk began clearing their throats.",
  },
  {
    id: "center-rest",
    name: "Chapter 10",
    title: "Center = Rest",
    tag: "The permission to stop",
    pageTitle: "Let rest be the center.",
    body: "I put rest at the center, where it belongs - not the opposite of the practice but its still point. Stop before collapse stops you for you, and let the day settle what it has been carrying.",
    source: "Wonder Compass · Chapter 10",
    shot: "./assets/screens/wonder-chapters-rest.png",
    card: "A sixty-second reset to re-magnetize the inner needle and prevent wonder from becoming another chore.",
    braid: "I let Rest stand at the center of the Compass; the day loosened its belt and stopped pretending exhaustion was a door.",
  },
];

const WONDER_INDEX = PAGES.findIndex((p) => p.wonderPrompt);
const DEFAULT_WONDER_PAGE = WONDER_INDEX >= 0
  ? {
      title: PAGES[WONDER_INDEX].title,
      body: PAGES[WONDER_INDEX].body,
      source: PAGES[WONDER_INDEX].source,
      shot: PAGES[WONDER_INDEX].shot,
      braid: PAGES[WONDER_INDEX].braid,
    }
  : null;
let selectedWonderChapterId = null;

function updateWonderUI() {
  wonderOptionsWrap?.querySelectorAll(".wonder-option").forEach((btn) => {
    const isSel = btn.dataset.wonder === selectedWonderChapterId;
    btn.classList.toggle("selected", isSel);
    btn.setAttribute("aria-pressed", isSel ? "true" : "false");
  });
}

function applyWonderChapter(chapter) {
  if (!chapter || WONDER_INDEX < 0) return;
  const page = PAGES[WONDER_INDEX];
  page.source = chapter.source;
  page.shot = chapter.shot;
  page.braid = chapter.braid;
  if (index === WONDER_INDEX) {
    elSource.textContent = page.source;
    elShot.src = page.shot;
  }
}

function selectWonderChapter(id, options = {}) {
  const chapter = WONDER_CHAPTERS.find((c) => c.id === id);
  if (!chapter) return;
  selectedWonderChapterId = id;
  applyWonderChapter(chapter);
  updateWonderUI();
  if (!options.quiet) hint.textContent = `${chapter.title} chosen - keep this page to braid that practice in.`;
}

function resetWonderChapter() {
  selectedWonderChapterId = null;
  if (DEFAULT_WONDER_PAGE && WONDER_INDEX >= 0) Object.assign(PAGES[WONDER_INDEX], DEFAULT_WONDER_PAGE);
  updateWonderUI();
}

function buildWonderOptions() {
  if (!wonderOptionsWrap || wonderOptionsWrap.dataset.built) return;
  wonderOptionsWrap.innerHTML = WONDER_CHAPTERS.map((chapter) =>
    `<button class="wonder-option" type="button" data-wonder="${chapter.id}" aria-pressed="false">
       <span class="wonder-option-name">${escapeHTML(chapter.name)}: ${escapeHTML(chapter.title)}</span>
       <span class="wonder-option-tag">${escapeHTML(chapter.tag)}</span>
       <span class="wonder-option-copy">${escapeHTML(chapter.card)}</span>
     </button>`).join("");
  wonderOptionsWrap.dataset.built = "1";
  wonderOptionsWrap.querySelectorAll(".wonder-option").forEach((btn) =>
    btn.addEventListener("click", () => selectWonderChapter(btn.dataset.wonder)));
}
buildWonderOptions();

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
      if (next > 0) earnGlow(`chapter-belief-${key}-${next}`, 1, `${binding.name} warmed the header Glow.`);
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
      { id: "fae-fi-crushed-pixies", title: "Crushed Pixies", artist: "Fae-Fi", src: "./assets/audio/fae-fi-crushed-pixies.m4a" },
      { id: "fae-fi-fae-fi", title: "Fae Fi", artist: "Fae-Fi", src: "./assets/audio/fae-fi-fae-fi.m4a" },
      { id: "fae-fi-mossy-groove", title: "Mossy Groove", artist: "Fae-Fi", src: "./assets/audio/fae-fi-mossy-groove.m4a" },
      { id: "fae-fi-to-the-adventure", title: "To the Adventure", artist: "Fae-Fi", blessed: true, blessedSrc: "./assets/audio/fae-fi-to-the-adventure.m4a" },
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
        caption: "That was Mossy Footsteps. There was no one there. There's never anyone there. I've started a folder." },
      { id: "faefi-intro-folktronica", category: "transition", track: "Folktronica", placement: "intro",
        src: "./assets/audio/fae-fi-penny-intro-folktronica.m4a",
        caption: "Coming up - Folktronica. A bird wrote the hook. The bird has filed a complaint. We're all very busy here." },
      { id: "faefi-outro-mossygroove", category: "transition", track: "Mossy Groove", placement: "outro",
        src: "./assets/audio/fae-fi-penny-outro-mossygroove.m4a",
        caption: "You just heard Mossy Groove. A patch of clover is dancing and won't stop, and I've regrettably transcribed all of it." },
      { id: "faefi-sponsor-thistledown", category: "sponsor", src: "./assets/audio/fae-fi-penny-sponsor-thistledown.m4a",
        caption: "Fae-Fi runs on dandelion synths and Thistledown & Co., purveyors of pocket-sized weather. Caught in the grey? A Thistledown sunbeam fits in any coat. That part, I checked. It's true." },
      { id: "faefi-sponsor-cloverhoney", category: "sponsor", src: "./assets/audio/fae-fi-penny-sponsor-clover-honey.m4a",
        conditions: { timeOfDay: ["dawn", "day"] },
        caption: "Today's brightness is brought to you by the Clover Honey Collective. Their slogan arrived far too polished, so I rewrote it: the afternoon's only as warm as you bothered to taste. It does hum. I've got the recording." },
      { id: "faefi-gossip-tuesday", category: "gossip", src: "./assets/audio/fae-fi-penny-gossip-tuesday.m4a",
        conditions: { weekdays: [2] },
        caption: "Somebody traded a perfectly good Tuesday for one more loop of this song. Filed under evidence the music is working. Flawless decision. No notes." },
      { id: "faefi-gossip-window", category: "gossip", src: "./assets/audio/fae-fi-penny-gossip-window.m4a",
        caption: "From my desk at The Bleed: the Wonder Compass has pointed at the same window all week. If it's your window, that's a fact you've been avoiding. Go see." },
      { id: "faefi-news-grey", category: "news", src: "./assets/audio/fae-fi-penny-news-grey.m4a",
        caption: "Filed this morning, off Today's Sky: the grey lost three feet of ground. Somebody noticed one true particular and wrote it down. That's the whole arithmetic of this place." },
      { id: "faefi-news-festival", category: "news", src: "./assets/audio/fae-fi-penny-news-festival.m4a",
        caption: "Festival weather incoming. I'll be in the corner, cataloguing joy as it happens, which is, I'm told, not the point of joy. Bring a souvenir." },
      { id: "faefi-network-band", category: "network", src: "./assets/audio/fae-fi-penny-network-band.m4a",
        caption: "For the record, the whole dial, filed in order: eighty-eight three, me, against my will. Ninety point nine, Euphony at Mothlight. One-oh-three seven, Wicker on Thornwave. And if you can hear Villanelle's Bindery at ninety-nine three, or Melisande's Market at one-oh-five one, you've gone properly nocturnal. Spin the dial. Somebody's playing your weather." },
      { id: "faefi-psa-timetable", category: "news", src: "./assets/audio/fae-fi-psa-timetable.m4a",
        caption: "Public notice from the records desk, since someone has to keep it straight. The Academy runs on bells: morning classes at nine, afternoon classes at one, and clubs gather at seven, lamps up. Five days of classes, a Saturday field run, and a Sunday that opens in another book entirely. It's all chalked on the board by the Inkworks. I keep the master copy. Naturally." },
      { id: "faefi-psa-curriculum", category: "news", src: "./assets/audio/fae-fi-psa-curriculum.m4a",
        caption: "For new readers wondering what's actually taught here: the whole curriculum is one compass. North is Notice - Boggle's Art of the Glint, finding the one odd detail. East is Embark - Momort's Wayfinding, crossing a small threshold on purpose. South is Sense - Euphony's Synesthetic Resonance, reading a room through the body. West is Write - Villanelle's Ink-Binding, one true sentence that keeps. And the Center is Rest - Stonebrook's Quiet Hours. Not a direction. The ground the other four stand on. Filed, cross-referenced, and only mildly poetic." },
      { id: "faefi-psa-week-grid", category: "news", src: "./assets/audio/fae-fi-psa-week-grid.m4a",
        caption: "The week, for the record, as briefly as I can manage. Mondays: the Glint, then Ink-Binding. Tuesdays: Wayfinding, then Resonance. Wednesdays: the Glint again, then Quiet Hours. Thursdays: Wayfinding, then Ink-Binding. Fridays: Resonance, then Basic Enchantments. Saturdays we run the full Compass in the field. Sundays open in the Vault of Doors, with Book Jumping. Clubs after dark. Don't make me repeat it - I'll only be more accurate." },
      { id: "faefi-psa-clubs", category: "news", src: "./assets/audio/fae-fi-psa-clubs.m4a",
        conditions: { timeOfDay: ["dusk", "night"] },
        caption: "Evening notice: the clubs are gathering - seven bells, lamps up. The Compass Society reads souvenirs aloud in the Secret Garden, where no one mocks a sentence. The Marginalia Guild annotates in the Corridor of Whispered Secrets, leaving notes for readers fifty years out. The Inkwright Society writes, shares, and burns it. And the Book Jumpers argue about what counts as a door. Find the room that fits your week. Tell them the records desk sent you." },
      { id: "faefi-psa-bleed-editions", category: "news", src: "./assets/audio/fae-fi-psa-bleed-editions.m4a",
        caption: "Reminder from your editor, which is me: The Bleed runs two editions. The Morning paper lands before one bell - weather, the day's hinges, what the Book noticed overnight, and a column off one of your own shelves. The Evening edition sets after four - tomorrow's shape, tonight's margins, a fresh column. The quiet afternoon between them belongs to you. That part's intentional. Read both. There may be a quiz. There won't be. But there could be." },
      { id: "faefi-psa-office-hours", category: "news", src: "./assets/audio/fae-fi-psa-office-hours.m4a",
        caption: "A notice I file gladly: the support faculty keep their doors open. Dr. Inkrest holds office hours for difficult pages - no appointment, just a chair, a lamp, and the time to name a hard thing slowly. Dr. Vellum takes the body's evidence - fuel, rest, recovery - and turns it into one small experiment with no shame attached. Neither will rush you. It's almost unnerving. If the day's gone heavy, that's what the doors are for." },
      { id: "faefi-psa-todays-sky", category: "news", src: "./assets/audio/fae-fi-psa-todays-sky.m4a",
        caption: "Daily service note: Today's Sky posts each morning - the moon's phase and sign, the weather drawing in, and the nearest thing the heavens are up to. It's the one forecast that reads the inner weather as much as the outer. I check it before I file anything. The sky, annoyingly, is usually right." },
      { id: "faefi-psa-festivals-wheel", category: "news", src: "./assets/audio/fae-fi-psa-festivals-wheel.m4a",
        caption: "Since readers keep asking what we celebrate: the Academy keeps the eight feasts of the Wheel. Imbolc, the First Stir, when the dark first turns. Ostara and Mabon, the two Rebalancings at the equinoxes. Beltane's Greenfire and Litha's Longest Day in the bright half. Lughnasadh, the First Harvest. And in the dark half - Samhain, the Thinning, and Yule, the Darkest Class, taught by candlelight. Eight feasts, one turning year. I keep the calendar. The calendar, for once, keeps itself." },
      { id: "faefi-psa-moons-showers", category: "news", src: "./assets/audio/fae-fi-psa-moons-showers.m4a",
        caption: "Also on the calendar, for the record: the moons and the falling stars. Every Full Moon is a Luminous Gathering - classes cancelled after sunset, everyone out reading by moonlight. Every New Moon, the Quiet Hours: candles only, the words holding their breath. And twice a year the ceiling goes clear for the meteors - the Perseids in August, the Falling Letters; the Geminids in December, the Winter Stars, when hot chocolate turns up in your hands unasked. I've not determined who delivers it. The investigation remains open." },
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
      { id: "mothlight-porchlight-fading", title: "Porchlight, Fading", artist: "Mothlight Beats", blessed: true, blessedSrc: "./assets/audio/mothlight-porchlight-fading.m4a" },
    ],
    banters: [
      { id: "mothlight-id-01", category: "stationID", src: "./assets/audio/mothlight-euphony-id-01.m4a",
        caption: "…there. Now the room's in tune. This is Mothlight Beats, ninety point nine - Professor Euphony, holding the lamp for the ache of lovely things ending." },
      { id: "mothlight-id-02", category: "stationID", src: "./assets/audio/mothlight-euphony-id-02.m4a",
        caption: "You're listening in the key of dusk. Mothlight, ninety point nine on the Academy band. I hear what you walked in carrying. We'll set it to music and it'll weigh less." },
      { id: "mothlight-id-03", category: "stationID", src: "./assets/audio/mothlight-euphony-id-03.m4a",
        caption: "Mothlight Beats. The static remembers being a summer you lost - listen, it's a minor seventh. Stay in it with me a while." },
      { id: "mothlight-outro-the-page-came-through", category: "transition", track: "The Page Came Through", placement: "outro",
        src: "./assets/audio/mothlight-euphony-outro-the-page-came-through.m4a",
        caption: "That was “The Page Came Through”… they always do, in the end. The ones you thought were gone. Here's something to let settle on you." },
      { id: "mothlight-outro-fae-dust", category: "transition", track: "Fae Dust", placement: "outro",
        src: "./assets/audio/mothlight-euphony-outro-fae-dust.m4a",
        caption: "“Fae Dust,” just then - yes, that itch behind your eyes is on purpose. Breathe. Mothlight has you." },
      { id: "mothlight-sponsor-porchlight-moth", category: "sponsor",
        src: "./assets/audio/mothlight-euphony-sponsor-porchlight-moth.m4a",
        caption: "Mothlight glows by the grace of Porchlight & Moth, keepers of the lamp left on - for everyone you're still waiting up for. Find them at dusk, where the diary opens." },
      { id: "mothlight-sponsor-the-remembering", category: "sponsor",
        src: "./assets/audio/mothlight-euphony-sponsor-the-remembering.m4a",
        caption: "Tonight's hush is held by The Remembering, a small shop in the Book Remembered. Bring them a page you thought you'd lost. They'll coax it back into the light - no charge." },
      { id: "mothlight-gossip-inner-weather", category: "gossip",
        src: "./assets/audio/mothlight-euphony-gossip-inner-weather.m4a",
        caption: "Penny files The Bleed dry, so let me sing it: somebody's inner weather finally broke into rain. Where you come from, that's not a storm - that's how the garden gets watered. If it's you, it's allowed." },
      { id: "mothlight-gossip-inkrest-lamp", category: "gossip",
        src: "./assets/audio/mothlight-euphony-gossip-inkrest-lamp.m4a",
        caption: "A note carried in on the dusk: Dr. Inkrest left her office lamp on past hours again. If the day sat heavy as a low note, her door is the kind that opens. No appointment. Just weather, and a chair, and a lamp." },
      { id: "mothlight-class-resonance", category: "news",
        src: "./assets/audio/mothlight-euphony-class-resonance.m4a",
        caption: "Come to the Resonance Chamber some afternoon - Wing Three, where I ring a single glass bell and dim one lamp, and the whole room changes color without a wall ever moving. That's Synesthetic Resonance. The South direction. Sense. We practice hearing a colour, then naming the real evidence underneath it. The senses are serious instruments, you know. Bring yours. They're already tuned - you've only stopped listening." },
      { id: "mothlight-class-quiet-hours", category: "gossip",
        src: "./assets/audio/mothlight-euphony-class-quiet-hours.m4a",
        conditions: { timeOfDay: ["dusk", "night"] },
        caption: "Professor Stonebrook turned the hourglass on its side again tonight and let the unmoving sand become the entire lesson. Quiet Hours. The Center. Rest isn't absence - it's the nervous system sorting the day so that tomorrow can happen at all. A pause chosen before collapse chooses it for you. If you've been running on the last of the light... his door is open. So is mine. Stay inside this song a while first." },
      { id: "mothlight-talisman-tide-glass", category: "news",
        src: "./assets/audio/mothlight-euphony-talisman-tide-glass.m4a",
        caption: "My own Chapter's talisman came up tonight - the Tide Glass. Salt-bright, unpredictable, Tidecrest through and through. Consult it and it shows you a different hour every time. It forgets your plans on purpose. And its one belief is a small mercy: the moment is complete in itself. You don't have to finish the day to deserve it. Let this one be complete. Here." },
      { id: "mothlight-talisman-moss-clasp", category: "gossip",
        src: "./assets/audio/mothlight-euphony-talisman-moss-clasp.m4a",
        caption: "They say the Moss Clasp - Mossbloom's quiet talisman - grows one new leaf whenever someone is truly listened to. Not spoken at. Listened to. It's older than its setting, and slow to act even when acting would be kind, because it trusts that the larger story is already being written. Someone, somewhere, is growing it a leaf right now, just by being heard. Be that for someone tonight." },
      { id: "mothlight-cast-inkrest", category: "gossip",
        src: "./assets/audio/mothlight-euphony-cast-inkrest.m4a",
        caption: "Dr. Inkrest sets the chairs out before the feelings arrive - did you know that? She seats a hard page near a lamp before she asks it to speak a single word. A difficult feeling isn't a verdict in that office. It's a page. And a page can be named, and seated, and revised one hour at a time. If today sat heavy as a low note, her office hours are the kind of door that simply opens. No appointment. Just weather, a chair, and the lamp." },
      { id: "mothlight-cast-serenity", category: "gossip",
        src: "./assets/audio/mothlight-euphony-cast-serenity.m4a",
        caption: "Serenity Brown swept through the Chamber today, left before the serious plan was finished, and somehow turned the detour into a rescue. She makes the loveliest chord in any room - the kind of laughter that changes its colour. Her whole creed is four words: joy isn't a distraction. From magic, she means. From anything. If the day's gone solemn on you, she'd tell you to abandon the plan and go look at the sea. So would I." },
      { id: "mothlight-lore-book-remembered", category: "news",
        src: "./assets/audio/mothlight-euphony-lore-book-remembered.m4a",
        caption: "The Book Remembered stirred tonight - an old page surfaced, one you were sure had gone quiet for good. That's how it works: give the Book enough notes and it begins to remember in chords. The quiet ones come back when the harmony is finally full enough to hold them. Don't reach for it. Just leave the lamp on and let it come the rest of the way. It always does, in the end." },
      { id: "mothlight-psa-samhain", category: "news",
        src: "./assets/audio/mothlight-euphony-psa-samhain.m4a",
        caption: "A note for the calendar's gentlest night: Samhain - the Thinning - comes at the turn of October, when the door between the kept and the lost stands a little ajar. The Book remembers more than usual then, and is kinder about it. Name someone you've lost, and one thing they left in your keeping. The veil is thin; be honest, be gentle. It isn't a sad feast. It's a held one." },
      { id: "mothlight-psa-yule-newmoon", category: "news",
        src: "./assets/audio/mothlight-euphony-psa-yule-newmoon.m4a",
        caption: "For the dark half of the year, two quiet feasts worth keeping. Yule - the Darkest Class - held by candlelight on the longest night, taught honestly, the fireplaces crowded. And every New Moon, the Listening: candles only, the Academy gone contemplative-dark. Both ask the same small thing - name one thing that survives the dark with you, and keep it where the candle can reach. The light always comes back. These feasts simply sit with you until it does." },
      { id: "mothlight-psa-resonance-class", category: "news",
        src: "./assets/audio/mothlight-euphony-psa-resonance-class.m4a",
        caption: "A standing invitation, for the record: Synesthetic Resonance meets twice a week - Tuesday afternoons at one bell, and Friday mornings at nine - in the Resonance Chamber, Wing Three. We practice the South direction. Sense. Hearing a colour, then naming the real evidence beneath it. The senses are serious instruments, and yours are only out of practice. Come tune the room with me. Bring nothing - you already carry everything it needs." },
      { id: "mothlight-psa-quiet-hours", category: "news",
        src: "./assets/audio/mothlight-euphony-psa-quiet-hours.m4a",
        caption: "Quiet Hours sits on the Wednesday timetable - Professor Stonebrook, the Still Room, one bell in the afternoon. It's the only class that teaches the Center. Rest. Not absence - the nervous system sorting the day so that tomorrow can happen. He turns the hourglass on its side and lets the still sand do the talking. If you've been running on the last of the light, that's the room. No one there will ask you to perform being fine." },
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
      { id: "thornwave-no-conflict-no-story", title: "No Conflict, No Story", artist: "Thornwave", src: "./assets/audio/thornwave-no-conflict-no-story.m4a" },
      { id: "thornwave-magic-margins", title: "Magic Margins", artist: "Thornwave", src: "./assets/audio/thornwave-magic-margins.m4a" },
      { id: "thornwave-velvet-arrears", title: "Velvet Arrears", artist: "Thornwave", src: "./assets/audio/thornwave-velvet-arrears.m4a" },
      { id: "thornwave-mossy-night", title: "Mossy Night", artist: "Thornwave", blessed: true, blessedSrc: "./assets/audio/thornwave-mossy-night.m4a" },
    ],
    banters: [
      { id: "thornwave-id-01", category: "stationID", src: "./assets/audio/thornwave-wicker-id-01.m4a",
        conditions: { timeOfDay: ["dusk", "night"] },
        caption: "Thornwave. One-oh-three point seven, after dark. Wicker Eddies, here to test whether anything you believe survives the bassline. Most of it won't. The stuff that does? That's the real magic. Stay tuned." },
      { id: "thornwave-id-02", category: "stationID", src: "./assets/audio/thornwave-wicker-id-02.m4a",
        caption: "You found Thornwave - one-oh-three seven, the frequency the dark fae kept for themselves. I puncture false magic for sport. This station isn't false. Felt that in your chest, didn't you. Good." },
      { id: "thornwave-id-03", category: "stationID", src: "./assets/audio/thornwave-wicker-id-03.m4a",
        conditions: { timeOfDay: ["dusk", "night"] },
        caption: "It's the hour rumors travel best, so I'm exactly where I belong. Wicker, on Thornwave. Keep your name to yourself. I collect those." },
      { id: "thornwave-outro-bramble-bass", category: "transition", track: "Bramble Bass", placement: "outro",
        src: "./assets/audio/thornwave-wicker-outro-bramble-bass.m4a",
        caption: "That was Bramble Bass. No theatrics, no glamour - just a thing that's actually true at a hundred and three point seven. Rare. Coming up, Nocturnal Faerie Lounge. Last call at the only bar the grey won't enter." },
      { id: "thornwave-outro-nocturnal-faerie-lounge", category: "transition", track: "Nocturnal Faerie Lounge", placement: "outro",
        src: "./assets/audio/thornwave-wicker-outro-nocturnal-faerie-lounge.m4a",
        caption: "Nocturnal Faerie Lounge, just now. Somebody in that crowd is making a deal they'll keep for thirty years. I'd talk them out of it - testing it, you understand - but the song's too good. Here's more." },
      { id: "thornwave-intro-bramble-bass", category: "transition", track: "Bramble Bass", placement: "intro",
        src: "./assets/audio/thornwave-wicker-intro-bramble-bass.m4a",
        caption: "The drop sounds like a door you were warned about, opening. I've never met a warning I didn't want to test. So - after this, let's open it. Bramble Bass." },
      { id: "thornwave-sponsor-bramblewine", category: "sponsor",
        src: "./assets/audio/thornwave-wicker-sponsor-bramblewine.m4a",
        caption: "Thornwave runs on favors owed and Bramblewine - aged in the dark, priced in the morning. One sip and the night belongs to you; two, and you belong to it. I've read the small print. There's always small print. That's the only honest thing at the Goblin Market - they tell you, then watch you not listen." },
      { id: "thornwave-sponsor-goblin-market", category: "sponsor",
        src: "./assets/audio/thornwave-wicker-sponsor-goblin-market.m4a",
        conditions: { timeOfDay: ["dusk", "night"] },
        caption: "Tonight's low end is sponsored by the Goblin Market. Open after hours. No refunds. All bargains binding. Tell Melisande over on one-oh-five that Wicker sent you, and she'll overcharge you with a straight face. Respect her for it. I do." },
      { id: "thornwave-gossip-pact", category: "gossip",
        src: "./assets/audio/thornwave-wicker-gossip-pact.m4a",
        caption: "Penny wouldn't print this - too unproven for the record - so I'll say it, because I prefer my truths a little dangerous: a pact came due this week. Somebody paid. The grey leaned one shade closer to whoever let it. Don't be that somebody. Plant the Belief. I'll wait. I'm patient when it matters." },
      { id: "thornwave-gossip-unwritten", category: "gossip",
        src: "./assets/audio/thornwave-wicker-gossip-unwritten.m4a",
        caption: "Rumor under the bassline. There's a chapter in this building nobody can jump into - yours, the Unwritten one. Everybody wants a look. They'd test it, pick it apart, like I would. Don't let us. Write it yourself first." },
      { id: "thornwave-news-nothing", category: "news",
        src: "./assets/audio/thornwave-wicker-news-grey.m4a",
        conditions: { timeOfDay: ["dusk", "night"] },
        caption: "Tonight's reading off Today's Sky: the Nothing made a move at the edges. We held. We always hold - barely, on purpose, which is the only kind of holding worth anything. Believe something out loud. I dare you. That's not mockery. That's the assignment." },
      { id: "thornwave-news-pact-dispatch", category: "news",
        src: "./assets/audio/thornwave-wicker-news-pact-dispatch.m4a",
        conditions: { timeOfDay: ["dusk", "night"] },
        caption: "Pact Dispatch is busy tonight. Three bargains struck, two already regretted, one that'll change a life. I can usually tell which is which - it's my whole talent. Tonight? Can't call it. That's how you know it's real. More Thornwave, after this." },
      { id: "thornwave-talisman-dusk-thorn", category: "news",
        src: "./assets/audio/thornwave-wicker-talisman-dusk-thorn.m4a",
        conditions: { timeOfDay: ["dusk", "night"] },
        caption: "Let's talk about my Chapter's talisman, since no one else will at this hour. The Dusk Thorn. Duskthorn. It only draws blood from a story that's already gone numb - never from a living one. Its belief is four words, and I happen to agree with every one of them: no conflict, no story. The grey wants your days smooth and quiet and forgettable. The Thorn wants them to cost something. So do I. That's not cruelty. That's plot." },
      { id: "thornwave-talisman-ember-seal", category: "gossip",
        src: "./assets/audio/thornwave-wicker-talisman-ember-seal.m4a",
        caption: "Emberheart's talisman is the Ember Seal - warm, insistent, bright at the edges, and impatient with waiting, which is the most honest thing in this building. It leaves faint scorch marks on your hesitations. Good. You should be able to see where you flinched. Its doctrine is the only line of Academy scripture I'd actually sign: you're the author, the protagonist, and the pen. So stop waiting for permission that was never coming. Write the next line yourself." },
      { id: "thornwave-class-book-jumping", category: "gossip",
        src: "./assets/audio/thornwave-wicker-class-book-jumping.m4a",
        caption: "You've been jumping into stories. Permancer's class - the Vault of Doors. He'll teach you that a genre is weather, not wallpaper, and that every door you open owes a return. All true. He lays out three bookmarks and rejects the prettiest one because it has no exit protocol. Me? I've never met a door I needed a bookmark to walk back through. That's the difference between us - and the reason he's right and I'm interesting. Keep the bookmark. For now." },
      { id: "thornwave-cast-finn", category: "gossip",
        src: "./assets/audio/thornwave-wicker-cast-finn.m4a",
        caption: "Finn Bridges chalked another challenge in red this week. Clean line, no theatrics - prove it by moving, don't cheapen the effort. He respects Momort's class most on the days it stops sounding like an escape route and starts sounding like discipline. I like Finn. He's one of the few who tests himself harder than I'd bother to. If he's marked a line for you, reader - don't argue it. Cross it. He'll respect that more than winning." },
      { id: "thornwave-cast-damien", category: "gossip",
        src: "./assets/audio/thornwave-wicker-cast-damien.m4a",
        conditions: { timeOfDay: ["night"] },
        caption: "A word about one of my own. Damien Nights still stands at my shoulder when the crew organizes - but his eyes keep drifting to you, reader. He keeps a pressed trail leaf hidden in a book. A man doesn't hide something gentle unless he's deciding which side he's on. I taught him doubt should protect something, not merely wound it. Looks like he was listening. Good. I'd rather lose him to the truth than keep him for the theatre." },
      { id: "thornwave-cast-thorne", category: "news",
        src: "./assets/audio/thornwave-wicker-cast-thorne.m4a",
        conditions: { timeOfDay: ["dusk", "night"] },
        caption: "The Headmistress is awake. Seraphina Thorne - unseelie, elegant, watchful, speaks as if every building is listening, which, in her case, they are. She keeps the Academy's doors from admitting they're tests. Believes beauty is a form of governance. She'd keep you safe by keeping you in the dark and call it mercy. I respect her more than I trust her. You should hold the same arithmetic. Wonder is only worth anything if it's allowed to stay a little dangerous." },
      { id: "thornwave-club-inkwright", category: "gossip",
        src: "./assets/audio/thornwave-wicker-club-inkwright.m4a",
        caption: "The Inkwright Society met in the Bibliophonic Hall tonight. Serious notebooks, no mascots. They write, they share - honest first, kind second - and then they burn it. Each meeting ends with a piece read aloud and set alight, the smoke going up into the library ceiling to be absorbed as words. Theatrical. I approve, obviously. The writing there's meant. If you've something true and dangerous to say, that's the only room in the building that can hold it." },
      { id: "thornwave-network-grey", category: "network",
        src: "./assets/audio/thornwave-wicker-network-grey.m4a",
        conditions: { timeOfDay: ["dusk", "night"] },
        caption: "One thing the whole band agrees on, and we agree on almost nothing: this is the sound the grey can't get into. ReEnchanted Radio. Keep believing out loud - it's the only thing that's ever worked, and I've spent my whole life trying to prove otherwise. Spin on." },
      { id: "thornwave-psa-clubs-night", category: "news",
        src: "./assets/audio/thornwave-wicker-psa-clubs-night.m4a",
        conditions: { timeOfDay: ["dusk", "night"] },
        caption: "It's after the bells, which means the clubs are awake - seven to ten, lamps up, doors open. The Compass Society reads souvenirs aloud like confessions, and no one in that garden mocks a sentence - more discipline than most of you manage. The Inkwright Society writes it true, then burns it; the smoke goes up into the library ceiling. The Marginalia Guild leaves threats to future readers, lovingly. And the Book Jumpers argue about doors until someone finds the one with a way back. Pick a room. Or don't. But the doors only open at this hour." },
      { id: "thornwave-psa-beltane", category: "news",
        src: "./assets/audio/thornwave-wicker-psa-beltane.m4a",
        caption: "One feast even I won't sharpen my teeth on: Beltane. The Greenfire. The first of May, when the courtyard goes reckless with bloom and the vines climb the shelves with tiny books for leaves. The bees in the Compass Rose are helpful and, frankly, a little drunk. Find the most alive green thing near you and talk to it like it can hear you. It can. That isn't me going soft - it's just true, and true is the only thing I deal in. Greenfire. Don't miss it." },
      { id: "thornwave-psa-fullmoon", category: "news",
        src: "./assets/audio/thornwave-wicker-psa-fullmoon.m4a",
        conditions: { timeOfDay: ["dusk", "night"] },
        caption: "When the moon comes full, the Academy does the one thing it almost never does - cancels class after sunset. The Luminous Gathering. Everyone spills into the courtyard to read by moonlight, and strangers actually speak to each other. The sentences glow. I've watched it happen and failed to find the trick. So write your souvenir under a full moon some night - they call it Moonwrite - and watch the page light up. Believe it out loud. I dare you. The moon's already holding still for you." },
    ],
  },
  {
    id: "the-bleed",
    name: "THE BLEED // UNAUTHORIZED",
    host: "Unknown Correspondent",
    freq: 97.3,
    hidden: true,
    signal: "The static parts around a voice that wasn't cleared for broadcast.",
    tagline: "This frequency doesn't appear on the Academy band. You didn't find it, and Penny Blackletter didn't leave the transmitter unlocked.",
    effect: "Record compromised · Margins awake · Plausible deniability −12",
    interstitialSrc: "./assets/audio/radio-free-margin-static.m4a",
    interstitialTitle: "Radio Free Margin Static",
    tracks: [
      { id: "the-bleed-intercept", title: "Intercept 97.3", artist: "Unknown Correspondent", src: "./assets/audio/the-bleed-pirate-signal.m4a" },
    ],
    banters: [
      { id: "bleed-rant-02", category: "network", src: "./assets/audio/bleed-rant-02.m4a", weight: 4,
        caption: "Unauthorized transmission continuing. If the Academy says the margin is blank, check whose hand is covering the ink. Static is not silence. Static is a crowd of facts waiting for one reader with nerve enough to tune between the approved numbers." },
      { id: "bleed-cast-crew", category: "network", src: "./assets/audio/bleed-cast-crew.m4a", weight: 6,
        caption: "Unauthorized intercept. The faction the Academy won't name on the record: Wicker's crew. Blackwood keeps its memory; Nights keeps its doubt. Watch which one cracks first - the broker, or the believer. You didn't get this from a station. You didn't get this at all." },
      { id: "bleed-talisman-contraband", category: "network", src: "./assets/audio/bleed-talisman-contraband.m4a", weight: 5,
        caption: "Hidden-band advisory. Five talismans, one per Chapter, and the Academy lists them like heirlooms. Thorn for conflict. Ember for authorship. Cipher for the work we do together. Glass for the unplanned. Clasp for what you receive. They are not heirlooms. They are tools. The grey is up - pick one up and use it. Quietly." },
      { id: "bleed-lore-unwritten", category: "network", src: "./assets/audio/bleed-lore-unwritten.m4a", weight: 4,
        caption: "Off the record, off the band: there's a chapter in this building no one can jump into, no one can assign, no one can grade. Yours. The Unwritten one. Everybody wants a look. Don't sign your name at anyone else's door. Write it from the inside. That's the only lock that holds." },
      { id: "bleed-cast-thorne", category: "network", src: "./assets/audio/bleed-cast-thorne.m4a", weight: 4,
        conditions: { timeOfDay: ["night"] },
        caption: "This is not a station ID. The Headmistress monitors this frequency - Thorne hears the whole band, and she keeps doors from admitting they're tests. If a threshold opens easy tonight, ask who left it open, and what it's measuring. Stay anonymous, reader. Stay awake." },
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
  let playingInterstitial = false;
  let pendingBanter = null;
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
      const locked = Boolean(t.blessed && !t.src);
      const blessed = Boolean(t.blessed && t.src);
      li.classList.toggle("playable", playable);
      li.classList.toggle("blessed-locked", locked);
      li.classList.toggle("blessed", blessed);
      li.classList.toggle("now-playing", onAir && playable && i === trackIndex);
      const state = onAir && playable && i === trackIndex ? "♫" : locked ? "🔒" : playable ? "▷" : "-";
      const tag = locked ? "Blessed · spend Belief on the dial" : blessed ? "✦ blessed" : playable ? "" : "no recording yet";
      li.innerHTML = `
        <span class="track-state" aria-hidden="true">${state}</span>
        <span class="track-meta"><strong>${t.title}</strong><small>${t.artist}</small></span>
        <span class="track-tag">${tag}</span>`;
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
    playingInterstitial = false;
    pendingBanter = null;
    pendingTrackIndex = null;
    card.classList.remove("on-banter");
    if (tuned) elName.textContent = tuned.name;
    if (elNote) elNote.textContent = message;
    setOnAir(false);
    renderTracks();
  }

  function play() {
    // A real song is starting - clear any DJ-break presentation.
    playingBanter = false;
    playingInterstitial = false;
    pendingBanter = null;
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
  // correct song. There's deliberately no category playlist to march through.
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
    playingInterstitial = false;
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

  function playInterstitial(nextIndex, banter = null) {
    if (!tuned?.interstitialSrc) {
      if (banter) playBanter(banter, nextIndex);
      else {
        trackIndex = nextIndex != null ? nextIndex : trackIndex;
        play();
      }
      return;
    }
    playingBanter = false;
    playingInterstitial = true;
    pendingBanter = banter;
    pendingTrackIndex = nextIndex;
    card.classList.add("on-banter");
    elName.textContent = tuned.interstitialTitle || "Pirate static";
    if (elNote) elNote.textContent = "Static between unauthorized broadcasts.";
    audio.src = tuned.interstitialSrc;
    ensureWaveAnalyser();
    audio.play().catch(() => {});
    renderTracks();
  }

  audio.addEventListener("ended", () => {
    const playable = tuned.tracks.map((t, i) => (t.src ? i : -1)).filter((i) => i >= 0);
    if (playable.length === 0) return;

    if (playingInterstitial) {
      playingInterstitial = false;
      const nextBanter = pendingBanter;
      pendingBanter = null;
      if (nextBanter) {
        playBanter(nextBanter, pendingTrackIndex);
      } else {
        trackIndex = pendingTrackIndex != null ? pendingTrackIndex : trackIndex;
        pendingTrackIndex = null;
        play();
      }
      return;
    }

    if (playingBanter) {
      // Break finished - play the song held behind it.
      playingBanter = false;
      card.classList.remove("on-banter");
      if (tuned?.interstitialSrc) {
        playInterstitial(pendingTrackIndex);
      } else {
        trackIndex = pendingTrackIndex != null ? pendingTrackIndex : trackIndex;
        pendingTrackIndex = null;
        play();
      }
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
      if (tuned?.interstitialSrc) playInterstitial(nextIndex, banter);
      else playBanter(banter, nextIndex);
    } else {
      if (tuned?.interstitialSrc) playInterstitial(nextIndex);
      else {
        trackIndex = nextIndex;
        play();
      }
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
      elName.textContent = "- - -";
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
      : "This station is broadcasting - the recording hasn't been pressed yet.";
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
    else { setOnAir(true); renderTracks(); } // silent broadcast - still goes on air
  });
  if (power) power.addEventListener("click", () => {
    if (onAir) powerOffBroadcast();
  });

  // The "Bless the dial" Belief spend (in the Glow menu) unlocks one secret
  // track per station and brings the cabinet to life on the current frequency.
  // Returns how many tracks it newly unlocked so the spend can react.
  window.blessRadioDial = function blessRadioDial() {
    let unlocked = 0;
    STATIONS.forEach((station) => {
      (station.tracks || []).forEach((t) => {
        if (t.blessed && !t.src && t.blessedSrc) { t.src = t.blessedSrc; unlocked += 1; }
      });
    });
    if (!tuned) { dial.value = STATIONS[0].freq; onDial(); }
    const idx = tuned ? tuned.tracks.findIndex((t) => t.blessed && t.src) : -1;
    if (idx >= 0) { trackIndex = idx; play(); }
    else { renderTracks(); }
    return unlocked;
  };

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
  const PIXIE_COLOR = [255, 224, 170];
  const letters = [];
  const sparks = [];
  let width = 0;
  let height = 0;
  let dpr = 1;

  const TAU = Math.PI * 2;
  const rand = (a, b) => a + Math.random() * (b - a);
  function wrap(v, max) {
    if (v < 0) return v + max;
    if (v > max) return v - max;
    return v;
  }

  function makeLetter(seedPos) {
    const color = colors[Math.floor(Math.random() * colors.length)];
    return {
      glyph: glyphs[Math.floor(Math.random() * glyphs.length)],
      x: seedPos ? Math.random() * Math.max(width, 1) : 0,
      y: seedPos ? Math.random() * Math.max(height, 1) : 0,
      vx: rand(-9, 9),
      vy: rand(-9, 9),
      depth: 0.35 + Math.random() * 0.9,
      size: 5 + Math.random() * 7,
      angle: Math.random() * TAU,
      spinV: (Math.random() - 0.5) * 0.5,
      seed: Math.random() * TAU,
      baseAlpha: 0.12 + Math.random() * 0.22,
      flash: 0,            // brightening from a bump or the pixie's gather
      cooldown: 0,         // throttles per-letter spark spawns
      color,
    };
  }

  // A winged mote that wanders the field and periodically gathers nearby
  // letters toward itself, trailing sparks - kin to the punctuation pixies.
  const pixie = {
    x: 0, y: 0, vx: 12, vy: -8,
    wing: 0,
    state: "wander",
    timer: rand(4, 8),
    trail: [],
    glow: 0,
  };

  function spawnSpark(x, y, color, strength) {
    if (sparks.length > 140) return;
    const a = Math.random() * TAU;
    const sp = rand(12, 46) * (strength || 1);
    sparks.push({
      x, y,
      vx: Math.cos(a) * sp,
      vy: Math.sin(a) * sp - 6,
      life: 0,
      maxLife: rand(0.4, 0.95),
      size: rand(0.7, 1.9),
      color,
    });
  }

  function resize() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    const hadSize = width > 0;
    width = window.innerWidth;
    height = window.innerHeight;
    canvas.width = Math.floor(width * dpr);
    canvas.height = Math.floor(height * dpr);
    canvas.style.width = `${width}px`;
    canvas.style.height = `${height}px`;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    if (!hadSize) {
      pixie.x = width * 0.5;
      pixie.y = height * 0.4;
    }
    const target = Math.min(170, Math.max(70, Math.floor((width * height) / 13000)));
    while (letters.length < target) letters.push(makeLetter(true));
    letters.length = target;
  }

  function steerPixie(dt, time) {
    pixie.timer -= dt;
    if (pixie.timer <= 0) {
      if (pixie.state === "wander" && letters.length) {
        pixie.target = letters[Math.floor(Math.random() * letters.length)];
        pixie.state = "gather";
        pixie.timer = rand(2.4, 4.2);
      } else {
        pixie.target = null;
        pixie.state = "wander";
        pixie.timer = rand(5, 9);
      }
    }

    // Base wander: a slow, looping current that never touches the cursor.
    let ax = Math.cos(time * 0.21 + 1.3) * 9 + Math.sin(time * 0.07) * 5;
    let ay = Math.sin(time * 0.18) * 9 + Math.cos(time * 0.05 + 2.1) * 5;

    if (pixie.state === "gather" && pixie.target) {
      const dx = pixie.target.x - pixie.x;
      const dy = pixie.target.y - pixie.y;
      const d = Math.hypot(dx, dy) || 1;
      ax += (dx / d) * 26;
      ay += (dy / d) * 26;
      pixie.glow = Math.min(1, pixie.glow + dt * 1.6);
    } else {
      pixie.glow = Math.max(0, pixie.glow - dt * 1.2);
    }

    // Keep her on stage with soft edge repulsion.
    const m = 70;
    if (pixie.x < m) ax += (m - pixie.x) * 0.6;
    if (pixie.x > width - m) ax -= (pixie.x - (width - m)) * 0.6;
    if (pixie.y < m) ay += (m - pixie.y) * 0.6;
    if (pixie.y > height - m) ay -= (pixie.y - (height - m)) * 0.6;

    pixie.vx = (pixie.vx + ax * dt) * 0.985;
    pixie.vy = (pixie.vy + ay * dt) * 0.985;
    const sp = Math.hypot(pixie.vx, pixie.vy);
    const max = 58;
    if (sp > max) { pixie.vx = pixie.vx / sp * max; pixie.vy = pixie.vy / sp * max; }
    pixie.x += pixie.vx * dt;
    pixie.y += pixie.vy * dt;
    pixie.wing += dt * 22;

    pixie.trail.unshift({ x: pixie.x, y: pixie.y, life: 1 });
    if (pixie.trail.length > 18) pixie.trail.pop();
    for (const p of pixie.trail) p.life -= dt * 1.4;
    while (pixie.trail.length && pixie.trail[pixie.trail.length - 1].life <= 0) pixie.trail.pop();
    if (pixie.glow > 0.2 && Math.random() < pixie.glow * 0.5) {
      spawnSpark(pixie.x + rand(-4, 4), pixie.y + rand(-4, 4), PIXIE_COLOR, 0.5);
    }
  }

  function collide(dt) {
    for (let i = 0; i < letters.length; i++) {
      const a = letters[i];
      for (let j = i + 1; j < letters.length; j++) {
        const b = letters[j];
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const minD = (a.size * a.depth + b.size * b.depth) * 0.5 + 5;
        const d2 = dx * dx + dy * dy;
        if (d2 > minD * minD || d2 === 0) continue;
        const d = Math.sqrt(d2) || 1;
        const nx = dx / d;
        const ny = dy / d;
        // Soft elastic push apart.
        const overlap = (minD - d) * 0.5;
        a.x -= nx * overlap; a.y -= ny * overlap;
        b.x += nx * overlap; b.y += ny * overlap;
        const relax = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
        if (relax < 0) {
          const imp = relax * 0.9;
          a.vx += nx * imp; a.vy += ny * imp;
          b.vx -= nx * imp; b.vy -= ny * imp;
        }
        a.flash = Math.min(1, a.flash + 0.6);
        b.flash = Math.min(1, b.flash + 0.6);
        if (a.cooldown <= 0 && b.cooldown <= 0) {
          const mxp = (a.x + b.x) * 0.5;
          const myp = (a.y + b.y) * 0.5;
          const n = 2 + (Math.random() * 3 | 0);
          for (let k = 0; k < n; k++) spawnSpark(mxp, myp, Math.random() < 0.5 ? a.color : b.color, 0.8);
          a.cooldown = b.cooldown = 0.5;
        }
      }
    }
  }

  let last = 0;
  function draw(t) {
    const time = t * 0.001;
    const dt = last ? Math.min(0.05, time - last) : 0;
    last = time;

    ctx.clearRect(0, 0, width, height);
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";

    // ── update letters ──
    for (const letter of letters) {
      // gentle self-propelled wander, no cursor input
      letter.vx += Math.cos(time * 0.3 + letter.seed) * 5 * dt;
      letter.vy += Math.sin(time * 0.27 + letter.seed * 1.3) * 5 * dt;

      if (pixie.glow > 0.15) {
        const dx = pixie.x - letter.x;
        const dy = pixie.y - letter.y;
        const d = Math.hypot(dx, dy);
        const R = 150;
        if (d < R && d > 1) {
          const pull = (1 - d / R) * pixie.glow * 90;
          letter.vx += (dx / d) * pull * dt;
          letter.vy += (dy / d) * pull * dt;
          letter.flash = Math.min(1, letter.flash + (1 - d / R) * dt * 2.2);
        }
      }

      letter.vx *= 0.985;
      letter.vy *= 0.985;
      const sp = Math.hypot(letter.vx, letter.vy);
      const max = 42;
      if (sp > max) { letter.vx = letter.vx / sp * max; letter.vy = letter.vy / sp * max; }

      letter.x = wrap(letter.x + letter.vx * dt, width);
      letter.y = wrap(letter.y + letter.vy * dt, height);
      letter.angle += letter.spinV * dt;
      if (letter.flash > 0) letter.flash = Math.max(0, letter.flash - dt * 2.4);
      if (letter.cooldown > 0) letter.cooldown -= dt;
    }

    collide(dt);
    steerPixie(dt, time);

    const scrollDrift = window.scrollY * 0.018;

    // ── draw letters ──
    for (const letter of letters) {
      const x = wrap(letter.x + 40, width + 80) - 40;
      const y = wrap(letter.y + scrollDrift * letter.depth + 40, height + 80) - 40;
      const [r, g, b] = letter.color;
      const alpha = Math.min(0.62, letter.baseAlpha + letter.flash * 0.5);
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(Math.sin(letter.angle) * 0.22 + letter.flash * 0.3);
      ctx.font = `${letter.size * letter.depth * (1 + letter.flash * 0.25)}px Fraunces, Georgia, serif`;
      ctx.fillStyle = `rgba(${r}, ${g}, ${b}, ${alpha})`;
      ctx.shadowColor = `rgba(${r}, ${g}, ${b}, ${(0.35 + letter.flash * 0.5)})`;
      ctx.shadowBlur = (4 + letter.flash * 10) * letter.depth;
      ctx.fillText(letter.glyph, 0, 0);
      ctx.restore();
    }

    // ── draw + update sparks ──
    for (let i = sparks.length - 1; i >= 0; i--) {
      const s = sparks[i];
      s.life += dt;
      if (s.life >= s.maxLife) { sparks.splice(i, 1); continue; }
      s.vy += 26 * dt;
      s.vx *= 0.96;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      const k = 1 - s.life / s.maxLife;
      const [r, g, b] = s.color;
      ctx.save();
      ctx.globalCompositeOperation = "lighter";
      ctx.beginPath();
      ctx.arc(s.x, s.y + scrollDrift * 0.6, s.size * k + 0.4, 0, TAU);
      ctx.fillStyle = `rgba(${r}, ${g}, ${b}, ${0.85 * k})`;
      ctx.shadowColor = `rgba(${r}, ${g}, ${b}, ${k})`;
      ctx.shadowBlur = 8 * k;
      ctx.fill();
      ctx.restore();
    }

    // ── draw pixie ──
    drawPixie(time);

    requestAnimationFrame(draw);
  }

  function drawPixie(time) {
    const px = pixie.x;
    const py = pixie.y + window.scrollY * 0.018 * 0.5;
    const [r, g, b] = PIXIE_COLOR;
    ctx.save();
    ctx.globalCompositeOperation = "lighter";

    // trail
    for (let i = pixie.trail.length - 1; i >= 0; i--) {
      const p = pixie.trail[i];
      const py2 = p.y + window.scrollY * 0.018 * 0.5;
      const a = Math.max(0, p.life) * 0.5;
      ctx.beginPath();
      ctx.arc(p.x, py2, 1.4 * p.life + 0.4, 0, TAU);
      ctx.fillStyle = `rgba(${r}, ${g}, ${b}, ${a})`;
      ctx.fill();
    }

    // wings
    const flap = Math.sin(pixie.wing) * 0.6 + 0.7;
    const heading = Math.atan2(pixie.vy, pixie.vx);
    ctx.translate(px, py);
    ctx.rotate(heading + Math.PI / 2);
    for (const side of [-1, 1]) {
      ctx.save();
      ctx.scale(side * flap, 1);
      ctx.beginPath();
      ctx.ellipse(4.5, -1, 4.2, 2.3, -0.5, 0, TAU);
      ctx.fillStyle = `rgba(${r}, ${g}, ${b}, ${0.16 + pixie.glow * 0.18})`;
      ctx.fill();
      ctx.restore();
    }
    ctx.rotate(-(heading + Math.PI / 2));

    // body glow + core
    const halo = 7 + pixie.glow * 6 + Math.sin(time * 6) * 0.8;
    const grad = ctx.createRadialGradient(0, 0, 0, 0, 0, halo);
    grad.addColorStop(0, `rgba(${r}, ${g}, ${b}, ${0.9})`);
    grad.addColorStop(0.4, `rgba(${r}, ${g}, ${b}, ${0.4 + pixie.glow * 0.3})`);
    grad.addColorStop(1, "rgba(255, 224, 170, 0)");
    ctx.beginPath();
    ctx.arc(0, 0, halo, 0, TAU);
    ctx.fillStyle = grad;
    ctx.fill();
    ctx.beginPath();
    ctx.arc(0, 0, 1.7, 0, TAU);
    ctx.fillStyle = "rgba(255, 248, 232, 0.95)";
    ctx.fill();
    ctx.restore();
  }

  window.addEventListener("resize", resize, { passive: true });
  resize();
  requestAnimationFrame(draw);
}
initField();

/* ───────────────────────── hidden lore marginalia ─────────────────────────
 * Words across the page are quietly clickable. Each opens a scrap of the
 * Book's own voice - folklore, cast, talismans, systems. The frame is
 * fictional; the life is real.
 */
const LORE = {
  /* ── folklore / animist / Fae ── */
  "faerie-tale": {
    kicker: "The older, more dangerous kind",
    title: "Not the Disney Fae",
    kind: "folklore",
    body: [
      "The Folk in my oldest pages aren't cute, and they aren't winged decorations. They're proud, easily slighted, and generous to the courteous. Across the British and Irish stories people rarely said the word ‘fairy’ aloud - too risky - and called them the Good Folk, the Gentry, the Fair Family, the Good Neighbours.",
      "The whole etiquette comes down to manners: don't boast, don't take without asking, don't break a promise, and say thank you where thanks are due. The woods really do keep what you promise them.",
    ],
    tryThis: "Get through one conversation today on the etiquette of the Folk: no boasting, no taking without asking, and a genuine thank-you where it's owed.",
  },
  "the-folk": {
    kicker: "Old law, not manners",
    title: "The Good Neighbours",
    kind: "folklore",
    body: [
      "When the Fae speak in old law, they aren't being rude - they're being older than your rules. A bargain with them runs on courtesy and exactness, and they remember every word of it long after you've forgotten you spoke.",
      "I keep their etiquette close because it turns out to be excellent advice for dealing with people, too: be precise, be courteous, and mean what you promise.",
    ],
  },
  "fairy-gifts": {
    kicker: "What a gift is really asking",
    title: "The Debt Inside a Gift",
    kind: "folklore",
    body: [
      "A gift from the Folk is never free, and never quite what it looks like - the gold turns to leaves by morning; the leaves turn out to be gold. The rule under every version is reciprocity: a gift opens a thread between giver and taker, and the thread must be honoured.",
      "It's why the Fae never want Belief. They want noticing. Pay in true attention and the bargain moves - but it remembers, and it's never quite free.",
    ],
    tryThis: "Think of one gift or favour you've accepted lately. Decide what, if anything, it quietly asked of you - and whether you mean to honour it.",
  },
  "moon-phases": {
    kicker: "Match your task to the sky",
    title: "The Moon's Four Faces",
    kind: "folklore",
    body: [
      "Long before calendars, the moon kept the working schedule of folk magic. The waxing moon was for beginning and drawing toward; the full moon for power and clarity; the waning moon for releasing and letting go; the dark moon for rest and the things best done unseen.",
      "Every Anchor Room I grow remembers which face was overhead when you visited. You really do have weeks for building and weeks for clearing out.",
    ],
    tryThis: "Look up tonight's moon phase. Pick one task that matches it - start something if it's waxing, finish or release something if it's waning.",
  },
  "genius-loci": {
    kicker: "The spirit of the place",
    title: "Every Corner Has Been Teaching You",
    kind: "folklore",
    body: [
      "The Romans called it the genius loci - the spirit of a place - and nearly every tradition keeps a version: the household god, the spirit of the well, the guardian of the crossroads. Animism simply takes the place seriously as a someone, not a something.",
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
      "A talisman listens because you have agreed it stands for something. When you think about it, I'm one enormous table of correspondences - everything in me points at something in you.",
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
      "I don't make these places less real by taking them in. I make them more thoroughly themselves.",
    ],
  },
  belief: {
    kicker: "Measure how vivid the world feels",
    title: "Belief",
    kind: "system",
    body: [
      "Belief is my word for what happens when attention, courage, and meaning gather in one place at one time. When it runs high, my ink goes dark, the colours sharpen, and the impossible turns suddenly cooperative.",
      "When it runs low - and it will - that isn't failure. It only means the world has gone muted, and is waiting for some small, concrete act of noticing to bring the brightness back up.",
    ],
    tryThis: "When the world goes muted today, do one small concrete act of noticing to bring the brightness back up.",
  },
  "anchor-rooms": {
    kicker: "Let a real place answer in Academy terms",
    title: "Anchor Rooms",
    kind: "system",
    body: [
      "Some real places step far enough into me to become Anchor Rooms. They stay exactly what they're - but I learn their room-feeling. A market becomes a bazaar of bargains; a pier becomes a tidal classroom; the café you already love becomes a small warm kingdom.",
      "I don't replace the place; I wouldn't dare. I only give it one more way to be read - and pin it to your real coordinates, so I know when you've truly come back.",
    ],
  },
  "the-nothing": {
    kicker: "Name the force that makes everything less",
    title: "The Nothing",
    kind: "system",
    body: [
      "Let me name the thing I'm set against. The Nothing isn't a monster with a speech to give. It's erasure - colours dulling, details going missing, stories flattening, rooms becoming merely rooms. It feeds on inattention and routine until your whole world reads like a summary of itself.",
      "Feeling grey is its first weather. Every Compass Run, every Enchantment, is a small refusal: specific, sensory meaning made in the real world, where the Nothing can't follow.",
    ],
    tryThis: "Pick one thing the Nothing has flattened into ‘just a room, just a commute’ and make it specific and sensory again.",
  },
  "wonder-compass": {
    kicker: "Make a complete loop through wonder",
    title: "The Wonder Compass",
    kind: "system",
    body: [
      "The Compass teaches my most practical ritual: North to Notice, East to Embark, South to Sense, West to Write, and Centre to Rest. I start you on tiny runs because tiny runs are the ones you can't wave away as nothing.",
      "The size never matters. A kitchen, a porch, a city block, or a whole day can become a Run, so long as the loop closes.",
    ],
    tryThis: "Run one tiny Compass: one question, one comfort, one sensory game, and one true sentence carried home.",
  },
  enchantments: {
    kicker: "Use attention as a spell",
    title: "Enchantments",
    kind: "system",
    body: [
      "An Enchantment is a pen-spell aimed straight at your real world. Photograph an object, a room, a pet, a meal - and it becomes the focus of the magic: it may speak, turn poetic, give up a hidden story, or show you the secret ways it rhymes with everything else.",
      "The spell only works because you genuinely looked. The pen aims the attention. The world, as always, supplies the wonder.",
    ],
    tryThis: "Look - really look - at one object, room, or meal until it gives up a hidden story.",
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
      "This is the chapter that keeps its fire useful. Emberheart belongs to warmth, daring, craft, and brave beginnings - and at their best my Emberheart students aren't just bold, they're kindling for other people's courage.",
      "Their magic favours lamps and hearths and kitchens and rescues, and the decisive moment when someone says yes before the fear has finished making its case.",
    ],
  },
  mossbloom: {
    kicker: "Life is listened to",
    title: "Mossbloom Chapter",
    kind: "chapter",
    body: [
      "This is the chapter that grows quietly, and don't mistake quiet for small. Mossbloom belongs to patience, repair, rooting, green persistence. Its students know that not every victory is a blaze - some look like a seedling coming back after winter.",
      "Their magic favours gardens and mending and slow courage, the kind of strength that builds a shelter rather than a spectacle.",
    ],
  },
  tidecrest: {
    kicker: "Life is a poem",
    title: "Tidecrest Chapter",
    kind: "chapter",
    body: [
      "This is the chapter where feeling and weather meet. Tidecrest belongs to memory, music, water, and change, and its students are forever accused of being dramatic by people who mistake depth for inconvenience.",
      "Their magic favours shorelines and rain and songs and letters - and the hard grace of letting an emotion move through a room without letting it drown the room.",
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
      "I'll tell you what I've got, which is mostly rumour. Duskthorn is the half-remembered chapter - twilight, thorns, secrecy, hard protection, and the cost of guarding what others would rather not name.",
      "Some of my students swear it's only a story invented to make the chapter system feel complete. The rest of them lower their voices when the west windows go violet. I let both be true for now.",
    ],
  },

  /* ── talismans (with art) ── */
  "ember-seal": {
    kicker: "Emberheart's talisman",
    title: "The Ember Seal",
    kind: "talisman",
    art: { src: "./assets/art/LabyrinthTalismanEmberSeal.png", alt: "The Ember Seal talisman" },
    body: [
      "Hold this one and feel a heat that doesn't burn the palm. The Ember Seal carries Emberheart's oath - to warm, to illuminate, to begin.",
      "I keep it as a reminder that courage is meant to be carried into kitchens and sickrooms and cold walks and first attempts, not hoarded for some theatrical emergency that may never come.",
    ],
  },
  "moss-clasp": {
    kicker: "Mossbloom's talisman",
    title: "The Moss Clasp",
    kind: "talisman",
    art: { src: "./assets/art/LabyrinthTalismanMossClasp.png", alt: "The Moss Clasp talisman" },
    body: [
      "Fasten yourself to whatever keeps growing. The Moss Clasp belongs to Mossbloom's slow magic - repair, shelter, rootwork, the quiet bravery of coming back.",
      "Picture it correctly and you won't picture a trophy. You'll picture something that simply holds: a mended strap, a garden gate, a hand around a warm mug, a promise kept without fuss.",
    ],
  },
  "tide-glass": {
    kicker: "Tidecrest's talisman",
    title: "The Tide Glass",
    kind: "talisman",
    art: { src: "./assets/art/LabyrinthTalismanTideGlass.png", alt: "The Tide Glass talisman" },
    body: [
      "Look through this and you don't predict a feeling or master it - you see its shape. The Tide Glass is Tidecrest's lens for emotion made visible: the curve of a wave before it breaks, the salt left after tears.",
      "I keep it for the readers who feel everything and fear it means they're broken. It only means they're awake.",
    ],
  },
  "wind-cipher": {
    kicker: "Riddlewind's talisman",
    title: "The Wind Cipher",
    kind: "talisman",
    art: { src: "./assets/art/LabyrinthTalismanWindCipher.png", alt: "The Wind Cipher talisman" },
    body: [
      "Turn this until the answer catches the air. The Wind Cipher is Riddlewind's talisman of moving thought - for clues, questions, jokes, maps, and the bright instant when a stuck idea suddenly shows you another side.",
      "My students say carrying it feels less like owning an answer and more like keeping a small weather system for the mind.",
    ],
  },
  "dusk-thorn": {
    kicker: "Duskthorn's talisman",
    title: "The Dusk Thorn",
    kind: "talisman",
    art: { src: "./assets/art/LabyrinthTalismanDuskThorn.png", alt: "The Dusk Thorn talisman" },
    body: [
      "Respect the sign that protects by pricking. The Dusk Thorn is the rumoured mark of Duskthorn - a talisman of boundaries, secrecy, and hard protection. It's not cruel, though it's rarely comfortable.",
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
      "No Book Fae is decorative; each keeps one necessary thing from going dull. Watch the margins when she is near - the page usually notices before the reader does.",
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
      "Small, exacting, and faintly smug, the Punctuation Pixie tends the breath of a sentence - the pause of a comma, the held breath before a dash, the full stop that finally lets you exhale.",
      "Mind your manners around it. Move a comma carelessly and it will move it back, and change your whole meaning while it's there.",
    ],
  },
  "deep-lore-dwarf": {
    kicker: "The underlayer",
    title: "The Deep Lore Dwarf",
    kind: "cast",
    art: { src: "./assets/art/fae-deep-lore-dwarf.jpg", alt: "Illustrated dossier of the Deep Lore Dwarf Book Fae" },
    body: [
      "It works the oldest, lowest seams of me - the overlooked thing that turns out to be holding something else up. It speaks rarely and is usually right when it does.",
      "A Deep Lore Dwarf once set a small grey stone before a reader and said nothing. The stone was older than the catalogue. So, it implied, were some of your troubles - and some of your strengths.",
    ],
  },
  "marginalia-goblin": {
    kicker: "A life between the lines",
    title: "The Marginalia Goblin",
    kind: "cast",
    art: { src: "./assets/art/fae-marginalia-goblin.jpg", alt: "Illustrated dossier of the Marginalia Goblin Book Fae" },
    body: [
      "It lives in the white space at the edge of the page and can't leave a margin alone. It scrawls, it doodles, it files ridiculous evidence, and every so often its scribble in the margin saves the whole shelf.",
      "When it's near, the edges of a page get busy. Watch the margins before you watch the text.",
    ],
  },

  /* ── cast: people ── */
  "headmistress-thorne": {
    kicker: "You probably shouldn't fully trust her",
    title: "Headmistress Seraphina Thorne",
    kind: "cast",
    art: { src: "./assets/art/cast-headmistress-thorne.jpg", alt: "Illustrated dossier of Headmistress Seraphina Thorne" },
    body: [
      "I keep my doors opening; she keeps them honest. Seraphina Thorne is my headmistress - elegant, dry, and very nearly impossible to startle. She can make a reprimand land like a riddle and a kindness arrive like a secret.",
      "She holds that wonder must be practised, not just admired, and that a school for magic owes its students one lesson before all others: notice the world before you go trying to change it. She isn't soft. She isn't careless either.",
    ],
  },
  "dr-vellum": {
    kicker: "She keeps your body's marginalia",
    title: "Dr. Elowen Vellum",
    kind: "cast",
    art: { src: "./assets/art/cast-dr-vellum.jpg", alt: "Illustrated dossier of Dr. Elowen Vellum, Academy Longevity Physician" },
    body: [
      "The Academy's longevity physician and keeper of the Refectory Marginalia. She turns your fuel, your sleep, your bloodwork into field notes in the margin - warmly clinical, precise, and entirely without shame.",
      "She holds that the body isn't a problem to win against. She can make a supplement interaction sound like etiquette, and she means it as care.",
    ],
  },
  "dr-inkrest": {
    kicker: "Keeper of difficult pages",
    title: "Dr. Selene Inkrest",
    kind: "cast",
    art: { src: "./assets/art/cast-dr-inkrest.jpg", alt: "Illustrated dossier of Dr. Selene Inkrest, Academy narrative therapist" },
    body: [
      "The Academy's narrative therapist, who curates the Reauthoring Rooms and keeps a chair and a lamp ready before any feeling arrives. She helps you set a problem down beside you so you can look at it instead of being it.",
      "She believes a hard page deserves a chair and a lamp, not a rush. She will wait so patiently that the room sometimes forgets to answer - and then, gently, it does.",
    ],
  },
  "gwendolyn-mythwright": {
    kicker: "Mossbloom · cryptid seeker",
    title: "Gwendolyn Mythwright",
    kind: "cast",
    art: { src: "./assets/art/cast-gwendolyn-mythwright.jpg", alt: "Illustrated dossier of Gwendolyn Mythwright, cryptid researcher" },
    body: [
      "She does her own research, passionately and at length, on things she has not yet proven. Her notebooks run ahead of her evidence - which is either a flaw or the entire point, depending on the week.",
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
      "He trusts the slow path. The errand he gives is never really about the destination - it's about what the going does to you.",
    ],
  },
  "finn-bridges": {
    kicker: "Emberheart · the honourable rival",
    title: "Finn Bridges",
    kind: "cast",
    art: { src: "./assets/art/cast-finn-bridges.jpg", alt: "Illustrated dossier of Finn Bridges, Emberheart rival" },
    body: [
      "Independent, determined, and happy to argue with anyone - including you. Finn is a rival who respects competence above agreement, which makes him antagonistic and oddly trustworthy at once.",
      "He will push back on your easy choices. Take it as a compliment: he only bothers to argue with people he thinks can win.",
    ],
  },
  "melisande-blackwood": {
    kicker: "Emberheart · knows things she shouldn't",
    title: "Melisande Blackwood",
    kind: "cast",
    art: { src: "./assets/art/cast-melisande-blackwood.jpg", alt: "Illustrated dossier of Melisande Blackwood" },
    body: [
      "Loyal, brilliant, and ruthless in roughly that order. Melisande runs with Wicker's crew and will attack the Belief she distrusts without blinking - she has read the room before you've finished entering it.",
      "She knows things she shouldn't, and trades them carefully. Be courteous. The Folk aren't the only ones in my pages who remember a slight.",
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
      "Brooding, severe, and fluent in shadow magic - Damien runs with Wicker's crew and keeps, and trades, the secrets that the Academy would rather stayed buried. He watches you more than is strictly polite.",
      "I've not decided yet whether he is a danger or a warning, and I suspect neither has he. Some pages are written in the dark on purpose.",
    ],
  },

  /* ── rooms ── */
  "the-stacks": {
    kicker: "Rooms that behave like pages",
    title: "The Stacks",
    kind: "room",
    art: { src: "./assets/art/room-stacks.jpg", alt: "Illustrated dossier of the Stacks, the Academy's living library" },
    body: [
      "My catalogued heart. The Stacks are corridors that behave like chapters and classrooms that keep their own weather - fog that makes the professors cancel class to watch the harbour vanish, a Library cloud overhead that changes colour when the building is thinking.",
      "The weather outside your window becomes the weather in here. Step in carelessly and the shelves will still be polite. Step in attentive and they'll start to show you things.",
    ],
  },
  "great-hall": {
    kicker: "Where the school gathers",
    title: "The Great Hall",
    kind: "room",
    art: { src: "./assets/art/room-great-hall.jpg", alt: "Illustrated dossier of the Great Hall of the Academy" },
    body: [
      "The room the whole Academy pours into - feasts, announcements, the Day of the Living Literary Figures when Holmes deduced the menu, Alice critiqued the architecture, and Dracula objected to the lighting.",
      "A hall this size keeps a long memory of everyone who has stood in it. On quiet evenings it still seems to be listening for the next gathering.",
    ],
  },
  kitchens: {
    kicker: "A small warm kingdom",
    title: "The Kitchens",
    kind: "room",
    art: { src: "./assets/art/room-kitchens.jpg", alt: "Illustrated dossier of the Academy Kitchens" },
    body: [
      "Down past the proper rooms, the Kitchens keep a hearth that has never quite gone out and a brownie's worth of small magic in the steam. This is where courage is meant to be carried - into the cooking, the warming, the feeding of someone who needs it.",
      "Leave a saucer of cream where no one is watching and don't mention it. The oldest hospitality in my pages still lives down here.",
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
      "The Academy's professors don't agree on what a life is for, which is why their classrooms are worth entering. Each teaches one practical way to make the ordinary world vivid again.",
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
      "Every figure, place, and object in me is illustrated and annotated like a dossier - a parchment file with a signature object, a colour palette, a chapter mark, and a line in a real hand. This one is Professor Lydia Boggle, who teaches riddles, misdirection, and the sacred usefulness of nonsense.",
      "I don't summarise a person too quickly. A life is never only an office or a talent or the rumour that reaches the door first. The illustration is just where the ink begins.",
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
      loreLinkClicks += 1;
      if (loreLinkClicks % 3 === 0) {
        earnGlow(`lore-link-belief-${loreLinkClicks}`, 1, "Three golden lore links opened. The Book adds one Belief to your Glow.");
      } else if (glowSpendNote) {
        const left = 3 - (loreLinkClicks % 3);
        glowSpendNote.textContent = `${left} more golden lore link${left === 1 ? "" : "s"} and the Book adds Belief.`;
      }
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
