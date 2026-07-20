pub mod api;
pub mod book;
#[allow(clippy::all, unused)]
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

pub use api::models::*;
use serde_json::Value;

/// Small, deterministic UB smoke coverage for `make miri-check`.
///
/// Keep this module free of disk, network and large-fixture work: Miri executes
/// an interpreter, so the full parser test suite belongs in `make miri-full`.
#[cfg(test)]
mod miri_smoke_tests {
    use crate::api::models::BookFormat;
    use crate::book::{sanitize_href, txt::parse_txt};

    #[test]
    fn parses_a_small_text_book_without_unsafe_aliasing() {
        let book = parse_txt(b"Title\n\nFirst paragraph.\nSecond line.", Some("utf-8"))
            .expect("small UTF-8 book must parse");

        assert_eq!(book.book_format, BookFormat::Txt);
        assert!(!book.title.is_empty());
        assert_eq!(book.chapters.len(), 1);
        assert!(
            book.chapters[0]
                .blocks
                .iter()
                .any(|block| block.text == "Title")
        );
        assert!(
            book.chapters[0]
                .blocks
                .iter()
                .any(|block| block.text.contains("First paragraph."))
        );
    }

    #[test]
    fn removes_unsafe_href_schemes_without_touching_safe_links() {
        assert_eq!(sanitize_href(" java\nscript:alert(1) "), None);
        assert_eq!(
            sanitize_href("https://example.com/chapter"),
            Some("https://example.com/chapter".into())
        );
    }
}
