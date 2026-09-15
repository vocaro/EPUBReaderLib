import Foundation
import ZIPFoundation

public enum Fixture {
    public static func epub(overrides: [String: String] = [:], epub2: Bool = false) throws -> Data {
        var files: [String: String] = [
            "mimetype": "application/epub+zip",
            "META-INF/container.xml": """
            <?xml version="1.0"?><container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0"><rootfiles><rootfile full-path="OPS/book.opf" media-type="application/oebps-package+xml"/></rootfiles></container>
            """,
            "OPS/book.opf": """
            <package xmlns="http://www.idpf.org/2007/opf" version="\(epub2 ? "2.0" : "3.0")" unique-identifier="uid"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>A Test Book</dc:title><dc:creator>Test Author</dc:creator><dc:language>en</dc:language><dc:identifier id="uid">test-book</dc:identifier></metadata><manifest><item id="one" href="one.xhtml" media-type="application/xhtml+xml"/><item id="two" href="two.xhtml" media-type="application/xhtml+xml"/><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" \(epub2 ? "" : "properties=\"nav\"")/><item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/></manifest><spine toc="ncx"><itemref idref="one"/><itemref idref="two"/></spine></package>
            """,
            "OPS/nav.xhtml": """
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>Contents</title></head><body><nav epub:type="toc"><ol><li><a href="one.xhtml#start">First <em>Chapter</em></a><ol><li><a href="two.xhtml">Second Chapter</a></li></ol></li></ol></nav></body></html>
            """,
            "OPS/toc.ncx": """
            <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><navMap><navPoint id="one" playOrder="1"><navLabel><text>First Chapter</text></navLabel><content src="one.xhtml#start"/><navPoint id="two" playOrder="2"><navLabel><text>Second Chapter</text></navLabel><content src="two.xhtml"/></navPoint></navPoint></navMap></ncx>
            """,
        ]
        for (name, title) in [("one", "First Chapter"), ("two", "Second Chapter")] {
            files["OPS/\(name).xhtml"] = """
            <html xmlns="http://www.w3.org/1999/xhtml"><head><title>\(title)</title></head><body><h1 id="start">\(title)</h1><p>\(name == "one" ? "Opening words are visible." : "The unique destination passage lives here.")</p>\(String(repeating: "<p>A paragraph of ordinary reading text for pagination.</p>", count: 50))</body></html>
            """
        }
        files.merge(overrides) { _, replacement in replacement }
        return try archive(files)
    }
    public static func archive(_ files: [String: String]) throws -> Data {
        let archive = try Archive(accessMode: .create)
        for name in files.keys.sorted(by: { a, b in a == "mimetype" || (b != "mimetype" && a < b) }) {
            let bytes = Data(files[name]!.utf8)
            try archive.addEntry(with: name, type: .file, uncompressedSize: Int64(bytes.count),
                                 compressionMethod: name == "mimetype" ? .none : .deflate) { position, size in
                bytes.subdata(in: Int(position)..<(Int(position) + size))
            }
        }
        return archive.data!
    }
}
