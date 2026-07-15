use crate::api::models::{
    BlockType, BookFormat, EmbeddedImage, NormalizedBook, ReaderBlock, ReaderChapter, RichSpan,
};
use crate::book::archive::{self, ZipFile};
use crate::book::encoding::decode_bytes;
use anyhow::{Context, Result};
use quick_xml::Reader;
use quick_xml::events::{BytesStart, Event};
use serde::Deserialize;
use std::collections::HashMap;

pub fn parse_docx(bytes: &[u8], forced_encoding: Option<&str>) -> Result<NormalizedBook> {
    if bytes.len() as u64 > crate::api::models::MAX_FILE_SIZE {
        anyhow::bail!("DOCX exceeds maximum file size");
    }
    let mut zip = archive::decode_zip(bytes).context("Failed to open DOCX archive")?;

    let entry_count = zip.entry_names().len();
    if entry_count > crate::api::models::MAX_EXTRACTED_FILES {
        anyhow::bail!(
            "Archive too large: {} entries (max {})",
            entry_count,
            crate::api::models::MAX_EXTRACTED_FILES
        );
    }

    let encoding_name = forced_encoding.unwrap_or("utf-8");

    let (title, authors, created_date) = parse_core_properties(&mut zip, encoding_name)?;

    let document_xml = zip
        .read_file_limited("word/document.xml", crate::api::models::MAX_CHAPTER_SIZE)?
        .context("DOCX missing word/document.xml")?;
    let doc_text = decode_bytes(&document_xml, encoding_name);

    let hyperlink_targets = parse_hyperlink_relationships(&mut zip, encoding_name)?;
    let image_targets = parse_image_relationships(&mut zip, encoding_name)?;
    let footnotes = parse_footnotes(&mut zip, encoding_name)?;
    let (blocks, chapter_title) = parse_document_xml_with_hyperlinks(
        &doc_text,
        &hyperlink_targets,
        &image_targets,
        &footnotes,
    )?;

    let id = crate::book::sha256_hex(bytes);

    let final_title = if title.is_empty() {
        chapter_title
    } else {
        title
    };

    let chapters = if blocks.is_empty() {
        vec![]
    } else {
        vec![ReaderChapter {
            index: 0,
            title: final_title.clone(),
            blocks,
        }]
    };

    let mut metadata = serde_json::Map::new();
    metadata.insert("created".into(), serde_json::Value::String(created_date));
    if !footnotes.is_empty() {
        metadata.insert("footnotes".into(), serde_json::json!(footnotes));
    }

    let images = extract_images(&mut zip);
    let cover_url = if let Some(img) = images.first() {
        let entry_name = format!("word/media/{}", img.id);
        let data = zip.read_file_limited(&entry_name, crate::api::models::MAX_IMAGE_SIZE)?;
        use base64::Engine;
        data.map(|data| {
            format!(
                "data:{};base64,{}",
                img.media_type,
                base64::engine::general_purpose::STANDARD.encode(&data)
            )
        })
    } else {
        None
    };

    Ok(NormalizedBook {
        id,
        title: final_title,
        authors,
        description: None,
        cover_url,
        chapters,
        metadata: Some(serde_json::Value::Object(metadata)),
        book_format: BookFormat::Docx,
        language: None,
        warnings: Vec::new(),
        images,
        toc: Vec::new(),
    })
}

#[derive(Deserialize)]
struct CoreProps {
    #[serde(rename = "title", default)]
    title: Option<String>,
    #[serde(rename = "creator", default)]
    creator: Vec<String>,
    #[serde(rename = "created", default)]
    created: Option<String>,
}

fn parse_core_properties(
    zip: &mut ZipFile<'_>,
    encoding_name: &str,
) -> Result<(String, Vec<String>, String)> {
    let props_bytes = zip
        .read_file_limited("docProps/core.xml", crate::api::models::MAX_CHAPTER_SIZE)?
        .context("DOCX missing docProps/core.xml")?;
    let props_text = decode_bytes(&props_bytes, encoding_name);

    let core: CoreProps =
        quick_xml::de::from_str(&props_text).context("Failed to parse core.xml")?;

    let title = core.title.unwrap_or_default();
    let authors: Vec<String> = core
        .creator
        .into_iter()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect();
    let created = core.created.unwrap_or_default();

    Ok((title, authors, created))
}

fn parse_hyperlink_relationships(
    zip: &mut ZipFile<'_>,
    encoding_name: &str,
) -> Result<HashMap<String, String>> {
    let Some(bytes) = zip.read_file_limited(
        "word/_rels/document.xml.rels",
        crate::api::models::MAX_CHAPTER_SIZE,
    )?
    else {
        return Ok(HashMap::new());
    };
    let text = decode_bytes(&bytes, encoding_name);
    let mut reader = Reader::from_str(&text);
    let mut targets = HashMap::new();

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Empty(ref element)) | Ok(Event::Start(ref element))
                if element.local_name().as_ref() == b"Relationship" =>
            {
                let id = xml_attribute(element, b"Id");
                let target = xml_attribute(element, b"Target");
                let mode = xml_attribute(element, b"TargetMode");
                if mode.as_deref() == Some("External") {
                    if let (Some(id), Some(target)) = (id, target) {
                        if let Some(safe_target) = crate::book::sanitize_href(&target) {
                            targets.insert(id, safe_target);
                        }
                    }
                }
            }
            Ok(_) => {}
            Err(_) => return Ok(HashMap::new()),
        }
    }

    Ok(targets)
}

fn parse_image_relationships(
    zip: &mut ZipFile<'_>,
    encoding_name: &str,
) -> Result<HashMap<String, String>> {
    let Some(bytes) = zip.read_file_limited(
        "word/_rels/document.xml.rels",
        crate::api::models::MAX_CHAPTER_SIZE,
    )?
    else {
        return Ok(HashMap::new());
    };
    let text = decode_bytes(&bytes, encoding_name);
    let mut reader = Reader::from_str(&text);
    let mut targets = HashMap::new();

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Empty(ref element)) | Ok(Event::Start(ref element))
                if element.local_name().as_ref() == b"Relationship" =>
            {
                let id = xml_attribute(element, b"Id");
                let relation_type = xml_attribute(element, b"Type");
                let target = xml_attribute(element, b"Target");
                if relation_type.is_some_and(|relation_type| relation_type.ends_with("/image")) {
                    if let (Some(id), Some(target)) = (id, target) {
                        if let Some(path) = document_relative_path(&target) {
                            targets.insert(id, path);
                        }
                    }
                }
            }
            Ok(_) => {}
            Err(_) => return Ok(HashMap::new()),
        }
    }

    Ok(targets)
}

fn document_relative_path(target: &str) -> Option<String> {
    if target.is_empty() || target.starts_with('/') || target.contains('\\') {
        return None;
    }
    let mut components = Vec::new();
    for component in target.split('/') {
        match component {
            "" | "." => {}
            ".." => {
                components.pop()?;
            }
            component => components.push(component),
        }
    }
    (!components.is_empty()).then(|| format!("word/{}", components.join("/")))
}

fn parse_footnotes(zip: &mut ZipFile<'_>, encoding_name: &str) -> Result<HashMap<String, String>> {
    let Some(bytes) =
        zip.read_file_limited("word/footnotes.xml", crate::api::models::MAX_CHAPTER_SIZE)?
    else {
        return Ok(HashMap::new());
    };
    let text = decode_bytes(&bytes, encoding_name);
    let mut reader = Reader::from_str(&text);
    reader.config_mut().trim_text(false);
    let mut footnotes = HashMap::new();
    let mut current_id: Option<String> = None;
    let mut current_text = String::new();
    let mut in_text = false;

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref element)) if element.local_name().as_ref() == b"footnote" => {
                current_id = xml_attribute(element, b"id")
                    .filter(|id| id.parse::<i32>().is_ok_and(|id| id > 0));
                current_text.clear();
            }
            Ok(Event::Start(ref element)) if element.local_name().as_ref() == b"t" => {
                in_text = current_id.is_some();
            }
            Ok(Event::Text(ref value)) if in_text => {
                current_text.push_str(&value.xml10_content().unwrap_or_default());
            }
            Ok(Event::End(ref element)) if element.local_name().as_ref() == b"t" => {
                in_text = false;
            }
            Ok(Event::End(ref element)) if element.local_name().as_ref() == b"p" => {
                if !current_text.ends_with('\n') && !current_text.is_empty() {
                    current_text.push('\n');
                }
            }
            Ok(Event::End(ref element)) if element.local_name().as_ref() == b"footnote" => {
                if let Some(id) = current_id.take() {
                    let note = current_text.trim().to_string();
                    if !note.is_empty() {
                        footnotes.insert(id, note);
                    }
                }
                current_text.clear();
                in_text = false;
            }
            Ok(_) => {}
            Err(_) => return Ok(HashMap::new()),
        }
    }

    Ok(footnotes)
}

/// Extract image metadata from word/media/ without loading bytes.
/// Use `get_asset_bytes()` (RCE-10.2) for lazy data loading.
fn extract_images(zip: &mut ZipFile<'_>) -> Vec<EmbeddedImage> {
    zip.entry_names()
        .iter()
        .filter(|name| name.starts_with("word/media/"))
        .map(|name| {
            let media_type = mime_from_name(name);
            let id = name.rsplit('/').next().unwrap_or(name).to_string();
            EmbeddedImage {
                id,
                media_type,
                data: Vec::new(),
            }
        })
        .collect()
}

fn mime_from_name(name: &str) -> String {
    let ext = name.rsplit('.').next().unwrap_or("").to_lowercase();
    match ext.as_str() {
        "jpg" | "jpeg" => "image/jpeg".to_string(),
        "png" => "image/png".to_string(),
        "gif" => "image/gif".to_string(),
        "bmp" => "image/bmp".to_string(),
        "svg" => "image/svg+xml".to_string(),
        "webp" => "image/webp".to_string(),
        "tiff" | "tif" => "image/tiff".to_string(),
        _ => "application/octet-stream".to_string(),
    }
}

#[cfg(test)]
fn parse_document_xml(text: &str) -> Result<(Vec<ReaderBlock>, String)> {
    parse_document_xml_with_hyperlinks(text, &HashMap::new(), &HashMap::new(), &HashMap::new())
}

fn parse_document_xml_with_hyperlinks(
    text: &str,
    hyperlink_targets: &HashMap<String, String>,
    image_targets: &HashMap<String, String>,
    footnotes: &HashMap<String, String>,
) -> Result<(Vec<ReaderBlock>, String)> {
    let mut reader = Reader::from_str(text);
    // Whitespace between XML elements is ignored outside runs; preserve spaces
    // inside `<w:t>` so adjacent runs don't collapse words together.
    reader.config_mut().trim_text(false);
    let mut blocks: Vec<ReaderBlock> = Vec::new();
    let mut block_index = 0i32;
    let mut chapter_title = String::new();

    let mut in_body = false;
    let mut in_paragraph = false;
    let mut in_run = false;
    let mut in_pstyle = false;
    let mut in_table = false;
    let mut in_table_row = false;
    let mut in_table_cell = false;
    let mut paragraph_is_numbered = false;
    let mut paragraph_numbering_id: Option<String> = None;
    let mut pending_list_numbering_id: Option<String> = None;
    let mut pstyle_val = String::new();

    let mut current_text = String::new();
    let mut rich_spans: Vec<RichSpan> = Vec::new();
    let mut current_span_text = String::new();
    let mut current_span_bold = false;
    let mut current_span_italic = false;
    let mut current_span_href: Option<String> = None;
    let mut current_note_ref: Option<String> = None;
    let mut current_image_assets: Vec<String> = Vec::new();
    let mut table_rows: Vec<Vec<String>> = Vec::new();
    let mut current_table_row: Vec<String> = Vec::new();
    let mut current_table_cell = String::new();
    let mut pending_list_items: Vec<ReaderBlock> = Vec::new();
    let mut element_depth = 0usize;

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => {
                if element_depth != 0 {
                    anyhow::bail!("DOCX XML parse error: unclosed elements");
                }
                break;
            }
            Ok(Event::Start(ref e)) => {
                element_depth += 1;
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                match tag.as_str() {
                    "w:body" => in_body = true,
                    "w:tbl" if in_body && !in_table => {
                        flush_docx_list(&mut blocks, &mut pending_list_items, &mut block_index);
                        pending_list_numbering_id = None;
                        in_table = true;
                        table_rows.clear();
                    }
                    "w:tr" if in_table => {
                        in_table_row = true;
                        current_table_row.clear();
                    }
                    "w:tc" if in_table_row => {
                        in_table_cell = true;
                        current_table_cell.clear();
                    }
                    "w:p" if in_body => {
                        in_paragraph = true;
                        current_text.clear();
                        rich_spans.clear();
                        current_span_text.clear();
                        current_span_bold = false;
                        current_span_italic = false;
                        current_span_href = None;
                        current_note_ref = None;
                        current_image_assets.clear();
                        pstyle_val.clear();
                        paragraph_is_numbered = false;
                        paragraph_numbering_id = None;
                    }
                    "w:numPr" if in_paragraph => paragraph_is_numbered = true,
                    "w:numId" if in_paragraph && paragraph_is_numbered => {
                        paragraph_numbering_id = word_value_attribute(e);
                    }
                    "w:hyperlink" if in_paragraph => {
                        current_span_href = word_attribute(e, b"anchor")
                            .map(|anchor| format!("#{anchor}"))
                            .or_else(|| {
                                word_attribute(e, b"id")
                                    .and_then(|id| hyperlink_targets.get(&id).cloned())
                            })
                            .and_then(|href| crate::book::sanitize_href(&href));
                    }
                    "w:footnoteReference" if in_paragraph => {
                        current_note_ref =
                            word_attribute(e, b"id").filter(|id| footnotes.contains_key(id));
                    }
                    "a:blip" if in_paragraph => {
                        if let Some(asset) = word_attribute(e, b"embed")
                            .and_then(|id| image_targets.get(&id).cloned())
                        {
                            current_image_assets.push(asset);
                        }
                    }
                    "w:pStyle" if in_paragraph => {
                        for attr in e.attributes().filter_map(|a| a.ok()) {
                            if is_word_value_attribute(attr.key.as_ref()) {
                                pstyle_val = String::from_utf8_lossy(&attr.value).into_owned();
                            }
                        }
                        in_pstyle = true;
                    }
                    "w:r" if in_paragraph => {
                        in_run = true;
                        current_span_text.clear();
                        current_span_bold = false;
                        current_span_italic = false;
                    }
                    "w:b" if in_run => current_span_bold = word_bool_value(e),
                    "w:i" if in_run => current_span_italic = word_bool_value(e),
                    "w:tab" if in_run => {
                        current_span_text.push('\t');
                    }
                    "w:br" if in_run => {
                        current_span_text.push('\n');
                    }
                    _ => {}
                }
            }
            Ok(Event::Text(ref e)) => {
                let text = e.xml10_content().unwrap_or_default().to_string();
                if in_run && in_paragraph {
                    current_span_text.push_str(&text);
                } else if in_pstyle {
                    pstyle_val.push_str(&text);
                }
            }
            Ok(Event::CData(ref e)) => {
                let text = e.xml10_content().unwrap_or_default();
                if in_run && in_paragraph {
                    current_span_text.push_str(&text);
                } else if in_pstyle {
                    pstyle_val.push_str(&text);
                }
            }
            Ok(Event::GeneralRef(ref e)) => {
                let text = e.xml10_content().unwrap_or_default();
                if in_run && in_paragraph {
                    current_span_text.push_str(&text);
                } else if in_pstyle {
                    pstyle_val.push_str(&text);
                }
            }
            Ok(Event::End(ref e)) => {
                element_depth = element_depth
                    .checked_sub(1)
                    .ok_or_else(|| anyhow::anyhow!("DOCX XML parse error: unexpected end tag"))?;
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                match tag.as_str() {
                    "w:body" => {
                        flush_docx_list(&mut blocks, &mut pending_list_items, &mut block_index);
                        pending_list_numbering_id = None;
                        in_body = false;
                    }
                    "w:pStyle" => in_pstyle = false,
                    "w:r" if in_paragraph => {
                        if !current_span_text.is_empty() {
                            rich_spans.push(RichSpan {
                                text: current_span_text.clone(),
                                bold: current_span_bold,
                                italic: current_span_italic,
                                superscript: false,
                                href: current_span_href.clone(),
                                line_break: false,
                            });
                        }
                        current_span_text.clear();
                        in_run = false;
                    }
                    "w:p" if in_paragraph => {
                        // Combine all span texts for the block text field
                        let full_text: String =
                            rich_spans.iter().map(|s| s.text.as_str()).collect();
                        let trimmed = full_text.trim().to_string();

                        if in_table_cell {
                            if !trimmed.is_empty() {
                                if !current_table_cell.is_empty() {
                                    current_table_cell.push('\n');
                                }
                                current_table_cell.push_str(&trimmed);
                            }
                        } else if !trimmed.is_empty() {
                            let is_heading = pstyle_val.starts_with("Heading")
                                || pstyle_val.starts_with("Title")
                                || pstyle_val.starts_with("Subtitle");

                            let block_type = if is_heading {
                                BlockType::Heading
                            } else {
                                BlockType::Paragraph
                            };

                            if is_heading && chapter_title.is_empty() {
                                chapter_title = trimmed.clone();
                            }

                            let has_formatting = rich_spans
                                .iter()
                                .any(|s| s.bold || s.italic || s.superscript || s.href.is_some());

                            let mut paragraph = ReaderBlock {
                                index: block_index + pending_list_items.len() as i32,
                                text: trimmed,
                                block_type,
                                image_url: None,
                                note_ref: current_note_ref.take(),
                                rich_spans: if has_formatting {
                                    Some(rich_spans.clone())
                                } else {
                                    None
                                },
                                heading_level: None,
                                ordered: None,
                                list_items: None,
                                table_rows: None,
                                image_alt: None,
                                text_indent: None,
                                text_align: None,
                                note_id: None,
                            };
                            if paragraph_is_numbered {
                                if pending_list_numbering_id != paragraph_numbering_id {
                                    flush_docx_list(
                                        &mut blocks,
                                        &mut pending_list_items,
                                        &mut block_index,
                                    );
                                    pending_list_numbering_id = paragraph_numbering_id.clone();
                                }
                                pending_list_items.push(paragraph);
                            } else {
                                flush_docx_list(
                                    &mut blocks,
                                    &mut pending_list_items,
                                    &mut block_index,
                                );
                                pending_list_numbering_id = None;
                                paragraph.index = block_index;
                                blocks.push(paragraph);
                                block_index += 1;
                            }
                        } else if !in_table_cell {
                            flush_docx_list(&mut blocks, &mut pending_list_items, &mut block_index);
                            pending_list_numbering_id = None;
                        }

                        if !in_table_cell && !current_image_assets.is_empty() {
                            flush_docx_list(&mut blocks, &mut pending_list_items, &mut block_index);
                            pending_list_numbering_id = None;
                            for image_url in std::mem::take(&mut current_image_assets) {
                                blocks.push(ReaderBlock {
                                    index: block_index,
                                    text: String::new(),
                                    block_type: BlockType::Image,
                                    image_url: Some(image_url),
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

                        in_paragraph = false;
                        rich_spans.clear();
                        current_span_text.clear();
                        current_span_href = None;
                        current_note_ref = None;
                    }
                    "w:hyperlink" if in_paragraph => current_span_href = None,
                    "w:tc" if in_table_cell => {
                        current_table_row.push(current_table_cell.trim().to_string());
                        current_table_cell.clear();
                        in_table_cell = false;
                    }
                    "w:tr" if in_table_row => {
                        if !current_table_row.is_empty() {
                            table_rows.push(std::mem::take(&mut current_table_row));
                        }
                        in_table_row = false;
                    }
                    "w:tbl" if in_table => {
                        if !table_rows.is_empty() {
                            let table_text = table_rows
                                .iter()
                                .map(|row| row.join(" | "))
                                .collect::<Vec<_>>()
                                .join("\n");
                            blocks.push(ReaderBlock {
                                index: block_index,
                                text: table_text,
                                block_type: BlockType::Table,
                                image_url: None,
                                note_ref: None,
                                rich_spans: None,
                                heading_level: None,
                                ordered: None,
                                list_items: None,
                                table_rows: Some(std::mem::take(&mut table_rows)),
                                image_alt: None,
                                text_indent: None,
                                text_align: None,
                                note_id: None,
                            });
                            block_index += 1;
                        }
                        in_table = false;
                    }
                    _ => {}
                }
            }
            Ok(Event::Empty(ref e)) => {
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                match tag.as_str() {
                    "w:pStyle" if in_paragraph => {
                        for attr in e.attributes().filter_map(|attr| attr.ok()) {
                            if is_word_value_attribute(attr.key.as_ref()) {
                                pstyle_val = String::from_utf8_lossy(&attr.value).into_owned();
                            }
                        }
                    }
                    "w:numPr" if in_paragraph => paragraph_is_numbered = true,
                    "w:numId" if in_paragraph && paragraph_is_numbered => {
                        paragraph_numbering_id = word_value_attribute(e);
                    }
                    "w:footnoteReference" if in_paragraph => {
                        current_note_ref =
                            word_attribute(e, b"id").filter(|id| footnotes.contains_key(id));
                    }
                    "a:blip" if in_paragraph => {
                        if let Some(asset) = word_attribute(e, b"embed")
                            .and_then(|id| image_targets.get(&id).cloned())
                        {
                            current_image_assets.push(asset);
                        }
                    }
                    "w:b" if in_run => current_span_bold = word_bool_value(e),
                    "w:i" if in_run => current_span_italic = word_bool_value(e),
                    "w:tab" if in_run => current_span_text.push('\t'),
                    "w:br" if in_run => current_span_text.push('\n'),
                    _ => {}
                }
            }
            Err(error) => anyhow::bail!("DOCX XML parse error: {error}"),
            _ => {}
        }
    }

    Ok((blocks, chapter_title))
}

fn word_bool_value(element: &BytesStart<'_>) -> bool {
    match element
        .attributes()
        .filter_map(|attribute| attribute.ok())
        .find(|attribute| is_word_value_attribute(attribute.key.as_ref()))
    {
        Some(attribute) => !matches!(
            String::from_utf8_lossy(&attribute.value)
                .to_lowercase()
                .as_str(),
            "0" | "false" | "off"
        ),
        None => true,
    }
}

fn is_word_value_attribute(key: &[u8]) -> bool {
    key == b"val" || key.ends_with(b":val")
}

fn word_value_attribute(element: &BytesStart<'_>) -> Option<String> {
    word_attribute(element, b"val")
}

fn word_attribute(element: &BytesStart<'_>, name: &[u8]) -> Option<String> {
    element
        .attributes()
        .filter_map(|attribute| attribute.ok())
        .find(|attribute| attribute.key.local_name().as_ref() == name)
        .map(|attribute| String::from_utf8_lossy(&attribute.value).into_owned())
}

fn xml_attribute(element: &BytesStart<'_>, name: &[u8]) -> Option<String> {
    word_attribute(element, name)
}

fn flush_docx_list(
    blocks: &mut Vec<ReaderBlock>,
    pending_items: &mut Vec<ReaderBlock>,
    block_index: &mut i32,
) {
    if pending_items.is_empty() {
        return;
    }
    let items = std::mem::take(pending_items);
    let text = items
        .iter()
        .map(|item| item.text.as_str())
        .collect::<Vec<_>>()
        .join("\n");
    blocks.push(ReaderBlock {
        index: *block_index,
        text,
        block_type: BlockType::List,
        image_url: None,
        note_ref: None,
        rich_spans: None,
        heading_level: None,
        ordered: Some(true),
        list_items: Some(items),
        table_rows: None,
        image_alt: None,
        text_indent: None,
        text_align: None,
        note_id: None,
    });
    *block_index += 1;
}

#[cfg(test)]
mod tests {
    use super::{parse_document_xml, parse_document_xml_with_hyperlinks, parse_docx};
    use std::collections::HashMap;
    use std::io::{Cursor, Write};

    fn malformed_docx() -> Vec<u8> {
        let mut bytes = Cursor::new(Vec::new());
        let mut zip = zip::ZipWriter::new(&mut bytes);
        let options = zip::write::FileOptions::<()>::default()
            .compression_method(zip::CompressionMethod::Stored);
        zip.start_file("docProps/core.xml", options)
            .expect("start core properties");
        zip.write_all(
            br#"<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"/>"#,
        )
        .expect("write core properties");
        zip.start_file("word/document.xml", options)
            .expect("start document XML");
        zip.write_all(
            br#"<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>unterminated"#,
        )
        .expect("write malformed document XML");
        zip.finish().expect("finish DOCX archive");
        bytes.into_inner()
    }

    #[test]
    fn rejects_malformed_document_xml() {
        let error = parse_docx(&malformed_docx(), None)
            .expect_err("malformed document XML must not produce a partial book");

        assert!(error.to_string().contains("DOCX XML parse error"));
    }

    #[test]
    fn preserves_formatting_from_empty_run_property_tags() {
        let xml = r#"
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                <w:body><w:p>
                    <w:r><w:rPr><w:b/></w:rPr><w:t>Bold</w:t></w:r>
                    <w:r><w:rPr><w:i/></w:rPr><w:t>Italic</w:t></w:r>
                </w:p></w:body>
            </w:document>
        "#;

        let (blocks, _) = parse_document_xml(xml).expect("parse DOCX XML");
        let spans = blocks[0].rich_spans.as_ref().expect("formatted spans");

        assert!(spans[0].bold);
        assert!(!spans[0].italic);
        assert!(!spans[1].bold);
        assert!(spans[1].italic);
    }

    #[test]
    fn reads_namespaced_word_value_attributes() {
        let xml = r#"
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                <w:body><w:p>
                    <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
                    <w:r><w:rPr><w:b/><w:i w:val="0"/></w:rPr><w:t>Heading</w:t></w:r>
                </w:p></w:body>
            </w:document>
        "#;

        let (blocks, _) = parse_document_xml(xml).expect("parse DOCX XML");
        let span = &blocks[0].rich_spans.as_ref().expect("formatted span")[0];

        assert_eq!(blocks[0].block_type, crate::api::models::BlockType::Heading);
        assert!(span.bold);
        assert!(!span.italic);
    }

    #[test]
    fn preserves_self_closing_tabs_in_runs() {
        let xml = r#"
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                <w:body><w:p><w:r><w:t>Before</w:t><w:tab/><w:t>After</w:t></w:r></w:p></w:body>
            </w:document>
        "#;

        let (blocks, _) = parse_document_xml(xml).expect("parse DOCX XML");

        assert_eq!(blocks[0].text, "Before\tAfter");
    }

    #[test]
    fn preserves_docx_tables_as_table_blocks() {
        let xml = r#"
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                <w:body><w:tbl>
                    <w:tr><w:tc><w:p><w:r><w:t>Name</w:t></w:r></w:p></w:tc>
                          <w:tc><w:p><w:r><w:t>Value</w:t></w:r></w:p></w:tc></w:tr>
                    <w:tr><w:tc><w:p><w:r><w:t>Author</w:t></w:r></w:p></w:tc>
                          <w:tc><w:p><w:r><w:t>Ursula</w:t></w:r></w:p></w:tc></w:tr>
                </w:tbl></w:body>
            </w:document>
        "#;

        let (blocks, _) = parse_document_xml(xml).expect("parse DOCX table");

        assert_eq!(blocks.len(), 1);
        assert_eq!(blocks[0].block_type, crate::api::models::BlockType::Table);
        assert_eq!(
            blocks[0].table_rows,
            Some(vec![
                vec!["Name".into(), "Value".into()],
                vec!["Author".into(), "Ursula".into()],
            ])
        );
    }

    #[test]
    fn groups_consecutive_numbered_paragraphs_into_an_ordered_list() {
        let xml = r#"
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                <w:body>
                    <w:p><w:pPr><w:numPr><w:numId w:val="42"/></w:numPr></w:pPr>
                      <w:r><w:t>First</w:t></w:r></w:p>
                    <w:p><w:pPr><w:numPr><w:numId w:val="42"/></w:numPr></w:pPr>
                      <w:r><w:t>Second</w:t></w:r></w:p>
                    <w:p><w:r><w:t>After the list</w:t></w:r></w:p>
                </w:body>
            </w:document>
        "#;

        let (blocks, _) = parse_document_xml(xml).expect("parse DOCX list");

        assert_eq!(blocks.len(), 2);
        assert_eq!(blocks[0].block_type, crate::api::models::BlockType::List);
        assert_eq!(blocks[0].ordered, Some(true));
        assert_eq!(
            blocks[0]
                .list_items
                .as_ref()
                .expect("list items")
                .iter()
                .map(|item| item.text.as_str())
                .collect::<Vec<_>>(),
            ["First", "Second"]
        );
        assert_eq!(blocks[1].text, "After the list");
    }

    #[test]
    fn preserves_external_and_bookmark_hyperlinks() {
        let xml = r#"
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
                <w:body><w:p>
                    <w:r><w:t>See </w:t></w:r>
                    <w:hyperlink r:id="rId7"><w:r><w:t>website</w:t></w:r></w:hyperlink>
                    <w:r><w:t> and </w:t></w:r>
                    <w:hyperlink w:anchor="chapter-2"><w:r><w:t>chapter</w:t></w:r></w:hyperlink>
                </w:p></w:body>
            </w:document>
        "#;
        let hyperlinks =
            HashMap::from([(String::from("rId7"), String::from("https://example.com"))]);

        let (blocks, _) =
            parse_document_xml_with_hyperlinks(xml, &hyperlinks, &HashMap::new(), &HashMap::new())
                .expect("parse DOCX links");
        let spans = blocks[0].rich_spans.as_ref().expect("rich spans");

        assert_eq!(blocks[0].text, "See website and chapter");
        assert_eq!(spans[1].href.as_deref(), Some("https://example.com"));
        assert_eq!(spans[3].href.as_deref(), Some("#chapter-2"));
    }

    #[test]
    fn resolves_external_hyperlinks_from_document_relationships() {
        let mut bytes = Cursor::new(Vec::new());
        let mut zip = zip::ZipWriter::new(&mut bytes);
        let options = zip::write::FileOptions::<()>::default()
            .compression_method(zip::CompressionMethod::Stored);
        zip.start_file("docProps/core.xml", options)
            .expect("start core properties");
        zip.write_all(
            br#"<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"/>"#,
        )
        .expect("write core properties");
        zip.start_file("word/document.xml", options)
            .expect("start document XML");
        zip.write_all(
            br#"<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body><w:p><w:hyperlink r:id="rId1"><w:r><w:t>Website</w:t></w:r></w:hyperlink></w:p></w:body></w:document>"#,
        )
        .expect("write document XML");
        zip.start_file("word/_rels/document.xml.rels", options)
            .expect("start relationships XML");
        zip.write_all(
            br#"<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://example.com" TargetMode="External"/></Relationships>"#,
        )
        .expect("write relationships XML");
        zip.finish().expect("finish DOCX archive");

        let book = parse_docx(&bytes.into_inner(), None).expect("parse DOCX with hyperlink");
        let spans = book.chapters[0].blocks[0]
            .rich_spans
            .as_ref()
            .expect("rich spans");

        assert_eq!(spans[0].href.as_deref(), Some("https://example.com"));
    }

    #[test]
    fn exposes_drawing_relationships_as_image_blocks() {
        let mut bytes = Cursor::new(Vec::new());
        let mut zip = zip::ZipWriter::new(&mut bytes);
        let options = zip::write::FileOptions::<()>::default()
            .compression_method(zip::CompressionMethod::Stored);
        zip.start_file("docProps/core.xml", options)
            .expect("start core properties");
        zip.write_all(
            br#"<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"/>"#,
        )
        .expect("write core properties");
        zip.start_file("word/document.xml", options)
            .expect("start document XML");
        zip.write_all(
            br#"<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body><w:p><w:r><w:drawing><a:blip r:embed="rIdImage"/></w:drawing></w:r></w:p></w:body></w:document>"#,
        )
        .expect("write document XML");
        zip.start_file("word/_rels/document.xml.rels", options)
            .expect("start relationships XML");
        zip.write_all(
            br#"<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rIdImage" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/></Relationships>"#,
        )
        .expect("write relationships XML");
        zip.start_file("word/media/image1.png", options)
            .expect("start image");
        zip.write_all(b"PNG").expect("write image");
        zip.finish().expect("finish DOCX archive");

        let archive = bytes.into_inner();
        let book = parse_docx(&archive, None).expect("parse DOCX image");

        assert_eq!(book.chapters[0].blocks.len(), 1);
        assert_eq!(
            book.chapters[0].blocks[0].block_type,
            crate::api::models::BlockType::Image
        );
        assert_eq!(
            book.chapters[0].blocks[0].image_url.as_deref(),
            Some("word/media/image1.png")
        );

        let path =
            std::env::temp_dir().join(format!("glibusta-docx-image-{}.docx", uuid::Uuid::new_v4()));
        std::fs::write(&path, archive).expect("write DOCX fixture");
        let image = crate::api::api::get_asset_bytes(
            path.to_string_lossy().into_owned(),
            "word/media/image1.png".to_string(),
        );
        let _ = std::fs::remove_file(path);

        assert_eq!(image.expect("extract DOCX image"), b"PNG");
    }

    #[test]
    fn extracts_docx_footnotes_and_links_references() {
        let mut bytes = Cursor::new(Vec::new());
        let mut zip = zip::ZipWriter::new(&mut bytes);
        let options = zip::write::FileOptions::<()>::default()
            .compression_method(zip::CompressionMethod::Stored);
        zip.start_file("docProps/core.xml", options)
            .expect("start core properties");
        zip.write_all(
            br#"<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"/>"#,
        )
        .expect("write core properties");
        zip.start_file("word/document.xml", options)
            .expect("start document XML");
        zip.write_all(
            br#"<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Text</w:t></w:r><w:r><w:footnoteReference w:id="1"/></w:r></w:p></w:body></w:document>"#,
        )
        .expect("write document XML");
        zip.start_file("word/footnotes.xml", options)
            .expect("start footnotes XML");
        zip.write_all(
            br#"<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:footnote w:id="-1"><w:p><w:r><w:t>separator</w:t></w:r></w:p></w:footnote><w:footnote w:id="1"><w:p><w:r><w:t>Footnote text</w:t></w:r></w:p></w:footnote></w:footnotes>"#,
        )
        .expect("write footnotes XML");
        zip.finish().expect("finish DOCX archive");

        let book = parse_docx(&bytes.into_inner(), None).expect("parse DOCX footnote");

        assert_eq!(book.chapters[0].blocks[0].note_ref.as_deref(), Some("1"));
        assert_eq!(
            book.metadata
                .as_ref()
                .and_then(|metadata| metadata["footnotes"]["1"].as_str()),
            Some("Footnote text")
        );
    }
}
