#!/usr/bin/env python3
"""Read an IPA, flat PKG, or Mach-O without extracting or executing it.

Checks ordinary literals, symbols, and ARM64 Swift small-string immediates.
This is a focused regression check, not a general binary decompiler or an
App Review approval. Run it alongside source/configuration and signing checks.
"""
import argparse
import gzip
import hashlib
import io
import json
import plistlib
import struct
import sys
import xml.etree.ElementTree as ET
import zipfile
import zlib
from pathlib import Path

TOKENS = (
    "ScreenshotMode", "-ScreenshotDemo", "-SkipAds", "-ScreenshotLocale",
    "-ResetScreenshotOnboarding", "-ConsentTestEEA", "-PhysicalQAConfig",
    "PhysicalQAConfig",
)
MACHO = (b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf")
MAX_BYTES = 512 * 1024 * 1024


def cpio_files(data):
    offset = 0
    while offset < len(data):
        magic = data[offset:offset + 6]
        if magic == b"070707":
            header_size, radix, alignment = 76, 8, 1
            name_size = int(data[offset + 59:offset + 65], radix)
            file_size = int(data[offset + 65:offset + 76], radix)
        elif magic in (b"070701", b"070702"):
            header_size, radix, alignment = 110, 16, 4
            name_size = int(data[offset + 94:offset + 102], radix)
            file_size = int(data[offset + 54:offset + 62], radix)
        else:
            raise ValueError("Unsupported or truncated CPIO payload")
        name_start = offset + header_size
        name_end = name_start + name_size
        name = data[name_start:name_end].rstrip(b"\0").decode("utf-8")
        content_start = (name_end + alignment - 1) // alignment * alignment
        content_end = content_start + file_size
        if name_end > len(data) or content_end > len(data):
            raise ValueError("Truncated CPIO member")
        if name == "TRAILER!!!":
            return
        yield name, data[content_start:content_end]
        offset = (content_end + alignment - 1) // alignment * alignment


def package_files(data):
    _, header_size, _, toc_size, _, _ = struct.unpack_from(">4sHHQQI", data)
    toc = ET.fromstring(zlib.decompress(data[header_size:header_size + toc_size]))
    heap = header_size + toc_size
    payload_count = 0
    for entry in toc.iter("file"):
        if entry.findtext("name") != "Payload":
            continue
        payload_count += 1
        content = entry.find("data")
        start = heap + int(content.findtext("offset"))
        size = int(content.findtext("length"))
        payload = data[start:start + size]
        if payload.startswith(b"\x1f\x8b"):
            with gzip.GzipFile(fileobj=io.BytesIO(payload)) as stream:
                payload = stream.read(MAX_BYTES + 1)
        if len(payload) > MAX_BYTES:
            raise ValueError("PKG payload exceeds size limit")
        yield from cpio_files(payload)
    if payload_count == 0:
        raise ValueError("PKG contains no supported Payload")


def input_files(path):
    data = path.read_bytes()
    if len(data) > MAX_BYTES:
        raise ValueError("Input exceeds size limit")
    if zipfile.is_zipfile(io.BytesIO(data)):
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            if sum(i.file_size for i in archive.infolist()) > MAX_BYTES:
                raise ValueError("IPA contents exceed size limit")
            for member in archive.infolist():
                if not member.is_dir():
                    yield member.filename, archive.read(member)
    elif data.startswith(b"xar!"):
        yield from package_files(data)
    elif data[:4] in MACHO:
        yield path.name, data
    else:
        raise ValueError("Expected an IPA, flat PKG, or 64-bit Mach-O")


def slices(data):
    if data[:4] in (b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf"):
        count = struct.unpack_from(">I", data, 4)[0]
        is_64 = data[:4] == b"\xca\xfe\xba\xbf"
        width = 32 if is_64 else 20
        for index in range(count):
            entry = 8 + width * index
            cpu = struct.unpack_from(">I", data, entry)[0]
            start, size = struct.unpack_from(">QQ" if is_64 else ">II", data, entry + 8)
            if start + size > len(data):
                raise ValueError("Truncated universal Mach-O slice")
            yield cpu, data[start:start + size]
    else:
        yield struct.unpack_from("<I", data, 4)[0], data


def text_sections(data):
    if data[:4] != b"\xcf\xfa\xed\xfe":
        raise ValueError("Unsupported Mach-O slice")
    commands = struct.unpack_from("<I", data, 16)[0]
    offset = 32
    sections = []
    for _ in range(commands):
        command, size = struct.unpack_from("<II", data, offset)
        if size < 8 or offset + size > len(data):
            raise ValueError("Invalid Mach-O load command")
        if command in (0x21, 0x2C) and struct.unpack_from("<I", data, offset + 16)[0]:
            raise ValueError("Encrypted executable cannot be audited")
        if command == 0x19:
            count = struct.unpack_from("<I", data, offset + 64)[0]
            for index in range(count):
                section = offset + 72 + 80 * index
                if section + 80 > offset + size:
                    raise ValueError("Invalid Mach-O section")
                name = data[section:section + 16].rstrip(b"\0")
                if name == b"__text":
                    address, length, file_offset = struct.unpack_from("<QQI", data, section + 32)
                    if file_offset + length > len(data):
                        raise ValueError("Truncated executable section")
                    sections.append((address, data[file_offset:file_offset + length]))
        offset += size
    if not sections:
        raise ValueError("Executable contains no __text section")
    return sections


def arm64_small_strings(sections):
    expected = {}
    for token in TOKENS:
        literal = token.encode("ascii")
        if len(literal) <= 15:
            storage = literal.ljust(15, b"\0") + bytes([0xE0 | len(literal)])
            expected[token] = struct.unpack("<QQ", storage)
    found = []
    for address, code in sections:
        registers, recent = {}, {token: {} for token in expected}
        for offset in range(0, len(code) - 3, 4):
            instruction = struct.unpack_from("<I", code, offset)[0]
            kind = instruction & 0x7F800000
            if not instruction & 0x80000000 or kind not in (0x52800000, 0x12800000, 0x72800000):
                continue
            register = instruction & 31
            shift = ((instruction >> 21) & 3) * 16
            immediate = ((instruction >> 5) & 0xFFFF) << shift
            mask = (1 << 64) - 1
            if kind == 0x52800000:  # MOVZ Xn
                value, start = immediate, offset
            elif kind == 0x12800000:  # MOVN Xn
                value, start = (~immediate) & mask, offset
            else:  # MOVK Xn, short materialization sequence
                if register not in registers:
                    continue
                previous, start = registers[register]
                if offset - start > 40:
                    continue
                value = (previous & ~(0xFFFF << shift)) | immediate
            registers[register] = value, start
            for token, words in expected.items():
                for index, word in enumerate(words):
                    if value == word:
                        recent[token][index] = offset
                matches = recent[token]
                if len(matches) == 2 and abs(matches[0] - matches[1]) <= 64:
                    found.append({"token": token, "method": "ARM64 Swift small-string immediates", "address": hex(address + offset)})
                    matches.clear()
    return found


def x86_small_strings(sections):
    found = []
    for token in TOKENS:
        literal = token.encode("ascii")
        if len(literal) > 15:
            continue
        storage = literal.ljust(15, b"\0") + bytes([0xE0 | len(literal)])
        for address, code in sections:
            start = 0
            while (start := code.find(storage[:8], start)) >= 0:
                other = code.find(storage[8:], max(0, start - 64), start + 72)
                if other >= 0:
                    found.append({"token": token, "method": "x86_64 Swift small-string immediate words", "address": hex(address + start)})
                start += 8
    return found


def audit(path):
    executables, bundles, hits = [], [], []
    for name, data in input_files(path):
        for token in TOKENS:
            if token.encode("ascii") in data or token in name:
                hits.append({"member": name, "token": token, "method": "literal, symbol, or resource name"})
        if Path(name).name == "Info.plist":
            info = plistlib.loads(data)
            if "CFBundleExecutable" in info:
                bundles.append({"member": name, "id": info.get("CFBundleIdentifier"), "version": info.get("CFBundleShortVersionString"), "build": info.get("CFBundleVersion")})
        if data[:4] not in MACHO:
            continue
        architectures = []
        for cpu, binary in slices(data):
            sections = text_sections(binary)
            architectures.append(hex(cpu))
            if cpu == 0x0100000C:
                hits.extend({"member": name, **hit} for hit in arm64_small_strings(sections))
            elif cpu == 0x01000007:
                hits.extend({"member": name, **hit} for hit in x86_small_strings(sections))
            else:
                raise ValueError("Unsupported CPU; cannot audit small-string encoding")
        executables.append({"member": name, "sha256": hashlib.sha256(data).hexdigest(), "architectures": architectures})
    if not executables:
        raise ValueError("No executable audited; cannot report a pass")
    return {"scope": "focused development-option binary regression check", "artifact": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bundles": bundles, "executables": executables, "development_options_found": hits, "passed": not hits, "not_verified": ["signing/provisioning", "all possible compiler string encodings", "physical mirroring", "ads/consent/IAP runtime", "App Review acceptance"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path)
    args = parser.parse_args()
    try:
        report = audit(args.artifact)
    except (OSError, ValueError, struct.error, ET.ParseError, KeyError) as error:
        report = {"artifact": str(args.artifact), "passed": False, "error": str(error)}
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
