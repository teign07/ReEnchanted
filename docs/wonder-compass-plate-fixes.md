# Wonder Compass plates: fix list

Written 25 October 2026, after a visual review of all 53 NotebookLM infographics
in `InsideCoverApp/WonderCompassImages/`. For Codex, using the same image-edit
pipeline as the 25 October repair pass (`docs/wonder-compass-images.md`).

## Rules for every plate

- **Change only the text listed.** Keep the composition, illustrations, palette,
  layout and the NotebookLM mark. Where a plate needs a new element (Ch 4A's
  missing signal), match the existing style.
- **The plates speak in bj's voice, and they match the chapter next to them.** The
  chapters were restored on 24 October (commit `8e474a59`): theories stated
  plainly, facts right, caveats in Notes & References. On a plate, never write
  "can", "may", "some studies", "one hypothesis", "this does not establish",
  "responses vary" or "is a metaphor". If a plate line needs a caveat, the line is
  wrong; use the replacement below.
- **Spell-check every word on the finished plate at full resolution**, not just the
  edited lines. Several plates marked "corrected" still have typos.
- **Afterwards:**
  - update `docs/wonder-compass-infographic-audit.json` (status, prompts, hashes)
    and the plate metadata in `Shared/BookReferenceLibrary.json` (sha256, pixel
    size)
  - run `python3 scripts/check_wonder_compass_images.py`
  - inspect small-text crops after JPEG conversion
- **Do not touch chapter prose.**

Each entry gives the file, then **Now** (the text on the plate) and **Make it**
(the replacement). **Now** was copied by eye from the plates, so use it to find
the text, and replace whatever the plate actually says there. Text not listed
stays as it is. Every **Make it** line was checked against the chapter it goes
with.

---

## Part 1: plates that say something the book no longer says

These go first. Each one contradicts the corrected chapter.

### 1. `Curing_Concrete_Blindness__Urban_Guide_Large.jpeg` (Ch 20)

The "1.3 seconds" figure came from a journal that doesn't exist. It was removed
from the chapter, and the plate contradicts itself (1.3 in the badge, 1.5 in the
text).

- Yellow badge.
  - **Now:** `1.3 seconds`
  - **Make it:** `42%`
- Text beside the badge.
  - **Now:** `The reality: Strangers look at you for an average of 1.5 seconds. You have more freedom to explore and be curious than you think.`
  - **Make it:** `The reality: City people glance and look away. And when one man stood on a New York sidewalk staring up at a building, 42% of passersby looked up too. Looking up isn't weird. It's contagious.`
- Intro paragraph.
  - **Now:** `city dwellere`
  - **Make it:** `city dwellers`

### 2. `A_Guide_to_Failing_Better_Large.jpeg` (Ch 15)

The insula/"same pathway" claim was removed from the chapter.

- North-fails solution.
  - **Now:** `Instead of seeking heauty, find something that irritates you. Disgust uses the same neural pathways as curiosity.`
  - **Make it:** `Instead of seeking beauty, find something that irritates you. When your interest goes offline, your eye for flaws keeps running. Use it.`

### 3. `The_Wonder_Antidote_Compass_Guide_Large.jpeg` (Ch 4A)

The book has twelve signals; the plate has eleven. Emotional Amnesia is missing,
and the Rumination antidote has no label.

- Subtitle.
  - **Now:** `A precision tool to counter eleven common negative states`
  - **Make it:** `A precision tool for all twelve signals of the Rut`
- Left header.
  - **Now:** `THE RUT: 11 COMMON SIGNALS`
  - **Make it:** `THE RUT: 12 SIGNALS`
- Left column: add a twelfth node in the same style, after Time Starvation.
  - **Make it:** `Emotional Amnesia`
- Right column: add a matching antidote.
  - **Make it:** `Emotional Amnesia: You build a physical library of written Souvenirs.`
- Right column, the unlabeled awe item.
  - **Now:** `Experiencing awe creates a "Small Self," which quiets the worrying brain.`
  - **Make it:** `Rumination: Awe creates the "Small Self," quieting the part of the brain that worries.`

### 4. `Survival_Compass_for_Darkest_Days_Large.jpeg` (Ch 16)

The chapter now credits Janoff-Bulman's term.

- Right heading in "The Problem".
  - **Now:** `Meaning Violation`
  - **Make it:** `Shattered Assumptions`

### 5. `Strengthen_Your_Bonds_With_Low_Pressure_Large.jpeg` (Ch 12A)

The 90% figure isn't in the chapter. It says "a lot of the time, they'll eventually wander over and join you."

- Gauge badge.
  - **Now:** `90%`
  - **Make it:** replace the gauge with a small open door, matching the plate's door art. No number.
- Text under the badge.
  - **Now:** `90% of the time, they will join you. Removing the pressure to participate allows genuine interest to grow.`
  - **Make it:** `A lot of the time, they'll wander over and join you. Take the pressure off, and curiosity does the inviting.`

### 6. `Reclaiming_Intimacy_Relationship_Guide_Large.jpeg` (Ch 12B)

The chapter now gives Gottman's recommendation and Grewen's real finding.

- 6-Second Kiss.
  - **Now:** `Kisses over six seconds shift the brain from "greeting" to "intimate connection."`
  - **Make it:** `Six seconds is too long to be a reflex. It's a kiss with potential.`
- 20-Second Hug.
  - **Now:** `Extended hugs drop cortisol levels and synchronize the nervous systems of both partners.`
  - **Make it:** `A long hug keeps your blood pressure down under stress. More hugs, fewer colds.`

---

## Part 2: Codex's cautious voice, painted into the plates

These plates now argue with the chapters beside them. Put bj's voice back.

### 7. `The_Biological_Cost_of_Boredom_Large.jpeg` (Ch 1A)

Restore the original title. Every callout below replaces a hedged one.

- Title.
  - **Now:** `When Boredom and Stress Wear You Down`
  - **Make it:** `The Biological Cost of Boredom`
- Subtitle.
  - **Now:** `Why Restless Days Can Feel Tiring`
  - **Make it:** `Why You're So Tired (When You Haven't Done Anything)`
- Top callout.
  - **Now:** `BOREDOM CAN FEEL RESTLESS / A task may offer too little challenge or meaning. That can leave you tense or disengaged.`
  - **Make it:** `BOREDOM IS STRESS / When researchers bored people on purpose, their heart rate and cortisol went up.`
- Second callout.
  - **Now:** `WORRY CAN PROLONG STRESS / Stressful thoughts can keep a stress response going, though responses vary.`
  - **Make it:** `WORRY KEEPS THE ALARM ON / Your body is terrible at telling a stressful thought from a tiger. The alarm keeps ringing long after the moment's over.`
- Stress icons heading.
  - **Now:** `PROLONGED STRESS CAN AFFECT HEALTH`
  - **Make it:** `PROLONGED STRESS WEARS YOU DOWN` (keep the three icon labels)
- Fatigue callout.
  - **Now:** `FATIGUE HAS MANY POSSIBLE CAUSES / Feeling tired or achy does not tell you what is happening in your immune system.`
  - **Make it:** `IT INFLAMES YOU / Loneliness and chronic stress switch on the genes for inflammation. That's the ache, the fog, the heavy limbs.`
- Long-term callout.
  - **Now:** `LONG-TERM HEALTH LINKS / Chronic stress is associated with health risks. This is not an inevitable progression from boredom.`
  - **Make it:** `THE INTEREST COMPOUNDS / Leave it for years, and chronic stress is tied to heart disease, diabetes and depression.`
- Icon label under the pancreas.
  - **Now:** `Health`
  - **Make it:** `Diabetes`
- Bottom banner, second line.
  - **Now:** `Your fatigue is real. These feelings do not identify a single cause.`
  - **Make it:** `Your fatigue is real. It's biology.`

### 8. `Awe__Your_Body_s_Reset_Button_Large.jpeg` (Ch 4A)

The chapter says it plainly now: "The people who felt the most wonder had the
least inflammation."

- Inflammation panel.
  - **Now:** `More reported awe was associated with lower IL-6 in one observational study. This does not establish a treatment effect.`
  - **Make it:** `The people who felt the most wonder had the least inflammation (IL-6).`
- Calm panel heading.
  - **Now:** `Positive Awe Can Feel Calming`
  - **Make it:** `Awe Hits the Brakes`
- Calm panel text.
  - **Now:** `Physiological responses vary with the person and the kind of awe.`
  - **Make it:** `Of five positive emotions tested, awe was the only one that eased off fight-or-flight.`
- Perspective panel. The plate edge currently cuts it off; fit the new text inside the bubble.
  - **Now:** `It Can Broaden Perspective / Some experiments link awe with a smaller sense of self and more helpful behavior`
  - **Make it:** `It Makes You Nicer / One minute staring up at tall trees made people more helpful.`
- Attention panel.
  - **Now:** `Awe Can Shift Attention / Awe can draw attention beyond with usual running commentary.`
  - **Make it:** `Awe Quiets the Worrier / Awe turns down the Default Mode Network, the part of your brain that chews on yourself.`
- AWE WALKS card.
  - **Now:** `Weekly 15-minute awe walks increased positive social emotions in one older-adult trial.`
  - **Make it:** `Fifteen minutes a week: more compassion, less distress, bigger smiles.`
- DAILY AWE card.
  - **Now:** `A small long-COVID trial found improved stress and well-being after a four-week program.`
  - **Make it:** `Four weeks of finding awe in ordinary days: less stress, less depression.`
- WRITING card.
  - **Now:** `A specific detail gives you a cue for remembering a moment.`
  - **Make it:** `Three good things a night for one week. Happier six months later.`

### 9. `Flow_State_Silences_Inner_Critic_Large.jpeg` (Ch 8A)

The chapter says flow quiets the critic and brain scans show it.

- Intro line.
  - **Now:** `Flow is deep absorption in an activity. A clear goal, feedback, and a manageable challenge can help you get involved in what you are doing.`
  - **Make it:** `Flow is complete absorption. The self vanishes, time bends, and the critic shuts up. Three triggers get you there.`
- Left panel.
  - **Now:** `The Caveman is a Metaphor / Your inner critic is a pattern of self-talk, not a creature in one brain region.`
  - **Make it:** `Meet the Caveman / He runs your inner critic: grim, efficient, and allergic to fun.`
- Middle panel.
  - **Now:** `Give Attention a Small Job / Try a clear sensory mission. You may become absorbed without forcing a result.`
  - **Make it:** `Give Him a Coloring Book / A Playful Mission gives your analytical brain a job, so the rest of you can enjoy the moment.`
- Right panel.
  - **Now:** `Flow Invites Absorption / Researchers are still studying flow's brain mechanisms. It is not a proven shutdown switch.`
  - **Make it:** `Flow Turns Him Down / In brain scans of people in flow, a self-critical hub of the prefrontal cortex goes quiet.`

### 10. `The_Science_of_Anthropomorphism_Large.jpeg` (Ch 8B)

Fix the hedges, the typos ("actuallly", "Iit"), and the step badges: the plate
shows 1, 1, 2, 2, 3. Show one 1, one 2 and one 3.

- Social cognition caption.
  - **Now:** `Anthropomorphism can engage brain regions used in thinking about people.`
  - **Make it:** `Call your lamp loyal, and the same brain region lights up that does the work when you think about your best friend.`
- Caveman caption.
  - **Now:** `One hypothesis links this habit to detecting agents in uncertain situations.`
  - **Make it:** `Your ancestors survived by assuming the rustling bush was someone. Your brain still sees characters everywhere.`
- Middle heading.
  - **Now:** `Weigh the Invitation`
  - **Make it:** `Use the Invitation`
- Bike caption.
  - **Now:** `Imagine your bike wanting an outing, then decide whether you want one too.`
  - **Make it:** `Your bike wants to go out. It's easier to help a friend than to motivate yourself.`
- Car panel.
  - **Now:** `Character Can Change How You Relate to Things / Some studies find greater perceived understanding or trust. Check how the object actualIly works.`
  - **Make it:** `Characters Get Cared For / People trusted a self-driving car named Iris more, and people who thought of their car as alive were less willing to trade it in.`
- Armchair panel.
  - **Now:** `Make Familiar Things Feel Companionable / Imaginative company can be pleasant. Iit does not replace human connection.`
  - **Make it:** `Your House Is Full of Friends / Treat your things as companions, and home stops feeling lonely.`

### 11. `phonto_Large.jpeg` (Ch 4A, "Why Your Brain Thinks an Email is a Tiger")

- First timeline item.
  - **Now:** `Meet Your Protective Caveman / The caveman is a metaphor for protective habits, not a literal ancestor in your brain.`
  - **Make it:** `Meet Your Protective Caveman / He's the oldest, fastest part of your brain, and he thinks it's still 50,000 years ago.`
- "Don't Fight Him" text.
  - **Now:** `You must gently reassure your primal brain that you are actually safe.`
  - **Make it:** `Speak his language. Show your primal brain the world is safe enough to enjoy.`

### 12. `Science-Backed_Benefits_of_Noticing_Large.jpeg` (Ch 6A)

The chapter says "it's hard to chew on a worry and chase a question at the same
time." The plate says the opposite.

- Curiosity panel.
  - **Now:** `Curiosity is linked with well-being. / Ask one question about something around you. Curiosity and anxiety can coexist.`
  - **Make it:** `Curiosity makes you happier. / On their most curious days, people found more meaning in their lives. And it's hard to chew on a worry and chase a question at the same time.`
- Novelty panel.
  - **Now:** `Novelty engages brain regions involved in learning and motivation. / Notice something new and see where your interest goes.`
  - **Make it:** `Novelty is dopamine. / Something new lights up your brain's motivation center. Noticing is a micro-dose of get-off-the-couch.`

### 13. `Action_Creates_Motivation__Not_Vice-Versa_Large.jpeg` (Ch 7)

Keep "where 90% of adventures die"; that line is in the chapter. Keep the
38/35/91 chart.

- Subtitle.
  - **Now:** `How Action Can Help You Begin`
  - **Make it:** `Why Motivation Is a Myth`
- Hack #1 text.
  - **Now:** `A meaningIall first action can help motivation grow.`
  - **Make it:** `You don't wait to feel good to move. You move to feel good.`
- Map label.
  - **Now:** `30 MIN JOG JOG`
  - **Make it:** `30 MIN JOG`
- Hack #2 text: remove the stray mark between "how" and "you".
  - **Now:** `Specify when, where, and how. you will begin.`
  - **Make it:** `Specify when, where, and how you will begin.`

---

## Part 3: typos and layout

| # | File | Now | Make it |
|---|---|---|---|
| 14 | `Are_You_Caught_in_The_Drift__Large.jpeg` (Ch 2) | `pulls you roward efficiency` | `pulls you toward efficiency` |
| 14 | same | `risk-averes` | `risk-averse` |
| 15 | `The_Art_of_Shadow_Wonder_Large.jpeg` (Ch 6A) | `harmouize` | `harmonize` |
| 16 | `Pre-Packed_Kit_for_Spontaneous_Joy_Large.jpeg` (Ch 7) | `Fancy Shacks` (bag label) | `Fancy Snacks` |
| 17 | `Resting_vs__Numbing_Brain_Recharge_Guide_Large.jpeg` (Ch 10) | `Maaks exhaustion` | `Masks exhaustion` |
| 18 | `3-D_Recipe_to_Beat_Inertia_Large.jpeg` (Ch 7) | `dally rut` | `daily rut` |
| 19 | `Four_Recipes_to_Beat_Creative_Block_Large.jpeg` (Ch 13) | `You can't fall when you're using trash` | `You can't fail when you're using trash` |
| 19 | same | `make 56 versions` | `make 50 versions` |
| 19 | same | `drled-up paints` | `dried-up paints` |
| 20 | `Break_the_Trance_of_the_Familiar_Large.jpeg` (Ch 18) | `a detall you usually ignore` | `a detail you usually ignore` |
| 20 | same | `Tum observation` | `Turn observation` |
| 20 | same | `product packeging` | `product packaging` |
| 21 | `Solve_the_Vacation_Burnout_Paradox_Large.jpeg` (Ch 23) | `Zeigamik` | `Zeigarnik` |
| 21 | same | `one lest activity` | `one last activity` |
| 22 | `The_Neurodivergent_Compass_Infographic_Large.jpeg` (Ch 11D) | `shieids` | `shields` |
| 23 | `Turn_Your_Smartphone_Into_A_Field_Kit_Large.jpeg` (Ch 6B) | `DIGITAL AIGNALL` (vertical label) | `DIGITAL AIRWALL` |
| 23 | same | `ial Media` (blocked app) | `Social Media` |
| 24 | `Protect_Your_Memories__24-Hour_Rule_Large.jpeg` (Ch 9) | heading `Instant Sharing Creates 'Messy' Memories.` appears twice | keep only the one directly above `Comments from others can overwrite your own feelings about the experience.` |
| 25 | `Your_Brain_on_Autopilot_Explained_Large.jpeg` (Ch 1A) | `You see the concept* of a thing` | `You see the concept of a thing` (no asterisk) |
| 26 | `Everyday_Adventure__The_Wonder_Compass__Large.jpeg` (Ch 5) | `North = Notice (The Spark)` appears twice | delete the small centered label above the N; keep the left text block |
| 27 | `The_4-Hour_Vacation_Blueprint_Large.jpeg` (Ch 22) | `THE RETURN` has no text | add under it: `Capture your Souvenir before you drive. Then a treat for the road.` |
| 28 | `The_60-Second_Reset_Guide_Large.jpeg` (Ch 10) | Step 3 shows a figure in lotus pose above `Do not meditate` | redraw the figure slumped comfortably in the armchair from Step 1, eyes closed |
| 29 | `Wonder_Compass__Noticing_to_Navigating_Large.jpeg` (Ch 26) | bottom badge `1 Your Moments Become Your Data` | `3 Your Moments Become Your Data` |
| 30 | `The__0_Compass_Guide_Large.jpeg` (Ch 11A) | penny reads `IN GOD WE THO` | `IN GOD WE TRUST` |

## Done when

- Every plate above has the listed changes and no other text changes.
- A full-resolution read of each edited plate finds no misspelled or malformed word.
- None of the banned hedges appear on any edited plate.
- The audit JSON, library metadata and checker all pass.

---

## Round two (25 October, after checking the first pass)

Every round-one change landed. A full read of the 30 plates found these
leftovers. Same rules as above: change only the text listed, keep the art,
spell-check the whole plate, then update the audit JSON and library metadata and
run the checker.

### Typos and garbled text

| # | File | Now | Make it |
|---|---|---|---|
| R1 | `Curing_Concrete_Blindness__Urban_Guide_Large.jpeg` (Ch 20) | handwriting in the open journal (W panel): `Document moments of centract, like a flwaer growing through a notway grate.` | `Document moments of contrast, like a flower growing through a subway grate.` (same handwritten style) |
| R2 | `Strengthen_Your_Bonds_With_Low_Pressure_Large.jpeg` (Ch 12A) | `Their persoective reveals tiny wonders` | `Their perspective reveals tiny wonders` |
| R3 | `Are_You_Caught_in_The_Drift__Large.jpeg` (Ch 2) | `pulls you toward efficiency. numbness, and anxiety.` | `pulls you toward efficiency, numbness, and anxiety.` (comma, and set the whole phrase in one style; the patched words are italic, the rest isn't) |
| R4 | `The_Neurodivergent_Compass_Infographic_Large.jpeg` (Ch 11D) | intro: `to work *with* neurodivergent brain wiring` | `to work with neurodivergent brain wiring` (no asterisks; italic "with" is fine) |
| R5 | `The_Wonder_Antidote_Compass_Guide_Large.jpeg` (Ch 4A) | Anhedonia: `A playful 'Sense mission` | `A playful "Sense" mission` |
| R6 | `Resting_vs__Numbing_Brain_Recharge_Guide_Large.jpeg` (Ch 10) | under NUMBING, the line `with constant input` is in a blurrier, slightly different font than `Masks exhaustion` | re-set both lines in the plate's caption font so they match |

### Hedges left in lines the first list didn't cover

**R7. `Your_Brain_on_Autopilot_Explained_Large.jpeg` (Ch 1A)**

- Subtitle.
  - **Now:** `Why Life Can Feel "Gray"`
  - **Make it:** `Why Life Feels "Gray"`

**R8. `Science-Backed_Benefits_of_Noticing_Large.jpeg` (Ch 6A)**

- Write 3 Good Things text.
  - **Now:** `Note three things that went well and why they happened. In one study, benefits lasted six months; continued practice mattered.`
  - **Make it:** `Write down three things that went well and why. One week of it, and people were still happier six months later.`

**R9. `The_Science_of_Anthropomorphism_Large.jpeg` (Ch 8B)**

- Left column header.
  - **Now:** `THE SURPRISING SCIENCE: YOU CAN IMAGINE AN OBJECT AS A CHARACTER`
  - **Make it:** `THE SURPRISING SCIENCE: YOUR BRAIN SEES CHARACTERS EVERYWHERE`
- Left heading.
  - **Now:** `Familiar Things Can Become Characters`
  - **Make it:** `Familiar Things Become Characters`

**R10. `Resting_vs__Numbing_Brain_Recharge_Guide_Large.jpeg` (Ch 10)**

The chapter names the sound and says your brain falls into step with it.

- Auditory Entrainment text.
  - **Now:** `Try a steady background sound if you find it restful.`
  - **Make it:** `Put on brown noise. Your brain falls into step with a steady rhythm.`

### Repeated line

**R11. `phonto_Large.jpeg` (Ch 4A)**

"Safe enough to enjoy" appears twice: here and in the closing caption under the
speech bubble.

- "Don't Fight Him, Educate Him" text.
  - **Now:** `Speak his language. Show your primal brain the world is safe enough to enjoy.`
  - **Make it:** `Speak his language.`

### Done when

- R1–R11 are on the plates, and no other text changed.
- A full-resolution read of each edited plate finds no misspelled or malformed word, and no stray asterisks or quote marks.
- The audit JSON, library metadata and `python3 scripts/check_wonder_compass_images.py` all pass.
