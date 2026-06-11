#!/usr/bin/env python3
"""Fast aggressive Flibusta probe — focused on finding new endpoints."""

import sys, os, re, json, time
from pathlib import Path
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed

sys.path.insert(0, str(Path(__file__).parent))
from bs4 import BeautifulSoup
from flibusta_client import FlibustaClient

RESULTS = Path(__file__).parent.parent / "test_results" / "hack-probe"
RESULTS.mkdir(parents=True, exist_ok=True)

c = FlibustaClient()
user = os.environ.get("FLIBUSTA_USER", "")
pw = os.environ.get("FLIBUSTA_PASSWORD", "")
logged_in = c.login(user, pw) if user and pw else False

visited = set()
new_endpoints_found = []


def save(name, data):
    (RESULTS / name).write_text(json.dumps(data, ensure_ascii=False, indent=2, default=str), encoding="utf-8")


def quick_probe(path):
    """Fast probe: get status, extract links, forms, selects, scripts."""
    if path in visited:
        return None
    visited.add(path)
    
    r = c._get(path)
    if not r:
        return None
    
    ct = r.headers.get("content-type", "")
    info = {"path": path, "status": r.status_code, "ct": ct[:30], "size": len(r.text)}
    
    if "html" not in ct and "text" in ct and "xml" not in ct:
        return info
    
    soup = BeautifulSoup(r.text, "html.parser")
    
    # Links
    links = set()
    for a in soup.find_all("a", href=True):
        h = a["href"].split("?")[0].split("#")[0]
        if h.startswith("/") and not h.startswith("/sites/") and h not in visited:
            links.add(h)
    info["links"] = list(links)[:50]
    
    # Forms
    forms = []
    for form in soup.find_all("form"):
        action = form.get("action", "")
        method = form.get("method", "GET").upper()
        fields = [i.get("name") for i in form.find_all(["input", "select", "textarea"]) if i.get("name")]
        selects = {}
        for s in form.find_all("select", {"name": True}):
            selects[s["name"]] = [o.get("value", "") for o in s.find_all("option")[:8]]
        forms.append({"action": action[:80], "method": method, "fields": fields[:15], "selects": selects})
    info["forms"] = forms
    
    # Scripts with JS
    js_urls = set()
    for script in soup.find_all("script"):
        text = script.string or ""
        urls = re.findall(r'["\'](/[a-z][a-z0-9/_-]+(?:\?[^"\']*)?)["\']', text)
        for u in urls:
            if not u.startswith("/sites/") and not u.startswith("/misc/"):
                js_urls.add(u.split("?")[0])
    if js_urls:
        info["js_urls"] = list(js_urls)[:20]
    
    # Selects (filters)
    all_selects = {}
    for s in soup.find_all("select", {"name": True}):
        opts = [(o.get("value",""), o.get_text(strip=True)[:25]) for o in s.find_all("option")[:10]]
        all_selects[s["name"]] = opts
    if all_selects:
        info["selects"] = all_selects
    
    # Pagination
    pager = soup.select_one(".pager, div.item-list .pager")
    if pager:
        page_nums = [li.get_text(strip=True) for li in pager.find_all("li")]
        has_next = pager.find(class_="pager-next") is not None
        info["pagination"] = {"pages": page_nums[:10], "has_next": has_next}
    
    # Tables
    tables = []
    for table in soup.find_all("table"):
        rows = table.find_all("tr")
        if rows:
            hdrs = [c.get_text(strip=True)[:15] for c in rows[0].find_all(["th","td"])]
            tables.append({"rows": len(rows), "cols": hdrs[:8]})
    if tables:
        info["tables"] = tables
    
    return info


# ═══════════════════════════════════════════════════════════════
# SEED: All known + pattern-based endpoints
# ═══════════════════════════════════════════════════════════════
SEEDS = [
    # Core
    "/",
    # Books
    "/b", "/b/226302", "/b/226302/read", "/b/226302/mail", "/b/226302/download",
    "/b/12345", "/b/1",
    # Authors
    "/a", "/a/all", "/a/6116", "/a/6116/series", "/a/226377", "/a/7171",
    # Letters
    "/Aa", "/Bb", "/V", "/Gg", "/D", "/E", "/Zh", "/Z", "/I", "/Y", "/K",
    "/L", "/M", "/N", "/O", "/P", "/R", "/Ss", "/S", "/T", "/U", "/F",
    "/H", "/Tz", "/Ch", "/Sh", "/Sz", "/Ee", "/Yu", "/Ya", "/Other",
    # Series
    "/s", "/s/242", "/s/28511", "/sequence/242", "/sequence/242/all",
    # Genres
    "/g", "/g/det_classic", "/g/39", "/g/love", "/g/sf",
    # Search
    "/booksearch?ask=Толстой&chb=on",
    "/booksearch?ask=Конан&cha=on",
    "/booksearch?ask=Шерлок&chs=on",
    "/booksearch?ask=роман&chg=on",
    "/booksearch?ask=Толстой&page=1&chb=on",
    "/booksearch?ask=Толстой&page=2&chb=on",
    "/comp",
    # OPDS
    "/opds/", "/opds/popular", "/opds/recent", "/opds/genres", "/opds/authors",
    "/opds/opensearch?searchTerm=Толстой&searchType=books&pageNumber=0",
    "/opds/opensearch?searchTerm=Толстой&searchType=books&pageNumber=1",
    "/opds/opensearch?searchType=authors&searchTerm=Толстой&pageNumber=0",
    "/opds/author/6116/alphabet/0",
    "/opds/genre/det_classic/0",
    # Recent/Stats
    "/new", "/new?sr=2", "/new?lang=ru", "/new?type=fb2",
    "/tracker", "/stat", "/stat/b",
    # User (auth)
    "/user/me", "/user/me/edit", "/user/me/watcher", "/user/me/track", "/user/me/openid",
    "/user/1452402",
    # Messages
    "/messages", "/messages/new", "/messages/new/1452402",
    # Polka
    "/polka", "/polka/show/1452402", "/polka/show/all", "/polka/show/1227048",
    # BW list
    "/bwlist", "/bwlist/show/1452402",
    # Rec
    "/rec", "/rec?view=recs&user=1452402",
    # Forum/Blog
    "/forum", "/forum/5", "/forum/6",
    "/blog", "/blog/4", "/blog/me",
    # Static
    "/node/68682", "/node/4023", "/node/55088", "/node/68684", "/node/add",
    "/dostup", "/upload",
    # Catalog
    "/catalog/catalog.zip", "/sql/", "/daily/",
    # Brute patterns
    "/api", "/json", "/xml", "/feed", "/rss",
    "/robots.txt", "/sitemap.xml",
    "/login", "/register", "/search",
    "/comment/reply", "/node/add/book", "/node/add/author",
    "/admin", "/export", "/import",
    "/book", "/book/advanced",
    # User-specific
    "/user", "/user/register", "/user/password",
    "/logout", "/blog/124185", "/blog/2215", "/blog/37400",
    # More patterns
    "/b/226302/complain", "/polka/watch/add/226302",
    "/Aa?page=1", "/g/det_classic?page=1",
    "/s?type1=1", "/s?type2=1",
    "/stat/b?page=1",
]

print(f"Probing {len(SEEDS)} seed endpoints...")
results = []
for i, ep in enumerate(SEEDS):
    info = quick_probe(ep)
    if info:
        results.append(info)
        new = len(info.get("links", []))
        forms = len(info.get("forms", []))
        marker = " NEW" if info["status"] == 200 and new > 0 else ""
        print(f"  [{i+1:3d}/{len(SEEDS)}] {info['status']:3d} {ep:55s} L={new:3d} F={forms}{marker}")
    time.sleep(0.15)

# ═══════════════════════════════════════════════════════════════
# PHASE 2: Crawl ALL new links from Phase 1
# ═══════════════════════════════════════════════════════════════
all_new = set()
for r in results:
    for link in r.get("links", []):
        if link not in visited:
            all_new.add(link)

print(f"\n\nCrawling {len(all_new)} newly discovered links...")
phase2 = []
for ep in sorted(all_new):
    info = quick_probe(ep)
    if info:
        phase2.append(info)
        if info["status"] == 200:
            print(f"  {info['status']:3d} {ep:55s} L={len(info.get('links',[])):3d}")
        time.sleep(0.15)

# ═══════════════════════════════════════════════════════════════
# PHASE 3: Crawl links from Phase 2 (depth 3)
# ═══════════════════════════════════════════════════════════════
all_new2 = set()
for r in phase2:
    for link in r.get("links", []):
        if link not in visited:
            all_new2.add(link)

# Filter: only crawl interesting patterns
interesting = {l for l in all_new2 if any(l.startswith(f"/{p}") for p in [
    "a", "b", "s", "g", "sequence", "opds", "user", "polka", "rec",
    "forum", "blog", "stat", "new", "messages", "bwlist", "tracker",
    "node", "comment", "booksearch", "comp", "upload", "node/add",
])}

print(f"\nCrawling {len(interesting)} interesting links (depth 3)...")
phase3 = []
for ep in sorted(interesting):
    info = quick_probe(ep)
    if info and info["status"] == 200:
        phase3.append(info)
        print(f"  {info['status']:3d} {ep:55s}")
    time.sleep(0.15)


# ═══════════════════════════════════════════════════════════════
# FINAL REPORT
# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("  FINAL REPORT")
print("=" * 60)

all_endpoints = sorted(visited)
print(f"\n  Total unique URLs: {len(all_endpoints)}")

# Categorize
cats = defaultdict(list)
for ep in all_endpoints:
    parts = ep.strip("/").split("/")
    root = parts[0] if parts and parts[0] else "root"
    cats[root].append(ep)

for cat in sorted(cats.keys()):
    print(f"\n  [{cat}] ({len(cats[cat])} endpoints)")
    for ep in sorted(cats[cat])[:15]:
        print(f"    {ep}")

# Save everything
save("all_probed.json", {
    "total": len(all_endpoints),
    "endpoints": all_endpoints,
    "categories": dict(cats),
    "phase1": len(results),
    "phase2": len(phase2),
    "phase3": len(phase3),
})

# Save details for each phase
save("phase1.json", [{"path": r["path"], "status": r["status"], "forms": r.get("forms", []), "selects": r.get("selects", {}), "pagination": r.get("pagination", {})} for r in results if r["status"] == 200])
save("phase2.json", [{"path": r["path"], "status": r["status"], "forms": r.get("forms", [])} for r in phase2 if r["status"] == 200])
save("phase3.json", [{"path": r["path"], "status": r["status"]} for r in phase3])

# Highlight NEW findings (endpoints not in our original docs)
original_endpoints = {
    "/", "/b", "/b/226302", "/b/226302/read", "/b/226302/mail", "/b/226302/download",
    "/a", "/a/all", "/a/6116", "/a/6116/series",
    "/s", "/s/242", "/sequence/242", "/sequence/242/all",
    "/g", "/g/det_classic", "/g/39",
    "/booksearch", "/comp",
    "/opds/", "/opds/popular", "/opds/recent", "/opds/genres", "/opds/authors",
    "/opds/opensearch", "/opds/author/6116/alphabet/0",
    "/new", "/tracker",
    "/stat", "/stat/b", "/stat/my",
    "/user/me", "/user/me/edit", "/user/me/watcher", "/user/me/track", "/user/me/openid",
    "/messages", "/messages/new",
    "/polka", "/polka/show/1452402", "/polka/show/all", "/polka/add/226302",
    "/bwlist", "/bwlist/show/1452402",
    "/rec",
    "/forum", "/forum/5", "/blog", "/blog/4", "/blog/me",
    "/node/68682", "/node/add", "/dostup", "/upload",
    "/Aa", "/Bb", "/Sh",
}

new_findings = []
for ep in all_endpoints:
    matched = False
    for orig in original_endpoints:
        if ep == orig or ep.startswith(orig + "?") or ep.startswith(orig + "/"):
            matched = True
            break
    if not matched and ep not in original_endpoints:
        new_findings.append(ep)

print(f"\n  === NEWLY DISCOVERED (not in original docs) ===")
for ep in sorted(new_findings):
    print(f"    {ep}")

save("new_findings.json", sorted(new_findings))

print(f"\n{'='*60}")
print(f"  Done! Results in: {RESULTS}")
print(f"{'='*60}")
