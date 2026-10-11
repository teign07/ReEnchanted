# App Privacy Inventory

Last updated: 2026-10-11

The working inventory for App Store Connect's App Privacy questionnaire.
Re-check it whenever a feature starts talking to a new host. The source of
truth for hosts is `grep -rhoE 'https://[a-zA-Z0-9.-]+' Shared InsideCoverApp`.

## High-level answers

- Tracking (ATT sense): **no**. No IDFA, no ad SDKs, no data brokers.
- Third-party analytics or crash SDKs: **none**.
- Account or login: **none**. A random installation ID (Keychain) is the only
  identity, used by our own Worker.
- Data sold: **no**.

## What leaves the device, by host

| Host | When | What is sent | Retained by us? |
| --- | --- | --- | --- |
| `reenchanted-physical-books.snow-potions.workers.dev` (our Worker) | Monthly shelf fetch (every install, on its own) | Random installation ID, short-lived session token | Installation hash in the session token only |
| same Worker → Stripe, Lulu | Reader orders a printed Book, gift, or Bound Year | Shipping name, postal address, email, phone if given; print-ready interior + cover PDFs; payment handled by Stripe's SDK | Order, membership and gift records in Stripe + Worker storage; print PDFs in private R2 for 3 days |
| `huggingface.co` | Reader installs the local brain | Plain file download (IP, user agent) | No |
| `api.open-meteo.com` | Weather seal | Coordinates for the forecast | No |
| `api.nal.usda.gov` | Reader asks for a nutrition estimate | Food description they typed | No |
| `duckduckgo.com`, `lite.duckduckgo.com`, `api.duckduckgo.com` | "Let my interests visit the public web" (off by default) | An interest phrase, broad home-place description | No |
| `eutils.ncbi.nlm.nih.gov`, `pubmed`, `api.openalex.org`, `api.semanticscholar.org`, `doi.org` | Faculty research / public findings | Topic queries, no reader text | No |
| `www.gutenberg.org` | Public-domain text fetches | Book identifiers | No |
| `oauth.reddit.com`, `www.reddit.com` | Only if `RedditInstalledAppClientID` is set (it is **empty**) | — | — |
| `community-api.reenchanted.app` (Public Margins) | **Closed for launch** (`PublicMarginsAPI.isAvailable = false`). Only a reader who sent something earlier can withdraw it | Deletion receipt | — |
| Apple speech / Journaling Suggestions | Reader taps dictation or the suggestions picker | Governed by Apple | No |

HealthKit data never leaves the device **except** when the reader turns on
"Include Fuel & Inner Weather" for a bound volume (off by default) and then
orders paper: a summary of body and food notes is in the PDF that goes to
Lulu. The toggle says so under its label. Body and fuel pages are excluded
from every edition by default (`EditionCurator.defaultPrivateTypes`).

Photos leave only inside a print PDF the reader orders.

## App Store Connect answers

Data **collected** (linked to the reader, used for App Functionality only; none
for tracking, ads, or analytics):

- **Contact Info**: Name, Email Address, Physical Address, Phone Number. Print
  orders and Bound Year only.
- **Financial Info → Payment Info**: card handled by Stripe for printed goods.
- **Purchases → Purchase History**: print orders and Bound Year membership.
- **User Content → Photos or Videos** and **Other User Content**: the print-ready
  PDFs of the reader's own Book, on order.
- **Health & Fitness → Health**: only through the opt-in print toggle above.
  Declare it; the honest answer is "yes, if they choose".
- **Identifiers → Device ID**: the random installation ID used for the monthly
  shelf session and to tie a printed order or membership to this install.

Data **not collected** (requests go straight to a public service and nothing is
kept by us or on our behalf): weather coordinates, nutrition queries, research
queries, model downloads. Conservative option: also declare **Location →
Coarse Location**, not linked, App Functionality, for Open-Meteo. It costs
nothing in the label and avoids an argument.

## Before each submission

- No new host in the grep above without a row here.
- `PublicMarginsAPI.isAvailable` still `false`, or this doc and the privacy
  policy updated together.
- `RedditInstalledAppClientID` still empty.
- `LandingPage/privacy.html` agrees with this table.
