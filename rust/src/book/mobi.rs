use std::collections::{HashMap, HashSet};

use anyhow::{bail, Result};
use regex::Regex;

use crate::api::models::{BlockType, NormalizedBook, ReaderBlock, ReaderChapter, RichSpan};

const MAX_DECOMPRESSED_RECORD_BYTES: usize = 8 * 1024 * 1024;
const MAX_TOTAL_TEXT_BYTES: usize = 32 * 1024 * 1024;

// ---------------------------------------------------------------------------
// BinaryReader
// ---------------------------------------------------------------------------

struct BinaryReader<'a> {
    bytes: &'a [u8],
}

impl<'a> BinaryReader<'a> {
    fn new(bytes: &'a [u8]) -> Self {
        Self { bytes }
    }

    fn check(&self, offset: usize, length: usize) {
        if offset + length > self.bytes.len() {
            panic!(
                "BinaryReader: offset {} + length {} out of range (len {})",
                offset,
                length,
                self.bytes.len()
            );
        }
    }

    fn u16be(&self, offset: usize) -> u16 {
        self.check(offset, 2);
        ((self.bytes[offset] as u16) << 8) | (self.bytes[offset + 1] as u16)
    }

    fn u32be(&self, offset: usize) -> u32 {
        self.check(offset, 4);
        ((self.bytes[offset] as u32) << 24)
            | ((self.bytes[offset + 1] as u32) << 16)
            | ((self.bytes[offset + 2] as u32) << 8)
            | (self.bytes[offset + 3] as u32)
    }

    fn ascii(&self, offset: usize, length: usize) -> String {
        self.check(offset, length);
        self.bytes[offset..offset + length]
            .iter()
            .map(|&b| b as char)
            .collect()
    }

    #[allow(dead_code)]
    fn slice(&self, start: usize, end: usize) -> &'a [u8] {
        if start > end || end > self.bytes.len() {
            panic!(
                "BinaryReader::slice: start {} end {} out of range (len {})",
                start,
                end,
                self.bytes.len()
            );
        }
        &self.bytes[start..end]
    }
}

// ---------------------------------------------------------------------------
// PalmRecord
// ---------------------------------------------------------------------------

struct PalmRecord {
    offset: usize,
    #[allow(dead_code)]
    attributes: u8,
    #[allow(dead_code)]
    unique_id: u32,
}

// ---------------------------------------------------------------------------
// PalmDb
// ---------------------------------------------------------------------------

struct PalmDb {
    name: String,
    records: Vec<PalmRecord>,
}

// ---------------------------------------------------------------------------
// PalmDbParser
// ---------------------------------------------------------------------------

struct PalmDbParser;

impl PalmDbParser {
    fn parse(&self, bytes: &[u8]) -> Result<PalmDb> {
        let reader = BinaryReader::new(bytes);
        let record_count = reader.u16be(76) as usize;
        let table_end = 78 + record_count * 8;

        if record_count == 0 || table_end > bytes.len() {
            bail!("Invalid PalmDB record table");
        }

        let mut records = Vec::with_capacity(record_count);
        let mut offset = 78;
        let mut previous_record_offset: i64 = -1;

        for _ in 0..record_count {
            let record_offset = reader.u32be(offset) as i64;
            if record_offset < table_end as i64 || record_offset >= bytes.len() as i64 {
                bail!("Invalid PalmDB record offset: {}", record_offset);
            }
            if previous_record_offset > record_offset {
                bail!("PalmDB record offsets are not sorted");
            }
            previous_record_offset = record_offset;
            records.push(PalmRecord {
                offset: record_offset as usize,
                attributes: bytes[offset + 4],
                unique_id: ((bytes[offset + 5] as u32) << 16)
                    | ((bytes[offset + 6] as u32) << 8)
                    | (bytes[offset + 7] as u32),
            });
            offset += 8;
        }

        let name = reader.ascii(0, 32).replace('\0', "").trim().to_string();

        Ok(PalmDb { name, records })
    }
}

// ---------------------------------------------------------------------------
// MobiHeader
// ---------------------------------------------------------------------------

struct MobiHeader {
    compression: u16,
    text_encoding: u16,
    text_record_count: u16,
    #[allow(dead_code)]
    record_size: u16,
    full_name_offset: u32,
    full_name_length: u32,
    exth_flags: u32,
    first_image_record_index: u32,
}

// ---------------------------------------------------------------------------
// MobiHeaderParser
// ---------------------------------------------------------------------------

struct MobiHeaderParser;

impl MobiHeaderParser {
    const MOBI_OFFSET: usize = 16;

    fn parse(&self, record0: &[u8]) -> Result<MobiHeader> {
        let reader = BinaryReader::new(record0);
        let mobi_offset = Self::MOBI_OFFSET;

        if reader.ascii(mobi_offset, 4) != "MOBI" {
            bail!("Invalid MOBI header");
        }

        Ok(MobiHeader {
            compression: reader.u16be(0),
            text_encoding: reader.u16be(mobi_offset + 12),
            text_record_count: reader.u16be(8),
            record_size: reader.u16be(10),
            full_name_offset: reader.u32be(mobi_offset + 84),
            full_name_length: reader.u32be(mobi_offset + 88),
            exth_flags: reader.u32be(mobi_offset + 128),
            first_image_record_index: reader.u32be(mobi_offset + 108),
        })
    }
}

// ---------------------------------------------------------------------------
// MobiMetadata
// ---------------------------------------------------------------------------

struct MobiMetadata {
    title: Option<String>,
    author: Option<String>,
    language: Option<String>,
    cover_record_index: Option<u32>,
    has_exth: bool,
}

impl MobiMetadata {
    fn default() -> Self {
        Self {
            title: None,
            author: None,
            language: None,
            cover_record_index: None,
            has_exth: false,
        }
    }
}

// ---------------------------------------------------------------------------
// ExthParser
// ---------------------------------------------------------------------------

struct ExthParser;

impl ExthParser {
    fn parse(&self, record0: &[u8], header: &MobiHeader) -> MobiMetadata {
        if (header.exth_flags & 0x40) == 0 {
            return MobiMetadata::default();
        }

        let exth_offset = match self.find_exth_offset(record0) {
            Some(o) => o,
            None => return MobiMetadata::default(),
        };

        let reader = BinaryReader::new(record0);
        let length = reader.u32be(exth_offset + 4) as usize;
        let count = reader.u32be(exth_offset + 8) as usize;
        let exth_end = exth_offset + length;

        if length < 12 || exth_end > record0.len() {
            return MobiMetadata {
                has_exth: true,
                ..MobiMetadata::default()
            };
        }

        let mut title: Option<String> = None;
        let mut author: Option<String> = None;
        let mut language: Option<String> = None;
        let mut cover_record_index: Option<u32> = None;
        let mut pos = exth_offset + 12;

        for _ in 0..count {
            if pos + 8 > exth_end {
                break;
            }
            let r = BinaryReader::new(record0);
            let rec_type = r.u32be(pos);
            let size = r.u32be(pos + 4) as usize;
            if size < 8 || pos + size > exth_end {
                break;
            }

            let data = &record0[pos + 8..pos + size];
            match rec_type {
                100 => {
                    author = Some(String::from_utf8_lossy(data).trim().to_string());
                }
                503 => {
                    title = Some(String::from_utf8_lossy(data).trim().to_string());
                }
                524 => {
                    language = Some(String::from_utf8_lossy(data).trim().to_string());
                }
                201 if data.len() >= 4 => {
                    let cr = BinaryReader::new(data);
                    cover_record_index = Some(cr.u32be(0));
                }
                _ => {}
            }
            pos += size;
        }

        MobiMetadata {
            title,
            author,
            language,
            cover_record_index,
            has_exth: true,
        }
    }

    fn find_exth_offset(&self, record0: &[u8]) -> Option<usize> {
        (0..record0.len().saturating_sub(3)).find(|&i| {
            record0[i] == 0x45
                && record0[i + 1] == 0x58
                && record0[i + 2] == 0x54
                && record0[i + 3] == 0x48
        })
    }
}

// ---------------------------------------------------------------------------
// MobiHtmlParser
// ---------------------------------------------------------------------------

struct MobiHtmlParser {
    block_elements: HashSet<&'static str>,
    void_elements: HashSet<&'static str>,
    entity_map: HashMap<&'static str, &'static str>,
    tag_name_re: Regex,
    strip_outer_re: Regex,
    href_re: Regex,
    tag_re: Regex,
}

impl MobiHtmlParser {
    fn new() -> Self {
        let mut block_elements = HashSet::new();
        for &name in &[
            "p",
            "div",
            "h1",
            "h2",
            "h3",
            "h4",
            "h5",
            "h6",
            "blockquote",
            "pre",
            "table",
            "ul",
            "ol",
            "li",
            "tr",
            "td",
            "th",
            "section",
            "article",
            "header",
            "footer",
            "figure",
            "figcaption",
        ] {
            block_elements.insert(name);
        }

        let mut void_elements = HashSet::new();
        for &name in &[
            "br", "hr", "img", "input", "meta", "link", "area", "base", "col", "embed", "source",
            "track", "wbr",
        ] {
            void_elements.insert(name);
        }

        let mut entity_map = HashMap::new();
        entity_map.insert("amp", "&");
        entity_map.insert("lt", "<");
        entity_map.insert("gt", ">");
        entity_map.insert("nbsp", " ");
        entity_map.insert("quot", "\"");
        entity_map.insert("apos", "'");

        Self {
            block_elements,
            void_elements,
            entity_map,
            tag_name_re: Regex::new(r"(?i)^<?/?([a-zA-Z][a-zA-Z0-9]*)").unwrap(),
            strip_outer_re: Regex::new(r"(?i)^<(p|div|blockquote|pre|section|article)[^>]*>")
                .unwrap(),
            href_re: Regex::new(r#"href="([^"]*)""#).unwrap(),
            tag_re: Regex::new(r"<[^>]*>").unwrap(),
        }
    }

    fn parse(&self, html: &str) -> Vec<ReaderBlock> {
        let clean = self.strip_mbp_and_comments(html);
        let block_chunks = self.split_into_block_chunks(&clean);
        let mut blocks: Vec<ReaderBlock> = Vec::new();
        let mut idx = 0i32;

        for chunk in &block_chunks {
            let trimmed = chunk.trim();
            if trimmed.is_empty() {
                continue;
            }

            let lower = trimmed.to_lowercase();
            if self.is_heading(&lower) {
                let text = self.extract_text_from_chunk(trimmed);
                if !text.is_empty() {
                    blocks.push(ReaderBlock {
                        index: idx,
                        text,
                        block_type: BlockType::Heading,
                        image_url: None,
                        note_ref: None,
                        rich_spans: Some(self.parse_inline(trimmed)),
                    });
                    idx += 1;
                }
            } else if lower.starts_with("<hr") || lower.starts_with("<hr/>") || lower == "<hr>" {
                blocks.push(ReaderBlock {
                    index: idx,
                    text: String::new(),
                    block_type: BlockType::Separator,
                    image_url: None,
                    note_ref: None,
                    rich_spans: None,
                });
                idx += 1;
            } else if self.is_blockquote(&lower) {
                let text = self.extract_text_from_chunk(trimmed);
                if !text.is_empty() {
                    blocks.push(ReaderBlock {
                        index: idx,
                        text,
                        block_type: BlockType::Quote,
                        image_url: None,
                        note_ref: None,
                        rich_spans: Some(self.parse_inline(trimmed)),
                    });
                    idx += 1;
                }
            } else {
                let inner = self.strip_outer_block_tag(trimmed);
                let spans = self.parse_inline(&inner);
                let text = self.spans_to_text(&spans);
                if !text.is_empty() {
                    blocks.push(ReaderBlock {
                        index: idx,
                        text,
                        block_type: BlockType::Paragraph,
                        image_url: None,
                        note_ref: None,
                        rich_spans: if spans.is_empty() { None } else { Some(spans) },
                    });
                    idx += 1;
                }
            }
        }

        if blocks.is_empty() {
            let stripped = self.tag_re.replace_all(html, " ");
            let collapsed = stripped.split_whitespace().collect::<Vec<_>>().join(" ");
            let plain_text = self.decode_entities(&collapsed);
            if !plain_text.is_empty() {
                blocks.push(ReaderBlock {
                    index: 0,
                    text: plain_text,
                    block_type: BlockType::Paragraph,
                    image_url: None,
                    note_ref: None,
                    rich_spans: None,
                });
            }
        }

        blocks
    }

    fn strip_mbp_and_comments(&self, html: &str) -> String {
        let mut result = String::with_capacity(html.len());
        let mut i = 0;
        let bytes = html.as_bytes();
        let len = bytes.len();

        while i < len {
            if bytes[i] == b'<' {
                // Check for mbp: tag
                if i + 5 < len
                    && bytes[i + 1] == b'm'
                    && bytes[i + 2] == b'b'
                    && bytes[i + 3] == b'p'
                    && bytes[i + 4] == b':'
                {
                    if let Some(end) = memchr::memchr(b'>', &bytes[i..]) {
                        i = i + end + 1;
                        continue;
                    } else {
                        break;
                    }
                }
                // Check for <!DOCTYPE
                if i + 9 < len
                    && bytes[i + 1] == b'!'
                    && (bytes[i + 2] == b'D' || bytes[i + 2] == b'd')
                {
                    if let Some(end) = memchr::memchr(b'>', &bytes[i..]) {
                        i = i + end + 1;
                        continue;
                    } else {
                        break;
                    }
                }
                // Check for <!-- comment -->
                if i + 4 < len
                    && bytes[i + 1] == b'!'
                    && bytes[i + 2] == b'-'
                    && bytes[i + 3] == b'-'
                {
                    // Look for -->
                    let mut j = i + 4;
                    while j + 2 < len {
                        if bytes[j] == b'-' && bytes[j + 1] == b'-' && bytes[j + 2] == b'>' {
                            i = j + 3;
                            break;
                        }
                        j += 1;
                    }
                    if j + 2 < len {
                        continue;
                    } else {
                        // No closing found, skip to end
                        break;
                    }
                }
                // Check for <? processing instruction ?>
                if i + 2 < len && bytes[i + 1] == b'?' {
                    let mut j = i + 2;
                    while j + 1 < len {
                        if bytes[j] == b'?' && bytes[j + 1] == b'>' {
                            i = j + 2;
                            break;
                        }
                        j += 1;
                    }
                    if j + 1 < len {
                        continue;
                    } else {
                        break;
                    }
                }
            }
            result.push(bytes[i] as char);
            i += 1;
        }

        result
    }

    fn split_into_block_chunks(&self, html: &str) -> Vec<String> {
        let mut result: Vec<String> = Vec::new();
        let mut buf = String::new();
        let mut i = 0;
        let chars: Vec<char> = html.chars().collect();
        let len = chars.len();

        while i < len {
            if chars[i] == '<' {
                let tag_end = chars[i..].iter().position(|&c| c == '>').map(|p| i + p);
                let tag_end = match tag_end {
                    Some(e) => e,
                    None => {
                        for c in &chars[i..] {
                            buf.push(*c);
                        }
                        break;
                    }
                };

                let tag: String = chars[i..=tag_end].iter().collect();
                let lower = tag.to_lowercase();
                let name_match = self.tag_name_re.captures(&lower);
                let name = name_match
                    .as_ref()
                    .and_then(|m| m.get(1))
                    .map(|m| m.as_str())
                    .unwrap_or("");
                let is_closing = tag.len() > 1 && chars[i + 1] == '/';
                let is_self_closing = tag.ends_with("/>") || self.void_elements.contains(name);

                if !is_closing && !is_self_closing && self.block_elements.contains(name) {
                    if !buf.is_empty() {
                        let s = buf.trim().to_string();
                        if !s.is_empty() {
                            result.push(s);
                        }
                        buf.clear();
                    }
                    buf.push_str(&tag);
                    i = tag_end + 1;
                    let remaining: String = chars[i..].iter().collect::<String>().to_lowercase();
                    let close_tag = format!("</{}>", name);
                    if let Some(close_idx) = remaining.find(&close_tag) {
                        let inner: String = chars[i..i + close_idx].iter().collect();
                        buf.push_str(&inner);
                        i = i + close_idx + close_tag.len();
                    }
                    let s = buf.trim().to_string();
                    if !s.is_empty() {
                        result.push(s);
                    }
                    buf.clear();
                } else if name == "br" || name == "br/" {
                    buf.push('\n');
                    i = tag_end + 1;
                } else if name == "p" && !is_closing {
                    if !buf.is_empty() {
                        let s = buf.trim().to_string();
                        if !s.is_empty() {
                            result.push(s);
                        }
                        buf.clear();
                    }
                    buf.push_str(&tag);
                    i = tag_end + 1;
                    let remaining: String = chars[i..].iter().collect::<String>().to_lowercase();
                    if let Some(close_idx) = remaining.find("</p>") {
                        let inner: String = chars[i..i + close_idx].iter().collect();
                        buf.push_str(&inner);
                        i = i + close_idx + 4;
                    }
                    let s = buf.trim().to_string();
                    if !s.is_empty() {
                        result.push(s);
                    }
                    buf.clear();
                } else if name == "div" && !is_closing {
                    if !buf.is_empty() {
                        let s = buf.trim().to_string();
                        if !s.is_empty() {
                            result.push(s);
                        }
                        buf.clear();
                    }
                    let remaining: String = chars[i..].iter().collect::<String>().to_lowercase();
                    if let Some(close_idx) = remaining.find("</div>") {
                        let inner: String = chars[i..i + close_idx].iter().collect();
                        let sub_chunks = self.split_into_block_chunks(&inner);
                        result.extend(sub_chunks);
                        i = i + close_idx + 6;
                    } else {
                        buf.push_str(&tag);
                        i = tag_end + 1;
                    }
                } else {
                    buf.push_str(&tag);
                    i = tag_end + 1;
                }
            } else {
                let next_tag = chars[i..].iter().position(|&c| c == '<').map(|p| i + p);
                let next_tag = next_tag.unwrap_or(len);
                let text: String = chars[i..next_tag].iter().collect();
                buf.push_str(&text);
                i = next_tag;
            }
        }

        let remaining = buf.trim().to_string();
        if !remaining.is_empty() {
            result.push(remaining);
        }
        result
    }

    fn is_heading(&self, lower: &str) -> bool {
        lower.starts_with("<h1")
            || lower.starts_with("<h2")
            || lower.starts_with("<h3")
            || lower.starts_with("<h4")
            || lower.starts_with("<h5")
            || lower.starts_with("<h6")
    }

    fn is_blockquote(&self, lower: &str) -> bool {
        lower.starts_with("<blockquote")
    }

    fn parse_inline(&self, chunk: &str) -> Vec<RichSpan> {
        let mut spans: Vec<RichSpan> = Vec::new();
        let mut buf = String::new();
        let mut bold = false;
        let mut italic = false;
        let mut superscript = false;
        let mut href: Option<String> = None;
        let chars: Vec<char> = chunk.chars().collect();
        let len = chars.len();
        let mut i = 0;

        while i < len {
            if chars[i] == '<' {
                let tag_end = chars[i..].iter().position(|&c| c == '>').map(|p| i + p);
                let tag_end = match tag_end {
                    Some(e) => e,
                    None => {
                        for c in &chars[i..] {
                            buf.push(*c);
                        }
                        break;
                    }
                };

                let tag: String = chars[i..=tag_end].iter().collect();
                let lower = tag.to_lowercase();
                let name_match = self.tag_name_re.captures(&lower);
                let name = name_match
                    .as_ref()
                    .and_then(|m| m.get(1))
                    .map(|m| m.as_str())
                    .unwrap_or("");
                let is_closing = tag.len() > 1 && chars[i + 1] == '/';
                let is_self_closing = tag.ends_with("/>") || self.void_elements.contains(name);

                if !is_closing && !is_self_closing && self.block_elements.contains(name) {
                    self.flush_buf(&mut buf, &mut spans, bold, italic, superscript, &href);
                    i = tag_end + 1;
                    continue;
                }

                if !is_closing && !is_self_closing {
                    self.flush_buf(&mut buf, &mut spans, bold, italic, superscript, &href);
                    if name == "b" || name == "strong" {
                        bold = true;
                    } else if name == "i" || name == "em" {
                        italic = true;
                    } else if name == "sup" {
                        superscript = true;
                    } else if name == "a" {
                        if let Some(m) = self.href_re.captures(&lower) {
                            href = m.get(1).map(|v| v.as_str().to_string());
                        }
                    }
                    i = tag_end + 1;
                    continue;
                }

                if is_closing {
                    self.flush_buf(&mut buf, &mut spans, bold, italic, superscript, &href);
                    if name == "b" || name == "strong" {
                        bold = false;
                    } else if name == "i" || name == "em" {
                        italic = false;
                    } else if name == "sup" {
                        superscript = false;
                    } else if name == "a" {
                        href = None;
                    }
                    i = tag_end + 1;
                    continue;
                }

                if name == "br" || name == "br/" {
                    self.flush_buf(&mut buf, &mut spans, bold, italic, superscript, &href);
                    spans.push(RichSpan {
                        text: "\n".to_string(),
                        bold,
                        italic,
                        superscript,
                        href: href.clone(),
                    });
                    i = tag_end + 1;
                    continue;
                }

                buf.push_str(&tag);
                i = tag_end + 1;
            } else {
                let next_tag = chars[i..].iter().position(|&c| c == '<').map(|p| i + p);
                let next_tag = next_tag.unwrap_or(len);
                let text: String = chars[i..next_tag].iter().collect();
                buf.push_str(&text);
                i = next_tag;
            }
        }

        self.flush_buf(&mut buf, &mut spans, bold, italic, superscript, &href);
        spans
    }

    fn flush_buf(
        &self,
        buf: &mut String,
        spans: &mut Vec<RichSpan>,
        bold: bool,
        italic: bool,
        superscript: bool,
        href: &Option<String>,
    ) {
        if buf.is_empty() {
            return;
        }
        let normalized = buf.split_whitespace().collect::<Vec<_>>().join(" ");
        let t = self.decode_entities(&normalized).trim().to_string();
        if !t.is_empty() {
            spans.push(RichSpan {
                text: t,
                bold,
                italic,
                superscript,
                href: href.clone(),
            });
        }
        buf.clear();
    }

    fn extract_text_from_chunk(&self, chunk: &str) -> String {
        let plain = self.tag_re.replace_all(chunk, " ");
        let collapsed = plain.split_whitespace().collect::<Vec<_>>().join(" ");
        self.decode_entities(&collapsed)
    }

    fn strip_outer_block_tag(&self, chunk: &str) -> String {
        if let Some(m) = self.strip_outer_re.captures(chunk) {
            let tag_name = m.get(1).unwrap().as_str();
            let after_open = &chunk[m.get(0).unwrap().end()..];
            let close_tag = format!("</{}>", tag_name);
            if let Some(close_idx) = after_open.to_lowercase().rfind(&close_tag) {
                return after_open[..close_idx].to_string();
            }
            return after_open.to_string();
        }
        chunk.to_string()
    }

    fn spans_to_text(&self, spans: &[RichSpan]) -> String {
        let mut buf = String::new();
        for span in spans {
            buf.push_str(&span.text);
        }
        buf.trim().to_string()
    }

    fn decode_entities(&self, input: &str) -> String {
        let mut result = String::with_capacity(input.len());
        let mut chars = input.char_indices().peekable();

        while let Some((i, c)) = chars.next() {
            if c == '&' {
                // Find the semicolon
                if let Some(semi_pos) = input[i + 1..].find(';') {
                    let entity = &input[i + 1..i + 1 + semi_pos];
                    if let Some(&replacement) = self.entity_map.get(entity) {
                        result.push_str(replacement);
                        // Skip past the entity + semicolon
                        for _ in 0..=semi_pos {
                            chars.next();
                        }
                        continue;
                    } else if let Some(stripped) = entity.strip_prefix('#') {
                        if let Some(hex_digits) = stripped.strip_prefix('x') {
                            if let Ok(code) = u32::from_str_radix(hex_digits, 16) {
                                if let Some(c) = char::from_u32(code) {
                                    result.push(c);
                                    for _ in 0..=semi_pos {
                                        chars.next();
                                    }
                                    continue;
                                }
                            }
                        } else {
                            if let Ok(code) = stripped.parse::<u32>() {
                                if let Some(c) = char::from_u32(code) {
                                    result.push(c);
                                    for _ in 0..=semi_pos {
                                        chars.next();
                                    }
                                    continue;
                                }
                            }
                        }
                    }
                    // Unknown entity — keep as-is
                    result.push(c);
                    // We consumed one char above, push the rest up to semicolon
                    for j in i + 1..=i + 1 + semi_pos {
                        result.push(input.as_bytes()[j] as char);
                        chars.next();
                    }
                    continue;
                }
            }
            result.push(c);
        }

        result
    }
}

// ---------------------------------------------------------------------------
// ChapterChunk (internal)
// ---------------------------------------------------------------------------

struct ChapterChunk {
    title: String,
    blocks: Vec<ReaderBlock>,
}

// ---------------------------------------------------------------------------
// MobiChapterSplitter
// ---------------------------------------------------------------------------

struct MobiChapterSplitter {
    chapter_pattern_re: Regex,
    tag_re: Regex,
}

impl MobiChapterSplitter {
    fn new() -> Self {
        Self {
            chapter_pattern_re: Regex::new(
                r"(?i)(?:^|\n)\s*(?:(?:глава|часть|раздел|пролог|эпилог|предисловие|послесловие)\s*\d*|(?:chapter|part|section|prologue|epilogue|preface|afterword)\s*\d*)\s*(?:\n|$)",
            )
            .unwrap(),
            tag_re: Regex::new(r"<[^>]*>").unwrap(),
        }
    }

    fn split(&self, blocks: &[ReaderBlock]) -> Vec<ReaderChapter> {
        if blocks.is_empty() {
            return vec![ReaderChapter {
                index: 0,
                title: "Документ".to_string(),
                blocks: vec![ReaderBlock {
                    index: 0,
                    text: "Не удалось извлечь текст.".to_string(),
                    block_type: BlockType::Paragraph,
                    image_url: None,
                    note_ref: None,
                    rich_spans: None,
                }],
            }];
        }

        let chunks = self.split_blocks_into_chunks(blocks);
        if chunks.len() <= 1 {
            let title = if !chunks.is_empty() {
                chunks[0].title.clone()
            } else {
                "Документ".to_string()
            };
            return vec![ReaderChapter {
                index: 0,
                title,
                blocks: blocks.to_vec(),
            }];
        }

        chunks
            .into_iter()
            .enumerate()
            .map(|(i, chunk)| ReaderChapter {
                index: i as i32,
                title: chunk.title,
                blocks: chunk.blocks,
            })
            .collect()
    }

    fn split_blocks_into_chunks(&self, blocks: &[ReaderBlock]) -> Vec<ChapterChunk> {
        let mut breaks: Vec<usize> = Vec::new();
        let mut titles: HashMap<usize, String> = HashMap::new();

        for (i, block) in blocks.iter().enumerate() {
            match block.block_type {
                BlockType::Heading => {
                    breaks.push(i);
                    titles.insert(i, block.text.clone());
                }
                BlockType::Separator if i > 0 && i < blocks.len() - 1 => {
                    if !self.is_nearby_heading(blocks, i) {
                        breaks.push(i);
                    }
                }
                BlockType::Paragraph => {
                    let text = &block.text;
                    let test = format!("\n{}\n", text);
                    if self.chapter_pattern_re.is_match(&test) {
                        breaks.push(i);
                        titles.insert(i, text.clone());
                    }
                }
                _ => {}
            }
        }

        if breaks.is_empty() {
            return self.chunk_by_size(blocks);
        }

        if breaks[0] != 0 {
            breaks.insert(0, 0);
            titles.insert(0, "Документ".to_string());
        }

        if breaks.len() == 1 {
            let title = titles
                .get(&breaks[0])
                .cloned()
                .unwrap_or_else(|| "Документ".to_string());
            return vec![ChapterChunk {
                title: self.clean_title(&title),
                blocks: blocks.to_vec(),
            }];
        }

        let chunk_map: HashSet<usize> = breaks.iter().copied().collect();
        let mut chunks: Vec<ChapterChunk> = Vec::new();

        for (b, &brk) in breaks.iter().enumerate() {
            let start = brk;
            let end = if b + 1 < breaks.len() {
                breaks[b + 1]
            } else {
                blocks.len()
            };
            let chapter_blocks: Vec<ReaderBlock> = blocks[start..end]
                .iter()
                .filter(|bl| {
                    !(bl.block_type == BlockType::Separator
                        && chunk_map.contains(&(bl.index as usize)))
                })
                .cloned()
                .collect();
            if chapter_blocks.is_empty() {
                continue;
            }
            let title = titles
                .get(&brk)
                .cloned()
                .unwrap_or_else(|| format!("Часть {}", chunks.len() + 1));
            chunks.push(ChapterChunk {
                title: self.clean_title(&title),
                blocks: chapter_blocks,
            });
        }

        chunks
    }

    fn is_nearby_heading(&self, blocks: &[ReaderBlock], index: usize) -> bool {
        let start = index.saturating_sub(2);
        let end = std::cmp::min(index + 2, blocks.len() - 1);
        for block in blocks.iter().take(end + 1).skip(start) {
            if block.block_type == BlockType::Heading {
                return true;
            }
        }
        false
    }

    fn chunk_by_size(&self, blocks: &[ReaderBlock]) -> Vec<ChapterChunk> {
        const CHUNK_SIZE: usize = 80;
        let mut chunks: Vec<ChapterChunk> = Vec::new();
        let mut start = 0;
        while start < blocks.len() {
            let end = std::cmp::min(start + CHUNK_SIZE, blocks.len());
            chunks.push(ChapterChunk {
                title: format!("Часть {}", chunks.len() + 1),
                blocks: blocks[start..end].to_vec(),
            });
            start = end;
        }
        chunks
    }

    fn clean_title(&self, raw: &str) -> String {
        let stripped = self.tag_re.replace_all(raw, "");
        let mut title = stripped.trim().to_string();
        if title.len() > 80 {
            title.truncate(80);
            title.push('…');
        }
        if title.is_empty() {
            "Без названия".to_string()
        } else {
            title
        }
    }
}

// ---------------------------------------------------------------------------
// MobiCoverExtractor
// ---------------------------------------------------------------------------

struct MobiCoverExtractor;

impl MobiCoverExtractor {
    fn extract(
        &self,
        full_bytes: &[u8],
        palm_db: &PalmDb,
        header: &MobiHeader,
        metadata: &MobiMetadata,
    ) -> Option<Vec<u8>> {
        let record_index = self.find_cover_record_index(header, metadata)?;
        if record_index >= palm_db.records.len() {
            return None;
        }

        let bytes = self.safe_record_bytes(full_bytes, palm_db, record_index)?;
        if bytes.len() < 8 {
            return None;
        }

        self.validate_image_bytes(bytes)
    }

    fn find_cover_record_index(
        &self,
        header: &MobiHeader,
        metadata: &MobiMetadata,
    ) -> Option<usize> {
        if let Some(idx) = metadata.cover_record_index {
            if idx > 0 {
                return Some(idx as usize);
            }
        }
        if header.first_image_record_index > 0 {
            return Some(header.first_image_record_index as usize);
        }
        None
    }

    fn safe_record_bytes<'a>(
        &self,
        full_bytes: &'a [u8],
        palm_db: &PalmDb,
        index: usize,
    ) -> Option<&'a [u8]> {
        if index >= palm_db.records.len() {
            return None;
        }
        let start = palm_db.records[index].offset;
        let end = if index + 1 < palm_db.records.len() {
            palm_db.records[index + 1].offset
        } else {
            full_bytes.len()
        };
        if start >= end || end > full_bytes.len() {
            return None;
        }
        Some(&full_bytes[start..end])
    }

    fn validate_image_bytes(&self, bytes: &[u8]) -> Option<Vec<u8>> {
        if self.is_jpeg(bytes) || self.is_png(bytes) || self.is_gif(bytes) {
            Some(bytes.to_vec())
        } else {
            None
        }
    }

    fn is_jpeg(&self, bytes: &[u8]) -> bool {
        bytes.len() >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8
    }

    fn is_png(&self, bytes: &[u8]) -> bool {
        bytes.len() >= 4
            && bytes[0] == 0x89
            && bytes[1] == 0x50
            && bytes[2] == 0x4E
            && bytes[3] == 0x47
    }

    fn is_gif(&self, bytes: &[u8]) -> bool {
        bytes.len() >= 3 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46
    }
}

// ---------------------------------------------------------------------------
// PalmDocDecompressor
// ---------------------------------------------------------------------------

struct PalmDocDecompressor;

impl PalmDocDecompressor {
    fn decompress(&self, input: &[u8]) -> Result<Vec<u8>> {
        let mut out: Vec<u8> = Vec::with_capacity(input.len() * 3);
        let mut i = 0;

        while i < input.len() {
            if out.len() > MAX_DECOMPRESSED_RECORD_BYTES {
                bail!("MOBI record is too large after decompression");
            }
            let c = input[i];
            i += 1;

            if c == 0 {
                out.push(c);
            } else if c <= 8 {
                for _ in 0..c {
                    if i >= input.len() {
                        break;
                    }
                    out.push(input[i]);
                    i += 1;
                }
            } else if c <= 0x7F {
                out.push(c);
            } else if c <= 0xBF {
                if i >= input.len() {
                    break;
                }
                let c2 = input[i];
                i += 1;
                let distance = (((c & 0x3F) as usize) << 5) | ((c2 >> 3) as usize);
                let length = ((c2 & 0x07) as usize) + 3;
                let start = out.len().checked_sub(distance);
                let start = match start {
                    Some(s) => s,
                    None => bail!("Invalid PalmDOC back reference"),
                };
                for j in 0..length {
                    let ch = out[start + j];
                    out.push(ch);
                }
            } else {
                out.push(0x20);
                out.push(c ^ 0x80);
            }
        }

        Ok(out)
    }
}

// ---------------------------------------------------------------------------
// MobiTextExtractor
// ---------------------------------------------------------------------------

struct MobiTextExtractor {
    html_parser: MobiHtmlParser,
}

impl MobiTextExtractor {
    fn new() -> Self {
        Self {
            html_parser: MobiHtmlParser::new(),
        }
    }

    fn extract_text(
        &self,
        full_bytes: &[u8],
        palm_db: &PalmDb,
        header: &MobiHeader,
    ) -> Result<String> {
        if header.compression != 1 && header.compression != 2 {
            bail!("Unsupported MOBI compression: {}", header.compression);
        }
        if header.text_record_count == 0
            || (header.text_record_count as usize) >= palm_db.records.len()
        {
            bail!("Invalid MOBI text record count");
        }

        let mut chunks: Vec<u8> = Vec::new();
        let decompressor = PalmDocDecompressor;

        for i in 1..=header.text_record_count as usize {
            let record = record_bytes(full_bytes, palm_db, i)?;
            let decompressed = if header.compression == 1 {
                record.to_vec()
            } else {
                decompressor.decompress(record)?
            };
            chunks.extend_from_slice(&decompressed);
            if chunks.len() > MAX_TOTAL_TEXT_BYTES {
                bail!("MOBI text stream is too large");
            }
        }

        Ok(self.decode_text(&chunks, header.text_encoding))
    }

    fn extract_blocks(
        &self,
        full_bytes: &[u8],
        palm_db: &PalmDb,
        header: &MobiHeader,
    ) -> Result<Vec<ReaderBlock>> {
        let text = self.extract_text(full_bytes, palm_db, header)?;
        if self.looks_like_html(&text) {
            Ok(self.html_parser.parse(&text))
        } else {
            Ok(self.plain_text_to_blocks(&text))
        }
    }

    fn looks_like_html(&self, text: &str) -> bool {
        let sample_len = std::cmp::min(text.len(), 2000);
        let sample = &text[..sample_len];
        sample.contains("<p")
            || sample.contains("<h")
            || sample.contains("<br")
            || sample.contains("<div")
            || sample.contains("<b>")
            || sample.contains("<i>")
    }

    fn plain_text_to_blocks(&self, text: &str) -> Vec<ReaderBlock> {
        let mut blocks: Vec<ReaderBlock> = Vec::new();
        let mut idx = 0i32;
        for line in text.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() {
                continue;
            }
            blocks.push(ReaderBlock {
                index: idx,
                text: trimmed.to_string(),
                block_type: BlockType::Paragraph,
                image_url: None,
                note_ref: None,
                rich_spans: None,
            });
            idx += 1;
        }
        if blocks.is_empty() && !text.trim().is_empty() {
            blocks.push(ReaderBlock {
                index: 0,
                text: text.trim().to_string(),
                block_type: BlockType::Paragraph,
                image_url: None,
                note_ref: None,
                rich_spans: None,
            });
        }
        blocks
    }

    fn decode_text(&self, bytes: &[u8], text_encoding: u16) -> String {
        // textEncoding values: 1252 = Windows-1252, 65001 = UTF-8, 65002 = UTF-16
        if text_encoding == 65001 {
            return String::from_utf8_lossy(bytes).into_owned();
        }
        if text_encoding == 65002 {
            return self.decode_utf16(bytes);
        }
        if text_encoding == 1252 {
            let (decoded, _, _) = encoding_rs::WINDOWS_1252.decode(bytes);
            return decoded.into_owned();
        }
        // Fallback: try UTF-8, fall back to latin1 if too many replacement chars.
        let utf8_text = String::from_utf8_lossy(bytes).into_owned();
        let replacement_count = utf8_text.matches('\u{FFFD}').count();
        if (replacement_count as f64) < (bytes.len() as f64 * 0.02) {
            return utf8_text;
        }
        let (decoded, _, _) = encoding_rs::WINDOWS_1252.decode(bytes);
        decoded.into_owned()
    }

    fn decode_utf16(&self, bytes: &[u8]) -> String {
        if bytes.len() >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE {
            return String::from_utf8_lossy(&bytes[2..]).into_owned();
        }
        if bytes.len() >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF {
            return String::from_utf8_lossy(&bytes[2..]).into_owned();
        }
        // No BOM — try LE first (most common on Windows-originated files).
        let mut buf = String::with_capacity(bytes.len() / 2);
        let mut i = 0;
        while i + 1 < bytes.len() {
            let code = (bytes[i] as u32) | ((bytes[i + 1] as u32) << 8);
            if let Some(c) = char::from_u32(code) {
                buf.push(c);
            }
            i += 2;
        }
        buf
    }
}

// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------

fn record_bytes<'a>(full_bytes: &'a [u8], palm_db: &PalmDb, index: usize) -> Result<&'a [u8]> {
    if index >= palm_db.records.len() {
        bail!("Record index {} out of range", index);
    }
    let start = palm_db.records[index].offset;
    let end = if index + 1 < palm_db.records.len() {
        palm_db.records[index + 1].offset
    } else {
        full_bytes.len()
    };
    if start > end || end > full_bytes.len() {
        bail!("Invalid record byte range: {}..{}", start, end);
    }
    Ok(&full_bytes[start..end])
}

fn full_name(record0: &[u8], header: &MobiHeader) -> Option<String> {
    if header.full_name_length == 0 {
        return None;
    }
    let end = header.full_name_offset as usize + header.full_name_length as usize;
    if header.full_name_offset as usize >= record0.len() || end > record0.len() {
        return None;
    }
    let name = String::from_utf8_lossy(&record0[header.full_name_offset as usize..end])
        .trim()
        .to_string();
    if name.is_empty() {
        None
    } else {
        Some(name)
    }
}

fn first_non_empty(values: &[Option<&str>]) -> String {
    for s in values.iter().flatten() {
        let trimmed = s.trim();
        if !trimmed.is_empty() {
            return trimmed.to_string();
        }
    }
    "MOBI document".to_string()
}

fn split_authors(value: Option<&str>) -> Vec<String> {
    let val = match value {
        Some(v) => v.trim(),
        None => return Vec::new(),
    };
    if val.is_empty() {
        return Vec::new();
    }
    let re = Regex::new(r#"(?i)\s*(?:;|,|and|&)\s*"#).unwrap();
    re.split(val)
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect()
}

fn stable_id(file_name: Option<&str>, bytes: &[u8]) -> String {
    use sha2::{Digest, Sha256};
    let take_len = std::cmp::min(bytes.len(), 1024 * 1024);
    let mut hasher = Sha256::new();
    hasher.update(&bytes[..take_len]);
    let digest = format!("{:x}", hasher.finalize());
    let prefix = strip_extension(file_name).unwrap_or_else(|| "mobi".to_string());
    format!("{}_{}", prefix, digest)
}

fn strip_extension(file_name: Option<&str>) -> Option<String> {
    let name = file_name?;
    if name.is_empty() {
        return None;
    }
    let normalized = name
        .rsplit('/')
        .next()
        .unwrap_or(name)
        .rsplit('\\')
        .next()
        .unwrap_or(name);
    let dot = normalized.rfind('.');
    Some(if let Some(d) = dot {
        normalized[..d].to_string()
    } else {
        normalized.to_string()
    })
}

fn description_for(header: &MobiHeader) -> String {
    if header.compression == 17480 {
        "MOBI/AZW3 document: Huff/CDIC compression is not supported yet".to_string()
    } else {
        "MOBI document".to_string()
    }
}

fn is_likely_kf8(header: &MobiHeader, record0: &[u8]) -> bool {
    let _ = header;
    let (text, _, _) = encoding_rs::WINDOWS_1252.decode(record0);
    text.contains("BOUNDARY") || text.contains("FDST") || text.contains("RESC")
}

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

pub fn parse_mobi(bytes: &[u8], _forced_encoding: Option<&str>) -> Result<NormalizedBook> {
    if bytes.len() < 86 {
        bail!("File is too small for PalmDB/MOBI");
    }

    let palm_db = PalmDbParser.parse(bytes)?;
    let record0 = record_bytes(bytes, &palm_db, 0)?;
    let header = MobiHeaderParser.parse(record0)?;
    let metadata = ExthParser.parse(record0, &header);

    let text_extractor = MobiTextExtractor::new();
    let blocks = text_extractor.extract_blocks(bytes, &palm_db, &header)?;

    let title = first_non_empty(&[
        metadata.title.as_deref(),
        full_name(record0, &header).as_deref(),
        Some(&palm_db.name),
        None, // fileName not available here
    ]);

    let authors = split_authors(metadata.author.as_deref());

    let chapters = MobiChapterSplitter::new().split(&blocks);

    let cover_extractor = MobiCoverExtractor;
    let cover_bytes = cover_extractor.extract(bytes, &palm_db, &header, &metadata);

    let mut meta = serde_json::Map::new();
    meta.insert(
        "format".to_string(),
        serde_json::Value::String("mobi".to_string()),
    );
    meta.insert(
        "mobiCompression".to_string(),
        serde_json::json!(header.compression),
    );
    meta.insert(
        "mobiTextRecordCount".to_string(),
        serde_json::json!(header.text_record_count),
    );
    meta.insert(
        "mobiRecordCount".to_string(),
        serde_json::json!(palm_db.records.len()),
    );
    meta.insert(
        "mobiExthPresent".to_string(),
        serde_json::json!(metadata.has_exth),
    );
    if let Some(ref lang) = metadata.language {
        meta.insert(
            "mobiLanguage".to_string(),
            serde_json::Value::String(lang.clone()),
        );
    }
    meta.insert(
        "mobiFirstImageRecordIndex".to_string(),
        serde_json::json!(header.first_image_record_index),
    );
    meta.insert(
        "mobiKf8Likely".to_string(),
        serde_json::json!(is_likely_kf8(&header, record0)),
    );
    if let Some(ref cover) = cover_bytes {
        meta.insert("mobiCoverBytes".to_string(), serde_json::json!(cover.len()));
    }
    if let Some(idx) = metadata.cover_record_index {
        meta.insert("mobiCoverRecordIndex".to_string(), serde_json::json!(idx));
    }

    Ok(NormalizedBook {
        id: stable_id(None, bytes),
        title,
        authors: if authors.is_empty() {
            vec!["Unknown".to_string()]
        } else {
            authors
        },
        description: Some(description_for(&header)),
        cover_url: None,
        chapters,
        metadata: Some(serde_json::Value::Object(meta)),
    })
}
