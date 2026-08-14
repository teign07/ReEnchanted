# Posting business to the Academy

A folio can add business for the Cast to already be in the middle of. A ladder
posted by a pack is the *same object* as one compiled into the app, so it gets
the serial, the world-pressure fingerprints, the Radio band, doors, and the
monthly binding without any parallel path.

## Where it goes

Drop a `*.reenchantedpack.json` into the app's Documents folder (Files app), or
add an `UndertakingLadder` to a bundled `PageArchetypePack` in
`Shared/PagePacks.swift`. Both routes land in the same registry via
`PageArchetypePackRegistry.installUndertakingLadders()`, which runs on the
world-clock pass rather than at launch.

## The shape

```json
{
  "id": "nocturne-folio",
  "displayName": "The Nocturne Folio",
  "version": 1,
  "author": "The Goblin Index Empire",
  "availability": "userImported",
  "archetypes": [],
  "undertakings": [
    {
      "id": "nocturne-the-lamp-that-lied",
      "actorID": "serenity-brown",
      "title": "The Lamp That Lied",
      "pursuit": "Find out which of the night lamps is reporting a street that is not there.",
      "why": "Serenity does not mind being misdirected. She minds being misdirected kindly.",
      "castIDs": ["serenity-brown", "wicker-eddies"],
      "eventID": null,
      "stages": [
        {
          "id": "the-count",
          "line": "Serenity counts the lamps on the west walk and gets a different number going back.",
          "trace": "A tally chalked on a wall, with one mark added in a second hand.",
          "tags": ["place", "night", "route"],
          "scene": "Serenity is halfway back along the walk when she stops.\n\n\"Eleven,\" she says.\n\nWicker, behind her, is not paying attention. \"You said twelve.\"\n\n\"Going out I said twelve.\"\n\nThey both turn round and look at the walk, which is straight, and lit, and has no corners in it at all.",
          "deniability": "I counted twice. Both counts were correct. That is the problem.",
          "surface": "witnessedScene",
          "castIDs": ["wicker-eddies"]
        }
      ]
    }
  ]
}
```

## Fields that matter

| field | what it does |
|---|---|
| `line` | the ledger sentence. Quoted by the Academy dispatch, room incident records, and pressure summaries. Keep it flat and factual. |
| `scene` | what the Page prints. Drop in late, one place, turn near the end, cut immediately after. 25–250 words. |
| `trace` | the residue. Required. It is fingerprinted onto the Bleed for a week and closes the Page **unlabelled**. |
| `deniability` | what the character says when it is put to them on the record. Reaches the Radio margin band. Optional — silence is a choice. |
| `surface` | `witnessedScene` (default), `letter`, `note`, or `storyPage`. Unknown values degrade to a scene rather than vanishing. |
| `castIDs` | everybody else in the beat. This is what makes a crossing visible to the systems that spend consequences instead of only to the prose. |
| `door` | optional errand into the reader's real day. Becomes a Playful Mission hosted by the character. |
| `eventID` | binds the business to a monthly world event. While that event runs, the ladder advances faster and the desk prefers it. Outside a run it behaves like any other business. |
| `phaseID` | on a **beat**: narrows it to one phase of that event. A hold, not a lock — see below. |

## Phase binding

A beat with a `phaseID` waits for its phase, so it lands in the right week of a
live event. The hold only applies while the event is **actually running**: for an
archive reader, or an event that never came round, it lifts and the beat is
ordinary. Stranding somebody permanently partway up a ladder would be a worse
failure than a beat arriving out of season.

The shipped example binds its five beats across `omen → outbreak → outbreak →
assembly → afterimage`, so the staircase argument opens as the words start
slipping and the verdict lands after the Treaty settles.


## Rules the tests enforce

These are checked in `UndertakingMicrodramaTests`, so a bad ladder fails at
authoring time rather than in someone's hands:

- Every beat leaves a `trace`.
- No scene explains its own significance (`"Left behind:"`, `"which is
  significant"`, `"little did"`…).
- No scene or deniability line assigns the reader anything. A beat that ends
  "bring me one" is an errand — put it in `door`, which is allowed to ask.
- Scenes stay between 25 and 250 words.
- Doors stay rare — at most one beat in six.
- `castIDs` may only name characters the reader actually has. A **core** ladder
  may never structurally name a character who lives behind an entitlement;
  prose may mention anyone, but a castID is resolved by the consequence
  systems. A pack ladder may name its own pack's cast, because it is enabled
  exactly when they exist.

## Two things that are deliberately hard

**A ladder seeds once, ever.** Its scenes are a finite piece of history, not a
renewable template. A successor must enter as genuinely new business with new
beat IDs, or the story-identity guard will treat it as already read.

**A pack cannot overwrite the core season.** `install` refuses any ladder whose
ID collides with a `core-*` one, so a paid folio can never rewrite free business
out from under a reader who is partway up it.

## What you get for free

Once a ladder is installed: it advances on the world clock (1–4 days per beat,
14% chance of going cold), leaves marks on five surfaces for a week, serializes
so a reader follows one thread rather than meeting ten at random, backfills
beats they missed rather than skipping them, opens its doors only after the
scene has been read, and binds into the monthly edition when it concludes.
