"""The Bleed for November: Penny's articles, and the desk pieces the paper sets itself
(classifieds placed by the Cast, and the Cast's letters to the editor)."""

from content_common import EVENT_ID, PACK_ID, atom


def article(id, title, body, phase, start, end, tags=()):
    a = {"id": f"the-guest.bleed.{id}", "packID": PACK_ID, "eventID": EVENT_ID, "title": title,
         "byline": "Penny Blackletter", "body": body, "editionKinds": ["morning", "evening"],
         "tags": [EVENT_ID] + list(tags)}
    return a, atom(a["id"], title, "bleedArticle", "bleedArticle", phase, start, end,
                   voice="publicReport", tags=("monthly-bleed",) + tuple(tags))


_ARTICLES = [
    article("west-door", "A Guest at the West Door",
            """The Kitchens' west door was opened on All Souls' Eve for the first time in living memory. A visitor knocked three times and recited the souling rhyme. Ambrose Trencher gave the visitor a soul cake and a seat by the fire, and did not ask a name.

The visitor is small, wears a green coat with brass buttons, and has remained by the fire since. Students have taken to calling the visitor the Guest. The Bleed will do the same until better information is available.

Every pot in the Kitchens has been found scrubbed each morning since. Mr Trencher has declined to say who scrubbed them. On the evidence, he does not know.

Asked whether he would ask the Guest's name, Mr Trencher said, “When it's eaten.” The Guest has eaten a great deal.""",
            "all-souls", 1, 6),
    article("missing-letters", "Letters Missing from The Middlemost Cookery",
            """On Bonfire Night this correspondent found a letter missing from Ambrose Trencher's copy of *The Middlemost Cookery*. The T had gone from treacle on the page for parkin. The page was whole on Sunday. The Bleed checked.

The gap is clean. The paper is undamaged. There is no smudge, no tear, and no ink on anyone's fingers.

Professor Lydia Boggle has confirmed that, under the house rules, a visitor who has eaten at the hearth for three nights may not be turned out. The Guest has eaten at the hearth for considerably more than three.

Professor Momort has asked students not to thank the Guest for anything. Asked why, he said, “Old kitchen manners.” Asked what that meant, he left.""",
            "all-souls", 5, 9),
    article("recap-week-one", "The First Week, Attested",
            """For those catching up: on All Souls' Eve a small visitor in a green coat came to the Kitchens' west door and was fed. Nobody knows its name. The Academy calls it the Guest.

Since then, the Kitchens' pots have been scrubbed each night by nobody. By the oldest house rule the Guest may not be turned out. On Bonfire Night a letter went missing from Ambrose Trencher's cookbook, *The Middlemost Cookery*. More have gone since.

The Bleed is keeping count. Readers are asked not to thank the Guest, on the advice of Professor Momort.""",
            "guest-right", 10, 12, ("weekly-recap",)),
    article("flat", "Martinmas Supper Tastes of Nothing",
            """Wednesday's Martinmas supper in the Great Hall tasted of nothing. This is not an opinion. The Bleed interviewed eleven diners at four tables. All eleven described the goose as the shape of goose.

Pippa Pilcrow attributed the fault to the gravy's punctuation. Serenity Brown told the Hall she has tasted nothing since October, and that everybody now knew what that was like.

Several diners report that the Guest went round the Hall filling water glasses before the food went flat. The Bleed records this. It draws no conclusion from it.

Mr Trencher halved the loaves for Martinmas, as is the custom, and left the second halves by the Kitchen door. By morning the basket was empty and the cloth was folded.""",
            "guest-right", 11, 14),
    article("recap-week-two", "Two Hundred and Fourteen",
            """For those catching up: a visitor called the Guest came to the Kitchens on All Souls and cannot be turned out under the house rules. Since then the Academy's food has gone flat and letters have vanished from *The Middlemost Cookery*.

This correspondent counted them: two hundred and fourteen. The only recipes keeping their letters were the ones somebody was still cooking.

The Academy is now cooking a great deal. Wicker Eddies has made an omelette. Letters are coming back. The count is on the Kitchen door: missing, and restored.""",
            "the-offer", 17, 20, ("weekly-recap",)),
    article("a-wish-said-aloud", "A Wish Said Aloud",
            """The Academy stirred the Christmas pudding on Stir-up Sunday, east to west, as is the custom. Every resident took a turn. Most made a wish and kept it.

The Guest took a turn as well, and said its wish aloud. It said: home. The Bleed is aware that wishes said aloud are not supposed to come true. It reports the wish anyway, because it was said in front of fifty witnesses.

The Headmistress was seen in the Kitchens' doorway during the stirring. She did not come in. This is the first time she has been seen on the Kitchen stairs this month. The Bleed does not know why, and will not guess.

That night a page came clear in *The Middlemost Cookery*, under the endpaper, after thirty years.""",
            "the-offer", 22, 24),
    article("recap-week-three", "The Week of the Page",
            """For those catching up: the Guest has lived in the Kitchens since All Souls. The Academy's food went flat and letters vanished from *The Middlemost Cookery*, until the whole Academy began cooking to bring them back.

On Stir-up Sunday the Guest said its wish aloud: home. That night a page under the cookbook's endpaper came clear for the first time in thirty years. It is titled *A Bowl for the One Who Keeps the Pots.*

Mr Trencher has read it a great many times. He has bought oats.""",
            "the-offer", 24, 25, ("weekly-recap",)),
    article("recap-week-four", "The Bowl, and After",
            """For those catching up: a visitor came to the Kitchens' west door on All Souls and stayed the month. The Academy called it the Guest. While it stayed, food went flat and *The Middlemost Cookery* lost its letters, until the Academy cooked them back.

On the last day of November Ambrose Trencher cooked the page he had waited thirty years to cook: oats in milk, with salt, honey, butter and cold cream round the edge. He set it on the hearth. He did not say who it was for.

By morning there was a white bowl on the west step, with a black thorn beside it. This correspondent has filed it under Unattributed.""",
            "the-bowl", 29, 29, ("weekly-recap",)),
]

BLEED_ARTICLES = [a for a, _ in _ARTICLES]
BLEED_ATOMS = [m for _, m in _ARTICLES]


# MARK: Desk pieces. The paper sets these itself; they need no manifest atom.

def classified(id, ad, reply, from_day=0):
    return {"id": f"the-guest.classified.{id}", "packID": PACK_ID, "eventID": EVENT_ID, "title": "Classified",
            "byline": "", "body": ad, "reply": reply, "editionKinds": ["morning", "evening"],
            "tags": [EVENT_ID, "classified", f"from-day:{from_day}"]}


def letter(id, slug, cue, signature, text, from_day=0):
    return {"id": f"the-guest.letter.{id}", "packID": PACK_ID, "eventID": EVENT_ID, "title": "Letter",
            "byline": signature, "body": text, "editionKinds": ["morning", "evening"],
            "tags": [EVENT_ID, "cast-letter", f"cast:{slug}", f"cue:{cue}", f"from-day:{from_day}"]}


CLASSIFIEDS = [
    classified("soup", "OFFERED: Soup, hot, on the warm corner of the range, after midnight. For whoever comes down. No questions. A. T.",
               "REPLY TO THE SOUP NOTICE: The bowl was empty by morning. Washed. Dried. Put back on the shelf, the right way up.", 1),
    classified("thermometer", "FOR SALE: One thermometer, barely used, refused at the door. Dr. Vellum, the Still Room.",
               "REPLY TO THE THERMOMETER: No buyers. Ambrose has offered to use it for the jam. Dr. Vellum is treating this as both an insult and a compliment.", 3),
    classified("treacle", "WANTED: The T from treacle. Last seen on the parkin page. Small, black, answers to tuh. Reward: parkin. P. Blackletter.",
               "REPLY TO THE TREACLE NOTICE: A second-year has offered the T from his own name. Ms Blackletter has declined. It is the wrong T.", 5),
    classified("stove", "NOTICE: Please stop thanking the stove. The stove is fine. It's the other thing you shouldn't thank. A. Trencher.",
               "REPLY TO THE STOVE NOTICE: A first-year asks whether he may say he's grateful to the stove. Permission granted.", 5),
    classified("hammer", "FOR EXCHANGE: A Bonfire Night toffee hammer, slightly sticky, for anything at all that isn't sticky. W. E.",
               "REPLY TO THE HAMMER NOTICE: Exchanged for a bag of toffee. W. E. is aware of the irony and would like it left alone.", 5),
    classified("windows", "NOTICE: The west windows in the Kitchens are to stay shut. Spoons are holding them. Do not borrow the spoons. Prof. L. Boggle.",
               "REPLY TO THE WINDOWS NOTICE: The spoons have been returned. The windows are shut. There was frost on the inside anyway.", 7),
    classified("goose", "LOST: The taste of goose. Last seen at the Martinmas supper. If found, please return to the Great Hall, any table.",
               "REPLY TO THE GOOSE NOTICE: Nothing found yet. The goose sends its regrets.", 11),
    classified("button", "FOUND: A brass button, green thread still in it, on the west step. The owner may apply to the Kitchens. The owner probably knows.",
               "REPLY TO THE BUTTON NOTICE: Nobody applied. The button's been sewn back on. Nobody saw who did it.", 8),
    classified("pinch", "WANTED: Somebody who knows how much a pinch is. P. Pilcrow, deeply concerned.",
               "REPLY TO THE PINCH NOTICE: Professor Boggle says it's what fits between finger and thumb. Pippa has asked whose finger. The matter is unresolved.", 13),
    classified("onion", "WANTED: One onion that doesn't make anyone cry. Will trade a spoon that doesn't burn. W. Eddies.",
               "REPLY TO THE ONION NOTICE: No such onion exists. Professor Boggle recommends a cold onion, a sharp knife, and accepting the rest.", 13),
    classified("recipes", "WANTED: Recipes that aren't written down anywhere. Especially your nan's. Apply to the Kitchen door. A. Trencher.",
               "REPLY TO THE RECIPES NOTICE: Fourteen have come in. One is just the word ENOUGH, written very large. Ambrose says it's the best of the lot.", 14),
    classified("spoons", "LOST: Nine teaspoons. No, wait. Found. Please leave them exactly where they are. Thank you. I mean: I'm grateful.",
               "REPLY TO THE TEASPOONS NOTICE: The teaspoons remain on the dresser. Someone has added a tenth. Nobody's owned up.", 15),
]

CAST_LETTERS = [
    letter("trencher-quiet", "ambrose-trencher", "quiet", "A. Trencher, the Kitchens",
           "Read your front page over the porridge pan. {possessive} {weekday} sounds like it wanted feeding. Did anybody feed it? Somebody should've."),
    letter("trencher-photo", "ambrose-trencher", "photo", "A. Trencher, the Kitchens",
           "That photograph. Was anybody eating? You can always tell a good day by whether there's a plate in it somewhere."),
    letter("trencher-word", "ambrose-trencher", "word", "A. Trencher, the Kitchens",
           "“{word}”. I'd put that in a soup. I'd put most things in a soup, but I'd put that in first."),
    letter("vellum-quoted", "dr-vellum", "quoted", "Dr. Vellum, the Still Room",
           "I've filed {possessive} quotation under evidence. Was it written before supper or after? It matters more than people think. I'd like to know."),
    letter("vellum-sky", "dr-vellum", "sky", "Dr. Vellum, the Still Room",
           "{Sky} lowers the appetite by a measurable amount. I've measured it. Ambrose says I'm wrong. He's put the soup on anyway."),
    letter("boggle-word", "lydia-boggle", "word", "Prof. L. Boggle, the Pantry",
           "“{word}” is a plain, useful sort of word. Those are the ones that do the work. I've pinned it up inside the Pantry door."),
    letter("boggle-handmade", "lydia-boggle", "handmade", "Prof. L. Boggle, the Pantry",
           "A page made by hand, in a month like this one? Somebody in your house knows what hands are for. Tell them to scrub the pots too."),
    letter("minseo-quiet", "min-seo-kim", "quiet", "Min-seo K., the Walled Garden",
           "Did anybody ask {subject} what they needed on {weekday}? I'm asking. You don't have to answer. It's just nice to be asked."),
    letter("minseo-photo", "min-seo-kim", "photo", "Min-seo K., the Walled Garden",
           "I looked at the photograph for ages. Who isn't in it? There's always somebody who isn't in it. I hope they got fed."),
    letter("wicker-dispatch", "wicker-eddies", "dispatch", "W. Eddies, the Gate",
           "You did the dare. I made an omelette. We've both had a week. Mine had eggshell in it. Yours probably didn't. Show-off.", 13),
    letter("wicker-quiet", "wicker-eddies", "quiet", "W. Eddies, the Gate",
           "I read your front page while burning toast. Both went fine. I mean the front page went fine. The toast's in the bin."),
    letter("serenity-word", "serenity-brown", "word", "S. Brown, the Kitchens, 2 a.m.",
           "I can't taste anything this month, so tell me what “{word}” tastes like. I'm serious. Write it in the margin.", 10),
    letter("serenity-sky", "serenity-brown", "sky", "S. Brown, the Kitchens, 2 a.m.",
           "{Sky}? I went up on the roof in it with my tongue out. Still nothing. Still going up there.", 10),
    letter("soren-braid", "soren-ng", "braid", "S. Ng, by the dresser",
           "“{braid}”. I've made a slip for it. Number ten. There were only meant to be nine.", 13),
    letter("pippa-quoted", "pippa-pilcrow", "quoted", "P. Pilcrow, the gravy's punctuation",
           "Your quotation has exactly the right number of commas. I counted. I wanted to add one. I didn't. Growth."),
    letter("mook-unfiled", "professor-thaddeus-mook", "unfiled", "Prof. T. Mook, the Registry (in red ink)",
           "Your correspondent hasn't filed. Neither, entirely, has The Middlemost Cookery. The Registry is having a difficult month.", 5),
    letter("gwendolyn-spell", "gwendolyn-mythwright", "spell", "G. Mythwright, the Stacks",
           "{spell} has been entered in the register. So has a soul cake, a parkin, and a stranger in a green coat. The register's getting heavy."),
    letter("inkrest-unfiled", "dr-inkrest", "unfiled", "Dr. S. Inkrest, the Still Room",
           "Nothing filed yet tonight. The Kitchen lamp's on anyway. Come down if you can't sleep. There's usually soup."),
]

DESK_PIECES = CLASSIFIEDS + CAST_LETTERS
