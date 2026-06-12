#!/usr/bin/env python3
"""Dirty Flibusta parsing — search, categories, formats, fresh books."""

import json
import re
import sys
import time
from pathlib import Path
from urllib.parse import urljoin

sys.path.insert(0, str(Path(__file__).parent))
from flibusta_client import FlibustaClient

RESULTS = Path(__file__).parent.parent / "test_results" / "dirty-parse"
RESULTS.mkdir(parents=True, exist_ok=True)

c = FlibustaClient()
BASE = c.base_url

def save(name, data):
    p = RESULTS / name
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
    print(f"  -> {p.name}")

def get(path):
    r = c._get(path)
    if r and r.status_code == 200:
        return r.text
    print(f"  FAIL {path}: {r.status_code if r else 'no response'}")
    return None

print(f"Base URL: {BASE}")
print(f"UA: {c.session.headers.get('User-Agent', 'N/A')[:80]}")

# ═══════════════════════════════════════════════════════════════
# 1. TEST SEARCH — what works from Python
# ═══════════════════════════════════════════════════════════════
print("\n=== 1. SEARCH TEST ===")
for q in ["Толстой", "Атаманов", "Шерлок", "Конан Дойл"]:
    books = c.search_books_by_name(q)
    print(f"  '{q}': {len(books)} books")
    if books:
        b = books[0]
        print(f"    First: #{b.book.id} '{b.book.name}' by {[a.name for a in b.authors]}")
    time.sleep(0.3)

authors = c.search_authors("Конан")
print(f"  Authors 'Конан': {len(authors)}")
for a in authors[:3]:
    print(f"    #{a.id} {a.name} ({a.books} books, {a.translations} translations)")

series = c.search_books_by_series("Гарри Поттер")
print(f"  Series 'Гарри Поттер': {len(series)}")

# ═══════════════════════════════════════════════════════════════
# 2. GENRE: КРИМИНАЛЬНЫЙ ДЕТЕКТИВ — fresh books
# ═══════════════════════════════════════════════════════════════
print("\n=== 2. GENRE: КРИМИНАЛЬНЫЙ ДЕТЕКТИВ (det_classic) ===")
html = get("/g/det_classic")
if html:
    from bs4 import BeautifulSoup
    soup = BeautifulSoup(html, "html.parser")
    
    books = []
    for a in soup.find_all("a", href=lambda h: h and h.startswith("/b/")):
        href = a["href"]
        book_id = re.sub(r"\D", "", href)
        name = a.get_text(strip=True)
        if book_id and name:
            books.append({"id": int(book_id), "name": name})
    
    save("genre_det_classic_books.json", books)
    print(f"  Books in det_classic: {len(books)}")
    for b in books[:10]:
        print(f"    #{b['id']} {b['name'][:60]}")

# ═══════════════════════════════════════════════════════════════
# 3. BOOK DETAILS — full parse with formats, cover, annotations
# ═══════════════════════════════════════════════════════════════
print("\n=== 3. BOOK DETAILS (226302) ===")
details = c.get_book_details("226302")
if details:
    save("book_226302.json", {
        "id": details.id,
        "title": details.title,
        "description": details.description[:300],
        "cover_url": details.cover_url,
        "authors": [{"id": a.id, "name": a.name} for a in details.authors],
        "genres": [{"id": g.id, "name": g.name} for g in details.genres],
        "formats": details.formats,
        "series": details.series,
        "download_urls": details.download_urls,
    })
    print(f"  Title: {details.title}")
    print(f"  Authors: {[a.name for a in details.authors]}")
    print(f"  Genres: {[g.name for g in details.genres]}")
    print(f"  Formats: {details.formats}")
    print(f"  Series: {details.series}")
    print(f"  Cover: {details.cover_url}")
    print(f"  Downloads: {details.download_urls}")

# ═══════════════════════════════════════════════════════════════
# 4. DOWNLOAD PAGE — what format options are shown
# ═══════════════════════════════════════════════════════════════
print("\n=== 4. DOWNLOAD PAGE (226302) ===")
html = get(f"/b/226302/download")
if html:
    soup = BeautifulSoup(html, "html.parser")
    dls = []
    for a in soup.find_all("a", href=True):
        href = a["href"]
        fmt_match = re.match(r"/b/226302/(\w+)", href)
        if fmt_match:
            fmt = fmt_match.group(1)
            dls.append({"format": fmt, "url": href, "text": a.get_text(strip=True)})
    
    save("download_226302.json", dls)
    print(f"  Download options: {len(dls)}")
    for d in dls:
        print(f"    [{d['format']}] {d['text']}: {d['url']}")

# ═══════════════════════════════════════════════════════════════
# 5. RECENT ADDITIONS — /new with filters
# ═══════════════════════════════════════════════════════════════
print("\n=== 5. RECENT ADDITIONS (/new) ===")
html = get("/new")
if html:
    soup = BeautifulSoup(html, "html.parser")
    
    recent = []
    for a in soup.find_all("a", href=lambda h: h and h.startswith("/b/")):
        href = a["href"]
        book_id = re.sub(r"\D", "", href)
        name = a.get_text(strip=True)
        if book_id and name:
            recent.append({"id": int(book_id), "name": name})
    
    save("recent_additions.json", recent)
    print(f"  Recent books: {len(recent)}")
    for b in recent[:10]:
        print(f"    #{b['id']} {b['name'][:60]}")
    
    forms = soup.find_all("form")
    for f in forms:
        action = f.get("action", "")
        if action.startswith("/new"):
            selects = f.find_all("select")
            for s in selects:
                name = s.get("name", "")
                opts = [(o.get("value", ""), o.get_text(strip=True)) for o in s.find_all("option")[:10]]
                print(f"    Select '{name}': {opts}")

# ═══════════════════════════════════════════════════════════════
# 6. POPULAR BOOKS — /stat/b
# ═══════════════════════════════════════════════════════════════
print("\n=== 6. POPULAR (/stat/b) ===")
html = get("/stat/b")
if html:
    soup = BeautifulSoup(html, "html.parser")
    popular = []
    for a in soup.find_all("a", href=lambda h: h and h.startswith("/b/")):
        href = a["href"]
        book_id = re.sub(r"\D", "", href)
        name = a.get_text(strip=True)
        if book_id and name:
            popular.append({"id": int(book_id), "name": name})
    
    save("popular.json", popular)
    print(f"  Popular books: {len(popular)}")
    for b in popular[:10]:
        print(f"    #{b['id']} {b['name'][:60]}")

# ═══════════════════════════════════════════════════════════════
# 7. AUTHOR PAGE — full structure
# ═══════════════════════════════════════════════════════════════
print("\n=== 7. AUTHOR PAGE (6116 Conan Doyle) ===")
html = get("/a/6116")
if html:
    soup = BeautifulSoup(html, "html.parser")
    
    h1 = None
    for h in soup.find_all("h1"):
        text = h.get_text(strip=True)
        if text and "Флибуста" not in text:
            h1 = text
            break
    
    books = []
    for a in soup.find_all("a", href=lambda h: h and h.startswith("/b/")):
        href = a["href"]
        bid = re.sub(r"\D", "", href)
        name = a.get_text(strip=True)
        if bid and name:
            books.append({"id": int(bid), "name": name})
    
    save("author_6116.json", {
        "name": h1,
        "book_count": len(books),
        "books": books[:20],
    })
    print(f"  Name: {h1}")
    print(f"  Books: {len(books)}")
    for b in books[:5]:
        print(f"    #{b['id']} {b['name'][:60]}")

# ═══════════════════════════════════════════════════════════════
# 8. COVERS — test URL pattern
# ═══════════════════════════════════════════════════════════════
print("\n=== 8. COVER URL PATTERN ===")
for bid in ["226302", "836924", "12345", "100", "5000"]:
    cover = c.get_cover_by_book_id(int(bid))
    print(f"  Book #{bid}: cover={'YES' if cover else 'NO'} ({len(cover)} bytes)" if cover else f"  Book #{bid}: cover=NO")

# ═══════════════════════════════════════════════════════════════
# 9. OPDS POPULAR — XML format
# ═══════════════════════════════════════════════════════════════
print("\n=== 9. OPDS POPULAR ===")
import xml.etree.ElementTree as ET
ATOM_NS = "http://www.w3.org/2005/Atom"

html = get("/opds/popular")
if html:
    root = ET.fromstring(html)
    entries = root.findall(f".//{{{ATOM_NS}}}entry")
    print(f"  OPDS entries: {len(entries)}")
    for e in entries[:5]:
        title = e.findtext(f"{{{ATOM_NS}}}title", "")
        authors = [a.findtext(f"{{{ATOM_NS}}}name", "") for a in e.findall(f"{{{ATOM_NS}}}author")]
        links = [(l.get("href", ""), l.get("type", "")) for l in e.findall(f"{{{ATOM_NS}}}link")]
        cover = [l.get("href") for l in e.findall(f"{{{ATOM_NS}}}link") if "image" in l.get("type", "")]
        print(f"    {title} by {authors} covers={cover[:1]}")

print(f"\nResults: {RESULTS}")
