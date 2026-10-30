import Foundation

/// The Kitchen's recipes, set down by hand.
///
/// The Cookery and custom recipes use published sources; Gayle O'Brien's use
/// her typed binder. Quantities are never adjusted for prose. Her wording and
/// notes stay intact, including informal measures. Allergen metadata and any
/// explicitly labeled Kitchen note are editorial, outside her transcription.
enum KitchenRecipeRegistry {
    static let gayle = "Gayle O'Brien, Mom"
    static let cookery = "The Middlemost Cookery"

    /// Recipes a monthly pack posted (`PageArchetypePack.recipes`).
    nonisolated(unsafe) static var delivered: [KitchenRecipe] = []

    static var all: [KitchenRecipe] {
        let bundledIDs = Set(bundled.map(\.id))
        return bundled + delivered.filter { !bundledIDs.contains($0.id) }
    }

    static func recipe(id: String) -> KitchenRecipe? { all.first { $0.id == id } }

    static let bundled: [KitchenRecipe] = custom + cookeryShelf + inherited

    // MARK: Customs with a day attached

    static let custom: [KitchenRecipe] = [
        KitchenRecipe(
            id: "soul-cakes",
            title: "Soul Cakes",
            shelf: .custom,
            credit: "All Souls, England and Wales",
            line: "“Forty of these, every All Souls. Cut the cross in every one. Somebody always asks why. Nobody knows. Do it anyway.” — A. T.",
            makes: "about 20",
            minutes: 40,
            ingredients: [
                "175g (¾ cup) butter, soft (milk)",
                "175g (¾ cup) caster or superfine sugar",
                "3 egg yolks (egg)",
                "450g (3½ cups) plain flour (wheat)",
                "1 tsp mixed spice, or ½ tsp nutmeg and ½ tsp cinnamon",
                "100g (⅔ cup) currants",
                "2 to 4 tbsp milk (milk)"
            ],
            allergens: ["milk", "egg", "wheat"],
            steps: [
                "Heat the oven to 190°C (375°F). Line two baking trays.",
                "Beat the butter and sugar together till they're pale and soft.",
                "Beat in the egg yolks one at a time.",
                "Sift in the flour and spice, add the currants, and stir in just enough milk to make a soft dough that holds together.",
                "Roll it out about 1cm (½ inch) thick and cut rounds about 7cm (3 inches) across.",
                "Set them on the trays and cut a cross in the top of each one with the back of a knife.",
                "Bake 15 to 20 minutes, till they're just golden. Cool on a rack."
            ],
            cookNote: "Children used to go door to door on All Souls singing for these, a cake for every soul. The rhyme is real. So is the cross.",
            window: KitchenWindow(startMonth: 10, startDay: 30, endMonth: 11, endDay: 2),
            smellAsk: "What did the kitchen smell like with these in the oven?",
            tags: ["all-souls", "baking", "the-guest"]
        ),
        KitchenRecipe(
            id: "parkin",
            title: "Parkin",
            shelf: .custom,
            credit: "Bonfire Night, Yorkshire",
            line: "“Make it now and leave it alone. It wants three days in a tin before it's any good. Most things do.” — A. T.",
            makes: "16 squares",
            minutes: 75,
            ingredients: [
                "200g (¾ cup + 2 tbsp) butter (milk)",
                "85g (⅓ cup + 1 tbsp) light brown sugar",
                "85g (¼ cup) black treacle, or molasses",
                "200g (⅔ cup) golden syrup, or light corn syrup",
                "100g (¾ cup) medium oatmeal, or quick oats (oats)",
                "250g (2 cups) self-raising flour (wheat)",
                "4 tsp ground ginger",
                "2 eggs, beaten (egg)",
                "1 tbsp milk (milk)"
            ],
            allergens: ["milk", "egg", "wheat", "oats"],
            steps: [
                "Heat the oven to 160°C (325°F). Grease and line a 22cm (9 inch) square tin.",
                "Melt the butter, sugar, treacle and syrup together over a low heat. Don't let it boil.",
                "Mix the oatmeal, flour and ginger in a big bowl.",
                "Pour in the melted mixture and stir, then beat in the eggs and the milk.",
                "Pour it into the tin and bake 50 minutes to an hour, till it's firm in the middle and a bit crusty on top.",
                "Cool it in the tin. Then wrap it up and put it away for at least three days before you cut it. It goes dark and sticky while it waits."
            ],
            cookNote: "Without self-raising flour: 250g plain flour and 2 tsp baking powder.",
            window: KitchenWindow(startMonth: 11, startDay: 1, endMonth: 11, endDay: 3),
            tags: ["bonfire-night", "baking", "the-guest"]
        ),
        KitchenRecipe(
            id: "bonfire-toffee",
            title: "Bonfire Toffee",
            shelf: .custom,
            credit: "Bonfire Night",
            line: "“Hot sugar is the worst burn in a kitchen. Grown-ups only, nobody leaves the pan, and the little hammer's the best part.” — A. T.",
            makes: "a 20cm slab",
            minutes: 40,
            ingredients: [
                "450g (2¼ cups) demerara or dark brown sugar",
                "150ml (⅔ cup) water",
                "¼ tsp cream of tartar",
                "115g (⅓ cup) black treacle, or molasses",
                "115g (⅓ cup) golden syrup, or light corn syrup",
                "25g (2 tbsp) butter, plus a little for the tin (milk)"
            ],
            allergens: ["milk"],
            steps: [
                "Butter a 20cm (8 inch) square tin well. You'll need a sugar thermometer.",
                "Put the sugar and water in a big, heavy pan over a low heat and stir till the sugar's completely dissolved.",
                "Add the cream of tartar, treacle, syrup and butter. Turn the heat up and let it boil, without stirring, till the thermometer says 150°C (300°F). That's hard crack. It takes a while. Don't walk away.",
                "Pour it carefully into the tin. It's hotter than anything else in your kitchen.",
                "When it's half set, mark it into squares with an oiled knife. When it's completely cold, break it up with a toffee hammer or the end of a rolling pin."
            ],
            cookNote: "Keep it in a tin with baking paper between the layers, or it all sticks back together.",
            window: KitchenWindow(startMonth: 11, startDay: 4, endMonth: 11, endDay: 5),
            smellAsk: "What did the burnt sugar smell like? Bonfire, or something else?",
            tags: ["bonfire-night", "sweets", "the-guest"]
        ),
        KitchenRecipe(
            id: "colcannon",
            title: "Colcannon",
            shelf: .custom,
            credit: "Halloween, Ireland",
            line: "“Potatoes, cabbage, a hole in the middle for the butter. It's the hole that matters.” — A. T.",
            makes: "4 plates",
            minutes: 35,
            ingredients: [
                "1kg (2¼ lb) floury potatoes, peeled and cut up",
                "250g (½ lb) cabbage or kale, shredded",
                "4 spring onions (scallions), sliced",
                "150ml (⅔ cup) milk (milk)",
                "50g (4 tbsp) butter, and more for the top (milk)",
                "salt and pepper"
            ],
            allergens: ["milk"],
            steps: [
                "Boil the potatoes in salted water till they're soft, 15 to 20 minutes. Drain them well.",
                "While they cook, cook the cabbage in a splash of water and a little of the butter for about 5 minutes, till it's just soft.",
                "Warm the milk with the spring onions in a small pan.",
                "Mash the potatoes with the butter and the hot milk, then fold the cabbage through. Season it well.",
                "Pile it on plates, push a hole in the middle of each with a spoon, and put a lump of butter in the hole to melt."
            ],
            cookNote: "In Ireland a ring or a coin used to be hidden in the Halloween colcannon. Whoever found it was in for a year of luck, or marriage. That's the folklore. Don't hide anything in yours that somebody could swallow.",
            months: [10, 11, 12, 1, 2],
            weatherTags: ["cold", "rain", "frost"],
            tags: ["potato", "supper"]
        ),
        KitchenRecipe(
            id: "christmas-pudding",
            title: "Stir-up Pudding",
            shelf: .custom,
            credit: "Stir-up Sunday",
            line: "“Everybody in the house stirs it once, east to west, eyes shut, and makes a wish. You don't say the wish. You don't skip anybody.” — A. T.",
            makes: "one 1.2 litre pudding, for 8",
            minutes: 420,
            ingredients: [
                "100g (¾ cup) self-raising flour (wheat)",
                "100g (2 cups) fresh white breadcrumbs (wheat)",
                "100g (¾ cup) shredded suet, beef or vegetable",
                "100g (½ cup) dark brown sugar",
                "1 tsp mixed spice",
                "450g (3 cups) mixed dried fruit (sulphites)",
                "grated zest of 1 orange",
                "2 eggs (egg)",
                "150ml (⅔ cup) stout (gluten), or milk (milk if you use it)",
                "2 tbsp brandy, if you like (sulphites)",
                "butter for the basin (milk)"
            ],
            allergens: ["wheat", "gluten", "egg", "milk", "sulphites"],
            steps: [
                "Butter a 1.2 litre (2½ pint) pudding basin.",
                "Mix the flour, breadcrumbs, suet, sugar, spice, dried fruit and orange zest in a big bowl.",
                "Beat the eggs with the stout and the brandy and stir them in.",
                "Now everybody stirs: once each, east to west, eyes shut, with a wish.",
                "Spoon it into the basin and press it down. Cover it with a pleated sheet of baking paper and a sheet of foil, and tie them on tight with string under the rim.",
                "Stand it on an upturned saucer in a big pan, pour in boiling water to come halfway up the basin, put the lid on and keep it at a gentle simmer for 6 hours. Top up with boiling water as it goes. Never let it boil dry.",
                "Let it cool, put on fresh paper and foil, and keep it somewhere cool and dark till Christmas.",
                "On the day, steam it again for 2 hours the same way, and turn it out."
            ],
            cookNote: "Stir-up Sunday is the last Sunday before Advent. The name comes from the prayer read in church that morning, which starts “Stir up, we beseech thee.” Everybody heard it as a reminder about the pudding.",
            window: KitchenWindow(startMonth: 11, startDay: 20, endMonth: 11, endDay: 22),
            smellAsk: "What did you wish? You don't have to say. Write what the bowl smelled like instead.",
            tags: ["stir-up-sunday", "christmas", "the-guest"]
        ),
    ]

    // MARK: The Middlemost Cookery

    static let cookeryShelf: [KitchenRecipe] = [
        KitchenRecipe(
            id: "soda-bread",
            title: "Soda Bread",
            shelf: .cookery,
            credit: cookery,
            line: "“No yeast, no waiting, no kneading. Mix it fast and get it in the oven. It's bread for people who need bread tonight.” — A. T.",
            makes: "one round loaf",
            minutes: 50,
            ingredients: [
                "500g (4 cups) plain flour, or half plain and half wholemeal (wheat)",
                "1 tsp bicarbonate of soda (baking soda)",
                "1 tsp salt",
                "400ml (1⅔ cups) buttermilk (milk)"
            ],
            allergens: ["wheat", "milk"],
            steps: [
                "Heat the oven to 200°C (400°F). Dust a baking tray with flour.",
                "Mix the flour, bicarbonate of soda and salt in a big bowl and make a well in the middle.",
                "Pour in most of the buttermilk and mix it quickly with your hand or a knife into a soft, slightly sticky dough. Add the rest if it's dry.",
                "Tip it out, shape it into a round with as little handling as you can, and set it on the tray.",
                "Cut a deep cross in the top, right to the edges.",
                "Bake 30 to 35 minutes, till it sounds hollow when you knock on the bottom."
            ],
            cookNote: "No buttermilk: stir 1 tbsp lemon juice into 400ml milk and leave it 10 minutes. The cross is to let the fairies out. That's what they say in Ireland, anyway.",
            tags: ["bread", "the-guest"]
        ),
        KitchenRecipe(
            id: "leek-and-potato-soup",
            title: "Leek and Potato Soup",
            shelf: .cookery,
            credit: cookery,
            line: "“Soup's how you say a thing to somebody without saying it. Put it on the warm corner of the range and go to bed.” — A. T.",
            makes: "4 bowls",
            minutes: 45,
            ingredients: [
                "25g (2 tbsp) butter (milk)",
                "2 leeks, sliced and well washed",
                "1 onion, chopped",
                "3 medium potatoes (about 450g, 1 lb), peeled and diced",
                "1 litre (4 cups) vegetable or chicken stock (check the stock for celery)",
                "salt and pepper",
                "a splash of milk or cream, if you like (milk)"
            ],
            allergens: ["milk", "celery"],
            steps: [
                "Melt the butter in a big pan. Add the leeks and onion, put the lid on, and let them go soft over a low heat for about 10 minutes. Don't let them brown.",
                "Add the potatoes and the stock. Bring it to the boil, then simmer for about 20 minutes, till the potatoes are soft.",
                "Blend it smooth, or mash half of it and leave the rest in pieces.",
                "Season it, stir in the milk or cream if you're using it, and heat it through."
            ],
            cookNote: "It's better the next night. Soup's been thinking.",
            months: [9, 10, 11, 12, 1, 2, 3],
            weatherTags: ["cold", "rain", "frost", "snow", "wind"],
            tags: ["soup", "the-guest"]
        ),
        KitchenRecipe(
            id: "stone-soup",
            title: "Stone Soup",
            shelf: .cookery,
            credit: cookery,
            line: "“A con, and the best recipe in the book. You start with nothing and a stone and you end up feeding the street.” — A. T.",
            makes: "as many bowls as people bring things",
            minutes: 60,
            ingredients: [
                "one clean, smooth stone, scrubbed and boiled first (it's for the story; you can leave it out)",
                "2 litres (8 cups) water or stock (check the stock for celery)",
                "an onion, chopped",
                "whatever everybody brings: a carrot, a potato, a handful of cabbage, a stick of celery, a handful of barley or lentils (barley: gluten)",
                "salt and pepper"
            ],
            allergens: ["celery", "gluten"],
            steps: [
                "Put the stone in a big pan of water and bring it to a simmer. Tell anybody who asks that you're making stone soup, and that it's very good, though it'd be better with an onion.",
                "Add the onion. Say it'd be better still with a carrot.",
                "Keep going. Everything anybody brings goes in, chopped small, the slow things (barley, potatoes, carrots) first and the quick things (cabbage) last.",
                "Simmer it all for 40 minutes or so, till everything's soft and the barley's cooked.",
                "Season it. Take the stone out before anybody eats. Serve it to everybody who put something in."
            ],
            cookNote: "Nobody knows how old this story is. It turns up all over Europe, with a nail or an axe instead of a stone.",
            months: [10, 11, 12, 1, 2],
            weatherTags: ["cold", "rain"],
            tags: ["soup", "sharing", "the-guest"]
        ),
        KitchenRecipe(
            id: "baked-apples",
            title: "Baked Apples",
            shelf: .cookery,
            credit: cookery,
            line: "Cut an apple across the middle before you core it, and there's a star inside. It's been there all along. Then bake the rest.",
            makes: "4",
            minutes: 50,
            ingredients: [
                "4 big apples, cooking or eating",
                "50g (¼ cup) brown sugar",
                "a handful of raisins or sultanas (sulphites)",
                "1 tsp cinnamon",
                "50g (4 tbsp) butter (milk)"
            ],
            allergens: ["milk", "sulphites"],
            steps: [
                "Heat the oven to 180°C (350°F).",
                "Core the apples, leaving the bottoms on if you can, and score a line through the skin round the middle of each so they don't burst.",
                "Mix the sugar, raisins and cinnamon and pack it into the holes. Put a bit of butter on top of each.",
                "Stand them in a dish with 4 tbsp of water in the bottom.",
                "Bake 35 to 45 minutes, till they're soft right through. Spoon the juice over them to serve."
            ],
            months: [9, 10, 11, 12, 1],
            weatherTags: ["cold"],
            tags: ["apples", "pudding"]
        ),
        KitchenRecipe(
            id: "the-hobs-bowl",
            title: "The Bowl",
            shelf: .cookery,
            credit: "The Middlemost Cookery, the back page",
            line: "Thirty years Ambrose looked for this page. It's oats. Set it down at night and say nothing about who it's for.",
            makes: "1 bowl",
            minutes: 10,
            ingredients: [
                "50g (½ cup) rolled oats (oats)",
                "300ml (1¼ cups) milk (milk)",
                "a pinch of salt",
                "1 tsp honey",
                "a small knob of butter (milk)",
                "2 tbsp cold cream (milk)"
            ],
            allergens: ["milk", "oats"],
            steps: [
                "Put the oats, milk and salt in a small pan and bring it slowly to a simmer.",
                "Cook it gently for about 5 minutes, stirring the whole time with the handle of a wooden spoon, till it's thick.",
                "Pour it into a plain bowl.",
                "Put the honey on top and the butter in the middle to melt into a little gold pool.",
                "Pour the cold cream round the edge, so it doesn't mix."
            ],
            cookNote: "The old way is no spoon. You're allowed a spoon.",
            window: KitchenWindow(startMonth: 11, startDay: 29, endMonth: 11, endDay: 30),
            smellAsk: "Who would you set this down for?",
            tags: ["porridge", "the-guest"]
        ),
    ]

    // MARK: Gayle O'Brien, Mom
    //
    // Transcribed from the sixteen binder photographs bj supplied on
    // 26 October 2026: fourteen recipes, with Rocky Road Candy and Chocolate
    // Raspberry Truffles each photographed twice. No photographs ship.
    // Preserve the binder's measures, wording and personal notes (typos fixed
    // 2026-10-30 at bj's request; nothing else rewritten). Do not
    // infer weights for packages or add quantities where she gave none.
    // The handwritten 350° on Siobhan's brownies belongs to the recipe too.

    private static let binderLine = "From her typed recipe binder."
    private static let candyWaxLine = "From her typed recipe binder. Kitchen note: Use only paraffin labeled for use as an ingredient in food."

    static let inherited: [KitchenRecipe] = [
        KitchenRecipe(
            id: "gayle-better-than-sex-cake",
            title: "Better Than Sex Cake",
            shelf: .inherited,
            credit: gayle,
            line: binderLine,
            ingredients: [
                "1 two-layer devil's food cake mix",
                "1 can sweetened condensed milk",
                "1 jar Butterscotch Caramel ice cream topping",
                "1 container of cool whip",
                "crushed Brickle"
            ],
            allergens: ["wheat", "egg", "milk", "soy", "nuts"],
            steps: [
                "Bake cake following box directions in 9 X 13 pan. Take cake out of the oven and poke holes all over cake. I use the handle of a wooden spoon.",
                "Pour condensed milk over hot cake. Microwave caramel topping and pour over cake. Refrigerate cake until cold. Just before serving top with cool whip and Brickle."
            ],
            cookNote: "The first time I made this cake I took a slice over to my next-door neighbor so she could try it. I told her the name of the cake and she laughed. She called me later and told me it was good but not that good.",
            tags: ["cake", "dessert", "family"]
        ),
        KitchenRecipe(
            id: "gayle-strawberry-cake",
            title: "Strawberry Cake",
            shelf: .inherited,
            credit: gayle,
            line: binderLine,
            ingredients: [
                "1 Box white cake mix",
                "2 containers of frozen strawberries",
                "1 16 oz pkg cream cheese (room temp)",
                "2 tablespoons sugar",
                "1 medium container of cool whip"
            ],
            allergens: ["wheat", "egg", "milk", "soy"],
            steps: [
                "Bake cake in 9 x 13 inch pan following box directions.",
                "FROSTING\nDrain strawberries reserving juice.",
                "In medium bowl beat cream cheese and sugar until smooth. Beat in about ¼ cup of strawberry juice. Gently fold in cool whip and strawberries.",
                "Frost cake and refrigerate until set."
            ],
            cookNote: "This is one of B.J.’s favorite cakes. It tastes like strawberry short cake.",
            tags: ["cake", "strawberry", "dessert", "family"]
        ),
        KitchenRecipe(
            id: "gayle-bj-lemon-birthday-cake",
            title: "B.J.’s Lemon Birthday Cake",
            shelf: .inherited,
            credit: gayle,
            line: binderLine,
            ingredients: [
                "1 Box lemon cake mix",
                "1 pkg. (4-serving size) lemon JELL-O Instant Pudding & Pie Filling",
                "1 cup of milk",
                "small container of cool whip"
            ],
            allergens: ["wheat", "egg", "milk", "soy"],
            steps: [
                "Bake cake in 9 x 13 inch pan following box directions.",
                "FROSTING\nPour 1 cup of milk into medium bowl. Add 1 pkg. (4-serving size) lemon JELL-O Instant Pudding & Pie Filling. Beat with wire whisk 2 minutes or until well blended. (Mixture will be thick.) Fold in small container of cool whip. Frost cake and refrigerate until set."
            ],
            tags: ["cake", "lemon", "birthday", "dessert", "family"]
        ),
        KitchenRecipe(
            id: "gayle-siobhan-chocolate-raspberry-brownies",
            title: "Siobhan’s Chocolate Raspberry Brownies",
            shelf: .inherited,
            credit: gayle,
            line: binderLine,
            makes: "two 9 x 13 pans or one large sheet pan",
            ingredients: [
                "1 8 oz box Baker’s unsweetened chocolate squares",
                "1 lb butter",
                "4 cups sugar",
                "6 eggs",
                "2 cups flour",
                "2 teaspoons vanilla extract",
                "1 ½ teaspoons salt",
                "12 oz jar seedless raspberry jam"
            ],
            allergens: ["milk", "egg", "wheat", "soy"],
            steps: [
                "Melt over a double boiler:\n1 8 oz box Baker’s unsweetened chocolate squares\n1 lb butter\nSet aside",
                "Mix together in large bowl with mixer until smooth:\n4 cups sugar\n6 eggs",
                "Slowly add melted chocolate and mix well.",
                "Add and mix:\n2 cups flour\n2 teaspoons vanilla extract\n1 ½ teaspoons salt",
                "Pour batter into greased pan",
                "Microwave 12 oz jar seedless raspberry jam for 1 ½ minutes. Stir jam and spread over batter. Do not mix into batter.",
                "350°\nBake for 35 to 38 minutes. Let completely cool before cutting."
            ],
            cookNote: "Siobhan is one of my best friends. I love her like a daughter and I miss her every day. Each time I make these brownies her warmth and caring surround me.",
            tags: ["brownies", "chocolate", "raspberry", "dessert", "family"]
        ),
        KitchenRecipe(
            id: "gayle-peanut-butter-bon-bons",
            title: "Peanut Butter Bon Bons",
            shelf: .inherited,
            credit: gayle,
            line: candyWaxLine,
            ingredients: [
                "2½ sticks melted margarine",
                "12 oz jar peanut butter",
                "1 lb powdered sugar",
                "2 ½ cups crushed graham crackers",
                "1 cup chopped nuts (optional)",
                "12 oz chocolate chips and ½ block of paraffin wax"
            ],
            allergens: ["peanuts", "wheat", "nuts", "milk", "soy"],
            steps: [
                "Mix with your hands\nGraham crumbs and powdered sugar\nAdd melted margarine\nAdd peanut butter and chopped nuts",
                "Shape into small balls and chill for 1 hour",
                "Melt\n12 oz chocolate chips and ½ block of paraffin wax over low heat\nDip each ball in chocolate mixture\nPlace on waxed paper until firm",
                "Store in airtight container"
            ],
            tags: ["candy", "peanut-butter", "chocolate", "family"]
        ),
        KitchenRecipe(
            id: "gayle-chocolate-coconut-balls",
            title: "Chocolate Coconut Balls",
            shelf: .inherited,
            credit: gayle,
            line: candyWaxLine,
            ingredients: [
                "½ cup melted margarine",
                "1 lb. flaked coconut",
                "1 can sweetened condensed milk",
                "1 lb. powdered sugar",
                "¾ stick paraffin wax",
                "12 oz. chocolate chips (melted)"
            ],
            allergens: ["milk", "soy", "nuts"],
            steps: [
                "Mix with your hands\nMelted margarine with condensed milk, coconut and powdered sugar",
                "Refrigerate for 30 minutes to 1 hour",
                "Roll into balls and chill again",
                "Melt chocolate chips and paraffin wax together on low heat\nDip each ball into chocolate mixture",
                "Place on waxed paper until firm",
                "Store in airtight container"
            ],
            cookNote: "This candy tastes like Mounds. Sometimes I push an almond into the tops before I dip them in chocolate. Now you have Almond Joys.",
            tags: ["candy", "chocolate", "coconut", "family"]
        ),
        KitchenRecipe(
            id: "gayle-chocolate-peanut-butter-truffles",
            title: "Chocolate Peanut Butter Truffles",
            shelf: .inherited,
            credit: gayle,
            line: binderLine,
            ingredients: [
                "1 package (8 squares) BAKER’S Semi-Sweet Chocolate",
                "½ cup peanut butter",
                "1 tub (8 ounces) Cool Whip Whipped Topping, thawed",
                "Powdered sugar, finely chopped nuts, coconut, unsweetened cocoa or multi-colored sprinkles"
            ],
            allergens: ["peanuts", "milk", "soy", "nuts"],
            steps: [
                "MICROWAVE chocolate in large microwave bowl on HIGH 2 minutes or until chocolate is almost melted, stirring halfway through heating time. Stir until chocolate is completely melted.",
                "STIR in peanut butter until smooth. Cool to room temperature. Stir in whipped topping.",
                "REFRIGERATE 1 hour. Shape into 1-inch balls. Roll in powdered sugar, nuts, coconut, cocoa or sprinkles. Store in refrigerator."
            ],
            tags: ["truffles", "chocolate", "peanut-butter", "candy", "family"]
        ),
        KitchenRecipe(
            id: "gayle-dark-chocolate-fudge",
            title: "Dark Chocolate Fudge",
            shelf: .inherited,
            credit: gayle,
            line: binderLine,
            ingredients: [
                "3 cups (18 ounces) semi-sweet chocolate chips",
                "1 (14 ounce) can Sweetened Condensed Milk",
                "Dash of salt",
                "½ to 1 cup chopped nuts (optional)",
                "1 ½ teaspoons vanilla extract"
            ],
            allergens: ["milk", "soy", "nuts"],
            steps: [
                "Line 8 or 9 inch square pan with foil. Butter foil; set aside.",
                "In heavy saucepan over low heat, melt chips with sweetened condensed milk and salt. Remove from heat; stir in nuts and vanilla. Spread evenly in prepared pan.",
                "Chill 2 hours or until firm. Turn fudge onto cutting board; peel off foil and cut into squares. Store covered in refrigerator."
            ],
            cookNote: "I have always made two batches of this fudge. One with nuts and one plain.",
            tags: ["fudge", "chocolate", "candy", "family"]
        ),
        KitchenRecipe(
            id: "gayle-rocky-road-candy",
            title: "Rocky Road Candy",
            shelf: .inherited,
            credit: gayle,
            line: binderLine,
            makes: "about 3½ dozen",
            ingredients: [
                "1 (12 ounce) package semi-sweet chocolate chips",
                "2 tablespoons butter or margarine",
                "1 (14 ounce) can Sweetened Condensed Milk",
                "2 cups dry roasted peanuts",
                "1 (10½ ounce) package miniature marshmallows"
            ],
            allergens: ["milk", "soy", "peanuts"],
            steps: [
                "Line 13 x 9 inch baking pan with waxed paper. In heavy saucepan over low heat, melt chips and butter with sweetened condensed milk; remove from heat.",
                "In large bowl, combine peanuts and marshmallows, stir in chocolate mixture. Spread in prepared pan. Chill 2 hours or until firm.",
                "Remove candy from pan; peel off paper and cut into squares. Store loosely covered at room temperature."
            ],
            tags: ["candy", "chocolate", "peanuts", "family"]
        ),
        KitchenRecipe(
            id: "gayle-chocolate-raspberry-truffles",
            title: "Chocolate Raspberry Truffles",
            shelf: .inherited,
            credit: gayle,
            line: binderLine,
            makes: "4 dozen",
            ingredients: [
                "1 (14 ounce) can Sweetened Condensed Milk",
                "¼ cup raspberry liqueur",
                "2 tablespoons butter or margarine",
                "2 tablespoons seedless raspberry jam",
                "2 (12 ounce) packages semi-sweet chocolate chips",
                "½ cup powdered sugar"
            ],
            allergens: ["milk", "soy"],
            steps: [
                "Microwave first 4 ingredients in large microwave-safe bowl on 100% power (HIGH) 3 minutes.",
                "Stir in chips until smooth. Cover and chill 1 hour.",
                "Shape mixture into 1-inch balls and roll in powdered sugar. Store covered at room temperature."
            ],
            tags: ["truffles", "chocolate", "raspberry", "alcohol", "candy", "family"]
        ),
        KitchenRecipe(
            id: "gayle-turkey-tetrazzini",
            title: "Turkey Tetrazzini",
            shelf: .inherited,
            credit: gayle,
            line: "From her typed recipe binder. Kitchen note: Use cooked turkey.",
            ingredients: [
                "1 (16 ounce) package uncooked spaghetti",
                "½ cup butter",
                "½ cup all-purpose flour",
                "3 cups chicken broth",
                "2 cups milk",
                "1 2/3 cups grated Parmesan cheese",
                "4 cups chopped turkey"
            ],
            allergens: ["wheat", "milk"],
            steps: [
                "Preheat oven to 350 degrees F. Lightly grease a medium baking dish.",
                "Bring a large pot of lightly salted water to a boil. Add spaghetti, and cook for 8 to 10 minutes or until al dente. Drain, and place in the prepared baking dish.",
                "Melt butter in medium saucepan over medium heat. Stir in flour. Mix in chicken broth and milk. Cook and stir until the mixture comes to a boil. Stir in about 1 1/3 cups Parmesan cheese, and remove from heat.",
                "Mix chicken broth mixture and turkey with spaghetti. Top with remaining cheese. Bake 1 hour in the preheated oven, until surface is lightly browned."
            ],
            tags: ["turkey", "pasta", "supper", "family"]
        ),
        KitchenRecipe(
            id: "gayle-strombolli",
            title: "Stromboli",
            shelf: .inherited,
            credit: gayle,
            line: binderLine,
            ingredients: [
                "Frozen bread dough",
                "1 Tablespoon oil",
                "Ham",
                "Salami",
                "Cheese – Provolone",
                "Tomatoes",
                "Onion"
            ],
            allergens: ["wheat", "milk"],
            steps: [
                "Thaw bread dough and let rise.",
                "Put a little flour and dough on table and roll out flat in a big circle (about the size of a pizza).",
                "Rub one tablespoon of oil over dough.",
                "Cover entire circle of dough with ham, about 5 slices. Top ham with slices of salami (about 9 slices). Next add cheese. Slice the tomato and onion very thinly and scatter over cheese.",
                "Now you have to roll the dough up very tight like a jellyroll. Pinch the ends to make sure everything stays inside. Place on cookie sheet and bake for 20 minutes at 350 degrees. Take out of oven and cover pan with foil. Continue baking for another 30 minutes.",
                "Remove and slice."
            ],
            tags: ["bread", "supper", "family"]
        ),
        KitchenRecipe(
            id: "gayle-nana-lemon-icebox-pie",
            title: "Nana’s Lemon Icebox Pie",
            shelf: .inherited,
            credit: gayle,
            // FDA: https://www.fda.gov/food/buy-store-serve-safe-food/what-you-need-know-about-egg-safety
            // The binder's claim remains in the transcription, immediately
            // qualified by an editorial note before the cooking instructions.
            line: "From her typed recipe binder. Kitchen note: Use pasteurized shell eggs for both filling and meringue. Lemon juice does not make raw eggs safe, and browning the meringue does not ensure the filling is cooked. Keep the pie refrigerated.",
            ingredients: [
                "one graham cracker piecrust",
                "3 egg yolks",
                "1 can sweetened condensed milk",
                "3 lemons"
            ],
            allergens: ["wheat", "egg", "milk"],
            steps: [
                "PIECRUST\nMake one graham cracker piecrust. You can use a ready made crust or it’s easy and better to make your own.",
                "FILLING\nSeparate your three eggs. Beat by hand the 3 egg yolks and add can condensed milk. Mixture will be thick. Squeeze the juice from 3 lemons and add to the filling. Stir to mix well. Add to the piecrust.",
                "(The acid from the lemon juice cooks the eggs.)",
                "TOP\nBeat the 3 egg whites with an electric mixer on high. I added a little cream of tartar to help stiffen the meringue. Cover top of pie with the meringue and bake in 425-degree oven just until the meringue starts to brown. Keep a close eye, it browns fast."
            ],
            cookNote: "This pie is Carol’s, Judy’s and my favorite. Mom always makes this for the three of us each time we go home.",
            tags: ["pie", "lemon", "dessert", "family"]
        ),
        KitchenRecipe(
            id: "gayle-layered-mint-chocolate-candy",
            title: "Layered Mint Chocolate Candy",
            shelf: .inherited,
            credit: gayle,
            line: binderLine,
            makes: "about 1 ¾ pounds",
            ingredients: [
                "1 (12-ounce) package semi-sweet chocolate chips",
                "1 (14-ounce) can Sweetened Condensed Milk",
                "2 teaspoons vanilla extract",
                "1 cup (6-ounces) deluxe white baking chips",
                "1 tablespoon peppermint extract",
                "Few drops green or red food coloring"
            ],
            allergens: ["milk", "soy"],
            steps: [
                "Line 8 or 9 inch square pan with waxed paper. In heavy saucepan over low heat, melt semi-sweet chips with 1 cup sweetened condensed milk. Stir in vanilla, spread half the mixture in prepared pan; chill 10 minutes or until firm. Keep remaining chocolate mixture at room temperature.",
                "In heavy saucepan over low heat, melt white chips with remaining condensed milk. Stir in peppermint extract and food coloring. Spread over chilled chocolate layer; chill 10 minutes or until firm. Spread reserved chocolate mixture over mint layer. Chill 2 hours or until firm.",
                "Turn candy onto cutting board; peel off paper and cut into squares. Store loosely covered at room temperature."
            ],
            tags: ["candy", "chocolate", "mint", "family"]
        ),
    ]
}
