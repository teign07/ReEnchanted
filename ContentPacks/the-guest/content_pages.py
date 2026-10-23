"""Dated Pages the world hands out: classes, letters and a notice."""

from content_common import PHASE_ROLE, atom


def beat(id, phase, opens, expires, title, body, report, page_type, room=None, cast=(), tag="class"):
    b = {
        "id": id, "phaseID": phase, "role": PHASE_ROLE[phase], "opensOnDay": opens, "expiresAfterDay": expires,
        "title": title, "body": body, "report": report, "isMilestone": False, "pageType": page_type,
        "reportsWhenMissed": False,
    }
    if room:
        b["roomID"] = room
    if cast:
        b["castIDs"] = list(cast)
    b["_tag"] = tag
    return b


BOGGLE = beat(
    "the-guest.class.a-potato", "all-souls", 5, 8, "A Potato",
    """Professor Boggle puts a potato on the front desk of the Glint Hall and sits down and looks at it.

That's how the lesson starts. Nobody says anything for nearly a minute. It's a very ordinary potato. It's got a bit of mud on it still, and two eyes on one side, and a dent where somebody dropped it.

“Ambrose told me something thirty years ago,” she says, at last. “He said a potato's owed the same attention as saffron. I thought he was being funny. He wasn't. He's never been funny in his life.”

She hands out potatoes. One each. Then she hands out peelers, and a sheet of paper, and a pencil.

“Write down five true things about your potato before you peel it,” she says. “Then five more after. Nothing clever. Nothing about what it means. What it is.”

The Glint Hall goes quiet in the way it only goes quiet when everybody's looking at something properly. Somebody finds out their potato smells like a cellar. Somebody finds a tiny green sprout curled up in one of the eyes like a fist. Somebody peels theirs and says, out loud, very surprised, “It's *wet* inside,” and nobody laughs, because it's true, and they'd never noticed.

At the end Professor Boggle collects the potatoes in a basket. She's taking them to the Kitchens.

“Nothing's wasted,” she says. “That's the other half of the lesson. The magic in a kitchen isn't the glamorous sort. It's paying attention to something cheap until it gives up being ordinary, and then feeding somebody with it.”

You've got mud on your thumb from the potato. I can smell it through my cover. It smells like the start of soup.""",
    "Professor Boggle taught the Glint Hall to write five true things about a potato before and after peeling it.",
    "academyClass", "location-glint-hall", ["lydia-boggle"])

VELLUM = beat(
    "the-guest.class.a-meal-is-fuel", "guest-right", 8, 11, "A Meal Is Fuel",
    """Dr. Vellum weighs a bowl of porridge on a brass scale and writes the number on the board.

“Four hundred and ten grams,” Vellum says. “Oats, milk, salt. This is fuel. It goes in. You go on. That's the whole arrangement, and it's a good one, and I'm going to show you how to notice it working.”

The Still Room's warm and quiet. Everybody gets a bowl and a card. On one side of the card it says BEFORE and on the other it says AFTER. Before you eat, you write down how your hands feel and how loud the room is and whether you can think in straight lines. After you eat, you write it all down again.

It's a good lesson. I like it more than I meant to. Your hands are cold before. They're warmer after. You write that down, and it turns out to be true, and that's a strange thing to find out about porridge.

Halfway through, the door opens and Ambrose comes in with a tray of tea. Nobody asked him to. He puts a cup down by every bowl, and one by Dr. Vellum's elbow, and goes away again.

Dr. Vellum looks at the tea for a long moment.

“That,” Vellum says to the class, “is the other theory. Ambrose thinks a meal is somebody saying a thing they can't say out loud. I think it's fuel.” A pause. “We've been arguing about it for nine years.”

“Who's right?” says somebody at the back.

Dr. Vellum drinks the tea.

“Write down how you feel after,” Vellum says. “Then you tell me.”""",
    "Dr. Vellum taught the Still Room to write before-and-after notes on a bowl of porridge, and admitted the other theory.",
    "academyClass", "location-still-room", ["dr-vellum", "ambrose-trencher"])

ONIONS = beat(
    "the-guest.class.dont-hurry-the-onions", "guest-right", 14, 17, "Don't Hurry the Onions",
    """Ambrose doesn't teach classes. He's said so, many times. He feeds people, and that's a different job.

Today he's teaching a class.

There are twelve students at the long table in the Kitchens, each with a chopping board, a knife and one onion. Ambrose stands at the end in his apron with his arms folded.

“Chop it,” he says. “Small. Doesn't have to be pretty.”

They chop. Eyes stream. Somebody says a word Penny would write down. The Kitchens fill up with that sharp, wet, green smell that makes you want to blink.

Then he puts a big flat pan on the range, and a lump of butter in it, and waits.

“Listen,” he says.

The butter goes from quiet to a small busy hiss, like rain on a tent. When it's foaming, he tips all twelve onions in at once, and the whole pan *roars*, and then settles into a low wet crackle.

“That's the sound,” says Ambrose. “Remember it. Now don't touch it.”

“For how long?”

“Longer than you want to.”

It takes twenty minutes. Nobody's allowed to turn the heat up. The onions go from white to clear to gold to the brown of a good violin, and the smell changes every five minutes, sharp to sweet to something so warm you could sleep in it.

“That's all I know,” Ambrose says, at the end. “Every good thing starts like this. The trick isn't the onions. The trick's not hurrying. Everybody hurries.”

He gives everyone a spoonful. It tastes of something. I'm almost sure it does.

I write down the sound. I've never kept a sound before.""",
    "Ambrose taught twelve students to soften onions in butter without hurrying, and to listen to the pan.",
    "academyClass", "location-kitchens", ["ambrose-trencher"])

TRENCHER_LETTER = beat(
    "the-guest.letter.trencher", "guest-right", 7, 10, "A Note from the Kitchens",
    """Reader—

I don't write letters. Penny says I have to write one, because the Book keeps asking her what I'm like, and she says she's tired of explaining.

So.

It's a strange month down here. You'll have heard. There's a guest by my fire and the soup's gone thin and my old cookbook's losing its letters, and I don't know what any of that means, and I'm not going to pretend I do.

What I do know is this. Everybody has to eat. That doesn't stop because a month's gone strange.

So this week, feed somebody. That's all. It doesn't have to be anything. Toast counts. A cup of tea put down by somebody's elbow counts. Make it, put it in front of them, and walk off before they can make a fuss.

And don't write back to say thanks. I won't read that part.

—A. Trencher

*P.S. If you've got a thing you make that isn't written down anywhere, write it down. I mean it. They don't keep otherwise.*""",
    "Ambrose wrote to the Reader: feed somebody this week, and write down the thing you make that isn't written anywhere.",
    "letter", "location-kitchens", ["ambrose-trencher"], tag="letter")

SERENITY_LETTER = beat(
    "the-guest.letter.serenity", "guest-right", 11, 14, "Paper",
    """Hello—

I'm writing this on the end of the long table at two in the morning. That's where I am at two in the morning now. Ambrose leaves soup on the warm corner of the range. I eat it. It tastes like paper.

Everybody knows that now. I told the whole Great Hall at Martinmas. I didn't mean to. It came out of me sideways, like a sneeze.

I want to tell you something I haven't told anyone, because you were there in October, carrying the Book, and you've seen worse than me eating soup at two in the morning.

The worst bit isn't the food. It's the rain. I used to stand on the roof and stick my tongue out at it. It tasted of tin and sky. That's gone too. I keep going up there anyway. I stand in it with my mouth open like an idiot and wait.

Nothing yet.

The Guest watches me eat. It leans over everybody's plate before they do. When it gets to mine, it stops, and looks at me, and moves on. As if there's nothing there.

I think there isn't. That's the funny part.

Don't worry about me. I'm only telling you because it's two in the morning and the soup's gone cold.

—S.

*P.S. Go and taste something for me. Something sharp. Tell the Book what it was.*""",
    "Serenity wrote at two in the morning: since October everything tastes of paper, even the rain.",
    "letter", "location-kitchens", ["serenity-brown"], tag="letter")

MOMORT_LETTER = beat(
    "the-guest.letter.momort", "guest-right", 8, 12, "Never the Other Thing",
    """Reader—

A short note, because you'll hear it said wrong at breakfast.

The rule is: you don't thank it. Not ever. Not for the pots, not for the trays, not if it passes you the salt. Say you're grateful, if something has to be said. Say nothing, if you can manage that. Never the other thing.

It isn't rudeness. Thanks are a kind of wage, and a paid thing's free to go, and some things, once they go, go a very long way and come back different. There's a door at the west end of the Kitchens with a sack of onions against it. I've never asked who put them there. I've a fair idea why.

Now the part nobody else will tell you. I like this month.

There's a stranger at the hearth, and a law nobody remembers making, and a cookbook going quiet one letter at a time. Something's at stake down there. Most months the Academy eats its supper and nothing's at stake at all, and it's very pleasant, and in a year nobody remembers a single mouthful.

Remember this one. Mind your manners and know where the doors are. Then go and sit nearer the fire than you strictly need to.

—K. Momort

*P.S. If it ever offers you anything, ask what it costs before you ask what it is.*""",
    "Professor Momort wrote to the Reader: never thank the Guest, say you're grateful, and if it offers anything, ask the cost first.",
    "letter", "location-momentum-yard", ["professor-kyle-momort"], tag="letter")

KITCHEN_LAW = beat(
    "the-guest.notice.kitchen-law", "guest-right", 7, 14, "Kitchen Law",
    """Professor Boggle found this in a drawer at the back of the Pantry, under a stack of old tea towels and a mousetrap with nothing in it. The ink's gone the brown of strong tea. The handwriting's older than anybody in the building. She's pinned it inside the Pantry door, and Penny's copied it out for me, word for word.

*THE RULES OF THIS KITCHEN*

*Feed the one at the door before you ask who they are.*

*Three nights at the hearth make a guest. A guest is not to be harmed nor turned out, until they go of their own choosing.*

*Never thank the ones who keep this house. Thanks are a wage, and a paid thing has to go.*

*Set the bowl down at night. Say nothing about who it is for.*

*Scrub your own pots. If they are scrubbed in the morning and you did not do it, say nothing, and leave the bowl.*

At the bottom somebody's added a line in pencil, much later, in a different hand:

*We stopped setting the bowl. I don't know who decided.*

Penny's put a small question mark beside that line. I've put my corner on it, very lightly. I don't like it.""",
    "Professor Boggle found the Kitchens' old rules in the Pantry: feed the guest first, never thank the ones who keep the house, set the bowl down at night.",
    "bookNotices", "location-pantry", ["lydia-boggle", "penny-blackletter"], tag="notice")

_ALL = [BOGGLE, VELLUM, ONIONS, TRENCHER_LETTER, MOMORT_LETTER, SERENITY_LETTER, KITCHEN_LAW]

BEAT_ATOMS = [
    atom(b["id"], b["title"], "worldEventBeat", "page", b["phaseID"], b["opensOnDay"], b["expiresAfterDay"],
         voice="publicReport" if b["_tag"] == "notice" else "immediate",
         priority="ambient" if b["_tag"] == "notice" else "featured",
         tags=(b["_tag"],))
    for b in _ALL
]

BEATS = [{k: v for k, v in b.items() if k != "_tag"} for b in _ALL]
