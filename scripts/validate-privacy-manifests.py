#!/usr/bin/env python3
"""Validate privacy plist structure and Apple TN3181 tracking-key relationships."""
import json
import plistlib
import re
import sys
from pathlib import Path


def validate_manifest(path):
    errors = []
    try:
        data = plistlib.loads(path.read_bytes())
    except Exception as error:
        return [f"Invalid property list: {type(error).__name__}"]
    if not isinstance(data, dict):
        return ["Privacy manifest root must be a dictionary"]
    tracking = data.get("NSPrivacyTracking")
    if tracking is not None and type(tracking) is not bool:
        errors.append("NSPrivacyTracking must be Boolean")
    domains = data.get("NSPrivacyTrackingDomains", [])
    if not isinstance(domains, list) or any(not isinstance(domain, str) for domain in domains):
        errors.append("NSPrivacyTrackingDomains must be an array of strings")
        domains = []
    if tracking is True and not domains:
        errors.append("TN3181: tracking=true requires one or more tracking domains")
    if domains and tracking is not True:
        errors.append("TN3181: nonempty tracking domains require tracking=true")
    if tracking is not True and "NSPrivacyTrackingDomains" in data and not domains:
        errors.append("Apple DTS 842856: omit the unused tracking domains key instead of an empty array")
    if len(domains) != len(set(domains)):
        errors.append("Tracking domains must not be duplicated")
    domain_pattern = re.compile(r"(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$")
    for domain in domains:
        if not domain_pattern.fullmatch(domain):
            errors.append(f"Tracking domain must be a hostname with no scheme, path, port or query: {domain}")
    for key in ("NSPrivacyAccessedAPITypes", "NSPrivacyCollectedDataTypes"):
        entries = data.get(key, [])
        if not isinstance(entries, list) or any(not isinstance(entry, dict) for entry in entries):
            errors.append(f"{key} must be an array of dictionaries")
            continue
        for entry in entries:
            if key == "NSPrivacyCollectedDataTypes":
                for boolean in ("NSPrivacyCollectedDataTypeLinked", "NSPrivacyCollectedDataTypeTracking"):
                    if type(entry.get(boolean)) is not bool:
                        errors.append(f"{boolean} must be Boolean")
                purposes = entry.get("NSPrivacyCollectedDataTypePurposes")
                if not isinstance(purposes, list) or not purposes or any(not isinstance(p, str) for p in purposes):
                    errors.append("Collected data purposes must be a nonempty array of strings")
            else:
                reasons = entry.get("NSPrivacyAccessedAPITypeReasons")
                if not isinstance(reasons, list) or not reasons or any(not isinstance(reason, str) or not re.fullmatch(r"[A-Z0-9]{4}\.\d+", reason) for reason in reasons):
                    errors.append("Required API reasons must be a nonempty array of reason codes")
    return errors


def main():
    root = Path(__file__).resolve().parents[1]
    paths = [Path(argument) for argument in sys.argv[1:]] if len(sys.argv) > 1 else [root / "Sources/iPadMirrorPad/PrivacyInfo.xcprivacy", root / "Sources/iPadMirrorBroadcastExtension/PrivacyInfo.xcprivacy", root / "Packaging/PrivacyInfo.xcprivacy"]
    manifests = [manifest for path in paths for manifest in (sorted(path.rglob("*.xcprivacy")) if path.is_dir() else [path])]
    results = [{"path": str(path), "errors": validate_manifest(path)} for path in manifests]
    passed = bool(results) and all(not result["errors"] for result in results)
    print(json.dumps({"scope": "Technical structure only; does not establish legal disclosures or App Review acceptance", "source": "https://developer.apple.com/documentation/technotes/tn3181-debugging-invalid-privacy-manifest", "passed": passed, "manifests": results}, indent=2))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
