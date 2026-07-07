use crate::api::models::{
    BlockType, BookFormat, EmbeddedImage, NormalizedBook, ReaderBlock, ReaderChapter, RichSpan,
};
use crate::book::archive::{self, ZipFile};
use crate::book::encoding::decode_bytes;
use anyhow::{Context, Result};
use quick_xml::Reader;
use quick_xml::events::Event;
use serde::Deserialize;

pub fn parse_docx(bytes: &[u8], forced_encoding: Option<&str>) -> Result<NormalizedBook> {
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
        .find_file("word/document.xml")
        .context("DOCX missing word/document.xml")?;
    let doc_text = decode_bytes(&document_xml, encoding_name);

    let (blocks, chapter_title) = parse_document_xml(&doc_text);

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

    let metadata = serde_json::json!({
        "created": created_date,
    });

    let images = extract_images(&mut zip);
    let cover_url = images.first().and_then(|img| {
        let entry_name = format!("word/media/{}", img.id);
        let data = zip.find_file(&entry_name)?;
        use base64::Engine;
        Some(format!(
            "data:{};base64,{}",
            img.media_type,
            base64::engine::general_purpose::STANDARD.encode(&data)
        ))
    });

    Ok(NormalizedBook {
        id,
        title: final_title,
        authors,
        description: None,
        cover_url,
        chapters,
        metadata: Some(metadata),
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
    zip: &mut ZipFile,
    encoding_name: &str,
) -> Result<(String, Vec<String>, String)> {
    let props_bytes = zip
        .find_file("docProps/core.xml")
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

/// Extract image metadata from word/media/ without loading bytes.
/// Use `get_asset_bytes()` (RCE-10.2) for lazy data loading.
fn extract_images(zip: &mut ZipFile) -> Vec<EmbeddedImage> {
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

fn parse_document_xml(text: &str) -> (Vec<ReaderBlock>, String) {
    let mut reader = Reader::from_str(text);
    reader.config_mut().trim_text(true);
    let mut blocks: Vec<ReaderBlock> = Vec::new();
    let mut block_index = 0i32;
    let mut chapter_title = String::new();

    let mut in_body = false;
    let mut in_paragraph = false;
    let mut in_run = false;
    let mut in_pstyle = false;
    let mut pstyle_val = String::new();

    let mut current_text = String::new();
    let mut rich_spans: Vec<RichSpan> = Vec::new();
    let mut current_span_text = String::new();
    let mut current_span_bold = false;
    let mut current_span_italic = false;

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref e)) => {
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                match tag.as_str() {
                    "w:body" => in_body = true,
                    "w:p" if in_body => {
                        in_paragraph = true;
                        current_text.clear();
                        rich_spans.clear();
                        current_span_text.clear();
                        current_span_bold = false;
                        current_span_italic = false;
                        pstyle_val.clear();
                    }
                    "w:pStyle" if in_paragraph => {
                        for attr in e.attributes().filter_map(|a| a.ok()) {
                            if attr.key.as_ref() == b"val" {
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
                    "w:b" if in_run => {
                        for attr in e.attributes().filter_map(|a| a.ok()) {
                            if attr.key.as_ref() == b"val" {
                                let val = String::from_utf8_lossy(&attr.value).to_lowercase();
                                current_span_bold = val != "0" && val != "false";
                            } else {
                                current_span_bold = true;
                            }
                        }
                    }
                    "w:i" if in_run => {
                        for attr in e.attributes().filter_map(|a| a.ok()) {
                            if attr.key.as_ref() == b"val" {
                                let val = String::from_utf8_lossy(&attr.value).to_lowercase();
                                current_span_italic = val != "0" && val != "false";
                            } else {
                                current_span_italic = true;
                            }
                        }
                    }
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
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                match tag.as_str() {
                    "w:body" => in_body = false,
                    "w:pStyle" => in_pstyle = false,
                    "w:r" if in_paragraph => {
                        if !current_span_text.is_empty() {
                            rich_spans.push(RichSpan {
                                text: current_span_text.clone(),
                                bold: current_span_bold,
                                italic: current_span_italic,
                                superscript: false,
                                href: None,
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

                        if !trimmed.is_empty() {
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

                            blocks.push(ReaderBlock {
                                index: block_index,
                                text: trimmed,
                                block_type,
                                image_url: None,
                                note_ref: None,
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
                            });
                            block_index += 1;
                        }

                        in_paragraph = false;
                        rich_spans.clear();
                        current_span_text.clear();
                    }
                    _ => {}
                }
            }
            Ok(Event::Empty(ref e)) => {
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                if tag == "w:br" && in_run {
                    current_span_text.push('\n');
                }
            }
            Err(_) => break,
            _ => {}
        }
    }

    (blocks, chapter_title)
}
