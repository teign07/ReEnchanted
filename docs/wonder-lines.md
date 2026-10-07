# Wonder lines: what ordinary things want

The nightly braid (see `Shared/WonderBraid.swift`) gets its magic from authored lines: one or two plain
sentences about what an ordinary thing wanted or did. Gemma tells the reader's own words and carries these
lines; it does not invent the miracle (the 2B model can connect and follow, not invent).

## Where the lines live

- **Bundled base:** `scripts/braid_wonder/lines.json` is the source for the Mac lab; the same rows are in
  `WonderBraid.rows`. `WonderBraidTests.testTheSwiftLibraryMirrorsTheLabFile` fails if they drift.
- **Monthly updates (no app update needed):** a pack's `*.reenchantedevents.json` may carry two optional top-level keys:

```json
"wonderLines": [
  { "id": "oct26-001", "nouns": ["pumpkin", "pumpkins"], "line": "The pumpkin had been practising its face for a week." },
  { "id": "oct26-002", "nouns": ["dog", "dogs"], "needs": ["leaves"], "line": "The dog took the leaves very personally." }
],
"retiredWonderLineIDs": ["w123a"]
```

  A delivered line joins the library for as long as its pack is enabled. A line whose `id` matches a bundled line
  **replaces** it; `retiredWonderLineIDs` takes lines out. Older packs and older apps ignore the keys.
  `scripts/monthly_pack.py` checks them at preflight (`check_wonder_lines`); the app drops any line that breaks a
  promise instead of failing the pack's install.

## The promises every line keeps

- One or two short sentences, at most 32 words, ending in a full stop. About a **thing**, never the reader:
  the miracle belongs to the object. No `I`, `my` or `me` (the Book's voice is separate).
- Plain words a child would use; exact and physical; sometimes cozy, sometimes a little terrible.
- Never the banned words (`hinge`, `ritual`), never the stock list (shimmer, whisper, tapestry...).
- `nouns`: the words that fire it (plurals and -ed/-ing are matched for you; phrases with a space work).
  `needs`: optional; the line fits only when the page also carries one of these words (a stick for the dog).
- **Setting nouns** (window, floor, sofa, morning...) only speak when nothing on the page acts, so give an
  object that does something a line before you give a room one.
- A used line rests for three weeks (`wonder-line:<id>` tags on the braid), so write two or three per noun.

## Month by month

Write the month's lines to its themes (October: pumpkins, leaves, lanterns, fog, apples, wet coats). A good
month adds 30-60 lines, retires nothing unless a line proved flat, and replaces any that read badly.

## Note prompts (lined space in the printed books)

The weekly and monthly books leave lined space for the reader, each with a small invitation ("One sentence
about today, in your own words."). The bundled bank is `NotePrompts.bundled` in `Shared/HandbookPuzzles.swift`;
a monthly pack refreshes it without an app update, with two more optional top-level keys:

```json
"notePrompts": [
  { "id": "oct26-n1", "kind": "day", "text": "What did the dark come early for tonight?" },
  { "id": "oct26-n2", "kind": "puzzle", "text": "Write a riddle whose answer is a pumpkin." }
],
"retiredNotePromptIDs": ["np-d04"]
```

`kind` is `day` (foot of a day's page), `puzzle` (spare room on a puzzle leaf), `margin` (open margin on a lesson or worksheet) or `any` (the default). A pack's
own prompts are dealt before the bundled ones, so a new month reads like a new month, and a prompt is not asked
twice in one book. The same id replaces a bundled prompt; `retiredNotePromptIDs` removes one. `scripts/monthly_pack.py`
checks them at preflight (one short line, 12+ characters, max 24 words, ends in `.` `?` or `!`, no banned words);
the app drops a bad one instead of failing the pack.
