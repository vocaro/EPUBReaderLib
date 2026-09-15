# Version 0.2.3 verification

Environment: macOS 27.0 `26A428` arm64, Xcode 27.0 `27A266a`, iOS 27.0 Simulator `24A434`.
The corpus consists of the library's synthetic fixtures. No inference is used.
`bash scripts/check-all.sh` passes: 148 Mac tests, 146 tests on each of the iPhone 17 Pro
and iPad Air 13-inch (M4) simulators, both sample builds, five documentation snippets and
twelve vendor identities.

The dark-mode typography regression requires `Canvas`, `CanvasText` and `LinkText` system
colors. The reader retains its 48/64-point margins and automatic UIKit safe-area adjustment;
unchanged inset values are not reassigned during SwiftUI updates. Public declarations,
dependencies, capabilities and bookmark formats are unchanged.

Local log: `/private/tmp/epubreaderlib-0.2.3-full-gate.log`. Simulator logs and results are
under `.build/validation/`. The gate owns and removes its simulators.
