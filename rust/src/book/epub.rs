use crate::api::models::{BlockType, NormalizedBook, ReaderBlock, ReaderChapter};
use crate::book::archive::{self, ZipFile};
use crate::book::encoding::{decode_bytes, get_xml_attr};
use anyhow::{Context, Result};
use quick_xml::events::Event;
use quick_xml::Reader;
use serde::Deserialize;
use std::collections::HashMap;

pub fn parse_epub(bytes: &[u8], forced_encoding: Option<&str>) -> Result<NormalizedBook> {
    let zip = archive::decode_zip(bytes).context("Failed to open EPUB archive")?;
    let encoding_name = forced_encoding.unwrap_or("utf-8");

    let container_xml = zip
        .find_file("META-INF/container.xml")
        .context("EPUB missing META-INF/container.xml")?;
    let container_text = decode_bytes(container_xml, encoding_name);
    let opf_path = parse_container_xml(&container_text)?;

    let opf_bytes = zip
        .find_file(&opf_path)
        .with_context(|| format!("OPF file not found: {}", opf_path))?;
    let opf_text = decode_bytes(opf_bytes, encoding_name);

    let opf_dir = opf_path.rsplit('/').nth(1).unwrap_or("");

    let (metadata, manifest_items, spine_ids) = parse_opf(&opf_text)?;

    let title = metadata.get("title").cloned().unwrap_or_default();
    let authors_raw = metadata.get("creator").cloned().unwrap_or_default();
    let authors: Vec<String> = authors_raw
        .split(';')
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect();
    let description = metadata.get("description").cloned();

    let cover_url = extract_cover_url(&zip, &manifest_items, &metadata, opf_dir, encoding_name);

    let mut chapters: Vec<ReaderChapter> = Vec::new();
    let mut chapter_index = 0i32;
    let mut block_index = 0i32;

    for spine_id in &spine_ids {
        let Some(item) = manifest_items.get(spine_id.as_str()) else {
            continue;
        };
        let item_href = if opf_dir.is_empty() {
            item.href.clone()
        } else {
            format!("{}/{}", opf_dir, item.href)
        };

        let Some(xhtml_bytes) = zip.find_file(&item_href).or_else(|| {
            // Try case-insensitive
            zip.entry_names()
                .iter()
                .find(|n| n.eq_ignore_ascii_case(&item_href))
                .and_then(|n| zip.find_file(n))
        }) else {
            continue;
        };

        let xhtml_text = decode_bytes(xhtml_bytes, encoding_name);
        let (blocks, next_block_index) = parse_xhtml_to_blocks(&xhtml_text, block_index);
        block_index = next_block_index;

        if blocks.is_empty() {
            continue;
        }

        let chapter_title = extract_chapter_title(&xhtml_text);

        chapters.push(ReaderChapter {
            index: chapter_index,
            title: chapter_title,
            blocks,
        });
        chapter_index += 1;
    }

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

struct ManifestItem {
    href: String,
    media_type: String,
    properties: Vec<String>,
}

#[derive(Deserialize)]
struct Container {
    #[serde(rename = "rootfiles", default)]
    rootfiles: Rootfiles,
}

#[derive(Default, Deserialize)]
struct Rootfiles {
    #[serde(rename = "rootfile", default)]
    rootfile: Vec<Rootfile>,
}

#[derive(Deserialize)]
struct Rootfile {
    #[serde(rename = "@full-path")]
    full_path: String,
}

fn parse_container_xml(text: &str) -> Result<String> {
    let container: Container =
        quick_xml::de::from_str(text).context("Failed to parse container.xml")?;
    container
        .rootfiles
        .rootfile
        .into_iter()
        .next()
        .map(|r| r.full_path)
        .context("No rootfile found in container.xml")
}

type OpfResult = (
    HashMap<String, String>,
    HashMap<String, ManifestItem>,
    Vec<String>,
);

fn parse_opf(text: &str) -> Result<OpfResult> {
    let mut reader = Reader::from_str(text);
    reader.config_mut().trim_text(true);
    let mut buf = Vec::new();

    let mut metadata: HashMap<String, String> = HashMap::new();
    let mut manifest_items: HashMap<String, ManifestItem> = HashMap::new();
    let mut spine_ids: Vec<String> = Vec::new();

    let mut in_metadata = false;
    let mut in_manifest = false;
    let mut in_spine = false;
    let mut in_dc_tag = false;
    let mut current_dc_tag = String::new();
    let mut current_text = String::new();

    loop {
        buf.clear();
        match reader.read_event_into(&mut buf) {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref e)) => {
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                match tag.as_str() {
                    "metadata" => in_metadata = true,
                    "manifest" => in_manifest = true,
                    "spine" => in_spine = true,
                    _ => {
                        // DC metadata tags: dc:title, dc:creator, etc.
                        if in_metadata && tag.starts_with("dc:") {
                            in_dc_tag = true;
                            current_dc_tag = tag[3..].to_string();
                            current_text.clear();
                        }
                        if in_metadata && tag == "meta" {
                            // Handle <meta name="cover" content="cover-id"/>
                            let name = get_xml_attr(e, b"name");
                            let content = get_xml_attr(e, b"content");
                            if let (Some(n), Some(c)) = (name, content) {
                                if n == "cover" {
                                    metadata.insert("cover-id".to_string(), c);
                                }
                            }
                        }
                        if in_manifest && tag == "item" {
                            let id = get_xml_attr(e, b"id");
                            let href = get_xml_attr(e, b"href");
                            let media_type = get_xml_attr(e, b"media-type");
                            let properties: Vec<String> = e
                                .attributes()
                                .filter_map(|a| a.ok())
                                .filter(|attr| attr.key.as_ref() == b"properties")
                                .flat_map(|attr| {
                                    String::from_utf8_lossy(&attr.value)
                                        .split_whitespace()
                                        .map(String::from)
                                        .collect::<Vec<_>>()
                                })
                                .collect();

                            if let (Some(id), Some(href), Some(mt)) = (id, href, media_type) {
                                manifest_items.insert(
                                    id.clone(),
                                    ManifestItem {
                                        href,
                                        media_type: mt,
                                        properties,
                                    },
                                );
                            }
                        }
                        if in_spine && tag == "itemref" {
                            if let Some(idref) = get_xml_attr(e, b"idref") {
                                spine_ids.push(idref);
                            }
                        }
                    }
                }
            }
            Ok(Event::Text(ref e)) => {
                if in_dc_tag {
                    current_text.push_str(&e.unescape().unwrap_or_default());
                }
            }
            Ok(Event::End(ref e)) => {
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                match tag.as_str() {
                    "metadata" => in_metadata = false,
                    "manifest" => in_manifest = false,
                    "spine" => in_spine = false,
                    _ => {
                        let tag_name = tag.strip_prefix("dc:").unwrap_or(&tag);
                        if in_dc_tag && tag_name == current_dc_tag {
                            let val = current_text.trim().to_string();
                            if !val.is_empty() {
                                // Append to support multiple dc:creator tags
                                let entry = metadata.entry(current_dc_tag.clone()).or_default();
                                if entry.is_empty() {
                                    *entry = val;
                                } else {
                                    entry.push_str("; ");
                                    entry.push_str(&val);
                                }
                            }
                            in_dc_tag = false;
                            current_dc_tag.clear();
                            current_text.clear();
                        }
                    }
                }
            }
            Err(e) => return Err(anyhow::anyhow!("OPF parse error: {}", e)),
            _ => {}
        }
    }

    Ok((metadata, manifest_items, spine_ids))
}

fn extract_cover_url(
    zip: &ZipFile,
    manifest: &HashMap<String, ManifestItem>,
    metadata: &HashMap<String, String>,
    opf_dir: &str,
    _encoding_name: &str,
) -> Option<String> {
    // Try cover-id from <meta name="cover" content="..."/>
    if let Some(cover_id) = metadata.get("cover-id") {
        if let Some(item) = manifest.get(cover_id.as_str()) {
            let href = if opf_dir.is_empty() {
                item.href.clone()
            } else {
                format!("{}/{}", opf_dir, item.href)
            };
            if let Some(bytes) = zip.find_file(&href) {
                let mime = &item.media_type;
                return Some(format!(
                    "data:{};base64,{}",
                    mime,
                    base64::Engine::encode(&base64::engine::general_purpose::STANDARD, bytes)
                ));
            }
        }
    }

    // Fallback: look for manifest item with properties="cover-image"
    for item in manifest.values() {
        if item.properties.iter().any(|p| p == "cover-image") {
            let href = if opf_dir.is_empty() {
                item.href.clone()
            } else {
                format!("{}/{}", opf_dir, item.href)
            };
            if let Some(bytes) = zip.find_file(&href) {
                let mime = &item.media_type;
                return Some(format!(
                    "data:{};base64,{}",
                    mime,
                    base64::Engine::encode(&base64::engine::general_purpose::STANDARD, bytes)
                ));
            }
        }
    }

    // Fallback: look for item whose id contains "cover"
    for (id, item) in manifest.iter() {
        if id.contains("cover") && item.media_type.starts_with("image/") {
            let href = if opf_dir.is_empty() {
                item.href.clone()
            } else {
                format!("{}/{}", opf_dir, item.href)
            };
            if let Some(bytes) = zip.find_file(&href) {
                let mime = &item.media_type;
                return Some(format!(
                    "data:{};base64,{}",
                    mime,
                    base64::Engine::encode(&base64::engine::general_purpose::STANDARD, bytes)
                ));
            }
        }
    }

    None
}

fn parse_xhtml_to_blocks(text: &str, mut block_index: i32) -> (Vec<ReaderBlock>, i32) {
    let mut reader = Reader::from_str(text);
    reader.config_mut().trim_text(true);
    let mut buf = Vec::new();

    let mut blocks: Vec<ReaderBlock> = Vec::new();
    let mut current_text = String::new();
    let mut in_body = false;
    let mut tag_stack: Vec<String> = Vec::new();

    loop {
        buf.clear();
        match reader.read_event_into(&mut buf) {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref e)) => {
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                match tag.as_str() {
                    "body" => in_body = true,
                    "p" if in_body => {
                        flush_block(
                            &mut blocks,
                            &mut current_text,
                            &mut block_index,
                            BlockType::Paragraph,
                        );
                        current_text.clear();
                        tag_stack.push("p".to_string());
                    }
                    t if t.starts_with('h') && t.len() == 2 && in_body => {
                        if t.as_bytes()[1].is_ascii_digit() {
                            flush_block(
                                &mut blocks,
                                &mut current_text,
                                &mut block_index,
                                BlockType::Paragraph,
                            );
                            current_text.clear();
                            tag_stack.push(t.to_string());
                        }
                    }
                    "blockquote" if in_body => {
                        flush_block(
                            &mut blocks,
                            &mut current_text,
                            &mut block_index,
                            BlockType::Paragraph,
                        );
                        current_text.clear();
                        tag_stack.push("blockquote".to_string());
                    }
                    "hr" if in_body => {
                        blocks.push(ReaderBlock {
                            index: block_index,
                            text: String::new(),
                            block_type: BlockType::Separator,
                            image_url: None,
                            note_ref: None,
                            rich_spans: None,
                        });
                        block_index += 1;
                    }
                    "img" if in_body => {
                        let src = get_xml_attr(e, b"src");
                        blocks.push(ReaderBlock {
                            index: block_index,
                            text: String::new(),
                            block_type: BlockType::Image,
                            image_url: src,
                            note_ref: None,
                            rich_spans: None,
                        });
                        block_index += 1;
                    }
                    _ => {}
                }
            }
            Ok(Event::Text(ref e)) => {
                if in_body {
                    let text = e.unescape().unwrap_or_default().to_string();
                    current_text.push_str(&text);
                }
            }
            Ok(Event::End(ref e)) => {
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                match tag.as_str() {
                    "body" => in_body = false,
                    "p" if in_body && tag_stack.last().map(|s| s.as_str()) == Some("p") => {
                        tag_stack.pop();
                        let t = current_text.trim().to_string();
                        if !t.is_empty() {
                            blocks.push(ReaderBlock {
                                index: block_index,
                                text: t,
                                block_type: BlockType::Paragraph,
                                image_url: None,
                                note_ref: None,
                                rich_spans: None,
                            });
                            block_index += 1;
                        }
                        current_text.clear();
                    }
                    t if t.starts_with('h') && t.len() == 2 && in_body => {
                        if tag_stack.last().map(|s| s.as_str()) == Some(t) {
                            tag_stack.pop();
                            let t_text = current_text.trim().to_string();
                            if !t_text.is_empty() {
                                blocks.push(ReaderBlock {
                                    index: block_index,
                                    text: t_text,
                                    block_type: BlockType::Heading,
                                    image_url: None,
                                    note_ref: None,
                                    rich_spans: None,
                                });
                                block_index += 1;
                            }
                            current_text.clear();
                        }
                    }
                    "blockquote"
                        if in_body
                            && tag_stack.last().map(|s| s.as_str()) == Some("blockquote") =>
                    {
                        tag_stack.pop();
                        let t = current_text.trim().to_string();
                        if !t.is_empty() {
                            blocks.push(ReaderBlock {
                                index: block_index,
                                text: t,
                                block_type: BlockType::Quote,
                                image_url: None,
                                note_ref: None,
                                rich_spans: None,
                            });
                            block_index += 1;
                        }
                        current_text.clear();
                    }
                    _ => {}
                }
            }
            Ok(Event::Empty(ref e)) => {
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                if tag == "hr" && in_body {
                    blocks.push(ReaderBlock {
                        index: block_index,
                        text: String::new(),
                        block_type: BlockType::Separator,
                        image_url: None,
                        note_ref: None,
                        rich_spans: None,
                    });
                    block_index += 1;
                } else if tag == "img" && in_body {
                    let src = get_xml_attr(e, b"src");
                    blocks.push(ReaderBlock {
                        index: block_index,
                        text: String::new(),
                        block_type: BlockType::Image,
                        image_url: src,
                        note_ref: None,
                        rich_spans: None,
                    });
                    block_index += 1;
                }
            }
            Err(_) => break,
            _ => {}
        }
    }

    // Flush any remaining text
    flush_block(
        &mut blocks,
        &mut current_text,
        &mut block_index,
        BlockType::Paragraph,
    );

    (blocks, block_index)
}

fn flush_block(
    blocks: &mut Vec<ReaderBlock>,
    text: &mut String,
    index: &mut i32,
    block_type: BlockType,
) {
    let trimmed = text.trim().to_string();
    if !trimmed.is_empty() {
        blocks.push(ReaderBlock {
            index: *index,
            text: trimmed,
            block_type,
            image_url: None,
            note_ref: None,
            rich_spans: None,
        });
        *index += 1;
    }
    text.clear();
}

fn extract_chapter_title(text: &str) -> String {
    let mut reader = Reader::from_str(text);
    reader.config_mut().trim_text(true);
    let mut buf = Vec::new();
    let mut in_title = false;
    let mut title = String::new();

    loop {
        buf.clear();
        match reader.read_event_into(&mut buf) {
            Ok(Event::Eof) | Err(_) => break,
            Ok(Event::Start(ref e)) => {
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                if tag == "title" {
                    in_title = true;
                    title.clear();
                }
            }
            Ok(Event::Text(ref e)) => {
                if in_title {
                    title.push_str(&e.unescape().unwrap_or_default());
                }
            }
            Ok(Event::End(ref e)) => {
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                if tag == "title" && in_title {
                    break;
                }
            }
            _ => {}
        }
    }

    title.trim().to_string()
}
