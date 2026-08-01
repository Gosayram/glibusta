import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from flibusta_client import FlibustaClient
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


if __name__ == "__main__":
    unittest.main()
