# Sealed copy: container metadata permission failure

On October 13, Rabbit's Seal a Copy reported that
`.com.apple.mobile_container_manager.metadata.plist` could not be copied because
the app lacked permission to access `container`.

The whole-Book moving-copy exporter in `InsideCoverApp/BookMovingCopy.swift`
mirrors the shared App Group folder into a temporary staging folder. Its
exclusion list covered caches, preferences and a pending restore, but included
the iOS container metadata file. A failed hard link fell back to copying that
file, and the resulting permission error stopped export.

The source now excludes that exact root file. The same policy preserves the
destination's metadata during restore, including when an older archive carries
its own metadata. Ordinary hidden Book files remain eligible. This failure
occurred in export staging; it did not initiate the restore/replacement path.

The existing simulator-only `--moving-copy-roundtrip` probe now first exercises
the real mirror and replacement helpers against disposable folders. It checks
that metadata is absent from export, destination metadata survives an archive
containing foreign metadata, and the vault, a nested photo and an ordinary
hidden file transfer byte for byte. It never modifies real container metadata.

Initial source-only validation: Swift frontend syntax parsing and
`git diff --check` passed. Build and device verification followed with bj's
authorization below. A simulator round trip and fresh-device migration remain
separate validation gates; never use the reader's only Book for a destructive
restore test.

## Authorized build follow-up

bj requested build/install and a fresh export on October 13. The first
executable filesystem probe exposed a second defect: `skipDescendants()` was
called for excluded files as well as directories, and Foundation's enumerator
then omitted the nested photo in a later directory. The mirror now calls it
only for excluded directories. Enumeration and required file-property errors
also propagate rather than silently permitting an incomplete export.

A macOS executable built from the production Foundation mirror/replacement
helpers and the disposable-folder probe passed: metadata excluded,
destination identity preserved, and vault, nested photo and ordinary hidden
Book file transferred byte for byte. This is filesystem-policy proof, not an
iOS archive or live Book restore. The superseded first build was stopped; the
replacement build includes both fixes.

## Rabbit result — October 13, 15:57 Eastern

- Debug build passed with all 1,558 build inputs and HEAD unchanged. The frozen
  source also stayed unchanged. The app and both extensions retained the
  existing identity and passed signature and Rabbit provisioning checks.
- In-place installation and launch passed. Rabbit's existing Book was visible.
  A separate pre-install vault transfer was blocked by the device file service;
  no pre/post vault equality claim is made.
- Glow → Bindery → Seal a Copy produced a new 403,536,371-byte `.aar` on Rabbit.
  It was copied to the Mac and extracted successfully using AppleArchive.
- The manifest identifies the existing app and App Group; the PlayerVault JSON
  and both preference domains parse. The extracted copy has 234 files,
  including 178 media files. The protected container metadata is absent.
- The verified archive is preserved with owner-only access in ignored local
  `output/book-backups/Rabbit-Book-2026-10-13-1557.aar`, with a SHA-256 and
  verification sidecar. Its digest matches the retrieved device archive.
- ReEnchanted remained running after export. No destructive restore or rename
  was performed; restoring into the new app identity remains a separate gate.

Build, source manifests, filesystem probe, installation, launch, retrieval and
archive inspection evidence are under
`/private/tmp/ReEnchanted-Rabbit-SealedCopy-Debug-20261013-lp9u2i4g`.
