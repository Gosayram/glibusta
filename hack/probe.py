#!/usr/bin/env python3
"""Aggressive Flibusta endpoint discovery — crawls, probes, extracts everything."""

import sys, os, re, json, time, hashlib
from pathlib import Path
from urllib.parse import urljoin, urlparse, parse_qs
from collections import defaultdict

sys.path.insert(0, str(Path(__file__).parent))
from bs4 import BeautifulSoup, Comment
from flibusta_client import FlibustaClient

RESULTS = Path(__file__).parent.parent / "test_results" / "hack-probe"
RESULTS.mkdir(parents=True, exist_ok=True)

c = FlibustaClient()
user = os.environ.get("FLIBUSTA_USER", "")
pw = os.environ.get("FLIBUSTA_PASSWORD", "")
logged_in = c.login(user, pw) if user and pw else False

visited = set()
all_endpoints = defaultdict(lambda: {"methods": set(), "status": [], "forms": [], "links": 0, "new_patterns": []})
all_patterns = set()
discovered = []


def save(name, data):
    (RESULTS / name).write_text(
        json.dumps(data, ensure_ascii=False, indent=2, default=str), encoding="utf-8"
    )


def parse_page(path, html):
    """Extract EVERYTHING from a page."""
    soup = BeautifulSoup(html, "html.parser")
    result = {
        "path": path,
        "title": soup.title.get_text(strip=True)[:80] if soup.title else "",
        "links": [],
        "forms": [],
        "scripts": [],
        "metas": [],
        "comments": [],
        "data_attrs": [],
        "json_blocks": [],
        "ajax_urls": [],
        "cookies_hints": [],
        "pagination": {},
        "tables": [],
        "selects": {},
    }

    # ── All links ──────────────────────────────────────────────
    for a in soup.find_all("a", href=True):
        href = a["href"]
        if href.startswith(("http://", "https://")):
            continue
        if href.startswith("#") or href.startswith("mailto:") or href.startswith("javascript:"):
            continue
        clean = href.split("?")[0].split("#")[0]
        text = a.get_text(strip=True)[:50]
        result["links"].append({"href": clean, "text": text})

    # ── All forms with EVERY input ─────────────────────────────
    for form in soup.find_all("form"):
        action = form.get("action", "")
        method = form.get("method", "GET").upper()
        fields = []
        for inp in form.find_all(["input", "select", "textarea"]):
            name = inp.get("name", "")
            if not name:
                continue
            field = {"name": name, "tag": inp.name, "type": inp.get("type", "text")}
            if inp.name == "select":
                opts = [o.get("value", "") for o in inp.find_all("option")]
                field["options"] = opts[:10]
            if inp.name == "textarea":
                field["rows"] = inp.get("rows", "")
            if inp.get("value"):
                field["value"] = inp["value"][:60]
            fields.append(field)
        result["forms"].append({
            "action": action[:80], "method": method, "fields": fields
        })

    # ── Scripts (JS/AJAX endpoints) ────────────────────────────
    for script in soup.find_all("script"):
        text = script.string or ""
        # Find AJAX URLs
        urls = re.findall(r'(?:url|href|src|action)\s*[:=]\s*["\']([^"\']+)["\']', text)
        for u in urls:
            if u.startswith("/") and not u.startswith("/sites/"):
                result["ajax_urls"].append(u)
        # Find JSON.parse blocks
        if "JSON" in text or "json" in text:
            result["json_blocks"].append(text[:200])

    # ── Meta tags ──────────────────────────────────────────────
    for meta in soup.find_all("meta"):
        result["metas"].append({
            "name": meta.get("name", ""),
            "content": meta.get("content", "")[:80],
        })

    # ── HTML comments (may contain hidden endpoints) ───────────
    for comment in soup.find_all(string=lambda s: isinstance(s, Comment)):
        text = str(comment).strip()
        if "/" in text and len(text) < 200:
            result["comments"].append(text[:100])

    # ── data-* attributes ──────────────────────────────────────
    for elem in soup.find_all(True):
        for attr, val in elem.attrs.items():
            if attr.startswith("data-") and val:
                result["data_attrs"].append({
                    "tag": elem.name, "attr": attr, "value": str(val)[:80]
                })

    # ── Pagination ─────────────────────────────────────────────
    pager = soup.select_one("div.item-list .pager, .pager")
    if pager:
        pages = []
        for li in pager.find_all("li"):
            text = li.get_text(strip=True)
            link = li.find("a")
            href = link["href"] if link else ""
            pages.append({"text": text, "href": href[:80]})
        result["pagination"] = {"pages": pages, "has_next": pager.find(class_="pager-next") is not None}

    # ── Selects with ALL options ───────────────────────────────
    for select in soup.find_all("select", {"name": True}):
        name = select.get("name")
        opts = [(o.get("value", ""), o.get_text(strip=True)[:30]) for o in select.find_all("option")]
        result["selects"][name] = opts

    # ── Tables ─────────────────────────────────────────────────
    for table in soup.find_all("table"):
        rows = table.find_all("tr")
        if rows:
            headers = [th.get_text(strip=True)[:20] for th in rows[0].find_all(["th", "td"])]
            result["tables"].append({"rows": len(rows), "headers": headers[:10]})

    return result


def probe_endpoint(path, label="", depth=0):
    """Probe a single endpoint and extract everything."""
    if path in visited or depth > 2:
        return
    visited.add(path)

    r = c._get(path)
    if not r:
        return

    status = r.status_code
    ct = r.headers.get("content-type", "")

    info = {
        "path": path,
        "label": label,
        "status": status,
        "content_type": ct,
        "content_length": len(r.text),
        "redirect_url": getattr(r, "url", ""),
    }

    # Check if response is JSON
    if "json" in ct:
        try:
            data = r.json()
            info["json"] = True
            info["json_keys"] = list(data.keys()) if isinstance(data, dict) else f"array[{len(data)}]"
        except:
            pass

    # Parse HTML
    if "html" in ct or "text" in ct:
        parsed = parse_page(path, r.text)
        info["parsed"] = {
            "links_count": len(parsed["links"]),
            "forms_count": len(parsed["forms"]),
            "ajax_urls": parsed["ajax_urls"],
            "json_blocks": len(parsed["json_blocks"]),
            "selects": {k: v[:5] for k, v in parsed["selects"].items()},
            "pagination": parsed["pagination"],
        }

        # Collect new unique links
        new_links = []
        for link in parsed["links"]:
            href = link["href"]
            if href not in all_endpoints and href not in visited:
                new_links.append(link)
        info["new_links"] = new_links

        # Collect forms
        info["forms"] = parsed["forms"]

        # Collect AJAX/JS endpoints
        if parsed["ajax_urls"]:
            info["ajax"] = parsed["ajax_urls"]

    all_endpoints[path]["methods"].add("GET")
    all_endpoints[path]["status"].append(status)

    return info


# ═══════════════════════════════════════════════════════════════
# PHASE 1: Known endpoint deep probe
# ═══════════════════════════════════════════════════════════════
print("=" * 60)
print("  PHASE 1: Deep probe of known endpoints")
print("=" * 60)

known_endpoints = [
    "/", "/b", "/b/226302", "/b/226302/read", "/b/226302/mail",
    "/a", "/a/6116", "/a/6116/series",
    "/s", "/s/242", "/sequence/242",
    "/g", "/g/det_classic", "/g/39",
    "/booksearch?ask=Толстой&chb=on",
    "/booksearch?ask=Толстой&cha=on",
    "/opds/", "/opds/popular", "/opds/recent", "/opds/genres", "/opds/authors",
    "/opds/opensearch?searchTerm=Толстой&searchType=books&pageNumber=0",
    "/new", "/tracker", "/stat", "/stat/b",
    "/rec", "/comp",
    "/forum", "/blog",
    "/user/me", "/user/me/edit", "/user/me/watcher", "/user/me/track",
    "/messages", "/messages/new",
    "/polka", "/polka/show/1452402", "/polka/show/all",
    "/bwlist", "/bwlist/show/1452402",
    "/Aa", "/Bb", "/Sh", "/Other",
]

phase1_results = []
for ep in known_endpoints:
    info = probe_endpoint(ep)
    if info:
        new_count = len(info.get("new_links", []))
        forms = info.get("forms_count", 0)
        print(f"  {info['status']:3d} {ep:50s} links={info.get('parsed',{}).get('links_count',0):4d} forms={forms} new={new_count}")
        phase1_results.append(info)
        time.sleep(0.3)

save("phase1_known.json", phase1_results)
print(f"\nPhase 1: {len(phase1_results)} endpoints probed, {len(visited)} unique URLs")


# ═══════════════════════════════════════════════════════════════
# PHASE 2: Discover NEW endpoints from links found in Phase 1
# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("  PHASE 2: Crawl discovered links")
print("=" * 60)

# Collect all unique new links from phase 1
new_endpoints = set()
for info in phase1_results:
    for link in info.get("new_links", []):
        href = link["href"]
        if href not in visited and not href.startswith("/sites/"):
            new_endpoints.add(href)

print(f"  Found {len(new_endpoints)} new unique endpoints to probe")

phase2_results = []
for ep in sorted(new_endpoints):
    info = probe_endpoint(ep)
    if info:
        new_count = len(info.get("new_links", []))
        print(f"  {info['status']:3d} {ep:50s} new={new_count}")
        phase2_results.append(info)
        time.sleep(0.3)

save("phase2_discovered.json", phase2_results)
print(f"\nPhase 2: {len(phase2_results)} new endpoints probed, total visited: {len(visited)}")


# ═══════════════════════════════════════════════════════════════
# PHASE 3: Brute-force common patterns
# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("  PHASE 3: Pattern-based discovery")
print("=" * 60)

patterns = [
    # Common REST/Drupal patterns
    "/api", "/api/v1", "/api/books", "/api/authors", "/api/search",
    "/rest", "/rest/books",
    "/json", "/json/books", "/json/authors",
    "/xml", "/xml/books",
    "/feed", "/feeds", "/rss", "/atom",
    "/sitemap.xml", "/robots.txt",
    # Drupal-specific
    "/admin", "/admin/content", "/admin/config",
    "/node", "/node/add", "/node/add/book", "/node/add/author",
    "/taxonomy", "/taxonomy/term",
    "/user/list", "/user/admin",
    # Common paths
    "/login", "/register", "/signup",
    "/search", "/advanced",
    "/about", "/help", "/faq", "/rules",
    "/donate", "/support",
    "/api/opds", "/api/search",
    # Book-specific
    "/b/new", "/b/recent", "/b/popular",
    "/a/new", "/a/recent",
    "/download", "/downloads",
    "/upload", "/import", "/export",
    # Letter pages
    f"/Other",
    # Comment patterns
    "/comment/reply",
]

phase3_results = []
for ep in patterns:
    if ep in visited:
        continue
    info = probe_endpoint(ep)
    if info and info["status"] != 404:
        print(f"  {info['status']:3d} {ep:50s}")
        phase3_results.append(info)
    time.sleep(0.2)

save("phase3_patterns.json", phase3_results)
print(f"\nPhase 3: {len(phase3_results)} pattern matches")


# ═══════════════════════════════════════════════════════════════
# PHASE 4: POST endpoints — try submitting known forms
# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("  PHASE 4: POST endpoint probing")
print("=" * 60)

post_endpoints = [
    ("/user/login", {"name": "test", "pass": "test", "form_id": "user_login", "op": "Вход"}),
    ("/polka/add/226302", {"flag": "on"}),
    ("/messages/new", {"recipient": "test", "subject": "test", "body": "test"}),
    ("/b/226302/mail", {"format": "fb2", "bookmailFormParams": "Отправить"}),
    ("/user/me/edit", {"mail": "test@test.com"}),
    ("/user/me/openid", {"openid_identifier": ""}),
    ("/dostup", {}),
    ("/comp", {"b1": "226302", "b2": "12345"}),
]

phase4_results = []
for path, data in post_endpoints:
    url = c.base_url + path
    try:
        r = c.session.post(url, data=data, timeout=15, verify=False, allow_redirects=False)
        ct = r.headers.get("content-type", "")
        loc = r.headers.get("location", "")
        print(f"  {r.status_code:3d} POST {path:40s} redirect={loc[:40] if loc else 'none'} ct={ct[:30]}")
        phase4_results.append({
            "path": path, "status": r.status_code,
            "redirect": loc[:80], "content_type": ct[:40],
            "content_length": len(r.text),
        })
    except Exception as e:
        print(f"  ERR  POST {path}: {e}")
    time.sleep(0.3)

save("phase4_post.json", phase4_results)


# ═══════════════════════════════════════════════════════════════
# PHASE 5: OPDS deep crawl
# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("  PHASE 5: OPDS deep crawl")
print("=" * 60)

import xml.etree.ElementTree as ET
ATOM_NS = "http://www.w3.org/2005/Atom"

opds_paths = [
    "/opds/",
    "/opds/popular",
    "/opds/recent",
    "/opds/genres",
    "/opds/authors",
    "/opds/opensearch?searchTerm=Толстой&searchType=books&pageNumber=0",
    "/opds/opensearch?searchType=authors&searchTerm=Толстой&pageNumber=0",
]

phase5_results = []
for path in opds_paths:
    r = c._get(path)
    if not r:
        continue
    try:
        root = ET.fromstring(r.text)
        entries = root.findall(f".//{{{ATOM_NS}}}entry")
        links = root.findall(f".//{{{ATOM_NS}}}link")

        # Extract all link hrefs
        link_hrefs = [l.get("href", "") for l in links]

        # Extract entry details
        entry_data = []
        for e in entries[:3]:
            entry = {
                "title": e.findtext(f"{{{ATOM_NS}}}title", ""),
                "id": e.findtext(f"{{{ATOM_NS}}}id", ""),
                "links": [{"href": l.get("href", ""), "type": l.get("type", "")} for l in e.findall(f"{{{ATOM_NS}}}link")],
            }
            authors = e.findall(f"{{{ATOM_NS}}}author")
            entry["authors"] = [a.findtext(f"{{{ATOM_NS}}}name", "") for a in authors]
            entry_data.append(entry)

        info = {
            "path": path,
            "entries": len(entries),
            "feed_links": link_hrefs,
            "sample_entries": entry_data,
        }
        phase5_results.append(info)
        print(f"  {path}: {len(entries)} entries, {len(link_hrefs)} feed links")
    except Exception as e:
        print(f"  {path}: XML error: {e}")

    # Follow OPDS sub-feeds (genres, authors)
    if "genres" in path or "authors" in path:
        for entry in entry_data[:5]:
            for link in entry.get("links", []):
                href = link.get("href", "")
                if href.startswith("/") and href not in visited:
                    r2 = c._get(href)
                    if r2 and r2.status_code == 200:
                        try:
                            root2 = ET.fromstring(r2.text)
                            entries2 = root2.findall(f".//{{{ATOM_NS}}}entry")
                            print(f"    -> {href}: {len(entries2)} entries")
                            visited.add(href)
                        except:
                            pass

save("phase5_opds.json", phase5_results)


# ═══════════════════════════════════════════════════════════════
# PHASE 6: Cookie/token analysis
# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("  PHASE 6: Session/cookie analysis")
print("=" * 60)

cookies = dict(c.session.cookies)
print(f"  Session cookies: {list(cookies.keys())}")

# Analyze cookie patterns
for name, value in cookies.items():
    print(f"    {name}: {value[:30]}... (len={len(value)})")

save("phase6_session.json", {
    "cookies": {k: {"length": len(v), "prefix": v[:10]} for k, v in cookies.items()},
    "headers": dict(c.session.headers),
})


# ═══════════════════════════════════════════════════════════════
# PHASE 7: Aggregate all findings
# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("  PHASE 7: Final report")
print("=" * 60)

# Deduplicate and categorize all endpoints
categories = defaultdict(list)
for path in sorted(all_endpoints.keys()):
    parts = path.strip("/").split("/")
    if not parts or not parts[0]:
        categories["root"].append(path)
    else:
        categories[parts[0]].append(path)

all_unique = sorted(visited)
print(f"\n  Total unique URLs visited: {len(all_unique)}")
print(f"  Categories: {len(categories)}")
for cat, paths in sorted(categories.items()):
    print(f"    {cat}: {len(paths)} endpoints")

# Find potentially interesting unexplored patterns
interesting = []
for path in all_unique:
    if "/b/" in path and "/read" not in path and "/download" not in path and "/mail" not in path:
        interesting.append(path)

# Save final report
report = {
    "total_visited": len(all_unique),
    "categories": {k: v for k, v in categories.items()},
    "all_endpoints": all_unique,
    "phase1_count": len(phase1_results),
    "phase2_count": len(phase2_results),
    "phase3_count": len(phase3_results),
    "phase4_count": len(phase4_results),
    "phase5_count": len(phase5_results),
    "session": {k: len(v) for k, v in cookies.items()},
}
save("report.json", report)

# Print discovered endpoints grouped
print("\n  ALL DISCOVERED ENDPOINTS:")
for cat in sorted(categories.keys()):
    print(f"\n  [{cat}]")
    for path in sorted(categories[cat])[:20]:
        methods = all_endpoints[path]["methods"]
        print(f"    {' '.join(m.upper() for m in methods):8s} {path}")

print(f"\n{'='*60}")
print(f"  Done! Results in: {RESULTS}")
print(f"{'='*60}")
