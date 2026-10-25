"""November art, using the existing story media and shared marginalia cabinet."""

from content_common import PACK_ID, EVENT_ID, atom, needs

CABINET_ID = "the-guest-margins"
TEMPLATES = ["harbor_field_note", "creature_comfort", "home_vessel", "good_company",
             "academy_field_study", "rest_and_quiet"]

# A plate belongs to the passage it depicts, rather than every branch of a scene.
STORY_PLATES = {
    "the-knock": ("entry", "The Knock"),
    "three-nights": ("bonfire", "Bonfire Night"),
    "flat": ("entry", "Martinmas supper"),
    "the-rescue": ("cooking", "Everybody cooks"),
    "the-offer": ("entry", "Three in the morning"),
    "stir-up-sunday": ("entry", "Stir-up Sunday"),
    "a-place-at-the-table": ("entry", "A place at the table"),
    "the-bowl": ("entry", "The bowl on the hearth"),
}


def attach_story_plates(scenes):
    by_id = {scene["id"]: scene for scene in scenes}
    for name, (node_name, caption) in STORY_PLATES.items():
        scene_id = f"the-guest.scene.{name}"
        scene = by_id[scene_id]
        node_id = f"{scene_id}.{node_name}"
        node = next(node for node in scene["nodes"] if node["id"] == node_id)
        media_id = f"the-guest.story-art.v1.scene.{scene_id}"
        node["illustration"] = {
            "id": media_id, "kind": "renderedImageFile",
            "reference": "{{asset-path:" + media_id + "}}",
            "caption": caption, "sourceID": "monthly-story-plate", "metadata": {},
        }


# Tags describe the actual objects; the shared resolver decides their placement.
SEASONAL = {
    "soul-cake": ("watercolor", ["food", "soul-cake", "remembrance"]),
    "parkin": ("watercolor", ["food", "parkin", "bonfire"]),
    "toffee-hammer": ("watercolor", ["toffee", "bonfire", "sweet"]),
    "wooden-spoon": ("scribble", ["spoon", "cooking", "recipe"]),
    "copper-pot": ("watercolor", ["pot", "copper", "cooking"]),
    "onion": ("botanical", ["onion", "food", "cooking"]),
    "garlic": ("botanical", ["garlic", "food", "cooking"]),
    "half-loaf": ("watercolor", ["bread", "sharing", "martinmas"]),
    "honey-jar": ("watercolor", ["honey", "jar", "sweet"]),
    "apple-star": ("botanical", ["apple", "seed", "star"]),
    "brass-button": ("scribble", ["button", "brass", "green-coat"]),
    "iron-latch": ("scribble", ["latch", "door", "frost"]),
    "black-thorn": ("botanical", ["thorn", "blackthorn", "cold"]),
    "pudding-cloth": ("watercolor", ["pudding", "wish", "stir-up-sunday"]),
    "numbered-spoon": ("fieldNote", ["spoon", "taste", "soren-ng"]),
    "candle-saucer": ("watercolor", ["candle", "light", "table"]),
    "napkin-hat": ("scribble", ["napkin", "table", "absence"]),
    "brown-bowl": ("watercolor", ["bowl", "oats", "hearth"]),
    "flour-handprint": ("texture", ["flour", "thumbprint", "stain"]),
    "tea-ring": ("texture", ["tea", "ring", "stain"]),
}

# The small story marks follow witnessed scenes; the final thorn waits for residue.
MARKS = [
    ("soul-cake-cross", "the-knock", "all-souls", 0, 6, "live"),
    ("west-door", "the-knock", "all-souls", 0, 6, "live"),
    ("scrubbed-pots", "three-nights", "guest-right", 7, 14, "live"),
    ("green-button", "three-nights", "guest-right", 7, 14, "live"),
    ("missing-letter", "three-nights", "guest-right", 7, 14, "live"),
    ("nine-spoons", "the-rescue", "the-offer", 15, 24, "live"),
    ("hearth-bowl", "the-bowl", "the-bowl", 29, 29, "live"),
    ("the-thorn", "the-bowl", None, None, None, "residue"),
]


def asset(name, *, directed=False, role="fieldNote", subjects=()):
    media_id = f"the-guest.{'mark' if directed else 'seasonal'}.v1.{name}"
    tags = ["monthly-content", "november-2026", "event:the-guest", "kitchen", name] + list(subjects)
    if directed:
        tags += ["monthly-margin", "ink"]
    return {
        "id": f"the-guest.{'margin' if directed else 'seasonal'}.{name}",
        "assetName": "{{asset-path:" + media_id + "}}", "kind": "doodle",
        "tags": tags, "supportedTemplates": TEMPLATES,
        "defaultOpacity": 1.0, "canTint": False, "directedOnly": directed,
        "placementTrigger": {"months": [11], "issueYear": 2026} if not directed else None,
        "leafTraits": {
            "semanticRole": role, "aspectRatio": 1.0,
            "preferredAnchors": ["lowerField"] if directed else ["middleLeading", "lowerLeading", "lowerField"],
            "crop": "contain", "blend": "normal", "visualWeight": 0.93,
            "allowsTextOverlap": False, "tintStrength": 0.0,
            "subjectTags": ["kitchen", name] + list(subjects),
        },
    }


def marginalia_cabinet():
    return {
        "id": CABINET_ID, "displayName": "November 2026 · The Guest",
        "version": "1.0", "author": "The Book", "availability": "userImported",
        "supportedTemplates": TEMPLATES,
        "backgrounds": [], "paperScraps": [], "stamps": [], "tape": [], "overlays": [],
        "fallbackPhrases": [],
        "doodles": [asset(name, role=role, subjects=tags) for name, (role, tags) in SEASONAL.items()]
                   + [asset(row[0], directed=True) for row in MARKS],
    }


def directed_marks():
    return [{
        "id": f"the-guest.margin.{name}", "packID": PACK_ID, "eventID": EVENT_ID,
        "assetPackID": CABINET_ID, "assetID": f"the-guest.margin.{name}",
        "text": "", "tags": [EVENT_ID, "authored-margin", "kitchen", name],
        "targetPageTypes": ["plainPage", "bookOfYou", "narrativeOS", "recipe", "packPage"],
        "targetContentIDs": [], "targetTagsAny": ["kitchen", EVENT_ID, "recipe"],
    } for name, *_ in MARKS]


def marginalia_atoms():
    return [atom(
        f"the-guest.margin.{name}", name.replace("-", " ").capitalize(),
        "marginalia", "marginalia", phase, start, end, stage=lifecycle,
        priority="ambient", tags=["monthly-margin", "kitchen"],
        dependencies=[needs(f"the-guest.scene.{scene}", policy="wait")],
        # After the month a mark is a receipt for readers who were there; the
        # device refuses the whole issue if residue speaks to everyone.
        voice="participantReceipt" if lifecycle == "residue" else "immediate",
        extra={"isRequired": False, **({"audience": "participants"} if lifecycle == "residue" else {})},
    ) for name, scene, phase, start, end, lifecycle in MARKS]
