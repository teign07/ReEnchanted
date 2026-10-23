# Illuminated photo composition

October 20, 2026. Implemented in source. No build or device render performed.

The photo capture flow, suggested illuminated photos, onboarding examples,
interleaf library photos, and photo enchantments all use
`IlluminatedPageComposer` and `IlluminatedArtifactPreview`. The interleaf path
still prepares and reveals one complete decoded composition.

New plans use one shared placement pass for text and cabinet artwork. Text is
placed before art, using rotated bounds with breathing room. Text stays on the
surrounding page; artwork can touch the photograph's edges while avoiding its
protected subject. An item without room is omitted. The renderer uses the
settled geometry directly, without independent nudging, resizing, or extra
rotation that could reintroduce collisions.

Photos have two main annotations and sometimes a small typographic stamp.
Most writing sits directly on the leaf in handwriting. At most one annotation
uses translucent torn paper, with a light texture and small shadow. New notes
have no rounded card border, repeated headings, or double tape. Up to four
unique cabinet marks share the same occupied-space list. Doodles render at
0.94 opacity and stamps at 0.82, retaining their asset alpha. They are not faded
because another independently placed card covered them. Downloaded artwork is
resolved into a bounded image cache before snapshot rendering; ImageRenderer
cannot rely on a child view's asynchronous image-loading task.

Fallback analysis explicitly marks its writing as fallback. The composer
chooses from 54 openings, 54 closings, 48 looking invitations and 24 stamp
labels using the composition seed. The expanded vocabulary mixes the Book's
handling of the picture with imagined Faerie-tales, small courtesies and
unbuyable treasures, and physical attention to weight, air, warmth, texture,
light and sound. It offers possibilities and optional small acts without
inventing what happened inside the photograph. Many lines simply give the
moment a magical cast rather than setting the Reader another task.
Generated observations and spell results retain their actual wording.

Enchantments use an explicit purpose in both capture and reconstructed folio
paths: one short opening and one complete result, without repeating the result
as an observation list or adding generic filler. The photo reserves more page
space for longer results. No seven-line cap is applied to the result.

Layout and annotation-style fields are optional for old saved plans to remain
decodable. Old stored plans retain their original rendering behavior, and
previously saved, flattened JPEGs keep their existing pixels. This change
applies when a composition is newly made, including new interleaf preparation.

Regression coverage in `IlluminationPaperVariationTests.swift` checks density,
rotated shared collisions, subject protection, repeatability, fallback variety,
observed-writing preservation, long enchantment results, and legacy decoding.
The previous tests requiring nine cards or six different paper assets have
been updated to the new composition contract. Swift tests are added but not
executed because running them would build the package. Swift frontend parsing
and whitespace checks are source validation only. Phone/iPad rendering, long
spell text fitting, downloaded cabinet artwork, settled frames, reduced motion,
and VoiceOver still need runtime verification.
