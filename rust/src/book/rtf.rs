use crate::api::models::{
    BlockType, BookFormat, NormalizedBook, ReaderBlock, ReaderChapter, RichSpan,
};
use crate::book::normalize_whitespace;
use anyhow::Result;

pub fn parse_rtf(bytes: &[u8], forced_encoding: Option<&str>) -> Result<NormalizedBook> {
    let encoding_name = forced_encoding.unwrap_or_else(|| detect_rtf_encoding(bytes));
    let decoded = if encoding_name.eq_ignore_ascii_case("utf-8") {
        String::from_utf8_lossy(bytes).into_owned()
    } else {
        decode_with_encoding(bytes, encoding_name)
    };
    let blocks = rtf_to_rich_blocks(&decoded, encoding_name);

    let chapters = if blocks.is_empty() {
        vec![]
    } else {
        vec![ReaderChapter {
            index: 0,
            title: String::new(),
            blocks,
        }]
    };

    let id = crate::book::sha256_hex(bytes);

    Ok(NormalizedBook {
        id,
        title: String::new(),
        authors: Vec::new(),
        description: None,
        cover_url: None,
        chapters,
        metadata: None,
        book_format: BookFormat::Rtf,
        language: None,
        warnings: Vec::new(),
        images: Vec::new(),
        toc: Vec::new(),
    })
}

fn detect_rtf_encoding(bytes: &[u8]) -> &str {
    let search_limit = bytes.len().min(500);
    let head = &bytes[..search_limit];
    if let Some(pos) = memchr::memchr(b'\\', head) {
        let region = &head[pos..search_limit.min(pos + 30)];
        if let Some(start) = region.windows(8).position(|w| w == b"\\ansicpg") {
            let num_start = pos + start + 8;
            if num_start < search_limit {
                let num_end = (num_start..search_limit)
                    .find(|&i| !bytes[i].is_ascii_digit())
                    .unwrap_or(search_limit);
                if let Ok(cp) = std::str::from_utf8(&bytes[num_start..num_end]) {
                    if let Ok(codepage) = cp.parse::<u16>() {
                        return codepage_to_encoding(codepage);
                    }
                }
            }
        }
    }
    "windows-1252"
}

fn codepage_to_encoding(cp: u16) -> &'static str {
    match cp {
        65001 => "utf-8",
        1250 => "windows-1250",
        1251 => "windows-1251",
        1252 => "windows-1252",
        1253 => "windows-1253",
        1254 => "windows-1254",
        1255 => "windows-1255",
        1256 => "windows-1256",
        1257 => "windows-1257",
        1258 => "windows-1258",
        874 => "windows-874",
        932 => "shift_jis",
        936 => "gb2312",
        949 => "euc-kr",
        950 => "big5",
        _ => "windows-1252",
    }
}

fn decode_with_encoding(bytes: &[u8], encoding: &str) -> String {
    let (decoded, _, _) = encoding_rs::Encoding::for_label(encoding.as_bytes())
        .unwrap_or(encoding_rs::WINDOWS_1252)
        .decode(bytes);
    decoded.into_owned()
}

#[derive(Clone, Default)]
struct RtfFmt {
    bold: bool,
    italic: bool,
    superscript: bool,
    font_size_half_pts: i32,
}

impl RtfFmt {
    fn heading_level(&self) -> Option<i32> {
        const DEFAULT: i32 = 24;
        let ratio = self.font_size_half_pts as f64 / DEFAULT as f64;
        // ponytail: font-size ratio → heading, common RTF convention
        if ratio >= 3.0 {
            Some(1)
        } else if ratio >= 2.0 {
            Some(2)
        } else if ratio >= 1.5 {
            Some(3)
        } else if ratio >= 1.2 {
            Some(4)
        } else {
            None
        }
    }
}

/// Flush accumulated span_text into rich_spans with current formatting.
/// Always preserves text (even without formatting) so paragraphs aren't lost.
fn flush_span(rich_spans: &mut Vec<RichSpan>, span_text: &mut String, fmt: &RtfFmt) {
    let text = std::mem::take(span_text);
    if !text.trim().is_empty() {
        rich_spans.push(RichSpan {
            text,
            bold: fmt.bold,
            italic: fmt.italic,
            superscript: fmt.superscript,
            href: None,
            line_break: false,
        });
    }
}

fn rtf_to_rich_blocks(body: &str, encoding_name: &str) -> Vec<ReaderBlock> {
    let bytes = body.as_bytes();
    let mut i = 0;
    let mut brace_depth = 0i32;
    let mut skip_group = false;
    let mut skip_depth = 0i32;
    let mut group_stack: Vec<RtfFmt> = Vec::new();
    let mut fmt = RtfFmt::default();
    let mut span_text = String::new();
    let mut rich_spans: Vec<RichSpan> = Vec::new();
    let mut blocks: Vec<ReaderBlock> = Vec::new();
    let mut block_index = 0i32;

    while i < bytes.len() {
        match bytes[i] {
            b'{' => {
                brace_depth += 1;
                if bytes[i + 1..].starts_with(b"\\fonttbl")
                    || bytes[i + 1..].starts_with(b"\\colortbl")
                    || bytes[i + 1..].starts_with(b"\\stylesheet")
                    || bytes[i + 1..].starts_with(b"\\*")
                {
                    skip_group = true;
                    skip_depth = brace_depth;
                }
                group_stack.push(fmt.clone());
                i += 1;
            }
            b'}' => {
                if brace_depth > 0 {
                    brace_depth -= 1;
                }
                if skip_group && brace_depth < skip_depth {
                    skip_group = false;
                }
                if let Some(prev) = group_stack.pop() {
                    fmt = prev;
                }
                i += 1;
            }
            b'\\' if !skip_group && brace_depth > 0 => {
                i += 1;
                if i >= bytes.len() {
                    break;
                }
                if bytes[i] == b'\'' {
                    let hex_start = i + 1;
                    let hex_end = hex_start.saturating_add(2);
                    if hex_end <= bytes.len() {
                        if let Ok(byte_val) = u8::from_str_radix(
                            std::str::from_utf8(&bytes[hex_start..hex_end]).unwrap_or("00"),
                            16,
                        ) {
                            if byte_val >= 0x20 {
                                append_encoded_byte(&mut span_text, byte_val, encoding_name);
                            }
                        }
                        i = hex_end;
                    } else {
                        i = bytes.len();
                    }
                    continue;
                }
                let cmd_start = i;
                while i < bytes.len() && (bytes[i].is_ascii_alphabetic() || bytes[i] == b'*') {
                    i += 1;
                }
                let cmd = std::str::from_utf8(&bytes[cmd_start..i]).unwrap_or("");

                match cmd {
                    "par" | "line" | "newline" | "page" | "sect" => {
                        push_rtf_paragraph(
                            &mut blocks,
                            &mut block_index,
                            &mut rich_spans,
                            &mut span_text,
                            &mut fmt,
                        );
                    }
                    "tab" => span_text.push('\t'),
                    "lquote" | "lq" => span_text.push('\u{2018}'),
                    "rquote" | "rq" => span_text.push('\u{2019}'),
                    "ldblquote" | "ldq" => span_text.push('\u{201C}'),
                    "rdblquote" | "rdq" => span_text.push('\u{201D}'),
                    "emdash" | "em" => span_text.push('\u{2014}'),
                    "endash" | "en" => span_text.push('\u{2013}'),
                    "bullet" => span_text.push('\u{2022}'),
                    "ansi" | "ansicpg" | "uc" | "deff" | "deflang" => {}
                    "fonttbl" | "colortbl" | "stylesheet" | "listtables" | "revtbl" => {
                        skip_group = true;
                        skip_depth = brace_depth;
                    }
                    "b" => {
                        flush_span(&mut rich_spans, &mut span_text, &fmt);
                        fmt.bold = bytes.get(i) != Some(&b'0');
                    }
                    "i" => {
                        flush_span(&mut rich_spans, &mut span_text, &fmt);
                        fmt.italic = bytes.get(i) != Some(&b'0');
                    }
                    "super" => {
                        flush_span(&mut rich_spans, &mut span_text, &fmt);
                        fmt.superscript = true;
                    }
                    "sub" => {
                        flush_span(&mut rich_spans, &mut span_text, &fmt);
                        fmt.superscript = false;
                    }
                    "ul" | "ulnone" | "strike" | "scaps" | "highlight" => {}
                    "fs" => {
                        let size_start = i;
                        while i < bytes.len() && bytes[i].is_ascii_digit() {
                            i += 1;
                        }
                        if size_start < i {
                            if let Ok(size) = std::str::from_utf8(&bytes[size_start..i])
                                .unwrap_or("24")
                                .parse::<i32>()
                            {
                                fmt.font_size_half_pts = size;
                            }
                        }
                    }
                    "f" | "cf" | "cb" | "shd" | "lang" | "fcharset" | "pn" => {
                        while i < bytes.len() && bytes[i].is_ascii_digit() {
                            i += 1;
                        }
                    }
                    "u" => {
                        let negative = i < bytes.len() && bytes[i] == b'-';
                        if negative {
                            i += 1;
                        }
                        let num_start = i;
                        while i < bytes.len() && bytes[i].is_ascii_digit() {
                            i += 1;
                        }
                        if num_start < i {
                            let num_str = std::str::from_utf8(&bytes[num_start..i]).unwrap_or("0");
                            if let Ok(mut code_point) = num_str.parse::<i32>() {
                                if negative {
                                    code_point += 65536;
                                }
                                if let Some(c) = char::from_u32(code_point as u32) {
                                    span_text.push(c);
                                }
                            }
                        }
                        if i < bytes.len() && bytes[i] == b';' {
                            i += 1;
                        }
                        continue;
                    }
                    "bin" => {
                        let num_start = i;
                        while i < bytes.len() && bytes[i].is_ascii_digit() {
                            i += 1;
                        }
                        if let Ok(len) = std::str::from_utf8(&bytes[num_start..i])
                            .unwrap_or("0")
                            .parse::<usize>()
                        {
                            i += len;
                        }
                        continue;
                    }
                    _ => {}
                }

                while i < bytes.len() && bytes[i].is_ascii_digit() {
                    i += 1;
                }
                if i < bytes.len() && bytes[i] == b' ' {
                    i += 1;
                }
            }
            _ if !skip_group && brace_depth > 0 => {
                // `body` is already decoded. Advance by a Unicode scalar rather
                // than treating each UTF-8 byte as a separate Latin-1 character.
                if let Some(ch) = body[i..].chars().next() {
                    span_text.push(ch);
                    i += ch.len_utf8();
                } else {
                    break;
                }
            }
            _ => {
                i += 1;
            }
        }
    }

    push_rtf_paragraph(
        &mut blocks,
        &mut block_index,
        &mut rich_spans,
        &mut span_text,
        &mut fmt,
    );

    blocks
}

/// Decode an RTF `\\'hh` escape with the document's declared ANSI code page.
fn append_encoded_byte(output: &mut String, byte: u8, encoding_name: &str) {
    let encoding = encoding_rs::Encoding::for_label(encoding_name.as_bytes())
        .unwrap_or(encoding_rs::WINDOWS_1252);
    let encoded = [byte];
    let (decoded, _, _) = encoding.decode(&encoded);
    output.push_str(&decoded);
}

fn push_rtf_paragraph(
    blocks: &mut Vec<ReaderBlock>,
    block_index: &mut i32,
    rich_spans: &mut Vec<RichSpan>,
    span_text: &mut String,
    fmt: &mut RtfFmt,
) {
    // Flush any remaining span with formatting into rich_spans
    flush_span(rich_spans, span_text, fmt);

    let text = if rich_spans.is_empty() {
        normalize_whitespace(span_text)
    } else {
        // rich_spans text is already normalized — concatenate directly
        let cap: usize = rich_spans.iter().map(|s| s.text.len()).sum();
        let mut combined = String::with_capacity(cap);
        for s in rich_spans.iter() {
            combined.push_str(&s.text);
        }
        let trimmed = combined.trim().to_string();
        if trimmed.len() < combined.len() {
            trimmed
        } else {
            combined
        }
    };
    if !text.is_empty() || !rich_spans.is_empty() {
        blocks.push(ReaderBlock {
            index: *block_index,
            text,
            block_type: BlockType::Paragraph,
            image_url: None,
            note_ref: None,
            rich_spans: if rich_spans.is_empty() {
                None
            } else {
                Some(rich_spans.clone())
            },
            heading_level: fmt.heading_level(),
            ordered: None,
            list_items: None,
            table_rows: None,
            image_alt: None,
            text_indent: None,
            text_align: None,
            note_id: None,
        });
        *block_index += 1;
    }
    rich_spans.clear();
    span_text.clear();
    *fmt = RtfFmt::default();
}

#[cfg(test)]
mod tests {
    use super::parse_rtf;

    #[test]
    fn reset_controls_disable_inline_formatting() {
        let book = parse_rtf(
            br"{\rtf1\ansi\b Bold\b0 plain\i italic\i0 normal}",
            Some("utf-8"),
        )
        .expect("parse RTF");
        let spans = book.chapters[0].blocks[0]
            .rich_spans
            .as_ref()
            .expect("rich spans");

        assert_eq!(
            spans
                .iter()
                .map(|span| (span.text.trim(), span.bold, span.italic))
                .collect::<Vec<_>>(),
            vec![
                ("Bold", true, false),
                ("plain", false, false),
                ("italic", false, true),
                ("normal", false, false),
            ],
        );
    }

    #[test]
    fn preserves_utf8_literal_text() {
        let book = parse_rtf(r"{\rtf1\ansi Привет, мир!}".as_bytes(), Some("utf-8"))
            .expect("parse UTF-8 RTF");

        assert_eq!(book.chapters[0].blocks[0].text, "Привет, мир!");
    }

    #[test]
    fn decodes_escaped_bytes_using_the_declared_code_page() {
        let book = parse_rtf(br"{\rtf1\ansi\ansicpg1251\'cf\'f0\'e8\'e2\'e5\'f2}", None)
            .expect("parse Windows-1251 RTF");

        assert_eq!(book.chapters[0].blocks[0].text, "Привет");
    }

    #[test]
    fn skips_unicode_fallback_characters() {
        let book = parse_rtf(br"{\rtf1\ansi\uc1\u1055?}", Some("utf-8"))
            .expect("parse Unicode escape");

        assert_eq!(book.chapters[0].blocks[0].text, "П");
    }
}
