"""Relics: small keepsake leaves for readers who lived a scene AND did its real-world
crossing. October's three are the pattern (`count-unbound.relic.*`)."""

from content_common import EVENT_ID, PACK_ID, atom, needs

RUN_ID = "the-guest:2026"
DETAIL = "The Guest Who Came on All Souls · November 2026"


def receipt(content_id):
    return {"kind": "receipt", "receipt": {"contentID": content_id, "state": "completed", "scopeID": PACK_ID,
                                            "runID": RUN_ID, "minimumOccurrences": 1}}


def relic(slug, title, body, braid):
    id = f"{EVENT_ID}.relic.{slug}"
    leaf = {"id": f"{id}.leaf", "title": title, "body": body, "prompt": "Keep this trace.", "choices": [],
            "braidText": braid}
    return {"id": id, "packID": PACK_ID, "eventID": EVENT_ID, "title": title, "opening": body,
            "prompt": "Keep this trace.", "detail": DETAIL, "choices": [], "entities": ["The Book"],
            "tags": [EVENT_ID, "return-relic", slug], "nodes": [leaf]}


SOUL_CAKE = relic(
    "soul-cake-cross", "The Cross off a Soul Cake",
    """At the end of All Souls week there was one soul cake left.

Ambrose found it at the back of the bread crock, gone hard as a roof tile. He doesn't throw food away. He broke it in half over the hens' bucket, and a little piece of the top flew off and landed in my gutter, and stuck.

It's the bit with the cross on. Two cuts in brown crust, the shape a knife makes when somebody means it. The old Academy cut that cross so the cake would know who it was for.

I've kept it there. It's gone soft with my keeping. It still smells, very faintly, of nutmeg and the end of a long day.""",
    "I kept the cross off the last soul cake of All Souls week, stuck in my gutter, beside the thing you made again.")

SLIP_SEVEN = relic(
    "slip-seven", "Slip Number Seven",
    """Serenity didn't open the rest of Soren's slips. She kept the first one in her pocket, and the other eight stayed on the dresser in their row, folded, beside their spoons.

The morning after, they were gone. All but one. Number seven had slid down behind the bread crock, and when Penny moved the crock to dust, it fell out and landed open, right on my leaf.

There wasn't a taste on the seventh spoon. Soren left it empty. The slip says, in his small careful hand:

*This one's warm. That's all. Hold it.*

She couldn't taste anything, then. But she could feel warm. He'd worked that out before anybody.

I haven't told her I've got it. I don't think it's mine to give.""",
    "I kept Soren's seventh slip, the one for the empty, warm spoon, beside the recipe you rescued.")

CLEAN_SPOON = relic(
    "clean-spoon", "A Very Clean Spoon",
    """After Serenity went up to bed that night, the Guest washed her spoon.

It didn't have to. Ambrose washes everything in the morning. But it took the spoon from beside her empty bowl and scrubbed it, round and round, slowly, the way it scrubs the pots, for longer than any spoon has ever needed.

In the morning it was back in the drawer with the others. You can tell which one. It shines like a puddle with the sky in it. When I'm open on the dresser, I can see my own leaves in the back of it, upside down.

Nobody uses it. Everybody knows which spoon it is, and nobody ever says.

I've kept the shine of it.""",
    "I kept the shine of the spoon the Guest scrubbed after Serenity's soup, beside the food you gave away.")

NAPKIN_HAT = relic(
    "napkin-hat", "The Napkin Hat",
    """Ambrose left the empty place at the long table all night, the way he always does. The plate still full. The candle out. The napkin folded into its little hat.

In the morning, the napkin hat had moved.

Not far. It was in the very middle of the plate now, where it hadn't been. As if somebody had sat down in the night, and picked it up, and looked at it a while, and put it back. Exactly. Very gently.

Ambrose saw it. He didn't say anything. He cleared the plate and shook out the napkin and put it in the wash with all the others.

But I'd already got the creases. I've kept them, every fold, in case anybody wants to know how it was done.""",
    "I kept the creases of the napkin hat from the empty place at the long table, beside the place you set.")

# (relic, scene that must be completed, crossing that must be completed, phase, first day)
RELICS = [
    (SOUL_CAKE, "the-guest.scene.the-knock", "the-guest.mission.made-for-you", "guest-right", 7),
    (SLIP_SEVEN, "the-guest.scene.the-rescue", "the-guest.mission.rescue-a-recipe", "the-offer", 15),
    (CLEAN_SPOON, "the-guest.scene.the-offer", "the-guest.mission.feed-someone", "the-offer", 20),
    (NAPKIN_HAT, "the-guest.scene.a-place-at-the-table", "the-guest.mission.set-a-place", "the-bowl", 26),
]

SCENES_RELICS = [r[0] for r in RELICS]

ATOMS_RELICS = []
for scene, lived, crossing, phase, first_day in RELICS:
    a = atom(scene["id"], scene["title"], "storyScene", "storyScene", phase, first_day, 30,
             interaction="choice", priority="featured", occurrence={"kind": "untilResolved"},
             tags=("relic",), dependencies=(needs(lived, policy="wait"),),
             extra={"isRequired": False, "survivesConclusion": True})
    a["gate"]["allOf"].append(receipt(crossing))
    ATOMS_RELICS.append(a)
