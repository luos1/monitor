#!/usr/bin/env python3
"""Build a local sandbox QA app or a provisioned Mac App Store package.

Never creates account resources, installs software, notarizes, or uploads.
The store path rejects the known unsupported usbmuxd transport until a matching
sandbox-compatible transport has been implemented and tested.
"""
import argparse
import datetime
import hashlib
import json
import plistlib
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(*args, **kwargs):
    return subprocess.run(list(args), check=True, **kwargs)


def read_profile(path, expected_bundle):
    data = plistlib.loads(subprocess.check_output(["security", "cms", "-D", "-i", str(path)]))
    entitlements = data.get("Entitlements", {})
    if "OSX" not in data.get("Platform", []):
        raise ValueError("Requires an OSX Mac App Store provisioning profile")
    if data.get("ProvisionedDevices") or data.get("ProvisionsAllDevices"):
        raise ValueError("Development/direct-distribution profiles cannot be submitted to Mac App Store")
    if entitlements.get("get-task-allow") or entitlements.get("com.apple.security.get-task-allow"):
        raise ValueError("Store distribution must not enable debugger access")
    team = data.get("TeamIdentifier", [])
    if len(team) != 1:
        raise ValueError("Profile must identify exactly one team")
    application_id = entitlements.get("com.apple.application-identifier", entitlements.get("application-identifier"))
    if application_id != team[0] + "." + expected_bundle:
        raise ValueError("Profile application identifier must match the existing Mac bundle ID")
    expires = data.get("ExpirationDate")
    if not expires or expires.replace(tzinfo=datetime.timezone.utc) <= datetime.datetime.now(datetime.timezone.utc):
        raise ValueError("Mac App Store profile has expired")
    certificates = data.get("DeveloperCertificates", [])
    if not certificates or any(not isinstance(certificate, bytes) for certificate in certificates):
        raise ValueError("Profile must include its authorized distribution certificates")
    return team[0], application_id, {hashlib.sha1(certificate).hexdigest().upper() for certificate in certificates}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["qa", "store"])
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--profile", type=Path)
    parser.add_argument("--qa-config", type=Path, help="Debug-only local physical QA configuration; never included in store mode")
    parser.add_argument("--app-identity")
    parser.add_argument("--installer-identity")
    args = parser.parse_args()
    info = plistlib.loads((ROOT / "Packaging/MacAppStore/Info.plist").read_bytes())
    entitlements = plistlib.loads((ROOT / "Packaging/MacAppStore/App.entitlements").read_bytes())
    expected_bundle = "com.raccoonmerchant.ipadmirror.mac"
    assert info["CFBundleIdentifier"] == expected_bundle
    assert entitlements["com.apple.security.app-sandbox"] is True
    assert entitlements["com.apple.security.network.client"] is True
    if any(key.startswith("com.apple.security.temporary-exception") for key in entitlements):
        raise ValueError("No broad sandbox exception is permitted in this store configuration")
    if args.mode == "store":
        if args.qa_config:
            parser.error("Physical QA configuration is forbidden in store mode")
        if not all((args.profile, args.app_identity, args.installer_identity)):
            parser.error("store requires existing --profile, --app-identity and --installer-identity; nothing will be created")
        if not args.app_identity.startswith(("Apple Distribution:", "3rd Party Mac Developer Application:")):
            parser.error("App Store app identity must be Apple Distribution or Mac App Distribution")
        if not args.installer_identity.startswith("3rd Party Mac Developer Installer:"):
            parser.error("A separate Mac Installer Distribution identity is required")
        team, application_id, permitted_certificates = read_profile(args.profile, expected_bundle)
        identities = subprocess.check_output(["security", "find-identity", "-v", "-p", "codesigning"], text=True)
        matches = [(fingerprint, name) for fingerprint, name in re.findall(r'\d+\) ([A-F0-9]{40}) "([^"]+)"', identities) if name == args.app_identity]
        if len(matches) != 1 or matches[0][0] not in permitted_certificates:
            raise ValueError("Selected signing identity is not an authorized certificate in this Mac profile")
        entitlements.update({"com.apple.developer.team-identifier": team, "com.apple.application-identifier": application_id})
    output = args.output.resolve()
    if output.exists():
        parser.error("Use a new output directory; existing artifacts are preserved")
    output.mkdir(parents=True)
    scratch = output / "swift-build"
    configuration = "release" if args.mode == "store" else "debug"
    build_args = ["swift", "build", "--configuration", configuration, "--arch", "arm64", "--arch", "x86_64", "--scratch-path", str(scratch), "-Xswiftc", "-DIPADMIRROR_MAC_APP_STORE"]
    run(*build_args, cwd=ROOT)
    binary_dir = Path(subprocess.check_output(build_args + ["--show-bin-path"], cwd=ROOT, text=True).strip())
    app = output / "iPad Mirror.app"
    contents = app / "Contents"
    (contents / "MacOS").mkdir(parents=True)
    resources = contents / "Resources"
    resources.mkdir()
    if args.mode == "qa" and args.qa_config:
        shutil.copy2(args.qa_config, resources / "PhysicalQAConfig.json")
    if args.mode == "qa":
        info["CFBundleIdentifier"] = expected_bundle + ".qa.task8.store"
    (contents / "Info.plist").write_bytes(plistlib.dumps(info, sort_keys=False))
    executable = contents / "MacOS/iPadMirrorMac"
    shutil.copy2(binary_dir / "iPadMirrorMac", executable)
    shutil.copy2(ROOT / "Packaging/AppIcon.icns", resources / "AppIcon.icns")
    shutil.copy2(ROOT / "Packaging/PrivacyInfo.xcprivacy", resources / "PrivacyInfo.xcprivacy")
    shutil.copytree(binary_dir / "iPadMirrorMac_iPadMirrorShared.bundle", resources / "iPadMirrorMac_iPadMirrorShared.bundle")
    for locale in ("en", "ko"):
        shutil.copytree(ROOT / f"Packaging/{locale}.lproj", resources / f"{locale}.lproj")
    contains_usbmuxd = b"/var/run/usbmuxd" in executable.read_bytes()
    if contains_usbmuxd:
        raise ValueError("Store signing blocked: current direct USB transport is denied by App Sandbox. Resolve transport scope and verify it first.")
    if args.mode == "store":
        shutil.copy2(args.profile, contents / "embedded.provisionprofile")
    entitlement_path = output / "signing.entitlements"
    entitlement_path.write_bytes(plistlib.dumps(entitlements))
    signing_args = ["codesign", "--force", "--options", "runtime", "--sign", args.app_identity if args.mode == "store" else "-", "--entitlements", str(entitlement_path)]
    if args.mode == "store":
        signing_args.append("--timestamp")
    run(*signing_args, str(app))
    run("codesign", "--verify", "--deep", "--strict", str(app))
    run("python3", str(ROOT / "scripts/validate-privacy-manifests.py"), str(app))
    package = None
    if args.mode == "store":
        package = output / "iPadMirrorMac-AppStore.pkg"
        run("productbuild", "--component", str(app), "/Applications", "--sign", args.installer_identity, str(package))
        run("pkgutil", "--check-signature", str(package))
    receipt = {"mode": args.mode, "bundle": info["CFBundleIdentifier"], "version": info["CFBundleShortVersionString"], "build": info["CFBundleVersion"], "app": str(app), "sandbox_enabled": True, "contains_direct_usbmuxd_transport": contains_usbmuxd, "transport_scope": "local-network-only", "physical_network_verified_by_packaging": False, "USB_sandbox_compatible": False if contains_usbmuxd else None, "Mac_App_Store_ready": False, "store_package_signed": args.mode == "store", "new_credentials_profiles_or_uploads": False, "binary_sha256": hashlib.sha256(executable.read_bytes()).hexdigest(), "package": str(package) if package else None}
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt))


if __name__ == "__main__":
    main()
