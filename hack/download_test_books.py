#!/usr/bin/env python3
"""Download test books from Flibusta in various formats."""

import os
import sys
import time
import requests
import urllib3
from pathlib import Path

from flibusta_client import _load_base_url

DISABLE_TLS_VERIFY = os.environ.get('DISABLE_TLS_VERIFY', '').lower() in ('1', 'true', 'yes')
if DISABLE_TLS_VERIFY:
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

BASE_URL = _load_base_url()

# Book IDs and formats to download
# (bookId, format, expected_encoding_hint)
BOOKS = [
    # EPUB books (UTF-8 usually)
    ("181420", "epub", "utf-8"),
    ("282351", "epub", "utf-8"),
    # FB2 books (various encodings)
    ("282351", "fb2", "utf-8"),
    ("181420", "fb2", "utf-8"),
    # TXT books (often windows-1251)
    ("282351", "txt", "windows-1251"),
]

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
}


def download_book(book_id: str, fmt: str, output_dir: Path) -> bool:
    url = f"{BASE_URL}/b/{book_id}/{fmt}"
    output_file = output_dir / f"{book_id}.{fmt}"

    if output_file.exists() and output_file.stat().st_size > 100:
        print(f"  SKIP (exists): {output_file.name}")
        return True

    try:
        print(f"  Downloading {url} ...")
        resp = requests.get(url, headers=HEADERS, verify=not DISABLE_TLS_VERIFY, timeout=30, allow_redirects=True)
        if resp.status_code == 200 and len(resp.content) > 100:
            output_file.write_bytes(resp.content)
            print(f"  OK: {output_file.name} ({len(resp.content)} bytes)")
            return True
        else:
            print(f"  FAIL: status={resp.status_code}, size={len(resp.content)}")
            return False
    except Exception as e:
        print(f"  ERROR: {e}")
        return False


def main():
    output_dir = Path(__file__).parent.parent / "test_results"
    output_dir.mkdir(exist_ok=True)

    print(f"Downloading test books to {output_dir}")
    print(f"Base URL: {BASE_URL}\n")

    success = 0
    fail = 0

    for book_id, fmt, _ in BOOKS:
        print(f"[{book_id}.{fmt}]")
        if download_book(book_id, fmt, output_dir):
            success += 1
        else:
            fail += 1
        time.sleep(1)  # Rate limit

    print(f"\nDone: {success} downloaded, {fail} failed")
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
