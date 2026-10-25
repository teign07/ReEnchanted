"""Radio: five DJ breaks on the existing stations, recorded by bj in ElevenLabs (2026-10-25).
Scripts and direction: RADIO-RECORDING.md. Each caption is exactly what was said; the pause
tags used for the recording aren't spoken and aren't in the caption."""

from content_common import EVENT_ID, PACK_ID, atom, needs

# (name, station, category, caption, file, placement)
CLIPS = [
    ("forty-cakes", "thornwave", "gossip",
     "Thornwave. Trencher's baking soul cakes. Forty of them. I asked him who they're for. He said "
     "“whoever knocks.” Nobody knocks on the Kitchens. There's no door there anybody uses. "
     "Here's one with a bolt on it.",
     "DJ_thornwave_the_guest_forty_cakes_01.mp3", "foreshadow"),
    ("kitchen-notice", "fae-fi", "news",
     "Fae-Fi, and a notice from the Kitchens. There's a new kitchen hand. Don't thank it. Don't leave it "
     "clothes. If you really have to say something, say you're grateful, and then go and do the washing up. "
     "That's it. That's the notice. Here's a song about bees.",
     "DJ_faefi_the_guest_kitchen_notice_01.mp3", "guest-right"),
    ("three-in-the-morning", "mothlight-beats", "news",
     "Mothlight. It's very late. The Kitchens' light is on again. If you're down there at this hour, and "
     "something at the sink is kind enough to offer you anything at all, finish your soup first. "
     "Always finish your soup.",
     "DJ_mothlight_the_guest_three_am_01.mp3", "the-offer"),
    ("wish", "thornwave", "gossip",
     "I stirred the pudding. I made a wish. Not telling you. Penny says it has to hang in a cloth till "
     "Christmas before it counts. So do the rest of us. Here's the track.",
     "DJ_thornwave_the_guest_wish_01.mp3", "stir-up"),
    ("the-bowl-is-washed", "fae-fi", "news",
     "Fae-Fi. The bowl's back on the dresser, washed and dry. Nobody saw who washed it. Trencher says "
     "that's how it's meant to be, and he'd like his kitchen back now, please. Here's something warm.",
     "DJ_faefi_the_guest_bowl_washed_01.mp3", "residue"),
]


def media_id(name):
    return f"{EVENT_ID}.audio.{name}"


RADIO_BANTERS = [{
    "id": f"{EVENT_ID}.radio.{name}", "packID": PACK_ID, "eventID": EVENT_ID, "stationID": station,
    "banter": {"id": f"{EVENT_ID}.radio.{name}", "category": category,
               "assetName": "{{asset-path:" + media_id(name) + "}}", "caption": caption, "weight": 2},
} for name, station, category, caption, _, _ in CLIPS]

AUDIO_FILES = {media_id(name): file for name, _, _, _, file, _ in CLIPS}


def _radio_atom(name, placement):
    rid = f"{EVENT_ID}.radio.{name}"
    title = name.replace("-", " ").capitalize()
    common = dict(interaction="none", priority="ambient", occurrence={"kind": "repeatable", "cooldownHours": 1},
                  tags=("monthly-radio",))
    if placement == "foreshadow":
        return atom(rid, title, "radioBanter", "radioBanter", None, None, None, stage="foreshadow", **common)
    if placement == "residue":
        # After the month it's a public report: it says nothing about which ending anyone chose.
        return atom(rid, title, "radioBanter", "radioBanter", None, None, None, stage="residue",
                    voice="publicReport", **common)
    if placement == "guest-right":
        return atom(rid, title, "radioBanter", "radioBanter", "guest-right", 7, 14, **common)
    if placement == "the-offer":
        a = atom(rid, title, "radioBanter", "radioBanter", "the-offer", 15, 24, **common)
        a["gate"]["allOf"].append({"kind": "timeBands", "strings": ["night"]})
        return a
    if placement == "stir-up":
        return atom(rid, title, "radioBanter", "radioBanter", "the-offer", 21, 24,
                    dependencies=(needs(f"{EVENT_ID}.scene.stir-up-sunday"),), **common)
    raise ValueError(placement)


RADIO_ATOMS = [_radio_atom(name, placement) for name, _, _, _, _, placement in CLIPS]
