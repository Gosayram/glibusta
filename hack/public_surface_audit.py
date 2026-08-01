#!/usr/bin/env python3
"""Audit only the public, robots-permitted metadata surface of BASE_URL."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import time
from collections import Counter
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.parse import urljoin, urlsplit
from xml.etree import ElementTree as ET

from bs4 import BeautifulSoup
from flibusta_client import FlibustaClient, RobotsDisallowedError

USER_AGENT = "GlibustaPublicSurfaceAudit/1.0"
PUBLIC_ENDPOINTS = (
    ("/", "html"),
    ("/a", "html"),
    ("/b", "html"),
    ("/g", "html"),
    ("/s", "html"),
    ("/new", "html"),
    ("/stat", "html"),
    ("/opds/", "xml"),
    ("/opds/popular", "xml"),
    ("/opds/recent", "xml"),
    ("/opds/genres", "xml"),
    (
        "/opds/opensearch?searchTerm=%D0%A2%D0%BE%D0%BB%D1%81%D1%82%D0%BE%D0%B9&searchType=books&pageNumber=0",
        "xml",
    ),
)


def _route_pattern(url: str, base_url: str) -> str | None:
    parsed = urlsplit(urljoin(f"{base_url}/", url))
    if parsed.netloc != urlsplit(base_url).netloc:
        return None
    path = re.sub(r"/\d+(?=/|$)", "/{id}", parsed.path or "/")
    query = "&".join(sorted(part.split("=", 1)[0] for part in parsed.query.split("&") if part))
    return f"{path}?{query}" if query else path


def _html_summary(body: str, base_url: str) -> dict[str, Any]:
    soup = BeautifulSoup(body, "html.parser")
    routes: Counter[str] = Counter()
    for link in soup.find_all("a", href=True):
        route = _route_pattern(str(link["href"]), base_url)
        if route:
            routes[route] += 1

    forms = []
    for form in soup.find_all("form"):
        fields = sorted(
            {
                str(field["name"])
                for field in form.select("input[name], select[name], textarea[name]")
            }
        )
        forms.append(
            {
                "method": str(form.get("method", "GET")).upper(),
                "action": _route_pattern(str(form.get("action", "")), base_url),
                "fields": fields,
            }
        )

    return {
        "html_lang": soup.html.get("lang") if soup.html else None,
        "has_main": bool(soup.select_one("main, #main")),
        "forms": forms,
        "route_patterns": dict(routes.most_common(100)),
    }


def _xml_summary(body: str) -> dict[str, Any]:
    root = ET.fromstring(body)
    fields = Counter(element.tag.rsplit("}", 1)[-1] for element in root.iter())
    links = Counter(
        (
            link.get("rel", ""),
            link.get("type", ""),
        )
        for link in root.iter()
        if link.tag.rsplit("}", 1)[-1] == "link"
    )
    return {
        "root": root.tag.rsplit("}", 1)[-1],
        "element_counts": dict(fields.most_common()),
        "link_rel_types": {f"{rel}|{mime}": count for (rel, mime), count in links.items()},
    }


def _robots_policy(client: FlibustaClient) -> dict[str, Any]:
    started = time.perf_counter()
    policy = client.robots_policy(USER_AGENT)
    elapsed_ms = round((time.perf_counter() - started) * 1000, 1)
    return {**policy, "elapsed_ms": elapsed_ms}


def _audit_endpoint(client: FlibustaClient, path: str, expected_type: str) -> dict[str, Any]:
    started = time.perf_counter()
    try:
        response = client._get(path, headers={"User-Agent": USER_AGENT})
    except RobotsDisallowedError:
        return {
            "path": path,
            "status": "blocked_by_robots",
            "elapsed_ms": round((time.perf_counter() - started) * 1000, 1),
        }
    elapsed_ms = round((time.perf_counter() - started) * 1000, 1)
    if response is None:
        return {"path": path, "error": "request failed", "elapsed_ms": elapsed_ms}

    content_type = response.headers.get("content-type", "").lower()
    result: dict[str, Any] = {
        "path": path,
        "status": response.status_code,
        "elapsed_ms": elapsed_ms,
        "content_type": content_type,
        "body_bytes": len(response.content),
        "sha256": hashlib.sha256(response.content).hexdigest(),
        "validation": {
            "success_status": 200 <= response.status_code < 300,
            "expected_content_type": expected_type in content_type,
        },
    }
    try:
        result["structure"] = (
            _html_summary(response.text, client.base_url)
            if expected_type == "html"
            else _xml_summary(response.text)
        )
    except (ET.ParseError, UnicodeDecodeError) as error:
        result["parse_error"] = str(error)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir", type=Path, default=Path("test_results/flibusta-surface-audit")
    )
    parser.add_argument("--delay-seconds", type=float, default=10)
    args = parser.parse_args()

    client = FlibustaClient(min_request_interval_seconds=args.delay_seconds)
    report: dict[str, Any] = {
        "generated_at": datetime.now(UTC).isoformat(),
        "base_url": client.base_url,
        "user_agent": USER_AGENT,
        "robots": _robots_policy(client),
        "endpoints": [],
    }
    if not report["robots"]["allowed"]:
        report["status"] = "blocked_by_robots"
        print("robots.txt disallows crawling; no public pages requested")
    else:
        report["status"] = "completed"
        for path, expected_type in PUBLIC_ENDPOINTS:
            report["endpoints"].append(_audit_endpoint(client, path, expected_type))

    args.output_dir.mkdir(parents=True, exist_ok=True)
    output = args.output_dir / "report.json"
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Saved {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
