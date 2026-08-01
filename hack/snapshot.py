#!/usr/bin/env python3
"""Collect bare HTML/XML of Flibusta public endpoints into hack/fixtures/ for
offline parser development. Uses crawl4ai (headless chromium) by default, with a
plain-requests fallback. Robots-gated: stops without fetching if robots.txt
disallows. Mirrors the compliance contract of public_surface_audit.py."""

from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import re
import sys
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent))
from flibusta_client import FlibustaClient

try:
    from crawl4ai import AsyncWebCrawler, BrowserConfig, CacheMode, CrawlerRunConfig

    _CRAWL4AI_AVAILABLE = True
except ImportError:
    _CRAWL4AI_AVAILABLE = False

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)

SNAPSHOT_TARGETS: list[tuple[str, str, str, str]] = [
    ("main", "home", "/", "html"),
    ("book", "b_226302", "b/226302", "html"),
    ("book", "b_1", "b/1", "html"),
    ("book", "b_836924", "b/836924", "html"),
    ("book", "b_226302_read", "b/226302/read", "html"),
    ("book", "b_226302_mail", "b/226302/mail", "html"),
    ("search", "books", "booksearch?ask=%D0%A2%D0%BE%D0%BB%D1%81%D1%82%D0%BE%D0%B9&chb=on", "html"),
    ("search", "authors", "booksearch?ask=%D0%A2%D0%BE%D0%BB%D1%81%D1%82%D0%BE%D0%B9&cha=on", "html"),
    ("search", "series", "booksearch?ask=%D0%A2%D0%BE%D0%BB%D1%81%D1%82%D0%BE%D0%B9&chs=on", "html"),
    ("search", "genres", "booksearch?ask=%D0%A2%D0%BE%D0%BB%D1%81%D1%82%D0%BE%D0%B9&chg=on", "html"),
    ("search", "books_empty", "booksearch?ask=zzzznomatchxyz&chb=on", "html"),
    ("author", "a_index", "a", "html"),
    ("author", "a_all", "a/all", "html"),
    ("author", "a_6116", "a/6116", "html"),
    ("series", "s_index", "s", "html"),
    ("series", "s_1", "s/1", "html"),
    ("genre", "g_index", "g", "html"),
    ("genre", "g_detective", "g/detive", "html"),
    ("recent", "new", "new", "html"),
    ("stat", "stat_b", "stat/b", "html"),
    ("misc", "login", "user/login", "html"),
    ("misc", "register", "user/register", "html"),
    ("misc", "tracker", "tracker", "html"),
    ("misc", "rec", "rec", "html"),
    ("opds", "root", "opds/", "xml"),
    ("opds", "popular", "opds/popular", "xml"),
    ("opds", "recent", "opds/recent", "xml"),
    ("opds", "genres", "opds/genres", "xml"),
    ("opds", "authors", "opds/authors", "xml"),
    ("opds", "search_books", "opds/opensearch?searchTerm=%D0%A2%D0%BE%D0%BB%D1%81%D1%82%D0%BE%D0%B9&searchType=books&pageNumber=0", "xml"),
]


def _robots_policy(client: FlibustaClient) -> dict[str, Any]:
    started = time.perf_counter()
    policy = client.robots_policy(USER_AGENT)
    elapsed_ms = round((time.perf_counter() - started) * 1000, 1)
    return {**policy, "elapsed_ms": elapsed_ms}


def _safe_filename(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]", "_", name)


def _resolve(client: FlibustaClient, path: str) -> str:
    return client._resolve_url(path)


async def _collect_crawl4ai(
    targets: list[tuple[str, str, str, str]],
    client: FlibustaClient,
    delay: float,
) -> list[dict[str, Any]]:
    browser_cfg = BrowserConfig(
        browser_type="chromium",
        headless=True,
        viewport_width=1280,
        viewport_height=720,
        user_agent=USER_AGENT,
        ignore_https_errors=False,
        java_script_enabled=True,
    )
    run_cfg = CrawlerRunConfig(
        cache_mode=CacheMode.BYPASS,
        check_robots_txt=True,
        wait_until="domcontentloaded",
        page_timeout=30000,
        verbose=False,
        mean_delay=0.0,
        max_range=0.0,
    )
    results: list[dict[str, Any]] = []
    # ponytail: serial loop, arun_many if throughput matters
    async with AsyncWebCrawler(config=browser_cfg) as crawler:
        for category, name, path, kind in targets:
            url = _resolve(client, path)
            r = await crawler.arun(url=url, config=run_cfg)
            headers = getattr(r, "response_headers", None)
            content_type = headers.get("content-type") if isinstance(headers, dict) else None
            results.append({
                "category": category,
                "name": name,
                "path": path,
                "url": getattr(r, "url", url),
                "success": bool(getattr(r, "success", False)),
                "status_code": getattr(r, "status_code", None),
                "html": getattr(r, "html", None),
                "content_type": content_type,
                "error": getattr(r, "error_message", None),
                "kind": kind,
            })
            await asyncio.sleep(delay)
    return results


def _collect_requests(
    targets: list[tuple[str, str, str, str]],
    client: FlibustaClient,
    delay: float,
) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for category, name, path, kind in targets:
        url = _resolve(client, path)
        response = client._get(path, headers={"User-Agent": USER_AGENT})
        if response is None:
            results.append({
                "category": category, "name": name, "path": path, "url": url,
                "success": False, "status_code": None, "html": None,
                "content_type": None, "error": "request failed", "kind": kind,
            })
        else:
            results.append({
                "category": category, "name": name, "path": path, "url": url,
                "success": True, "status_code": response.status_code,
                "html": response.text,
                "content_type": response.headers.get("content-type"),
                "error": None, "kind": kind,
            })
        time.sleep(delay)
    return results


def _write_snapshot(report: dict[str, Any], snap: dict[str, Any], output_dir: Path) -> int:
    html = snap["html"] or ""
    html_bytes = html.encode("utf-8")
    ext = ".xml" if snap["kind"] == "xml" else ".html"
    fixture_path = output_dir / snap["category"] / (_safe_filename(snap["name"]) + ext)
    fixture_rel = None
    if snap["success"] and html:
        fixture_path.parent.mkdir(parents=True, exist_ok=True)
        fixture_path.write_bytes(html_bytes)
        fixture_rel = str(fixture_path.relative_to(output_dir))
    report["snapshots"].append({
        "category": snap["category"],
        "name": snap["name"],
        "path": snap["path"],
        "url": snap["url"],
        "kind": snap["kind"],
        "status": snap["status_code"],
        "success": snap["success"],
        "content_type": snap["content_type"],
        "bytes": len(html_bytes),
        "sha256": hashlib.sha256(html_bytes).hexdigest(),
        "fixture": fixture_rel,
        "fetched_at": datetime.now(UTC).isoformat(),
        "error": snap["error"],
    })
    return 1 if fixture_rel else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).parent / "fixtures")
    parser.add_argument("--delay-seconds", type=float, default=2.0)
    parser.add_argument("--backend", choices=["crawl4ai", "requests"], default="crawl4ai")
    args = parser.parse_args()

    client = FlibustaClient(min_request_interval_seconds=args.delay_seconds)
    report: dict[str, Any] = {
        "generated_at": datetime.now(UTC).isoformat(),
        "base_url": client.base_url,
        "user_agent": USER_AGENT,
        "backend": args.backend,
        "robots": _robots_policy(client),
        "snapshots": [],
    }

    n = 0
    if not report["robots"]["allowed"]:
        report["status"] = "blocked_by_robots"
        print("robots.txt disallows crawling; no pages requested")
    else:
        report["status"] = "completed"
        if args.backend == "crawl4ai" and not _CRAWL4AI_AVAILABLE:
            print(
                "crawl4ai not installed; run 'pip install crawl4ai && crawl4ai-setup'"
                " or use --backend requests"
            )
            return 1
        try:
            if args.backend == "crawl4ai":
                snapshots = asyncio.run(
                    _collect_crawl4ai(SNAPSHOT_TARGETS, client, args.delay_seconds)
                )
            else:
                snapshots = _collect_requests(SNAPSHOT_TARGETS, client, args.delay_seconds)
        except ImportError:
            print(
                "crawl4ai not installed; run 'pip install crawl4ai && crawl4ai-setup'"
                " or use --backend requests"
            )
            return 1
        for snap in snapshots:
            n += _write_snapshot(report, snap, args.output_dir)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "manifest.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    if report["status"] == "completed":
        print(f"Saved {n} snapshots to {args.output_dir} (backend={args.backend})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
