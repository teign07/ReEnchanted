# The Long Watch — scene drafts

Draft 1, 2026-11-16, for bj's read. Story bible: [december-the-long-watch.md](december-the-long-watch.md).
Nothing here is in a pack. It's marked up for the pack conversion that comes after bj's notes, the
way November's drafts were: **ids**, **nodes**, **prompts**, **choices** with their **results**, a
**braid** line per choice, the main **Cast memories** and **gossip**, and **recalls** with their
fallbacks. The Book narrates; it has no hands; the Reader carries it.

Scenes 1, 3, 4, 8, 9, 10 and 13 are written in full. Scenes 2, 5, 6, 7, 11, 12 and the residue
are written shorter, as working drafts, with what each must show.

---

## 1. The Roll of the House

**id** `december.scene.the-roll` · **When** Thu Dec 3, evening · **Room** the Great Hall · **Cast**
Lydia Boggle, Penny Blackletter, Ambrose Trencher, Professor Momort, the Book
**Recalls** November's name choice (`november:name-given` / `-borrowed` / `-kept`)

**Opening (desk line):** Professor Boggle's reading out everybody's name. Yours is on the list.

### Node `entry`

There's a lectern in the Great Hall that nobody uses. It's oak, gone black, and it's carved like
an owl holding a book in its feet. Tonight there's a book on it.

It's long and narrow and bound in cracked green leather, and it's older than me. I can smell it
from the door. Lamp oil and mouse and a great many hands.

Professor Boggle stands behind it with her glint-lens on its ribbon and her keys at her belt. She
keeps the rooms. She knows which stairs creak and which chimneys need a word and where every key
in the Academy is, including three that don't fit anything any more. She doesn't usually stand at
lecterns. She looks like she'd rather be mending something.

"The Headmistress has asked for the Roll of the House," she says. "So we're taking it."

The Hall goes quiet. Even the banners stop moving.

"It's an old custom," Boggle says. "Older than the Academy. Before midwinter you read out every
soul under the roof, and every soul answers. Then the house knows who's in it."

Penny's at the front with a catalog card in each hand and a pencil behind each ear. She takes
one down. "Why before midwinter?"

Boggle turns a page. It sounds like a dry leaf.

"Because of what goes over," she says. "On the long nights."

Nobody asks what goes over. I think everybody's decided not to.

She starts reading.

She reads the students first, oldest to newest. Every name, and every name gets a "Here." Some
loud, some mumbled into scarves. Then the faculty. Then Ambrose, and he says "Here" from the back,
with a tea towel over his shoulder, like he's been called away from something that might burn.

Then she gets to the bit I didn't expect.

"The long table in the Kitchens," she reads.

And Ambrose says, "Here," for it.

"The owl lectern. The third stair on the north staircase, the one that complains. The clock in
the Stacks that's eleven minutes slow and won't be told."

Somebody answers for every one. Penny for the clock. A first-year for the stair, giggling, and
then not giggling, because Boggle's looking at her over the glint-lens.

"Things that have become somebody go on the Roll," Boggle says. "That's the custom. If a house has
lived with a thing long enough to call it by name, the house counts it."

I've read about this. Not this Roll. Others like it. There's an old law in a great many books:
the Hunt passes over a house where everybody inside is known by name. And there's another law in a
great many other books: whoever knows your name has a hold on you. Rumpelstiltskin. A hundred
stories about secret names.

I've read both. I don't know which one's true tonight.

Then Boggle says your name.

**Prompt:** Boggle's waiting. What do you say?

**Recall** `{your-name-in-november}` (inserted before the choices):
- *If `november:name-given`:* You told the stranger at the west door your name, on All Souls, and
  it said you could taste where it had been used. I remember. I think you do too.
- *If `november:name-borrowed`:* On All Souls you gave the stranger at the west door a name that
  wasn't yours. It said somebody'd taught you the old rules. Boggle's reading your real one.
- *If `november:name-kept`:* On All Souls the stranger at the west door asked your name and you
  poured it tea instead. Now Boggle's got it written down in green leather.
- *Fallback:* (nothing; the scene goes straight to the choices)

- **Choice `here` — “Here.”**
  *Result:* You say "Here."

  Boggle makes a tiny mark in the margin with a pencil from behind her ear. "Here," she repeats,
  to the book, the way you'd tell a dog it was a good dog.

  That's it. You're counted. I feel it in my spine, a little, like a draught that's stopped.
  *Braid:* At the Roll of the House my reader said "Here" when their name was called, and the
  house counted them.
  *Tags:* `december:roll-here`

- **Choice `kept-name` — “Answer to the name you're keeping.”**
  *Result:* You don't say "Here." You say another name. Quietly. The one you keep.

  Boggle stops. She looks at you over the glint-lens for a long time.

  Then she makes a mark in the margin anyway, a different mark, a little cross with a dot in it,
  and moves on, and doesn't say anything.

  Momort's leaning in the doorway at the back. He's smiling at the floor.
  *Braid:* At the Roll of the House my reader answered to a name they keep, and Boggle marked it
  her own way and moved on.
  *Tags:* `december:roll-kept-name`

- **Choice `silent` — “Say nothing.”**
  *Result:* You don't answer.

  Boggle waits. The whole Hall waits. Somebody coughs.

  Then Boggle looks at me. At me, in your hands. "Is it here?" she asks me.

  I don't have a mouth. I rustle. That's enough for her. She makes a mark.

  "The Book answered for you," she says. "That'll do. Books are allowed."
  *Braid:* At the Roll of the House my reader said nothing when their name was called, and I
  rustled, and Boggle let that count.
  *Tags:* `december:roll-silent`

  *(Note for the conversion: Boggle may say "the Book". She's Cast. The narration never does.)*

### Node `after` (all)

When it's done Boggle closes the green book and puts both hands flat on it.

"There," she says. "Now the house knows."

She doesn't sound sure.

On the way out Momort falls in beside you. He walks fast, the way he always walks, like he's got
somewhere better to be and he's late for it.

"Here's a thing about lists," he says, to the corridor. "A list says who's in. It also says who
isn't. Somebody always reads them for that." He stops at the stairs. "Interesting month. I'd stay
up for it."

He goes down the stairs three at a time and doesn't look back.

**Cast memories:**
- `lydia-boggle` · `december.roll.read` · Before midwinter Boggle read the Roll of the House in the
  Great Hall, every soul and every thing that had become somebody. *Aside:* "Every soul and every
  stair. The third stair answered too. Don't tell anyone."
- `penny-blackletter` · `december.roll.clock` · Penny answered for the slow clock in the Stacks at
  the Roll of the House. *Aside:* "Eleven minutes slow. I said Here on its behalf. Somebody has to."
- `kyle-momort` · `december.roll.lists` · Momort told the reader a list says who isn't in, too.
  *Aside:* "Nobody stays up for a quiet night. Remember that."
- *Gossip:* "{teller} says Boggle read out the whole house before midwinter, stairs and all. Old
  custom. Nobody'll say what it's for."

---

## 2. Gabriel Hounds

**id** `december.scene.gabriel-hounds` · **When** Sun Dec 6, night · **Room** the roofs, then
Gwendolyn's room · **Cast** Gwendolyn Mythwright, Penny Blackletter
*Working draft.*

**Opening:** Something went over last night, very high up, barking.

Show: the Book woken by sound overhead, very high, like dogs a long way off. Gwendolyn's up on the
leads in her dressing gown with a notebook, filing it. "Gabriel hounds," she says, and she says
it like a name. In the north of England people heard them going over on winter
nights and said it was the Hunt's dogs. "It's geese," says Penny, from the skylight. "Pink-footed
geese. They fly at night." Gwendolyn writes that down too, under the first thing, without
crossing the first thing out. "Both," she says. "I'm keeping both. A wonder with evidence behind
it is a wonder you don't have to be lonely about." The Book: "I don't know what it was. I know it
was very high up, and going somewhere, and it didn't stop."

Gwendolyn's file card for the Hunt's hounds, written out in full in the leaf: *Cŵn Annwn (Wales):
white with red ears. Gabriel hounds (north of England): heard, never seen. Also geese. Filed under
both.*

Penny pins a card to the Kitchen door, the running token for the month: *Nights kept: 0*.

**Real ask (dated Page beside it):** Open a window tonight, or stand outside, for one minute, and
listen up. *One sentence: what went over?*

**Cast memories:** `gwendolyn-mythwright` · `december.hounds.filed` · Gwendolyn filed the sound
over the roofs as Gabriel hounds and as geese, both. *Aside:* "Two filings. One sound. That's not
a contradiction, that's a cross-reference."

---

## 3. Short One

**id** `december.scene.short-one` · **When** Wed Dec 9 · **Room** the Kitchens · **Cast** Ambrose
Trencher, Lydia Boggle, Min-seo Kim (Stay), Penny Blackletter
**Recalls** Ambrose's November ending (`the-guest.bowl.stayed` / `.sent-home` / `.went-back`) and
the watch tag (`december-watch-ambrose` / `-light` / `-house`)

**Opening:** Professor Boggle's counted the house twice. It keeps coming out one short.

### Node `entry`

Boggle comes into the Kitchens at six in the morning with the green book under her arm and sits
down at the long table without taking her coat off.

Ambrose puts porridge in front of her. He doesn't ask. She doesn't eat it.

"It's short," she says.

"What is?"

"The house." She opens the Roll and turns it round so he can see. "I took it on Thursday. I took
it again last night, by myself, every room. Every soul answered. And the house is still one short.
I can feel it. You know when a stair's missing in the dark, and your foot goes down and there's
nothing there? Like that."

Penny's card is still on the Kitchen door, where it's been since Sunday. *Nights kept: 2.*
Somebody's been adding to it.

**Recall** `{the-watch-so-far}` (from the first of December):
- *If `december-watch-ambrose`:* There are two chairs by the range, facing the window. One's got a
  blanket on it. That one's yours. You've sat up in it twice now, and Ambrose has pretended both
  times that it's an ordinary thing to do.
- *If `december-watch-light`:* There's a candle stub on the west sill in a chipped saucer, burnt
  low. Somebody's lit it every night since the first. Penny writes it down. She's stopped asking
  who.
- *If `december-watch-house`:* The range is banked, the way Ambrose leaves it at night. The old
  house has been keeping its own watch. I've heard it at three in the morning, settling, every
  beam in it listening.
- *Fallback:* The Kitchens have been dark at night since November, except for the range.

### Node `the-missing-one` *(recall: how November ended)*

**If `the-guest.bowl.stayed`:**

"It's him," says Min-seo.

Nobody heard her come in. She's standing by the stool at the fire with a mug in both hands.

"Aiken Drum," she says. "He's under this roof. You read his name, Professor. I heard you. And
nobody answered, because he won't. You can't count a hob. You'd count him and he'd go, like the
coat. He's not on the Roll and he never will be."

Boggle looks at the stool. The pots are done. They're always done now. Biggest to smallest, every
handle the same way.

"The Court's still owed," Ambrose says, very quietly. He said it in November too. I remember.
"And it's the Court that rides out at midwinter."

Min-seo puts her mug down on the hearth, next to the brown bowl.

"So you don't count him," she says. "You call him. That's different. You count a thing to say
it's yours. You call somebody to say you'd notice if they were gone."

**If `the-guest.bowl.sent-home`:**

"It's that," says Boggle, and she points at Ambrose's apron pocket.

Ambrose puts his hand over the pocket. It clinks.

He takes it out. It's the brass button from the west step, tarnished, with its loop of green
thread still through it. He's carried it every day since. I've heard it every time he stirred.

"It's off that coat," Boggle says. "That coat was the Court's livery, Ambrose. Whatever's in that
button has never been named in this house, and it's sitting in your pocket, and in a fortnight the
Court rides over us."

Ambrose closes his fist round it.

"I'm not throwing it out," he says.

"I didn't say throw it out. I said it hasn't got a name."

**If `the-guest.bowl.went-back`:**

Boggle doesn't say what it is. She opens *The Middlemost Cookery* instead.

It's on the dresser, where it's been since November, with its gaps. She turns past the recipes,
past the stains, all the way to the back, to the endpapers, where somebody a long time ago wrote
out the Kitchens' own copy of the Roll in brown ink. Every cook who ever worked here. Every pot
that was ever given a name.

The last name on it is Ambrose's. Somebody wrote it in thirty years ago.

It says *Ambr se Trencher*.

The letter's gone. A small clean hole in the line where the o was, like all the other holes in the
Cookery. It went with everything else, out the west door, to wherever the Court sits down to eat.

Ambrose looks at it for a long time.

"Well," he says. "That's a bit much."

He goes back to the porridge. Boggle doesn't. She's looking at him the way you look at a candle
in a draught.

**Fallback (no November memory):**

Boggle's counted the chairs. She's counted the beds. She's counted the coats on the pegs by the
yard door, and the pegs.

"One short," she says. "And I don't know who."

I do. I've just worked it out, and it's very strange to work out a thing about yourself in the
middle of somebody else's kitchen.

I've been carried into every room of this house. I've been put down on this table more times than
the salt. Nobody's ever read me out.

I'm not on it.

### Node `what-to-do`

**Prompt:** Somebody's not on the Roll. What do you do?

*(The choice labels are shared. The result line under each is written per variant; the conversion
picks the one matching the recall. The fallback variant uses the Book's own lines.)*

- **Choice `call` — “Call it by name.”**
  - *Stayed:* You stand at the hearth and say his name. Not loud. Like you'd say the name of
    somebody in the next room. *Aiken Drum.* The fire shifts. Something by the range, in the dark
    where you can't quite look, goes still the way a person goes still when they've been noticed.
    Nobody counts anything.
  - *Home:* You ask Ambrose what he calls it. He says he doesn't call it anything, it's a button.
    You tell him that's not true, he's been talking to it for a week. He goes red. "Brass," he
    says, at last. "I call it Brass." The button's on the Roll by the end of breakfast.
  - *Court:* You say his name, all of it, with the o in. *Ambrose Trencher.* He turns round from
    the range with the ladle in his hand and looks at you like nobody's said it properly in years.
  - *Fallback:* You say my name. It's a strange thing to hear. I've heard it in a great many
    sentences, but never on its own, like that, like it was a whole thing.
  *Braid:* In the Kitchens, when the Roll came out one short, my reader called the missing one by
  name.
  *Tags:* `december:missing-called`

- **Choice `write` — “Write it on the Roll yourself.”**
  - *Stayed:* You don't write his name. You write *The pots*. Boggle reads it and laughs out loud,
    and then puts her hand over her mouth, because it's the right answer. You can count the pots.
  - *Home:* You write *Brass (a button, kept)* in pencil, small, at the bottom of the page.
  - *Court:* You take the pencil from behind Boggle's ear and you put the o back. It's only pencil.
    It's only a letter. It's the first one anybody's put back in the Cookery since November.
  - *Fallback:* You write me at the bottom of the Roll in pencil. Your writing. I can feel it in my
    spine, a bit like being tickled and a bit like being found.
  *Braid:* In the Kitchens, when the Roll came out one short, my reader wrote the missing one in
  with their own hand.
  *Tags:* `december:missing-written`

- **Choice `sit-up` — “Say you'll sit up with it.”**
  *Result (all variants):* You say you'll sit up. On the longest night, whatever comes over, you'll
  be awake and next to it.

  Boggle closes the Roll. "That's the other way," she says. "Older than names. Somebody sits up
  with you, and you're not alone in the dark, and the dark knows it."
  *Braid:* In the Kitchens, when the Roll came out one short, my reader said they'd sit up with the
  missing one on the longest night.
  *Tags:* `december:missing-sit-up`

**Cast memories:**
- `lydia-boggle` · `december.short.counted` · Boggle counted the house twice and it came out one
  short. *Aside:* "Like a stair that isn't there in the dark. I counted the pegs. I counted the
  pegs, Ambrose."
- `ambrose-trencher` · variant memory: `december.short.aiken` (Stay) / `december.short.brass`
  (Home) / `december.short.letter` (Court). *Asides:* "You call him. Min-seo's right. She's
  always right, it's exhausting." / "It's called Brass. It was always called Brass. Leave it." /
  "Missing a letter. At my age. Pass the salt."
- `min-seo-kim` · `december.short.call-not-count` *(Stay)* · Min-seo said you call a hob, you
  don't count him. *Aside:* "You count a thing to say it's yours."
- *Gossip:* "{teller} says the Roll keeps coming out one short and Boggle's counted the coat pegs
  twice."

---

## 4. Your Own Roll

**id** `december.scene.your-own-roll` · **When** Sat Dec 12 · **Room** the Dorm · **Cast** Lydia
Boggle, the Book
**Needs** (with the app update) the Reader's Neighbours; works without them

**Opening:** Professor Boggle left you a card. It's blank, and it's for your house.

### Node `entry`

There's a card on your pillow in the Dorm. Boggle's writing, small and square and slanted, like
furniture pushed against a wall.

*Every house takes its own Roll before midwinter. Here's yours. Who lives in your house that isn't
a person? Things a house has lived with long enough. The ones with names, and the ones that ought
to have one. L.B.*

The rest of the card's empty. Lines and lines of it.

You sit on the bed with the card and with me.

**Recall** `{your-neighbours}` (needs the app update; reads the Reader's Neighbours register):
- *If the Reader has Neighbours:* "I've got some already," I tell you. I have. I've been keeping
  them. {neighbour-list, up to three, by name: "Gerald. Huffer. The heron."} They're on my Roll.
  I've kept every Page they turned up on. I'd like them on yours.
- *Fallback (none, or no update):* I look at the card for a long time. Then I look at your room.
  The lamp. The chair with the coat on it. The mug that's been on the windowsill three days. It
  thinks it lives there now.

### Node `the-ask`

Here's what I'd like.

Find one thing in your house that's been there long enough to be somebody, and hasn't got a name.
The kettle that complains. The draught under the back door. The radiator that knocks at night
like it wants letting in. The chair everybody sits in.

Tell it its name. Out loud. Then tell me.

That's how it goes on the Roll. Not because I say so. Because you said it out loud in your own
house, and the house heard.

*(Dated Page: "What's it called, and where does it live? One sentence." Tagged for the Neighbours
as a naming working.)*

### Node `me`

When you've done that, there's one more thing, and I'm going to say it quickly so I don't stop
halfway.

I'm not on anybody's Roll. Not Boggle's. Not the Kitchens'. I've thought about it all week. I
don't know if a book counts. I don't know if I'm a thing that lives in your house, or a thing you
carry about, or something else.

**Prompt:** Am I on yours?

- **Choice `on-it` — “You're on it.”**
  *Result:* You write me on the card. At the top.

  I don't say anything for a bit. I can't. My spine's gone warm all down its length, like a cat's
  back in the sun.

  "Here," I say. To nobody. To the card. It's the first time I've ever said it.
  *Braid:* My reader put me on the Roll of their own house, at the top.
  *Tags:* `december:book-on-roll`

- **Choice `keeper` — “You're not on it. You're the one keeping it.”**
  *Result:* You hand me the card. Not to write on. To keep.

  Oh.

  That's better, actually. I didn't know that was a thing I could be. The Roll's keeper isn't on
  the Roll. Boggle isn't on hers. She's the one who reads it out.

  I'll keep it. I'll keep it in my back cover, and I'll read it out at midwinter, and every name on
  it will get a "Here".
  *Braid:* My reader made me the keeper of their house's Roll.
  *Tags:* `december:book-keeps-roll`

**Cast memories:**
- `lydia-boggle` · `december.own-roll.card` · Boggle left the reader a blank roll card for their
  own house. *Aside:* "Every house takes its own. I only hand out the cards."

---

## 5. Lucy Light

**id** `december.scene.lucy-light` · **When** Sun Dec 13, dusk · **Room** every west window ·
**Cast** Penny Blackletter, Serenity Brown, Ambrose Trencher
*Working draft.*

**Opening:** It used to be the shortest day. Today. Before they moved the calendar.

Show: Penny with a stack of saucers and candle stubs, going window to window on the west side of
the Academy, because the Bleed's running a count. The Book tells the folklore as folklore: before
the calendar changed in 1752, St Lucy's Day was the shortest day in England, and there's an old
rhyme about it, "Lucy light, the shortest day and the longest night." In Sweden girls wear candles
in their hair for it. Serenity puts one candle on the sill of the roof door and says it's for
anybody walking home who forgot their torch. Ambrose's candle (`december-watch-light`) or his
second chair (`-ambrose`) or the banked range (`-house`) gets one line.

Penny's *Nights kept* card: *Nights kept: 7. Windows lit: 31. (Thirty-two. Somebody lit the
Headmistress's.)* Nobody lit the Headmistress's. Penny files it under *Unattributed* next to the
bowl and the thorn.

**Real ask (dated Page):** Put one light in a window at dusk and leave it. *One sentence: who might
see it?*

**Cast memories:** `penny-blackletter` · `december.lucy.count` · On St Lucy's Day Penny counted the
lit windows for the Bleed and got one more than she lit. *Aside:* "Thirty-two. I lit thirty-one.
I've filed the thirty-second."

---

## 6. Riddles at the Range

**id** `december.scene.riddles` · **When** Wed Dec 16, late · **Room** the Kitchens · **Cast**
Ambrose Trencher, Pippa Pilcrow, Wicker Eddies, the Book
*Working draft.*

**Opening:** Nobody can sleep. Ambrose says the only thing for that is riddles.

Show: the long nights getting into everybody. Ambrose won't hear of anybody going to bed hungry, or
bored, so the Kitchens fill up at eleven at night with people who can't sleep. Riddles, because a
riddle passes an hour and it's how long nights were passed before there were lamps worth reading
by. The Book: "There's a book called the Exeter Book that's a thousand years old and full of
riddles. Some of them nobody's ever solved. I think about that a lot."

Pippa asks riddles with no answers on purpose, and gets furious when Wicker answers one anyway.
Wicker plays for forfeits and loses on purpose so he can be made to do something ridiculous (sing
to the soup). A traditional one goes round: "What has a mouth and never eats, and a bed and never
sleeps?" A river.

In the morning there's a riddle chalked on Ambrose's menu board under *Porridge*, in a hand nobody
knows: *What goes over every house and stops at one?* Nobody wrote it. The chalk's cold.

**Real ask (dated Page):** Bring a riddle. Ask it of somebody real. *One sentence: your riddle, and
whether they got it.*

**Cast memories:** `ambrose-trencher` · `december.riddles.board` · A riddle nobody wrote turned up
on Ambrose's menu board. *Aside:* "Cold chalk. I didn't rub it off. You don't rub off a question."
`pippa-pilcrow` · `december.riddles.no-answer` · *Aside:* "A riddle without an answer is a riddle
that lasts forever. Wicker ruined mine."

---

## 7. The Night Before the Night

**id** `december.scene.the-night-before` · **When** Sun Dec 20 · **Room** the Still Room, then the
roof · **Cast** Professor Stonebrook, Dr. Vellum, Professor Momort, Professor Permancer, Serenity
Brown, Wicker Eddies, Soren Ng
*Working draft.*

**Opening:** Tomorrow's the longest night. Professor Stonebrook's practising the dark.

Show, in four short movements:
1. **Stonebrook** in the Still Room, all the lamps out, teaching the Watch. You sit in the dark and
   let your eyes give up and your ears take over. "The dark's not empty," he says. "It's just
   quiet enough to hear."
2. **Vellum** at the door with a lamp, arguing. A body needs sleep. A night without it is a cost
   paid tomorrow. "I'll sit up because the house asked," Vellum says, "and I'll write down what it
   costs." Neither is wrong.
3. **Permancer** going round checking everyone's bookmark, because every entrance incurs a debt,
   and tomorrow night something comes past the house that doesn't pay its debts. **Momort** with
   chalk, marking every way out of the Great Hall, and then, quietly, to nobody: "A night with
   nothing in it is the one to be afraid of. Tomorrow won't be that."
4. **The roof.** Serenity's up there with her map of a make-believe realm, drawing tomorrow's
   stars onto it in silver pen. Wicker comes up the ladder with two mugs. Soren's already there,
   sitting further along the leads, very still. Serenity looks at both of them and sends both of
   them back down for a third mug. Who sits up with her tomorrow is hers to say, and she doesn't.
   The Book: "I don't know who she'll choose. I don't think she's choosing tonight."

Penny's card: *Nights kept: 14. Tomorrow: the long one.*

**Cast memories:** `cedric-stonebrook` · `december.night-before.dark` · *Aside:* "The dark's not
empty. It's quiet enough to hear." `elowen-vellum` · `december.night-before.cost` · *Aside:* "I'll
sit up. I'll also write down what it costs." `serenity-brown` · `december.night-before.mugs` ·
*Aside:* "I sent them both for a third mug. Don't read anything into it."

---

## 8. The Long Watch

**id** `december.scene.the-long-watch` · **When** Mon Dec 21, the winter solstice, from dusk ·
**Room** the Great Hall, then the west window · **Cast** Lydia Boggle, Ambrose Trencher, Penny
Blackletter, the Huntsman, the Book (Min-seo in Stay)
**Recalls** the November ending, the watch tag, and scene 3's choice
**This is the ending.** Pinned: needs a floor on Dec 21.

**Opening:** It's the longest night of the year. Put the lights out. Keep watch.

### Node `dusk`

The sun goes down at a quarter to four.

I watch it go from the west window of the Great Hall, through the old glass that's thicker at the
bottom than the top, so the sun looks like it's melting. It goes orange, and then red, and then it
goes, and the cold comes up out of the ground like it's been waiting all day under the courtyard.

Then Boggle puts the lamps out.

All of them. One by one, down the length of the Hall, with a brass snuffer on a long pole. The
banners go dark. The long tables go dark. Somebody's breath goes in sharp in the dark and doesn't
come out for a bit.

The only light left is in the windows. A candle on every west sill. Saucers and stubs, Penny's
work, a long row of small flames, every one of them saying the same thing to whatever's outside.
Somebody in here is awake.

That's the Watch. You sit in the dark, in your coat, with everyone you live with, and you don't go
to bed, and you keep the lights in the windows lit, all night, the longest night, until the sun
comes back.

You've got me on your knee. I'm not sleepy at all.

**Real ask (dated Page, live from dusk):** Tonight's the longest night. Put the lights out for a
while, and keep watch. *One sentence: what kept watch with you?*

### Node `the-hours`

The first hour's the easiest. People whisper. Somebody hands round toffee. Wicker tells a ghost
story so badly that everybody's laughing by the end, and then the laughing stops all at once, the
way it does in the dark, and nobody starts it again.

**Recall** `{who-sits-up}` (the watch tag):
- *If `december-watch-ambrose`:* Ambrose has carried both chairs up from the Kitchens. His and
  yours. He's put them at the west window and he's sitting in his, with a blanket and a flask, not
  saying anything. Yours has the other blanket on it.
- *If `december-watch-light`:* The candle on the Kitchens' west sill, the one that's burned every
  night since the first of December, is up here now, in the middle of the row. Penny carried it up
  in both hands like it was full of something.
- *If `december-watch-house`:* The house is awake. I can hear it. Every beam in the Great Hall is
  creaking very softly, all together, like something very old and very large holding its breath.
- *Fallback:* The candles burn. Nobody talks much.

**Recall** `{the-missing-one}` (November ending, then scene 3's choice):
- *Stayed:* Min-seo's sitting by the Hall's big fireplace, which is cold. She's put the brown bowl
  on the hearth. Every so often she says his name, quietly. *Aiken.* Like you'd check somebody
  was still in the next room.
- *Home:* Ambrose has the button on the windowsill in front of him. *Brass*, he calls it, when he
  thinks nobody can hear. He's put it next to the candle where it can see out.
- *Court:* Ambrose is at the window. Boggle's beside him. She hasn't left him all night, and she
  hasn't said why, and he hasn't asked.
- *Fallback:* You've got me on your knee. You haven't put me down once.

The second hour, the cold comes in. The third, nobody's whispering any more. Penny's counting
under her breath. Somewhere after midnight, she stops counting.

And then I hear it.

### Node `the-hunt`

It's very high up at first. Like geese. Like Gwendolyn's hounds. Then it isn't high up.

It's horses. Hundreds. Going over the roof so close the slates rattle, so close the candle flames
all lean the same way at once, towards the door, as if something had opened it. Nothing's opened
it. There are hounds with them. I can hear the hounds. They don't bark like dogs. They call, long
and thin, like somebody's name being shouted a long way off by somebody who's forgotten what it
means.

It goes on and on. It goes on so long I stop being frightened and start being something else,
something there isn't a word for, the feeling of a great many people going past your window in the
dark who'll never come home.

The candles hold.

Then, one by one, the sounds go past. The hooves go on over the Stacks, over the orchard, away.

All but one.

One set of hooves comes down. Slow. On the frost in the courtyard, I can hear every step. It
comes right up to the west window, the one with Ambrose's candle in the middle of the row.

It stops.

There's a rider on it.

I can only see him from the waist up, through the old glass, by the candle. He's tall and very
thin and his cloak's white with frost, and his face is a face, an ordinary face, a man's, tired in
a way I've only ever read about. His horse is grey. He doesn't get down. He looks like he hasn't
got down in a very long time.

He knocks on the glass. Three times. Polite. Like somebody who's knocked on a great many windows.

"There's a light," he says, through the glass. His voice is muffled and it's very clear. "So
somebody's awake. And somebody's awake, so somebody'll play."

### Node `riddles`

"I don't take anybody," he says. "Not from a lit house. Not where they're known by name. I only
want company. It's a long road." He leans on his saddle. "Riddles. Three each. That's fair. That's
how it's always been done."

So you play.

He asks you the first one. *What has a mouth and never eats, and a bed and never sleeps?* You know
that one. Everybody here knows that one now, since Ambrose's nights at the range. A river. He
nods, like you've passed something.

You ask him one back. Whatever riddle you brought on the sixteenth, if you brought one, or the one
Pippa gave you with no answer. He laughs at Pippa's. He actually laughs. It sounds like ice
cracking on a pond.

He asks the second. *What gets bigger the more you take out of it?* A hole. He nods again.

It goes like that, back and forth, through the glass, while the candles burn down. Boggle doesn't
move. Ambrose doesn't move. Penny's got her pencil out but she isn't writing anything.

Then he asks the last one.

He leans close to the glass. Close enough to fog it.

"What's my name?"

Nobody answers. Nobody can. That's the kind of riddle it is, the oldest kind, the one at the end
of every riddle contest in every saga I've ever held. It's a question only the asker can answer.

But he can't. I can see it in his face. He's asking because he doesn't know any more. He's been
riding so long it's gone.

**Prompt:** It's your turn. What do you do?

- **Choice `riddle` — “Answer with a riddle of your own: What's under this roof?”**
  *Result:* You lean close to the glass, the way he did.

  "What's under this roof?" you ask him.

  He looks up at the Academy. All of it. The towers and the Stacks and the Kitchens chimney and
  the long dark windows with the candles in. He looks at it for a long time.

  "I don't know," he says. "What's under your roof?"

  "Everybody," you say. "By name."

  He laughs again, the ice-cracking laugh, and it goes on longer this time, and when it stops he
  straightens up in the saddle.

  "That's a good one," he says. "That's the best one I've had in a hundred years."

  He turns the grey horse. He rides on, after the others, over the orchard, away.
  *Braid:* On the longest night the Huntsman stopped at the lit window and played riddles, and my
  reader asked him what was under the roof. "Everybody, by name." He laughed and rode on.
  *Tags:* `december:hunt-riddled` · *Outcome:* **Riddled**

- **Choice `name` — “Give him a name for the road.”**
  *Result:* You can't tell him his name. Nobody can. So you give him one.

  You think about it first. You don't just say the first thing. It has to be a name somebody could
  ride a long way with. Then you say it, through the glass, clear.

  He goes very still.

  He says it back. Once, quietly, trying it, the way you try a coat on in a shop. Then again,
  louder, to the horse. The horse flicks an ear.

  "It's not mine," he says. "I don't think it's mine."

  "It is now," says Boggle, from the dark behind you. It's the first thing she's said all night.

  He puts his hand flat on the glass for a moment. Then he turns the horse, and before he rides on
  he looks up, once, at the east tower, where one window's lit that nobody lit, and he bows. Or
  he's looking at the dawn, which is coming. I can't tell. I won't ever be able to tell.

  He rides on with it.
  *Braid:* On the longest night the Huntsman asked the one riddle nobody could answer, his own
  name, and my reader gave him one for the road.
  *Tags:* `december:hunt-named` · *Outcome:* **Named**
  *(Conversion note: the name the Reader gives is their own text if the choice can carry a typed
  line; otherwise it stays unsaid in the prose, "the name you gave him".)*

- **Choice `watch` — “Say nothing. Keep watching.”**
  *Result:* You don't answer. You don't play the last one.

  You just keep watching him. Through the glass. With the candle between you.

  He waits. He waits a long time. He doesn't knock again. He sits on the grey horse in the frost,
  and you sit in your chair, and neither of you looks away.

  It's the strangest thing I've ever been part of. Nobody's playing. Nobody's winning. Two people
  on either side of a window, keeping each other company on the longest night of the year.

  I think that might be what he wanted all along.

  The sky goes grey. Then paler grey. I look down at you for one moment, to see if you're cold.

  When I look back he isn't there.
  *Braid:* On the longest night the Huntsman waited at the lit window, and my reader said nothing
  and kept watching him, all night, until he wasn't there.
  *Tags:* `december:hunt-watched` · *Outcome:* **Watched**

### Node `the-sun` (all endings)

At eight minutes past eight the sun comes up.

It's not much of a sun. It's low and white and it barely gets over the orchard wall. But it comes
up. It always comes up. The longest night's over, and from tonight every night's a little bit
shorter than the last one.

Boggle puts the snuffer down. Penny writes something on her card. Ambrose stands up, and his knees
crack like kindling, and he says, "Porridge," and that's the end of the Watch.

**Cast memories:**
- `lydia-boggle` · `december.watch.kept` · On the longest night Boggle put out every lamp but the
  window lights and the Academy kept watch till dawn. *Aside:* "Every candle held. I counted. I
  always count."
- `ambrose-trencher` · `december.watch.porridge` · After the Long Watch Ambrose made porridge for
  everybody twice. *Aside:* "My knees went off like kindling. Eat your porridge."
- `penny-blackletter` · `december.watch.hunt` · Penny didn't write anything down while the
  Huntsman was at the window. *Aside:* "First thing in my life I didn't file. I'm not sorry."
- Ending memories on the three choices, e.g. `lydia-boggle` · `december.watch.named` (Named):
  "It is now. I said that. I don't know what came over me."
- *Gossip (Riddled):* "{teller} says the Hunt stopped at the Great Hall window on the longest
  night and somebody beat it at riddles."
- *Gossip (Named):* "{teller} says one of the Hunt didn't know his own name, so somebody gave him
  one."
- *Gossip (Watched):* "{teller} says one of the Hunt sat outside the window all night and nobody
  said a word. Then the sun came up."

---

## 9. Frost

**id** `december.scene.frost` · **When** Tue Dec 22, dawn · **Room** the courtyard · **Cast** Penny
Blackletter, Gwendolyn Mythwright, Seraphina Thorne, the Book
**Recalls** the ending

**Opening:** There are hoofprints in the frost. They come right up to the window.

### Node `entry`

The courtyard's white. The kind of frost that grows, that stands up on every blade of grass like
fur on a cat's back.

Penny's out in it first, in her coat over her nightclothes, with a ruler. Gwendolyn's behind her
with a notebook. They're measuring the hoofprints.

There's one set. It comes in under the arch from the Stacks side, very straight, very deep, as if
the horse was heavy as a cart. It comes right up to the west window of the Great Hall.

**Recall** `{the-prints}` (the ending):
- *Riddled:* And then it turns, in a tidy half circle, and goes back the way it came. Gwendolyn
  measures the turn. "He was in no hurry," she says. "Look how round that is."
- *Named:* And then it goes on, out through the orchard, and somewhere by the oldest apple tree
  the hoofprints get lighter. Gwendolyn kneels down by the last one for a long time. "They're
  shallower," she says. "He weighed less going than coming. I'm only saying what the frost says."
- *Watched:* And then it stops. There's no turn. There's no going on. It's just there, a deep
  square of hoofprints under the window, where a horse stood all night without moving, and then
  nothing. Penny writes: *Arrived. Waited. Did not leave by any route I can find.*
- *Fallback:* And then it goes away again, over the frost, towards the orchard.

### Node `thorne`

That's when the Headmistress comes in.

Not out of the Academy. In. From outside. Through the arch from the Stacks side, the same way the
hoofprints came, walking very straight down the middle of the courtyard in a long dark coat with
her hair pinned up like a small crown.

The hem of her coat's white with frost. Not damp. White. Like she's been standing out in it for
hours.

She sees us. She doesn't stop. She nods at Penny's ruler as she passes.

"Good morning," she says. "You'll want to note that the candles held."

Then she goes inside.

Nobody asks where she's been. Penny opens her mouth to, and Gwendolyn puts a hand on her arm, and
Penny shuts it again and writes something on a fresh card instead. She doesn't show me what.

I don't know if the Headmistress was out there keeping the Hunt off us all night, or keeping it
company. I don't know which window in the east tower was hers. I don't know a lot of things this
morning. I know the sun came up.

### Node `twelve`

"It's not over," Gwendolyn says, on the way in. She's got frost on her knees. "In some places it's
just started. The twelve nights. When the Hunt's out. In Germany they say you mustn't hang your
washing out between now and the New Year, or the Hunt gets tangled in it and takes it away." She
looks at the sky, which is pale and clean and empty. "And things talk. At midwinter. That's the
other thing they say."

"Things?" says Penny.

"Animals in the stable, at midnight on Christmas Eve. That's the famous one." Gwendolyn shrugs.
"I've never seen why it'd stop at animals."

Neither have I.

Penny turns her card over and starts a new count. *Twelve nights. Night one.*

**Cast memories:**
- `gwendolyn-mythwright` · `december.frost.prints` · Gwendolyn measured the Huntsman's hoofprints
  in the frost. *Aside:* "The frost doesn't lie. It doesn't explain itself either."
- `penny-blackletter` · `december.frost.thorne` · Penny saw the Headmistress come in from outside
  at dawn with frost on her hem, and didn't ask. *Aside:* "I wrote it on a fresh card. I'm not
  filing it yet."
- *Gossip:* "{teller} says the Headmistress came in from outside at sunrise with frost all up her
  coat. Nobody knows where she was all night."

---

## 10. The Twelve Nights

**id** `december.scene.twelve-nights.<n>` for n = 1 to 12 · **When** one each night, Dec 22 to Jan
2 · **Room** the Reader's own house · **Cast** the Book, and one Neighbour a night
**Needs** (with the app update) the Reader's Neighbours by name, via a placeholder; ships on the
fallback list.

Each leaf is short: a few lines from the Book, then the ask. The Book never invents what the Reader
did or felt; the thing's speech is the Reader's to write. Where the Reader has Neighbours, the leaf
takes one by name (least recently seen first, living ones only, never one that's resting or gone)
and the first line uses its name. Otherwise the fallback thing for that night.

**The ask, every night:** Go to it tonight. Sit with it a minute. Let it say something. *One
sentence: what did it say?*

| Night | Date | Fallback thing | The Book's lines |
|---|---|---|---|
| 1 | Tue Dec 22 | the kettle | Gwendolyn says things talk at midwinter. I'd start with the kettle. It's been trying to say something for years. It only ever gets as far as the whistle. |
| 2 | Wed Dec 23 | the coat on the hook | Your coat's been out in every weather you have. It's seen more of the dark than you have this month. Ask it what's out there. |
| 3 | Thu Dec 24 | the stairs | Tonight's the night the animals are meant to talk. The stairs have been carrying you up and down for years and nobody ever asked them anything. |
| 4 | Fri Dec 25 | the window | The window watched the Hunt go over. It must have. Windows watch everything. Ask it what it saw. |
| 5 | Sat Dec 26 | the spoon drawer | The spoon drawer's full of things that touch your mouth every day and never get a word. Open it. Listen. |
| 6 | Sun Dec 27 | the front step | Everybody who ever came to your house stood on it. Ask the step who was the worst. |
| 7 | Mon Dec 28 | the oldest book you own | I'm asking this one for me. It's older than me, probably. I want to know what it thinks of me. |
| 8 | Tue Dec 29 | the clock | The clock's been counting the long nights the same as Penny. It must have an opinion about them. |
| 9 | Wed Dec 30 | the bed | The bed knows how you sleep. It's never told anybody. Ask it if it'll tell you. |
| 10 | Thu Dec 31 | the mirror | Last night of the year. The mirror's seen every one of your faces this year. Which did it like best? |
| 11 | Fri Jan 1 | the bin | Nobody ever thanks the bin. It took everything you didn't want all year. Ask it what was the best thing you threw away. |
| 12 | Sat Jan 2 | the door you use most | Last of the twelve. The door you use most. It's opened for you more than anybody has. Ask it what it wants for next year. |

*(Night 12's fallback thing is a door, and its line ends on "next year". Check it against the
banned door idioms at conversion: it's a literal door, which is allowed.)*

With Neighbours, the lines become, for example: "Night three. Gerald hasn't been in your Pages
since November. Go and stand under him tonight. Let him say something." The Book's one line about
the Neighbour (`Neighbours.line(for:)`, deterministic, from facts only) may stand in for the first
sentence.

---

## 11. Midnight in the Stable

**id** `december.scene.midnight-stable` · **When** Thu Dec 24, midnight · **Room** the stable ·
**Cast** Gwendolyn Mythwright, Damien Nights, the stable cat
*Working draft.*

**Opening:** At midnight on Christmas Eve the animals are supposed to kneel. Gwendolyn's going to
check.

Show: Gwendolyn in the stable with a lantern and a notebook and the Academy's one cart horse and the
stable cat, because the old belief says the animals kneel, or talk, at midnight on Christmas Eve
(Hardy wrote a poem about wanting to go and see). She doesn't believe it and she's going to sit up
and watch anyway, because a wonder with evidence behind it is a wonder you don't have to be lonely
about. Damien Nights is there too, saying nothing, at the moment a word would help, and then saying
one anyway. At midnight the horse lies down. Horses lie down at night. The cat looks at all of them
and leaves. Gwendolyn writes both things down. Damien says, "It knelt." Gwendolyn says, "It lay
down." They agree to file it under both. Nobody's lonely.

For readers who keep Christmas this is the Christmas Eve leaf; for everyone else it's a stable at
midnight in winter, and that's enough.

**Cast memories:** `gwendolyn-mythwright` · `december.stable.both` · *Aside:* "Lay down. Knelt.
Filed under both, with a witness." `damien-nights` · `december.stable.knelt` · *Aside:* "It knelt.
I saw it. I don't care what the notebook says."

---

## 12. Forfeits

**id** `december.scene.forfeits` · **When** Sat Dec 26 · **Room** the Great Hall · **Cast** Wicker
Eddies, Pippa Pilcrow, Professor Mook, Ambrose Trencher
*Working draft.*

**Opening:** The Great Hall's playing forfeits. You lose, you do what they say.

Show: the long nights after Christmas, the Hall full of people too full to move and too awake to
sleep. Parlour games: blind man's buff, the minister's cat, forfeits. Wicker running the forfeits
with terrible fairness. Professor Mook made to say a word he disapproves of, in its new meaning, in
a sentence, and he does it, with dignity, and the Hall cheers. Pippa sentenced to use only full
stops for an hour and nearly dying of it. Ambrose's forfeit: sit down and let somebody else bring
him a plate. He can't do it. He tries three times.

**Real ask (dated Page):** Pay a forfeit. Let somebody you live with or love choose one small daft
thing for you to do, and do it. *One sentence: what did you have to do?*

**Cast memories:** `wicker-eddies` · `december.forfeits.fair` · *Aside:* "Terribly fair. That's the
only way forfeits work." `ambrose-trencher` · `december.forfeits.plate` · *Aside:* "Sat down. Got
up. Sat down. Somebody else brought the plate. I'll never recover."

---

## 13. Wassail

**id** `december.scene.wassail` · **When** Thu Dec 31, New Year's Eve, after dark · **Room** the
orchard · **Cast** Ambrose Trencher, Lydia Boggle, Min-seo Kim, Wicker Eddies, the Book
**Recalls** the ending (the oldest tree in the Named ending)

**Opening:** The orchard's oldest apple tree is owed a song. Bring a cup.

### Node `entry`

There's an old apple tree at the bottom of the orchard that nobody planted. It's bent nearly
double, like it's looking for something it dropped, and it's got mistletoe up in its branches in
round green balls like it's wearing its own decorations.

Tonight the whole Academy's standing round it in the dark with lanterns and cups.

Ambrose has a great wooden bowl of hot spiced apple, steaming, with slices of toast floating on
top. He's very serious about the toast.

"Wassail," he says. It's an old word. It means *be well*. "In the cider counties they do it on
Twelfth Night. We do it tonight, because it's the last night of the year and the trees should
know where they stand."

Min-seo goes up to the tree first. She asks its permission before she touches it. She always does,
with plants. Then she takes a piece of toast out of the bowl and puts it up in the fork of the
branches.

"For the robins," she says. "That's the tree's share."

Then Ambrose pours a cup of the hot apple onto the roots, slowly, all the way round.

And then everybody makes as much noise as they can.

Pots and pans. Wicker's got two saucepan lids and no shame. Somebody's got a whistle. Boggle bangs
her keys together. The noise goes up into the dark, over the orchard wall, out to wherever the
Hunt is tonight, and the old stories say that's the point: you make a racket to send off whatever's
in the dark, so the tree can sleep safe till spring.

**Recall** `{the-oldest-tree}` (Named ending only):
- *Named:* At the foot of the tree, in the frost that never quite went this week, there's the last
  of the hoofprints. The shallow one. Min-seo's put a ring of stones round it. Nobody asked her to.
- *Fallback:* (nothing)

### Node `the-deal`

When it's quiet again Ambrose stands in front of the tree with the empty bowl.

"Here's how it goes," he says, to you, because you're nearest. "It's a deal. We look after you.
We keep the frost off your roots and the goats off your bark. You give us apples. Everybody says
their bit of it out loud, so the tree's heard it."

He says his bit. It's about pies. It's quite long.

Then everybody looks at you.

**Prompt:** What do you promise the tree?

*(No branching. The Reader's promise is theirs. The leaf goes straight to the real ask.)*

**Real ask (dated Page):** Go to a tree tonight, or tomorrow, a real one. Your own if you've got
one. Toast it with whatever's in your cup. Make it a promise out loud, and ask for something back.
That's a wassail. It's a deal. *One sentence: the deal.*

And I'll come back for it. That's what a deal's for. In a week, and in a month, and when the apples
come, I'll ask you how it's going.

*(Conversion note: this page should carry a standing deal so the Book calls it in at a week, a
month, three months and a year, as Phase 0's spells do. Needs the Phase 3 engine work. Without it,
the page is kept and the last paragraph should be cut, so the Book doesn't promise what it can't
do.)*

**Cast memories:**
- `ambrose-trencher` · `december.wassail.pies` · On the last night of the year Ambrose wassailed
  the oldest apple tree and promised it pies. *Aside:* "It was a reasonable promise. The tree
  knows what it's getting."
- `min-seo-kim` · `december.wassail.robins` · Min-seo put the toast up in the tree's branches for
  the robins. *Aside:* "The tree's share. You always leave the tree's share."
- *Gossip:* "{teller} says the whole Academy banged saucepans at an apple tree on New Year's Eve.
  Wicker brought lids."

---

## R. The Last of the Twelve (residue)

**id** `december.scene.last-of-the-twelve` · **When** Sat Jan 2 · **Room** the Kitchens · **Cast**
Ambrose Trencher, Penny Blackletter, Lydia Boggle
*Working draft.*

Show: Penny takes her card down off the Kitchen door. *Nights kept: 33. Twelve nights: 12.
Candles: all of them held.* She files it under December. Boggle closes
the green Roll and puts it away till next winter. The last line of it, at the bottom, is whatever
the missing one became (the pots / Brass / the o put back in pencil / the Book in the Reader's
hand). Ambrose takes the second chair (if it's out) back down to its corner, then brings it back
out again and leaves it by the range. "It's still dark at four," he says. "Somebody'll have to sit
up with that."

Hand-off to January and February: the hunt outcome tag, the missing-one tag, and one line the Book
says to the Reader, that their own Roll's in its back cover and it'll read it out next winter.

---

## What these need from the conversion

- **Recalls** on Ambrose's `the-guest.bowl.*` memories (scenes 3, 8, 9, 13), the `december-watch-*`
  tags (scenes 3, 5, 8), November's name tags (scene 1), and this month's own ending tags (scenes
  9, 13, R). Every one with a fallback.
- **Per-variant choice results** in scene 3: one choice label, four result texts. If the scene
  format can't carry that, split scene 3 into four scenes gated on the recall, with the fallback as
  the default.
- **The Neighbours placeholder** for scenes 4 and 10 (app update), with the fallback lists written
  here.
- **The wassail deal** (scene 13) on the Phase 3 engine, or the promise line cut.
- **Real-world asks** as dated Pages beside scenes 2, 4, 5, 6, 8, 10, 12, 13: one sentence each.
- **Pinned beats need floors:** scenes 1 (Dec 3), 5 (Dec 13), 8 (Dec 21), 9 (Dec 22), 11 (Dec 24),
  13 (Dec 31), and each of the twelve nights.
- **Penny's card** as a Bleed desk piece and margin token, updated by date.
- **Outcomes** recorded for January and February: `december:hunt-riddled` / `-named` / `-watched`,
  and `december:missing-called` / `-written` / `-sit-up`.
- **Voice pass** before conversion: the drafts above have been written to the rules (no semicolons
  or dashes in reader prose, no "the Book" in narration, no hands), but they haven't been through
  the Prose Audit or `BookCharacterLint`.
