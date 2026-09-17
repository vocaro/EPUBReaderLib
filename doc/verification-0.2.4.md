# Version 0.2.4 verification

Environment: macOS 27.0 `26A428` arm64, Xcode 27.0 `27A266a`, iOS 27.0 Simulator `24A434`.
The corpus consists of the library's synthetic fixtures. No inference is used.
`bash scripts/check-all.sh` passes: 150 Mac tests, 147 tests on each of the iPhone 17 Pro
and iPad Air 13-inch (M4) simulators, both sample builds, five documentation snippets and
twelve vendor identities.

On macOS the web view marks the reader page with `sw-macos` through a main-frame user script
injected at document start, and bootstrap.js does not create the continuous-scroll edge fade.
`testScrolledEdgeFadeIsDrawnOnIOSOnly` checks the live page in scrolled flow: no strips on Mac,
both strips and no mark on iPhone and iPad. It fails on Mac without the bootstrap.js gate.
The Mac sample in scrolled flow shows full-strength text at both edges and no bottom gap; the
Mac web view still sets no fixed content inset. iOS insets, edge effects and fade are unchanged.
Public declarations, dependencies, capabilities and bookmark formats are unchanged.

Simulator logs and results are under `.build/validation/`. The gate owns and removes its simulators.
