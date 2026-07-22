#!/usr/bin/env python3
"""Verify the static 16 KiB-page properties of an Android release artifact.

This deliberately checks properties that can be proven without a device:
arm64 ELF load-segment alignment, and APK mmap alignment for stored native
libraries.  It does not replace install/start smoke tests on a 16 KiB device.
"""

from __future__ import annotations

import argparse
import re
import struct
import sys
import zipfile
from pathlib import Path

PAGE_SIZE = 16 * 1024
PT_LOAD = 1
ZIP_LOCAL_HEADER = struct.Struct("<IHHHHHIIIHH")
ZIP_LOCAL_HEADER_SIGNATURE = 0x04034B50
PAGE_SIZE_ASSUMPTION = re.compile(
    r"(?:PAGE_SIZE|page_size|getpagesize\s*\(\)|_SC_PAGESIZE)"
    r".{0,80}?(?:==|!=|<=|>=|<|>|=).{0,20}\b(?:4096|0x1000)\b"
)
NATIVE_SOURCE_SUFFIXES = {".c", ".cc", ".cpp", ".cxx", ".h", ".hpp", ".rs"}


def _load_alignments(data: bytes, member: str) -> list[int]:
    if data[:4] != b"\x7fELF":
        raise ValueError(f"{member}: not an ELF file")

    elf_class, byte_order = data[4], data[5]
    endian = "<" if byte_order == 1 else ">" if byte_order == 2 else None
    if endian is None:
        raise ValueError(f"{member}: unsupported ELF byte order {byte_order}")

    if elf_class == 1:
        header = struct.Struct(f"{endian}16sHHIIIIIHHHHHH")
        program_header = struct.Struct(f"{endian}IIIIIIII")
        program_offset_index, entry_size_index, entry_count_index = 5, 9, 10
    elif elf_class == 2:
        header = struct.Struct(f"{endian}16sHHIQQQIHHHHHH")
        program_header = struct.Struct(f"{endian}IIQQQQQQ")
        program_offset_index, entry_size_index, entry_count_index = 5, 9, 10
    else:
        raise ValueError(f"{member}: unsupported ELF class {elf_class}")

    if len(data) < header.size:
        raise ValueError(f"{member}: truncated ELF header")
    values = header.unpack_from(data)
    offset = values[program_offset_index]
    entry_size = values[entry_size_index]
    entry_count = values[entry_count_index]
    if entry_size < program_header.size or offset + entry_size * entry_count > len(data):
        raise ValueError(f"{member}: truncated program-header table")

    return [
        program_header.unpack_from(data, offset + index * entry_size)[-1]
        for index in range(entry_count)
        if program_header.unpack_from(data, offset + index * entry_size)[0] == PT_LOAD
    ]


def _zip_data_offset(artifact: Path, info: zipfile.ZipInfo) -> int:
    with artifact.open("rb") as archive:
        archive.seek(info.header_offset)
        header = archive.read(ZIP_LOCAL_HEADER.size)
    if len(header) != ZIP_LOCAL_HEADER.size:
        raise ValueError(f"{info.filename}: truncated ZIP local header")
    signature, *_, name_length, extra_length = ZIP_LOCAL_HEADER.unpack(header)
    if signature != ZIP_LOCAL_HEADER_SIGNATURE:
        raise ValueError(f"{info.filename}: invalid ZIP local-header signature")
    return info.header_offset + ZIP_LOCAL_HEADER.size + name_length + extra_length


def _check_page_size_assumptions(source_root: Path) -> list[str]:
    errors: list[str] = []
    for path in source_root.rglob("*"):
        if path.suffix not in NATIVE_SOURCE_SUFFIXES or not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if PAGE_SIZE_ASSUMPTION.search(text):
            errors.append(f"{path}: hard-coded 4 KiB page-size assumption")
    return errors


def check_artifact(artifact: Path) -> list[str]:
    errors: list[str] = []
    is_apk = artifact.suffix.lower() == ".apk"
    with zipfile.ZipFile(artifact) as archive:
        libraries = [
            info
            for info in archive.infolist()
            if info.filename.endswith(".so") and "/arm64-v8a/" in info.filename
        ]
        if not libraries:
            return [f"{artifact}: no arm64-v8a native libraries found"]

        for info in libraries:
            try:
                alignments = _load_alignments(archive.read(info), info.filename)
            except ValueError as error:
                errors.append(str(error))
                continue
            if not alignments:
                errors.append(f"{info.filename}: no PT_LOAD segments")
            elif any(alignment < PAGE_SIZE for alignment in alignments):
                actual = ", ".join(hex(alignment) for alignment in alignments)
                errors.append(
                    f"{info.filename}: PT_LOAD alignment must be at least 0x{PAGE_SIZE:x} "
                    f"for 16 KiB pages (found {actual})"
                )

            if is_apk:
                if info.compress_type != zipfile.ZIP_STORED:
                    errors.append(
                        f"{info.filename}: APK native library must be stored, not compressed"
                    )
                    continue
                try:
                    data_offset = _zip_data_offset(artifact, info)
                except ValueError as error:
                    errors.append(str(error))
                    continue
                if data_offset % PAGE_SIZE:
                    errors.append(
                        f"{info.filename}: APK data offset 0x{data_offset:x} is not 16 KiB aligned"
                    )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path, help="APK or AAB to inspect")
    parser.add_argument(
        "--scan-page-size-assumptions",
        type=Path,
        metavar="SOURCE_ROOT",
        help="reject hard-coded 4 KiB assumptions in native source files",
    )
    args = parser.parse_args()

    if not args.artifact.is_file():
        parser.error(f"artifact does not exist: {args.artifact}")

    errors = check_artifact(args.artifact)
    if args.scan_page_size_assumptions:
        errors.extend(_check_page_size_assumptions(args.scan_page_size_assumptions))
    if errors:
        print("16 KiB Android compatibility check failed:", file=sys.stderr)
        print(*[f"  - {error}" for error in errors], sep="\n", file=sys.stderr)
        return 1

    artifact_kind = (
        "APK ELF and ZIP alignment" if args.artifact.suffix.lower() == ".apk" else "AAB ELF"
    )
    print(f"16 KiB Android compatibility check passed ({artifact_kind}): {args.artifact}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
