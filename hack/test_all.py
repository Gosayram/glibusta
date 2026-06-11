#!/usr/bin/env python3
"""Comprehensive Flibusta API test suite.

Tests all endpoints from the TypeScript flibusta-api reference,
plus book details, covers, and authenticated features.
"""

import json
import os
import sys
import time
from pathlib import Path

from bs4 import BeautifulSoup

# Add hack/ to path
sys.path.insert(0, str(Path(__file__).parent))

from flibusta_client import (
    FlibustaClient,
    AuthorBooks,
    BooksByName,
    BookSeries,
    Genre,
    OpdsBook,
    BookDetails,
    PaginatedResult,
)

RESULTS_DIR = Path(__file__).parent.parent / "test_results" / "hack-tests"
RESULTS_DIR.mkdir(parents=True, exist_ok=True)


def save_result(name: str, data) -> None:
    p = RESULTS_DIR / name
    if isinstance(data, (dict, list)):
        p.write_text(json.dumps(data, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
    elif hasattr(data, "__dataclass_fields__"):
        # dataclass -> dict
        from dataclasses import asdict
        p.write_text(json.dumps(asdict(data), ensure_ascii=False, indent=2, default=str), encoding="utf-8")
    else:
        p.write_text(str(data), encoding="utf-8")
    print(f"  -> {p.name}")


def section(title: str):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")


def test_connection(client: FlibustaClient) -> bool:
    section("1. CONNECTION TEST")
    r = client._get("/")
    if r:
        print(f"  Status: {r.status_code}")
        print(f"  URL: {r.url}")
        print(f"  Content length: {len(r.text)} bytes")
        save_result("01_connection.json", {
            "status": r.status_code,
            "url": r.url,
            "content_length": len(r.text),
            "headers": dict(r.headers),
        })
        return True
    print("  FAILED to connect!")
    return False


def test_search_books_html(client: FlibustaClient):
    section("2. SEARCH BOOKS (HTML)")
    queries = ["Шерлок", "Толстой", "Пришвин"]
    for q in queries:
        print(f"\n  Query: '{q}'")
        books = client.search_books_by_name(q)
        print(f"  Found: {len(books)} books")
        for b in books[:3]:
            print(f"    [{b.book.id}] {b.book.name}")
            print(f"      Authors: {[a.name for a in b.authors]}")
        save_result(f"02_books_html_{q}.json", [
            {"id": b.book.id, "name": b.book.name, "authors": [a.name for a in b.authors]}
            for b in books
        ])


def test_search_books_html_paginated(client: FlibustaClient):
    section("3. SEARCH BOOKS (HTML paginated)")
    result = client.search_books_by_name_paginated("Толстой", page=0, limit=5)
    print(f"  Items: {len(result.items)}")
    print(f"  Total: {result.total_count}")
    print(f"  Pages: {result.total_pages}")
    print(f"  Has next: {result.has_next_page}")
    for b in result.items[:5]:
        print(f"    [{b.book.id}] {b.book.name}")
    save_result("03_books_html_paginated.json", {
        "items": [{"id": b.book.id, "name": b.book.name} for b in result.items],
        "current_page": result.current_page,
        "total_count": result.total_count,
        "total_pages": result.total_pages,
        "has_next": result.has_next_page,
    })


def test_search_authors_html(client: FlibustaClient):
    section("4. SEARCH AUTHORS (HTML)")
    queries = ["Конан", "Толстой"]
    for q in queries:
        print(f"\n  Query: '{q}'")
        authors = client.search_authors(q)
        print(f"  Found: {len(authors)} authors")
        for a in authors[:5]:
            print(f"    [{a.id}] {a.name} — books={a.books}, translations={a.translations}")
        save_result(f"04_authors_html_{q}.json", [
            {"id": a.id, "name": a.name, "books": a.books, "translations": a.translations}
            for a in authors
        ])


def test_search_authors_html_paginated(client: FlibustaClient):
    section("5. SEARCH AUTHORS (HTML paginated)")
    result = client.search_authors_paginated("Конан", page=0, limit=3)
    print(f"  Items: {len(result.items)}")
    print(f"  Total: {result.total_count}")
    print(f"  Has next: {result.has_next_page}")
    for a in result.items[:3]:
        print(f"    [{a.id}] {a.name} — books={a.books}")
    save_result("05_authors_html_paginated.json", {
        "items": [{"id": a.id, "name": a.name} for a in result.items],
        "total_count": result.total_count,
        "has_next": result.has_next_page,
    })


def test_search_series_html(client: FlibustaClient):
    section("6. SEARCH SERIES (HTML)")
    queries = ["Шерлок", "Гарри Поттер"]
    for q in queries:
        print(f"\n  Query: '{q}'")
        series = client.search_books_by_series(q)
        print(f"  Found: {len(series)} series")
        for s in series[:5]:
            print(f"    [{s.id}] {s.name} — {s.books} books")
        save_result(f"06_series_html_{q}.json", [
            {"id": s.id, "name": s.name, "books": s.books}
            for s in series
        ])


def test_search_genres_html(client: FlibustaClient):
    section("7. SEARCH GENRES (HTML)")
    queries = ["роман", "детектив"]
    for q in queries:
        print(f"\n  Query: '{q}'")
        genres = client.search_genres(q)
        print(f"  Found: {len(genres)} genres")
        for g in genres[:10]:
            print(f"    [{g.id}] {g.name}")
        save_result(f"07_genres_html_{q}.json", [
            {"id": g.id, "name": g.name} for g in genres
        ])


def test_opds_search_books(client: FlibustaClient):
    section("8. OPDS SEARCH BOOKS")
    queries = ["Шерлок", "Толстой"]
    for q in queries:
        print(f"\n  Query: '{q}'")
        books = client.search_books_by_name_opds(q)
        print(f"  Found: {len(books)} books")
        for b in books[:3]:
            print(f"    {b.title}")
            print(f"      Authors: {[a.name for a in b.authors]}")
            print(f"      Downloads: {len(b.downloads)}")
            print(f"      Cover: {b.cover}")
            print(f"      Desc: {b.description[:80]}...")
        save_result(f"08_opds_books_{q}.json", [
            {
                "title": b.title,
                "authors": [{"name": a.name, "uri": a.uri} for a in b.authors],
                "categories": b.categories,
                "cover": b.cover,
                "downloads": [{"link": d.link, "type": d.type} for d in b.downloads],
                "description": b.description[:500],
            }
            for b in books
        ])


def test_opds_search_books_paginated(client: FlibustaClient):
    section("9. OPDS SEARCH BOOKS (paginated)")
    result = client.search_books_by_name_opds_paginated("Шерлок", page=0, limit=3)
    print(f"  Items: {len(result.items)}")
    print(f"  Total: {result.total_count}")
    print(f"  Has next: {result.has_next_page}")
    for b in result.items[:3]:
        print(f"    {b.title}")
    save_result("09_opds_books_paginated.json", {
        "items": [{"title": b.title, "downloads": len(b.downloads)} for b in result.items],
        "total_count": result.total_count,
        "has_next": result.has_next_page,
    })


def test_opds_author_books(client: FlibustaClient):
    section("10. OPDS AUTHOR BOOKS")
    author_ids = [6116, 2800]  # Конан Дойль, Толстой
    for aid in author_ids:
        print(f"\n  Author ID: {aid}")
        books = client.get_books_by_author_opds(aid)
        print(f"  Found: {len(books)} books")
        for b in books[:3]:
            print(f"    {b.title}")
            print(f"      Downloads: {len(b.downloads)}")
        save_result(f"10_opds_author_{aid}.json", [
            {
                "title": b.title,
                "downloads": [{"link": d.link, "type": d.type} for d in b.downloads],
                "cover": b.cover,
            }
            for b in books
        ])


def test_opds_genres_list(client: FlibustaClient):
    section("11. OPDS GENRES LIST")
    genres = client.get_genres_list_opds()
    print(f"  Found: {len(genres)} genres")
    for g in genres[:15]:
        print(f"    [{g.id}] {g.name}")
    save_result("11_opds_genres.json", [{"id": g.id, "name": g.name} for g in genres])


def test_book_details(client: FlibustaClient):
    section("12. BOOK DETAILS (HTML)")
    book_ids = ["12345", "1", "226302"]
    for bid in book_ids:
        print(f"\n  Book ID: {bid}")
        details = client.get_book_details(bid)
        if details:
            print(f"    Title: {details.title}")
            print(f"    Authors: {[a.name for a in details.authors]}")
            print(f"    Genres: {[g.name for g in details.genres]}")
            print(f"    Formats: {details.formats}")
            print(f"    Cover: {details.cover_url}")
            print(f"    Description: {details.description[:100]}...")
            from dataclasses import asdict
            save_result(f"12_book_details_{bid}.json", asdict(details))
        else:
            print("    Not found")


def test_cover(client: FlibustaClient):
    section("13. COVER IMAGE")
    book_ids = [226302, 12345]
    for bid in book_ids:
        print(f"\n  Book ID: {bid}")
        data = client.get_cover_by_book_id(bid)
        if data:
            print(f"    Size: {len(data)} bytes")
            cover_path = RESULTS_DIR / f"13_cover_{bid}.jpg"
            cover_path.write_bytes(data)
            print(f"    Saved: {cover_path.name}")
        else:
            print("    Not found")


def test_genres_page(client: FlibustaClient):
    section("14. GENRES PAGE")
    genres = client.get_genres_page()
    print(f"  Found: {len(genres)} genres")
    for g in genres[:10]:
        print(f"    [{g.id}] {g.name}")
    save_result("14_genres_page.json", [{"id": g.id, "name": g.name} for g in genres])


def test_auth(client: FlibustaClient):
    section("15. AUTH TEST")
    user = os.environ.get("FLIBUSTA_USER", "")
    password = os.environ.get("FLIBUSTA_PASSWORD", "")

    if not user or not password:
        print("  FLIBUSTA_USER / FLIBUSTA_PASSWORD not set — skipping auth test")
        print("  To test: export FLIBUSTA_USER=xxx FLIBUSTA_PASSWORD=yyy")
        return

    print(f"  Logging in as: {user[:3]}***")
    success = client.login(user, password)
    if success:
        print("  Login SUCCESS")
        print(f"  Is logged in: {client.is_logged_in()}")

        # Test authenticated endpoints
        print("\n  [1] Testing /my page...")
        r = client._get("/my")
        if r:
            print(f"    Status: {r.status_code}")
            soup = BeautifulSoup(r.text, "html.parser")
            # Find user info
            h1 = soup.find("h1")
            if h1:
                print(f"    User page title: {h1.get_text(strip=True)[:60]}")
            save_result("15_auth_my_page.html", r.text[:10000])

        # Test bookmarks
        print("\n  [2] Testing bookmarks...")
        r = client._get("/user/bookmarks")
        if r:
            print(f"    Status: {r.status_code}")
            soup = BeautifulSoup(r.text, "html.parser")
            book_links = soup.find_all("a", href=lambda h: h and "/b/" in h)
            print(f"    Bookmark links: {len(book_links)}")
            for a in book_links[:5]:
                print(f"      {a.get('href')} -> {a.get_text(strip=True)[:50]}")
            save_result("15_auth_bookmarks.html", r.text[:10000])

        # Test history
        print("\n  [3] Testing history...")
        r = client._get("/user/history")
        if r:
            print(f"    Status: {r.status_code}")
            save_result("15_auth_history.html", r.text[:10000])

        # Test collections/shelves
        print("\n  [4] Testing collections...")
        r = client._get("/collections")
        if r:
            print(f"    Status: {r.status_code}")
            soup = BeautifulSoup(r.text, "html.parser")
            collection_links = soup.find_all("a", href=lambda h: h and "/collection/" in h)
            print(f"    Collection links: {len(collection_links)}")
            for a in collection_links[:5]:
                print(f"      {a.get('href')} -> {a.get_text(strip=True)[:50]}")
            save_result("15_auth_collections.html", r.text[:10000])

        # Test adding a bookmark
        print("\n  [5] Testing add bookmark...")
        r = client._get("/b/226302")
        if r:
            soup = BeautifulSoup(r.text, "html.parser")
            # Look for bookmark form
            bookmark_form = None
            for form in soup.find_all("form"):
                inputs = {i.get("name") for i in form.find_all("input") if i.get("name")}
                if "bookmark" in str(inputs).lower() or "collection" in str(inputs).lower():
                    bookmark_form = form
                    break
            if bookmark_form:
                print(f"    Bookmark form found: {bookmark_form.get('action', '')}")
            else:
                print("    No bookmark form found (might need different approach)")

        # Test OPDS with auth
        print("\n  [6] Testing OPDS with auth...")
        r = client._get("/opds/")
        if r:
            print(f"    OPDS status: {r.status_code}")
            save_result("15_auth_opds.xml", r.text[:5000])

        # Test search with auth
        print("\n  [7] Testing search with auth session...")
        books = client.search_books_by_name("Толстой")
        print(f"    Books found: {len(books)}")

    else:
        print("  Login FAILED — check credentials")


def test_pagination_deep(client: FlibustaClient):
    section("16. DEEP PAGINATION TEST")
    print("  Testing page 0 -> 1 -> 2 for 'Толстой' books...")
    for page in range(3):
        result = client.search_books_by_name_paginated("Толстой", page=page, limit=3)
        print(f"  Page {page}: {len(result.items)} items, has_next={result.has_next_page}")
        if not result.has_next_page:
            print("  No more pages")
            break
    save_result("16_deep_pagination.json", {
        "test": "deep_pagination",
        "query": "Толстой",
        "pages_tested": page + 1,
    })


def test_multiple_formats(client: FlibustaClient):
    section("17. DOWNLOAD FORMATS TEST")
    # Test OPDS to get download links for a known book
    books = client.search_books_by_name_opds("Шерлок")
    if books:
        b = books[0]
        print(f"  Book: {b.title}")
        print(f"  Downloads available:")
        for d in b.downloads:
            print(f"    {d.type}: {d.link}")
        save_result("17_formats.json", {
            "title": b.title,
            "downloads": [{"link": d.link, "type": d.type} for d in b.downloads],
        })
    else:
        print("  No books found")


def test_error_handling(client: FlibustaClient):
    section("18. ERROR HANDLING")
    # Test non-existent book
    print("  Testing non-existent book...")
    details = client.get_book_details("99999999")
    print(f"    Result: {details}")

    # Test empty search
    print("  Testing empty search...")
    books = client.search_books_by_name("")
    print(f"    Books: {len(books)}")

    # Test special characters
    print("  Testing special characters...")
    books = client.search_books_by_name("<script>alert(1)</script>")
    print(f"    Books: {len(books)}")


def main():
    print(f"{'='*60}")
    print("  FLIBUSTA COMPREHENSIVE API TEST SUITE")
    print(f"{'='*60}")

    client = FlibustaClient()
    print(f"Base URL: {client.base_url}")
    print(f"Results: {RESULTS_DIR}")

    # 1. Connection
    if not test_connection(client):
        print("\nCannot connect. Aborting.")
        sys.exit(1)

    # 2-7. HTML endpoints
    test_search_books_html(client)
    test_search_books_html_paginated(client)
    test_search_authors_html(client)
    test_search_authors_html_paginated(client)
    test_search_series_html(client)
    test_search_genres_html(client)

    # 8-11. OPDS endpoints
    test_opds_search_books(client)
    test_opds_search_books_paginated(client)
    test_opds_author_books(client)
    test_opds_genres_list(client)

    # 12-14. Book details, covers, genres page
    test_book_details(client)
    test_cover(client)
    test_genres_page(client)

    # 15. Auth (uses FLIBUSTA_USER/FLIBUSTA_PASSWORD from env)
    test_auth(client)

    # 16-18. Advanced tests
    test_pagination_deep(client)
    test_multiple_formats(client)
    test_error_handling(client)

    section("DONE")
    print(f"  All results saved to: {RESULTS_DIR}")
    print(f"  Total files: {len(list(RESULTS_DIR.iterdir()))}")


if __name__ == "__main__":
    main()
