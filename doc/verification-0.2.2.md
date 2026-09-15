# Version 0.2.2 verification

Environment: macOS 27.0 `26A428` arm64, Xcode 27.0 `27A266a`, iOS 27.0 Simulator `24A434`.
The corpus consists of the library's original synthetic fixtures. No inference is used.
`bash scripts/check-all.sh` passes.

- Mac: 148 tests pass (46 core, 102 adapter).
- iPhone 17 Pro and iPad Air 13-inch (M4) simulators: 146 tests pass each (46 core, 100 adapter).
- Both sample applications build; all five documentation snippets and twelve vendor identities pass.
- Eight new XML parsing tests cover navigation role whitespace, comments, CDATA, processing
  instructions, quoted external identifiers, malformed boundaries and actual internal subsets.
- Public parsing/extraction cases exercise UTF-8, UTF-16, UTF-16BE, UTF-16LE and UTF-32BE.
  UTF-32LE declaration screening is tested directly, with and without its BOM; the host XML
  parser does not accept UTF-32LE, so that check makes no publication-opening support claim.
- `swift package diagnose-api-breaking-changes 0.2.1` reports no breaking changes in
  EPUBReaderLib, EPUBReaderFoliate or EPUBReaderTesting. Manual review confirms no changes to
  public declarations, capabilities, events, dependencies or persisted bookmark formats.

The original issue reproductions fail on 0.2.1: three navigation separator assertions return
empty contents, one harmless OPF comment throws `invalidXML`, and one harmless CDATA example
throws `malformedContent`. The same cases pass with this patch. Independent Foundation parser
controls accept both harmless XML inputs. Real entity declarations and internal DTD subsets
remain rejected by both publication parsing and section text extraction.

Logs are local at `/private/tmp/epubreaderlib-bug-reproductions-final.log`,
`/private/tmp/epubreaderlib-bug-fixes-safety-final.log`,
`/private/tmp/epubreaderlib-0.2.2-full-gate.log`, `/private/tmp/epubreaderlib-0.2.2-api-check.log`
and `.build/validation/`. The full gate owns and removes its simulators. These checks establish
regression coverage; they do not establish complete EPUB conformance or physical-device performance.
