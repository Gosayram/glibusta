#!/usr/bin/env python3
"""Test ALL discovered Flibusta endpoints.

Covers books, authors, series, genres, OPDS, search, user features,
messages, polka, recommendations, forum, stats, and more.
"""

import json
import os
import re
import sys
from pathlib import Path
from dataclasses import asdict

sys.path.insert(0, str(Path(__file__).parent))

from bs4 import BeautifulSoup
from flibusta_client import FlibustaClient

RESULTS_DIR = Path(__file__).parent.parent / "test_results" / "hack-endpoints"
RESULTS_DIR.mkdir(parents=True, exist_ok=True)

passed = 0
failed = 0
skipped = 0


def save(name, data):
    p = RESULTS_DIR / name
    if isinstance(data, (dict, list)):
        p.write_text(json.dumps(data, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
    else:
        p.write_text(str(data), encoding="utf-8")


def check(label, condition, detail=""):
    global passed, failed
    if condition:
        passed += 1
        print(f"  ✓ {label}" + (f" — {detail}" if detail else ""))
    else:
        failed += 1
        print(f"  ✗ {label}" + (f" — {detail}" if detail else ""))


def section(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")


def main():
    global passed, failed, skipped

    c = FlibustaClient()
    user = os.environ.get("FLIBUSTA_USER", "")
    pw = os.environ.get("FLIBUSTA_PASSWORD", "")
    logged_in = c.login(user, pw) if user and pw else False

    print(f"Base: {c.base_url}")
    print(f"Auth: {'YES' if logged_in else 'NO'}")
    print(f"Results: {RESULTS_DIR}")

    # ─────────────────────────────────────────────────────────────
    # 1. MAIN PAGE
    # ─────────────────────────────────────────────────────────────
    section("1. MAIN PAGE")
    r = c._get("/")
    check("GET /", r is not None and r.status_code == 200)
    if r:
        soup = BeautifulSoup(r.text, "html.parser")
        nav_links = [a["href"] for a in soup.find_all("a", href=True) if a["href"].startswith("/") and not a["href"].startswith("/node")]
        check("Has navigation links", len(nav_links) > 20, f"{len(nav_links)} links")
        save("01_main.json", {"links": len(nav_links)})

    # ─────────────────────────────────────────────────────────────
    # 2. BOOKS
    # ─────────────────────────────────────────────────────────────
    section("2. BOOKS")

    # /b — index
    r = c._get("/b")
    check("GET /b", r is not None and r.status_code == 200)

    # /b/{id} — details
    r = c._get("/b/226302")
    check("GET /b/226302", r is not None and r.status_code == 200)
    if r:
        soup = BeautifulSoup(r.text, "html.parser")
        h1s = soup.find_all("h1")
        title_h1 = [h for h in h1s if "Флибуста" not in h.get_text()]
        check("Has book title", len(title_h1) > 0, title_h1[0].get_text(strip=True)[:40] if title_h1 else "")

        authors = soup.find_all("a", href=lambda h: h and h.startswith("/a/"))
        check("Has author links", len(authors) > 0)

        formats = []
        for a in soup.find_all("a", href=True):
            m = re.match(r"/b/226302/(\w+)", a["href"])
            if m and m.group(1) != "read":
                formats.append(m.group(1))
        check("Has download formats", len(formats) > 0, str(set(formats)))

        save("02_book_226302.json", {
            "title": title_h1[0].get_text(strip=True) if title_h1 else "",
            "authors": [a.get_text(strip=True) for a in authors[:5]],
            "formats": list(set(formats)),
        })

    # /b/{id}/read — read online
    r = c._get("/b/226302/read")
    check("GET /b/226302/read", r is not None and r.status_code == 200)

    # /b/{id}/download — download page
    r = c._get("/b/226302/download")
    check("GET /b/226302/download", r is not None and r.status_code == 200)

    # /b/{id}/mail — email form (auth)
    if logged_in:
        r = c._get("/b/226302/mail")
        check("GET /b/226302/mail", r is not None and r.status_code == 200)
        if r:
            soup = BeautifulSoup(r.text, "html.parser")
            mail_form = [f for f in soup.find_all("form") if "mail" in f.get("action", "")]
            check("Has mail form", len(mail_form) > 0)
            if mail_form:
                selects = mail_form[0].find_all("select")
                formats = []
                for s in selects:
                    if s.get("name") == "format":
                        formats = [o.get("value") for o in s.find_all("option")]
                check("Mail has format options", len(formats) > 0, str(formats))
                save("02_book_mail.json", {"formats": formats})

    # ─────────────────────────────────────────────────────────────
    # 3. AUTHORS
    # ─────────────────────────────────────────────────────────────
    section("3. AUTHORS")

    r = c._get("/a")
    check("GET /a", r is not None and r.status_code == 200)

    r = c._get("/a/all")
    check("GET /a/all", r is not None and r.status_code == 200)

    r = c._get("/a/6116")
    check("GET /a/6116 (Conan Doyle)", r is not None and r.status_code == 200)
    if r:
        soup = BeautifulSoup(r.text, "html.parser")
        book_links = soup.find_all("a", href=lambda h: h and h.startswith("/b/"))
        check("Author has books", len(book_links) > 10, f"{len(book_links)} books")

        # Check filter form
        forms = soup.find_all("form")
        filter_forms = [f for f in forms if f.get("action", "").startswith("/a/")]
        check("Has filter form", len(filter_forms) > 0)
        if filter_forms:
            selects = filter_forms[0].find_all("select")
            select_names = [s.get("name") for s in selects]
            check("Filter has lang/order", "lang" in select_names and "order" in select_names)

    # Letter pages
    for letter in ["/Aa", "/Bb", "/Sh"]:
        r = c._get(letter)
        check(f"GET {letter}", r is not None and r.status_code == 200)

    # ─────────────────────────────────────────────────────────────
    # 4. SERIES
    # ─────────────────────────────────────────────────────────────
    section("4. SERIES")

    r = c._get("/s")
    check("GET /s (index)", r is not None and r.status_code == 200)
    if r:
        soup = BeautifulSoup(r.text, "html.parser")
        forms = soup.find_all("form")
        series_forms = [f for f in forms if f.get("action", "").startswith("/s")]
        check("Has sort/filter form", len(series_forms) > 0)

    r = c._get("/s/242")
    check("GET /s/242 (series page)", r is not None and r.status_code == 200)
    if r:
        soup = BeautifulSoup(r.text, "html.parser")
        book_links = soup.find_all("a", href=lambda h: h and h.startswith("/b/"))
        check("Series has books", len(book_links) > 5, f"{len(book_links)} books")

    r = c._get("/sequence/242")
    check("GET /sequence/242 (alias)", r is not None and r.status_code == 200)

    r = c._get("/sequence/242/all")
    check("GET /sequence/242/all", r is not None and r.status_code == 200)

    # ─────────────────────────────────────────────────────────────
    # 5. GENRES
    # ─────────────────────────────────────────────────────────────
    section("5. GENRES")

    r = c._get("/g")
    check("GET /g (list)", r is not None and r.status_code == 200)
    if r:
        soup = BeautifulSoup(r.text, "html.parser")
        genre_links = soup.find_all("a", href=lambda h: h and h.startswith("/g/"))
        check("Has genre links", len(genre_links) > 10, f"{len(genre_links)} genres")

    r = c._get("/g/det_classic")
    check("GET /g/det_classic", r is not None and r.status_code == 200)
    if r:
        soup = BeautifulSoup(r.text, "html.parser")
        book_links = soup.find_all("a", href=lambda h: h and h.startswith("/b/"))
        check("Genre has books", len(book_links) > 100, f"{len(book_links)} books")

        forms = soup.find_all("form")
        genre_forms = [f for f in forms if f.get("action", "").startswith("/g/")]
        check("Has sort form", len(genre_forms) > 0)

    r = c._get("/g/39")
    check("GET /g/39 (numeric genre)", r is not None and r.status_code == 200)

    # ─────────────────────────────────────────────────────────────
    # 6. SEARCH
    # ─────────────────────────────────────────────────────────────
    section("6. SEARCH")

    queries = {
        "books": "booksearch?ask=Шерлок&chb=on",
        "authors": "booksearch?ask=Конан&cha=on",
        "series": "booksearch?ask=Шерлок&chs=on",
        "genres": "booksearch?ask=роман&chg=on",
    }
    for label, path in queries.items():
        r = c._get(path)
        check(f"Search {label}", r is not None and r.status_code == 200)
        if r:
            soup = BeautifulSoup(r.text, "html.parser")
            h3 = soup.find("h3")
            total = 0
            if h3:
                m = re.search(r"из\s+(\d+)", h3.get_text())
                if m:
                    total = int(m.group(1))
            check(f"  Has results count", total > 0, f"total={total}")

    # Paginated search
    r = c._get("booksearch?ask=Толстой&page=1&chb=on")
    check("Paginated search (page=1)", r is not None and r.status_code == 200)

    # Compare
    r = c._get("/comp")
    check("GET /comp (compare)", r is not None and r.status_code == 200)
    if r:
        soup = BeautifulSoup(r.text, "html.parser")
        forms = [f for f in soup.find_all("form") if "b1" in str(f)]
        check("Has compare form", len(forms) > 0)

    # ─────────────────────────────────────────────────────────────
    # 7. OPDS
    # ─────────────────────────────────────────────────────────────
    section("7. OPDS")

    import xml.etree.ElementTree as ET
    ATOM_NS = "http://www.w3.org/2005/Atom"

    opds_endpoints = [
        "/opds/",
        "/opds/popular",
        "/opds/recent",
        "/opds/genres",
        "/opds/authors",
    ]
    for path in opds_endpoints:
        r = c._get(path)
        ok = r is not None and r.status_code == 200
        check(f"GET {path}", ok)
        if ok:
            try:
                root = ET.fromstring(r.text)
                entries = root.findall(f".//{{{ATOM_NS}}}entry")
                check(f"  Has entries", len(entries) > 0, f"{len(entries)} entries")
            except:
                check(f"  XML parse", False)

    # OPDS search
    r = c._get("/opds/opensearch?searchTerm=Толстой&searchType=books&pageNumber=0")
    check("OPDS search books", r is not None and r.status_code == 200)
    if r:
        try:
            root = ET.fromstring(r.text)
            entries = root.findall(f".//{{{ATOM_NS}}}entry")
            check("  Has results", len(entries) > 0, f"{len(entries)} books")
            if entries:
                entry = entries[0]
                title = entry.findtext(f"{{{ATOM_NS}}}title", "")
                authors = entry.findall(f"{{{ATOM_NS}}}author")
                links = entry.findall(f"{{{ATOM_NS}}}link")
                check("  Entry has title", bool(title))
                check("  Entry has authors", len(authors) > 0)
                check("  Entry has links", len(links) > 0)
                save("07_opds_search.json", {
                    "title": title,
                    "authors": [a.findtext(f"{{{ATOM_NS}}}name", "") for a in authors],
                    "links": len(links),
                })
        except:
            check("  OPDS XML parse", False)

    # OPDS author books
    r = c._get("/opds/author/6116/alphabet/0")
    check("OPDS author books", r is not None and r.status_code == 200)

    # ─────────────────────────────────────────────────────────────
    # 8. RECENT / TRACKER
    # ─────────────────────────────────────────────────────────────
    section("8. RECENT / TRACKER")

    r = c._get("/new")
    check("GET /new (recent)", r is not None and r.status_code == 200)
    if r:
        soup = BeautifulSoup(r.text, "html.parser")
        # Find filter form
        forms = soup.find_all("form")
        new_forms = [f for f in forms if f.get("action", "").startswith("/new")]
        check("Has filter form", len(new_forms) > 0)
        if new_forms:
            selects = new_forms[0].find_all("select")
            select_names = [s.get("name") for s in selects]
            check("Has lang/type/sr filters", all(n in select_names for n in ["lang", "type", "sr"]))

        # Find mass download form
        mass_forms = [f for f in forms if "mass" in f.get("action", "")]
        check("Has mass download form", len(mass_forms) > 0)

    r = c._get("/tracker")
    check("GET /tracker", r is not None and r.status_code == 200)

    # ─────────────────────────────────────────────────────────────
    # 9. STATISTICS
    # ─────────────────────────────────────────────────────────────
    section("9. STATISTICS")

    r = c._get("/stat")
    check("GET /stat", r is not None and r.status_code == 200)

    r = c._get("/stat/b")
    check("GET /stat/b (popular)", r is not None and r.status_code == 200)
    if r:
        soup = BeautifulSoup(r.text, "html.parser")
        book_links = soup.find_all("a", href=lambda h: h and h.startswith("/b/"))
        check("Has popular books", len(book_links) > 5, f"{len(book_links)} books")

    if logged_in:
        r = c._get("/stat/my")
        check("GET /stat/my (my stats)", r is not None and r.status_code == 200)

    # ─────────────────────────────────────────────────────────────
    # 10. USER (authenticated)
    # ─────────────────────────────────────────────────────────────
    section("10. USER")

    if logged_in:
        r = c._get("/user/me")
        check("GET /user/me", r is not None and r.status_code == 200)
        if r:
            soup = BeautifulSoup(r.text, "html.parser")
            tabs = soup.select(".tabs a, ul.tabs a")
            check("Has profile tabs", len(tabs) >= 3, f"{len(tabs)} tabs")
            save("10_user_me.html", r.text[:10000])

        r = c._get("/user/me/edit")
        check("GET /user/me/edit", r is not None and r.status_code == 200)
        if r:
            soup = BeautifulSoup(r.text, "html.parser")
            edit_form = [f for f in soup.find_all("form") if "edit" in f.get("action", "")]
            check("Has edit form", len(edit_form) > 0)

        r = c._get("/user/me/watcher")
        check("GET /user/me/watcher", r is not None and r.status_code == 200)

        r = c._get("/user/me/track")
        check("GET /user/me/track", r is not None and r.status_code == 200)
    else:
        print("  (skipped — no auth)")

    # ─────────────────────────────────────────────────────────────
    # 11. MESSAGES
    # ─────────────────────────────────────────────────────────────
    section("11. MESSAGES")

    if logged_in:
        r = c._get("/messages")
        check("GET /messages (inbox)", r is not None and r.status_code == 200)
        if r:
            soup = BeautifulSoup(r.text, "html.parser")
            msg_form = [f for f in soup.find_all("form") if "privatemsg" in str(f)]
            check("Has message list form", len(msg_form) > 0)

        r = c._get("/messages/new")
        check("GET /messages/new", r is not None and r.status_code == 200)
        if r:
            soup = BeautifulSoup(r.text, "html.parser")
            msg_form = [f for f in soup.find_all("form") if "messages" in f.get("action", "")]
            check("Has compose form", len(msg_form) > 0)
            if msg_form:
                inputs = [i.get("name") for i in msg_form[0].find_all("input") if i.get("name")]
                check("Has recipient/subject", "recipient" in inputs and "subject" in inputs)
    else:
        print("  (skipped — no auth)")

    # ─────────────────────────────────────────────────────────────
    # 12. POLKA / BOOKSHELF
    # ─────────────────────────────────────────────────────────────
    section("12. POLKA / BOOKSHELF")

    r = c._get("/polka")
    check("GET /polka", r is not None and r.status_code == 200)

    r = c._get("/polka/show/1452402")
    check("GET /polka/show/{id}", r is not None and r.status_code == 200)

    r = c._get("/polka/show/all")
    check("GET /polka/show/all", r is not None and r.status_code == 200)

    if logged_in:
        # Check polka/add form on book page
        r = c._get("/b/226302")
        if r:
            soup = BeautifulSoup(r.text, "html.parser")
            polka_form = [f for f in soup.find_all("form") if "polka/add" in f.get("action", "")]
            check("Book page has polka form", len(polka_form) > 0)

        # Check polka/watch
        r = c._get("/polka/watch/add/226302")
        check("GET /polka/watch/add/{id}", r is not None and r.status_code == 200)
    else:
        print("  (skipped — no auth)")

    # ─────────────────────────────────────────────────────────────
    # 13. BLACK/WHITE LIST
    # ─────────────────────────────────────────────────────────────
    section("13. BLACK/WHITE LIST")

    r = c._get("/bwlist")
    check("GET /bwlist", r is not None and r.status_code == 200)

    r = c._get("/bwlist/show/1452402")
    check("GET /bwlist/show/{id}", r is not None and r.status_code == 200)

    # ─────────────────────────────────────────────────────────────
    # 14. RECOMMENDATIONS
    # ─────────────────────────────────────────────────────────────
    section("14. RECOMMENDATIONS")

    r = c._get("/rec")
    check("GET /rec", r is not None and r.status_code == 200)
    if r:
        soup = BeautifulSoup(r.text, "html.parser")
        rec_forms = soup.find_all("form")
        check("Has filter form", len(rec_forms) > 0)

    r = c._get("/rec?view=recs&user=1452402&udata=id")
    check("GET /rec?view=recs&user={id}", r is not None and r.status_code == 200)

    # ─────────────────────────────────────────────────────────────
    # 15. FORUM / BLOG
    # ─────────────────────────────────────────────────────────────
    section("15. FORUM / BLOG")

    r = c._get("/forum")
    check("GET /forum", r is not None and r.status_code == 200)

    r = c._get("/forum/5")
    check("GET /forum/5", r is not None and r.status_code == 200)

    r = c._get("/blog")
    check("GET /blog", r is not None and r.status_code == 200)

    r = c._get("/blog/4")
    check("GET /blog/{id}", r is not None and r.status_code == 200)

    if logged_in:
        r = c._get("/blog/me")
        check("GET /blog/me", r is not None and r.status_code == 200)

    # ─────────────────────────────────────────────────────────────
    # 16. STATIC PAGES
    # ─────────────────────────────────────────────────────────────
    section("16. STATIC PAGES")

    for path, label in [
        ("/node/68682", "Help"),
        ("/node/4023", "FAQ"),
        ("/node/55088", "Book FAQ"),
        ("/node/68684", "Authors on Flibusta"),
        ("/dostup", "Access FAQ"),
        ("/node/add", "Create content"),
    ]:
        r = c._get(path)
        check(f"GET {path} ({label})", r is not None and r.status_code == 200)

    # ─────────────────────────────────────────────────────────────
    # SUMMARY
    # ─────────────────────────────────────────────────────────────
    section("SUMMARY")
    total = passed + failed + skipped
    print(f"  Passed: {passed}/{total}")
    print(f"  Failed: {failed}/{total}")
    print(f"  Skipped: {skipped}/{total}")
    print(f"  Results: {RESULTS_DIR}")

    save("summary.json", {
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "total": total,
    })


if __name__ == "__main__":
    main()
