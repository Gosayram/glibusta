use crate::api::models::{BlockType, NormalizedBook, ReaderBlock, ReaderChapter, RichSpan};
use crate::book::archive;
use crate::book::encoding::get_xml_attr;
use anyhow::{bail, Context, Result};
use quick_xml::events::Event;
use quick_xml::Reader;

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
    let mut cover_data: Option<String> = None;
    let mut body_blocks: Vec<ReaderBlock> = Vec::new();
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

    let mut current_text = String::new();
    let mut current_author_parts: Vec<String> = Vec::new();
    let mut current_rich_spans: Vec<RichSpan> = Vec::new();
    let mut current_span_text = String::new();
    let mut current_span_bold = false;
    let mut current_span_italic = false;
    let mut section_depth = 0i32;

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
                    "coverpage" => in_coverpage = true,
                    "binary" => {
                        let is_cover = e.attributes().any(|a| {
                            a.map(|attr| {
                                attr.key.as_ref() == b"id"
                                    && std::str::from_utf8(attr.value.as_ref())
                                        .unwrap_or("")
                                        .starts_with("cover")
                            })
                            .unwrap_or(false)
                        });
                        if is_cover && cover_data.is_none() {
                            in_binary = true;
                            current_text.clear();
                        }
                    }
                    "body" => in_body = true,
                    "section" if in_body => {
                        in_section = true;
                        section_depth += 1;
                    }
                    "p" if in_body => in_p = true,
                    "subtitle" if in_body => in_subtitle = true,
                    "epigraph" if in_body => in_epigraph = true,
                    "empty-line" if in_body => in_empty_line = true,
                    "image" if in_body && !in_coverpage => in_image = true,
                    "text-author" if in_body => in_text_author = true,
                    "strong" if in_p || in_subtitle => current_span_bold = true,
                    "emphasis" if in_p || in_subtitle => current_span_italic = true,
                    "a" if in_p => {
                        if let Some(href) = get_xml_attr(e, b"href") {
                            current_rich_spans.push(RichSpan {
                                text: String::new(),
                                bold: current_span_bold,
                                italic: current_span_italic,
                                superscript: false,
                                href: Some(href),
                            });
                        }
                    }
                    "sup" if in_p => current_span_bold = false,
                    _ => {}
                }
            }
            Ok(Event::Text(ref e)) => {
                let text = e.xml10_content().unwrap_or_default().to_string();
                if in_book_title && title.is_empty() {
                    title = text.clone();
                } else if in_first_name || in_middle_name || in_last_name {
                    current_author_parts.push(text.clone());
                } else if in_genre {
                    genres.push(text.clone());
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
                if in_book_title && title.is_empty() {
                    title = text.clone();
                } else if in_first_name || in_middle_name || in_last_name {
                    current_author_parts.push(text.clone());
                } else if in_genre {
                    genres.push(text.clone());
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
            Ok(Event::CData(ref e)) => {
                let text = e.xml10_content().unwrap_or_default();
                if in_book_title && title.is_empty() {
                    title = text.to_string();
                } else if in_first_name || in_middle_name || in_last_name {
                    current_author_parts.push(text.to_string());
                } else if in_genre {
                    genres.push(text.to_string());
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
                    "coverpage" => in_coverpage = false,
                    "binary" => {
                        if in_binary && cover_data.is_none() && !current_text.is_empty() {
                            cover_data = Some(current_text.trim().to_string());
                        }
                        in_binary = false;
                        current_text.clear();
                    }
                    "body" => in_body = false,
                    "section" => {
                        if section_depth > 0 {
                            section_depth -= 1;
                        }
                        if section_depth == 0 {
                            in_section = false;
                        }
                    }
                    "p" if in_body => {
                        let text = current_span_text.trim().to_string();
                        current_span_text.clear();

                        if !text.is_empty() || !current_rich_spans.is_empty() {
                            let rich = if current_rich_spans.is_empty() {
                                None
                            } else {
                                let mut spans = current_rich_spans.clone();
                                if !text.is_empty() {
                                    if let Some(last) = spans.last_mut() {
                                        if last.text.is_empty() {
                                            last.text = text.clone();
                                        }
                                    }
                                }
                                Some(spans)
                            };
                            body_blocks.push(ReaderBlock {
                                index: block_index,
                                text,
                                block_type: BlockType::Paragraph,
                                image_url: None,
                                note_ref: None,
                                rich_spans: rich,
                            });
                            block_index += 1;
                        }
                        current_rich_spans.clear();
                        current_span_bold = false;
                        current_span_italic = false;
                        in_p = false;
                    }
                    "subtitle" if in_body => {
                        let text = current_text.trim().to_string();
                        current_text.clear();
                        if !text.is_empty() {
                            body_blocks.push(ReaderBlock {
                                index: block_index,
                                text,
                                block_type: BlockType::Heading,
                                image_url: None,
                                note_ref: None,
                                rich_spans: None,
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
                                block_type: BlockType::Quote,
                                image_url: None,
                                note_ref: None,
                                rich_spans: None,
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
                                block_type: BlockType::Paragraph,
                                image_url: None,
                                note_ref: None,
                                rich_spans: None,
                            });
                            block_index += 1;
                        }
                        in_text_author = false;
                    }
                    "empty-line" if in_body => {
                        body_blocks.push(ReaderBlock {
                            index: block_index,
                            text: String::new(),
                            block_type: BlockType::Separator,
                            image_url: None,
                            note_ref: None,
                            rich_spans: None,
                        });
                        block_index += 1;
                        in_empty_line = false;
                    }
                    "image" if in_body && !in_coverpage => {
                        // FB2 images are referenced by id via l:href
                        // We store a placeholder; actual image extraction happens at render time
                        body_blocks.push(ReaderBlock {
                            index: block_index,
                            text: String::new(),
                            block_type: BlockType::Image,
                            image_url: Some(String::from("fb2-image")),
                            note_ref: None,
                            rich_spans: None,
                        });
                        block_index += 1;
                        in_image = false;
                    }
                    "strong" if in_p => current_span_bold = false,
                    "emphasis" if in_p => current_span_italic = false,
                    "a" if in_p => {}
                    "sup" if in_p => {}
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
                    });
                    block_index += 1;
                } else if tag_name == "image" && in_body && !in_coverpage {
                    body_blocks.push(ReaderBlock {
                        index: block_index,
                        text: String::new(),
                        block_type: BlockType::Image,
                        image_url: Some(String::from("fb2-image")),
                        note_ref: None,
                        rich_spans: None,
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

    let chapters = if body_blocks.is_empty() {
        vec![]
    } else {
        vec![ReaderChapter {
            index: chapter_index,
            title: title.clone(),
            blocks: body_blocks,
        }]
    };

    let id = crate::book::sha256_hex(bytes);

    Ok(NormalizedBook {
        id,
        title,
        authors,
        description,
        cover_url,
        chapters,
        metadata: None,
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
