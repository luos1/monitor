#!/usr/bin/env python3
"""Read-only configuration checks; does not approve store/privacy responses."""
import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
checks = []


def check(name, passed):
    checks.append({"name": name, "passed": bool(passed)})


def plist(relative):
    return plistlib.loads((ROOT / relative).read_bytes())


def without_debug_blocks(source):
    """Keep both sides of unknown conditions; remove only DEBUG-only code."""
    stack = []
    output = []
    for line in source.splitlines():
        directive = re.match(r"\s*#(if|elseif|else|endif)\b\s*(.*)", line)
        if directive:
            kind, expression = directive.groups()
            if kind == "if":
                known = False if expression == "DEBUG" else True if expression == "!DEBUG" else None
                stack.append({"known": known, "active": known is not False})
            elif kind == "else":
                stack[-1]["active"] = stack[-1]["known"] is not True
            elif kind == "elseif":
                stack[-1]["active"] = expression != "DEBUG"
            else:
                stack.pop()
            continue
        if all(frame["active"] for frame in stack):
            output.append(line)
    if stack:
        raise ValueError("Unclosed Swift compilation condition")
    return "\n".join(output)


pad = plist("Sources/iPadMirrorPad/Info.plist")
extension = plist("Sources/iPadMirrorBroadcastExtension/Info.plist")
for name, info in (("iPad app", pad), ("broadcast extension", extension)):
    check(f"{name}: version from build settings", info["CFBundleShortVersionString"] == "$(MARKETING_VERSION)")
    check(f"{name}: build from build settings", info["CFBundleVersion"] == "$(CURRENT_PROJECT_VERSION)")
check("AdMob app ID", pad.get("GADApplicationIdentifier") == "ca-app-pub-2932716467029728~6289164999")

project = (ROOT / "iPadMirrorPad.xcodeproj/project.pbxproj").read_text()
check("app and extension default to build 7", re.findall(r"CURRENT_PROJECT_VERSION = (\d+);", project) == ["7"] * 4)
check("app and extension retain store version 1.0", re.findall(r"MARKETING_VERSION = ([\d.]+);", project) == ["1.0"] * 4)
mac_info = plist("Packaging/MacAppStore/Info.plist")
check("Mac Store version 1.0 build 3", (mac_info["CFBundleShortVersionString"], mac_info["CFBundleVersion"]) == ("1.0", "3"))
mac_entitlements = plist("Packaging/MacAppStore/App.entitlements")
check("Mac Store client-only sandbox", mac_entitlements.get("com.apple.security.app-sandbox") is True and mac_entitlements.get("com.apple.security.network.client") is True and "com.apple.security.network.server" not in mac_entitlements)
check("iOS 17 deployment target", set(re.findall(r"IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);", project)) == {"17.0"})
check("Debug screenshot helper remains available to UI tests", "ScreenshotMode.swift in Sources" in project)
release_sources = [(p, without_debug_blocks(p.read_text())) for p in (ROOT / "Sources").rglob("*.swift")]
check("Release contains no screenshot-option implementation or callers", all(not any(token in text for token in ("ScreenshotMode", "-ScreenshotDemo", "-SkipAds", "-ScreenshotLocale", "-ResetScreenshotOnboarding", "-ConsentTestEEA", "-PhysicalQAConfig")) for _, text in release_sources))

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
privacy_validation = subprocess.run([sys.executable, str(ROOT / "scripts/validate-privacy-manifests.py")], capture_output=True, text=True)
check("privacy manifest types and TN3181 tracking relationships", privacy_validation.returncode == 0)
check("local StoreKit IDs match existing products", {p["productID"] for p in products} == {"ipadmirror.lifetime", "ipadmirror.donation"})
check("products are non-consumable", all(p["type"] == "NonConsumable" for p in products))

print(json.dumps({"scope": "local configuration only", "checks": checks, "passed": all(c["passed"] for c in checks), "not_verified": ["privacy disclosure accuracy", "ad serving approval", "sandbox purchases", "physical iPad mirroring", "App Store submission"]}, ensure_ascii=False, indent=2))
sys.exit(0 if all(c["passed"] for c in checks) else 1)
