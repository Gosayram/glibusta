pub mod archive;
pub mod djvu;
pub mod docx;
pub mod encoding;
pub mod epub;
pub mod fb2;
pub mod hash;
pub(crate) mod html_parser;
pub mod layout;
pub mod mobi;
#[cfg(feature = "pdf")]
pub mod pdf;
pub mod rtf;
pub mod txt;

pub(crate) use hash::sha256_hex;

use crate::api::models::RichSpan;

// ---------------------------------------------------------------------------
// ARC-2.3: Object Pool — reuse Vec<RichSpan> allocations across paragraphs
// ---------------------------------------------------------------------------

thread_local! {
    static SPAN_POOL: std::cell::RefCell<Vec<Vec<RichSpan>>> = const { std::cell::RefCell::new(Vec::new()) };
}

/// Get a pre-allocated Vec<RichSpan> from the pool (or create new).
#[allow(dead_code)]
pub(crate) fn pool_get_spans() -> Vec<RichSpan> {
    SPAN_POOL
        .with(|pool| pool.borrow_mut().pop())
        .unwrap_or_default()
}

/// Return a Vec<RichSpan> to the pool for reuse. Clears the vec.
#[allow(dead_code)]
pub(crate) fn pool_return_spans(mut spans: Vec<RichSpan>) {
    spans.clear();
    SPAN_POOL.with(|pool| {
        let p = pool.borrow();
        if p.len() < 64 {
            drop(p);
            pool.borrow_mut().push(spans);
        }
    });
}

/// Strip dangerous schemes from href (javascript:, vbscript:, data:).
pub(crate) fn sanitize_href(href: &str) -> Option<String> {
    let trimmed = href.trim();
    if trimmed.is_empty() {
        return None;
    }
    let lower = trimmed.to_ascii_lowercase();
    if lower.starts_with("javascript:")
        || lower.starts_with("vbscript:")
        || lower.starts_with("data:")
    {
        return None;
    }
    Some(trimmed.to_string())
}

/// Flush accumulated span_text into a RichSpan if formatting is active.
pub(crate) fn flush_rich_span(
    spans: &mut Vec<RichSpan>,
    span_text: &mut String,
    bold: bool,
    italic: bool,
    superscript: bool,
    href: &Option<String>,
) {
    let text = span_text.trim().to_string();
    if text.is_empty() && href.is_none() {
        return;
    }
    if bold || italic || superscript || href.is_some() {
        spans.push(RichSpan {
            text,
            bold,
            italic,
            superscript,
            href: href.clone(),
            line_break: false,
        });
    }
    span_text.clear();
}

/// Collapse whitespace + normalize typography (dashes, quotes, ellipsis).
pub(crate) fn normalize_whitespace(text: &str) -> String {
    let mut result = String::with_capacity(text.len());
    let mut prev_was_space = true; // true → skip leading whitespace
    let mut has_typo_chars = false;

    for ch in text.chars() {
        match ch {
            '\r' => continue,
            '\n' | ' ' | '\t' => {
                if !prev_was_space {
                    result.push(' ');
                }
                prev_was_space = true;
            }
            _ => {
                prev_was_space = false;
                if ch == '-' || ch == '.' || ch == '"' {
                    has_typo_chars = true;
                }
                result.push(ch);
            }
        }
    }

    if result.is_empty() {
        return result;
    }

    // Trim trailing whitespace
    let trimmed_len = result.trim_end().len();
    result.truncate(trimmed_len);

    if has_typo_chars {
        normalize_typography(&result)
    } else {
        result
    }
}

/// Normalize Russian/English typography (single-pass):
/// - " - " → " — " and "--" → "—"
/// - "..." → "…"
/// - Straight quotes "..." → «...» (Russian guillemets)
pub(crate) fn normalize_typography(text: &str) -> String {
    let bytes = text.as_bytes();
    let mut result = String::with_capacity(bytes.len());
    let mut open_quote = true;
    let mut i = 0;
    while i < bytes.len() {
        // Pattern matching — scan for known sequences
        if bytes[i] == b'-' {
            if i + 1 < bytes.len() && bytes[i + 1] == b'-' {
                // "--" → em dash
                result.push('\u{2014}');
                i += 2;
            } else if i > 0 && bytes[i - 1] == b' ' && i + 1 < bytes.len() && bytes[i + 1] == b' ' {
                // " - " → " — " (leading space already copied, push just "\u{2014} ")
                result.push_str("\u{2014} ");
                i += 2; // skip past the trailing space
            } else {
                let (ch, adv) = copy_char(bytes, i);
                result.push_str(ch);
                i = adv;
            }
        } else if i + 2 < bytes.len()
            && bytes[i] == b'.'
            && bytes[i + 1] == b'.'
            && bytes[i + 2] == b'.'
        {
            // "..." → "…"
            result.push('\u{2026}');
            i += 3;
        } else if bytes[i] == b'"' {
            if open_quote {
                result.push('\u{00AB}');
            } else {
                result.push('\u{00BB}');
            }
            open_quote = !open_quote;
            i += 1;
        } else {
            let (ch, adv) = copy_char(bytes, i);
            result.push_str(ch);
            i = adv;
        }
    }
    result
}

/// Copy a single UTF-8 character from bytes at position i. Returns (&str, next_i).
fn copy_char(bytes: &[u8], i: usize) -> (&str, usize) {
    let first = bytes[i];
    let len = if first < 0x80 {
        1
    } else if first & 0xE0 == 0xC0 {
        2
    } else if first & 0xF0 == 0xE0 {
        3
    } else {
        4
    };
    let end = (i + len).min(bytes.len());
    // SAFETY: input text is valid UTF-8, slice is within bounds
    (
        unsafe { std::str::from_utf8_unchecked(&bytes[i..end]) },
        end,
    )
}

// ---------------------------------------------------------------------------
// RCE-28.2: Rust-side BookParser trait
// ---------------------------------------------------------------------------

use crate::api::models::{BookFormat, NormalizedBook};

/// Trait for format-specific book parsers.
/// Enables adding new formats (PDF, DjVu) without rewriting core dispatch.
pub trait BookParser {
    /// Detect if this parser can handle the given format.
    fn detect(format: BookFormat) -> bool
    where
        Self: Sized;

    /// Parse a book from bytes into NormalizedBook.
    fn parse(bytes: &[u8], forced_encoding: Option<&str>) -> anyhow::Result<NormalizedBook>
    where
        Self: Sized;
}

/// Dispatch to the correct parser using BookParser trait.
pub fn dispatch_parse_trait(format: BookFormat, bytes: &[u8]) -> anyhow::Result<NormalizedBook> {
    match format {
        BookFormat::Fb2 => fb2::parse_fb2(bytes, None),
        BookFormat::Epub => epub::parse_epub(bytes, None),
        BookFormat::Txt => txt::parse_txt(bytes, None),
        BookFormat::Docx => docx::parse_docx(bytes, None),
        BookFormat::Rtf => rtf::parse_rtf(bytes, None),
        BookFormat::Mobi | BookFormat::Azw3 | BookFormat::Prc => mobi::parse_mobi(bytes, None),
        _ => Err(anyhow::anyhow!("Unsupported format: {:?}", format)),
    }
}
