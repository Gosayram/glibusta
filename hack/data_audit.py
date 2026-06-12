#!/usr/bin/env python3
"""Comprehensive Flibusta data audit — what data can we extract?"""

import json
import re
import sys
import time
from pathlib import Path
from xml.etree import ElementTree as ET

sys.path.insert(0, str(Path(__file__).parent))
from flibusta_client import FlibustaClient

RESULTS = Path(__file__).parent.parent / "test_results" / "data-audit"
RESULTS.mkdir(parents=True, exist_ok=True)

ATOM_NS = "http://www.w3.org/2005/Atom"
OS_NS = "http://a9.com/-/spec/opensearch/1.1/"

c = FlibustaClient()

def save(name, data):
    p = RESULTS / name
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
    print(f"  Saved: {p.name}")

def audit(label, data):
    print(f"\n{'='*60}")
    print(f"  {label}")
    print(f"{'='*60}")
    if isinstance(data, dict):
        for k, v in data.items():
            if isinstance(v, list):
                print(f"  {k}: {len(v)} items")
                for item in v[:3]:
                    print(f"    {item}")
            else:
                print(f"  {k}: {v}")
    elif isinstance(data, list):
        print(f"  {len(data)} items")
        for item in data[:5]:
            print(f"    {item}")


# ═══════════════════════════════════════════════════════════════
# 1. BOOK DETAIL PAGE — full field extraction
# ═══════════════════════════════════════════════════════════════
print("\n### 1. BOOK DETAIL PAGE ###")
book_id = "226302"
details = c.get_book_details(book_id)
if details:
    audit(f"BOOK #{book_id}", {
        "title": details.title,
        "description": details.description[:200] if details.description else None,
        "cover_url": details.cover_url,
        "authors": [(a.id, a.name) for a in details.authors],
        "genres": [(g.id, g.name) for g in details.genres],
        "formats": details.formats,
        "series": details.series,
        "download_urls": details.download_urls,
    })
    save("book_detail.json", {
        "id": details.id,
        "title": details.title,
        "description": details.description,
        "cover_url": details.cover_url,
        "authors": [{"id": a.id, "name": a.name} for a in details.authors],
        "genres": [{"id": g.id, "name": g.name} for g in details.genres],
        "formats": details.formats,
        "series": details.series,
    })


# ═══════════════════════════════════════════════════════════════
# 2. BOOK COVER — direct image URL pattern
# ═══════════════════════════════════════════════════════════════
print("\n### 2. BOOK COVER ###")
for bid in ["226302", "1", "12345", "836924"]:
    cover = c.get_cover_by_book_id(int(bid))
    print(f"  Book #{bid}: cover={'YES' if cover else 'NO'} ({len(cover) if cover else 0} bytes)")
save("covers.json", {
    "pattern": "i/{y}/{book_id}/cover.{jpg,png}",
    "note": "y = last digits of book_id when len > 4",
})


# ═══════════════════════════════════════════════════════════════
# 3. SEARCH RESULTS — what data is in search hits?
# ═══════════════════════════════════════════════════════════════
print("\n### 3. SEARCH RESULTS DATA ###")
from bs4 import BeautifulSoup

for qtype, qparam, link_prefix in [
    ("books", "chb=on", "/b/"),
    ("authors", "cha=on", "/a/"),
    ("series", "chs=on", "/sequence/"),
    ("genres", "chg=on", "/g/"),
]:
    r = c._get(f"booksearch?ask=Толстой&page=0&{qparam}")
    if not r:
        continue
    soup = BeautifulSoup(r.text, "html.parser")
    main = soup.select_one("#main") or soup
    for ul in main.find_all("ul"):
        items = ul.find_all("li", recursive=False)
        if not items:
            continue
        sample = items[0]
        links = sample.find_all("a", recursive=False)
        print(f"\n  [{qtype}] Sample item:")
        print(f"    Raw text: {sample.get_text(strip=True)[:120]}")
        for i, a in enumerate(links):
            print(f"    Link[{i}]: {a.get('href', '')} -> {a.get_text(strip=True)[:60]}")
        break

save("search_data_audit.json", {
    "books": "id, name, authors (id+name), NO cover in search results",
    "authors": "id, name, books_count, translations_count (from text)",
    "series": "id, name, books_count (from text)",
    "genres": "id, name",
    "covers": "NOT available in HTML search — must use /i/ endpoint or OPDS",
})


# ═══════════════════════════════════════════════════════════════
# 4. OPDS — covers + rich data
# ═══════════════════════════════════════════════════════════════
print("\n### 4. OPDS DATA ###")
r = c._get("/opds/opensearch?searchTerm=Толстой&searchType=books&pageNumber=0")
if r:
    root = ET.fromstring(r.text)
    entries = root.findall(f".//{{{ATOM_NS}}}entry")
    if entries:
        e = entries[0]
        opds_data = {
            "title": e.findtext(f"{{{ATOM_NS}}}title", ""),
            "id": e.findtext(f"{{{ATOM_NS}}}id", ""),
            "updated": e.findtext(f"{{{ATOM_NS}}}updated", ""),
            "authors": [],
            "categories": [],
            "links": [],
            "description": e.findtext(f"{{{ATOM_NS}}}content", "")[:200],
        }
        for a_el in e.findall(f"{{{ATOM_NS}}}author"):
            opds_data["authors"].append({
                "name": a_el.findtext(f"{{{ATOM_NS}}}name", ""),
                "uri": a_el.findtext(f"{{{ATOM_NS}}}uri", ""),
            })
        for cat in e.findall(f"{{{ATOM_NS}}}category"):
            opds_data["categories"].append(cat.get("label", ""))
        for link in e.findall(f"{{{ATOM_NS}}}link"):
            opds_data["links"].append({
                "href": link.get("href", ""),
                "type": link.get("type", ""),
                "rel": link.get("rel", ""),
            })
        audit("OPDS Book Entry", opds_data)
        save("opds_book_entry.json", opds_data)


# ═══════════════════════════════════════════════════════════════
# 5. AUTHOR PAGE — available fields
# ═══════════════════════════════════════════════════════════════
print("\n### 5. AUTHOR PAGE ###")
r = c._get("/a/6116")
if r:
    soup = BeautifulSoup(r.text, "html.parser")
    h1s = soup.find_all("h1")
    name = ""
    for h1 in h1s:
        t = h1.get_text(strip=True)
        if t and t != "Флибуста":
            name = t
            break
    book_links = soup.find_all("a", href=lambda h: h and h.startswith("/b/"))
    series_links = soup.find_all("a", href=lambda h: h and ("/sequence/" in h or h.startswith("/s/")))

    forms = soup.find_all("form")
    filter_form = None
    for f in forms:
        if f.get("action", "").startswith("/a/"):
            filter_form = f
            break
    filters = {}
    if filter_form:
        for sel in filter_form.find_all("select"):
            name_attr = sel.get("name", "")
            opts = [o.get("value", "") for o in sel.find_all("option")][:5]
            filters[name_attr] = opts
        for cb in filter_form.find_all("input", {"type": "checkbox"}):
            filters[f"checkbox:{cb.get('name', '')}"] = cb.get("value", "")

    audit("Author #6116", {
        "name": name,
        "book_count": len(book_links),
        "series_count": len(series_links),
        "filters": filters,
        "note": "NO bio, NO photo, NO birth date — only name + books + filter form",
    })


# ═══════════════════════════════════════════════════════════════
# 6. COMMENTS / REVIEWS (polka)
# ═══════════════════════════════════════════════════════════════
print("\n### 6. REVIEWS (POLKA) ###")
r = c._get("/polka/show/all")
if r:
    soup = BeautifulSoup(r.text, "html.parser")
    review_items = soup.find_all("div", class_=lambda c: c and "node" in c)
    if not review_items:
        review_items = soup.find_all("tr")
    print(f"  Reviews page items: {len(review_items)}")
    for item in review_items[:3]:
        text = item.get_text(strip=True)[:150]
        print(f"    {text}")

r = c._get("/polka/show/1452402")
if r:
    soup = BeautifulSoup(r.text, "html.parser")
    print(f"  User polka items: {len(soup.find_all('a', href=lambda h: h and h.startswith('/b/')))} books")

save("reviews_audit.json", {
    "polka_show_all": "/polka/show/all — all reviews (no auth needed)",
    "polka_show_user": "/polka/show/{user_id} — user's rated books",
    "polka_add": "POST /polka/add/{book_id} — add review (auth required)",
    "fields": "body (text), score (1-5), flag",
    "note": "Reviews ARE accessible — can parse rating + text from /polka/show/all",
})


# ═══════════════════════════════════════════════════════════════
# 7. TRACKER / RECENT COMMENTS
# ═══════════════════════════════════════════════════════════════
print("\n### 7. TRACKER (RECENT COMMENTS) ###")
r = c._get("/tracker")
if r:
    soup = BeautifulSoup(r.text, "html.parser")
    book_links = soup.find_all("a", href=lambda h: h and h.startswith("/b/"))
    print(f"  Tracker book links: {len(book_links)}")
    for b in book_links[:5]:
        print(f"    {b.get_text(strip=True)[:60]}: {b['href']}")


# ═══════════════════════════════════════════════════════════════
# 8. RECOMMENDATIONS
# ═══════════════════════════════════════════════════════════════
print("\n### 8. RECOMMENDATIONS ###")
for view in ["recs", "popular"]:
    r = c._get(f"/rec?view={view}")
    if r:
        soup = BeautifulSoup(r.text, "html.parser")
        book_links = soup.find_all("a", href=lambda h: h and h.startswith("/b/"))
        print(f"  /rec?view={view}: {len(book_links)} books")


# ═══════════════════════════════════════════════════════════════
# 9. STATISTICS
# ═══════════════════════════════════════════════════════════════
print("\n### 9. STATISTICS ###")
r = c._get("/stat")
if r:
    soup = BeautifulSoup(r.text, "html.parser")
    text = soup.get_text()[:500]
    print(f"  /stat text: {text[:200]}")

r = c._get("/stat/b")
if r:
    soup = BeautifulSoup(r.text, "html.parser")
    book_links = soup.find_all("a", href=lambda h: h and h.startswith("/b/"))
    print(f"  /stat/b popular books: {len(book_links)}")


# ═══════════════════════════════════════════════════════════════
# 10. USER PROFILES
# ═══════════════════════════════════════════════════════════════
print("\n### 10. USER PROFILES ###")
for uid in ["1452402", "1"]:
    profile = c.get_user_profile(uid)
    print(f"  User #{uid}: {profile}")


# ═══════════════════════════════════════════════════════════════
# SUMMARY — DATA MODEL
# ═══════════════════════════════════════════════════════════════
print("\n" + "="*60)
print("  DATA MODEL SUMMARY")
print("="*60)

model = {
    "Book": {
        "from_html": ["id", "title", "description", "cover_url", "authors", "genres", "formats", "series", "download_urls"],
        "from_opds": ["title", "id", "authors", "categories", "cover_link", "downloads", "description"],
        "from_cover_endpoint": ["cover_image (jpg/png)"],
        "NOT_available": ["rating", "reviews", "comments_count", "downloads_count", "date_added"],
    },
    "Author": {
        "from_html": ["id", "name", "book_count", "translation_count"],
        "NOT_available": ["photo", "bio", "birth_date", "death_date"],
    },
    "Series": {
        "from_html": ["id", "name", "book_count"],
    },
    "Genre": {
        "from_html": ["id", "name"],
    },
    "Review (Polka)": {
        "from_html": ["reviewer_id", "book_id", "body", "score (1-5)"],
        "requires_auth": True,
    },
    "Cover": {
        "pattern": "i/{y}/{book_id}/cover.{jpg,png}",
        "opds_pattern": "link[type=image/jpeg].href",
    },
    "Search": {
        "books": "booksearch?ask={q}&chb=on",
        "authors": "booksearch?ask={q}&cha=on",
        "series": "booksearch?ask={q}&chs=on",
        "genres": "booksearch?ask={q}&chg=on",
    },
}
audit("AVAILABLE DATA MODEL", model)
save("data_model.json", model)

print(f"\nResults: {RESULTS}")
