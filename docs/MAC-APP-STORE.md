# Mac App Store status and distribution scope

## Submission observation: 2026-10-09 18:49 KST

The console owner confirmed resubmission of **iOS 1.0(13)** and **Mac App Store 1.0(3)** in App Store Connect at 2026-10-09 18:49 KST (09:49 UTC). Both were **Waiting for Review**, with **manual release** selected. This is a dated observation, not evidence of current approval or public release. This documentation update did not recheck the console or submit either app.

The reviewer's installation route for the companion app remains **unverified**. Resubmission does not establish access to both apps. See the [launch record](LAUNCH.md) for the artifact identities and verification limits.

## Store identity and packaging

The native receiver retains `com.raccoonmerchant.ipadmirror.mac`, store version 1.0, macOS 14+, Korean/English resources, and free unlimited receiving. The iOS app uses `com.raccoonmerchant.ipadmirror` and remains a separate submitted app. Do not change the receiver bundle ID to reuse the iOS record: doing so changes the existing Mac app identity and preferences domain.

The existing Mac App Store record, matching store profile, Apple Distribution app identity and Mac Installer Distribution installer identity were used for the final Store build 3 package. No new identity, certificate, key or profile was created for that package, and none is committed. The existing notarized Developer ID ZIP uses direct distribution and is a separate artifact.

`Packaging/MacAppStore` holds a separate store Info.plist (store build 3) and App Sandbox/outgoing network entitlements. `scripts/package-mac-app-store.py qa --output /tmp/new-output` makes an isolated local sandbox QA app. The `store` mode requires caller-supplied existing app and installer signing identities and a matching OSX store profile. It rejects development/direct profiles, different bundle IDs, debugger access and expired profiles, then uses Xcode's codesign/productbuild/pkgutil tools. It does not install, notarize, upload, or modify iOS settings.

## Network-only Store transport

Store build 2 removed the unused `com.apple.security.network.server` entitlement after the build 1 review identified no incoming listener; build 3 retains that scope. `BonjourBrowser` discovers and resolves the iPhone/iPad service; `FrameReceiver` initiates an outgoing `NWConnection` and receives authenticated encrypted frames over that established connection. The Mac app does not publish a service or call listen/accept. `network.client` and App Sandbox remain enabled. The listener in `FrameReceiverIntegrationTests` is a test sender, not part of the shipped Mac target. Packaging rejects a server entitlement for this client-only target.

Historical baseline testing showed `/var/run/usbmuxd` connection succeeded without Sandbox and failed with EPERM in an App Sandbox container, even with network client/server and USB entitlements. TCP loopback communication succeeded in that same sandbox. This documented blocker for the direct USB implementation was not retried in this documentation task. No broad sandbox exception or privileged helper was added.

The approved Store build uses the compile-time flag `IPADMIRROR_MAC_APP_STORE`. It excludes USB discovery, the entire usbmuxd client, direct USB receiving and Debug USB auto-connection. The default build retains those paths. Store onboarding and empty-state copy explain the same reachable local network and local-network permission requirement in Korean/English. The authentication handshake requests the existing sender wireless capture profile; no iOS source change is needed.

Both QA and Store packaging use the flag and reject a binary containing the internal socket path. Debug QA may include a private local configuration for physical testing and record frame counts/interface type in its own sandbox container; Store mode forbids that configuration and Release excludes the QA hooks. Existing marketing images showing Direct USB Connection must not be uploaded for the network-only Store build. Take genuine connected Korean/English images after physical mirroring passes.

## Verified final artifacts and remaining checks

The final local artifacts use source commit [5ae19c0b](https://github.com/luos1/monitor/commit/5ae19c0b402128a7d4493132197e4e133f7a9ff9). The 2026-10-08 verification completed iOS Release archive/export and universal Mac Store Release compilation/signing. It independently unpacked the IPA and PKG to check signatures, profiles, versions, bundle IDs, shared groups, absence of debugger access and the Store transport entitlements. The focused development-option audit found none of its target tokens in the final iOS 13 and Mac Store 3 binaries. These checks do not prove every possible compiler encoding or runtime behavior.

The **Debug + Mac Store suite passed 26 tests with zero failures**, including encrypted JPEG loopback connection, disconnect/reconnect and authentication checks. The existing Release test target could not compile because it references DEBUG-only `UsageAccessManager.simulateConsumed`; production Release compilation and signing passed separately. Physical iPhone/iPad-to-Mac mirroring, live ads/UMP/ATT, Apple Sandbox purchase/restore and matching connected screenshots remain unverified for this pair.

The packaging receipt's earlier `Mac_App_Store_ready=false` is a local readiness record, not the latest console state. The dated console observation above supersedes the old pending-upload/submission guidance. It does not close the physical QA, screenshot or companion-installation gaps, or establish Apple approval. This documentation task did not rebuild, upload, change permissions or deploy.

## Build history and legacy direct download

iOS build **7** was the initial resubmission candidate and remains the committed project default. The final archive explicitly set `CURRENT_PROJECT_VERSION=13`, producing app and Broadcast Extension build 13. Build 7 is historical guidance, not the submitted IPA. Keep the previously submitted iOS 6 and Mac Store 2 artifacts as comparison evidence.

The published [USB Mac 1.0.0(4) release](https://github.com/luos1/monitor/releases/tag/mac-v1.0.0-build4) has recorded signing, notarization, Gatekeeper and public-download checks. It is distinct from the new network-only Store **1.0(3)** in source revision, transport and distribution. Its public ZIP still contains `ScreenshotMode`, `-SkipAds`, `-ScreenshotLocale` and `-ScreenshotDemo` tokens. Preserve it as an existing release; do not describe it as the new fixed build or an equivalent installer for Store 3.

An old review note containing the direct Mac 4 URL does not prove installation access to the new Store 3. No verified TestFlight access, installable attachment or Apple confirmation of companion access has been established for the new pair. That installation route remains unresolved after resubmission.
