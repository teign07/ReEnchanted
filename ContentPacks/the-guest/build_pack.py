#!/usr/bin/env python3
"""Builds the November 2026 issue, The Guest Who Came on All Souls.

The JSON this writes is what ships; this file is where it's authored. Run it from
anywhere: `python3 ContentPacks/the-guest/build_pack.py`. Story bible:
docs/november-the-guest.md. Scene drafts: docs/november-the-guest-scenes.md.

Live day 0 is Sunday 1 November 2026.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PACK_ID = "the-guest-november-2026"
EVENT_ID = "the-guest"
OUT = os.path.join(HERE, "november.reenchantedevents.json")
MARGINS_OUT = os.path.join(HERE, "margins.reenchantedpack.json")

from content_event import EVENT, BEATS  # noqa: E402
from content_scenes import SCENES as SCENES_EARLY, SCENE_ATOMS as ATOMS_EARLY  # noqa: E402
from content_scenes2 import SCENES_LATE, ATOMS_LATE  # noqa: E402

from content_december import SCENES_DECEMBER, ATOMS_DECEMBER  # noqa: E402
from content_relics import SCENES_RELICS, ATOMS_RELICS  # noqa: E402
from content_guest_cast import give_the_guest_its_memories  # noqa: E402

SCENES = SCENES_EARLY[:4] + SCENES_LATE + SCENES_DECEMBER + SCENES_EARLY[4:] + SCENES_RELICS
SCENE_ATOMS = ATOMS_EARLY[:4] + ATOMS_LATE + ATOMS_DECEMBER + ATOMS_EARLY[4:] + ATOMS_RELICS
give_the_guest_its_memories(SCENES, EVENT)
from content_bleed import BLEED_ARTICLES, BLEED_ATOMS, DESK_PIECES  # noqa: E402
from content_pages import BEAT_ATOMS  # noqa: E402
from content_extras import WONDER_LINES, NOTE_PROMPTS  # noqa: E402
from content_margins import margins_pack, UNDERTAKINGS, SPELLS, SNIPPETS  # noqa: E402


def manifest():
    return {
        "schemaVersion": 1,
        "id": PACK_ID,
        "issueNumber": 2,
        "publicationKind": "publicIssue",
        "title": EVENT["title"],
        "eventPackID": PACK_ID,
        "eventID": EVENT_ID,
        "phasePlans": [
            {"phaseID": "all-souls", "role": "setup", "openingContentID": "the-guest.scene.the-knock",
             "directionPacketID": "the-guest.direction.all-souls", "directionStatus": "ready"},
            {"phaseID": "guest-right", "role": "buildup", "openingContentID": "the-guest.scene.flat",
             "directionPacketID": "the-guest.direction.guest-right", "directionStatus": "ready"},
            {"phaseID": "the-offer", "role": "climax", "openingContentID": "the-guest.scene.the-offer",
             "directionPacketID": "the-guest.direction.the-offer", "directionStatus": "ready"},
            {"phaseID": "the-bowl", "role": "aftermath", "openingContentID": "the-guest.scene.a-place-at-the-table",
             "directionPacketID": "the-guest.direction.the-bowl", "directionStatus": "ready"},
        ],
        "content": SCENE_ATOMS + BEAT_ATOMS + BLEED_ATOMS,
        "coverageRequirements": coverage(),
        "externalContentIDs": ["count-unbound.relationship.november-occasion"],
    }


def coverage():
    def req(id, label, channel, minimum, maximum=None, stage=None, role=None, priorities=(), interactions=(), tags=()):
        r = {"id": id, "label": label, "channel": channel, "minimumReady": minimum,
             "priorities": list(priorities), "interactions": list(interactions), "tagsAll": list(tags)}
        if maximum is not None:
            r["maximumReady"] = maximum
        if stage:
            r["lifecycleStage"] = stage
        if role:
            r["phaseRole"] = role
        return r
    return [
        req("setup-spine", "Setup spine", "storyScene", 1, stage="live", role="setup", priorities=("spine", "milestone")),
        req("buildup-spine", "Buildup spine", "storyScene", 1, stage="live", role="buildup", priorities=("spine", "milestone")),
        req("climax-spine", "Climax spine", "storyScene", 1, stage="live", role="climax", priorities=("spine", "milestone")),
        req("aftermath-spine", "Aftermath spine", "storyScene", 1, stage="live", role="aftermath", priorities=("spine", "milestone")),
        req("crossings", "Weekly real-world crossings", "storyScene", 2, 4, stage="live", interactions=("fieldMission",)),
        req("bleed-reports", "Guest Bleed reports", "bleedArticle", 2, 8),
        req("letters", "Kitchen letters", "page", 2, 3, tags=("letter",)),
        req("classes", "Academy classes", "page", 3, 3, tags=("class",)),
    ]


def build():
    pack = {
        "id": PACK_ID,
        "displayName": "The Guest Who Came on All Souls",
        "version": 2,
        "author": "ReEnchanted",
        "availability": "userImported",
        "minimumRuntimeVersion": 12,
        "events": [dict(EVENT, beats=BEATS)],
        "authoringManifests": [manifest()],
        "storyScenes": SCENES,
        "bleedArticles": BLEED_ARTICLES + DESK_PIECES,
        "wonderLines": WONDER_LINES,
        "notePrompts": NOTE_PROMPTS,
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(pack, f, ensure_ascii=False, indent=1)
        f.write("\n")
    with open(MARGINS_OUT, "w", encoding="utf-8") as f:
        json.dump(margins_pack(), f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"wrote {os.path.relpath(OUT)}: {len(SCENES)} scenes, {len(BEATS)} beats, "
          f"{len(BLEED_ARTICLES)} articles, {len(DESK_PIECES)} desk pieces, "
          f"{sum(len(p['pulses']) for p in EVENT['phases'])} pulses, "
          f"{len(EVENT['record']['entries'])} record entries, {len(EVENT['catchUp'])} rungs")
    print(f"wrote {os.path.relpath(MARGINS_OUT)}: {len(UNDERTAKINGS)} ladders, {len(SPELLS)} spells, "
          f"{len(SNIPPETS)} pencilings")


if __name__ == "__main__":
    build()
