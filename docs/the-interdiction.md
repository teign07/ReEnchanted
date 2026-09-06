# The Interdiction

What the app would have to borrow from fairy tales to make its parts cohere,
written against the codebase on 2026-09-03 (`feat/reader-role-and-first-door`).

Companion to `docs/magical-book-simulator.md`. That one asked what videogames
know. This one asks what the older form knows, and reaches a sharper answer.

## The hypothesis under test

> The thing that brings this monster together might be the authored monthly
> content.

**Half right.** Authored monthly content is the correct vehicle. It cannot be
the thing in its current shape, because a season is currently *weather*.

## Finding 0 — the launch season is not scheduled to run

Report before design, because this one is operational.

- `dictionaryRebellion` is `recurrence: .oneShot, startYear: 2027`
  (`Shared/WorldEvents.swift:670`), pinned by
  `testDictionaryRebellionIsOneShotInSeptember2027`
  (`Tests/InsideCoverCoreTests/WorldSystemsTests.swift:885`).
- `WorldEventResolver.lifecycleSnapshot` guards `now >= foreshadowStart`.
  Foreshadow opens 2027-08-25, so nothing resolves in September 2026.
- The only other bundled event, `starlitPaperTrial`, ran May 2026 and is past.
- Both bundled packs are `availability: .locked`, requiring `PackEntitlements`.

So the launch month has no live authored season, and no free one.
`DICTIONARY_REBELLION_PLAN.md` still says *"target: Sept 2026"* and
*"Registered as a bundled, free pack."* Confirm whether 2027 is a decision or
drift.

The engine underneath did ship, and it is the deepest reader-to-world hook in
the app: `ReaderLexicon`, `WordNegotiation` rulings, `Treaty`, and
`readerLexicon.languageLawSection()` feeding the model prompt
(`Shared/InsideCoverStore.swift:920`). The reader's rulings change how the Book
speaks.

## Finding 1 — a season is weather

`EventInfluencePacket` carries `atmosphere`, `storyInstruction`,
`classInstruction`, `letterInstruction`, `bleedInstruction`, `radioInstruction`,
`widgetWhisperLine`, `visualTreatment`. Every field instructs an existing
surface to change colour. `effects` are score boosts. `WorldEventOutcome` grades
on `minimumTouchCount`.

A season changes the light on everything without changing what anything is.

`DICTIONARY_REBELLION_PLAN.md` diagnosed exactly this — *"they measure how much
the player engaged, not which way they ruled"* — and fixed it with the Treaty.
The fix works. It does not generalise: it is a bespoke ruling system, not a
shape any month could take.

## Finding 2 — nothing is ever forbidden

Grepped. **Nothing in this app forbids the reader anything, ever.** The only
`.forbidden` states run the other direction — `Shared/GrimoireSweep.swift:903`,
*"the reader shut this door."* The reader forbids the Book.

`TaleGrammar` has a `.transgression` beat and a `forbiddenDoor` shape, but both
are recognised retrospectively from tags (`Shared/TaleGrammar.swift:164`, `:181`).
The file header is honest: *"It is a witness... nothing here invents an event."*

This is the gap. Don't open the thirteenth door. Be home by midnight. Don't look
back. Don't ask his name.

**A fairy tale is not a shape noticed afterwards. It is a shape you are caught
inside, and what catches you is a rule stated before you can break it.**

One sentence to author. It retroactively charges every moment after it. All the
machinery to enforce and pay it off already exists — laws (`FaeLaw`), prices
(`TaleBeat.price`, Belief costs), scars (`TaleScar`), consequences
(`StoryConsequenceLedger`), and a witness that reads them all. What is missing
is the thing at the front that makes any of it matter in advance.

Everything in this app is priced after the fact. Fairy tales price before.

## Finding 3 — two smaller absences of the same family

**The bargain has no teeth.** Offered on the desk, owed only when tapped;
swiping costs nothing. Correct consent design, and it should stay. But the
fairy-tale version is compatible with it: Rumpelstiltskin is not tricked — she
*agrees*, and the horror is that she agreed. A named price the reader takes
anyway is more frightening than a free refusal, and no less consensual.

**There is no return.** `TaleBeat.ret` is the payload of the whole form, and the
Book has no ordinary world to return anyone to — everything is the Book.
`BookJumpEngine` is the one system with a real outside and inside, because
`returnReward(depth:hasSouvenir:)` pays nothing unless something comes back.
That is the model.

## The thing

**A season is one authored tale-shape the reader is inside, not weather they are
under.**

`TaleShape` has ten patterns. Today the Book waits to recognise one by accident.
Instead a season picks one deliberately and runs it:

| Stage | Length | What it is |
|---|---|---|
| Foreshadow | 7d | **The interdiction.** One sentence, the Book's voice, addressed to the reader. Not a task — a prohibition. |
| Live | 30d | The rule is breakable, and breaking it is the design. `GrimoireSweep` already scans the reader's own writing, so a lexical interdiction is trivially detectable. On break: no shame, no punishment — a consequence, immediately, in world. |
| — | — | **The price, named up front, exacted at the end.** Not `minimumTouchCount`. Something the reader agreed to lose. |
| Residue | 7d | **The return**, with `TaleScar` making the change permanent and un-undoable. Already exactly right. |
| Casebook | — | The tale bound and told back. Already built. |

### What this welds together

- Authored content supplies the interdiction and the price.
- `TaleGrammar` witnesses the beats **as they happen** instead of waiting to
  notice a shape by accident.
- `TaleScar` makes the ending stick.
- `ReaderLexicon` / `StoryConsequenceLedger` carry it forward past the season.
- `FaeLaw` judges the payment by a law that is coherent and *not the reader's*.
- The Curator already boosts on `WorldEventEffect`.

### The commercial corollary

Nobody subscribes to a season for more content. They subscribe because **each
season leaves a scar, and they want to know what it will be.**

## Constraints this must not break

- **Consent is not negotiable.** The interdiction is stated plainly, in advance,
  and breaking it is never punished — only answered. The Director's law holds:
  the Book may be cunning about timing, never about consent
  (`docs/living-book-director.md`).
- **No shame.** A broken interdiction is plot, not failure. The reader who
  breaks it should get the more interesting month, not the poorer one.
- **The pressure ceiling still applies.** Invite / Nudge / Call me on my
  nonsense governs how hard the interdiction may press.
- **Hard days suppress.** An interdiction consequence is an intervention and
  obeys the same suppression as a commissioned Page.
- **The reader may always shut the door.** `GrimoireSweep`'s `.forbidden` is
  permanent and outranks any authored season.

## First slice

Do not build a new season. Give the *existing* Dictionary Rebellion an
interdiction — one sentence in foreshadow, one detectable break, one consequence
Page, one scar at residue — and see whether the month reads differently.

If it does, every future season gets the same five parts, and the authored
content finally has a shape rather than a palette.
