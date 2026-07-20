# The Unquiet Folio — drama recipe pack (implementation plan)

Goal: add a drama line ("Clash Pages") to Story Pages. Cozy pages make the reader
feel held; clash pages make the world push back. The threat is never violence —
it is *something precious being made generic*: forged margins, flattened words,
counterfeit trust, rivalries pulling tight.

This is ~90% content, ~10% engine. All prose below is final — transcribe it
verbatim, do not re-author. No new files are added to targets, so **no
pbxproj or Package.swift changes are needed** (only existing files change).

House laws that must hold:
- Retreat is not failure. Failure becomes story, never punishment.
- The app owns mechanics; the model writes only ink. All landing lines below
  are the deterministic floor — Gemma embellishes on top.
- Everything ships pack-authorable (this pack is a bundled `StoryFormPack`).

---

## Step 1 — Engine: `.rivalryEdge` requirement

File: `Shared/StoryEngine.swift`

1a. Add a case to `StoryRecipeRequirement` (search `enum StoryRecipeRequirement`):

```swift
case rivalryEdge
```

1b. In `selectRecipe(...)` → inner `func eligible(...)` (search
`requirements.contains(.nothingPressure)`), add alongside the other checks:

```swift
if requirements.contains(.rivalryEdge) && !StoryFormRegistry.hasRivalryEdge(among: entities) { return false }
```

1c. Add this helper to `StoryFormRegistry` (near `recipeIsValid`), internal so
tests can reach it:

```swift
/// True when any relationship edge between the available entities carries
/// real tension — the fuel for rivalry-driven clash recipes.
static func hasRivalryEdge(among entities: [NarrativeWorldEntity]) -> Bool {
    let ids = Set(entities.map(\.id))
    return NarrativePackRegistry.relationships.contains { edge in
        edge.tension >= 2 && ids.contains(edge.sourceEntityID) && ids.contains(edge.targetEntityID)
    }
}
```

Known v1 simplification (acceptable, do not fix): the blueprint's lead/companion
are chosen by the existing casting logic and may not be the exact tense pair;
the relationship-pressures section still carries the tension lines into the
prompt, so the scene reads correctly either way.

## Step 2 — Engine: clash genres are recipe-gated

Convention: a genre with `"clash"` in its `moodTags` may only be picked when the
selected recipe prefers it. This keeps dread genres off cozy pages while staying
pack-authorable (any user pack can mark a genre `"clash"`).

File: `Shared/StoryEngine.swift`, in `StoryFormRegistry.select(...)`, inside the
`scoredGenres` map (search `let scoredGenres = allGenres.map`), immediately
after `var score = tags.intersection(...)`:

```swift
if genre.moodTags.contains("clash") && recipe?.preferredGenreIDs.contains(genre.id) != true {
    score -= 100
}
```

## Step 3 — Engine: clash pages mandate the Belief dice

File: `Shared/SourceAdapters.swift`, in
`StoryPageMechanicMandate.mandate(for:inputs:packet:now:)`.

The `let seed = ...` line currently sits after the `shouldAllowMechanic` guard.
Keep the guard first, then insert this block right after the `seed` line
(before the `roll` pacing logic):

```swift
let isClashRecipe = packet.blueprint.flatMap { blueprint in
    StoryFormRegistry.recipes.first { $0.id == blueprint.recipeID }
}?.preferredTags.contains("clash") ?? false
if isClashRecipe {
    return StoryPageMechanicMandate(
        kind: .beliefDice,
        choiceID: choiceID(for: .beliefDice, packet: packet, seed: seed),
        enchantmentID: nil,
        reason: "A clash is underway; the confrontation choice carries the Belief dice."
    )
}
```

Notes: `shouldAllowMechanic` still gates this (a clash page right after another
mechanic page rolls nothing — "not every clash rolls" is correct). The
bright/costly/complication/retreat ladder is *presentation* of the existing
belief-dice outcome tiers plus the landing templates below; no new resolution
system.

## Step 4 — Content: the pack

File: `Shared/StoryEngine.swift`. In `StoryFormRegistry.bundledPacks`, append a
second `StoryFormPack` after the `core-story-forms` pack. `forms: []` (clash
pages reuse the core forms). Transcribe exactly:

```swift
StoryFormPack(
    id: "unquiet-folio",
    displayName: "The Unquiet Folio",
    version: 1,
    author: "The Book",
    availability: "bundledFree",
    forms: [],
    genres: [
        StoryGenre(id: "trickster-duel", name: "Trickster's Duel", lens: "Social pressure with a grin. The threat is being made to feel foolish for caring. Wit is the weapon and the wound.", moodTags: ["clash", "mischief", "audience"],
            exemplar: "\"Nice page,\" Wicker said, not reading it. \"Very brave, keeping the sad ones.\" He let the silence do his work, then flicked a paper pellet at the inkwell. \"Relax. If I wanted it, it'd be gone. I'm here because someone's lying to you, and it's embarrassingly not me.\"",
            palette: ["forged marginal note", "paper pellet", "inkwell", "borrowed grin", "the Stacks ladder", "a stolen title", "a dare", "an audience of two"]),
        StoryGenre(id: "grey-static", name: "Grey Static", lens: "The Rut of Routine edits, it does not attack: exact words go pale, lists become \"items\", days become \"fine\". Specificity is the counterspell.", moodTags: ["clash", "grey", "flattening"],
            exemplar: "The list was still on the door, but someone had corrected it. Where it once said \"the good cup, the loud clock, Tuesday's moth,\" it now said \"items.\" Mara read it twice. \"Who signs their work 'fine'?\" she asked. The hallway light seemed suddenly very reasonable, very beige.",
            palette: ["the word \"fine\"", "a corrected list", "beige light", "a missing adjective", "blank margin", "a title gone \"Untitled\"", "the good cup", "static hum"]),
        StoryGenre(id: "threshold-gothic", name: "Threshold Gothic", lens: "Borrowed rules and courteous danger: things that must ask permission, and the terrible weight of granting it. Invitation logic, old handwriting, the wrong side of the glass.", moodTags: ["clash", "threshold", "invitation"],
            exemplar: "The letter arrived under the window, not the door — folded once and cold to the touch. \"It requests permission,\" Odile said, not touching it. \"Twice, politely.\" Below the signature, in older handwriting: MAY I COME IN. The latch, which had never mattered before, mattered enormously now.",
            palette: ["window latch", "an invitation with no stamp", "cold envelope", "older handwriting", "permission asked twice", "the wrong side of the glass", "salt on the sill", "a rule that followed you home"])
    ],
    recipes: unquietFolioRecipes
)
```

Then add (near `coreRecipes`, reusing the existing private `recipe(...)` and
`turn(...)` helper functions):

```swift
static let unquietFolioRecipes: [StoryRecipe] = [
    recipe("grey-edit", "The Grey Edit", weight: 14, requirements: [.keptPage], mode: .balanced,
        premise: "The Rut of Routine has edited the kept page inside {{thread}}: the exact words of {{grounding}} have gone pale, corrected to \"fine.\"",
        beats: ["Show the kept page with its specific words flattened to filler while {{lead}} names what is missing.", "After the chosen response, the true words return, partly return, or their first-stolen word is learned — and the grey's editing rule gets written down."],
        turn: turn(.factLearned, want: "to learn which exact word the grey took first from {{grounding}}", obstacle: "the flattened sentence reads as almost true, which is how it hides", statement: "By the end, at least one exact word has been restored or the grey's editing rule has been named.", slice: "One small true detail is read aloud and refuses to stay grey.", progress: "The restored word points at where the grey nests inside {{thread}}.", surprise: "The edit was practice: the grey is drafting toward a page that has not been written yet."),
        tags: ["clash", "grey", "nothing", "evidence", "words"], forms: ["small-mystery", "nocturne"], genres: ["grey-static", "gentle-horror"],
        grounding: "Quote or nearly quote the kept material's own concrete words as the thing being erased and restored; the whole fight is over exact wording.",
        tone: "Dread at kitchen scale, then defiance. Specificity is the weapon; the scene itself must never go vague.",
        choices: "Offer restoring one exact detail, spending Belief to reject the whole edit, or asking the Book which word vanished first.",
        continuation: "The restored words stay restored. Escalate to the grey's source or its next target; never re-flatten the same page."),
    recipe("wicker-marks-the-page", "Wicker Marks the Page", weight: 14, requirements: [.keptPage], mode: .conversation,
        premise: "Wicker Eddies has forged a marginal note on the kept page in {{thread}} — {{grounding}} — and stayed to watch it land.",
        beats: ["{{lead}} defends the page while Wicker performs innocence, the forged note doing its small cruel work.", "After the chosen response, the forgery burns off, buys Wicker leverage, or exposes what he actually came for."],
        turn: turn(.revealWant, want: "to make the reader doubt that {{grounding}} deserved keeping", obstacle: "the page's specific words are truer than his joke, and he knows it", statement: "By the end, the forged note is exposed, overwritten, or traded — and Wicker's real errand shows one honest edge.", slice: "The reader's own words outlast the joke, read aloud once, plainly.", progress: "The forgery peels up, and what Wicker was covering moves {{thread}} one step.", surprise: "The note is in Wicker's hand, but the idea belonged to someone else."),
        tags: ["clash", "wicker", "forgery", "margins"], forms: ["correspondence", "visitation"], genres: ["trickster-duel", "cozy-mystery"],
        grounding: "The forged note mocks the kept material's exact content; quote the page's real words against Wicker's fake ones.",
        tone: "Social pressure, not menace: the threat is being made to feel foolish for caring. Wicker is funny, quick, and wrong.",
        choices: "Offer naming the forgery with evidence, writing over him with better mischief, or sealing the true page at a visible cost.",
        continuation: "Wicker keeps whatever he won and remembers whatever he lost. Move to consequence or counter-move; do not replay the forgery."),
    recipe("rivals-tether", "The Rival's Tether", weight: 12, requirements: [.character, .secondCharacter, .rivalryEdge], mode: .conversation,
        premise: "{{lead}} and {{companion}} have let a tension knot pull tight inside {{thread}}, and {{grounding}} just became the rope.",
        beats: ["The two collide over the concrete material mid-scene — each certain, neither cruel, the reader between them.", "After the chosen response, the knot loosens, tightens honestly, or reveals what the rivalry has been protecting."],
        turn: turn(.beTakenSeriously, want: "to be taken seriously about what {{grounding}} means", obstacle: "{{companion}} read the same evidence and reached the opposite conviction", statement: "By the end, the rivalry has been named to its face, and one of them has conceded one exact inch.", slice: "One ordinary detail both rivals agree on, grudgingly, out loud.", progress: "The concession — small, specific — moves {{thread}} one honest step.", surprise: "The rivalry is a guard dog: what it protects finally shows itself."),
        tags: ["clash", "rivalry", "tension", "cast"], forms: ["visitation", "quiet-epic"], genres: ["trickster-duel", "serial-adventure"],
        grounding: "Both rivals argue from the same concrete material; the disagreement is conviction, never facts.",
        tone: "Friction that sharpens instead of wounds. Fast exchanges, real stakes, no cruelty.",
        choices: "Offer siding with one rival on evidence, forcing both to defend the same detail, or naming what the quarrel protects.",
        continuation: "The concession holds. Warmth or tension moves visibly; never reset both rivals to their opening positions."),
    recipe("counterfeit-invitation", "The Counterfeit Invitation", weight: 12, requirements: [.groundedSource, .character], mode: .conversation,
        premise: "An invitation reaches the reader inside {{thread}}, signed by a friend — but {{grounding}} says the hand is wrong.",
        beats: ["The invitation performs warmth while one concrete detail from the real material refuses to corroborate it.", "After the chosen response, the forgery is unmasked, accepted on the reader's own terms, or audited into a stranger truth."],
        turn: turn(.keepSecret, want: "to find out who is wearing a friend's handwriting", obstacle: "refusing outright would insult the real friend if the letter is genuine", statement: "By the end, the invitation's true sender has been tested, and trust lands somewhere exact.", slice: "One verifying question only the real sender could answer, asked casually.", progress: "The unmasked scheme points one step deeper into {{thread}}.", surprise: "The invitation is genuine — and that is somehow worse."),
        tags: ["clash", "letters", "trust", "forgery"], forms: ["correspondence", "small-mystery"], genres: ["threshold-gothic", "trickster-duel"],
        grounding: "One concrete detail from the material is the tell that exposes or verifies the invitation.",
        tone: "Social suspense: trust as a wager. Courteous surface, sharp undertow.",
        choices: "Offer following it openly, asking one verifying question, or having the ink audited by someone exact.",
        continuation: "The verdict on the sender stands. Follow the consequence of trusting or refusing; never re-litigate the same letter.")
]
```

Cadence is handled by the existing knobs: modest `baseWeight` (12–14 vs
souvenir-door's 22) and the `recipe(...)` helper's default 18h cooldown make
clash pages weather, not climate. Do not add new cadence machinery.

## Step 5 — Tests

File: `Tests/InsideCoverCoreTests/WorldSystemsTests.swift` (Story forms MARK).
Note `testStoryFormRegistryIsWellFormed` asserts `coreRecipes.count == 12` —
unchanged, the new recipes live in their own pack. The existing
`testBundledGenresShipExemplarAndPalette` automatically covers the three new
genres (each exemplar above is ≤75 words). Add:

```swift
func testUnquietFolioPackIsWellFormed() {
    let pack = StoryFormRegistry.bundledPacks.first { $0.id == "unquiet-folio" }
    XCTAssertNotNil(pack)
    XCTAssertEqual(pack?.genres.count, 3)
    XCTAssertEqual(pack?.recipes.count, 4)
    XCTAssertTrue(pack?.genres.allSatisfy { $0.moodTags.contains("clash") } ?? false)
    XCTAssertTrue(pack?.recipes.allSatisfy { $0.preferredTags.contains("clash") } ?? false)
    XCTAssertTrue(pack?.recipes.allSatisfy(StoryFormRegistry.recipeIsValid) ?? false)
    XCTAssertTrue(pack?.recipes.allSatisfy { $0.beats.count == StoryVignetteBeats.maximumInteractiveTurns } ?? false)
}

func testClashGenresNeverSurfaceWithoutClashRecipe() {
    for day in 1...14 {
        let picked = StoryFormRegistry.select(
            tags: ["rain", "evening", "mischief", "grey"], surfaceHistory: [:], ascendantChapterID: nil,
            dayID: "2026-07-\(day)", slot: "slot-\(day)", now: Date()
        )
        XCTAssertFalse(picked.genre.moodTags.contains("clash"), "clash genre \(picked.genre.id) surfaced with no clash recipe")
    }
}

func testClashRecipePrefersClashGenre() {
    let greyEdit = StoryFormRegistry.recipes.first { $0.id == "grey-edit" }
    XCTAssertNotNil(greyEdit)
    let picked = StoryFormRegistry.select(
        tags: [], surfaceHistory: [:], ascendantChapterID: nil,
        dayID: "2026-07-01", slot: "slot-a", recipe: greyEdit, now: Date()
    )
    XCTAssertTrue(greyEdit?.preferredGenreIDs.contains(picked.genre.id) ?? false)
}

func testRivalryEdgeDetection() {
    let all = NarrativePackRegistry.entities
    XCTAssertTrue(StoryFormRegistry.hasRivalryEdge(among: all), "the bundled cast should contain at least one tense edge (e.g. Finn Bridges)")
    XCTAssertFalse(StoryFormRegistry.hasRivalryEdge(among: []))
}
```

Note for `testClashRecipePrefersClashGenre`: the +7 recipe preference plus the
−100 gate on unpreferred clash genres makes a preferred genre win with empty
tags; if hash jitter ever picks the recipe's *second* preferred genre that is
still a pass (assert membership in `preferredGenreIDs`, as written).

Also add a mandate test (same file or `Tests/InsideCoverCoreTests/` wherever
`StoryScenePacketBuilder.packet` fixtures already exist — see
`testPacketCarriesFormAndGenre`):

```swift
func testClashBlueprintMandatesBeliefDice() {
    var packet = StoryScenePacketBuilder.packet(for: BookDay.today(), inputs: .empty)
    guard var blueprint = packet.blueprint else { return XCTFail("packet needs a blueprint") }
    blueprint.recipeID = "grey-edit"
    packet.blueprint = blueprint
    packet.turn = blueprint.turn
    let mandate = StoryPageMechanicMandate.mandate(for: BookDay.today(), inputs: .empty, packet: packet, now: Date())
    XCTAssertEqual(mandate.kind, .beliefDice)
}
```

(If `shouldAllowMechanic` fails because `packet.turn` is nil, setting it from
the blueprint as above fixes it; `BookDay.today()` with `.empty` inputs has no
recent mechanic pages, so the guard passes.)

## Step 6 — Docs

File: `docs/ContentPackCatalog.md`, Story Forms section. After the genres
bullet, add:

```markdown
- **Clash genres** — a genre with `"clash"` in `moodTags` is recipe-gated: it
  only surfaces when the selected recipe lists it in `preferredGenreIDs`.
  Bundled example: The Unquiet Folio (Trickster's Duel, Grey Static,
  Threshold Gothic) — the drama line where something precious is being made
  generic and the reader spends Belief to keep it strange.
```

## Verify

1. `swift test` — full package suite (includes the new tests).
2. Build the app target (Xcode or `xcodebuild -project
   EnchantifyInsideCover.xcodeproj -scheme InsideCoverApp -destination
   'generic/platform=iOS Simulator' build`). Only `Shared/StoryEngine.swift`,
   `Shared/SourceAdapters.swift`, tests, and docs change.

## Explicitly out of scope (phase 2+, do not attempt)

- Escaped-book-villain recipes ("Something Followed Through the Spine",
  Dracula invitation, Red Queen) — need a `.recentBookJump` requirement wired
  to Book Jump state first.
- The visible modifier-stack roll UI ("Your Glow: 47 / Wicker's Interference:
  41", "Test the Binding" / "Throw the Inkbones" naming) — presentation work.
- Tone-preference intensity gating (gentle/balanced/strange multiplier on
  clash recipe weights).
- Wicker/clash radio banters and consequence tags feeding The Bleed.
- Book of You braid integration (clash digest tags, "WHERE BELIEF WAS TESTED"
  hinge, two-shelves 50/50 mix) — separate plan: `docs/braid-two-shelves-plan.md`
  (its Part B depends on this pack landing first).
