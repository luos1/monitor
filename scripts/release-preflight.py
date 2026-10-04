#!/usr/bin/env python3
"""Read-only configuration checks; does not approve store/privacy responses."""
import json
import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
checks = []


def check(name, passed):
    checks.append({"name": name, "passed": bool(passed)})


def plist(relative):
    return plistlib.loads((ROOT / relative).read_bytes())


pad = plist("Sources/iPadMirrorPad/Info.plist")
extension = plist("Sources/iPadMirrorBroadcastExtension/Info.plist")
for name, info in (("iPad app", pad), ("broadcast extension", extension)):
    check(f"{name}: version from build settings", info["CFBundleShortVersionString"] == "$(MARKETING_VERSION)")
    check(f"{name}: build from build settings", info["CFBundleVersion"] == "$(CURRENT_PROJECT_VERSION)")
check("AdMob app ID", pad.get("GADApplicationIdentifier") == "ca-app-pub-2932716467029728~6289164999")

project = (ROOT / "iPadMirrorPad.xcodeproj/project.pbxproj").read_text()
check("app and extension default to build 4", re.findall(r"CURRENT_PROJECT_VERSION = (\d+);", project) == ["4"] * 4)
check("iOS 17 deployment target", set(re.findall(r"IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);", project)) == {"17.0"})
check("skip-ads support compiled", "ScreenshotMode.swift in Sources" in project)

pins = json.loads((ROOT / "iPadMirrorPad.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved").read_text())["pins"]
versions = {p["identity"]: p["state"]["version"] for p in pins}
check("Google Mobile Ads 12.14.0 pinned", versions.get("swift-package-manager-google-mobile-ads") == "12.14.0")
check("UMP 3.1.0 pinned", versions.get("swift-package-manager-google-user-messaging-platform") == "3.1.0")

monetization = (ROOT / "Sources/iPadMirrorShared/MonetizationConfig.swift").read_text()
debug = monetization.split("#if DEBUG", 1)[1].split("#else", 1)[0]
release = monetization.split("#else", 1)[1].split("#endif", 1)[0]
check("Debug uses Google sample ad IDs", all(i in debug for i in ("1712485313", "2934735716")) and "2932716467029728" not in debug)
check("Release uses existing ad IDs", all(i in release for i in ("6065803719", "3303909002")) and "3940256099942544" not in release)

for name, path, required in (
    ("iPad app", "Sources/iPadMirrorPad/PrivacyInfo.xcprivacy", {"CA92.1", "1C8F.1"}),
    ("broadcast extension", "Sources/iPadMirrorBroadcastExtension/PrivacyInfo.xcprivacy", {"1C8F.1"}),
    ("Mac", "Packaging/PrivacyInfo.xcprivacy", {"CA92.1"}),
):
    manifest = plist(path)
    defaults = next(t for t in manifest["NSPrivacyAccessedAPITypes"] if t["NSPrivacyAccessedAPIType"] == "NSPrivacyAccessedAPICategoryUserDefaults")
    check(f"{name}: UserDefaults reason matches container", set(defaults["NSPrivacyAccessedAPITypeReasons"]) == required)

products = json.loads((ROOT / "Packaging/Products.storekit").read_text())["products"]
check("local StoreKit IDs match existing products", {p["productID"] for p in products} == {"ipadmirror.lifetime", "ipadmirror.donation"})
check("products are non-consumable", all(p["type"] == "NonConsumable" for p in products))

print(json.dumps({"scope": "local configuration only", "checks": checks, "passed": all(c["passed"] for c in checks), "not_verified": ["privacy disclosure accuracy", "ad serving approval", "sandbox purchases", "physical iPad mirroring", "App Store submission"]}, ensure_ascii=False, indent=2))
sys.exit(0 if all(c["passed"] for c in checks) else 1)
