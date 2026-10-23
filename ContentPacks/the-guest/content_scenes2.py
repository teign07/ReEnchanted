"""Scenes 5 to 8: the Offer, Stir-up Sunday, the long table, and the Bowl."""

from content_common import memory, needs
from content_scenes import choice, node, scene, _scene_atom

# MARK: 5. The Offer — live day 18, three in the morning

O = "the-guest.scene.the-offer"
EVENING = "{october-evening}"

OFFER_RECALL = {
    "marker": EVENING,
    "entityID": "serenity-brown",
    "options": [
        {"key": "count-unbound.november.knocking",
         "line": """“The glass roof,” says the Guest. “The rain coming down it in lines. Two cups of tea. A paper bird with a wing gone soft. You remember the tea, don't you? It's the one thing you've still got the taste of. A little. At the back of everything.”

Serenity's hand goes to the strap of her map case, where the bird's still tucked, outside, where the weather can get at it.

The door from the stairs creaks. Soren's standing in it. He can't sleep either, by the look of him. He's heard enough. He doesn't come in. He stands there very still, the way he stands in front of a pattern he's just understood.

“That's how it works,” he says quietly. “It takes the thing you can still taste. That's the only way in.”"""},
        {"key": "count-unbound.november.answer",
         "line": """“The long table,” says the Guest. “A pear tart under a cloth. A boy with his hands flat where you could see them. You took one slice upstairs in a napkin. You can still taste that, can't you? A little. Pear and burnt sugar. At the back of everything.”

Serenity looks at the long table. At the far end, by the window, there's the knot in the pine where she set her map case down that night.

The door from the yard bangs. Wicker comes in with mud on his boots and his collar up. He's been out walking too. He stops dead when he sees who's talking to her.

He knows what a bargain costs. He wrote one inside *Dracula*.

“Don't,” he says. Then he stops himself. He shuts his mouth. He keeps his hands where she can see them. “Sorry. It's yours to say. I'm only telling you what I know. It always costs more than it says.”"""},
        {"key": "count-unbound.november.greenhouse",
         "line": """“The little greenhouse,” says the Guest. “Frost on the grass. A moth asleep on a geranium. You made yourself something hot, after, and drank it in the dark by yourself. You can still taste that. A little. At the back of everything.”

Serenity's very still. Nobody knows about that evening. She left a note that said *Out*, and that was all.

Nobody comes to the door. Nobody's going to. It's her evening and it's her choice, the way it was then."""},
    ],
    "fallback": """“The evening you kept for yourself,” says the Guest. “You know the one. Nobody else was there. You can still taste a little of it. At the back of everything.”

Serenity's very still. She doesn't ask how it knows. I don't think she wants to hear the answer.""",
}

OFFER = scene(
    O, "The Offer",
    [
        node(f"{O}.entry", "Three in the morning",
             f"""Serenity comes down to the Kitchens at three in the morning.

She does that now. Since October, she hears things at night. Pages turning in the walls. Doors that are really books. She can't sleep through it, so she walks, and her walks end up here, where it's warm.

Ambrose has left something out for her. He always does now. Tonight it's a bowl of leek and potato soup under a plate, on the warm corner of the range, and a spoon laid next to it, and a folded napkin. He doesn't say anything about it in the mornings. She doesn't either.

You're there because you couldn't sleep either. You're sitting on the bench by the dresser with me on your knees. I've got my leaves shut. I keep them shut after dark now.

The Guest is awake.

It's at the sink, in its long green coat, scrubbing a pot. The pot's already clean. It scrubs it anyway, slowly, round and round, the way you'd stroke a dog. In the low light from the range, I can see that the sleeves of the coat are far too long for it. It's rolled them up four times.

Serenity sits down with her soup. She can't taste it. She eats it anyway.

The Guest stops scrubbing.

“I could give it back,” it says.

Serenity's spoon stops halfway.

“The taste of things.” The Guest doesn't turn round. It talks to the pot. “Soup. Rain. All of it. I know where it went. I've been eating everybody else's. I could give you yours.”

It's very quiet. Even the walls have stopped turning pages.

At night the Guest doesn't smell of nothing any more. It smells of frost. Frost and old iron, like a gate in winter. I didn't notice it till now. I wish I hadn't.

“What for?” says Serenity.

Now it turns. The hood tilts towards her.

“One evening,” it says. “You've got one I'd like. An evening in November.”

{EVENING}

Serenity looks down at her soup. She stirs it. She can't taste it. She hasn't tasted anything for seven weeks.

Then she looks at you.

She doesn't ask anybody else. She asks you, because you were there in October, carrying me, when she made the plan on the back of a menu.

“What would you do?”""",
             "What do you tell her?",
             [
                 choice("take-it", "Take it. You should be able to taste things.",
                        """She looks at you for a long moment. Then she nods.

“Yes,” she says to the Guest. “Have it.”

The Guest comes across the Kitchens. It doesn't touch her. It leans over her bowl, the way it leans over every plate, and breathes in.

Serenity gasps.

“Leeks,” she says. “Leeks. And pepper, too much pepper, and—oh—butter.” She's laughing. She's crying a bit. She takes another spoonful and shuts her eyes. “I'd forgotten. I'd forgotten soup was this *loud.*”

She eats the whole bowl. She asks for more. The Guest goes back to its pot.

And in the morning, when somebody mentions an evening in November, she frowns. She looks puzzled, politely, the way you look when someone tells you about a dream you had.

“Did I?” she says.

The ones who were there remember it for her.""",
                        "At three in the morning you told Serenity to take the Guest's offer, and she tasted soup again. She doesn't remember her evening in November any more.",
                        ["offer-taken"], f"{O}.taken",
                        [memory("serenity-brown", "the-guest.offer.taken",
                                "At three in the morning Serenity took the Guest's offer on the reader's word, and tasted leek soup again.",
                                aside="Leeks! Pepper! Everything's so loud. People keep telling me about an evening I can't find. I believe them.",
                                gossip="{teller} says Serenity can taste again. Found her in the Kitchens at breakfast eating marmalade off the spoon. She cried.")]),
                 choice("keep-night", "Keep the evening. Paper can be got used to.",
                        """She looks at you for a long moment. Then she nods.

“No,” she says to the Guest. “I'll keep it.”

The Guest doesn't argue. It doesn't look disappointed. It looks, for a second, almost proud of her, the way a teacher looks when somebody gets a hard sum right.

“Clever,” it says. “Keep the old rules.”

It goes back to its pot. Serenity eats her paper soup to the last spoonful. Then she does something I didn't expect. She sticks her tongue out, just a little, at the window, where it's started to rain.

She can't taste it. But she remembers what it tasted like.""",
                        "At three in the morning you told Serenity to keep her evening. She said no to the Guest and kept it.",
                        ["offer-refused"], f"{O}.kept",
                        [memory("serenity-brown", "the-guest.offer.kept",
                                "At three in the morning Serenity said no to the Guest's offer on the reader's word, and kept her evening.",
                                aside="Still paper. Still mine. I'd make the same choice again, I think. Ask me in a week.",
                                gossip="{teller} says the Guest offered Serenity something at three in the morning and she said no. Nobody knows what.")]),
             ],
             memories=[memory("serenity-brown", "the-guest.offer.asked",
                              "At three in the morning the Guest offered Serenity the taste of things back, for one evening's memory.")]),
        node(f"{O}.taken", "Marmalade",
             """At breakfast Serenity eats marmalade straight off the spoon, standing up, with her eyes shut.

Ambrose watches her from the range. He doesn't say anything. He cuts her another slice of toast and puts it by her elbow, and goes back to the porridge, and his shoulders are shaking a bit, and I don't think it's laughing.""",
             "Keep this leaf.",
             braid="Serenity took the Guest's offer and tasted again. The ones who were there keep her evening for her."),
        node(f"{O}.kept", "Rain",
             """At breakfast Serenity's on the roof.

She's standing in the rain with her face turned up and her tongue out, like an idiot, the way she said she would. She can't taste it. She stays up there till her hair's soaked flat.

When she comes down, she's smiling. I don't understand it. I've decided I don't have to.""",
             "Keep this leaf.",
             braid="Serenity kept her evening and stood in the rain on the roof anyway."),
    ],
    prompt="Read on, then choose.", room="location-kitchens", cast=["serenity-brown"],
    report="At three in the morning the Guest made Serenity Brown an offer: the taste of things, for one evening's memory. What she answered is hers to tell.",
    report_after=21, tags=("the-offer",))
OFFER["nodes"][0]["recalls"] = [OFFER_RECALL]


# MARK: 6. Stir-up Sunday — live day 21

S = "the-guest.scene.stir-up-sunday"
STIR_UP = scene(
    S, "Stir-up Sunday",
    [
        node(f"{S}.entry", "Stir-up Sunday",
             """It's Stir-up Sunday, the last Sunday before Advent, and the whole Academy's queueing out of the Kitchens and halfway up the stairs.

That's the custom. Ambrose makes the Christmas pudding today, in the biggest bowl in the building, a great brown earthenware one he can barely lift. And everybody in the house has to take a turn at the stirring. You stir from east to west, the way the three kings travelled in the old story. You shut your eyes. And you make a wish, and you don't say it out loud, or it won't come.

The pudding page is nearly whole again. The spices have come back to the recipe, letter by letter, as the Academy's cooked. Penny's been counting. Over a hundred letters restored. Some of them came from out there, from people's own kitchens, and Ambrose says that's the strangest and best part.

The queue moves. Pippa stirs and wishes with her whole face screwed up. Dr. Vellum stirs exactly three times and makes a note. Serenity stirs, and laughs at something, and won't say what.

You stir. I can't stir. But you hold me over the bowl while you do it, and I make a wish too. I'm not telling you what it is either. Those are the rules.

Then the Guest steps up.

Nobody's sure it's allowed. Everybody looks at Ambrose. Ambrose holds out the wooden spoon.

The Guest takes it in both its clean hands. It stirs from east to west, slowly, round and round. It shuts its eyes, under the hood.

And then it does what you must never do. It says its wish out loud.

“Home,” it says. “The smell of the house when the bowl was put down. I want to go home.”

The spoon stops.

At the back of the Kitchens, in the doorway to the stairs, there's a tall dark shape in a long black coat. It's Headmistress Thorne. I didn't hear her come. She's standing perfectly still with her hands folded, and she's watching the Guest, and her face is doing nothing at all.

Then she turns and goes back up the stairs, and doesn't come into the room.

She hasn't come into a room the Guest's been in all month. I've only just noticed.""",
             "The pudding goes into its cloth.",
             [choice("stay-late", "Stay after the queue's gone.",
                     "You stay. The Kitchens empty out. The pudding steams in its cloth, and the windows run with it.",
                     "On Stir-up Sunday everybody stirred and wished. The Guest said its wish out loud: home. The Headmistress watched from the doorway and went away.",
                     ["stir-up"], f"{S}.the-page",
                     [memory("pippa-pilcrow", "the-guest.stir.face",
                             "On Stir-up Sunday Pippa stirred the pudding and wished with her whole face screwed up.",
                             aside="I wished so hard my ears went hot. I'm not telling you. Ask my ears."),
                      memory("dr-vellum", "the-guest.stir.three-times",
                             "On Stir-up Sunday Dr. Vellum stirred the pudding exactly three times and wrote something down.",
                             aside="Three stirs. I wrote down the wish. Then I crossed it out. Then I wrote it down again."),
                      memory("serenity-brown", "the-guest.stir.laughed",
                             "On Stir-up Sunday Serenity stirred the pudding, laughed at something, and wouldn't say what.",
                             aside="I laughed at the pudding. It looked like a planet. Don't tell anyone that's what I wished on."),
                      memory("headmistress-thorne", "the-guest.stir.watched",
                             "On Stir-up Sunday the Headmistress watched the Guest say its wish from the Kitchens' doorway and went back upstairs.")])]),
        node(f"{S}.the-page", "Under the endpaper",
             """That night, after the queue's gone and the pudding's steaming in its cloth, Ambrose sits down at the long table with *The Middlemost Cookery*.

He doesn't open it at a recipe. He opens it at the back, at the place he always opens it, where the endpaper's coming loose. For thirty years he's been trying to read what's under that endpaper. There's a page stuck to it, with writing nobody's ever been able to make out.

Tonight you can read it.

Not all of it. The Academy's cooking has brought back most of the letters. The title's whole now, in old brown handwriting:

*A Bowl for the One Who Keeps the Pots.*

Under it there's a list of things. Most of it's there. Some of it isn't. There are gaps, like missing teeth.

Ambrose reads it three times. Then he lays his hand flat on the page, the way you'd lay your hand on a sleeping animal to feel it breathe.

“That's it,” he says. “That's what I've been looking for.”

He looks across at the stool by the fire. The Guest's asleep there, in its green coat, with its sleeves rolled up four times.

“It was never for us,” he says. “It's for them. It always was.”""",
             "Ambrose has the page. It isn't finished.",
             [
                 choice("promise-cook", "Tell him you'll keep cooking, so he can finish it.",
                        """He nods. He doesn't say anything. He gets up and puts the kettle on, and makes you a cup of tea you didn't ask for, and slides it across the table, and that's how Ambrose says a thing.""",
                        "On Stir-up Sunday you promised Ambrose you'd keep cooking, so the bowl's page could come back.",
                        ["stir-promise"], f"{S}.close",
                        [memory("ambrose-trencher", "the-guest.stir.reader-promised",
                                "On Stir-up Sunday the reader promised Ambrose they'd keep cooking so the page could come back.",
                                aside="You said you'd keep cooking. I made you tea. That's the whole conversation, as far as I'm concerned.")]),
                 choice("ask-thorne", "Ask him why the Headmistress won't come in.",
                        """Ambrose looks at the door to the stairs for a long time.

“Thirty years I've cooked for that woman,” he says. “She's never once eaten in this room. I used to think it was manners.” He turns the page over. He turns it back. “Now I don't know what I think.”""",
                        "On Stir-up Sunday you asked Ambrose why the Headmistress never comes into the Kitchens.",
                        ["stir-thorne"], f"{S}.close",
                        [memory("ambrose-trencher", "the-guest.stir.reader-asked-thorne",
                                "On Stir-up Sunday the reader asked Ambrose why the Headmistress never comes into the Kitchens.",
                                aside="You asked about her. I've been asking myself for thirty years. I still haven't got an answer.")]),
             ]),
        node(f"{S}.close", "Steam",
             """The pudding steams all night in its cloth, on the back of the range.

In the morning the pots are scrubbed, as always. But something else has been done too. The big brown bowl the pudding was stirred in has been washed and dried and set on the hearth, upside down, by the Guest's stool. As if somebody's keeping it ready.""",
             "Keep this leaf.",
             braid="On Stir-up Sunday a page came clear under the endpaper of Ambrose's cookbook: A Bowl for the One Who Keeps the Pots.",
             memories=[memory("ambrose-trencher", "the-guest.stir.page-scene",
                              "On Stir-up Sunday the page under the endpaper came back: A Bowl for the One Who Keeps the Pots.",
                              aside="Thirty years. It was at the back the whole time. Under the paper. Waiting for somebody to cook enough.",
                              gossip="{teller} says the Guest said its wish out loud at the pudding. Said it wants to go home.")]),
    ],
    prompt="Read on, then choose.", room="location-kitchens",
    cast=["ambrose-trencher", "headmistress-thorne", "pippa-pilcrow", "dr-vellum", "serenity-brown"],
    report="On Stir-up Sunday the whole Academy stirred the pudding and wished. The Guest said its wish out loud: home. The Headmistress watched from the doorway and didn't come in. That night a page came clear in Ambrose's cookbook: A Bowl for the One Who Keeps the Pots.",
    report_after=22, tags=("stir-up-sunday",))


# MARK: 7. A Place at the Table — live day 25

P = "the-guest.scene.a-place-at-the-table"
TABLE = scene(
    P, "A Place at the Table",
    [
        node(f"{P}.entry", "The long table",
             """Tonight everybody's eating in the Kitchens.

Not in the Great Hall. Ambrose wanted the long table, so the long table's what they've got. It's been scrubbed white. It's set end to end with every plate in the building, odd ones and good ones, blue-rimmed and plain, and candles stuck in saucers all the way down the middle. There's soup. There's a ham. There's mashed potato in a bowl the size of a well. There's the cranberry sauce Penny made. It's set too hard and has to be cut with a knife, and it's perfect.

And there's one chair at the top of the table that nobody's sitting in.

It's got a plate in front of it. A full one. Soup and ham and potato and a spoonful of the cranberry. A candle. A napkin folded into a little hat.

Nobody sits in it. Nobody asks about it either. Everybody seems to know.

Ambrose stands up at the end, with his apron still on.

“That one's for whoever's missing,” he says. “Everybody's got somebody. Somebody who used to sit at your table and doesn't now. They get a place too. That's all.” He sits down. “Eat your soup.”

Everyone eats their soup.

It tastes of soup. It tastes of leeks and pepper and good stock. The Academy's been cooking for two weeks, all of it, and the Guest hasn't leaned over a single plate tonight. It's sitting halfway down the table on a bench between Penny and a second-year, eating ham. It's eating it the ordinary way. It's tasting it, as far as I can tell.

I've been watching it all evening. I've never seen it look so much like it belongs somewhere.""",
             "The talk goes low at the far end.",
             [choice("listen", "Listen to the far end of the table.",
                     "You listen. The candles have burned halfway down, and everybody's voices have gone soft.",
                     "Supper was at the long table in the Kitchens, with a place set for whoever's missing.",
                     ["the-table"], f"{P}.round",
                     [memory("ambrose-trencher", "the-guest.table.chair-scene",
                             "Ambrose set a place at the long table for whoever's missing, and nobody sat in it, and nobody asked.",
                             aside="Somebody's always missing. You set the place. You don't make a speech. I made a short speech. That's allowed.")])]),
        node(f"{P}.round", "Round the table",
             """Down at the far end, the talk goes quiet and low.

Penny says she'd set the chair for her grandmother, who taught her to file things alphabetically and to always check twice. Wicker doesn't say who he'd set it for. He looks at the chair for a long time and then cuts himself more ham. Soren says, “My father. He used to fold the napkins like that,” and touches the little hat on the empty plate, very gently, and puts it back exactly.

Serenity's sitting between Wicker and Soren. That's an accident, I think. Or it isn't. The table's very long, and she's got a lot of room on either side, and she's chosen the middle.

Professor Boggle's been trying to thank Ambrose for twenty years. For the soup when she was ill. For the cake on her fiftieth. For a thousand cups of tea put down by her elbow without a word. Every time, he's walked off before she got to the end of the sentence.

Tonight she gets up and goes round to the range, where he's ladling seconds.

“Ambrose. I'm grateful,” she says.

He stops ladling.

They're the right words. They're the old words. They don't pay him, and they don't send him away. They just sit there between the two of them, in the steam, like a warm plate.

He doesn't walk off. He doesn't say anything either. But he stands there and lets her have said it.

That's new.

Then the Guest leans across the table to you.

“Who'd you set it for?” it says. “The empty one.”""",
             "Who would you set the empty chair for?",
             [
                 choice("someone-gone", "Someone who used to sit at your table.",
                        """You tell it. Or you don't say the name, and it doesn't ask. It just nods.

“Then they've got a place,” it says. “That's how it works. You put the bowl down and you don't say who it's for, and everybody knows.”

It goes back to its ham. The candle in front of the empty chair burns very straight all evening.""",
                        "At the long table you'd set the empty chair for someone who used to sit at yours.",
                        ["chair-gone"], f"{P}.close"),
                 choice("someone-far", "Someone who's far away.",
                        """“Far's just a long walk,” says the Guest. It sounds like it knows. “Set the chair anyway. It helps them find the house.”""",
                        "At the long table you'd set the empty chair for someone far away.",
                        ["chair-far"], f"{P}.close"),
                 choice("the-guest", "For it. It's been missing from here a long time.",
                        """The Guest goes very still.

Nobody's ever said that to it. I can tell. Its clean hands are flat on the table, and for a moment the hood's tipped down so far I think it's fallen asleep.

“Yes,” it says, at last. Very quietly. “I have, haven't I.”""",
                        "At the long table you told the Guest the empty chair was for it.",
                        ["chair-guest"], f"{P}.close"),
             ],
             memories=[memory("penny-blackletter", "the-guest.table.grandmother-scene",
                              "At the long table Penny said she'd set the empty chair for her grandmother, who taught her to check twice.",
                              aside="My grandmother checked everything twice. I check everything three times. She'd have had something to say about that."),
                       memory("soren-ng", "the-guest.table.napkin",
                              "At the long table Soren touched the napkin folded on the empty plate and put it back exactly.",
                              aside="My father folded them like that. I didn't know anybody else knew the hat."),
                       memory("wicker-eddies", "the-guest.table.didnt-say",
                              "At the long table Wicker looked at the empty chair a long time and didn't say who he'd set it for.",
                              aside="I didn't say who. I know who. That's enough for one supper."),
                       memory("serenity-brown", "the-guest.table.middle",
                              "At the long table Serenity sat in the middle, with plenty of room on either side.",
                              aside="I sat in the middle. There was room. Don't read anything into it. Read something into the potatoes."),
                       memory("lydia-boggle", "the-guest.table.grateful",
                              "At the long table Professor Boggle finally said it to Ambrose, I'm grateful, and he stood still and let her.",
                              aside="Twenty years. He stood still for it. I'm not going to make a fuss. I'm going to make a fuss later.",
                              gossip="{teller} says Professor Boggle told Trencher she was grateful, at the range, and he didn't walk off. Twenty years, apparently.")]),
        node(f"{P}.close", "The candles",
             """The candles burn down to their saucers one by one. People go up to bed in twos and threes.

The empty plate's still full when the last of them goes. Ambrose doesn't clear it. He leaves it where it is, with the candle out and the napkin hat still standing, till morning.""",
             "Keep this leaf.",
             braid="At the long table Ambrose set one place for whoever's missing. Nobody sat in it, and the Guest ate with everybody else.",
             memories=[memory("ambrose-trencher", "the-guest.table.left-plate",
                              "After the long-table supper Ambrose left the empty place's plate till morning instead of clearing it.",
                              gossip="{teller} says Ambrose set a place at the long table for nobody, and nobody sat in it. Everybody just knew.")]),
    ],
    prompt="Read on, then choose.", room="location-kitchens",
    cast=["ambrose-trencher", "penny-blackletter", "soren-ng", "wicker-eddies", "serenity-brown", "lydia-boggle"],
    report="Supper was at the long table in the Kitchens. Ambrose set one place for whoever was missing, and nobody sat in it. The Guest ate with everybody else, the ordinary way.",
    report_after=26, tags=("a-place-at-the-table",))


# MARK: 8. The Bowl — live day 29

B = "the-guest.scene.the-bowl"
BOWL = scene(
    B, "The Bowl",
    [
        node(f"{B}.entry", "Oats",
             """It's the last day of November and Ambrose is cooking something small.

All month the Kitchens have been loud. Today they're quiet. He's sent everybody out. There's just him at the range, and the Guest asleep on its stool by the fire, and Serenity on the end of the long table, swinging her boots, and you, with me open on your knees. I've opened my leaves for this. I want to see.

*The Middlemost Cookery*'s propped against the bread crock, open at the back. Ambrose has read the page so many times he doesn't need to. He reads it anyway.

It isn't a feast. That's the first surprise. After thirty years I thought it'd be a feast. It's oats. It's a small pan of oats, cooked slowly in milk, stirred the whole time with the handle of a wooden spoon. A pinch of salt. Pippa isn't here to object. When it's thick, a spoonful of honey on top, and a knob of butter melting into a little gold pool, and a splash of cream poured round the edge, cold, so it doesn't mix.

That's all.

He takes down a bowl. It's a plain brown one from the very back of the dresser, chipped on one side, older than anything else in the room. I've never seen him use it.

He fills it. He doesn't put a spoon in.

Then he carries it across the Kitchens, and he doesn't put it in the Guest's hands. He kneels down and puts it on the hearth, on the warm stones, beside the stool. And he gets up and goes back to the range, and turns his back, and starts washing the pan.

He doesn't say who it's for.

Everybody knows.

The Guest wakes.

It looks at the bowl for a long time. Then it slides off the stool and kneels by the hearth, and pushes back its hood.

I can see its face now, for the first time. It's small and brown and creased like a walnut, with a big soft nose and two bright black eyes, and it looks very, very old, and very, very tired.

It leans over the bowl. It breathes in.""",
             "It's breathing in the bowl.",
             [choice("watch", "Watch.",
                     "You don't move. Neither does Serenity. Ambrose keeps washing the pan, with his back turned.",
                     "On the last day of November Ambrose cooked the bowl from the page and set it on the hearth without saying who it was for.",
                     ["the-bowl"], f"{B}.home-or-not",
                     [memory("ambrose-trencher", "the-guest.bowl.cooked-scene",
                             "On the last day of November Ambrose cooked the bowl from the page and set it on the hearth without saying who it was for.",
                             aside="Oats. Thirty years and it was oats. I'd have laughed if I wasn't busy.")])]),
        node(f"{B}.home-or-not", "It smells like home",
             """The smell of the oats goes all through the Kitchens. Honey and warm milk and butter going brown. It's the plainest smell in the world. It's the smell of a house at night when everyone's in bed and somebody's left something warm out for whoever needs it.

The Guest picks up the bowl in both its clean hands, and drinks from the side, the old way, with no spoon.

And it changes.

Not much. Nothing like a story where someone turns into a swan. The green coat goes on being a green coat, too big. But the frost goes out of the room. The old iron smell goes out of it. The Guest smells of something at last. It smells of oats and soot and soap and a warm brick floor. It smells like the Kitchens.

It smells like it's home.

It sets the bowl down, empty. It looks round the Kitchens at the pots, and the long table, and the range, and Ambrose's back, still turned, still washing the pan that's already clean.

Then it looks at you.

“I could go,” it says. “I know the way now. I can taste it.” It touches the brown bowl. “Or I could stay. Keep the pots. Like before. If the house would have me.”

Behind it, very faintly, I can smell frost again. Far off. Out past the west door. Something out there's waiting to see what it chooses.""",
             "What do you tell it?",
             [
                 choice("send-home", "Go home. You've been away long enough.",
                        """It nods, slowly, like somebody who's been told a thing they knew.

It gets up. It goes to the west door. It moves the sack of onions itself. On the step, with the cold coming in round it, it turns back.

It looks at Ambrose's back. It looks at you. It looks, for a long moment, at the brown bowl on the hearth.

“I'm grateful,” it says.

It's the only right thing to say. It doesn't pay anyone. It doesn't send anyone away. It's just true. Then it's gone, into the dark, and the door swings shut on its own.""",
                        "On the last day of November the Guest ate from the bowl, and you told it to go home. It said “I'm grateful” at the west door.",
                        ["ending-home"], f"{B}.after",
                        [memory("ambrose-trencher", "the-guest.bowl.sent-home",
                                "On the last day of November the Guest ate from Ambrose's bowl, said it was grateful, and went home through the west door.",
                                aside="Went home. Good. The pots are mine again. I'll do them badly for a week, out of respect.",
                                gossip="{teller} says the Guest went home on the last night. Said it was grateful at the door. Trencher's doing the pots himself now.")]),
                 choice("ask-to-stay", "Stay. Keep the pots. The house wants you.",
                        """The Guest looks at the pots, all hanging in their row, biggest to smallest, handles all one way.

“Yes,” it says. “I'd like that.”

It doesn't go anywhere. It pulls its hood back up and sits on its stool. And then it says, to nobody, to the fire, to the house:

“I'm grateful.”

Then, because a thing that's going to live in a house ought to be called something, it tells us its name.

“Aiken Drum,” it says.

Ambrose stops washing the pan for exactly one second. Then he goes on.

Out past the west door, very far off, something that was waiting turns away. I hear it go. I'm the only one who does.""",
                        "On the last day of November the Guest ate from the bowl, and you asked it to stay. It told us its name, Aiken Drum, and it keeps the pots again.",
                        ["ending-stay"], f"{B}.after",
                        [memory("ambrose-trencher", "the-guest.bowl.stayed",
                                "On the last day of November the Guest ate from Ambrose's bowl, stayed on to keep the Academy's pots, and said its name was Aiken Drum.",
                                aside="It's staying. The bowl goes out every night now. And nobody thanks it. I mean that.",
                                gossip="{teller} says the Guest's staying. Trencher puts a bowl on the hearth every night, and nobody's allowed to say thank you.")]),
                 choice("let-it-go-back", "Tell it the house can't take it back.",
                        """The Guest looks at you for a long time.

Then it puts the brown bowl down on the hearth, very carefully, the way you'd put down something you weren't allowed to keep.

“No,” it says. “I suppose it can't.”

It stands up. It pulls its hood back over its face. And the frost comes back into the room, slowly, the way cold comes in under a door.

“They'll want me back,” it says. “I've been away too long already. And I've got a great deal to carry.”

It goes to the west door. It moves the onions. On the step it stops, and turns.

“Keep cooking,” it says to Ambrose's back. “Somebody should.”

It doesn't say thank you. It doesn't say it's grateful. It goes out into the dark, and the door shuts, and the frost goes with it.""",
                        "On the last day of November the Guest ate from the bowl, and you told it the house couldn't take it back. It went out into the cold.",
                        ["ending-court"], f"{B}.court",
                        [memory("ambrose-trencher", "the-guest.bowl.went-back",
                                "On the last day of November the Guest ate from Ambrose's bowl, then went back out into the cold to the Court.",
                                aside="It went back. Told me to keep cooking. So I'm cooking.",
                                gossip="{teller} says the Guest went back out the west door on the last night, and the frost went with it.")]),
             ]),
        node(f"{B}.after", "Finished",
             """When it's over, Serenity gets down off the table.

She goes over to the range, where Ambrose is still washing the pan. She doesn't touch him. She leans against the warm brick beside him.

“That was a good bowl,” she says.

He doesn't answer. He keeps washing.

“Ambrose. I'm grateful. For the soup. Every night. You never said and I never said and I want to say it properly.”

He stops washing. He stands there with his hands in the water.

And for the first time in thirty years, Ambrose Trencher lets somebody finish thanking him.

Later, when the Kitchens have gone dark, Professor Boggle comes down the back stairs with a plate under a cloth. She's cooked for him. Cheese on toast, a little burnt at the corners. She puts it down in front of him and doesn't say a word, the way he never does.

Ambrose looks at it for a long time. Then he sits down, which nobody's ever seen him do in his own kitchen, and eats every bite.""",
             "Read on.",
             [choice("to-morning", "Morning.",
                     "The fire goes down. Nobody banks it. In the morning nobody needs to.",
                     "For the first time in thirty years, Ambrose let somebody finish thanking him.",
                     ["thanked"], f"{B}.morning",
                     [memory("serenity-brown", "the-guest.bowl.grateful",
                             "On the last day of November Serenity told Ambrose she was grateful for the soup, every night, and he let her finish.",
                             aside="I said it properly. He stood there. His hands were in the water the whole time. It counted."),
                      memory("lydia-boggle", "the-guest.bowl.cooked-for-him",
                             "On the last night of November Professor Boggle cooked Ambrose cheese on toast, and he sat down in his own kitchen and ate it.",
                             aside="He sat down. In his own kitchen. I burnt the corners a little. It felt friendlier.")])]),
        node(f"{B}.court", "Bread",
             """Ambrose stands holding the clean pan for a long time.

Then he puts it down, and gets out flour, and starts on tomorrow's bread. Serenity gets down off the table and helps him without being asked. Neither of them says anything. There isn't anything to say that the bread can't.

Later, when the dough's proving under its cloth, Professor Boggle comes down the back stairs with a plate. She's cooked for him. Cheese on toast, a little burnt at the corners. She puts it down in front of him and doesn't say a word, the way he never does.

Ambrose looks at it for a long time. Then he sits down, which nobody's ever seen him do in his own kitchen, and eats every bite.""",
             "Read on.",
             [choice("to-morning", "Morning.",
                     "The fire goes down. Ambrose banks it himself.",
                     "Ambrose started on tomorrow's bread, and Serenity helped him.",
                     ["bread"], f"{B}.morning",
                     [memory("serenity-brown", "the-guest.bowl.bread",
                             "After the Guest went back out into the cold, Serenity helped Ambrose start the bread without a word.",
                             aside="We made bread. Neither of us said anything. It was the right amount of not saying anything."),
                      memory("lydia-boggle", "the-guest.bowl.cooked-for-him",
                             "On the last night of November Professor Boggle cooked Ambrose cheese on toast, and he sat down in his own kitchen and ate it.",
                             aside="He sat down. In his own kitchen. I burnt the corners a little. It felt friendlier.")])]),
        node(f"{B}.morning", "Unattributed",
             """In the morning there's a bowl on the step outside the west door.

It's a plain white one, very fine, the kind you could see a candle through. It's empty and clean. Beside it, laid very straight on the stone, there's a single long black thorn.

Nobody saw who put it there. Nobody says who it's from.

Penny files it under *Unattributed.*""",
             "Keep this leaf.",
             braid="In the morning there was a white bowl on the west step, and a black thorn beside it. Penny filed it under Unattributed.",
             memories=[memory("ambrose-trencher", "the-guest.bowl.white-bowl",
                              "On the morning after the bowl, Ambrose found a fine white bowl and a black thorn on the west step.",
                              aside="A white bowl. A thorn. I know whose house that came from. I'm not saying. I'm making porridge.")]),
    ],
    prompt="Read on, then choose.", room="location-kitchens", cast=["ambrose-trencher", "serenity-brown", "lydia-boggle"],
    report="On the last day of November Ambrose cooked the bowl from the page: oats in milk, with salt, honey, butter and cold cream round the edge. He set it on the hearth and didn't say who it was for. In the morning there was a white bowl on the west step, with a black thorn beside it.",
    report_after=29, tags=("the-bowl",))

SCENES_LATE = [OFFER, STIR_UP, TABLE, BOWL]

ATOMS_LATE = [
    _scene_atom(OFFER, "the-offer", 18, 20, priority="milestone"),
    _scene_atom(STIR_UP, "the-offer", 21, 23),
    _scene_atom(TABLE, "the-bowl", 25, 27),
    _scene_atom(BOWL, "the-bowl", 29, 29, priority="milestone"),
]
