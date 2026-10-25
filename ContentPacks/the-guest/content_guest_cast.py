"""The Guest's own witness, using the staged visitor's permanent Cast ID.

These memories are authored beside the scene IDs. They use the ordinary Cast
memory harvest; no extra progression or save state is introduced.
"""
from content_common import memory

GUEST = "visitor-the-guest"

# The moment's node is the shared event; choices keep its private part.
SCENE_MEMORIES = {
    "the-knock": ("the-guest.knock.arrived",
        "The Guest knocked at the west door. Ambrose gave it a soul cake and a place by the fire before asking its name.",
        "He moved the onions. There was a place by the fire."),
    "three-nights": ("the-guest.three-nights.sheltered",
        "The Guest spent three nights at the Academy hearth. Ambrose refused to let Vellum examine it without leave.",
        "Three nights. The house knows its own rule."),
    "flat": ("the-guest.flat.second-helping",
        "The Guest sat in the Kitchens while the food went flat. Ambrose still gave it another helping.",
        "He divided the bread again. There was enough."),
    "the-rescue": ("the-guest.rescue.asked",
        "Min-seo asked the Guest what it needed while the students cooked in Ambrose's kitchen.",
        "She asked what I needed. Nobody else had asked that."),
    "the-offer": ("the-guest.offer.made",
        "The Guest offered Serenity her taste back in return for the memory of her October evening.",
        None),
    "stir-up-sunday": ("the-guest.stir.watched",
        "The Guest took its turn stirring the Academy's pudding, from east to west, with both its clean hands on the spoon.",
        "Everybody had a turn with the spoon."),
    "a-place-at-the-table": ("the-guest.table.place",
        "The Guest was at the Academy's long table when the company made room for people who weren't there.",
        "An empty chair can be meant for somebody."),
    "the-bowl": ("the-guest.bowl.offered",
        "Ambrose set the brown bowl on the hearth for the Guest, without asking for thanks or payment.",
        None),
    # The six short scenes between the eight.
    "pot-watch": ("the-guest.pot-watch.scrubbed",
        "The Guest scrubbed every pot in the Kitchens at three in the morning while three students slept under the long table.",
        "They brought toffee. They slept. The pots were done."),
    "salt": ("the-guest.salt.seconds",
        "The Guest ate two bowls of Ambrose's stock by the fire while Dr. Vellum measured everybody else's.",
        "It was warm. I had more. Nobody measured mine."),
    "nine-spoons": ("the-guest.spoons.seventh",
        "The Guest woke by the Kitchens fire at the seventh spoon, the empty one, and watched Serenity hold it.",
        "Nothing on a spoon. I know that taste."),
    "the-tray": ("the-guest.tray.bowed",
        "The Guest followed the Headmistress's tray up the tower stairs and bowed to her, and she sent it down again.",
        "Her stairs. She keeps her own house."),
    "letters-home": ("the-guest.letters.slept",
        "The Guest slept by the fire while Penny and Pippa read the letters coming home to The Middlemost Cookery.",
        "They were counting what came back. I heard the pages."),
    "the-day-book": ("the-guest.day-book.slept",
        "The Guest slept by the fire while Professor Boggle read the old house day-book aloud in the Kitchens.",
        None),
}

MEMORY_NODES = {"flat": "kitchens", "the-rescue": "min-seo",
                "nine-spoons": "spoons", "the-tray": "stairs", "the-day-book": "accounts"}

CHOICE_MEMORIES = {
    ("the-knock", "give-name"): ("the-guest.knock.reader-name",
        "The Reader gave the Guest their name by the fire. The Guest listened and kept it carefully.",
        "You said what I should call you. I heard."),
    ("the-knock", "false-name"): ("the-guest.knock.reader-name",
        "The Reader offered the Guest a borrowed name. The Guest accepted the name it was given.",
        "That was the name you gave. I didn't ask for another."),
    ("the-knock", "no-name"): ("the-guest.knock.reader-name",
        "The Reader kept their name to themselves at the hearth. The Guest didn't insist.",
        "A place by the fire doesn't need your name on it."),
    ("the-offer", "take-it"): ("the-guest.offer.taken",
        "Serenity accepted the Guest's offer. Her taste returned, and she gave away the memory of her October evening.",
        None),
    ("the-offer", "keep-night"): ("the-guest.offer.kept",
        "Serenity refused the Guest's offer and kept the memory of her October evening.",
        "She said no. I heard that too."),
    ("pot-watch", "look"): ("the-guest.pot-watch.seen",
        "The Reader watched from under the long table while the Guest scrubbed the copper jam pan.",
        "You looked. Pots don't mind being watched."),
    ("pot-watch", "thank-it"): ("the-guest.pot-watch.thanked",
        "The Reader thanked the Guest out loud in the dark while it scrubbed the pots, and its humming stopped.",
        None),
    ("the-bowl", "send-home"): ("the-guest.bowl.sent-home",
        "The Reader told the Guest to go home. It said it was grateful and left through the west door.",
        None),
    ("the-bowl", "ask-to-stay"): ("the-guest.bowl.stayed",
        "The Reader asked the Guest to stay. It accepted the Academy's hearth and told the household its name, Aiken Drum.",
        "The house asked. I stayed. The bowl goes there."),
    ("the-bowl", "let-it-go-back"): ("the-guest.bowl.went-back",
        "The Reader told the Guest the house couldn't take it back. It went back into the cold and told Ambrose to keep cooking.",
        None),
}


def give_the_guest_its_memories(scenes, event):
    for scene in scenes:
        short = scene["id"].removeprefix("the-guest.scene.")
        authored = SCENE_MEMORIES.get(short)
        if authored is None:
            continue
        if GUEST not in scene["castIDs"]:
            scene["castIDs"].append(GUEST)
        # Freeze only after this moment's node is committed. An opening node
        # mustn't give him something that happens farther down the route.
        moment = next(n for n in scene["nodes"] if n["id"].endswith('.' + MEMORY_NODES.get(short, 'entry')))
        moment.setdefault("castMemories", []).append(memory(GUEST, *authored))
        for node in scene["nodes"]:
            for choice in node["choices"]:
                witness = CHOICE_MEMORIES.get((short, choice["id"]))
                if witness:
                    choice.setdefault("castMemories", []).append(memory(GUEST, *witness))
    # Public arrival can introduce the Guest to a Reader who missed the Knock.
    # No public record decides an ending or discloses the name.
    arrival = next(e for e in event["record"]["entries"] if e["id"] == "the-guest.record.the-knock")
    arrival.setdefault("castMemories", []).append(memory(GUEST, *SCENE_MEMORIES["the-knock"]))
