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

## Evidence levels

- **Fixture-backed**: parsing behaviour covered by `test/fixtures/`.
- **Historical candidate**: route or form recorded in `ENDPOINTS.md`.
- **Archived snapshot**: metadata in ignored `test_results/`; useful for a
  hypothesis, never a substitute for a sanitised fixture.
- **Live audit**: metadata recorded only after `robots.txt` permits it.

Promote a candidate to verified only with an authorised audit result and a
sanitised fixture plus a parser test.
