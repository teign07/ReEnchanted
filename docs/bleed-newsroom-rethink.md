# The Bleed: a newspaper worth coming back to

Implemented editorial direction, 15–16 October 2026.

Morning offers something worth meeting today. Evening follows what changed and
brings something worth coming home to. The weekly issue has the distance to tell
the Reader’s week. Daily issues get their own news, tastes, arguments and pleasures.

## What now chooses an issue

The existing edition builder selects the newspaper before the local writer runs.
Canonical monthly articles remain verbatim. Public Academy reporting comes from
current, already-occurred undertaking beats and speaking positions in live
arguments. The paper stores actual printed story IDs and source revisions, so
unchanged reporting does not earn another article. A changed report receives the
previous printed text as context, not as evidence of a new event.

A lead may receive local prose. Secondary Academy briefs keep their authored
facts. Practical strips carry weather and appointments directly and disappear
when empty. Outside research requires existing personalized-research permission,
selects one finding and prints source URLs. Permission and selection are checked
again when opening, rather than trusting the announcement’s old tray.

Small ads, replies, literary puzzles and answers are authored. Their miniature
fictions do not change the Academy’s incident ledger. Evening gives the actual
morning’s answer; when morning was missed, it includes the question. Occasional
morning enquiries invite a Plain Page beginning **For Penny:**. Evening can receive
one unprinted submission from the preceding seven days. Ordinary diary entries,
sensitive Pages, and generated prose cannot silently become submissions.

Generated copy uses the established character fidelity reviewer, a source-support
review and mechanical checks for padding, excess length, leaked packet labels and
invented correspondence quotations. It gets at most one repair. If it still fails,
the item uses its factual floor or is omitted. Same-model source review is a guard;
it cannot establish external truth. Search snippets remain attributed reports.

Press memory lives in the existing private vault: at most forty records within
thirty days. It remembers opened papers without automatically Keeping them, earning
Belief, claiming a Reader contribution or moving any fictional state. Submission
handwriting is removed from durable press-memory bodies; its ID and fingerprint
are enough to prevent reuse. The original Page and editions the Reader Keeps
retain their own text. Reopening an unkept slot can refresh the tray; earlier
printed items remain in its bounded memory, and its puzzle does not reroll.

## The Reader's words belong in the paper

The daily paper can offer one small literary encounter with the Reader's own
language. It does not have to make an argument about their whole life. The
weekly still has room and distance for that larger story.

`BleedReaderDesk` offers three forms to the editor:

| Form | What it gives the Reader | Evidence |
| --- | --- | --- |
| A line I wouldn't let go | Their exact words, then the Book holding up one particular verb, image, sound or turn of phrase. | One intact passage and its source Page's date. |
| Read it another way | A possible second reading of the actual language. The Book owns that interpretation; the Reader can disagree. | One intact passage containing a concrete image or potentially double-use word. |
| Two lines, side by side | Two exact passages whose wording meets, with the space between them still visible. | Distinct source Pages at least three calendar days apart, sharing a literal nontrivial word. This is not evidence of a personal theme or causal change. |

For example, with synthetic Reader ink:

> **Your Page · 13 Oct 2026**
>
> “The gate still catches. I lift it before I turn the key.”
>
> **Your Page · 16 Oct 2026**
>
> “I fixed the gate after lunch. For once, it shut without being lifted.”
>
> **The Book's reading**
>
> I read the gate changing jobs between these lines. First it makes you lift;
> then it gets to shut. ‘For once’ leaves the old nuisance rattling inside the
> new sentence. Those two small words have kept the squeak.

This is a human-authored specimen, not a claimed model result. The point is
attention to the language: the small words do something. The paper has no
grounds to announce that the Reader is more confident, has found closure, or
should fix another gate tomorrow.

The Reader's quotations and Page dates are inserted by the compositor. The
model writes only the Book's 25–55 word response. It cannot improve a quote,
clip it mid-sentence, alter its punctuation or invent its date. A source Page's
date is labelled as such, not asserted to be the date of a later margin note or
the event described. An unavailable or rejected response leaves the exact ink.
Character/source review and copy checks apply to the Book's response; the
Reader's own phrasing is not rejected for sounding like padding.

Sources use atomic Reader sentences, including their actual margin notes on a
Book-written Page. Generated bodies, fiction choices, and authored quotations
do not transfer authorship. Sealed, shadow, sensitive, body/fuel, future,
do-not-weave and already-printed sources stay out. Ordinary eligible diary and
Plain Page writing can supply this private Book reading; it is not silently
made into a letter to Penny. Explicit **For Penny:** submissions keep their
own correspondence channel and win the single Reader seat in an evening paper.
Hard days do not solicit playful reinterpretation. All of this remains local;
Reader text does not enter a news query or an external model.

## Curate the bench, then run the presses

`BleedNewsroom.candidatePool` now gathers more than the issue can print. It
includes eligible canonical inserts and the shared pulse, up to eight public
Academy reports, several Reader passages and forms, correspondence, an opted-in
interest news request, the paired puzzle, small ads, six authored very short
fictions, an occasional enquiry and practical strips.

`BleedIssueCurator` picks before research or generation. Canonical inserts retain
priority. Other features share six seats, with at most two world pieces, one
Reader piece, one outside discovery and two pleasures. Practical strips remain
a separate compact rail. A real Academy follow-up outranks unchanged bench
material; an explicit submission outranks an automatic reading; recently printed
Reader forms rest; a short fiction can replace recently printed small ads. Only
one Academy report receives local polish. No unselected candidate starts a model
call or enters print memory. After outside discovery, the editor chooses again:
an unavailable article can give its room to another eligible item. The bank is
finite and needs continuing authorship.

Morning prefers a held line. Evening prefers a paired return when the actual
sources qualify. These are editorial preferences, not mandatory daily boxes.
The current editor uses explicit source rules, priorities, history and room
limits. It does not claim model judgment of literary quality, and a local writer
can still omit unsupported copy. Future authored forms belong in this same pool.

## A daily print object

Both editions use the existing `BleedPDFWriter` and the exact issue already read
on the pocket leaf. Export makes no new writing request. A shared issue parser
replaces the PDF's separate interpretation of the newspaper. The new setting
uses white Letter stock, half-inch margins, two readable columns, a 10.5-point
serif body with 14-point leading, a large lead headline, rules, Page folios and
distinct morning/evening accent and edition lines. Reader passages get a larger
italic setting; the short Book response stays separate. Sources remain readable
and clickable. Available authored artwork can appear without a forced plate.

The old full-page sepia wash, fake folds, mandatory press-room ad, random
marginalia and duplicate lead pull quote have been removed from the print path.
Extra copy continues onto another sheet rather than reducing the type to fit.
Core Text carries the actual visible character range across columns, preserving
Unicode and repeated spaces. A layout failure prevents saving an incomplete PDF.
Paired emphasis in authored copy is typeset; Reader asterisks remain literal.

The existing PDF action now says **Make print edition**, followed by **Open print
edition** and **Share PDF**. Quick Look previews that exact file. Export names
carry the original issue's slot, retaining morning/evening identity when an old
paper is opened later. Sharing and printing remain Reader actions.

Two independently rendered, one-page layout studies are saved in
`output/pdf/bleed-morning-layout-study.pdf` and
`output/pdf/bleed-evening-layout-study.pdf`. They combine actual authored Count
Unbound copy with labelled synthetic Reader ink and authored Book responses.
`scripts/bleed_print_studies.py` reads the shared numeric type/page spec and the
shipping content bank. Its ReportLab rendering is a design study, not the app's
Core Text renderer or proof of live event/phase eligibility. Both studies were
rendered to PNG and visually checked; a separate three-page overflow study was
also checked. Reader quotations survived PDF extraction. No native PDF, Quick
Look, AirPrint, model or device result is implied by those proofs.

## One world through the day

The monthly issue already authors the world's pulse. The Count Unbound supplies
34 pulse passages across its four phases, with quiet variants, alongside its
authored scenes and canonical newspaper inserts. The core Cast also has ten
undertaking ladders containing fifty authored scenes. These sources now reach
the daily paper through the existing world and encounter systems.

`SceneWorldCanon.dailyPulse` chooses one eligible current-phase pulse for the
local date. The Bleed prints that passage verbatim, preserving its fact and
event-run identity in its normal press record. The nightly braid receives that
same choice through the existing braid context, including an unkept paper's
vault memory. A kept paper can recover the choice too. If the braid came first,
its world-claim tag fixes the later paper's choice. Current phase and event dates
remain authoritative; an old run or a future print cannot choose today's story.
There is no second world clock, scheduler, incident ledger or new authored plot.

The channels do different work:

| Channel | Its job | Its source boundary |
| --- | --- | --- |
| Morning Bleed | Put something concrete from the living Academy in front of the Reader. | One verbatim monthly pulse, available canonical inserts, public Cast reporting. |
| Cast encounter | Let the Reader meet the people and the actual authored scene. | The next unseen, already-occurred scene on the existing serial. A report may prefer its thread, but never skips an opening or marks anything witnessed. |
| Evening Bleed | Follow a real change, answer the morning puzzle, receive correspondence. | No reroll or unchanged reprint of the morning pulse. A missed morning still permits a standalone evening issue. |
| Nightly braid | Let that world event live beside the Reader's actual day in the Book's voice. | The same public fact, with explicit context that printing it was not another occurrence. A later outcome or the Reader's attendance cannot be invented. |
| Weekly issue | Find the shape of the Reader's week. | The week's actual life and established Book history. |

For example, an authored school-hours pulse says, “Every coat in the Great Hall
is wet on one side only, the side that faces the East Stacks.” That exact passage
can be the morning's Academy item. Evening cannot manufacture an explanation or
dry the coats merely to produce a follow-up. The braid may tell that same oddity
beside the Reader's supplied day; it cannot put the Reader in the Great Hall.
On a hard day the same pulse uses its authored quiet variant, or stays out if it
has none. An encountered monthly outcome owns the night's world strand instead
of competing with another scheduled incident. Existing nightly world limits hold.

Public Cast reporting now receives the current authored witnessed scene as a
supporting source, in addition to its short ledger fact and physical trace.
Visible action and exact speech can make the report worth reading. Narrator-only
knowledge, private motives, future stages, letters and found private notes do not
become testimony. The braid still receives short public facts and traces rather
than copying a finished Cast scene into its prose.

Kept papers with typed print records no longer become a second whole-newspaper
fiction atom in the braid. Their public facts already have a route. Reader margin
notes remain Reader contributions. Printing grants no attendance, encounter,
fictional consequence or participation credit. Missing editions creates no debt.

Twenty-one source regression cases in `WorldStoryContinuityTests.swift` cover
the common pulse, press memory and archived papers, missed editions, phase and
run boundaries, quiet variants, authored outcome priority, public scene sources,
related encounter preference and its daily gate, duplication, Reader ink and
backward decoding. They have been syntax-parsed, not executed.

## Seven paired editorial specimens

These are **readable source specimens, not app captures or model outputs**.
The puzzles and small ads below come directly from the shipping editorial library.
Academy and Reader examples use the explicitly described synthetic fixtures.
Factual floors show the offline behaviour; approved local prose may improve their
setting without adding facts. These are excerpts: mastheads, dates, optional
appointments, outside research and plates are omitted here.

### 1. A first paper, no personal history

No weather, calendar or outside clippings are supplied. Both editions still contain authored material; the issue says nothing about missing data.

**Morning**

> **The small ads**
>
> WANTED: A less suspicious word than ‘moist’. Must be willing to work beside cake.

> **The small puzzle**
>
> THE PORTRAIT SAID PENNY IS LYING. Punctuate this twice: once so the portrait accuses Penny, once so Penny accuses the portrait. Keep every word in order.
>
> Answer in the evening paper.

**Evening**

> **The small ads**
>
> REPLY TO THIS MORNING'S WORD VACANCY: ‘Damp’ applied. The cake has asked to see other candidates.

> **The answer, unfolded**
>
> The portrait said, ‘Penny is lying.’ Or: ‘The portrait,’ said Penny, ‘is lying.’ Same words, different accuser. Please check the quotation marks before duelling.

### 2. An ordinary day with Academy business

The source facts have not changed by evening. Evening omits the morning report rather than paraphrasing it.

**Morning**

> **Academy report**
>
> Penny found a changed comma in an old headline. A red circle marks page four.

> **The small ads**
>
> FOR SALE: One convincing last sentence. Never used. Owner keeps remembering something else.

> **The small puzzle**
>
> A worm enters a closed book at the first printed page and stops at the last. Has it eaten the whole story? Consider what a hole can actually take.
>
> Answer in the evening paper.

> **A small enquiry**
>
> Notice one thing somebody repaired rather than replaced. What did they use?
>
> If you’d like Penny to read it, open a Plain Page and begin with “For Penny:”. Keep the page. A later evening paper can carry your note. It stays in your Book.

**Evening**

> **The small ads**
>
> REPLY TO THE LAST-SENTENCE AD: Does it come with the courage to stop? Seller has enclosed a further page.

> **The answer, unfolded**
>
> A hole removes only the words in its path. The worm has eaten through the book, but most of the story is still there. Readers with toast crumbs should find this reassuring.

### 3. A follow-up earns the lead

Synthetic Academy facts for the editorial rehearsal. These are not additions to shipping canon. The evening can compare current facts with the actual printed morning report.

**Morning**

> **Academy report**
>
> Penny found a changed comma in an old headline. A red circle marks page four.

> **The small ads**
>
> ROOM AVAILABLE inside a parenthesis. Quiet tenant preferred. No subclauses after ten.

> **The small puzzle**
>
> SHE ONLY BORROWED THE KEY. Move ONLY to two other positions. How does each move change what the sentence denies? No keys need to be borrowed.
>
> Answer in the evening paper.

**Evening**

> **Further to the morning report**
>
> Penny found the original headline in a second copy. The comma is absent.

> **The small ads**
>
> REPLY TO THE PARENTHESIS AD: A footnote has enquired. It comes with three references and an explanation of each.

> **The answer, unfolded**
>
> ‘Only she borrowed the key’ excludes other borrowers. ‘She borrowed only the key’ excludes other objects. ‘She only borrowed the key’ may deny taking it permanently. One small word; three different defences.

### 4. A Reader writes to Penny

The fixture includes an explicit Plain Page beginning “For Penny:”. This shows the deterministic fallback. A generated response must quote the source exactly and pass the copy desk. An ordinary diary with the same words would not be selected.

**Morning**

> **The small ads**
>
> LOST: The word that was here a moment ago. Looks exactly like the gap between these teeth.

> **The small puzzle**
>
> Turn COLD into WARM. Change one letter at a time, keeping four letters and making an English word at every step. One route needs four changes.
>
> Answer in the evening paper.

> **A small enquiry**
>
> Listen for a small sound you can identify without looking. Write down the sound before naming its maker.
>
> If you’d like Penny to read it, open a Plain Page and begin with “For Penny:”. Keep the page. A later evening paper can carry your note. It stays in your Book.

**Evening**

> **From your side of the paper**
>
> From your note:
>
> The bench had been repaired with a blue plank.

> **The small ads**
>
> REPLY TO THE LOST-WORD NOTICE: Found it while washing up. Have forgotten why we needed it.

> **The answer, unfolded**
>
> COLD → CORD → CARD → WARD → WARM. Four changes. Other routes may work; this is the one the puzzle desk can account for without inventing a word.

### 5. A quiet day after a full one

Yesterday’s report remains unchanged. There is no lead about the Reader’s emerging theme, no retrospective filler, and no suggestion they should have written more.

**Morning**

> **The small ads**
>
> EXCHANGE: A perfectly good certainty for a question with working hinges.

> **The small puzzle**
>
> Please Observe Every Margin. A small poem is concealed in this notice. Read the beginnings.
>
> Answer in the evening paper.

**Evening**

> **The small ads**
>
> REPLY TO THE EXCHANGE NOTICE: Can the certainty be folded? The question is larger than expected.

> **The answer, unfolded**
>
> POEM: the first letters of Please Observe Every Margin. The smallest contribution to the literary pages this week. It still wanted a byline.

### 6. The local model is unavailable

The Academy report uses supplied facts. Authored pleasures still print. An outside discovery with no accepted prose is omitted; internal packets never become reader-facing fallback copy.

**Morning**

> **Academy report**
>
> Penny found a changed comma in an old headline. A red circle marks page four.

> **The small ads**
>
> WANTED: Someone to read the end of this notice and then allow it to end.

> **The small puzzle**
>
> A witness says: ‘The chair was empty when I looked.’ Which headline is supported? A: NOBODY CAME. B: CHAIR EMPTY AT TIME OF OBSERVATION. C: GUEST LEAVES EARLY. The best headline may be the dullest.
>
> Answer in the evening paper.

> **A small enquiry**
>
> Look at a place people wait. What has been worn smooth?
>
> If you’d like Penny to read it, open a Plain Page and begin with “For Penny:”. Keep the page. A later evening paper can carry your note. It stays in your Book.

**Evening**

> **The small ads**
>
> REPLY TO THE NOTICE ABOUT ENDINGS: Received.
>
> No further correspondence.

> **The answer, unfolded**
>
> B. The witness saw an empty chair. They did not establish that nobody came or that anyone left. Penny would shorten the headline, but she would keep that distinction.

### 7. A disputed account receives contrary evidence

Synthetic ledger facts for rehearsal, not new canon. The paper attributes Penny’s account and reports contrary evidence. It does not invent an admission, culprit, resolution, or Reader transformation.

**Morning**

> **Academy report**
>
> Who moved the bench?
>
> Penny’s account: The blue paint is fresh.

> **The small ads**
>
> FREE TO A GOOD HOME: An adjective. Very. Answers to ‘very’. Eats nouns if left unattended.

> **The small puzzle**
>
> The sign says STOP. Rearrange its four letters into three other English words. The sign itself should remain where it is.
>
> Answer in the evening paper.

**Evening**

> **Further to the morning report**
>
> Who moved the bench?
>
> Penny’s account: The blue paint is fresh.
>
> Later evidence: The old photograph already shows blue paint.

> **The small ads**
>
> REPLY TO THE ADJECTIVE AD: ‘Very’ is an adverb.
>
> CORRECTION: The advertisement has been edited. The word is still available.

> **The answer, unfolded**
>
> POST, POTS and SPOT all work. So do TOPS and OPTS. Five possible escapes from STOP, none of which requires moving the sign.

## Interest columns: a finding, not a definition

The initial rethink left the old research mechanism in place. Its first open-web
fallback asked DuckDuckGo's instant-answer endpoint about a bare interest; that
can return an encyclopedia abstract. Stronger writing instructions could not turn
that input into reporting. The interest desk now has a separate article selection
step before writing, inside the same Bleed press run.

- Search public news results filtered to seven days and extract direct publisher
  links. Prefer concrete discoveries, releases and research; filter definitions,
  introductory guides, duplicate tracking URLs and unrelated stock-tip headlines.
- Open up to four candidate publisher pages, two at a time. Read publication
  metadata and actual article text from structured Article data or article/main
  paragraphs. A search date, dateModified, headline or short abstract does not
  establish a current readable article. Reject missing evidence, stale articles,
  future dates, unsupported destinations and irrelevant results. Ordinary search
  remains a discovery fallback, subject to the same publisher checks.
- Choose one article. Use its real headline as the column title and print its
  publisher, publication date and URL. Hand its source text to the writer. Do not
  ask the writer to invent an angle from a bag of topical snippets.
- Ask for 75–110 words: who did what, the concrete finding or change, the best
  supported detail, and why it matters. Assume the Reader understands their own
  interest. Definitions, uses-of-AI lists, introductory history and generic
  predictions about the future fail the copy desk even when factually true.
- Remember the canonical article URL in the existing print record, across
  interests and editions. Exclude previously printed URLs, including tracking
  variants. No suitable current article means no interest column that day.

The interest desk no longer uses Reddit posts or instant-answer abstracts as
article evidence. Their existing routes for other features remain unchanged.
Personalized research still requires the existing explicit permission. No remote
lookup uses private Pages or correspondence. The newsroom version advances to
invalidate the earlier prepared-edition cache.

Live public-page checks confirmed news-card links and publisher metadata/body
formats. DuckDuckGo Lite returned a bot challenge during that check, which is
why the news route has direct publisher discovery rather than depending entirely
on that old fallback. These are network/format checks, not an on-device writing
quality claim. Fifteen added regression cases cover discovery, dated extraction,
rejection of background/undated/thin/stale/future/repeated material, AI abbreviation
matching, selected-story packets, concrete openings and print-record compatibility.
No build or Swift test execution was performed.

## Calendar repair

The reader previously queried from one hour before opening, filtered out every
all-day event not starting today, then applied an unsorted global cap. That lost
earlier appointments and tomorrow’s all-day events before the Bleed could print
them. The strip also admitted only events starting on the target date, losing
multi-day and overnight events. A prepared paper could bypass fetching entirely.

Fetching now spans local midnight today through midnight after the requested days,
retains all-day events, and sorts before its bounded cap. The strip uses interval
overlap with exclusive event ends. Calendar days, including daylight-saving
transitions, come from Calendar arithmetic rather than fixed 24-hour offsets.

The first unhandled Bleed calendar offer is no longer restricted to issue #1.
Denied or unavailable access gets a plain explanation instead of claiming the
calendar is connected and empty. Full permission is requested only when undetermined;
authorised refreshes do not request it again. The usage-description keys were
already present in both app configurations. Apple documents the full-access
requirement in [Accessing the event store](https://developer.apple.com/documentation/eventkit/accessing-the-event-store)
and the reset requirement after a premature fetch in
[requestFullAccessToEvents](https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents(completion:)).
The store is reset after a new grant before this fetch.

Prepared-paper opening paths now fetch before reusing copy, including the
desk route that bypasses generation. Manual opening uses the same press run.
Only practical
strips are recomposed, retaining the original edition date, story copy and puzzle.
Kept historical readbacks are not refreshed. The live toggle and permission flows
also report denied access accurately. These are verified source defects, not a
claim to have inspected the Reader’s current device permission state.

## Pocket reading

The existing newspaper sheet now sets article headlines, bylines, bodies and
rules separately, with header accessibility traits, Dynamic Type text styles,
selectable article text and labelled HTTP(S) source links. Older unstructured
papers retain their text fallback. PDF, Keep and sharing use their established
paths. This is source work; visual and accessibility behaviour await runtime QA.

## Validation and remaining gates

Swift parser validation and targeted whitespace checks passed for the modified
sources. New regression coverage contains 25 cases in
`Tests/InsideCoverCoreTests/BleedNewsroomTests.swift`; existing Bleed expectations
now reflect optional desks and the new voice. Coverage includes story revisions,
private/future business, correspondence consent and provenance, paired puzzles,
press-memory bounds and reprints, decoding, copy editing, permission revocation,
whole-day fetching, all-day and overnight overlaps, DST, denied calendar access,
cache refresh and source-link parsing.

The Reader/pool/print source work adds 26 cases in
`Tests/InsideCoverCoreTests/BleedReaderAndCurationTests.swift`, covering atomic
authorship, exact locked text and dates, privacy exclusions, whole passages,
literal returns, private letters retaining their channel, hard-day restraint,
source/form rest, bounded selection, canonical priority, alternate pleasures,
response boundaries, old decoding and export identity. These cases were parsed,
not executed. The independent PDF studies have visual and extraction evidence;
the native writer's pagination, fonts, links, Unicode, long headings and Quick
Look need their own runtime exercise after an authorised build.

No build, Swift test execution, simulator/device run or model writing session is
claimed here. The publisher/discovery network checks above verify formats only.
The next authorised build should run the Bleed, world-continuity
and monthly-authored-content regressions, then exercise both editions on device:
print → close → reopen; morning → evening; restart without Keep; permission
revocation; a submitted Plain Page; unavailable model; empty and populated calendar;
PDF and share controls; VoiceOver and large text; a shared morning pulse through
the nightly braid; a related authored scene without a false encounter receipt.
Timings and source-review quality
need real model evidence. Read paired live issues with actual Readers before
calling the prose moonshot quality.

The shipped content bank is intentionally finite: ten literary games, seven paired
small ads, six very short fictions and ten enquiry seeds. Longer-term pleasure
needs continued human authorship in this same editorial seam. There is no
fabricated “live news” fallback.
