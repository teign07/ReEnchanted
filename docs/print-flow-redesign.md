# The print flow — what's confusing, and what it should be

Written 2026-08-08, before adding the seasonal volume or the Bound Year to it.
Adding a third binding to the flow as it stands would make a confusing screen
more confusing, so the shape comes first.

**This is not a criticism of the hardening.** The Worker and its client are in
very good order — expiring quotes, session capabilities, signed webhooks, a
Durable Object serialising Lulu submission, PII erased once the job is accepted.
Every gate below exists for a real reason. The problem is that the *reasons* have
been surfaced as the reader's job.

---

## The diagnosis, in one line

**It is the operator's console, shown to the customer.** The reader is asked to
proof PDFs, tick a vendor disclosure, upload print files, submit a print job and
refresh its status — none of which is buying a book. Nobody ordering a book
anywhere else uploads a print file.

---

## Panel by panel

The studio renders five panels in this order, in `BookShopSheet.swift`:

| | Panel | What the reader is asked to do |
|---|---|---|
| 1 | `physicalBookStudioHero` | Pick a binding, see the cover |
| 2 | `physicalBookStudioPrintFilesPanel` | **Proof interior**, **Proof cover**, share the PDFs |
| 3 | `physicalBookOrderReviewPanel` | Check the order |
| 4 | `physicalBookStudioCheckoutPanel` | Pay |
| 5 | `physicalBookSubmissionPanel` | **Upload print files**, **submit**, refresh status |

### 1. Paying is not the last step

Checkout is panel 4 of 5. After paying, the reader still has to tick a consent
box, upload print files and press a final submit. `physicalBookSubmissionReady`
is a six-condition gate:

```
pendingPhysicalBookOrder != nil && printFileChecksums != nil &&
hostedPrintFiles != nil && currentQuoteRequest != nil &&
thirdPartyPrintConsent && isQuoteServiceConfigured
```

Every one of those is sound engineering. But from the reader's chair, they paid
for a book and the book did not order itself.

### 2. The vocabulary is the vendor's

The readiness copy, verbatim:

> "Checkout creates a saved order before final print submission unlocks."
> "Confirm that **Lulu** will receive the print files before upload or final submission."
> "This paid order needs its original live quote. Get a fresh quote if this was saved before the latest order handoff."
> "Make print PDFs first so the interior and cover proofs are ready."

*Handoff. Checksums. Unlocks. Live quote. Submission.* And it **names the print
house to the reader**, who did not choose them and cannot change them. This is a
build log with buttons on it.

It is also the one screen in the app where the Book does not speak. "Print
Files", "Proof interior", "Refresh status" — there is no voice here at all,
feral or otherwise.

### 3. The address is collected twice

`physicalBookQuotePostalCode` and `physicalBookQuoteStateCode` for the quote,
then `physicalBookStreet1/2`, `City`, `ShippingStateCode`, `ShippingPostalCode`,
`CountryCode`, `RecipientName`, `PhoneNumber` for the shipment. The reader types
their postcode, then types it again.

### 4. Twenty pieces of state, one screen

Around twenty `@State` properties drive the studio, several of which are stages
of the same conveyor (`quote → paymentIntent → checksums → hostedFiles →
submittedOrder`). The screen has no single answer to "where am I?", which is
why it reads as a panel of instruments rather than a process.

---

## The shape it should be

**The reader orders a book. The Book does the printing.** Every step that exists
because a print house needs it should be invisible.

One linear flow, four steps, each answerable in a sentence:

1. **How it's bound.** Cover preview, binding, and the upsells — cloth, foil, a
   cover off their own camera roll. One screen, one decision.
2. **Where it goes.** One address, entered once. The quote derives from it; no
   separate postcode step.
3. **What it costs.** The itemised breakdown that already exists — manufacturing,
   shipping, tax, the markup — because *"everything about money stays simple,
   clear, and fair"* is the brand and this part is already right.
4. **Pay.** And that is the last thing the reader does.

Then the Book takes over: PDFs generated, uploaded, job submitted, all without a
button. The reader sees a state, not a queue — *"It's gone to the bindery"*, then
*"It's on its way"*, with tracking when there is tracking.

### What happens to the steps that vanish

| Today | Becomes |
|---|---|
| Proof interior / proof cover | **Optional courtesy** — "Look inside before it prints." Never a gate. |
| Third-party print consent | Folded into the purchase terms, where consent belongs. Named once, plainly, not as a checkbox blocking a button. |
| Upload print files | Automatic, after payment. |
| Final submit | Gone. Paying is the submit. |
| Refresh status | Automatic; the webhook already knows. |

### What must not change

- **Server authority.** The Worker still owns pricing, still verifies the
  PaymentIntent amount, still serialises submission through the Durable Object.
  None of this touches that.
- **The itemised price.** It is the most on-brand thing on the screen.
- **Failing closed.** Every gate stays; it simply stops being a button. A blocked
  order should say so in the Book's voice and tell the reader nothing they
  cannot act on.

---

---

## The Pressing — making it an event

Ordering this book is the climax of the entire product. Someone is about to hold
their own year as an object. It currently reads as a shipping form.

**The reframe that makes "satisfying" and "frictionless" the same goal:** today
the *reader* does the waiting work — proof, upload, submit. Move all of it to the
machine and there is still an unavoidable few seconds of real latency. That
latency is where the ceremony goes. Same seconds, opposite feeling. And
`BinderySewingOverlay` already exists, doing exactly this at the onboarding
finale.

### Five beats

**1. The book in your hands.** Full-bleed cover, their real one — patron
frontispiece, their season's title. **Swipe to change the binding**, the way you
turn a book over to look at it. Not a picker, not a segmented control. Each swap
re-renders the true preview with a haptic. This is the only "choosing" screen and
it is made of the object itself.

**2. One postcode.** The only typing in the entire flow, and only because the
quote cannot price shipping without it. Framed as the Book asking, not as a form
field.

**3. The till.** The itemised breakdown that already exists — manufacturing,
shipping, tax, markup — in the clerk's voice. This is the most on-brand screen in
the app and it is already right; it just needs to be *seen* rather than buried
in panel three of five.

**4. One tap.** Apple Pay. Face ID and it is done — and Apple Pay hands back the
name, email and full shipping address, which is what deletes the second address
form entirely. Postcode for the quote, biometrics for everything else.

**5. The Pressing.** Pay, and the ceremony runs *while the real work happens*:
PDFs generate, upload to R2, the Lulu job submits. Gold stitches walk the spine.
The Cast murmurs. Then it is gone.

**The stitches must track real progress.** Files written → stitches advance;
upload accepted → the spine cinches; job accepted → the seal. Never a fake
timer. If the upload fails the stitches stop and the Book says so plainly — a
ceremony that lies once is never trusted again.

### The beat that makes it part of the story

**A keepsake Page, pressed into the Book.** Not a receipt screen — a Page, kept:
*the day you sent The Long Thaw away to be bound.* It goes on the shelf with
everything else and turns up again later the way kept pages do.

Nothing else in the app makes a purchase part of the story. This is the one that
should.

---

## Order of work

1. **Apple Pay.** Four lines on `PaymentSheet.Configuration` and the biggest
   friction in the flow is gone: no card number, no expiry, no CVC, no typed
   address. Today a reader hand-types all of it for a $68 keepsake.
   *Dependency: needs a merchant identifier and the Apple Pay capability, which
   needs the paid developer account — so this is first in value, not
   necessarily first in time.*
2. Collapse the address to one postcode; let Apple Pay return the rest.
3. Make submission automatic on payment success, driven by the webhook the
   Worker already signs and verifies. Paying becomes the last thing the reader
   does.
4. Replace the five panels with the five beats; proofing becomes a courtesy.
5. The Pressing ceremony, wired to **real** progress.
6. The keepsake Page.
7. Rewrite every string to `BookVoice.animismLine`. Right now this screen is
   mute, and it is the screen where the reader spends money.
8. **Only then** add the seasonal softcover to the binding picker
   (`bookOfYouVariants` → `allPrintableVariants`, a one-line change that is
   deliberately being held back until it lands somewhere coherent).
9. Then the Bound Year membership and the upsell catalogue.
