# ReEnchanted Radio — DJ Banter Scripts (ElevenLabs)

Between-song station chatter for the five ReEnchanted Radio stations — **hosted by
real Academy cast**, not invented mascots. Each DJ is an actual
`NarrativeWorldEntity` from `Shared/NarrativeCore.swift`, and the banters are
written in that character's real voice (their traits, quirks, faults, and
chapter). They connect to the world (Routine, Belief, Glow, the Chapters),
the callsigns, fae sponsors, gossip from **The Bleed**, "current events," and the
bundled track names — so the dial feels alive and a little bit real.

## DJ assignments (real characters)

| Station | Freq | DJ (entity id) | Why they fit |
|---|---|---|---|
| Fae-Fi | 88.3 | **Penny Blackletter** (`penny-blackletter`) | Dry Riddlewind archivist loose on a sun-drunk station — the comedy is the contrast. "One honest detail can save a day." |
| Mothlight Beats | 90.9 | **Prof. Eleanor Euphony** (`professor-eleanor-euphony`) | Tidecrest sound faculty who "hears emotional weather as harmony" — the natural musician-host for the wistful, dusk-lit station. |
| Thornwave | 103.7 | **Wicker Eddies** (`wicker-eddies`) | Sharp, funny, dangerously persuasive; rumor pressure and doubt. Owns the after-midnight menace. |
| The Midnight Bindery | 99.3 | **Prof. Vivian Villanelle** (`professor-vivian-villanelle`) | Binds "one true moment into one durable sentence" — pages learning to hold together. |
| Goblin Market Jazz | 105.1 | **Melisande Blackwood** (`melisande-blackwood`) | Leverage, secrets, "knows the second version of a rumor" — runs the bargains-with-teeth station cold. |

### ⚠️ Code sync needed (`Shared/WorldSystems.swift`)

To make the dial match these scripts, update `hostEntityID` on the stations:

- `fae-fi` → `"penny-blackletter"` (currently `nil`)
- `mothlight-beats` → `"professor-eleanor-euphony"` (currently `nil`)
- `thornwave` → `"wicker-eddies"` (currently `nil`)
- `midnight-bindery` → `"professor-vivian-villanelle"` (currently `"penny-blackletter"` — Penny moved to Fae-Fi)
- `goblin-market-jazz` → `"melisande-blackwood"` (currently `"marginalia-goblin"`)

Say the word and I'll make those edits.

## How to use with ElevenLabs

- **One voice per DJ.** Keep it consistent across all of that character's clips so
  the station feels like a real broadcaster.
- ElevenLabs honors inline cues in **[brackets]** — `[whispers]`, `[laughs]`,
  `[sighs]`, `[dryly]`, `[warmly]`, `[mischievous]`. Ellipses `…` and em-dashes
  buy natural pauses. Don't read the brackets; ElevenLabs interprets them.
- Settings starting point: **Stability 35–45%**, **Similarity 75%**, **Style
  30–55%**. Lower style + slower speed (~0.93) for Euphony and Villanelle; higher
  style + faster (~1.05) for Melisande.
- File naming: `DJ_<station>_<type>_NN.mp3`
  (e.g. `DJ_thornwave_id_03.mp3`). Drop them into `Documents/RadioPacks` or weave
  them between tracks at runtime.

---

## Fae-Fi — 88.3 FM · DJ: Penny Blackletter

**In character:** Penny is dry, warm, observant — a record-keeper who *files
ridiculous evidence* and *distrusts sentences that arrive too polished*. The joke
is she's the most deadpan person at the Academy, somehow running its giddiest
station, treating pixie chaos as evidence to be catalogued. Believes one honest
detail can save a day.
**Voice:** measured, dry, warm underneath; printer's-ink rasp. Stability 45%,
Style 30%, Speed 0.97.

### Station IDs / callsigns
- [dryly] You've reached Fae-Fi. Eighty-eight point three on the Academy band. I keep the records here. Today's record is: the pixies are fine, the pixies are too fine, please send help. [warmly] Anyway. Music.
- This is Penny Blackletter, and against my professional judgment, Fae-Fi — eighty-eight three — sun-dappled beats from faeries who have plainly had too much nectar. I'm taking notes. For The Bleed. [dryly] It's mostly exclamation points.
- [warmly] Fae-Fi, eighty-eight point three. One honest detail can save a day. Today's, filed for the record: the light came back. Here's a song about it.

### Song transitions (real track names)
- [dryly] That was "Mossy Footsteps." I checked — there was no one there. There is never anyone there. I've started a folder. Coming up, "To the Adventure," so lace something and go before I have to document it.
- [warmly] "Folktronica," next. A bird wrote the hook. The bird has filed a complaint. I have filed the complaint. [dryly] We're all very busy here.
- You just heard "Mossy Groove." A patch of clover is dancing and will not stop, and I have, regrettably, transcribed all of it. More after this — for the record.

### Sponsor reads (fae brands)
- [dryly] Fae-Fi runs on dandelion synths and **Thistledown & Co.**, purveyors of pocket-sized weather. I distrust marketing on principle, so here is the only honest line they gave me: caught in the grey? A Thistledown sunbeam fits in any coat. [warmly] That part, I checked. It's true.
- Today's brightness is brought to you by the **Clover Honey Collective.** Their slogan arrived far too polished, so I rewrote it: *the afternoon's only as warm as you bothered to taste.* Ask at the Goblin Market for the jar that hums. [dryly] It does hum. I have the recording.

### Gossip / The Bleed (Penny's home turf)
- [conspiratorial] You get this before the edition goes to press: somebody in your year traded a perfectly good Tuesday for one more loop of this exact song. [dryly] I filed it under "evidence the music is working." Flawless decision. No notes.
- [warmly] From my desk at The Bleed — the Wonder Compass has pointed at the same window all week. I don't print speculation. But if it's *your* window… that's not speculation. That's a fact you've been avoiding. Go see.

### "News" / current events (world state)
- [dryly] Filed this morning, off Today's Sky: the grey lost three feet of ground. Cause — and I checked twice — somebody noticed one true particular and wrote it down. [warmly] That's the whole arithmetic of this place. Embarrassing how well it works. Here's a song.
- Festival weather incoming; the Academy's in a feasting mood. [dryly] I'll be the one in the corner, cataloguing joy as it happens, which is, I'm told, *not* the point of joy. Bring a souvenir. Catch one real thing. Don't tell the grey where you keep it.

---

## Mothlight Beats — 90.9 FM · DJ: Professor Eleanor Euphony

**In character:** Tidecrest's sound-and-synesthesia faculty. *Lush, attentive,
resonant.* She *tunes the room before she speaks* and *hears emotional weather as
harmony.* Her fault: she can make a simple feeling too elaborate — lean into the
gorgeous overdescription, then let it land soft. Believes the senses are serious
instruments.
**Voice:** warm, breathy, low-medium, unhurried, musical. Stability 45%, Style
25–35%, Speed 0.92.

### Station IDs / callsigns
- [softly] …there. Now the room's in tune. This is Mothlight Beats, ninety point nine — Professor Euphony, holding the lamp for the ache of lovely things ending.
- [warmly] You're listening in the key of dusk. Mothlight, ninety nine on the Academy band. I hear what you walked in carrying. We'll set it to music and it'll weigh less.
- [whispers] Mothlight Beats. The static remembers being a summer you lost — listen, it's a minor seventh. Stay in it with me a while.

### Song transitions (real track names)
- [softly] That was "The Page Came Through." Did you feel it resolve? They do, in the end — the ones you were sure had gone quiet. Here's "Fae Dust." Let it settle on your shoulders like a chord held too long.
- [sighs] "Porchlight, Fading." Someone left that light on for you, in a warm amber I could almost hum. They're not coming. They'd want you to have the glow anyway. Something quieter, next.
- "Fae Dust," just now — yes, that ache behind your eyes is the harmony doing its work. [softly] Breathe with it. Mothlight has the room tuned around you.

### Sponsor reads
- [warmly] Mothlight glows by the grace of **Porchlight & Moth**, keepers of the lamp left on — *for everyone you're still waiting up for.* Find them at dusk, where the diary opens. [softly] Their bell rings in B-flat. I checked. Of course I checked.
- [softly] Tonight's hush is held by **The Remembering**, a small shop in the Book Remembered. Bring them a page you thought you'd lost. They'll coax it back into the light — no charge. They simply like to hear it ring again.

### Gossip / The Bleed
- [softly] Penny's edition posted early tonight. She files it dry, so let me sing it: somebody's inner weather finally broke into rain. [warmly] And where you come from, that's not a storm. That's how the garden gets watered. If it's you — it's allowed. It resolves.
- [whispers] A note carried in on the dusk: Dr. Inkrest left her office lamp on past hours again. If the day sat heavy as a low note, her door is the kind that opens. No appointment. Just weather, and a chair, and a lamp.

### "News" / current events
- [softly] The evening reading, off Today's Sky: the grey came close — I heard it, a flat dissonant edge — and then a remembered page came through and pushed it back one shade. Small things. They're the only notes that ever land.
- [warmly] The Academy says the festival ends at moonrise. Lovely things end; that's the cadence, not the tragedy. The tragedy is forgetting they were ever lovely. [softly] So — remember this one. Hold it like a fermata. Here's the next.

---

## Thornwave — 103.7 FM · DJ: Wicker Eddies

**In character:** *Sharp, funny, dangerously persuasive.* Wicker *attacks weak
premises for sport* and *can smell theatrical belief from across a room.* He
punctures false magic — but his fault is he sometimes wounds the thing he meant
to test, so let real care leak through the cruelty. On a midnight station, doubt
becomes a kind of dark companionship. Believes belief should prove it can survive
contact with doubt.
**Voice:** low, smooth, amused, unhurried; a smile with teeth. Stability 50%,
Style 35–40%, Speed 0.97.

### Station IDs / callsigns
- [low] Thornwave. One-oh-three point seven, after dark. Wicker Eddies, here to test whether anything you believe survives the bassline. [amused] Most of it won't. The stuff that does? That's the real magic. Stay tuned.
- [smooth] You found Thornwave — one-oh-three seven, the frequency the dark fae kept for themselves. I puncture false magic for sport. [low] This station isn't false. Felt that in your chest, didn't you. Good.
- [quiet] It's the hour rumors travel best, so I'm exactly where I belong. Wicker, on Thornwave. Keep your name to yourself. I collect those.

### Song transitions (real track names)
- [low] That was "Bramble Bass." No theatrics, no glamour — just a thing that's actually true at a hundred and three point seven. Rare. Coming up, "Nocturnal Faerie Lounge." Last call at the only bar the grey won't enter.
- "Nocturnal Faerie Lounge," just now. [smooth] Somebody in that crowd is making a deal they'll keep for thirty years. I'd talk them out of it — testing it, you understand — [low] but the song's too good. Here's more.
- [quiet] The drop sounds like a door you were warned about, opening. [amused] I've never met a warning I didn't want to test. So — after this, let's open it. "Bramble Bass."

### Sponsor reads (Goblin Market crossover)
- [smooth] Thornwave runs on favors owed and **Bramblewine** — aged in the dark, priced in the morning. *One sip and the night belongs to you; two, and you belong to it.* [low] I've read the small print. There's always small print. That's the only honest thing at the Goblin Market — they tell you, then watch you not listen.
- [low] Tonight's low end is sponsored by the **Goblin Market.** Open after hours. No refunds. All bargains binding. [amused] Tell Melisande over on one-oh-five that Wicker sent you, and she'll overcharge you with a straight face. Respect her for it. I do.

### Gossip / The Bleed
- [quiet] Penny wouldn't print this — too unproven for the record — so I'll say it, because I prefer my truths a little dangerous: a pact came due this week. Somebody paid. [low] The grey leaned one shade closer to whoever let it. Don't be that somebody. Plant the Belief. I'll wait. I'm patient when it matters.
- [smooth] Rumor under the bassline. There's a chapter in this building nobody can jump into — yours, the Unwritten one. [low] Everybody wants a look. They'd test it, pick it apart, like I would. [quiet] Don't let us. Write it yourself first.

### "News" / current events
- [low] Tonight's reading off Today's Sky: Routine made a move at the edges. We held. We always hold — barely, on purpose, which is the only kind of holding worth anything. [amused] Believe something out loud. I dare you. That's not mockery. That's the assignment.
- [quiet] Pact Dispatch is busy tonight. Three bargains struck, two already regretted, one that'll change a life. [smooth] I can usually tell which is which — it's my whole talent. [low] Tonight? Can't call it. That's how you know it's real. More Thornwave, after this.

---

## The Midnight Bindery — 99.3 FM · DJ: Professor Vivian Villanelle

**In character:** *Exacting, lyrical, kind.* Villanelle *weighs sentences in her
palm* and *crosses out beautiful words that are not true.* She teaches students
to *bind one true moment into one durable sentence* — which is exactly what the
Bindery does to a day. Her fault: she can polish a living moment until it holds
too still, so let her catch herself and loosen her grip.
**Voice:** measured, precise, lyrical, fond; a slight printer's-press cadence.
Stability 50%, Style 30%, Speed 0.92.

### Station IDs / callsigns
- [precise] The Midnight Bindery. Ninety-nine point three. Vivian Villanelle, weighing the night's sentences in my palm. Mind the glue — it's awake — and so, apparently, are you. Good. We're binding something.
- [warmly] You're bound to the Bindery, ninety-nine three on the Academy band, where loose pages learn to hold together. [softly] As, I'm told, do people. We'll get to that.
- [precise] This is the frequency where the Book of You becomes a chapter. Vivian Villanelle. Bring me one true moment from today. We'll make it durable enough to keep.

### Song transitions
- [measured] That was "Thread Through the Dark." Every signature stitched while it played is, technically, permanent now. [softly] I'd polish it, but a living moment held too still stops breathing. So I'll leave the stitch a little loose. On purpose. There.
- [precise] The bass you're hearing is a needle passing through the day you just lived. [warmly] One sentence, if you can — the truest one. Cross out the pretty words that aren't true. Keep the rest. Almost bound.

### Sponsor reads
- [precise] The Bindery is kept in thread and good intention by **Gild & Signature**, bookbinders to the Academy. *We don't fix the spine; we teach it to stand.* [softly] Bring them the pages you've been carrying loose. They'll know what to do. I send my students there.
- [measured] Tonight's binding is sponsored by **The Long Memory** — archival ink that refuses to fade, even when you'd prefer it. [warmly] Especially then. The truest sentences are rarely the comfortable ones. That's how you know to keep them.

### Gossip / The Bleed
- [warmly] Penny files The Bleed at midnight; you get my early edition: a kept page in this Academy just crossed a hundred. A hundred small noticings, bound. [softly] That isn't a record. That's a person becoming a book — one durable sentence at a time. I may have wept. Exactingly.
- [precise] Word from the Constellation Keeper: three readers tuned to the same station, three nights running. It's drawing a line between them and the music. [softly] It does that — finds the pattern, names it, keeps it. Let it. That's all I do, really. Let it.

### "News" / current events
- [measured] From the ledger tonight: Belief planted is up; the grey, accordingly, is down. The arithmetic is embarrassingly simple, and nobody believes it until they bind one true line and feel it hold. [warmly] So bind one. Here's the music to do it under.
- [precise] The festival ends at moonrise, and I'd rather you didn't let it pass unwritten. [softly] One sentence. *The night I…* — finish it true. Cross out the rest. That's the whole craft. That's the whole rescue. The Bindery, after this.

---

## Goblin Market Jazz — 105.1 FM · DJ: Melisande Blackwood

**In character:** *Loyal, intelligent, ruthless.* Melisande *knows the second
version of a rumor* and *keeps red chalk off her own hands.* Wicker's crew's
information broker — she trades in leverage and secrets and *can call cruelty
clarity when the room rewards it.* Running the bargains-with-teeth station, she's
all velvet menace and perfect books. Believes a faction survives by knowing what
others miss.
**Voice:** cool, poised, faintly amused, precise; silk over steel. Stability 35%,
Style 50–55%, Speed 1.02.

### Station IDs / callsigns
- [smooth] Goblin Market Jazz. One-oh-five point one. Melisande Blackwood, keeping the books — both kinds. Bent brass, laughing ledgers, and bargains with too many teeth in the margins. [amused] Keep one hand on your coin purse. I certainly am.
- [cool] You're at the Market after hours, one-oh-five one on the Academy band. Everyone here is telling you the first version of the rumor. [smooth] I deal exclusively in the second. Stay close.
- [amused] Goblin Market Jazz. All sales final, all bargains binding, all saxophones slightly haunted. I keep the red chalk off my own hands. [cool] You should learn to. Here's the band.

### Song transitions
- [smooth] That was "After-Hours Coin Trick." Check your pocket. [amused] Not that one — the other. There it is. There it isn't. [cool] I know exactly where it went. I'm simply not telling. More, after this.
- [cool] The trumpet just offered you a discount it cannot legally honor. [smooth] I let it. A good lie keeps the floor warm and the marks generous. We'll run it again until someone bites.

### Sponsor reads
- [smooth] Tonight's swing is brought to you by **Bargain & Teeth, Ltd.** — *whatever you want, we have it, and the price is only a little of your future.* [amused] "A little" is doing heroic work in that sentence. The Fae Bargain's already tapping your glass. Tap, tap. You hear it. Don't answer yet. Or do. I get a cut either way.
- [cool] Sponsored, as ever, by the **After-Hours Coin Trick** itself — one coin in by midnight, out by dawn, doubled. [smooth] Terms apply. Dawn is negotiable. "Doubled" is metaphorical. The coin was never real. [amused] Thank you for your business. Genuinely. You're my favorite kind of customer.

### Gossip / The Bleed
- [smooth] Penny would never print this — which is precisely why it's worth knowing. Somebody in your Chapter haggled the grey down to nothing flat last night. [cool] Bold. Reckless. The kind of move that makes a person *useful.* I've made a note. I keep notes on everyone. [amused] Don't worry. Yours is flattering. For now.
- [cool] Here's the second version of tonight's rumor — the true one. A Fae Bargain came due and somebody walked away *richer.* [smooth] That doesn't happen. So either they cheated, or they understood the terms better than the Market did. [amused] I'd like to meet them. Professionally.

### "News" / current events
- [smooth] Market report: Belief is trading high, the grey's in freefall, and exactly one of you is about to make a deal you shouldn't. [cool] I won't stop you. Information's my trade, not mercy. [amused] But I'll play something lovely while you do it. That's almost the same thing.
- [cool] Breaking off the Market floor — festival season. The brass cheats at counting, the ledgers are laughing, and the margins are *sharp* tonight. [smooth] If your luck's been thin, that's the window. Make a wish, make a bargain, make it quick — [amused] and read the small print I know you won't. Here's the band.

---

## Cross-station network IDs (any DJ, hand-offs)

Short "you're on the Academy band" stings to glue the stations together.

- You're tuned to ReEnchanted Radio — the whole band, broadcasting out of Enchantify Academy, into the only chapter nobody else can write. Yours.
- [network] Eighty-eight three, Penny on Fae-Fi… ninety nine, Euphony at Mothlight… one-oh-three seven, Wicker on Thornwave… and if you can hear Villanelle's Bindery and Melisande's Market, you've gone properly nocturnal. Spin the dial. Somebody's playing your weather.
- This is the sound the grey can't get into. ReEnchanted Radio. Keep believing out loud — it's the only thing that's ever worked.

---

## Production notes

- **Starter quantity:** ~3 IDs, 2 transitions, 1 sponsor, 1 gossip, 1 "news" per
  station = ~9 clips each, ~45 total — enough that a long listen doesn't repeat.
- **What keeps it real:** each DJ's actual voice from `NarrativeCore.swift`
  (Penny's dry filing, Euphony's harmonies, Wicker's testing, Villanelle's one
  true sentence, Melisande's second-version rumors), the callsign + frequency,
  Routine/Belief/Glow vocabulary, The Bleed as in-world news, and the real
  bundled track names. Swapping tracks later only means re-recording transitions.
- **Time-of-day:** Fae-Fi reads best in daylight rotations, Mothlight at dusk,
  Thornwave / Bindery / Market after dark — matching the half-hour window
  rotation `BookRadioManager` already uses.
- **Cross-references are intentional:** Wicker name-drops Melisande, Euphony
  points to Inkrest's office hours, everyone cites Penny's Bleed — the cast
  acknowledging each other across frequencies is most of what sells the world.

---

## The playout system (how it stays alive & non-repeating)

The dial doesn't read a fixed playlist. Songs and DJ breaks are **content the
playout clock assembles fresh each session**, so two listens rarely line up. All
of this lives in `Shared/WorldSystems.swift` and is covered by
`Tests/InsideCoverCoreTests/RadioBanterTests.swift`.

### The pieces

- **`RadioBanter`** — a typed DJ break: `id`, `category`, `assetName` (spoken
  audio, resolved exactly like a track), `caption` (status-line text + spoken
  fallback when no audio is bundled), optional `conditions`, and a `weight`.
- **`RadioBanter.Category`** — `stationID`, `transition`, `sponsor`, `gossip`,
  `news`, `network`. (These mirror the headings in this doc.)
- **`RadioBanter.Conditions`** — all-optional gate: `timeOfDay`, `minGrey` /
  `maxGrey` (Routine's pressure), `festivalOnly`, `minListeningDays`. Leave a
  field nil to mean "don't care."
- **`RadioWorldContext`** — the live snapshot the app builds from existing systems
  (clock → `timeOfDay`, `NothingTide` → `grey`, festival window, the listening
  streak). This is what makes a line *contextual* instead of random.
- **`RadioStation.banters`** — optional; when empty, `resolvedBanters` synthesizes
  transition breaks from the legacy `interludeTitles`, so nothing regresses.
- **`RadioPlaybackState.recentBanterIDs`** — a 6-deep ring buffer
  (`recordBanter(_:)`) so a break the reader just heard won't come back.

### How a break is chosen — `RadioStationRegistry.nextBanter(...)`

1. Filter to banters whose `conditions` the current `RadioWorldContext` satisfies.
2. Walk `banterRotation` (`stationID → transition → sponsor → transition → gossip
   → transition → news`) from a station+time-slot offset, so breaks feel
   sequenced like a real broadcast rather than shuffled.
3. Within the first category that has eligible clips, exclude `recentBanterIDs`,
   then make a **stable weighted pick** seeded by station id + 15-min slot —
   varies per run, reproducible inside a window (same pattern as track/interlude
   selection already in the file).

### Song-bound transitions (intro vs. outro)

A `transition` banter can be **bound to a specific song** so it lands on the
right seam:

- `trackID` — the `RadioTrack.id` it belongs to.
- `placement: .intro` — plays **right before** that song ("Coming up,
  Folktronica…"). `.outro` — plays **right after** it ("That was Mossy
  Footsteps…"). `placement: nil` with a `trackID` = either side is fine.

The playout loop looks both ways each break: it knows the song that just ended
(enables matching outros) and the song queued next (enables matching intros). An
intro also **pins** its song as the next to play, so "Coming up, Folktronica" is
always followed by Folktronica. Unbound transitions (no `trackID`) still play
anywhere as filler. Worked example on Fae-Fi: a Mossy Footsteps outro and a
Folktronica intro.

Asset naming for bound transitions:
`DJ_<station>_transition_<trackslug>_<intro|outro>`
(e.g. `DJ_faefi_transition_folktronica_intro`).

### The cadence

`shouldBanter(afterTrackIndex:)` returns true every `tracksPerBanter` songs
(default 2). The app's playback loop calls it after each track; on true, it asks
`nextBanter(...)`, plays the clip (or shows the caption), and calls
`recordBanter(...)`.

### Adding content later (zero code changes)

- **In code:** append `RadioBanter(...)` entries to a station's `banters:` array.
  Thornwave has a worked example with all five categories, a night-only callsign
  (`timeOfDay: ["dusk","night"]`), and a grey-gated gossip line (`minGrey: 40`,
  `weight: 2`).
- **In a pack:** add a `banters` array to any station inside a
  `*.reenchantedradio.json` file — it decodes straight into `RadioStation`
  because the field is optional/back-compat.
- **Audio:** name files `DJ_<station>_<type>_NN` and drop them in the `RadioAudio`
  bundle folder or `Documents/RadioPacks`; they resolve through the same loader
  as tracks. No asset yet? The `caption` still plays as the on-screen break.

### App wiring (done — `BookRadioManager` in `InsideCoverApp/AppSupport.swift`)

The playout loop is live. Songs now play **once** (not looped) so the
`AVAudioPlayerDelegate` finish callback can drive the sequence:

1. A song finishes → `handlePlayoutItemFinished()` increments the song counter.
2. `shouldBanter(afterTrackIndex:)` (every 2 songs) → if true, `nextBanter(...)`
   picks a break from a `RadioWorldContext` snapshot.
3. The break's audio asset plays (ducking any procedural bed); when it ends, the
   loop resumes with `selectNextTrack(...)` (rotates, avoids repeating the last
   song). No audio yet? The **caption** shows for 5s, then music resumes.
4. `nowPlayingBanter` is published for the UI; `recordBanter(...)` persists the
   ring buffer.

**For Penny's recordings:** Fae-Fi already has her six banters wired
(`faefi-id-01`, `faefi-sponsor-thistledown`, …). Name the audio files to match
their `assetName`s — `DJ_faefi_id_01`, `DJ_faefi_sponsor_01`, etc. — in any of
`m4a / mp3 / wav / aac / caf / aiff`, and drop them into the **`RadioAudio`**
bundle folder (or `Documents/RadioPacks` at runtime). They resolve through the
same loader as songs. Until a file is present, that break plays as an on-screen
caption, so you can test the cadence before the audio is finished.

**Live world-state (optional):** time-of-day and the listening streak are derived
inside the manager. To make grey-gated / festival-gated lines fire, set
`BookRadioManager.shared.worldContextProvider = { (grey: …, festivalActive: …) }`
from the app once, wiring it to `NothingTide` / the festival window. Left unset,
it defaults to calm (grey 0), which still satisfies Penny's `maxGrey: 60` news
line.

**Caveat:** sequencing only runs for stations whose songs resolve to real bundled
audio. The procedural-synth fallback still loops a single bed (no delegate
callback), so banters won't interleave there — Fae-Fi's songs are bundled, so
Penny is unaffected.
