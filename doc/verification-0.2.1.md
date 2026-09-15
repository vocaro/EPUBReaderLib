# Version 0.2.1 verification

The full local gate passes on Xcode 27.0 `27A266a`, macOS 27.0 `26A428` arm64 and iOS 27.0
Simulator `24A434`, against the package's original synthetic EPUB fixtures. No inference is used.

- Mac: 140 tests pass (38 core, 102 adapter).
- iPhone 17 Pro and iPad Air 13-inch (M4) simulators: 138 tests pass each (38 core, 100 adapter).
- Both sample applications build; all five documentation examples and twelve vendor identities pass.

Text extraction has 15 tests per platform. The embedded-SVG regression fails against 0.2.0 because
script/style contents enter the text, and passes with the patch while keeping the diagram label.
No public API signatures, dependency pins, reader behavior or bookmark formats change.
The original 0.2.0 tag and verification record remain intact.

Logs are local at `/private/tmp/epub-text-library-final-gate.log` and `.build/validation/`.
The [text API](text-extraction.md) defines supported content and limits; the
[0.2.0 record](verification-0.2.0.md) describes the initial extraction coverage.
