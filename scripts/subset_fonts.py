#!/usr/bin/env python3
"""Subset app fonts to Cyrillic + Latin + common punctuation.

In-place subsetting of assets/fonts/*.ttf using fonttools pyftsubset.
Run during release builds to reduce APK size by ~65%.

Restore originals: git checkout assets/fonts/
"""

import subprocess
import sys
from pathlib import Path

FONTS_DIR = Path(__file__).resolve().parent.parent / "assets" / "fonts"

UNICODES = ",".join(
    [
        "U+0020-007E",  # Basic Latin (ASCII printable)
        "U+00A0-00FF",  # Latin-1 Supplement (NBSP, «», etc.)
        "U+0100-017F",  # Latin Extended-A (European)
        "U+0400-04FF",  # Cyrillic
        "U+0500-052F",  # Cyrillic Supplementary
        "U+2000-206F",  # General Punctuation (dash, quotes)
        "U+20A0-20CF",  # Currency Symbols (₽, etc.)
        "U+2100-214F",  # Letterlike Symbols (№)
        "U+2150-218F",  # Number Forms (fractions)
        "U+FB00-FB04",  # Latin ligatures (ﬀ, ﬁ, ﬂ, ﬃ, ﬄ)
    ]
)


HERE = Path(__file__).resolve().parent.parent
PYFTSUBSET = HERE / ".venv-tools" / "bin" / "pyftsubset"


def subset_font(font_path: Path) -> int:
    orig_size = font_path.stat().st_size
    tmp = font_path.with_suffix(".subset.ttf")
    subprocess.run(
        [str(PYFTSUBSET), str(font_path), f"--unicodes={UNICODES}", f"--output-file={tmp}"],
        check=True,
        capture_output=True,
        text=True,
    )
    sub_size = tmp.stat().st_size
    tmp.replace(font_path)
    return orig_size, sub_size


def main() -> None:
    if not FONTS_DIR.exists():
        print(f"ERROR: fonts dir not found: {FONTS_DIR}", file=sys.stderr)
        sys.exit(1)

    ttf_files = sorted(FONTS_DIR.glob("*.ttf"))
    if not ttf_files:
        print("No .ttf files found in", FONTS_DIR)
        sys.exit(0)

    total_orig = 0
    total_sub = 0
    for f in ttf_files:
        orig, sub = subset_font(f)
        total_orig += orig
        total_sub += sub
        pct = (orig - sub) * 100 // orig
        print(f"  {f.name}: {orig // 1024}K → {sub // 1024}K (-{pct}%)")

    total_pct = (total_orig - total_sub) * 100 // total_orig
    print(f"  Total: {total_orig // 1024}K → {total_sub // 1024}K (-{total_pct}%)")


if __name__ == "__main__":
    main()
