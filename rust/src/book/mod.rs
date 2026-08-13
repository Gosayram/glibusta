pub mod archive;
pub mod cbr;
pub mod cbz;
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

/// Strip schemes the native reader must not navigate (javascript:, vbscript:,
/// data:, file:). HTTP(S) links are presented for explicit user confirmation.
pub(crate) fn sanitize_href(href: &str) -> Option<String> {
    let trimmed = href.trim();
    if trimmed.is_empty() {
        return None;
    }
    if let Some(colon) = trimmed.find(':') {
        let scheme: Vec<u8> = trimmed.as_bytes()[..colon]
            .iter()
            .copied()
            .filter(|byte| !byte.is_ascii_whitespace() && !byte.is_ascii_control())
            .map(|byte| byte.to_ascii_lowercase())
            .collect();
        if matches!(
            scheme.as_slice(),
            b"javascript" | b"vbscript" | b"data" | b"file"
        ) {
            return None;
        }
    }
    Some(trimmed.to_string())
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
    // Fast-path: no typographic characters → return as-is
    if !text.bytes().any(|b| b == b'-' || b == b'.' || b == b'"') {
        return text.to_string();
    }
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
                let (ch, adv) = copy_char(text, i);
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
            let (ch, adv) = copy_char(text, i);
            result.push_str(ch);
            i = adv;
        }
    }
    result
}

/// Copy a single UTF-8 character at position `i`. Returns (character, next_i).
fn copy_char(text: &str, i: usize) -> (&str, usize) {
    let ch = text[i..].chars().next().expect("index is within text");
    let end = i + ch.len_utf8();
    (&text[i..end], end)
}

/// Insert soft hyphens (U+00AD) at TeX hyphenation break points.
/// Skips words shorter than 3 characters and already-hyphenated words.
pub(crate) fn add_soft_hyphens(text: &str) -> String {
    // ponytail: skip if already processed
    if text.contains('\u{00AD}') {
        return text.to_string();
    }
    let mut result = String::with_capacity(text.len() + text.len() / 5);
    for segment in split_keep_delims(text) {
        if segment.is_empty() {
            continue;
        }
        let first_char = segment.chars().next().unwrap();
        if first_char.is_alphanumeric() {
            let word = segment.to_string();
            let breaks = crate::api::api::hyphenate_word(word);
            if breaks.is_empty() {
                result.push_str(segment);
            } else {
                let bytes = segment.as_bytes();
                let mut last = 0;
                for pos in &breaks {
                    let &pos = pos;
                    if pos > last && pos < bytes.len() {
                        result.push_str(&segment[last..pos]);
                        result.push('\u{00AD}');
                        last = pos;
                    }
                }
                result.push_str(&segment[last..]);
            }
        } else {
            result.push_str(segment);
        }
    }
    result
}

/// Split text into alternating alphanumeric and non-alphanumeric segments.
/// Delimiters (punctuation, spaces) are preserved exactly.
fn split_keep_delims(text: &str) -> Vec<&str> {
    let mut segments = Vec::new();
    let mut start = 0;
    let mut in_alpha = false;
    for (i, ch) in text.char_indices() {
        let is_a = ch.is_alphanumeric();
        if i == start {
            in_alpha = is_a;
        } else if is_a != in_alpha {
            segments.push(&text[start..i]);
            start = i;
            in_alpha = is_a;
        }
    }
    if start < text.len() {
        segments.push(&text[start..]);
    }
    segments
}

/// Collapse multiple whitespace into single spaces and multiple newlines
/// into single newlines, then trim. Skips image/separator blocks.
pub(crate) fn collapse_whitespace(text: &str) -> String {
    let mut result = String::with_capacity(text.len());
    let mut prev_was_space = true;
    let mut consecutive_newlines = 0u32;

    for ch in text.chars() {
        match ch {
            '\r' => continue,
            '\n' => {
                consecutive_newlines += 1;
                if consecutive_newlines <= 1 {
                    result.push('\n');
                }
                prev_was_space = true;
            }
            ' ' | '\t' | '\x0C' => {
                if !prev_was_space {
                    result.push(' ');
                }
                prev_was_space = true;
            }
            _ => {
                consecutive_newlines = 0;
                prev_was_space = false;
                result.push(ch);
            }
        }
    }

    // Trim trailing whitespace
    let trimmed = result.trim_end();
    if trimmed.len() == result.len() {
        result
    } else {
        trimmed.to_string()
    }
}

/// Remove blocks with empty text (whitespace-only) that are not images/separators,
/// and collapse whitespace in text content. Applied after parsing.
pub(crate) fn postprocess_chapters(chapters: &mut [crate::api::models::ReaderChapter]) {
    for chapter in chapters.iter_mut() {
        chapter.blocks.retain(|b| {
            !b.text.trim().is_empty()
                || matches!(
                    b.block_type,
                    crate::api::models::BlockType::Image | crate::api::models::BlockType::Separator
                )
        });
        for block in &mut chapter.blocks {
            if matches!(
                block.block_type,
                crate::api::models::BlockType::Image | crate::api::models::BlockType::Separator
            ) {
                continue;
            }
            let cleaned = collapse_whitespace(&block.text);
            if cleaned != block.text {
                block.text = cleaned;
            }
        }
    }
}
