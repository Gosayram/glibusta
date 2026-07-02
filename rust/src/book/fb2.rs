use crate::api::models::{
    BlockType, BookFormat, NormalizedBook, ReaderBlock, ReaderChapter, RichSpan,
};
use crate::book::archive;
use crate::book::encoding::get_xml_attr;
use crate::book::flush_rich_span;
use anyhow::{Context, Result, bail};
use quick_xml::Reader;
use quick_xml::events::Event;

pub fn parse_fb2(bytes: &[u8], forced_encoding: Option<&str>) -> Result<NormalizedBook> {
    let raw_bytes = if looks_like_zip(bytes) {
        let mut zip = archive::decode_zip(bytes).context("Failed to open FB2.ZIP")?;
        find_fb2_in_zip(&mut zip).context("No .fb2 file found in archive")?
    } else {
        bytes.to_vec()
    };

    let encoding_name = forced_encoding
        .map(|s| s.to_string())
        .unwrap_or_else(|| detect_fb2_encoding(&raw_bytes));
    let encoding =
        encoding_rs::Encoding::for_label(encoding_name.as_bytes()).unwrap_or(encoding_rs::UTF_8);
    let (xml_text, _) = encoding.decode_without_bom_handling(&raw_bytes);
    let xml_text = xml_text.into_owned();

    parse_fb2_xml(&xml_text, &raw_bytes)
}

fn parse_fb2_xml(xml_text: &str, bytes: &[u8]) -> Result<NormalizedBook> {
    let mut reader = Reader::from_str(xml_text);
    reader.config_mut().trim_text(true);

    let mut title = String::new();
    let mut authors: Vec<String> = Vec::new();
    let mut genres: Vec<String> = Vec::new();
    let mut description: Option<String> = None;
    let mut language: Option<String> = None;
    let mut cover_data: Option<String> = None;
    let mut body_blocks: Vec<ReaderBlock> = Vec::new();
    let mut chapters_blocks: Vec<Vec<ReaderBlock>> = Vec::new();
    let mut block_index = 0i32;
    let chapter_index = 0i32;

    // State tracking
    let mut in_title_info = false;
    let mut in_book_title = false;
    let mut in_annotation = false;
    let mut in_author = false;
    let mut in_first_name = false;
    let mut in_middle_name = false;
    let mut in_last_name = false;
    let mut in_genre = false;
    let mut in_body = false;
    let mut in_section = false;
    let mut in_p = false;
    let mut in_subtitle = false;
    let mut in_epigraph = false;
    let mut in_image = false;
    let mut in_empty_line = false;
    let mut in_coverpage = false;
    let mut in_binary = false;
    let mut in_text_author = false;
    let mut in_poem = false;
    let mut in_stanza = false;
    let mut in_cite = false;
    let mut in_pre = false;
    let mut in_lang = false;

    // CRT-1.13: FB2 footnotes parsing
    let mut in_notes_body = false;
    let mut current_note_id: Option<String> = None;
    let mut current_note_text = String::new();
    let mut footnotes: std::collections::HashMap<String, String> = std::collections::HashMap::new();
    let mut current_note_ref: Option<String> = None;

    let mut current_text = String::new();
    let mut current_author_parts: Vec<String> = Vec::new();
    let mut current_rich_spans: Vec<RichSpan> = Vec::new();
    let mut current_span_text = String::new();
    let mut current_span_bold = false;
    let mut current_span_italic = false;
    let mut current_span_superscript = false;
    let mut current_span_href: Option<String> = None;
    let mut section_depth = 0i32;
    let mut current_binary_id: Option<String> = None;

    // Collect all binary data for inline images
    let mut binaries: std::collections::HashMap<String, String> = std::collections::HashMap::new();

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref e)) => {
                let tag_name = String::from_utf8_lossy(e.name().as_ref()).to_string();
                match tag_name.as_str() {
                    "title-info" => in_title_info = true,
                    "book-title" if in_title_info => in_book_title = true,
                    "annotation" if in_title_info => in_annotation = true,
                    "author" if in_title_info => {
                        in_author = true;
                        current_author_parts.clear();
                    }
                    "first-name" if in_author => in_first_name = true,
                    "middle-name" if in_author => in_middle_name = true,
                    "last-name" if in_author => in_last_name = true,
                    "genre" if in_title_info => in_genre = true,
                    "lang" if in_title_info => in_lang = true,
                    "coverpage" => in_coverpage = true,
                    "binary" => {
                        let binary_id = get_xml_attr(e, b"id").unwrap_or_default();
                        if binary_id.starts_with("cover") && cover_data.is_none() {
                            in_binary = true;
                            current_binary_id = Some(binary_id);
                        } else {
                            // Still track for inline image lookups
                            in_binary = true;
                            current_binary_id = Some(binary_id);
                        }
                        current_text.clear();
                    }
                    "body" => {
                        let body_name = get_xml_attr(e, b"name");
                        in_body = true;
                        in_notes_body = body_name.as_deref() == Some("notes");
                    }
                    "section" if in_body => {
                        if in_notes_body {
                            // CRT-1.13: capture footnote section
                            current_note_id = get_xml_attr(e, b"id");
                            current_note_text.clear();
                        } else {
                            section_depth += 1;
                            if section_depth == 1 {
                                // Start new chapter for top-level sections
                                if !body_blocks.is_empty() {
                                    chapters_blocks.push(std::mem::take(&mut body_blocks));
                                }
                                chapters_blocks.push(Vec::new());
                                in_section = true;
                            } else {
                                in_section = true;
                            }
                        }
                    }
                    "p" if in_body => {
                        if in_notes_body {
                            // Accumulate footnote text — handled in text event and section end
                        }
                        in_p = true;
                    }
                    "subtitle" if in_body => in_subtitle = true,
                    "epigraph" if in_body => in_epigraph = true,
                    "empty-line" if in_body => in_empty_line = true,
                    "image" if in_body && !in_coverpage => in_image = true,
                    "text-author" if in_body => in_text_author = true,
                    "poem" if in_body => in_poem = true,
                    "stanza" if in_body && in_poem => {
                        // Insert separator between stanzas
                        if !current_text.trim().is_empty() {
                            body_blocks.push(ReaderBlock {
                                index: block_index,
                                text: current_text.trim().to_string(),
                                block_type: BlockType::Poem,
                                ..default_block()
                            });
                            block_index += 1;
                        }
                        current_text.clear();
                        in_stanza = true;
                    }
                    "v" if in_body && in_poem => {
                        // Verse line — treated like <p> inside poem
                        flush_fb2_block(
                            &mut body_blocks,
                            &mut current_text,
                            &mut current_rich_spans,
                            &mut current_span_text,
                            &mut block_index,
                            if in_cite {
                                BlockType::Cite
                            } else {
                                BlockType::Poem
                            },
                        );
                    }
                    "cite" if in_body => in_cite = true,
                    "pre" if in_body => in_pre = true,
                    "strong" if in_p || in_subtitle => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            &current_span_href,
                        );
                        current_span_bold = true;
                    }
                    "emphasis" if in_p || in_subtitle => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            &current_span_href,
                        );
                        current_span_italic = true;
                    }
                    "a" if in_p => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            &current_span_href,
                        );
                        current_span_href = get_xml_attr(e, b"href");
                        // CRT-1.13: capture footnote reference
                        let a_type = get_xml_attr(e, b"type");
                        if a_type.as_deref() == Some("note") {
                            if let Some(ref href) = current_span_href {
                                current_note_ref = Some(href.trim_start_matches('#').to_string());
                            }
                        }
                    }
                    "sup" if in_p || in_subtitle => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            &current_span_href,
                        );
                        current_span_superscript = true;
                    }
                    _ => {}
                }
            }
            Ok(Event::Text(ref e)) => {
                let text = e.xml10_content().unwrap_or_default().to_string();
                if in_notes_body && in_p {
                    current_note_text.push_str(&text);
                } else if in_book_title && title.is_empty() {
                    title = text.clone();
                } else if in_first_name || in_middle_name || in_last_name {
                    current_author_parts.push(text.clone());
                } else if in_genre {
                    genres.push(text.clone());
                } else if in_lang {
                    language = Some(text.clone());
                } else if in_annotation {
                    description = Some(description.take().unwrap_or_default() + &text);
                } else if in_binary {
                    current_text.push_str(&text);
                } else if in_p && in_body {
                    if let Some(last) = current_rich_spans.last_mut() {
                        if last.text.is_empty() && last.href.is_some() {
                            last.text = text.clone();
                        } else {
                            current_span_text.push_str(&text);
                        }
                    } else {
                        current_span_text.push_str(&text);
                    }
                } else if in_body
                    && ((in_subtitle || in_epigraph || in_text_author)
                        || (!in_section && !in_image && !in_empty_line))
                {
                    current_text.push_str(&text);
                }
            }
            Ok(Event::GeneralRef(ref e)) => {
                let text = e.xml10_content().unwrap_or_default().to_string();
                if in_notes_body && in_p {
                    current_note_text.push_str(&text);
                } else if in_book_title && title.is_empty() {
                    title = text.clone();
                } else if in_first_name || in_middle_name || in_last_name {
                    current_author_parts.push(text.clone());
                } else if in_genre {
                    genres.push(text.clone());
                } else if in_lang {
                    language = Some(text.clone());
                    if let Some(last) = current_rich_spans.last_mut() {
                        if last.text.is_empty() && last.href.is_some() {
                            last.text = text.clone();
                        } else {
                            current_span_text.push_str(&text);
                        }
                    } else {
                        current_span_text.push_str(&text);
                    }
                } else if in_body
                    && ((in_subtitle || in_epigraph || in_text_author)
                        || (!in_section && !in_image && !in_empty_line))
                {
                    current_text.push_str(&text);
                }
            }
            Ok(Event::CData(ref e)) => {
                let text = e.xml10_content().unwrap_or_default();
                if in_book_title && title.is_empty() {
                    title = text.to_string();
                } else if in_first_name || in_middle_name || in_last_name {
                    current_author_parts.push(text.to_string());
                } else if in_genre {
                    genres.push(text.to_string());
                } else if in_lang {
                    language = Some(text.to_string());
                } else if in_annotation {
                    description = Some(description.take().unwrap_or_default() + &text);
                } else if in_binary {
                    current_text.push_str(&text);
                } else if in_p && in_body {
                    if let Some(last) = current_rich_spans.last_mut() {
                        if last.text.is_empty() && last.href.is_some() {
                            last.text = text.to_string();
                        } else {
                            current_span_text.push_str(&text);
                        }
                    } else {
                        current_span_text.push_str(&text);
                    }
                } else if in_body
                    && ((in_subtitle || in_epigraph || in_text_author)
                        || (!in_section && !in_image && !in_empty_line))
                {
                    current_text.push_str(&text);
                }
            }
            Ok(Event::End(ref e)) => {
                let tag_name = String::from_utf8_lossy(e.name().as_ref()).to_string();
                match tag_name.as_str() {
                    "title-info" => in_title_info = false,
                    "book-title" => in_book_title = false,
                    "annotation" => {
                        in_annotation = false;
                        description =
                            Some(description.take().unwrap_or_default().trim().to_string());
                    }
                    "first-name" => in_first_name = false,
                    "middle-name" => in_middle_name = false,
                    "last-name" => in_last_name = false,
                    "author" => {
                        if !current_author_parts.is_empty() {
                            authors.push(current_author_parts.join(" "));
                            current_author_parts.clear();
                        }
                        in_author = false;
                    }
                    "genre" => in_genre = false,
                    "lang" => in_lang = false,
                    "coverpage" => in_coverpage = false,
                    "binary" => {
                        if in_binary && !current_text.is_empty() {
                            if let Some(ref id) = current_binary_id {
                                if id.starts_with("cover") && cover_data.is_none() {
                                    cover_data = Some(current_text.trim().to_string());
                                }
                                binaries.insert(id.clone(), current_text.trim().to_string());
                            }
                        }
                        in_binary = false;
                        current_binary_id = None;
                        current_text.clear();
                    }
                    "body" => {
                        in_body = false;
                        in_notes_body = false;
                    }
                    "section" => {
                        if in_notes_body {
                            // CRT-1.13: store footnote
                            if let Some(ref id) = current_note_id {
                                let text = current_note_text.trim().to_string();
                                if !text.is_empty() {
                                    footnotes.insert(id.clone(), text);
                                }
                            }
                            current_note_id = None;
                            current_note_text.clear();
                        } else {
                            if section_depth > 0 {
                                section_depth -= 1;
                            }
                            if section_depth == 0 {
                                in_section = false;
                                // Finalize current chapter
                                if !body_blocks.is_empty() {
                                    chapters_blocks.push(std::mem::take(&mut body_blocks));
                                }
                            }
                        }
                    }
                    "p" if in_body => {
                        // Flush any remaining inline text into a span if formatting active
                        if !current_span_text.trim().is_empty()
                            && (current_span_bold
                                || current_span_italic
                                || current_span_superscript
                                || current_span_href.is_some())
                        {
                            flush_rich_span(
                                &mut current_rich_spans,
                                &mut current_span_text,
                                current_span_bold,
                                current_span_italic,
                                current_span_superscript,
                                &current_span_href,
                            );
                        }
                        // Get the full text: either from spans or from raw text buffer
                        let text = if current_rich_spans.is_empty() {
                            let t = current_span_text.trim().to_string();
                            current_span_text.clear();
                            t
                        } else {
                            current_rich_spans
                                .iter()
                                .map(|s| s.text.as_str())
                                .collect::<Vec<_>>()
                                .join("")
                                .trim()
                                .to_string()
                        };

                        if !text.is_empty() || !current_rich_spans.is_empty() {
                            let rich = if current_rich_spans.is_empty() {
                                None
                            } else {
                                Some(current_rich_spans.clone())
                            };
                            body_blocks.push(ReaderBlock {
                                index: block_index,
                                text,
                                block_type: BlockType::Paragraph,
                                image_url: None,
                                note_ref: current_note_ref.take(),
                                rich_spans: rich,
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
                        }
                        current_rich_spans.clear();
                        current_span_text.clear();
                        current_span_bold = false;
                        current_span_italic = false;
                        current_span_superscript = false;
                        current_span_href = None;
                        in_p = false;
                    }
                    "subtitle" if in_body => {
                        let text = current_text.trim().to_string();
                        current_text.clear();
                        if !text.is_empty() {
                            body_blocks.push(ReaderBlock {
                                index: block_index,
                                text,
                                block_type: BlockType::Subtitle,
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
                        }
                        in_subtitle = false;
                    }
                    "epigraph" if in_body => {
                        let text = current_text.trim().to_string();
                        current_text.clear();
                        if !text.is_empty() {
                            body_blocks.push(ReaderBlock {
                                index: block_index,
                                text,
                                block_type: BlockType::Epigraph,
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
                        }
                        in_epigraph = false;
                    }
                    "text-author" if in_body => {
                        let text = current_text.trim().to_string();
                        current_text.clear();
                        if !text.is_empty() {
                            body_blocks.push(ReaderBlock {
                                index: block_index,
                                text,
                                block_type: BlockType::TextAuthor,
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
                        }
                        in_text_author = false;
                    }
                    "poem" if in_body && in_poem => {
                        flush_fb2_block(
                            &mut body_blocks,
                            &mut current_text,
                            &mut current_rich_spans,
                            &mut current_span_text,
                            &mut block_index,
                            BlockType::Poem,
                        );
                        in_poem = false;
                        in_stanza = false;
                    }
                    "stanza" if in_body && in_stanza => {
                        // Flush any remaining verse text in this stanza
                        if !current_text.trim().is_empty() {
                            body_blocks.push(ReaderBlock {
                                index: block_index,
                                text: current_text.trim().to_string(),
                                block_type: BlockType::Poem,
                                ..default_block()
                            });
                            block_index += 1;
                        }
                        current_text.clear();
                        // Add stanza separator (empty line)
                        body_blocks.push(ReaderBlock {
                            index: block_index,
                            text: String::new(),
                            block_type: BlockType::Separator,
                            ..default_block()
                        });
                        block_index += 1;
                        in_stanza = false;
                    }
                    "v" if in_body && in_poem => {
                        // Verse end — flush as poem line
                        flush_fb2_block(
                            &mut body_blocks,
                            &mut current_text,
                            &mut current_rich_spans,
                            &mut current_span_text,
                            &mut block_index,
                            BlockType::Poem,
                        );
                    }
                    "cite" if in_body && in_cite => {
                        flush_fb2_block(
                            &mut body_blocks,
                            &mut current_text,
                            &mut current_rich_spans,
                            &mut current_span_text,
                            &mut block_index,
                            BlockType::Cite,
                        );
                        in_cite = false;
                    }
                    "pre" if in_body && in_pre => {
                        flush_fb2_block(
                            &mut body_blocks,
                            &mut current_text,
                            &mut current_rich_spans,
                            &mut current_span_text,
                            &mut block_index,
                            BlockType::Paragraph,
                        );
                        in_pre = false;
                    }
                    "empty-line" if in_body => {
                        body_blocks.push(ReaderBlock {
                            index: block_index,
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
                        block_index += 1;
                        in_empty_line = false;
                    }
                    "image" if in_body && !in_coverpage => {
                        // Try to extract binary reference from the image tag
                        let image_ref = current_text.trim().to_string();
                        current_text.clear();
                        let key = image_ref.trim_start_matches('#').to_string();
                        let image_url = binaries
                            .get(&key)
                            .map(|d| format!("data:image/jpeg;base64,{}", d));
                        body_blocks.push(ReaderBlock {
                            index: block_index,
                            text: String::new(),
                            block_type: BlockType::Image,
                            image_url,
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
                        in_image = false;
                    }
                    "strong" if in_p => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            &current_span_href,
                        );
                        current_span_bold = false;
                    }
                    "emphasis" if in_p => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            &current_span_href,
                        );
                        current_span_italic = false;
                    }
                    "a" if in_p => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            &current_span_href,
                        );
                        current_span_href = None;
                    }
                    "sup" if in_p => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            &current_span_href,
                        );
                        current_span_superscript = false;
                    }
                    _ => {}
                }
            }
            Ok(Event::Empty(ref e)) => {
                let tag_name = String::from_utf8_lossy(e.name().as_ref()).to_string();
                if tag_name == "empty-line" && in_body {
                    body_blocks.push(ReaderBlock {
                        index: block_index,
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
                    block_index += 1;
                } else if tag_name == "image" && in_body && !in_coverpage {
                    // Empty <image l:href="#id"/> — lookup binary
                    let href = get_xml_attr(e, b"l:href")
                        .or_else(|| get_xml_attr(e, b"href"))
                        .unwrap_or_default();
                    let key = href.trim_start_matches('#').to_string();
                    let image_url = binaries
                        .get(&key)
                        .map(|d| format!("data:image/jpeg;base64,{}", d));
                    body_blocks.push(ReaderBlock {
                        index: block_index,
                        text: String::new(),
                        block_type: BlockType::Image,
                        image_url,
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
                }
            }
            Err(e) => {
                bail!("FB2 XML parse error: {}", e);
            }
            _ => {}
        }
    }

    let cover_url = cover_data.map(|d| format!("data:image/jpeg;base64,{}", d));

    let chapters = if !chapters_blocks.is_empty() {
        // Sections were found — build chapters from them
        if !body_blocks.is_empty() {
            // Preamble before first section
            chapters_blocks.insert(0, std::mem::take(&mut body_blocks));
        }
        let mut idx = 0i32;
        chapters_blocks
            .into_iter()
            .filter(|blocks| !blocks.is_empty())
            .map(|blocks| {
                let ch_title = blocks
                    .iter()
                    .find(|b| {
                        b.block_type == BlockType::Heading || b.block_type == BlockType::Subtitle
                    })
                    .map(|b| b.text.clone())
                    .unwrap_or_else(|| title.clone());
                let chapter = ReaderChapter {
                    index: idx,
                    title: ch_title,
                    blocks,
                };
                idx += 1;
                chapter
            })
            .collect()
    } else if body_blocks.is_empty() {
        vec![]
    } else {
        vec![ReaderChapter {
            index: chapter_index,
            title: title.clone(),
            blocks: body_blocks,
        }]
    };

    let id = crate::book::sha256_hex(bytes);

    let metadata = if footnotes.is_empty() {
        None
    } else {
        Some(serde_json::json!({ "footnotes": footnotes }))
    };

    Ok(NormalizedBook {
        id,
        title,
        authors,
        description,
        cover_url,
        chapters,
        metadata,
        book_format: BookFormat::Fb2,
        language,
        warnings: Vec::new(),
        images: Vec::new(),
        toc: Vec::new(),
    })
}

fn looks_like_zip(bytes: &[u8]) -> bool {
    bytes.len() >= 2 && bytes[0] == b'P' && bytes[1] == b'K'
}

fn find_fb2_in_zip(zip: &mut archive::ZipFile) -> Option<Vec<u8>> {
    let name = zip
        .entry_names()
        .iter()
        .find(|name| name.ends_with(".fb2") && !name.ends_with(".fb2.zip"))
        .cloned()?;
    zip.find_file(&name)
}

fn detect_fb2_encoding(bytes: &[u8]) -> String {
    if bytes.starts_with(b"\xef\xbb\xbf") {
        return "utf-8".to_string();
    }
    if bytes.starts_with(b"\xff\xfe") {
        return "utf-16le".to_string();
    }
    if bytes.starts_with(b"\xfe\xff") {
        return "utf-16be".to_string();
    }
    let snippet = &bytes[..bytes.len().min(200)];
    if let Some(pos) = snippet.windows(15).position(|w| w == b"encoding=") {
        let after = &snippet[pos + 10..];
        if let Some(q) = after.first() {
            if *q == b'"' || *q == b'\'' {
                let quote = *q;
                if let Some(end) = after[1..].iter().position(|&b| b == quote) {
                    let label = std::str::from_utf8(&after[1..1 + end]).unwrap_or("utf-8");
                    if encoding_rs::Encoding::for_label_no_replacement(label.as_bytes()).is_some() {
                        return label.to_lowercase();
                    }
                }
            }
        }
    }
    "utf-8".to_string()
}

fn default_block() -> ReaderBlock {
    ReaderBlock {
        index: 0,
        text: String::new(),
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
    }
}

fn flush_fb2_block(
    blocks: &mut Vec<ReaderBlock>,
    current_text: &mut String,
    current_rich_spans: &mut Vec<RichSpan>,
    current_span_text: &mut String,
    block_index: &mut i32,
    block_type: BlockType,
) {
    flush_rich_span(
        current_rich_spans,
        current_span_text,
        false,
        false,
        false,
        &None,
    );
    let t = crate::book::normalize_typography(current_text.trim());
    if !t.is_empty() {
        let rich = if current_rich_spans.is_empty() {
            None
        } else {
            Some(current_rich_spans.clone())
        };
        blocks.push(ReaderBlock {
            index: *block_index,
            text: t,
            block_type,
            image_url: None,
            note_ref: None,
            rich_spans: rich,
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
    current_text.clear();
    current_rich_spans.clear();
    current_span_text.clear();
}
