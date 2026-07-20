use crate::api::models::{BlockType, ReaderBlock, RichSpan};
use scraper::{ElementRef, Html, Selector};
use smallvec::SmallVec;

/// Parse HTML content into ReaderBlocks using html5ever + scraper.
///
/// Uses the spec-compliant HTML5 parser from Servo, correctly handling
/// malformed HTML, self-closing tags, and Unicode.
///
/// ponytail: supports p, h1-h6, blockquote, ul, ol, li, img, pre, div, hr.
/// No table support. Add when EPUB tables appear in test corpus.
#[allow(dead_code)]
pub(crate) fn html_to_blocks(text: &str, block_offset: i32) -> (Vec<ReaderBlock>, i32) {
    let document = Html::parse_document(text);
    let mut blocks: Vec<ReaderBlock> = Vec::new();
    let mut next_index = block_offset;

    let body_sel = Selector::parse("body").unwrap();
    if let Some(body) = document.select(&body_sel).next() {
        walk_children(body, &mut blocks, &mut next_index, 0, false);
    }

    (blocks, next_index)
}

fn emit_block(
    blocks: &mut Vec<ReaderBlock>,
    index: &mut i32,
    text: String,
    block_type: BlockType,
    heading_level: Option<i32>,
    rich_spans: Option<Vec<RichSpan>>,
    text_align: Option<String>,
) {
    blocks.push(ReaderBlock {
        index: *index,
        text,
        block_type,
        image_url: None,
        note_ref: None,
        rich_spans,
        heading_level,
        ordered: None,
        list_items: None,
        table_rows: None,
        image_alt: None,
        text_indent: None,
        text_align,
        note_id: None,
    });
    *index += 1;
}

fn walk_children(
    parent: ElementRef<'_>,
    blocks: &mut Vec<ReaderBlock>,
    index: &mut i32,
    blockquote_depth: i32,
    in_list: bool,
) {
    for el in parent.child_elements() {
        let tag: &str = el.value().name();
        match tag {
            "p" | "div" if !in_list => {
                let text = collect_text(el);
                if !text.is_empty() {
                    let rich = collect_rich_spans(el);
                    let bt = if blockquote_depth > 0 {
                        BlockType::Quote
                    } else {
                        BlockType::Paragraph
                    };
                    let rich = if rich.is_empty() || (rich.len() == 1 && rich[0].text == text) {
                        None
                    } else {
                        Some(rich.into_vec())
                    };
                    emit_block(blocks, index, text, bt, None, rich, None);
                }
            }
            h_tag if is_heading(h_tag) && !in_list => {
                let level = h_tag.as_bytes().get(1).map(|d| (d - b'0') as i32);
                let text = collect_text(el);
                if !text.is_empty() {
                    emit_block(blocks, index, text, BlockType::Heading, level, None, None);
                }
            }
            "blockquote" if !in_list => {
                walk_children(el, blocks, index, blockquote_depth + 1, false);
            }
            "ul" | "ol" => {
                let items: Vec<String> = el
                    .child_elements()
                    .filter(|c| c.value().name() == "li")
                    .map(collect_text)
                    .collect();
                if !items.is_empty() {
                    let ordered = tag == "ol";
                    let items_blocks: Vec<ReaderBlock> = items
                        .iter()
                        .map(|s| ReaderBlock {
                            index: 0,
                            text: s.clone(),
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
                        })
                        .collect();
                    blocks.push(ReaderBlock {
                        index: *index,
                        text: items.join(" | "),
                        block_type: BlockType::List,
                        image_url: None,
                        note_ref: None,
                        rich_spans: None,
                        heading_level: None,
                        ordered: Some(ordered),
                        list_items: Some(items_blocks),
                        table_rows: None,
                        image_alt: None,
                        text_indent: None,
                        text_align: None,
                        note_id: None,
                    });
                    *index += 1;
                }
            }
            "img" => {
                let src = el.attr("src").unwrap_or("").to_string();
                let alt = el.attr("alt").unwrap_or("").to_string();
                if !src.is_empty() {
                    blocks.push(ReaderBlock {
                        index: *index,
                        text: alt.clone(),
                        block_type: BlockType::Image,
                        image_url: Some(src),
                        note_ref: None,
                        rich_spans: None,
                        heading_level: None,
                        ordered: None,
                        list_items: None,
                        table_rows: None,
                        image_alt: if alt.is_empty() { None } else { Some(alt) },
                        text_indent: None,
                        text_align: None,
                        note_id: None,
                    });
                    *index += 1;
                }
            }
            "pre" if !in_list => {
                let text = collect_text(el);
                if !text.is_empty() {
                    emit_block(
                        blocks,
                        index,
                        text,
                        BlockType::Paragraph,
                        None,
                        None,
                        Some("ws:pre".to_string()),
                    );
                }
            }
            "hr" => {
                emit_block(
                    blocks,
                    index,
                    String::new(),
                    BlockType::Separator,
                    None,
                    None,
                    None,
                );
            }
            "head" | "script" | "style" | "noscript" => {
                // skip non-content elements entirely
            }
            _ => {
                walk_children(el, blocks, index, blockquote_depth, in_list);
            }
        }
    }
}

/// Collect text from all descendant text nodes; insert \n on <br>.
fn collect_text(el: ElementRef<'_>) -> String {
    let mut text = String::new();
    for node in el.descendants() {
        if let Some(t) = node.value().as_text() {
            text.push_str(t);
        } else if let Some(br) = ElementRef::wrap(node) {
            if br.value().name() == "br" {
                text.push('\n');
            }
        }
    }
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return String::new();
    }
    crate::book::normalize_typography(trimmed)
}

/// Collect inline formatting (b, i, sup, a) from direct children only.
/// ponytail: SmallVec avoids heap allocation for common 1-2 span case.
fn collect_rich_spans(el: ElementRef<'_>) -> SmallVec<[RichSpan; 4]> {
    let mut spans = SmallVec::new();
    for child in el.children() {
        if let Some(t) = child.value().as_text() {
            let text = t.trim();
            if !text.is_empty() {
                spans.push(RichSpan {
                    text: crate::book::normalize_typography(text),
                    bold: false,
                    italic: false,
                    superscript: false,
                    subscript: false,
                    strikethrough: false,
                    code: false,
                    style_name: None,
                    href: None,
                    line_break: false,
                });
            }
        } else if let Some(sub) = ElementRef::wrap(child) {
            let tag = sub.value().name();
            let t = collect_text(sub);
            if t.is_empty() {
                continue;
            }
            match tag {
                "b" | "strong" => spans.push(RichSpan {
                    text: t,
                    bold: true,
                    italic: false,
                    superscript: false,
                    subscript: false,
                    strikethrough: false,
                    code: false,
                    style_name: None,
                    href: None,
                    line_break: false,
                }),
                "i" | "em" | "cite" => spans.push(RichSpan {
                    text: t,
                    bold: false,
                    italic: true,
                    superscript: false,
                    subscript: false,
                    strikethrough: false,
                    code: false,
                    style_name: None,
                    href: None,
                    line_break: false,
                }),
                "sup" => spans.push(RichSpan {
                    text: t,
                    bold: false,
                    italic: false,
                    superscript: true,
                    subscript: false,
                    strikethrough: false,
                    code: false,
                    style_name: None,
                    href: None,
                    line_break: false,
                }),
                "a" => {
                    let href = sub.attr("href").and_then(crate::book::sanitize_href);
                    spans.push(RichSpan {
                        text: t,
                        bold: false,
                        italic: false,
                        superscript: false,
                        subscript: false,
                        strikethrough: false,
                        code: false,
                        style_name: None,
                        href,
                        line_break: false,
                    });
                }
                "br" => spans.push(RichSpan {
                    text: String::new(),
                    bold: false,
                    italic: false,
                    superscript: false,
                    subscript: false,
                    strikethrough: false,
                    code: false,
                    style_name: None,
                    href: None,
                    line_break: true,
                }),
                _ => spans.push(RichSpan {
                    text: t,
                    bold: false,
                    italic: false,
                    superscript: false,
                    subscript: false,
                    strikethrough: false,
                    code: false,
                    style_name: None,
                    href: None,
                    line_break: false,
                }),
            }
        }
    }
    spans
}

fn is_heading(tag: &str) -> bool {
    tag.len() == 2 && tag.starts_with('h') && tag.as_bytes().get(1).is_some_and(u8::is_ascii_digit)
}
