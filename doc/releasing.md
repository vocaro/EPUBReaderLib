# Releases and API compatibility

## Version policy

The package uses semantic version tags (`0.1.0`, without a `v` prefix). All three public products
share one version: EPUBReaderLib, EPUBReaderFoliate and EPUBReaderTesting. Consumers should select
a released version rather than the moving `main` branch.

During 0.x development, incompatible public API, minimum platform, event-contract or bookmark
format changes require a minor version increase. Patch releases preserve source compatibility and
documented behavior; compatible API additions may ship in a patch. After 1.0, breaking changes
require a major version. Internal Foliate bridge types are not public API.

The public interface is source-distributed through SwiftPM; binary ABI stability is not promised.
Persisted bookmark values are opaque and versioned independently through their `format` field.
An engine update must preserve restoration of existing supported formats or explicitly reject them
with `.incompatibleLocation`. It must never silently reinterpret another engine's bookmark.
Changing the Foliate revision requires rerunning rendering and contract tests and reviewing
bookmarks. Cross-engine conversion is not automatic.

## Release checklist

1. Update `doc/changelog.md`, README version, sample version and any affected API documentation.
2. Run `bash scripts/check-all.sh` on OS 27, including Mac, iPhone and iPad tests and sample builds.
   Preserve the logs and record the toolchain and OS builds in the release's verification note.
3. Review the public declarations against the previous tag. Use
   `swift package diagnose-api-breaking-changes <previous-tag>` as an additional source-compatibility
   check, and manually review event semantics, capabilities and persisted bookmark formats.
4. Run `python3 scripts/check-vendor.py`; inspect dependency pins, the Foliate compatibility patch
   and license notices. Do not overwrite upstream identities to conceal local modifications.
5. Commit reviewed changes, fast-forward `main`, and create an annotated version tag at that commit.
   Push the branch and tag together. Never move a published tag; fix releases with a new version.
6. Publish release notes describing observable behavior, platform requirements, validation and
   limitations. The first release has no prior tagged API baseline.

## Foliate compatibility patch

The upstream files in `Resources/epub-reader/lib` remain byte-for-byte pinned. Before serving
`epub.js`, `ReaderEPUBURLPatch` applies a small set of exact substitutions that preserve encoded
URL references and decode fragments once. Every substitution checks its occurrence count and
refuses changed source. The bootstrap decodes resource paths once at ZIP lookup. This addresses
upstream double-decoding and reserved characters without changing the host publication snapshot.

Review and rerun encoded-filename/fragment rendering tests whenever updating Foliate. The patch
is part of the MIT-licensed adapter and the served derivative retains Foliate's bundled MIT notice.
