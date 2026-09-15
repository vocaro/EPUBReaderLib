# Architecture

`EPUBReaderLib` owns immutable publications and public reader protocols. It imports Foundation,
CryptoKit, ZIPFoundation and SwiftUI, and has no dependency on WebKit or Foliate. Parsing does not
create a view or JavaScript context. `EPUBReaderFoliate` owns the WebKit adapter, validated message
bridge, custom URL scheme and bundled foliate-js assets. Nothing in the engine-neutral interface
requires a web view, JavaScript, a DOM node or EPUB CFI.

## Publication model

Opening copies the archive into a bounded snapshot and checks every archive entry before returning.
Archive paths are decoded ZIP paths; manifest/navigation hrefs are URL references. The parser
resolves references relative to the containing OPF/navigation document. It exposes metadata,
manifest resources, linear/nonlinear spine entries, cover and nested contents. Reading resource
bytes does not execute document content. XML expansion and external entity resolution are refused.

Default limits are 256 MiB compressed, 512 MiB expanded, 32 MiB per resource, 20,000 entries and
4 MiB per XML document, with depth/node limits. Hosts may lower or raise import limits. Resources
are retained in memory; the total memory footprint includes both compressed and expanded data.
For large books, open on a background task. Task cancellation is checked while expanding entries.
A host granting security-scoped file access must keep access active until opening completes.

Inputs need an EPUB mimetype, a container rootfile and a nonempty resolvable spine. Remote manifest
resources, unsupported encryption, archive traversal, duplicate paths, symlinks, entity declarations
and malformed metadata/navigation XML fail explicitly. The package does not repair malformed EPUBs,
validate the full EPUB specification, synthesize page numbers or provide DRM support. Standard IDPF
and Adobe font obfuscation are decoded for resource access; Foliate receives the original archive. Media overlays,
TTS, annotation persistence and full-text search result enumeration are outside the initial API.

## Engine contract

An engine constructs a session with a publication, optional selection action and event callback.
The session creates an `AnyView`, accepts typed commands, advertises capabilities and closes its
resources. A native implementation can return a SwiftUI/AppKit/UIKit-backed view without WebKit;
`NativeEngineTests` implements this using only SwiftUI and the public contract.

`send` acknowledges command submission, not successful navigation or paint completion. Later
position/error events describe effects. Cancellation before submission throws `CancellationError`;
a submitted page turn cannot be undone by cancelling its caller. `close` is idempotent, disables
callbacks and releases renderer references. Hosts serialize commands whose order matters and close
sessions explicitly. Views returned by a closed session contain no reader.

Portable location fields contain the publication fingerprint, section href, text quote and overall
progression when known. Exact restoration uses a separately tagged engine bookmark. Foliate's
`epubcfi-v1` bookmark is accepted only for the same publication fingerprint and engine identifier.
Other engines may offer approximate navigation by href or quote; this is not automatic bookmark
conversion. The package does not promise cross-engine page, search or selection equivalence.

## Foliate isolation

The adapter vendors a pinned upstream import closure. Its scheme handler serves only the host page,
bootstrap module, exact allowlisted assets and the publication snapshot. The WebKit data store is
nonpersistent. Content Security Policy refuses remote origins and book scripts; book images, CSS,
fonts and media can use allowed local/blob/data resources. The bootstrap removes connection hints
before parsing them into rendered sections and reports fidelity reductions to the host. Navigation
outside the reader's allowed schemes, new windows and document-driven dialogs are refused.

Selection and location messages are length/range checked and only accepted from the main frame.
Command arguments use JSON serialization. The package never fetches remote book resources or opens
external links. Sandboxed macOS hosts need `com.apple.security.network.client` for WebKit's helper
processes to launch, even with remote document access prohibited. This entitlement does not change
the adapter's navigation or content policy.

The engine uses foliate-js's EPUB renderer for both reflowable and fixed-layout publications. The
synthetic mounted-reader regression exercises reflowable EPUB; fixed-layout/media/vertical-script
coverage is not a general fidelity guarantee. Host apps must present `.disclosure` and `.failed`
events appropriately and may provide their own fallback.
