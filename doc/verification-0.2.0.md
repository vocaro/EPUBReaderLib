# Version 0.2.0 verification

Environment: Xcode 27.0 `27A266a`, macOS 27.0 `26A428` arm64, iOS 27.0 Simulator runtime
`24A434`. Corpus: the package's original synthetic EPUB fixtures. Tier: deterministic,
non-generative. `bash scripts/check-all.sh` passes.

| Check | Result |
| --- | --- |
| macOS parsing, text extraction, engine contracts and rendering | 139 passed |
| iPhone 17 Pro Simulator | 137 passed |
| iPad Air 13-inch (M4) Simulator | 137 passed |
| macOS and generic iOS sample applications | Both build |
| Documentation examples | Five match compiled sample sources |
| Vendored resources and licenses | All 12 identities match |

The new API contributes 14 tests on each platform. These cover section identity and order,
head/body separation, inline/block text, Unicode word joiners, entities, CDATA, semantic roles and
namespace aliases, empty/nonlinear sections, encoded links, malformed content, UTF-16, limits and
cancellation. Three generic StudyWright head/title/script extraction regressions are represented
by the upstream cases; consumer policy and end-to-end citation tests remain in StudyWright.

The declarations add text-extraction types and one publication method; no existing public signature,
engine event, capability or bookmark contract changes. The parser shares its existing declaration
safety policy with the new API. No Foliate assets or third-party dependency versions change.
Apple's shipped libxml2 streaming reader supplies Unicode-preserving XHTML text.

Logs are local at `/private/tmp/epub-text-library-gate.log` and `.build/validation/`.
The gate creates and removes its own simulators. These results establish regression coverage,
not full EPUB conformance, physical-device performance or browser-computed text fidelity.
