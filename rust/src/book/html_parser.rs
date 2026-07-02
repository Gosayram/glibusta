use crate::api::models::{BlockType, ReaderBlock, RichSpan};
use scraper::{Element, ElementRef, Html};

/// Parse HTML content into ReaderBlocks using html5ever + scraper.
///
/// Unlike the streaming quick-xml parser in epub.rs, this uses the
/// spec-compliant HTML5 parser from Servo, correctly handling
/// malformed HTML, self-closing tags, and Unicode.
///
/// ponytail: supports p, h1-h6, blockquote, ul, ol, li, img, pre, div.
/// No table support — EPUB tables are rare. Add when needed.
#[allow(dead_code)]
pub(crate) fn html_to_blocks(text: &str, block_offset: i32) -> (Vec<ReaderBlock>, i32) {
    let document = Html::parse_document(text);
    let mut blocks: Vec<ReaderBlock> = Vec::new();
    let mut next_index = block_offset;

    if let Some(body) = document.root_element().first_element_child() {
        walk_children(body, &mut blocks, &mut next_index, 0, false);
    }

    (blocks, next_index)
}

fn walk_children(
    parent: ElementRef<'_>,
    blocks: &mut Vec<ReaderBlock>,
    index: &mut i32,
    blockquote_depth: i32,
    in_list: bool,
) {
    for child in parent.children() {
        if let Some(el) = ElementRef::wrap(child) {
            let tag = el.value().name.local.as_ref();
            match tag {
                "p" | "div" if !in_list => {
                    let text = collect_text(el);
                    if !text.trim().is_empty() {
                        let rich = collect_rich_spans(el);
                        blocks.push(ReaderBlock {
                            index: *index,
                            text: text.trim().to_string(),
                            block_type: if blockquote_depth > 0 {
                                BlockType::Quote
                            } else {
                                BlockType::Paragraph
                            },
                            image_url: None,
                            note_ref: None,
                            rich_spans: if rich.is_empty() { None } else { Some(rich) },
                            heading_level: None,
                            ordered: None,
                            list_items: None,
                            table_rows: None,
                            image_alt: None,
                            text_indent: None,
                            text_align: None,
                            note_id: None,
                        });
                        *index += 1;
                    }
                }
                h_tag if is_heading(h_tag) && !in_list => {
                    let level = h_tag.as_bytes().get(1).map(|d| (d - b'0') as i32);
                    let text = collect_text(el);
                    if !text.trim().is_empty() {
                        blocks.push(ReaderBlock {
                            index: *index,
                            text: text.trim().to_string(),
                            block_type: BlockType::Heading,
                            image_url: None,
                            note_ref: None,
                            rich_spans: None,
                            heading_level: level,
                            ordered: None,
                            list_items: None,
                            table_rows: None,
                            image_alt: None,
                            text_indent: None,
                            text_align: None,
                            note_id: None,
                        });
                        *index += 1;
                    }
                }
                "blockquote" if !in_list => {
                    walk_children(el, blocks, index, blockquote_depth + 1, false);
                }
                "ul" | "ol" => {
                    let ordered = tag == "ol";
                    let items = collect_list_items(el);
                    if !items.is_empty() {
                        let text = items.join(" | ");
                        blocks.push(ReaderBlock {
                            index: *index,
                            text,
                            block_type: BlockType::List,
                            image_url: None,
                            note_ref: None,
                            rich_spans: None,
                            heading_level: None,
                            ordered: Some(ordered),
                            list_items: Some(
                                items
                                    .into_iter()
                                    .map(|s| ReaderBlock {
                                        index: 0,
                                        text: s,
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
                                    .collect(),
                            ),
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
                    let src = el.value().attr("src").unwrap_or("").to_string();
                    let alt = el.value().attr("alt").unwrap_or("").to_string();
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
                    if !text.trim().is_empty() {
                        blocks.push(ReaderBlock {
                            index: *index,
                            text: text.to_string(),
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
                            text_align: Some("ws:pre".to_string()),
                            note_id: None,
                        });
                        *index += 1;
                    }
                }
                "hr" => {
                    blocks.push(ReaderBlock {
                        index: *index,
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
                    });
                    *index += 1;
                }
                _ => {
                    walk_children(el, blocks, index, blockquote_depth, in_list);
                }
            }
        }
    }
}

fn collect_text(el: ElementRef<'_>) -> String {
    let mut text = String::new();
    for node in el.descendants() {
        if let Some(t) = node.value().as_text() {
            text.push_str(t);
        } else if let Some(br) = ElementRef::wrap(node) {
            if br.value().name.local.as_ref() == "br" {
                text.push('\n');
            }
        }
    }
    crate::book::normalize_typography(text.trim())
}

fn collect_rich_spans(el: ElementRef<'_>) -> Vec<RichSpan> {
    let mut spans = Vec::new();
    for child in el.children() {
        if let Some(t) = child.value().as_text() {
            let text = t.trim().to_string();
            if !text.is_empty() {
                spans.push(RichSpan {
                    text: crate::book::normalize_typography(&text),
                    bold: false,
                    italic: false,
                    superscript: false,
                    href: None,
                    line_break: false,
                });
            }
        } else if let Some(sub_el) = ElementRef::wrap(child) {
            let tag = sub_el.value().name.local.as_ref();
            let text = collect_text(sub_el);
            if text.is_empty() {
                continue;
            }
            let t = crate::book::normalize_typography(&text);
            match tag {
                "b" | "strong" => spans.push(RichSpan {
                    text: t,
                    bold: true,
                    italic: false,
                    superscript: false,
                    href: None,
                    line_break: false,
                }),
                "i" | "em" | "cite" => spans.push(RichSpan {
                    text: t,
                    bold: false,
                    italic: true,
                    superscript: false,
                    href: None,
                    line_break: false,
                }),
                "sup" => spans.push(RichSpan {
                    text: t,
                    bold: false,
                    italic: false,
                    superscript: true,
                    href: None,
                    line_break: false,
                }),
                "a" => {
                    let href = sub_el.value().attr("href").map(|s| s.to_string());
                    spans.push(RichSpan {
                        text: t,
                        bold: false,
                        italic: false,
                        superscript: false,
                        href,
                        line_break: false,
                    });
                }
                "br" => spans.push(RichSpan {
                    text: String::new(),
                    bold: false,
                    italic: false,
                    superscript: false,
                    href: None,
                    line_break: true,
                }),
                _ => spans.push(RichSpan {
                    text: t,
                    bold: false,
                    italic: false,
                    superscript: false,
                    href: None,
                    line_break: false,
                }),
            }
        }
    }
    spans
}

fn collect_list_items(el: ElementRef<'_>) -> Vec<String> {
    let mut items = Vec::new();
    for child in el.children() {
        if let Some(li) = ElementRef::wrap(child) {
            if li.value().name.local.as_ref() == "li" {
                items.push(collect_text(li));
            }
        }
    }
    items
}

fn is_heading(tag: &str) -> bool {
    tag.len() == 2 && tag.starts_with('h') && tag.as_bytes().get(1).is_some_and(u8::is_ascii_digit)
}
