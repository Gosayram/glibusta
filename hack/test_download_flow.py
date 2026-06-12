#!/usr/bin/env python3
"""Test the full Flibusta download flow: search → details → download → verify."""

import os
import sys
import time
import re
import requests
import urllib3
from pathlib import Path

DISABLE_TLS_VERIFY = os.environ.get('DISABLE_TLS_VERIFY', '').lower() in ('1', 'true', 'yes')
if DISABLE_TLS_VERIFY:
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

BASE_URL = "https://www.flibusta.is"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
}


def _get(url, timeout=15):
    return requests.get(url, headers=HEADERS, verify=not DISABLE_TLS_VERIFY,
                        timeout=timeout, allow_redirects=True)


def test_search(query):
    """Test search via /booksearch?ask=&chb=on"""
    print(f"\n=== Search: '{query}' ===")
    url = f"{BASE_URL}/booksearch?ask={query}&chb=on"
    r = _get(url)
    print(f"  Status: {r.status_code}, Size: {len(r.content)} bytes")

    if r.status_code != 200:
        print(f"  FAIL: Non-200 status")
        return []

    html = r.text
    # Parse book IDs from search results
    book_ids = re.findall(r'href="/b/(\d+)"', html)
    book_ids = list(dict.fromkeys(book_ids))  # dedupe, preserve order
    print(f"  Found {len(book_ids)} book IDs: {book_ids[:5]}")
    return book_ids


def test_book_details(book_id):
    """Test getting book details from /b/{id}"""
    print(f"\n=== Book details: {book_id} ===")
    url = f"{BASE_URL}/b/{book_id}"
    r = _get(url)
    print(f"  Status: {r.status_code}, Size: {len(r.content)} bytes")

    if r.status_code != 200:
        print(f"  FAIL: Non-200 status")
        return None

    html = r.text

    # Extract title
    h1_matches = re.findall(r'<h1[^>]*>(.*?)</h1>', html, re.DOTALL)
    title = ""
    for h1 in h1_matches:
        text = re.sub(r'<[^>]+>', '', h1).strip()
        if text and text != "Флибуста":
            title = text
            break
    print(f"  Title: {title}")

    # Extract available formats
    formats = []
    for match in re.finditer(rf'href="/b/{book_id}/(\w+)"', html):
        fmt = match.group(1)
        if fmt not in ('read', 'mail') and fmt not in formats:
            formats.append(fmt)
    print(f"  Formats: {formats}")

    return {"id": book_id, "title": title, "formats": formats}


def test_download(book_id, fmt, output_dir):
    """Test downloading a book via /b/{id}/{format}"""
    print(f"\n=== Download: {book_id}.{fmt} ===")
    url = f"{BASE_URL}/b/{book_id}/{fmt}"
    output_file = output_dir / f"{book_id}.{fmt}"

    r = _get(url, timeout=30)
    print(f"  Status: {r.status_code}, Size: {len(r.content)} bytes")
    print(f"  Content-Type: {r.headers.get('Content-Type', 'unknown')}")

    if r.status_code != 200:
        print(f"  FAIL: Non-200 status")
        return False

    if len(r.content) < 200:
        print(f"  FAIL: Too small ({len(r.content)} bytes)")
        return False

    # Check if we got HTML instead of a book file
    if b"<!DOCTYPE html" in r.content[:500] or b"<html" in r.content[:500]:
        print(f"  FAIL: Got HTML page instead of book file")
        # Show what we got
        preview = r.text[:500]
        print(f"  Preview: {preview[:200]}...")
        return False

    output_file.write_bytes(r.content)
    print(f"  Saved: {output_file} ({len(r.content)} bytes)")

    # Verify file is a valid book
    if fmt == 'epub':
        # EPUB files start with PK (ZIP header)
        if r.content[:2] == b'PK':
            print(f"  Valid EPUB (ZIP header OK)")
        else:
            print(f"  WARNING: Not a valid EPUB (missing PK header)")
    elif fmt == 'fb2':
        # FB2 files may be plain XML or ZIP
        if r.content[:2] == b'PK':
            print(f"  Valid FB2 (ZIP header OK)")
        elif b'<?xml' in r.content[:200] or b'<FictionBook' in r.content[:500]:
            print(f"  Valid FB2 (XML header OK)")
        else:
            print(f"  WARNING: Unknown FB2 format")
    elif fmt == 'txt':
        # TXT files are plain text or ZIP
        if r.content[:2] == b'PK':
            print(f"  Valid TXT (ZIP wrapper)")
        else:
            print(f"  Valid TXT (plain text)")

    return True


def test_opds_search(query):
    """Test OPDS search endpoint"""
    print(f"\n=== OPDS Search: '{query}' ===")
    url = f"{BASE_URL}/opds/opensearch?searchTerm={query}&searchType=books&pageNumber=0"
    r = _get(url)
    print(f"  Status: {r.status_code}, Size: {len(r.content)} bytes")

    if r.status_code != 200:
        print(f"  FAIL: Non-200 status")
        return []

    # Parse XML for book entries
    book_ids = re.findall(r'<id>tag:flibusta:book/(\d+)</id>', r.text)
    print(f"  Found {len(book_ids)} books via OPDS")
    return book_ids


def main():
    output_dir = Path(__file__).parent.parent / "test_results"
    output_dir.mkdir(exist_ok=True)

    print(f"Base URL: {BASE_URL}")
    print(f"Output: {output_dir}\n")

    all_ok = True

    # 1. Search
    book_ids = test_search("Пушкин")
    if not book_ids:
        print("\nFATAL: Search returned no results")
        all_ok = False

    # 2. Book details
    if book_ids:
        details = test_book_details(book_ids[0])
        if not details:
            all_ok = False

    # 3. Download test books
    download_tests = [
        ("181420", "epub"),
        ("282351", "fb2"),
        ("282351", "txt"),
    ]
    for book_id, fmt in download_tests:
        if not test_download(book_id, fmt, output_dir):
            all_ok = False
        time.sleep(1)

    # 4. OPDS search
    opds_ids = test_opds_search("Толстой")
    if not opds_ids:
        print("  WARNING: OPDS search returned no results")

    # 5. Test download URL construction (what Flutter would use)
    print(f"\n=== Download URL construction ===")
    for book_id, fmt in download_tests:
        flutter_url = f"{BASE_URL}/b/{book_id}/{fmt}"
        print(f"  Flutter would use: {flutter_url}")
        # Verify it's accessible
        r = requests.head(flutter_url, headers=HEADERS, verify=not DISABLE_TLS_VERIFY,
                          timeout=10, allow_redirects=True)
        print(f"    HEAD status: {r.status_code}, Content-Type: {r.headers.get('Content-Type', '?')}")

    print(f"\n{'='*50}")
    print(f"Result: {'ALL OK' if all_ok else 'SOME FAILURES'}")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
