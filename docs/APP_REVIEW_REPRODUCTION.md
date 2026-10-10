# App Review reproduction — candidate only

Scope: iOS 1.0 build 7 (app 6802445864) and macOS 1.0 build 3 (app 6818995921). This document is a handoff draft, not a sent message or proof of a successful build, upload, device test or App Review acceptance.

Both apps are needed. The console owner must provide a working way to obtain the matching companion before submitting. The October 8 rejection snapshot showed no approved public App Store version for either app. Recheck availability and do not claim that an unavailable public link is usable.

1. Install/open the candidate iOS sender and Mac App Store receiver on their respective devices.
2. Connect both to the same reachable local network. Client isolation or blocked Bonjour/TCP can prevent discovery. Allow local network access on both devices when requested.
3. In the sender, complete the visible usage guide. Its home screen shows a real eight-character connection code.
4. Tap the visible full-screen broadcast button. In the ReplayKit system picker select iPad Mirror Broadcast (스크린미러 방송) and confirm Start Broadcast.
5. In the Mac app, enter the code from the sender home screen and select the matching discovered device.
6. Switch to the iOS Home Screen or another app to see those screen frames in the Mac receiver. No separate built-in drawing or meeting feature is involved.
7. Use the visible stop-sharing button or system broadcast control to stop. The Mac full-window display button is enabled after a frame arrives.

The Mac App Store app receives over local networking only. It initiates a client connection; the network listener is in the iOS Broadcast Extension. A USB cable alone does not connect this store receiver. Direct-download Mac builds have a separately documented USB path and must not be substituted for an exact Mac Store test.

The iOS usage guide discloses the initial 60-minute allowance and paid options. Before that allowance expires, the home Add Time / Lifetime Access button opens the rewarded-ad, Lifetime Access, Developer Support and Restore Purchases screen. Both StoreKit products provide lifetime access; Developer Support explicitly says so. Prices come from StoreKit. No sign-in to a developer service or secret menu is required.

Ads depend on UMP consent/request eligibility and availability. ATT is optional for screen sharing. Verified lifetime access suppresses ads. Product availability depends on Apple StoreKit. Document actual unavailable-ad/product cases without claiming they are App Review-specific behavior.

All screenshot/skip-ad switches and their call sites are DEBUG-only. Release cannot enable them by command-line arguments. This deliberate development/production separation is not a reviewer-specific exception.

The existing 5.6 message has not identified a concrete feature. These changes remove an independently verified production-development switch and clarify reproduction. They do not establish the cause or guarantee review acceptance.

Before console handoff, fill in the source commit, archive/IPA/PKG hashes, build server IDs after upload, validation outputs, actual device/OS and connection evidence. Mark any device, ad or sandbox-purchase test that was not performed. Do not resubmit until final Release verification is complete.


Focused binary check after creating the final artifacts:

```sh
python3 scripts/verify-release-screenshot-options.py /absolute/path/to/final.ipa
python3 scripts/verify-release-screenshot-options.py /absolute/path/to/final.pkg
```

Record both JSON results alongside source SHA, artifact hashes and signing evidence. This check includes ARM64 and x86_64 Swift small-string immediates; ordinary `strings` output alone misses some flags. Its success is limited to the documented encodings. It cannot replace compilation or device tests.
