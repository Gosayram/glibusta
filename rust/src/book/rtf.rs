use crate::api::models::{
    BlockType, BookFormat, MAX_IMAGE_SIZE, NormalizedBook, ReaderBlock, ReaderChapter, RichSpan,
};
use crate::book::normalize_whitespace;
use anyhow::Result;
use base64::Engine;
use std::sync::LazyLock;

/// Extended half of IBM PC code page 437, used by the RTF `\pc` header.
static CP437_EXTENDED: LazyLock<Vec<char>> = LazyLock::new(|| {
    "ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒáíóúñÑªº¿⌐¬½¼¡«»░▒▓│┤╡╢╖╕╣║╗╝╜╛┐└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■ "
        .chars()
        .collect()
});

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
    if has_rtf_control_word(head, b"\\mac") {
        return "macintosh";
    }
    if has_rtf_control_word(head, b"\\pc") {
        return "ibm437";
    }
    "windows-1252"
}

fn has_rtf_control_word(bytes: &[u8], control_word: &[u8]) -> bool {
    bytes
        .windows(control_word.len())
        .enumerate()
        .any(|(index, word)| {
            word == control_word
                && match bytes.get(index + control_word.len()) {
                    Some(next) => !next.is_ascii_alphabetic(),
                    None => true,
                }
        })
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
    if encoding.eq_ignore_ascii_case("ibm437") {
        return decode_cp437(bytes);
    }
    let (decoded, _, _) = encoding_rs::Encoding::for_label(encoding.as_bytes())
        .unwrap_or(encoding_rs::WINDOWS_1252)
        .decode(bytes);
    decoded.into_owned()
}

fn decode_cp437(bytes: &[u8]) -> String {
    bytes
        .iter()
        .map(|&byte| {
            if byte < 0x80 {
                char::from(byte)
            } else {
                CP437_EXTENDED[(byte - 0x80) as usize]
            }
        })
        .collect()
}

#[derive(Clone, Default)]
struct RtfFmt {
    bold: bool,
    italic: bool,
    superscript: bool,
    font_size_half_pts: i32,
    href: Option<String>,
}

struct RtfPicture {
    group_depth: i32,
    hex: String,
    media_type: Option<&'static str>,
    exceeds_limit: bool,
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
            href: fmt.href.clone(),
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
    let mut unicode_fallback_count = 1usize;
    let mut in_table_row = false;
    let mut table_rows: Vec<Vec<String>> = Vec::new();
    let mut current_table_row: Vec<String> = Vec::new();
    let mut picture: Option<RtfPicture> = None;
    let mut pending_hyperlink_href: Option<String> = None;
    let mut hyperlink_result_depth: Option<i32> = None;

    while i < bytes.len() {
        match bytes[i] {
            b'{' => {
                brace_depth += 1;
                if bytes[i + 1..].starts_with(b"\\*\\fldinst") {
                    let mut end = i.saturating_add(8192).min(bytes.len());
                    while end > i && !body.is_char_boundary(end) {
                        end -= 1;
                    }
                    pending_hyperlink_href = extract_rtf_hyperlink(&body[i..end]);
                }
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
                if hyperlink_result_depth == Some(brace_depth) {
                    flush_span(&mut rich_spans, &mut span_text, &fmt);
                    hyperlink_result_depth = None;
                }
                if picture
                    .as_ref()
                    .is_some_and(|picture| picture.group_depth == brace_depth)
                {
                    if let Some(picture) = picture.take() {
                        push_rtf_picture(&mut blocks, &mut block_index, picture);
                    }
                }
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
                    let mut escaped_bytes = Vec::new();
                    loop {
                        let hex_start = i + 1;
                        let hex_end = hex_start.saturating_add(2);
                        if hex_end > bytes.len() {
                            i = bytes.len();
                            break;
                        }
                        if let Ok(byte_val) = u8::from_str_radix(
                            std::str::from_utf8(&bytes[hex_start..hex_end]).unwrap_or("00"),
                            16,
                        ) {
                            if byte_val >= 0x20 {
                                escaped_bytes.push(byte_val);
                            }
                        }
                        i = hex_end;
                        if bytes.get(i) != Some(&b'\\') || bytes.get(i + 1) != Some(&b'\'') {
                            break;
                        }
                        i += 1;
                    }
                    append_encoded_bytes(&mut span_text, &escaped_bytes, encoding_name);
                    continue;
                }
                let cmd_start = i;
                while i < bytes.len() && (bytes[i].is_ascii_alphabetic() || bytes[i] == b'*') {
                    i += 1;
                }
                let cmd = std::str::from_utf8(&bytes[cmd_start..i]).unwrap_or("");

                match cmd {
                    "par" | "line" | "newline" | "page" | "sect" if in_table_row => {
                        if !span_text.is_empty() {
                            span_text.push('\n');
                        }
                    }
                    "par" | "line" | "newline" | "page" | "sect" => {
                        flush_rtf_table(&mut blocks, &mut block_index, &mut table_rows);
                        push_rtf_paragraph(
                            &mut blocks,
                            &mut block_index,
                            &mut rich_spans,
                            &mut span_text,
                            &mut fmt,
                        );
                    }
                    "trowd" => {
                        push_rtf_paragraph(
                            &mut blocks,
                            &mut block_index,
                            &mut rich_spans,
                            &mut span_text,
                            &mut fmt,
                        );
                        in_table_row = true;
                        current_table_row.clear();
                    }
                    "pict" => {
                        push_rtf_paragraph(
                            &mut blocks,
                            &mut block_index,
                            &mut rich_spans,
                            &mut span_text,
                            &mut fmt,
                        );
                        picture = Some(RtfPicture {
                            group_depth: brace_depth,
                            hex: String::new(),
                            media_type: None,
                            exceeds_limit: false,
                        });
                    }
                    "pngblip" if picture.is_some() => {
                        if let Some(picture) = picture.as_mut() {
                            picture.media_type = Some("image/png");
                        }
                    }
                    "jpegblip" if picture.is_some() => {
                        if let Some(picture) = picture.as_mut() {
                            picture.media_type = Some("image/jpeg");
                        }
                    }
                    "fldrslt" => {
                        flush_span(&mut rich_spans, &mut span_text, &fmt);
                        fmt.href = pending_hyperlink_href.take();
                        hyperlink_result_depth = Some(brace_depth);
                    }
                    "cell" if in_table_row => {
                        current_table_row.push(take_rtf_table_cell(
                            &mut rich_spans,
                            &mut span_text,
                            &mut fmt,
                        ));
                    }
                    "row" if in_table_row => {
                        if !span_text.is_empty() || !rich_spans.is_empty() {
                            current_table_row.push(take_rtf_table_cell(
                                &mut rich_spans,
                                &mut span_text,
                                &mut fmt,
                            ));
                        }
                        if !current_table_row.is_empty() {
                            table_rows.push(std::mem::take(&mut current_table_row));
                        }
                        in_table_row = false;
                    }
                    "tab" => span_text.push('\t'),
                    "lquote" | "lq" => span_text.push('\u{2018}'),
                    "rquote" | "rq" => span_text.push('\u{2019}'),
                    "ldblquote" | "ldq" => span_text.push('\u{201C}'),
                    "rdblquote" | "rdq" => span_text.push('\u{201D}'),
                    "emdash" | "em" => span_text.push('\u{2014}'),
                    "endash" | "en" => span_text.push('\u{2013}'),
                    "bullet" => span_text.push('\u{2022}'),
                    "ansi" | "ansicpg" | "deff" | "deflang" => {}
                    "uc" => {
                        let count_start = i;
                        while i < bytes.len() && bytes[i].is_ascii_digit() {
                            i += 1;
                        }
                        if let Ok(count) = std::str::from_utf8(&bytes[count_start..i])
                            .unwrap_or("1")
                            .parse::<usize>()
                        {
                            unicode_fallback_count = count;
                        }
                        if i < bytes.len() && bytes[i] == b' ' {
                            i += 1;
                        }
                        continue;
                    }
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
                        i = skip_unicode_fallback(body, i, unicode_fallback_count);
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
            _ if !skip_group && picture.is_some() => {
                if let Some(ch) = body[i..].chars().next() {
                    if ch.is_ascii_hexdigit() {
                        if let Some(picture) = picture.as_mut() {
                            let max_hex_len = MAX_IMAGE_SIZE.saturating_mul(2);
                            if picture.hex.len() < max_hex_len {
                                picture.hex.push(ch);
                            } else {
                                picture.exceeds_limit = true;
                            }
                        }
                    }
                    i += ch.len_utf8();
                } else {
                    break;
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

    if in_table_row {
        if !span_text.is_empty() || !rich_spans.is_empty() {
            current_table_row.push(take_rtf_table_cell(
                &mut rich_spans,
                &mut span_text,
                &mut fmt,
            ));
        }
        if !current_table_row.is_empty() {
            table_rows.push(current_table_row);
        }
    }
    flush_rtf_table(&mut blocks, &mut block_index, &mut table_rows);
    push_rtf_paragraph(
        &mut blocks,
        &mut block_index,
        &mut rich_spans,
        &mut span_text,
        &mut fmt,
    );

    blocks
}

/// Skip the fallback representation following an RTF `\\uN` escape.
fn skip_unicode_fallback(body: &str, mut index: usize, count: usize) -> usize {
    let bytes = body.as_bytes();
    for _ in 0..count {
        if index >= bytes.len() {
            break;
        }
        if bytes[index] == b'\\'
            && bytes.get(index + 1) == Some(&b'\'')
            && index.saturating_add(4) <= bytes.len()
        {
            index += 4;
        } else if let Some(ch) = body[index..].chars().next() {
            index += ch.len_utf8();
        } else {
            break;
        }
    }
    index
}

/// Decode an RTF `\\'hh` escape with the document's declared ANSI code page.
fn append_encoded_bytes(output: &mut String, bytes: &[u8], encoding_name: &str) {
    if encoding_name.eq_ignore_ascii_case("ibm437") {
        for &byte in bytes {
            output.push(if byte < 0x80 {
                char::from(byte)
            } else {
                CP437_EXTENDED[(byte - 0x80) as usize]
            });
        }
        return;
    }
    let encoding = encoding_rs::Encoding::for_label(encoding_name.as_bytes())
        .unwrap_or(encoding_rs::WINDOWS_1252);
    let (decoded, _, _) = encoding.decode(bytes);
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

fn take_rtf_table_cell(
    rich_spans: &mut Vec<RichSpan>,
    span_text: &mut String,
    fmt: &mut RtfFmt,
) -> String {
    flush_span(rich_spans, span_text, fmt);
    let text = rich_spans
        .iter()
        .map(|span| span.text.as_str())
        .collect::<String>();
    rich_spans.clear();
    span_text.clear();
    *fmt = RtfFmt::default();
    normalize_whitespace(&text)
}

fn flush_rtf_table(
    blocks: &mut Vec<ReaderBlock>,
    block_index: &mut i32,
    table_rows: &mut Vec<Vec<String>>,
) {
    if table_rows.is_empty() {
        return;
    }
    let rows = std::mem::take(table_rows);
    let text = rows
        .iter()
        .map(|row| row.join(" | "))
        .collect::<Vec<_>>()
        .join("\n");
    blocks.push(ReaderBlock {
        index: *block_index,
        text,
        block_type: BlockType::Table,
        image_url: None,
        note_ref: None,
        rich_spans: None,
        heading_level: None,
        ordered: None,
        list_items: None,
        table_rows: Some(rows),
        image_alt: None,
        text_indent: None,
        text_align: None,
        note_id: None,
    });
    *block_index += 1;
}

fn push_rtf_picture(blocks: &mut Vec<ReaderBlock>, block_index: &mut i32, picture: RtfPicture) {
    let Some(media_type) = picture.media_type else {
        return;
    };
    if picture.exceeds_limit || picture.hex.len() % 2 != 0 {
        return;
    }

    let mut bytes = Vec::with_capacity(picture.hex.len() / 2);
    for pair in picture.hex.as_bytes().chunks_exact(2) {
        let Ok(pair) = std::str::from_utf8(pair) else {
            return;
        };
        let Ok(byte) = u8::from_str_radix(pair, 16) else {
            return;
        };
        bytes.push(byte);
    }
    if bytes.is_empty() || bytes.len() > MAX_IMAGE_SIZE {
        return;
    }

    blocks.push(ReaderBlock {
        index: *block_index,
        text: String::new(),
        block_type: BlockType::Image,
        image_url: Some(format!(
            "data:{media_type};base64,{}",
            base64::engine::general_purpose::STANDARD.encode(bytes)
        )),
        note_ref: None,
        rich_spans: None,
        heading_level: None,
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

fn extract_rtf_hyperlink(instruction: &str) -> Option<String> {
    const HYPERLINK: &str = "HYPERLINK";
    let uppercase = instruction.to_ascii_uppercase();
    let start = uppercase.find(HYPERLINK)? + HYPERLINK.len();
    let target = instruction[start..].trim_start();
    let href = if let Some(rest) = target.strip_prefix('"') {
        rest.split('"').next()?
    } else {
        target.split_whitespace().next()?
    };
    crate::book::sanitize_href(href)
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
    fn decodes_consecutive_utf8_escaped_bytes_as_one_sequence() {
        let book = parse_rtf(
            br"{\rtf1\ansi\ansicpg65001\'d0\'9f\'d1\'80\'d0\'b8\'d0\'b2\'d0\'b5\'d1\'82}",
            None,
        )
        .expect("parse UTF-8 escaped RTF");

        assert_eq!(book.chapters[0].blocks[0].text, "Привет");
    }

    #[test]
    fn decodes_shift_jis_escaped_bytes_as_one_sequence() {
        let book = parse_rtf(br"{\rtf1\ansi\ansicpg932\'93\'fa\'96\'7b}", None)
            .expect("parse Shift-JIS escaped RTF");

        assert_eq!(book.chapters[0].blocks[0].text, "日本");
    }

    #[test]
    fn decodes_mac_roman_documents() {
        let book = parse_rtf(b"{\\rtf1\\mac Caf\x8e}", None).expect("parse MacRoman RTF");

        assert_eq!(book.chapters[0].blocks[0].text, "Café");
    }

    #[test]
    fn decodes_ibm_pc_code_page_437_documents() {
        let book = parse_rtf(br"{\rtf1\pc Caf\'82}", None).expect("parse CP437 RTF");

        assert_eq!(book.chapters[0].blocks[0].text, "Café");
    }

    #[test]
    fn retains_text_from_an_unclosed_group() {
        let book = parse_rtf(br"{\rtf1\ansi Unfinished text", Some("utf-8"))
            .expect("parse incomplete RTF");

        assert_eq!(book.chapters[0].blocks[0].text, "Unfinished text");
    }

    #[test]
    fn skips_unicode_fallback_characters() {
        let book =
            parse_rtf(br"{\rtf1\ansi\uc1\u1055?}", Some("utf-8")).expect("parse Unicode escape");

        assert_eq!(book.chapters[0].blocks[0].text, "П");
    }

    #[test]
    fn preserves_rtf_tables_as_table_blocks() {
        let book = parse_rtf(
            br"{\rtf1\ansi\trowd\cellx1000\intbl Header A\cell\cellx2000\intbl Header B\cell\row\trowd\cellx1000\intbl Cell A\cell\cellx2000\intbl Cell B\cell\row}",
            Some("utf-8"),
        )
        .expect("parse RTF table");

        let blocks = &book.chapters[0].blocks;
        assert_eq!(blocks.len(), 1, "{blocks:#?}");
        assert_eq!(blocks[0].block_type, crate::api::models::BlockType::Table);
        assert_eq!(
            blocks[0].table_rows.as_ref(),
            Some(&vec![
                vec!["Header A".to_string(), "Header B".to_string()],
                vec!["Cell A".to_string(), "Cell B".to_string()],
            ]),
        );
    }

    #[test]
    fn extracts_rtf_png_picture_as_an_image_block() {
        let book = parse_rtf(
            br"{\rtf1\ansi{\pict\pngblip 89504E470D0A1A0A}}",
            Some("utf-8"),
        )
        .expect("parse RTF picture");

        let blocks = &book.chapters[0].blocks;
        assert_eq!(blocks.len(), 1, "{blocks:#?}");
        assert_eq!(blocks[0].block_type, crate::api::models::BlockType::Image);
        assert!(
            blocks[0]
                .image_url
                .as_deref()
                .is_some_and(|url| url.starts_with("data:image/png;base64,")),
        );
    }

    #[test]
    fn preserves_rtf_hyperlink_field_targets() {
        let book = parse_rtf(
            br#"{\rtf1\ansi{\field{\*\fldinst{HYPERLINK "https://example.com"}}{\fldrslt{Example}}}}"#,
            Some("utf-8"),
        )
        .expect("parse RTF hyperlink");

        let block = &book.chapters[0].blocks[0];
        assert_eq!(block.text, "Example");
        assert_eq!(
            block
                .rich_spans
                .as_ref()
                .and_then(|spans| spans[0].href.as_deref()),
            Some("https://example.com"),
        );
    }

    #[test]
    fn strips_dangerous_rtf_hyperlink_field_targets() {
        let book = parse_rtf(
            br#"{\rtf1\ansi{\field{\*\fldinst{HYPERLINK "javascript:alert(1)"}}{\fldrslt{Unsafe}}}}"#,
            Some("utf-8"),
        )
        .expect("parse RTF hyperlink");

        let span = &book.chapters[0].blocks[0]
            .rich_spans
            .as_ref()
            .expect("rich span")[0];
        assert_eq!(span.text, "Unsafe");
        assert!(span.href.is_none());
    }
}
