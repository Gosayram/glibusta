# Public-surface research

`hack/` contains local parser experiments and a conservative public-surface
audit. The runtime app is the source of truth; `openapi.yaml` and
`ENDPOINTS.md` are unverified design references, not an API contract.

## Safe audit

```bash
make flibusta-audit
```

The command reads `BASE_URL` from `.env`, validates it as a same-origin HTTP(S)
URL, requests `robots.txt`, and stops unless the configured audit user agent is
allowed. If permitted, it makes serial public GET requests with the declared
delay and writes only metadata to `test_results/flibusta-surface-audit/`:
status, latency, response size, MIME validation, content hash, and HTML/Atom
structure. It neither saves page bodies nor authenticates, posts forms, or
downloads books.

The client uses TLS verification for HTTPS, a 5-second connect timeout, a
20-second read timeout, no automatic cross-origin redirects, and checks the
exact target URL against `robots.txt`. It honours the larger of the configured
interval and the declared `Crawl-delay`; it deliberately does not retry requests
automatically, so retry bursts cannot violate that delay. Scripts that use
`FlibustaClient` share this guard. Do not bypass it; use authorised local HTML
fixtures to evolve parsers while live crawling is unavailable.

## Record mode (app-driven capture)

The configured origin disallows crawling for every agent
(`User-agent: * / Disallow: /`). Bulk fetching with `snapshot.py` or
`flibusta-audit` therefore fails closed. The legitimate way to obtain real pages
is to capture them from the app's own user-driven traffic, not from a crawler.

The Flutter app has a compile-time record mode. When enabled, a Dio interceptor
saves every HTML/XML response (search, book details, author, OPDS, etc.) to
`<app-documents>/fixtures/<category>/<name>.{html,xml}` plus an append-only
`record.jsonl` manifest (url, status, content-type, bytes, sha256).

```bash
flutter run --dart-define=RECORD_FIXTURES=true
# use the app normally: search, open books, browse authors/genres
```

Book-file downloads use `dart:io` directly and are intentionally not recorded.
Pull the captures off the device (path shown in the Diagnostics screen) and copy
them into `hack/fixtures/` or `test/fixtures/` to evolve parsers offline. This
is user-initiated traffic, not crawling, so it is legitimate regardless of
`robots.txt`.

`snapshot.py` remains as a robots-gated bulk collector for the day the origin
permits it; `--backend requests` reuses `FlibustaClient` without a browser.

## Evidence levels

- **Fixture-backed**: parsing behaviour covered by `test/fixtures/`.
- **Historical candidate**: route or form recorded in `ENDPOINTS.md`.
- **Archived snapshot**: metadata in ignored `test_results/`; useful for a
  hypothesis, never a substitute for a sanitised fixture.
- **Live audit**: metadata recorded only after `robots.txt` permits it.

Promote a candidate to verified only with an authorised audit result and a
sanitised fixture plus a parser test.
