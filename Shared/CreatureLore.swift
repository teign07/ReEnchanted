import Foundation

/// What people have said about animals, held back until the reader meets one.
///
/// The Correspondences shelf already knows how to print inherited lore, so this
/// is that shape and not a new one. The difference is when it arrives. A static
/// list of thirty animals the reader has never seen is a field guide; the same
/// thirty rows, each appearing the day its animal turns up in a photograph, is
/// a grimoire filling itself in. Nothing here is a claim about the reader and
/// nothing here ever becomes one — `observable` is nil on every row, which is
/// the same law the rest of the inherited library runs under.
///
/// Several of these are true and say so. A crow really does remember a face for
/// years. Squirrels really do plant forests by forgetting. The tension between
/// the rhyme and the fieldwork is the best thing on the shelf, so where the
/// Book knows the difference it says which is which.
enum CreatureLore {

    static let packID = "creature-lore"

    /// The lore for one creature, if the Book has any.
    static func lore(for creature: String) -> InheritedCorrespondence? {
        byCreature[VisualFact.normalized(creature)]
    }

    /// Rows for creatures the reader has actually filed, in the order the
    /// entries arrive. The shelf never shows lore for an animal they've never
    /// met: the whole point is that it unlocks.
    static func rows(for creatures: [String]) -> [InheritedCorrespondence] {
        creatures.compactMap(lore(for:))
    }

    static let pack = CorrespondencePack(
        id: packID,
        displayName: "What the Animals Are Supposed to Mean",
        version: "1.0",
        author: "The Book",
        availability: .bundledFree,
        correspondences: rowsByCreature.map(\.1)
    )

    private static let byCreature: [String: InheritedCorrespondence] = {
        var map: [String: InheritedCorrespondence] = [:]
        for (creature, row) in rowsByCreature { map[creature] = row }
        return map
    }()

    private static func row(
        _ creature: String,
        _ subject: String,
        _ sense: String,
        _ tradition: String,
        _ lore: String,
        weight: Int = 5
    ) -> (String, InheritedCorrespondence) {
        (creature, InheritedCorrespondence(
            id: "creature-\(creature.replacingOccurrences(of: " ", with: "-"))",
            subject: subject,
            sense: sense,
            lore: lore,
            tradition: tradition,
            source: .folk,
            // Lore-only, permanently. The Book files what it saw; what people
            // have said about it is furniture, and furniture doesn't get to
            // become evidence about the reader.
            observable: nil,
            tags: ["creature", creature],
            packID: packID,
            weight: weight
        ))
    }

    // MARK: The file

    static let rowsByCreature: [(String, InheritedCorrespondence)] = [

        row("magpie", "Magpie", "one for sorrow, two for joy",
            "British counting rhyme, written down by 1780",
            "There's a counting rhyme for magpies and nearly everyone in Britain knows it without remembering learning it. One for sorrow, two for joy, three for a girl, four for a boy. People still salute a lone one to cancel it out. I like that a bird got a whole rhyme with a small apology built into it."),

        row("crow", "Crow", "a face they don't forget",
            "Folklore is worldwide. The face-memory is fieldwork, University of Washington",
            "Crows are supposed to carry messages between here and wherever the dead went. I can't check that one. The part I can check is stranger: they really do remember individual human faces for years, and they tell the other crows. Somebody who wronged a crow years ago is still being shouted at by birds that weren't there."),

        row("raven", "Raven", "thought, and memory",
            "Norse, and the Tower of London",
            "Odin kept two ravens, Huginn and Muninn — thought and memory — and sent them out every morning to see what the world was doing. He said he worried more about Memory not coming back. Six of them live at the Tower of London because of a story that the kingdom falls if they leave, and nobody has been brave enough to test it."),

        row("robin", "Robin", "somebody come back to check on you",
            "British and Irish folk custom",
            "In Britain and Ireland a robin turning up right after a death is somebody stopping in. Harming one is meant to be very bad luck, and the robin has clearly worked this out, because it'll stand a foot from your boot and stare at you until you move first."),

        row("wren", "Wren", "king by a technicality",
            "European folk tale, widely told",
            "The birds agreed that whoever flew highest would be king. The eagle won, right up until the wren climbed out of the eagle's back feathers and went a little higher. Europe's smallest bird holds the title on a cheat and every other bird let it stand."),

        row("swallow", "Swallow", "one, and what it doesn't make",
            "Aristotle, Nicomachean Ethics, and European household custom",
            "One swallow doesn't make a summer. Aristotle wrote that down, so people have been saying it for two thousand three hundred years without much improvement. A swallow nesting on your house is luck across most of Europe. Knocking the nest down is very much not."),

        row("starling", "Starling", "nobody's in charge",
            "Observed behaviour; the seven-neighbour model is Italian, 2008",
            "A murmuration has no leader. Each bird watches about seven of the ones nearest it, and the whole enormous shape falls out of that and nothing else. Thousands of birds moving as one thing with nobody deciding. Standing under one is the closest most people get to watching maths happen outdoors."),

        row("owl", "Owl", "knowing, and bad timing",
            "Greek and Roman, and they disagreed",
            "An owl out in daylight is a warning almost everywhere. Athens put one on the coins for wisdom. Rome thought one on your roof meant a death in the house. Same bird, opposite conclusions. It simply looks like it knows something, and every country filled that in differently."),

        row("heron", "Heron", "standing still on purpose",
            "Widely attested wherever there are marshes",
            "A heron will stand in cold water without moving for the better part of an hour. Not waiting — hunting, at a speed your eye can't follow. Every culture near a marsh decided this meant patience. Watch one for a while. It changes how long you're willing to stand somewhere yourself."),

        row("swan", "Swan", "a pair, and a very long grudge",
            "Irish: the Children of Lir",
            "Swans pair for years, and the Children of Lir spent nine hundred of them as four. They're also the only bird most people are genuinely frightened of. Both facts get repeated about them and neither one ever gets dropped."),

        row("seagull", "Seagull", "sailors, and weather coming",
            "Coastal folk custom, British Isles and Brittany",
            "Gulls were sailors who didn't come back, which is why some coasts still won't harm one. When they come inland and stand about in a car park, there's weather out at sea. The bird knows before the forecast does and has never been thanked for it."),

        row("pigeon", "Pigeon", "the ones that came back",
            "Homing behaviour is unexplained; Cher Ami is documented, 1918",
            "A pigeon called Cher Ami carried a message through with a bullet in her chest and saved a couple of hundred men. Pigeons find their way home from places they have never been, and nobody can fully say how. The bird you step around outside the shop is a navigational instrument nobody has managed to take apart."),

        row("duck", "Duck", "the weather, and not minding it",
            "Weather lore; the heat exchange is anatomy",
            "Ducks are supposed to get loud before rain. What's certain is that a duck standing in freezing water is fine and has arranged not to feel it — warm blood going down through its feet heats the cold blood coming back up. It isn't enduring the pond. It genuinely isn't cold."),

        row("goose", "Goose", "the ones that woke the city",
            "Roman: the geese of Juno, 390 BC",
            "Geese in the temple of Juno heard raiders coming up the Capitoline in the dark and made enough noise to wake Rome. The city held. Geese have never once been described as pleasant, and on the evidence they were right not to be."),

        row("bird", "A bird", "the one you couldn't name",
            "The oldest kind of note there is",
            "Sometimes all I can tell is that it was a bird. That's still worth writing down. Half of birdwatching has always been a shape going past too fast to name, and people have kept lists of those for three hundred years anyway."),

        row("cat", "Cat", "a threshold, and what's on the other side",
            "Contradictory across Europe, which is the interesting part",
            "Cats end up on both sides of nearly every door in folklore. Lucky in one country, unlucky in the next, always at a boundary. The one thing everybody agrees on is that a cat staring hard at a corner where nothing is happening is worth getting up to look at."),

        row("dog", "Dog", "the one who knows first",
            "Universal, and mostly true for dull reasons",
            "Dogs are supposed to know first. Weather, illness, whoever's coming up the path. Most of it is true and the reason is boring — they hear it and smell it long before you can. Knowing why doesn't make it less useful to you."),

        row("fox", "Fox", "cleverer than the story needs",
            "Japanese kitsune; European beast fables",
            "Every country with foxes in it has a fox who talks. In Japan they're kitsune and grow another tail each century. Across Europe they're the one who wins by being quicker rather than stronger. Nobody anywhere ever made the fox the honest character, and the fox has never once complained about the casting."),

        row("hare", "Hare", "not a rabbit, and possibly not a hare",
            "British and Irish witch lore",
            "Hares were where witches went when they wanted to be somewhere else. Out in the open in March, boxing, plainly furious about something. A hare is a rabbit that never agreed to be one."),

        row("rabbit", "Rabbit", "the first word of the month",
            "British and North American household custom",
            "Saying rabbit rabbit as the first words you say on the first of the month is meant to bring luck for the whole of it. Small, silly, and entirely free, which is the kind of magic that survives longest. Set yourself an alarm."),

        row("squirrel", "Squirrel", "burying more than it can find",
            "Observed; the forests are the evidence",
            "A squirrel buries thousands of nuts in a season and loses track of a good share of them. The forgotten ones become trees. Every oak wood you have ever walked through is partly a filing error. I find that enormously reassuring and I think you might too."),

        row("deer", "Deer", "the white one you shouldn't follow",
            "Celtic and Arthurian",
            "The white stag turns up over and over as the thing that leads a hunter off the edge of the map and into the other place. It's never presented as the deer's fault. Somebody always follows it anyway."),

        row("horse", "Horse", "iron, the right way up",
            "European; the argument is unresolved",
            "The horseshoe goes above the door and the argument about which way up has been running for centuries. Points up holds the luck in. Points down pours it over whoever walks under. The iron was always the actual point — the fae are supposed to hate it — and the horse simply happened to be wearing some."),

        row("cow", "Cow", "lying down before the rain",
            "Farming lore; the science shrugs politely",
            "Cows lying down in a field is supposed to mean rain coming. Farmers have believed it a very long time and researchers have mostly shrugged. They do lie down more in cool, damp air. That's either the whole answer or an excellent alibi."),

        row("sheep", "Sheep", "the one that finds the gap",
            "Shepherds' counting, and everybody's insomnia",
            "Counting sheep to sleep comes from shepherds who genuinely had to count them, at the end of a day, in poor light. There is always one that has found a gap in the wall nobody knew was there. Every flock has it and no wall survives it."),

        row("pig", "Pig", "cleverer than you were told",
            "Widely underestimated",
            "Pigs solve puzzles, use mirrors to find food behind them, and learn their own names faster than most dogs. Nearly every language uses them as an insult about mess. Somebody clearly met one, lost an argument, and never let it go."),

        row("mouse", "Mouse", "the one behind the wall",
            "Sailors' word-avoidance, North Sea coasts",
            "A mouse in the wall is the oldest housemate there is. At sea it was terrible luck to say the word at all, so crews called them everything except their name. Anything you can hear and never see ends up with a nickname eventually."),

        row("hedgehog", "Hedgehog", "a slander that lasted six hundred years",
            "English parish records; the accusation is false",
            "Hedgehogs were accused for centuries of drinking milk straight out of cows in the field, and parishes paid bounties for dead ones. It isn't true, and hedgehogs are largely lactose intolerant, so the story was cruel as well as wrong. Somebody saw one in a field near a cow, once, and it ran for six hundred years."),

        row("bat", "Bat", "the wrong bird, at the right hour",
            "Filed with birds until Linnaeus",
            "Bats were filed with the birds for centuries and were never birds. They come out at the exact hinge of the day, which is the hour everything gets a reputation. The bat has never bothered to defend itself and I respect that."),

        row("bee", "Bee", "told first, or they leave",
            "English and Welsh custom, still practised into the last century",
            "Somebody has to go and tell the bees. A death in the family, a marriage, a move — someone walks out to the hives and says it out loud, and drapes them in black if it was a death. If nobody tells them, the bees leave, or die. I think about this more than I should."),

        row("butterfly", "Butterfly", "a soul, mid-change",
            "Greek: psyche means both",
            "Greek used one word, psyche, for butterfly and for soul, and never seems to have felt the need to separate them. Plenty of places will tell you the first butterfly you see in a year sets the colour of that year. Whatever you make of that, a creature that dissolved itself completely and came back out with wings has earned the comparison."),

        row("moth", "Moth", "the lamp, and whatever it means by it",
            "Symbolism worldwide; the lamp remains unexplained",
            "Moths get called souls in a lot of places, mostly because of what they do around a lamp. Nobody has fully explained the lamp. The best guess is that they navigate by the moon and a bulb ruins the arithmetic. A creature undone by a light it mistook for the moon is a fair thing to put in a book."),

        row("spider", "Spider", "patience, and rain",
            "Half of Europe says one thing, half says the other",
            "Killing a spider brings rain in about half of Europe. Leaving one alone brings money in the other half. Both can't be right. What's true either way is that something in your house worked all night on a thing you'll walk straight through tomorrow without noticing."),

        row("dragonfly", "Dragonfly", "the devil's darning needle",
            "American and northern European nursery threat",
            "Dragonflies were supposed to sew shut the lips of children who told lies. Somebody invented that to quiet one specific child and it worked well enough to cross a continent. In fact they're among the most successful hunters alive and catch very nearly everything they go after."),

        row("ladybug", "Ladybird", "counting the spots",
            "European; the rhyme is grim",
            "The rhyme sends the ladybird home because her house is on fire and her children are gone. Bleak, for a children's verse. In parts of Europe the spots are the number of happy months coming. Landing on you is luck everywhere, and nobody ever counts the spots on the ones that don't land."),

        row("ant", "Ant", "carrying more than it should",
            "Aesop, and every paving stone",
            "An ant carries many times its own weight, and every one you see is running an errand for somebody it has never met. Aesop used them to shame a grasshopper, which was unkind to both. I'd rather watch the one hauling a crumb the size of its own head across a paving slab."),

        row("snail", "Snail", "carrying the house",
            "Weather lore, and an observation",
            "A snail leaves a written line behind it and can't read it back. Old weather lore says a snail climbing high means rain coming. Mostly it's the animal that has most visibly reached the same decision you did about staying in."),

        row("frog", "Frog", "rain, and being something else first",
            "Weather lore, and every transformation story",
            "Frogs mean rain in nearly all weather lore and transformation in nearly all stories, and they get to mean both because they genuinely do both. Something that was a swimming thing with a tail and is now a sitting thing with legs has earned a bit of symbolism."),

        row("snake", "Snake", "shedding, and starting again",
            "Ouroboros, and the rod of Asclepius",
            "A snake leaves its entire skin behind in one piece. That's why it ended up meaning renewal almost everywhere, and why the ouroboros eats itself forever, and why the medical staff still has one wrapped round it. Very few animals got a better deal out of symbolism."),

        row("fish", "Fish", "silence, and knowing",
            "Irish: the Salmon of Knowledge",
            "The Salmon of Knowledge ate nine hazelnuts and knew everything there was, and then a boy burned his thumb on it while cooking it and got the lot by accident. Fish keep turning up in stories as the thing that knows and cannot say."),
    ]
}
