import Foundation
import SwiftUI

public struct EPUBEngineBookmark: Codable, Equatable, Sendable {
    public var engineID: String
    public var format: String
    public var value: String
    public init(engineID: String, format: String, value: String) {
        self.engineID = engineID; self.format = format; self.value = value
    }
}

/// Portable fields describe a reading position. `bookmark` restores an engine's precise position.
/// Engines must reject incompatible bookmarks; matching text/href is a separate, potentially approximate operation.
public struct EPUBLocation: Codable, Equatable, Sendable {
    public var publicationID: String
    public var href: String?
    public var progression: Double?
    public var title: String?
    public var quote: String?
    public var bookmark: EPUBEngineBookmark?
    public init(publicationID: String, href: String? = nil, progression: Double? = nil,
                title: String? = nil, quote: String? = nil, bookmark: EPUBEngineBookmark? = nil) {
        self.publicationID = publicationID; self.href = href; self.progression = progression
        self.title = title; self.quote = quote; self.bookmark = bookmark
    }
}

public struct EPUBSelection: Equatable, Sendable {
    public let text: String
    public let location: EPUBLocation
    public init(text: String, location: EPUBLocation) { self.text = text; self.location = location }
}

public enum EPUBReadingFlow: String, Codable, Sendable { case paginated, scrolled }

public struct EPUBReaderStyle: Equatable, Sendable {
    public var fontSize: Double
    public var isDark: Bool
    public var flow: EPUBReadingFlow
    public init(fontSize: Double = 17, isDark: Bool = false, flow: EPUBReadingFlow = .paginated) {
        self.fontSize = fontSize; self.isDark = isDark; self.flow = flow
    }
}

public enum EPUBReaderCapability: String, Hashable, Sendable {
    case pagination, scrolling, typography, selection, bookmarks, locateText, navigateHref, searchHighlight
}

public enum EPUBReaderCommand: Equatable, Sendable {
    case nextPage, previousPage
    case restore(EPUBLocation)
    case navigate(href: String)
    case locate(text: String, highlight: Bool)
    case searchHighlight(text: String)
    case clearSearch
    case style(EPUBReaderStyle)
}

public enum EPUBReaderError: Error, Equatable, Sendable {
    case unsupported(EPUBReaderCapability)
    case incompatibleLocation
    case invalidCommand(String)
    case notReady
    case closed
    case engineFailure(String)
}

public enum EPUBReaderEvent: Equatable, Sendable {
    case ready
    case relocated(EPUBLocation)
    case selectionChanged(EPUBSelection?)
    /// Display these to disclose content the engine withheld or could not render faithfully.
    case disclosure(String)
    case notice(String)
    case failed(EPUBReaderError)
}

public struct EPUBSelectionAction {
    public var title: String
    public var systemImage: String
    public var perform: @MainActor (EPUBSelection) -> Void
    public init(title: String, systemImage: String = "text.quote",
                perform: @escaping @MainActor (EPUBSelection) -> Void) {
        self.title = title; self.systemImage = systemImage; self.perform = perform
    }
}

/// An engine constructs a session using a validated publication. Implementations may use any native view technology.
@MainActor public protocol EPUBReaderEngine {
    var id: String { get }
    func makeSession(publication: EPUBPublication, selectionAction: EPUBSelectionAction?,
                     onEvent: @escaping @MainActor (EPUBReaderEvent) -> Void) throws -> any EPUBReaderSession
}

/// The host retains one session per mounted reader. Close it when the book leaves the UI.
/// `send` acknowledges submission, not navigation completion; observe events for resulting positions/errors.
/// Cancellation before submission has no effect; after submission it cannot undo a displayed page turn.
@MainActor public protocol EPUBReaderSession: AnyObject {
    var capabilities: Set<EPUBReaderCapability> { get }
    func makeView() -> AnyView
    func send(_ command: EPUBReaderCommand) async throws
    /// Idempotent. Releases engine resources and suppresses subsequent callbacks.
    func close()
}

/// Mount exactly once per session. The host supplies its own loading, error, disclosure and toolbar UI.
public struct EPUBReaderView: View {
    private let session: any EPUBReaderSession
    public init(session: any EPUBReaderSession) { self.session = session }
    public var body: some View { session.makeView() }
}
