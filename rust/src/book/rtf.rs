use crate::api::models::{BlockType, NormalizedBook, ReaderBlock, ReaderChapter};
use anyhow::Result;

pub fn parse_rtf(bytes: &[u8], forced_encoding: Option<&str>) -> Result<NormalizedBook> {
    let (text, _encoding) = decode_rtf(bytes, forced_encoding)?;
    Ok(text_to_book(text))
}

fn decode_rtf(bytes: &[u8], forced_encoding: Option<&str>) -> Result<(String, String)> {
    let encoding_name = forced_encoding.unwrap_or_else(|| detect_rtf_encoding(bytes));
    let decoded = if encoding_name.eq_ignore_ascii_case("utf-8") {
        String::from_utf8_lossy(bytes).into_owned()
    } else {
        decode_with_encoding(bytes, encoding_name)
    };
    let (header_end, _codepage) = find_body_start(&decoded);
    let body = &decoded[header_end..];
    let plain_text = rtf_to_plain(body);
    let cleaned = clean_rtf_output(&plain_text);
    Ok((cleaned, encoding_name.to_string()))
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

fn rtf_to_plain(text: &str) -> String {
    let bytes = text.as_bytes();
    let mut result = String::with_capacity(text.len());
    let mut i = 0;
    let mut skip_group = false;
    let mut brace_depth = 0i32;

    while i < bytes.len() {
        match bytes[i] {
            b'{' => {
                brace_depth += 1;
                if bytes[i + 1..].starts_with(b"\\fonttbl") {
                    skip_group = true;
                }
                i += 1;
            }
            b'}' => {
                if brace_depth > 0 {
                    brace_depth -= 1;
                }
                if brace_depth == 0 && skip_group {
                    skip_group = false;
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
                        result.push('\n');
                    }
                    "tab" => {
                        result.push('\t');
                    }
                    "lquote" | "lq" => result.push('\u{2018}'),
                    "rquote" | "rq" => result.push('\u{2019}'),
                    "ldblquote" | "ldq" => result.push('\u{201C}'),
                    "rdblquote" | "rdq" => result.push('\u{201D}'),
                    "emdash" | "em" => result.push('\u{2014}'),
                    "endash" | "en" => result.push('\u{2013}'),
                    "bullet" => result.push('\u{2022}'),
                    "ansi" | "ansicpg" | "uc" | "deff" | "deflang" => {}
                    "fonttbl" | "colortbl" | "stylesheet" | "listtables" | "revtbl" => {
                        skip_group = true;
                    }
                    "b" | "b0" | "i" | "i0" | "super" | "sub" | "ul" | "ulnone" | "strike"
                    | "scaps" | "highlight" => {}
                    "fs" | "f" | "cf" | "cb" | "shd" | "lang" | "fcharset" | "pn" => {
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
                                    result.push(c);
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
                                    result.push(byte_val as char);
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
                result.push(c as char);
                i += 1;
            }
            _ => {
                i += 1;
            }
        }
    }

    result
}

fn clean_rtf_output(text: &str) -> String {
    let mut result = String::with_capacity(text.len());
    let mut prev_was_newline = false;

    for c in text.chars() {
        match c {
            '\r' => continue,
            '\n' => {
                if !prev_was_newline {
                    result.push('\n');
                }
                prev_was_newline = true;
            }
            ' ' | '\t' => {
                if !prev_was_newline {
                    result.push(' ');
                }
                prev_was_newline = false;
            }
            _ => {
                result.push(c);
                prev_was_newline = false;
            }
        }
    }

    result.trim().to_string()
}

fn text_to_book(text: String) -> NormalizedBook {
    let lines: Vec<&str> = text.lines().collect();
    let mut chapters: Vec<ReaderChapter> = Vec::new();
    let mut current_blocks: Vec<ReaderBlock> = Vec::new();
    let mut block_index = 0i32;
    let mut current_text = String::new();

    for line in &lines {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            if !current_text.is_empty() {
                current_blocks.push(ReaderBlock {
                    index: block_index,
                    text: current_text.trim().to_string(),
                    block_type: BlockType::Paragraph,
                    image_url: None,
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
                block_index += 1;
                current_text.clear();
            }
        } else {
            if !current_text.is_empty() {
                current_text.push(' ');
            }
            current_text.push_str(trimmed);
        }
    }

    if !current_text.is_empty() {
        current_blocks.push(ReaderBlock {
            index: block_index,
            text: current_text.trim().to_string(),
            block_type: BlockType::Paragraph,
            image_url: None,
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
    }

    if !current_blocks.is_empty() {
        chapters.push(ReaderChapter {
            index: 0,
            title: String::new(),
            blocks: current_blocks,
        });
    }

    NormalizedBook {
        id: String::new(),
        title: String::new(),
        authors: Vec::new(),
        description: None,
        cover_url: None,
        chapters,
        metadata: None,
    }
}
