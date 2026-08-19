#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBXPROJ = ROOT / "iPadMirrorPad.xcodeproj" / "project.pbxproj"
BACKUP_PATH = PBXPROJ.with_suffix(".pbxproj.screenshot-build-bak")

REMOVE_MARKERS = [
    "AdMobConfiguration.swift in Sources",
    "AdMobService.swift in Sources",
    "AdMobBannerView.swift in Sources",
    "AdMobInterstitialManager.swift in Sources",
    "GoogleMobileAds in Frameworks",
    "B10000000000000000000001 /* GoogleMobileAds */,",
]


def strip() -> None:
    if not BACKUP_PATH.exists():
        shutil.copy2(PBXPROJ, BACKUP_PATH)
    lines = [
        line
        for line in PBXPROJ.read_text().splitlines(keepends=True)
        if not any(marker in line for marker in REMOVE_MARKERS)
    ]
    PBXPROJ.write_text("".join(lines))


def restore() -> None:
    if BACKUP_PATH.exists():
        shutil.move(BACKUP_PATH, PBXPROJ)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["strip", "restore"])
    args = parser.parse_args()
    if args.action == "strip":
        strip()
    else:
        restore()
    return 0


if __name__ == "__main__":
    sys.exit(main())
