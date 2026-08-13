#!/usr/bin/env python3
"""Download more test books — various encodings and formats."""

import os
import sys
import time
import requests
import urllib3
from pathlib import Path

from flibusta_client import _load_base_url

# SECURITY: Only disable TLS verification for local dev/testing against
# flubusta mirrors that use self-signed or expired certificates.
# NEVER set DISABLE_TLS_VERIFY=1 in production or against untrusted networks.
DISABLE_TLS_VERIFY = os.environ.get('DISABLE_TLS_VERIFY', '').lower() in ('1', 'true', 'yes')
if DISABLE_TLS_VERIFY:
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

BASE_URL = _load_base_url()

# Known working book IDs from Flibusta catalog
# Format: (bookId, format)
BOOKS = [
    ("52496", "epub"),     # Classic Russian literature — likely UTF-8
    ("52496", "fb2"),      # Same book in FB2
    ("60913", "epub"),     # Another classic
    ("60913", "fb2"),
    ("280792", "epub"),    # Modern book
    ("161303", "epub"),    # Sci-fi
    ("161303", "fb2"),
    ("431001", "txt"),     # Text format
    ("52496", "txt"),      # TXT version of classic
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
        if resp.status_code == 200 and len(resp.content) > 200:
            content_type = resp.headers.get("Content-Type", "")
            # Check if we got HTML instead of the actual book
            if b"<!DOCTYPE html" in resp.content[:500] or b"<html" in resp.content[:500]:
                print(f"  SKIP (HTML page, not a book): status={resp.status_code}")
                return False
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

    print(f"Downloading additional test books to {output_dir}")
    print(f"Base URL: {BASE_URL}\n")

    success = 0
    fail = 0

    for book_id, fmt in BOOKS:
        print(f"[{book_id}.{fmt}]")
        if download_book(book_id, fmt, output_dir):
            success += 1
        else:
            fail += 1
        time.sleep(1)

    print(f"\nDone: {success} downloaded, {fail} failed")
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
