import Foundation

// MARK: - The Academy curriculum
//
// Each room teaches a course, not a lesson: one lesson a month, in order, the
// same lesson for every student that month. The Academy year opens in
// September (September 2026 was its first term), so a reader who keeps a year
// of books holds the whole subject, taught twelve different ways. The room's
// class page in the app and its leaf in the monthly book read the same lesson,
// so what the reader sat is what the book prints.
//
// The courses are written from The Wonder Compass: the Art of the Glint is
// North = Notice. A room without a course yet keeps its one standing lesson
// (`AcademyScheduleRegistry.lessonModules`).

enum AcademyCurriculum {
    static let courses: [String: [AcademyLessonModule]] = [
        "art-of-the-glint": glint,
        "wayfinding-kineticism": wayfinding,
        "synesthetic-resonance": resonance,
        "ink-binding": inkBinding,
        "quiet-hours": quietHours,
        "basic-enchantments": enchantments,
        "book-jumping": bookJumping,
        "compass-running": compassRunning,
        "compass-society": compassSociety,
        "marginalia-guild": marginaliaGuild,
        "inkwright-society": inkwrightSociety,
        "book-jumpers": bookJumpers
    ]

    /// Months since the Academy's first September: 0 is September 2026.
    static func termIndex(of date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return ((parts.year ?? 2026) - 2026) * 12 + ((parts.month ?? 9) - 9)
    }

    /// The lesson a room teaches in the month of `date`.
    static func lesson(for sessionID: String, on date: Date, calendar: Calendar = .current) -> AcademyLessonModule? {
        guard let course = courses[sessionID], !course.isEmpty else {
            return AcademyScheduleRegistry.lessonModules[sessionID]
        }
        let count = course.count
        return course[((termIndex(of: date, calendar: calendar) % count) + count) % count]
    }

    /// A lesson by its id, wherever it is taught.
    static func lesson(id: String) -> AcademyLessonModule? {
        for course in courses.values {
            if let lesson = course.first(where: { $0.id == id }) { return lesson }
        }
        return AcademyScheduleRegistry.lessonModules.values.first { $0.id == id }
    }

    /// How many lessons the room's year holds.
    static func lessonCount(for sessionID: String) -> Int {
        max(1, courses[sessionID]?.count ?? 1)
    }

    // MARK: The Art of the Glint: North = Notice

    private static let northReading = "The Wonder Compass, Chapter 6A: North = Notice"

    /// A lesson's own worksheet. The kind stays the room's, so the class page handles it as it
    /// always has; only the words and the boxes change.
    private static func practice(
        _ room: String, _ id: String, kind: AcademyActivity.Kind, title: String, invitation: String, action: String,
        _ fields: [(id: String, label: String, placeholder: String)]
    ) -> AcademyActivity {
        AcademyActivity(
            id: id, sessionID: room, kind: kind,
            title: title, invitation: invitation, actionTitle: action,
            fields: fields.map { .init(id: $0.id, label: $0.label, placeholder: $0.placeholder) }
        )
    }

    private static func glintPractice(
        _ id: String, title: String, invitation: String, action: String,
        _ fields: [(id: String, label: String, placeholder: String)]
    ) -> AcademyActivity {
        practice("art-of-the-glint", "glint-\(id)", kind: .evidenceLog, title: title, invitation: invitation, action: action, fields)
    }

    /// September to August, twelve ways into one subject. Boggle's words at the board are hers:
    /// dry, plain, kitchen-table. Everything else on the leaf is the Book telling it, so it stays
    /// simple and in the third person (the class page hands these lines to the model as well).
    static let glint: [AcademyLessonModule] = [
        AcademyLessonModule(
            id: "glint-specificity-001",
            sessionID: "art-of-the-glint",
            title: "The Doorknob Test",
            realSubject: "why your own house goes invisible, and how to see it again",
            concept: "Your brain stops seeing the things it sees every day. One small true fact makes it look again.",
            lectureBeats: [
                "Your brain stops seeing the things you see every day. It's saving effort.",
                "One small true fact about a thing makes you look at it properly again.",
                "Write down what you can see first. Work out what it means after."
            ],
            demonstration: "Boggle put a teaspoon, a button and a key under the lamp. She described the key out loud, every scratch on it. After that nobody could stop looking at the key. The spoon and the button just sat there.",
            interactionPrompt: "Say one exact thing about something in this room, before you say what it means.",
            realWorldPractice: "Pick one thing at home you never look at. Write down three plain facts about it. Nothing about what it reminds you of yet.",
            number: 1,
            mode: "The big idea",
            lecture: "Before you sit down. The door you just came through. Is the handle on the left or the right? Don't turn round. You've used that door every day this month. Hands up for left. Hands up for right. Hands up for no idea. That's most of you. Good. That's honest. Your brain stops looking at things it sees every day. It's saving itself the bother. That's what the Rut does. It turns your whole house into wallpaper. You don't fix that by having a big feeling about doors. You fix it with one plain fact. Brass. A bit loose. Warm on the side the sun gets. Write the fact down first. You can decide what it means later.",
            twoMinutes: "Guess which side the handle is on the nearest door. Don't look yet. Now go and look. Write down two things about that handle you'd never noticed.",
            reading: northReading
        ),
        AcademyLessonModule(
            id: "glint-gorilla-002",
            sessionID: "art-of-the-glint",
            title: "You See What You're Looking For",
            realSubject: "why you miss things right in front of you",
            concept: "You only see what you're looking for. So pick something good to look for.",
            lectureBeats: [
                "When you're busy looking for one thing, you can miss everything else.",
                "Half the people who watched the gorilla film never saw the gorilla.",
                "You can change what you notice by changing what you look for."
            ],
            demonstration: "Boggle gave the class thirty seconds to count every blue thing in the Glint Hall. While they counted, she swapped her teacup for a jam jar. Then she asked who'd seen it. Only Wilbur had, because he'd lost count and given up.",
            interactionPrompt: "What were you looking for on your way here? What might you have walked right past?",
            realWorldPractice: "Pick one odd thing to look for today, like a red hat, a crack shaped like a letter, or anything yellow. Count how many times you find it.",
            number: 2,
            mode: "A real experiment",
            lecture: "In 1999 two scientists, Daniel Simons and Christopher Chabris, made a short film. Some students pass basketballs around. You're told to count the passes made by the team in white. Halfway through, somebody in a gorilla suit walks into the middle. They stop. They face the camera. They thump their chest. They walk off. Nine seconds of gorilla. About half the people counting never saw it. They weren't silly. They were busy counting. I've written the rule in my ledger, and I'll write it on the board as well: you see what you're looking for. That's bad news if you only ever look for jobs. It's good news, because you get to choose.",
            twoMinutes: "Pick a colour. Count every bit of it you can see from where you are. Then write down one thing you only saw because you were looking.",
            reading: northReading,
            practice: glintPractice(
                "gorilla-count", title: "The Gorilla Count",
                invitation: "Boggle wants you to go looking on purpose. Pick one thing to look for today and count it. Then write down the thing you nearly missed.",
                action: "Bring the count back",
                [("hunt", "What you looked for", "Something odd and easy to spot"),
                 ("count", "How many you found", "And where they were"),
                 ("missed", "What you nearly missed", "The thing that was there all along")]
            )
        ),
        AcademyLessonModule(
            id: "glint-filter-003",
            sessionID: "art-of-the-glint",
            title: "Teach Your Eyes What to Keep",
            realSubject: "how your brain picks what you notice, and how to change it",
            concept: "Your brain throws most things away without telling you. You can teach it to keep the good ones.",
            lectureBeats: [
                "Your brain throws away most of what you see and hear before you know it was there.",
                "It keeps things that are dangerous, urgent or new. Ordinary things go in the bin.",
                "Writing down three good things a day, for a week, teaches it to keep those too."
            ],
            demonstration: "Boggle tipped a tin of buttons onto the table. Everybody had to pick out the ones with four holes. Then she asked how many of the buttons were cracked. Nobody knew. They hadn't been looking for cracks. She tipped them out again and said, \"Cracks this time.\" Suddenly there were cracks everywhere.",
            interactionPrompt: "Name one thing your brain usually throws away that you'd like it to keep.",
            realWorldPractice: "For three days, write down three things that went well. Little ones count. Give each one a detail you could draw.",
            number: 3,
            mode: "A game",
            lecture: "Every second, your eyes and ears and skin pick up far more than you could ever think about. So something in your head sorts it, like the post. Dangerous: keep. Urgent: keep. New: keep. Same as yesterday: bin. That's why you can't remember the drive home. Here's the useful part. You can change how it sorts. In 2005 a scientist called Martin Seligman asked people to write down three things that went well every day, for one week. That's all they did. Months later those people were happier than the ones who hadn't. One week of writing taught their heads what to keep. So that's your homework. Three things. Every day.",
            twoMinutes: "Write down three things that went well today. Little ones count. Add one detail to each, something you could draw.",
            reading: northReading,
            practice: glintPractice(
                "three-kept", title: "Three Kept Things",
                invitation: "Boggle's teaching your brain what to keep. Write down three things that went well today. Little ones count. Give each one a detail you could draw.",
                action: "Hand in the three",
                [("first", "First thing", "What went well, and one detail"),
                 ("second", "Second thing", "Smaller is fine"),
                 ("third", "Third thing", "The one you nearly didn't count")]
            )
        ),
        AcademyLessonModule(
            id: "glint-light-004",
            sessionID: "art-of-the-glint",
            title: "Watch the Light",
            realSubject: "seeing your own home again by watching the light move",
            concept: "Everything in your house stays put except the light. Watch it move, and your house looks new.",
            lectureBeats: [
                "At home you stop seeing rooms. You see jobs.",
                "Light is the only thing in a house that moves around by itself.",
                "Follow one patch of light through a day and your room turns into a clock."
            ],
            demonstration: "Boggle drew a chalk mark on the floor where the morning sun landed. An hour later she drew another one. By the end of class there was a little curved line of marks, and she made everybody stand on it.",
            interactionPrompt: "Where's the light in this room right now? Where will it be in an hour?",
            realWorldPractice: "Pick one patch of light at home. Check where it is in the morning, at lunch, and late in the day.",
            number: 4,
            mode: "Homework at home",
            lecture: "Home's the hardest place to notice anything. You don't see your rooms. You see your jobs. The cup to wash. The coat to hang up. So for today, forget the jobs. Look at the light. It's the only thing in your house that moves around all day by itself. That patch of sun on the stairs came a very long way to get there. It slides across the floor because the whole world's turning under you. I've timed mine. It gets to the kettle at ten past four. Your house is a clock. Go and find out what time it says.",
            twoMinutes: "Find the nearest patch of light. What's it touching? What colour is it? Where's its edge?",
            reading: northReading + "; Chapter 17: Home",
            practice: glintPractice(
                "light-hunt", title: "The Light Hunt",
                invitation: "Boggle wants your house to be a clock. Find one patch of light. Write down where it is and what it's touching. Then come back later and see where it went.",
                action: "Report the light",
                [("where", "Where the light is", "The wall, the stairs, the floor by the window"),
                 ("touching", "What it's touching", "And what colour it makes it"),
                 ("later", "Where it went later", "Or that it's gone")]
            )
        ),
        AcademyLessonModule(
            id: "glint-fish-005",
            sessionID: "art-of-the-glint",
            title: "Look at Your Fish",
            realSubject: "looking at one thing for longer than feels sensible",
            concept: "The first look shows you what you expected. The good stuff turns up after you get bored.",
            lectureBeats: [
                "The first look only finds what you already expected.",
                "Getting bored means you're nearly at the good part. Keep going.",
                "Drawing or writing while you look slows your eyes down, so they catch more."
            ],
            demonstration: "Boggle gave everyone a teaspoon and twenty minutes. After five minutes Aria said she'd finished. After fifteen she found her own face in the bowl of the spoon, upside down, with the window behind it. She went very quiet.",
            interactionPrompt: "What did you see in your teaspoon after you thought you'd finished?",
            realWorldPractice: "Look at one small thing for ten whole minutes. Only write down what you saw after the first five.",
            number: 5,
            mode: "A true story",
            lecture: "This is a true story. In the 1850s a young man called Samuel Scudder went to study with a famous scientist, Louis Agassiz, at Harvard. On the first day Agassiz put a dead fish in a tin pan in front of him, told him to look at it, and left. After ten minutes Scudder thought he'd seen everything. After an hour he was bored stiff. So he started drawing it, and the drawing showed him things his eyes had skipped. Agassiz came back, listened, and told him to keep looking. This went on for three days. Years later Scudder wrote that it was the best lesson he ever had. You're not getting a fish. You're getting a teaspoon. And twenty minutes.",
            twoMinutes: "Look at one small thing for two whole minutes. That's longer than it sounds. Write down the last thing you noticed.",
            reading: "Samuel H. Scudder, \"In the Laboratory with Agassiz\" (1874)",
            practice: glintPractice(
                "look-again", title: "Look Again",
                invitation: "Boggle's handing out teaspoons. Look at one small thing for longer than feels sensible. Write down what turned up late.",
                action: "Bring back what you saw",
                [("object", "What you looked at", "Something small, close enough to touch"),
                 ("first", "What you saw first", "The obvious bit"),
                 ("later", "What turned up later", "What you only saw once you'd got bored")]
            )
        ),
        AcademyLessonModule(
            id: "glint-wonder-006",
            sessionID: "art-of-the-glint",
            title: "Say \"I Wonder\"",
            realSubject: "how asking a question changes what you notice",
            concept: "Saying \"I wonder\" sends your eyes out looking. Make the wonder small and sharp, so you can go and find the answer.",
            lectureBeats: [
                "\"I wonder\" stops your eyes waiting and starts them hunting.",
                "Once you're looking for something, it turns up everywhere. It was there all along.",
                "A good wonder is small enough to have an answer you could go and find."
            ],
            demonstration: "Boggle wrote \"I wonder what's in the East Wing\" on the board. The class made it sharper, one go at a time, until it said \"I wonder who winds the clock on the East Wing landing when nobody's meant to.\" Then she sent Zara to find out.",
            interactionPrompt: "Say a fuzzy wonder of your own. Now make it sharper, until it has an answer.",
            realWorldPractice: "Write one \"I wonder\" about something you could walk to. Make it sharp. Then go and find out.",
            number: 6,
            mode: "Showing how",
            lecture: "Here are the two most useful words I know. I wonder. Say them and your eyes stop waiting and start hunting. You know when you learn a new word, and then you hear it three times that same week? The word didn't follow you about. You told your brain to keep it, so it did. Wondering works the same way. But a wonder needs edges. \"I wonder what's in town\" is fog. \"I wonder if the bakery on the corner still does the twisty loaf on Saturdays\" has an answer, and you can go and get it. Keep your wonders small. The big ones take all day and get nowhere.",
            twoMinutes: "Finish this: \"I wonder…\", about something near you. Then write it again, sharper. Then once more.",
            reading: northReading,
            practice: glintPractice(
                "sharpen", title: "Sharpen a Wonder",
                invitation: "Boggle doesn't take fuzzy wonders. Write a fuzzy one. Make it sharp. Then say where the answer is.",
                action: "Hand in the sharp one",
                [("vague", "The fuzzy wonder", "I wonder what's…"),
                 ("sharp", "The sharp one", "Small enough to have an answer"),
                 ("where", "Where the answer is", "The place, the person, or the book that knows")]
            )
        ),
        AcademyLessonModule(
            id: "glint-tug-007",
            sessionID: "art-of-the-glint",
            title: "Follow the Tug",
            realSubject: "listening to your body when you choose what to look at",
            concept: "Some choices feel heavy and some feel light. Follow the light one.",
            lectureBeats: [
                "Your body has an opinion before your head does.",
                "A Should feels heavy, like leaning back. A Tug feels light, like leaning in.",
                "When you follow the Tug, noticing gets easier."
            ],
            demonstration: "Wilbur picked the oldest plaque in the Academy to study, because it was important. Boggle asked what he'd been looking at while he decided. It was a pigeon with one white foot. He said he'd much rather know where it lived. Boggle said the plaque could wait. The pigeon couldn't.",
            interactionPrompt: "What in this room would you look at if nobody was marking you?",
            realWorldPractice: "Next time you've got ten spare minutes, notice which choice feels heavy and which feels light. Do the light one.",
            number: 7,
            mode: "Someone gets it wrong",
            lecture: "You've got ten things you could look at. How do you pick one? Don't pick the one that's good for you. That's a Should. A Should sits on your chest like a wet coat. You want the Tug. The little \"huh?\" The half a smile. The feeling of leaning forward. Your body decides before your head's finished thinking, so in this room your body votes first. Try it. Think about sorting the washing. Feel that? Now think about the blue door on the lane that you've never opened. Feel that? The second one's North. Go that way.",
            twoMinutes: "Think of two things you could do next. Which one makes you lean back? Which one makes you lean in? Write down the lean-in one.",
            reading: northReading,
            practice: glintPractice(
                "tug", title: "Feel for the Tug",
                invitation: "Boggle wants your body's vote counted. Write down a Should you felt today, a Tug you felt, and which one you followed.",
                action: "Count the vote",
                [("should", "A Should", "Something that felt heavy"),
                 ("tug", "A Tug", "Something that made you lean in, even a bit"),
                 ("followed", "Which you followed", "And what happened")]
            )
        ),
        AcademyLessonModule(
            id: "glint-five-feet-008",
            sessionID: "art-of-the-glint",
            title: "Don't Move Your Feet",
            realSubject: "finding new things in a place you know by heart",
            concept: "There's always something new within five feet of you. You just have to stand still long enough to find it.",
            lectureBeats: [
                "Interesting things are close by, in the places you stopped looking.",
                "Vuja de is seeing something you know well as if it's brand new.",
                "Standing still makes you look closer instead of further."
            ],
            demonstration: "Boggle made everyone stand still in one spot for ten minutes. Zara was by the window. She found a fly stuck between two panes of glass, a date written in pencil on the frame, and an old handprint on the glass, very low down, from somebody small.",
            interactionPrompt: "Don't move your feet. Find one thing within five feet that you've never noticed in this room.",
            realWorldPractice: "Stand still somewhere ordinary today, like the sink, the bus stop or your desk. Find three things within five feet you'd never noticed.",
            number: 8,
            mode: "A rule to play by",
            lecture: "Everybody thinks the interesting things are somewhere else. Abroad. On holiday. They're about five feet from your shoes. The comedian George Carlin had a word for this: vuja de. It's déjà vu backwards. Déjà vu is when something new feels like you've seen it before. Vuja de is when something you've seen a thousand times suddenly looks brand new. You can practise it. Today's rule is simple. You're not allowed to move your feet. Everything you find has to be close enough to touch, or nearly. I tried it at my own sink. I found four things. One of them was a fork I lost in March.",
            twoMinutes: "Stay right where you are. Find three things within five feet that you've never really looked at. Write down the oddest one.",
            reading: northReading,
            practice: glintPractice(
                "five-feet", title: "Don't Move Your Feet",
                invitation: "Boggle's rule: you stay where you are. Write down where you stood, and what you found close by that you'd never noticed.",
                action: "Report from where you stood",
                [("where", "Where you stood", "An ordinary spot"),
                 ("found", "What you found", "Three things, all close enough to touch"),
                 ("strangest", "The oddest one", "And what's odd about it")]
            )
        ),
        AcademyLessonModule(
            id: "glint-label-009",
            sessionID: "art-of-the-glint",
            title: "A Name Isn't a Look",
            realSubject: "how knowing the name of something can stop you seeing it",
            concept: "When you know a thing's name, you stop looking at it. Say the name, then keep looking.",
            lectureBeats: [
                "Knowing a thing's name makes you feel like you've already looked at it.",
                "Names are good for sorting things. They're bad for seeing them.",
                "After you name something, look for what the name leaves out."
            ],
            demonstration: "Boggle held up a leaf. Everyone said \"leaf\" and started looking away. She waited. Five minutes later the board said: a bite mark, a vein that splits in two and then splits again, silver underneath, and a tiny round hole. Aria said the hole was a door. Boggle wrote that down too.",
            interactionPrompt: "Name something in this room. Now say three things about it that its name doesn't tell you.",
            realWorldPractice: "Pick something you'd usually sum up in one word, like a weed, a bus or a pigeon. Write three things about this one that the word doesn't cover.",
            number: 9,
            mode: "The usual mistake",
            lecture: "This is the mistake everybody makes, and clever people make it most. You see a bird. You think \"pigeon\". You're done. The word turns up and your looking stops, like the name was a receipt. But \"pigeon\" doesn't tell you anything about this one. The green and purple on its neck that only shows when it turns. The bad foot. The way it walks like it's late for something. A name's a drawer you put things away in. In this room we take things out of their drawers. Say the name if you have to. Then find three things it didn't tell you.",
            twoMinutes: "Pick something near you and say its name. Now find two things about this one that the name leaves out.",
            reading: northReading,
            practice: glintPractice(
                "past-the-label", title: "Past the Name",
                invitation: "Boggle won't take the name as the answer. Write the name. Then write what this one has that the name leaves out.",
                action: "Hand in what the name missed",
                [("label", "What it's called", "The one word you'd usually stop at"),
                 ("missing", "What the name leaves out", "Three things true of this one"),
                 ("detail", "The surprise", "The one you'd never have seen")]
            )
        ),
        AcademyLessonModule(
            id: "glint-map-010",
            sessionID: "art-of-the-glint",
            title: "Find the Blank on the Map",
            realSubject: "using a map to find places worth exploring near you",
            concept: "A map's full of places you've never been. Look for the odd ones, pick one, and go.",
            lectureBeats: [
                "You can read a map for mysteries as well as for errands.",
                "Green patches, odd names, roads that stop and strange shapes from above are all worth a look.",
                "Picking one exact spot turns \"I should get out more\" into a trip."
            ],
            demonstration: "Boggle unrolled the Labyrinth's map, the one that's only half drawn, and asked for its emptiest corner. The class picked a patch past the North Stair. All it had on it was a question mark in somebody's handwriting. Boggle wouldn't say whose.",
            interactionPrompt: "Think of the map you know best. Where's the emptiest bit? What do you think is there?",
            realWorldPractice: "Open a map of where you live. Find one green patch, odd name or dead-end road you could get to. Go and see it.",
            number: 10,
            mode: "A trip out",
            lecture: "You can find things to notice miles away without getting out of your chair. You just have to read a map the right way. Most people use maps for errands. Read yours for mysteries. Look for green patches you've driven past a hundred times and never walked into. Look for a street or a village with a name so odd you have to see it. Look for roads that just stop. Switch to the picture from above and look for anything that doesn't fit. A round shape in a field. A pond nobody talks about. A roof with something painted on it. Then pick one, and go. The map stays at home. You're the one who goes.",
            twoMinutes: "Open a map of where you are and zoom out a little. Find one place with a name you've never noticed, and write it down.",
            reading: northReading,
            practice: glintPractice(
                "blank-place", title: "Mark the Blank Place",
                invitation: "Boggle wants a trip out. Find one odd or empty place on the map. Say why it pulled at you, and what was really there.",
                action: "Report from the blank place",
                [("place", "The place on the map", "A green patch, an odd name, a road that stops"),
                 ("why", "Why it pulled at you", "What made you wonder"),
                 ("there", "What was really there", "Or what you think is, if you haven't been yet")]
            )
        ),
        AcademyLessonModule(
            id: "glint-shadow-011",
            sessionID: "art-of-the-glint",
            title: "Broken Things Count",
            realSubject: "noticing old, worn and broken things, and how they make you feel",
            concept: "Broken and worn-out things are worth looking at too. They've been somewhere.",
            lectureBeats: [
                "Mono no aware is the feeling you get for things because they don't last.",
                "A worn or broken thing has been used and kept, sometimes for a very long time.",
                "On a heavy day, looking at something broken can feel more honest than trying to be cheerful."
            ],
            demonstration: "Boggle brought in a cracked teapot from the Kitchens. Nobody could use it any more. She asked how many cups it had poured before it cracked. The class worked it out from the stains, and got a number so big that the room went quiet.",
            interactionPrompt: "Find the most worn-out thing in this room. Ask it one question about where it's been.",
            realWorldPractice: "On your way somewhere today, find one broken, rusty or fading thing. Look at it for ten seconds. Ask it one \"I wonder\" question.",
            number: 11,
            mode: "An old word",
            lecture: "There's an old Japanese phrase, mono no aware. It means something like \"the sadness of things\". A scholar called Motoori Norinaga wrote a lot about it, more than two hundred years ago. It's the feeling you get when blossom falls off a tree. It's sad because it doesn't last, and that's partly why it's lovely. Most of the world isn't shiny. It's rust. Peeling paint. A shop that's shut for good. You've been taught to look away from those. Don't. Ask them things instead. Who locked that door the last time? Where was this car going when it was new? On a grey day, that sort of looking is often the only sort that fits. It counts. I keep a page for it in my ledger.",
            twoMinutes: "Find the most worn-out or broken thing you can see. Look at it for ten seconds. How long has it been there? What happened to it?",
            reading: northReading,
            practice: glintPractice(
                "shadow-spark", title: "A Shadow Spark",
                invitation: "Boggle says broken things count too. Find one worn-out or fading thing. Write what it is, what you asked it, and your best guess at the answer.",
                action: "Bring back the shadow",
                [("thing", "The worn-out thing", "Rust, a crack, peeling paint, a shut shop"),
                 ("question", "What you asked it", "I wonder…"),
                 ("guess", "Your best guess", "What you think happened to it")]
            )
        ),
        AcademyLessonModule(
            id: "glint-ledger-012",
            sessionID: "art-of-the-glint",
            title: "Read Back What You Kept",
            realSubject: "reading back what you noticed, and why it makes a year feel longer",
            concept: "A year you wrote down feels longer than one you didn't. Reading it back brings the days back.",
            lectureBeats: [
                "Things you don't write down go blurry. Things you do write down come back, with the whole day around them.",
                "A month full of small new things feels longer when you look back on it.",
                "Reading your own notes shows you what your eyes like best."
            ],
            demonstration: "Boggle opened her own ledger, the neat one, and read out three things she'd noticed a year ago. One was about a teaspoon. She remembered the whole afternoon it came from, and told them all of it. Class ran ten minutes over.",
            interactionPrompt: "Say one thing you noticed early this year that you'd forgotten until just now.",
            realWorldPractice: "Read back through what you've kept this year. Copy out the three noticings that bring back their whole day.",
            number: 12,
            mode: "Looking back",
            lecture: "Last lesson of the year, and the homework's nice for once. Go back and read what you noticed. All of it. The teaspoons. The pigeons. The light on the stairs. A month you didn't write down shrinks to a smudge. A month you did is full of rooms again. Time's funny like that. Weeks full of new little things feel long when you look back. Weeks that were all the same fold up to nothing. So reading back isn't being soppy. It's proof. It says: I was awake for that. And it shows you what your eyes like best. Then next September you'll know which way to look.",
            twoMinutes: "Think of one small thing you noticed months ago. Write down everything about that day it brings back.",
            reading: "The Wonder Compass, Appendix G: the Data Reviews",
            practice: glintPractice(
                "ledger", title: "Read the Ledger",
                invitation: "Boggle's last homework of the year: read back what you kept. Copy out one thing you noticed. Then write what it brought back, and what it says about what your eyes like.",
                action: "Close the year's ledger",
                [("noticing", "Something you'd forgotten", "Copy it out"),
                 ("brought", "What it brought back", "The day around it"),
                 ("loves", "What your eyes like", "Light, faces, small broken things…")]
            )
        )
    ]

    // MARK: Wayfinding & Kineticism: East = Embark

    private static let eastReading = "The Wonder Compass, Chapter 7: East = Embark"

    private static func wayPractice(
        _ id: String, title: String, invitation: String, action: String,
        _ fields: [(id: String, label: String, placeholder: String)]
    ) -> AcademyActivity {
        practice("wayfinding-kineticism", "wayfinding-\(id)", kind: .thresholdPlan, title: title, invitation: invitation, action: action, fields)
    }

    /// Momort teaches East honestly: move first, plan exactly, bribe yourself, set a stop, cross the
    /// line. What he praises gives him away. He likes the route with trouble on it, the plan that
    /// falls apart, the first ten seconds of anything scary. A careful reader may catch the creed
    /// under it (no trouble, no story), but he never names it, and he never mixes up scary with
    /// dangerous. The other faculty don't entirely trust him, and the lessons show it.
    static let wayfinding: [AcademyLessonModule] = [
        AcademyLessonModule(
            id: "wayfinding-threshold-001",
            sessionID: "wayfinding-kineticism",
            title: "Stand Up First",
            realSubject: "why you have to move before you feel like it",
            concept: "Nobody feels like going. You move first, and the feeling catches up.",
            lectureBeats: [
                "Waiting until you feel like it doesn't work. The feeling hardly ever comes first.",
                "Moving first changes how you feel, a bit like starting a cold engine.",
                "Make the first move tiny and physical: stand up, put your shoes on."
            ],
            demonstration: "Professor Momort didn't let the class sit down. He walked them twice round the Momentum Yard while he talked, and by the second lap Finn said he felt awake for the first time all week. Momort said that was the lesson, and they could sit down now if they really wanted. Nobody did.",
            interactionPrompt: "What's the smallest move that would get you started on something today?",
            realWorldPractice: "Next time you don't feel like going, do the first physical step anyway, like shoes on or coat on. Then decide.",
            number: 1,
            mode: "The big idea",
            lecture: "Stand up. No, before you decide whether you want to. Up. Good. Now you're somebody who's standing, and it took about a second. That's the whole of my subject. Nobody feels like going. Not ever. The sofa's warm, and it knows the shape of you. If you wait until you feel like it, you'll wait for ever. So you move first, and the feeling catches you up. It's like a cold engine. You don't wait for it to want to start. You turn the key. It coughs. It complains. Then it runs. Your body's the engine, and standing up is turning the key. A day where nothing moves is a day nobody remembers. Walk with me. We'll talk on the way.",
            twoMinutes: "Stand up right now, before you decide whether you want to. Walk to the nearest door and back. Write down how you feel compared with before.",
            reading: eastReading,
            practice: wayPractice(
                "move-first", title: "Move First",
                invitation: "Momort won't let you wait until you feel like it. Pick something you've been putting off. Do the first physical step, then write how you felt before and after.",
                action: "Report the first step",
                [("putting-off", "What you were putting off", "The thing you didn't feel like doing"),
                 ("first-move", "Your first move", "Shoes on, coat on, up off the sofa"),
                 ("after", "How you felt after", "Compared with before")]
            )
        ),
        AcademyLessonModule(
            id: "wayfinding-ticket-002",
            sessionID: "wayfinding-kineticism",
            title: "Where, When, How",
            realSubject: "why exact plans happen and fuzzy ones don't",
            concept: "\"Sometime\" never comes. Say where, when and how, and you'll probably go.",
            lectureBeats: [
                "A plan with no time and no place usually doesn't happen.",
                "Writing down exactly when and where made people about three times likelier to go.",
                "Being scared into it hardly helped. Being exact did."
            ],
            demonstration: "Professor Momort made everyone write a plan on a slip of paper. Then he read them out. Every one that said \"sometime\" he screwed up and threw over his shoulder. The ones with a time and a place he pinned to the gate. By the end there were four on the gate and a little pile of paper on the floor.",
            interactionPrompt: "Take a plan of yours that says \"sometime\". Give it a day, a time and a place.",
            realWorldPractice: "Write one plan for this week with a place, a day and a time. Stick it where you'll see it.",
            number: 2,
            mode: "A real experiment",
            lecture: "Most people plan like this: I should go for a walk sometime. Sometime isn't a time. Somewhere isn't a place. In 2002 some researchers in Britain took people who wanted to exercise more and split them into three groups. The first group just kept a note of their exercise. The second group read a leaflet about heart disease first, to scare them into it. The third group read the leaflet too, and then wrote down exactly when and where they'd exercise. The first two groups did about the same. About a third of them went. The third group? Nine out of ten. Being scared hardly helped. Being exact did nearly everything. So write it like a ticket. Saturday, nine o'clock, the blue postbox, with a coffee. Sometime's where plans go to die. I don't let mine go there.",
            twoMinutes: "Think of something you keep saying you'll do sometime. Write it again with a place, a day and a time.",
            reading: eastReading,
            practice: wayPractice(
                "ticket", title: "Write the Ticket",
                invitation: "Momort only keeps plans with a time and a place on them. Write one for this week, like a ticket.",
                action: "Pin it to the gate",
                [("where", "Where", "The exact spot"),
                 ("when", "When", "The day and the time"),
                 ("how", "How", "How you'll get there, and what you'll take")]
            )
        ),
        AcademyLessonModule(
            id: "wayfinding-bribe-003",
            sessionID: "wayfinding-kineticism",
            title: "Bribe Yourself",
            realSubject: "using a treat to get yourself out of the door",
            concept: "Pair the thing you're putting off with something you love. Only let yourself have the nice thing while you're doing it.",
            lectureBeats: [
                "Most people won't do something just because it's good for them.",
                "Joining a treat to a task makes the task easier to start.",
                "The treat works best if you only get it while you're doing the thing."
            ],
            demonstration: "Professor Momort put a tin of toffees at the far end of the Momentum Yard and said they were only for people who'd walked there. Then he sat on the tin. Finn had to argue him off it, which took longer than the walk and was much more fun to watch.",
            interactionPrompt: "What treat would get you out of the door this week?",
            realWorldPractice: "Pick one treat you only get while you're doing a thing you've been putting off. Try it once this week.",
            number: 3,
            mode: "A game",
            lecture: "Nobody wants to do things because they're good for them. We're all just tall toddlers. We want biscuits. So give yourself a biscuit. Join the thing you're putting off to something you love, and only let yourself have the nice thing while you're doing the hard one. A scientist called Katherine Milkman tried it. People were only allowed to listen to the audiobooks they were hooked on while they were at the gym. They went to the gym a lot more. They wanted to know what happened next, so the story dragged them there. So the podcast you've been saving, you only get to hear it on the walk. The good chocolate, you only open at the top of the hill. Find out what you'd go a long way for. Then make it wait for you at the far end.",
            twoMinutes: "Name one thing you're putting off and one treat you love. Write a rule that joins them: \"I only get the treat while I'm doing the thing.\"",
            reading: eastReading,
            practice: wayPractice(
                "bribe", title: "Pick Your Bribe",
                invitation: "Momort wants you bribed. Pick one thing you keep putting off, one treat you love, and the rule that joins them.",
                action: "Strike the deal",
                [("task", "The thing you're putting off", "The walk, the call, the drawer"),
                 ("treat", "The treat", "Something you'd go a long way for"),
                 ("rule", "The rule", "I only get the treat while…")]
            )
        ),
        AcademyLessonModule(
            id: "wayfinding-stop-004",
            sessionID: "wayfinding-kineticism",
            title: "Say When You'll Stop",
            realSubject: "why knowing when something ends makes it easier to start",
            concept: "Decide when you'll stop before you start. Knowing there's an end makes it easier to begin.",
            lectureBeats: [
                "Your head worries about anything that might not end.",
                "A clear stop, like twenty minutes or three songs, lets you start without worrying.",
                "Turn round when you said you would, even if you're enjoying it."
            ],
            demonstration: "Professor Momort led the class out through the gate with no stop agreed. They walked until the lamps came on. Professor Stonebrook came out with a lantern and walked them all back. Momort said it was the best lesson he'd taught all term. Stonebrook didn't say anything.",
            interactionPrompt: "What stop would make something you're avoiding feel safe to start?",
            realWorldPractice: "Next time you go out, decide your stop before you leave: a time, a number of songs, or a place to turn round.",
            number: 4,
            mode: "Someone gets it wrong",
            lecture: "Professor Stonebrook has asked me to teach you this one, so I will. Before you go anywhere, decide when you'll stop. Twenty minutes. Three songs. Back before tea. Your head worries about anything with no end to it. What if it takes all day? What if I get stuck? Give it an end and it stops worrying and lets you go. That's true. I'll say it's true. I'll also say the best walk I ever took was the one where I forgot to turn round. But you're not me. Set the stop. Then see how close to it you can get.",
            twoMinutes: "Pick something you've been avoiding because it might go on for ever. Give it an end: ten minutes, three songs, one page. Write the end down.",
            reading: eastReading,
            practice: wayPractice(
                "stop", title: "Set the Stop",
                invitation: "Stonebrook made Momort teach this one. Plan one small trip, and decide before you go exactly when it ends.",
                action: "Report the stop",
                [("where", "Where you're going", "Somewhere small"),
                 ("stop", "When you'll stop", "A time, a number of songs, a place to turn round"),
                 ("kept", "Did you stop there?", "Be honest")]
            )
        ),
        AcademyLessonModule(
            id: "wayfinding-coat-005",
            sessionID: "wayfinding-kineticism",
            title: "The Going-Out Coat",
            realSubject: "how what you wear can get you out of the door",
            concept: "Keep one thing you only wear for going out. Putting it on tells your body you're going.",
            lectureBeats: [
                "Fred Rogers changed into a cardigan and trainers at the start of every show.",
                "Changing what you wear can change what mood you're in.",
                "A coat or hat you only wear for adventures makes it easier to leave."
            ],
            demonstration: "Professor Momort brought in a pile of old coats from lost property and made everybody choose one. Lara picked a long green one with brass buttons. She didn't take it off for the rest of the week. On Thursday she went somewhere in it and wouldn't say where.",
            interactionPrompt: "What would your going-out coat be?",
            realWorldPractice: "Choose one coat, hat or pair of socks that's only for going out on purpose. Wear it next time you go.",
            number: 5,
            mode: "A true story",
            lecture: "Every episode of his television show, Fred Rogers came in through the door, took off his jacket and put on a cardigan, then took off his shoes and put on trainers. Every single time. He wasn't only getting comfy. He was telling himself, and everybody watching, that something had changed. You can do the same thing the other way round. Pick one thing you only wear when you're going out on purpose. A coat. A hat. Your good socks. It doesn't have to be smart. It just has to be only for that. Then when you put it on, your body knows. We're going. It's very hard to sit back down on the sofa in your going-out coat. Try it. You'll feel silly. Good.",
            twoMinutes: "Pick one thing you own that could be your going-out coat. Put it on right now. Write down what you feel like doing.",
            reading: eastReading,
            practice: wayPractice(
                "coat", title: "Choose Your Going-Out Coat",
                invitation: "Momort wants you dressed for leaving. Pick one thing you'll only wear when you go out on purpose, and wear it once.",
                action: "Report the coat",
                [("what", "What you picked", "A coat, a hat, a scarf, your good socks"),
                 ("why", "Why that one", "What it feels like on"),
                 ("where", "Where it took you", "The first place you wore it")]
            )
        ),
        AcademyLessonModule(
            id: "wayfinding-bag-006",
            sessionID: "wayfinding-kineticism",
            title: "Pack the Bag Before You're Tired",
            realSubject: "getting ready in advance so small problems don't keep you in",
            concept: "Pack a bag for going out before you need it. When the urge comes, you just pick it up and go.",
            lectureBeats: [
                "When you're tired, small problems turn into reasons to stay home.",
                "A packed bag by the door fixes those problems in advance.",
                "What's in the bag is only for going out, never for ordinary days."
            ],
            demonstration: "Professor Momort tipped his own bag out on the floor of the Momentum Yard: a plaster, a blanket, a torch, a bar of very good chocolate, a pencil, and a note in his own handwriting that said \"Go somewhere it might not go to plan.\" Then he packed it all again in under a minute and hung it back by the gate.",
            interactionPrompt: "What usually stops you going, and what could go in the bag to fix it?",
            realWorldPractice: "Pack a small going-out bag this week and hang it by the door. Don't raid it on ordinary days.",
            number: 6,
            mode: "Showing how",
            lecture: "When you're tired, every small thing is a reason to stay in. Where's the charger? Have we got snacks? Is it going to rain? So we fix those things now, while you're not tired. Get a bag. Any bag. Put in the things that stop a trip ending early: something warm, a plaster, something dry to sit on, your charger. Put in a treat you love that you're not allowed to eat at home. Put in a notebook and a pen that works. Check the pen. Then hang the bag by the door. The rule is, you never raid the bag for ordinary life. The chocolate in the bag is for going. That way, when you get the urge, you just pick up the handle, and you're already halfway gone.",
            twoMinutes: "Find any bag. Put one treat in it that you're only allowed to eat when you go out. Hang it by the door.",
            reading: eastReading,
            practice: wayPractice(
                "bag", title: "Pack the Bag",
                invitation: "Momort wants a bag by your door. Write what goes in it: one thing that keeps you out longer, one treat, and one thing for noticing.",
                action: "Hang it by the door",
                [("keeps", "Something that keeps you out", "Warm, dry, charged"),
                 ("treat", "The treat", "Only for going out"),
                 ("noticing", "Something for noticing", "A notebook, a pen that works, a magnifying glass")]
            )
        ),
        AcademyLessonModule(
            id: "wayfinding-long-way-007",
            sessionID: "wayfinding-kineticism",
            title: "The Long Way There",
            realSubject: "turning an ordinary errand into a small trip",
            concept: "Take a different way to somewhere ordinary. The long way there, the short way back.",
            lectureBeats: [
                "The way you always go has stopped being interesting to you.",
                "A new route turns an errand into a small trip.",
                "Momort's rule: the long way there, the short way back."
            ],
            demonstration: "Professor Momort sent the class to the post room by a corridor none of them had used. It had a door that stuck and a stair with one step missing. Finn complained the whole way. At supper it was the only thing he talked about.",
            interactionPrompt: "Which way do you always go, and what's the other way?",
            realWorldPractice: "On your next errand, take the long way there and the short way back.",
            number: 7,
            mode: "A rule to play by",
            lecture: "You've got to post a letter. Boring. So go a different way. Take the side street you've never been down. The main road knows your shoes by now. It's bored of you, and you're bored of it. Here's my rule, and it's the only one I'm strict about: the long way there, the short way back. And if you've got a choice between two side streets, take the one with something in the way. A hill. A gate that sticks. A dog that barks at everybody. A walk where nothing gets in your way is a walk you won't remember by teatime. A bit of trouble is what makes it a story.",
            twoMinutes: "Think of your next errand. Plan a different way there. Write down one thing on the new way that you've never seen.",
            reading: eastReading,
            practice: wayPractice(
                "long-way", title: "The Long Way There",
                invitation: "Momort's rule: the long way there, the short way back. Take a new way to somewhere ordinary, and write what got in your way.",
                action: "Report the long way",
                [("errand", "Where you were going", "The ordinary errand"),
                 ("route", "The new way you went", "The street, the path, the stairs"),
                 ("trouble", "What got in your way", "A hill, a gate, a dog, a puddle")]
            )
        ),
        AcademyLessonModule(
            id: "wayfinding-threshold-008",
            sessionID: "wayfinding-kineticism",
            title: "The Other Side of the Door",
            realSubject: "the moment of leaving, and why old stories start there",
            concept: "Every old story starts when someone leaves home. Shutting your own front door on purpose is that moment.",
            lectureBeats: [
                "Old stories from all over the world start with somebody crossing a line.",
                "Once they're over it, the rules change.",
                "Stopping on your own doorstep for three seconds lets you feel the line."
            ],
            demonstration: "Professor Momort stood the class in the doorway of the Momentum Yard and made them wait there, half in and half out, for a whole minute. Then he stepped out and didn't look back. Most of them followed. Lara stayed in the doorway a bit longer, because she wanted to know what would happen if she didn't.",
            interactionPrompt: "What line do you cross every day without noticing?",
            realWorldPractice: "Next time you leave the house on purpose, stop on the doorstep for three seconds before you go. Feel the line.",
            number: 8,
            mode: "An old pattern",
            lecture: "In 1949 a man called Joseph Campbell wrote a book about the old stories from all over the world, and he noticed the same thing kept happening in them. Somebody leaves home. They cross a line, a door, a river, the edge of a wood, and once they're over it, the rules change. He called it crossing the first threshold. You do it every time you shut your front door on purpose. Stand on the step for three seconds. The house air's behind you. The outside air's on your face. That's the line. Nothing happens to people who stay inside. Not in the old stories, and not in yours. Everything worth telling starts on the other side of a door.",
            twoMinutes: "Go and stand in a doorway for thirty seconds, half in and half out. Write one thing you can feel on each side.",
            reading: "Joseph Campbell, The Hero with a Thousand Faces (1949)",
            practice: wayPractice(
                "line", title: "Cross the Line",
                invitation: "Momort wants you to feel the line. Next time you leave the house on purpose, stop on the step for three seconds. Write what was on each side.",
                action: "Report from the step",
                [("behind", "What was behind you", "The inside: the smell, the sound"),
                 ("ahead", "What was in front of you", "The outside: the air, the noise"),
                 ("next", "What happened next", "After you crossed")]
            )
        ),
        AcademyLessonModule(
            id: "wayfinding-flop-009",
            sessionID: "wayfinding-kineticism",
            title: "When It Goes Wrong, Stay",
            realSubject: "what to do when a trip doesn't go to plan",
            concept: "When a trip goes wrong, don't go home and call it wasted. The bit that goes wrong is often the bit you remember.",
            lectureBeats: [
                "Plans go wrong. Places shut, it rains, things aren't as good as the pictures.",
                "The usual mistake is deciding the whole trip was wasted.",
                "What you do next, right there, is often the best part."
            ],
            demonstration: "Professor Momort promised the class a trip up the bell tower, and when they got there the door was locked. He looked delighted. They spent the hour finding out who had the key, and it turned out to be a first-year who'd been keeping it in his sock. Momort said he couldn't have planned it better. Finn was fairly sure he had.",
            interactionPrompt: "Tell the story of a plan that went wrong. What happened next?",
            realWorldPractice: "Next time a plan goes wrong, stay put for ten minutes before you go home. Look for what else is there.",
            number: 9,
            mode: "The usual mistake",
            lecture: "This'll happen to you. You plan a trip. You've got the snacks, the plan, the coat. You get there, and it's shut. Or it's raining. Or it's nowhere near as good as the pictures. The usual mistake is to go home and call it wasted. Don't. That's the bit where it gets good. Look around. The odd shop over the road. The crisps in the car. The rain on the windscreen. The trip that goes wrong is the one you'll still be telling people about next year. Nobody tells stories about the day everything went to plan. I've never heard one. I'd fall asleep.",
            twoMinutes: "Think of a time a plan went wrong. Write down the best thing that happened because it did.",
            reading: "The Wonder Compass, Chapter 15: The Adventure of Failing",
            practice: wayPractice(
                "flop", title: "The Thing That Went Wrong",
                invitation: "Momort loves a plan that falls apart. Write about one that did: what you planned, what went wrong, and what you did instead.",
                action: "Tell Momort",
                [("planned", "What you planned", "The trip, the visit, the treat"),
                 ("wrong", "What went wrong", "Shut, rained off, not as good as the pictures"),
                 ("instead", "What you did instead", "And whether it was better")]
            )
        ),
        AcademyLessonModule(
            id: "wayfinding-big-day-010",
            sessionID: "wayfinding-kineticism",
            title: "A Big Day Out Is Just a Bigger Step",
            realSubject: "planning a whole day away the same way you'd plan a walk",
            concept: "A big day out uses the same three questions as a walk: where, what treat, and when you stop.",
            lectureBeats: [
                "The same plan works for a ten-minute walk and a whole day away.",
                "For a big trip, ask the questions twice: once for the journey and once when you get there.",
                "Go somewhere new to everybody you know, and the story's yours to bring back."
            ],
            demonstration: "Professor Momort pinned a big map to the gate and gave each student a pin. They had to pick a town nobody in the class had heard of. Lara picked one called Puddletown. Momort said that was ideal, and that she should go and find out if it was true.",
            interactionPrompt: "Where could you get to in a day that nobody you know has been?",
            realWorldPractice: "Plan one day out this summer with a place, a treat for the journey, and a time you'll be home.",
            number: 10,
            mode: "The big trip",
            lecture: "Summer's for the big ones. A whole day somewhere new. People think a big trip's a different thing from a walk to the postbox. It isn't. It's the same three questions, only bigger. Where are you going? What's your treat? When do you stop? A town two hours away. The singing-in-the-car music and the good crisps. Leave at nine, home by four. Then, when you get there, do it all again, small. Where's the best bakery? Walk there. One hour, then lunch. And go somewhere nobody you know has been. Then nobody can tell you what it's like. You'll have to bring the story back yourself.",
            twoMinutes: "Name one town you've never been to that you could get to in a day. Write down why you picked it.",
            reading: eastReading + "; Chapter 23: Weekends & Beyond",
            practice: wayPractice(
                "big-day", title: "Plan the Big Day",
                invitation: "Momort says a big day out is the same plan, only bigger. Plan one: where, what treat, and when you'll be home.",
                action: "Pin it to the map",
                [("where", "Where you'll go", "Somewhere nobody you know has been"),
                 ("treat", "Your treat for the journey", "The music, the snacks"),
                 ("home", "When you'll be home", "A time, so you can enjoy it")]
            )
        ),
        AcademyLessonModule(
            id: "wayfinding-ten-seconds-011",
            sessionID: "wayfinding-kineticism",
            title: "The First Ten Seconds",
            realSubject: "doing small scary things, and telling scary from dangerous",
            concept: "The worst bit of anything scary is the first ten seconds. Say yes before the fear finishes talking. Scary's fine. Dangerous isn't.",
            lectureBeats: [
                "The first ten seconds of something scary are the hardest.",
                "After that, your body notices it's fine and settles down.",
                "Scary and dangerous are different. Do the first. Leave the second alone."
            ],
            demonstration: "Professor Momort took the class down to the pond by the Momentum Yard and asked who'd put their feet in. Everybody said it was too cold. Momort counted to three and walked in up to his knees in his trousers. Finn followed, then everyone. Afterwards they all said the first ten seconds were the worst, and the rest was brilliant.",
            interactionPrompt: "What's a small scary thing you've been putting off? Is it scary, or dangerous?",
            realWorldPractice: "Do one small scary thing this week, like cold water, a phone call or saying hello first. Notice the first ten seconds.",
            number: 11,
            mode: "A dare",
            lecture: "Cold water. Running for a bus you might miss. Putting your hand up. Saying hello to somebody first. The worst part of anything scary is the first ten seconds. After that your body works out it's still alive, and it calms down. So don't wait for the fear to finish talking. Say yes before it gets to the end of its sentence. Now listen, because this matters. Scary isn't the same as dangerous. Scary is a cold lake on a hot day with friends on the bank. Dangerous is a cold lake on your own in the dark. Do the scary ones. Leave the dangerous ones alone. A life with nothing scary in it is very safe and very quiet, and nobody ever writes it down.",
            twoMinutes: "Think of one small scary thing you could do today, like saying hello first or asking the question. Write it down. Then count to three and do it.",
            reading: eastReading,
            practice: wayPractice(
                "ten-seconds", title: "The First Ten Seconds",
                invitation: "Momort dares you to do one small scary thing this week. Scary, not dangerous. Write what it was and what the first ten seconds felt like.",
                action: "Take the dare",
                [("thing", "The scary thing", "Small, and safe"),
                 ("first", "The first ten seconds", "What your body did"),
                 ("after", "After that", "How it felt once you were in")]
            )
        ),
        AcademyLessonModule(
            id: "wayfinding-count-up-012",
            sessionID: "wayfinding-kineticism",
            title: "Where Have You Been?",
            realSubject: "looking back on a year of going out on purpose",
            concept: "Count the times you went out this year. Star the ones you'd tell somebody about.",
            lectureBeats: [
                "Every trip counts, even the ones that only got as far as the door.",
                "The ones worth telling are usually the ones that went a bit wrong.",
                "Looking back shows you what kind of going out suits you."
            ],
            demonstration: "Professor Momort chalked every trip the class had taken that year on the wall of the Momentum Yard. It took him all morning. Then he gave out gold stars and asked them to stick one on each trip they'd tell their family about. Nearly all the stars ended up on the trips where something had gone wrong.",
            interactionPrompt: "Which trip from this year would you tell somebody about?",
            realWorldPractice: "Make a list of the times you went out on purpose this year. Put a star by the ones you'd tell somebody about.",
            number: 12,
            mode: "Counting up",
            lecture: "End of the year. Count up where you've been. Not the miles. The stories. Every time you went out on purpose, write it down. The long way to the post. The shut bakery. The cold pond. Some days you'll only have got as far as the front door before you turned round. Write those down too. Getting to the door counts. Now look at your list and put a star by the ones you'd tell somebody about. I'll bet you a toffee the stars are on the days that went a bit wrong. They nearly always are. That's what the year was for. Next year, go and get more of those.",
            twoMinutes: "Think back over this year. Write down one time you went somewhere that you'd tell a friend about. What went wrong on it?",
            reading: "The Wonder Compass, Chapter 15: The Adventure of Failing",
            practice: wayPractice(
                "count-up", title: "Count Your Trips",
                invitation: "Momort wants the year counted. Write down a trip you took this year, the one you'd tell somebody about, and why that one.",
                action: "Stick on the star",
                [("trip", "A trip from this year", "Even one that only got as far as the door"),
                 ("star", "The one you'd tell", "The one with the star"),
                 ("why", "Why that one", "What happened")]
            )
        )
    ]

    // MARK: Synesthetic Resonance: South = Sense

    private static let southReading = "The Wonder Compass, Chapter 8A: South = Sense"

    private static func resonancePractice(
        _ id: String, title: String, invitation: String, action: String,
        _ fields: [(id: String, label: String, placeholder: String)]
    ) -> AcademyActivity {
        practice("synesthetic-resonance", "resonance-\(id)", kind: .sensoryScore, title: title, invitation: invitation, action: action, fields)
    }

    /// Euphony hears a room before she speaks in it. Her lushness is in what she attends to, never
    /// in long words: she listens first, and lands on the plain bodily fact. Her own fault (a
    /// simple feeling made too elaborate) is the lesson she gets wrong in front of the class.
    static let resonance: [AcademyLessonModule] = [
        AcademyLessonModule(
            id: "resonance-sensory-001",
            sessionID: "synesthetic-resonance",
            title: "The Senses Are Instruments",
            realSubject: "using all your senses to really be somewhere",
            concept: "Most people look at a thing, say its name and walk on. Use your ears, nose, hands and tongue as well, and you'll actually be there.",
            lectureBeats: [
                "Looking, naming and walking off is how most people see things. It's like being in a museum.",
                "Your eyes get bored fastest. Your other senses are waiting.",
                "Feel it before you name it: how cold, how loud, what it smells like."
            ],
            demonstration: "Professor Euphony rang a glass bell and turned one lamp down. Then she asked what colour the room was now. Nothing had moved, but everybody said it was different.",
            interactionPrompt: "Pick a sound in this room. Say what colour it is. Then say what the real sound is.",
            realWorldPractice: "Stop in one room today. Write down one sound, one colour, and one thing your body can feel.",
            number: 1,
            mode: "The big idea",
            lecture: "Listen first. Before you say anything. What can you hear? Good. Keep that. Most people visit the world the way they visit a museum. They walk up to a thing. They look at it. They say its name. Waterfall. Done. They take a picture to prove they were there, and walk off to the next thing. They saw it. They never felt it. Your eyes are only one of your instruments, and they're the one that gets bored quickest. You've got skin. Ears. A nose. A tongue. Hands. Today we play all of them. Go and stand by the window. Don't name anything. Tell me how cold the glass is. Tell me what the room sounds like when nobody's talking. Tell me what it smells like. Then you can tell me what it is.",
            twoMinutes: "Stop where you are. Write down one sound, one colour, and one thing your body can feel right now.",
            reading: southReading
        ),
        AcademyLessonModule(
            id: "resonance-hands-002",
            sessionID: "synesthetic-resonance",
            title: "Your Hands Are Hungry",
            realSubject: "how much of your brain listens to your hands, and how to feed them",
            concept: "Your brain gives your hands a huge amount of room. Most days they only touch flat glass. Give them something rough, warm or strange.",
            lectureBeats: [
                "A brain surgeon's map showed that big parts of the brain listen to the hands, the lips and the tongue.",
                "Most of the day our hands only touch flat, smooth things.",
                "Touching something rough, warm, cold or soft wakes you up fast."
            ],
            demonstration: "Professor Euphony passed round a cloth bag with things inside: a pine cone, a cold spoon, a scrap of velvet, a knob of bread. Nobody was allowed to look. Elio guessed the bread straight away, because it was still warm.",
            interactionPrompt: "Without looking, what's the most interesting thing you can touch from where you're sitting?",
            realWorldPractice: "Find three things with different textures today: something rough, something smooth and something soft. Touch each one for five seconds.",
            number: 2,
            mode: "A strange map",
            lecture: "About ninety years ago a brain surgeon in Montreal called Wilder Penfield operated on people while they were wide awake. It sounds terrible. It didn't hurt them, because the brain can't feel itself. He touched tiny parts of their brains and asked what they felt, and from their answers he drew a map of how much brain goes to each part of the body. If you made a person in the shape of that map, they'd have little legs, a small body, enormous lips, an enormous tongue, and hands like dinner plates. Listen to that. Your hands are some of the busiest things you own. And what do they touch all day? Flat glass. Smooth plastic. Keys. They're starving. Feed them. Bark. Brick. Wool. Cold stone. Warm bread.",
            twoMinutes: "Without getting up, find three things that feel different: something rough, something smooth, something soft. Touch each one for five seconds.",
            reading: southReading,
            practice: resonancePractice(
                "hands", title: "Feed Your Hands",
                invitation: "Euphony says your hands are starving. Find three things that feel different, and write down how each one felt.",
                action: "Let your hands report",
                [("rough", "Something rough", "Bark, brick, a doormat"),
                 ("smooth", "Something smooth", "A pebble, a mug, a window"),
                 ("soft", "Something soft", "Wool, moss, a cat")]
            )
        ),
        AcademyLessonModule(
            id: "resonance-one-sound-003",
            sessionID: "synesthetic-resonance",
            title: "Turn One Sound Up",
            realSubject: "picking one sound out of many by listening hard",
            concept: "Most sounds wash over you. Pick one out and listen hard, and the rest of the world gets sharper.",
            lectureBeats: [
                "We usually treat sound as background.",
                "You can pick one sound out of many just by listening for it.",
                "Giving your mind a small listening job quietens the worrying part."
            ],
            demonstration: "Professor Euphony had everyone close their eyes and count the sounds in the Resonance Chamber. Aria got to eleven. Elio got to fourteen, because he counted his own breathing and the boy next to him chewing his pencil.",
            interactionPrompt: "Close your eyes. What's the quietest sound you can find in this room?",
            realWorldPractice: "Next time you're cooking or washing up, close your eyes for a minute. Find the loudest sound and the quietest one.",
            number: 3,
            mode: "A game",
            lecture: "Next time you're cooking, close your eyes while the onions are frying. Don't stir. Just listen. Find the loudest pop in the pan. Now find the quietest hiss underneath it. Now find something that isn't the pan at all. The fridge. A car outside. Somebody's radio two houses away. Most of the time we let sound wash over us like bathwater. Today you're going to pick one sound out and turn it up, just by listening to it. Your ears can do that. They've just never been asked. And while you're busy listening, the part of you that worries goes quiet, because you've given it something to do.",
            twoMinutes: "Close your eyes for one minute. Count every sound you can hear. Write down the quietest one.",
            reading: southReading,
            practice: resonancePractice(
                "one-sound", title: "Turn One Sound Up",
                invitation: "Euphony wants your ears working. Close your eyes somewhere ordinary and listen. Write the loudest sound, the quietest, and the one you'd never noticed.",
                action: "Report what you heard",
                [("loudest", "The loudest sound", "The one you can't miss"),
                 ("quietest", "The quietest sound", "The one underneath everything"),
                 ("new", "One you'd never noticed", "It's probably always there")]
            )
        ),
        AcademyLessonModule(
            id: "resonance-cold-004",
            sessionID: "synesthetic-resonance",
            title: "Why Metal Feels Cold",
            realSubject: "what your skin is really telling you when something feels cold",
            concept: "Metal and wood in the same room are the same temperature. Metal feels colder because it pulls the warmth out of your hand faster.",
            lectureBeats: [
                "Your skin tells you how fast something takes your warmth away, not how warm it is.",
                "That's why metal feels colder than wood in the same room.",
                "Touching different things one after another wakes your hands up."
            ],
            demonstration: "Professor Euphony laid a brass ruler and a wooden one side by side and asked which was colder. Everybody said the brass. Then she put a thermometer on each. They were exactly the same.",
            interactionPrompt: "Touch two different things near you. Which feels colder? Why do you think it does?",
            realWorldPractice: "Go round your home and touch five different materials, one after another. Write which felt coldest and which felt warmest.",
            number: 4,
            mode: "A test you can do",
            lecture: "Put one hand on something metal and the other on something wooden. A door handle and a table will do. The metal feels colder, doesn't it? Here's the strange part. If they've been in the same room all day, they're the same temperature. The metal just pulls the warmth out of your hand faster, so your skin tells you it's cold. Your hand isn't measuring the thing. It's measuring what the thing is doing to you. I love that. Every surface is having a little conversation with your skin. Go round your house and touch everything once. Stone, glass, wool, wood, the kettle when it's cooled. Listen to what each one says.",
            twoMinutes: "Touch something metal and something wooden at the same time. Write down what each one feels like. They're probably the same temperature.",
            reading: southReading,
            practice: resonancePractice(
                "cold", title: "Hot and Cold",
                invitation: "Euphony wants your skin listening. Touch five different things in your house. Write which felt coldest, which felt warmest, and which surprised you.",
                action: "Report the temperatures",
                [("coldest", "The coldest", "And what it's made of"),
                 ("warmest", "The warmest", "And what it's made of"),
                 ("surprise", "The surprise", "The one that didn't feel how you expected")]
            )
        ),
        AcademyLessonModule(
            id: "resonance-cake-005",
            sessionID: "synesthetic-resonance",
            title: "A Cake Dipped in Tea",
            realSubject: "how smells and tastes bring back old memories",
            concept: "A smell or a taste can bring back a whole day from years ago, all at once. Smell things on purpose and see what comes back.",
            lectureBeats: [
                "Proust bit into a cake dipped in tea, and his childhood came back all at once.",
                "Smell and taste take a short road to the part of you that keeps memories.",
                "Smelling things on purpose can bring back days you'd forgotten."
            ],
            demonstration: "Professor Euphony set out six little jars with cloths over them and let everyone sniff each one. Aria smelled the third jar and said, \"My nan's kitchen,\" before she knew she was going to say it. It was cloves.",
            interactionPrompt: "What smell takes you straight back somewhere?",
            realWorldPractice: "Smell five things on purpose this week, like coffee, an old book or soap. Write down anything they bring back.",
            number: 5,
            mode: "A true story",
            lecture: "More than a hundred years ago a French writer called Marcel Proust dipped a little cake in his tea and took a bite, and his whole childhood came back. Not as a thought. All at once, like a door opening. Sunday mornings. His aunt's room. The town where he grew up. He wrote thousands of pages about it, and it all started with one mouthful. Smell and taste do that. They take a shorter road to the part of you that keeps feelings and memories. That's why a stranger's perfume on the bus can make you miss somebody. So go and smell things on purpose. The inside of an old book. Coffee. Rain on a hot pavement. Find out which doors they open.",
            twoMinutes: "Find the strongest smell you can get to in two minutes. Smell it with your eyes shut. Write down what it brings back, even if it's nothing much.",
            reading: "Marcel Proust, Swann's Way (1913)",
            practice: resonancePractice(
                "cake", title: "What It Brings Back",
                invitation: "Euphony wants to know where your nose takes you. Smell one thing on purpose. Write what it was, what it brought back, and how old you were there.",
                action: "Tell her where it took you",
                [("smell", "What you smelled", "Coffee, soap, an old book"),
                 ("back", "What it brought back", "A room, a person, a day"),
                 ("age", "How old you were there", "Your best guess")]
            )
        ),
        AcademyLessonModule(
            id: "resonance-ant-006",
            sessionID: "synesthetic-resonance",
            title: "Get Down to Ant Height",
            realSubject: "seeing small things very close up",
            concept: "Get your eye very close to something small and it turns into a whole world. Change how near you are and you change what's there.",
            lectureBeats: [
                "Up close, moss or bark looks like a forest.",
                "Changing how close you are changes what you can see.",
                "Very near and very far are both good ways to look."
            ],
            demonstration: "Professor Euphony took the class outside and had them lie on their fronts on the path with their faces close to a crack between the stones. Elio found three kinds of tiny plant in a space the size of a stamp, and an ant carrying something bigger than itself.",
            interactionPrompt: "If you got your eye three inches from something in this room, what would you pick?",
            realWorldPractice: "Get your eye three inches from some moss, some bark or a crack in the pavement. Find three different tiny things there.",
            number: 6,
            mode: "Showing how",
            lecture: "Kneel down. Yes, really. Put your eye about three inches from that moss on the step. Now it isn't a green smudge any more. It's a forest. There are tiny stalks with tiny cups on top. There's a drop of water sitting in it like a lake. There might be something living in there that's never once been looked at by a person. Changing how close you are changes what's there. Get very close, and an ordinary thing turns into a country. Then stand up and look as far away as you can see. It's the same world both times. You've just changed the lens.",
            twoMinutes: "Pick something small near you and get your eye as close to it as it'll go. Write down three things you can see that you couldn't from further away.",
            reading: southReading,
            practice: resonancePractice(
                "ant", title: "Ant Height",
                invitation: "Euphony wants you very close to something small. Get your eye three inches away. Write what it was, and three things you found there.",
                action: "Report from down there",
                [("what", "What you looked at", "Moss, bark, a crack, a crumb"),
                 ("found", "Three things you found", "Things you couldn't see standing up"),
                 ("strangest", "The strangest one", "And why")]
            )
        ),
        AcademyLessonModule(
            id: "resonance-one-note-007",
            sessionID: "synesthetic-resonance",
            title: "One Note Is Enough",
            realSubject: "describing a moment with one true detail instead of everything",
            concept: "You don't have to describe everything. Pick the one truest thing and say it plainly.",
            lectureBeats: [
                "Describing too much can bury the one thing that mattered.",
                "Pick one sense and one detail.",
                "Say it in plain words, the way you'd tell a friend."
            ],
            demonstration: "Professor Euphony described a raindrop on the window for five whole minutes: its colour, its music, its sadness. Then Aria put her hand up and said, \"It's sliding down.\" The room laughed, and Professor Euphony wrote Aria's sentence on the board instead of her own.",
            interactionPrompt: "Describe something in this room in one plain sentence, with only one detail.",
            realWorldPractice: "Tonight, describe one moment from today using one sense and one plain sentence.",
            number: 7,
            mode: "Someone gets it wrong",
            lecture: "I'll own up to something. I sometimes make a simple feeling far too complicated. Somebody tells me their tea's nice, and I'm off, telling them it's a warm amber chord with a sad little note of orange peel. It's tea. It's nice. That's today's lesson, and it's for me as much as for you. You don't need to describe everything. Pick the one truest thing. One sound. One smell. One feeling in your hands. Say it plainly. \"The mug was too hot to hold.\" That's enough. One clear note, played properly, is plenty.",
            twoMinutes: "Look at one thing near you. Write one plain sentence about it, using only one sense.",
            reading: southReading + "; Chapter 9: West = Write",
            practice: resonancePractice(
                "one-note", title: "One Clear Note",
                invitation: "Euphony's learning this one too. Pick one moment from today. Write it once with everything in, then again with only the one truest detail.",
                action: "Play the one note",
                [("everything", "With everything in", "All of it, as much as you like"),
                 ("one", "With one detail", "The truest one, in plain words"),
                 ("sense", "Which sense it was", "Sound, smell, touch, taste or sight")]
            )
        ),
        AcademyLessonModule(
            id: "resonance-colours-008",
            sessionID: "synesthetic-resonance",
            title: "Hearing Colours",
            realSubject: "synaesthesia, and playing at mixing your senses",
            concept: "Some people really do hear colours. You can play at it too: listen to something properly first, then say what colour it is.",
            lectureBeats: [
                "Synaesthesia is real. Some people see colours when they hear sounds.",
                "Most of us don't, but we can play the game.",
                "Start from the real sound or smell, then guess its colour."
            ],
            demonstration: "Professor Euphony played one note on the piano and asked everyone to write down its colour without talking. When they turned their papers over, more than half had written some kind of blue. Elio had written \"the colour of a cold spoon\", which she said counted.",
            interactionPrompt: "What colour is the loudest sound in this room?",
            realWorldPractice: "Pick three sounds today and give each one a colour. Write down the real sound first.",
            number: 8,
            mode: "Something real and rare",
            lecture: "A few people in every hundred really do mix their senses up. They hear a trumpet and see orange. They see the number seven and it's always green. It's called synaesthesia, and it's real. The painter Wassily Kandinsky wrote that colours were like the keys of a piano, and each one played a note. Most of us don't have it. But we can play at it. What colour's the sound of a kettle? What does Tuesday taste like? There's no right answer. The game only works if you start from the real thing, though. Listen to the kettle first, properly. Then say its colour. You'll be surprised how many people agree with you.",
            twoMinutes: "Listen to one sound near you. Write what it really is. Then write what colour it would be.",
            reading: "Wassily Kandinsky, Concerning the Spiritual in Art (1911)",
            practice: resonancePractice(
                "colours", title: "Hear a Colour",
                invitation: "Euphony wants you to play at mixing your senses. Pick a sound. Write what it really is, what colour it is, and what it would taste like.",
                action: "Play it back to her",
                [("sound", "The real sound", "A kettle, a door, a bird"),
                 ("colour", "Its colour", "Whatever comes first"),
                 ("taste", "Its taste", "Sweet, sour, burnt, cold")]
            )
        ),
        AcademyLessonModule(
            id: "resonance-uncool-009",
            sessionID: "synesthetic-resonance",
            title: "Nobody's Looking",
            realSubject: "getting past feeling silly so you can really look and touch",
            concept: "People notice you far less than you think. So crouch down, touch the bark, smell the bread.",
            lectureBeats: [
                "Feeling silly stops a lot of people from really looking at things.",
                "People guess they're being watched about twice as much as they are.",
                "If it still feels too much, start with things nobody can see you do."
            ],
            demonstration: "Professor Euphony took the class to the busiest corridor in the Academy and had them all crouch down to look at the skirting boards. Hardly anybody walking past even glanced at them. One professor stepped right over Elio without noticing he was there.",
            interactionPrompt: "What would you look at closely if nobody could see you?",
            realWorldPractice: "Do one thing this week you'd usually be too embarrassed to do, like crouching to look at a beetle or smelling the bread in a shop.",
            number: 9,
            mode: "The usual mistake",
            lecture: "Here's the mistake. You see something lovely, a beetle on the pavement, moss on a wall, and you want to crouch down and look. Then you think, people will see me. So you don't. In 2000 some scientists at Cornell asked students to walk into a room wearing a T-shirt with a very embarrassing singer's face on it. The students guessed about half the room would notice. About a quarter did. People are far too busy worrying about themselves to look at you. So crouch down. Touch the bark. Close your eyes in the shop and smell the bread. Nobody's looking. And if they are, they're probably wishing they were brave enough too.",
            twoMinutes: "Wiggle your toes and feel exactly where your socks touch them. Nobody can see you doing it. That counts.",
            reading: southReading,
            practice: resonancePractice(
                "uncool", title: "Be Uncool",
                invitation: "Euphony says nobody's looking. Do one thing you'd usually be too embarrassed to do. Write what it was, who saw, and what you found.",
                action: "Own up",
                [("did", "What you did", "Crouched, touched, sniffed, stared"),
                 ("saw", "Who saw", "Probably nobody"),
                 ("found", "What you found", "The thing that was worth it")]
            )
        ),
        AcademyLessonModule(
            id: "resonance-taste-010",
            sessionID: "synesthetic-resonance",
            title: "Eat It Slowly",
            realSubject: "tasting food properly instead of just eating it",
            concept: "Most of the time we eat without tasting. Slow one mouthful right down and find three different tastes in it.",
            lectureBeats: [
                "We usually eat without paying any attention.",
                "Smelling first and then taking one slow bite lets you find several tastes in one thing.",
                "Tasting slowly makes a meal something you remember."
            ],
            demonstration: "Professor Euphony gave everybody one strawberry and made them wait a whole minute before eating it. Aria said the waiting was torture. Afterwards she said it was the best strawberry she'd ever had, and that she was still cross about the minute.",
            interactionPrompt: "What's one taste you'd find if you slowed right down?",
            realWorldPractice: "Eat one thing very slowly this week. Write down three different tastes you found in it.",
            number: 10,
            mode: "A tasting",
            lecture: "Most of the time we don't taste food. We just eat it. Today you're a food critic. Take one strawberry. Don't eat it yet. Smell it. What's that smell like? Now take one bite and keep it in your mouth. Find three different tastes. Sweet. A bit sour. Something green, maybe, near the stalk. Notice what your teeth feel. Notice when the taste changes. That's one strawberry, and it took a whole minute. You can do this with toast. With a cup of tea. With anything at all. You'll eat less of it, and you'll remember all of it.",
            twoMinutes: "Take one mouthful of whatever's nearest, a drink, a biscuit, anything. Keep it in your mouth for ten seconds. Write down three tastes.",
            reading: southReading,
            practice: resonancePractice(
                "taste", title: "Three Tastes",
                invitation: "Euphony wants one mouthful taken slowly. Write what you ate, the three tastes you found, and which one surprised you.",
                action: "Report the tasting",
                [("food", "What you ate", "One thing, one mouthful"),
                 ("tastes", "The three tastes", "Sweet, sour, salty, bitter, something else"),
                 ("surprise", "The surprise", "The one you didn't expect")]
            )
        ),
        AcademyLessonModule(
            id: "resonance-song-011",
            sessionID: "synesthetic-resonance",
            title: "The Song From That Summer",
            realSubject: "how songs hold on to particular years of your life",
            concept: "One song can belong to one year of your life. Play it on purpose and listen for what comes back with it.",
            lectureBeats: [
                "Songs get tied to the time when you first loved them.",
                "Music from your teens tends to stay the clearest of all.",
                "Playing an old song on purpose can bring back a room, a smell or a person."
            ],
            demonstration: "Professor Euphony asked each student to hum the song from their best summer. Elio hummed something nobody recognised. When he finished he was quiet for a bit, and then he said it was the song from the summer his brother taught him to swim.",
            interactionPrompt: "What song takes you straight back to one particular year?",
            realWorldPractice: "Play one old song on purpose this week, with your eyes closed. Write down what comes back with it.",
            number: 11,
            mode: "Listening back",
            lecture: "Everybody has one. A song that belongs to one particular year of your life, and when it comes on in a shop, you're right back there. The same weather. The same shoes. The same person you were. Songs from when we're young stick hardest. Scientists have found that most people remember the music from their teens far better than anything that came after. That's not you being old-fashioned. It's your memory keeping its best recordings. So this week, play the song on purpose. Close your eyes. Don't sing along. Listen for what comes back with it: a smell, a room, a person. Then write it down before it goes.",
            twoMinutes: "Think of a song from one particular summer. Hum the first line. Write down one thing it brings back.",
            reading: southReading,
            practice: resonancePractice(
                "song", title: "The Song From That Summer",
                invitation: "Euphony wants you to play an old song on purpose. Write which song it was, which year it belongs to, and what came back with it.",
                action: "Tell her what came back",
                [("song", "The song", "The one that belongs to one year"),
                 ("year", "Which year", "And where you were"),
                 ("back", "What came back", "A smell, a room, a person")]
            )
        ),
        AcademyLessonModule(
            id: "resonance-last-light-012",
            sessionID: "synesthetic-resonance",
            title: "The Last Light",
            realSubject: "watching one sunset all the way to the end",
            concept: "Watch one sunset right to the end. Notice the colours, the sounds, and the cold on your hands.",
            lectureBeats: [
                "Most people see sunsets but hardly ever watch one to the end.",
                "As the light goes, the sounds and the temperature change too.",
                "Watching right to the end keeps you in one long, slow moment."
            ],
            demonstration: "Professor Euphony took the class up to the roof at sunset and made them promise not to talk until the sun was gone. It took longer than anybody expected. When it was over, Aria said she'd heard a bird she'd never noticed before, and nobody else had heard it.",
            interactionPrompt: "When did you last watch something all the way to the end?",
            realWorldPractice: "Watch one sunset all the way down this week. Write down one sound, one colour and one thing you felt.",
            number: 12,
            mode: "A long look",
            lecture: "End of the year, and I want to give you the simplest lesson I know. Go outside at sunset. Watch the sun until the very last bit of it has gone. Don't look away. Don't check anything. Notice how the colours change, and how the sounds change too: the birds get louder, the traffic gets softer. Notice how cold your hands get. Notice the exact moment it's gone. Most people have seen a thousand sunsets and watched maybe two of them to the end. Watch this one. Then go back in and write down one sound, one colour and one thing you felt. That's everything I've taught you this year, in one evening.",
            twoMinutes: "Look out of the nearest window for two whole minutes without looking away. Write down how the light changed, even a little.",
            reading: southReading,
            practice: resonancePractice(
                "last-light", title: "The Last Light",
                invitation: "Euphony's last lesson of the year: watch one sunset all the way down. Write one sound, one colour, and one thing you felt.",
                action: "Report the last light",
                [("sound", "One sound", "What you heard as it went"),
                 ("colour", "One colour", "The last one before dark"),
                 ("felt", "One thing you felt", "In your hands, or anywhere")]
            )
        )
    ]

    // MARK: Ink-Binding: West = Write

    private static let westReading = "The Wonder Compass, Chapter 9: West = Write"

    private static func inkPractice(
        _ id: String, title: String, invitation: String, action: String,
        _ fields: [(id: String, label: String, placeholder: String)]
    ) -> AcademyActivity {
        practice("ink-binding", "ink-binding-\(id)", kind: .sentenceWorkshop, title: title, invitation: invitation, action: action, fields)
    }

    /// Villanelle is exacting and kind: beauty has to earn its place by being true. She crosses
    /// out the lovely word that didn't happen and asks for the chipped cup. Her own fault (polishing
    /// a living moment until it holds too still) is the lesson she gets wrong.
    static let inkBinding: [AcademyLessonModule] = [
        AcademyLessonModule(
            id: "ink-binding-souvenir-001",
            sessionID: "ink-binding",
            title: "One Sentence Can Carry Time",
            realSubject: "writing one true sentence about a moment so you keep it",
            concept: "One true sentence can hold a whole moment. Put real things in it, and cross out anything pretty that isn't true.",
            lectureBeats: [
                "A good sentence carries one moment home. It doesn't try to hold the whole day.",
                "Real things, like a cup or a coat or a name, hold a moment better than big words.",
                "When you fix a sentence, take out the pretty bits that aren't true."
            ],
            demonstration: "Professor Villanelle wrote the same moment three ways on the board. Then she crossed out the prettiest word, because it wasn't true.",
            interactionPrompt: "Which sentence keeps the moment best? Which word has earned its place?",
            realWorldPractice: "Tonight, write one sentence about one real moment from today. Don't explain why it mattered.",
            number: 1,
            mode: "The big idea",
            lecture: "One sentence. That's all I'll ever ask of you in this room. Not a diary. Not a page. One sentence about the best moment of your day, written before you sleep. If you don't write it, it goes. By next week you'll know you went somewhere, and that's all. Write it, and it stays. But it has to be true, and it has to have something real in it. A cup. A coat. A name. Not \"it was lovely\". Lovely is a label. Give me the thing that made it lovely. Write it, and read it back. If it brings the moment back, keep it. If it doesn't, cut a word and try again.",
            twoMinutes: "Write one sentence about something that happened today. Put one real thing in it. Cross out any word that's only there to be pretty.",
            reading: westReading
        ),
        AcademyLessonModule(
            id: "ink-binding-forgetting-002",
            sessionID: "ink-binding",
            title: "Most of It's Gone by Tomorrow",
            realSubject: "how fast we forget, and catching a day before it goes",
            concept: "Most of what happens to you is forgotten within a day. Write one sentence the same day, before it goes.",
            lectureBeats: [
                "A scientist tested his own memory and found most things go within a day.",
                "We forget fast at first, then more slowly.",
                "Writing a moment down the same day catches it before it falls away."
            ],
            demonstration: "Professor Villanelle asked the class what they'd had for lunch three days ago. Nobody knew. Then she asked Zara to read out what she'd written in her notebook that day. Zara read one line about the soup, and suddenly half the class remembered the soup too, and the argument about the soup.",
            interactionPrompt: "What did you do last Saturday? What can you actually remember about it?",
            realWorldPractice: "For one week, write one sentence about each day before you go to sleep. On the last night, read them all back.",
            number: 2,
            mode: "A real experiment",
            lecture: "In 1885 a German scientist called Hermann Ebbinghaus published what he'd found from years of learning lists of nonsense words and testing himself to see how many he still knew. Most of what he'd learned was gone within a day. Not slowly. Fast at first, and then slower. He drew it as a curve, dropping off a cliff and then flattening out. Your Saturdays fall off the same cliff. By Tuesday you know you went somewhere, and you can't remember what it smelled like. So write it down the same day, while it's still warm. One sentence before you sleep catches it at the top of the cliff.",
            twoMinutes: "Write one sentence about the best moment of yesterday. Then notice how much of the day it brings back.",
            reading: "Hermann Ebbinghaus, Memory (1885)",
            practice: inkPractice(
                "same-day", title: "Catch It Before It Goes",
                invitation: "Villanelle wants today kept before it falls away. Write one sentence about the best moment of today, before you sleep.",
                action: "Bind it",
                [("moment", "The moment", "What happened, in one sentence"),
                 ("thing", "The real thing in it", "The cup, the coat, the name")]
            )
        ),
        AcademyLessonModule(
            id: "ink-binding-specific-003",
            sessionID: "ink-binding",
            title: "Real Things Beat Pretty Words",
            realSubject: "why exact details stay in your memory and labels don't",
            concept: "\"It was lovely\" is forgotten by Thursday. One real detail, like a cat drawn in the foam, stays for years.",
            lectureBeats: [
                "A sentence with only a label in it, like \"nice\" or \"fun\", slides out of your memory.",
                "One real detail you could see, hear or touch makes it stick.",
                "You don't have to be clever. You have to be exact."
            ],
            demonstration: "Professor Villanelle collected everybody's sentence about breakfast and read them out without names. Six said it was nice. One said the toast had been cut into triangles by somebody who loved them. Everybody knew whose that was.",
            interactionPrompt: "Take a sentence with \"nice\" in it. Swap \"nice\" for the real thing that made it nice.",
            realWorldPractice: "Write one sentence about today with no labels in it: no \"nice\", no \"fun\", no \"lovely\". Only real things.",
            number: 3,
            mode: "The usual mistake",
            lecture: "The commonest mistake I see is a sentence like this: \"We went to the café and it was lovely.\" It's true. It's also gone by Thursday, because there's nothing in it to hold on to. Lovely is a label, and labels slide straight off your memory. Now try: \"The man behind the counter drew a cat in the foam without being asked.\" You'll remember that café in ten years. You don't have to be clever. \"The rock was smooth and I liked it\" is good, because smooth is a real thing your hand felt. \"Saw a weird dog\" is good, because you'll know exactly which dog. Give me the real thing. Leave out the lovely.",
            twoMinutes: "Write \"It was nice\" about something from today. Then cross out \"nice\" and write the real thing instead.",
            reading: westReading,
            practice: inkPractice(
                "label", title: "Cross Out the Label",
                invitation: "Villanelle won't take \"lovely\". Write a sentence the lazy way, then again with the real thing in it.",
                action: "Hand in the real one",
                [("lazy", "The lazy sentence", "It was nice, it was fun…"),
                 ("real", "The real one", "With the thing you could see, hear or touch")]
            )
        ),
        AcademyLessonModule(
            id: "ink-binding-wires-004",
            sessionID: "ink-binding",
            title: "Cross the Wires",
            realSubject: "describing one sense with the words for another",
            concept: "Describe one sense with the words for another, like \"the fire sounded orange\". Your memory can't file it away, so it keeps it.",
            lectureBeats: [
                "Memory keeps the senses in separate drawers, which makes things easy to forget.",
                "Mixing them up, like a sound that's a colour, makes a sentence stick.",
                "It doesn't have to be good. Silly ones work too."
            ],
            demonstration: "Professor Villanelle lit a candle and asked the class to describe it without using any words about seeing. Ellie said it sounded like somebody whispering in the next room. Zara said it tasted warm. Villanelle kept both.",
            interactionPrompt: "Describe something in this room using the words for a different sense.",
            realWorldPractice: "Write one sentence today that describes a sound as a colour, or a smell as a sound.",
            number: 4,
            mode: "A game",
            lecture: "Your memory keeps the senses in separate drawers. Sounds here. Colours there. Tastes over there. Neat, and very easy to forget. So we're going to make a mess. Describe one sense with the words for another. \"The fire sounded orange.\" \"The wind tasted like a rusty nail.\" \"The library was so quiet it was soft.\" Your memory has no drawer for an orange sound, so it has to stop and keep it. Children do this all the time. \"That song's red.\" They're not being sweet. That's how the world arrives before anybody teaches you to sort it. And it doesn't have to be good. \"The soup smelled loud\" is ridiculous. You'll laugh when you read it in January, and you'll remember the whole kitchen.",
            twoMinutes: "Pick something you can hear right now. Write one sentence saying what colour it is, or what it tastes like.",
            reading: westReading,
            practice: inkPractice(
                "wires", title: "Cross the Wires",
                invitation: "Villanelle wants your senses mixed up. Write one plain sentence about a moment, then cross the wires: describe one sense with another.",
                action: "Hand in the crossed one",
                [("plain", "The plain sentence", "What happened, said simply"),
                 ("crossed", "The crossed one", "The fire sounded orange…")]
            )
        ),
        AcademyLessonModule(
            id: "ink-binding-turn-005",
            sessionID: "ink-binding",
            title: "Let the World Do Something",
            realSubject: "turning a sentence round so the world acts on you",
            concept: "Most sentences put you in the middle: I saw, I sat, I ate. Turn them round and let the world do something to you.",
            lectureBeats: [
                "\"I saw the mountain\" is true, but flat.",
                "Giving the thing the verb, like \"the bench caught me\", makes the sentence come alive.",
                "It turns you from a camera into somebody the world's talking to."
            ],
            demonstration: "Professor Villanelle wrote \"I opened the door\" on the board. Then she let the class turn it round, one go at a time, until it said \"The door gave in with a sigh, as if it had been holding its breath all winter.\" Then she crossed out \"all winter\", because it hadn't been winter.",
            interactionPrompt: "Take a sentence that starts with \"I\". Turn it round so the thing does something to you.",
            realWorldPractice: "Write one sentence today where an object, the weather or a place does something to you.",
            number: 5,
            mode: "Showing how",
            lecture: "Most sentences put you in the middle. I saw the mountain. I sat on the bench. I ate the pie. True, and dead on the page. Turn them round. Give the thing the verb. \"The bench caught me, as if it had been keeping the spot all afternoon.\" \"The pie had been waiting in the case since six this morning, and I was the one who finally picked it.\" When you write \"the sun hit my face\", that's just weather. When you write \"the sun found me\", something's happened between you. You're not a camera. You're in a conversation. Let the world have a line.",
            twoMinutes: "Write an \"I\" sentence about something you did today. Then turn it round so the thing does something instead.",
            reading: westReading,
            practice: inkPractice(
                "turn", title: "Turn It Round",
                invitation: "Villanelle wants the world to have a line. Write a sentence that starts with \"I\", then turn it round so the thing does something to you.",
                action: "Hand in both",
                [("i", "The I sentence", "I saw, I sat, I ate"),
                 ("turned", "Turned round", "The bench caught me…")]
            )
        ),
        AcademyLessonModule(
            id: "ink-binding-cheese-006",
            sessionID: "ink-binding",
            title: "Samuel Pepys Buried His Cheese",
            realSubject: "why the small odd detail is the one that lasts",
            concept: "The small true thing is what lasts. Samuel Pepys wrote that he buried his cheese during the Great Fire of London, and people still remember it.",
            lectureBeats: [
                "Samuel Pepys kept a diary all the way through the Great Fire of London in 1666.",
                "Out of everything he wrote, people remember that he buried his cheese.",
                "The small, odd, exact detail is often the one that lasts longest."
            ],
            demonstration: "Professor Villanelle read the class a few lines from Pepys's diary. Then she asked them to write one sentence about the biggest thing that had happened to them this year, with the smallest true detail they could remember right in the middle of it. Zara put in the odd socks she'd worn to her exam.",
            interactionPrompt: "What's the smallest true detail you remember from a big day?",
            realWorldPractice: "Write one sentence about something big that happened this year, with the smallest true detail you can remember in it.",
            number: 6,
            mode: "A true story",
            lecture: "In September 1666, London caught fire. A man called Samuel Pepys was keeping a diary, and he wrote down what he did while the city burned. He watched the flames from a boat on the river. He saw pigeons that wouldn't leave their homes until their wings caught. And he dug a hole in his garden and buried his wine and his Parmesan cheese, so the fire wouldn't get them. More than three hundred and fifty years later, people still talk about that cheese. Not because it mattered. Because it was exactly true, and nobody else would have thought to write it down. That's what lasts. Not \"it was a terrible fire\". The cheese.",
            twoMinutes: "Think of a big day from your life. Write down the smallest, oddest true thing you remember from it.",
            reading: "Samuel Pepys, Diary, 2 to 4 September 1666",
            practice: inkPractice(
                "cheese", title: "Bury the Cheese",
                invitation: "Villanelle wants the small true thing. Pick a big day, and write the smallest, oddest detail you remember from it.",
                action: "Bind the detail",
                [("day", "The big day", "What happened"),
                 ("cheese", "The small true thing", "The cheese, the socks, the teapot")]
            )
        ),
        AcademyLessonModule(
            id: "ink-binding-alive-007",
            sessionID: "ink-binding",
            title: "Don't Polish It Still",
            realSubject: "fixing what's false without smoothing away what's alive",
            concept: "Fix what's false in a sentence, but leave in what's alive. Too much polishing makes a moment hold too still.",
            lectureBeats: [
                "A sentence can be polished until it's perfect and dead.",
                "Keep a bit of the moment's mess: the run-on bit, the odd word.",
                "Reading it out loud shows you which parts are alive."
            ],
            demonstration: "Zara brought Professor Villanelle a sentence about running for the last bus. Villanelle trimmed it, then trimmed it again, until it was short and neat and perfect. Then she read both out loud. The class liked Zara's messy one better. Villanelle said they were right, and gave it back.",
            interactionPrompt: "Read your sentence out loud. Which part did you say faster?",
            realWorldPractice: "Write a sentence about a moment from today. Fix one thing that isn't true, and leave the rest alone.",
            number: 7,
            mode: "Someone gets it wrong",
            lecture: "I have a fault, and I'd rather you heard it from me. I polish. Somebody brings me a sentence that's alive and wriggling, and I smooth it and trim it and tidy it until it's perfect and doesn't move any more. A sentence about a moment should still have a bit of the moment's mess in it. The word you nearly crossed out. The bit that runs on too long because you were out of breath. Fix what's false. Leave what's alive. If you can't tell which is which, read it out loud. The living bits are the ones you can't help saying faster.",
            twoMinutes: "Write one quick sentence about something that just happened. Don't fix it. Read it out loud, and underline the part that sounds most alive.",
            reading: westReading,
            practice: inkPractice(
                "alive", title: "Leave It Alive",
                invitation: "Villanelle's owning up to polishing too much. Write a quick sentence about a moment, then fix only what's false.",
                action: "Hand it in, still moving",
                [("quick", "The quick sentence", "Fast, messy, true"),
                 ("fixed", "The one thing you fixed", "Only what wasn't true")]
            )
        ),
        AcademyLessonModule(
            id: "ink-binding-wait-008",
            sessionID: "ink-binding",
            title: "Wait a Day Before You Share It",
            realSubject: "keeping a moment to yourself so it sets in your memory",
            concept: "Write your sentence, then wait a whole day before you share it. A new memory needs time to set, like wet cement.",
            lectureBeats: [
                "Thinking about how a moment will look to other people pulls you out of it.",
                "A new memory sets like cement, and it needs a day to harden.",
                "Keeping something to yourself for a day makes it more yours."
            ],
            demonstration: "Professor Villanelle made everyone hand in their phones at the start of class and write a sentence about the walk there instead. She gave the phones back the next morning. Ellie said it was the longest day of her life. She also said she remembered that walk better than any other walk all year.",
            interactionPrompt: "What's something you saw this week that you haven't told anybody?",
            realWorldPractice: "Next time something lovely happens, write your sentence and wait a whole day before you show anybody.",
            number: 8,
            mode: "A rule to play by",
            lecture: "Take the photo if you like. Write your sentence. Then don't post it. Not for a whole day. The moment you start thinking about how it'll look to other people, you stop being in it. You're wrapping it up. You're thinking of a caption. And afterwards you'll remember how many people liked it, and not what the air smelled like. A new memory is like wet cement. If everybody walks on it straight away, it goes messy. Give it a day to set. Carry it about with you, like something warm in your pocket that nobody else knows is there. Then share it, if you still want to.",
            twoMinutes: "Write one sentence about something good from today. Don't show anyone. Keep it till tomorrow.",
            reading: westReading,
            practice: inkPractice(
                "wait", title: "The One-Day Secret",
                invitation: "Villanelle's rule: write it, then wait a day before you share it. Write the sentence now, and tomorrow say whether you still want to.",
                action: "Keep it a day",
                [("sentence", "The sentence", "The moment, kept"),
                 ("tomorrow", "Tomorrow", "Do you still want to share it?")]
            )
        ),
        AcademyLessonModule(
            id: "ink-binding-said-009",
            sessionID: "ink-binding",
            title: "The Sentence Somebody Said to You",
            realSubject: "the sentences other people say to us that stay for years",
            concept: "Some sentences people say to you stay for years. Write one down, with who said it and where you were.",
            lectureBeats: [
                "Most people carry a few sentences that somebody once said to them.",
                "Remembering the sentence brings back the room, the weather and the moment.",
                "It shows how strong one sentence can be."
            ],
            demonstration: "Professor Villanelle told the class the sentence she'd carried longest. A woman on a ferry had told her, \"You hold your pen like it owes you money.\" She'd been eleven. She still holds it that way.",
            interactionPrompt: "What's a sentence somebody once said to you that you've never forgotten?",
            realWorldPractice: "Write down one sentence somebody said to you that stayed. Add who said it and where you were.",
            number: 9,
            mode: "Something said to you",
            lecture: "Most of us carry a few sentences that other people said to us. One from a teacher. One from a stranger on a train. One from somebody we loved. We never wrote them down, and we never forgot them either. Today I want you to write one down. It might be kind. It might be funny. It might be one that still stings a little. Write it exactly as you remember it, then write who said it and where you were. You'll notice something. You remember the room, and the weather, and what you were holding. That's how strong one sentence can be. It's worth remembering when it's your turn to say one.",
            twoMinutes: "Write down one sentence somebody said to you that you've never forgotten. Add where you were when they said it.",
            reading: westReading,
            practice: inkPractice(
                "said", title: "The Sentence That Stayed",
                invitation: "Villanelle wants the sentences you've carried. Write one somebody said to you, who said it, and where you were.",
                action: "Bind it at last",
                [("said", "What they said", "As exactly as you remember it"),
                 ("who", "Who said it", "A name, or just who they were"),
                 ("where", "Where you were", "The room, the weather, what you were holding")]
            )
        ),
        AcademyLessonModule(
            id: "ink-binding-ending-010",
            sessionID: "ink-binding",
            title: "Write It Before You Leave",
            realSubject: "how endings shape what we remember",
            concept: "We remember an outing by its best moment and by how it ended. Write your sentence before you leave, and make the ending the best bit.",
            lectureBeats: [
                "People chose more cold water if it ended slightly better.",
                "We remember things by their best moment and by their ending.",
                "Writing your sentence before you leave makes the ending the best part."
            ],
            demonstration: "At the end of a walk, Professor Villanelle stopped the class at the gate and wouldn't let anybody through until they'd written their sentence. It was raining. Ellie wrote hers on the back of her hand. It was the only one that got smudged, and the only one she still knows word for word.",
            interactionPrompt: "Where would you stop to write your sentence on the way home today?",
            realWorldPractice: "Next time you go somewhere, write your sentence before you leave the place, not when you get home.",
            number: 10,
            mode: "An odd result",
            lecture: "In the 1990s a scientist called Daniel Kahneman asked people to hold a hand in cold water. Once for a minute. Once for a minute and a half, where the last half-minute was a tiny bit less cold. Then he asked which one they'd rather do again. Most of them picked the longer one. More cold water, but a better ending. We remember things by their best or worst moment, and by how they end. So you get to choose the ending. Write your sentence before you leave the place. On the bench, in the car, at the gate. Then the last thing you did there was catch the best bit, and that's what you'll keep.",
            twoMinutes: "Before you get up from where you are, write one sentence about the best bit of the last hour.",
            reading: westReading,
            practice: inkPractice(
                "before-you-leave", title: "Before You Leave",
                invitation: "Villanelle wants the ending to be the best bit. Next time you go somewhere, write your sentence before you leave, and say where you wrote it.",
                action: "Bind it at the gate",
                [("where", "Where you wrote it", "The bench, the car, the gate"),
                 ("sentence", "The sentence", "The best bit")]
            )
        ),
        AcademyLessonModule(
            id: "ink-binding-unsent-011",
            sessionID: "ink-binding",
            title: "The Message You Didn't Send",
            realSubject: "finishing the message you never sent, whether or not you send it",
            concept: "Write the message you never sent, all the way to the end. You don't have to send it. Finishing it is the point.",
            lectureBeats: [
                "Most people carry a message they never sent.",
                "Writing it all the way through helps, even if nobody reads it.",
                "Short is often better. Then you choose: send it, keep it, or burn it."
            ],
            demonstration: "Professor Villanelle gave each student a postcard and said it had to be finished by the end of class. Most people wrote to somebody far away. Ellie wrote to her old dog. She didn't post it. She pinned it above her bed.",
            interactionPrompt: "Who's the message you never sent meant for? You don't have to say what it says.",
            realWorldPractice: "Write the message you never sent, all the way to the end, as short as you can. Then decide what to do with it.",
            number: 11,
            mode: "A letter",
            lecture: "Everybody has one. A message you typed and deleted. A letter you meant to write and didn't. A thank you you never got round to. Today you're going to write it. You don't have to send it. That isn't the point. The point is that it's been sitting in you half-made, and words that are half-made go sour. Write it all the way to the end. Make it short. The best letters are often the ones that had to be short. Then decide. Send it, or keep it, or burn it. All three are allowed. Leaving it half-written is the only thing I won't allow.",
            twoMinutes: "Think of a thank you you never said. Write it in one sentence. You don't have to send it.",
            reading: westReading,
            practice: inkPractice(
                "unsent", title: "The Message You Didn't Send",
                invitation: "Villanelle wants it finished. Write the message you never sent, short, then decide what to do with it.",
                action: "Finish it",
                [("who", "Who it's for", "Just a name, or who they are"),
                 ("message", "The message", "Short, and all the way to the end"),
                 ("next", "What you'll do with it", "Send it, keep it, or burn it")]
            )
        ),
        AcademyLessonModule(
            id: "ink-binding-jar-012",
            sessionID: "ink-binding",
            title: "Open the Jar",
            realSubject: "reading back your own sentences on a grey day",
            concept: "Keep your sentences in one place. On a grey day, read five of them back. They're proof your days weren't all the same.",
            lectureBeats: [
                "Sentences you wrote on good days are there for the bad ones.",
                "Reading a few back can crack a grey day open.",
                "Every sentence is a moment saved from being forgotten."
            ],
            demonstration: "Professor Villanelle brought in a big glass jar full of folded papers, a sentence from every student who'd ever sat in the Inkworks. She let each person pull one out and read it. Zara pulled out one in handwriting she knew. It was her own, from her very first week.",
            interactionPrompt: "Which sentence from this year would you put in the jar first?",
            realWorldPractice: "Gather every sentence you wrote this year into one place. On the next grey day, read five of them back.",
            number: 12,
            mode: "Opening the jar",
            lecture: "End of the year. If you've been writing your sentences, you've got a jar of them now, or a notebook, or a list on your phone. On the next grey day, open it. Read five. Not all of them. Five. The toast in triangles. The fire that sounded orange. The bus you nearly missed. You'll feel the grey crack a little. That's proof. Proof your days weren't all the same, even when they felt it. Every sentence you wrote this year was one moment you stole back from forgetting. Keep stealing. The jar's never full.",
            twoMinutes: "Find something you wrote months ago, a note, a message, anything. Read it. Write down what it brought back.",
            reading: westReading,
            practice: inkPractice(
                "jar", title: "Open the Jar",
                invitation: "Villanelle's last lesson of the year: read back what you wrote. Copy out the sentence that brought the most back, and say why.",
                action: "Put it back in the jar",
                [("sentence", "The sentence", "Copy it out"),
                 ("back", "What it brought back", "The day around it"),
                 ("why", "Why that one", "What it has that the others don't")]
            )
        )
    ]

    // MARK: Quiet Hours: Center = Rest

    private static let centerReading = "The Wonder Compass, Chapter 10: Center = Rest"

    private static func quietPractice(
        _ id: String, title: String, invitation: String, action: String,
        _ fields: [(id: String, label: String, placeholder: String)]
    ) -> AcademyActivity {
        practice("quiet-hours", "quiet-hours-\(id)", kind: .restCheckIn, title: title, invitation: invitation, action: action, fields)
    }

    /// Stonebrook is slow and plain: rest is the ground under every direction, never a prize. No
    /// sleepy sayings. His own fault (waiting past the moment a clear instruction was needed) is the
    /// lesson he gets wrong. Every worksheet comes after the room's quiet minute.
    static let quietHours: [AcademyLessonModule] = [
        AcademyLessonModule(
            id: "quiet-hours-integration-001",
            sessionID: "quiet-hours",
            title: "Stopping Counts",
            realSubject: "rest, and why stopping helps you start again",
            concept: "When you stop, your body and your head get a chance to sort out the day. Stopping is part of the work.",
            lectureBeats: [
                "Rest is what everything else stands on.",
                "You can choose to stop before you're too tired to keep going.",
                "A rest is a good time to ask what you're still carrying from today."
            ],
            demonstration: "Professor Stonebrook laid an hourglass on its side, so the sand couldn't run. Then he sat down and waited. That was the lesson.",
            interactionPrompt: "Name one thing a short stop would look after.",
            realWorldPractice: "Stop for five minutes today. Afterwards, write down what got clearer.",
            number: 1,
            mode: "The big idea",
            lecture: "Sit down. You don't have to do anything yet. Most people think rest is the prize you get when the work's done. It isn't. It's what the work stands on. A compass needle spins on a little pin in the middle. Take the pin out and the needle falls off. Rest is the pin. You can't notice anything when you're worn through. You can't go anywhere. You can't feel your own hands. So in this room we practise stopping. Not falling over. Stopping, before you have to. That's harder than it sounds. We'll start by sitting here a while.",
            twoMinutes: "Stop. Put everything down for two minutes. Then write one thing that feels clearer than before.",
            reading: centerReading
        ),
        AcademyLessonModule(
            id: "quiet-hours-numbing-002",
            sessionID: "quiet-hours",
            title: "Resting or Numbing?",
            realSubject: "the difference between real rest and scrolling",
            concept: "Lying still with your phone isn't the same as resting. Rest leaves you fuller. Numbing leaves you emptier.",
            lectureBeats: [
                "Scrolling keeps your head busy even when your body's still.",
                "Real rest happens when the stream of new things stops.",
                "You can tell which one it was by how you feel afterwards."
            ],
            demonstration: "Professor Stonebrook had the class spend ten minutes looking at their phones, then ten minutes looking out of the window. Afterwards he asked for one word for how each ten minutes felt. For the phones, most of them wrote \"tired\". For the window, Finn wrote \"slow\", then crossed it out and wrote \"good\".",
            interactionPrompt: "Think of the last time you rested. Did you come away fuller or emptier?",
            realWorldPractice: "Next time you reach for your phone to rest, try ten minutes of looking out of a window instead. Notice which leaves you fuller.",
            number: 2,
            mode: "The usual mistake",
            lecture: "Here's a question. Last time you lay on the sofa with your phone for two hours, how did you feel when you got up? Rested? Or sort of scraped out, tired and buzzing at the same time? That's because it wasn't rest. Your body was still, but your head was working the whole time. Look at this. Skip that. Like this. Hate that. Hundreds of little choices a minute. That's numbing. It turns the noise down. Rest turns it off. If you want to know which one you're doing, notice how you feel when you stop. Rest leaves you fuller. Numbing leaves you emptier. Both are allowed. Just don't call one the other.",
            twoMinutes: "Put your phone face down for two minutes and look at something far away. Write one word for how you feel after.",
            reading: centerReading,
            practice: quietPractice(
                "numbing", title: "Fuller or Emptier",
                invitation: "Stonebrook wants you to notice the difference. After your quiet minute, write what you usually do to rest, and whether it leaves you fuller or emptier.",
                action: "Return from the pause",
                [("usual", "What you usually do to rest", "The sofa, the phone, the bath"),
                 ("fuller", "Fuller or emptier?", "Be honest")]
            )
        ),
        AcademyLessonModule(
            id: "quiet-hours-minute-003",
            sessionID: "quiet-hours",
            title: "One Minute of Nothing",
            realSubject: "sitting still and doing nothing for one minute",
            concept: "Sit for one minute and do nothing at all. It's harder than it sounds, and it clears more than you'd think.",
            lectureBeats: [
                "One minute of doing nothing is harder than it sounds.",
                "The first part is easy, the middle's boring, and the end can feel uncomfortable.",
                "If a minute's too long, start with ten seconds and add one a day."
            ],
            demonstration: "Professor Stonebrook rang a small bell, and the whole room sat still for one minute. Somebody's stomach rumbled at forty seconds. Nobody laughed until the bell went again, and then everybody did.",
            interactionPrompt: "What was the hardest part of the minute?",
            realWorldPractice: "Do one minute of nothing every day this week. Phone face down, eyes closed, no trying.",
            number: 3,
            mode: "One minute",
            lecture: "Today's lesson takes one minute, and it's the hardest thing I'll ask of you all year. Put your phone face down, out of reach. Sit in a chair. Close your eyes. Do nothing. Don't try to empty your head. Don't think about your breathing. Don't plan your tea. Just sit. The first twenty seconds are fine. The next twenty are boring. The last twenty might feel a bit uncomfortable, because things you've been keeping busy so you don't have to feel them come up. Let them. You're safe here. When the minute's over, notice what's different. If a minute's too long, do ten seconds. Tomorrow, do eleven.",
            twoMinutes: "Put everything down. Close your eyes for one minute and do nothing. Then write down what was different afterwards.",
            reading: centerReading,
            practice: quietPractice(
                "minute", title: "One Minute of Nothing",
                invitation: "Stonebrook's hardest lesson takes one minute. Do nothing at all, then write which part was hardest and what was different after.",
                action: "Return from the minute",
                [("hardest", "The hardest part", "The boring bit, the itchy bit"),
                 ("after", "What was different after", "\"Nothing\" is a real answer")]
            )
        ),
        AcademyLessonModule(
            id: "quiet-hours-chair-004",
            sessionID: "quiet-hours",
            title: "The Chair Is Holding You",
            realSubject: "letting something hold you up so your body can let go",
            concept: "Something's always holding you up: a chair, the floor, the ground. For one minute, let it, and stop holding yourself together.",
            lectureBeats: [
                "A chair holds you up the whole time you sit in it.",
                "Noticing where it touches you helps your body let go.",
                "Putting everything down for a minute makes it easier to pick back up."
            ],
            demonstration: "Professor Stonebrook asked everyone to sit back and say out loud every place the chair was touching them. It started slowly. By the end Finn was saying \"my left elbow, a bit\" with his eyes shut, and his shoulders had come down about an inch.",
            interactionPrompt: "Where's your chair touching you right now?",
            realWorldPractice: "Once a day this week, sit back in a chair and let it take your whole weight for one minute.",
            number: 4,
            mode: "Showing how",
            lecture: "Sit back. All the way. Now notice where the chair touches you. The backs of your legs. Your back. Your elbows, maybe. That chair's been holding you up the whole time you've been sitting there, and you haven't once had to think about it. The floor's holding the chair. The ground's holding the floor. For one minute, let them. Let your shoulders drop. Let your hands go heavy. You don't have to hold yourself together right now. The furniture's doing it. When you stand up again you can pick it all back up, and it'll be easier, because you put it down for a bit.",
            twoMinutes: "Sit back. Name every place the chair's touching you. Let it take your weight for one minute.",
            reading: centerReading,
            practice: quietPractice(
                "chair", title: "Let the Chair Hold You",
                invitation: "Stonebrook wants you held. After your quiet minute, write where the chair was touching you and what you put down.",
                action: "Get up slowly",
                [("touching", "Where the chair touched you", "The backs of your legs, your back"),
                 ("put-down", "What you put down", "Just for the minute")]
            )
        ),
        AcademyLessonModule(
            id: "quiet-hours-key-005",
            sessionID: "quiet-hours",
            title: "Dalí's Key",
            realSubject: "short naps, and the useful space between awake and asleep",
            concept: "The space between awake and asleep is where stuck things come loose. A short nap can fix more than you'd expect.",
            lectureBeats: [
                "Dalí napped holding a key over a plate, so the clatter would wake him as he fell asleep.",
                "The edge of sleep is where ideas wander in.",
                "A short nap, about twenty minutes, can leave you clearer instead of groggy."
            ],
            demonstration: "Professor Stonebrook handed out blankets and let the class nap for twenty minutes on the floor of the Still Room. When they woke up, he asked what they'd seen. Most of them had nothing. One girl said she'd dreamed the answer to a maths problem. It was wrong, but she was very pleased about it.",
            interactionPrompt: "When did a nap last fix something for you?",
            realWorldPractice: "Try one short nap this week, about twenty minutes. Write down anything that came to you just before or just after.",
            number: 5,
            mode: "A true story",
            lecture: "The painter Salvador Dalí had a trick for napping. He'd sit in a chair holding a heavy key over a plate on the floor. As he drifted off, his fingers would let go. The key would hit the plate, the clatter would wake him, and he'd paint whatever he'd just been seeing. That bit between awake and asleep is a strange, useful place. Ideas wander in there. Things you've been stuck on come loose. You don't need a key. You need twenty minutes lying down somewhere warm, and no expectations. Some naps fix more than they should. I've had a few that fixed a whole week.",
            twoMinutes: "Close your eyes for two minutes, as if you were about to fall asleep. Write down the first thing that floats in.",
            reading: "Salvador Dalí, 50 Secrets of Magic Craftsmanship (1948)",
            practice: quietPractice(
                "nap", title: "The Twenty-Minute Nap",
                invitation: "Stonebrook says some naps fix more than they should. Take one short nap. Write how long it was and what floated in at the edge of sleep.",
                action: "Wake up and report",
                [("long", "How long you slept", "About twenty minutes is plenty"),
                 ("floated", "What floated in", "A picture, an idea, or nothing at all")]
            )
        ),
        AcademyLessonModule(
            id: "quiet-hours-bored-walk-006",
            sessionID: "quiet-hours",
            title: "The Bored Walk",
            realSubject: "walking a familiar route so your mind can wander",
            concept: "Walk a way you know by heart, with no phone and no music. Your feet take over, and your head gets to wander.",
            lectureBeats: [
                "On a route you know, your feet can walk without you.",
                "That leaves your head free to drift.",
                "Answers you've been chasing often turn up on walks like this."
            ],
            demonstration: "Professor Stonebrook walked the class round the same corridor three times without saying anything. On the first lap people were fidgety. On the second they were bored. On the third, Finn suddenly stopped and said, \"Oh!\" He wouldn't say what about, but he looked very happy.",
            interactionPrompt: "What's a walk you know so well your feet could do it without you?",
            realWorldPractice: "Take one walk this week on a way you know well, with no phone and no music. Notice where your head wanders.",
            number: 6,
            mode: "A walk",
            lecture: "Leave your phone at home. Go for a walk on a way you know so well your feet could do it without you. No podcast. No music. No counting steps. Just walk. On a new route you have to keep paying attention, and that's tiring. On an old one, your feet take over and your head's free to wander off on its own. That's where the good thoughts are. They've been sitting there waiting for you to stop talking over them. You might come back with an answer. You might come back with nothing but cold ears. Both count.",
            twoMinutes: "Walk to the furthest room in your home and back, slowly, without your phone. Write down what you thought about.",
            reading: centerReading,
            practice: quietPractice(
                "bored-walk", title: "The Bored Walk",
                invitation: "Stonebrook wants you bored on purpose. Walk a way you know by heart, with no phone. Write where you went, and where your head went.",
                action: "Come back in",
                [("where", "Where you walked", "A way your feet know"),
                 ("head", "Where your head went", "What turned up while you walked")]
            )
        ),
        AcademyLessonModule(
            id: "quiet-hours-tree-007",
            sessionID: "quiet-hours",
            title: "Look at a Tree",
            realSubject: "why looking at branching patterns in nature calms you down",
            concept: "Look at a tree for five minutes. Its branches split into smaller and smaller branches, and that pattern is easy on your eyes and calms you down.",
            lectureBeats: [
                "Trees, rivers and lightning all branch the same way, smaller and smaller.",
                "A scientist found that looking at patterns like this calms people down.",
                "Five minutes with a tree can rest your eyes after a day of screens."
            ],
            demonstration: "Professor Stonebrook took the class out to the old oak by the Still Room and asked them to follow one branch with their eyes, from the trunk to the very last twig. Nobody managed it in under five minutes. Nobody wanted to stop, either.",
            interactionPrompt: "What's the nearest tree to where you are right now?",
            realWorldPractice: "Look at one tree for five whole minutes this week. Follow one branch all the way out to the end.",
            number: 7,
            mode: "A real finding",
            lecture: "Look at a tree. Not quickly. For five minutes. Notice how the trunk splits into branches, and the branches into smaller branches, and those into twigs, and the twigs into the veins on the leaves. It's the same shape over and over, getting smaller. Rivers do it on a map. Lightning does it. The insides of your lungs do it. A scientist called Richard Taylor has spent years studying patterns like this, and he's found that looking at them calms people down. Your eyes don't have to work at them. They already know the shape. A screen's all hard edges and straight lines. A tree's something your eyes can rest on.",
            twoMinutes: "Find a tree, from a window if you need to. Follow one branch with your eyes, from the trunk to the smallest twig.",
            reading: centerReading,
            practice: quietPractice(
                "tree", title: "Five Minutes With a Tree",
                invitation: "Stonebrook wants your eyes resting on a tree. Look at one for five minutes. Write which tree it was, and how you felt after.",
                action: "Come back from the tree",
                [("tree", "Which tree", "Where it is, what it looks like"),
                 ("felt", "How you felt after", "Compared with before")]
            )
        ),
        AcademyLessonModule(
            id: "quiet-hours-wide-eyes-008",
            sessionID: "quiet-hours",
            title: "Wide Eyes",
            realSubject: "using wide, relaxed looking to calm your body down",
            concept: "When you're worried, your eyes go narrow. Look at one spot and try to see the whole room at once, and your body settles.",
            lectureBeats: [
                "Worry makes your eyes narrow and fix on one thing.",
                "Looking wide, taking in the edges of the room, tells your body things are safe.",
                "Lots of people find their breathing slows down when they do it."
            ],
            demonstration: "Professor Stonebrook asked the class to stare at a mark on the wall and say what they could see at the very edges without moving their eyes. Somebody saw the door open. Somebody saw a spider on the ceiling. Finn saw Professor Stonebrook pull a face, and nearly moved his eyes.",
            interactionPrompt: "Look at one spot. What can you see at the very edges?",
            realWorldPractice: "Next time you feel tense this week, look at one spot and widen your eyes to take in the whole room. Count five breaths.",
            number: 8,
            mode: "A game",
            lecture: "When you're busy or worried, your eyes go narrow. You stare at one thing, the screen, the email, the problem, as if it might jump at you. Try this. Pick a spot on the wall in front of you. Keep looking at it. Now, without moving your eyes, try to see the corners of the room at the same time. Both sides. The ceiling and the floor. Notice what happens to your breathing. For lots of people it slows down, and their shoulders drop a little. Narrow eyes are for danger. Wide eyes are for when it's safe. You can tell your body it's safe just by looking wider.",
            twoMinutes: "Look at one spot in front of you. Without moving your eyes, see as much of the room as you can. Stay like that for one minute.",
            reading: centerReading,
            practice: quietPractice(
                "wide-eyes", title: "Wide Eyes",
                invitation: "Stonebrook wants you looking wide. After your quiet minute, look at one spot and take in the whole room. Write what you saw at the edges and what your breathing did.",
                action: "Let your eyes come back",
                [("edges", "What you saw at the edges", "Without moving your eyes"),
                 ("breathing", "What your breathing did", "Faster, slower, the same")]
            )
        ),
        AcademyLessonModule(
            id: "quiet-hours-tide-009",
            sessionID: "quiet-hours",
            title: "When the Tide Goes Out",
            realSubject: "working in rhythm, with breaks before you crash",
            concept: "Most people can only concentrate for about an hour and a half before they need a break. When you get fidgety, stop for ten minutes.",
            lectureBeats: [
                "Your energy comes and goes in waves through the day.",
                "Fidgeting, hunger and reading the same line twice mean it's time to stop.",
                "A ten-minute break now saves you from crashing later."
            ],
            demonstration: "Professor Stonebrook set a clock on his desk at the start of a long study session and told the class to stop the moment they caught themselves reading the same line twice. Within the hour, all of them had stopped at least once. Finn stopped four times, and said it was the best work he'd done all term.",
            interactionPrompt: "How do you know when you've been working too long?",
            realWorldPractice: "Next time you're working on something long, stop for ten minutes the first time you read the same line twice.",
            number: 9,
            mode: "Your body's clock",
            lecture: "You're not a machine. You're more like the tide. Lots of people find they can only really concentrate for about an hour and a half before their body asks for a break. You get fidgety. Hungry. You read the same line three times. That isn't you being lazy. That's the tide going out. If you push on through with coffee and gritted teeth, you can keep going, but you're borrowing, and it has to be paid back later. So when the tide goes out, stop. Ten minutes. Stand up, look out of a window, get a glass of water. Then go back. Work, rest. Work, rest. That's the rhythm.",
            twoMinutes: "Think about today. When did your energy dip? Write down what you were doing, and whether you stopped.",
            reading: centerReading,
            practice: quietPractice(
                "tide", title: "When the Tide Goes Out",
                invitation: "Stonebrook wants you to catch the dip. After your quiet minute, write what tells you it's time to stop, and what you did with your ten minutes.",
                action: "Go back in",
                [("signs", "What tells you", "Fidgeting, hunger, the same line twice"),
                 ("ten", "What you did with your ten minutes", "A window, a drink, a stretch")]
            )
        ),
        AcademyLessonModule(
            id: "quiet-hours-car-010",
            sessionID: "quiet-hours",
            title: "Ten More Minutes in the Car",
            realSubject: "taking a pause before something hard, and ending it",
            concept: "Pausing before something hard is part of doing it. Take your ten minutes, then give the pause an end.",
            lectureBeats: [
                "Sitting still for a bit before a hard thing is normal, and it helps.",
                "The pause is where you gather yourself.",
                "Give it an end, like one breath and the word \"right\", and then go."
            ],
            demonstration: "Before an exam, Professor Stonebrook made the whole class sit outside the hall for five minutes with their eyes closed. Then he said, \"Right,\" and they all went in. Afterwards, three of them said those five minutes were the part of the day they remembered best.",
            interactionPrompt: "What's a hard thing coming up that you'll need a pause before?",
            realWorldPractice: "Before the next hard thing this week, take a short pause on purpose. Notice three things, take one slow breath, say \"right\", and go.",
            number: 10,
            mode: "Before a hard thing",
            lecture: "You know when you've parked, and you just sit there. Engine off. Ten more minutes. You're not ready to go in yet. People feel bad about that. They shouldn't. The pause before a hard thing is part of the hard thing. It's where you gather yourself. I've done it outside a hospital. I've done it outside my own front door. Here's what I do. I put both hands on the wheel. I notice three things I can see out of the window. I take one slow breath. Then I say out loud, \"Right.\" And I get out. The pause is allowed. It just needs an end.",
            twoMinutes: "Think of something hard you've got coming up. Sit still for one minute as if you were about to go in. Then say \"right\" out loud.",
            reading: centerReading,
            practice: quietPractice(
                "pause", title: "The Pause Before",
                invitation: "Stonebrook says the pause before a hard thing is part of it. After your quiet minute, write what the hard thing is, and how you'll end the pause when it comes.",
                action: "Say \"right\"",
                [("hard", "The hard thing", "You don't have to say much"),
                 ("end", "How you'll end the pause", "One breath, one word, a hand on the door")]
            )
        ),
        AcademyLessonModule(
            id: "quiet-hours-call-time-011",
            sessionID: "quiet-hours",
            title: "When to Get Up",
            realSubject: "giving rest an end, so it doesn't turn into being stuck",
            concept: "Rest needs an end. Before you stop, know the one small thing you'll do when you get up.",
            lectureBeats: [
                "Resting can turn into being stuck if nobody calls time.",
                "Sometimes the kind thing is a clear next step.",
                "Before you rest, pick one small thing you'll do afterwards."
            ],
            demonstration: "A student came to the Still Room upset about an essay. Professor Stonebrook sat with her in silence for most of an hour. Then Finn, passing, said, \"Just write the first line badly.\" She did, and went off to finish it. Stonebrook said Finn had taught the better lesson that day, and wrote it on the board.",
            interactionPrompt: "What's the one small thing you'll do when you get up from this?",
            realWorldPractice: "Next time you take a rest, decide first what one small thing you'll do when it ends. Then do it.",
            number: 11,
            mode: "Someone gets it wrong",
            lecture: "I've got a fault, and I'll tell you before somebody else does. I wait too long. A student's stuck, and I sit with them, kindly, in the quiet, when what they needed was somebody to say, \"Go and get a glass of water, then do the first sum.\" Rest has an end. Stopping isn't the same as giving up, but it can turn into it if nobody calls time. So when you rest, know what you'll do when you get up. Not everything. One small thing. Then, when the rest is done, get up and do it. Enough for today is still somewhere to go.",
            twoMinutes: "Think of something you've been stuck on. Write down the very first small step, so small you could do it badly in five minutes.",
            reading: centerReading,
            practice: quietPractice(
                "call-time", title: "Call Time",
                invitation: "Stonebrook's owning up to waiting too long. After your quiet minute, write the one small thing you'll do when you get up, and whether you did it.",
                action: "Get up and do it",
                [("thing", "The one small thing", "So small you could do it badly"),
                 ("did", "Did you do it?", "Be honest")]
            )
        ),
        AcademyLessonModule(
            id: "quiet-hours-bench-012",
            sessionID: "quiet-hours",
            title: "A Bench With a View",
            realSubject: "letting a whole year settle before the next one",
            concept: "At the end of something big, sit still and let it settle. Rest is when what you lived becomes part of you.",
            lectureBeats: [
                "Everything you did this year is still settling in.",
                "Rest is when your head sorts it out and keeps what matters.",
                "Ten minutes on a bench is enough to let it happen."
            ],
            demonstration: "On the last day of term, Professor Stonebrook took the class to a bench that looked out over the Academy's bins. They sat there for ten minutes. A fox came past. Nobody said a word about it until supper, and then they couldn't stop.",
            interactionPrompt: "What from this year do you want to let settle?",
            realWorldPractice: "Find a bench with a view of something ordinary, and sit there for ten minutes doing nothing with the time.",
            number: 12,
            mode: "Sitting still",
            lecture: "Last lesson of the year. Find a bench with a view of something ordinary. A car park. A hedge. A bus stop. Sit on it for ten minutes. Don't do anything with the time. Let the year come and sit next to you. Everything you noticed, everywhere you went, everything you felt and wrote down. It's all still settling. Rest is when that happens. It's when the days you lived become part of you, instead of just things that went past. Sit until the bench is just a bench again. Then go home. You've done enough for this year.",
            twoMinutes: "Sit somewhere with a view of something ordinary. For two minutes, let the last few weeks come and sit with you. Write down the first thing that does.",
            reading: centerReading,
            practice: quietPractice(
                "bench", title: "The Last Bench",
                invitation: "Stonebrook's last lesson of the year: sit on a bench for ten minutes and let the year settle. Write where you sat, and what came and sat with you.",
                action: "Go home",
                [("where", "Where you sat", "A bench with a view of something ordinary"),
                 ("came", "What came and sat with you", "From this year")]
            )
        )
    ]

    // MARK: Basic Enchantments: Everything Speaks

    private static let charactersReading = "The Wonder Compass, Chapter 8B: Characters"

    private static func spellPractice(
        _ id: String, title: String, invitation: String, action: String,
        _ fields: [(id: String, label: String, placeholder: String)]
    ) -> AcademyActivity {
        practice("basic-enchantments", "enchantments-\(id)", kind: .enchantmentCasting, title: title, invitation: invitation, action: action, fields)
    }

    /// Wispwood teaches one enchantment a month, cast by hand: in the app the class still opens
    /// the spellbook and the camera; on paper the reader does it in the boxes. She's scattered and
    /// delighted, apologises to objects, and follows an accident far enough to learn, then
    /// remembers the edges. The month she forgot them is the lesson she gets wrong.
    static let enchantments: [AcademyLessonModule] = [
        AcademyLessonModule(
            id: "enchantments-object-voice-001",
            sessionID: "basic-enchantments",
            title: "Ask the Mug Nicely",
            realSubject: "looking closely at an object, and imagining what it would say",
            concept: "To make an object talk, look at it properly first. What it says has to come from what you can see on it.",
            lectureBeats: [
                "Enchanting something starts with describing it. Bossing it about doesn't work.",
                "The safest magic asks what the thing already seems to know.",
                "Mistakes can be fun, but you're still in charge of the spell."
            ],
            demonstration: "Professor Wispwood said sorry to a chipped mug. Then she listed everything you could see on it. Then she let the mug answer, using only those things.",
            interactionPrompt: "Pick something in this room. What do its scratches and marks say about it?",
            realWorldPractice: "Pick one ordinary thing at home. Write what it would say, using only what you can see on it.",
            number: 1,
            mode: "The big idea",
            lecture: "Oh, sorry, that's the kettle. It always wants to join in. Right. Today's enchantment is called Everything Speaks, and it's the first one everybody learns. Pick up something ordinary. A mug will do. Don't tell it what to say. That's rude, and it never works. Look at it first. The chip on the rim. The brown ring inside where the tea sat. The way the handle's gone shiny from your thumb. Now ask it something. What's the worst thing anyone's ever poured into you? Then let it answer, using only what you can see on it. The mug can't lie about its own chip. That's what keeps the magic honest.",
            twoMinutes: "Pick the nearest object. Look at its marks and scratches. Write one thing it would say if it could.",
            reading: charactersReading,
            practice: spellPractice(
                "speaks", title: "Everything Speaks",
                invitation: "Wispwood wants an object to answer you. Pick one, write what you can see on it, what you asked it, and what it said back.",
                action: "Let it speak",
                [("object", "The object", "A mug, a key, a shoe"),
                 ("marks", "What you can see on it", "Chips, marks, shiny bits"),
                 ("answer", "What it said back", "Using only what you can see")]
            )
        ),
        AcademyLessonModule(
            id: "enchantments-triangles-002",
            sessionID: "basic-enchantments",
            title: "Two Triangles and a Circle",
            realSubject: "why our brains turn things into characters without being asked",
            concept: "Your brain can't help turning moving shapes into characters. Enchanting objects just uses something you already do.",
            lectureBeats: [
                "People watching two triangles and a circle saw a bully, a scared one and a hero.",
                "Brains turn moving things into characters without being asked.",
                "Doing it on purpose, and kindly, is what enchanting is."
            ],
            demonstration: "Professor Wispwood pushed three teacups round the table with a spoon, very slowly, and asked what was happening. Within a minute the class had decided the chipped one was being left out. Wilbur moved it back into the group without thinking, then went pink.",
            interactionPrompt: "What thing in your life do you already talk to as if it's a person?",
            realWorldPractice: "Notice every time today you talk to a thing as if it's a person: the printer, the car, the door. Write down what you said.",
            number: 2,
            mode: "A real experiment",
            lecture: "In 1944 two scientists, Fritz Heider and Marianne Simmel, made a tiny cartoon. Just two triangles and a little circle moving round a box. No faces. No words. Then they asked people what they'd seen. Nearly everybody told a story. The big triangle was a bully. The little circle was frightened. The small triangle was brave and came to help. Oh, I love that. Nobody told them to. Their brains just did it. You do it too. You shout at the printer. You say the car doesn't want to start this morning. So you're already enchanting things all day long. In this room we just do it on purpose, and kindly.",
            twoMinutes: "Push two or three small things around a table for one minute. Write down the story your brain made up about them.",
            reading: "Fritz Heider and Marianne Simmel, \"An Experimental Study of Apparent Behavior\" (1944)",
            practice: spellPractice(
                "triangles", title: "Who's Who",
                invitation: "Wispwood says you already do this. Write down a thing you talk to as if it's a person, what you say to it, and what kind of character it is.",
                action: "Introduce them",
                [("thing", "The thing", "The printer, the car, the kettle"),
                 ("say", "What you say to it", "Out loud or in your head"),
                 ("character", "What kind of character it is", "Grumpy, shy, loyal, dramatic")]
            )
        ),
        AcademyLessonModule(
            id: "enchantments-poetry-003",
            sessionID: "basic-enchantments",
            title: "Everything's Poetry",
            realSubject: "turning one real detail into a line that sounds good out loud",
            concept: "Poetry is one real little detail, said in a way that has music in it. Find the detail first, then find the music.",
            lectureBeats: [
                "Poetry starts with one real little detail.",
                "Then you say it out loud and change words until it sounds right.",
                "No rhymes needed. If it sounds good whispered, it's working."
            ],
            demonstration: "Professor Wispwood wrote \"the rain is on the window\" on the board, then let the class say it out loud and change one word at a time. By the end it said \"the rain keeps knocking, then forgets why\". Finn said it sounded like his grandad. Wispwood said that was the best thing anybody can say about a line.",
            interactionPrompt: "Pick a sound in this room and say it in a way that has music in it.",
            realWorldPractice: "Find one real little detail today and write it as one line of poetry. Say it out loud until it sounds right.",
            number: 3,
            mode: "Showing how",
            lecture: "Everything's Poetry. People get frightened of this one, so let's be very clear. You don't need rhymes. You don't need long words. You need one real little detail, and a way of saying it that sounds nice in your mouth. Oh, listen: the radiator's ticking. Ticking, ticking, like a clock that's lost its face. See? That's all. The real thing first. The radiator, ticking. Then the music. Say it out loud, change a word, say it again, until it sounds right. If it sounds good when you whisper it, it's poetry. If it only looks good on paper, keep going.",
            twoMinutes: "Pick one thing you can hear or see. Write one line about it. Whisper it. Change one word. Whisper it again.",
            reading: charactersReading,
            practice: spellPractice(
                "poetry", title: "Everything's Poetry",
                invitation: "Wispwood wants one real detail with music in it. Write the plain version, then the one that sounds right out loud.",
                action: "Whisper it",
                [("plain", "The plain detail", "The rain's on the window"),
                 ("line", "The line with music in it", "Say it out loud until it sounds right")]
            )
        ),
        AcademyLessonModule(
            id: "enchantments-haiku-004",
            sessionID: "basic-enchantments",
            title: "Three Quiet Lines",
            realSubject: "writing a haiku about one small moment",
            concept: "A haiku is three short lines about one small moment happening right now: something still, something moving, and one thing you can sense.",
            lectureBeats: [
                "Bashō's poem about a frog and an old pond is more than three hundred years old.",
                "A haiku catches one small moment, as it happens.",
                "You don't need to count syllables. Three short, quiet lines will do."
            ],
            demonstration: "Professor Wispwood opened the window of the Spark Annex and asked everyone to write three lines about whatever happened next. A pigeon landed on the sill, looked at them all, and left. Eleven students wrote about the pigeon. Wilbur wrote about the draught.",
            interactionPrompt: "What's happening right now that could be three quiet lines?",
            realWorldPractice: "Write one haiku this week about something small happening right in front of you.",
            number: 4,
            mode: "A poem from long ago",
            lecture: "In 1686 a Japanese poet called Matsuo Bashō wrote a poem about an old pond. A frog jumps in. You hear the water. That's very nearly all of it. Three short lines, and people have been reading it for more than three hundred years. A haiku catches one small moment, usually something outside, usually happening right now. You don't have to count syllables. The old Japanese poets didn't count the way we do anyway. Just three short lines. Something still. Something that moves. And one thing you can hear, or smell, or feel. Oh, careful with this one. It's quiet. Shouting scares it off.",
            twoMinutes: "Look out of the nearest window. Write three short lines: something still, something moving, something you can hear.",
            reading: "Matsuo Bashō, the old pond (1686)",
            practice: spellPractice(
                "haiku", title: "Three Quiet Lines",
                invitation: "Wispwood wants one small moment in three short lines: something still, something moving, and something you can sense.",
                action: "Say it quietly",
                [("still", "Something still", "The first line"),
                 ("moving", "Something moving", "The second line"),
                 ("sense", "Something you can sense", "The third line")]
            )
        ),
        AcademyLessonModule(
            id: "enchantments-stories-005",
            sessionID: "basic-enchantments",
            title: "Who Held You Last?",
            realSubject: "reading the story an object's marks can tell",
            concept: "Every object has been somewhere before you. Ask it who held it last, and answer using only the marks you can find on it.",
            lectureBeats: [
                "Every object has a past, even a pencil.",
                "Dents, names, stickers and wear are clues to its story.",
                "The story's already there. You're the one listening to it."
            ],
            demonstration: "Professor Wispwood brought a box of old things from the Academy's lost property and gave one to each student. Finn got a glove with a darned thumb. By the end of the lesson he'd decided it belonged to a postman who bit his nails. Nobody could prove him wrong.",
            interactionPrompt: "Pick something near you. Who do you think held it last?",
            realWorldPractice: "Pick one old thing at home, or in a second-hand shop. Write its story using only the clues you can find on it.",
            number: 5,
            mode: "Asking questions",
            lecture: "Everything's Stories. Every object you own has been somewhere before you. Oh, even that pencil. Especially that pencil. So ask it. Who held you last? Where were you before you were here? What's the worst day you've had? Then answer, but only with what you can find on it. A dent means it was dropped. A name written inside means it belonged to somebody once. A sticker half peeled off means somebody changed their mind. The object's already telling a story. You're just the one listening. Second-hand shops are full of them. I can't go in one without crying a little.",
            twoMinutes: "Pick up the oldest thing within reach. Find one mark on it. Write what you think happened.",
            reading: charactersReading,
            practice: spellPractice(
                "stories", title: "Who Held You Last?",
                invitation: "Wispwood wants an object's story. Find an old thing, write the clues you can see on it, and the story they tell.",
                action: "Tell its story",
                [("thing", "The thing", "Something that's been somewhere"),
                 ("clues", "The clues", "Dents, names, stickers, wear"),
                 ("story", "Its story", "Who held it last, and what happened")]
            )
        ),
        AcademyLessonModule(
            id: "enchantments-riddle-006",
            sessionID: "basic-enchantments",
            title: "A Moth Ate Words",
            realSubject: "riddles, and describing a thing truthfully from a strange angle",
            concept: "A riddle is an object describing itself sideways. Say true things about it without saying what it is, and see if anyone guesses.",
            lectureBeats: [
                "The Exeter Book holds riddles that are about a thousand years old.",
                "Some of them are still argued about, because the answers were never written down.",
                "A good riddle says only true things, just from a strange angle."
            ],
            demonstration: "Professor Wispwood had each student write a riddle about something in their pocket. Wilbur's said, \"I have teeth but never eat, and I go through your hair but never get lost.\" Everybody got it straight away. Wilbur said that meant it was a good one. Wispwood said it meant it was a comb.",
            interactionPrompt: "Describe something in this room without saying its name, and without lying.",
            realWorldPractice: "Write a riddle about one ordinary thing at home. Try it on somebody and see if they guess.",
            number: 6,
            mode: "A riddle",
            lecture: "About a thousand years ago in England, somebody copied nearly a hundred riddles into a big book that's still kept at Exeter Cathedral. They're in Old English, and the answers aren't written down, so people still argue about some of them. Here's one I love. It says a moth ate words. A thief in the dark swallowed a famous song, and wasn't one bit cleverer for all the words it ate. Oh, isn't that perfect? It's a bookworm. A riddle is just an object describing itself sideways, so you can't quite see it. Pick something. Describe it without saying what it is, and without lying. Then see if anybody guesses.",
            twoMinutes: "Pick something you can see. Write two true things about it without saying what it is. Could somebody guess?",
            reading: "The Exeter Book riddles (about a thousand years old)",
            practice: spellPractice(
                "riddle", title: "Make a Riddle",
                invitation: "Wispwood wants an object to describe itself sideways. Write a riddle, its answer, and whether anybody guessed.",
                action: "Ask the riddle",
                [("riddle", "The riddle", "Only true things, from a strange angle"),
                 ("answer", "The answer", "What it really is"),
                 ("guessed", "Did anybody guess?", "Who, and how fast")]
            )
        ),
        AcademyLessonModule(
            id: "enchantments-pencil-007",
            sessionID: "basic-enchantments",
            title: "Nobody Knows How to Make a Pencil",
            realSubject: "how many people and places it takes to make one ordinary thing",
            concept: "Every ordinary thing was made by thousands of people who never met. Pick one, and follow where its parts came from.",
            lectureBeats: [
                "Leonard Read wrote that no single person knows how to make a pencil.",
                "The wood, the lead, the rubber and the metal all came from different places and people.",
                "Following a thing's threads backwards shows how many hands it passed through."
            ],
            demonstration: "Professor Wispwood held up a cup of tea and asked the class to name everybody who'd helped make it. They got to the tea pickers, the ship's crew, the cow, the farmer, the potter who made the cup, and whoever dug up the clay. Then Finn asked who'd built the ship, and they had to stop for lunch.",
            interactionPrompt: "Pick something on your table. Where did its parts come from?",
            realWorldPractice: "Pick one ordinary thing and trace where its parts came from, as far back as you can go. Count the people.",
            number: 7,
            mode: "A true story",
            lecture: "In 1958 a man called Leonard Read wrote a little essay in the voice of a pencil. The pencil says that not one person on earth knows how to make it. And it's right. The wood comes from trees somebody cut down. The black bit inside comes out of a mine. The rubber on the end comes from somewhere else, and the metal band from somewhere else again. Thousands of people who've never met all helped make one pencil. Oh, and not one of them knew they were doing it. Everything's Connected is that. Pick a thing and follow its threads backwards. Where did each part come from? Who touched it before you did?",
            twoMinutes: "Pick up the nearest object. Name three different places or people that had to exist for it to be in your hand.",
            reading: "Leonard Read, \"I, Pencil\" (1958)",
            practice: spellPractice(
                "pencil", title: "Follow the Threads",
                invitation: "Wispwood wants the threads followed. Pick one ordinary thing, write where its parts came from, and how many people you think it took.",
                action: "Follow it back",
                [("thing", "The thing", "A pencil, a cup, a sock"),
                 ("parts", "Where its parts came from", "As far back as you can go"),
                 ("people", "How many people", "Your best guess")]
            )
        ),
        AcademyLessonModule(
            id: "enchantments-puns-008",
            sessionID: "basic-enchantments",
            title: "Everything's Punny",
            realSubject: "wordplay, and finding a second meaning in ordinary things",
            concept: "A pun uses a word's two meanings at once. Find the second meaning hiding in an ordinary thing, and it stops being ordinary.",
            lectureBeats: [
                "A pun is one word doing two jobs at once.",
                "Most objects have a second meaning hiding in their names or their parts.",
                "A groan means the pun worked."
            ],
            demonstration: "Wilbur stood up and made eleven puns about the classroom clock in a row. By the sixth everybody was groaning. By the tenth they were laughing at the groaning. Professor Wispwood said nobody had ever done so much with a clock, and that he'd had his time.",
            interactionPrompt: "Find a second meaning hiding in something in this room.",
            realWorldPractice: "Make one pun about an ordinary thing you use every day. Try it on somebody and count the groans.",
            number: 8,
            mode: "Wordplay",
            lecture: "Oh, this is Wilbur's favourite, so I'll be quick before he takes over. A pun is when one word means two things at once, and you use both. Why did the scarecrow win a prize? Because he was outstanding in his field. Groan if you like. Groaning means it worked. Puns are good for objects, because most things have a second meaning hiding in them. A clock has hands and a face, but no arms. A bookshelf is full of stories, and some of them are tall. Look at a thing until you find its second meaning. Then say both at once. It shakes the thing loose from being ordinary.",
            twoMinutes: "Pick one thing near you. Find a word in its name or its parts that means something else too. Make a pun with it.",
            reading: charactersReading,
            practice: spellPractice(
                "puns", title: "Find the Second Meaning",
                invitation: "Wispwood wants a word doing two jobs. Pick a thing, find its hidden second meaning, and write the pun.",
                action: "Make them groan",
                [("thing", "The thing", "A clock, a bookshelf, a spoon"),
                 ("meaning", "Its second meaning", "The word that means something else too"),
                 ("pun", "The pun", "Groans count as applause")]
            )
        ),
        AcademyLessonModule(
            id: "enchantments-roast-009",
            sessionID: "basic-enchantments",
            title: "Roast the Kettle, Not the Person",
            realSubject: "playful teasing, and the limits that keep it kind",
            concept: "Playful magic needs edges. Tease the object, never the person, and never somebody else's thing unless they've said yes.",
            lectureBeats: [
                "A friendly tease aimed at an object's weak spot can be very funny.",
                "Teasing somebody's belongings can hurt the person who loves them.",
                "Ask first. Roast the thing, never the person."
            ],
            demonstration: "Professor Wispwood told the class about the pencil case, and then let them roast the Spark Annex's ancient radiator instead. It clanks, it leaks, and it only heats one corner. By the end they'd written it a list of complaints so long that Finn said somebody should give it a holiday.",
            interactionPrompt: "Which object in your life deserves a friendly roast? What's its weak spot?",
            realWorldPractice: "Write a friendly roast of one object you own that lets you down. Keep it about the object.",
            number: 9,
            mode: "Someone gets it wrong",
            lecture: "I need to own up to something. Last spring I taught the enchantment called Everything's Roasted. It's a friendly little burn aimed at an object's weak spot. The kettle that takes nine minutes. The umbrella that turns inside out if you look at it. Lovely. But I got carried away, and I roasted a student's pencil case, and it turned out her nan had made it. Oh, I felt dreadful. So here's the rule I should have started with. Roast the thing, never the person. And never somebody else's thing unless they've said yes. Playful magic still needs edges. The edges are what make it safe to play.",
            twoMinutes: "Pick one thing you own that's a bit useless. Write one friendly joke about its weak spot.",
            reading: charactersReading,
            practice: spellPractice(
                "roast", title: "A Friendly Roast",
                invitation: "Wispwood's learned her lesson. Roast one object of your own, kindly. Write what it is, its weak spot, and your roast.",
                action: "Roast it kindly",
                [("thing", "The thing", "Your own, not somebody else's"),
                 ("weak", "Its weak spot", "What it always gets wrong"),
                 ("roast", "Your roast", "Friendly, and about the thing, never a person")]
            )
        ),
        AcademyLessonModule(
            id: "enchantments-thanks-010",
            sessionID: "basic-enchantments",
            title: "Thank the Kettle",
            realSubject: "thanking the things that look after you, and then the people",
            concept: "Pick something that looks after you every day and never gets thanked. Say one nice, true thing to it. Then try it on a person.",
            lectureBeats: [
                "Sailors name their boats, and musicians talk to their instruments.",
                "Thanking a thing makes you notice what it does for you.",
                "Practising on objects makes it easier to say nice things to people."
            ],
            demonstration: "Professor Wispwood went round the Spark Annex thanking things: the door, the lamp, the chair that wobbles but has never once dropped anybody. The class laughed at first. Then Finn quietly thanked his boots, which had been his brother's.",
            interactionPrompt: "What looks after you every day and never gets thanked?",
            realWorldPractice: "Say one nice, true thing to an object that looks after you. Then say one to a person.",
            number: 10,
            mode: "A kindness",
            lecture: "Sailors give their boats names and talk to them. Lots of musicians talk to their instruments. People who talk to their plants tend to look after them better, too, because they notice them more. Everything's Nice is that. Pick one thing that looks after you every day and never gets thanked. The kettle. Your shoes. The front door that keeps the rain out. Say one nice, true thing to it. Out loud, if you're brave. Oh, it'll feel silly. Do it anyway. Then try it on a person. It's easier once you've practised on a kettle.",
            twoMinutes: "Pick the object that's done the most for you today. Write it one sentence of thanks.",
            reading: charactersReading,
            practice: spellPractice(
                "thanks", title: "Everything's Nice",
                invitation: "Wispwood wants something thanked. Write what you thanked, what you said, and who you said something nice to afterwards.",
                action: "Say thank you",
                [("thing", "What you thanked", "The kettle, your shoes, the door"),
                 ("said", "What you said", "Nice, and true"),
                 ("person", "And a person", "Who you said something nice to after")]
            )
        ),
        AcademyLessonModule(
            id: "enchantments-salt-011",
            sessionID: "basic-enchantments",
            title: "Salt Is Made of Cubes",
            realSubject: "the true, astonishing facts hiding inside plain things",
            concept: "Plain things are full of true, astonishing facts. Salt grains are tiny cubes. Find the hidden wonder in one ordinary thing.",
            lectureBeats: [
                "Salt grows into tiny cubes all by itself.",
                "Glass is mostly sand, and the iron in your blood is the same stuff as the iron in a nail.",
                "True facts are often stranger than anything you could make up."
            ],
            demonstration: "Professor Wispwood gave everyone a magnifying glass and a pinch of salt on black paper. When they saw the cubes, Wilbur said, \"No,\" very quietly, and then \"No,\" again, louder.",
            interactionPrompt: "What ordinary thing would you most like to know one amazing fact about?",
            realWorldPractice: "Pick one ordinary thing and find out one true, amazing fact about it. Then tell somebody.",
            number: 11,
            mode: "A hidden fact",
            lecture: "Oh, I have to show you this. Tip a little salt onto something dark and look at it very closely. The grains are tiny cubes. Little boxes. Salt grows like that, all by itself. Glass is mostly sand that got very, very hot. The iron in your blood is the same stuff as the iron in a nail. Everything's Wonderful is finding the astonishing fact hiding inside a plain thing. You don't have to make anything up. The true facts are already stranger than anything I could invent. Pick one ordinary thing, and find out one true, amazing thing about it.",
            twoMinutes: "Pick something near you. Write down the most amazing true thing you already know about it, or one question you'd love answered.",
            reading: charactersReading,
            practice: spellPractice(
                "salt", title: "The Hidden Wonder",
                invitation: "Wispwood wants the wonder hiding in a plain thing. Write the thing, the true fact you found, and who you told.",
                action: "Tell somebody",
                [("thing", "The thing", "Salt, glass, a leaf, your own hand"),
                 ("fact", "The amazing fact", "True, and checked"),
                 ("told", "Who you told", "And what they said")]
            )
        ),
        AcademyLessonModule(
            id: "enchantments-spellbook-012",
            sessionID: "basic-enchantments",
            title: "Your Own Spellbook",
            realSubject: "looking back at the ordinary things that turned out to be magic",
            concept: "Your spellbook is a list of ordinary things you looked at until they turned out to be magic. Write up your three favourites.",
            lectureBeats: [
                "Every object you enchanted this year is a page in your spellbook.",
                "A good entry says what it was, what you did, and what it showed you.",
                "Leave room. There'll be more."
            ],
            demonstration: "Professor Wispwood showed the class her own spellbook. It was falling apart, and half of it was held in with tape. The very first entry was a teaspoon. She said she'd been eight, and it was still her best one.",
            interactionPrompt: "Which object you enchanted this year would go first in your spellbook?",
            realWorldPractice: "Write up your three favourite enchanted objects from this year: what each one was, what you did, and what it showed you.",
            number: 12,
            mode: "Your own spellbook",
            lecture: "End of the year, and it's time you had your own spellbook. Go back through every object you enchanted. The mug that spoke. The pencil with thousands of makers. The radiator you roasted. The kettle you thanked. Pick your three favourites and write them up properly: what it was, what you did, and what it showed you. That's a spellbook. Not a list of magic words. A list of ordinary things you looked at properly, until they turned out to be magic all along. Oh, and leave room at the back. You'll need it next year.",
            twoMinutes: "Think of one ordinary thing that surprised you this year. Write it up as a spellbook entry: the thing, what you did, what it showed you.",
            reading: charactersReading,
            practice: spellPractice(
                "spellbook", title: "Your Own Spellbook",
                invitation: "Wispwood's last lesson of the year: start your own spellbook. Write up your favourite enchanted object.",
                action: "Write it in",
                [("object", "The object", "The one that surprised you most"),
                 ("did", "What you did", "The enchantment you cast"),
                 ("showed", "What it showed you", "The magic that was there all along")]
            )
        )
    ]

    // MARK: Book Jumping: entering stories and coming home

    private static let fairyStories = "J. R. R. Tolkien, \"On Fairy-Stories\" (1947)"

    private static func jumpPractice(
        _ id: String, title: String, invitation: String, action: String,
        _ fields: [(id: String, label: String, placeholder: String)]
    ) -> AcademyActivity {
        practice("book-jumping", "book-jumping-\(id)", kind: .landingProtocol, title: title, invitation: invitation, action: action, fields)
    }

    /// Permancer is precise and adventurous: a story is a place with its own rules and rights,
    /// you may enter, and you come home with something. Safety never gets to postpone wonder.
    /// His readings are real books about reading, and the old rules about other worlds.
    static let bookJumping: [AcademyLessonModule] = [
        AcademyLessonModule(
            id: "book-jumping-return-001",
            sessionID: "book-jumping",
            title: "Always Know Your Way Back",
            realSubject: "reading a story's rules, and knowing how to come back out",
            concept: "Before you jump into a story, work out its rules, and keep your way back where you can see it.",
            lectureBeats: [
                "Every kind of story has its own weather.",
                "Each story has rules: what's dangerous, what's allowed, and what it costs.",
                "A bookmark is a promise to the you who has to come home."
            ],
            demonstration: "Professor Permancer laid three bookmarks next to a glowing page and threw out the prettiest one, because it had no way back.",
            interactionPrompt: "Name one rule of this story before you decide if it's safe to go in.",
            realWorldPractice: "Before you read or watch something that pulls you in today, say what mood you're going into and how you'll come back.",
            number: 1,
            mode: "The big idea",
            lecture: "Every story is a place. When you read properly, you go there. That's the whole of my subject, and it isn't a figure of speech. Ask anybody who's missed their bus stop because of a book. So before you jump, three things. Where are you going in? What's the weather like in there: funny, frightening, sad? And how do you get back out? A bookmark. A time. A cup of tea going cold beside you. Mark the page you leave from. Stories don't like losing people. And when you come back, bring something with you. A line. A feeling. That's how you know you went.",
            twoMinutes: "Think of the book or show you're in the middle of. Write one of its rules, and how you get back out.",
            reading: fairyStories
        ),
        AcademyLessonModule(
            id: "book-jumping-carried-002",
            sessionID: "book-jumping",
            title: "A Story Is Somewhere You Go",
            realSubject: "how being carried away by a story changes you",
            concept: "When a story really carries you away, you're somewhere else for a while, and you come back a little changed. Choose your stories the way you'd choose places to visit.",
            lectureBeats: [
                "Readers who were carried away by a story noticed fewer of its mistakes.",
                "Afterwards, their opinions had moved towards the story's.",
                "Being carried away is real, and it changes you, so choose where you go."
            ],
            demonstration: "Professor Permancer read the class a short ghost story with the lights down. Halfway through, Orion knocked his pencil off the desk and three people screamed. Permancer said it was the best proof of the lesson he'd ever had, and carried on reading.",
            interactionPrompt: "When did a story last carry you so far away you forgot where you were?",
            realWorldPractice: "Next time a story carries you away, notice one thing that's different about you when you come back.",
            number: 2,
            mode: "A real experiment",
            lecture: "In 2000 two scientists, Melanie Green and Timothy Brock, gave people a story to read and asked them to circle anything in it that didn't ring true. The people who'd been carried away by the story circled far fewer mistakes. They were too far inside to notice. And afterwards, their opinions had moved towards the story's. They'd been somewhere, and they'd come back a bit different. That's what a jump is. It's real, and it changes you. So choose your stories the way you'd choose where to go on holiday. And when you come back, notice what's different.",
            twoMinutes: "Think of the last story that carried you away. Write down where you were when you started, and where you were in your head by the end.",
            reading: "Melanie Green and Timothy Brock, on being carried away by stories (2000)",
            practice: jumpPractice(
                "carried", title: "Where Did You Go?",
                invitation: "Permancer wants to know where you went. Write what carried you away, where it took you, and what was different when you came back.",
                action: "Report from the landing",
                [("story", "The story", "A book, a film, a song"),
                 ("where", "Where it took you", "In your head"),
                 ("different", "What was different after", "In you, not in the story")]
            )
        ),
        AcademyLessonModule(
            id: "book-jumping-weather-003",
            sessionID: "book-jumping",
            title: "Read the Weather",
            realSubject: "the rules different kinds of stories keep",
            concept: "Every kind of story has its own weather and its own rules. Read the first page, work out the rules, then enjoy watching them kept or broken.",
            lectureBeats: [
                "Ghost stories, fairy tales and detective stories each have their own rules.",
                "The first page usually tells you what kind of place you're in.",
                "Knowing the rules lets you enjoy it when a story breaks them."
            ],
            demonstration: "Professor Permancer read out the first lines of six different books, and the class had to say what kind of story each one was and one rule it would keep. They got five right. The sixth was a cookbook. Orion said it was a horror story. Permancer read out the recipe for tripe and said Orion wasn't wrong.",
            interactionPrompt: "What kind of story is the one you're reading now? What's one rule it keeps?",
            realWorldPractice: "Read the first page of three different books. For each one, write what kind of place it is and one rule it'll probably keep.",
            number: 3,
            mode: "Reading the rules",
            lecture: "Every kind of story has its own weather, and its own rules. In a ghost story, the candle's going to go out. In a fairy tale, the youngest child usually wins, and you should be very polite to old women at crossroads. In a detective story, keep an eye on whoever seems nicest. Read the first page and ask: what's the weather in here? What usually happens in places like this? Knowing the rules doesn't spoil anything. It means you can see what's coming, and enjoy it all the more when the story breaks a rule on purpose.",
            twoMinutes: "Pick up any book near you. Read the first two lines. Write what kind of story it is, and one rule you think it'll keep.",
            reading: "Vladimir Propp, Morphology of the Folktale (1928)",
            practice: jumpPractice(
                "weather", title: "Read the Weather",
                invitation: "Permancer wants the weather read before you jump. Pick a story, say what kind of place it is, and one rule it keeps.",
                action: "Report the weather",
                [("story", "The story", "The book you picked"),
                 ("kind", "What kind of place it is", "Spooky, funny, grim, tender"),
                 ("rule", "One rule it keeps", "What usually happens in places like this")]
            )
        ),
        AcademyLessonModule(
            id: "book-jumping-believe-004",
            sessionID: "book-jumping",
            title: "Believing on Purpose",
            realSubject: "choosing to believe a story while you're in it, and choosing to stop",
            concept: "You can choose to believe a story while you're in it, and choose to stop when it's over. Both are skills.",
            lectureBeats: [
                "Coleridge called it the willing suspension of disbelief.",
                "Choosing to believe lets a story work on you.",
                "Choosing to stop believing at the end is how you come home."
            ],
            demonstration: "Professor Permancer told the class there was a dragon asleep under the Vault of Doors, and asked them to believe it until the bell rang. They did. They whispered. Somebody tiptoed. When the bell rang Permancer said, \"Lesson over,\" and Orion asked, quite seriously, whether they should still tiptoe on the way out.",
            interactionPrompt: "What's something you believe in while you're reading, that you know isn't real?",
            realWorldPractice: "Next time you read or watch a story, choose to believe it completely until the end. Notice the moment you come back out.",
            number: 4,
            mode: "An old idea",
            lecture: "In 1817 the poet Samuel Taylor Coleridge wrote about the willing suspension of disbelief. It means you know the dragon isn't real, and you choose to believe in it anyway, just for a while, so the story can work on you. That's a skill, and you decide when to use it. Grown-ups often forget how. They sit in the cinema checking whether things are realistic, and they miss the whole film. Choose to believe. On purpose, for as long as the story lasts. Then, when it's over, choose to stop. That's the bookmark. You can do both.",
            twoMinutes: "Imagine something impossible is in the next room: a dragon, a ghost, a door that wasn't there before. Believe it for one minute. Write what you felt.",
            reading: "Samuel Taylor Coleridge, Biographia Literaria (1817)",
            practice: jumpPractice(
                "believe", title: "Believe It on Purpose",
                invitation: "Permancer wants you to believe on purpose, then come back. Write what you chose to believe, how it felt, and the moment you stopped.",
                action: "Come back out",
                [("what", "What you believed", "The dragon, the ghost, the door"),
                 ("felt", "How it felt", "While you believed it"),
                 ("back", "The moment you came back", "What brought you out")]
            )
        ),
        AcademyLessonModule(
            id: "book-jumping-gun-005",
            sessionID: "book-jumping",
            title: "Nothing's There by Accident",
            realSubject: "noticing the details a writer puts in a scene on purpose",
            concept: "In a good story, nothing's there by accident. When you land in a scene, notice what the writer put in the room, and guess what will matter later.",
            lectureBeats: [
                "Chekhov said a gun on the wall in the first act has to go off before the end.",
                "Writers put things in a scene for a reason.",
                "Guessing what will matter later makes you a sharper reader."
            ],
            demonstration: "Professor Permancer read the class the first page of a mystery and had them list everything in the room. Twelve things. They voted on which one would matter. They picked the umbrella. It was the umbrella. Orion was so pleased he had to go and walk round the corridor.",
            interactionPrompt: "In the story you're reading now, what's something you think will matter later?",
            realWorldPractice: "In the next story you read or watch, write down one thing near the start that you think will matter. See if you're right.",
            number: 5,
            mode: "A writer's rule",
            lecture: "Anton Chekhov wrote plays and stories, and in his letters he gave a famous bit of advice. If there's a gun hanging on the wall at the start, it has to go off before the end. If it doesn't, take it out. In a good story, nothing's there by accident. The key on the table matters. The stranger in the corner matters. So when you jump, look round the room you land in. Notice what the writer put there. Guess which thing's going to matter later. You'll be right more often than you think, and it's very satisfying.",
            twoMinutes: "Think of the opening of a story you know well. What was in the first scene that turned out to matter?",
            reading: "Anton Chekhov, letters (1889)",
            practice: jumpPractice(
                "gun", title: "Spot the Gun on the Wall",
                invitation: "Permancer wants you watching the room. Write down one early detail you think will matter, and whether it did.",
                action: "Check your guess",
                [("story", "The story", "What you're reading or watching"),
                 ("detail", "The detail", "The thing you think will matter"),
                 ("did", "Did it?", "Fill this in at the end")]
            )
        ),
        AcademyLessonModule(
            id: "book-jumping-fairy-food-006",
            sessionID: "book-jumping",
            title: "Never Eat the Fairy Food",
            realSubject: "the old rule about other worlds, and stories that are hard to leave",
            concept: "In the oldest stories, if you eat the food in another world, you have to stay. Some stories want to keep you. Visit, but keep your way back.",
            lectureBeats: [
                "Persephone ate pomegranate seeds in the underworld, and had to go back there every year.",
                "Thomas the Rhymer was warned not to eat the fruit in Elfland.",
                "Some worlds, and some stories, want to keep you. Know what you'd give up."
            ],
            demonstration: "Professor Permancer set a bowl of very red apples on the desk in the Vault of Doors and told the class not to eat them. Nobody did, for the whole lesson. At the end Permancer ate one and said they were perfectly ordinary apples. Nobody believed him, and nobody ate one afterwards either.",
            interactionPrompt: "Is there a story, a game or a show that's hard to come back from? What does it keep?",
            realWorldPractice: "Notice one story, game or show this week that's hard to stop. Set yourself a way back before you start.",
            number: 6,
            mode: "Old rules",
            lecture: "The oldest stories about other worlds all carry the same warning. In the Greek myth, Persephone eats pomegranate seeds in the underworld, and because of that she has to go back there for part of every year. In the old Scottish ballad of Thomas the Rhymer, the Queen of Elfland warns him not to eat the fruit in her garden. In story after story, if you eat the food in the other world, you have to stay. That's a story about stories. Some worlds want to keep you. You can visit. You can look. Just know what you'd be giving up, and keep your bookmark where you can reach it.",
            twoMinutes: "Think of something that's hard to stop once you've started: a game, a show, scrolling. Write down one way you could set a bookmark for it.",
            reading: "The ballad of Thomas the Rhymer; the myth of Persephone",
            practice: jumpPractice(
                "fairy-food", title: "What Wants to Keep You",
                invitation: "Permancer says some worlds want to keep you. Write one that's hard to come back from, what it keeps, and your bookmark for next time.",
                action: "Set the bookmark",
                [("world", "What's hard to come back from", "A game, a show, a book"),
                 ("keeps", "What it keeps", "Your time, your sleep, your evening"),
                 ("bookmark", "Your bookmark", "How you'll get back next time")]
            )
        ),
        AcademyLessonModule(
            id: "book-jumping-reread-007",
            sessionID: "book-jumping",
            title: "Go Back In",
            realSubject: "rereading, and what a second visit shows you",
            concept: "The first time through a story, you find out what happens. The second time, you get to look around. Go back into one you loved.",
            lectureBeats: [
                "Nabokov said you can't really read a book, only reread it.",
                "Knowing what happens frees you to notice everything else.",
                "Going back to a book from years ago shows you how you've changed."
            ],
            demonstration: "Professor Permancer asked each student to bring a book they'd loved when they were small. Zara brought one about a mouse with a lantern. She read the first page out loud, stopped, and said she'd never noticed that the mouse was scared. She'd always thought it was brave.",
            interactionPrompt: "What book would you most like to go back into? What do you think you'd notice now?",
            realWorldPractice: "Reread a book or watch a film you loved years ago. Write down one thing you notice now that you missed then.",
            number: 7,
            mode: "Going back in",
            lecture: "The writer Vladimir Nabokov once told his students that you can't really read a book. You can only reread it. The first time through, you're busy finding out what happens. The second time, you know what happens, so you can look around. You notice the gun on the wall. You notice the joke you missed. You notice the person you didn't like the first time, and now you understand them. Pick a book you loved when you were younger, and go back in. It'll have changed. Or you will have. Probably both.",
            twoMinutes: "Think of a story you loved when you were younger. Write down one thing you think you'd understand differently now.",
            reading: "Vladimir Nabokov, Lectures on Literature",
            practice: jumpPractice(
                "reread", title: "Go Back In",
                invitation: "Permancer wants you back inside a story you loved. Write which one, what you noticed this time, and what that says about you now.",
                action: "Report the second visit",
                [("story", "The story", "One you loved years ago"),
                 ("noticed", "What you noticed this time", "The thing you missed before"),
                 ("changed", "What's changed", "The story, or you")]
            )
        ),
        AcademyLessonModule(
            id: "book-jumping-painting-008",
            sessionID: "book-jumping",
            title: "Step Into a Picture",
            realSubject: "imagining your way into a painting or a photograph",
            concept: "You can jump into a picture too. Look at it for a minute, step in, and find out what's just outside the frame.",
            lectureBeats: [
                "Every picture has a world going on beyond its edges.",
                "Imagining the ground, the smell and the sounds puts you inside it.",
                "The edges of the frame are a door."
            ],
            demonstration: "Professor Permancer hung an old painting of a harbour in the Vault and asked what was just out of the frame on the left. Zara said a fish market. Orion said a man shouting about the price of eels. Zara said that was the fish market. They argued for ten minutes, then both drew it.",
            interactionPrompt: "Pick a picture you can see. What's just outside its edge?",
            realWorldPractice: "Pick one painting or photo this week. Step into it in your head, and write what's just outside the frame.",
            number: 8,
            mode: "A game",
            lecture: "You can jump into a picture as well as a book. Pick a painting, a photo, a postcard on somebody's fridge. Look at it for a full minute. Now step in. What's the ground like under your feet? What can you smell? What's just outside the edge of the frame, where the painter didn't show you? Who's about to walk in? The edges of a picture are a door. Painters always leave a little world going on beyond them. Go and have a look, and come back before the paint dries.",
            twoMinutes: "Find any picture near you. Look at it for one minute. Write what's just outside its left edge.",
            reading: "J. R. R. Tolkien, \"Leaf by Niggle\" (1945)",
            practice: jumpPractice(
                "painting", title: "Step Into a Picture",
                invitation: "Permancer wants you inside a picture. Pick one, step in, and write what's under your feet and what's just outside the frame.",
                action: "Step back out",
                [("picture", "The picture", "A painting, a photo, a postcard"),
                 ("ground", "Under your feet", "What it's like to stand in it"),
                 ("outside", "Outside the frame", "What the painter didn't show you")]
            )
        ),
        AcademyLessonModule(
            id: "book-jumping-stayed-009",
            sessionID: "book-jumping",
            title: "The Pirate Week",
            realSubject: "coming back from a story properly",
            concept: "Coming back is part of the jump. Set your way out before you go in, and do one ordinary thing as soon as you're back.",
            lectureBeats: [
                "It's easy to stay too long in a story you love.",
                "Set your way out before you go in, and check the time when you come up.",
                "Doing one ordinary thing straight afterwards helps you land."
            ],
            demonstration: "Orion told the story of the pirate week himself, standing on a chair. When he got to the doubloons he stopped, looked down at the class, and said \"Arr\" without meaning to. Permancer sent him to make everybody tea.",
            interactionPrompt: "What's one ordinary thing you could do straight after a story, to land properly?",
            realWorldPractice: "After your next long read or long film, do one ordinary thing straight away: make a drink, wash a cup, look out of a window.",
            number: 9,
            mode: "Someone gets it wrong",
            lecture: "I'll tell you about Orion, with his permission, which he gave very grandly. Last year he jumped into a pirate story and forgot his bookmark. He was in there three days. When he came out, he talked like a pirate for a week. He called the Headmistress \"Captain\". He tried to pay for lunch in doubloons. It's funny now. It wasn't then. Here's what it teaches. Coming back is part of the jump. Set the way out before you go in. Check the time when you come up. And when you're back, do one ordinary thing straight away. Make tea. Wash a cup. Look out of a real window. That's how your feet find the floor again.",
            twoMinutes: "Think of the last time you came out of a story feeling a bit dizzy. Write one ordinary thing you could have done to land.",
            reading: fairyStories,
            practice: jumpPractice(
                "landing", title: "Land Properly",
                invitation: "Permancer doesn't want another pirate week. Write where you went, when you came back, and the ordinary thing you did to land.",
                action: "Put the kettle on",
                [("where", "Where you went", "The book, film or game"),
                 ("when", "When you came back", "Check the clock"),
                 ("ordinary", "The ordinary thing", "Tea, a cup to wash, a real window")]
            )
        ),
        AcademyLessonModule(
            id: "book-jumping-aloud-010",
            sessionID: "book-jumping",
            title: "Read It Out Loud",
            realSubject: "reading aloud as a different way into a story",
            concept: "Reading out loud is a different way into a story. You can't skim, you go at its speed, and you hear its voice.",
            lectureBeats: [
                "Dickens read his books aloud to huge crowds, and some people fainted.",
                "Reading aloud makes you go at the story's own speed.",
                "You hear things you'd never hear reading silently."
            ],
            demonstration: "Professor Permancer had each student read one paragraph of the same story out loud, one after another. By the end the story had eleven different voices. Orion's was the loudest. Zara's was the one that made the room go quiet.",
            interactionPrompt: "Read one sentence of something near you out loud. How did it sound different?",
            realWorldPractice: "Read one page of a story out loud this week, to somebody or to nobody. Notice what you hear.",
            number: 10,
            mode: "A true story",
            lecture: "Charles Dickens used to read his own books out loud to enormous crowds, all over Britain and America. He did all the voices. When he read the scene from Oliver Twist where Nancy is murdered, people in the audience fainted. He did it so often, and put so much into it, that his doctors told him to stop. Reading out loud is a different way in. You can't skim. You have to go at the story's speed. You hear the jokes land. Try it. Read one page of something out loud, to somebody or to nobody. A cat will do. You'll find the story has a voice you never heard on the page.",
            twoMinutes: "Pick up anything with words on it: a book, a letter, a packet. Read one paragraph out loud. Write down what you noticed.",
            reading: "Charles Dickens, \"Sikes and Nancy\" (his reading, 1868)",
            practice: jumpPractice(
                "aloud", title: "Read It Out Loud",
                invitation: "Permancer wants you to hear a story. Read one page out loud, and write what you read, who listened, and what you heard that you'd have missed.",
                action: "Take a bow",
                [("read", "What you read", "One page is plenty"),
                 ("listened", "Who listened", "A person, a cat, nobody"),
                 ("heard", "What you heard", "Something you'd have missed reading silently")]
            )
        ),
        AcademyLessonModule(
            id: "book-jumping-souvenir-011",
            sessionID: "book-jumping",
            title: "Bring Something Back",
            realSubject: "keeping a commonplace book of lines you loved",
            concept: "When you come back from a story, bring one line with you. Copy it out by hand, and keep them all in one place.",
            lectureBeats: [
                "Readers have kept commonplace books for hundreds of years.",
                "Copying one line out by hand is like bringing a stone home from the beach.",
                "A year of lines becomes a map of everywhere you've been."
            ],
            demonstration: "Professor Permancer showed the class his own commonplace book. It was small and thick and smelled of pipe smoke, though he says he's never smoked. The first line in it was from a book about a lighthouse keeper. He read it out, then closed the book and didn't say anything for a while.",
            interactionPrompt: "What's one line from a story you'd bring back with you?",
            realWorldPractice: "Start a commonplace book. Copy out one line you loved from something you read this week, with the book's name underneath.",
            number: 11,
            mode: "An old habit",
            lecture: "For hundreds of years, readers kept what they called a commonplace book. Whenever they found a line they loved, they copied it out by hand. Thomas Jefferson kept one. So did plenty of people whose names nobody remembers. It's the same as bringing a stone home from the beach. A souvenir from where you've been. So from now on, when you come back from a story, bring one line with you. Copy it out. Put the book's name under it. In a year you'll have a little book of every place you've been.",
            twoMinutes: "Write down one line from any story that's stuck with you. Put where it came from underneath.",
            reading: "Thomas Jefferson's Literary Commonplace Book",
            practice: jumpPractice(
                "line", title: "Bring Something Back",
                invitation: "Permancer wants a souvenir from every jump. Copy out one line you loved, where it came from, and why that line.",
                action: "Copy it in",
                [("line", "The line", "Copied exactly"),
                 ("from", "Where it came from", "The book, and who wrote it"),
                 ("why", "Why that one", "What it brought back with it")]
            )
        ),
        AcademyLessonModule(
            id: "book-jumping-doors-012",
            sessionID: "book-jumping",
            title: "Your Shelf of Doors",
            realSubject: "looking back at a year of stories as places you've been",
            concept: "Count the stories you went into this year. Which took you furthest? Which was hardest to leave? A year of reading is a map.",
            lectureBeats: [
                "Every story you read this year was a door you went through.",
                "Thinking about which took you furthest shows you what you love.",
                "Next year, try a kind of story you'd never usually choose."
            ],
            demonstration: "Professor Permancer drew a map on the wall of the Vault of Doors, with a little door for every book the class had read that year. There were nearly two hundred. Orion's pirate book had a skull and crossbones next to it, which he'd added himself.",
            interactionPrompt: "Which story took you furthest this year?",
            realWorldPractice: "List every story you went into this year. Star the one that took you furthest, and pick one new kind to try next year.",
            number: 12,
            mode: "Counting your doors",
            lecture: "End of the year. Go to your shelf, or your list, or wherever you keep them, and count the doors. Every story you went into this year. The ones you loved. The ones you left halfway. The pirate ones. Put them in order. Which one took you furthest? Which one was hardest to come back from? Which one did you bring something back from? A year of reading isn't a pile. It's a map of places you've been. And next year, I'd like you to go somewhere you'd never usually go. A kind of story you've never tried. Mark the page. Off you go.",
            twoMinutes: "Write down the three stories that took you furthest this year. Put a star by the one that was hardest to leave.",
            reading: "Italo Calvino, If on a Winter's Night a Traveller (1979)",
            practice: jumpPractice(
                "doors", title: "Count Your Doors",
                invitation: "Permancer's last lesson of the year: count your doors. Write the story that took you furthest, the one hardest to leave, and a kind you'll try next year.",
                action: "Mark the map",
                [("furthest", "Furthest", "The one that took you furthest"),
                 ("hardest", "Hardest to leave", "The one that nearly kept you"),
                 ("next", "Next year", "A kind of story you've never tried")]
            )
        )
    ]

    // MARK: Compass Running: the whole loop, in the field

    private static let compassReading = "The Wonder Compass, Chapter 5: The Wonder Compass"

    private static func runPractice(
        _ id: String, title: String, invitation: String, action: String,
        _ fields: [(id: String, label: String, placeholder: String)]
    ) -> AcademyActivity {
        practice("compass-running", "compass-running-\(id)", kind: .compassRun, title: title, invitation: invitation, action: action, fields)
    }

    /// Stonebrook at the Field Gate: practical and weathered, constraints first and magic after.
    /// Each month is one whole run, North to Center, in a new place. In the app the class still
    /// starts the Compass Run; on paper the reader fills in the run they did.
    static let compassRunning: [AcademyLessonModule] = [
        AcademyLessonModule(
            id: "compass-running-loop-001",
            sessionID: "compass-running",
            title: "Go Out, Come Back",
            realSubject: "planning a small adventure that's easy to finish",
            concept: "A Compass Run goes all the way round: notice, go, sense, write, rest. Miss a step and it feels unfinished.",
            lectureBeats: [
                "North notices before it changes anything.",
                "East crosses one small line, with clear rules.",
                "South senses, West writes, and Center rests, so the run becomes part of your life."
            ],
            demonstration: "Professor Stonebrook laid out a whole run with chalk stones. Then he took away every stone that would cost too much energy.",
            interactionPrompt: "Which rule makes a tiny adventure easy enough to finish?",
            realWorldPractice: "Plan one free Compass Run with a clear way home and one sentence to bring back.",
            number: 1,
            mode: "The big idea",
            lecture: "Here's a whole Compass Run, start to finish. Five stops. North: notice something, and say \"I wonder\". East: go towards it, with a treat and a time you'll stop. South: when you get there, use your hands and ears and nose, not just your eyes. West: write one sentence about the best bit. Center: sit down for a minute and let it settle. Then come home. That's all a run is. Constraints first, magic after. Decide how far, how long and how much it'll cost before you set off. Then you're free to enjoy it. A run that's too big never gets finished. Make yours small enough to finish today.",
            twoMinutes: "Plan a run you could do this week. What will you notice first? Where will you stop? What sentence will you bring back?",
            reading: compassReading,
            practice: runPractice(
                "full", title: "The Full Run",
                invitation: "Stonebrook wants one whole run, all five stops. Write what you wondered, where you went and when you stopped, and your sentence.",
                action: "Come back through the gate",
                [("north", "North: what you wondered", "I wonder…"),
                 ("east", "East: where you went, and your stop", "How far, how long"),
                 ("west", "West: your sentence", "One sentence about the best bit")]
            )
        ),
        AcademyLessonModule(
            id: "compass-running-floor-002",
            sessionID: "compass-running",
            title: "The Floor Run",
            realSubject: "a Compass Run at home, seeing a familiar room from a new angle",
            concept: "You can go on a Compass Run without leaving the room. Lie on the floor and look at the underneath of everything.",
            lectureBeats: [
                "Your brain thinks it knows your home completely.",
                "Changing how you look, like lying on the floor, makes it new again.",
                "Even a five-minute run at home has all five stops."
            ],
            demonstration: "Professor Stonebrook had the whole Saturday crew lie on the floor of the hut by the Open Field Gate and look up. Somebody found a carving on the underside of a bench: two sets of initials and a date from before any of them were born.",
            interactionPrompt: "What would your room look like from the floor?",
            realWorldPractice: "Do the Floor Run once this week: lie on the floor for five minutes and find one thing you've never seen.",
            number: 2,
            mode: "A run at home",
            lecture: "This run doesn't need shoes. North: I wonder what my living room looks like from the cat's point of view. East: go to the rug. Bring a cushion. Five minutes, no more. South: lie down on your back and look at the underneath of everything. The bottom of the table. The springs under the sofa. Find one thing you've never seen. A lost button. A coin. A cobweb with history. West: write one sentence about it. Center: stay down there one more minute, doing nothing. You've just gone exploring without leaving the room. Most people never see the underneath of their own house.",
            twoMinutes: "Lie on the floor right now, or crouch down low. Look under the nearest piece of furniture. Write down what you find.",
            reading: compassReading + "; Chapter 17: Home",
            practice: runPractice(
                "floor", title: "The Floor Run",
                invitation: "Stonebrook's run with no shoes: lie down and look at the underneath of everything. Write what you wondered, what you found, and your sentence.",
                action: "Get up off the floor",
                [("north", "North: what you wondered", "I wonder what my room looks like from down here"),
                 ("south", "South: what you found", "Under the table, under the sofa"),
                 ("west", "West: your sentence", "One sentence about the best bit")]
            )
        ),
        AcademyLessonModule(
            id: "compass-running-oldest-003",
            sessionID: "compass-running",
            title: "The Oldest Thing on Your Street",
            realSubject: "a Compass Run down your own road, finding what's lasted longest",
            concept: "Find the oldest thing on your street and ask what it's lived through. It's been waiting a long time for somebody to notice.",
            lectureBeats: [
                "Every street has something older than everybody living on it.",
                "Touching it and asking what it's survived turns it into a character.",
                "A five-minute run down your own road counts."
            ],
            demonstration: "Professor Stonebrook walked the crew to the oldest gatepost on the Academy lane. It leaned a bit. It had a groove worn into it at waist height. They worked out that it came from a hundred years of people's hands resting there while they talked.",
            interactionPrompt: "What's the oldest thing you walk past every day?",
            realWorldPractice: "Walk to the end of your street this week and find the oldest thing on it. Write one sentence about what it's lived through.",
            number: 3,
            mode: "A run down the street",
            lecture: "North: I wonder what's the oldest thing on my street, and what it's lived through. East: walk to the end of your road. Five minutes. Leave your phone inside if you can. South: find the oldest thing you can see. A tree. A wall. A gatepost. Go close. Touch it, if it's yours to touch. What's it survived? Storms. Years and years. Hundreds of people walking past without looking. West: write one sentence about what it's lived through. Center: stand still next to it for a minute before you walk back. You've been walking past it for years. Today you said hello.",
            twoMinutes: "Look out of the window. What's the oldest thing you can see? Write one thing it's lived through.",
            reading: "The Wonder Compass, Chapter 18: Around Town",
            practice: runPractice(
                "oldest", title: "The Oldest Thing",
                invitation: "Stonebrook wants you on your own street. Find the oldest thing on it. Write what it is, what it's lived through, and your sentence.",
                action: "Say hello and come back",
                [("what", "What it is", "A tree, a wall, a gatepost"),
                 ("lived", "What it's lived through", "Storms, years, people"),
                 ("west", "West: your sentence", "One sentence about it")]
            )
        ),
        AcademyLessonModule(
            id: "compass-running-free-004",
            sessionID: "compass-running",
            title: "The Run That Costs Nothing",
            realSubject: "a Compass Run that doesn't cost any money",
            concept: "A Compass Run doesn't have to cost anything. Go somewhere free and find the best thing in it that nobody's selling.",
            lectureBeats: [
                "Libraries, parks, hills and free museums are all good places for a run.",
                "The best things in a place are often the ones nobody's selling.",
                "Sitting somewhere for free, just because you can, is part of it."
            ],
            demonstration: "Professor Stonebrook gave the crew one rule: nobody spends anything all day. They went to the library, the river and the top of the hill. At the end, Lara said it was the best day out she'd had all year, and that she still had all her money, which felt like cheating.",
            interactionPrompt: "What's the best free place you could get to this week?",
            realWorldPractice: "Do one Compass Run this week that costs nothing at all. Go somewhere free, and find the best thing there that nobody's selling.",
            number: 4,
            mode: "A free run",
            lecture: "December's an expensive month, so this run costs nothing at all. Not a penny. North: I wonder what I can find that's free. East: somewhere that doesn't charge you to go in. The library. A park. A church that leaves its door open. A free museum. A hill. South: once you're there, find the best thing in the place that nobody's selling. The view. The warm radiator. The smell of old books. West: write it down. Center: sit there for a while, because you're allowed to, and it didn't cost you anything. Most of the best things never did.",
            twoMinutes: "Write down three places near you that are free to go into. Put a star by the one you've never been to.",
            reading: "The Wonder Compass, Chapter 11A: The $0 Compass",
            practice: runPractice(
                "free", title: "The Free Run",
                invitation: "Stonebrook's run costs nothing. Write where you went, the best free thing you found, and your sentence.",
                action: "Come home with your money",
                [("where", "Where you went", "Somewhere free to go into"),
                 ("best", "The best free thing", "The view, the warmth, the smell"),
                 ("west", "West: your sentence", "One sentence about it")]
            )
        ),
        AcademyLessonModule(
            id: "compass-running-dark-005",
            sessionID: "compass-running",
            title: "The Dark Run",
            realSubject: "a short, safe Compass Run after dark",
            concept: "Your street's a different place after dark. Go for a short, safe run when it's dark, and listen to it.",
            lectureBeats: [
                "Set the safety first: lit streets, close to home, somebody knows, back soon.",
                "In the dark, your ears and skin notice more than your eyes.",
                "A street you know feels like somewhere new at night."
            ],
            demonstration: "Professor Stonebrook took the crew round the Academy grounds after supper, each with a lantern, keeping to the paths. They counted lit windows. There were thirty-one. One of them was in a tower nobody uses, and nobody could explain it.",
            interactionPrompt: "What would your street sound like in the dark?",
            realWorldPractice: "Take one short, safe walk after dark this week: lit streets, close to home, back in fifteen minutes. Write one sentence.",
            number: 5,
            mode: "A run after dark",
            lecture: "It's dark by teatime this month, so we run in the dark. Short, safe, and close to home. Lit streets. Somebody knows where you've gone. Back in fifteen minutes. Those are the constraints. Now the magic. North: I wonder what my street's like at night. East: walk it, slowly, with something warm to drink. South: listen. It's a different street in the dark. The lit windows. The sound of your own feet. The cold on your face. Which houses have left a light on, and who for? West: write one sentence. Center: stand under one streetlamp for a minute before you go in.",
            twoMinutes: "Turn the lights off where you are, or look out at the dark. For one minute, just listen. Write down what you heard.",
            reading: "The Wonder Compass, Chapter 11C: The Safe Compass",
            practice: runPractice(
                "dark", title: "The Dark Run",
                invitation: "Stonebrook's winter run is short, safe and after dark. Write your safety rules, what you heard, and your sentence.",
                action: "Come in out of the dark",
                [("rules", "Your safety rules", "Lit streets, how long, who knows"),
                 ("heard", "What you heard", "Feet, windows, wind"),
                 ("west", "West: your sentence", "One sentence about the dark")]
            )
        ),
        AcademyLessonModule(
            id: "compass-running-rain-006",
            sessionID: "compass-running",
            title: "The Rainy-Day Run",
            realSubject: "a Compass Run in the rain instead of cancelling",
            concept: "Rain changes everything: the sounds, the smells, the way water moves. Don't cancel the run. Go out in it for ten minutes.",
            lectureBeats: [
                "Rain makes a familiar place look, sound and smell different.",
                "Following where the water goes is a whole adventure.",
                "Coming back in, wet and warm, is part of the run."
            ],
            demonstration: "It poured on the crew's Saturday. Professor Stonebrook took them out anyway. They followed one stream of rainwater from the top of the lane all the way to the drain at the bottom. Elio named it. By the drain they were all cheering it on.",
            interactionPrompt: "What does rain sound like on different things near you?",
            realWorldPractice: "Next time it rains, go out for ten minutes anyway. Follow where the water goes, and write one sentence.",
            number: 6,
            mode: "A run in the rain",
            lecture: "Most people cancel a run when it rains. Don't. Rain's the best weather there is for noticing, because everything changes. North: I wonder what the rain's doing to my street. East: coat on, hood up, ten minutes. Leave something warm ready for after. South: watch where the water goes. Which way the puddles run. What the rain sounds like on a car roof, a leaf, an umbrella, your own hood. Smell it. West: write one sentence. Center: when you get in, sit with your warm drink and your wet hair for a minute before you do anything else. That bit's the best bit.",
            twoMinutes: "If it's raining, listen to it for two minutes. If it isn't, remember the last rain. Write what it sounded like on three different things.",
            reading: compassReading,
            practice: runPractice(
                "rain", title: "The Rainy-Day Run",
                invitation: "Stonebrook won't cancel for rain. Go out in it for ten minutes. Write where the water went, what it sounded like, and your sentence.",
                action: "Come in and dry off",
                [("water", "Where the water went", "Follow one stream"),
                 ("sound", "What it sounded like", "On a roof, a leaf, your hood"),
                 ("west", "West: your sentence", "One sentence about the rain")]
            )
        ),
        AcademyLessonModule(
            id: "compass-running-two-007",
            sessionID: "compass-running",
            title: "The Run for Two",
            realSubject: "a Compass Run with someone else, and comparing what you each noticed",
            concept: "Go on a run with somebody else. You'll each notice different things, and you'll remember it for each other.",
            lectureBeats: [
                "Two people on a run notice different things.",
                "A couple of minutes of quiet before you compare makes it better.",
                "Swapping sentences afterwards gives you both twice as much."
            ],
            demonstration: "Professor Stonebrook paired the crew up and sent each pair to the same pond. When they came back, no two pairs had written about the same thing. One pair had written about a heron. Another had written about the heron's shadow, and swore it was a different bird.",
            interactionPrompt: "Who would you take on a run with you?",
            realWorldPractice: "Go on one run with somebody else this week. Each write a sentence, then swap.",
            number: 7,
            mode: "A run for two",
            lecture: "This month you need somebody else. A friend, a child, a neighbour, your mum on the phone. North: each of you says one \"I wonder\". Pick the better one. East: go together, and agree the stop before you start. South: when you get there, don't talk for two minutes. Just look and listen. Then tell each other one thing you noticed. You'll have noticed different things. That's the point. West: each write your own sentence, then swap. Center: have something to eat together afterwards. Two people notice twice as much, and they remember it for each other.",
            twoMinutes: "Ask somebody near you, or message somebody, one question: what's one thing you noticed today? Write down their answer, and yours.",
            reading: "The Wonder Compass, Chapter 12A: The Shared Compass",
            practice: runPractice(
                "two", title: "The Run for Two",
                invitation: "Stonebrook's run needs two people. Write who you went with, your sentence, and theirs.",
                action: "Swap sentences",
                [("who", "Who you went with", "A friend, a child, a neighbour"),
                 ("yours", "Your sentence", "What you noticed"),
                 ("theirs", "Their sentence", "What they noticed")]
            )
        ),
        AcademyLessonModule(
            id: "compass-running-work-008",
            sessionID: "compass-running",
            title: "The Ten-Minute Run",
            realSubject: "a whole Compass Run in ten minutes of a working day",
            concept: "A whole Compass Run fits into ten minutes of a working day. Find the bit of the building nobody goes to, and go.",
            lectureBeats: [
                "Even a busy day has ten minutes in it.",
                "Stairwells, back corridors and quiet corners are good places for a run.",
                "Writing your sentence before you go back to work keeps it."
            ],
            demonstration: "Professor Stonebrook sent the crew to find the quietest place in the Academy in under ten minutes. Lara found a stairwell nobody uses, where the echo comes back three times. She said it made her footsteps sound important.",
            interactionPrompt: "Where's the quietest place in the building you spend your days in?",
            realWorldPractice: "Take one ten-minute run during a working day this week. Find the bit of the building nobody goes to.",
            number: 8,
            mode: "A run at work",
            lecture: "You can do a run in the middle of a working day. You've got ten minutes. That's enough. North: I wonder where in this building nobody goes. East: the stairwell, the far end of the corridor, the bit of the car park by the bins. Bring the good chocolate. Ten minutes on a timer. South: stairwells are wonderful. Cold concrete. Every step echoes. Your breath comes back to you twice. Listen to it. West: write one sentence on your phone before you go back. Center: take one slow breath at the top of the stairs. Then back to your desk. Nobody will even know you went. You will.",
            twoMinutes: "Think of the place where you work or study. Write down the one spot in it you've never been, and why you might go.",
            reading: "The Wonder Compass, Chapter 21: Wonder at Work",
            practice: runPractice(
                "work", title: "The Ten-Minute Run",
                invitation: "Stonebrook says ten minutes is enough. Write where you went, what it sounded like, and your sentence.",
                action: "Back to your desk",
                [("where", "Where you went", "The stairwell, the far corridor"),
                 ("sound", "What it sounded like", "Echoes, hums, your own breath"),
                 ("west", "West: your sentence", "Written before you went back")]
            )
        ),
        AcademyLessonModule(
            id: "compass-running-ugly-009",
            sessionID: "compass-running",
            title: "When Nothing Sparks",
            realSubject: "getting a run going on days when nothing seems interesting",
            concept: "Some days nothing looks interesting. Look for something annoying instead, or something in your own hand. Getting to the door counts.",
            lectureBeats: [
                "Every runner has days when nothing sparks.",
                "Looking for the ugliest or most annoying thing can get you going.",
                "Making the run smaller, even down to your own hand, still counts."
            ],
            demonstration: "On a grey Saturday nobody in the crew could think of anything. Professor Stonebrook asked them to find the ugliest thing in the grounds instead. They found a drainpipe shaped like a nose. Elio wrote six sentences about it.",
            interactionPrompt: "What's the most annoying thing you walk past every day?",
            realWorldPractice: "On a day when nothing sparks, find the ugliest or most annoying thing you can see, and write one sentence about it.",
            number: 9,
            mode: "When it won't start",
            lecture: "Some days you won't be able to find anything to wonder about. That's normal. It happens to me. Here's what to do. If nothing looks interesting, look for something annoying instead. The ugliest thing you can see. The pothole you've been stepping round for two years. Annoyance and curiosity live very close together, and sometimes annoyance gets you going when nothing else will. If even that's too much, make it smaller. Find something interesting in your own hand. The weight of your keys. The warmth of a cup. A run that starts with an ugly bin is still a run. Getting as far as the front door counts too.",
            twoMinutes: "Find the ugliest thing you can see from where you are. Look at it properly for thirty seconds. Write one sentence about it.",
            reading: "The Wonder Compass, Chapter 15: The Adventure of Failing",
            practice: runPractice(
                "ugly", title: "The Ugly Run",
                invitation: "Stonebrook has days when nothing sparks too. Find the ugliest or most annoying thing near you. Write what it is, what you noticed, and your sentence.",
                action: "Count it",
                [("thing", "The ugly thing", "The pothole, the bin, the sign"),
                 ("noticed", "What you noticed", "Up close"),
                 ("west", "West: your sentence", "One sentence about it")]
            )
        ),
        AcademyLessonModule(
            id: "compass-running-four-hours-010",
            sessionID: "compass-running",
            title: "The Four-Hour Run",
            realSubject: "turning one afternoon into a trip that feels like a holiday",
            concept: "Four hours is enough for a whole trip. Pick one big wonder, plan it properly, and run small loops inside it.",
            lectureBeats: [
                "One afternoon can feel like a holiday if you plan it like one.",
                "Inside a big run, do small runs: a bakery, a wall, a bench.",
                "Leave the journey home empty, and let the day settle."
            ],
            demonstration: "Professor Stonebrook took the crew on a four-hour run along the river to the next village. They had a plan, a bag, and a time to be back. They came home with forty-two sentences, one dog that followed them, and no idea how it had only been four hours.",
            interactionPrompt: "Where could you go for one afternoon that would feel like a holiday?",
            realWorldPractice: "Plan one four-hour run this summer: one big wonder, a bag, a treat, and a time to be home.",
            number: 10,
            mode: "A long run",
            lecture: "Summer's long, so this run is too. Four hours. Not a holiday, not a weekend. One afternoon. North: pick one wonder big enough to fill it. A town you've never been to. A river you've never followed. East: plan it properly. Where, what treat, home by when. Pack the bag. South: once you're there, run a small loop inside the big one. Find the best bakery, the oldest wall, the quietest bench. West: write one sentence before you leave. Center: on the way home, don't fill the time. Look out of the window. Four hours can feel like a week away, if you let it.",
            twoMinutes: "Write down one place you could get to and back in an afternoon. What's the one thing you'd most want to see there?",
            reading: "The Wonder Compass, Chapter 22: The Four-Hour Vacation",
            practice: runPractice(
                "four-hours", title: "The Four-Hour Run",
                invitation: "Stonebrook's long run: one afternoon, planned like a holiday. Write where you went, the small loop inside it, and your sentence.",
                action: "Come home slowly",
                [("where", "Where you went", "Somewhere for one afternoon"),
                 ("loop", "The small loop inside", "The bakery, the wall, the bench"),
                 ("west", "West: your sentence", "Written before you came home")]
            )
        ),
        AcademyLessonModule(
            id: "compass-running-green-011",
            sessionID: "compass-running",
            title: "The Green Run",
            realSubject: "a Compass Run somewhere green, noticing what's living there",
            concept: "Somewhere green is full of living things you've never noticed. Get down low, listen, touch, and then lie still and watch the sky.",
            lectureBeats: [
                "Every patch of grass has more living in it than you'd think.",
                "Getting low, listening and touching finds what eyes alone miss.",
                "Lying still at the end lets the place settle into you."
            ],
            demonstration: "Professor Stonebrook took the crew to the meadow behind the Open Field Gate and gave them ten minutes to find as many different plants as they could in one square of grass. Lara found nineteen. She said she'd walked across that meadow a hundred times and never seen any of them.",
            interactionPrompt: "What's the nearest green place you could get to?",
            realWorldPractice: "Do one run somewhere green this month. Find three tiny plants, listen for one bird, and lie still for five minutes.",
            number: 11,
            mode: "A run somewhere green",
            lecture: "This one's outside, somewhere green. A park, a wood, a field, even a churchyard. North: I wonder what's living here that I've never noticed. East: walk in, with a blanket to sit on. Thirty minutes. South: get down low. Find three different tiny plants in one patch of grass. Listen for a bird you can't see. Touch the bark of two different trees, and notice which one feels warmer. West: write one sentence. Center: lie on the blanket and watch the clouds for five minutes. Don't name them. Just watch them go.",
            twoMinutes: "Find the nearest living plant, even a houseplant or a weed in a crack. Look at it closely for one minute. Write down three things about it.",
            reading: "The Wonder Compass, Chapter 19: Natural Wonder",
            practice: runPractice(
                "green", title: "The Green Run",
                invitation: "Stonebrook's summer run is somewhere green. Write where you went, what you found living there, and your sentence.",
                action: "Fold up the blanket",
                [("where", "Where you went", "A park, a wood, a field"),
                 ("living", "What you found living there", "Plants, birds, insects"),
                 ("west", "West: your sentence", "One sentence about it")]
            )
        ),
        AcademyLessonModule(
            id: "compass-running-again-012",
            sessionID: "compass-running",
            title: "Run It Again",
            realSubject: "repeating your first run of the year to see what's changed",
            concept: "Go back and do your very first run of the year again. The place will have changed, and so will you.",
            lectureBeats: [
                "Repeating your first run shows you how the place has changed.",
                "It also shows you how much more you notice now.",
                "One run done twice can hold a whole year."
            ],
            demonstration: "Professor Stonebrook took the crew back to the gatepost from their first run of the year. Nothing much had changed about the gatepost. But they all found things they hadn't seen the first time: a snail shell in the groove, a name scratched on the back, a feather tucked into a crack. Stonebrook said that was the lesson. The gatepost hadn't changed. They had.",
            interactionPrompt: "Where was your first run of the year? What do you think will have changed?",
            realWorldPractice: "Go back and do your first run of the year again. Write one sentence about what changed in the place, and one about what changed in you.",
            number: 12,
            mode: "The same run, a year on",
            lecture: "Last run of the year. Go back to your very first run, the one from last September, and do it again. Same place. Same time of day if you can. Then look for what's different. The place will have changed. A tree's grown, a shop's shut, somebody's painted their door. You'll have changed too. You'll notice things you'd have walked straight past a year ago. That's the whole year, right there, in one run. Write one sentence about the place, and one about you. Then sit down and let it be the end of something. Next month we start again.",
            twoMinutes: "Think of a place you went a year ago. Write one thing that's probably changed about it, and one thing that's changed about you.",
            reading: "The Wonder Compass, Appendix G: Your Adventure Through Wonder",
            practice: runPractice(
                "again", title: "Run It Again",
                invitation: "Stonebrook's last run of the year: go back to your first one. Write where it was, what changed in the place, and what changed in you.",
                action: "Close the gate behind you",
                [("where", "Where your first run was", "From last September"),
                 ("place", "What changed in the place", "Trees, shops, doors"),
                 ("you", "What changed in you", "What you noticed this time")]
            )
        )
    ]

    // MARK: The societies: one meeting a month

    private static func societyPractice(
        _ id: String, title: String, invitation: String, action: String,
        _ fields: [(id: String, label: String, placeholder: String)]
    ) -> AcademyActivity {
        practice("compass-society", "compass-society-\(id)", kind: .souvenirCircle, title: title, invitation: invitation, action: action, fields)
    }
    /// The Compass Society meets in the Secret Garden of Prose with one rule: nobody mocks a sentence.
    /// Zara anchors it, quick and practical; care shows up as the next useful move, never a pep talk.
    static let compassSociety: [AcademyLessonModule] = [
        AcademyLessonModule(
            id: "compass-society-souvenirs-001",
            sessionID: "compass-society",
            title: "Say It Out Loud",
            realSubject: "sharing what you noticed, and listening to other people",
            concept: "A true sentence feels more real once somebody's heard it and been kind about it.",
            lectureBeats: [
                "Your sentence is what you saw. It isn't a show.",
                "Listeners help by asking about one real detail.",
                "Sharing should make the thing feel more real. It doesn't have to be impressive."
            ],
            demonstration: "Zara Finch read one sentence twice. First she read it like a play. Then she read it plainly. Everybody could hear which one was true.",
            interactionPrompt: "Ask one kind question that would help a sentence get more exact.",
            realWorldPractice: "Tell somebody one small true thing you noticed. If nobody's around, write down the question you'd want them to ask.",
            number: 1,
            mode: "The big idea",
            lecture: "Right. Rules first, because there's only one. Nobody mocks a sentence in this garden. Not a bit. Not with your face, either. You read yours, we listen, then somebody asks you about one real thing in it. That's it. Why read it out at all? Because a sentence you've only written down is half kept. Say it out loud to people who are listening, and it's real. You'll feel daft the first time. Everybody does. Read it anyway. Plainly. Not like a play. Then sit down, and listen to somebody else's.",
            twoMinutes: "Write one small true thing you noticed today. Then write the question you'd like somebody to ask you about it.",
            reading: "The Wonder Compass, Chapter 12A: The Shared Compass"
        ),
        AcademyLessonModule(
            id: "compass-society-fine-002",
            sessionID: "compass-society",
            title: "Not Fine",
            realSubject: "answering 'how was your day?' with something real",
            concept: "When somebody asks how your day was, don't say fine. Give them one small true thing you saw instead.",
            lectureBeats: [
                "\"Fine\" ends a conversation before it starts.",
                "One small, real detail makes people lean in.",
                "Keep one sentence ready every day for when somebody asks."
            ],
            demonstration: "Zara made everyone in the Secret Garden of Prose ask the person next to them how their day had been, and banned the word \"fine\". Lara said she'd seen a crow carrying a whole slice of toast. The person next to her said, \"No,\" and then they talked for twenty minutes.",
            interactionPrompt: "If somebody asked how your day was right now, what would you tell them instead of \"fine\"?",
            realWorldPractice: "This week, when somebody asks how your day was, tell them one small true thing you saw instead of saying fine.",
            number: 2,
            mode: "The usual mistake",
            lecture: "Somebody asks how your day was. You say fine. They say fine. That's the whole conversation, and neither of you has said anything. It happens a hundred times a week. So here's the fix. Have a sentence ready. Not a big one. \"I saw a kid dancing in the cereal aisle.\" \"The bus driver was singing.\" Next time somebody asks, give them that instead of fine. Watch their face. They lean in. They tell you one back. That's two people who've actually said something. It costs one sentence. Keep one in your pocket every day.",
            twoMinutes: "Write the sentence you'd give somebody tonight instead of \"fine\". Make it one small thing you saw today.",
            reading: "The Wonder Compass, Chapter 9: West = Write",
            practice: societyPractice(
                "fine", title: "Instead of Fine",
                invitation: "Zara's banned \"fine\". Write the sentence you gave instead, who you gave it to, and what they said back.",
                action: "Read it to the circle",
                [
                 ("sentence", "Your sentence", "One small true thing"),
                 ("who", "Who asked", "A friend, a parent, a stranger"),
                 ("back", "What they said back", "Did they tell you one?")
                ]
            )
        ),
        AcademyLessonModule(
            id: "compass-society-question-003",
            sessionID: "compass-society",
            title: "Ask About One Thing",
            realSubject: "listening well, and asking about one real detail",
            concept: "When somebody shares a sentence, don't just say it's lovely. Ask about one real detail in it. The answer's often the best part.",
            lectureBeats: [
                "\"That's lovely\" is kind, but it doesn't help.",
                "One question about one detail shows you really listened.",
                "Ask about the thing, not about what it meant."
            ],
            demonstration: "Lara read a sentence about her grandmother's kitchen. Zara asked one question: \"What was on the windowsill?\" Lara thought, and then said, \"A row of eggcups, one for each of us, even after we'd all left home.\" Nobody said anything for a bit. Then Zara said, \"Write that one down.\"",
            interactionPrompt: "Ask one question about one detail in somebody's sentence.",
            realWorldPractice: "Next time somebody tells you about their day, ask one question about one real detail in it.",
            number: 3,
            mode: "Showing how",
            lecture: "When somebody reads you their sentence, don't tell them it's lovely. That's nice of you, and it doesn't help. Ask about one real thing in it. \"What colour was the crow?\" \"How long did the bus driver sing for?\" One question, about one detail. It shows you actually heard it. And nine times out of ten, the answer's better than the sentence. People keep their best bits back. A good question gets them out. Don't ask what it meant. Don't ask how it made them feel. Ask about the thing.",
            twoMinutes: "Think of something somebody told you this week. Write one question you could ask about one detail in it.",
            reading: "The Wonder Compass, Chapter 12A: The Shared Compass",
            practice: societyPractice(
                "question", title: "One Good Question",
                invitation: "Zara wants one good question. Write what somebody shared, the question you asked about it, and their answer.",
                action: "Bring it to the circle",
                [
                 ("shared", "What they shared", "Their sentence or story"),
                 ("question", "Your question", "About one real detail"),
                 ("answer", "Their answer", "Often the best part")
                ]
            )
        ),
        AcademyLessonModule(
            id: "compass-society-forty-seventh-004",
            sessionID: "compass-society",
            title: "Elio's Forty-Seventh",
            realSubject: "keeping one moment just for yourself",
            concept: "Most sentences get more real when you share them. A few are only yours. Keep one this month that nobody will ever hear.",
            lectureBeats: [
                "Sharing makes most moments feel more real.",
                "Some moments are just for you, and that's allowed.",
                "Keeping one secret sentence is part of the practice too."
            ],
            demonstration: "Zara asked Elio, again, about his forty-seventh run. He smiled, again. Then he took a folded paper out of his pocket, showed them it was there, and put it back. Everybody agreed that was somehow better than hearing it.",
            interactionPrompt: "Is there a moment from this year you'd rather keep to yourself?",
            realWorldPractice: "Write one sentence this month that you won't share with anybody. Keep it somewhere safe.",
            number: 4,
            mode: "A secret",
            lecture: "Elio's done forty-seven Compass Runs. He's read us forty-six of them. He won't read the forty-seventh. We've asked. He just smiles. And here's the thing. That's allowed. This society's about sharing, but not about sharing everything. Some sentences are only for you. You keep them because they're yours. Sharing makes most things more real. Keeping one or two makes you more real. So this month, write one sentence nobody will ever hear. Fold it up. Put it somewhere. You'll know it's there. That's enough.",
            twoMinutes: "Write one sentence about something you'd never tell anyone. Fold it up. Keep it.",
            reading: "The Wonder Compass, Chapter 9: West = Write",
            practice: societyPractice(
                "kept", title: "The One You Keep",
                invitation: "Zara says one sentence can be only yours. Don't write it here. Just write where you've kept it, and how it feels to have it.",
                action: "Keep it",
                [
                 ("where", "Where you kept it", "A pocket, a drawer, a book"),
                 ("feels", "How it feels", "To have one nobody's heard")
                ]
            )
        ),
        AcademyLessonModule(
            id: "compass-society-twice-005",
            sessionID: "compass-society",
            title: "Read It Twice",
            realSubject: "reading a sentence aloud slowly enough to be heard",
            concept: "Read your sentence out loud twice, with a breath in between. The second time, people really hear it, and so do you.",
            lectureBeats: [
                "The first reading is often lost while the room settles.",
                "The second, slower reading is the one that lands.",
                "The word you lean on is usually the best one. The one you rush might need cutting."
            ],
            demonstration: "Zara made the whole circle read twice. The first round was quick and mumbled. The second round was slow, and the garden went quiet in a way it hadn't before. Somebody's sentence about a shoelace made two people cry, and nobody knew why.",
            interactionPrompt: "Read your sentence twice. Which word did you lean on the second time?",
            realWorldPractice: "Read one sentence of yours out loud twice this week, with a breath in between. Notice which word you lean on.",
            number: 5,
            mode: "A rule to play by",
            lecture: "New rule. Everybody reads their sentence twice. The first time, the room's still settling. Somebody's coughing. You're nervous. Nobody really hears it. The second time, slower, the room's ready, and it lands. It feels strange saying the same thing again straight away. Do it anyway. Leave a breath between. You'll notice, the second time, which word you lean on. That's usually the best word. And if there's a word you don't want to say twice, that's the word to cut.",
            twoMinutes: "Write one sentence about today. Read it out loud twice, slowly the second time. Underline the word you leaned on.",
            reading: "The Wonder Compass, Chapter 12A: The Shared Compass",
            practice: societyPractice(
                "twice", title: "Read It Twice",
                invitation: "Zara's rule: read it twice. Write your sentence, the word you leaned on, and any word you'd cut.",
                action: "Read it again",
                [
                 ("sentence", "Your sentence", "Read out loud twice"),
                 ("leaned", "The word you leaned on", "The second time through"),
                 ("cut", "A word you'd cut", "The one you didn't want to say again")
                ]
            )
        ),
        AcademyLessonModule(
            id: "compass-society-swap-006",
            sessionID: "compass-society",
            title: "The Sentence Swap",
            realSubject: "hearing your own words in somebody else's voice",
            concept: "Swap sentences without names, and read somebody else's aloud as if it were yours. You'll hear your own properly for the first time.",
            lectureBeats: [
                "Hearing your sentence in somebody else's voice lets you really hear it.",
                "Reading a stranger's sentence means carrying their moment for a minute.",
                "Nobody has to say whose was whose."
            ],
            demonstration: "Zara passed the hat round the Secret Garden. Lara pulled out a sentence about a lost glove on a railing and read it very seriously. Halfway through she realised it was her own, and went red, and finished it anyway.",
            interactionPrompt: "If you heard your sentence in somebody else's voice, what do you think you'd notice?",
            realWorldPractice: "Swap one sentence with somebody this week, without names, and read theirs out loud.",
            number: 6,
            mode: "A game",
            lecture: "Everybody writes one sentence on a card. No name. They go in a hat. Everybody takes one out and reads it aloud as if it were theirs. Here's why. When you hear your own sentence in somebody else's voice, you can finally hear it properly. You stop thinking about yourself and hear the words. And reading a stranger's sentence as if it's yours is a funny kind of kindness. For a minute, you carry their moment. Afterwards, nobody has to say whose was whose. Most people tell anyway.",
            twoMinutes: "Write a sentence about today. Now read it out loud in a completely different voice, as if somebody else wrote it. Write what you noticed.",
            reading: "The Wonder Compass, Chapter 12A: The Shared Compass",
            practice: societyPractice(
                "swap", title: "The Swap",
                invitation: "Zara wants sentences swapped. Write the sentence you read out, whose it turned out to be, and what you heard in your own when somebody else read it.",
                action: "Pass the hat",
                [
                 ("read", "The sentence you read", "Somebody else's"),
                 ("whose", "Whose it was", "If they told you"),
                 ("heard", "What you heard in yours", "When somebody else read it")
                ]
            )
        ),
        AcademyLessonModule(
            id: "compass-society-theirs-007",
            sessionID: "compass-society",
            title: "Tell Somebody Else's",
            realSubject: "passing on somebody else's small wonder, properly",
            concept: "Bring somebody else's small wonder and tell it for them, properly. You'll have to really listen to tell it right.",
            lectureBeats: [
                "To tell somebody's moment well, you have to ask them about it.",
                "Telling it carefully shows how much it mattered to them.",
                "Passing on somebody's wonder is a kind thing to do."
            ],
            demonstration: "Lara told the circle her little brother's sentence: he'd seen a snail on the bus. Just on the seat, going somewhere. Everybody laughed, and then everybody wanted to know where it got off. Lara said she'd ask him.",
            interactionPrompt: "Whose small wonder from this week would you most like to tell for them?",
            realWorldPractice: "Ask somebody for one small thing they noticed this week. Then tell it to somebody else, properly, for them.",
            number: 7,
            mode: "Telling someone else's",
            lecture: "This month you don't read your own sentence. You tell somebody else's. Ask a friend, a parent, anybody, for one small thing they noticed this week. Then bring it here and tell it for them. Properly. With the details. You'll find you have to ask them questions to tell it right. And when you tell it, you'll hear how much it mattered to them. Telling somebody's wonder for them is one of the nicest things you can do. They'll hear about it, too. People always do.",
            twoMinutes: "Think of something small somebody told you recently. Write it down as if you were telling it for them.",
            reading: "The Wonder Compass, Chapter 12A: The Shared Compass",
            practice: societyPractice(
                "theirs", title: "Somebody Else's Wonder",
                invitation: "Zara wants somebody else's wonder told well. Write whose it was, what they noticed, and who you told it to.",
                action: "Tell it for them",
                [
                 ("whose", "Whose it was", "A friend, a parent, a child"),
                 ("noticed", "What they noticed", "With the details"),
                 ("told", "Who you told it to", "And what they said")
                ]
            )
        ),
        AcademyLessonModule(
            id: "compass-society-mended-008",
            sessionID: "compass-society",
            title: "When It Lands Wrong",
            realSubject: "what to do when sharing goes wrong",
            concept: "Sharing something real is a risk. If you hurt somebody's sentence, own up straight away. If somebody hurts yours, you can say it mattered.",
            lectureBeats: [
                "Even a kind laugh can land badly when somebody's shared something real.",
                "If you get it wrong, say so straight away, plainly.",
                "If somebody laughs at yours, you can say, \"That one mattered to me.\""
            ],
            demonstration: "Zara stood up at the start of the meeting and said sorry to Lara in front of everybody. Then she asked Lara what the cat's name was. It was Biscuit. Lara read the sentence again, and this time everybody listened, and nobody laughed until the bit that was meant to be funny.",
            interactionPrompt: "Has somebody ever laughed at something you shared? What did you wish you'd said?",
            realWorldPractice: "This week, if you notice you've brushed off something somebody shared, go back and ask them one question about it.",
            number: 8,
            mode: "Someone gets it wrong",
            lecture: "I need to say something, and it's about me. Last week Lara read a sentence about her cat, and I laughed. Not at her. At the cat. But it didn't land like that, and she went quiet for the rest of the night. I broke our one rule without meaning to. So here's what I've learned. If you get it wrong, say so. Straight away, plainly, in front of everybody. Don't make a big thing of it. Then ask about the cat. And if somebody laughs at yours, you can say, \"That one mattered to me.\" That's allowed too.",
            twoMinutes: "Think of something you shared that didn't go well. Write the sentence you wish you'd said.",
            reading: "The Wonder Compass, Chapter 12A: The Shared Compass",
            practice: societyPractice(
                "mended", title: "Mending It",
                invitation: "Zara's owning up. Write about a time sharing went wrong, what you'd say now, and the question you'd ask.",
                action: "Mend it",
                [
                 ("happened", "What happened", "Yours, or somebody else's"),
                 ("say", "What you'd say now", "Plainly"),
                 ("question", "The question you'd ask", "About the real thing in it")
                ]
            )
        ),
        AcademyLessonModule(
            id: "compass-society-far-009",
            sessionID: "compass-society",
            title: "Send It Far",
            realSubject: "sending small true sentences to people far away",
            concept: "Send one small sentence about your day to somebody far away. It tells them they're part of your days, and they'll send one back.",
            lectureBeats: [
                "A short sentence about something you saw is easier to send than a long message.",
                "It tells somebody they're still part of your days.",
                "Over a year, the messages back and forth become their own little book."
            ],
            demonstration: "Zara had everyone send one sentence to somebody far away before the meeting ended. Most people had a reply before they'd left the garden. Elio's grandad sent back a photo of his own garden, with a heron in it.",
            interactionPrompt: "Who's far away that you'd like to send a sentence to?",
            realWorldPractice: "Send one small sentence about your day to somebody far away. Keep doing it once a week.",
            number: 9,
            mode: "Sent away",
            lecture: "Some of the people you love aren't here. They've moved, or they're busy, or they're just far. Send them a sentence. Not a long message. Not \"how are you\". One small thing you saw today that made you think of them, or just that you wanted them to have. \"There's a heron on the canal again.\" That's all. It tells them they're in your days. And it gives them something to send back. Over a year, a thread like that turns into its own little book.",
            twoMinutes: "Think of somebody far away. Write one small thing you saw today that you'd like them to know about.",
            reading: "The Wonder Compass, Chapter 9: West = Write",
            practice: societyPractice(
                "far", title: "Send It Far",
                invitation: "Zara wants a sentence sent far. Write who you sent it to, what you sent, and what came back.",
                action: "Send it",
                [
                 ("who", "Who you sent it to", "Somebody far away"),
                 ("sent", "What you sent", "One small thing"),
                 ("back", "What came back", "If anything has yet")
                ]
            )
        ),
        AcademyLessonModule(
            id: "compass-society-linked-010",
            sessionID: "compass-society",
            title: "Linked Lines",
            realSubject: "writing something together, one sentence each",
            concept: "Write together: each person adds one sentence that picks up something from the last. You end up with something nobody could have written alone.",
            lectureBeats: [
                "Japanese poets wrote long linked poems together, called renga.",
                "Each new part picks up something from the one before and turns it.",
                "A circle of sentences becomes one piece that nobody owns alone."
            ],
            demonstration: "Zara started with a sentence about rain on the greenhouse. Lara caught the word \"glass\" and wrote about her nan's glasses. Elio caught \"nan\" and wrote about bread. It went round twice and ended with a sentence about rain on a bakery window, and the whole circle cheered.",
            interactionPrompt: "Take the last sentence somebody said, and add one that catches something from it.",
            realWorldPractice: "Start a chain with a friend or somebody at home: each of you adds one sentence that picks up something from the last.",
            number: 10,
            mode: "Writing together",
            lecture: "Hundreds of years ago in Japan, poets used to sit together and write one long poem between them, called a renga. One person wrote a few lines. The next added lines that picked up something from the last ones and turned it a little. Round and round the room. Bashō was famous for it. So tonight we do it with sentences. I'll start with one about today. You add one that catches something from mine. A colour, a sound, a word. Then the next person. By the end we'll have one long thing nobody could have written alone.",
            twoMinutes: "Write a sentence about today. Then write a second one that catches one word from the first and goes somewhere new.",
            reading: "The Wonder Compass, Chapter 12A: The Shared Compass",
            practice: societyPractice(
                "linked", title: "Linked Lines",
                invitation: "Zara wants a chain. Write the sentence you were given, the bit you caught from it, and the sentence you added.",
                action: "Add your line",
                [
                 ("given", "The sentence you were given", "From whoever went before"),
                 ("caught", "What you caught", "A colour, a sound, a word"),
                 ("yours", "Your sentence", "Where you took it")
                ]
            )
        ),
        AcademyLessonModule(
            id: "compass-society-listen-011",
            sessionID: "compass-society",
            title: "Just Listen",
            realSubject: "listening without planning what you'll say next",
            concept: "Most people wait for their turn instead of listening. Put your own sentence face down and just hear everybody else's.",
            lectureBeats: [
                "Planning what you'll say means you're not really listening.",
                "Putting your own sentence away lets you hear other people properly.",
                "A circle only works if everybody's actually heard."
            ],
            demonstration: "Zara made everyone put their cards face down in a pile in the middle, so nobody could rehearse. Then she called on people at random. Lara said it was terrifying. She also said it was the first meeting where she could remember every single sentence afterwards.",
            interactionPrompt: "What's one thing somebody said today that you really listened to?",
            realWorldPractice: "In one conversation this week, don't plan what you'll say next. Just listen until they've finished.",
            number: 11,
            mode: "Listening",
            lecture: "Most people don't listen to somebody's sentence. They wait for their turn. You can see them doing it. Lips moving a bit. Planning. Tonight, nobody plans. When somebody reads, your own card stays face down. Don't think about yours at all. Just hear theirs. Then, when it's your turn, read yours without having practised it in your head. It'll come out rougher. It'll also be the first time all year that everybody in this garden actually heard everybody else. That's the whole point of a circle.",
            twoMinutes: "Think of the last conversation you had. Write down one thing the other person said, as exactly as you can.",
            reading: "The Wonder Compass, Chapter 12A: The Shared Compass",
            practice: societyPractice(
                "listen", title: "Just Listen",
                invitation: "Zara wants you listening. Write whose sentence you heard best, what it was, and what you noticed when you stopped planning your own.",
                action: "Report what you heard",
                [
                 ("whose", "Whose you heard", "Somebody else's"),
                 ("what", "What it was", "As exactly as you can"),
                 ("noticed", "What you noticed", "When you stopped planning yours")
                ]
            )
        ),
        AcademyLessonModule(
            id: "compass-society-year-012",
            sessionID: "compass-society",
            title: "Read the Year",
            realSubject: "choosing your best sentence of the year and reading it aloud",
            concept: "Read back through a year of your sentences and pick the one that makes your chest go tight. Bring it, and read it aloud.",
            lectureBeats: [
                "Choosing one sentence from a whole year makes you read them all again.",
                "The right one is often the one that makes your chest go tight.",
                "Reading it aloud to people who listen closes the year properly."
            ],
            demonstration: "On the last night of the year, the whole Compass Society read their best sentences one after another, by lantern light. Elio read his forty-sixth. Then he looked at Zara, took out the folded paper, and put it back in his pocket again. Zara said that was fine. It was still his.",
            interactionPrompt: "What's the best sentence you wrote this year?",
            realWorldPractice: "Read back through everything you wrote this year and choose your one best sentence. Read it to somebody.",
            number: 12,
            mode: "Looking back",
            lecture: "Last meeting of the year. Everybody brings their best sentence from the whole year. Just one. Choosing's the hard part. Read back through all of them. Some will make you laugh. Some you won't remember writing. One will make your chest go tight. That's the one. Bring it here. Read it twice. We'll ask you one question about it. Then we'll keep a moment's quiet for the year, because it was a good one, even the bits that weren't. And next year we start again. Same garden. Same rule. Nobody mocks a sentence here.",
            twoMinutes: "Think back over this year. Write down the one moment you'd most want to keep, in one sentence.",
            reading: "The Wonder Compass, Chapter 9: West = Write",
            practice: societyPractice(
                "year", title: "The Year's Best",
                invitation: "Zara's last meeting of the year: bring your best sentence. Write it, why that one, and who you read it to.",
                action: "Read it to the garden",
                [
                 ("sentence", "Your best sentence", "From the whole year"),
                 ("why", "Why that one", "What it does to you"),
                 ("who", "Who you read it to", "And what they asked")
                ]
            )
        )
    ]

    private static func guildPractice(
        _ id: String, title: String, invitation: String, action: String,
        _ fields: [(id: String, label: String, placeholder: String)]
    ) -> AcademyActivity {
        practice("marginalia-guild", "marginalia-\(id)", kind: .marginalNote, title: title, invitation: invitation, action: action, fields)
    }
    /// The Marginalia Guild, officially Boggle's: annotating books for the readers who come after.
    /// Her ledger voice again, dry and exact. Real margins from Fermat to a Dubrovnik cat.
    static let marginaliaGuild: [AcademyLessonModule] = [
        AcademyLessonModule(
            id: "marginalia-annotation-001",
            sessionID: "marginalia-guild",
            title: "Write Back to the Book",
            realSubject: "writing notes in the margins of what you read",
            concept: "A good note in the margin shows you really read the page. It's for a stranger who'll read the same page one day.",
            lectureBeats: [
                "A margin note talks to the page, and to somebody who isn't here yet.",
                "The best notes point at one exact word, picture or question.",
                "You can disagree with a book and still be fair to it."
            ],
            demonstration: "Professor Boggle compared three margin notes. She kept the one that pointed at the oddest verb on the page.",
            interactionPrompt: "Write a note that somebody reading later could answer.",
            realWorldPractice: "Copy out one sentence from something you read today. Write one honest question next to it.",
            number: 1,
            mode: "The big idea",
            lecture: "A margin is the white bit round the edge of the page. Most people leave it empty, out of respect. I think that's a waste. A margin's where you talk back. Underline the strangest verb, and write \"why this one?\" next to it. Disagree, in pencil. Draw a little star by the line that made you put the book down and stare at the wall. Then one day somebody else will open your copy and find you there. Fifty years from now, maybe. Write something they could answer. Your own books only, mind. Library books get a slip of paper.",
            twoMinutes: "Find one sentence near you, in a book, on a packet, anywhere. Write one honest question next to it.",
            reading: "The Wonder Compass, Chapter 9: West = Write"
        ),
        AcademyLessonModule(
            id: "marginalia-fermat-002",
            sessionID: "marginalia-guild",
            title: "The Margin Was Too Small",
            realSubject: "how one margin note can matter for centuries",
            concept: "One note in a margin can matter more than you'd think. Fermat's note kept mathematicians busy for more than three hundred and fifty years.",
            lectureBeats: [
                "Fermat wrote in a margin that he'd found a proof, but the margin was too small to hold it.",
                "Nobody ever found his proof, and the puzzle wasn't solved until 1994.",
                "A short note can carry a lot. Make yours worth reading."
            ],
            demonstration: "Professor Boggle wrote \"I have a marvellous answer, but this margin is too small\" in the margin of the Guild's register, and left it there. By the end of the evening four people had written guesses underneath. One of the guesses was rude. She left that there too, and noted the date.",
            interactionPrompt: "What's a note you'd leave in the margin of the book you're reading?",
            realWorldPractice: "Leave one note in the margin of one of your own books this week: a question, a guess, or an argument.",
            number: 2,
            mode: "A true story",
            lecture: "In 1637 a French lawyer called Pierre de Fermat was reading an old maths book, and he wrote a note in the margin. He said he'd found a truly marvellous proof of a puzzle about numbers, but the margin was too small to hold it. He never wrote it down anywhere else, and nobody ever found it. Mathematicians spent more than three hundred and fifty years trying to work it out. It was finally solved in 1994. All because of one note in a margin. I'm not saying your notes will keep anybody busy for three hundred years. I'm saying a margin note can matter more than you'd think. Make it a good one.",
            twoMinutes: "Find any book of your own. Write one short note in the margin next to a line you like. Make it something a stranger could answer.",
            reading: "Pierre de Fermat, in the margin of Diophantus's Arithmetica (1637)",
            practice: guildPractice(
                "fermat", title: "The Note in the Margin",
                invitation: "Boggle wants one good margin note. Write the line you answered, your note, and what you hope a stranger will make of it.",
                action: "File the note",
                [
                 ("line", "The line", "Copy it out"),
                 ("note", "Your note", "A question, a guess, an argument"),
                 ("stranger", "For the stranger", "What you hope they'll think")
                ]
            )
        ),
        AcademyLessonModule(
            id: "marginalia-monks-003",
            sessionID: "marginalia-guild",
            title: "Monks in the Margins",
            realSubject: "leaving a little of yourself in the margins, the way old scribes did",
            concept: "Long ago, monks copying books wrote about themselves in the margins: the cold, their aching hands, their cats. Leave a little of yourself in your margins too.",
            lectureBeats: [
                "Monks copying books by hand wrote little notes about their own day in the margins.",
                "One Irish monk wrote a poem about his cat, Pangur Bán, and people still read it.",
                "Where you were and what the weather was doing is often the part that lasts."
            ],
            demonstration: "Professor Boggle read the Guild a few of the old monks' complaints. My hand is tired. The ink is thin. It's cold. Ellie laughed and said it sounded exactly like her. Then she wrote \"Raining. Toast going cold.\" in the corner of the page she was reading, and looked very pleased with herself.",
            interactionPrompt: "If you wrote a note about yourself in the margin of what you're reading, what would it say?",
            realWorldPractice: "Next time you read one of your own books, write where you are and what the weather's doing in the margin.",
            number: 3,
            mode: "Old notes",
            lecture: "A thousand years ago, books were copied out by hand, one letter at a time, often by monks in cold rooms. And they wrote in the margins. Not about the book. About themselves. That the ink was thin. That their hand hurt. That it was cold. One Irish monk wrote a little poem in his notebook about his cat, Pangur Bán, who hunted mice while the monk hunted words. Nobody remembers most of the books those monks copied. People still read the poem about the cat. So leave a little of yourself in your margins. Where you are. What the weather's doing. It's the bit that lasts.",
            twoMinutes: "Write a tiny note about right now: where you are, the weather, what you're drinking. As if it were going in a margin.",
            reading: "Pangur Bán (Irish, ninth century)",
            practice: guildPractice(
                "monks", title: "Leave Yourself in It",
                invitation: "Boggle wants you in the margin. Write the book, where you were reading it, and the little note you left.",
                action: "File it",
                [
                 ("book", "The book", "One of your own"),
                 ("where", "Where you were", "The room, the weather, the drink"),
                 ("note", "Your note", "About you, not the book")
                ]
            )
        ),
        AcademyLessonModule(
            id: "marginalia-snails-004",
            sessionID: "marginalia-guild",
            title: "Knights Fighting Snails",
            realSubject: "drawing in the margins, the way medieval artists did",
            concept: "Old books are full of strange little margin drawings, like knights fighting snails. Margins aren't only for words. Draw in yours.",
            lectureBeats: [
                "Knights fighting snails turn up again and again in the margins of medieval books.",
                "Nobody's completely sure why, which is part of the fun.",
                "A small drawing in a margin can say what words can't."
            ],
            demonstration: "Professor Boggle gave every Guild member a page and ten minutes to doodle in its margins. The second-year who's been reading the same mythology book for six months drew a tiny dragon asleep on the page number. Boggle said it was the best margin she'd seen all year, and asked him not to tell anyone she'd said so.",
            interactionPrompt: "If you drew one thing in the margin of the page you're reading, what would it be?",
            realWorldPractice: "Draw one small picture in the margin of one of your own books, next to the line that made you think of it.",
            number: 4,
            mode: "A strange old picture",
            lecture: "In handwritten books from about seven hundred years ago, there's a picture that keeps turning up in the margins. A knight in full armour, with a sword, fighting a snail. Nobody's completely sure why. Some people think it was a joke about cowards. Some think it was about a particular group of people at the time. Some think the artists just found it funny. I like that we don't know. Margins aren't only for words. Draw in them. A little picture of whatever the page made you think of. Your doodle might puzzle somebody for seven hundred years.",
            twoMinutes: "Draw a tiny picture of the last thing that made you smile, as if it were in the corner of a page.",
            reading: "The margins of medieval books (thirteenth and fourteenth centuries)",
            practice: guildPractice(
                "snails", title: "Draw in the Margin",
                invitation: "Boggle wants a doodle. Write the line you drew next to, what you drew, and why.",
                action: "File the doodle",
                [
                 ("line", "The line", "The one that made you think of it"),
                 ("drew", "What you drew", "A snail, a dragon, a cup"),
                 ("why", "Why", "What it says that words don't")
                ]
            )
        ),
        AcademyLessonModule(
            id: "marginalia-three-kinds-005",
            sessionID: "marginalia-guild",
            title: "Question, Argument, Joy",
            realSubject: "the three kinds of margin note worth writing",
            concept: "There are three good kinds of margin note: a question, an argument, and a shout of joy. Underlining on its own is just nodding.",
            lectureBeats: [
                "A good note is a question, a disagreement, or a little shout of joy.",
                "Underlining on its own is like nodding without saying anything.",
                "Knowing you'll answer back makes you read more closely."
            ],
            demonstration: "Professor Boggle handed out one poem and three coloured pencils: one for questions, one for arguments, one for joy. Ellie used up her joy pencil first. Most people barely touched their argument one. Boggle said that told her more about them than the poem did.",
            interactionPrompt: "Write one question you'd ask the book you're reading now.",
            realWorldPractice: "In one chapter of a book of your own, leave one question, one argument and one shout of joy.",
            number: 5,
            mode: "Showing how",
            lecture: "There are three kinds of good margin note, and I keep them in my ledger under three headings. A question: why does she open the window here? An argument: no, he'd never have said that. And a little shout of joy: yes, exactly this. Most people only ever underline, which is like nodding at somebody without saying anything. Tonight, every note has to be one of the three. Question, argument or joy. If it isn't, rub it out. You'll find you read differently when you know you're going to have to say something back.",
            twoMinutes: "Pick any sentence near you. Write a question to it, an argument with it, and a \"yes, exactly\". One line each.",
            reading: "The Wonder Compass, Chapter 9: West = Write",
            practice: guildPractice(
                "three", title: "Three Kinds of Note",
                invitation: "Boggle files notes under three headings. Leave one of each in your own book, and copy them here.",
                action: "File all three",
                [
                 ("question", "A question", "Why…?"),
                 ("argument", "An argument", "No, because…"),
                 ("joy", "A shout of joy", "Yes, exactly this")
                ]
            )
        ),
        AcademyLessonModule(
            id: "marginalia-fair-006",
            sessionID: "marginalia-guild",
            title: "Argue Fairly",
            realSubject: "disagreeing with a book honestly and fairly",
            concept: "Argue with a book, but fairly: argue with what it really says, say why, and then write one thing it got right.",
            lectureBeats: [
                "Disagreeing with a book means you're really reading it.",
                "Argue with what it actually says, not what you think it says.",
                "Find one thing it got right, even if you hate it."
            ],
            demonstration: "The second-year finally finished his mythology book and hated the ending. Professor Boggle made him write his argument in the margin, then one thing the book had got right. It took him forty minutes to find one. He found it on page twelve, and said it was annoyingly good.",
            interactionPrompt: "What's something you disagree with in something you've read lately?",
            realWorldPractice: "Find one line you disagree with in something you're reading. Argue with it in one sentence, then write one thing it gets right.",
            number: 6,
            mode: "A rule to play by",
            lecture: "You're allowed to argue with a book. I'd worry if you didn't. But there's a rule. Argue with what it actually says, not what you think it says. Copy the line out first, in the margin if there's room, so you're sure. Then say why you disagree, in one sentence. Then, and this is the hard bit, write one thing the book's got right. Every book's got something right, even the bad ones. A fair argument leaves the book standing. You don't have to win. You have to have been listening.",
            twoMinutes: "Think of something you read or heard this week that you disagreed with. Write why, in one sentence. Then write one thing it got right.",
            reading: "The Wonder Compass, Chapter 9: West = Write",
            practice: guildPractice(
                "fair", title: "A Fair Argument",
                invitation: "Boggle allows arguments, fairly. Write the line, your argument, and one thing it got right.",
                action: "File the argument",
                [
                 ("line", "The line", "Exactly as it says"),
                 ("argument", "Your argument", "In one sentence"),
                 ("right", "One thing it got right", "There's always one")
                ]
            )
        ),
        AcademyLessonModule(
            id: "marginalia-traces-007",
            sessionID: "marginalia-guild",
            title: "Somebody Was Here",
            realSubject: "finding other readers' notes in second-hand books",
            concept: "Second-hand books are full of other readers' notes, names and pressed flowers. Find one, and answer it.",
            lectureBeats: [
                "Old books often hold notes, names, bookmarks and flowers from earlier readers.",
                "Scholars have found thousands of these in old library books.",
                "Answering an old note is like talking to somebody across the years."
            ],
            demonstration: "Ellie brought in a second-hand poetry book with a note in the margin from 1962: \"Read this to M. on the train.\" The Guild spent the whole meeting arguing about who M. was. Ellie wrote underneath, in pencil, \"I hope it went well.\"",
            interactionPrompt: "What's the most interesting thing you've ever found inside a second-hand book?",
            realWorldPractice: "Look through a second-hand book for a note, a name or a bookmark somebody left. If it's your book, answer it in pencil.",
            number: 7,
            mode: "Finding old notes",
            lecture: "Second-hand books are full of people. Notes in the margins. Names written inside the cover. A bus ticket used as a bookmark in 1987. A pressed flower. Scholars at the University of Virginia went looking through old library books for exactly this sort of thing, and found thousands: notes, drawings, flowers, even locks of hair. Every one is a person who sat where you're sitting and read the same page. Go to a second-hand shop and look. When you find a note, answer it. In pencil. Underneath theirs.",
            twoMinutes: "Find the oldest book in your home. Look inside the cover and in the margins. Write down anything somebody left.",
            reading: "Book Traces, University of Virginia",
            practice: guildPractice(
                "traces", title: "Somebody Was Here",
                invitation: "Boggle wants you to find another reader. Write what you found, in which book, and how you answered it.",
                action: "File the find",
                [
                 ("found", "What you found", "A note, a name, a ticket, a flower"),
                 ("book", "In which book", "And how old it is"),
                 ("answered", "How you answered", "In pencil, underneath")
                ]
            )
        ),
        AcademyLessonModule(
            id: "marginalia-library-008",
            sessionID: "marginalia-guild",
            title: "Not in the Library Books",
            realSubject: "where it's fine to write, and where it isn't",
            concept: "Write all over your own books. Ask before writing in anybody else's. Library books never: tuck a slip of paper in at the page instead.",
            lectureBeats: [
                "Your own books are yours to write in.",
                "Library books belong to everybody, so they stay clean.",
                "A slip of paper tucked in at the page still lets the next reader find you."
            ],
            demonstration: "The second-year spent the whole meeting rubbing pencil out of a library book with a soft rubber, very carefully, while the Guild watched. Then he wrote the same note on a slip of paper and tucked it in. Professor Boggle wrote the incident up in her ledger under \"Resolved\".",
            interactionPrompt: "Which of your own books would you most like to write in?",
            realWorldPractice: "Next time you borrow a book, leave a note for the next reader on a slip of paper tucked in at the page.",
            number: 8,
            mode: "Someone gets it wrong",
            lecture: "I have to say this, because somebody in this Guild, who shall remain nameless, wrote a long and frankly excellent note in a library book. In pencil, at least. The library rang me. So here's the rule, written in my ledger in capitals. Your own books, write all over them. Other people's books, ask first. Library books, never. Not one dot. Use a slip of paper instead. Write your note on the slip, tuck it in at the page, and leave it there. The next reader still finds you. The library doesn't ring me. Everybody wins.",
            twoMinutes: "Write a note on a scrap of paper that you could tuck into a library book for the next reader. Keep it kind.",
            reading: "The Wonder Compass, Chapter 9: West = Write",
            practice: guildPractice(
                "slip", title: "A Slip for the Next Reader",
                invitation: "Boggle's rule: never in library books. Write the book, the page, and the slip you left for the next reader.",
                action: "Tuck it in",
                [
                 ("book", "The book", "A borrowed one"),
                 ("page", "The page", "Where you tucked it in"),
                 ("slip", "Your slip", "What the next reader will find")
                ]
            )
        ),
        AcademyLessonModule(
            id: "marginalia-coleridge-009",
            sessionID: "marginalia-guild",
            title: "Coleridge's Borrowed Books",
            realSubject: "leaving a gift of notes in a friend's book",
            concept: "Coleridge filled his friends' books with notes, and they were worth more for it. With permission, leave a friend something in theirs.",
            lectureBeats: [
                "Coleridge gave borrowed books back with the margins full of his notes.",
                "His friend Charles Lamb said the notes made them worth three times as much.",
                "With permission, a note in a friend's book is a gift."
            ],
            demonstration: "Professor Boggle lent Ellie her own copy of a book of fairy tales and said she could write in it once, anywhere. Ellie took a week to choose. When the book came back, there was one word in pencil next to the last line: \"Again.\"",
            interactionPrompt: "Whose book would you like to leave a note in, if they said yes?",
            realWorldPractice: "Ask a friend if you can write one note in a book of theirs. If they say yes, make it worth keeping.",
            number: 9,
            mode: "A borrowed book",
            lecture: "The poet Samuel Taylor Coleridge borrowed books from his friends, and when he gave them back, the margins were full of his notes. His friend Charles Lamb wrote that Coleridge returned books with interest, worth three times as much as before. People collect Coleridge's margin notes now. They fill whole volumes. So: with permission, and only with permission, write in a friend's book. Leave them something worth having. Then give it back.",
            twoMinutes: "Think of a book a friend loves. Write the note you'd leave in it if they let you.",
            reading: "Charles Lamb, \"The Two Races of Men\" (1820)",
            practice: guildPractice(
                "coleridge", title: "A Note for a Friend",
                invitation: "Boggle says with permission only. Write whose book it was, where you wrote, and the note you left.",
                action: "Give it back",
                [
                 ("whose", "Whose book", "And that they said yes"),
                 ("where", "Where you wrote", "Which page, which line"),
                 ("note", "Your note", "Something worth keeping")
                ]
            )
        ),
        AcademyLessonModule(
            id: "marginalia-underline-010",
            sessionID: "marginalia-guild",
            title: "Underline Less",
            realSubject: "choosing the one line on a page that matters most",
            concept: "Underlining everything means nothing stands out. Allow yourself one underline a page, and choose it.",
            lectureBeats: [
                "If half the page is underlined, none of it stands out.",
                "A limit of one a page makes you choose.",
                "Choosing the one line is what reading closely means."
            ],
            demonstration: "Professor Boggle confiscated every highlighter in the Corridor of Whispered Secrets and handed out one sharp pencil each. Ellie argued for ten minutes. Then she read a whole chapter, underlined exactly one line, and said she'd never read a chapter so carefully in her life.",
            interactionPrompt: "If you could only underline one line on the page you're reading, which would it be?",
            realWorldPractice: "Read one chapter this week allowing yourself one underline a page. Choose carefully.",
            number: 10,
            mode: "The usual mistake",
            lecture: "The commonest mistake in this Guild is the highlighter. People colour in half the page, and then none of it stands out. That isn't reading. That's painting. Here's my rule. One underline a page, at most. If you want to underline something else, you have to rub out the first one. It makes you choose. And choosing is reading. When you come back to the book in ten years, you'll find one line on each page, and it'll be the right one. Highlighters are for shopping lists.",
            twoMinutes: "Find a page of anything. Read it all, then underline only one line. Write why that one.",
            reading: "The Wonder Compass, Chapter 9: West = Write",
            practice: guildPractice(
                "underline", title: "One a Page",
                invitation: "Boggle allows one underline a page. Write the book, the one line you chose, and why that one.",
                action: "File the line",
                [
                 ("book", "The book", "One of your own"),
                 ("line", "The line you chose", "Only one"),
                 ("why", "Why that one", "What made it beat the others")
                ]
            )
        ),
        AcademyLessonModule(
            id: "marginalia-paws-011",
            sessionID: "marginalia-guild",
            title: "Paw Prints",
            realSubject: "the accidental marks that record where a page was read",
            concept: "A cat once walked across a manuscript in 1445, and its paw prints are still there. Leave your accidents in: the tea ring, the crumb. They show where you were.",
            lectureBeats: [
                "Inky paw prints from 1445 are still on a page in Dubrovnik.",
                "Accidental marks record the moment a page was read.",
                "Tea rings and crumbs are a kind of margin note too."
            ],
            demonstration: "Ellie arrived late with a book she'd dropped in a puddle. It had dried wavy, with a tide line across every page. She was nearly in tears. Professor Boggle looked at it for a long time, said it was the best record of a Tuesday she'd ever seen, and asked if she could write it up in the ledger.",
            interactionPrompt: "What accidental mark is in one of your books? What happened?",
            realWorldPractice: "Find an accidental mark in one of your own books: a stain, a fold, a crumb. Write down what you think happened.",
            number: 11,
            mode: "An accident",
            lecture: "In 1445, in Dubrovnik, somebody was copying out a book when a cat walked across the wet ink. The paw prints are still there on the page, nearly six hundred years later. Nobody wrote down the cat's name. But we know it was there. That's the best kind of margin, really. The accidental one. The tea ring. The crumb. The bit where you fell asleep and your pen wandered off. Don't clean those up. They're the record of where you were when you read it. They're the cat.",
            twoMinutes: "Find a mark on something near you that got there by accident. Write down how you think it happened.",
            reading: "A manuscript in the Dubrovnik archives (1445)",
            practice: guildPractice(
                "paws", title: "Leave the Cat In",
                invitation: "Boggle says keep the accidents. Write the book, the mark, and what happened.",
                action: "File the accident",
                [
                 ("book", "The book", "One of yours"),
                 ("mark", "The mark", "A ring, a fold, a crumb, a paw"),
                 ("happened", "What happened", "Where you were when it did")
                ]
            )
        ),
        AcademyLessonModule(
            id: "marginalia-year-012",
            sessionID: "marginalia-guild",
            title: "Your Year in the Margins",
            realSubject: "reading back a year of your own margin notes",
            concept: "Read back only the margins of everything you wrote in this year. Copy your three best notes into one book, and lend it to somebody.",
            lectureBeats: [
                "Your margins add up to a year-long conversation.",
                "Half of it turns out to be with yourself.",
                "Lending a book with your notes in lets somebody else join in."
            ],
            demonstration: "Professor Boggle read the Guild her own best margin note of the year. It was in a cookbook, next to a recipe for gingerbread, and it said: \"Too much ginger. Make it again anyway.\" She'd made it eleven times.",
            interactionPrompt: "What's the best note you wrote in a margin this year?",
            realWorldPractice: "Read back only the margins of the books you wrote in this year. Copy your three best notes into one book, date them, and lend it to somebody.",
            number: 12,
            mode: "Looking back",
            lecture: "End of the year. Take down every book you wrote in this year and read only the margins. Not the books. Just you. The questions. The arguments. The shouts of joy. The tea rings. You'll find you've been having a conversation all year, and half of it was with yourself. Copy your three best notes into the back of this year's last book. Date them. Then lend that book to somebody. Let them find you in it. That's what margins were for all along.",
            twoMinutes: "Think of a book you read this year. Write the note you wish you'd left in its margin.",
            reading: "The Wonder Compass, Chapter 9: West = Write",
            practice: guildPractice(
                "year", title: "The Year in the Margins",
                invitation: "Boggle's last meeting of the year: read only your margins. Copy out your best note, where it was, and who you'll lend it to.",
                action: "Close the ledger",
                [
                 ("note", "Your best note", "Copied out"),
                 ("where", "Where it was", "Which book, which page"),
                 ("lend", "Who you'll lend it to", "So they can find you in it")
                ]
            )
        )
    ]

    private static func inkwrightPractice(
        _ id: String, title: String, invitation: String, action: String,
        _ fields: [(id: String, label: String, placeholder: String)]
    ) -> AcademyActivity {
        practice("inkwright-society", "inkwright-\(id)", kind: .workshopNote, title: title, invitation: invitation, action: action, fields)
    }
    /// The Inkwright Society: honest first, kind second, and a burning at the end of every meeting.
    /// Professor Maxwell Thorne (not the Headmistress) only observes, so when he speaks it's brief and plain.
    static let inkwrightSociety: [AcademyLessonModule] = [
        AcademyLessonModule(
            id: "inkwright-workshop-001",
            sessionID: "inkwright-society",
            title: "Honest First, Kind Second",
            realSubject: "giving and getting feedback on writing",
            concept: "Good feedback looks after what the writer was trying to do, and still says honestly what worked and what didn't.",
            lectureBeats: [
                "Praise only helps when it says what worked.",
                "Say what a line did to you before you say how to fix it.",
                "Rewriting is how you stay loyal to the better version."
            ],
            demonstration: "The circle read one rough paragraph out loud. Then they picked out the line that was alive and the line that was only there to look nice.",
            interactionPrompt: "Name one line that feels alive, and one question that could help it grow.",
            realWorldPractice: "Rewrite one sentence today. Make its best noun or verb more exact.",
            number: 1,
            mode: "The big idea",
            lecture: "I don't say much in this room. I watch. But I'll say this once, at the start of every year. Here, we're honest first and kind second. Kindness matters. But the kindest thing you can do for a piece of writing is to tell the writer the truth about it. \"It's great\" helps nobody. \"This line's alive, and this one's only there to look nice\" helps a lot. Say what worked. Say what didn't. Then, at the end, one piece gets read aloud and burned. Don't ask me why yet. You'll see.",
            twoMinutes: "Take one sentence you wrote lately. Swap its dullest word for an exact one.",
            reading: "The Wonder Compass, Chapter 9: West = Write"
        ),
        AcademyLessonModule(
            id: "inkwright-inklings-002",
            sessionID: "inkwright-society",
            title: "The Inklings Read Aloud",
            realSubject: "reading work aloud to honest friends",
            concept: "Tolkien read The Lord of the Rings aloud to his friends as he wrote it, and they didn't always like it. Honest listeners make writing better.",
            lectureBeats: [
                "The Inklings, including Tolkien and C. S. Lewis, read their work aloud to each other most weeks.",
                "Not everybody liked everything, and they said so.",
                "Honest listeners don't stop you writing. They help it grow."
            ],
            demonstration: "Finn read the Society the first page of a story he'd been working on for a year. Somebody said the dragon was boring. Finn went red. Then he crossed the dragon out, put in a very small, very angry goose instead, and everybody leaned in.",
            interactionPrompt: "Who would you read your writing to, if you knew they'd be honest?",
            realWorldPractice: "Read one thing you've written out loud to somebody this week, and ask them for one honest thing.",
            number: 2,
            mode: "A true story",
            lecture: "In Oxford, in the 1930s and 40s, a group of friends met most weeks to read their work out loud to each other. They called themselves the Inklings. Two of them were J. R. R. Tolkien and C. S. Lewis. Tolkien read them chapters of The Lord of the Rings while he was writing it. They didn't always like it. One of them famously complained about the number of elves. Tolkien kept going. Honest listeners don't stop you writing. They make what you write better. And a room that complains about elves is a room that's paying attention.",
            twoMinutes: "Write the first two lines of something. Read them out loud. Write the one honest thing you'd say if somebody else had written them.",
            reading: "Humphrey Carpenter, The Inklings (1978)",
            practice: inkwrightPractice(
                "inklings", title: "Read It to the Room",
                invitation: "The Inkwrights read aloud. Write what you read, who heard it, and the one honest thing they said.",
                action: "Offer it to the circle",
                [
                 ("read", "What you read", "Your own writing"),
                 ("heard", "Who heard it", "A friend, a group, the dog"),
                 ("honest", "The honest thing", "What they said")
                ]
            )
        ),
        AcademyLessonModule(
            id: "inkwright-effect-003",
            sessionID: "inkwright-society",
            title: "Say What It Did to You",
            realSubject: "telling a writer what their work did to you before suggesting fixes",
            concept: "Before you tell a writer how to fix their work, tell them what it did to you: where you laughed, where you got lost, where you got bored.",
            lectureBeats: [
                "A writer can't know what happened inside you while you listened.",
                "Say where you laughed, got lost or got bored, before suggesting fixes.",
                "Writers usually find the fix themselves once they know."
            ],
            demonstration: "Professor Thorne made a rule for one meeting: nobody could suggest a single change. They could only say what had happened to them while they listened. Finn said it was the most useful meeting they'd ever had, and also the most terrifying.",
            interactionPrompt: "Think of something you read recently. Where did you get bored, and where did you lean in?",
            realWorldPractice: "Next time somebody shows you something they've made, tell them one place you leaned in and one place you drifted, before anything else.",
            number: 3,
            mode: "Showing how",
            lecture: "When somebody reads you their work, don't tell them how to fix it. Not yet. First tell them what it did to you. \"I laughed here.\" \"I got lost here.\" \"I was bored from here to here.\" \"This line made the back of my neck go cold.\" That's something nobody else can give them. Only you know what happened inside you while you listened. Once they know that, they can usually work out the fix themselves. And they'll like it better, because it's theirs.",
            twoMinutes: "Think of a film, book or song from this week. Write where it made you lean in, and where you drifted off.",
            reading: "The Wonder Compass, Chapter 9: West = Write",
            practice: inkwrightPractice(
                "effect", title: "What It Did to Me",
                invitation: "Thorne wants effects before fixes. Write whose work it was, where you leaned in, and where you drifted.",
                action: "Offer the note",
                [
                 ("whose", "Whose work", "Theirs, not yours"),
                 ("leaned", "Where you leaned in", "The exact moment"),
                 ("drifted", "Where you drifted", "Be honest, and kind")
                ]
            )
        ),
        AcademyLessonModule(
            id: "inkwright-darlings-004",
            sessionID: "inkwright-society",
            title: "Murder Your Darlings",
            realSubject: "cutting the line you're proudest of when it's only showing off",
            concept: "The line you're proudest of is often the one that's showing off. Ask whether the piece needs it, or only you do.",
            lectureBeats: [
                "Arthur Quiller-Couch told writers to murder their darlings in 1914.",
                "He meant the clever, showing-off line you love most.",
                "Cut it and see. Usually nobody misses it."
            ],
            demonstration: "Finn read a poem with a line in it he was very proud of, about the moon being a coin in the sky's pocket. Professor Thorne said, \"Read it without that line.\" Finn did. It was better. Finn said he hated that, and wrote the line on a slip of paper to burn at the end.",
            interactionPrompt: "What's the line in your writing you'd hate most to lose?",
            realWorldPractice: "Take something you've written and cut the line you're proudest of. Read it again without it.",
            number: 4,
            mode: "An old rule",
            lecture: "In 1914 a writer called Arthur Quiller-Couch gave a lecture at Cambridge about writing. He said that whenever you write something you think is especially fine, you should murder it. Murder your darlings. He meant the line you're proudest of. The clever one. The one that's showing off. It's often the one that's in the way. Read your piece out loud. Find the line you'd most hate to lose. Ask whether the piece needs it, or whether you do. If it's only you, cut it. Put it in a drawer if you must. You'll be amazed how often nobody misses it, including you.",
            twoMinutes: "Write a sentence with your fanciest word in it. Then write it again without that word. Which is better?",
            reading: "Arthur Quiller-Couch, On the Art of Writing (1916)",
            practice: inkwrightPractice(
                "darlings", title: "Murder a Darling",
                invitation: "Thorne says cut the line you love most. Write the darling, what the piece was like without it, and whether you put it back.",
                action: "Offer it up",
                [
                 ("darling", "The darling", "The line you were proudest of"),
                 ("without", "Without it", "What changed"),
                 ("back", "Did you put it back?", "Be honest")
                ]
            )
        ),
        AcademyLessonModule(
            id: "inkwright-true-005",
            sessionID: "inkwright-society",
            title: "One True Sentence",
            realSubject: "getting started by writing one true sentence",
            concept: "When you can't start, write one true sentence. Not clever, not beautiful, just true. Then write the next.",
            lectureBeats: [
                "Hemingway got himself started by writing one true sentence.",
                "True comes before clever or beautiful.",
                "One true sentence makes the next one easier."
            ],
            demonstration: "Professor Thorne gave the Society ten minutes and told them to write the truest sentence they knew. Most people wrote something big and sad. Finn wrote, \"I still sleep with the landing light on.\" Nobody laughed. Thorne said that was the one.",
            interactionPrompt: "What's one true sentence you could write right now?",
            realWorldPractice: "When you're stuck on anything you're writing this week, stop and write one true sentence. Then carry on from there.",
            number: 5,
            mode: "A writer's trick",
            lecture: "When Ernest Hemingway was young and stuck, in Paris, he used to tell himself that all he had to do was write one true sentence. The truest sentence he knew. Then he'd go on from there. It works. When you can't start, don't try to start the whole thing. Write one sentence that's true. Not clever. Not beautiful. True. Then another. The rest comes after. It's what they teach in the Inkworks, and it's what the Compass Society reads out loud. It's the only trick there is.",
            twoMinutes: "Write the truest sentence you know about today. Not clever. Just true.",
            reading: "Ernest Hemingway, A Moveable Feast (1964)",
            practice: inkwrightPractice(
                "true", title: "One True Sentence",
                invitation: "Thorne's trick for starting: one true sentence. Write it, and then the sentence that came after it.",
                action: "Offer it",
                [
                 ("true", "Your true sentence", "Not clever, just true"),
                 ("next", "The next one", "What came after")
                ]
            )
        ),
        AcademyLessonModule(
            id: "inkwright-bad-first-006",
            sessionID: "inkwright-society",
            title: "Let It Be Bad First",
            realSubject: "writing a rough first draft instead of waiting to be good",
            concept: "Every good piece of writing started as a bad one. Write the first go badly, fast and all the way through. Then fix it.",
            lectureBeats: [
                "Waiting until you can write it well means never starting.",
                "The first go only has to exist.",
                "You can fix anything except a blank page."
            ],
            demonstration: "Professor Thorne set a timer for ten minutes and told the Society to write the worst story they could. They laughed the whole time. When they read them out, three of the worst stories had one really good line in them. Thorne said that was the point.",
            interactionPrompt: "What have you been waiting to write until you could do it well?",
            realWorldPractice: "Write the first go of something this week as fast and badly as you can, all the way to the end. Fix it tomorrow.",
            number: 6,
            mode: "The usual mistake",
            lecture: "The usual mistake is waiting until you can write it well. You can't. Nobody can. Every good piece of writing started out as a bad one. The first go is meant to be rubbish. Its only job is to exist, so there's something to fix. Write it badly, fast, all the way to the end. Don't stop to fix anything. Then put it away for a day. Then fix it. You can't fix a blank page. You can fix anything else.",
            twoMinutes: "Write the worst possible first line of a story. Then see if there's one good word in it.",
            reading: "The Wonder Compass, Chapter 9: West = Write",
            practice: inkwrightPractice(
                "bad-first", title: "The Bad First Go",
                invitation: "Thorne wants it bad first. Write what you started, how long the bad first go took, and the one good bit in it.",
                action: "Offer the draft",
                [
                 ("started", "What you started", "A story, a letter, a poem"),
                 ("long", "How long it took", "Fast is the point"),
                 ("good", "The one good bit", "There's always one")
                ]
            )
        ),
        AcademyLessonModule(
            id: "inkwright-kafka-007",
            sessionID: "inkwright-society",
            title: "Kafka Asked for a Burning",
            realSubject: "letting go of practice writing, and being careful what you burn",
            concept: "Some writing is just for practice, and it's fine to let it go. But be careful: Kafka asked for his work to be burned, and it turned out to be wonderful.",
            lectureBeats: [
                "Kafka asked his friend to burn his work, and his friend didn't.",
                "Letting some writing go makes it easier to keep going.",
                "Writers are often wrong about which of their pieces is worst."
            ],
            demonstration: "At the burning, Finn put the first page of his goose story on the fire. Professor Thorne leaned over and took it back out before it caught, singed at one corner. He handed it back to Finn without a word. Finn kept it.",
            interactionPrompt: "Is there something you've written that you'd like to throw away? Are you sure?",
            realWorldPractice: "Pick one piece of your writing to let go of. Before you do, read it once more and copy out the best line.",
            number: 7,
            mode: "A burning",
            lecture: "Franz Kafka asked his best friend, Max Brod, to burn everything he'd written after he died. Brod didn't. Because he didn't, we have The Trial, and The Castle, and a great deal else. In this society we burn one piece at the end of every meeting. People always ask why. Here's why. Burning one thing lets you keep the rest. It says some writing is for practice, and that's fine. But think hard before you burn the thing you think is worst. Sometimes, like Kafka, you're wrong about which one that is. Keep a copy. Burn the copy.",
            twoMinutes: "Think of something you wrote and threw away, or wanted to. Write the one line from it you'd keep.",
            reading: "Max Brod's postscript to Franz Kafka's The Trial (1925)",
            practice: inkwrightPractice(
                "kafka", title: "Before the Burning",
                invitation: "Thorne says burn the copy, not the only one. Write what you're letting go, the line you saved, and why.",
                action: "Offer it to the fire",
                [
                 ("letting", "What you're letting go", "A draft, a poem, a page"),
                 ("saved", "The line you saved", "The best one in it"),
                 ("why", "Why", "What it's got")
                ]
            )
        ),
        AcademyLessonModule(
            id: "inkwright-great-008",
            sessionID: "inkwright-society",
            title: "Not Just Great",
            realSubject: "giving praise that's exact enough to be useful",
            concept: "Praise only helps when it's exact. Instead of saying \"great\", say exactly what worked and exactly where.",
            lectureBeats: [
                "If everything's great, nobody knows what's working.",
                "Exact praise tells a writer what to keep.",
                "Say what worked, and where."
            ],
            demonstration: "Professor Thorne banned the word \"great\" for a month. The first-year with the very serious notebook went silent for two whole meetings. In the third, he told Finn that one line about a wet dog had made him smell the dog. Finn wrote it on his wrist.",
            interactionPrompt: "Praise one thing somebody made, exactly: what worked, and where.",
            realWorldPractice: "This week, whenever you praise something somebody made, say exactly what worked and where. No \"great\".",
            number: 8,
            mode: "Someone gets it wrong",
            lecture: "One of our first-years tells every person in this room, every single week, that their writing is great. He means it kindly. It's useless. If everything's great, nobody knows what's working. Praise is only worth something when it's exact. \"The bit where the goose bit the vicar made me laugh out loud\" is worth a hundred \"that's great\"s. So for one month, the word \"great\" is banned. Praise all you like. But you have to say exactly what, and exactly where.",
            twoMinutes: "Think of something somebody made that you liked. Write exactly what worked and where, without using the word \"great\".",
            reading: "The Wonder Compass, Chapter 9: West = Write",
            practice: inkwrightPractice(
                "exact", title: "Exact Praise",
                invitation: "Thorne's banned \"great\". Write whose work it was, exactly what worked, and where.",
                action: "Offer the praise",
                [
                 ("whose", "Whose work", "Somebody else's"),
                 ("what", "Exactly what worked", "No \"great\""),
                 ("where", "Where", "The line, the moment")
                ]
            )
        ),
        AcademyLessonModule(
            id: "inkwright-franklin-009",
            sessionID: "inkwright-society",
            title: "Learn by Copying",
            realSubject: "copying out writing you admire to learn how it's built",
            concept: "Copy out a paragraph you love, slowly, by hand. You'll feel how it's built. Then write one of your own the same way.",
            lectureBeats: [
                "Benjamin Franklin taught himself to write by rewriting essays he admired.",
                "Copying by hand lets you feel how good writing is built.",
                "Then you can build your own the same way."
            ],
            demonstration: "Professor Thorne had everyone copy out a paragraph from a book they loved, by hand, without hurrying. Finn chose a page about a storm at sea. Halfway through he said, \"Oh, it's all short sentences when the boat's in trouble,\" and started his own storm on the spot.",
            interactionPrompt: "What paragraph would you most like to copy out by hand?",
            realWorldPractice: "Copy out one paragraph you love, by hand. Then write a paragraph of your own built the same way.",
            number: 9,
            mode: "How Franklin learned",
            lecture: "When Benjamin Franklin was a boy, he wanted to write better. So he found essays he admired and made short notes on each one. Then he put the essays away, waited a few days, and tried to write them again from his notes. Then he compared his version with the real one, and saw exactly where his was worse. Once or twice, he thought his was a little better. You can do the same. Find a paragraph you love. Copy it out by hand, slowly. You'll feel how it's built. Then write one of your own the same way.",
            twoMinutes: "Copy out two sentences you love, slowly. Write one thing you noticed about how they're built.",
            reading: "Benjamin Franklin, Autobiography",
            practice: inkwrightPractice(
                "copy", title: "Copy It Out",
                invitation: "Thorne says copy to learn. Write what you copied, what you noticed about how it's built, and the first line of your own.",
                action: "Offer your own",
                [
                 ("copied", "What you copied", "A paragraph you love"),
                 ("built", "How it's built", "Short sentences, a list, a surprise at the end"),
                 ("yours", "Your own first line", "Built the same way")
                ]
            )
        ),
        AcademyLessonModule(
            id: "inkwright-one-reader-010",
            sessionID: "inkwright-society",
            title: "Write for One Person",
            realSubject: "writing with one particular reader in mind",
            concept: "Write for one particular person. You'll know what to explain, what to leave out, and which jokes they'll get.",
            lectureBeats: [
                "Vonnegut's rule: write to please just one person.",
                "Picturing one reader tells you what to explain and what to skip.",
                "Writing for one person often reaches everybody."
            ],
            demonstration: "Professor Thorne asked each Inkwright to name the one person they were really writing for. Finn said his brother, and then wouldn't read his piece out, because his brother wasn't there. Thorne said that was exactly right, and let him off.",
            interactionPrompt: "Who's the one person you'd most like to write something for?",
            realWorldPractice: "Write something short this week for one particular person, as if they're the only one who'll ever read it.",
            number: 10,
            mode: "A writer's rule",
            lecture: "Kurt Vonnegut had a list of rules for writers. One of them was: write to please just one person. Not everybody. One. Pick somebody. Your sister. Your best friend. A teacher you liked. Write the whole thing for them, as if they're the only one who'll ever read it. You'll know what to explain and what to leave out. You'll know which jokes they'll get. Writing for everybody is writing for nobody. Write for one person, and somehow everybody can feel it.",
            twoMinutes: "Pick one person. Write two sentences about your day just for them, the way you'd tell it to them.",
            reading: "Kurt Vonnegut, Bagombo Snuff Box (1999)",
            practice: inkwrightPractice(
                "one-reader", title: "For One Person",
                invitation: "Thorne wants you writing for one reader. Write who it's for, what you wrote, and what you left out because of them.",
                action: "Offer it, or don't",
                [
                 ("who", "Who it's for", "One person"),
                 ("wrote", "What you wrote", "A letter, a story, a poem"),
                 ("left", "What you left out", "Because they'd already know")
                ]
            )
        ),
        AcademyLessonModule(
            id: "inkwright-half-011",
            sessionID: "inkwright-society",
            title: "Cut It in Half",
            realSubject: "rewriting by cutting until every word earns its place",
            concept: "Take something you've written and cut it to half its length. You'll find out which words were really doing the work.",
            lectureBeats: [
                "Most writing has words in it that aren't doing anything.",
                "Cutting to half makes every sentence earn its place.",
                "You find out which words were really working."
            ],
            demonstration: "Professor Thorne gave the Society a hundred words of somebody's old story and asked them to get it down to fifty. Then twenty-five. The twenty-five-word version was read out at the burning, and somebody asked if they could keep it instead.",
            interactionPrompt: "Which words in your last piece of writing aren't doing anything?",
            realWorldPractice: "Take one thing you've written and cut it to half its length. Read both. Keep whichever is better.",
            number: 11,
            mode: "A game",
            lecture: "Take something you've written. Count the words. Now cut it to half. Every sentence has to earn its place. You'll be surprised what goes. The \"very\"s. The \"I think\"s. The second describing word. The sentence that only repeats the one before. Then cut it in half again, if you dare. Somewhere in there is the version that's all muscle. You might go back to the first half. But you'll know which words were doing the work. It's a game. It's also the whole of rewriting.",
            twoMinutes: "Write one long sentence about today. Then rewrite it in half as many words.",
            reading: "The Wonder Compass, Chapter 9: West = Write",
            practice: inkwrightPractice(
                "half", title: "Cut It in Half",
                invitation: "Thorne's game: cut it to half. Write the long version, the half version, and the best word you cut.",
                action: "Offer the short one",
                [
                 ("long", "The long version", "As you first wrote it"),
                 ("half", "The half version", "Every word earning its place"),
                 ("cut", "The best word you cut", "The one that hurt")
                ]
            )
        ),
        AcademyLessonModule(
            id: "inkwright-burning-012",
            sessionID: "inkwright-society",
            title: "Read, Burn, Keep",
            realSubject: "choosing what to share, what to let go and what to keep working on",
            concept: "At the end of the year, bring three pieces: read one aloud, let one go, and keep the one you're not finished with.",
            lectureBeats: [
                "Choosing what to read, what to let go and what to keep is part of writing.",
                "Letting go of practice pieces makes room for the next ones.",
                "The piece you keep is the one you're not finished with yet."
            ],
            demonstration: "At the last burning of the year, Finn read the goose story aloud, finished at last. He burned his first draft of it. He kept a single page of something new, which he wouldn't let anybody see. Professor Thorne said that was the right way round.",
            interactionPrompt: "If you had to read one piece aloud, burn one and keep one, which would they be?",
            realWorldPractice: "Choose three things you wrote this year. Read one aloud to somebody, let one go, and keep the one you're not finished with.",
            number: 12,
            mode: "The last burning",
            lecture: "Last meeting of the year. Bring three things you've written. Read one aloud. Burn one. Keep one. Choosing is the work. The one you read is the one you're proudest of. The one you burn is the one you've learned from and don't need any more. The one you keep is the one you're not finished with. Watch the smoke go up into the ceiling with everybody else's. It's been doing that for a very long time. Somewhere up there is every practice piece anybody ever wrote in this room. Yours are in good company.",
            twoMinutes: "List three things you wrote this year. Mark one to share, one to let go, and one to keep working on.",
            reading: "The Wonder Compass, Chapter 9: West = Write",
            practice: inkwrightPractice(
                "burning", title: "Read, Burn, Keep",
                invitation: "Thorne's last meeting of the year: three pieces. Write what you read aloud, what you let go, and what you kept.",
                action: "Offer it to the fire",
                [
                 ("read", "What you read aloud", "The one you're proudest of"),
                 ("burned", "What you let go", "The one you learned from"),
                 ("kept", "What you kept", "The one you're not finished with")
                ]
            )
        )
    ]

    private static func jumpersPractice(
        _ id: String, title: String, invitation: String, action: String,
        _ fields: [(id: String, label: String, placeholder: String)]
    ) -> AcademyActivity {
        practice("book-jumpers", "book-jumpers-\(id)", kind: .doorProtocol, title: title, invitation: invitation, action: action, fields)
    }
    /// The Book Jumpers take one book a month off the club's own shelf, and spend half the meeting
    /// agreeing the door, the landing and the way out. In the app the club still picks its book itself.
    static let bookJumpers: [AcademyLessonModule] = [
        AcademyLessonModule(
            id: "book-jumpers-landing-001",
            sessionID: "book-jumpers",
            title: "Choose the Spine, Then Argue About the Door",
            realSubject: "planning a jump together, and agreeing the way out first",
            concept: "Pick one book. Then everybody agrees where the door is, where you'll land and how you'll get out, before the fun starts.",
            lectureBeats: [
                "Pick one book. You can't jump into the whole library.",
                "Being excited isn't a plan for landing.",
                "Everybody needs to agree what counts as the door.",
                "A good way out is boring enough to work when you're scared."
            ],
            demonstration: "Professor Permancer made the club choose one book off a crowded table. Then they argued about three possible doors, until Zara spotted the one with a shadow that led back out.",
            interactionPrompt: "Pick the book first. Then pick the door with the clearest way out, and say why.",
            realWorldPractice: "Before you dive into a story today, say the book, the door, where you'll land, and the way out, in one line.",
            number: 1,
            mode: "The big idea",
            lecture: "First rule of this club: pick one book. You can't jump into the library. Tonight it's Alice's Adventures in Wonderland, and before anybody moves, look at how Alice goes in. She follows a rabbit down a hole without a single thought about how she'll get out. She falls so slowly she has time to take a jar of marmalade off a shelf on the way down. It's empty. That's what a jump with no plan looks like: interesting, and very hard to get home from. So we argue. Which door? Where do we land? What brings us back? Settle those three. Then, and only then, we jump.",
            twoMinutes: "Name a story you'd like to jump into. Write the door, where you'd land, and how you'd get out.",
            reading: "Lewis Carroll, Alice's Adventures in Wonderland (1865)"
        ),
        AcademyLessonModule(
            id: "book-jumpers-dracula-002",
            sessionID: "book-jumpers",
            title: "Don't Invite Him In",
            realSubject: "the rule about doors in Dracula, and shutting a story behind you",
            concept: "In Dracula, a vampire can only come in if somebody invites him. Every door works both ways, so agree before you jump: go through, and shut it behind you.",
            lectureBeats: [
                "In Dracula, Van Helsing says a vampire has to be invited in the first time.",
                "A door you can go through is a door something can come back through.",
                "The whole group agrees how the door gets shut before anybody jumps."
            ],
            demonstration: "The club jumped into Dracula at the chapter where Jonathan Harker first arrives at the castle. Orion wanted to land inside. Zara made them land on the road outside, in the snow, with the door still shut. They watched the castle for ten minutes. Everybody agreed it was much scarier from the road.",
            interactionPrompt: "Which door in this story would you never open? Why?",
            realWorldPractice: "Before you start a scary book or film this month, decide with whoever you're with how you'll shut the door afterwards: lights on, a cup of tea, something funny.",
            number: 2,
            mode: "A rule from the book",
            lecture: "October, so it's Dracula. And Dracula has the best rule about doors of any book on the shelf. Van Helsing says a vampire can't come into a house the first time unless somebody inside invites him in. After that, he can come and go as he likes. Think about that before we jump. Every door in this club works both ways. If we can go in, something can come out. So we agree, all of us, before anybody moves. We open the door, we go through, and we shut it behind us. Nobody invites anybody. Not even if he asks nicely. Especially if he asks nicely.",
            twoMinutes: "Think of a scary story you know. Write down the door in it you'd never open, and how you'd shut it behind you.",
            reading: "Bram Stoker, Dracula (1897)",
            practice: jumpersPractice(
                "dracula", title: "Shut the Door Behind You",
                invitation: "The club's jumping into Dracula. Settle the door, where you'll land, and how you'll shut it behind you.",
                action: "Put it to the group",
                [
                 ("door", "The door", "The scene you'd step through"),
                 ("landing", "Where you land", "Somewhere outside, with the door still shut"),
                 ("return", "How you shut it", "What gets everyone safely back out")
                ]
            )
        ),
        AcademyLessonModule(
            id: "book-jumpers-frankenstein-003",
            sessionID: "book-jumpers",
            title: "Whose Side Are You On?",
            realSubject: "choosing whose eyes you see a story through",
            concept: "In Frankenstein, the creature tells his own side, and suddenly you're with him. Before you jump into a story, choose whose eyes you'll see it through.",
            lectureBeats: [
                "Mary Shelley wrote Frankenstein at eighteen, for a ghost-story competition.",
                "In the middle of the book, the creature tells his own story.",
                "Choosing whose eyes you see a story through changes the whole story."
            ],
            demonstration: "Half the club went in as Victor and half as the creature, landing in the same snowy mountain scene. Afterwards, Orion, who'd been Victor, said he'd felt sorry for the creature the whole time. Zara, who'd been the creature, said she still didn't trust Victor. Permancer said they'd both done it properly.",
            interactionPrompt: "In the story you know best, whose side would you tell it from?",
            realWorldPractice: "In the next story you read or watch, pick the character you'd normally ignore, and watch the whole thing from their side.",
            number: 3,
            mode: "Pick who you'll be",
            lecture: "Frankenstein started as a ghost-story competition. In 1816 a group of friends were stuck indoors by bad weather in a house by Lake Geneva, and the poet Lord Byron said they should each write a ghost story. Mary Shelley was eighteen. She wrote Frankenstein. And here's the thing about it. In the middle of the book, the creature tells his own story, and suddenly you're on his side. So tonight, before we jump, everybody decides who they'll be. Victor or the creature. You can't be both. Afterwards we compare notes, and see whether anybody changed sides.",
            twoMinutes: "Think of a story you know well. Write two sentences of it from the side of a character who isn't the hero.",
            reading: "Mary Shelley, Frankenstein (1818)",
            practice: jumpersPractice(
                "frankenstein", title: "Whose Side",
                invitation: "The club's jumping into Frankenstein. Choose whose eyes you'll see it through, where you land, and how you'll get back.",
                action: "Put it to the group",
                [
                 ("door", "Whose eyes", "Victor, the creature, somebody else"),
                 ("landing", "Where you land", "The scene you'd step into"),
                 ("return", "What gets you out", "The way back")
                ]
            )
        ),
        AcademyLessonModule(
            id: "book-jumpers-carol-004",
            sessionID: "book-jumpers",
            title: "Three Doors, One Night",
            realSubject: "making several short trips from one safe place",
            concept: "In A Christmas Carol, Scrooge makes three trips in one night and always comes back to his own bed. Make short trips, with one safe place to come back to.",
            lectureBeats: [
                "Scrooge is taken out three times, into the past, the present and what's still to come.",
                "Every time, he comes back to the same bed.",
                "Short trips from one safe spot make a well-built jump."
            ],
            demonstration: "The club jumped three times in one evening: into Fezziwig's party, into the Cratchits' kitchen, and into the churchyard at the end. Each time they came back to the same rug in the Vault of Doors. After the churchyard, nobody wanted to go again, so Permancer made cocoa instead.",
            interactionPrompt: "If you could visit your own past, present and future for one minute each, where would you go?",
            realWorldPractice: "Make three short visits this month to one story, each to a different scene, and come back to the same chair every time.",
            number: 4,
            mode: "A winter jump",
            lecture: "December, so it's A Christmas Carol, and it's the only book on the shelf with three doors in one night. Scrooge is taken out of his bedroom three times, by three ghosts: into the past, into the present, into what's still to come. And every time, he's brought back to his own bed. That's a properly built jump. Three trips, one place to come back to, the same bed every time. Tonight we copy it. Three short jumps into three different scenes. Same landing spot each time we come back: right here, on this rug. Nobody leaves the rug without saying where they're going.",
            twoMinutes: "Write one sentence about a moment from your past, one about right now, and one about a moment you hope is coming.",
            reading: "Charles Dickens, A Christmas Carol (1843)",
            practice: jumpersPractice(
                "carol", title: "Three Doors",
                invitation: "The club's jumping into A Christmas Carol: three scenes, one place to come back to. Write the three scenes and your spot.",
                action: "Put it to the group",
                [
                 ("door", "Three scenes", "Past, present, still to come"),
                 ("landing", "Where you land each time", "The same place every time"),
                 ("return", "What brings you back", "The rug, the bed, the chair")
                ]
            )
        ),
        AcademyLessonModule(
            id: "book-jumpers-watson-005",
            sessionID: "book-jumpers",
            title: "Land as Watson",
            realSubject: "noticing like the person who tells the story",
            concept: "Holmes told Watson that he saw but didn't observe. Land in a story as the one who notices, and count the steps.",
            lectureBeats: [
                "Watson had climbed the stairs hundreds of times without counting them.",
                "Holmes said, \"You see, but you do not observe.\"",
                "The one who tells the story is often the one who notices the people."
            ],
            demonstration: "The club landed in Baker Street, and Permancer asked them to count the steps on the way up. They got seventeen. Then Zara asked what Mrs Hudson had for breakfast, and nobody, including Holmes, had any idea.",
            interactionPrompt: "How many steps are there up to your front door?",
            realWorldPractice: "Count something you pass every day but have never counted: steps, windows, lamp posts. Write down the number.",
            number: 5,
            mode: "A detective's rule",
            lecture: "January's for Sherlock Holmes. In one of the first stories, Holmes asks Dr Watson how many steps there are up to their rooms. Watson has climbed them hundreds of times, and he's got no idea. Seventeen, says Holmes. \"You see, but you do not observe.\" So tonight we land as Watson. Not as Holmes. Watson's the one who tells the stories, because he's the one who notices the people, not just the clues. Land in Baker Street. Count the steps. Then tell me one thing about the room that Holmes would never bother to notice.",
            twoMinutes: "Without getting up, guess how many steps or stairs there are in your home. Then go and count them.",
            reading: "Arthur Conan Doyle, \"A Scandal in Bohemia\" (1891)",
            practice: jumpersPractice(
                "watson", title: "Count the Steps",
                invitation: "The club's landing in Baker Street as Watson. Write what you counted, the number, and one thing about the room Holmes would ignore.",
                action: "Put it to the group",
                [
                 ("door", "What you counted", "Steps, windows, cups"),
                 ("landing", "The number", "Exactly"),
                 ("return", "What Holmes would ignore", "Something about the people")
                ]
            )
        ),
        AcademyLessonModule(
            id: "book-jumpers-austen-006",
            sessionID: "book-jumpers",
            title: "First Impressions",
            realSubject: "testing your first impression of people, in stories and in life",
            concept: "Austen first called her book First Impressions. Land at the dance, judge everybody in ten seconds, then stay long enough to find out you were wrong.",
            lectureBeats: [
                "Pride and Prejudice was first called First Impressions.",
                "Elizabeth decides about Darcy straight away, and she's wrong.",
                "Write down your first impression, then stay long enough to test it."
            ],
            demonstration: "The club landed at the Meryton dance and wrote down one first impression each. By the end of the evening, half of them had crossed theirs out. Orion's had said \"Mr Collins seems nice\". He crossed it out three times.",
            interactionPrompt: "Who did you get wrong at first, in a story or in life?",
            realWorldPractice: "Notice your first impression of somebody new this month. Write it down. Check it again a week later.",
            number: 6,
            mode: "Watch your first impression",
            lecture: "Jane Austen first called Pride and Prejudice \"First Impressions\", and that's what the whole book's about. Elizabeth Bennet meets Mr Darcy at a dance, decides he's horrible, and spends most of the book finding out she was wrong. Tonight we jump into that dance. Land by the wall, with a glass of something. Make up your mind about everybody in ten seconds. Write it down. Then stay for the whole evening, and see how many you'd change. It's the best lesson on the shelf about not trusting your first look.",
            twoMinutes: "Think of somebody you misjudged at first. Write your first impression, and what you think now.",
            reading: "Jane Austen, Pride and Prejudice (1813)",
            practice: jumpersPractice(
                "austen", title: "First Impressions",
                invitation: "The club's at the dance in Pride and Prejudice. Write who you judged, your first impression, and what you thought by the end.",
                action: "Put it to the group",
                [
                 ("door", "Who you judged", "In the story, or in your life"),
                 ("landing", "First impression", "Ten seconds' worth"),
                 ("return", "By the end", "What you think now")
                ]
            )
        ),
        AcademyLessonModule(
            id: "book-jumpers-garden-007",
            sessionID: "book-jumpers",
            title: "The Key in the Earth",
            realSubject: "finding a door that's been there all along",
            concept: "In The Secret Garden, a robin shows Mary a key buried in the earth, and a locked garden comes back to life. Look for the door in your own life that's been there all along.",
            lectureBeats: [
                "Mary finds a garden that's been locked up for ten years.",
                "A robin shows her where the key is buried.",
                "The best doors are already there, waiting to be noticed."
            ],
            demonstration: "The club landed by the ivy-covered wall and spent ten minutes looking for the door. Zara found it first, behind the ivy, exactly where the book says. Permancer made them wait outside without going in until a robin landed on the wall. It took a while. It was worth it.",
            interactionPrompt: "What's a door in your own life that's been there all along?",
            realWorldPractice: "Look for one secret garden near you this month: a path, a gate or a corner you've never gone through. Go through it.",
            number: 7,
            mode: "A spring jump",
            lecture: "March, so it's The Secret Garden. Mary Lennox is sent to a big gloomy house where nobody talks to her, and she finds out about a garden that's been locked up for ten years. A robin shows her where the key's buried. She digs it up. She goes in, and the garden that looked dead is only sleeping. It's the best door on the whole shelf, because nobody made it. It was already there, waiting for somebody to notice. Tonight we land by the wall, by the ivy, and look for the door. Then, in the real world, you go and look for yours.",
            twoMinutes: "Think of a place near you that you've walked past but never gone into. Write where it is, and what you think is behind it.",
            reading: "Frances Hodgson Burnett, The Secret Garden (1911)",
            practice: jumpersPractice(
                "garden", title: "Find the Door",
                invitation: "The club's jumping into The Secret Garden. Write the door you'd look for, where you'd land, and the real one near you.",
                action: "Put it to the group",
                [
                 ("door", "The door in the book", "Behind the ivy"),
                 ("landing", "Where you land", "By the wall"),
                 ("return", "Your real secret garden", "A gate or a path near you")
                ]
            )
        ),
        AcademyLessonModule(
            id: "book-jumpers-quixote-008",
            sessionID: "book-jumpers",
            title: "Giant or Windmill?",
            realSubject: "coming back from a story and seeing what's really there",
            concept: "Don Quixote loved stories so much he fought windmills he thought were giants. When you come back from a story, check: giant, or windmill?",
            lectureBeats: [
                "Don Quixote read so much about knights that he thought he was one.",
                "He mistook windmills for giants.",
                "When you come back from a story, check what's real before you charge."
            ],
            demonstration: "The club jumped into the windmill chapter and watched from a hill. Orion very nearly ran down to help. Zara held on to his sleeve. Afterwards he said he knew they were windmills, really, but they did look a lot like giants. Permancer wrote that down as the most honest thing anybody had said all term.",
            interactionPrompt: "Has a story ever made you see something ordinary as something it wasn't?",
            realWorldPractice: "After your next long story, before you do anything else, name three ordinary things around you, out loud. Windmills, not giants.",
            number: 8,
            mode: "Someone gets it wrong",
            lecture: "Don Quixote read so many books about knights that he couldn't tell them apart from real life any more. He put on his great-grandfather's old armour, called himself a knight, and rode out to fight giants. The giants were windmills. It's very funny, and very sad. He jumped in and never properly came back. Orion, I'm looking at you, because of the pirate week. Here's the lesson. Love a story as much as you like. But when you come back, check. Is it a giant, or a windmill? If you can't tell, you haven't landed yet.",
            twoMinutes: "Look at the nearest ordinary object. Write what it would be if it were in a story. Then write what it really is.",
            reading: "Miguel de Cervantes, Don Quixote (1605)",
            practice: jumpersPractice(
                "quixote", title: "Giant or Windmill?",
                invitation: "The club's watching Don Quixote from the hill. Write what he thinks it is, what it really is, and how you'll check when you come back from a story.",
                action: "Put it to the group",
                [
                 ("door", "What he thinks it is", "A giant"),
                 ("landing", "What it really is", "A windmill"),
                 ("return", "How you'll check", "When you come back from a story")
                ]
            )
        ),
        AcademyLessonModule(
            id: "book-jumpers-oz-009",
            sessionID: "book-jumpers",
            title: "The Way Home Was on Your Feet",
            realSubject: "keeping your way home close before you go anywhere",
            concept: "Dorothy's silver shoes could have taken her home all along. Before any jump, know where your way home is, and keep it close.",
            lectureBeats: [
                "Dorothy spends the whole book trying to get home.",
                "Her silver shoes could have taken her home all along.",
                "Keep your way home close, like something you're already wearing."
            ],
            demonstration: "Permancer made every club member choose a pair of silver shoes before the jump: something they'd be wearing or carrying that meant home. Zara picked her house key. Orion picked his left sock, which nobody understood, and he wouldn't explain.",
            interactionPrompt: "What are your silver shoes: the thing that always brings you home?",
            realWorldPractice: "Pick your own silver shoes: one thing you always carry that reminds you of home. Keep it with you this month.",
            number: 9,
            mode: "The way home",
            lecture: "In The Wonderful Wizard of Oz, Dorothy spends the whole book trying to get home to Kansas. She walks the yellow brick road. She meets the Wizard. She fights the witch. And right at the end, she finds out she could have gone home any time. The silver shoes on her feet could take her. In the book they're silver, by the way, not red. She only had to knock her heels together three times. Before every jump, I want you to know where your silver shoes are. The way home should be something you're already wearing.",
            twoMinutes: "Write down one thing you carry or wear every day that could be your silver shoes. Why that?",
            reading: "L. Frank Baum, The Wonderful Wizard of Oz (1900)",
            practice: jumpersPractice(
                "oz", title: "Your Silver Shoes",
                invitation: "The club's jumping into Oz. Write your silver shoes, where you'd land, and how you'll knock your heels together to come home.",
                action: "Put it to the group",
                [
                 ("door", "Your silver shoes", "Something you always carry"),
                 ("landing", "Where you'd land", "Somewhere on the yellow brick road"),
                 ("return", "Heels together", "How you'll come home")
                ]
            )
        ),
        AcademyLessonModule(
            id: "book-jumpers-island-010",
            sessionID: "book-jumpers",
            title: "X Marks the Spot",
            realSubject: "drawing a map and letting it become a story",
            concept: "Treasure Island started with a map drawn on a rainy holiday. Draw a map, mark the landing, the treasure and the way back, and you've made a door.",
            lectureBeats: [
                "Stevenson drew a map of an island first, then wrote the story.",
                "A map with a landing, a treasure and a way back is a story waiting to happen.",
                "You can draw a map of a real place, or a made-up one."
            ],
            demonstration: "Permancer handed out paper and made the club draw a treasure map of the Academy grounds. Everybody's X was somewhere different. Zara's was under the old oak. She wouldn't say what was there, and the next day the soil under the oak looked freshly dug.",
            interactionPrompt: "If you drew a treasure map of where you live, where would the X be?",
            realWorldPractice: "Draw a treasure map of somewhere near you. Mark where you'd land, the treasure, and the way back. Then go to the X.",
            number: 10,
            mode: "Start with a map",
            lecture: "Treasure Island started with a map. Robert Louis Stevenson was stuck indoors on a rainy holiday in Scotland, and he drew a map of an island with his stepson. Then he made up the story to go with it. That's a door you can build yourself. Draw a map of somewhere. A real place, or one you've made up. Mark where you'd land. Mark the treasure. Mark the way back to the boat. Every map is a story waiting to be told. Summer's a good time to go and find out what's at the X.",
            twoMinutes: "Draw a quick map of the room you're in. Put an X on the most interesting spot. Write what's there.",
            reading: "Robert Louis Stevenson, Treasure Island (1883)",
            practice: jumpersPractice(
                "island", title: "Draw the Map",
                invitation: "The club's jumping into Treasure Island. Draw your own map. Write where you landed, what the X was, and the way back to the boat.",
                action: "Put it to the group",
                [
                 ("door", "Where you landed", "The beach, the gate, the door"),
                 ("landing", "What the X was", "Real or made up"),
                 ("return", "The way back", "To the boat")
                ]
            )
        ),
        AcademyLessonModule(
            id: "book-jumpers-whale-011",
            sessionID: "book-jumpers",
            title: "Too Big to Jump Whole",
            realSubject: "visiting a huge book one chapter at a time",
            concept: "Moby-Dick is too big to jump into whole. Pick one chapter, stand on the deck, and come back. You don't have to finish a book to have been inside it.",
            lectureBeats: [
                "Moby-Dick has more than a hundred and thirty chapters.",
                "A huge book can be visited one chapter at a time.",
                "Standing on the deck once still counts."
            ],
            demonstration: "The club jumped into the chapter where the crew first sees the whale. Orion wanted to stay for the whole voyage. Permancer reminded him about the pirate week. Orion came back after one chapter, wet to the knees, and said he could smell the sea for the rest of the day.",
            interactionPrompt: "Which big book have you never finished? Which chapter would you visit?",
            realWorldPractice: "Pick one chapter of a huge book you've never read, and read only that chapter. Notice what it's like to be there.",
            number: 11,
            mode: "Jump into one chapter",
            lecture: "Moby-Dick starts with one of the most famous lines ever written: Call me Ishmael. Then it goes on for more than a hundred and thirty chapters, one of them all about rope. It's an enormous book. You can't jump into the whole thing. Nobody can. So we pick one chapter. One. We land on the deck, we stay for that chapter, and we come back. You don't have to finish a great big book to have been inside it. You just have to have stood on the deck once, and smelled the sea.",
            twoMinutes: "Pick up the biggest book you can reach. Open it anywhere. Read one paragraph. Write one thing you'd see if you were standing there.",
            reading: "Herman Melville, Moby-Dick (1851)",
            practice: jumpersPractice(
                "whale", title: "One Chapter",
                invitation: "The club's standing on the deck of the Pequod for one chapter. Write which chapter, what you saw, and what you smelled.",
                action: "Put it to the group",
                [
                 ("door", "The chapter", "Just one"),
                 ("landing", "What you saw", "From the deck"),
                 ("return", "What you smelled", "The sea, the rope, the rain")
                ]
            )
        ),
        AcademyLessonModule(
            id: "book-jumpers-home-012",
            sessionID: "book-jumpers",
            title: "The Long Way Home",
            realSubject: "coming home at the end of a year of stories, and noticing what's changed",
            concept: "Odysseus took ten years to get home, and came back so changed that only his old dog knew him. At the end of a year of stories, come home and notice what's changed.",
            lectureBeats: [
                "Odysseus spent ten years trying to get home after the war.",
                "When he got back, hardly anybody recognised him, except his dog.",
                "A year of stories changes you too. Notice how."
            ],
            demonstration: "The club landed on the beach at Ithaca for the last jump of the year. Nobody spoke. Then they came back to the Vault of Doors, and Permancer made each of them say one way they'd changed since September. Zara said she'd stopped holding the exit door quite so tightly. Orion said he now owned a sock with a story.",
            interactionPrompt: "How have you changed since the start of the year?",
            realWorldPractice: "At the end of this year of stories, write down one way you've changed, and one story that helped.",
            number: 12,
            mode: "Coming home",
            lecture: "Last jump of the year, so it's the oldest book on the shelf. The Odyssey. Odysseus spends ten years at war, and then another ten trying to get home. Monsters. Storms. Islands that want to keep him. And when he finally gets back to Ithaca, he's so changed that hardly anybody recognises him. His old dog does, though. That's what a year of jumping is like. You go into a lot of stories, and when you come home, you're a bit different. Tonight we jump in at the very end, when he gets home. Then we come home too. Look round. What's changed?",
            twoMinutes: "Write one way you're different from a year ago. Then write the story, book or film that had something to do with it.",
            reading: "Homer, The Odyssey",
            practice: jumpersPractice(
                "home", title: "Coming Home",
                invitation: "The club's last jump of the year is to Ithaca. Write where you landed, who recognised you, and what's changed in you since September.",
                action: "Put it to the group",
                [
                 ("door", "Where you landed", "The beach at Ithaca"),
                 ("landing", "Who recognised you", "Even if it was only the dog"),
                 ("return", "What's changed", "In you, since September")
                ]
            )
        )
    ]
}
