#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

MACOS_SIZES = {
    "app_icon_16.png": 16,
    "app_icon_32.png": 32,
    "app_icon_64.png": 64,
    "app_icon_128.png": 128,
    "app_icon_256.png": 256,
    "app_icon_512.png": 512,
    "app_icon_1024.png": 1024,
}


def fit_square(image: Image.Image, size: int, scale: float) -> Image.Image:
    source = image.convert("RGBA")
    side = min(source.size)
    left = (source.width - side) // 2
    top = (source.height - side) // 2
    cropped = source.crop((left, top, left + side, top + side))

    target = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    content_size = max(1, round(size * scale))
    resized = cropped.resize((content_size, content_size), Image.Resampling.LANCZOS)
    offset = ((size - content_size) // 2, (size - content_size) // 2)
    target.alpha_composite(resized, offset)
    return target


def save_android_icons(root: Path, image: Image.Image) -> None:
    for density, size in ANDROID_SIZES.items():
        directory = root / "android" / "app" / "src" / "main" / "res" / density
        directory.mkdir(parents=True, exist_ok=True)
        fit_square(image, size, 0.74).save(directory / "ic_launcher.png")


def save_macos_icons(root: Path, image: Image.Image) -> None:
    directory = root / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    directory.mkdir(parents=True, exist_ok=True)
    for filename, size in MACOS_SIZES.items():
        fit_square(image, size, 1.0).save(directory / filename)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate Android and macOS app icons from a square PNG."
    )
    parser.add_argument("source", type=Path, help="Path to the source PNG icon.")
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Flutter project root. Defaults to this script's parent project.",
    )
    args = parser.parse_args()

    source = args.source.expanduser().resolve()
    root = args.project_root.expanduser().resolve()

    with Image.open(source) as image:
        save_android_icons(root, image)
        save_macos_icons(root, image)

    print("Generated Android and macOS app icons.")


if __name__ == "__main__":
    main()
