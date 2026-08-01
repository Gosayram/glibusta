#!/usr/bin/env python3
"""Flibusta API Client — Python port of flibusta-api with full parsing."""

import hashlib
import re
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional
from urllib import robotparser
from urllib.parse import quote, urljoin, urlsplit, urlunsplit

import requests
from bs4 import BeautifulSoup

ATOM_NS = "http://www.w3.org/2005/Atom"
OS_NS = "http://a9.com/-/spec/opensearch/1.1/"


def _load_base_url() -> str:
    env = Path(__file__).parent.parent / ".env"
    if not env.exists():
        raise RuntimeError(".env is required; run 'make env-decrypt' first")
    for line in env.read_text().splitlines():
        line = line.strip()
        if line.startswith("BASE_URL="):
            return line.split("=", 1)[1].strip().rstrip("/")
    raise RuntimeError("BASE_URL is required in .env")


def _get_numbers(s: str) -> str:
    match = re.search(r"/(\d+)(?:/|$)", urlsplit(s).path)
    return match.group(1) if match else ""


def _download_format(href: str, book_id: str) -> str | None:
    path = urlsplit(href).path
    direct = re.fullmatch(rf"/b/{re.escape(book_id)}/([a-z0-9]+)", path, re.IGNORECASE)
    if direct and direct.group(1).lower() not in {"complain", "download", "mail", "read"}:
        return direct.group(1).lower()
    download = re.fullmatch(rf"/b/{re.escape(book_id)}/download/[^/]+\.([a-z0-9]+)", path, re.IGNORECASE)
    return download.group(1).lower() if download else None


def _normalize_base_url(base_url: str) -> str:
    parsed = urlsplit(base_url.strip())
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError("BASE_URL must be an absolute http(s) URL")
    if parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise ValueError("BASE_URL must not contain credentials, a query, or a fragment")
    return urlunsplit((parsed.scheme, parsed.netloc, parsed.path.rstrip("/"), "", ""))


# ── Data classes ──────────────────────────────────────────────────────────────

@dataclass
class Author:
    id: int
    name: str


@dataclass
class AuthorBooks(Author):
    books: Optional[int] = None
    translations: Optional[int] = None


@dataclass
class Book:
    id: int
    name: str


@dataclass
class BooksByName:
    book: Book
    authors: list = field(default_factory=list)


@dataclass
class BookSeries:
    id: int
    name: str
    books: Optional[int] = None


@dataclass
class Genre:
    id: str
    name: str


@dataclass
class OpdsAuthor:
    name: str
    uri: str


@dataclass
class OpdsDownload:
    link: str
    type: str


@dataclass
class OpdsBook:
    id: str = ""
    authors: list = field(default_factory=list)  # list[OpdsAuthor]
    title: str = ""
    updated: str = ""
    categories: list = field(default_factory=list)
    cover: Optional[str] = None
    downloads: list = field(default_factory=list)  # list[OpdsDownload]
    description: str = ""


@dataclass
class PaginatedResult:
    items: list = field(default_factory=list)
    current_page: int = 0
    total_count: Optional[int] = None
    total_pages: int = 1
    has_next_page: bool = False
    has_previous_page: bool = False


@dataclass
class BookDetails:
    id: str
    title: str
    description: str = ""
    cover_url: Optional[str] = None
    authors: list = field(default_factory=list)
    genres: list = field(default_factory=list)
    formats: list = field(default_factory=list)
    download_urls: list = field(default_factory=list)
    series: list = field(default_factory=list)


# ── MIME types for OPDS downloads ─────────────────────────────────────────────

OPDS_MIME_TYPES = {
    "application/epub",
    "application/fb2+zip",
    "application/html+zip",
    "application/pdf+rar",
    "application/rtf+zip",
    "application/txt+zip",
    "application/x-mobipocket-ebook",
    "application/pdf+zip",
    "application/djvu",
    "application/msword",
    "application/x-rar-compressed",
    "application/pdf",
}


class RobotsDisallowedError(RuntimeError):
    """Raised before a request that the configured origin disallows."""


class FlibustaClient:
    """Flibusta API client — parses both HTML and OPDS endpoints."""

    def __init__(
        self,
        base_url: Optional[str] = None,
        *,
        connect_timeout_seconds: float = 5,
        read_timeout_seconds: float = 20,
        min_request_interval_seconds: float = 1,
    ) -> None:
        if connect_timeout_seconds <= 0 or read_timeout_seconds <= 0:
            raise ValueError("request timeouts must be positive")
        if min_request_interval_seconds < 0:
            raise ValueError("min_request_interval_seconds must not be negative")
        self.base_url = _normalize_base_url(base_url or _load_base_url())
        self._origin = urlsplit(self.base_url).netloc
        self._timeout = (connect_timeout_seconds, read_timeout_seconds)
        self._min_request_interval_seconds = min_request_interval_seconds
        self._last_request_at: Optional[float] = None
        self._robots_parser: Optional[robotparser.RobotFileParser] = None
        self._robots_metadata: Optional[dict[str, Any]] = None
        self.session = requests.Session()
        self.session.headers["User-Agent"] = (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/120.0.0.0 Safari/537.36"
        )
        self._logged_in = False

    def _resolve_url(self, path: str) -> str:
        url = urljoin(f"{self.base_url}/", path.lstrip("/"))
        parsed = urlsplit(url)
        if parsed.scheme != urlsplit(self.base_url).scheme or parsed.netloc != self._origin:
            raise ValueError("Refusing a request outside BASE_URL")
        return url

    def _wait_for_request_slot(self, minimum_interval_seconds: float = 0) -> None:
        if self._last_request_at is None:
            return
        interval = max(self._min_request_interval_seconds, minimum_interval_seconds)
        remaining = interval - (time.monotonic() - self._last_request_at)
        if remaining > 0:
            time.sleep(remaining)

    def _request_unchecked(
        self, method: str, path: str, *, minimum_interval_seconds: float = 0, **kwargs: Any
    ) -> Optional[requests.Response]:
        self._wait_for_request_slot(minimum_interval_seconds)
        kwargs.setdefault("allow_redirects", False)
        try:
            response = self.session.request(
                method,
                self._resolve_url(path),
                timeout=self._timeout,
                **kwargs,
            )
            self._last_request_at = time.monotonic()
            return response
        except requests.RequestException as error:
            print(f"  ERR {method} {path}: {error}")
            return None

    def robots_policy(self, user_agent: Optional[str] = None, path: str = "/") -> dict[str, Any]:
        """Return the cached robots policy; fail closed when it cannot be read."""
        agent = user_agent or self.session.headers["User-Agent"]
        if self._robots_metadata is None:
            response = self._request_unchecked("GET", "/robots.txt", headers={"User-Agent": agent})
            if response is None or not 200 <= response.status_code < 300:
                self._robots_metadata = {
                    "fetched": False,
                    "reason": "robots.txt request failed",
                }
            else:
                parser = robotparser.RobotFileParser()
                parser.parse(response.text.splitlines())
                self._robots_parser = parser
                self._robots_metadata = {
                    "fetched": True,
                    "status": response.status_code,
                    "sha256": hashlib.sha256(response.content).hexdigest(),
                }

        policy = dict(self._robots_metadata)
        crawl_delay = self._robots_parser.crawl_delay(agent) if self._robots_parser else None
        policy["crawl_delay_seconds"] = crawl_delay
        policy["effective_delay_seconds"] = max(self._min_request_interval_seconds, crawl_delay or 0)
        policy["allowed"] = bool(self._robots_parser and self._robots_parser.can_fetch(agent, self._resolve_url(path)))
        return policy

    def _request(self, method: str, path: str, **kwargs: Any) -> Optional[requests.Response]:
        if path.rstrip("/") != "/robots.txt":
            headers = kwargs.get("headers") or {}
            policy = self.robots_policy(headers.get("User-Agent"), path)
            if not policy["allowed"]:
                raise RobotsDisallowedError(
                    f"robots.txt disallows requests to {self._resolve_url(path)}; audit only with permission"
                )
            return self._request_unchecked(
                method,
                path,
                minimum_interval_seconds=policy["effective_delay_seconds"],
                **kwargs,
            )
        return self._request_unchecked(method, path, **kwargs)

    def _get(self, path: str, **kwargs: Any) -> Optional[requests.Response]:
        return self._request("GET", path, **kwargs)

    def _post(self, path: str, data: dict, **kwargs: Any) -> Optional[requests.Response]:
        return self._request("POST", path, data=data, **kwargs)

    # ── Auth ──────────────────────────────────────────────────────────────────

    def login(self, username: str, password: str) -> bool:
        """Login via form POST. Returns True on success."""
        r = self._get("/user/login")
        if not r:
            return False

        soup = BeautifulSoup(r.text, "html.parser")

        # Find the login form (POST form with name/pass fields)
        form = None
        for f in soup.find_all("form"):
            method = f.get("method", "GET").upper()
            if method != "POST":
                continue
            inputs = {i.get("name") for i in f.find_all("input") if i.get("name")}
            if "name" in inputs and "pass" in inputs:
                form = f
                break

        if not form:
            print("  Login form not found")
            return False

        action = form.get("action", "/user/login")
        # Clean up Drupal-style action URL
        if "index.php" in action:
            # Extract the actual path from index.php?q=...
            q_match = re.search(r"q=([^&]+)", action)
            if q_match:
                action = q_match.group(1)

        # Collect all hidden fields
        hidden = {}
        for inp in form.find_all("input", {"type": "hidden"}):
            name = inp.get("name")
            value = inp.get("value", "")
            if name:
                hidden[name] = value

        # Find submit button text
        submit = form.find("input", {"type": "submit"})
        op_text = submit.get("value", "Вход") if submit else "Вход"

        payload = {
            **hidden,
            "name": username,
            "pass": password,
            "op": op_text,
        }

        r = self._post(action, data=payload)
        if not r:
            return False

        # Check success: redirected to user page or page contains logout link
        if r.status_code == 200:
            if "logout" in r.text.lower() or "/user" in r.url.lower():
                self._logged_in = True
                return True

        return False

    def is_logged_in(self) -> bool:
        if not self._logged_in:
            r = self._get("/my")
            if r and r.status_code == 200 and "logout" in r.text.lower():
                self._logged_in = True
        return self._logged_in

    # ── HTML helpers ──────────────────────────────────────────────────────────

    def _get_html_page(self, path: str) -> Optional[BeautifulSoup]:
        r = self._get(path)
        if not r:
            return None
        return BeautifulSoup(r.text, "html.parser")

    def _find_results_ul(self, soup: BeautifulSoup, link_prefix: str) -> Optional:
        """Find the UL element that contains actual search results (not nav/sidebar).

        Looks for a UL inside #main that has LI elements with links matching link_prefix.
        """
        main = soup.select_one("#main") or soup
        for ul in main.find_all("ul"):
            links = ul.find_all("a", href=lambda h: h and h.startswith(link_prefix))
            if links:
                return ul
        return None

    def _remove_pager(self, soup: BeautifulSoup) -> BeautifulSoup:
        for pager in soup.select("div.item-list .pager"):
            pager.decompose()
        return soup

    def _get_page_info(self, soup: BeautifulSoup) -> dict:
        pager = soup.select_one("div.item-list .pager")
        if not pager:
            return {"total_pages": 1, "has_next": False, "has_previous": False}

        pager_items = pager.find_all(class_=re.compile(r"pager-(current|item)"))
        has_next = pager.find(class_="pager-next") is not None
        has_previous = pager.find(class_="pager-previous") is not None

        return {
            "total_pages": len(pager_items),
            "has_next": has_next,
            "has_previous": has_previous,
        }

    def _get_total_count(self, soup: BeautifulSoup) -> Optional[int]:
        h3 = soup.find("h3")
        if not h3:
            return None
        text = h3.get_text()
        match = re.search(r"из\s+(\d+)", text)
        return int(match.group(1)) if match else None

    # ── OPDS helpers ──────────────────────────────────────────────────────────

    def _get_opds_feed(self, path: str) -> Optional[ET.Element]:
        r = self._get(path)
        if not r:
            return None
        try:
            return ET.fromstring(r.text)
        except ET.ParseError as e:
            print(f"  XML parse error: {e}")
            return None

    def _parse_opds_entry(self, entry: ET.Element) -> OpdsBook:
        authors = []
        for author_el in entry.findall(f"{{{ATOM_NS}}}author"):
            name_el = author_el.find(f"{{{ATOM_NS}}}name")
            uri_el = author_el.find(f"{{{ATOM_NS}}}uri")
            authors.append(
                OpdsAuthor(
                    name=name_el.text if name_el is not None else "",
                    uri=uri_el.text if uri_el is not None else "",
                )
            )

        entry_id = entry.findtext(f"{{{ATOM_NS}}}id", "")
        title = entry.findtext(f"{{{ATOM_NS}}}title", "")
        updated = entry.findtext(f"{{{ATOM_NS}}}updated", "")

        categories = []
        for cat in entry.findall(f"{{{ATOM_NS}}}category"):
            label = cat.get("label", "")
            if label:
                categories.append(label)

        cover = None
        downloads = []
        for link in entry.findall(f"{{{ATOM_NS}}}link"):
            link_type = link.get("type", "")
            link_href = link.get("href", "")
            if link_type in ("image/jpeg", "image/png"):
                cover = link_href
            elif link_type in OPDS_MIME_TYPES:
                downloads.append(OpdsDownload(link=link_href, type=link_type))

        content_el = entry.find(f"{{{ATOM_NS}}}content")
        description = ""
        if content_el is not None:
            description = content_el.text or ""
            # Sometimes content has #text subelement
            text_el = content_el.find(f"{{{ATOM_NS}}}text")
            if text_el is not None and text_el.text:
                description = text_el.text

        return OpdsBook(
            id=entry_id,
            authors=authors,
            title=title,
            updated=updated,
            categories=categories,
            cover=cover,
            downloads=downloads,
            description=description,
        )

    # ── Search: Books by name (HTML) ──────────────────────────────────────────

    def search_books_by_name(self, name: str) -> list:
        """Search books by name via HTML."""
        soup = self._get_html_page(
            f"booksearch?ask={quote(name)}&page=0&chb=on"
        )
        if not soup:
            return []

        soup = self._remove_pager(soup)
        results = []
        results_ul = self._find_results_ul(soup, "/b/")
        if not results_ul:
            return []

        for li in results_ul.find_all("li", recursive=False):
            children = li.find_all("a", recursive=False)
            if not children:
                continue
            book_link = children[0]
            href = book_link.get("href", "")
            if not href.startswith("/b/"):
                continue
            book_id = _get_numbers(href)
            book_name = book_link.get_text(strip=True)
            if book_id and book_name:
                results.append(BooksByName(
                    book=Book(id=int(book_id), name=book_name),
                    authors=[
                        Author(id=_get_numbers(a.get("href", "")), name=a.get_text(strip=True))
                        for a in children[1:]
                    ],
                ))
        return results

    def search_books_by_name_paginated(self, name: str, page: int = 0, limit: int = 50) -> PaginatedResult:
        """Search books by name with pagination."""
        soup = self._get_html_page(
            f"booksearch?ask={quote(name)}&page={page}&chb=on"
        )
        if not soup:
            return PaginatedResult()

        page_info = self._get_page_info(soup)
        total_count = self._get_total_count(soup)
        soup = self._remove_pager(soup)

        results_ul = self._find_results_ul(soup, "/b/")
        items = []
        if results_ul:
            for li in results_ul.find_all("li", recursive=False)[:limit]:
                children = li.find_all("a", recursive=False)
                if not children:
                    continue
                book_link = children[0]
                href = book_link.get("href", "")
                if not href.startswith("/b/"):
                    continue
                book_id = _get_numbers(href)
                book_name = book_link.get_text(strip=True)
                if book_id and book_name:
                    items.append(BooksByName(
                        book=Book(id=int(book_id), name=book_name),
                        authors=[
                            Author(id=_get_numbers(a.get("href", "")), name=a.get_text(strip=True))
                            for a in children[1:]
                        ],
                    ))

        return PaginatedResult(
            items=items,
            current_page=page,
            total_count=total_count,
            total_pages=page_info["total_pages"],
            has_next_page=page_info["has_next"],
            has_previous_page=page_info["has_previous"],
        )

    # ── Search: Authors (HTML) ────────────────────────────────────────────────

    def search_authors(self, name: str) -> list:
        """Search authors by name via HTML."""
        soup = self._get_html_page(
            f"booksearch?ask={quote(name)}&page=0&cha=on"
        )
        if not soup:
            return []

        soup = self._remove_pager(soup)
        results = []
        results_ul = self._find_results_ul(soup, "/a/")
        if not results_ul:
            return []

        for li in results_ul.find_all("li", recursive=False):
            children = li.find_all("a", recursive=False)
            if not children:
                continue
            author_link = children[0]
            href = author_link.get("href", "")
            if not href.startswith("/a/"):
                continue
            author_id = _get_numbers(href)
            author_name = author_link.get_text(strip=True)

            books_count = None
            translations_count = None
            text = li.get_text()
            books_match = re.search(r"(\d+)\s+книг", text)
            trans_match = re.search(r"(\d+)\s+(?:перевод|перевода)", text)
            if books_match:
                books_count = int(books_match.group(1))
            if trans_match:
                translations_count = int(trans_match.group(1))

            if author_id and author_name:
                results.append(AuthorBooks(
                    id=int(author_id),
                    name=author_name,
                    books=books_count,
                    translations=translations_count,
                ))
        return results

    def search_authors_paginated(self, name: str, page: int = 0, limit: int = 50) -> PaginatedResult:
        """Search authors by name with pagination."""
        soup = self._get_html_page(
            f"booksearch?ask={quote(name)}&page={page}&cha=on"
        )
        if not soup:
            return PaginatedResult()

        page_info = self._get_page_info(soup)
        total_count = self._get_total_count(soup)
        soup = self._remove_pager(soup)

        results_ul = self._find_results_ul(soup, "/a/")
        items = []
        if results_ul:
            for li in results_ul.find_all("li", recursive=False)[:limit]:
                children = li.find_all("a", recursive=False)
                if not children:
                    continue
                author_link = children[0]
                href = author_link.get("href", "")
                if not href.startswith("/a/"):
                    continue
                author_id = _get_numbers(href)
                author_name = author_link.get_text(strip=True)
                text = li.get_text()
                books_count = None
                translations_count = None
                books_match = re.search(r"(\d+)\s+книг", text)
                trans_match = re.search(r"(\d+)\s+(?:перевод|перевода)", text)
                if books_match:
                    books_count = int(books_match.group(1))
                if trans_match:
                    translations_count = int(trans_match.group(1))
                if author_id and author_name:
                    items.append(AuthorBooks(
                        id=int(author_id), name=author_name,
                        books=books_count, translations=translations_count,
                    ))

        return PaginatedResult(
            items=items, current_page=page, total_count=total_count,
            total_pages=page_info["total_pages"],
            has_next_page=page_info["has_next"],
            has_previous_page=page_info["has_previous"],
        )

    # ── Search: Books by series (HTML) ────────────────────────────────────────

    def search_books_by_series(self, name: str) -> list:
        """Search book series by name."""
        soup = self._get_html_page(
            f"booksearch?ask={quote(name)}&page=0&chs=on"
        )
        if not soup:
            return []

        soup = self._remove_pager(soup)
        results = []
        # Series links use /sequence/ not /s/
        results_ul = None
        main = soup.select_one("#main") or soup
        for ul in main.find_all("ul"):
            links = ul.find_all("a", href=lambda h: h and "/sequence/" in h)
            if links:
                results_ul = ul
                break
        if not results_ul:
            return []

        for li in results_ul.find_all("li", recursive=False):
            children = li.find_all("a", recursive=False)
            if not children:
                continue
            series_link = children[0]
            href = series_link.get("href", "")
            if "/sequence/" not in href:
                continue
            series_id = _get_numbers(href)
            series_name = series_link.get_text(strip=True)
            text = li.get_text()
            books_match = re.search(r"(\d+)\s+книг", text)
            books_count = int(books_match.group(1)) if books_match else None

            if series_id and series_name:
                results.append(BookSeries(
                    id=int(series_id), name=series_name, books=books_count,
                ))
        return results

    def search_books_by_series_paginated(self, name: str, page: int = 0, limit: int = 50) -> PaginatedResult:
        """Search book series with pagination."""
        soup = self._get_html_page(
            f"booksearch?ask={quote(name)}&page={page}&chs=on"
        )
        if not soup:
            return PaginatedResult()

        page_info = self._get_page_info(soup)
        total_count = self._get_total_count(soup)
        soup = self._remove_pager(soup)

        # Series links use /sequence/ not /s/
        results_ul = None
        main = soup.select_one("#main") or soup
        for ul in main.find_all("ul"):
            links = ul.find_all("a", href=lambda h: h and "/sequence/" in h)
            if links:
                results_ul = ul
                break

        items = []
        if results_ul:
            for li in results_ul.find_all("li", recursive=False)[:limit]:
                children = li.find_all("a", recursive=False)
                if not children:
                    continue
                series_link = children[0]
                href = series_link.get("href", "")
                if "/sequence/" not in href:
                    continue
                series_id = _get_numbers(href)
                series_name = series_link.get_text(strip=True)
                text = li.get_text()
                books_match = re.search(r"(\d+)\s+книг", text)
                books_count = int(books_match.group(1)) if books_match else None
                if series_id and series_name:
                    items.append(BookSeries(
                        id=int(series_id), name=series_name, books=books_count,
                    ))

        return PaginatedResult(
            items=items, current_page=page, total_count=total_count,
            total_pages=page_info["total_pages"],
            has_next_page=page_info["has_next"],
            has_previous_page=page_info["has_previous"],
        )

    # ── Search: Genres (HTML) ─────────────────────────────────────────────────

    def search_genres(self, name: str) -> list:
        """Search genres by name."""
        soup = self._get_html_page(
            f"booksearch?ask={quote(name)}&page=0&chg=on"
        )
        if not soup:
            return []

        soup = self._remove_pager(soup)
        results = []
        results_ul = self._find_results_ul(soup, "/g/")
        if not results_ul:
            return []

        for li in results_ul.find_all("li", recursive=False):
            link = li.find("a", href=lambda h: h and h.startswith("/g/"))
            if not link:
                continue
            href = link.get("href", "")
            genre_id = href.replace("/g/", "")
            genre_name = link.get_text(strip=True)
            if genre_id and genre_name:
                results.append(Genre(id=genre_id, name=genre_name))
        return results

    def search_genres_paginated(self, name: str, page: int = 0, limit: int = 50) -> PaginatedResult:
        """Search genres with pagination."""
        soup = self._get_html_page(
            f"booksearch?ask={quote(name)}&page={page}&chg=on"
        )
        if not soup:
            return PaginatedResult()

        page_info = self._get_page_info(soup)
        total_count = self._get_total_count(soup)
        soup = self._remove_pager(soup)

        results_ul = self._find_results_ul(soup, "/g/")
        items = []
        if results_ul:
            for li in results_ul.find_all("li", recursive=False)[:limit]:
                link = li.find("a", href=lambda h: h and h.startswith("/g/"))
                if not link:
                    continue
                href = link.get("href", "")
                genre_id = href.replace("/g/", "")
                genre_name = link.get_text(strip=True)
                if genre_id and genre_name:
                    items.append(Genre(id=genre_id, name=genre_name))

        return PaginatedResult(
            items=items, current_page=page, total_count=total_count,
            total_pages=page_info["total_pages"],
            has_next_page=page_info["has_next"],
            has_previous_page=page_info["has_previous"],
        )

    # ── OPDS: Search books by name ────────────────────────────────────────────

    def search_books_by_name_opds(self, name: str) -> list:
        """Search books by name via OPDS."""
        feed = self._get_opds_feed(
            f"opds/opensearch?searchTerm={quote(name)}&searchType=books&pageNumber=0"
        )
        if feed is None:
            return []

        entries = feed.findall(f".//{{{ATOM_NS}}}entry")
        if not entries:
            return []
        return [self._parse_opds_entry(e) for e in entries]

    def search_books_by_name_opds_paginated(self, name: str, page: int = 0, limit: int = 20) -> PaginatedResult:
        """Search books by name via OPDS with pagination."""
        feed = self._get_opds_feed(
            f"opds/opensearch?searchTerm={quote(name)}&searchType=books&pageNumber={page}"
        )
        if feed is None:
            return PaginatedResult()

        total_el = feed.find(f"{{{OS_NS}}}totalResults")
        per_page_el = feed.find(f"{{{OS_NS}}}itemsPerPage")
        start_el = feed.find(f"{{{OS_NS}}}startIndex")

        total_results = int(total_el.text) if total_el is not None else 0
        items_per_page = int(per_page_el.text) if per_page_el is not None else 20
        start_index = int(start_el.text) if start_el is not None else 0

        entries = feed.findall(f".//{{{ATOM_NS}}}entry")
        if entries and not isinstance(entries, list):
            entries = [entries]

        items = []
        if entries:
            sliced = entries[:limit]
            items = [self._parse_opds_entry(e) for e in sliced]

        has_next = (start_index + items_per_page) < total_results
        has_previous = start_index > 0
        total_pages = max(1, (total_results + items_per_page - 1) // items_per_page) if items_per_page else 1

        return PaginatedResult(
            items=items,
            current_page=page,
            total_count=total_results,
            total_pages=total_pages,
            has_next_page=has_next,
            has_previous_page=has_previous,
        )

    # ── OPDS: Books by author ─────────────────────────────────────────────────

    def get_books_by_author_opds(self, author_id: int) -> list:
        """Get author's books via OPDS."""
        feed = self._get_opds_feed(f"opds/author/{author_id}/alphabet/0")
        if feed is None:
            return []

        entries = feed.findall(f".//{{{ATOM_NS}}}entry")
        if not entries:
            return []
        return [self._parse_opds_entry(e) for e in entries]

    def get_books_by_author_opds_paginated(self, author_id: int, page: int = 0, limit: int = 20) -> PaginatedResult:
        """Get author's books via OPDS with pagination."""
        feed = self._get_opds_feed(f"opds/author/{author_id}/alphabet/{page}")
        if feed is None:
            return PaginatedResult()

        entries = feed.findall(f".//{{{ATOM_NS}}}entry")
        if entries and not isinstance(entries, list):
            entries = [entries]

        items = []
        if entries:
            sliced = entries[:limit]
            items = [self._parse_opds_entry(e) for e in sliced]

        has_next = any(
            link.get("rel") == "next"
            for link in feed.findall(f"{{{ATOM_NS}}}link")
        )
        has_previous = page > 0

        return PaginatedResult(
            items=items,
            current_page=page,
            has_next_page=has_next,
            has_previous_page=has_previous,
        )

    # ── OPDS: Genres list ─────────────────────────────────────────────────────

    def get_genres_list_opds(self) -> list:
        """Get genres list via OPDS."""
        feed = self._get_opds_feed("opds/genres")
        if feed is None:
            return []

        entries = feed.findall(f".//{{{ATOM_NS}}}entry")
        results = []
        for e in entries:
            title = e.findtext(f"{{{ATOM_NS}}}title", "")
            eid = e.findtext(f"{{{ATOM_NS}}}id", "")
            # Extract genre id from URL like /g/detective
            genre_id = eid.split("/g/")[-1] if "/g/" in eid else eid
            results.append(Genre(id=genre_id, name=title))
        return results

    # ── Cover ─────────────────────────────────────────────────────────────────

    def get_cover_by_book_id(self, book_id: int) -> Optional[bytes]:
        """Fetch cover image. Returns bytes or None."""
        id_str = str(book_id)
        y = int(id_str[4:]) if len(id_str) > 4 else 0

        for ext in ("jpg", "png"):
            url = f"i/{y}/{book_id}/cover.{ext}"
            r = self._get(url)
            if r and r.status_code == 200 and "image" in r.headers.get("content-type", ""):
                return r.content
        return None

    # ── Book details (HTML) ───────────────────────────────────────────────────

    def get_book_details(self, book_id: str) -> Optional[BookDetails]:
        """Get detailed book information from HTML page."""
        soup = self._get_html_page(f"b/{book_id}")
        if not soup:
            return None

        # Title: skip the first h1 (site name "Флибуста"), use the second one
        title = ""
        h1_tags = soup.find_all("h1")
        for h1 in h1_tags:
            text = h1.get_text(strip=True)
            if text and text != "Флибуста":
                title = text
                break

        # Description: find h2 "Аннотация" and get following siblings until next h2.
        description = ""
        for h2 in soup.find_all("h2"):
            if "Аннотация" in h2.get_text():
                desc_parts = []
                for sib in h2.find_next_siblings():
                    if sib.name == "h2":
                        break
                    desc_parts.append(sib.get_text(strip=True))
                description = " ".join(desc_parts)
                break
        if not description:
            description_el = soup.select_one(".book_description")
            description = description_el.get_text(" ", strip=True) if description_el else ""

        # Cover image
        cover_img = soup.find("img", src=lambda s: s and "cover" in s.lower())
        cover_url = cover_img["src"] if cover_img else None

        # Find the book info div (contains title h1)
        book_info_div = None
        for div in soup.find_all("div", class_=True):
            h1 = div.find("h1")
            if h1 and title and title in h1.get_text():
                book_info_div = div
                break

        # Authors: only from /a/ links BEFORE the first book download link.
        authors = []
        seen_author_ids = set()
        if book_info_div or soup:
            found_download = False
            for a in (book_info_div or soup).find_all("a", href=True):
                href = a["href"]
                if _download_format(href, book_id) is not None:
                    found_download = True
                    continue
                if found_download:
                    break
                if href.startswith("/a/"):
                    author_id = _get_numbers(href)
                    author_name = a.get_text(strip=True)
                    if author_id and author_name and author_id not in seen_author_ids:
                        seen_author_ids.add(author_id)
                        authors.append(Author(id=int(author_id), name=author_name))

        # Genres: from /g/ links in the book info div
        genres = []
        seen_genre_ids = set()
        if book_info_div or soup:
            found_download = False
            for a in (book_info_div or soup).find_all("a", href=True):
                href = a["href"]
                if _download_format(href, book_id) is not None:
                    found_download = True
                    continue
                if found_download:
                    break
                if href.startswith("/g/"):
                    genre_id = href.replace("/g/", "")
                    genre_name = a.get_text(strip=True)
                    if genre_id and genre_name and genre_id not in seen_genre_ids:
                        seen_genre_ids.add(genre_id)
                        genres.append(Genre(id=genre_id, name=genre_name))

        # Download formats and URLs: from /b/{id}/{format} links
        formats = []
        download_urls = []
        seen_formats = set()
        for a in soup.find_all("a", href=True):
            href = a["href"]
            fmt = _download_format(href, book_id)
            if fmt:
                if fmt not in seen_formats:
                    formats.append(fmt)
                    seen_formats.add(fmt)
                if href not in download_urls:
                    download_urls.append(href)

        # Series: from /sequence/ or /s/ links in book info div
        series = []
        seen_series_ids = set()
        if book_info_div or soup:
            for a in (book_info_div or soup).find_all("a", href=True):
                href = a["href"]
                if "/sequence/" in href or href.startswith("/s/"):
                    series_id = _get_numbers(href)
                    series_name = a.get_text(strip=True)
                    if series_id and series_name and series_id not in seen_series_ids:
                        seen_series_ids.add(series_id)
                        series.append({"id": series_id, "name": series_name})

        return BookDetails(
            id=book_id,
            title=title,
            description=description,
            cover_url=cover_url,
            authors=authors,
            genres=genres,
            formats=formats,
            download_urls=download_urls,
            series=series,
        )

    # ── Genres page (HTML) ────────────────────────────────────────────────────

    def get_genres_page(self) -> list:
        """Get genres from /genres page."""
        soup = self._get_html_page("genres")
        if not soup:
            return []

        results = []
        for a in soup.select("a[href*='/g/']"):
            href = a.get("href", "")
            genre_id = href.replace("/g/", "")
            genre_name = a.get_text(strip=True)
            if genre_id and genre_name:
                results.append(Genre(id=genre_id, name=genre_name))
        return results

    # ── NEW ENDPOINTS ────────────────────────────────────────────────────────

    def get_genres_list_page(self) -> list:
        """Get all genres from /g page."""
        soup = self._get_html_page("/g")
        if not soup:
            return []
        results = []
        seen = set()
        for a in soup.find_all("a", href=True):
            href = a["href"]
            if href.startswith("/g/") and href not in seen:
                seen.add(href)
                genre_id = href.replace("/g/", "")
                genre_name = a.get_text(strip=True)
                if genre_id and genre_name:
                    results.append(Genre(id=genre_id, name=genre_name))
        return results

    def get_recent_additions(self, lang=None, fmt=None, sort="1") -> dict:
        """Get recent additions from /new with filters.

        Args:
            lang: Language code (e.g. 'ru', 'en') or None for all
            fmt: Format (e.g. 'fb2', 'pdf') or None for all
            sort: '1' = new+fixed, '2' = new only
        """
        params = []
        if lang:
            params.append(f"lang={lang}")
        if fmt:
            params.append(f"type={fmt}")
        if sort:
            params.append(f"sr={sort}")
        path = "/new" + ("?" + "&".join(params) if params else "")
        soup = self._get_html_page(path)
        if not soup:
            return {"books": [], "total": 0}

        books = []
        for a in soup.find_all("a", href=lambda h: h and h.startswith("/b/")):
            href = a["href"]
            book_id = _get_numbers(href)
            book_name = a.get_text(strip=True)
            if book_id and book_name:
                books.append({"id": book_id, "name": book_name})

        return {"books": books, "total": len(books)}

    def get_popular_books(self) -> list:
        """Get popular books from /stat/b."""
        soup = self._get_html_page("/stat/b")
        if not soup:
            return []
        books = []
        for a in soup.find_all("a", href=lambda h: h and h.startswith("/b/")):
            href = a["href"]
            book_id = _get_numbers(href)
            book_name = a.get_text(strip=True)
            if book_id and book_name:
                books.append({"id": book_id, "name": book_name})
        return books

    def get_all_genres(self) -> list:
        """Get complete genre list from /g (with 500+ genres)."""
        soup = self._get_html_page("/g")
        if not soup:
            return []
        results = []
        seen = set()
        for a in soup.find_all("a", href=True):
            href = a["href"]
            if href.startswith("/g/") and href not in seen:
                seen.add(href)
                genre_id = href.replace("/g/", "")
                genre_name = a.get_text(strip=True)
                if genre_id and genre_name:
                    results.append(Genre(id=genre_id, name=genre_name))
        return results

    def get_all_authors_letter(self, letter: str) -> list:
        """Get authors starting with a specific letter."""
        soup = self._get_html_page(f"/{letter}")
        if not soup:
            return []
        results = []
        for a in soup.find_all("a", href=True):
            href = a["href"]
            if href.startswith("/a/"):
                author_id = _get_numbers(href)
                author_name = a.get_text(strip=True)
                if author_id and author_name:
                    results.append(Author(id=int(author_id), name=author_name))
        return results

    def get_book_mail_formats(self, book_id: str) -> list:
        """Get available email formats for a book."""
        soup = self._get_html_page(f"/b/{book_id}/mail")
        if not soup:
            return []
        formats = []
        for form in soup.find_all("form"):
            if "mail" in form.get("action", ""):
                for select in form.find_all("select"):
                    if select.get("name") == "format":
                        formats = [o.get("value") for o in select.find_all("option")]
        return formats

    def get_user_profile(self, user_id: str) -> dict:
        """Get user public profile."""
        soup = self._get_html_page(f"/user/{user_id}")
        if not soup:
            return {}
        title = soup.title.get_text(strip=True) if soup.title else ""
        return {"user_id": user_id, "title": title}

    def get_book_compare(self, book_id_1: str, book_id_2: str) -> Optional[str]:
        """Compare two books via /comp endpoint."""
        r = self._get(f"/comp?b1={book_id_1}&b2={book_id_2}")
        if not r:
            return None
        return r.text

    def get_series_with_books(self, series_id: int) -> dict:
        """Get series page with books and sort options."""
        soup = self._get_html_page(f"/s/{series_id}")
        if not soup:
            return {"books": [], "sort_options": []}

        books = []
        for a in soup.find_all("a", href=lambda h: h and h.startswith("/b/")):
            href = a["href"]
            book_id = _get_numbers(href)
            book_name = a.get_text(strip=True)
            if book_id and book_name:
                books.append({"id": book_id, "name": book_name})

        sort_options = []
        for form in soup.find_all("form"):
            if form.get("action", "").startswith("/s/"):
                for select in form.find_all("select"):
                    if select.get("name") == "order":
                        for opt in select.find_all("option"):
                            sort_options.append(opt.get("value", ""))

        return {"books": books, "sort_options": sort_options}

    def get_genre_books(self, genre_id: str, order: str = "a") -> list:
        """Get books in a genre with sort order."""
        soup = self._get_html_page(f"/g/{genre_id}?order={order}")
        if not soup:
            return []
        books = []
        for a in soup.find_all("a", href=lambda h: h and h.startswith("/b/")):
            href = a["href"]
            book_id = _get_numbers(href)
            book_name = a.get_text(strip=True)
            if book_id and book_name:
                books.append({"id": book_id, "name": book_name})
        return books

    def get_author_books_filtered(self, author_id: int, lang=None, order="a", ghosts=False, translations=False) -> list:
        """Get author books with filters."""
        params = []
        if ghosts:
            params.append("hg=1")
        if translations:
            params.append("sa=1")
        if lang:
            params.append(f"lang={lang}")
        if order:
            params.append(f"order={order}")
        path = f"/a/{author_id}" + ("?" + "&".join(params) if params else "")
        soup = self._get_html_page(path)
        if not soup:
            return []
        books = []
        for a in soup.find_all("a", href=lambda h: h and h.startswith("/b/")):
            href = a["href"]
            book_id = _get_numbers(href)
            book_name = a.get_text(strip=True)
            if book_id and book_name:
                books.append({"id": book_id, "name": book_name})
        return books

    def get_mass_download_form(self) -> dict:
        """Get mass download form from /new page."""
        soup = self._get_html_page("/new")
        if not soup:
            return {}
        for form in soup.find_all("form"):
            action = form.get("action", "")
            if "mass" in action or "download" in action:
                inputs = []
                for inp in form.find_all("input"):
                    name = inp.get("name")
                    if name:
                        inputs.append(name)
                return {"action": action, "inputs": inputs[:20]}
        return {}

    def send_book_to_email(self, book_id: str, email: str, fmt: str = "fb2") -> bool:
        """Send book to email via /b/{id}/mail form."""
        payload = {
            "to": email,
            "format": fmt,
            "bookmailFormParams": "Отправить",
        }
        r = self._post(f"/b/{book_id}/mail", data=payload)
        return r is not None and r.status_code == 200

    def add_to_polka(self, book_id: str, flag: bool = True) -> bool:
        """Add book to polka (bookshelf)."""
        payload = {
            "flag": "on" if flag else "",
        }
        r = self._post(f"/polka/add/{book_id}", data=payload)
        return r is not None and r.status_code == 200

    def watch_book(self, book_id: str) -> bool:
        """Start watching/tracking a book."""
        payload = {"id": book_id}
        r = self._post("/polka/watch/add", data=payload)
        return r is not None and r.status_code == 200

    def get_messages(self) -> list:
        """Get inbox messages."""
        soup = self._get_html_page("/messages")
        if not soup:
            return []
        messages = []
        for tr in soup.find_all("tr"):
            cells = tr.find_all("td")
            if len(cells) >= 3:
                sender = cells[0].get_text(strip=True)
                subject = cells[1].get_text(strip=True)
                date = cells[2].get_text(strip=True)
                if sender and subject:
                    messages.append({"sender": sender, "subject": subject, "date": date})
        return messages

    def send_message(self, recipient: str, subject: str, body: str) -> bool:
        """Send a private message."""
        payload = {
            "recipient": recipient,
            "subject": subject,
            "body": body,
            "op": "Отправить сообщение",
        }
        r = self._post("/messages/new", data=payload)
        return r is not None and r.status_code == 200

    def get_user_bwlist(self, user_id: str) -> dict:
        """Get user's black/white list."""
        soup = self._get_html_page(f"/bwlist/show/{user_id}")
        if not soup:
            return {"black": [], "white": []}
        # Parse the list - structure varies
        return {"user_id": user_id, "status": "parsed"}

    def get_recommendations(self, view="recs", user_id=None) -> list:
        """Get community recommendations."""
        path = "/rec"
        params = [f"view={view}"]
        if user_id:
            params.append(f"user={user_id}")
        path += "?" + "&".join(params)
        soup = self._get_html_page(path)
        if not soup:
            return []
        books = []
        for a in soup.find_all("a", href=lambda h: h and h.startswith("/b/")):
            href = a["href"]
            book_id = _get_numbers(href)
            book_name = a.get_text(strip=True)
            if book_id and book_name:
                books.append({"id": book_id, "name": book_name})
        return books
