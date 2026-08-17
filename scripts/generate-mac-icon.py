#!/usr/bin/env python3
"""Generate Packaging/AppIcon.icns from the iPad 1024x1024 app icon."""

from __future__ import annotations

import io
import struct
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:  # pragma: no cover - runtime dependency hint
    raise SystemExit(
        "Pillow is required. Install with: pip3 install pillow"
    ) from exc

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Sources/iPadMirrorPad/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png"
OUTPUT = ROOT / "Packaging/AppIcon.icns"

ICON_TYPES = {
    16: b"icp4",
    32: b"icp5",
    64: b"icp6",
    128: b"ic07",
    256: b"ic08",
    512: b"ic09",
    1024: b"ic10",
}


def make_icns(source: Path, output: Path) -> None:
    img = Image.open(source).convert("RGBA")
    body = b""
    for size, otype in ICON_TYPES.items():
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        buffer = io.BytesIO()
        resized.save(buffer, format="PNG", optimize=True)
        data = buffer.getvalue()
        entry_size = 8 + len(data)
        body += otype + struct.pack(">I", entry_size) + data

    file_size = 8 + len(body)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as handle:
        handle.write(b"icns")
        handle.write(struct.pack(">I", file_size))
        handle.write(body)


def main() -> int:
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else SOURCE
    output = Path(sys.argv[2]) if len(sys.argv) > 2 else OUTPUT
    if not source.is_file():
        print(f"Source icon not found: {source}", file=sys.stderr)
        return 1
    make_icns(source, output)
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
