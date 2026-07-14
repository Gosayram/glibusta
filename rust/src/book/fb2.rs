use crate::api::models::{
    BlockType, BookFormat, MAX_FILE_SIZE, MAX_IMAGE_SIZE, NormalizedBook, ReaderBlock,
    ReaderChapter, RichSpan,
};
use crate::book::archive;
use crate::book::encoding::{attr_eq, get_xml_attr};
use crate::book::flush_rich_span;
use anyhow::{Context, Result, bail};
use quick_xml::Reader;
use quick_xml::events::Event;

pub fn parse_fb2(bytes: &[u8], forced_encoding: Option<&str>) -> Result<NormalizedBook> {
    if bytes.len() as u64 > MAX_FILE_SIZE {
        bail!(
            "FB2 file exceeds maximum size of {} MiB",
            MAX_FILE_SIZE / 1024 / 1024
        );
    }

    let raw_bytes = if looks_like_zip(bytes) {
        let mut zip = archive::decode_zip(bytes).context("Failed to open FB2.ZIP")?;
        find_fb2_in_zip(&mut zip)?.context("No .fb2 file found in archive")?
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
                match e.name().as_ref() {
                    b"title-info" => in_title_info = true,
                    b"book-title" if in_title_info => in_book_title = true,
                    b"annotation" if in_title_info => in_annotation = true,
                    b"author" if in_title_info => {
                        in_author = true;
                        current_author_parts.clear();
                    }
                    b"first-name" if in_author => in_first_name = true,
                    b"middle-name" if in_author => in_middle_name = true,
                    b"last-name" if in_author => in_last_name = true,
                    b"genre" if in_title_info => in_genre = true,
                    b"lang" if in_title_info => in_lang = true,
                    b"coverpage" => in_coverpage = true,
                    b"binary" => {
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
                    b"body" => {
                        in_body = true;
                        in_notes_body = attr_eq(e, b"name", b"notes");
                    }
                    b"section" if in_body => {
                        if in_notes_body {
                            current_note_id = get_xml_attr(e, b"id");
                            current_note_text.clear();
                        } else {
                            section_depth += 1;
                            if section_depth == 1 {
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
                    b"p" if in_body => {
                        in_p = true;
                    }
                    b"subtitle" if in_body => in_subtitle = true,
                    b"epigraph" if in_body => in_epigraph = true,
                    b"empty-line" if in_body => in_empty_line = true,
                    b"image" if in_body && !in_coverpage => in_image = true,
                    b"text-author" if in_body => in_text_author = true,
                    b"poem" if in_body => in_poem = true,
                    b"stanza" if in_body && in_poem => {
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
                    b"v" if in_body && in_poem => {
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
                    b"cite" if in_body => in_cite = true,
                    b"pre" if in_body => in_pre = true,
                    b"strong" if in_p || in_subtitle => {
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
                    b"emphasis" if in_p || in_subtitle => {
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
                    b"a" if in_p => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            &current_span_href,
                        );
                        current_span_href =
                            get_xml_attr(e, b"href").and_then(|h| crate::book::sanitize_href(&h));
                        if attr_eq(e, b"type", b"note") {
                            if let Some(ref href) = current_span_href {
                                current_note_ref = Some(href.trim_start_matches('#').to_string());
                            }
                        }
                    }
                    b"sup" if in_p || in_subtitle => {
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
                let text = e.xml10_content().unwrap_or_default();
                if in_notes_body && in_p {
                    current_note_text.push_str(&text);
                } else if in_book_title && title.is_empty() {
                    title = text.into_owned();
                } else if in_first_name || in_middle_name || in_last_name {
                    current_author_parts.push(text.into_owned());
                } else if in_genre {
                    genres.push(text.into_owned());
                } else if in_lang {
                    language = Some(text.into_owned());
                } else if in_annotation {
                    description = Some(description.take().unwrap_or_default() + &text);
                } else if in_binary {
                    if current_text.len().saturating_add(text.len()) > max_base64_image_size() {
                        bail!(
                            "FB2 image exceeds maximum size of {} MiB",
                            MAX_IMAGE_SIZE / 1024 / 1024
                        );
                    }
                    current_text.push_str(&text);
                } else if in_p && in_body {
                    if let Some(last) = current_rich_spans.last_mut() {
                        if last.text.is_empty() && last.href.is_some() {
                            last.text = text.into_owned();
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
                let text = e.xml10_content().unwrap_or_default();
                if in_notes_body && in_p {
                    current_note_text.push_str(&text);
                } else if in_book_title && title.is_empty() {
                    title = text.into_owned();
                } else if in_first_name || in_middle_name || in_last_name {
                    current_author_parts.push(text.into_owned());
                } else if in_genre {
                    genres.push(text.into_owned());
                } else if in_lang {
                    let owned = text.into_owned();
                    language = Some(owned.clone());
                    if let Some(last) = current_rich_spans.last_mut() {
                        if last.text.is_empty() && last.href.is_some() {
                            last.text = owned;
                        } else {
                            current_span_text.push_str(&owned);
                        }
                    } else {
                        current_span_text.push_str(&owned);
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
                    title = text.into_owned();
                } else if in_first_name || in_middle_name || in_last_name {
                    current_author_parts.push(text.into_owned());
                } else if in_genre {
                    genres.push(text.into_owned());
                } else if in_lang {
                    language = Some(text.into_owned());
                } else if in_annotation {
                    description = Some(description.take().unwrap_or_default() + &text);
                } else if in_binary {
                    current_text.push_str(&text);
                } else if in_p && in_body {
                    if let Some(last) = current_rich_spans.last_mut() {
                        if last.text.is_empty() && last.href.is_some() {
                            last.text = text.into_owned();
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
            Ok(Event::End(ref e)) => match e.name().as_ref() {
                b"title-info" => in_title_info = false,
                b"book-title" => in_book_title = false,
                b"annotation" => {
                    in_annotation = false;
                    description = Some(description.take().unwrap_or_default().trim().to_string());
                }
                b"first-name" => in_first_name = false,
                b"middle-name" => in_middle_name = false,
                b"last-name" => in_last_name = false,
                b"author" => {
                    if !current_author_parts.is_empty() {
                        authors.push(current_author_parts.join(" "));
                        current_author_parts.clear();
                    }
                    in_author = false;
                }
                b"genre" => in_genre = false,
                b"lang" => in_lang = false,
                b"coverpage" => in_coverpage = false,
                b"binary" => {
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
                b"body" => {
                    in_body = false;
                    in_notes_body = false;
                }
                b"section" => {
                    if in_notes_body {
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
                            if !body_blocks.is_empty() {
                                chapters_blocks.push(std::mem::take(&mut body_blocks));
                            }
                        }
                    }
                }
                b"p" if in_body => {
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
                            Some(std::mem::take(&mut current_rich_spans))
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
                b"subtitle" if in_body => {
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
                b"epigraph" if in_body => {
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
                b"text-author" if in_body => {
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
                b"poem" if in_body && in_poem => {
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
                b"stanza" if in_body && in_stanza => {
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
                    body_blocks.push(ReaderBlock {
                        index: block_index,
                        text: String::new(),
                        block_type: BlockType::Separator,
                        ..default_block()
                    });
                    block_index += 1;
                    in_stanza = false;
                }
                b"v" if in_body && in_poem => {
                    flush_fb2_block(
                        &mut body_blocks,
                        &mut current_text,
                        &mut current_rich_spans,
                        &mut current_span_text,
                        &mut block_index,
                        BlockType::Poem,
                    );
                }
                b"cite" if in_body && in_cite => {
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
                b"pre" if in_body && in_pre => {
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
                b"empty-line" if in_body => {
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
                b"image" if in_body && !in_coverpage => {
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
                b"strong" if in_p => {
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
                b"emphasis" if in_p => {
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
                b"a" if in_p => {
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
                b"sup" if in_p => {
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
            },
            Ok(Event::Empty(ref e)) => match e.name().as_ref() {
                b"empty-line" if in_body => {
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
                }
                b"image" if in_body && !in_coverpage => {
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
                _ => {}
            },
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

fn max_base64_image_size() -> usize {
    MAX_IMAGE_SIZE
        .checked_add(2)
        .and_then(|size| size.checked_div(3))
        .and_then(|groups| groups.checked_mul(4))
        .unwrap_or(usize::MAX)
}

fn looks_like_zip(bytes: &[u8]) -> bool {
    bytes.len() >= 2 && bytes[0] == b'P' && bytes[1] == b'K'
}

fn find_fb2_in_zip(zip: &mut archive::ZipFile<'_>) -> Result<Option<Vec<u8>>> {
    let Some(name) = zip
        .entry_names()
        .iter()
        .find(|name| name.ends_with(".fb2") && !name.ends_with(".fb2.zip"))
        .cloned()
    else {
        return Ok(None);
    };
    zip.read_file_limited(&name, crate::api::models::MAX_FILE_SIZE as usize)
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
            Some(std::mem::take(current_rich_spans))
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
