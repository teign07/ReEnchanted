# The Unwritten Deck: production and integration

## Current source — additional margins, October 29, 2026

Edition `unwritten-v3.2` adds varied marginal compositions on another 26 cards:
six paintings have relocated studies or small helpers; twenty use new native
lettering placements only. All main reading notes from v3.1 are preserved.
The six painted edits are Empress, Chariot, Ace of Wands, Queen of Cups,
Queen of Swords and Nine of Pentacles. The other 72 faces and the back remain
byte-identical to the start of this pass. The prior four artwork refinements
remain integrated. Stable IDs and the existing native card face are retained.

Production records and the complete post-integration audit are under
`output/imagegen/unwritten-deck-v3-margins-round2-20261029/`.
Earlier checkpoints below remain history. The artwork pass itself ran no build.
A subsequent reader-authorized Debug build installed and launched v3.2 on Rabbit;
see `docs/unwritten-tarot-installed-revision.json` for current device evidence.
Native visual and physical-print QA remain separate.


## Current refinement — October 29, 2026

The source edition is now `unwritten-v3.1`: the complete 78-card wild-library
deck with a focused reader-authorized refinement. Four paintings changed
(Five of Wands, Four of Swords, Queen of Wands, Ace of Pentacles); the other
74 paintings and back are byte-identical to the preceding complete deck.
Twenty-eight main notes were revised, and nineteen marginal compositions
were varied across 34 affected cards. Words, studies and small fae follow
each scene rather than a prescribed corner arrangement. The Book notices
physical particulars and can be blunt, curious or mischievous; it does not
need to turn each image into reassuring advice.

Selected full-size masters, exact built-in edit prompts/receipts, before
images, authored specifications, composed proofs and full-catalog validation
are preserved under `output/imagegen/unwritten-deck-v3-refinement-20261029/`.
The existing native lettering, scene/transcript data and stable asset IDs are
the only app seams used. Earlier production checkpoints below are history;
the installed-revision index and current report identify the current source.
No build, device installation or native/physical-print QA ran for this pass.


October 27, 2026. This extends the existing Tarot Page and illustrated interleaf
cabinet. The July design bible remains the symbolic/art starting point; its
Aurora-led product implementation proposal is historical. The live reader is
Serenity Brown.

The current governing direction is `unwritten-tarot-wild-library-direction.md`:
the wild, seemingly endless library Academy, current Cast, older authored
Enchantify Academy characters, literary fae and purposeful marginalia. The
reader asked for previews first, then explicitly requested implementing the
available cards. Approved v3 faces are integrated incrementally in the source
asset catalog. `unwritten-tarot-installed-revision.json` tracks the exact set,
count and hashes; unselected faces and the back retain their v1 inputs. The previous bookcraft
revision under `unwritten-deck-v2/` was stopped after the reader rejected its
Greek/Mediterranean world, and its installer is barred. Preserve its useful
pens, paper knives, book clasps and annotation approach. The complete first pass
described below supplies the remaining faces. Exact labels and notes belong to the native
card composition; generated painting does not supply readable prose.

The reader approved the v3 direction and asked for ordinary Academy rooms as
well as wild Stacks, fuller marginalia, and books everywhere, including the
Kitchens. Three room studies plus fuller lettering on the existing Penny
painting are staged in `output/imagegen/unwritten-deck-v3-room-studies/`.
`unwritten-tarot-room-plan.json` maps room variety across all 78 identities;
it is a staging plan, not a completed new deck or new lore. The native card
composition now supports the extra labels, notes and leader lines, with full
scene/marginalia accessibility transcripts and matching Serenity context.

The active edition is `unwritten-v3-partial`. The first installed batch was
Magician, Lovers, Hermit, Ten of Wands, Three of Pentacles, Four of Wands and
Four of Swords. Later batches added the Fool and Empress, then High Priestess,
Emperor and Hierophant. See
`unwritten-tarot-installed-revision.json` for the installed batch and
`output/imagegen/unwritten-deck-v3-integration/` for hash-bound reviews,
specifications, optimized exports, before-images and the installation receipt.
The reader explicitly authorized incremental installation; subsequent approved
batches may use `scripts/install_unwritten_tarot_batch.py`, which reuses the
existing optimizer, preserves unselected assets and rejects concurrent edits.
The stopped v2 installer remains barred. The classroom's winged seam helper
and pointed sewing needle are accepted variations with accurate labels, not
failed RWS symbols. No regeneration is required for them.

The initial seven masters total 24,522,155 bytes; their sRGB JPEG inputs total 3,735,748
bytes (84.77% fewer encoded bytes), with pixel dimensions preserved. This is
source-level integration, not a device update. Swift syntax, data, image decode,
hash and document-layout checks passed. No app build or native runtime QA ran.

Subsequent batches preserve original painting masters and compose exact text in
the existing native card face. Physical source lettering, such as the High
Priestess's B, J and TORA, is distinguished from handwritten marginalia in the
accessible description and Serenity context. The overnight production folder
retains per-card prompts, references, attempt receipts, rejected outputs,
hash-bound reviews and document-layout proofs. These proofs establish visual
document review, not native runtime behavior. The batch installer snapshots all
79 catalog hashes before replacing only selected, reviewed faces, and refuses
to overwrite an already accepted v3 face.
After replacement it verifies the exact changed-asset set, the complete manifest,
untouched masters, decoded dimensions and embedded color profiles, saving those
results with the batch. Swift syntax and native runtime checks are recorded
separately; the installer does not perform either.

October 28 continuation: 20 v3 faces are now integrated—Fool through Devil and
Four/Ten of Wands, Four of Swords, Three of Pentacles—with 58 remaining. The
13 additional faces are reviewed in six preserved batches under
`output/imagegen/unwritten-deck-v3-overnight/`. The original seven and back
remained byte-identical. All three production workers subsequently reported a
usage limit; exact errors and a filtered remaining queue are saved there. No
generation retry or fallback followed those errors. The consumed one-time
overnight automation was deleted.

The 20 untouched masters total 68,583,157 bytes; their sRGB JPEG catalog inputs
total 10,385,520 bytes, about 84.86% fewer encoded bytes with dimensions
preserved. This is source asset size, not app size or decoded memory. Death's
967×1626 master is an explicitly reviewed small aspect variation: the complete
painting fits inside the native 7:12 plate without cropping, resizing or
upscaling the export. Its hash-bound review permits a 0.012 ratio tolerance;
the optimizer's default 0.01 guard remains in force for all other inputs.
Source syntax, full catalog hashes and document-layout checks passed; app build
and native runtime QA remain unrun.

## First-pass artwork history

The approved six-card prototype established physical cream paper, fine irregular
ink, transparent watercolor, believable people, a clear RWS-readable scene, and
sparse related marginal studies. The Fool retains the earlier desktop image's
impossible library precipice, dog, rose, bundle and sun, with a clearer silhouette
and no written lessons. Existing Penny Blackletter and Kitchen illustrations
anchor the medium. Accepted deck images become subsequent style references.

`scripts/prepare_unwritten_tarot.py` prepares all 78 individual prompts from the
authored card manifest. Generation uses the built-in ImageGen tool, one card at
a time. It never runs during a reader's session. Each accepted image and its
generation receipt remain under `output/imagegen/unwritten-deck-v1/`; that local
production directory is deliberately outside the app bundle and Git history.

`scripts/optimize_unwritten_tarot.py` preserves the original RWS imports, makes
sRGB JPEG derivatives, and checks dimensions, ratio, decode success and hashes.
It does not crop, sharpen, upscale or alter symbols. Installation requires all
78 faces, the back, and an explicit production review for every asset. The
installer refuses to overwrite a concurrently changed asset. The committed
`unwritten-deck-art-manifest.json` records final hashes, prompts/references,
generation receipts and accepted deviations.
That first pass installed all 78 faces and the back. Its sRGB JPEG inputs totaled
48,748,468 bytes, compared with 317,591,874 bytes of preserved PNG masters
(84.65% fewer encoded bytes). Pixel dimensions are preserved. This measures
source asset size, not compiled app size, decoded memory or frame pacing.
The older `rws-temporary-asset-manifest.tsv` describes the historical reference
import, not the current artwork's license or authorship. Its historical importer
refuses to overwrite an installed Unwritten Deck.

Card names and Major numbering are rendered consistently by `TarotCardFace`,
outside the generated artwork. Traditional card identities, ranks and suits
stay intact. Figures are clothed; the Hanged Man is a calm, noninjured inverted
figure supported at the ankle. Difficult cards retain their symbolic difficulty.
The Tower's flame field and the Empress's star crown are accepted visual
adaptations: the generated ornament counts do not precisely reproduce the
July bible's 22 flames and 12 stars. These are recorded explicitly rather than
claimed as exact reproductions. Numbered Minor suit counts remain strict.

The Ten of Wands required a separate precise-object edit after two rejected
full-scene generations: the extra second staff from the left was removed. Its
receipt preserves the rejected attempts and the final edit prompt.

## Reading and preview

The existing asset names are retained, so saved card IDs, orientations, notes,
reader prose and draw logic are untouched. New readings record the current
edition, presently `unwritten-v3-partial`; the first pass used `unwritten-v1`.
Older saved readings retain their stored version field but display the current
illustration of the same card, as the existing renderer resolves by card ID.
This is an intentional reillustration, not a history migration or a new deck
picker.

Every revealed card, including read-only kept readings, opens the existing
`FolioExpandedArtifactView` inspector through a small shared modifier. It keeps
the card's orientation, supports the existing pinch/double-tap/pan/reset actions,
and has an explicit accessibility action and close control. The inspector uses
the same live card face as the reading. Face-down cards keep their reveal action.

The generated back is rendered as two matching, oppositely rotated impressions.
The code gives the complete back 180-degree symmetry, including paper wear;
generation alone does not guarantee reversal-neutral markings.

## Between Pages

All 78 cards join `InterleafIllustrationLibrary` as illustrations. They borrow
the existing three illustration slots per ten boundaries; photos and quieter
encounters retain their slots. The 78-card pool does not compete by sheer size.

The selector offers a related Tarot picture in one of four illustration slots,
and an unrelated one in one of fourteen. These are deterministic chances, not
guarantees for a particular opening. Both neighboring Pages contribute literal
subjects and authored tags. Whole-word/explicit-phrase matching prevents
`rainbow` from matching `rain` or `homework` from matching `home`/`work`.
Selection does not infer the reader's feelings or make model/network calls.

The existing encounter store holds choices steady and tracks actually visible
artwork for repeat rests. New boundaries give a Tarot image seven days' rest,
even when it is the sole literal subject match; already-held leaves stay still.
A Tarot interleaf is not a Tarot draw, prediction,
saved reading, or personal evidence. It remains an illustrated leaf, with the
existing full-screen inspection action.

## Validation boundary

Standalone production-policy probes exercise all 78 identities, literal subject
matching and rarity. In 10,000 seeds they selected related Tarot 2,523 times and
unrelated Tarot 721 times. The existing synthetic month harness also executed
2,480 encounters with no selection/history invariant failures. Source parsing
checks Swift syntax without building an app. Compression crops and whole-deck
review sheets support asset review.

These checks do not establish native rendering, page-curl/tap interaction,
VoiceOver, frame pacing, memory pressure or physical print quality. No app build,
installation, deployment or publication is part of this task. Hands-on native
QA and any physical printer proof remain separate.

## October 29, 2026 continuation: 75 reviewed faces installed

The source catalog now contains 75 accepted wild-library v3 faces: all 22
Majors, 12 Wands, all 14 Cups, all 14 Swords and 13 Pentacles. The Five and
Eight of Wands and Seven of Pentacles retain their prior v1 assets. Each used
two image calls and still failed exact suit-object review; no further call was
made. Their rejected paintings and final dispositions are preserved in
`output/imagegen/unwritten-deck-v3-overnight/held-card-review.json`.

Fifty-five faces were added after the 20-face afternoon baseline. Fresh,
hash-bound batches preserved those earlier accepted faces, the back and all
unselected assets. The complete 79-entry manifest and stable identities remain
intact, with edition `unwritten-v3-partial`. The existing fullscreen inspection
and related interleaf behavior remain in place.

The 75 preserved raster masters total 248,830,931 bytes; their progressive sRGB
4:4:4 JPEG derivatives total 37,388,977 bytes, 84.97% fewer encoded bytes.
Dimensions and complete images are preserved, without crop or upscale. These
figures describe encoded files, not app size, decoded memory or performance.
The King's 971x1619 Pentacles master has a separately hash-approved 0.017
aspect tolerance after full-fit visual review; its complete scene and lettering
remain visible. Existing approved Death and Four of Cups tolerances remain
recorded in their reviews.

The Ten of Pentacles has one explicit composition adaptation: authored native
paper-backed lettering covers text-like marks on a tiny lower-right raster
tag. Enlarged document proofs show no readable pseudo-writing, with faint
background color remaining. Check that tag in eventual native fullscreen QA.
Its split visible phrase has a continuous authored accessibility transcript,
using the existing marginalia model and installer. No illustration master was
changed for this lettering correction.

All 79 asset/master/export hashes, decoding, dimensions, progressive encoding,
ICC profiles and sampling passed source checks. Swift syntax parsing and the
scoped whitespace check passed. Each accepted new card received individual
count, tableau, identity, anatomy and lettering review. The 75-page installed
JPEG document proof and overview are under
`output/imagegen/unwritten-deck-v3-overnight/catalog-proof-75/`.
The current report is `continuation-report.md` and the machine-readable audit is
`continuation-validation.json` in the same production directory. Earlier
20-face reports are historical snapshots.

No app build, device installation, deployment, native VoiceOver/gesture test
or physical print proof has run. Production is stopped with three failed-count
cards held under the current two-call limit; there is no active generation or
pending scheduled continuation.

## October 29, 2026 completion: all 78 faces installed

The reader explicitly lifted the previous attempt cap: “Take as many attempts
as you need to get it awesome.” Each of the final three cards then passed
after one additional built-in ImageGen edit, cumulative attempt three. The
Five of Wands now has five whole pens with a coherent grip for each of its
five writers; the Eight has eight complete flying pens with visible ends;
the Seven of Pentacles has six vine clasps and one tray clasp. Counts, original
RWS tableaux, anatomy, named identity and final lettering were reviewed
independently before installation.

Batch 20 completes edition `unwritten-v3`: 22 Majors and 14 cards in every
suit. No faces remain held. The prior 75 accepted faces and the back remain
byte-for-byte unchanged against the new 75-face baseline. All historical
rejections, receipts and the earlier 75-face report remain preserved.

The 78 masters total 257,313,160 bytes; optimized face JPEGs total 38,691,255
bytes, 84.96% fewer encoded bytes with original dimensions preserved. This is
an encoded-asset measurement, not a runtime-memory or compiled-app claim.
All 79 catalog assets passed hash, decode, dimension, progressive sRGB JPEG
and 4:4:4 checks. Current Swift syntax parsing and scoped whitespace checks
passed. Root visually inspected the completed 78-card overview and enlarged
installed-JPEG proofs of the final three cards.

The complete document review bundle is
`output/imagegen/unwritten-deck-v3-overnight/catalog-proof-78/`.
The current handoff is `finished-deck-report.md`; the final preservation and
image audit is `finishing-corrections/final-validation.json` in that production
directory. Earlier reports describe historical partial states.

No app build, device installation, deployment, native interaction/VoiceOver
test or physical print proof ran. Those review boundaries, including the Ten
of Pentacles tag-overlay check, remain as documented above. Art generation
and source integration are complete, with no active or queued image calls.

## Later authorized Debug build on Rabbit

After the reader explicitly requested Debug, the complete current checkout
built successfully with 1,696 unchanged app inputs. The app and Share/Widget
extensions passed strict signatures and Rabbit provisioning checks. All 79
Tarot assets were verified inside the compiled asset catalog. Once Rabbit
returned home, installation and launch succeeded; the same app process stayed
alive for 203.4 seconds with no newly listed relevant app or Jetsam reports.
This is startup evidence; hands-on Tarot, fullscreen and VoiceOver QA remain
open. Build and deployment evidence, plus the preserved app and IPA, are under
`output/device-builds/Rabbit-Debug-20261029-163822Z/`.
