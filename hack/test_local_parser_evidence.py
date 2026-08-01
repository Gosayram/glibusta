import sys
import unittest
from pathlib import Path
from xml.etree import ElementTree as ET

from bs4 import BeautifulSoup

sys.path.insert(0, str(Path(__file__).parent))

from flibusta_client import ATOM_NS, OS_NS, FlibustaClient, _get_numbers

FIXTURES = Path(__file__).parent.parent / "test" / "fixtures"


class LocalParserEvidenceTest(unittest.TestCase):
    def test_book_details_supports_local_download_fixture(self) -> None:
        soup = BeautifulSoup(
            (FIXTURES / "book_details" / "sample_book.html").read_text(encoding="utf-8"),
            "html.parser",
        )
        client = FlibustaClient("https://library.example")
        client._get_html_page = lambda _: soup

        book = client.get_book_details("12345")

        self.assertIsNotNone(book)
        self.assertEqual(book.description[:5], "Роман")
        self.assertEqual([author.id for author in book.authors], [100])
        self.assertEqual(book.formats, ["fb2", "epub", "txt", "mobi"])

    def test_route_id_does_not_include_a_format_digit(self) -> None:
        self.assertEqual(_get_numbers("/b/743131/fb2"), "743131")

    def test_opds_preserves_all_authors_and_uses_ceiling_pages(self) -> None:
        feed = ET.fromstring(
            f"""<feed xmlns=\"{ATOM_NS}\" xmlns:os=\"{OS_NS}\">
              <os:totalResults>21</os:totalResults><os:itemsPerPage>20</os:itemsPerPage>
              <os:startIndex>0</os:startIndex><entry><id>book:1</id><title>Book</title>
              <author><name>One</name><uri>/a/1</uri></author>
              <author><name>Two</name><uri>/a/2</uri></author></entry></feed>"""
        )
        client = FlibustaClient("https://library.example")
        client._get_opds_feed = lambda _: feed

        result = client.search_books_by_name_opds_paginated("book")

        self.assertEqual(result.total_pages, 2)
        self.assertEqual(result.items[0].id, "book:1")
        self.assertEqual([author.name for author in result.items[0].authors], ["One", "Two"])


if __name__ == "__main__":
    unittest.main()
