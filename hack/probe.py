#!/usr/bin/env python3
"""Fast Flibusta probe — minimal, focused, no BS4 on huge pages."""
import sys, os, re, json, time
from pathlib import Path
from collections import defaultdict

sys.path.insert(0, str(Path(__file__).parent))
from flibusta_client import FlibustaClient

RESULTS = Path(__file__).parent.parent / "test_results" / "hack-probe"
RESULTS.mkdir(parents=True, exist_ok=True)

c = FlibustaClient()
user = os.environ.get("FLIBUSTA_USER", "")
pw = os.environ.get("FLIBUSTA_PASSWORD", "")
c.login(user, pw) if user and pw else None

visited = set()
forms_map = {}
selects_map = {}
js_urls = set()

def save(name, data):
    (RESULTS / name).write_text(json.dumps(data, ensure_ascii=False, indent=2, default=str), encoding="utf-8")

def fast(path):
    """Get page, regex-extract links/forms/selects — no BS4 for speed."""
    if path in visited:
        return None
    visited.add(path)
    try:
        r = c._get(path)
    except Exception as e:
        return None
    if not r:
        return None
    ct = r.headers.get("content-type", "")
    html = r.text
    entry = {"path": path, "status": r.status_code, "size": len(html)}

    if "html" not in ct:
        return entry

    # Regex-based extraction (much faster than BS4)
    # Links
    links = set(re.findall(r'href="(/[^"]{1,200})"', html))
    links = {l.split("?")[0].split("#")[0] for l in links
             if not l.startswith("/sites/") and not l.startswith("/misc/")}

    # Forms
    form_blocks = re.findall(r'<form[^>]*action="([^"]*)"[^>]*method="(\w+)"[^>]*>(.*?)</form>', html, re.S)
    for action, method, body in form_blocks:
        fields = re.findall(r'name="([^"]+)"', body)
        selects = re.findall(r'<select[^>]*name="([^"]+)"[^>]*>(.*?)</select>', body, re.S)
        sel_dict = {}
        for sname, sbody in selects:
            opts = re.findall(r'<option[^>]*value="([^"]*)"[^>]*>([^<]*)', sbody)
            sel_dict[sname] = [f"{v}:{t.strip()[:20]}" for v, t in opts[:8]]
        k = f"{method.upper()}:{action[:50]}"
        if k not in forms_map:
            forms_map[k] = {"action": action[:80], "method": method.upper(), "fields": fields[:15], "selects": sel_dict}

    # JS endpoints
    js_matches = re.findall(r'["\'](/[a-z][a-z0-9/_-]+(?:\?[^"\']*)?)["\']', html)
    for u in js_matches:
        if not u.startswith("/sites/") and not u.startswith("/misc/"):
            js_urls.add(u.split("?")[0])

    entry["links_count"] = len(links)
    # Filter: skip slow endpoints and individual entities
    SLOW_PREFIXES = ("/b/", "/a/", "/node/", "/comment/", "/user/", "/blog/", "/forum/")
    SLOW_SUFFIXES = ("/download", "/read", "/complain", "/mail", "/delalias")
    filtered = set()
    for l in links:
        if any(l.endswith(s) for s in SLOW_SUFFIXES):
            continue
        parts = l.strip("/").split("/")
        if len(parts) == 2 and parts[0] in ("a", "b", "node", "comment", "user", "blog", "forum"):
            continue
        filtered.add(l)
    entry["new_links"] = list(filtered - visited)[:40]
    return entry


# ═══════════════════════════════════════════════════════════════
print("PHASE 1: Seeds", flush=True)
SEEDS = [
    "/", "/b/226302", "/b/226302/read", "/b/226302/mail", "/b/12345",
    "/a/6116", "/a/6116/series", "/a/226377",
    "/s/242", "/s/28511", "/sequence/242", "/sequence/242/all",
    "/g/det_classic", "/g/39", "/g/love", "/g/sf",
    "/booksearch?ask=Толстой&chb=on", "/booksearch?ask=Конан&cha=on",
    "/booksearch?ask=Шерлок&chs=on", "/booksearch?ask=роман&chg=on",
    "/comp", "/new", "/tracker", "/stat", "/stat/b",
    "/rec", "/forum", "/blog", "/blog/4",
    "/user/me", "/user/me/edit", "/user/me/watcher",
    "/messages", "/messages/new",
    "/polka", "/polka/show/1452402", "/polka/show/all",
    "/bwlist", "/bwlist/show/1452402",
    "/dostup", "/upload", "/node/68682", "/node/4023", "/node/add",
    "/Aa", "/Other",
]

results = []
all_new = set()
for ep in SEEDS:
    t0 = time.time()
    info = fast(ep)
    dt = time.time() - t0
    if info:
        results.append(info)
        new = info.get("new_links", [])
        all_new.update(new)
        print(f"  {info['status']:3d} {ep:50s} L={info.get('links_count',0):4d} new={len(new):3d} {dt:.1f}s", flush=True)
    time.sleep(0.1)

print(f"\n  Total visited: {len(visited)}, new links pool: {len(all_new)}", flush=True)

# ═══════════════════════════════════════════════════════════════
print("\nPHASE 2: Follow new links (skip slow)", flush=True)
phase2 = []
SLOW = ("/download", "/read", "/complain", "/mail", "/delalias", "/fb2", "/epub")
for ep in sorted(all_new):
    if ep in visited:
        continue
    if any(ep.endswith(s) for s in SLOW):
        continue
    t0 = time.time()
    info = fast(ep)
    dt = time.time() - t0
    if info and info["status"] == 200:
        phase2.append(info)
        print(f"  {info['status']:3d} {ep:50s} {dt:.1f}s", flush=True)
    time.sleep(0.1)

# ═══════════════════════════════════════════════════════════════
print("\nPHASE 3: Patterns", flush=True)
PATTERNS = [
    "/api", "/json", "/xml", "/feed", "/rss",
    "/robots.txt", "/sitemap.xml",
    "/login", "/register", "/search",
    "/admin", "/export", "/import", "/download",
    "/comment/reply", "/user/list",
    "/b/new", "/a/new",
    "/taxonomy", "/help", "/faq", "/about",
    "/donate", "/support", "/feedback",
    "/b/226302/complain", "/polka/watch/add/226302",
    "/node/172739", "/node/180481", "/node/296743",
    "/node/684900", "/node/767158", "/node/688889",
    "/rec?view=new", "/rec?view=popular",
    "/messages/inbox", "/messages/sent",
]
for ep in PATTERNS:
    if ep not in visited:
        fast(ep)
        time.sleep(0.08)

# ═══════════════════════════════════════════════════════════════
# REPORT
# ═══════════════════════════════════════════════════════════════
print("\n" + "=" * 60, flush=True)
print("REPORT", flush=True)
print("=" * 60, flush=True)

all_eps = sorted(visited)
print(f"\nTotal: {len(all_eps)} URLs\n", flush=True)

cats = defaultdict(list)
for ep in all_eps:
    p = ep.strip("/").split("/")
    cats[p[0] if p and p[0] else "root"].append(ep)

for cat in sorted(cats):
    print(f"[{cat}] ({len(cats[cat])})", flush=True)
    for e in sorted(cats[cat])[:15]:
        print(f"  {e}", flush=True)
    if len(cats[cat]) > 15:
        print(f"  ... +{len(cats[cat]) - 15}", flush=True)
    print(flush=True)

print(f"Forms ({len(forms_map)}):", flush=True)
for k, f in sorted(forms_map.items()):
    print(f"  {f['method']:4s} {f['action'][:55]}", flush=True)
    if f.get("selects"):
        for sn, sopts in f["selects"].items():
            print(f"         select: {sn} = {[x.split(':')[1] for x in sopts[:5]]}", flush=True)
print(flush=True)

print(f"Selects ({len(selects_map)}):", flush=True)
for n, o in sorted(selects_map.items()):
    print(f"  {n}: {[x.split(':')[1][:20] for x in o[:8]]}", flush=True)
print(flush=True)

print(f"JS URLs ({len(js_urls)}):", flush=True)
for u in sorted(js_urls):
    print(f"  {u}", flush=True)

# New findings
KNOWN_PREFIXES = ["/b", "/a", "/s", "/g", "/sequence", "/booksearch", "/comp",
    "/new", "/tracker", "/opds", "/stat", "/user", "/messages", "/polka",
    "/rec", "/forum", "/blog", "/bwlist", "/node", "/dostup", "/upload",
    "/Aa", "/Other", "/catalog", "/sql", "/daily", "/comment"]
new = []
for ep in all_eps:
    if not any(ep.startswith(p) or ep == p for p in KNOWN_PREFIXES):
        new.append(ep)

print(f"\nNEWLY DISCOVERED ({len(new)}):", flush=True)
for e in sorted(new):
    print(f"  {e}", flush=True)

save("probe_report.json", {
    "total": len(all_eps),
    "endpoints": all_eps,
    "forms": forms_map,
    "selects": selects_map,
    "js_urls": list(js_urls),
    "new_findings": sorted(new),
})

print(f"\nSaved to {RESULTS}/probe_report.json", flush=True)
