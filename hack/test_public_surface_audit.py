import sys
import unittest
from pathlib import Path
from unittest.mock import Mock

sys.path.insert(0, str(Path(__file__).parent))

from flibusta_client import FlibustaClient, RobotsDisallowedError
from public_surface_audit import _route_pattern


class PublicSurfaceAuditTest(unittest.TestCase):
    def test_normalizes_internal_routes_and_rejects_other_origins(self) -> None:
        self.assertEqual(
            _route_pattern("/b/12345/read?format=fb2", "https://library.example"),
            "/b/{id}/read?format",
        )
        self.assertIsNone(_route_pattern("https://other.example/b/1", "https://library.example"))

    def test_client_rejects_untrusted_base_urls(self) -> None:
        with self.assertRaises(ValueError):
            FlibustaClient("ftp://library.example")

    def test_client_stops_when_robots_disallows_crawling(self) -> None:
        client = FlibustaClient("https://library.example", min_request_interval_seconds=0)
        robots = Mock(
            status_code=200,
            text="User-agent: *\nDisallow: /\n",
            content=b"User-agent: *\nDisallow: /\n",
        )
        client.session.request = Mock(return_value=robots)

        with self.assertRaises(RobotsDisallowedError):
            client._get("/")

        self.assertEqual(client.session.request.call_count, 1)
        self.assertIn("robots.txt", client.session.request.call_args.args[1])


if __name__ == "__main__":
    unittest.main()
