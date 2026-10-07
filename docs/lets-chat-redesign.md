# Let's Chat — the redesign of "Ask the Book"

bj, 2026-10-04: it "takes forever to respond, and on the second round of
chatting, just repeats the Reader's entry. I want it to be able to talk about
stuff, without taking forever, and actually working." Also named as broken:
wrong/ignorant answers, voice off, UI clunky. Scope chosen: speed + chat UI +
new abilities. The reader-facing name is **Let's Chat** (the Page type stays
`.askTheBook` so no archive migration; the code names are internal).

## Diagnosis (what was actually wrong)

1. **The echo.** On turn two `followUpTerms` feeds the last message back in as
   search terms, so the reader's own earlier words come back as the top record.
   The prompt's ARCHIVE ANSWER CONTRACT then says the reply MUST use the
   strongest record in its first paragraph, and `finalizeGenerated` prepends
   that record's snippet if the reply did not. Result: the Book reads the
   reader's entry back to them.
2. **Every message pays for everything.** The full archive (all days, up to 20k
   events, 20k memories, 20k faculty entries) is reloaded and searched on every
   message, including "hi". The prompt then carries a ~1.2k-character knowledge
   header, canon, relationship, interior, patina and rules for a one-word
   greeting.
3. **Cold weights every turn.** `releaseAfterFlow` runs after every reply, so
   each message starts with a cold multi-GB Gemma load. (That release exists
   because with E2B resident a 6 GB phone has no room to raise the keyboard.)
4. **No streaming.** The generator already streams (`streamDetails`), but the
   chat shows nothing until the whole 520-token reply lands.
5. **Canned answers hijack real questions.** `BookInteriorAnswerGrounder`
   substring-matches ("what do you think about", "re-enchanted", "working on"),
   so "what do you think about my sister's wedding?" gets the Book's own
   opinion statement.
6. **Voice.** The chat RULES ask for "opinions, restraint and occasional dry
   humor", which is the essayist register bj rejected ([[book-voice-spec]]).

## Shape of the fix

**Router first** (`Shared/LetsChat.swift`, `LetsChatRouter`). A deterministic
read of the message decides intent — greeting, small talk, about the Book,
about the reader's history, about the world, or an action — and with it: does
this need the archive, how much lore, how long a reply. Greetings and small
talk never touch the archive. Only history questions pay for retrieval.

**Retrieval stops echoing.** Evidence that is a near-copy of anything the reader
has said in this chat is dropped before ranking. The answer contract becomes
"if an opened record answers it, build from it in your own words; never read the
reader's sentence back." The repair line quotes a title and date, never the
reader's own snippet.

**Echo guard after generation.** A reply that repeats the reader's message, or
the Book's previous answer, is cut back or retried once.

**Lean prompt.** Intent-sized: small talk gets canon + relationship + a few
rules and last-3-turn history, no knowledge packet, no memory block. History is
labelled so a 2B model does not copy it.

**Archive cache.** The loaded dataset is reused between turns until the store
file changes.

**Streaming bubbles.** The reply streams into a chat bubble; retrieved leaves
show as chips before the first token.

**Residency.** Devices with room keep the model warm for the whole chat and
release when it closes or goes idle; 6 GB-class phones still release between
turns so the keyboard can rise.

**Abilities** (all reader-confirmed, none invented by the model):
- *Remember this* — "remember that…" offers a chip; Yes writes a SelfFact.
- *Keep this* — keep the chat (or one exchange) as a Page.
- *Book starts a thread* — follow-up chips derived from what was opened
  ("Tell me more about…"), and the Book's own opener when it spoke first.

## Phases

1. Core (testable on the Mac): router, echo guard, retrieval fix, lean prompt,
   interior-grounder tightening. Tests.
2. App: streaming, archive cache, residency, chat surface.
3. Abilities.

## Follow-up (2026-10-04)

- **6 GB phones.** Weights now stay resident while the composer has focus (a
  keyboard that is already up stays up, and every reply was already generated
  in that state) and are released the moment focus goes, before the field can
  be tapped again. `chatMayKeepModelWarm` in `CapturePageSheet` is the switch
  if a 6 GB phone ever fails to raise a keyboard in the chat. Not yet verified
  on Rabbit.
- **Chat turns no longer wait 560 ms** for "paper arrival": new
  `LocalBrainPresentation.conversation`.
- **Overlapping model load with archive search: not built.** The cache already
  makes repeat searches cheap, so there is little to hide; and on a 6 GB phone
  the first archive read would land on top of a cold 2.6 GB load, where the
  measured floor is already 309-324 MB free. The gate also refuses a second
  caller (`busy`) rather than queueing, so it would have needed more than a
  small change. Revisit only with a measured search time.
- **Interior grounder voice pass done.** Canned lines rewritten to the voice
  spec; the generated parts they embed (opinion forge, fault admissions, long
  game strategy/hypothesis text) still carry their own voice and are not
  touched here.

## Owed

- Persistent ChatSession / KV prefix reuse across turns.
- No reminders/task system exists in the app, so "add a task" is not built.
