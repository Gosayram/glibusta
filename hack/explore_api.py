#!/usr/bin/env python3
"""Flibusta API Research — focused, fast"""

import json
from pathlib import Path
from urllib.parse import urljoin
from xml.etree import ElementTree as ET

import requests
import urllib3
from bs4 import BeautifulSoup

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

OUTPUT = Path("/tmp/flibusta_pars")
OUTPUT.mkdir(exist_ok=True)

def load_url() -> str:
    env = Path(__file__).parent.parent / ".env"
    if env.exists():
        for line in env.read_text().splitlines():
            if line.startswith("BASE_URL="):
                return line.split("=", 1)[1].strip()
    return "http://flibusta.is"

BASE = load_url()
S = requests.Session()
S.headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"

def get(path: str) -> requests.Response | None:
    try:
        return S.get(urljoin(BASE, path), timeout=15, verify=False)
    except Exception as e:
        print(f"  ERR {path}: {e}")
        return None

def post(path: str, data: dict) -> requests.Response | None:
    try:
        return S.post(urljoin(BASE, path), data=data, timeout=15, verify=False,
                      allow_redirects=True)
    except Exception as e:
        print(f"  ERR POST {path}: {e}")
        return None

def save(name: str, data) -> None:
    p = OUTPUT / name
    if isinstance(data, (dict, list)):
        p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    else:
        p.write_text(str(data), encoding="utf-8")
    print(f"  -> {p.name}")

def soup(html: str) -> BeautifulSoup:
    return BeautifulSoup(html, "html.parser")

def links(html: str) -> list[dict]:
    s = soup(html)
    result = []
    for a in s.find_all("a", href=True):
        result.append({"href": a["href"], "text": a.get_text(strip=True)[:100]})
    return result

# ── 1. Main ──────────────────────────────
def probe_main():
    print("\n=== 1. MAIN PAGE ===")
    r = get("/")
    if not r:
        return
    save("01_main.html", r.text)

    all_links = links(r.text)
    save("02_all_links.json", all_links)

    auth = [l for l in all_links if any(k in (l["href"] + l["text"]).lower()
            for k in ["login", "auth", "register", "user", "профил", "вход", "openid"])]
    save("03_auth.json", auth)
    print(f"  Auth links ({len(auth)}):")
    for a in auth:
        print(f"    [{a['text']}] -> {a['href']}")

# ── 2. OPDS ──────────────────────────────
def probe_opds():
    print("\n=== 2. OPDS ===")
    for p in ["/opds/", "/opds/popular", "/opds/recent", "/opds/genres", "/opds/authors"]:
        r = get(p)
        if r:
            name = p.replace("/", "_")
            save(f"04_opds_{name}.html", r.text)
            print(f"  {p}: {r.status_code} ({len(r.text)}b)")

# ── 3. OPDS XML search ───────────────────
def probe_opds_search():
    print("\n=== 3. OPDS SEARCH (XML) ===")
    r = get("/opds/opensearch?searchTerm=Толстой&searchType=books&pageNumber=0")
    if not r:
        return
    save("05_opds_search.xml", r.text)
    try:
        ns = {"a": "http://www.w3.org/2005/Atom", "os": "http://a9.com/-/spec/opensearch/1.1/"}
        root = ET.fromstring(r.text)
        total = root.findtext("os:totalResults", namespaces=ns)
        per_page = root.findtext("os:itemsPerPage", namespaces=ns)
        start = root.findtext("os:startIndex", namespaces=ns)
        entries = root.findall("a:entry", namespaces=ns)
        print(f"  total={total} perPage={per_page} startIndex={start} entries={len(entries)}")
        books = []
        for e in entries[:5]:
            t = e.findtext("a:title", namespaces=ns)
            eid = e.findtext("a:id", namespaces=ns)
            links_el = e.findall("a:link", namespaces=ns)
            link_hrefs = [l.get("href", "") for l in links_el]
            authors_el = e.findall("a:author/a:name", namespaces=ns)
            author_names = [a.text for a in authors_el if a.text]
            cats = e.findall("a:category", namespaces=ns)
            cat_labels = [c.get("label", "") for c in cats]
            content = e.findtext("a:content", namespaces=ns) or ""
            print(f"  BOOK: {t} | id={eid} | authors={author_names}")
            print(f"        links={link_hrefs[:3]} cats={cat_labels[:3]}")
            print(f"        desc={content[:120]}...")
            books.append({
                "title": t, "id": eid, "links": link_hrefs,
                "authors": author_names, "categories": cat_labels,
                "description": content[:500],
            })
        save("06_opds_books.json", books)
    except Exception as ex:
        print(f"  XML error: {ex}")

# ── 4. HTML search ───────────────────────
def probe_search():
    print("\n=== 4. HTML SEARCH ===")
    for label, path in [
        ("books", "/booksearch?ask=Толстой&chb=on"),
        ("authors", "/authorsearch?ask=Толстой"),
        ("series", "/series?search=Толстой"),
    ]:
        r = get(path)
        if r:
            save(f"07_search_{label}.html", r.text)
            s = soup(r.text)
            items = s.select("ul li")
            print(f"  {label}: {len(items)} items")

# ── 5. Book details ──────────────────────
def probe_book(bid: str):
    print(f"\n=== 5. BOOK #{bid} ===")
    r = get(f"/b/{bid}")
    if not r:
        return
    save(f"08_book_{bid}.html", r.text)
    s = soup(r.text)

    h1 = s.find("h1")
    print(f"  Title: {h1.get_text(strip=True) if h1 else 'N/A'}")

    img = s.find("img", src=True)
    if img:
        print(f"  Cover: {img['src']}")

    desc = s.find("div", id="book_description") or s.find("div", class_="book_description")
    if desc:
        print(f"  Desc: {desc.get_text(strip=True)[:150]}...")

    dls = [a for a in s.find_all("a", href=True)
           if "/download/" in a["href"]
           or any(a["href"].endswith(ext) for ext in [".fb2", ".epub", ".txt", ".mobi", ".pdf", ".djvu"])]
    print(f"  Downloads: {len(dls)}")
    for d in dls[:8]:
        print(f"    {d.get_text(strip=True)}: {d['href']}")

    # Проверяем наличие Opds-ссылок
    opds = [a for a in s.find_all("a", href=True) if "opds" in a["href"].lower()]
    if opds:
        print(f"  OPDS links: {len(opds)}")
        for o in opds[:3]:
            print(f"    {o.get_text(strip=True)}: {o['href']}")

# ── 6. Auth pages ────────────────────────
def probe_auth():
    print("\n=== 6. AUTH PAGES ===")
    for p in ["/user/register", "/user/login", "/user/password", "/user", "/my"]:
        r = get(p)
        if r:
            name = p.replace("/", "_")
            save(f"09_auth_{name}.html", r.text)
            s = soup(r.text)
            forms = s.find_all("form")
            print(f"\n  {p}: {r.status_code}, forms={len(forms)}")
            for f in forms:
                action = f.get("action", "N/A")
                method = f.get("method", "GET").upper()
                inputs = [i.get("name") for i in f.find_all("input") if i.get("name")]
                textareas = [t.get("name") for t in f.find_all("textarea") if t.get("name")]
                selects = [sl.get("name") for sl in f.find_all("select") if sl.get("name")]
                fields = inputs + textareas + selects
                print(f"    FORM: {method} {action}")
                print(f"    Fields: {fields}")

# ── 7. Genres ────────────────────────────
def probe_genres():
    print("\n=== 7. GENRES ===")
    r = get("/genres")
    if not r:
        return
    save("10_genres.html", r.text)
    s = soup(r.text)
    genre_links = s.select("a[href*='/g/']")
    print(f"  Genre links: {len(genre_links)}")
    for g in genre_links[:15]:
        print(f"    {g.get_text(strip=True)}: {g['href']}")

# ── 8. Author page ───────────────────────
def probe_author(aid: str):
    print(f"\n=== 8. AUTHOR #{aid} ===")
    r = get(f"/a/{aid}")
    if not r:
        return
    save(f"11_author_{aid}.html", r.text)
    s = soup(r.text)
    h1 = s.find("h1")
    print(f"  Name: {h1.get_text(strip=True) if h1 else 'N/A'}")
    book_links = [a for a in s.find_all("a", href=True) if "/b/" in a["href"]]
    print(f"  Book links: {len(book_links)}")
    for b in book_links[:5]:
        print(f"    {b.get_text(strip=True)}: {b['href']}")

# ── 9. OPDS author books ─────────────────
def probe_opds_author_books():
    print("\n=== 9. OPDS AUTHOR BOOKS ===")
    r = get("/opds/opensearch?searchType=authors&searchTerm=Толстой&pageNumber=0")
    if not r:
        return
    save("12_opds_author_search.xml", r.text)
    try:
        ns = {"a": "http://www.w3.org/2005/Atom", "os": "http://a9.com/-/spec/opensearch/1.1/"}
        root = ET.fromstring(r.text)
        entries = root.findall("a:entry", namespaces=ns)
        total = root.findtext("os:totalResults", namespaces=ns)
        print(f"  Total: {total}, entries on page: {len(entries)}")
        authors = []
        for e in entries[:5]:
            t = e.findtext("a:title", namespaces=ns)
            eid = e.findtext("a:id", namespaces=ns)
            print(f"  AUTHOR: {t} | id={eid}")
            authors.append({"title": t, "id": eid})
        save("13_opds_authors.json", authors)
    except Exception as ex:
        print(f"  XML error: {ex}")

# ── 10. OPDS genres list ─────────────────
def probe_opds_genres():
    print("\n=== 10. OPDS GENRES ===")
    r = get("/opds/genres")
    if not r:
        return
    save("14_opds_genres.xml", r.text)
    try:
        ns = {"a": "http://www.w3.org/2005/Atom"}
        root = ET.fromstring(r.text)
        entries = root.findall("a:entry", namespaces=ns)
        print(f"  Genres: {len(entries)}")
        for e in entries[:15]:
            t = e.findtext("a:title", namespaces=ns)
            eid = e.findtext("a:id", namespaces=ns)
            print(f"    {t}: {eid}")
    except Exception as ex:
        print(f"  XML error: {ex}")

# ── 11. Try login with form token ────────
def probe_login_form():
    print("\n=== 11. LOGIN FORM ANALYSIS ===")
    r = get("/user/login")
    if not r:
        return
    s = soup(r.text)
    forms = s.find_all("form")
    for f in forms:
        action = f.get("action", "")
        method = f.get("method", "GET")
        hidden = [(i["name"], i.get("value", "")) for i in f.find_all("input", {"type": "hidden"})]
        visible = [(i["name"], i.get("type", "text")) for i in f.find_all("input") if i.get("type") != "hidden" and i.get("name")]
        print(f"  Form: {method} {action}")
        print(f"  Hidden fields: {hidden}")
        print(f"  Visible fields: {visible}")

# ── Main ─────────────────────────────────
if __name__ == "__main__":
    print(f"BASE: {BASE}\nOutput: {OUTPUT}")
    probe_main()
    probe_opds()
    probe_opds_search()
    probe_opds_author_books()
    probe_opds_genres()
    probe_search()
    probe_book("12345")
    probe_book("1")
    probe_auth()
    probe_genres()
    probe_author("6116")
    probe_login_form()
    print(f"\n{'='*50}\nDone! Results: {OUTPUT}\n{'='*50}")
