"""November's page pack (margins.reenchantedpack.json): the Cast's own business while the
Guest is in the house, kitchen spells for the desk, and the month's pencilings. The art
(seasonal drawings and directed marks) joins this file once it's generated."""

from content_common import EVENT_ID
from content_art import marginalia_cabinet

MARGINS_ID = "the-guest-margins-pagepack"


def stage(id, phase, line, trace, tags, scene, *, surface="witnessedScene", deniability=None, door=None, cast=()):
    s = {"id": id, "line": line, "trace": trace, "tags": list(tags), "scene": scene, "surface": surface,
         "phaseID": phase, "castIDs": list(cast)}
    if deniability:
        s["deniability"] = deniability
    if door:
        s["door"] = door
    return s


def door(id, title, ask, proof, tags):
    return {"id": id, "title": title, "ask": ask, "proofPrompt": proof, "tags": ["undertaking-door"] + list(tags)}


def ladder(id, actor, title, pursuit, why, stages):
    cast = [actor] + sorted({c for s in stages for c in s["castIDs"] if c != actor})
    return {"id": id, "actorID": actor, "title": title, "pursuit": pursuit, "why": why, "stages": stages,
            "castIDs": cast, "eventID": EVENT_ID}


# MARK: Wicker learns to cook

WICKER = ladder(
    "pack-the-guest-wicker-cooks", "wicker-eddies", "Wicker Can't Cook",
    "Make one thing properly, for somebody, before November's out.",
    "He's never made anything for anybody that wasn't a dare.",
    [
        stage("toast", "all-souls",
              "Wicker burns toast in the Kitchens, twice, and asks Ambrose to watch him do it a third time.",
              "Two black slices on the windowsill, set out side by side like evidence.",
              ["kitchen", "mistake", "learning"],
              """The first slice is black. So is the second.

Wicker sets them both on the windowsill, side by side, and stares at them as if they've lied to him.

“Again,” he says.

Ambrose doesn't look up from the onions. “You're standing too far away from it.”

“It's a fire. You stand far away from fire.”

“You stand far away from a fire you don't respect,” says Ambrose. “Closer.”

Wicker takes one step closer to the grill. Then, after a moment, another. He puts in a third slice and doesn't take his eyes off it, not once, the whole time, as if it might try something.""",
              deniability="I was establishing a baseline. The baseline is black.",
              cast=["ambrose-trencher"]),
        stage("the-list", "guest-right",
              "Ambrose pins up a list of everything Wicker has burnt, with a note beside each one on what went wrong.",
              "A list on the Kitchens' corkboard, its last line in a different, smaller hand.",
              ["kitchen", "record", "mistake"],
              """THINGS EDDIES HAS BURNT — A. T.

Toast (2). Stood too far away.
Toast (1). Stood too close. Looked away.
Rice. Didn't look at all.
Porridge. Bottom of the pan. Didn't stir.
An egg. Unclear how.
The tea towel. Do not discuss.

At the bottom, in a different, smaller hand, newer:

*Toast (1). Perfect. Witnessed. W. E.*

And under that, in Ambrose's hand again: *Fluke.*""",
              surface="note", deniability="The tea towel was already like that.",
              cast=["ambrose-trencher"]),
        stage("eggs", "guest-right",
              "Penny finds Wicker in the Kitchens after midnight with a box of eggs and a pan, practising something he won't name.",
              "A great many eggshells in the bin, and the Cookery open at OMELETTE with a buttery thumbprint on the page.",
              ["kitchen", "night", "secret"],
              """It's past midnight and the Kitchens smell of butter and panic.

Penny stops in the doorway in her dressing gown, holding a candle. There are eggshells all along the long table. There's a pan on the range. There's Wicker, in the middle of it, with a fork in one hand and the Cookery propped open against the bread crock.

“Don't,” he says.

“I didn't say anything.”

“You were going to write it down.”

Penny looks at the eggshells. She counts them without meaning to. Eleven.

“It's for the record,” she says.

“It's for nobody.” He tips the pan. Something folds over in it, more or less. He looks at it the way he looks at a lock he's nearly got. “It's for nobody yet.”

Penny goes back to bed. She doesn't write it down. She remembers the number, though.""",
              deniability="I was hungry. Eleven times.",
              cast=["penny-blackletter"]),
        stage("letter", "the-offer",
              "Wicker writes to the Reader that cooking is lock-picking with a smell, and that everybody has one thing they can't cook.",
              "A letter with a grease spot in one corner, shaped very like a thumb.",
              ["kitchen", "letter", "learning"],
              """Reader—

I've worked something out. Cooking's lock-picking. You can't force it. You listen, and you wait, and you feel for the bit where it gives. The difference is that a lock doesn't smell of anything when you get it wrong, and an omelette very much does.

I've made nine omelettes now. Three were good. I gave one of them away, and I'm not going to talk about that.

Trencher says everybody's got one thing they can't cook, however good they are. His is pastry. He said it with his whole face, so I believe him.

I find that very comforting.

—W.

*P.S. The grease spot's not mine. It was on the paper when I got it.*""",
              surface="letter", deniability="Lock-picking's a figure of speech. Mostly.",
              door=door("wicker-cant-cook", "The Thing They Can't Cook",
                        "Somebody near you has one thing they can't cook, however good they are at everything else. "
                        "Wicker finds this extremely comforting and would like to know what it is.",
                        "Who, and what can't they make?", ["kitchen", "people", "anywhere"])),
        stage("porridge", "the-bowl",
              "Wicker makes the porridge one morning before Ambrose is up, and Ambrose eats a bowl of it without a word.",
              "The big pan, scrubbed, hung back one hook along from where it lives.",
              ["kitchen", "morning", "gift"],
              """Ambrose comes down at six and the range is already lit.

The big pan's on it. The porridge in it is thick and smooth, with a skin on top exactly the right thickness. There are bowls warming on the rack. Wicker's sitting on the end of the long table with his arms folded, very carefully not looking at anything.

Ambrose takes a bowl. He fills it. He stands at the range and eats the whole thing with his back to the room, the way he eats everything.

Then he washes the bowl and puts it away, and ties on his apron, and says, “Salt.”

“What about it?”

“There was enough.”

Wicker doesn't say anything for a long time. Then he gets up and washes the pan, and hangs it back on the wrong hook, and Ambrose, who notices everything, doesn't move it.""",
              deniability="He said there was enough salt. From Trencher, that's a parade.",
              cast=["ambrose-trencher"]),
    ])


# MARK: Dr. Vellum wants to examine the Guest

VELLUM = ladder(
    "pack-the-guest-vellum-examines", "dr-vellum", "A Request to Examine the Guest",
    "Examine the Guest properly, with instruments, before anybody else decides what it is.",
    "Dr. Vellum doesn't mind not knowing a thing. What Vellum minds is a whole building agreeing not to find out.",
    [
        stage("the-form", "all-souls",
              "Dr. Vellum files a formal request to examine the Guest, and Ambrose sends it back with a tea ring on it.",
              "A request form on the Still Room desk, a ring of tea right over the signature line.",
              ["study", "record", "kitchen"],
              """REQUEST FOR EXAMINATION — STILL ROOM

Subject: the Guest (Kitchens, by the fire).
Purpose: weight; temperature; pulse, if present; response to salt, iron and lamplight.
Instruments: scale, thermometer, lamp, one silver spoon.
Duration: twenty minutes. Fifteen if it objects.
Requested by: Dr. Vellum.

Approved by: ____________

Across the approval line there's a ring of tea, perfectly round, still a little damp. Nothing's written inside it. Nothing needs to be.""",
              surface="note", deniability="The form came back with tea on it. I'm counting that as a maybe.",
              cast=["ambrose-trencher"]),
        stage("weighing", "guest-right",
              "Dr. Vellum weighs a bowl of soup before and after the Guest leans over it, and the scale says nothing changed.",
              "Two numbers in a notebook, identical, the second underlined so hard the pencil went through the page.",
              ["study", "strange", "kitchen"],
              """Dr. Vellum sets the bowl of soup on the brass scale. Four hundred and twelve grams. It goes in the notebook.

The Guest comes down the long table the way it always does, leaning over every plate. It leans over this one. It breathes in. It moves on.

Dr. Vellum puts the bowl back on the scale.

Four hundred and twelve grams.

Vellum tastes the soup. Then tastes it again. Then sits down very slowly on the bench, and writes the second number under the first, and underlines it, and keeps on underlining it until the pencil goes through the page."""),
        stage("no-instruments", "the-offer",
              "Ambrose lets Dr. Vellum sit with the Guest for an hour, on one condition: no instruments.",
              "A leather case of instruments left on the Kitchens' dresser overnight, still buckled.",
              ["study", "kitchen", "night"],
              """“No instruments,” says Ambrose.

“Then it isn't an examination.”

“No,” Ambrose agrees, and goes on cutting bread.

Dr. Vellum stands there for some time holding the leather case. Then sets it down on the dresser, square to the edge, and goes over to the fire, and sits on the floor beside the Guest's stool, and says nothing at all.

An hour later Vellum gets up, picks up the case without opening it, and goes back to the Still Room.

The notebook stays shut that night. Nothing new goes in it.""",
              deniability="I observed. Observation doesn't need a pencil. It merely prefers one.",
              cast=["ambrose-trencher"]),
        stage("who-made-it", "the-offer",
              "Dr. Vellum writes to the Reader about a new column in the notebook, headed WHO MADE IT.",
              "A Still Room notebook with a new column ruled down the right-hand side of every page.",
              ["study", "letter", "kitchen"],
              """Reader—

I'm writing to correct something I taught this month. I said a meal is fuel. It is. I stand by the numbers.

But I weighed a bowl of soup before and after something leaned over it, and the numbers were the same, and the soup wasn't. I've no instrument for the difference. I've looked. The Still Room has a great many instruments, and none of them is for that.

So I've started a new column. I don't know what to call it yet. For now the top of it just says WHO MADE IT.

It's the most useful column I've got.

—Dr. Vellum

*P.S. Ambrose has read this letter. I'm to tell you he said nothing about it.*""",
              surface="letter", deniability="I've ruled a new column. I'll keep putting things in it till I know what it's for.",
              door=door("vellum-who-made-it", "Who Made It",
                        "Something you eat this week was made by somebody, even if it came out of a packet. "
                        "Dr. Vellum has a new column and would like one more entry in it.",
                        "What did you eat, and who made it?", ["kitchen", "people", "immediate"])),
        stage("left-blank", "the-bowl",
              "Dr. Vellum records the bowl Ambrose set on the hearth, and leaves the box for its weight empty.",
              "A notebook page dated the thirtieth, with one box on it left blank.",
              ["study", "record", "kitchen"],
              """STILL ROOM NOTEBOOK — 30 NOVEMBER

Bowl: brown, chipped, on the Kitchens' hearth.
Contents: oats, milk, salt, honey, butter, cream round the edge.
Weight:
Made by: A. Trencher.
For: not stated.

Note: not weighed. It didn't seem the right instrument.""",
              surface="note", deniability="I left a box blank. I've done it before. Once.",
              cast=["ambrose-trencher"]),
    ])


# MARK: Penny keeps the Cookery's count

PENNY = ladder(
    "pack-the-guest-penny-counts", "penny-blackletter", "The Cookery Count",
    "Keep an exact count of every letter The Middlemost Cookery loses, and every one it gets back.",
    "If a book's going to lose its letters, somebody ought to be counting them, and it's always Penny.",
    [
        stage("two-columns", "all-souls",
              "Penny borrows The Middlemost Cookery overnight and starts a ledger of its missing letters.",
              "A ledger ruled in red, one column headed GONE and the other headed BACK, the second one empty.",
              ["record", "words", "kitchen"],
              """Penny borrows the Cookery the way you'd borrow somebody's cat: with both arms, promising to bring it back.

In the Record room she lights two lamps and rules a fresh page. Two columns. She heads the first one GONE. She heads the second one BACK.

“Back?” says Ambrose, from the doorway. He's followed her up. He won't admit it.

“In case.”

“Letters don't come back.”

Penny turns the first page of the Cookery under the lamp, very slowly, and writes *treacle, T* in the first column.

“Then the other column will stay empty,” she says, “and that'll be a record too.”""",
              deniability="The BACK column's empty. It's allowed to be. For now.",
              cast=["ambrose-trencher"]),
        stage("the-count", "guest-right",
              "Penny's count of the Cookery's missing letters reaches two hundred and fourteen, and she notices which pages are holding.",
              "A sheet of figures pinned in the Record room, one page number circled.",
              ["record", "words", "pattern"],
              """THE MIDDLEMOST COOKERY — LETTERS GONE (P. B.)

Day 4: 1. (T, treacle.)
Day 6: 3.
Day 8: 11.
Day 10: 40.
Day 12: 214.

Losses aren't random. Recipes nobody's made in years are going first. Pages with stains on them are holding. Page 61 (shepherd's pie, half a greasy thumbprint) hasn't lost a single letter.

Query: does it matter whose thumb?""",
              surface="note", deniability="The counting's fine. It's the numbers I object to."),
        stage("first-back", "the-offer",
              "The first letter comes back to the Cookery, and Penny writes it in the second column with a hand that isn't quite steady.",
              "The BACK column with one entry in it, the ink blotted where the pen stopped.",
              ["record", "words", "kitchen", "return"],
              """Penny's checking page nineteen for the third time that morning when she stops.

*Soda bread.* Yesterday it said *oda bread*. Today the S is back. It's a little darker than the letters round it, like a button that's just been sewn on.

Somebody in the Kitchens made soda bread last night. She knows who. She was there. It was terrible.

She picks up the pen and writes *soda, S* in the BACK column.

Then she sits with the nib still on the paper, so the ink spreads into a little blot, and doesn't lift it for a long time.""",
              deniability="A letter was restored. I wrote it down. Nobody needs to look at me like that.",
              cast=["ambrose-trencher"]),
        stage("official-figures", "the-offer",
              "Penny writes to the Reader with the official figures: two hundred and thirty-one letters gone, seventeen back.",
              "A letter with two numbers in it, the smaller one written larger.",
              ["record", "letter", "kitchen"],
              """Reader—

Official figures, since nobody else is keeping them.

Gone: two hundred and thirty-one. Back: seventeen.

Seventeen isn't many. I know. But every one of them came back because somebody made the thing on the page, in an actual pan, and ate it. I've checked each one against the Kitchens' fire log. It's never once been wrong.

I'm told your kitchen isn't in the Academy. I'm not sure that matters. I've stopped being sure what matters, this month.

—P. Blackletter

*P.S. If you make something that's written down somewhere, I'd like to know which page.*""",
              surface="letter",
              deniability="Seventeen is a number. I don't have feelings about numbers. I have feelings about seventeen.",
              door=door("penny-which-page", "Which Page",
                        "Somewhere in your house there's a recipe written down: a card, a cookbook, the back of a packet. "
                        "Penny would like to know what's on it, and when it was last made.",
                        "What's the recipe, and when was it last made?", ["kitchen", "record", "anywhere"])),
        stage("ledger-closed", "the-bowl",
              "Penny closes her ledger the day the Cookery's back page comes whole, and leaves its columns open.",
              "The ledger on the Record room shelf, a ribbon marking two columns with no line drawn under them.",
              ["record", "words", "ending"],
              """THE MIDDLEMOST COOKERY — LEDGER, LAST ENTRY

29 November. The back page. A bowl.
Letters gone: none. Letters back: all of them.

It's the first page in the book with nothing missing. It's also the only page I've never once seen anybody cook.

For the file: Ambrose has read this page every morning for a week. He doesn't need to. He reads it anyway.

Ledger closed. Columns left open.""",
              surface="note", deniability="A ledger can be closed with its columns open. I've checked the rules. I wrote the rules."),
    ])

UNDERTAKINGS = [WICKER, VELLUM, PENNY]


# MARK: Kitchen spells (repeatable Pages while the Guest is in the house)

def spell(id, title, detail, reason, body, trigger, symbol):
    trig = {"activeWorldEventIDs": [EVENT_ID]}
    trig.update(trigger)
    return {"id": f"the-guest-spell-{id}", "title": title, "headline": title, "detail": detail, "reason": reason,
            "bodyTemplate": body, "score": 57, "cadenceHours": 24, "renderStyleRaw": "loreLetter",
            "symbolName": symbol, "tags": [EVENT_ID, "kitchen", "spell"], "trigger": trig}


SPELLS = [
    spell("cold-evening", "A Spell for a Cold Evening", "The cold's trying the doors.",
          "Cold evenings want something warm, made slowly.",
          """It's {timeOfDay} and the cold's trying the doors. Here's a spell the Academy Kitchens know.

Put a pan of milk on low, or oat milk, or whatever you drink warm. Low. The cold's watching to see if you'll hurry. Stir it slowly, the way the hands of a clock go, never the other way. When the first tiny bubble shows at the edge, stop. Put in one thing you love: honey, a pinch of cinnamon, a square of chocolate. Don't tell the pan what it is.

Drink it somewhere you can see a window.

The rule: every drop. Leave any and the cold gets the last word.

Write in the margin what you put in.""",
          {"timeBands": ["dusk", "night"], "weatherTags": ["cold", "frost"]}, "cup.and.saucer"),
    spell("dark-early", "A Spell for When the Dark Comes Early", "The dark's coming in sooner every day.",
          "In November the dark arrives before supper does.",
          """The dark comes earlier every day this month, like a guest who's found out where the good chair is.

So get there first. Before it's fully dark, put a light on in the kitchen, and then one more than you need. Then put the kettle on, or a pan, or just a plate out on the table.

The dark can come in. It always does. But it has to come into a lit kitchen with somebody in it, and then it behaves.

The rule: no going back to the dark till you've eaten something.

Write in the margin what you ate with the lights on.""",
          {"timeBands": ["dusk"]}, "lamp.table"),
    spell("bread-and-salt", "Bread and Salt", "The oldest law in the Kitchens.",
          "Feed the one at the door before you ask who they are.",
          """The oldest law in the Kitchens is the first one on Professor Boggle's list: feed the one at the door before you ask who they are.

Here's the spell that goes with it. The next time somebody comes into your house, or your room, or sits down next to you, give them something to eat before you ask them anything. It can be tiny. A biscuit. A grape. A crust. Bread and salt is the old way, but anything counts.

The rule: no questions till they've eaten. Not even “how are you”. Not one.

Write in the margin who came, and what you gave them.""",
          {"timeBands": ["day"], "rarity": 0.5}, "fork.knife"),
    spell("bowl-for-the-moon", "A Bowl Set Down", "The full moon's when the old bowls went out.",
          "On full-moon nights the old houses set a bowl down for whoever kept them.",
          """It's a {moon} tonight. That's when the old houses set a bowl down, at night, for whoever keeps them.

You can too. Put one small thing on a saucer or in a cup: a biscuit, a slice of apple, a heel of bread, a spoonful of honey. Leave it by a window where the moon can see it.

The rule: don't watch it, and don't say who it's for. In the morning, eat it yourself or give it to the birds. Never throw it away.

Write in the margin what you set down.""",
          {"timeBands": ["dusk", "night"], "moonPhases": ["Full Moon"]}, "moon.stars"),
]


# MARK: Pencilings

def pencil(id, text, tags, weight=1.0):
    return {"id": f"the-guest.pencil.{id}", "text": text, "tags": [EVENT_ID] + list(tags), "packID": MARGINS_ID,
            "weight": weight, "placementTrigger": {"activeWorldEventIDs": [EVENT_ID], "issueYear": 2026}}


SNIPPETS = [
    pencil("door-first", "Feed the one at the door first.", ["kitchen", "threshold"]),
    pencil("smells-like-home", "Smells like somebody's home.", ["kitchen", "home"]),
    pencil("enough", "Enough is a real measurement.", ["recipe", "kitchen"]),
    pencil("looks-right", "Till it looks right\nis a real time.", ["recipe", "kitchen"]),
    pencil("onions", "Don't hurry the onions.", ["kitchen", "patience"]),
    pencil("grateful", "Never the other thing.\nSay you're grateful.", ["thanks", "fae"]),
    pencil("scrubbed", "Somebody scrubbed these.\nDon't ask who.", ["kitchen", "night"]),
    pencil("paper-remembers", "Paper remembers every kitchen.", ["book", "kitchen", "memory"]),
    pencil("bowl", "Set the bowl down.\nSay nothing.", ["night", "kitchen"]),
    pencil("one-more-plate", "One more plate,\nfor whoever's missing.", ["table", "absence"]),
    pencil("burnt-sugar", "Burnt sugar.\nStill counts.", ["kitchen", "mistake"]),
    pencil("west-step", "Frost on the west step again.", ["cold", "night"]),
    pencil("nearly-right", "Nearly right\nis the whole point.", ["recipe", "memory"]),
]


def margins_pack():
    return {
        "id": MARGINS_ID,
        "displayName": "The Guest Margins",
        "version": 2,
        "author": "ReEnchanted",
        "availability": "userImported",
        "archetypes": SPELLS,
        "marginaliaSnippets": SNIPPETS,
        "marginaliaPack": marginalia_cabinet(),
        "undertakings": UNDERTAKINGS,
    }
