# Host integration

Keep the parsed publication and session outside SwiftUI `body`. Use a distinct view identity for
each book and close the session when the reader leaves the screen. The host owns persistence,
selection action behavior, navigation intent, toolbars, disclosures and fallback UI.

```swift
import EPUBReaderLib
import EPUBReaderFoliate
import SwiftUI

@MainActor @Observable
final class BookReader {
    var session: (any EPUBReaderSession)?
    var ready = false
    var location: EPUBLocation?
    var disclosure: String?
    var error: String?

    func open(_ publication: EPUBPublication, engine: any EPUBReaderEngine) throws {
        close()
        session = try engine.makeSession(publication: publication, selectionAction: nil) {
            [weak self] event in
            guard let self else { return }
            switch event {
            case .ready: ready = true
            case .relocated(let value): location = value
            case .disclosure(let value): disclosure = value
            case .failed(let value): error = String(describing: value)
            case .notice, .selectionChanged: break
            }
        }
    }

    func close() {
        session?.close()
        session = nil
        ready = false
        location = nil
        disclosure = nil
        error = nil
    }
}
```

Construct `BookReader` in `@State`, open the publication off the main actor, then call
`reader.open(publication, engine: FoliateEngine())`. Mount `EPUBReaderView(session: session)` when
a session exists. React to readiness before sending style, navigation or restoration commands.
For an application receiving rapid navigation changes, serialize them and associate work with
its own current document/navigation identity so old work cannot affect a newly opened book.

To store a position, encode `EPUBLocation` using `JSONEncoder`. On reopen, compare its publication
ID and send `.restore(location)` only when bookmarks are supported. If restoration reports an
incompatible location, offer an explicit section/quote fallback where supported. EPUB files that
change have a different SHA-256 identity, even when their metadata identifier is unchanged.

## Adding an engine

Implement `EPUBReaderEngine` and `EPUBReaderSession` in a separate module. Choose a stable engine
ID and versioned bookmark format. Return native SwiftUI content or wrap your toolkit's native view
in a representable. Adapt its input events to the public value types and expose only capabilities
that work. Refuse unsupported commands, check task cancellation before effects, and suppress all
callbacks after close. A toolkit with different location semantics keeps them inside its bookmark.

The protocol permits Readium or epub.js adapters; they require their own implementation, platform
support checks, licensing review and tests. The initial package ships only Foliate.
