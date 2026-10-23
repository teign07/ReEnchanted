"""The month itself: calendar, phases, pulses, the Academy map, the packet, the Record
and the catch-up ladder. Live day 0 is Sunday 1 November 2026."""

from content_common import EVENT_ID, memory

GUEST = "visitor-the-guest"


def stage(cast, room, note, from_day=None, through_day=None, from_hour=None, until_hour=None, name=None):
    s = {"castID": cast, "roomID": room, "note": note}
    if name:
        s["name"] = name
    for key, value in (("fromDay", from_day), ("throughDay", through_day),
                       ("fromHour", from_hour), ("untilHour", until_hour)):
        if value is not None:
            s[key] = value
    return s


def guest(note, from_day=None, through_day=None, from_hour=None, until_hour=None):
    return stage(GUEST, "location-kitchens", note, from_day, through_day, from_hour, until_hour, name="The Guest")


def room_note(room, note, from_day=None, through_day=None):
    n = {"roomID": room, "note": note}
    if from_day is not None:
        n["fromDay"] = from_day
    if through_day is not None:
        n["throughDay"] = through_day
    return n


def pulse(id, text, tender):
    return {"id": id, "text": text, "tender": tender}


PHASES = [
    {
        "id": "all-souls",
        "title": "All Souls",
        "startsAtProgress": 0.0,
        "role": "setup",
        "intensity": 1,
        "lexicalRules": [],
        "scene": "It's All Souls. Ambrose has baked forty soul cakes and moved the onions away from the "
                 "little west door. I don't know why he did that. I'm keeping one eye on the door.",
        "packetLine": "A small stranger in an old green coat came souling to the Kitchens' west door on All "
                      "Souls' Eve, and Ambrose Trencher fed it without asking its name. Call it the Guest, "
                      "never a name. It never says thank you. Don't explain what it is. Don't claim the Reader "
                      "was there unless a receipt says so.",
        "staging": [
            stage("ambrose-trencher", "location-kitchens", "Ambrose is baking soul cakes. Forty of them, with a cross cut in every one.",
                  through_day=1, from_hour=6, until_hour=22),
            guest("Somebody small in a green coat is asleep on the stool by the fire.", from_day=1),
            stage("lydia-boggle", "location-pantry", "Professor Boggle's going through the Pantry drawers. She's looking for something old.",
                  from_day=2, from_hour=16, until_hour=21),
            stage("dr-vellum", "location-kitchens", "Dr. Vellum's here with a notebook and a thermometer. Ambrose is ignoring both.",
                  from_day=2, through_day=3, from_hour=18, until_hour=21),
            stage("penny-blackletter", "location-kitchens", "Penny's checking The Middlemost Cookery page by page. With a magnifying glass.",
                  from_day=4, from_hour=7, until_hour=9),
            stage("professor-kyle-momort", "location-open-field-gate", "Professor Momort's by the bonfire, watching the edge of the light.",
                  from_day=4, through_day=4, from_hour=18, until_hour=23),
        ],
        "roomNotes": [
            room_note("location-kitchens", "The onion sack's been moved off the little west door. Nobody's put it back.", from_day=1),
            room_note("location-pantry", "Somebody's left a saucer of cream on the bottom shelf. Nobody admits to it.", from_day=2),
            room_note("location-open-field-gate", "Bonfire tonight. Parkin, toffee, and a hammer to break it with.", from_day=4, through_day=4),
        ],
        "pulses": [
            pulse("as-soul-cakes",
                  "There's a tray of soul cakes on the long table with a cross cut in every one. Ambrose says a custom's like a pot: if nobody uses it, it rusts.",
                  "There's a tray of soul cakes on the long table. Ambrose made forty, the way the old Academy did."),
            pulse("as-nutmeg",
                  "The smell of nutmeg has got into the stairwells. Even the Stacks smell faintly of cake.",
                  "The whole Academy smells faintly of nutmeg and warm currants."),
            pulse("as-west-door",
                  "The sack of onions has been moved off the little west door in the Kitchens. It's the first time anybody can remember.",
                  "The little west door in the Kitchens has been opened. It hadn't been opened in a long while."),
            pulse("as-pots",
                  "Every pot in the Kitchens was scrubbed in the night and hung biggest to smallest. Ambrose hasn't moved them back.",
                  "The pots in the Kitchens were clean this morning. Somebody did it in the night."),
            pulse("as-stool",
                  "The low stool by the Kitchen fire has somebody on it all day now, in a green coat with brass buttons.",
                  "Someone small in a green coat sits by the Kitchen fire, out of the draught."),
            pulse("as-thanks",
                  "Nobody's heard the stranger by the fire say thank you. Nobody's heard Ambrose wait for it, either.",
                  "The stranger by the fire eats what Ambrose gives it and says very little."),
            pulse("as-name",
                  "The students have started calling the stranger the Guest, with a capital G, the way you'd say the Headmistress.",
                  "People have started calling the stranger by the fire the Guest."),
            pulse("as-bonfire",
                  "There's a bonfire going up in the courtyard. It's already taller than the stable door, and the first-years keep adding chairs.",
                  "A bonfire's going up in the courtyard for the fifth."),
        ],
    },
    {
        "id": "guest-right",
        "title": "Guest-right",
        "startsAtProgress": 7 / 30,
        "role": "buildup",
        "intensity": 2,
        "lexicalRules": [],
        "scene": "The Guest's eaten at the hearth three nights, so nobody can turn it out. Letters are going "
                 "missing from Ambrose's cookbook. I keep my leaves shut after dark now.",
        "packetLine": "Guest-right holds: the Guest ate at the hearth three nights and can't be harmed or turned "
                      "out. Letters are fading from Ambrose's cookbook, The Middlemost Cookery. Keep the menace "
                      "small and domestic: flat food, scrubbed pots, frost on one window. Never say what the Guest is.",
        "staging": [
            guest("The Guest's on its stool by the fire. Don't thank it."),
            stage("ambrose-trencher", "location-kitchens", "Ambrose is cooking. He's salting everything twice.", from_hour=5, until_hour=23),
            stage("penny-blackletter", "location-kitchens", "Penny's counting the letters in the Cookery before breakfast.", from_hour=7, until_hour=9),
            stage("pippa-pilcrow", "location-great-hall", "Pippa's on a bench, blaming the gravy's punctuation.", from_day=10, through_day=10, from_hour=17, until_hour=20),
            stage("serenity-brown", "location-kitchens", "Serenity can't sleep. She's on the end of the long table, swinging her boots.", from_day=10, from_hour=22, until_hour=4),
            stage("wicker-eddies", "location-kitchens", "Wicker's making an omelette. Stand well back.", from_day=13, from_hour=14, until_hour=17),
            stage("min-seo-kim", "location-kitchens", "Min-seo's sitting on the floor by the Guest's stool. She's asking it things.", from_day=13, from_hour=15, until_hour=18),
            stage("lydia-boggle", "location-kitchens", "Professor Boggle's making soda bread with her sleeves pushed up.", from_day=13, from_hour=13, until_hour=17),
        ],
        "roomNotes": [
            room_note("location-pantry", "The old house rules are pinned inside the Pantry door now. The ink's very brown."),
            room_note("location-great-hall", "Supper hasn't tasted of anything since Martinmas.", from_day=10),
            room_note("location-kitchens", "Hold your fork still when the Guest goes past.", from_day=10),
        ],
        "pulses": [
            pulse("gr-pots",
                  "The pots were scrubbed again in the night. They're always scrubbed. Ambrose has stopped looking surprised and started looking thoughtful.",
                  "The pots were clean again this morning. Ambrose put the kettle on and said nothing about it."),
            pulse("gr-letters",
                  "Another letter's gone from The Middlemost Cookery. Penny checks it at breakfast now, before her tea.",
                  "Penny checks Ambrose's old cookbook every morning now, page by page."),
            pulse("gr-vellum",
                  "Dr. Vellum has written GUEST at the top of a fresh page of notes and underlined it twice. The rest of the page is empty.",
                  "Dr. Vellum has started a page of notes about the Guest. It's mostly blank."),
            pulse("gr-boggle",
                  "Professor Boggle found the old house rules in a Pantry drawer. She's pinned them inside the door and keeps reading them by candlelight.",
                  "The old house rules are pinned up in the Pantry. Professor Boggle reads them sometimes."),
            pulse("gr-watching",
                  "The Guest watches people eat. It watches very closely, like someone trying to remember a tune.",
                  "The Guest sits by the fire and watches the long table."),
            pulse("gr-grateful",
                  "Professor Momort says I'm grateful at every meal now. Half the first-years have caught it off him.",
                  "People at the Academy have started saying I'm grateful instead of the other thing."),
            pulse("gr-spoons",
                  "Somebody's shut every west-facing window in the Kitchens and wedged them with spoons.",
                  "The west windows in the Kitchens are shut and wedged tight."),
            pulse("gr-soup",
                  "The soup tasted thin today. Ambrose added salt, then more salt, then stood looking at it for a long time.",
                  "Ambrose stood over the soup for a long time today."),
            pulse("gr-frost",
                  "There was frost on the inside of the Kitchens' west window this morning. Only that window.",
                  "One of the Kitchen windows had frost on it this morning."),
        ],
    },
    {
        "id": "the-offer",
        "title": "The Offer",
        "startsAtProgress": 15 / 30,
        "role": "climax",
        "intensity": 3,
        "lexicalRules": [],
        "scene": "The whole Academy's cooking, because a recipe only stays alive while somebody's making it. "
                 "The Guest's awake at night now. At night it smells of frost.",
        "packetLine": "The Academy is cooking to keep recipes alive; only recipes being made keep their letters. "
                      "The Guest offered Serenity Brown her sense of taste back in exchange for a memory; only scene "
                      "receipts say what she chose. Never settle who Serenity cares for. Headmistress Thorne avoids "
                      "every room the Guest is in; never explain why.",
        "staging": [
            guest("The Guest's scrubbing a pot that's already clean.", from_hour=22, until_hour=6),
            guest("The Guest's on its stool by the fire. It's watching the dresser.", from_hour=6, until_hour=22),
            stage("ambrose-trencher", "location-kitchens", "Ambrose is teaching three people to make soup at once.", from_hour=6, until_hour=22),
            stage("serenity-brown", "location-kitchens", "Serenity's down at three in the morning again. There's soup on the warm corner of the range for her.",
                  from_hour=2, until_hour=5),
            stage("soren-ng", "location-kitchens", "Soren's at the dresser laying out teaspoons. Each one's got a number.", through_day=20, from_hour=15, until_hour=17),
            stage("headmistress-thorne", "location-headmistress-tower", "The Headmistress is eating in the Tower again."),
            stage("ambrose-trencher", "location-kitchens", "It's Stir-up Sunday. Everybody stirs, east to west. Everybody wishes.",
                  from_day=21, through_day=21, from_hour=9, until_hour=18),
            stage("lydia-boggle", "location-kitchens", "Professor Boggle's in the queue for the pudding, behind six first-years.",
                  from_day=21, through_day=21, from_hour=10, until_hour=12),
        ],
        "roomNotes": [
            room_note("location-kitchens", "Penny's count is on the door: letters missing, letters restored."),
            room_note("location-headmistress-tower", "Trays go up. They come down full."),
            room_note("location-kitchens", "Stir from east to west. Don't say your wish out loud.", from_day=21, through_day=21),
        ],
        "borrowedRooms": [
            {
                "id": "borrowed-cold-kitchen",
                "name": "The Cold Kitchen",
                "note": "A kitchen with no fire in it, through the little west door, only after dark. Somebody's set a very long table. Don't go in.",
                "x": 0.16, "y": 0.645, "width": 0.11, "height": 0.05, "form": "room",
                "joins": [{"roomID": "location-kitchens", "kind": "door"}],
                "fromDay": 16, "throughDay": 24,
            }
        ],
        "pulses": [
            pulse("of-cooking",
                  "Every oven in the Academy's on. Somebody's always making something now, because a recipe only keeps its letters while it's being made.",
                  "Somebody's always cooking at the Academy now. The Kitchens never go cold."),
            pulse("of-count",
                  "Penny's count is pinned to the Kitchen door: letters missing, letters restored. The second number keeps going up.",
                  "There's a count on the Kitchen door. The good number's going up."),
            pulse("of-spoons",
                  "There are teaspoons on the dresser with tiny folded numbers beside them. Nobody touches them except Serenity.",
                  "There are teaspoons laid out on the dresser, one to nine."),
            pulse("of-omelettes",
                  "Wicker's made four omelettes this week. The fourth one was nearly an omelette.",
                  "Wicker's been learning to cook. He's getting better."),
            pulse("of-3am",
                  "The Kitchen lamp's on at three in the morning now. Ambrose leaves soup on the warm corner of the range for whoever comes down.",
                  "There's always a lamp on in the Kitchens at night now, and something warm left out."),
            pulse("of-iron",
                  "At night the Kitchens smell of frost and old iron. By morning they smell of bread again.",
                  "The Kitchens smell of bread in the mornings."),
            pulse("of-thorne",
                  "The Headmistress hasn't eaten in the Great Hall all month. Her tray goes up to the Tower and comes back down full.",
                  "The Headmistress is taking her meals in the Tower."),
            pulse("of-pudding",
                  "Ambrose brought the big brown pudding bowl up from the cellar and scrubbed it himself, before anybody else could.",
                  "The big pudding bowl's up from the cellar for Stir-up Sunday."),
            pulse("of-apples",
                  "Min-seo sits with the Guest in the afternoons now. They don't talk much. She brings it apples, and it eats the cores.",
                  "Min-seo sits with the Guest in the afternoons and brings it apples."),
        ],
    },
    {
        "id": "the-bowl",
        "title": "The Bowl",
        "startsAtProgress": 25 / 30,
        "role": "aftermath",
        "intensity": 2,
        "lexicalRules": [],
        "scene": "Ambrose has the page he's looked for for thirty years. It's for a bowl. There's a chair at the "
                 "long table for whoever's missing.",
        "packetLine": "Ambrose has the page: a plain bowl of oats cooked in milk, with salt, honey, butter and cold "
                      "cream. A chair is set at the long table for whoever's missing. The ending depends on the "
                      "Reader's own scenes; use only receipts and never assume one.",
        "staging": [
            guest("The Guest's eating at the long table, the ordinary way.", through_day=28),
            stage("ambrose-trencher", "location-kitchens", "Supper's at the long table tonight. One chair's for whoever's missing.",
                  from_day=25, through_day=25, from_hour=17, until_hour=23),
            stage("penny-blackletter", "location-kitchens", "Penny made the cranberry sauce. It's set too hard. It's perfect.",
                  from_day=25, through_day=25, from_hour=17, until_hour=22),
            stage("ambrose-trencher", "location-kitchens", "Ambrose has sent everybody out. He's cooking something small.",
                  from_day=29, from_hour=6, until_hour=13),
            stage("serenity-brown", "location-kitchens", "Serenity's on the end of the long table. She won't say why she's here.",
                  from_day=29, from_hour=7, until_hour=13),
        ],
        "roomNotes": [
            room_note("location-kitchens", "A chair at the top of the long table is set for whoever's missing.", from_day=25),
            room_note("location-pantry", "There's a jug of cream in the cold larder with a cloth over it and a note: NOT FOR TEA.", from_day=27),
        ],
        "pulses": [
            pulse("tb-chair",
                  "There's a chair at the top of the long table that nobody sits in. It's got a plate, a candle and a napkin folded into a little hat.",
                  "There's a place set at the long table for whoever's missing."),
            pulse("tb-page",
                  "Ambrose reads the same page of The Middlemost Cookery every night now, the one from under the endpaper. He doesn't need to. He reads it anyway.",
                  "Ambrose reads one old page every night before bed."),
            pulse("tb-oats",
                  "Somebody's bought a great deal of oats. Nobody will say why.",
                  "There's a new sack of oats in the Pantry."),
            pulse("tb-tasting",
                  "The Guest's stopped leaning over plates. It eats the ordinary way now, and it seems to taste it.",
                  "The Guest eats at the long table now, like everybody else."),
            pulse("tb-onions",
                  "The onion sack's back by the west door, but it's not against it. Ambrose says he'll want the door again.",
                  "The onion sack is back beside the little west door."),
            pulse("tb-cream",
                  "There's a jug of cream in the cold larder with a cloth over it and a note: NOT FOR TEA.",
                  "Ambrose is saving a jug of cream for something."),
        ],
    },
]

PACKET = {
    "logline": "A stranger came souling to the Kitchens' west door on All Souls, and Ambrose fed it. Now the "
               "taste is going out of the Academy's food.",
    "atmosphere": "Warm kitchens, short days, frost on one window, and a guest nobody can turn out.",
    "storyInstruction": "Use only committed authored scenes and truthful reports. A phase's date isn't proof the "
                        "Reader attended or chose anything. The Guest is never named, never explained, and never "
                        "says thank you. Never settle who Serenity Brown cares for.",
    "classInstruction": "Classes this month can touch cooking, kitchens, bread and who gets fed. Leave the Guest out "
                        "unless the class beat names it.",
    "letterInstruction": "Letters this month can smell of the Kitchens. Never invent what the Guest is.",
    "monthlyEditionLine": "A guest came to the Kitchens on All Souls and stayed the month. On the last day Ambrose "
                          "Trencher set the bowl down.",
    "bleedInstruction": "Penny reports the Guest as an attested fact and its effects as measurements: letters "
                        "missing, letters restored, suppers gone flat. She never guesses what it is.",
    "radioInstruction": "The stations are playing warm things this month: kitchens, frost, the long walk home.",
    "widgetWhisperLine": "Somebody's eating the taste out of things. Cook something.",
    "bookOfYouInstruction": "If the Reader cooked or ate something today, that's this month's thread. Never invent a "
                            "meal they didn't keep.",
    "fieldworkPrompt": "If you cooked or ate something worth keeping today, give me a sentence about it.",
    "fieldworkPlaceholder": "Tonight the kitchen smelled of…",
    "fieldworkRewardLine": "Kept. Ambrose says that one counts.",
}


def entry(id, title, account, on_day, known_from_day=None, memories=()):
    e = {"id": f"the-guest.record.{id}", "title": title, "account": account, "onDay": on_day}
    if known_from_day is not None:
        e["knownFromDay"] = known_from_day
    if memories:
        e["castMemories"] = list(memories)
    return e


RECORD = {
    "outcomeTitle": "The Bowl Set Down",
    "historySentence": "A guest came souling to the Kitchens on All Souls and stayed the month; on the last day "
                       "Ambrose Trencher set the bowl down.",
    "entries": [
        entry("soul-cakes", "Soul cakes",
              "On the first of November Ambrose Trencher baked forty soul cakes for All Souls, as the old Academy "
              "did, and moved the sack of onions off the little west door.",
              0, 0,
              [memory("ambrose-trencher", "the-guest.soul-cakes.forty",
                      "Ambrose baked forty soul cakes for All Souls and moved the onions off the west door without knowing why.",
                      aside="Forty soul cakes. And I moved the onions. Don't ask me why. My hands knew before I did.")]),
        entry("the-knock", "The knock",
              "That night the Guest knocked three times at the west door, saying the old souling rhyme. Ambrose "
              "Trencher gave them a soul cake and a seat by the fire, and didn't ask their name.",
              0, 1,
              [memory("ambrose-trencher", "the-guest.knock.fed",
                      "Ambrose fed a stranger at the west door on All Souls' Eve and didn't ask their name.",
                      aside="Fed them first. You always feed them first. The questions keep.",
                      gossip="{teller} says somebody came in at the west door on All Souls and Ambrose let them sit by the fire.")]),
        entry("the-pots", "The pots",
              "In the morning every pot in the Kitchens had been scrubbed and hung biggest to smallest. Ambrose "
              "Trencher left them that way.",
              1, 1,
              [memory("ambrose-trencher", "the-guest.knock.pots",
                      "In the morning every pot in the Kitchens had been scrubbed and hung biggest to smallest.",
                      aside="Somebody hung my pots wrong. Beautifully wrong. I haven't moved them.")]),
        entry("guest-right", "Three nights",
              "On the third evening Dr. Vellum asked to examine the stranger, now called the Guest. Ambrose "
              "refused. Professor Lydia Boggle confirmed the oldest house rule: three nights at the hearth make a "
              "guest, and nobody may harm a guest or turn one out.",
              2, 3,
              [memory("dr-vellum", "the-guest.three-nights.thermometer",
                      "Dr. Vellum asked to examine the Guest and Ambrose said no: three nights at the hearth makes a guest.",
                      aside="Three nights of porridge and not one measurement. I've written that down instead."),
               memory("lydia-boggle", "the-guest.three-nights.house-rule",
                      "Professor Boggle told the Kitchens the oldest house rule: three nights at the hearth, and nobody may turn a guest out.",
                      aside="I keep the rooms. I know the rules the rooms keep. I'd rather I didn't, this month.",
                      gossip="{teller} says the Guest can't be turned out now. Three nights at the hearth. Professor Boggle looked it up.")]),
        entry("treacle", "The T in treacle",
              "On Bonfire Night Penny Blackletter found the first letter missing from The Middlemost Cookery, "
              "Ambrose's estate-sale cookbook: the T in treacle, on the page for parkin. It had been there on "
              "Sunday.",
              4, 5,
              [memory("penny-blackletter", "the-guest.parkin.letter",
                      "Penny found the first letter missing from The Middlemost Cookery: the T in treacle, gone between Sunday and Bonfire Night.",
                      aside="The T's gone from treacle. I've checked my eyes. My eyes are fine.")]),
        entry("momort", "Never the other thing",
              "At the bonfire Professor Kyle Momort told students never to thank the Guest. To say I'm grateful, "
              "if they must say something, and never the other thing.",
              4, 5,
              [memory("professor-kyle-momort", "the-guest.bonfire.warning",
                      "At the bonfire Professor Momort warned students never to thank the Guest, only to say they were grateful.",
                      aside="The other thing is a door. I've said so. I'll say it again at breakfast.",
                      gossip="{teller} says you're not allowed to thank the Guest. Momort said so, plainly, which he never does.")]),
        entry("flat", "Martinmas",
              "At the Martinmas supper the food in the Great Hall tasted of nothing. Serenity Brown laughed, and "
              "told the Hall she hadn't tasted anything since October. Ambrose Trencher halved the loaves for "
              "Martinmas and gave the extra half to the Guest.",
              10, 11,
              [memory("serenity-brown", "the-guest.flat.paper",
                      "At the Martinmas supper Serenity told the whole Hall she hasn't tasted anything since the Count.",
                      aside="Everybody knows now. It's oddly nice. Six weeks of paper and now we're all eating it.",
                      gossip="{teller} says Serenity can't taste anything. Hasn't since October. She laughed and told everyone."),
               memory("ambrose-trencher", "the-guest.flat.halved",
                      "On Martinmas Ambrose halved the loaves, as Saint Martin halved his cloak, and gave the Guest an extra half.",
                      aside="Halved the bread. Gave it the extra half. You don't skip a guest because the soup's gone wrong.")]),
        entry("the-count", "Two hundred and fourteen",
              "Penny Blackletter counted two hundred and fourteen letters missing from The Middlemost Cookery and "
              "found that only the recipes somebody was still making had kept theirs. Ambrose Trencher said, "
              "\"Then we cook.\"",
              13, 14,
              [memory("penny-blackletter", "the-guest.rescue.count",
                      "Penny counted two hundred and fourteen missing letters and found only the recipes being made stayed whole.",
                      aside="Two hundred and fourteen. And a pattern. I'd rather have the pattern than the sleep."),
               memory("ambrose-trencher", "the-guest.rescue.cook",
                      "When Penny showed Ambrose that only the recipes being made stayed whole, he tied his apron tighter and said they'd cook.",
                      gossip="{teller} says everybody's cooking now. Even the second-years. Especially the second-years. Stand back.")]),
        entry("cooking", "The Kitchens full",
              "That afternoon the Kitchens filled. Wicker Eddies made his first omelette. Soren Ng laid out nine "
              "teaspoons of tastes on the dresser. Min-seo Kim asked the Guest what it needed, and it said, "
              "\"Something I used to have.\"",
              13, 14,
              [memory("wicker-eddies", "the-guest.rescue.omelette",
                      "Wicker made his first omelette and carried it the whole length of the long table to Serenity.",
                      aside="Brown on one side. Runny on the other. She ate all of it. She can't even taste it.",
                      gossip="{teller} says Wicker cooked. Actually cooked. An omelette. With eggshell in it."),
               memory("soren-ng", "the-guest.rescue.spoons",
                      "Soren laid out nine teaspoons of tastes on the dresser for Serenity, with numbered slips.",
                      aside="Nine spoons. She kept the first slip. That's all I know so far. That's plenty."),
               memory("min-seo-kim", "the-guest.rescue.asked",
                      "Min-seo was the only one who asked the Guest what it needed, and it said something it used to have.",
                      aside="Nobody'd asked it anything in two weeks. Two weeks! I'd have bitten someone.")]),
        entry("the-offer", "Three in the morning",
              "In the small hours the Guest made Serenity Brown an offer: the taste of things, for one evening's "
              "memory. What she answered is hers to tell.",
              18, 21,
              [memory("serenity-brown", "the-guest.offer.made",
                      "At three in the morning the Guest offered Serenity the taste of things back, for one evening's memory.")]),
        entry("stir-up", "Stir-up Sunday",
              "On Stir-up Sunday the whole Academy stirred the pudding and wished. The Guest stirred too, and "
              "said its wish out loud: home. The Headmistress stood in the doorway and didn't come in.",
              21, 22,
              [memory("headmistress-thorne", "the-guest.stir.doorway",
                      "On Stir-up Sunday the Headmistress stood in the Kitchens' doorway, watched the Guest stir, and went back upstairs.",
                      gossip="{teller} says the Headmistress came down on Stir-up Sunday, stood in the door, and went away again.")]),
        entry("the-page", "Under the endpaper",
              "That night the page under the endpaper of The Middlemost Cookery came clear for the first time in "
              "thirty years. It was titled A Bowl for the One Who Keeps the Pots. Ambrose Trencher read it three "
              "times.",
              21, 22,
              [memory("ambrose-trencher", "the-guest.stir.the-page",
                      "On Stir-up Sunday the page under the endpaper came back: A Bowl for the One Who Keeps the Pots.",
                      aside="Thirty years. It was at the back the whole time. Waiting for somebody to cook enough.")]),
        entry("the-table", "A place at the table",
              "Supper was at the long table in the Kitchens. Ambrose Trencher set one place for whoever was "
              "missing, and nobody sat in it. Penny Blackletter said she'd set it for her grandmother.",
              25, 26,
              [memory("penny-blackletter", "the-guest.table.grandmother",
                      "At the long table Penny said she'd set the empty chair for her grandmother, who taught her to check twice."),
               memory("ambrose-trencher", "the-guest.table.chair",
                      "Ambrose set a place at the long table for whoever's missing, and nobody sat in it.",
                      gossip="{teller} says Ambrose set a place at the long table for nobody, and nobody asked why. Everybody knew.")]),
        entry("the-bowl", "The bowl",
              "On the last day of November Ambrose Trencher cooked the bowl from the page: oats in milk, salt, "
              "honey, butter, cold cream round the edge. He set it on the hearth and didn't say who it was for.",
              29, 29,
              [memory("ambrose-trencher", "the-guest.bowl.cooked",
                      "On the last day of November Ambrose cooked the bowl from the page and set it on the hearth without saying who it was for.",
                      aside="Oats. Thirty years and it was oats. I'd have laughed if I wasn't busy.")]),
        entry("the-thorn", "Unattributed",
              "By the end of the last night there was a white bowl on the west step, very fine, with a single "
              "black thorn laid beside it. Penny Blackletter filed it under Unattributed.",
              29, 29,
              [memory("penny-blackletter", "the-guest.bowl.thorn",
                      "Penny filed a white bowl and a black thorn found on the west step under Unattributed.",
                      aside="Unattributed. I've never used that drawer before. I don't like how easily it opened.")]),
    ],
}


def rung(n, from_day, title, body, question, tells):
    return {"id": f"the-guest.catchup.{n}", "fromDay": from_day, "title": title, "body": body,
            "openQuestion": question, "tells": [f"the-guest.record.{t}" for t in tells]}


CATCH_UP = [
    rung(0, 0, "Everybody Still Has to Eat",
         "October was the month a Count got out of his book. He's back in it now. Serenity Brown came out of it "
         "hearing pages turn in the walls, and she's got a word for that: Nightbound. The East Stacks are open "
         "again. The Academy's tired.\n\nSo November starts in the Kitchens, where it's warm. It's All Souls. "
         "Ambrose Trencher has baked forty soul cakes, the way the old Academy did, with a cross cut in every "
         "one. And he's moved the sack of onions off the little west door. Nobody uses that door. Nobody's "
         "used it in a hundred years.\n\nI've asked him why he moved them. He says his hands knew before he did.",
         "Who's going to come to the west door?",
         ["soul-cakes"]),
    rung(1, 3, "The Guest",
         "On All Souls' Eve somebody knocked at the Kitchens' west door, three times, saying the old souling "
         "rhyme. Ambrose gave them a soul cake and a seat by the fire, and didn't ask their name. They're small. "
         "They wear a green coat that's far too big for them. They've been here ever since.\n\nThe students call "
         "them the Guest. Every morning every pot in the Kitchens is scrubbed, and nobody did it. The Guest eats "
         "everything it's given and never says thank you. Dr. Vellum wanted to examine it. Professor Boggle "
         "says the oldest house rule won't allow it: three nights at the hearth, and nobody can turn a guest "
         "out.\n\nI can't smell it. Everybody smells of something.",
         "What does the Guest want?",
         ["soul-cakes", "the-knock", "the-pots", "guest-right"]),
    rung(2, 5, "The T in Treacle",
         "A stranger the students call the Guest came to the Kitchens on All Souls, and Ambrose let it stay. It "
         "eats everything and never says thank you, and by the oldest house rule nobody can turn it out.\n\nOn "
         "Bonfire Night Penny found a letter missing from Ambrose's old cookbook, The Middlemost Cookery. The T "
         "had gone from treacle, on the page for parkin. It was there on Sunday. Penny checks the book every "
         "morning now.\n\nAt the bonfire, Professor Momort told everybody never to thank the Guest. Say I'm "
         "grateful, he said, if you have to say something. Never the other thing.",
         "Where are the letters going?",
         ["the-knock", "guest-right", "treacle", "momort"]),
    rung(3, 11, "Martinmas Goes Flat",
         "Since All Souls a stranger called the Guest has been living in the Kitchens. Nobody can turn it out, "
         "and nobody's allowed to thank it. Letters keep vanishing from Ambrose's cookbook.\n\nThen, at the "
         "Martinmas supper, nobody could taste their food. Goose, potatoes, gravy: all of it tasted of nothing. "
         "Serenity Brown laughed out loud, and told the whole Hall she hasn't tasted anything since October. "
         "\"Now you know,\" she said.\n\nAmbrose halved the loaves for Martinmas, the way Saint Martin halved "
         "his cloak for a beggar. He gave the Guest the extra half.",
         "Can anybody get the taste back?",
         ["the-knock", "guest-right", "treacle", "flat"]),
    rung(4, 14, "Then We Cook",
         "A stranger called the Guest has lived in the Kitchens since All Souls. Since it came, the Academy's "
         "food has gone flat, and letters keep going missing from Ambrose's cookbook.\n\nPenny counted them: "
         "two hundred and fourteen. Then she found the pattern. The only recipes keeping their letters are the "
         "ones somebody's still making. A recipe only stays alive while somebody's cooking it.\n\nSo Ambrose "
         "said, \"Then we cook.\" And now everybody does. Wicker made his first omelette. Soren laid out nine "
         "teaspoons of tastes. Min-seo asked the Guest what it needed. It said something it used to have.\n\n"
         "Ambrose says your kitchen counts too.",
         "What will you make?",
         ["the-knock", "flat", "the-count", "cooking"]),
    rung(5, 22, "A Wish Said Out Loud",
         "The Guest came to the Kitchens on All Souls. Since then the food's gone flat and letters have "
         "vanished from Ambrose's cookbook, and the whole Academy's been cooking to keep the recipes alive.\n\n"
         "One night at three in the morning, the Guest made Serenity an offer: the taste of things, for one "
         "evening's memory. What she answered is hers to tell.\n\nOn Stir-up Sunday everybody stirred the "
         "pudding and wished. The Guest stirred too, and said its wish out loud. You must never do that. It "
         "said: home. The Headmistress watched from the doorway and didn't come in.\n\nThat night a page came "
         "back in Ambrose's cookbook, from under the endpaper, after thirty years.",
         "What's on the page?",
         ["the-count", "the-offer", "stir-up", "the-page"]),
    rung(6, 26, "A Place for Whoever's Missing",
         "A stranger called the Guest came to the Kitchens on All Souls and has stayed all month. The Academy's "
         "been cooking to keep its recipes alive. On Stir-up Sunday the Guest said its wish out loud: home.\n\n"
         "The page Ambrose has looked for for thirty years came back that night. It's called A Bowl for the One "
         "Who Keeps the Pots.\n\nSupper's been at the long table in the Kitchens. Ambrose set one place for "
         "whoever's missing, and nobody sat in it, and nobody asked. The Guest ate with everybody else, the "
         "ordinary way. It looked like it belonged somewhere.",
         "Who's the bowl for?",
         ["stir-up", "the-page", "the-table"]),
    rung(7, 30, "The Bowl Set Down",
         "On All Souls a stranger came souling to the Kitchens' west door, and Ambrose Trencher fed it. The "
         "Academy called it the Guest. While it stayed, the food went flat and Ambrose's old cookbook lost its "
         "letters, until everybody started cooking to keep the recipes alive.\n\nOn the last day of November "
         "Ambrose cooked the page he'd waited thirty years for. It was oats, in milk, with honey and butter and "
         "cold cream round the edge. He set the bowl on the hearth and didn't say who it was for. Everybody "
         "knew.\n\nIn the morning there was a white bowl on the west step, and a black thorn beside it.",
         "What did the Guest do?",
         ["the-page", "the-table", "the-bowl", "the-thorn"]),
]

FORESHADOW = {
    "staging": [
        stage("ambrose-trencher", "location-kitchens", "Ambrose is testing soul cakes. He's eaten nine.", from_hour=14, until_hour=20),
    ],
    "roomNotes": [
        room_note("location-kitchens", "There's a sack of onions against the little west door. There always has been."),
        room_note("location-pantry", "Somebody's dusted an old brown bowl and put it back at the very back of the dresser."),
    ],
}

RESIDUE = {
    "staging": [
        stage("ambrose-trencher", "location-kitchens", "Ambrose is making bread like nothing happened. Ask him. He'll say nothing happened.",
              from_hour=5, until_hour=21),
        stage("penny-blackletter", "location-kitchens", "Penny's checking the Cookery. Every letter's where it should be. She checks again.",
              from_hour=7, until_hour=8),
    ],
    "roomNotes": [
        room_note("location-kitchens", "The west door's shut. The pots are hung biggest to smallest. Nobody's moved them."),
    ],
}

EVENT = {
    "id": EVENT_ID,
    "title": "The Guest Who Came on All Souls",
    "subtitle": "Somebody's eating the taste out of things.",
    "calendar": {
        "startMonth": 11, "startDay": 1, "durationDays": 30, "recurrence": "oneShot", "startYear": 2026,
        "foreshadowDays": 4, "residueDays": 7,
    },
    "phases": PHASES,
    "triggers": [],
    "outcomes": [],
    "effects": [
        {"id": "the-guest.effect.trencher", "target": "entity", "targetID": "ambrose-trencher", "tags": [],
         "boost": 6, "reason": "November is Ambrose's month."},
    ],
    "packet": PACKET,
    "foreshadowAcademy": FORESHADOW,
    "residueAcademy": RESIDUE,
    "record": RECORD,
    "catchUp": CATCH_UP,
}

from content_pages import BEATS  # noqa: E402
