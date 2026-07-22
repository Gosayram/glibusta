use crate::api::models::{
    BlockType, BookFormat, EmbeddedImage, NormalizedBook, ReaderBlock, ReaderChapter, RichSpan,
};
use crate::book::archive::{self, ZipFile};
use crate::book::encoding::{decode_bytes, detect_encoding};
use anyhow::{Context, Result};
use quick_xml::Reader;
use quick_xml::events::{BytesStart, Event};
use serde::Deserialize;
use std::collections::HashMap;

type ListNumberingKey = (String, String);

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

    let (title, authors, created_date) = parse_core_properties(&mut zip, forced_encoding)?;

    let document_xml = zip
        .read_file_limited("word/document.xml", crate::api::models::MAX_CHAPTER_SIZE)?
        .context("DOCX missing word/document.xml")?;
    let doc_text = decode_docx_xml(&document_xml, forced_encoding);

    let hyperlink_targets = parse_hyperlink_relationships(&mut zip, forced_encoding)?;
    let image_targets = parse_image_relationships(&mut zip, forced_encoding)?;
    let mut footnotes = parse_footnotes(&mut zip, forced_encoding)?;
    footnotes.extend(parse_endnotes(&mut zip, forced_encoding)?);
    let numbering_styles = parse_numbering_styles(&mut zip, forced_encoding)?;
    let (blocks, chapter_title) = parse_document_xml_with_hyperlinks(
        &doc_text,
        &hyperlink_targets,
        &image_targets,
        &footnotes,
        &numbering_styles,
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
    // Office documents commonly contain unsupported preview/vector assets (for
    // example EMF) before the first reader-renderable bitmap.  Do not turn
    // those into a `data:application/octet-stream` cover when a usable image
    // exists later in `word/media/`.
    let cover_url = if let Some(img) = images
        .iter()
        .find(|img| is_cover_image_type(&img.media_type))
    {
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

/// DOCX XML parts are normally UTF-8, but OPC/XML also permits UTF-16 parts.
/// An explicit user choice remains authoritative; otherwise use the BOM, a
/// valid XML declaration, then the existing charset fallback for each part.
fn decode_docx_xml(bytes: &[u8], forced_encoding: Option<&str>) -> String {
    let (bytes, bom_encoding) = match bytes {
        [0xEF, 0xBB, 0xBF, rest @ ..] => (rest, Some("utf-8")),
        [0xFF, 0xFE, rest @ ..] => (rest, Some("utf-16le")),
        [0xFE, 0xFF, rest @ ..] => (rest, Some("utf-16be")),
        _ => (bytes, None),
    };
    let encoding = forced_encoding
        .or(bom_encoding)
        .or_else(|| utf16_encoding_without_bom(bytes))
        .or_else(|| xml_declared_encoding(bytes).filter(is_supported_encoding))
        .unwrap_or_else(|| detect_encoding(bytes));

    decode_bytes(bytes, encoding)
}

fn utf16_encoding_without_bom(bytes: &[u8]) -> Option<&'static str> {
    match bytes {
        [b'<', 0, ..] => Some("utf-16le"),
        [0, b'<', ..] => Some("utf-16be"),
        _ => None,
    }
}

fn is_supported_encoding(label: &&str) -> bool {
    encoding_rs::Encoding::for_label_no_replacement(label.as_bytes()).is_some()
}

/// Extract a declared encoding from the bounded ASCII XML declaration. UTF-16
/// declarations without a BOM are handled before this because their bytes are
/// not ASCII-compatible.
fn xml_declared_encoding(bytes: &[u8]) -> Option<&str> {
    let declaration_end = bytes
        .get(..bytes.len().min(1024))?
        .windows(2)
        .position(|window| window == b"?>")?;
    let declaration = std::str::from_utf8(&bytes[..declaration_end]).ok()?;
    let lower = declaration.to_ascii_lowercase();
    let encoding_start = lower.find("encoding")? + "encoding".len();
    let value = declaration[encoding_start..]
        .trim_start()
        .strip_prefix('=')?
        .trim_start();
    let quote = value.chars().next()?;
    if quote != '\'' && quote != '\"' {
        return None;
    }
    let value = &value[quote.len_utf8()..];
    let end = value.find(quote)?;
    Some(&value[..end])
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
    forced_encoding: Option<&str>,
) -> Result<(String, Vec<String>, String)> {
    let props_bytes = zip
        .read_file_limited("docProps/core.xml", crate::api::models::MAX_CHAPTER_SIZE)?
        .context("DOCX missing docProps/core.xml")?;
    let props_text = decode_docx_xml(&props_bytes, forced_encoding);

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
    forced_encoding: Option<&str>,
) -> Result<HashMap<String, String>> {
    let Some(bytes) = zip.read_file_limited(
        "word/_rels/document.xml.rels",
        crate::api::models::MAX_CHAPTER_SIZE,
    )?
    else {
        return Ok(HashMap::new());
    };
    let text = decode_docx_xml(&bytes, forced_encoding);
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
    forced_encoding: Option<&str>,
) -> Result<HashMap<String, String>> {
    let Some(bytes) = zip.read_file_limited(
        "word/_rels/document.xml.rels",
        crate::api::models::MAX_CHAPTER_SIZE,
    )?
    else {
        return Ok(HashMap::new());
    };
    let text = decode_docx_xml(&bytes, forced_encoding);
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
    // Relationship targets are resolved relative to `word/document.xml`, whose
    // parent is `word/`. Starting there also accepts valid OPC paths such as
    // `../word/media/image.png` without allowing a target to escape the
    // package root.
    let mut components = vec!["word"];
    for component in target.split('/') {
        match component {
            "" | "." => {}
            ".." => {
                components.pop()?;
            }
            component => components.push(component),
        }
    }
    (!components.is_empty()).then(|| components.join("/"))
}

fn parse_footnotes(
    zip: &mut ZipFile<'_>,
    forced_encoding: Option<&str>,
) -> Result<HashMap<String, String>> {
    parse_notes(zip, forced_encoding, "word/footnotes.xml", b"footnote")
}

fn parse_endnotes(
    zip: &mut ZipFile<'_>,
    forced_encoding: Option<&str>,
) -> Result<HashMap<String, String>> {
    Ok(
        parse_notes(zip, forced_encoding, "word/endnotes.xml", b"endnote")?
            .into_iter()
            .map(|(id, text)| (format!("endnote:{id}"), text))
            .collect(),
    )
}

fn parse_notes(
    zip: &mut ZipFile<'_>,
    forced_encoding: Option<&str>,
    entry_name: &str,
    note_element: &[u8],
) -> Result<HashMap<String, String>> {
    let Some(bytes) = zip.read_file_limited(entry_name, crate::api::models::MAX_CHAPTER_SIZE)?
    else {
        return Ok(HashMap::new());
    };
    let text = decode_docx_xml(&bytes, forced_encoding);
    let mut reader = Reader::from_str(&text);
    reader.config_mut().trim_text(false);
    let mut footnotes = HashMap::new();
    let mut current_id: Option<String> = None;
    let mut current_text = String::new();
    let mut in_text = false;

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref element)) if element.local_name().as_ref() == note_element => {
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
            Ok(Event::End(ref element)) if element.local_name().as_ref() == note_element => {
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

/// Resolve Word's `numId` and nesting level to whether it is an ordered list.
/// DOCX keeps this information in `word/numbering.xml`, separate from the
/// paragraphs that reference it.
fn parse_numbering_styles(
    zip: &mut ZipFile<'_>,
    forced_encoding: Option<&str>,
) -> Result<HashMap<ListNumberingKey, bool>> {
    let Some(bytes) =
        zip.read_file_limited("word/numbering.xml", crate::api::models::MAX_CHAPTER_SIZE)?
    else {
        return Ok(HashMap::new());
    };
    let text = decode_docx_xml(&bytes, forced_encoding);

    let mut reader = Reader::from_str(&text);
    let mut abstract_levels = HashMap::<ListNumberingKey, bool>::new();
    let mut abstract_id: Option<String> = None;
    let mut level: Option<String> = None;
    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref element)) | Ok(Event::Empty(ref element)) => {
                match element.local_name().as_ref() {
                    b"abstractNum" => abstract_id = word_attribute(element, b"abstractNumId"),
                    b"lvl" => level = word_attribute(element, b"ilvl"),
                    b"numFmt" => {
                        if let (Some(abstract_id), Some(level), Some(format)) = (
                            abstract_id.as_ref(),
                            level.as_ref(),
                            word_value_attribute(element),
                        ) {
                            abstract_levels.insert(
                                (abstract_id.clone(), level.clone()),
                                !format.eq_ignore_ascii_case("bullet"),
                            );
                        }
                    }
                    _ => {}
                }
            }
            Ok(Event::End(ref element)) => match element.local_name().as_ref() {
                b"abstractNum" => abstract_id = None,
                b"lvl" => level = None,
                _ => {}
            },
            Err(_) => return Ok(HashMap::new()),
            Ok(_) => {}
        }
    }

    let mut reader = Reader::from_str(&text);
    let mut styles = HashMap::new();
    let mut num_id: Option<String> = None;
    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref element)) | Ok(Event::Empty(ref element)) => {
                match element.local_name().as_ref() {
                    b"num" => num_id = word_attribute(element, b"numId"),
                    b"abstractNumId" => {
                        if let (Some(num_id), Some(abstract_id)) =
                            (num_id.as_ref(), word_value_attribute(element))
                        {
                            for ((resolved_abstract_id, level), ordered) in &abstract_levels {
                                if resolved_abstract_id == &abstract_id {
                                    styles.insert((num_id.clone(), level.clone()), *ordered);
                                }
                            }
                        }
                    }
                    _ => {}
                }
            }
            Ok(Event::End(ref element)) if element.local_name().as_ref() == b"num" => {
                num_id = None;
            }
            Err(_) => return Ok(HashMap::new()),
            Ok(_) => {}
        }
    }
    Ok(styles)
}

/// Extract image metadata from word/media/ without loading bytes.
/// Use `get_asset_bytes()` (RCE-10.2) for lazy data loading.
fn extract_images(zip: &mut ZipFile<'_>) -> Vec<EmbeddedImage> {
    zip.entry_names()
        .iter()
        .filter(|name| name.starts_with("word/media/"))
        .map(|name| {
            let media_type = mime_from_name(name);
            let id = name.strip_prefix("word/media/").unwrap_or(name).to_string();
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

/// Formats backed by Flutter's byte-image codecs on the supported platforms.
/// SVG needs a separate vector renderer and TIFF/Office vector formats are not
/// accepted by `Image.memory`, so they remain available as lazy assets but are
/// not selected as the library cover.
fn is_cover_image_type(media_type: &str) -> bool {
    matches!(
        media_type,
        "image/jpeg" | "image/png" | "image/gif" | "image/bmp" | "image/webp"
    )
}

#[cfg(test)]
fn parse_document_xml(text: &str) -> Result<(Vec<ReaderBlock>, String)> {
    parse_document_xml_with_hyperlinks(
        text,
        &HashMap::new(),
        &HashMap::new(),
        &HashMap::new(),
        &HashMap::new(),
    )
}

fn parse_document_xml_with_hyperlinks(
    text: &str,
    hyperlink_targets: &HashMap<String, String>,
    image_targets: &HashMap<String, String>,
    footnotes: &HashMap<String, String>,
    numbering_styles: &HashMap<ListNumberingKey, bool>,
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
    let mut table_depth = 0usize;
    let mut in_table_row = false;
    let mut in_table_cell = false;
    let mut paragraph_is_numbered = false;
    let mut paragraph_numbering_id: Option<String> = None;
    let mut paragraph_numbering_level: Option<String> = None;
    let mut pending_list_numbering_key: Option<ListNumberingKey> = None;
    let mut pending_list_ordered = true;
    let mut pstyle_val = String::new();

    let mut current_text = String::new();
    let mut rich_spans: Vec<RichSpan> = Vec::new();
    let mut current_span_text = String::new();
    let mut current_span_bold = false;
    let mut current_span_italic = false;
    let mut current_span_superscript = false;
    let mut current_span_subscript = false;
    let mut current_span_strikethrough = false;
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
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                match tag.as_str() {
                    "body" => in_body = true,
                    "tbl" if in_body => {
                        if table_depth == 0 {
                            flush_docx_list(
                                &mut blocks,
                                &mut pending_list_items,
                                &mut block_index,
                                pending_list_ordered,
                            );
                            pending_list_numbering_key = None;
                            table_rows.clear();
                        }
                        table_depth += 1;
                    }
                    "tr" if table_depth == 1 => {
                        in_table_row = true;
                        current_table_row.clear();
                    }
                    "tc" if table_depth == 1 && in_table_row => {
                        in_table_cell = true;
                        current_table_cell.clear();
                    }
                    "p" if in_body => {
                        in_paragraph = true;
                        current_text.clear();
                        rich_spans.clear();
                        current_span_text.clear();
                        current_span_bold = false;
                        current_span_italic = false;
                        current_span_superscript = false;
                        current_span_subscript = false;
                        current_span_strikethrough = false;
                        current_span_href = None;
                        current_note_ref = None;
                        current_image_assets.clear();
                        pstyle_val.clear();
                        paragraph_is_numbered = false;
                        paragraph_numbering_id = None;
                        paragraph_numbering_level = None;
                    }
                    "numPr" if in_paragraph => paragraph_is_numbered = true,
                    "numId" if in_paragraph && paragraph_is_numbered => {
                        paragraph_numbering_id = word_value_attribute(e);
                    }
                    "ilvl" if in_paragraph && paragraph_is_numbered => {
                        paragraph_numbering_level = word_value_attribute(e);
                    }
                    "hyperlink" if in_paragraph => {
                        current_span_href = word_attribute(e, b"anchor")
                            .map(|anchor| format!("#{anchor}"))
                            .or_else(|| {
                                word_attribute(e, b"id")
                                    .and_then(|id| hyperlink_targets.get(&id).cloned())
                            })
                            .and_then(|href| crate::book::sanitize_href(&href));
                    }
                    "footnoteReference" if in_paragraph => {
                        current_note_ref =
                            word_attribute(e, b"id").filter(|id| footnotes.contains_key(id));
                    }
                    "endnoteReference" if in_paragraph => {
                        current_note_ref = word_attribute(e, b"id")
                            .map(|id| format!("endnote:{id}"))
                            .filter(|id| footnotes.contains_key(id));
                    }
                    "blip" if in_paragraph => {
                        if let Some(asset) = word_attribute(e, b"embed")
                            .and_then(|id| image_targets.get(&id).cloned())
                        {
                            current_image_assets.push(asset);
                        }
                    }
                    "pStyle" if in_paragraph => {
                        for attr in e.attributes().filter_map(|a| a.ok()) {
                            if is_word_value_attribute(attr.key.as_ref()) {
                                pstyle_val = String::from_utf8_lossy(&attr.value).into_owned();
                            }
                        }
                        in_pstyle = true;
                    }
                    "r" if in_paragraph => {
                        in_run = true;
                        current_span_text.clear();
                        current_span_bold = false;
                        current_span_italic = false;
                        current_span_superscript = false;
                        current_span_subscript = false;
                        current_span_strikethrough = false;
                    }
                    "b" if in_run => current_span_bold = word_bool_value(e),
                    "i" if in_run => current_span_italic = word_bool_value(e),
                    "strike" | "dstrike" if in_run => {
                        current_span_strikethrough = word_bool_value(e);
                    }
                    "vertAlign" if in_run => match word_value_attribute(e).as_deref() {
                        Some(value) if value.eq_ignore_ascii_case("superscript") => {
                            current_span_superscript = true;
                            current_span_subscript = false;
                        }
                        Some(value) if value.eq_ignore_ascii_case("subscript") => {
                            current_span_subscript = true;
                            current_span_superscript = false;
                        }
                        _ => {
                            current_span_superscript = false;
                            current_span_subscript = false;
                        }
                    },
                    "tab" if in_run => {
                        current_span_text.push('\t');
                    }
                    "br" if in_run => {
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
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                match tag.as_str() {
                    "body" => {
                        flush_docx_list(
                            &mut blocks,
                            &mut pending_list_items,
                            &mut block_index,
                            pending_list_ordered,
                        );
                        pending_list_numbering_key = None;
                        in_body = false;
                    }
                    "pStyle" => in_pstyle = false,
                    "r" if in_paragraph => {
                        if !current_span_text.is_empty() {
                            rich_spans.push(RichSpan {
                                text: current_span_text.clone(),
                                bold: current_span_bold,
                                italic: current_span_italic,
                                superscript: current_span_superscript,
                                subscript: current_span_subscript,
                                strikethrough: current_span_strikethrough,
                                code: false,
                                style_name: None,
                                href: current_span_href.clone(),
                                line_break: false,
                            });
                        }
                        current_span_text.clear();
                        in_run = false;
                    }
                    "p" if in_paragraph => {
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

                            let has_formatting = rich_spans.iter().any(|s| {
                                s.bold
                                    || s.italic
                                    || s.superscript
                                    || s.subscript
                                    || s.strikethrough
                                    || s.href.is_some()
                            });

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
                                let numbering_key =
                                    paragraph_numbering_id.clone().map(|numbering_id| {
                                        (
                                            numbering_id,
                                            paragraph_numbering_level.clone().unwrap_or_default(),
                                        )
                                    });
                                let ordered = numbering_key
                                    .as_ref()
                                    .and_then(|key| numbering_styles.get(key))
                                    .copied()
                                    .unwrap_or(true);
                                if pending_list_numbering_key != numbering_key {
                                    flush_docx_list(
                                        &mut blocks,
                                        &mut pending_list_items,
                                        &mut block_index,
                                        pending_list_ordered,
                                    );
                                    pending_list_numbering_key = numbering_key;
                                    pending_list_ordered = ordered;
                                }
                                pending_list_items.push(paragraph);
                            } else {
                                flush_docx_list(
                                    &mut blocks,
                                    &mut pending_list_items,
                                    &mut block_index,
                                    pending_list_ordered,
                                );
                                pending_list_numbering_key = None;
                                paragraph.index = block_index;
                                blocks.push(paragraph);
                                block_index += 1;
                            }
                        } else if !in_table_cell {
                            flush_docx_list(
                                &mut blocks,
                                &mut pending_list_items,
                                &mut block_index,
                                pending_list_ordered,
                            );
                            pending_list_numbering_key = None;
                        }

                        if !in_table_cell && !current_image_assets.is_empty() {
                            flush_docx_list(
                                &mut blocks,
                                &mut pending_list_items,
                                &mut block_index,
                                pending_list_ordered,
                            );
                            pending_list_numbering_key = None;
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
                    "hyperlink" if in_paragraph => current_span_href = None,
                    "tc" if table_depth == 1 && in_table_cell => {
                        current_table_row.push(current_table_cell.trim().to_string());
                        current_table_cell.clear();
                        in_table_cell = false;
                    }
                    "tr" if table_depth == 1 && in_table_row => {
                        if !current_table_row.is_empty() {
                            table_rows.push(std::mem::take(&mut current_table_row));
                        }
                        in_table_row = false;
                    }
                    "tbl" if table_depth > 0 => {
                        table_depth -= 1;
                        if table_depth == 0 && !table_rows.is_empty() {
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
                    }
                    _ => {}
                }
            }
            Ok(Event::Empty(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                match tag.as_str() {
                    "pStyle" if in_paragraph => {
                        for attr in e.attributes().filter_map(|attr| attr.ok()) {
                            if is_word_value_attribute(attr.key.as_ref()) {
                                pstyle_val = String::from_utf8_lossy(&attr.value).into_owned();
                            }
                        }
                    }
                    "numPr" if in_paragraph => paragraph_is_numbered = true,
                    "numId" if in_paragraph && paragraph_is_numbered => {
                        paragraph_numbering_id = word_value_attribute(e);
                    }
                    "ilvl" if in_paragraph && paragraph_is_numbered => {
                        paragraph_numbering_level = word_value_attribute(e);
                    }
                    "footnoteReference" if in_paragraph => {
                        current_note_ref =
                            word_attribute(e, b"id").filter(|id| footnotes.contains_key(id));
                    }
                    "endnoteReference" if in_paragraph => {
                        current_note_ref = word_attribute(e, b"id")
                            .map(|id| format!("endnote:{id}"))
                            .filter(|id| footnotes.contains_key(id));
                    }
                    "blip" if in_paragraph => {
                        if let Some(asset) = word_attribute(e, b"embed")
                            .and_then(|id| image_targets.get(&id).cloned())
                        {
                            current_image_assets.push(asset);
                        }
                    }
                    "b" if in_run => current_span_bold = word_bool_value(e),
                    "i" if in_run => current_span_italic = word_bool_value(e),
                    "strike" | "dstrike" if in_run => {
                        current_span_strikethrough = word_bool_value(e);
                    }
                    "vertAlign" if in_run => match word_value_attribute(e).as_deref() {
                        Some(value) if value.eq_ignore_ascii_case("superscript") => {
                            current_span_superscript = true;
                            current_span_subscript = false;
                        }
                        Some(value) if value.eq_ignore_ascii_case("subscript") => {
                            current_span_subscript = true;
                            current_span_superscript = false;
                        }
                        _ => {
                            current_span_superscript = false;
                            current_span_subscript = false;
                        }
                    },
                    "tab" if in_run => current_span_text.push('\t'),
                    "br" if in_run => current_span_text.push('\n'),
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
    ordered: bool,
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
        ordered: Some(ordered),
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

    fn utf16le_xml(xml: &str) -> Vec<u8> {
        let mut bytes = vec![0xFF, 0xFE];
        for unit in xml.encode_utf16() {
            bytes.extend_from_slice(&unit.to_le_bytes());
        }
        bytes
    }

    fn utf16be_xml(xml: &str) -> Vec<u8> {
        let mut bytes = vec![0xFE, 0xFF];
        for unit in xml.encode_utf16() {
            bytes.extend_from_slice(&unit.to_be_bytes());
        }
        bytes
    }

    fn docx_with_xml_parts(core_xml: &[u8], document_xml: &[u8]) -> Vec<u8> {
        let mut bytes = Cursor::new(Vec::new());
        let mut zip = zip::ZipWriter::new(&mut bytes);
        let options = zip::write::FileOptions::<()>::default()
            .compression_method(zip::CompressionMethod::Stored);
        zip.start_file("docProps/core.xml", options)
            .expect("start core properties");
        zip.write_all(core_xml).expect("write core properties");
        zip.start_file("word/document.xml", options)
            .expect("start document XML");
        zip.write_all(document_xml).expect("write document XML");
        zip.finish().expect("finish DOCX archive");
        bytes.into_inner()
    }

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
    fn auto_detects_utf16le_docx_xml_parts() {
        let mut bytes = Cursor::new(Vec::new());
        let mut zip = zip::ZipWriter::new(&mut bytes);
        let options = zip::write::FileOptions::<()>::default()
            .compression_method(zip::CompressionMethod::Stored);
        zip.start_file("docProps/core.xml", options)
            .expect("start core properties");
        zip.write_all(&utf16le_xml(
            r#"<?xml version="1.0" encoding="UTF-16"?>
            <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
                xmlns:dc="http://purl.org/dc/elements/1.1/">
              <dc:title>UTF-16 title</dc:title><dc:creator>Автор</dc:creator>
            </cp:coreProperties>"#,
        ))
        .expect("write UTF-16 core properties");
        zip.start_file("word/document.xml", options)
            .expect("start document XML");
        zip.write_all(&utf16le_xml(
            r#"<?xml version="1.0" encoding="UTF-16"?>
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
              <w:body><w:p><w:r><w:t>Привет, UTF-16 DOCX.</w:t></w:r></w:p></w:body>
            </w:document>"#,
        ))
        .expect("write UTF-16 document XML");
        zip.finish().expect("finish DOCX archive");

        let book = parse_docx(&bytes.into_inner(), None).expect("parse UTF-16 DOCX");

        assert_eq!(book.title, "UTF-16 title");
        assert_eq!(book.authors, ["Автор"]);
        assert_eq!(book.chapters[0].blocks[0].text, "Привет, UTF-16 DOCX.");
    }

    #[test]
    fn auto_detects_utf16be_docx_xml_parts() {
        let core_xml = utf16be_xml(
            r#"<?xml version="1.0" encoding="UTF-16"?>
            <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
                xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>BE title</dc:title></cp:coreProperties>"#,
        );
        let document_xml = utf16be_xml(
            r#"<?xml version="1.0" encoding="UTF-16"?>
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
              <w:body><w:p><w:r><w:t>Привет, UTF-16 BE.</w:t></w:r></w:p></w:body>
            </w:document>"#,
        );

        let book = parse_docx(&docx_with_xml_parts(&core_xml, &document_xml), None)
            .expect("parse UTF-16BE DOCX");

        assert_eq!(book.title, "BE title");
        assert_eq!(book.chapters[0].blocks[0].text, "Привет, UTF-16 BE.");
    }

    #[test]
    fn honors_declared_legacy_encoding_in_docx_xml_parts() {
        let core = r#"<?xml version="1.0" encoding="windows-1251"?>
            <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
                xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Книга</dc:title></cp:coreProperties>"#;
        let document = r#"<?xml version="1.0" encoding="windows-1251"?>
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
              <w:body><w:p><w:r><w:t>Текст в CP1251.</w:t></w:r></w:p></w:body>
            </w:document>"#;
        let (core_xml, _, _) = encoding_rs::WINDOWS_1251.encode(core);
        let (document_xml, _, _) = encoding_rs::WINDOWS_1251.encode(document);

        let book = parse_docx(
            &docx_with_xml_parts(core_xml.as_ref(), document_xml.as_ref()),
            None,
        )
        .expect("parse declared Windows-1251 DOCX");

        assert_eq!(book.title, "Книга");
        assert_eq!(book.chapters[0].blocks[0].text, "Текст в CP1251.");
    }

    #[test]
    fn strips_utf8_bom_from_docx_xml_parts() {
        let core = b"\xEF\xBB\xBF<?xml version=\"1.0\"?><cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\"><dc:title>BOM title</dc:title></cp:coreProperties>";
        let document = b"\xEF\xBB\xBF<?xml version=\"1.0\"?><w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:t>BOM-safe text.</w:t></w:r></w:p></w:body></w:document>";

        let book =
            parse_docx(&docx_with_xml_parts(core, document), None).expect("parse UTF-8 BOM DOCX");

        assert_eq!(book.title, "BOM title");
        assert_eq!(book.chapters[0].blocks[0].text, "BOM-safe text.");
        assert!(!book.chapters[0].blocks[0].text.starts_with('\u{feff}'));
    }

    #[test]
    fn forced_docx_encoding_overrides_misdeclared_xml() {
        let core = r#"<?xml version="1.0" encoding="utf-8"?>
            <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
                xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Книга</dc:title></cp:coreProperties>"#;
        let document = r#"<?xml version="1.0" encoding="utf-8"?>
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
              <w:body><w:p><w:r><w:t>Принудительная кодировка.</w:t></w:r></w:p></w:body>
            </w:document>"#;
        let (core_xml, _, _) = encoding_rs::WINDOWS_1251.encode(core);
        let (document_xml, _, _) = encoding_rs::WINDOWS_1251.encode(document);

        let book = parse_docx(
            &docx_with_xml_parts(core_xml.as_ref(), document_xml.as_ref()),
            Some("windows-1251"),
        )
        .expect("forced encoding must override XML declaration");

        assert_eq!(book.title, "Книга");
        assert_eq!(book.chapters[0].blocks[0].text, "Принудительная кодировка.");
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
    fn preserves_vertical_alignment_and_strikethrough_run_properties() {
        let xml = r#"
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                <w:body><w:p>
                    <w:r><w:rPr><w:vertAlign w:val="superscript"/></w:rPr><w:t>2</w:t></w:r>
                    <w:r><w:rPr><w:vertAlign w:val="subscript"/></w:rPr><w:t>n</w:t></w:r>
                    <w:r><w:rPr><w:strike/></w:rPr><w:t>obsolete</w:t></w:r>
                </w:p></w:body>
            </w:document>
        "#;

        let (blocks, _) = parse_document_xml(xml).expect("parse DOCX XML");
        let spans = blocks[0].rich_spans.as_ref().expect("formatted spans");

        assert!(spans[0].superscript);
        assert!(spans[1].subscript);
        assert!(spans[2].strikethrough);
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
    fn parses_equivalently_with_alternate_namespace_prefixes() {
        let xml = r#"
            <d:document xmlns:d="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                <d:body><d:p><d:r><d:rPr><d:b/></d:rPr><d:t>Bold</d:t></d:r></d:p></d:body>
            </d:document>
        "#;

        let (blocks, _) = parse_document_xml(xml).expect("parse alternate-prefix DOCX XML");
        let span = &blocks[0].rich_spans.as_ref().expect("formatted span")[0];

        assert_eq!(blocks[0].text, "Bold");
        assert!(span.bold);
    }

    #[test]
    fn ignores_unknown_and_custom_xml_fields_without_losing_field_result() {
        let xml = r#"
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                xmlns:cx="urn:example:custom">
                <w:body>
                    <w:customXml w:element="cx:metadata" cx:storeItemID="{test}">
                        <w:p><w:r><w:t>Before field. </w:t></w:r>
                            <w:sdt><w:sdtPr><w:tag w:val="unsupported-control"/></w:sdtPr>
                                <w:sdtContent><w:fldSimple w:instr="DATE">
                                    <w:r><w:t>2026-07-18</w:t></w:r>
                                </w:fldSimple></w:sdtContent>
                            </w:sdt>
                            <w:unknownField cx:value="ignored"><w:r><w:t> After field.</w:t></w:r></w:unknownField>
                        </w:p>
                    </w:customXml>
                </w:body>
            </w:document>
        "#;

        let (blocks, _) = parse_document_xml(xml).expect("custom DOCX XML must degrade safely");

        assert_eq!(blocks.len(), 1);
        assert_eq!(blocks[0].text, "Before field. 2026-07-18 After field.");
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
    fn preserves_outer_table_when_a_cell_contains_a_nested_table() {
        let xml = r#"
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                <w:body><w:tbl><w:tr>
                    <w:tc><w:p><w:r><w:t>Before nested</w:t></w:r></w:p>
                        <w:tbl><w:tr><w:tc><w:p><w:r><w:t>Nested value</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
                        <w:p><w:r><w:t>After nested</w:t></w:r></w:p>
                    </w:tc>
                    <w:tc><w:p><w:r><w:t>Sibling</w:t></w:r></w:p></w:tc>
                </w:tr></w:tbl></w:body>
            </w:document>
        "#;

        let (blocks, _) = parse_document_xml(xml).expect("parse nested DOCX table");

        assert_eq!(blocks.len(), 1);
        assert_eq!(blocks[0].block_type, crate::api::models::BlockType::Table);
        assert_eq!(
            blocks[0].table_rows,
            Some(vec![vec![
                "Before nested\nNested value\nAfter nested".into(),
                "Sibling".into(),
            ]]),
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
    fn preserves_bullet_lists_from_numbering_xml() {
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
            br#"<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
                <w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="7"/></w:numPr></w:pPr><w:r><w:t>One</w:t></w:r></w:p>
                <w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="7"/></w:numPr></w:pPr><w:r><w:t>Two</w:t></w:r></w:p>
            </w:body></w:document>"#,
        )
        .expect("write document XML");
        zip.start_file("word/numbering.xml", options)
            .expect("start numbering XML");
        zip.write_all(
            br#"<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                <w:abstractNum w:abstractNumId="3"><w:lvl w:ilvl="0"><w:numFmt w:val="bullet"/></w:lvl></w:abstractNum>
                <w:num w:numId="7"><w:abstractNumId w:val="3"/></w:num>
            </w:numbering>"#,
        )
        .expect("write numbering XML");
        zip.finish().expect("finish DOCX archive");

        let book = parse_docx(&bytes.into_inner(), None).expect("parse DOCX bullet list");
        let list = &book.chapters[0].blocks[0];

        assert_eq!(list.block_type, crate::api::models::BlockType::List);
        assert_eq!(list.ordered, Some(false));
        assert_eq!(list.text, "One\nTwo");
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

        let (blocks, _) = parse_document_xml_with_hyperlinks(
            xml,
            &hyperlinks,
            &HashMap::new(),
            &HashMap::new(),
            &HashMap::new(),
        )
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
    fn extracts_floating_anchor_images_without_interpreting_wrap_layout() {
        // Word stores floating pictures under `wp:anchor` rather than
        // `wp:inline`.  The normalized reader model deliberately has no Word
        // page-layout layer, but the image itself must remain available as an
        // image block regardless of its wrapping settings.
        let xml = r#"
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
                xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
              <w:body><w:p>
                <w:r><w:t>Text around a floating picture.</w:t></w:r>
                <w:r><w:drawing><wp:anchor behindDoc="0">
                  <a:graphic><a:graphicData><a:blip r:embed="rIdFloat"/></a:graphicData></a:graphic>
                </wp:anchor></w:drawing></w:r>
              </w:p></w:body>
            </w:document>
        "#;
        let images = HashMap::from([(
            String::from("rIdFloat"),
            String::from("word/media/floating.png"),
        )]);

        let (blocks, _) = parse_document_xml_with_hyperlinks(
            xml,
            &HashMap::new(),
            &images,
            &HashMap::new(),
            &HashMap::new(),
        )
        .expect("parse floating DOCX image");

        assert_eq!(blocks.len(), 2);
        assert_eq!(blocks[0].text, "Text around a floating picture.");
        assert_eq!(blocks[1].block_type, crate::api::models::BlockType::Image);
        assert_eq!(
            blocks[1].image_url.as_deref(),
            Some("word/media/floating.png")
        );
    }

    #[test]
    fn resolves_relative_nested_media_from_alternate_content() {
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
            br#"<word:document xmlns:word="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:draw="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:rel="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><word:body><word:p><mc:AlternateContent><mc:Choice Requires="draw"><word:r><word:drawing><draw:blip rel:embed="picture-7"/></word:drawing></word:r></mc:Choice></mc:AlternateContent></word:p></word:body></word:document>"#,
        )
        .expect("write document XML");
        zip.start_file("word/_rels/document.xml.rels", options)
            .expect("start relationships XML");
        zip.write_all(
            br#"<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="picture-7" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../word/media/figures/cover.webp"/></Relationships>"#,
        )
        .expect("write relationships XML");
        zip.start_file("word/media/figures/cover.webp", options)
            .expect("start nested image");
        zip.write_all(b"WEBP").expect("write nested image");
        zip.finish().expect("finish DOCX archive");

        let archive = bytes.into_inner();
        let book = parse_docx(&archive, None).expect("parse DOCX with nested image");

        assert_eq!(book.images.len(), 1);
        assert_eq!(book.images[0].id, "figures/cover.webp");
        assert_eq!(
            book.cover_url.as_deref(),
            Some("data:image/webp;base64,V0VCUA==")
        );
        assert_eq!(book.chapters[0].blocks.len(), 1);
        assert_eq!(
            book.chapters[0].blocks[0].image_url.as_deref(),
            Some("word/media/figures/cover.webp")
        );

        let path = std::env::temp_dir().join(format!(
            "glibusta-docx-nested-image-{}.docx",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(&path, archive).expect("write DOCX fixture");
        let image = crate::api::api::get_asset_bytes(
            path.to_string_lossy().into_owned(),
            "word/media/figures/cover.webp".to_string(),
        );
        let _ = std::fs::remove_file(path);

        assert_eq!(image.expect("extract nested DOCX image"), b"WEBP");
    }

    #[test]
    fn skips_unsupported_media_when_selecting_docx_cover() {
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
            br#"<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Body</w:t></w:r></w:p></w:body></w:document>"#,
        )
        .expect("write document XML");
        // EMF is a valid Office media entry but cannot be rendered by the
        // Flutter byte-image path.  Archive order deliberately puts it first.
        zip.start_file("word/media/preview.emf", options)
            .expect("start EMF preview");
        zip.write_all(b"EMF").expect("write EMF preview");
        zip.start_file("word/media/cover.png", options)
            .expect("start PNG cover");
        zip.write_all(b"PNG").expect("write PNG cover");
        zip.finish().expect("finish DOCX archive");

        let book = parse_docx(&bytes.into_inner(), None).expect("parse DOCX media");

        assert_eq!(book.images.len(), 2);
        assert_eq!(
            book.cover_url.as_deref(),
            Some("data:image/png;base64,UE5H")
        );
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

    #[test]
    fn extracts_docx_endnotes_and_links_references() {
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
            br#"<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Text</w:t></w:r><w:r><w:endnoteReference w:id="1"/></w:r></w:p></w:body></w:document>"#,
        )
        .expect("write document XML");
        zip.start_file("word/endnotes.xml", options)
            .expect("start endnotes XML");
        zip.write_all(
            br#"<w:endnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:endnote w:id="-1"><w:p><w:r><w:t>separator</w:t></w:r></w:p></w:endnote><w:endnote w:id="1"><w:p><w:r><w:t>Endnote text</w:t></w:r></w:p></w:endnote></w:endnotes>"#,
        )
        .expect("write endnotes XML");
        zip.finish().expect("finish DOCX archive");

        let book = parse_docx(&bytes.into_inner(), None).expect("parse DOCX endnote");

        assert_eq!(
            book.chapters[0].blocks[0].note_ref.as_deref(),
            Some("endnote:1")
        );
        assert_eq!(
            book.metadata
                .as_ref()
                .and_then(|metadata| metadata["footnotes"]["endnote:1"].as_str()),
            Some("Endnote text")
        );
    }
}
