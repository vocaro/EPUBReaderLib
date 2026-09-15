import CryptoKit
import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import ZIPFoundation

/// Failures opening a publication. Rendering failures belong to `EPUBReaderError`.
public enum EPUBPublicationError: Error, Equatable, Sendable {
    case invalidArchive(String)
    case unsafePath(String)
    case limitExceeded(String)
    case missingResource(String)
    case invalidXML(String)
    case unsupportedEncryption
}

public struct EPUBImportLimits: Sendable {
    public var archiveBytes: Int = 256 * 1024 * 1024
    public var resourceBytes: Int = 32 * 1024 * 1024
    public var expandedBytes: Int = 512 * 1024 * 1024
    public var entryCount: Int = 20_000
    public var xmlBytes: Int = 4 * 1024 * 1024
    public init() {}
}

public struct EPUBMetadata: Equatable, Sendable {
    public let title: String
    public let authors: [String]
    public let languages: [String]
    public let identifiers: [String]
}

public struct EPUBResource: Equatable, Sendable, Identifiable {
    public let id: String
    /// Decoded archive path, relative to the archive root.
    public let path: String
    /// URL-encoded archive-relative reference for reader navigation. `path` is for byte access.
    public var href: String {
        path.addingPercentEncoding(withAllowedCharacters:
            .urlPathAllowed.subtracting(CharacterSet(charactersIn: "#%?")))!
    }
    public let mediaType: String
    public let properties: Set<String>
}

public enum EPUBLayout: String, Sendable { case reflowable, prePaginated }

public struct EPUBSpineItem: Equatable, Sendable {
    public let resource: EPUBResource
    public let isLinear: Bool
    public let layout: EPUBLayout
}

public struct EPUBNavigationItem: Equatable, Sendable {
    public let title: String
    /// Archive-relative URL reference; may include a fragment.
    public let href: String?
    public let children: [EPUBNavigationItem]
}

/// An immutable snapshot. Parsing and every engine read the same bytes even if the source file changes.
/// Opening validates ZIP paths, declared sizes, CRCs and actual expanded sizes before returning.
public struct EPUBPublication: Sendable {
    public let id: String
    public let metadata: EPUBMetadata
    public let resources: [EPUBResource]
    public let spine: [EPUBSpineItem]
    public let tableOfContents: [EPUBNavigationItem]
    public let cover: EPUBResource?
    /// Original EPUB bytes, for engines with their own container implementation.
    public let archiveData: Data
    private let contents: [String: Data]

    public func data(for resource: EPUBResource) throws -> Data {
        try data(at: resource.path)
    }

    /// Reads a decoded archive path, never a file-system path or remote URL.
    public func data(at path: String) throws -> Data {
        guard let data = contents[path] else { throw EPUBPublicationError.missingResource(path) }
        return data
    }

    /// Synchronous for CLI/background use. Call off the main actor for large books.
    /// `onProgress` receives cumulative expanded bytes on the importing thread; keep it brief.
    public static func open(at url: URL, limits: EPUBImportLimits = .init(),
                            onProgress: (@Sendable (Int) -> Void)? = nil) throws -> Self {
        guard url.isFileURL else { throw EPUBPublicationError.unsafePath(url.absoluteString) }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        guard limits.archiveBytes > 0, limits.archiveBytes < Int.max else {
            throw EPUBPublicationError.limitExceeded("archiveBytes")
        }
        let data = try handle.read(upToCount: limits.archiveBytes + 1) ?? Data()
        return try open(data: data, limits: limits, onProgress: onProgress)
    }

    /// `onProgress` receives cumulative expanded bytes synchronously, after each decoded chunk.
    public static func open(data: Data, limits: EPUBImportLimits = .init(),
                            onProgress: (@Sendable (Int) -> Void)? = nil) throws -> Self {
        try Task.checkCancellation()
        guard limits.archiveBytes > 0, data.count <= limits.archiveBytes,
              limits.resourceBytes > 0, limits.expandedBytes > 0, limits.entryCount > 0,
              limits.xmlBytes > 0 else { throw EPUBPublicationError.limitExceeded("import limits") }
        let archive: Archive
        do { archive = try Archive(data: data, accessMode: .read) }
        catch { throw EPUBPublicationError.invalidArchive(String(describing: error)) }
        var contents: [String: Data] = [:]
        var paths = Set<String>()
        var total = 0
        for entry in archive {
            try Task.checkCancellation()
            let path = entry.path
            guard isSafePath(path, directory: entry.type == .directory), entry.type != .symlink else {
                throw EPUBPublicationError.unsafePath(path)
            }
            guard paths.insert(path).inserted else {
                throw EPUBPublicationError.invalidArchive("Duplicate path: \(path)")
            }
            guard paths.count <= limits.entryCount else { throw EPUBPublicationError.limitExceeded("entry count") }
            guard entry.uncompressedSize <= UInt64(limits.resourceBytes),
                  entry.uncompressedSize <= UInt64(limits.expandedBytes - total) else {
                throw EPUBPublicationError.limitExceeded(path)
            }
            if entry.type == .directory { continue }
            var bytes = Data()
            let crc = try archive.extract(entry, bufferSize: 32_768) { chunk in
                try Task.checkCancellation()
                guard chunk.count <= limits.resourceBytes - bytes.count,
                      chunk.count <= limits.expandedBytes - total else {
                    throw EPUBPublicationError.limitExceeded(path)
                }
                bytes.append(chunk)
                total += chunk.count
                onProgress?(total)
                try Task.checkCancellation()
            }
            guard crc == entry.checksum else { throw EPUBPublicationError.invalidArchive("CRC: \(path)") }
            contents[path] = bytes
        }
        guard contents["mimetype"] == Data("application/epub+zip".utf8) else {
            throw EPUBPublicationError.invalidArchive("Missing EPUB mimetype")
        }
        func xml(_ path: String) throws -> XMLNode {
            guard let bytes = contents[path] else { throw EPUBPublicationError.missingResource(path) }
            guard bytes.count <= limits.xmlBytes else { throw EPUBPublicationError.limitExceeded(path) }
            return try XMLTree.parse(bytes, path: path)
        }
        let container = try xml("META-INF/container.xml")
        guard let opfPath = container.descendants("rootfile").first?.attributes["full-path"],
              isSafePath(opfPath) else { throw EPUBPublicationError.invalidXML("container rootfile") }
        let opf = try xml(opfPath)
        guard opf.name == "package", let manifest = opf.children.first(where: { $0.name == "manifest" }),
              let spineNode = opf.children.first(where: { $0.name == "spine" }) else {
            throw EPUBPublicationError.invalidXML("OPF package, manifest or spine")
        }
        let metadataNode = opf.children.first { $0.name == "metadata" }
        func values(_ name: String) -> [String] {
            metadataNode?.children.filter { $0.name == name }.map(\.text).filter { !$0.isEmpty } ?? []
        }
        if contents["META-INF/encryption.xml"] != nil {
            let encryption = try xml("META-INF/encryption.xml")
            let identifier = metadataNode?.children.first {
                $0.name == "identifier" && $0.attributes["id"] == opf.attributes["unique-identifier"]
            }?.text ?? ""
            for encrypted in encryption.descendants("EncryptedData") {
                guard let algorithm = encrypted.descendants("EncryptionMethod").first?.attributes["Algorithm"],
                      let uri = encrypted.descendants("CipherReference").first?.attributes["URI"],
                      let path = uri.removingPercentEncoding, isSafePath(path), var bytes = contents[path] else {
                    throw EPUBPublicationError.unsupportedEncryption
                }
                let key: [UInt8]
                let prefixLength: Int
                switch algorithm {
                case "http://www.idpf.org/2008/embedding":
                    let normalized = identifier.filter { !$0.isWhitespace }
                    guard !normalized.isEmpty else { throw EPUBPublicationError.unsupportedEncryption }
                    key = Array(Insecure.SHA1.hash(data: Data(normalized.utf8)))
                    prefixLength = 1040
                case "http://ns.adobe.com/pdf/enc#RC":
                    let value = identifier.replacingOccurrences(of: "urn:uuid:", with: "")
                    guard let uuid = UUID(uuidString: value) else { throw EPUBPublicationError.unsupportedEncryption }
                    var raw = uuid.uuid
                    key = withUnsafeBytes(of: &raw) { Array($0) }
                    prefixLength = 1024
                default: throw EPUBPublicationError.unsupportedEncryption
                }
                for index in 0..<min(prefixLength, bytes.count) { bytes[index] ^= key[index % key.count] }
                contents[path] = bytes
            }
            guard !encryption.descendants("EncryptedData").isEmpty else {
                throw EPUBPublicationError.unsupportedEncryption
            }
        }
        var resources: [EPUBResource] = []
        var byID: [String: EPUBResource] = [:]
        for item in manifest.children where item.name == "item" {
            guard let id = item.attributes["id"], !id.isEmpty, byID[id] == nil,
                  let href = item.attributes["href"], let type = item.attributes["media-type"] else {
                throw EPUBPublicationError.invalidXML("Manifest item")
            }
            let reference = try resolve(href, relativeTo: opfPath)
            let path = String(reference.split(separator: "#", maxSplits: 1)[0]).removingPercentEncoding ?? reference
            guard contents[path] != nil else { throw EPUBPublicationError.missingResource(path) }
            let resource = EPUBResource(id: id, path: path, mediaType: type,
                properties: Set((item.attributes["properties"] ?? "").split(whereSeparator: \.isWhitespace).map(String.init)))
            resources.append(resource)
            byID[id] = resource
        }
        let fixedLayout = metadataNode?.children.contains {
            $0.name == "meta" && $0.attributes["property"] == "rendition:layout" && $0.text == "pre-paginated"
        } ?? false
        let spine = try spineNode.children.filter { $0.name == "itemref" }.map { item in
            guard let ref = item.attributes["idref"], let resource = byID[ref] else {
                throw EPUBPublicationError.invalidXML("Spine idref")
            }
            let properties = Set((item.attributes["properties"] ?? "").split(whereSeparator: \.isWhitespace))
            let fixed = properties.contains("rendition:layout-pre-paginated") ||
                (fixedLayout && !properties.contains("rendition:layout-reflowable"))
            return EPUBSpineItem(resource: resource, isLinear: item.attributes["linear"] != "no",
                                layout: fixed ? .prePaginated : .reflowable)
        }
        guard !spine.isEmpty else { throw EPUBPublicationError.invalidXML("Empty spine") }
        var toc: [EPUBNavigationItem] = []
        if let nav = resources.first(where: { $0.properties.contains("nav") }) {
            let root = try xml(nav.path)
            if let node = root.descendants("nav").first(where: {
                ($0.attributes["type"] ?? "").split(separator: " ").contains("toc")
            }) {
                func items(_ node: XMLNode) throws -> [EPUBNavigationItem] {
                    try node.children.filter { $0.name == "li" }.map { li in
                        let label = li.children.first { $0.name == "a" || $0.name == "span" }
                        let href = try label?.attributes["href"].map { try resolve($0, relativeTo: nav.path) }
                        let children = try li.children.filter { $0.name == "ol" }.flatMap { try items($0) }
                        return EPUBNavigationItem(title: label?.text ?? "", href: href, children: children)
                    }
                }
                toc = try node.children.filter { $0.name == "ol" }.flatMap { try items($0) }
            }
        } else if let ncxID = spineNode.attributes["toc"], let ncx = byID[ncxID] {
            let root = try xml(ncx.path)
            func points(_ parent: XMLNode) throws -> [EPUBNavigationItem] {
                try parent.children.filter { $0.name == "navPoint" }.map { point in
                    let title = point.children.first { $0.name == "navLabel" }?.text ?? ""
                    let href = try point.children.first { $0.name == "content" }?.attributes["src"].map {
                        try resolve($0, relativeTo: ncx.path)
                    }
                    return EPUBNavigationItem(title: title, href: href, children: try points(point))
                }
            }
            if let map = root.descendants("navMap").first { toc = try points(map) }
        }
        let coverID = metadataNode?.children.first {
            $0.name == "meta" && $0.attributes["name"] == "cover"
        }?.attributes["content"]
        return Self(id: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            metadata: EPUBMetadata(title: values("title").first ?? "", authors: values("creator"),
                                   languages: values("language"), identifiers: values("identifier")),
            resources: resources, spine: spine, tableOfContents: toc,
            cover: resources.first { $0.properties.contains("cover-image") } ?? coverID.flatMap { byID[$0] },
            archiveData: data, contents: contents)
    }

    private static func isSafePath(_ path: String, directory: Bool = false) -> Bool {
        let path = directory && path.hasSuffix("/") ? String(path.dropLast()) : path
        return !path.isEmpty && !path.contains("\\") && !path.contains(":") && !path.contains("\0")
            && path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy {
                !$0.isEmpty && $0 != "." && $0 != ".."
            }
    }

    /// Resolve local EPUB references with a synthetic origin; escape the archive root only by failing.
    private static func resolve(_ href: String, relativeTo path: String) throws -> String {
        guard let decoded = href.removingPercentEncoding, !decoded.contains("\\"),
              !decoded.contains("\0"), !decoded.hasPrefix("/"),
              URLComponents(string: href)?.scheme == nil,
              URLComponents(string: href)?.query == nil else { throw EPUBPublicationError.unsafePath(href) }
        let rawParts = href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let parts = rawParts.map { String($0).removingPercentEncoding! }
        var stack = path.split(separator: "/").dropLast().map(String.init)
        if parts[0].isEmpty { stack.append(String(path.split(separator: "/").last!)) }
        else {
            for part in parts[0].split(separator: "/") {
                if part == "." { continue }
                if part == ".." {
                    guard !stack.isEmpty else { throw EPUBPublicationError.unsafePath(href) }
                    stack.removeLast()
                } else { stack.append(String(part)) }
            }
        }
        let result = stack.joined(separator: "/")
        guard isSafePath(result) else { throw EPUBPublicationError.unsafePath(href) }
        let encoded = result.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "#%?")))!
        let fragment = parts.count == 2 ? "#" + parts[1].addingPercentEncoding(
            withAllowedCharacters: .urlFragmentAllowed.subtracting(CharacterSet(charactersIn: "#%")))! : ""
        return encoded + fragment
    }
}

private final class XMLNode {
    let name: String
    let attributes: [String: String]
    var children: [XMLNode] = []
    var content = ""
    var text: String { content.trimmingCharacters(in: .whitespacesAndNewlines) }
    init(_ name: String, _ attributes: [String: String]) { self.name = name; self.attributes = attributes }
    func descendants(_ name: String) -> [XMLNode] {
        children.flatMap { ($0.name == name ? [$0] : []) + $0.descendants(name) }
    }
}

private final class XMLTree: NSObject, XMLParserDelegate {
    var stack: [XMLNode] = []
    var root: XMLNode?
    var count = 0
    static func parse(_ data: Data, path: String) throws -> XMLNode {
        // Removing zero bytes also catches ASCII declaration tokens in UTF-16/32 XML.
        let declarationProbe = String(decoding: data.filter { $0 != 0 }, as: UTF8.self).uppercased()
        guard !declarationProbe.contains("<!ENTITY"),
              declarationProbe.range(of: "<!DOCTYPE[^>]*\\[", options: .regularExpression) == nil
        else { throw EPUBPublicationError.invalidXML(path) }
        let delegate = XMLTree()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        parser.delegate = delegate
        guard parser.parse(), let root = delegate.root else { throw EPUBPublicationError.invalidXML(path) }
        return root
    }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        count += 1
        guard stack.count < 64, count <= 100_000 else { parser.abortParsing(); return }
        let local = String(name.split(separator: ":").last ?? Substring(name))
        var attrs: [String: String] = [:]
        for (key, value) in attributes { attrs[String(key.split(separator: ":").last!)] = value }
        let node = XMLNode(local, attrs)
        if let parent = stack.last { parent.children.append(node) } else { root = node }
        stack.append(node)
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { stack.last?.content += string }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        stack.last?.content += String(decoding: CDATABlock, as: UTF8.self)
    }
    func parser(_ parser: XMLParser, didEndElement: String, namespaceURI: String?, qualifiedName: String?) {
        let node = stack.popLast()
        if let node { stack.last?.content += node.content }
    }
}
