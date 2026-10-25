"""Story scenes and real-world crossings. Prose drafts and bj's notes live in
docs/november-the-guest-scenes.md; this file is what ships."""

from content_common import EVENT_ID, PACK_ID, atom, memory, needs

DETAIL = "The Guest Who Came on All Souls · November 2026"


def choice(id, title, result, braid, tags, next_node=None, memories=()):
    c = {"id": id, "title": title, "prompt": title, "result": result, "effectLine": "",
         "consequenceTags": [f"{EVENT_ID}:{t}" for t in tags], "braidText": braid}
    if next_node:
        c["nextNodeID"] = next_node
    if memories:
        c["castMemories"] = list(memories)
    return c


def node(id, title, body, prompt, choices=(), braid=None, memories=()):
    n = {"id": id, "title": title, "body": body, "prompt": prompt, "choices": list(choices)}
    if braid:
        n["braidText"] = braid
    if memories:
        n["castMemories"] = list(memories)
    return n


def scene(id, title, nodes, *, prompt, room, cast, report, report_after, tags=()):
    return {
        "id": id, "packID": PACK_ID, "eventID": EVENT_ID, "title": title,
        "opening": nodes[0]["body"], "prompt": prompt, "detail": DETAIL, "choices": [],
        "entities": ["The Book"], "tags": [EVENT_ID, "academy"] + list(tags),
        "reportAfterLiveDay": report_after, "report": report, "roomID": room, "castIDs": list(cast),
        "nodes": list(nodes),
    }


# MARK: 1. The Knock — All Souls' Eve, live day 0

K = "the-guest.scene.the-knock"
KNOCK = scene(
    K, "The Knock",
    [
        node(f"{K}.entry", "The Knock",
             """The soul cakes are cooling on the long table.

There are forty of them, flat and round and the colour of a good brown paper bag, and every one has a cross cut into the top before it went in the oven. Ambrose Trencher's the Academy's cook, and the Kitchens are his. He makes them every All Souls. Nobody asked him to. The old Academy did it, so he does it. He says a custom's like a pot: if nobody uses it, it rusts.

The Kitchens are warm and nearly dark. The big fire's been banked down to a red heap. The pots hang in their rows over the range, and the long pine table runs away into the shadows like a road. It smells of nutmeg and hot currants and the end of a long day.

You've set me on the end of the table, by the cakes. I can smell them through my cover. Paper remembers every kitchen, and I'm remembering this one as hard as I can.

Then somebody knocks.

It isn't the door from the Great Hall. Everybody uses that one. It isn't the yard door where the milk comes in. It's the little door at the west end, past the Pantry. It's low and black, with iron studs, and its bolts are painted over so thick they look like knuckles. Nobody uses the west door. Ambrose keeps a sack of onions against it. Except he moved the onions this morning, and couldn't say why.

The knock comes three times. It's polite. It's patient. It sounds like somebody who's knocked on a great many doors.

Ambrose wipes his hands on his apron. He looks at the west door for a long moment. He looks at the soul cakes. Then he goes to it.

The door sticks. He has to put his shoulder to it. It opens with a sound like a stair giving way, and the cold comes in all at once, a wet black November cold that smells of leaves and stone.

Somebody's standing on the step.

They're small. They come up to about Ambrose's elbow. They're wearing a coat that's far too big for them, a long green coat with brass buttons, the kind a grand person might've worn to church a very long time ago. It's gone ragged at the hem. It's dark with rain. The hood's up, and I can't see a face under it. I can see two hands, folded in front, and they're very clean.

The somebody says, in a voice like a spoon in an empty bowl:

“A soul, a soul, a soul cake. Please, good master, a soul cake. An apple, a pear, a plum or a cherry, any good thing to make us all merry.”

It's the old souling rhyme. Children used to go door to door with it on All Souls, a long time ago, asking for cakes and saying a prayer for the house's dead in return. I know it from three different books. I've never heard anybody say it out loud before. It sounds older out loud.

Ambrose doesn't ask who they are. That's the first thing I notice, and I notice it very hard.

He takes a soul cake off the tray. He puts it in their clean hands. Then he steps back from the door, so the way's clear.

“Come and sit by the fire,” he says. “You've had a long walk.”

The somebody comes in.

They walk the way a cat walks into a new house: along the wall, and slowly, touching nothing. They sit on the low stool by the banked fire. They eat the soul cake in small, careful bites, with the hood still up, and they don't drop a crumb.

They don't say thank you.

Ambrose doesn't wait for it. He's already putting the kettle on.

I lean my corner towards the stool, just a little, the way I lean towards anything new. I want to know what they smell of. Everybody smells of something. Penny smells of pencil shavings and cold tea. Wicker smells of grass and trouble. You smell of your own house, and your soap, and the weather you walked in.

The somebody by the fire smells of nothing at all.

It's like leaning towards a kitchen that isn't there any more.

I close my cover. Not all the way. Enough.

Ambrose brings the tea. While it's cooling, he takes a second soul cake off the tray and bites it, the way a cook always tastes his own batch.

He stops chewing.

He looks at the cake. He looks at the stool. He doesn't say anything, but his jaw goes very still. Later, when the somebody's dozing by the fire, he tells you very quietly what it tasted of.

“Nothing,” he says. “Like eating the shape of a cake.”

The somebody wakes before the tea's gone cold. They turn the hood towards you. I still can't see a face. I can see the fire in two small round places where eyes would be.

“And who are you, that carries a book about?” they say. “What do they call you?”

The kettle ticks. Ambrose has gone very still at the range. In every story I've ever held, there's a moment where somebody asks your name at a fire. I've never liked what happens next.""",
             "What do you tell it?",
             [
                 choice("give-name", "Tell it your name.",
                        """You tell it.

The hood tips, slowly, as if it's putting your name somewhere safe. Or somewhere it can find again.

“That's a good name,” it says. “It's been used. You can taste where.”

It turns back to the fire. I keep my ribbon pressed flat against you for the rest of the night.""",
                        "At the fire in the Kitchens, the stranger asked your name, and you told it.",
                        ["name-given"], f"{K}.morning",
                        [memory("ambrose-trencher", "the-guest.knock.reader-name-given",
                                "At the fire on All Souls' Eve the stranger asked the reader's name, and the reader told it.",
                                aside="You told it your name. I nearly dropped the kettle. Brave, or something like it.")]),
                 choice("false-name", "Give it a name that isn't yours.",
                        """You give it a name. It isn't yours. It's a good one, though, and you say it straight.

The hood stays still a long time.

“Clever,” it says, at last. It sounds pleased, the way a cat sounds pleased. “Somebody taught you the old rules. Keep them.”

It turns back to the fire. Ambrose lets out a breath he's been holding since the knock.""",
                        "At the fire in the Kitchens, the stranger asked your name, and you gave it a borrowed one.",
                        ["name-borrowed"], f"{K}.morning",
                        [memory("ambrose-trencher", "the-guest.knock.reader-name-borrowed",
                                "At the fire on All Souls' Eve the stranger asked the reader's name, and the reader gave it a borrowed one.",
                                aside="You gave it a borrowed name. Good. Somebody raised you right.")]),
                 choice("no-name", "Don't answer. Offer it more tea.",
                        """You don't answer. You pour it more tea instead.

It looks at the cup. It looks at you. Then it takes the tea in both its clean hands and drinks it down, and says nothing at all, and I've never been so glad of a silence.

“Fair,” it says, to the fire.""",
                        "At the fire in the Kitchens, the stranger asked your name. You poured it tea instead.",
                        ["name-kept"], f"{K}.morning",
                        [memory("ambrose-trencher", "the-guest.knock.reader-name-kept",
                                "At the fire on All Souls' Eve the stranger asked the reader's name, and the reader poured it tea instead.",
                                aside="You answered with tea. That's the oldest answer there is.")]),
             ]),
        node(f"{K}.morning", "In the morning",
             """In the morning the stranger's still on the stool by the fire, asleep, with the hood up and the green coat pulled around them like a tent.

Every pot in the Kitchens has been scrubbed.

All of them. The big stock pots and the little milk pans and the copper ones Ambrose saves for jam. Somebody's scoured them till they shine, and hung them back on their hooks in a perfect row, biggest to smallest, with their handles all pointing the same way.

Ambrose stands in front of them in his nightshirt with a cold cup of tea in his hand. He doesn't say anything for a long time.

Then he says, “That's not how I hang them.”

He doesn't move them back.""",
             "Keep this leaf.",
             braid="On All Souls' Eve a stranger came souling to the Kitchens' west door, and Ambrose fed it. In the morning every pot was scrubbed.",
             memories=[memory("ambrose-trencher", "the-guest.knock.pots-scene",
                              "In the morning after the knock, every pot in the Kitchens had been scrubbed and hung biggest to smallest.",
                              aside="Somebody hung my pots wrong. Beautifully wrong. I haven't moved them.",
                              gossip="{teller} says every pot in the Kitchens got scrubbed in the night. Nobody did it.")]),
    ],
    prompt="Read on, then choose.", room="location-kitchens", cast=["ambrose-trencher"],
    report="On All Souls' Eve a small stranger in a green coat came souling to the Kitchens' west door. Ambrose gave it a soul cake and a seat by the fire, and didn't ask its name. In the morning every pot had been scrubbed.",
    report_after=1, tags=("the-knock",))


# MARK: 2. Three Nights — live days 2 to 6 (Bonfire Night is day 4)

T = "the-guest.scene.three-nights"
THREE_NIGHTS = scene(
    T, "Three Nights",
    [
        node(f"{T}.entry", "Three Nights",
             """The stranger who knocked at the Kitchens' west door on All Souls' Eve has been at the Academy for three nights now. The small one, in the long green coat that's far too big for them.

Nobody's learned their name. The students have started calling them the Guest, with a capital G, the way you'd say the Headmistress or the Weather. The Guest sleeps on the stool by the fire. The Guest eats whatever Ambrose puts in front of them: porridge, stew, toast, the burnt ends of things, a whole apple, core and all. The Guest never says thank you, and never refuses a second helping.

And every morning, every pot in the Kitchens is scrubbed and hung back biggest to smallest, and nobody did it.

Dr. Vellum comes down to the Kitchens on the third evening with a notebook, a thermometer and a look.

“I'd like to examine your visitor,” Vellum says. “Temperature. Pulse. Appetite. Three nights of eating like that and nobody's taken a single measurement.”

Ambrose is chopping onions. He doesn't stop.

“No.”

“It's a simple examination.”

“They've eaten at my hearth three nights,” says Ambrose. “That makes them a guest. You don't poke a guest with a thermometer.”

“That isn't a rule.”

“It's the oldest rule there is.”

Professor Boggle is sitting at the end of the long table, mending a tea towel. She keeps the Academy's rooms. She knows where every key is and which stairs creak and which chimneys need a word. She doesn't look up from her needle.

“He's right, I'm afraid,” she says. “The house rules are older than the Academy. Three nights at the hearth and they're under its roof. Nobody can turn them out. Nobody can harm them. Not till they choose to go.”

Vellum looks at the Guest. The Guest is sitting on the stool by the fire, eating a bowl of porridge very slowly, with the hood up.

“And if they never choose to go?”

Nobody answers that.

Ambrose puts a cup of tea down by Professor Boggle's elbow without asking if she wants one. She says, “Ambrose, that's very kind of—” and he's already gone back to the onions. She finishes the sentence anyway, quietly, to the tea towel. I'm the only one who hears the end of it.""",
             "Bonfire Night comes.",
             [choice("to-the-bonfire", "Go out to the bonfire.",
                     "You go out into the cold, with me under your arm, to where the sky's going orange.",
                     "Three nights after All Souls, Dr. Vellum asked to examine the Guest, and Ambrose said no: it had eaten at his hearth.",
                     ["three-nights"], f"{T}.bonfire",
                     [memory("dr-vellum", "the-guest.three-nights.scene",
                             "On the third evening Dr. Vellum came down with a thermometer and Ambrose refused under the oldest rule.",
                             aside="He chopped onions the whole time. Didn't stop once. I've never lost an argument to someone holding a knife so calmly."),
                      memory("lydia-boggle", "the-guest.three-nights.needle",
                             "Professor Boggle told Dr. Vellum the house rules: three nights at the hearth and nobody can turn a guest out.",
                             aside="I didn't look up from my needle. I didn't want anyone to see my face.")])]),
        node(f"{T}.bonfire", "Bonfire Night",
             """It's Bonfire Night, and the courtyard's full.

The bonfire's taller than the stable roof. It roars and spits, and sparks go up into the black sky like somebody's shaken out a blanket full of stars. Everybody's in scarves. Everybody's breath is showing. Ambrose has brought out trays of parkin, sticky and dark and smelling of black treacle and ginger, and bags of bonfire toffee you have to break with a little hammer.

The Guest stands at the very edge of the firelight.

They won't come closer. Everybody else is crowding in to the warmth, holding their hands out, and the Guest stays back where the dark starts, in their long green coat, with a square of parkin in their clean hands.

Penny finds Ambrose at the toffee table. She's carrying his book.

It's *The Middlemost Cookery*. He bought it at an estate sale thirty years ago and he carries it everywhere, in his apron pocket, wrapped in a tea towel. The spine's held together with string. He won't say what he keeps looking for in it. There's a page at the very back, stuck down under the endpaper, that he's never been able to read. Penny's holding it open at the page for parkin.

“Ambrose. Read the second line.”

He reads it. His face does something slow.

The second line says *1 lb of oatmeal, ½ lb of black _reacle.*

The T's gone. It isn't smudged. It isn't torn. There's just a clean small gap where a letter used to be, like a missing tooth.

“It was there on Sunday,” says Penny. “I checked. I always check.”

Somewhere behind us, in the dark at the edge of the light, the Guest takes another small bite of parkin.

Somebody touches your elbow. It's Professor Momort. He's wrapped in a coat with too many collars, and his face is lit orange on one side by the fire.

“Whatever you do,” he says, very low, “don't thank it. Not for anything. If it does you a kindness, say *I'm grateful*. Never the other thing.”

“Why?”

He looks at the Guest for a long moment.

“Because thanks are payment,” he says. “And you don't know what you'd be paying for.”

Then a rocket goes up with a scream and bursts green over the stables, and when I look back, he's gone.""",
             "The Guest's standing alone at the edge of the dark.",
             [
                 choice("bring-toffee", "Take it a piece of toffee.",
                        """You break off a piece of toffee and carry it across the courtyard.

The Guest takes it. It holds it up to the firelight, so the light goes through it, amber and gold.

“Burnt sugar,” it says. “I'd forgotten it could be that colour.”

It doesn't say thank you. You don't either. You've been told.""",
                        "On Bonfire Night you took the Guest a piece of toffee at the edge of the dark.",
                        ["bonfire-toffee"], f"{T}.embers",
                        [memory("ambrose-trencher", "the-guest.bonfire.reader-toffee",
                                "On Bonfire Night the reader carried a piece of toffee to the Guest at the edge of the dark.",
                                aside="You took it the toffee. Nobody else went near. I saw.")]),
                 choice("watch-guest", "Stay by the fire and watch it.",
                        """You stay in the warm and watch.

The Guest eats its parkin to the last crumb. Then it does something nobody else sees. It walks to the long trestle table where the empty trays are stacked, and it lines them up, edge to edge, biggest to smallest, all facing the same way.

Then it goes back to the dark.""",
                        "On Bonfire Night you watched the Guest stack the empty trays, biggest to smallest.",
                        ["bonfire-watched"], f"{T}.embers"),
                 choice("ask-momort", "Follow Momort and ask what he meant.",
                        """You find him by the stable wall, warming his hands.

“Old kitchen manners,” he says. “There are things that keep a house, and they don't work for thanks. Thank them and you've paid them. Pay them and they've got to go.” He watches the sparks. “And a thing that's been sent away hungry for long enough doesn't come back the same.”

He doesn't say anything else. He doesn't need to. I'm shut tight.""",
                        "On Bonfire Night Professor Momort told you why you never thank the things that keep a house.",
                        ["bonfire-momort"], f"{T}.embers",
                        [memory("professor-kyle-momort", "the-guest.bonfire.reader-asked",
                                "On Bonfire Night the reader followed Professor Momort to the stable wall and asked why nobody should thank the Guest.",
                                aside="You followed me. Good. People who ask are harder to fool.")]),
             ]),
        node(f"{T}.embers", "Embers",
             """By midnight the bonfire's a red heap, ticking to itself. Everybody's gone in.

Penny's still at the toffee table with *The Middlemost Cookery* open under a lantern, going through it page by page with her finger. She doesn't find another gap tonight.

She doesn't close the book either.""",
             "Keep this leaf.",
             braid="On Bonfire Night Penny found the first letter missing from Ambrose's cookbook: the T in treacle.",
             memories=[memory("penny-blackletter", "the-guest.bonfire.lantern",
                              "After the bonfire Penny sat up with The Middlemost Cookery under a lantern, checking every page for gaps.",
                              aside="One gap. One. I checked every page twice. One is how it starts.",
                              gossip="{teller} says a letter's gone missing from Ambrose's cookbook. Just vanished. Penny's beside herself.")]),
    ],
    prompt="Read on, then choose.", room="location-kitchens",
    cast=["ambrose-trencher", "dr-vellum", "lydia-boggle", "penny-blackletter", "professor-kyle-momort"],
    report="Three nights after All Souls, Dr. Vellum asked to examine the Guest; Ambrose refused, and Professor Boggle confirmed the house rule. On Bonfire Night Penny found the T missing from treacle in The Middlemost Cookery, and Professor Momort warned students never to thank the Guest.",
    report_after=5, tags=("three-nights",))


# MARK: 3. Flat — Martinmas, live day 10

F = "the-guest.scene.flat"
FLAT = scene(
    F, "Flat",
    [
        node(f"{F}.entry", "Flat",
             """It's Martinmas, and the Great Hall's gone very quiet at supper.

There's goose. There's always goose at Martinmas, a big crackling brown one for every table, and red cabbage, and roast potatoes with crunchy edges. It looks wonderful. It smells wonderful. The whole Hall's full of the smell of it, warm and fat and gold.

Nobody can taste it.

You can see it go round the Hall, table by table. Somebody takes a bite and stops chewing. Somebody else frowns at a potato as if it's told a lie. A first-year puts down his fork and says, loudly, “Is it me?”

It isn't him. It's everybody.

Pippa stands up on her bench.

“It's the punctuation,” she says. “Somebody's taken the full stop off the gravy. Gravy without a full stop just goes *on.*”

Nobody laughs. That's how I know it's bad.

It's been ten days since the Guest came. I've been counting. The Guest's the stranger in the green coat who knocked at the Kitchens' west door on All Souls' Eve, and Ambrose fed it, and it never left. It sleeps on the stool by the Kitchens fire. Every night every pot in the house gets scrubbed, and nobody owns up. At first everybody said *them*. Now everybody says *it*. I don't know when that changed.

And nobody thanks it. Not for anything. Professor Momort says thanks are a kind of payment, and you don't know what you'd be paying for. So when it fills your glass, you say nothing. Or you say *I'm grateful*. Never the other thing.

At the end of the Hall, by the door to the Kitchens, the Guest is going round the tables with a big jug of water, filling up glasses. Nobody asked it to. At every place, it stops for just a moment, and leans a little over the plate, the way you'd lean over a flower.

Then it moves on. And the next plate goes flat.

Serenity's sitting near the window. She's got a plate of goose in front of her and she hasn't touched it. She's watching the Hall. And then she starts to laugh.

It's a surprised laugh. It comes out of her before she can stop it, bright and sudden, like a bird getting out of a box.

Everybody turns to look.

“Sorry,” she says. “Sorry. It's just—” She picks up her fork. She puts down her fork. “Now you know.”

“Know what?” says Pippa.

“What it's like.” Serenity pushes her plate away an inch. “I haven't tasted anything since October. Not since the Count. It all tastes like paper. I've been eating paper for six weeks and smiling about it.”

The Hall's quieter than I've ever heard it. Even the fire's listening.""",
             "Supper's over.",
             [choice("to-the-kitchens", "Go down to the Kitchens.",
                     "You go down the back stairs, where it's warm, and the smell of bread meets you halfway.",
                     "At the Martinmas supper nobody could taste their food, and Serenity told the Hall she hasn't tasted anything since October.",
                     ["flat"], f"{F}.kitchens",
                     [memory("pippa-pilcrow", "the-guest.flat.full-stop",
                             "At the Martinmas supper Pippa stood on her bench and blamed the flat gravy on a missing full stop.",
                             aside="I still say it was the full stop. Gravy needs ending."),
                      memory("serenity-brown", "the-guest.flat.laughed",
                             "At the Martinmas supper Serenity laughed out loud and told the Hall she's tasted nothing but paper since October.",
                             aside="Everybody knows now. It's oddly nice. Six weeks of paper and now we're all eating it.")])]),
        node(f"{F}.kitchens", "Martinmas bread",
             """Later, in the Kitchens, Ambrose is halving loaves.

It's a Martinmas thing. Saint Martin was a soldier, in the old story, who met a beggar at a gate on a freezing night and cut his own cloak in two with his sword to share it. So at Martinmas Ambrose cuts every loaf in half, and keeps one half, and puts the other half in a basket by the door, for whoever needs it.

He cuts one more than usual. He takes the extra half over to the stool by the fire and puts it in the Guest's clean hands.

The Guest eats it. Ambrose watches.

*The Middlemost Cookery*'s on the dresser, wrapped in its tea towel. That's Ambrose's old cookbook. Since Bonfire Night, letters have been going out of it, one at a time. They don't fall out. They leave. Ambrose doesn't open it in front of people any more.

Serenity's come down too. She's sitting on the end of the long table with her boots swinging, the way she sits on everything, and she's watching the Guest as well. You've set me down beside her.

“It does it to every plate,” she says, quietly. “Have you seen? It leans over. Like it's smelling them. And then they're gone.”

I'd tell her she's right, if I could tell her things. I can't. I press my corner against her map case instead, and she looks down at me, and then at the Guest.

Because it's true. The Guest went round every place in the Hall. It leaned over every plate. When it got to Serenity's, it leaned, and stopped, and its hood turned up towards her face for a long moment.

Then it moved on. There was nothing on her plate for it to take.

Serenity turns her mug of tea round and round in her hands.

“It looked at me,” she says. “Like I was a jar it couldn't get the lid off.”""",
             "She's waiting to see what you'll say.",
             [
                 choice("tell-her", "Tell her you saw it too.",
                        """You tell her you saw it lean over her plate and stop.

She nods, slowly. She doesn't look frightened. She looks interested, the way she looks at a map with a blank bit in the corner.

“Then there's one plate in this Academy it can't eat from,” she says. “Good. Somebody ought to be keeping an eye on it.”""",
                        "On Martinmas you told Serenity you'd seen the Guest stop at her plate.",
                        ["flat-told"], f"{F}.close",
                        [memory("serenity-brown", "the-guest.flat.reader-saw",
                                "On Martinmas the reader told Serenity they'd seen the Guest stop at her plate and move on.",
                                aside="You saw it too. One plate it can't eat from. Mine. I'm going to keep an eye on it.")]),
                 choice("ask-what-she-misses", "Ask her what she misses tasting most.",
                        """She doesn't answer straight away. She looks at the fire.

“Rain,” she says. “Isn't that stupid? You can't taste rain. But I used to stick my tongue out at it, up on the roof, and it tasted of tin and the sky. I miss that.”

She drinks her paper tea. Behind her, the Guest's hood turns, very slightly, towards the word *rain.*""",
                        "On Martinmas Serenity told you she misses the taste of rain.",
                        ["flat-rain"], f"{F}.close",
                        [memory("serenity-brown", "the-guest.flat.rain",
                                "On Martinmas the reader asked Serenity what she misses tasting most, and she said the rain.",
                                aside="Rain. I told you rain. Tin and the sky. Don't laugh. You didn't laugh.")]),
                 choice("say-nothing", "Say nothing. Sit with her.",
                        """You don't say anything. You sit with her on the end of the long table, and swing your boots too, and watch the fire.

After a while she bumps her shoulder against yours.

“Thanks,” she says. Then she remembers, and goes pink, and glances at the stool by the fire. “I mean. I'm grateful.”

The Guest doesn't look round. But I see its clean hands go still.""",
                        "On Martinmas you sat with Serenity on the end of the long table and said nothing.",
                        ["flat-sat"], f"{F}.close",
                        [memory("serenity-brown", "the-guest.flat.sat",
                                "On Martinmas the reader sat with Serenity on the end of the long table and said nothing, which helped.",
                                aside="You just sat there. Swinging your boots. It was the best thing anyone did all day.")]),
             ]),
        node(f"{F}.close", "The basket by the door",
             """When the Kitchens are empty, the basket of half-loaves by the door is still full.

In the morning it isn't. Nobody saw who took them. Every half's gone, and the basket's been put back exactly where it was, and the cloth's been folded on top of it into a neat square.""",
             "Keep this leaf.",
             braid="On Martinmas nobody could taste their supper. Ambrose halved the loaves and gave the Guest the extra half.",
             memories=[memory("ambrose-trencher", "the-guest.flat.basket",
                              "On Martinmas Ambrose halved the loaves and gave the Guest an extra half; by morning the basket by the door was empty.",
                              aside="Halved the bread. Gave it the extra half. You don't skip a guest because the soup's gone wrong.",
                              gossip="{teller} says Serenity can't taste anything. Hasn't since October. She laughed in the middle of supper and told everyone.")]),
    ],
    prompt="Read on, then choose.", room="location-great-hall",
    cast=["serenity-brown", "ambrose-trencher", "pippa-pilcrow"],
    report="At the Martinmas supper nobody in the Great Hall could taste their food. Serenity Brown told the Hall she hasn't tasted anything since October. In the Kitchens Ambrose halved the loaves and gave the Guest the extra half.",
    report_after=11, tags=("flat",))


# MARK: 4. The Rescue — live day 13

R = "the-guest.scene.the-rescue"
RESCUE = scene(
    R, "The Rescue",
    [
        node(f"{R}.entry", "Two hundred and fourteen",
             """Penny's been up all night with *The Middlemost Cookery*.

That's Ambrose's cookbook. He bought it at an estate sale thirty years ago, and he's carried it in his apron pocket ever since, wrapped in a tea towel. On Bonfire Night Penny found the first letter gone out of it: the T in *treacle*. It wasn't smudged. It wasn't torn. It was just gone.

She's got it open on the long table, with a lamp on each side and a magnifying glass and a stack of index cards a hand high. She's gone through it page by page and written down every missing letter. Her eyes are red. Her pencil's worn to a stub.

“Two hundred and fourteen,” she says. “Since Bonfire Night. The S's are going fastest. Then the E's. The Christmas pudding's lost all its spices. The gingerbread's lost its *bread.*” She doesn't look at the stool by the fire when she says the next bit. “The first one went four days after the Guest came.”

Ambrose stands at her shoulder. He's gone grey under his kitchen colour.

“Thirty years,” he says. “I've had that book thirty years.”

“There's something else.” Penny turns the pages back. “Look. Stone soup.”

The stone soup page is whole. Every letter's there, crisp and black. *Put a clean stone in the pot. Tell everybody you're making soup.*

“You made it on Thursday,” says Penny. “For the second-years. And the soda bread, there, you made on Tuesday. And the leek and potato. All whole.”

She sits back. She looks at Ambrose the way she looks at a piece of evidence that's finally decided to speak.

“The only recipes keeping their letters,” she says, “are the ones somebody's making.”

The Kitchens go very quiet. By the fire, the Guest's scrubbing a pan that's already clean, in its green coat, with its sleeves rolled up four times.

Ambrose ties his apron tighter.

“Then we cook,” he says.""",
             "By the afternoon the Kitchens are full.",
             [choice("help-cook", "Roll up your sleeves.",
                     "You set me on the dresser, out of the way of the flour, and roll up your sleeves.",
                     "Penny counted two hundred and fourteen missing letters and found that only the recipes somebody was making stayed whole. Ambrose said, “Then we cook.”",
                     ["rescue-cook"], f"{R}.cooking",
                     [memory("penny-blackletter", "the-guest.rescue.night",
                             "Penny sat up all night counting missing letters in The Middlemost Cookery and found the pattern by morning.",
                             aside="Two hundred and fourteen. And a pattern. I'd rather have the pattern than the sleep.")])]),
        node(f"{R}.cooking", "Everybody cooks",
             """It's chaos.

There are second-years making scones you could build a wall with. There's a boy from the Glint Hall crying over an onion, and he isn't sad, it's just the onion. Professor Boggle's making soda bread with her sleeves pushed up to the elbow and flour in her eyebrows. Pippa's going round correcting the recipe cards. “A *pinch*,” she's telling a first-year, “is not a measurement. It's a threat.”

Ambrose stands in the middle of it all with a wooden spoon, saying “Lower the heat. Lower. Lower. Good,” to everyone at once.

And Wicker Eddies is making an omelette.

He's never made an omelette. He's never made anything, as far as I know, unless you count trouble. He's got the pan far too hot and he's got eggshell in it and he's frowning at it with the most serious face I've ever seen him wear. He doesn't look at Serenity, at the far end of the table. He looks at the pan as if the pan is a dare.

When it's done, it's brown on one side and runny on the other. He puts it on a plate. He walks it down the whole length of the long table and sets it down in front of her, and walks away again before she can say anything.

Serenity looks at the omelette. She takes a bite. She can't taste it. Everybody knows she can't.

She eats the whole thing anyway, slowly, without a word.

Soren's at the dresser, doing something nobody else has noticed. He's laying out teaspoons. Each one's got a tiny taste on it: a grain of sea salt, a drop of honey, a curl of lemon peel, a smear of mustard, a single blackcurrant. Beside each spoon there's a folded paper slip with a number on it, one to nine.

When Serenity gets up to put her plate away, the first slip's sitting on her map case. It says, in Soren's small careful hand: *Start at the dresser. Go in order. Don't skip seven.*

She stands there holding it. She doesn't open the rest. But she puts it in her pocket.""",
             "The afternoon goes on.",
             [choice("stay-on", "Stay till the end of the afternoon.",
                     "You stay. The light goes long and gold across the flour on the table, and then it goes.",
                     "The whole Academy cooked. Wicker made his first omelette for Serenity, and Soren laid out nine teaspoons of tastes.",
                     ["rescue-afternoon"], f"{R}.min-seo",
                     [memory("wicker-eddies", "the-guest.rescue.omelette-scene",
                             "Wicker made his first omelette and carried it the whole length of the long table to Serenity.",
                             aside="Brown on one side. Runny on the other. She ate all of it. She can't even taste it. She ate all of it."),
                      memory("soren-ng", "the-guest.rescue.spoons-scene",
                             "Soren laid out nine teaspoons of tastes on the dresser and left the first numbered slip on Serenity's map case.",
                             aside="Nine spoons. She kept the first slip. That's all I know so far. That's plenty."),
                      memory("serenity-brown", "the-guest.rescue.ate-it",
                             "Serenity ate Wicker's first omelette to the last bite, slowly, without tasting any of it.",
                             aside="Eggshell. I could feel the eggshell. Couldn't taste a thing. Ate it all. Don't ask me why."),
                      memory("pippa-pilcrow", "the-guest.rescue.pinch",
                             "In the full Kitchens Pippa went round correcting recipe cards and told a first-year a pinch is a threat.",
                             aside="A pinch is a threat. I stand by it. Write down the grams like a person."),
                      memory("lydia-boggle", "the-guest.rescue.soda-bread",
                             "Professor Boggle made soda bread in the full Kitchens with her sleeves pushed up and flour in her eyebrows.",
                             aside="I had flour in my eyebrows for two days. Nobody told me. I'm choosing to be grateful about it.")])]),
        node(f"{R}.min-seo", "What do you need?",
             """At the end of the afternoon, when the Kitchens have gone quiet and sticky, Min-seo Kim does something nobody else has thought to do.

She goes and sits on the floor by the stool, beside the Guest. Not too close. Close enough.

“Can I ask you something?”

The hood turns.

“You've been here two weeks. Everybody's been talking about you. Nobody's asked you anything.” She pulls her knees up. “What do you need?”

The Guest is quiet for a long time. The fire ticks. I'm holding my breath, as much as a book can.

“Something I used to have,” it says, at last.

“What was it?”

“I don't remember.” The clean hands turn over, palms up, empty. “That's why I'm eating. I'm looking for it. I think it tasted of this house.”

Then Ambrose turns round from the range, and looks at you.

“Your kitchen counts too,” he says. “Whatever you make out there, where you live. It counts. A recipe's only alive while somebody's making it. So make something.”""",
             "What do you bring?",
             [
                 choice("bring-own", "A recipe from your own kitchen.",
                        """You tell Ambrose about something you make at home. Something you don't even look up any more.

He listens the way he listens to a pan: completely. When you're done, he nods once.

“That'll keep,” he says. “Write it down in the Book. Then make it. In that order or the other one, I don't mind which.”""",
                        "You promised Ambrose a recipe from your own kitchen.",
                        ["rescue-own"], f"{R}.close",
                        [memory("ambrose-trencher", "the-guest.rescue.reader-own",
                                "In the full Kitchens the reader told Ambrose about something they make at home without looking it up.",
                                aside="You told me about the thing you make. I've been thinking about it. Make it.")]),
                 choice("rescue-one", "Go and rescue one from someone else.",
                        """“Good,” says Ambrose. “Those are the ones in the most danger. The ones only one person knows. Ask somebody how they make the thing they make. Write it down before it goes.”

He gives you a soul cake for the road. It tastes of nutmeg. It tastes of something.""",
                        "You went out to rescue a recipe that only lives in someone's head.",
                        ["rescue-other"], f"{R}.close",
                        [memory("ambrose-trencher", "the-guest.rescue.reader-rescue",
                                "The reader went out to rescue a recipe that only lives in someone's head, with a soul cake for the road.",
                                aside="You went to get one off somebody. Those are the ones that go first. Bring it back.")]),
                 choice("ask-guest", "Ask the Guest what it used to eat here.",
                        """You ask it.

The hood turns towards the fire, and stays there a long time.

“Something warm,” it says. “Left out at night. In a bowl by the hearth. Nobody said who it was for. Everybody knew.” Its hands close. “I can't remember what was in it. I can remember that I scrubbed the pots after.”

At the range, Ambrose has stopped stirring.""",
                        "The Guest told you it used to eat something warm, left out in a bowl by the hearth.",
                        ["rescue-bowl"], f"{R}.close",
                        [memory("min-seo-kim", "the-guest.rescue.bowl-heard",
                                "Min-seo heard the Guest tell the reader it used to eat something warm left out in a bowl by the hearth.",
                                aside="A bowl by the hearth. Nobody said who for. I've been thinking about that all night.")]),
             ]),
        node(f"{R}.close", "Restored",
             """That night Penny checks *The Middlemost Cookery* again.

The soda bread's whole. The leek and potato's whole. And on the scones page, three letters have come back that weren't there in the morning. An S. Two E's. Crisp and black, as if somebody's just written them in.

Penny writes a new number on a fresh index card, under the old one. *Restored: 3.*

She pins it to the Kitchen door, where everybody'll see it. Two columns: *Missing*, and *Restored*.""",
             "Keep this leaf.",
             braid="The whole Academy started cooking, because a recipe only stays alive while somebody's making it. Three letters came back.",
             memories=[memory("min-seo-kim", "the-guest.rescue.asked-scene",
                              "Min-seo was the only one who sat by the Guest and asked what it needed; it said something it used to have.",
                              aside="Nobody'd asked it anything in two weeks. Two weeks! I'd have bitten someone.",
                              gossip="{teller} says Wicker cooked. Actually cooked. An omelette. For Serenity. With eggshell in it.")]),
    ],
    prompt="Read on, then choose.", room="location-kitchens",
    cast=["ambrose-trencher", "penny-blackletter", "wicker-eddies", "soren-ng", "min-seo-kim", "serenity-brown",
          "lydia-boggle", "pippa-pilcrow"],
    report="Penny counted two hundred and fourteen letters missing from The Middlemost Cookery and found that only the recipes being made kept theirs, so the whole Academy started cooking. Wicker made his first omelette. Soren laid out nine teaspoons of tastes. Min-seo asked the Guest what it needed.",
    report_after=14, tags=("the-rescue",))


# MARK: Real-world crossings

def crossing(id, title, opening, invitation, return_prompt, braid, kept):
    return {
        "id": id, "packID": PACK_ID, "eventID": EVENT_ID, "title": title, "opening": opening,
        "prompt": "Take this with you.", "detail": "", "choices": [], "entities": ["The Book"],
        "tags": [EVENT_ID, "real-world-crossing"], "missionInvitation": invitation,
        "missionReturnPrompt": return_prompt, "responsePlaceholder": return_prompt,
        "braidText": braid, "missionKeptResponse": kept, "allowsFindingUse": True,
    }


MADE_FOR_YOU = crossing(
    "the-guest.mission.made-for-you", "Something Somebody Used to Make",
    """It's All Souls. That's the night, in the old stories, when everybody who used to sit at your table comes back to see how you're getting on.

I don't know about that. I'm a book. But I know about this.

Somebody used to make something for you. It doesn't have to be anything special. It almost never is. Toast cut into soldiers. A soup when you were ill. The sandwich in your school bag. A cake on one particular day of the year that only ever smelled like that on that day.

Some of the people who made those things are far away now. Some of them are gone. Some of them are in the next room and haven't made it in years.

Make it. This week, if you can. It doesn't have to be right. It'll be nearly right, and nearly right is the whole point.

Then come back and give me one sentence about it. What it smelled like, maybe. That's the bit I can't get by myself.""",
    "Make something somebody used to make for you. Bring back one sentence about it.",
    "It smelled like…",
    "You made something somebody used to make for you, and brought back what it smelled like.",
    "I've got it. Ambrose would say that's the whole of cooking: putting something back on the table that was missing.")

RESCUE_A_RECIPE = crossing(
    "the-guest.mission.rescue-a-recipe", "Rescue a Recipe",
    """There's a recipe near you that's in danger.

It isn't written down anywhere. Somebody makes it by feel. They've made it a hundred times. If you asked them how much salt, they'd say “enough,” and hold up a pinch of air.

Those are the ones that go first. They live in one person's hands, and hands get old, and move away, and stop.

Find one. Ask somebody how they make the thing they make. Your grandad's chilli. A friend's soup. The thing somebody at work brings to every party. Your own, even, if you're the only one who knows it.

Write down what they tell you, exactly as they say it. *Enough* is a real measurement. *Till it looks right* is a real time.

Then bring me one sentence: whose it is, and what it's called. I'll keep it where it can't go missing.""",
    "Ask somebody how they make the thing they make. Write it down. Bring back whose it is.",
    "It's…'s, and it's called…",
    "You rescued a recipe that only lived in somebody's hands, and brought back whose it was.",
    "Kept. Safe now. The Cookery's got one more page it didn't have before, and so have I.")

FEED_SOMEONE = crossing(
    "the-guest.mission.feed-someone", "Feed Somebody",
    """Ambrose has a rule. He's never written it down, so I'm writing it down for him.

When somebody's having a hard time, don't ask them what's wrong. Put something in front of them. Then walk away before they can make a fuss.

That's all. That's the rule.

This week, feed somebody. Make something and give it away. A plate. A jar. A slice of something in a napkin. Toast counts. A cup of tea left by somebody's elbow counts.

Don't wait to be thanked. Ambrose never does.

Then give me one sentence about who you fed. You don't have to say their name if you don't want to. Just what you gave them, and what their face did.""",
    "Make something and give it to somebody. Bring back one sentence about what their face did.",
    "I gave them…",
    "You fed somebody and walked off before they could make a fuss.",
    "That's the whole trick. Ambrose would say so, if he ever said anything about it.")

SET_A_PLACE = crossing(
    "the-guest.mission.set-a-place", "Set a Place",
    """Ambrose sets a place at the long table for whoever's missing. He doesn't say who. Everybody knows.

You can do it too, if you want. One meal this week. Put out one more plate, or one more cup, or just a spoon. For somebody who used to sit with you, or somebody far away, or somebody you haven't met yet.

You don't have to tell anybody why. You don't have to tell me who.

If you want to, bring me one sentence afterwards. What you put out. Or nothing at all. Some places at the table are meant to stay quiet.""",
    "Set one more place at one meal this week, for whoever's missing.",
    "I set out…",
    "You set a place at the table for whoever's missing.",
    "I've kept it. I won't say who it was for. Nobody ever does.")

CROSSINGS = [
    (MADE_FOR_YOU, "all-souls", 0, 6, 13, None),
    (RESCUE_A_RECIPE, "guest-right", 7, 14, 21, None),
    (FEED_SOMEONE, "the-offer", 15, 21, 27, None),
    (SET_A_PLACE, "the-bowl", 25, 29, 29, None),
]

SCENES = [KNOCK, THREE_NIGHTS, FLAT, RESCUE] + [c[0] for c in CROSSINGS]


def _scene_atom(s, phase, min_day, max_day, priority="spine", deps=()):
    return atom(s["id"], s["title"], "storyScene", "storyScene", phase, min_day, max_day,
                interaction="choice", priority=priority, occurrence={"kind": "untilResolved"},
                tags=("story",), dependencies=deps)


SCENE_ATOMS = [
    _scene_atom(KNOCK, "all-souls", 0, 1, priority="milestone"),
    _scene_atom(THREE_NIGHTS, "all-souls", 2, 6),
    _scene_atom(FLAT, "guest-right", 10, 12, priority="milestone"),
    _scene_atom(RESCUE, "guest-right", 13, 16, deps=(needs(FLAT["id"]),)),
]

for mission, phase, start, end, return_end, _ in CROSSINGS:
    a = atom(mission["id"], mission["title"], "storyScene", "storyScene", phase, start, end,
             interaction="fieldMission", priority="featured", occurrence={"kind": "untilResolved"},
             tags=("crossing",))
    a["missionReturn"] = {
        "placement": {"lifecycleStage": "live"},
        "gate": {"allOf": [{"kind": "worldEvent", "worldEvent": {
            "eventIDs": [EVENT_ID], "runIDs": [], "phaseIDs": [], "phaseRoles": [],
            "lifecycleStages": ["live"], "activationModes": [], "minimumLiveDay": start,
            "maximumLiveDay": return_end}}], "anyOf": [], "noneOf": []},
    }
    SCENE_ATOMS.append(a)
