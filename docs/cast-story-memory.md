# The Cast remember the month

October 6, 2026. Moonshot: the Cast remember what happened to them in the
monthly story pages.

## The gap

A kept monthly scene is a `.narrativeOS` Page with no `entity:` tags. Nothing
in the keep path turned it into a memory, so Wicker could write a verb into
Dracula on Sunday and forget it by Monday. The per-character store that
letters, notes, Story Pages and the Cast page read (`NarrativeEntityMemory`)
never heard of October. Even if it had, it's a 240-row recency window, and a
month of ordinary keeps would push the story out.

## The design

**Authored, not inferred.** Every memory is written beside its moment in the
pack, as `castMemories: [AuthoredCastMemory]`:

| Where | Earned when |
| --- | --- |
| `AuthoredStoryScene.castMemories` | the reader completes a scene with no nodes |
| `AuthoredStoryNode.castMemories` | the reader finishes that node (`nodeCompleted`) |
| `AuthoredStorySceneChoice.castMemories` | the reader commits that choice |
| `WorldEventRecordEntry.castMemories` | the entry is public (`knownFromDay`), whether or not the reader came |

Each memory has an `entityID`, a `key`, a plain third-person `memory`, and an
optional `aside`: the same moment in the character's own mouth, said some days
later. The `key` names the moment across the whole story. A scene and a record
entry can share one, and then the reader's version replaces the rumour.

**Two witnesses.** `withReader` is what the reader was there for. `lived` is
what happened in the story anyway, released from the dated record no earlier
than it's public, so the Cast never spoil the month.

**Frozen.** `CastStoryMemoryLedger` lives in the vault and travels in exported
saves. The pack retires at residue end and the Cast don't forget with it. A
rewritten pack can't change a frozen memory. Only a `lived` memory gives way,
to the reader's own version of that moment.

**One harvest.** `CastStoryMemoryHarvest.memories(source:receipts:lifecycle:now:)`
is pure and idempotent. It reads the authored receipts the keep path already
writes, plus the dated record. `ContentView.tendCastStoryMemories()` runs it
after every Keep and whenever the monthly catalog loads (at least once a day),
and absorbs anything new. Readers who played October before this shipped get
backfilled on first launch, while the pack is still installed.

## Where the memories come out

1. **The Cast page.** "What happened to them" shows up to five moments, newest
   first: the aside in quotes, the plain fact underneath, and "You were there"
   when it's the reader's version. The story isn't repeated under "What stuck".
2. **Every prompt that reads the Cast's memory.** `CastStoryMemoryProjection`
   folds the ledger into `inputs.narrative.entityMemories` at read time, tagged
   `cast-story`, so letters, student notes, Story Pages and deep-bond gating hear
   it with no new plumbing, and the 240-row cap can't push it out. Nothing is
   written to the archive.
3. **The Keep margin.** `CastStoryAside.pick` lets one Cast member say one
   aside a day. It waits 18 hours after the moment (the scene already spoke),
   expires after 21 days, says each aside once, and never fires on the scene
   being kept or on a distress day. Someone on the Page being kept goes first,
   and the reader's own moments go before the ones they heard about. Its
   precedence is just below the word echo and above the chosen quill and the
   ordinary living note.
4. **Later scenes, across months.** `AuthoredStoryNode.recalls:
   [AuthoredCastRecall]` puts a marker in the body. The first option whose key
   is remembered fills it (by a named Cast member or by anyone); otherwise the
   fallback does, and that may be empty. This is what lets November's Serenity
   remember the reader sat by her map in October. It requires runtime 11, and
   both validators check the marker and the options.

## October's memories

164 memories in 89 places, 157 with asides. Seven people remember things:
Serenity, Wicker, Ambrose, Penny, Permancer, Villanelle and Soren. Every Cast
member listed on a scene remembers something from it (tested). Three cast lists
were short of who was actually in the room: Wicker on the wrong-way stair and at
the Nightbound breakfast, and Ambrose in the East Stacks. They're added, so the
map moves too.

`CastStoryMemoryAudit` is the authoring contract (`CastStoryMemoryTests`):

- the Cast member must be known and in the scene's cast;
- a record memory must belong to somebody the account names;
- memories run 5 to 45 words and never address the reader as "you";
- asides run 4 to 34 words and are contracted;
- none of the triangle words, no "hinge", "ritual" or "forgive";
- record memories may not carry a fact before the record makes it public.

The asides keep the triangle unsettled. They're each person's own frame and
never a verdict ("She used the case. Closed it, click. Nodded at me. A whole
nod. I'm not making anything of it.").

## Second-hand: the news gets round (October 7)

A third witness, `heard`. `CastStoryGossip.spread` works from the ledger alone,
so news keeps travelling after a pack retires. It's pure and idempotent like the
harvest, and runs inside `tendCastStoryMemories()` after it.

- **Only news spreads.** A moment travels only if its memory carries an
  authored `gossip` line. October has 36 of them on 58 memories: the bread, the
  verb in Dracula, Ambrose putting his ladle down, the toast tower named
  Permancer, Sir Fluffington. Each line starts `{teller} says`, so anyone in the
  Cast can say it.
- **A bystander tells it.** The teller is somebody who was there (on the
  scene's cast, or holding the moment first-hand) and isn't named in it. Wicker
  never goes round telling people what Wicker did: Ambrose, who served the soup,
  does. With no bystander, it's "Everyone says…".
- **One hop.** Whoever only heard it never passes it on.
- **Two ears per moment,** a day or two after it happened (one day at least),
  never someone who was there or someone the news is about. Closeness to the
  teller (authored ties plus the live relationship field) counts, halved and
  capped, against a stable bit of luck. Anyone already holding a lot of news
  loses two points per item, so the month spreads round. A simulated October
  reached 21 different Cast members, nobody more than three times, including
  ones who were never in the story.
- Hearsay is the weakest witness. A later first-hand or record memory of the
  same moment replaces it. The Cast page says "Heard from Ambrose" (or
  "everyone"); prompts read "heard from Ambrose"; a heard aside can be said in
  the margin, ranked after first-hand ones.

## Let's Chat reads it (October 7)

`LetsChatCastMemory` lets a message that names a Cast member pull in what they
carry. It matches given names, or surnames for professors ("Has Permancer heard
about it?"), and takes at most two people with four memories each.

- **A direct question** ("what does Wicker remember?", "what's happened to
  Serenity?", "has Penny heard…") is answered straight from the ledger in the
  Book's voice, before any archive search: up to three moments with their
  asides, "You were there for that one", or "Wicker wasn't there. Ambrose
  told." Somebody with nothing yet: "…hasn't told me anything from the story
  yet."
- **Any other mention** gives Gemma a "WHAT WICKER EDDIES REMEMBERS FROM THE
  STORY" section, with each line marked by who witnessed it. The model may pass
  these on in its own words, but not add to them, and says the person hasn't
  told it anything beyond what's there. The section is small and authored, so
  the budget never cuts it.

## Release

The pack bytes changed again on October 7: `issue.json` runtime is now v8. The
unpublished v7 candidate was moved aside to
`2026-10-count-unbound-superseded-2026-10-07-v7`. The signed candidate is
`~/.reenchanted-publishing/releases/2026-10-07-count-unbound-2026-10-candidate`,
with 1 new asset out of 37. Publish it with `scripts/ship_release.sh`. Old apps
ignore the new keys. October still asks for runtime 10. Memories, gossip and
the chat need the new app build.

## Not built yet

- **Asides in Gemma's hands.** The deterministic aside is the floor. On device
  the brain could vary it, or answer a letter with it, under the existing
  echo-guard.
- **November recalls.** The mechanism is live, but there's no content until the
  November scenes are written. Every continuing monthly story should author
  `castMemories` (and `gossip` on its best news) and use `recalls` for
  callbacks.
- **Gossip that changes people.** Hearing news could nudge the relationship
  field (Damien hears about the bread and gets ideas). Kept out deliberately for
  now: gossip informs, it doesn't act.
