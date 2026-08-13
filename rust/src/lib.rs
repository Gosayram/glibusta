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
    use crate::book::{normalize_whitespace, sanitize_href};

    #[test]
    fn normalizes_text_without_unsafe_aliasing() {
        let normalized = normalize_whitespace("  First\r\nsecond -- \"quoted\"...  ");

        assert_eq!(normalized, "First second — «quoted»…");
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
