# Bound leaves and unfolded Pages

`SurfacePage.leafPresentation` is the single policy. It depends on the Page's purpose and authored state, never on screen size or how many controls fit.

- **Short answer:** print the question once and provide one answer field. Keep works on the leaf. Other input methods and suggestions remain in the unfolded Page.
- **Reading:** print the complete prose across ordinary leaves. Keep preserves the complete Page.
- **Reading with other options:** print the complete prose. Unfolding starts with the other options; “Read the Page again” restores the prose. The Bleed, written letters, and Book of You follow this rule. Opened notes keep their text visible above the reply box, with one sender heading and share-card controls after the reply.
- **Activity preview:** print a brief excerpt and a direct explanation of what unfolds. Choices, worksheets, readings, games, maps, and multi-step tasks happen in the unfolded Page. Keep cannot complete an activity from its teaser.

Generation invitations keep their existing “Let me write” route. Finished story results, authored scenes without a choice, and kept readbacks remain reading matter. Binding and other authored activity metadata take priority over a broad Page type.

The footer consistently contains the unfolding action and the original Rip It Out / Keep layout. Auxiliary buttons do not stack above it. No modal control view, option grid, attachment picker, or scrolling form is mounted on a bound leaf. Prose may span leaves; controls do not produce extra leaves.

Preview text is derived from the existing Page, not generated again. The canonical prose, choices, source identity, and save payload stay whole. Unfolding carries any answer already typed on the leaf through the existing Page-opening route.

New copy uses familiar words and direct actions. Say what the reader can do and what opening gives them. Keep the Book honest; do not add riddles, ornamental explanations, or baby talk.

## Verification

Source syntax and policy regression cases can be checked separately from a build. On iPhone and iPad, verify the journal question appears once, activity previews have no clipped controls, both reading and answer drafts survive unfolding, and the Bleed opens at its other options with the complete issue available on request. Repeat Keep, Rip It Out, page turns, larger text, and modal reopening. Check crash reports after exercising those actions; launch success alone is insufficient.
