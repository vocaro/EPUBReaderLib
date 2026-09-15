# Version 0.1.0 verification

The local release gate (`bash scripts/check-all.sh`) passes on the following environment:

- Xcode 27.0, build 27A266a; Apple Swift 6.4, swiftlang-6.4.0.34.1.
- macOS 27.0, build 26A428, Apple silicon.
- iOS 27.0 Simulator runtime, build 24A434.
- Corpus: original synthetic EPUB fixtures committed with the package; no inference tier is used.

| Check | Result |
| --- | --- |
| macOS parser, contracts, security and rendering | 125 tests pass, zero failures |
| iPhone 17 Pro Simulator, same suite | 123 tests pass, zero failures |
| iPad Air 13-inch (M4) Simulator, same suite | 123 tests pass, zero failures |
| ReaderSampleMac application | Build succeeds |
| ReaderSample iOS/iPadOS application | Generic iOS device build succeeds |
| Shared sample Swift sources | Compile successfully |
| Documentation examples | All four match compiled source |
| Vendored files and license texts | All 12 match pinned identities |

The two additional Mac tests verify explicit light/dark WebKit appearance. All five layout fixtures
and the shared Foliate engine contract run on all three platforms. The gate removes its dedicated
simulators after testing.

This records deterministic regression coverage and sample compilation. It does not claim hardware
performance measurements, exhaustive EPUB conformance or a completed accessibility audit. Coverage
details and reproducible commands are in [testing](testing.md).
