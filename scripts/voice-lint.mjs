#!/usr/bin/env node
// Holds LandingPage/ copy to the Book's own voice.
//
// The rules come from BookVoice.animism in Shared/LiteraryContinuity.swift,
// which is what the local Gemma writer is held to inside the app. The website
// is held to the same one. Prose in docs/landing-voice.md.
//
//   node scripts/voice-lint.mjs            lint, exit 1 on any error
//   node scripts/voice-lint.mjs --report   also print first-person coverage
//   node scripts/voice-lint.mjs --quiet    errors only, no warnings
//
// Two exemption markers, matching the two registers that are not the Book:
//   slip  exact, unvoiced fact — specs, privacy, licence, consent
//   cast  a named character speaking; they keep their own voices, and they
//         are allowed to call the Book "the Book", because they are not it
//
//   HTML   <!-- slip:start --> ... <!-- slip:end -->
//   JS     /* cast:start */ ... /* cast:end */

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, relative } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const args = new Set(process.argv.slice(2));
const REPORT = args.has('--report');
const QUIET = args.has('--quiet');

const TARGETS = [
  { path: 'LandingPage/index.html', kind: 'html' },
  { path: 'LandingPage/app.js', kind: 'js' },
];

// ─────────────────────────── the rules ───────────────────────────

const RULES = [
  {
    id: 'third-person-book',
    level: 'error',
    // "the Book of You" is the artefact's name, "Book Fae" a species, and
    // "Book Jumping" a page type. Those stay.
    test: /\bthe Book(?:'s|s)?\b(?!\s+(?:of You|Fae|Jump|Sprite|Wyrm|Remembered))/g,
    say: 'The Book never calls itself "the Book". Say I / me / my.',
  },
  {
    id: 'third-person-product',
    level: 'error',
    test: /\bReEnchanted\s+(?:is|isn't|has|have|treats|asks|keeps|offers|lets|gives|makes|does|doesn't|will|can|can't|turns|reads|writes|remembers|helps|uses)\b/g,
    say: 'The product described from outside. Let the Book speak for itself.',
  },
  {
    id: 'simile',
    level: 'error',
    test: /\b(?:as if|as though|seems? to|seemed to|almost as if|sort of like|kind of like)\b/gi,
    say: 'No similes, no hedging. The lamp leaned in. Full stop.',
  },
  {
    id: 'explainer',
    level: 'error',
    test: /\b(?:animism|animistic|anthropomorph\w*|folklore|symbolis\w+|symboliz\w+|symbols?|represents|personif\w+|the spirit of|we tend to see)\b/gi,
    say: 'Never explain the idea. The kettle is sulking; that is the whole sentence.',
  },
  {
    id: 'object-with-a-lesson',
    level: 'warn',
    test: /\b(?:reminds? (?:you|us) that|a reminder that|teaches (?:you|us)|stands for|a metaphor for)\b/gi,
    say: 'An object gets a mood and an errand, never a lesson.',
  },
  {
    id: 'product-speak',
    level: 'error',
    test: /\b(?:users?|seamless(?:ly)?|effortless(?:ly)?|leverage|utili[sz]e|robust|delightful|holistic|mindfulness|self-?care|wellness|onboarding experience)\b/gi,
    say: 'Brochure language. Say what actually happens.',
  },
  {
    id: 'therapy',
    level: 'error',
    test: /\b(?:it's okay to|it is okay to|be gentle with yourself|we understand that|you deserve|take care of yourself|no pressure|at your own pace|safe space)\b/gi,
    say: 'Never soothe, reassure, absolve, or bless.',
  },
  {
    id: 'tender-narrator',
    level: 'error',
    // The failure mode that survived the first pass: copy that is correctly in
    // first person and still completely wrong, because it is soothing. A voice
    // can say "I" and still be a gentle narrator instead of a half-feral one.
    test: /\b(?:I'?ll be gentle|be gentle with the|may I\?|if you'?d let me|if you let me|trying to be worth|I saved you a soft|I hope I can|I'?m trying not to|I understand that kind)\b/gi,
    say: 'Tender narrator, not feral child. It says "I" and still soothes. Cut the comfort.',
  },
  {
    id: 'soft-adverb',
    level: 'warn',
    // Legitimate in a named character's mouth, suspicious in the Book's.
    test: /\b(?:gently|softly|kindly|tenderly|sweetly)\b/gi,
    say: 'Check the speaker. The Book does not do adverbs like this; the Cast may.',
  },
  {
    id: 'greeting-card',
    level: 'warn',
    test: /\b(?:your journey|embrace the|find your(?:self)?|inner peace|live your best|magical experience|sprinkle of magic)\b/gi,
    say: 'Greeting card. Cut it and say the next true thing.',
  },
  {
    id: 'loose-like',
    level: 'warn',
    // "like" is legitimate as a preposition of example; flagged softly because
    // it is also the most common way a simile sneaks back in.
    test: /\b(?:looked?s?|felt|feels|sounded?s?|seemed) like\b/gi,
    say: 'Probably a simile wearing a coat. Make it happen instead.',
  },
];

// ───────────────────────── text extraction ─────────────────────────

// Replace a match with the same number of newlines so line numbers survive.
const blank = (text, re) =>
  text.replace(re, (m) => '\n'.repeat((m.match(/\n/g) || []).length));

function extractHTML(src) {
  let t = src;
  t = blank(t, /<!--\s*(slip|cast):start\s*-->[\s\S]*?<!--\s*\1:end\s*-->/gi);
  t = blank(t, /<(script|style|svg|noscript|title)\b[\s\S]*?<\/\1\s*>/gi);
  t = blank(t, /<!--[\s\S]*?-->/g);
  t = blank(t, /<[^>]*>/g); // drops alt=, meta content=, aria-label= with it
  return t
    .replace(/&amp;/g, '&')
    .replace(/&quot;|&#0?39;|&apos;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/&[a-z]+;/gi, ' ');
}

function extractJS(src) {
  // Markers may carry a trailing note after the keyword, e.g.
  // /* cast:start — Zara speaking */
  let t = blank(src, /\/\*\s*(slip|cast):start\b[^*]*\*\/[\s\S]*?\/\*\s*\1:end\b[^*]*\*\//gi);
  // Comments go first: an apostrophe in one ("don't") would otherwise open a
  // phantom string literal and swallow the code after it. The lookbehind keeps
  // "https://" out of it.
  t = blank(t, /\/\*[\s\S]*?\*\//g);
  t = blank(t, /(?<!:)\/\/[^\n]*/g);
  // Keep prose string literals; blank the code around them so identifiers,
  // CSS selectors, and URLs can't trip the rules.
  const out = [];
  const strings = /(['"`])((?:\\.|(?!\1)[\s\S])*?)\1/g;
  let last = 0;
  let m;
  while ((m = strings.exec(t)) !== null) {
    out.push(blank(t.slice(last, m.index), /[\s\S]+/));
    const body = m[2];
    const prose = body.length >= 24 && /\s/.test(body) && !/^[.#/]|^https?:/.test(body);
    out.push(prose ? m[0] : blank(m[0], /[\s\S]+/));
    last = m.index + m[0].length;
  }
  out.push(blank(t.slice(last), /[\s\S]+/));
  return out.join('');
}

// ─────────────────────────── the pass ───────────────────────────

let errors = 0;
let warnings = 0;

for (const target of TARGETS) {
  const full = join(root, target.path);
  let src;
  try {
    src = readFileSync(full, 'utf8');
  } catch {
    console.error(`voice-lint: cannot read ${target.path}`);
    process.exitCode = 1;
    continue;
  }

  const text = target.kind === 'html' ? extractHTML(src) : extractJS(src);
  const lines = text.split('\n');
  const hits = [];

  // `kind: "folklore",` is a taxonomy value, not something the Book said.
  // Bare single-token key/value lines carry no prose, so skip them.
  const dataLine = /^\s*[\w$]+:\s*["'`][\w-]+["'`],?\s*$/;

  lines.forEach((line, i) => {
    if (!line.trim() || dataLine.test(line)) return;
    for (const rule of RULES) {
      rule.test.lastIndex = 0;
      let m;
      while ((m = rule.test.exec(line)) !== null) {
        hits.push({ line: i + 1, rule, match: m[0], context: line.trim() });
        if (rule.test.lastIndex === m.index) rule.test.lastIndex++;
      }
    }
  });

  const shown = hits.filter((h) => !(QUIET && h.rule.level === 'warn'));
  if (shown.length) {
    console.log(`\n${relative(root, full)}`);
    for (const h of shown) {
      const tag = h.rule.level === 'error' ? 'ERROR' : ' warn';
      const snippet = h.context.length > 96 ? `${h.context.slice(0, 93)}...` : h.context;
      console.log(`  ${tag}  ${target.path}:${h.line}  [${h.rule.id}] "${h.match}"`);
      console.log(`         ${snippet}`);
      console.log(`         → ${h.rule.say}`);
    }
  }

  errors += hits.filter((h) => h.rule.level === 'error').length;
  warnings += hits.filter((h) => h.rule.level === 'warn').length;

  if (REPORT && target.kind === 'html') {
    // Which <section>s never once say "I"? Not fatal — some are pure Slip —
    // but a section with no first person is a section the Book didn't write.
    const sections = [...src.matchAll(/<section\b([^>]*)>([\s\S]*?)<\/section>/g)];
    const silent = sections
      .map((s) => ({
        id: (s[1].match(/\b(?:id|class)="([^"]+)"/) || [, '(unnamed)'])[1].split(' ')[0],
        body: extractHTML(s[2]),
      }))
      .filter((s) => s.body.trim().length > 200)
      .filter((s) => !/\b(?:I|I'm|I'll|I've|I'd|me|my|mine)\b/.test(s.body))
      .map((s) => s.id);
    console.log(`\n  first-person coverage: ${sections.length - silent.length}/${sections.length} sections`);
    if (silent.length) console.log(`  silent: ${silent.join(', ')}`);
  }
}

const plural = (n, w) => `${n} ${w}${n === 1 ? '' : 's'}`;
console.log(
  `\nvoice-lint: ${plural(errors, 'error')}, ${plural(warnings, 'warning')}` +
    (errors ? '' : ' — the Book sounds like itself.')
);
if (errors) process.exitCode = 1;
