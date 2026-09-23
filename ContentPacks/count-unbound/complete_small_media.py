#!/usr/bin/env python3
"""Synchronize the non-audio October articles, letters, lessons, and residue."""

import json
from pathlib import Path


ROOT = Path(__file__).parent
PACK = ROOT / "opening.reenchantedevents.json"
PACK_ID = "count-unbound-october-2026"
EVENT_ID = "count-unbound"


def article(id, title, body, byline="Penny Blackletter"):
    return dict(id=id, packID=PACK_ID, eventID=EVENT_ID, title=title,
                byline=byline, body=body, editionKinds=["morning", "evening"],
                tags=["count-unbound", "monthly-bleed"])


ARTICLES = [
    article("count-unbound.bleed.jump-complete", "Every Listed Jumper Home", """A supervised Jump into *Dracula* ended early after Wicker Eddies wrote an unauthorized sentence in the source margin. The sentence read: *For one sentence, let him choose the verb.*

Professor Permancer opened the return. Every registered entrant answered the bookmark's check. The source is closed while the annotation is examined.

“I meant it,” Eddies said when asked whether it was a prank.

Permancer has asked the Bleed to print the exact sentence. We have."""),
    article("count-unbound.bleed.east-stacks", "Serenity Brown Awake", """Serenity Brown is awake in the Kitchens after an attack in the East Stacks. Count Dracula crossed out of his source during Sunday's return and deliberately used the wound to hold himself in Academy space.

Brown can hear page-turns from closed books. She is deciding what help she wants to give. Reports go to Penny Blackletter; visits go through Ambrose. No further injury has been reported.

Permancer has confirmed that he opened the return invitation. Eddies has confirmed his alteration to the source. Both are assisting the investigation."""),
    article("count-unbound.bleed.several-places", "Several Places, One Entrance", """A composite castle has grown through the East Stacks. The Quillquarium drawbridge is real and closed to visitors. The nursery window belongs to a neighboring book. Please don't take it home.

Dracula's absence from his source is pulling other stories into the gap. The Academy has reconstructed the return conditions: source, invitation, and withdrawal of the living claim.

Serenity Brown has agreed to the controlled return. The final condition is hers to release."""),
    article("count-unbound.bleed.count-returned", "The Count Returned", """Dracula is back in *Dracula*. The borrowed rooms have returned to their books.

Serenity Brown still hears the crossings. She has named the change Nightbound and asked us to print it. She was in the Kitchens this morning, complaining about her cards.

The Vault's new return list names every permitted traveller and must be checked from both sides. Permancer has suspended ordinary teaching Jumps while the safeguards are fitted. The school will publish the reopening when it has one.

Eddies helped close the breach. The original annotation remains in the record."""),
]


def beat(id, phase, role, first, last, title, body, report, page_type, stage=None):
    result = dict(id=id, phaseID=phase, role=role, opensOnDay=first,
                  expiresAfterDay=last, title=title, body=body, report=report,
                  isMilestone=False, pageType=page_type, reportsWhenMissed=False)
    if stage:
        result["lifecycleStage"] = stage
    return result


BEATS = [
    beat("count-unbound.class.book-jumping-roster", "school-hours", "setup", 3, 6,
         "The Roster", "Professor Permancer passes the bookmark around. Each ribbon answers one name. Penny checks that she can match them without looking at the total. “Again,” he says. The ribbon has already started.",
         "Permancer's class practiced matching each returning ribbon to a named traveller, not merely counting them.", "academyClass"),
    beat("count-unbound.class.ink-has-no-conscience", "uninvited", "buildup", 7, 13,
         "Ink Has No Conscience", "Professor Villanelle puts Wicker's sentence on the board. Nobody laughs at it. “Read the verb,” she says. “Now tell me who had to live with it.”",
         "Villanelle's class studied the sentence Wicker wrote in the source and asked who bore its consequence.", "academyClass"),
    beat("count-unbound.letter.permancer", "uninvited", "buildup", 14, 20,
         "A Letter from Permancer", "Reader—\n\nI went back to the Vault before breakfast.\n\nI put the list where Penny held it. I stood where I had stood. Every ribbon pointed home.\n\nThen I walked around it.\n\nThe list told me everyone had come home. It had not counted who else crossed. I should have checked both sides before I invited anyone through.\n\nThe new procedure is on my desk. There is a blank line at the bottom for what I have still failed to ask.\n\nIf you bring back a look from the other side of something, I would like to read it. Penny is making room beside the chalk outline.\n\n—Permancer",
         "Permancer wrote to the Reader about the return list's blind side and the procedure he was changing.", "letter"),
    beat("count-unbound.class.invitation-shape", "uninvited", "buildup", 17, 20,
         "The Chair's Direction", "Professor Wispwood turns a chair towards the class. Then towards the wall. “Same chair,” she says. “Which way would you sit?” The chair turns itself back. “Thank you,” she tells it.",
         "Wispwood's class tested how the direction of an ordinary chair could change an invitation.", "academyClass"),
    beat("count-unbound.class.rest-after-door", "nightbound", "aftermath", 28, 30,
         "Rest After the Door", "Professor Stonebrook takes the chalk out of the clock's hands. For a little while, the room stops writing the next thing. There's a chair by the window. He sits in the other one.",
         "Stonebrook made room for rest after the return rather than assigning another crossing.", "academyClass"),
    beat("count-unbound.letter.wicker", "nightbound", "aftermath", 29, 30,
         "A Letter from Wicker", "I repaired Serenity's map case.\n\nThe clasp was always crooked. I used to tell her so. She used to tell me to carry my own map.\n\nI straightened it. Then I tried closing it with one hand and had to put it back the way it was.\n\nShe's using it. She hasn't spoken to me about it.\n\nI keep writing another sentence here. I've crossed it out so often the paper's gone soft.\n\nLeave that bit alone.\n\n—Wicker",
         "Wicker wrote that he repaired Serenity's map case and left the crooked clasp as she used it.", "letter"),
    beat("count-unbound.residue.protocol-amendment", "nightbound", "aftermath", 0, 6,
         "Amendment in the Vault", "Permancer's notice has a new line: *An invitation can be held open, lit, arranged, or left waiting.* Below it, Penny has written: *Check what it means from the other side.* The notice hangs a little away from the wall so you can read the back.",
         "The Vault posted an amended invitation rule and Penny's instruction to check it from the other side.", "bookNotices", "residue"),
    beat("count-unbound.residue.route-receipt", "nightbound", "aftermath", 0, 6,
         "Receipt or Rumor", "People say the red chair still appears after the East Stacks close. It's facing the right way now. Nobody agrees which way that is.",
         "People disagreed about which way the red chair faced after the East Stacks closed.", "bookNotices", "residue"),
]


PHASES = {
    "setup": "school-hours", "buildup": "uninvited",
    "climax": "reciprocal", "aftermath": "nightbound",
}


def atom(id, title, channel, kind, role, first, last, stage="live", tags=()):
    gate = {"allOf": [{"kind": "worldEvent", "worldEvent": {
        "eventIDs": [EVENT_ID], "runIDs": [], "phaseIDs": [], "phaseRoles": [],
        "lifecycleStages": [stage], "activationModes": [],
        **({"minimumLiveDay": first, "maximumLiveDay": last} if stage == "live" else {})
    }}], "anyOf": [], "noneOf": []}
    return dict(id=id, title=title, reference={"kind": kind, "id": id},
                channel=channel,
                placement={"lifecycleStage": stage, **({"phaseID": PHASES[role], "phaseRole": role} if stage == "live" else {})},
                audience="everyone", voice="publicReport" if channel == "bleedArticle" or stage == "residue" else "immediate",
                interaction="none", priority="featured" if stage == "live" else "ambient",
                gate=gate, occurrence={"kind": "oncePerRun"}, dependencies=[],
                productionStatus="ready", isRequired=True,
                tags=["count-unbound", *tags])


def main():
    pack = json.loads(PACK.read_text())
    event = pack["events"][0]
    manifest = pack["authoringManifests"][0]
    ids = {item["id"] for item in ARTICLES + BEATS}
    pack["bleedArticles"] = [item for item in pack.get("bleedArticles", []) if item["id"] not in ids] + ARTICLES
    event["beats"] = [item for item in event.get("beats", []) if item["id"] not in ids] + BEATS
    atoms = [item for item in manifest["content"] if item["id"] not in ids]
    # News of a same-day incident starts the following morning. An unseen
    # Reader may receive public history, but never a premature headline.
    for item, role, first, last in zip(ARTICLES, ("setup", "buildup", "climax", "aftermath"),
                                       (4, 8, 22, 28), (6, 13, 26, 30)):
        atoms.append(atom(item["id"], item["title"], "bleedArticle", "bleedArticle",
                          role, first, last, tags=("monthly-bleed",)))
    for item in BEATS:
        stage = item.get("lifecycleStage", "live")
        tags = ("letter",) if item["pageType"] == "letter" else (("class",) if item["pageType"] == "academyClass" else ("residue",))
        atoms.append(atom(item["id"], item["title"], "page", "worldEventBeat",
                          item["role"], item["opensOnDay"], item["expiresAfterDay"],
                          stage=stage, tags=tags))
    manifest["content"] = atoms
    # Every preparation can meet Penny's independent check. A completed Week
    # Three return adds the Reader's exact observation; absent evidence leaves
    # the same fictional discovery in place without inventing participation.
    strategy = next(scene for scene in pack["storyScenes"] if scene["id"] == "count-unbound.strategy")
    insertion = {
        "contentID": "count-unbound.mission.other-side",
        "marker": "{other-side}",
        "quotationTemplate": "I open to the detail you checked from another side. “{sentence}”\n\nPenny turns a catalogue card over and writes BACK. “I'm adding a column.” She checks both sides of the prepared threshold.",
        "fallback": "Penny turns a catalogue card over and writes BACK. “I'm adding a column.” She checks both sides of the prepared threshold.",
        "interpretations": {},
    }
    for node in strategy["nodes"]:
        if node["id"] not in {"count-unbound.strategy.terms.after", "count-unbound.strategy.hunt.after", "count-unbound.strategy.gambit.after"}:
            continue
        node["findingInsertion"] = insertion
        node["body"] = node["body"].replace(
            'Penny walks behind the chalk. “Let\'s see what it does from here.”',
            "{other-side}")
        if "{other-side}" not in node["body"]:
            node["body"] += "\n\n{other-side}"
    PACK.write_text(json.dumps(pack, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
