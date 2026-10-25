"""Six short scenes between the eight. They fill the quiet days and are optional:
each one depends on the scene before it, so it never takes that scene's place
on the desk, and each one tells a reader who's been away who the Guest is and
what the month's about, by showing it again."""

from content_common import memory, needs
from content_scenes import choice, node, scene, _scene_atom, THREE_NIGHTS, RESCUE
from content_scenes2 import STIR_UP, TABLE


# MARK: The Pot Watch — live days 7 to 8

P = "the-guest.scene.pot-watch"
POT_WATCH = scene(
    P, "The Pot Watch",
    [
        node(f"{P}.entry", "Under the long table",
             """Wicker's decided to catch whoever scrubs the pots.

It's been a week since the Guest came. That's the stranger in the long green coat who knocked at the Kitchens' west door on All Souls' Eve, and ate a soul cake by the fire, and never left. Every morning since, somebody's scrubbed every pot in the Kitchens and hung it back on its hook, biggest to smallest, handles all one way. Ambrose didn't do it. Nobody did it. That's what everybody says. Wicker says nobody isn't a person, and he's going to see their face.

So it's eleven at night, and the three of you are under the long table with a blanket and a bag of bonfire toffee left over from Thursday. You, and Wicker, and Soren, who says he's only come to stop Wicker doing anything stupid. I'm on your knees. My leaves are shut. I keep them shut after dark now.

The fire's banked down to a red heap. The Guest's asleep on its stool beside it, with the hood up and the sleeves of the coat rolled four times, and its clean hands folded in its lap. It doesn't move. I don't think it's breathing. I don't want to check.

“If it's the Guest,” Wicker whispers, “I'm going to say thanks. Just to see what happens.”

“Don't,” says Soren. “Momort said. Never thank it.”

“Momort says loads of things.”

“He said that one plainly. He never says anything plainly.”

Wicker eats a piece of toffee very loudly. That means Soren's won.

At midnight Soren's asleep sitting up, with his chin on his chest. At one, Wicker's asleep with his mouth open, holding the toffee hammer.

At three, the scrubbing starts.

It's a small sound. Round and round. A pot hums when it's being scrubbed. I didn't know that. And under the pot's humming there's another hum, very low, with no words in it. It's an old tune. I don't know its name. I think it knows mine.

You're the only one awake. You and me.""",
             "Somebody's scrubbing in the dark.",
             [
                 choice("look", "Look.",
                        """You lift the edge of the blanket.

It's the Guest. It's at the big sink with its back to you, in its green coat, scrubbing the copper jam pan. Slowly. Round and round, the way you'd stroke a dog. It's humming. When the pan's done it holds it up to the red light of the fire and looks at itself in the copper. Then it hangs the pan on its hook, in exactly its place.

The stool by the fire's empty. I didn't hear it get up. Nobody ever does.""",
                        "Under the long table at three in the morning, you watched the Guest scrub the copper jam pan.",
                        ["pot-watch-looked"], f"{P}.morning"),
                 choice("listen", "Shut your eyes and listen.",
                        """You shut your eyes. I'm already shut.

You listen to the whole Kitchens being scrubbed, pot by pot, big ones and little ones, with the humming going on under it. It's somebody doing the washing-up. That's all it is. It's the most ordinary sound there is, and my spine's gone cold all the way down, and I don't know why.

Somewhere around four, you fall asleep too.""",
                        "Under the long table you lay with your eyes shut and listened to every pot in the Kitchens being scrubbed.",
                        ["pot-watch-listened"], f"{P}.morning"),
                 choice("thank-it", "Say thank you into the dark.",
                        """“Thank you,” you say, into the dark. Not loud.

The scrubbing stops.

It stops dead, in the middle of a pot. There isn't any sound at all. The fire doesn't tick. Wicker doesn't snore. I can't smell anything, and I can always smell something.

It goes on for a long time. Long enough for me to think of every story I've ever held where somebody said the wrong word at the wrong time.

Then the scrubbing starts again. Slower. The humming doesn't.

I don't speak to you till morning. I'm not cross with you. I'm scared. I don't know the difference very well yet.

In the morning there's one little milk pan left in the sink, half done.""",
                        "Under the long table you said thank you into the dark, and the Guest's humming stopped.",
                        ["pot-watch-thanked"], f"{P}.morning",
                        [memory("soren-ng", "the-guest.pot-watch.milk-pan",
                                "The morning after the pot watch Soren found one milk pan left half scrubbed in the sink, for the first time since All Souls.",
                                aside="One pan. Half done. Somebody said it, didn't they. I was asleep. I should've been awake.")]),
             ]),
        node(f"{P}.morning", "The morning",
             """In the morning the pots are hung, biggest to smallest, handles all one way. The Guest's asleep on its stool as if it's never moved.

Wicker wakes up with toffee stuck to his cheek and says he saw the whole thing. He didn't. Soren wakes up and says nothing. He goes and looks very closely at the copper jam pan, and then at the Guest's clean hands, and then at you.

“Well?” he says.

Ambrose comes in in his nightshirt, finds three students crawling out from under his table, and puts the kettle on without a word.""",
             "Keep this leaf.",
             braid="A week after All Souls, three of you sat up under the long table to see who scrubs the pots.",
             memories=[memory("wicker-eddies", "the-guest.pot-watch.hammer",
                              "Wicker sat up under the long table to catch whoever scrubs the pots, and fell asleep at one holding the toffee hammer.",
                              aside="I saw everything. I saw most of it. I saw the start of it.",
                              gossip="{teller} says Wicker sat up all night to catch the pot-scrubber and fell asleep holding a toffee hammer."),
                       memory("soren-ng", "the-guest.pot-watch.went-to-stop-him",
                              "Soren went under the long table to stop Wicker thanking the Guest, and fell asleep sitting up at midnight.",
                              aside="I went to stop him saying it. Then I fell asleep first. That's two jobs I didn't do.")]),
    ],
    prompt="Read on, then choose.", room="location-kitchens",
    cast=["wicker-eddies", "soren-ng"],
    report="A week after All Souls, Wicker Eddies and Soren Ng sat up under the long table in the Kitchens to catch whoever scrubs the pots at night. Both fell asleep. In the morning the pots were done.",
    report_after=8, tags=("pot-watch",))


# MARK: Salt — live day 9, the night before Martinmas

S = "the-guest.scene.salt"
SALT = scene(
    S, "Salt",
    [
        node(f"{S}.entry", "Three pinches",
             """Ambrose has salted the stock three times, and it's still not right.

He stands at the range with the big stock pot, tasting off the end of a wooden spoon. He frowns. He adds a pinch. He tastes. He adds another. He's been the Academy's cook for thirty years. He doesn't salt twice. I've never seen him do it.

“It isn't the salt,” says Dr. Vellum.

Dr. Vellum's at the end of the long table with her notebook, a thermometer, the brass kitchen scales and six first-years. Every first-year's got a cup of the stock and a pencil and a card that says, at the top, *TASTE, 1 TO 10.*

Vellum isn't allowed to examine the Guest. That's the stranger in the green coat who knocked at the west door on All Souls and has slept on the stool by the fire ever since. Ambrose said no, on the third night. Professor Boggle said the house said no too: once somebody's eaten at your hearth three nights they're a guest, and nobody pokes a guest. So Vellum's examining the soup instead.

“Same bones,” she says, reading out of her notebook. “Same weight of salt. Same onions. I weighed them. Same temperature, to the degree. And every night since Thursday it scores lower.” She holds up the cards. “Tonight's average is four. One of them's written, *Tastes like soup somebody told me about.*”

“Food's fuel,” says Ambrose, without turning round. “You've always said so. So why do you care what it tastes of?”

Vellum opens her mouth. She shuts it again. She writes something down and doesn't show anybody.

I know this. I know it from somewhere. Everything going a bit less every day, so slowly that nobody says anything till it's gone. I hate it. I hate it more than anything there is.

On the stool by the fire the Guest's eating a bowl of the same stock, slowly, with the hood up. It's the only one in the Kitchens who's asked for seconds.""",
             "The stock's going round.",
             [
                 choice("taste-it", "Taste the stock yourself.",
                        """You take a cup and drink.

It's stock. It's hot and it's salty and there are onions in it. Everything's in it. It just tastes far away. It tastes like it's in the next room.

“Well?” says Vellum, holding out a card.

You give it a number. She writes it down. She doesn't say what it means, and that's how I know she doesn't know either.""",
                        "The night before Martinmas you tasted Ambrose's stock for Dr. Vellum's panel, and it tasted far away.",
                        ["salt-tasted"], f"{S}.close"),
                 choice("watch-guest", "Watch the Guest eat.",
                        """You watch it.

Before every spoonful the Guest stops. It leans over the bowl, just a little, the way you'd lean over a flower, and breathes in. Then it eats.

Then it leans over the next spoonful.

I've watched it eat for nine days. I've never seen it do that before tonight. I don't like that I've seen it now.""",
                        "The night before Martinmas you watched the Guest lean over its bowl and breathe in before every spoonful.",
                        ["salt-watched"], f"{S}.close"),
                 choice("ask-vellum", "Ask Vellum what she wrote down.",
                        """“Nothing,” says Vellum. Then, because she's honest, she turns the notebook round.

It says: *Fuel doesn't go flat.* It's underlined twice.

“That isn't a finding,” she says. “It's a worry. I don't write those down, usually.” She turns the notebook back.""",
                        "The night before Martinmas Dr. Vellum showed you what she'd written: fuel doesn't go flat.",
                        ["salt-vellum"], f"{S}.close",
                        [memory("dr-vellum", "the-guest.salt.reader-asked",
                                "The reader asked Dr. Vellum what she'd written about the stock, and she showed them: fuel doesn't go flat.",
                                aside="You asked. I showed you. Don't tell Ambrose it was underlined twice.")]),
             ]),
        node(f"{S}.close", "Tomorrow",
             """When the first-years have gone up to bed, Vellum stays. She sits at the long table with her notebook till the fire's low.

On the last line of the page she writes: *Tomorrow is Martinmas. Goose for the whole Hall.* And under that, after a long time: *Watch the plates.*

Ambrose puts a cup of tea down by her elbow. She drinks it. It tastes of tea. Nearly.""",
             "Keep this leaf.",
             braid="The night before Martinmas Ambrose salted the stock three times, and Dr. Vellum wrote down: watch the plates.",
             memories=[memory("dr-vellum", "the-guest.salt.panel",
                              "Dr. Vellum ran a panel of six first-years on Ambrose's stock and found it tasted of less every night, with nothing changed.",
                              aside="Same bones, same salt, lower every night. I've written down a worry. I never write those down.",
                              gossip="{teller} says Vellum's measuring the soup now, since she isn't allowed to measure the Guest."),
                       memory("ambrose-trencher", "the-guest.salt.three-pinches",
                              "The night before Martinmas Ambrose salted the stock three times and it still wasn't right.",
                              aside="Three times. I don't salt twice. I've never salted twice in my life.")]),
    ],
    prompt="Read on, then choose.", room="location-kitchens",
    cast=["ambrose-trencher", "dr-vellum"],
    report="The night before Martinmas Dr. Vellum ran a tasting panel on Ambrose's stock. Nothing in it had changed, and it scored lower every night. She wrote down: watch the plates.",
    report_after=9, tags=("salt",))


# MARK: Nine Spoons — live days 15 to 16

N = "the-guest.scene.nine-spoons"
NINE_SPOONS = scene(
    N, "Nine Spoons",
    [
        node(f"{N}.entry", "The dresser",
             """It's past midnight, and Serenity's laying nine teaspoons out on the dresser in the Kitchens, in a row.

They're Soren's. He laid them out on the afternoon the whole Academy cooked, each with a tiny taste on it and a folded paper slip beside it, numbered one to nine. Serenity only took the first slip. It says: *Start at the dresser. Go in order. Don't skip seven.* She's carried it round in her pocket ever since.

In the morning the spoons were washed and back in the drawer. Everything in the Kitchens gets washed in the night, and nobody does it. And the other eight slips had gone. Nobody knows where.

So she's doing it again herself, from memory. She looked at them very hard that afternoon. She's good at remembering where things go. That's what maps are. Sea salt on one. Honey on two. Lemon peel, mustard, one blackcurrant, a fleck of black pepper. She puts them on, one by one.

Then she gets to seven, and stops.

“I can't remember seven,” she says. “I think it was empty. Why would he leave one empty?”

She leaves it empty. She does eight and nine: a shred of mint, one grain of sugar.

The trouble is, Serenity can't taste. She hasn't since October, since the Count. Everything tastes of paper to her. And this month the rest of the Academy's food's been going the same way, ever since the Guest came. The Guest's asleep right now on its stool by the fire, in its green coat, with its sleeves rolled up four times.

So nine tastes on nine spoons is either a very kind thing or a very stupid one. Serenity's trying to work out which. She's been trying for ten minutes.

You're here because you couldn't sleep. You've got me under your arm.

“Will you do them with me?” she says. “I'll eat them. You tell me what they're like. Properly. Like you're telling somebody who's never had them.”

That's a job. I love it when somebody gives you a job.""",
             "Spoon one's waiting.",
             [
                 choice("tell-her", "Tell her what they taste like.",
                        "You pick up the first spoon and hand it to her.",
                        "After midnight you told Serenity what Soren's spoons tasted like, one by one.",
                        ["spoons-told"], f"{N}.spoons"),
             ]),
        node(f"{N}.spoons", "One to seven",
             """Spoon one's a grain of sea salt. She eats it. You tell her it's a spark on your tongue. It's the sea when a wave smacks you in the face. She's drawn the sea a hundred times. Now she knows what it's like.

Spoon two's honey. You tell her it's slow, and it's a summer afternoon, and it sticks to the back of everything. Three's lemon peel, and you tell her it's loud and it's yellow. Four's mustard, and you tell her it goes up your nose and shouts. Five's one blackcurrant, and you tell her it's purple. Purple isn't a taste. Except it is.

She eats every one. She can't taste any of them. She listens to you with her eyes shut, very hard.

Six is the pepper. It makes her sneeze, and she laughs, because a sneeze is something.

Then seven.

Spoon seven's empty. There's nothing on it at all. It's clean and cold, and there's no slip to say what it's for. She's had nothing on her tongue since October. And Soren put a spoon of it in the row and told her not to skip it.

By the fire, the Guest's hood turns towards the dresser. It's awake. I don't know how long it's been awake.

Serenity holds spoon seven for a long time.""",
             "She's holding the empty spoon.",
             [
                 choice("ask-her", "Ask her what nothing tastes like.",
                        """She puts the empty spoon in her mouth and takes it out again.

“Like licking a page,” she says, to the dresser. “Like the bit after somebody's stopped talking.” She stops. “Lonely. That's what it tastes like. Lonely.”

Then she does eight and nine on her own, and you don't have to tell her what they are.""",
                        "Serenity told you what nothing tastes like: lonely.",
                        ["spoons-lonely"], f"{N}.dawn",
                        [memory("serenity-brown", "the-guest.spoons.lonely",
                                "The reader asked Serenity what nothing tastes like, at Soren's seventh spoon, and she said lonely.",
                                aside="Lonely. I said it out loud. To a dresser. You were there, so it counts.")]),
                 choice("let-her-skip", "Tell her she can skip it.",
                        """“He said don't skip seven,” she says. “He wrote it down. Soren doesn't write things down for nothing.”

She doesn't eat it. She wraps spoon seven in a napkin and puts it in her map case, with her maps.

“Later,” she says. “By myself.”""",
                        "You told Serenity she could skip the seventh spoon, and she kept it in her map case instead.",
                        ["spoons-kept"], f"{N}.dawn",
                        [memory("serenity-brown", "the-guest.spoons.kept-seven",
                                "The reader told Serenity she could skip Soren's seventh spoon, and she put it in her map case to do by herself.",
                                aside="I've still got seven. I haven't done it. I'm going to. Don't ask me when.")]),
                 choice("eat-nothing-too", "Eat nothing with her.",
                        """You take an empty spoon out of the drawer and hold it up. She looks at it. She looks at you.

You both put your spoons in your mouths at the same time.

Yours tastes of spoon. You tell her so. She laughs so hard she has to sit down on the floor.

“Now there's two of us,” she says.""",
                        "You ate an empty spoon with Serenity at the same time, so there were two of you.",
                        ["spoons-together"], f"{N}.dawn",
                        [memory("serenity-brown", "the-guest.spoons.two-of-us",
                                "The reader ate an empty spoon at the same moment as Serenity, so she wasn't eating nothing on her own.",
                                aside="It tasted of spoon, you said. That's the funniest thing anyone's said to me since October.")]),
             ]),
        node(f"{N}.dawn", "Six o'clock",
             """Soren comes down at six for his tea and finds the spoons laid out on the dresser again, in a row, one to nine.

He stands there a long time, looking at them. He doesn't ask who did it. He knows. Then he picks them all up and washes them, very carefully, and dries them, and puts them back in the drawer. He goes up to breakfast whistling. I've never heard him whistle.

Wicker's left something on the dresser too. It's a recipe card, pinned down with a fork, in letters an inch high: *OMELETTE (FIXED). Less hot. No shells. More nerve.*

It doesn't say who it's for.

The Guest's asleep again on its stool. The pots are scrubbed. They always are.""",
             "Keep this leaf.",
             braid="In the middle of the night Serenity went through Soren's nine spoons, and seven was empty.",
             memories=[memory("serenity-brown", "the-guest.spoons.nine",
                              "In the middle of the night Serenity went through Soren's nine teaspoons while the reader told her what each one was like.",
                              aside="I couldn't taste one of them. I heard every one. That isn't nothing.",
                              gossip="{teller} says Serenity went through Soren's spoons in the middle of the night. Nobody knows what she did about seven."),
                       memory("soren-ng", "the-guest.spoons.cleared",
                              "Soren came down at six and found his nine spoons laid out again on the dresser, and knew Serenity had been through them in the night.",
                              aside="She went through them. I'm not going to ask her about seven.")]),
    ],
    prompt="Read on, then choose.", room="location-kitchens",
    cast=["serenity-brown", "soren-ng"],
    report="After the Academy's day of cooking, Serenity Brown laid out Soren Ng's nine teaspoons of tastes again from memory and went through them in the night. She couldn't remember what went on the seventh.",
    report_after=16, tags=("nine-spoons",))


# MARK: The Tray — live day 17

Y = "the-guest.scene.the-tray"
TRAY = scene(
    Y, "The Tray",
    [
        node(f"{Y}.entry", "Up the back stairs",
             """Every night at seven Ambrose sends a tray up to the Headmistress.

He's done it for thirty years. Soup, bread, a bit of whatever's on, a pot of tea, and a cloth over the top. Headmistress Thorne eats in her study at the top of the tower, on her own. She's never once eaten in the Kitchens. Ambrose used to say that was manners.

This month the tray's been coming back untouched.

Every night. The soup cold, the bread whole, the cloth still folded. Ambrose doesn't say anything about it. He scrapes it into the pig bucket and looks at the stool by the fire, where the Guest's sitting in its green coat, eating its second helping. It's been on that stool since All Souls. Seventeen days. I've been counting.

Tonight Ambrose gives the tray to you.

“Take it up,” he says. “She'll open the door to a student. She won't to me, this month.”

So you're on the back stairs with the tray, and me under your arm, going up. The stairs go round and round. The soup's getting cold. That's a waste, because tonight it nearly tastes of soup.

Halfway up, you stop.

There's somebody on the stairs below you. Coming up behind, very quietly.

It's the Guest.

It's never left the Kitchens. Not once. It stops two steps below you and looks up the stairwell with its hood tipped back, at the dark at the top, where the Headmistress's door is.

Then the door at the top opens, and Thorne's standing in it.""",
             "The Headmistress is looking down the stairs.",
             [
                 choice("stand-still", "Stand still between them.",
                        "You don't move. The tray rattles a bit. I don't.",
                        "On the tower stairs you stood still with the Headmistress's tray, between her and the Guest.",
                        ["tray-stood"], f"{Y}.stairs"),
             ]),
        node(f"{Y}.stairs", "Not on my stairs",
             """Thorne comes down three steps. She's tall and dark, in her long black coat, and she stops with the tray between her and the Guest. She doesn't look at the tray. She looks past you, down at the hood.

The Guest bows. It bows low. Lower than anybody bows at the Academy. It's the bow out of an old story, where the one bowing's been told exactly how low to go.

Thorne doesn't bow back.

“Not on my stairs,” she says. She says it quietly. She doesn't sound cross. She sounds like somebody reading out a rule.

The Guest straightens up. It looks at her for a long moment. Then it goes back down, round and round, without a sound, and it's gone.

Thorne lifts the cloth off the tray. She looks at the soup. She puts the cloth back.

“Tell Mr. Trencher,” she says, “that I'm grateful.”

Then she goes back up and shuts her door, and the tray's still in your hands.

*I'm grateful.* Those are Momort's words. They're the old ones, for the ones you mustn't thank. He said them at the bonfire, to students.

Nobody's told the Headmistress. I'm nearly sure nobody has.""",
             "You've still got the tray.",
             [
                 choice("take-it-down", "Take the tray back down to Ambrose.",
                        """You carry it all the way back down. Ambrose looks at the full bowl. He looks at you.

“She say anything?”

You tell him. He stands very still with the tray.

“Grateful,” he says. “Thirty years. She's never said that.”

He doesn't scrape it into the pig bucket. He eats the soup himself, standing up, cold.""",
                        "You carried the Headmistress's full tray back down, and Ambrose ate her cold soup himself.",
                        ["tray-returned"], f"{Y}.later",
                        [memory("ambrose-trencher", "the-guest.tray.cold-soup",
                                "The reader carried the Headmistress's full tray back down, and Ambrose ate her cold soup standing up.",
                                aside="Grateful. Thirty years of trays and she's never said it. I ate the soup. Somebody had to.")]),
                 choice("knock", "Knock and ask her why she won't eat.",
                        """You knock. Nothing. You knock again.

From the other side of the door, very close, the Headmistress says: “Because I know whose table it is.”

Then her footsteps go away.

I don't know which table she means. I think about it all the way down the stairs, and I still don't.""",
                        "You knocked on the Headmistress's door, and she said she knows whose table it is.",
                        ["tray-knocked"], f"{Y}.later",
                        [memory("headmistress-thorne", "the-guest.tray.whose-table",
                                "The reader knocked on Headmistress Thorne's door to ask why she won't eat, and she answered through it that she knows whose table it is.")]),
                 choice("follow-guest", "Go after the Guest.",
                        """You go down after it, round and round, as fast as you can with a tray.

It's back on its stool when you get to the Kitchens, hood up, sleeves rolled, as if it's never moved. Ambrose is chopping onions. He hasn't noticed anything.

As you come in, the Guest says, to the fire, very low: “She keeps her own house.”

It doesn't say anything else all night.""",
                        "You followed the Guest back down to the Kitchens, and it said the Headmistress keeps her own house.",
                        ["tray-followed"], f"{Y}.later"),
             ]),
        node(f"{Y}.later", "The west door",
             """Later, when the Kitchens are dark, there's frost on the inside of the west door. Only there. A little fern of it, round the keyhole, where somebody's breathed on the iron from outside.

In the morning it's gone, and the pots are scrubbed.""",
             "Keep this leaf.",
             braid="The Guest followed the Headmistress's tray up the tower stairs, and she sent it down again.",
             memories=[memory("headmistress-thorne", "the-guest.tray.stairs",
                              "Headmistress Thorne met the Guest on the tower stairs, told it not on her stairs, and sent Ambrose word that she was grateful.",
                              gossip="{teller} says the Guest went all the way up the tower stairs, and the Headmistress sent it down again."),
                       memory("ambrose-trencher", "the-guest.tray.untouched",
                              "All November the Headmistress's supper tray came back untouched, until Ambrose sent it up with the reader.",
                              aside="Thirty years of trays. This month they all come back full. I've stopped asking the soup why.")]),
    ],
    prompt="Read on, then choose.", room="location-kitchens",
    cast=["ambrose-trencher", "headmistress-thorne"],
    report="All month Headmistress Thorne sent back her supper tray untouched. One night the Guest followed it up the tower stairs; she sent it down again, and told Ambrose she was grateful.",
    report_after=17, tags=("the-tray",))


# MARK: Letters Coming Home — live days 22 to 23

L = "the-guest.scene.letters-home"
LETTERS_HOME = scene(
    L, "Letters Coming Home",
    [
        node(f"{L}.entry", "Forty hands",
             """Penny's found something odd about the letters coming back.

All month, letters have been going out of *The Middlemost Cookery*, Ambrose's old cookbook. They started going on Bonfire Night, four days after the Guest came, and they only come back when somebody makes the recipe. So the Academy's been cooking, all of it, for more than a week. On the Kitchen door Penny's card says *Missing* and *Restored*, and the second number keeps going up.

Penny's got the Cookery open on the long table under two lamps. Pippa's on the bench beside her with a magnifying glass the size of a saucer. Pippa Pilcrow cares about letters more than anybody alive. She says they're the only people who never let you down.

“Look,” says Penny. “The ones that went missing were all the same. Brown ink. Somebody's neat handwriting, a hundred years old. Now look what's come back.”

You look.

The soda bread's whole again. But the second E in *soda* is round and fat and blue. It's biro. The S in *scones* has come back in thick pencil, pressed hard, the way a little kid writes. The pudding page has got a T in some grandmother's curly copperplate, with a loop on the top like a hat.

“They come back in the hand of whoever made it,” says Penny. “Every one. I've checked forty.”

Pippa's nose is an inch off the page. “That's a lefty,” she says. “Look at the slope. That one was in a hurry. And that one,” she points at a careful little R, “was somebody who'd never cooked before in their life and was scared stiff.”

Ambrose is standing behind them with a tea towel over his shoulder. He hasn't said anything. He's looking at the book. It's full of people now.

Some of the letters aren't from the Academy at all. Penny's sure. They're from out there, from people's own kitchens, wherever those are.

By the fire, the Guest's asleep on its stool in its green coat, with its clean hands open in its lap.""",
             "The Cookery's open on the table.",
             [
                 choice("look-for-yours", "Look for a letter from your kitchen.",
                        """You go through it page by page. I go with you, with my corner down on the paper, because I can smell what I can't read.

Every letter smells of where it came from. The biro E smells of a flat with the window open. The copperplate T smells of cloves and a coal fire. One S smells of nothing but chips, and it's very proud of itself.

If you've cooked something this month, it's in here somewhere. I'd know your kitchen anywhere. I've been carried through it. And if you haven't yet, there's a gap on a page that's waiting for you. It isn't going anywhere.""",
                        "You looked through The Middlemost Cookery for a letter that came home from your own kitchen.",
                        ["letters-looked"], f"{L}.close"),
                 choice("ask-pippa", "Ask Pippa which letter's her favourite.",
                        """Pippa doesn't even think about it. She turns to the parkin page and points.

It's the T in *treacle*. It's the first one that went. It's back. It's small and wobbly, and it's leaning on the R next to it. It's had a long walk.

“Wicker,” she says. “He made the parkin last week. Three times. The first two were bricks.” She puts her finger beside the T. She doesn't touch it. “Look how hard he pressed. You can feel it from the back of the page.”

She's right. I can feel it from here.""",
                        "Pippa showed you her favourite letter in the Cookery: the T in treacle, back in Wicker's hand.",
                        ["letters-pippa"], f"{L}.close",
                        [memory("pippa-pilcrow", "the-guest.letters.wickers-t",
                                "The reader asked Pippa for her favourite letter back in the Cookery, and she showed them the wobbly T in treacle that Wicker made.",
                                aside="Wicker's T. Pressed so hard you can feel it through the page. Don't tell him it's my favourite.")]),
                 choice("ask-ambrose", "Ask Ambrose whose the old handwriting was.",
                        """Ambrose takes a long time to answer.

“I always thought it was the cook's,” he says. “Whoever had these Kitchens before they were mine. Before anybody's.”

He turns to the back, to the page under the endpaper that came clear on Stir-up Sunday. *A Bowl for the One Who Keeps the Pots.* It's in the same brown ink.

“Somebody who cooked here a long time ago,” he says. “And left a bowl out every night.”

He looks at the stool by the fire. The Guest's asleep on it. It doesn't wake up.""",
                        "Ambrose told you the old brown handwriting in the Cookery belonged to whoever had the Kitchens long ago.",
                        ["letters-ambrose"], f"{L}.close"),
             ]),
        node(f"{L}.close", "A new card",
             """Before she goes to bed, Penny writes a fresh card and pins it under the count on the Kitchen door. *The letters come home in the hand of whoever made it.*

Under that, very small, she's put: *Including the ones from out there.*

In the morning somebody's straightened the card. It's perfectly level now. The pots are scrubbed.""",
             "Keep this leaf.",
             braid="The letters coming home to The Middlemost Cookery came back in the handwriting of whoever made the recipe.",
             memories=[memory("penny-blackletter", "the-guest.letters.hands",
                              "Penny found the letters coming back into The Middlemost Cookery were in the handwriting of whoever made the recipe.",
                              aside="Forty letters, forty hands. I've started a file for each one. I'm going to need more files.",
                              gossip="{teller} says the cookbook's letters come back in the handwriting of whoever made the dish. Penny's checked forty."),
                       memory("pippa-pilcrow", "the-guest.letters.magnifier",
                              "Pippa read the letters coming home to The Middlemost Cookery with a magnifying glass and could tell who'd written each one.",
                              aside="That T's a lefty. That R was scared stiff. Letters can't lie. Not to me."),
                       memory("ambrose-trencher", "the-guest.letters.everybodys",
                              "Ambrose watched Penny and Pippa read the letters coming home to his cookbook and didn't say anything for a long time.",
                              aside="Thirty years that book's been mine. It's everybody's now. I don't mind as much as I thought I would.")]),
    ],
    prompt="Read on, then choose.", room="location-kitchens",
    cast=["penny-blackletter", "pippa-pilcrow", "ambrose-trencher"],
    report="Penny Blackletter found that the letters coming back into The Middlemost Cookery come back in the handwriting of whoever made the recipe, including people cooking far from the Academy.",
    report_after=23, tags=("letters-home",))


# MARK: The Day-Book — live days 27 to 28

D = "the-guest.scene.the-day-book"
DAY_BOOK = scene(
    D, "The Day-Book",
    [
        node(f"{D}.entry", "Behind the jam",
             """It's nearly the end of November, and Ambrose can't sleep.

He's at the long table with *The Middlemost Cookery* open at the back, at the page that came clear on Stir-up Sunday: *A Bowl for the One Who Keeps the Pots.* For thirty years he's tried to read that page. Now he nearly can. The letters have come home from everybody's cooking, here and out there. All but one line at the very bottom. There's still a gap in it, as long as a few words.

He's going to cook it on the last day. He's decided. He just doesn't know how it ends.

Over by the fire the Guest's asleep on its stool. It's been there since All Souls, in its long green coat with the brass buttons and its sleeves rolled up four times. Four weeks of scrubbed pots. Four weeks of leaning over people's suppers until there was nothing left in them to taste, and then the whole Academy cooking to get it back.

Then Professor Boggle comes down the back stairs in her dressing gown with a book under her arm.

It's huge. It's bound in brown leather gone soft as a glove, and it smells of a hundred years of candle smoke. It's very old and it doesn't say hello. I like it straight away.

“The house day-book,” she says. “The Academy's household accounts, from before. I keep the rooms, so I keep the rooms' books. I've been looking for this in the Pantry drawers all month. It was behind the jam.”

She puts it on the table beside the Cookery and opens it at a page she's marked with a hair ribbon.""",
             "Boggle's opened the day-book.",
             [
                 choice("read-it", "Read it with them.",
                        "You lean in. So do I.",
                        "Near the end of November you read the old house day-book with Ambrose and Professor Boggle.",
                        ["day-book-read"], f"{D}.accounts"),
             ]),
        node(f"{D}.accounts", "The pots not done",
             """It's a list, in old brown ink. It's the same brown ink as the Cookery. One line a day, every day, all the way down the page.

*Bread, 40 loaves. Candles, 2 doz. Cream, a bowl, for the hearth.*

*Bread, 40 loaves. Coal. Cream, a bowl, for the hearth.*

*Cream, a bowl, for the hearth.*

Every night. For pages and pages. Somebody put a bowl of cream on the hearth every night and wrote it down, and never wrote who it was for. Everybody knew.

Boggle turns the page.

*Paid to the tailor, for a coat for the one that keeps the pots. Green, with brass buttons. As thanks.*

Then the next line: *The pots not done.*

And the next: *The pots not done.*

Then a whole page of it. *The pots not done. The pots not done.* After that the bowl of cream isn't written down any more.

Nobody says anything. Ambrose looks at the stool by the fire. Boggle looks at the stool by the fire. I look too, through the gap in my leaves, at the long green coat and its brass buttons. I count them. I don't know why. I want to know how many there are.

“Thanks are payment,” says Boggle, very quietly. “Momort says it. The house rules say it. Thank the ones who keep a house and you've paid them off, and once they're paid they've got to go.” She puts her finger beside the line about the coat. She doesn't touch it. “Somebody meant it kindly. They gave it a good coat.”""",
             "The Guest's still asleep.",
             [
                 choice("where-it-went", "Ask Boggle where it went, after.",
                        """“It doesn't say,” says Boggle. “The day-book's for bread and candles.”

She shuts it, very carefully.

“My grandmother kept the rooms before me,” she says. “She used to say a thing that keeps a house, sent off hungry, doesn't go anywhere good. It goes somewhere cold. Somewhere that'll feed it, and want feeding back.”

Out past the west door, the frost ticks on the iron. I hear it. I don't think they do.""",
                        "Professor Boggle told you where a thing that keeps a house goes when it's sent off hungry.",
                        ["day-book-cold"], f"{D}.frost",
                        [memory("lydia-boggle", "the-guest.day-book.grandmother",
                                "The reader asked Professor Boggle where the old keeper of the pots went, and she told them her grandmother's saying: somewhere cold.",
                                aside="My grandmother said it. Somewhere cold that'll feed you and want feeding back. I didn't like it then either.")]),
                 choice("missing-line", "Look for the missing line of the bowl page.",
                        """You put the day-book beside the Cookery, page to page, the old brown ink next to the old brown ink.

There it is. On the night before the coat, the cream's written down differently. *Oats in milk, a pinch of salt, honey, butter. Cold cream round the edge, poured last. Set on the hearth. No spoon.*

It's the bottom line of the bowl page, word for word. While you're looking, the gap in the Cookery fills itself in, letter by letter, in brown. It's been waiting a very long time to finish that sentence.

Ambrose reads it. He doesn't say anything for a while. Then he says, “No spoon,” very softly. That's the bit he's going to remember.""",
                        "You laid the day-book beside the Cookery, and the last line of the bowl page came back: no spoon.",
                        ["day-book-line"], f"{D}.frost",
                        [memory("ambrose-trencher", "the-guest.day-book.no-spoon",
                                "The reader laid the old day-book beside the Cookery, and the last line of the bowl page came back: no spoon.",
                                aside="No spoon. Thirty years and I'd have put a spoon in it. I'd have got it wrong at the very end.")]),
                 choice("send-him-to-bed", "Tell Ambrose to go to bed.",
                        """“I will,” says Ambrose. He doesn't.

Boggle doesn't go either. She sits on the bench across from him with the day-book shut under her hands. After a while he gets up and puts the kettle on, and makes her a cup of tea she didn't ask for, and puts it by her elbow.

“I'm grateful,” she says. It's the old way, the way she said it at the long table.

He doesn't walk off. He stands by the range with his own cup. They drink their tea, him standing and her sitting, and neither of them says anything else till the fire's down.""",
                        "You told Ambrose to go to bed. He didn't, and Professor Boggle stayed up with him.",
                        ["day-book-tea"], f"{D}.frost"),
             ]),
        node(f"{D}.frost", "The west door",
             """Before you go up, you look at the west door.

There's frost on the inside of it, all over the iron studs, thick as sugar. It's in the keyhole. It's on the bolts that are painted over so thick they look like knuckles. On the other side of the door, out in the dark, something's standing very still, waiting for the last day.

The Guest sleeps through all of it, in its green coat, by the fire.

In the morning the frost's gone. The pots are scrubbed.""",
             "Keep this leaf.",
             braid="Professor Boggle found the old house day-book: a bowl of cream for the hearth every night, then a green coat given as thanks, then the pots not done.",
             memories=[memory("lydia-boggle", "the-guest.day-book.coat",
                              "Professor Boggle found the old house day-book behind the jam and showed Ambrose the line about a green coat given as thanks.",
                              aside="Behind the jam. All month. I keep the rooms and I couldn't find a book behind the jam.",
                              gossip="{teller} says Professor Boggle found an old house book in the Pantry, and there's a coat in it. A green one."),
                       memory("ambrose-trencher", "the-guest.day-book.sat-up",
                              "Near the end of November Ambrose sat up with the bowl page, and Professor Boggle came down and sat up with him.",
                              aside="She came down in her dressing gown. With a book. At midnight. I didn't mind.")]),
    ],
    prompt="Read on, then choose.", room="location-kitchens",
    cast=["lydia-boggle", "ambrose-trencher"],
    report="Near the end of November Professor Boggle found the Academy's old house day-book. Every night it set out a bowl of cream for the hearth, until somebody gave the one who kept the pots a green coat as thanks. After that the pots weren't done.",
    report_after=28, tags=("the-day-book",))


INTERLUDES = [POT_WATCH, SALT, NINE_SPOONS, TRAY, LETTERS_HOME, DAY_BOOK]

ATOMS_INTERLUDES = [
    _scene_atom(POT_WATCH, "guest-right", 7, 8, priority="featured", deps=(needs(THREE_NIGHTS["id"]),)),
    _scene_atom(SALT, "guest-right", 9, 9, priority="featured", deps=(needs(THREE_NIGHTS["id"]),)),
    _scene_atom(NINE_SPOONS, "the-offer", 15, 16, priority="featured", deps=(needs(RESCUE["id"]),)),
    # Day 17 is a recap day: a beat that opens on it isn't retired by it.
    _scene_atom(TRAY, "the-offer", 17, 17, priority="featured"),
    _scene_atom(LETTERS_HOME, "the-offer", 22, 23, priority="featured", deps=(needs(STIR_UP["id"]),)),
    _scene_atom(DAY_BOOK, "the-bowl", 27, 28, priority="featured", deps=(needs(TABLE["id"]),)),
]
