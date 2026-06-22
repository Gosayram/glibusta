pub mod archive;
pub mod docx;
pub mod encoding;
pub mod epub;
pub mod fb2;
pub mod hash;
pub mod mobi;
pub mod rtf;
pub mod txt;

pub(crate) use hash::sha256_hex;

use crate::api::models::RichSpan;

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

/// Collapse whitespace: newlines/tabs to spaces, collapse runs, trim.
pub(crate) fn normalize_whitespace(text: &str) -> String {
    let mut result = String::with_capacity(text.len());
    let mut prev_was_space = false;
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
                result.push(ch);
                prev_was_space = false;
            }
        }
    }
    result.trim().to_string()
}
