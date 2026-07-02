use crate::api::models::{
    BlockType, BookFormat, NormalizedBook, ReaderBlock, ReaderChapter, RichSpan,
};
use crate::book::{flush_rich_span, normalize_whitespace};
use anyhow::Result;

pub fn parse_rtf(bytes: &[u8], forced_encoding: Option<&str>) -> Result<NormalizedBook> {
    let encoding_name = forced_encoding.unwrap_or_else(|| detect_rtf_encoding(bytes));
    let decoded = if encoding_name.eq_ignore_ascii_case("utf-8") {
        String::from_utf8_lossy(bytes).into_owned()
    } else {
        decode_with_encoding(bytes, encoding_name)
    };
    let (header_end, _codepage) = find_body_start(&decoded);
    let body = &decoded[header_end..];
    let blocks = rtf_to_rich_blocks(body);

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

fn find_body_start(text: &str) -> (usize, u16) {
    let mut codepage: u16 = 1252;
    let mut pos = 0;

    while pos < text.len() && pos < 2000 {
        if text[pos..].starts_with("\\ansicpg") {
            let num_start = pos + 8;
            let num_end = text[num_start..]
                .find(|c: char| !c.is_ascii_digit())
                .map(|e| num_start + e)
                .unwrap_or(text.len());
            if let Ok(cp) = text[num_start..num_end].parse::<u16>() {
                codepage = cp;
            }
        }

        if text[pos..].starts_with("\\rtf1") {
            let mut brace_depth = 0i32;
            let mut search_pos = pos;
            while search_pos < text.len() && search_pos < 5000 {
                match text.as_bytes()[search_pos] {
                    b'{' => brace_depth += 1,
                    b'}' => {
                        brace_depth -= 1;
                        if brace_depth < 0 {
                            return (search_pos + 1, codepage);
                        }
                    }
                    b'\\' => {
                        search_pos += 1;
                        if search_pos < text.len() {
                            match text.as_bytes()[search_pos] {
                                b'{' | b'}' | b'\\' => {}
                                b'\n' | b'\r' => {}
                                _ => {
                                    while search_pos < text.len()
                                        && text.as_bytes()[search_pos].is_ascii_alphanumeric()
                                    {
                                        search_pos += 1;
                                    }
                                    if search_pos < text.len()
                                        && text.as_bytes()[search_pos] == b' '
                                    {
                                        search_pos += 1;
                                    }
                                    continue;
                                }
                            }
                        }
                    }
                    _ => {}
                }
                search_pos += 1;
            }
            break;
        }
        pos += 1;
    }

    (pos, codepage)
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

fn rtf_to_rich_blocks(body: &str) -> Vec<ReaderBlock> {
    let bytes = body.as_bytes();
    let mut i = 0;
    let mut brace_depth = 0i32;
    let mut skip_group = false;
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
                if bytes[i + 1..].starts_with(b"\\fonttbl") {
                    skip_group = true;
                }
                group_stack.push(fmt.clone());
                i += 1;
            }
            b'}' => {
                if brace_depth > 0 {
                    brace_depth -= 1;
                }
                if skip_group && brace_depth == 0 {
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
                let cmd_start = i;
                while i < bytes.len()
                    && (bytes[i].is_ascii_alphabetic() || bytes[i] == b'*' || bytes[i] == b'\'')
                {
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
                    }
                    "b" => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            fmt.bold,
                            fmt.italic,
                            fmt.superscript,
                            &None,
                        );
                        fmt.bold = true;
                    }
                    "b0" => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            fmt.bold,
                            fmt.italic,
                            fmt.superscript,
                            &None,
                        );
                        fmt.bold = false;
                    }
                    "i" => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            fmt.bold,
                            fmt.italic,
                            fmt.superscript,
                            &None,
                        );
                        fmt.italic = true;
                    }
                    "i0" => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            fmt.bold,
                            fmt.italic,
                            fmt.superscript,
                            &None,
                        );
                        fmt.italic = false;
                    }
                    "super" => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            fmt.bold,
                            fmt.italic,
                            fmt.superscript,
                            &None,
                        );
                        fmt.superscript = true;
                    }
                    "sub" => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            fmt.bold,
                            fmt.italic,
                            fmt.superscript,
                            &None,
                        );
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
                    _ => {
                        if cmd.starts_with('\'') && i + 2 <= bytes.len() {
                            let hex = &bytes[i..i + 2];
                            if let Ok(byte_val) =
                                u8::from_str_radix(std::str::from_utf8(hex).unwrap_or("00"), 16)
                            {
                                if byte_val >= 0x20 {
                                    span_text.push(byte_val as char);
                                }
                            }
                            i += 2;
                            continue;
                        }
                    }
                }

                while i < bytes.len() && bytes[i].is_ascii_digit() {
                    i += 1;
                }
                if i < bytes.len() && bytes[i] == b' ' {
                    i += 1;
                }
            }
            c if !skip_group && brace_depth > 0 => {
                span_text.push(c as char);
                i += 1;
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

fn push_rtf_paragraph(
    blocks: &mut Vec<ReaderBlock>,
    block_index: &mut i32,
    rich_spans: &mut Vec<RichSpan>,
    span_text: &mut String,
    fmt: &mut RtfFmt,
) {
    flush_rich_span(
        rich_spans,
        span_text,
        fmt.bold,
        fmt.italic,
        fmt.superscript,
        &None,
    );
    let text = if rich_spans.is_empty() {
        normalize_whitespace(span_text)
    } else {
        normalize_whitespace(
            &rich_spans
                .iter()
                .map(|s| s.text.as_str())
                .collect::<Vec<_>>()
                .join(""),
        )
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
