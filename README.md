# EPUBReaderLib

A Swift library for parsing and reading EPUBs with pluggable rendering engines.

EPUBReaderLib provides publication metadata, reading order, nested contents and resource access,
plus an engine-neutral SwiftUI reader interface. **EPUBReaderFoliate** supplies the initial
[foliate-js](https://github.com/johnfactotum/foliate-js) engine. A replacement engine can use native
views, another JavaScript library or a different rendering toolkit.

Requires Swift 6.2, iOS/iPadOS 17+ or macOS 14+. MIT licensed.

## Installation

Add `https://github.com/vocaro/EPUBReaderLib.git` to your Swift package dependencies. Link
`EPUBReaderLib` for publication parsing and reader contracts; also link `EPUBReaderFoliate` to
use the bundled engine. No JavaScript build step or asset download is required.

```swift
import EPUBReaderLib

// Open off the main actor for large books; cancellation is checked during archive expansion.
let publication = try EPUBPublication.open(at: bookURL)
print(publication.metadata.title)
for chapter in publication.spine {
    let bytes = try publication.data(for: chapter.resource)
    // XHTML, images, stylesheets and other publication resources remain available to the host.
}
```

Create and retain a reading session on the main actor, then mount `EPUBReaderView(session:)`:

```swift
import EPUBReaderFoliate

let engine: any EPUBReaderEngine = FoliateEngine()
let session = try engine.makeSession(
    publication: publication,
    selectionAction: EPUBSelectionAction(title: "Use passage") { selection in
        print(selection.text)
    },
    onEvent: { event in
        // Present loading/errors/disclosures, save positions, or handle selection changes.
    }
)
// In your SwiftUI view body:
EPUBReaderView(session: session)
```

After `.ready`, send commands with `try await session.send(...)`. For example,
`.navigate(href: publication.tableOfContents[0].href!)`, `.nextPage`,
`.locate(text: "a passage", highlight: true)` or `.style(.init(fontSize: 20, isDark: true))`.
Check `session.capabilities` before offering optional features. Retain the session outside `body`,
mount it once, and call `session.close()` when leaving the book. See the
[host integration guide](doc/integration.md) for a complete lifecycle example.

## Features and boundaries

- EPUB 2 OPF/NCX and EPUB 3 OPF/navigation parsing, metadata, cover resource and reading order.
- Bounded archive import, path checks, CRC validation and an immutable source snapshot.
- Foliate pagination, scrolling, typography, local contents navigation, passage location,
  search highlighting, text selection, position events and precise engine-specific restoration.
- SwiftUI on iPhone, iPad and native Mac; keyboard and accessibility page-turn actions.
- No accounts, networking service, library database, app toolbar or persistence policy.

This is an initial release, not an EPUB conformance validator. See
[architecture and limitations](doc/architecture.md) for supported inputs, security boundaries and
bookmark portability. Readium and epub.js adapters are possible extensions, not included products.

## Verification

```sh
swift test
python3 scripts/check-vendor.py
```

Tests include parser failures and limits, a native SwiftUI test engine, bridge/routing security,
WebKit hint filtering and a mounted macOS reader journey. Live macOS tests create a temporary
window and require a graphical login. They do not require UI automation or model inference.

## Licenses

The library is MIT licensed. ZIPFoundation is MIT. Bundled foliate-js is MIT and its zip.js bundle
is BSD-3-Clause. Upstream license texts ship in the resource bundle; their pinned identities are
in [the vendor manifest](doc/vendor-manifest.json). See [third-party notices](doc/third-party-notices.md).
