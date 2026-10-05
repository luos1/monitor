# AGENTS.md

## Cursor Cloud specific instructions

### This is an Apple-platform-only project — it cannot be built, tested, or run on Linux Cloud Agents

`iPadMirror` (아이패드미러) is a native macOS + iPadOS Swift/SwiftUI app that mirrors an
iPad screen to a Mac. Every buildable target depends on Apple-proprietary frameworks
that **do not exist on Linux** and cannot be installed there:

- `Sources/iPadMirrorMac` (the SwiftPM executable + test target): `SwiftUI`, `AppKit`,
  `ImageIO`, `Network`, `CryptoKit`, `Combine`, `Darwin`.
- `Sources/iPadMirrorShared`: `SwiftUI`, `StoreKit`.
- `Sources/iPadMirrorPad` / `Sources/iPadMirrorBroadcastExtension` (iPad app + broadcast
  extension): `UIKit`, `ReplayKit`, `AppTrackingTransparency`, `GoogleMobileAds`.

Because of this, the Cloud Agent Linux VM **cannot** run the documented dev workflow.
Installing the swift.org Linux toolchain does **not** help: `swift build` / `swift test`
fail immediately with `error: no such module 'SwiftUI'` (verified with Swift 6.0.3 on
Ubuntu 24.04). There is no cross-platform (Foundation-only) subset that compiles in
isolation, since the pure-logic files live in modules that import `SwiftUI`.

Do not spend time trying to install Apple SDKs or a Swift toolchain on Linux to build
this repo — it is a hard platform limitation, not a missing dependency.

### Where the app actually builds/tests/runs (requires macOS + Xcode)

Use a macOS machine with Xcode 16.4 (this is exactly what CI does — see
`.github/workflows/ci.yml`, which runs on `macos-15`). Standard commands are documented
in `README.md`:

- Mac app tests: `swift test`
- Package the Mac app: `./scripts/package-mac-app.sh release`
- iPad app: open `iPadMirrorPad.xcodeproj` in Xcode and build/run
  (`xcodebuild -project iPadMirrorPad.xcodeproj -scheme iPadMirrorPad ...`).

Runtime also requires two real Apple devices working together (an iPad broadcasting via
ReplayKit and a Mac receiving over the local network / USB), so full end-to-end
functionality cannot be exercised headlessly regardless of OS.
