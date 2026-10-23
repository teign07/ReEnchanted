"""Small channels: the month's wonder lines for the nightly braid, and the lined-space
prompts the printed books deal before the bundled ones."""


def wonder(id, nouns, line, needs=None):
    w = {"id": f"the-guest.wonder.{id}", "nouns": nouns, "line": line}
    if needs:
        w["needs"] = needs
    return w


WONDER_LINES = [
    wonder("onion", ["onion", "onions"],
           "The onion went clear in the butter, the way a shy person does once they've decided to stay."),
    wonder("garlic", ["garlic"],
           "The garlic had been sitting in its papery coat all week, waiting for somebody brave."),
    wonder("butter", ["butter"],
           "The butter went from quiet to a small busy hiss, like rain finding a tent."),
    wonder("honey", ["honey"],
           "The honey took its time leaving the spoon, the way you do from a warm room."),
    wonder("oats", ["oats", "oatmeal"],
           "The oats had been in the jar since summer, dreaming of milk."),
    wonder("cinnamon", ["cinnamon", "nutmeg", "cloves", "spice", "spices"],
           "The spices in the jar remembered ships, and said so, the moment the lid came off."),
    wonder("apple", ["apple", "apples"],
           "Cut across the middle, the apple had a star inside it, and it'd been keeping quiet about it all along."),
    wonder("jam", ["jam", "marmalade", "jar", "jars"],
           "The jar of jam had been holding a whole August in the dark for somebody."),
    wonder("pan", ["pan", "pans", "pot", "pots", "saucepan"],
           "The pot hung on its hook, scrubbed and shining, and wouldn't say who'd done it."),
    wonder("ladle", ["ladle", "ladles"],
           "The ladle had dipped into a thousand suppers and remembered every one as the best."),
    wonder("flour", ["flour"],
           "The flour got onto everything it could reach, the way news does."),
    wonder("salt", ["salt"],
           "The salt sat in its cellar like a gatekeeper, deciding who got in."),
    wonder("gravy", ["gravy"],
           "The gravy went on and on round the plate, because nobody had given it a full stop."),
    wonder("pudding", ["pudding", "puddings"],
           "The pudding steamed in its cloth all night, keeping everybody's wishes warm."),
    wonder("leftovers", ["leftovers", "leftover"],
           "The leftovers in the fridge were the best part of yesterday, waiting to be asked back."),
    wonder("bowl", ["bowl", "bowls"],
           "The bowl on the hearth had been set down for somebody, and everybody knew who."),
    wonder("recipe", ["recipe", "recipes", "cookbook", "cookbooks"],
           "The old recipe knew the way back to a kitchen that wasn't there any more, and went anyway."),
    wonder("napkin", ["napkin", "napkins"],
           "The napkin had been folded into a little hat for somebody who wasn't coming, and wore it proudly."),
]


def prompt(id, kind, text):
    return {"id": f"the-guest.note.{id}", "kind": kind, "text": text}


NOTE_PROMPTS = [
    prompt("smell", "day", "What did the kitchen smell like tonight?"),
    prompt("fed", "day", "Who did you feed today? Who fed you?"),
    prompt("one-day", "any", "What does your house smell like on the one day a year it smells like that?"),
    prompt("hands", "day", "Something you made with your hands. What did they do?"),
    prompt("made-for-you", "any", "Write down something somebody used to make for you."),
    prompt("not-written", "any", "A recipe that isn't written down anywhere. Write it down here."),
    prompt("enough", "margin", "How much is enough? Write the amount the way the person who taught you would say it."),
    prompt("chair", "any", "Who would you set an empty chair for?"),
    prompt("cold", "day", "What do you eat when it's cold?"),
    prompt("sound", "day", "The sound of something cooking. Describe it without naming the food."),
    prompt("table", "any", "The best table you ever ate at. Who was there?"),
    prompt("wrong", "day", "Something that went wrong in the kitchen, and what you did about it."),
    prompt("grateful", "margin", "Say I'm grateful to somebody. Write down who, and for what."),
    prompt("wish", "margin", "A wish you'd make if you were stirring the pudding. You don't have to say it out loud."),
    prompt("bowl", "puzzle", "Draw the bowl you'd leave out for whoever keeps your house."),
]
