#!/usr/bin/env python3
"""Deep parse of Flibusta author page — extracts avatar, bio, series groups, genres, ratings, formats."""

import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).parent))
from flibusta_client import FlibustaClient

RESULTS = Path(__file__).parent.parent / "test_results" / "author-page"
RESULTS.mkdir(parents=True, exist_ok=True)

c = FlibustaClient()


def save(name, data):
    p = RESULTS / name
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
    print(f"  -> {p.name}")


@dataclass
class AuthorBook:
    id: str
    name: str
    index: Optional[int] = None
    size: Optional[str] = None
    pages: Optional[int] = None
    rating: Optional[float] = None
    formats: list = field(default_factory=list)
    series_id: Optional[str] = None
    series_name: Optional[str] = None
    genres: list = field(default_factory=list)


@dataclass
class SeriesGroup:
    id: str
    name: str
    genres: list = field(default_factory=list)
    books: list = field(default_factory=list)


@dataclass
class AuthorPage:
    id: str
    name: str
    avatar_url: Optional[str] = None
    biography: str = ""
    external_links: list = field(default_factory=list)
    series_groups: list = field(default_factory=list)
    standalone_books: list = field(default_factory=list)
    all_books_count: int = 0
    filters: dict = field(default_factory=dict)


def parse_author_page(author_id: str) -> Optional[AuthorPage]:
    """Parse full author page HTML structure."""
    from bs4 import BeautifulSoup, NavigableString

    r = c._get(f"/a/{author_id}")
    if not r or r.status_code != 200:
        print(f"  FAIL: Could not fetch /a/{author_id}")
        return None

    soup = BeautifulSoup(r.text, "html.parser")

    # ── Author name ──────────────────────────────────────────────────────────
    name = ""
    for h1 in soup.find_all("h1"):
        text = h1.get_text(strip=True)
        if text and text != "Флибуста":
            name = text
            break

    # ── Avatar / Photo ───────────────────────────────────────────────────────
    avatar_url = None
    divabio = soup.find(id="divabio")
    if divabio:
        for img in divabio.find_all("img"):
            src = img.get("src", "")
            if "/ia/" in src:
                avatar_url = src
                break

    # ── Biography ────────────────────────────────────────────────────────────
    biography = ""
    if divabio:
        paragraphs = []
        for p in divabio.find_all("p"):
            text = p.get_text(strip=True)
            if text and not text.startswith("http"):
                paragraphs.append(text)
        biography = "\n\n".join(paragraphs)

    # ── External links ───────────────────────────────────────────────────────
    external_links = []
    if divabio:
        for a in divabio.find_all("a", href=True):
            href = a["href"]
            if href.startswith("http"):
                external_links.append({"url": href, "text": a.get_text(strip=True)})

    # ── Filter form (GET) ───────────────────────────────────────────────────
    filters = {}
    for form in soup.find_all("form"):
        if form.get("method", "").upper() == "GET":
            for sel in form.find_all("select"):
                name_attr = sel.get("name", "")
                opts = [(o.get("value", ""), o.get_text(strip=True)) for o in sel.find_all("option")]
                filters[name_attr] = opts
            for cb in form.find_all("input", {"type": "checkbox"}):
                filters[f"checkbox:{cb.get('name', '')}"] = cb.get("value", "")
            break

    # ── Books grouped by series ──────────────────────────────────────────────
    # The POST form has flat children: <br>, <a href="/s/ID"> (series), genre <a>s,
    # <img>, <svg>, <input>, text, <a href="/b/ID"> (book), <span>, etc.
    series_groups = []
    standalone_books = []

    books_form = None
    for form in soup.find_all("form"):
        if form.get("method", "").upper() == "POST" and "/b/" in str(form):
            books_form = form
            break

    if books_form:
        current_series = None
        current_genres = []

        children = list(books_form.children)
        i = 0
        while i < len(children):
            child = children[i]

            if isinstance(child, NavigableString):
                i += 1
                continue

            # Series header: <a href="/s/ID"><span class="h8">Name</span></a>
            if child.name == "a":
                href = child.get("href", "")
                series_match = re.match(r"^/s/(\d+)$", href)
                if series_match:
                    series_id = series_match.group(1)
                    series_name_el = child.find("span", class_="h8")
                    series_name = series_name_el.get_text(strip=True) if series_name_el else child.get_text(strip=True)

                    # Collect genres from following sibling text nodes and <a> elements
                    # until we hit a <br>
                    current_genres = []
                    i += 1
                    while i < len(children):
                        next_child = children[i]
                        if isinstance(next_child, NavigableString):
                            text = str(next_child).strip()
                            if text.startswith("("):
                                # Start of genres section
                                i += 1
                                continue
                            elif text.startswith(")"):
                                # End of genres section
                                break
                            elif text.startswith(",") or text.startswith(" и "):
                                i += 1
                                continue
                            else:
                                break
                        elif next_child.name == "br":
                            break
                        elif next_child.name == "a":
                            ghref = next_child.get("href", "")
                            gid_match = re.match(r"^/g/(\d+)$", ghref)
                            if gid_match:
                                current_genres.append({
                                    "id": gid_match.group(1),
                                    "name": next_child.get_text(strip=True),
                                })
                            i += 1
                            continue
                        else:
                            break
                        i += 1

                    current_series = SeriesGroup(
                        id=series_id,
                        name=series_name,
                        genres=current_genres,
                    )
                    series_groups.append(current_series)
                    continue

                # Book link: <a href="/b/ID">Book Name</a>
                book_match = re.match(r"^/b/(\d+)$", href)
                if book_match:
                    book_id = book_match.group(1)
                    book_name = child.get_text(strip=True)

                    if book_name:
                        # Look ahead for rating, size, formats in surrounding children
                        rating = None
                        size = None
                        pages = None
                        index = None
                        formats = []

                        # Search backwards for rating SVG
                        for j in range(max(0, i - 5), i):
                            prev = children[j]
                            if hasattr(prev, "name") and prev.name == "svg":
                                title_el = prev.find("title")
                                if title_el:
                                    rm = re.search(r"Средняя оценка: ([\d.]+)", title_el.get_text())
                                    if rm:
                                        rating = float(rm.group(1))

                        # Search forwards for size span, index text, format links
                        for j in range(i + 1, min(len(children), i + 15)):
                            next_c = children[j]
                            if isinstance(next_c, NavigableString):
                                text = str(next_c)
                                # Index: "- 1.  " or "-  "
                                idx_match = re.search(r"(\d+)\.\s", text)
                                if idx_match and index is None:
                                    index = int(idx_match.group(1))
                                continue
                            if hasattr(next_c, "name"):
                                if next_c.name == "span":
                                    st = next_c.get_text(strip=True)
                                    sm = re.search(r"(\d+K)", st)
                                    if sm:
                                        size = sm.group(1)
                                    pm = re.search(r"(\d+)\s*с\.", st)
                                    if pm:
                                        pages = int(pm.group(1))
                                elif next_c.name == "a":
                                    ahref = next_c.get("href", "")
                                    fmt_match = re.match(rf"^/b/{book_id}/(\w+)$", ahref)
                                    if fmt_match:
                                        fmt = fmt_match.group(1)
                                        if fmt not in ("read", "download", "mail", "complain"):
                                            formats.append(fmt)
                                elif next_c.name == "br":
                                    break

                        book = AuthorBook(
                            id=book_id,
                            name=book_name,
                            index=index,
                            size=size,
                            pages=pages,
                            rating=rating,
                            formats=formats,
                            series_id=current_series.id if current_series else None,
                            series_name=current_series.name if current_series else None,
                            genres=[g["name"] for g in (current_series.genres if current_series else [])],
                        )

                        if current_series:
                            current_series.books.append(book)
                        else:
                            standalone_books.append(book)
            i += 1

    total_books = sum(len(sg.books) for sg in series_groups) + len(standalone_books)

    return AuthorPage(
        id=author_id,
        name=name,
        avatar_url=avatar_url,
        biography=biography,
        external_links=external_links,
        series_groups=series_groups,
        standalone_books=standalone_books,
        all_books_count=total_books,
        filters=filters,
    )


# ══════════════════════════════════════════════════════════════════════════════
# Test
# ══════════════════════════════════════════════════════════════════════════════

TEST_AUTHORS = [
    "143632",  # Михаил Атаманов (has avatar, bio, many series)
    "6116",    # Конан Дойл
]

for author_id in TEST_AUTHORS:
    print(f"\n{'='*60}")
    print(f"  AUTHOR #{author_id}")
    print(f"{'='*60}")

    author = parse_author_page(author_id)
    if not author:
        continue

    print(f"  Name: {author.name}")
    print(f"  Avatar: {author.avatar_url}")
    print(f"  Bio length: {len(author.biography)} chars")
    print(f"  External links: {len(author.external_links)}")
    print(f"  Series groups: {len(author.series_groups)}")
    print(f"  Standalone books: {len(author.standalone_books)}")
    print(f"  Total books: {author.all_books_count}")

    for sg in author.series_groups:
        print(f"\n  Series: {sg.name} (#{sg.id})")
        print(f"    Genres: {[g['name'] for g in sg.genres]}")
        print(f"    Books: {len(sg.books)}")
        for b in sg.books[:3]:
            print(f"      #{b.id} {b.name} [{', '.join(b.formats)}] rating={b.rating} size={b.size}")

    if author.standalone_books:
        print(f"\n  Standalone:")
        for b in author.standalone_books[:5]:
            print(f"    #{b.id} {b.name} [{', '.join(b.formats)}]")

    save(f"author_{author_id}.json", {
        "id": author.id,
        "name": author.name,
        "avatar_url": author.avatar_url,
        "biography": author.biography,
        "external_links": author.external_links,
        "all_books_count": author.all_books_count,
        "filters": author.filters,
        "series_groups": [
            {
                "id": sg.id,
                "name": sg.name,
                "genres": sg.genres,
                "books": [
                    {
                        "id": b.id,
                        "name": b.name,
                        "index": b.index,
                        "size": b.size,
                        "pages": b.pages,
                        "rating": b.rating,
                        "formats": b.formats,
                    }
                    for b in sg.books
                ],
            }
            for sg in author.series_groups
        ],
        "standalone_books": [
            {
                "id": b.id,
                "name": b.name,
                "size": b.size,
                "pages": b.pages,
                "rating": b.rating,
                "formats": b.formats,
            }
            for b in author.standalone_books
        ],
    })

print(f"\nResults: {RESULTS}")
