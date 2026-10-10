# Landing screenshots · October 10, 2026

The published Pagewright worktable (`pagewright-studio-tonight`) is the maker's
current capture. Its content is preserved; the website now uses a WebP copy.
The finished example is the actual `pagewright-floating-home` export from the
published sample month, including the selected boat-interior photographs.

Eleven replacement screenshots were captured through Simulator's **Save Screen…**
command from the already-installed QA app on iPhone 17 Pro / iOS 26.5. No app
build was performed. Originals and the visual contact sheet are in ignored
`output/landing-screenshot-refresh/`.

The replacements show current Glow/Magic, Compass Run, Wicker's About Page,
Anchor, the Cast/Belief menus, Radio, three Search views, and Colophon/privacy.
The Wicker image is explicitly described as his Page, not a completed Dare.
Search shows genuine Page-family matches for “Small Glow”; the third image
opens a result on the reading stand rather than claiming an index progress view.
The Colophon accurately shows this QA install has no local model installed.

The old Story-choice image was retired because it included obsolete navigation.
The prose-only scene illustration remains alongside a link to the actual sample
month. Covers, the illustrated photo keep, and Professor Boggle's dossier are
artwork rather than screenshots of obsolete app navigation and remain in use.
The legacy `app.js` screenshot deck is not loaded by the public landing page.

An attempt to import the existing simulated October archive through **Open a
sealed copy** did not open the file picker in this installed QA app. No sample
archive was imported and no generated placeholder Story Page was published.

`scripts/optimize-landing-images.py` runs after artwork syncs in the deployment
script. It preserves transparency and formats, caps normal raster images at
1600 pixels per side, retains up to 2000 pixels of height for sample Pages,
and uses moderate JPEG/WebP compression. It keeps the original bytes whenever
the candidate saves less than 15%. A content-hash cache under ignored `output/`
prevents repeated lossy recompression. App originals and downloadable PDFs
are outside its scope.

Publication is staged from the latest public mirror, with only the screenshot
HTML patch, new WebP images, and image optimization applied. Concurrent promo,
terms, physical-edition, and app changes are not part of this publication.

The scoped optimization pass reduced raster storage from 52.2 MB to 37.4 MB
(about 28%). Current app captures are 36–72 KB each; the existing worktable
is a 40 KB WebP. A second pass made zero changes. The Book reserves screenshot
aspect ratios before pagination, so lazy loading does not collapse their
measured height and push later images beneath the footer.
The mechanics and Anchor image containers are semantic figures, so the same
image-size limit and geometry reservation apply to them in the public Book.

Final public mirror: `c4d9424`. GitHub Pages deployment succeeded. Live mobile
verification at 390 px confirmed complete image decoding, normal blend mode,
no horizontal overflow, matching screenshot headings, and leaf content fitting
its measured height. The browser warning/error log was empty. Desktop geometry
was also checked locally; all 539 staged raster files decoded successfully.
The final public desktop check also passed: complete screenshots, matching
headings, no horizontal overflow, and content fitting each measured leaf.
Forward and backward turns between the Spell and Compass leaves were checked.
