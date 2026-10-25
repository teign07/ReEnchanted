"""December's residue scene: the first morning after November, read through whatever the
Cast remember of the ending and of Serenity's offer, and one last choice the Long Watch inherits."""

from content_common import EVENT_ID, PACK_ID, atom, memory, needs
from content_scenes import choice, node

D = "the-guest.scene.the-first-of-december"
BOWL_ID = "the-guest.scene.the-bowl"
ENDING = "{november-ending}"
SERENITY = "{serenity-at-breakfast}"

ENDING_RECALL = {
    "marker": ENDING,
    "entityID": "ambrose-trencher",
    "options": [
        {"key": "the-guest.bowl.stayed",
         "line": """The pots are done.

That's the first thing I see. They're hanging in their row over the range, biggest to smallest, every handle pointing the same way, shining like somebody had all night and nothing better to do. Which somebody did.

The stool's still by the fire. Nobody's on it. The brown bowl's on the hearth, washed and dry and empty, waiting for tonight.

Wicker comes in for porridge. He's learning to cook now, badly, on purpose, every day. He sees the pots, and his face does something soft, and he opens his mouth and says, “Oh, that's—tha—”

Min-seo's behind him in the queue. She puts her whole hand over his mouth before he can finish.

He looks at her over her fingers. She doesn't take it away.

“You don't,” she says. “Not to it. Say you're grateful, if you've got to say something. Or do the washing up.”

Wicker does the washing up. He's terrible at it. Something in the dark beside the range watches him do it, I think, and doesn't say a word, the way you don't say anything to somebody who's trying.

His name's Aiken Drum. He told us, at the end. I'm calling him he now, because a thing with a name is a somebody.

There's an old song from Galloway, in Scotland, about a brownie called Aiken Drum, who worked a farm all night for a bowl of brose and went away when somebody gave him a pair of trousers. That part's folklore. It's real folklore. You can look it up. I don't know if it's the same Aiken Drum. I haven't asked. You don't ask."""},
        {"key": "the-guest.bowl.sent-home",
         "line": """The stool's gone from beside the fire.

Not moved. Gone. Ambrose has put it in the Pantry, behind the flour sacks, where he doesn't have to look at it. He hasn't said a thing about it. He's said a great deal about porridge.

The pots are hanging over the range in no order at all. Ambrose did them himself last night, the way he's always done them, fast and loud and wrong. One of the little ones is upside down. He keeps looking at it. He hasn't fixed it.

There was something on the west step this morning: a brass button, tarnished, with a loop of green thread still through it. Just one. Very clean. Ambrose picked it up and didn't say anything, and now it's in his apron pocket. I can hear it clink when he stirs.

It's gone home. Wherever home is, for something like that. The first place, before there were kitchens. I don't know where it is. I only know the frost hasn't come in under the west door since. Not once. The onions have stopped being needed, and Ambrose keeps forgetting, and moving them back anyway."""},
        {"key": "the-guest.bowl.went-back",
         "line": """The west door's shut. Ambrose has pushed the sack of onions back against it, and then, after he'd thought about it, a second sack.

The pots are hanging in no order at all.

*The Middlemost Cookery*'s on the dresser, open, and I can see the gaps in it from here. Small clean holes in the lines where the letters went, like a smile with teeth out. They didn't come back. They went with it, out into the cold, to wherever the Court sits down to eat.

Ambrose doesn't look at the gaps. He's making porridge, a huge pot of it, enough for everybody twice. He makes everything like that. Too much, for whoever turns up.

“Keep cooking,” he says, to nobody, stirring. “Somebody should.”

He's put a stool back by the fire. Nobody's on it. I don't think he expects anybody to be. I think he just can't stand the space where it was."""},
    ],
    "fallback": """November ended on the last night, at the hearth. Ambrose cooked one small plain bowl from the back of the Cookery and set it down by the fire without saying who it was for. What happened after that is the Kitchens' business, and they're keeping it.

The stool's still by the fire. The cold's still under the west door, a little, if you know where to stand.""",
}

SERENITY_RECALL = {
    "marker": SERENITY,
    "entityID": "serenity-brown",
    "options": [
        {"key": "the-guest.offer.taken",
         "line": """Serenity comes down to breakfast and eats three bowls of porridge with golden syrup, and then a fourth, because she can. She tastes everything now. She licks the syrup spoon. She puts a pinch of salt on her tongue just to feel it go off like a firework.

Sometimes somebody mentions the evening, the one in November that she gave away, and she gets a polite, puzzled look and says, “Tell me again.”

So they do. They take turns. Everybody who was there has their own bit of it, and they hand it to her like a dish passed down the table. She listens like it's a story about somebody she'd have liked."""},
        {"key": "the-guest.offer.kept",
         "line": """Serenity comes down to breakfast and eats her porridge, which still tastes of paper. She minds it less than she did. She's started doing a thing: she gets whoever's next to her to tell her what it tastes like, and she eats while they talk.

This morning it's Penny. “Oats,” says Penny, unhelpfully. “Milk. Salt. Slightly too much salt. Ambrose is upset about something.”

Serenity laughs with her mouth full. She's still got her evening. She checks on it sometimes, the way you check a pocket for a key."""},
    ],
    "fallback": """Serenity comes down to breakfast and sits on the end of the long table, swinging her boots, her map case beside her. Whatever November asked of her, she isn't saying. She eats her porridge all the way to the bottom of the bowl.""",
}

FIRST_OF_DECEMBER = {
    "id": D, "packID": PACK_ID, "eventID": EVENT_ID, "title": "The First of December",
    "prompt": "Read on.", "detail": "The Guest Who Came on All Souls · December",
    "choices": [], "entities": ["The Book", "Ambrose Trencher", "Serenity Brown"],
    "tags": [EVENT_ID, "academy", "residue", "december"],
    "roomID": "location-kitchens",
    # Wicker and Min-seo only appear if it stayed, so they aren't listed.
    "castIDs": ["ambrose-trencher", "serenity-brown", "penny-blackletter"],
    "nodes": [
        node(f"{D}.entry", "The first of December",
             f"""It's the first of December, and the Kitchens are pretending nothing happened.

They're good at it. Ambrose has chalked the menu on the board by the door. It says *Porridge*, and underneath, smaller, *It's cold. Wear the other socks.* The range is lit. The long table's been scrubbed so hard that the knot in the pine has come up pale. Everything's back where it goes.

But I can smell November in the corners. Nutmeg in the cracks of the floor. Burnt sugar from Bonfire Night, still stuck to the underside of the toffee tray. And under all of it, where you'd only notice if you were made of paper, a little cold. Not frost. The memory of frost. The way a step remembers somebody who stood on it a long time.

{ENDING}

Penny's put the white bowl on a shelf in the Record room, under a card that says *Unattributed*, with the black thorn laid inside it. She's tied the thorn down with thread. She says that's for filing reasons.

I think it's so it can't get out.""",
             "Read on.",
             [choice("breakfast", "Breakfast.",
                     "Ambrose bangs the porridge pot with the ladle, twice. That means breakfast, and it means sit down.",
                     "On the first of December the Kitchens pretended nothing had happened, and Penny filed the white bowl and the thorn under Unattributed.",
                     ["december"], f"{D}.long-nights",
                     [memory("penny-blackletter", "the-guest.december.unattributed",
                             "On the first of December Penny filed the white bowl and the black thorn under Unattributed, and tied the thorn down with thread.",
                             aside="The thorn's tied down for filing reasons. Don't ask me what the other reasons are.")])],
             braid="On the first of December the Kitchens pretended nothing had happened, and Penny filed the white bowl and the thorn under Unattributed."),
        node(f"{D}.long-nights", "The long nights",
             f"""{SERENITY}

The nights are getting long now. Every evening the dark comes in a bit earlier and stays a bit later, like it's decided to move in. Yesterday Ambrose looked at the window at four o'clock and it was already black. He said, to nobody, “Somebody'll have to sit up with that.”

He meant the dark. I think. He doesn't say what he means. He makes porridge about it.

But he looked at you when he said it.""",
             "Who sits up with the long nights?",
             memories=[memory("serenity-brown", "the-guest.december.breakfast",
                              "On the first of December Serenity came down to breakfast at the long table and ate her porridge to the bottom of the bowl.",
                              aside="All of it. Ambrose watched me finish like it was an exam.")],
             choices=
             [
                 choice("sit-up", "I'll sit up with Ambrose.",
                        """He doesn't say yes. He goes and gets a second chair and puts it by the range, facing the window, and a blanket on it, and a mug on the floor beside it.

That's yes.""",
                        "On the first of December you said you'd sit up with Ambrose through the long nights, and he put out a second chair.",
                        ["december-watch-ambrose"],
                        memories=[memory("ambrose-trencher", "the-guest.december.second-chair",
                                         "On the first of December Ambrose put a second chair by the range for the reader, facing the long dark window.",
                                         aside="The second chair's out. Don't make a thing of it.",
                                         gossip="{teller} says Trencher's got two chairs by the range now, facing the window. He won't say who the other one's for.")]),
                 choice("light", "Leave a light in the west window.",
                        """You find a candle stub and a chipped saucer and set them on the west sill, and light it.

It burns small and steady. From outside, I think, it looks like somebody's home. That's what it's for. And it tells whoever's out there in the cold that somebody in here is awake, and looking out.""",
                        "On the first of December you left a candle burning in the Kitchens' west window, so whoever was out in the cold would know somebody was awake.",
                        ["december-watch-light"],
                        memories=[memory("penny-blackletter", "the-guest.december.candle",
                                         "On the first of December a candle went into the Kitchens' west window at dusk, and Penny wrote down that it was lit.",
                                         aside="Logged: one candle, west sill, lit at dusk. Purpose: unrecorded. I can guess.",
                                         gossip="{teller} says there's a candle in the Kitchens' west window every night now. Penny logs it. Nobody knows who lights it.")]),
                 choice("the-house", "Let the house keep its own watch.",
                        """You go up to bed. The Academy creaks all round you, settling, stretching its old beams in the cold. Somewhere below, the fire shifts in the range and settles too.

Houses know how to sit up by themselves. They've been doing it a lot longer than anybody.""",
                        "On the first of December you went up to bed and left the old house to keep its own watch through the long nights.",
                        ["december-watch-house"],
                        memories=[memory("ambrose-trencher", "the-guest.december.banked",
                                         "On the first of December Ambrose banked the range himself and left the old house to keep its own watch.",
                                         aside="The house can mind itself a night or two. It's done it before.")]),
             ]),
    ],
}
FIRST_OF_DECEMBER["opening"] = FIRST_OF_DECEMBER["nodes"][0]["body"]
FIRST_OF_DECEMBER["nodes"][0]["recalls"] = [ENDING_RECALL]
FIRST_OF_DECEMBER["nodes"][1]["recalls"] = [SERENITY_RECALL]

SCENES_DECEMBER = [FIRST_OF_DECEMBER]

ATOMS_DECEMBER = [
    atom(D, FIRST_OF_DECEMBER["title"], "storyScene", "storyScene", None, None, None,
         interaction="choice", priority="featured", occurrence={"kind": "untilResolved"},
         tags=("story", "residue"), stage="residue",
         dependencies=(needs(BOWL_ID, "nodeCompleted", "wait"),), extra={"isRequired": False}),
]
