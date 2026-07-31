use std::collections::{HashMap, HashSet};
use std::sync::LazyLock;

use regex::Regex;

use crate::api::models::{BlockType, ReaderBlock, RichSpan};

use super::TAG_RE;

static TAG_NAME_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)^<?/?([a-zA-Z][a-zA-Z0-9]*)").unwrap());
static STRIP_OUTER_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)^<(p|div|blockquote|pre|section|article)[^>]*>").unwrap());
static HREF_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)\bhref\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s>]+))"#).unwrap()
});
static IMG_TAG_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"(?is)<img\b[^>]*>").unwrap());
static RECINDEX_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?i)\brecindex\s*=\s*(?:\"(\d+)\"|'(\d+)'|(\d+))"#).unwrap());
static ALT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)\balt\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s>]+))"#).unwrap()
});

enum MobiHtmlChunk {
    Text(String),
    Image { recindex: u32, alt: Option<String> },
}

pub(crate) struct MobiHtmlParser {
    block_elements: HashSet<&'static str>,
    void_elements: HashSet<&'static str>,
    entity_map: HashMap<&'static str, &'static str>,
}

impl MobiHtmlParser {
    pub fn new() -> Self {
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
        }
    }

    pub fn parse(&self, html: &str) -> Vec<ReaderBlock> {
        let clean = self.strip_mbp_and_comments(html);
        let block_chunks = self.split_into_block_chunks(&clean);
        let mut blocks: Vec<ReaderBlock> = Vec::new();
        let mut idx = 0i32;

        for chunk in &block_chunks {
            for chunk in self.split_inline_images(chunk) {
                let MobiHtmlChunk::Text(chunk) = chunk else {
                    let MobiHtmlChunk::Image { recindex, alt } = chunk else {
                        unreachable!("MobiHtmlChunk has only text and image variants");
                    };
                    blocks.push(ReaderBlock {
                        index: idx,
                        text: alt.clone().unwrap_or_default(),
                        block_type: BlockType::Image,
                        image_url: Some(format!("mobi-recindex:{recindex}")),
                        note_ref: None,
                        rich_spans: None,
                        heading_level: None,
                        ordered: None,
                        list_items: None,
                        table_rows: None,
                        image_alt: alt,
                        text_indent: None,
                        text_align: None,
                        note_id: None,
                        page_break_before: false,
                        page_break_inside_avoid: false,
                    });
                    idx += 1;
                    continue;
                };
                let trimmed = chunk.trim();
                if trimmed.is_empty() {
                    continue;
                }

                let lower = trimmed.to_lowercase();
                if self.is_heading(&lower) {
                    let text = self.extract_text_from_chunk(trimmed);
                    if !text.is_empty() {
                        let level = self.extract_heading_level(&lower);
                        blocks.push(ReaderBlock {
                            index: idx,
                            text,
                            block_type: BlockType::Heading,
                            image_url: None,
                            note_ref: None,
                            rich_spans: Some(self.parse_inline(trimmed)),
                            heading_level: Some(level),
                            ordered: None,
                            list_items: None,
                            table_rows: None,
                            image_alt: None,
                            text_indent: None,
                            text_align: None,
                            note_id: None,
                            page_break_before: false,
                            page_break_inside_avoid: false,
                        });
                        idx += 1;
                    }
                } else if lower.starts_with("<hr") || lower.starts_with("<hr/>") || lower == "<hr>"
                {
                    blocks.push(ReaderBlock {
                        index: idx,
                        text: String::new(),
                        block_type: BlockType::Separator,
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
                        page_break_before: false,
                        page_break_inside_avoid: false,
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
                            heading_level: None,
                            ordered: None,
                            list_items: None,
                            table_rows: None,
                            image_alt: None,
                            text_indent: None,
                            text_align: None,
                            note_id: None,
                            page_break_before: false,
                            page_break_inside_avoid: false,
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
                            heading_level: None,
                            ordered: None,
                            list_items: None,
                            table_rows: None,
                            image_alt: None,
                            text_indent: None,
                            text_align: None,
                            note_id: None,
                            page_break_before: false,
                            page_break_inside_avoid: false,
                        });
                        idx += 1;
                    }
                }
            }
        }

        if blocks.is_empty() {
            let stripped = TAG_RE.replace_all(html, " ");
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
                    heading_level: None,
                    ordered: None,
                    list_items: None,
                    table_rows: None,
                    image_alt: None,
                    text_indent: None,
                    text_align: None,
                    note_id: None,
                    page_break_before: false,
                    page_break_inside_avoid: false,
                });
            }
        }

        blocks
    }

    fn split_inline_images(&self, chunk: &str) -> Vec<MobiHtmlChunk> {
        let mut chunks = Vec::new();
        let mut cursor = 0;

        for tag in IMG_TAG_RE.find_iter(chunk) {
            if tag.start() > cursor {
                chunks.push(MobiHtmlChunk::Text(chunk[cursor..tag.start()].to_string()));
            }
            let recindex = RECINDEX_RE
                .captures(tag.as_str())
                .and_then(|captures| {
                    (1..=3)
                        .find_map(|index| captures.get(index))
                        .and_then(|value| value.as_str().parse::<u32>().ok())
                })
                .filter(|index| *index > 0);
            if let Some(recindex) = recindex {
                let alt = ALT_RE
                    .captures(tag.as_str())
                    .and_then(|captures| (1..=3).find_map(|index| captures.get(index)))
                    .map(|value| self.decode_entities(value.as_str()));
                chunks.push(MobiHtmlChunk::Image { recindex, alt });
            } else {
                chunks.push(MobiHtmlChunk::Text(tag.as_str().to_string()));
            }
            cursor = tag.end();
        }

        if cursor < chunk.len() {
            chunks.push(MobiHtmlChunk::Text(chunk[cursor..].to_string()));
        }
        chunks
    }

    fn strip_mbp_and_comments(&self, html: &str) -> String {
        let mut result = String::with_capacity(html.len());
        let mut i = 0;
        let bytes = html.as_bytes();
        let len = bytes.len();

        while i < len {
            if bytes[i] == b'<' {
                // Check for mbp: tag
                if i + 5 < len && bytes[i + 1..i + 5].eq_ignore_ascii_case(b"mbp:") {
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
            let Some(character) = html[i..].chars().next() else {
                break;
            };
            result.push(character);
            i += character.len_utf8();
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
                let name_match = TAG_NAME_RE.captures(&lower);
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
                        let close_char_idx = remaining[..close_idx].chars().count();
                        let inner: String = chars[i..i + close_char_idx].iter().collect();
                        buf.push_str(&inner);
                        i = i + close_char_idx + close_tag.chars().count();
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
                        let close_char_idx = remaining[..close_idx].chars().count();
                        let inner: String = chars[i..i + close_char_idx].iter().collect();
                        buf.push_str(&inner);
                        i = i + close_char_idx + 4;
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
                        let close_char_idx = remaining[..close_idx].chars().count();
                        let inner: String = chars[i..i + close_char_idx].iter().collect();
                        let sub_chunks = self.split_into_block_chunks(&inner);
                        result.extend(sub_chunks);
                        i = i + close_char_idx + 6;
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

    fn extract_heading_level(&self, lower: &str) -> i32 {
        if lower.starts_with("<h1") {
            1
        } else if lower.starts_with("<h2") {
            2
        } else if lower.starts_with("<h3") {
            3
        } else if lower.starts_with("<h4") {
            4
        } else if lower.starts_with("<h5") {
            5
        } else if lower.starts_with("<h6") {
            6
        } else {
            1
        }
    }

    fn is_blockquote(&self, lower: &str) -> bool {
        lower.starts_with("<blockquote")
    }

    fn parse_inline(&self, chunk: &str) -> Vec<RichSpan> {
        let mut spans: Vec<RichSpan> = Vec::new();
        let mut buf = String::new();
        let mut bold_depth = 0u32;
        let mut italic_depth = 0u32;
        let mut superscript_depth = 0u32;
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
                let name_match = TAG_NAME_RE.captures(&lower);
                let name = name_match
                    .as_ref()
                    .and_then(|m| m.get(1))
                    .map(|m| m.as_str())
                    .unwrap_or("");
                let is_closing = tag.len() > 1 && chars[i + 1] == '/';
                let is_self_closing = tag.ends_with("/>") || self.void_elements.contains(name);

                if !is_closing && !is_self_closing && self.block_elements.contains(name) {
                    self.flush_buf(
                        &mut buf,
                        &mut spans,
                        bold_depth > 0,
                        italic_depth > 0,
                        superscript_depth > 0,
                        &href,
                    );
                    i = tag_end + 1;
                    continue;
                }

                if !is_closing && !is_self_closing {
                    self.flush_buf(
                        &mut buf,
                        &mut spans,
                        bold_depth > 0,
                        italic_depth > 0,
                        superscript_depth > 0,
                        &href,
                    );
                    if name == "b" || name == "strong" {
                        bold_depth = bold_depth.saturating_add(1);
                    } else if name == "i" || name == "em" {
                        italic_depth = italic_depth.saturating_add(1);
                    } else if name == "sup" {
                        superscript_depth = superscript_depth.saturating_add(1);
                    } else if name == "a" {
                        if let Some(captures) = HREF_RE.captures(&tag) {
                            href = (1..=3)
                                .find_map(|index| captures.get(index))
                                .and_then(|value| crate::book::sanitize_href(value.as_str()));
                        }
                    }
                    i = tag_end + 1;
                    continue;
                }

                if is_closing {
                    self.flush_buf(
                        &mut buf,
                        &mut spans,
                        bold_depth > 0,
                        italic_depth > 0,
                        superscript_depth > 0,
                        &href,
                    );
                    if name == "b" || name == "strong" {
                        bold_depth = bold_depth.saturating_sub(1);
                    } else if name == "i" || name == "em" {
                        italic_depth = italic_depth.saturating_sub(1);
                    } else if name == "sup" {
                        superscript_depth = superscript_depth.saturating_sub(1);
                    } else if name == "a" {
                        href = None;
                    }
                    i = tag_end + 1;
                    continue;
                }

                if name == "br" || name == "br/" {
                    self.flush_buf(
                        &mut buf,
                        &mut spans,
                        bold_depth > 0,
                        italic_depth > 0,
                        superscript_depth > 0,
                        &href,
                    );
                    spans.push(RichSpan {
                        text: "\n".to_string(),
                        bold: bold_depth > 0,
                        italic: italic_depth > 0,
                        superscript: superscript_depth > 0,
                        subscript: false,
                        strikethrough: false,
                        code: false,
                        style_name: None,
                        href: href.clone(),
                        line_break: true,
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

        self.flush_buf(
            &mut buf,
            &mut spans,
            bold_depth > 0,
            italic_depth > 0,
            superscript_depth > 0,
            &href,
        );
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
                subscript: false,
                strikethrough: false,
                code: false,
                style_name: None,
                href: href.clone(),
                line_break: false,
            });
        }
        buf.clear();
    }

    fn extract_text_from_chunk(&self, chunk: &str) -> String {
        let plain = TAG_RE.replace_all(chunk, " ");
        let collapsed = plain.split_whitespace().collect::<Vec<_>>().join(" ");
        self.decode_entities(&collapsed)
    }

    fn strip_outer_block_tag(&self, chunk: &str) -> String {
        if let Some(m) = STRIP_OUTER_RE.captures(chunk) {
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
                    let entity_end = i + 2 + semi_pos;
                    let literal = &input[i..entity_end];
                    result.push_str(literal);
                    // `&` was consumed by the iterator; consume the remaining
                    // characters of the literal entity without treating byte
                    // offsets as character counts.
                    for _ in literal['&'.len_utf8()..].chars() {
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

#[cfg(test)]
mod tests {
    use super::MobiHtmlParser;

    #[test]
    fn strips_dangerous_link_schemes_from_rich_spans() {
        let blocks =
            MobiHtmlParser::new().parse(r#"<p><a href="javascript:alert(1)">Read</a></p>"#);

        let span = &blocks[0].rich_spans.as_ref().expect("rich span")[0];
        assert_eq!(span.text, "Read");
        assert!(span.href.is_none());
    }

    #[test]
    fn preserves_single_quoted_link_targets() {
        let blocks = MobiHtmlParser::new().parse("<p><a href='chapter-2.html'>Next</a></p>");

        let span = &blocks[0].rich_spans.as_ref().expect("rich span")[0];
        assert_eq!(span.href.as_deref(), Some("chapter-2.html"));
    }

    #[test]
    fn preserves_utf8_text_while_removing_mobi_metadata_tags() {
        let blocks = MobiHtmlParser::new().parse("<mbp:pagebreak/><p>Привет, мир!</p>");

        assert_eq!(blocks[0].text, "Привет, мир!");
    }

    #[test]
    fn preserves_outer_formatting_after_a_nested_equivalent_tag_closes() {
        let blocks = MobiHtmlParser::new().parse("<p><b>Outer <strong>inner</strong> tail</b></p>");
        let spans = blocks[0].rich_spans.as_ref().expect("rich spans");

        assert_eq!(spans[2].text, "tail");
        assert!(spans[2].bold);
    }

    #[test]
    fn preserves_unknown_entities_with_unicode_content() {
        let blocks = MobiHtmlParser::new().parse("<p>До &неизвестно; после</p>");

        assert_eq!(blocks[0].text, "До &неизвестно; после");
    }

    #[test]
    fn strips_uppercase_mobi_pagebreak_tags() {
        let blocks = MobiHtmlParser::new().parse("<MBP:pagebreak/><p>Next page</p>");

        assert_eq!(blocks.len(), 1);
        assert_eq!(blocks[0].text, "Next page");
    }
}
