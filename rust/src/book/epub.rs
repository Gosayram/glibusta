use crate::api::models::{
    BlockType, BookFormat, NormalizedBook, ReaderBlock, ReaderChapter, RichSpan, TocEntry,
};
use crate::book::archive::{self, ZipFile};
use crate::book::encoding::{attr_eq, decode_bytes, get_class_attr_arena, get_xml_attr};
use crate::book::flush_rich_span;
use anyhow::{Context, Result, bail};
use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use bumpalo::Bump;
use quick_xml::Reader;
use quick_xml::events::Event;
use serde::Deserialize;
use std::collections::HashMap;

pub fn parse_epub(bytes: &[u8], forced_encoding: Option<&str>) -> Result<NormalizedBook> {
    if bytes.len() as u64 > crate::api::models::MAX_FILE_SIZE {
        bail!("EPUB exceeds maximum file size");
    }
    let mut zip = archive::decode_zip(bytes).context("Failed to open EPUB archive")?;

    // RCE-12.6: zip bomb guard — reject archives with too many entries
    let entry_count = zip.entry_names().len();
    if entry_count > crate::api::models::MAX_EXTRACTED_FILES {
        bail!(
            "Archive too large: {} entries (max {})",
            entry_count,
            crate::api::models::MAX_EXTRACTED_FILES
        );
    }

    let encoding_name = forced_encoding.unwrap_or("utf-8");

    let container_xml = zip
        .read_file_limited(
            "META-INF/container.xml",
            crate::api::models::MAX_CHAPTER_SIZE,
        )?
        .context("EPUB missing META-INF/container.xml")?;
    let container_text = decode_bytes(&container_xml, encoding_name);
    let opf_path = parse_container_xml(&container_text)?;

    let opf_bytes = zip
        .read_file_limited(&opf_path, crate::api::models::MAX_CHAPTER_SIZE)?
        .with_context(|| format!("OPF file not found: {}", opf_path))?;
    let opf_text = decode_bytes(&opf_bytes, encoding_name);

    let opf_dir = opf_path.rsplit('/').nth(1).unwrap_or("");

    let (metadata, manifest_items, spine_ids, ncx_id) = parse_opf(&opf_text)?;

    let title = metadata.get("title").cloned().unwrap_or_default();
    let authors_raw = metadata.get("creator").cloned().unwrap_or_default();
    let authors: Vec<String> = authors_raw
        .split(';')
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect();
    let description = metadata.get("description").cloned();
    let language = metadata.get("language").cloned();

    let cover_url =
        extract_cover_url(&mut zip, &manifest_items, &metadata, opf_dir, encoding_name)?;

    let mut chapters: Vec<ReaderChapter> = Vec::new();
    let mut chapter_index = 0i32;
    let mut block_index = 0i32;
    let mut warnings: Vec<crate::api::models::ParseWarning> = Vec::new();
    // CRT-1.14: collect @font-face declarations across all XHTML files
    let mut font_faces: std::collections::HashMap<String, String> =
        std::collections::HashMap::new();

    for spine_id in &spine_ids {
        let Some(item) = manifest_items.get(spine_id.as_str()) else {
            continue;
        };
        let item_href = if opf_dir.is_empty() {
            item.href.clone()
        } else {
            format!("{}/{}", opf_dir, item.href)
        };

        let matching_name = zip
            .entry_names()
            .iter()
            .find(|name| name.eq_ignore_ascii_case(&item_href))
            .cloned();
        let xhtml_bytes = zip
            .read_file_limited(&item_href, crate::api::models::MAX_CHAPTER_SIZE)?
            .or(match matching_name {
                Some(name) => zip.read_file_limited(&name, crate::api::models::MAX_CHAPTER_SIZE)?,
                None => None,
            });
        let Some(xhtml_bytes) = xhtml_bytes else {
            continue;
        };

        let xhtml_text = decode_bytes(&xhtml_bytes, encoding_name);
        let css = extract_css(&xhtml_text);
        // CRT-1.14: extract @font-face declarations
        for (family, src) in extract_font_faces(&xhtml_text) {
            font_faces.entry(family).or_insert(src);
        }
        let (mut blocks, next_block_index, page_breaks_in_file) =
            parse_xhtml_to_blocks(&xhtml_text, block_index, &css);
        // RCE-7.5: collapse empty div/span — remove blocks with no visible content
        blocks.retain(|b| {
            !b.text.trim().is_empty()
                || b.image_url.is_some()
                || b.block_type == BlockType::Separator
                || b.table_rows.is_some()
                || b.list_items.is_some()
        });
        block_index = next_block_index;

        // If quick-xml produced nothing, try html5ever for malformed HTML content.
        // html5ever handles unclosed tags, bare &, and other real-world HTML soup.
        if blocks.is_empty() && !xhtml_text.trim().is_empty() {
            let (html5_blocks, html5_next) =
                crate::book::html_parser::html_to_blocks(&xhtml_text, block_index);
            if !html5_blocks.is_empty() {
                blocks = html5_blocks;
                block_index = html5_next;
                // Apply CSS at tag level (no class info from simplified parser)
                for b in &mut blocks {
                    apply_css_props(
                        b,
                        match b.block_type {
                            BlockType::Heading => "h1",
                            BlockType::Quote => "blockquote",
                            BlockType::List => "ul",
                            BlockType::Image => "img",
                            BlockType::Separator => "hr",
                            _ => "p",
                        },
                        None,
                        &css,
                    );
                }
            }
        }

        if blocks.is_empty() {
            continue;
        }

        // MD-1.4: split chapter at CSS page-break-before points
        let chapter_title = extract_chapter_title(&xhtml_text);
        if page_breaks_in_file.is_empty() {
            chapters.push(ReaderChapter {
                index: chapter_index,
                title: chapter_title.clone(),
                blocks,
            });
            chapter_index += 1;
        } else {
            let mut start = 0;
            for &break_idx in &page_breaks_in_file {
                if break_idx > start && break_idx <= blocks.len() {
                    let sub: Vec<ReaderBlock> = blocks[start..break_idx].to_vec();
                    if !sub.is_empty() {
                        chapters.push(ReaderChapter {
                            index: chapter_index,
                            title: chapter_title.clone(),
                            blocks: sub,
                        });
                        chapter_index += 1;
                    }
                }
                start = break_idx;
            }
            if start < blocks.len() {
                let sub: Vec<ReaderBlock> = blocks[start..].to_vec();
                if !sub.is_empty() {
                    chapters.push(ReaderChapter {
                        index: chapter_index,
                        title: chapter_title.clone(),
                        blocks: sub,
                    });
                    chapter_index += 1;
                }
            }
        }
    }

    let id = crate::book::sha256_hex(bytes);

    // RCE-11.3: warn about broken images (img blocks with no src)
    for ch in &chapters {
        for b in &ch.blocks {
            if b.block_type == crate::api::models::BlockType::Image && b.image_url.is_none() {
                warnings.push(crate::api::models::ParseWarning {
                    message: format!("Broken image in chapter {}: missing src", ch.index),
                });
            }
        }
    }

    // LW-8.1: fixed-layout info + CRT-1.14: font-face declarations
    let rendition_layout = metadata.get("rendition:layout");
    let rendition_viewport = metadata.get("rendition:viewport");
    let rendition_orientation = metadata.get("rendition:orientation");
    let has_rendition = rendition_layout
        .or(rendition_viewport)
        .or(rendition_orientation)
        .is_some();
    let meta = if font_faces.is_empty() && !has_rendition {
        None
    } else {
        let mut obj = serde_json::json!({});
        if !font_faces.is_empty() {
            obj["fonts"] = serde_json::json!(font_faces);
        }
        if let Some(layout) = rendition_layout {
            obj["rendition:layout"] = serde_json::json!(layout);
        }
        if let Some(vp) = rendition_viewport {
            obj["rendition:viewport"] = serde_json::json!(vp);
        }
        if let Some(orient) = rendition_orientation {
            obj["rendition:orientation"] = serde_json::json!(orient);
        }
        Some(obj)
    };

    // ---- TOC extraction ----
    let toc = extract_epub_toc(&mut zip, &manifest_items, &ncx_id, opf_dir, encoding_name)?;

    if cover_url.is_none() {
        warnings.push(crate::api::models::ParseWarning {
            message: "Cover image not found".to_string(),
        });
    }
    if chapters.is_empty() {
        warnings.push(crate::api::models::ParseWarning {
            message: "No content chapters found".to_string(),
        });
    }
    if toc.is_empty() && !chapters.is_empty() {
        warnings.push(crate::api::models::ParseWarning {
            message: "TOC not found, fallback to chapter titles".to_string(),
        });
    }

    Ok(NormalizedBook {
        id,
        title,
        authors,
        description,
        cover_url,
        chapters,
        metadata: meta,
        book_format: BookFormat::Epub,
        language,
        warnings,
        images: Vec::new(),
        toc,
    })
}

/// Find and parse EPUB table of contents (NCX for EPUB 2, nav.xhtml for EPUB 3).
fn extract_epub_toc(
    zip: &mut ZipFile,
    manifest: &HashMap<String, ManifestItem>,
    ncx_id: &Option<String>,
    opf_dir: &str,
    encoding_name: &str,
) -> Result<Vec<TocEntry>> {
    // Try EPUB 3 nav.xhtml first (preferred)
    if let Some(toc) = try_parse_nav_xhtml(zip, manifest, opf_dir, encoding_name)? {
        if !toc.is_empty() {
            return Ok(toc);
        }
    }

    // Fall back to EPUB 2 NCX
    if let Some(toc) = try_parse_ncx(zip, manifest, ncx_id, opf_dir, encoding_name)? {
        return Ok(toc);
    }

    Ok(Vec::new())
}

fn try_parse_nav_xhtml(
    zip: &mut ZipFile,
    manifest: &HashMap<String, ManifestItem>,
    opf_dir: &str,
    encoding_name: &str,
) -> Result<Option<Vec<TocEntry>>> {
    let Some(nav_item) = manifest.values().find(|item| {
        item.properties.iter().any(|p| p == "nav") && item.media_type == "application/xhtml+xml"
    }) else {
        return Ok(None);
    };
    let nav_path = if opf_dir.is_empty() {
        nav_item.href.clone()
    } else {
        format!("{}/{}", opf_dir, nav_item.href)
    };
    let Some(bytes) = zip.read_file_limited(&nav_path, crate::api::models::MAX_CHAPTER_SIZE)?
    else {
        return Ok(None);
    };
    let text = decode_bytes(&bytes, encoding_name);
    Ok(Some(parse_nav_xhtml(&text)))
}

fn try_parse_ncx(
    zip: &mut ZipFile,
    manifest: &HashMap<String, ManifestItem>,
    ncx_id: &Option<String>,
    opf_dir: &str,
    encoding_name: &str,
) -> Result<Option<Vec<TocEntry>>> {
    // Find NCX: either by spine toc attribute or by media-type
    let ncx_item = ncx_id
        .as_ref()
        .and_then(|id| manifest.get(id.as_str()))
        .or_else(|| {
            manifest
                .values()
                .find(|item| item.media_type == "application/x-dtbncx+xml")
        });
    let Some(ncx_item) = ncx_item else {
        return Ok(None);
    };
    let ncx_path = if opf_dir.is_empty() {
        ncx_item.href.clone()
    } else {
        format!("{}/{}", opf_dir, ncx_item.href)
    };
    let Some(bytes) = zip.read_file_limited(&ncx_path, crate::api::models::MAX_CHAPTER_SIZE)?
    else {
        return Ok(None);
    };
    let text = decode_bytes(&bytes, encoding_name);
    Ok(Some(parse_ncx(&text)))
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
    Option<String>, // ncx_id from <spine toc="...">
);

fn parse_opf(text: &str) -> Result<OpfResult> {
    let mut reader = Reader::from_str(text);
    reader.config_mut().trim_text(true);
    reader.config_mut().allow_dangling_amp = true;
    let mut metadata: HashMap<String, String> = HashMap::new();
    let mut manifest_items: HashMap<String, ManifestItem> = HashMap::new();
    let mut spine_ids: Vec<String> = Vec::new();
    let mut ncx_id: Option<String> = None;

    let mut in_metadata = false;
    let mut in_manifest = false;
    let mut in_spine = false;
    let mut in_dc_tag = false;
    let mut current_dc_tag = String::new();
    let mut current_text = String::new();
    // LW-8.1: track rendition property name for <meta property="rendition:*">text</meta>
    let mut in_rendition_meta = false;
    let mut current_rendition_prop = String::new();

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                match tag.as_str() {
                    "metadata" => in_metadata = true,
                    "manifest" => in_manifest = true,
                    "spine" => {
                        in_spine = true;
                        if let Some(toc) = get_xml_attr(e, b"toc") {
                            ncx_id = Some(toc);
                        }
                    }
                    _ => {
                        // DC metadata tags: dc:title, dc:creator, etc.
                        // local_name() strips namespace prefix, so check both forms
                        let is_dc_tag = in_metadata
                            && (tag.starts_with("dc:")
                                || matches!(
                                    tag.as_str(),
                                    "title"
                                        | "creator"
                                        | "language"
                                        | "description"
                                        | "publisher"
                                        | "date"
                                        | "identifier"
                                        | "subject"
                                        | "contributor"
                                        | "rights"
                                        | "source"
                                        | "type"
                                        | "format"
                                        | "coverage"
                                        | "relation"
                                ));
                        if is_dc_tag {
                            in_dc_tag = true;
                            current_dc_tag = tag.trim_start_matches("dc:").to_string();
                            current_text.clear();
                        }
                        if in_metadata && tag == "meta" {
                            // Handle <meta name="cover" content="cover-id"/>
                            let name = get_xml_attr(e, b"name");
                            let content = get_xml_attr(e, b"content");
                            if let Some(ref n) = name {
                                if n == "cover" {
                                    if let Some(c) = &content {
                                        metadata.insert("cover-id".to_string(), c.clone());
                                    }
                                }
                            }
                            // LW-8.1: EPUB3 rendition properties (<meta property="rendition:*">)
                            let property = get_xml_attr(e, b"property");
                            if let Some(ref prop) = property {
                                if prop.starts_with("rendition:") {
                                    if let Some(c) = content {
                                        metadata.insert(prop.clone(), c);
                                    } else {
                                        // text content follows — track for End event
                                        in_rendition_meta = true;
                                        current_rendition_prop = prop.clone();
                                        current_text.clear();
                                    }
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
                let t = e.xml10_content().unwrap_or_default();
                if in_dc_tag {
                    current_text.push_str(&t);
                }
                if in_rendition_meta {
                    current_text.push_str(&t);
                }
            }
            Ok(Event::CData(ref e)) => {
                let text = e.xml10_content().unwrap_or_default();
                if in_dc_tag {
                    current_text.push_str(&text);
                }
                if in_rendition_meta {
                    current_text.push_str(&text);
                }
            }
            Ok(Event::GeneralRef(ref e)) => {
                let text = e.xml10_content().unwrap_or_default();
                if in_dc_tag {
                    current_text.push_str(&text);
                }
                if in_rendition_meta {
                    current_text.push_str(&text);
                }
            }
            Ok(Event::End(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
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
                        // LW-8.1: close rendition meta (text content collected)
                        if in_rendition_meta && tag == "meta" {
                            let val = current_text.trim().to_string();
                            if !val.is_empty() {
                                metadata.insert(current_rendition_prop.clone(), val);
                            }
                            in_rendition_meta = false;
                            current_rendition_prop.clear();
                            current_text.clear();
                        }
                    }
                }
            }
            // Handle self-closing tags like <item ... /> and <itemref ... />
            Ok(Event::Empty(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
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
                if in_metadata && tag == "meta" {
                    let name = get_xml_attr(e, b"name");
                    let content = get_xml_attr(e, b"content");
                    if let (Some(n), Some(c)) = (name, content) {
                        if n == "cover" {
                            metadata.insert("cover-id".to_string(), c);
                        }
                    }
                    // LW-8.1: self-closing rendition property
                    let property = get_xml_attr(e, b"property");
                    let value = get_xml_attr(e, b"content");
                    if let (Some(ref prop), Some(c)) = (property, value) {
                        if prop.starts_with("rendition:") {
                            metadata.insert(prop.clone(), c);
                        }
                    }
                }
            }
            Err(e) => bail!("OPF parse error: {}", e),
            _ => {}
        }
    }

    Ok((metadata, manifest_items, spine_ids, ncx_id))
}

/// Parse NCX (EPUB 2 table of contents).
fn parse_ncx(text: &str) -> Vec<TocEntry> {
    let mut reader = Reader::from_str(text);
    reader.config_mut().trim_text(true);
    let mut entries: Vec<TocEntry> = Vec::new();
    let mut current_title = String::new();
    let mut in_nav_label = false;
    let mut in_text = false;

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                match tag.as_str() {
                    "navLabel" => in_nav_label = true,
                    "text" if in_nav_label => in_text = true,
                    _ => {}
                }
            }
            Ok(Event::Text(ref e)) => {
                if in_text {
                    current_title.push_str(&e.xml10_content().unwrap_or_default());
                }
            }
            Ok(Event::End(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                match tag.as_str() {
                    "text" if in_nav_label => in_text = false,
                    "navLabel" => in_nav_label = false,
                    "navPoint" => {
                        if !current_title.trim().is_empty() {
                            entries.push(TocEntry {
                                title: current_title.trim().to_string(),
                                chapter_index: -1,
                                children: Vec::new(),
                            });
                        }
                        current_title.clear();
                    }
                    _ => {}
                }
            }
            _ => {}
        }
    }
    entries
}

/// Parse EPUB 3 nav.xhtml (table of contents).
fn parse_nav_xhtml(text: &str) -> Vec<TocEntry> {
    // Look for <nav epub:type="toc"> <ol> <li> <a href="...">text</a> ...
    let mut reader = Reader::from_str(text);
    let mut entries: Vec<TocEntry> = Vec::new();
    let mut stack: Vec<Vec<TocEntry>> = Vec::new();
    let mut in_toc_nav = false;
    let mut in_li = false;
    let mut in_a = false;
    let mut current_title = String::new();
    let mut current_href = String::new();

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                if !in_toc_nav {
                    if tag == "nav" {
                        // Check for epub:type="toc"
                        for attr in e.attributes().filter_map(|a| a.ok()) {
                            if attr.key.as_ref() == b"epub:type" || attr.key.as_ref() == b"type" {
                                let val = String::from_utf8_lossy(&attr.value);
                                if val == "toc" {
                                    in_toc_nav = true;
                                }
                                break;
                            }
                        }
                    }
                } else if tag == "ol" {
                    stack.push(Vec::new());
                } else if tag == "li" {
                    in_li = true;
                    current_title.clear();
                    current_href.clear();
                } else if in_li && tag == "a" {
                    in_a = true;
                    if let Some(href) = get_xml_attr(e, b"href") {
                        current_href = href;
                    }
                }
            }
            Ok(Event::Text(ref e)) => {
                let text = e.xml10_content().unwrap_or_default().to_string();
                if in_a {
                    current_title.push_str(&text);
                }
            }
            Ok(Event::End(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                if tag == "ol" && !stack.is_empty() {
                    let children = stack.pop().unwrap_or_default();
                    if let Some(parent) = stack.last_mut() {
                        // Add the children to the last entry of the parent
                        if let Some(last) = parent.last_mut() {
                            last.children = children;
                        }
                    } else {
                        // Top-level list
                        entries = children;
                    }
                } else if tag == "li" {
                    in_li = false;
                    let entry = TocEntry {
                        title: current_title.trim().to_string(),
                        chapter_index: -1,
                        children: Vec::new(),
                    };
                    if !current_title.trim().is_empty() {
                        if let Some(top) = stack.last_mut() {
                            top.push(entry);
                        }
                    }
                    current_title.clear();
                    current_href.clear();
                } else if tag == "a" {
                    in_a = false;
                }
            }
            _ => {}
        }
    }
    entries
}

fn extract_cover_url(
    zip: &mut ZipFile,
    manifest: &HashMap<String, ManifestItem>,
    metadata: &HashMap<String, String>,
    opf_dir: &str,
    _encoding_name: &str,
) -> Result<Option<String>> {
    // Try cover-id from <meta name="cover" content="..."/>
    if let Some(cover_id) = metadata.get("cover-id") {
        if let Some(item) = manifest.get(cover_id.as_str()) {
            let href = if opf_dir.is_empty() {
                item.href.clone()
            } else {
                format!("{}/{}", opf_dir, item.href)
            };
            if let Some(cover) = read_cover_image(zip, &href, &item.media_type)? {
                return Ok(Some(cover));
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
            if let Some(cover) = read_cover_image(zip, &href, &item.media_type)? {
                return Ok(Some(cover));
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
            if let Some(cover) = read_cover_image(zip, &href, &item.media_type)? {
                return Ok(Some(cover));
            }
        }
    }

    Ok(None)
}

fn read_cover_image(zip: &mut ZipFile, href: &str, media_type: &str) -> Result<Option<String>> {
    let bytes = zip.read_file_limited(href, crate::api::models::MAX_IMAGE_SIZE)?;
    Ok(bytes.map(|data| encode_data_uri(media_type, &data)))
}

fn encode_data_uri(mime: &str, bytes: &[u8]) -> String {
    format!("data:{};base64,{}", mime, STANDARD.encode(bytes))
}

/// Collect CSS class→properties map from `<style>` elements in XHTML.
/// Uses html5ever (via scraper) for robust extraction from malformed HTML.
#[allow(unused_mut, unused_variables)]
fn extract_css(text: &str) -> HashMap<String, HashMap<String, String>> {
    let mut all_style = String::new();
    #[cfg(not(miri))]
    {
        let doc = scraper::Html::parse_document(text);
        let sel = scraper::Selector::parse("style").unwrap();
        for style in doc.select(&sel) {
            if let Some(content) = style.first_child().and_then(|n| n.value().as_text()) {
                all_style.push_str(content);
                all_style.push('\n');
            }
        }
    }
    if all_style.is_empty() {
        return HashMap::new();
    }
    parse_css_rules(&all_style)
}

/// Parse CSS rule blocks from concatenated style content.
fn parse_css_rules(css: &str) -> HashMap<String, HashMap<String, String>> {
    let mut rules: HashMap<String, HashMap<String, String>> = HashMap::new();
    let expanded = expand_media_queries(css);
    for line in expanded.lines() {
        let line = line.trim();
        if let Some(body_start) = line.find('{') {
            if let Some(body_end) = line.rfind('}') {
                let selector = &line[..body_start].trim();
                let body = &line[body_start + 1..body_end];
                let selector = if selector.starts_with('.') {
                    selector
                } else if !selector.contains(' ') && !selector.contains(':') {
                    let tag = selector.trim();
                    if !tag.is_empty() {
                        selector
                    } else {
                        continue;
                    }
                } else {
                    continue;
                };
                if !selector.is_empty() {
                    let props = rules.entry(selector.to_string()).or_default();
                    for prop in body.split(';') {
                        let prop = prop.trim();
                        if let Some(colon) = prop.find(':') {
                            let name = prop[..colon].trim().to_string();
                            let value = prop[colon + 1..].trim().to_string();
                            if !name.is_empty() && !value.is_empty() {
                                props.insert(name, value);
                            }
                        }
                    }
                }
            }
        }
    }
    rules
}

/// LW-1.4: expand @media blocks — extract inner rules so they participate in normal CSS matching.
/// ponytail: treats all @media as "always apply" (screen reader = screen context).
fn expand_media_queries(css: &str) -> String {
    let mut result = String::with_capacity(css.len());
    let mut i = 0;
    let bytes = css.as_bytes();
    while i < bytes.len() {
        // Look for @media at start of a rule or after whitespace/newline
        if bytes[i] == b'@' {
            let rest = &css[i..];
            if rest.to_lowercase().starts_with("@media") {
                // Skip past @media <query> {
                if let Some(open) = rest.find('{') {
                    let mut depth = 1;
                    let mut j = i + open + 1;
                    while j < bytes.len() && depth > 0 {
                        match bytes[j] {
                            b'{' => depth += 1,
                            b'}' => depth -= 1,
                            _ => {}
                        }
                        j += 1;
                    }
                    // Extract inner content (between the outer braces)
                    let inner = &css[i + open + 1..j - 1];
                    result.push_str(inner);
                    result.push('\n');
                    i = j;
                    continue;
                }
            }
        }
        result.push(bytes[i] as char);
        i += 1;
    }
    result
}

/// CRT-1.14: extract @font-face declarations from XHTML text.
/// Uses html5ever (via scraper) for robust extraction from malformed HTML.
#[allow(unused_mut, unused_variables)]
fn extract_font_faces(text: &str) -> Vec<(String, String)> {
    let mut faces = Vec::new();
    #[cfg(not(miri))]
    {
        let doc = scraper::Html::parse_document(text);
        let sel = scraper::Selector::parse("style").unwrap();
        for style in doc.select(&sel) {
            if let Some(content) = style.first_child().and_then(|n| n.value().as_text()) {
                let style_text = content.to_string();
                let expanded = expand_media_queries(&style_text);
                let mut pos = 0;
                while let Some(start) = expanded[pos..].find("@font-face") {
                    let abs_start = pos + start;
                    if let Some(brace) = expanded[abs_start..].find('{') {
                        let block_start = abs_start + brace + 1;
                        let mut depth = 1i32;
                        let mut j = block_start;
                        let bytes = expanded.as_bytes();
                        while j < bytes.len() && depth > 0 {
                            match bytes[j] {
                                b'{' => depth += 1,
                                b'}' => depth -= 1,
                                _ => {}
                            }
                            j += 1;
                        }
                        let block = &expanded[block_start..j - 1];
                        let mut font_family = String::new();
                        let mut src = String::new();
                        for prop in block.split(';') {
                            let prop = prop.trim();
                            if let Some(colon) = prop.find(':') {
                                let name = prop[..colon].trim();
                                let value = prop[colon + 1..].trim();
                                if name == "font-family" {
                                    font_family =
                                        value.trim_matches(|c| c == '\'' || c == '"').to_string();
                                } else if name == "src" {
                                    if let Some(url_start) = value.find("url(") {
                                        let rest = &value[url_start + 4..];
                                        if let Some(url_end) = rest.find(')') {
                                            src = rest[..url_end]
                                                .trim_matches(|c| c == '\'' || c == '"')
                                                .to_string();
                                        }
                                    }
                                }
                            }
                        }
                        if !font_family.is_empty() && !src.is_empty() {
                            faces.push((font_family, src));
                        }
                        pos = j;
                    } else {
                        pos = abs_start + 10;
                    }
                }
            }
        }
    }
    faces
}

/// Apply CSS properties to a ReaderBlock by matching tag/class selectors.
/// ponytail: only text-indent and text-align; no cascade, no inheritance, no compound selectors.
fn apply_css_props(
    block: &mut ReaderBlock,
    tag: &str,
    class: Option<&str>,
    css: &HashMap<String, HashMap<String, String>>,
) {
    // MD-1.1: CSS inheritance — body properties apply to all blocks first (lowest priority)
    if tag != "body" {
        if let Some(props) = css.get("body") {
            apply_props(block, props);
        }
    }
    // MD-1.1: cascade by specificity — tag < class < compound
    // Tag selector
    if let Some(props) = css.get(tag) {
        apply_props(block, props);
    }
    // MD-1.1: multiple classes — HTML allows class="poem italic", apply each in order
    if let Some(class_str) = class {
        for cls in class_str.split_whitespace() {
            let class_sel = format!(".{}", cls);
            if let Some(props) = css.get(&class_sel) {
                apply_props(block, props);
            }
        }
    }
    // Compound selector: tag.class (e.g., "p.poem")
    if let Some(class_str) = class {
        for cls in class_str.split_whitespace() {
            let compound = format!("{}.{}", tag, cls);
            if let Some(props) = css.get(&compound) {
                apply_props(block, props);
            }
        }
    }
}

/// RCE-7.3: Inline CSS normalization — apply CSS properties to a ReaderBlock.
/// ponytail: text-indent, text-align, white-space, margin-left, line-height, font-weight, font-style, color, display.
fn apply_props(block: &mut ReaderBlock, props: &HashMap<String, String>) {
    // RCE-7.3: display:none removes every renderable payload from the block.
    if let Some(display) = props.get("display") {
        if display.trim() == "none" {
            block.text.clear();
            block.block_type = BlockType::Paragraph;
            block.image_url = None;
            block.image_alt = None;
            block.rich_spans = None;
            block.list_items = None;
            block.table_rows = None;
            return;
        }
    }
    if let Some(indent) = props.get("text-indent") {
        if let Some(v) = parse_css_length(indent) {
            block.text_indent = Some(v);
        }
    }
    if let Some(align) = props.get("text-align") {
        block.text_align = Some(align.clone());
    }
    // MD-1.7: white-space: pre/pre-wrap — store as special value with ws: prefix
    if let Some(ws) = props.get("white-space") {
        let v = ws.trim();
        if v == "pre" || v == "pre-wrap" || v == "nowrap" {
            let ws_val = format!("ws:{v}");
            let new_align = match block.text_align.take() {
                Some(existing) => format!("{existing}|{ws_val}"),
                None => ws_val,
            };
            block.text_align = Some(new_align);
        }
    }
    // MD-1.2: margin-left as text-indent fallback for indented blocks
    if block.text_indent.is_none() {
        if let Some(ml) = props.get("margin-left") {
            if let Some(v) = parse_css_length(ml) {
                block.text_indent = Some(v);
            }
        }
    }
    // Store extra CSS properties as pipe-separated prefixes in text_align
    // Format: "left|fg:#333|lh:1.5|fw:700|fs:italic"
    let extra: &[(&str, &str)] = &[
        ("color", "fg"),
        ("background-color", "bg"),
        ("line-height", "lh"),
        ("font-weight", "fw"),
        ("font-style", "fs"),
        ("text-decoration", "td"),
        ("padding-left", "pl"),
        ("opacity", "op"),
    ];
    for &(css_prop, prefix) in extra {
        if let Some(val) = props.get(css_prop) {
            let stored = format!("{prefix}:{}", val.trim());
            let new_align = match block.text_align.take() {
                Some(existing) => format!("{existing}|{stored}"),
                None => stored,
            };
            block.text_align = Some(new_align);
        }
    }
}

/// MD-1.4: check if CSS has page-break-before: always for given tag/class.
fn css_has_page_break(
    css: &HashMap<String, HashMap<String, String>>,
    tag: &str,
    class: Option<&str>,
) -> bool {
    if let Some(props) = css.get(tag) {
        if has_page_break_prop(props) {
            return true;
        }
    }
    if let Some(cls) = class {
        let class_sel = format!(".{}", cls);
        if css.get(&class_sel).is_some_and(has_page_break_prop) {
            return true;
        }
    }
    false
}

fn has_page_break_prop(props: &HashMap<String, String>) -> bool {
    if let Some(val) = props
        .get("page-break-before")
        .or_else(|| props.get("break-before"))
    {
        let v = val.trim();
        return v == "always" || v == "page";
    }
    false
}

/// MD-1.2: convert CSS length units to pixels. Default base = 16px (browser standard).
fn parse_css_length(value: &str) -> Option<f64> {
    let v = value.trim();
    // ponytail: 16px base font, 96/72 pt→px
    if let Some(rest) = v.strip_suffix("em").or_else(|| v.strip_suffix("rem")) {
        rest.trim().parse::<f64>().ok().map(|n| n * 16.0)
    } else if let Some(rest) = v.strip_suffix("px") {
        rest.trim().parse::<f64>().ok()
    } else if let Some(rest) = v.strip_suffix("pt") {
        rest.trim().parse::<f64>().ok().map(|n| n * 96.0 / 72.0)
    } else if let Some(rest) = v.strip_suffix('%') {
        // ponytail: percentage of base font width (approx)
        rest.trim().parse::<f64>().ok().map(|n| n * 16.0 / 100.0)
    } else {
        // No unit → assume px
        v.parse::<f64>().ok()
    }
}

fn parse_xhtml_to_blocks(
    text: &str,
    mut block_index: i32,
    css: &HashMap<String, HashMap<String, String>>,
) -> (Vec<ReaderBlock>, i32, Vec<usize>) {
    let arena = Bump::new();
    let mut reader = Reader::from_str(text);
    reader.config_mut().trim_text(true);
    reader.config_mut().allow_dangling_amp = true;
    let mut blocks: Vec<ReaderBlock> = Vec::new();
    let mut page_breaks: Vec<usize> = Vec::new();
    let mut current_text = String::new();
    let mut in_body = false;
    let mut in_block = false; // inside p, h1-h6, blockquote
    let mut in_pre = false;
    let mut block_type = BlockType::Paragraph;
    let mut heading_level: Option<i32> = None;
    let mut blockquote_depth: i32 = 0;
    let mut current_class: Option<&str> = None;

    // Rich span tracking
    let mut rich_spans: Vec<RichSpan> = Vec::new();
    let mut span_text = String::new();
    let mut bold = false;
    let mut italic = false;
    let mut superscript = false;
    let mut href: Option<String> = None;

    // Table state
    let mut table_rows: Vec<Vec<String>> = Vec::new();
    let mut current_row: Vec<String> = Vec::new();
    let mut in_table = false;

    // List state
    let mut in_list = false;
    let mut list_items: Vec<String> = Vec::new();

    // Pre-computed heading tag names (avoid format!("h{}", level) on every heading)
    const H_TAGS: [&str; 6] = ["h1", "h2", "h3", "h4", "h5", "h6"];

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref e)) => {
                let local_name = e.local_name();
                let name = local_name.as_ref();
                current_class = get_class_attr_arena(e, &arena);
                match name {
                    b"body" => in_body = true,
                    b"aside" if in_body => {
                        if attr_eq(e, b"epub:type", b"footnote") || attr_eq(e, b"type", b"footnote")
                        {
                            flush_block(
                                &mut blocks,
                                &mut current_text,
                                &mut rich_spans,
                                &mut block_index,
                                BlockType::Footnote,
                                None,
                                None,
                            );
                            current_text.clear();
                            rich_spans.clear();
                            span_text.clear();
                            in_block = true;
                            block_type = BlockType::Footnote;
                            href = None;
                        }
                    }
                    b"p" | b"pre" if in_body => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            bold,
                            italic,
                            superscript,
                            &href,
                        );
                        flush_block(
                            &mut blocks,
                            &mut current_text,
                            &mut rich_spans,
                            &mut block_index,
                            block_type.clone(),
                            heading_level,
                            None,
                        );
                        current_text.clear();
                        rich_spans.clear();
                        span_text.clear();
                        in_block = true;
                        in_pre = name == b"pre";
                        block_type = if blockquote_depth > 0 {
                            BlockType::Quote
                        } else {
                            BlockType::Paragraph
                        };
                        heading_level = None;
                    }
                    b if b.starts_with(b"h") && b.len() == 2 && in_body => {
                        let digit = b[1];
                        if digit.is_ascii_digit() {
                            flush_rich_span(
                                &mut rich_spans,
                                &mut span_text,
                                bold,
                                italic,
                                superscript,
                                &href,
                            );
                            flush_block(
                                &mut blocks,
                                &mut current_text,
                                &mut rich_spans,
                                &mut block_index,
                                block_type.clone(),
                                heading_level,
                                None,
                            );
                            current_text.clear();
                            rich_spans.clear();
                            span_text.clear();
                            in_block = true;
                            block_type = BlockType::Heading;
                            heading_level = Some(digit as i32 - b'0' as i32);
                        }
                    }
                    b"blockquote" if in_body => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            bold,
                            italic,
                            superscript,
                            &href,
                        );
                        flush_block(
                            &mut blocks,
                            &mut current_text,
                            &mut rich_spans,
                            &mut block_index,
                            block_type.clone(),
                            heading_level,
                            None,
                        );
                        current_text.clear();
                        rich_spans.clear();
                        span_text.clear();
                        in_block = true;
                        block_type = BlockType::Quote;
                        heading_level = None;
                        blockquote_depth += 1;
                    }
                    b"table" if in_body => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            bold,
                            italic,
                            superscript,
                            &href,
                        );
                        flush_block(
                            &mut blocks,
                            &mut current_text,
                            &mut rich_spans,
                            &mut block_index,
                            block_type.clone(),
                            heading_level,
                            None,
                        );
                        current_text.clear();
                        rich_spans.clear();
                        span_text.clear();
                        in_table = true;
                        table_rows.clear();
                    }
                    b"tr" if in_table => {
                        current_row.clear();
                    }
                    b"td" | b"th" if in_table => {
                        span_text.clear();
                        rich_spans.clear();
                    }
                    b"ul" if in_body => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            bold,
                            italic,
                            superscript,
                            &href,
                        );
                        flush_block(
                            &mut blocks,
                            &mut current_text,
                            &mut rich_spans,
                            &mut block_index,
                            block_type.clone(),
                            heading_level,
                            None,
                        );
                        current_text.clear();
                        rich_spans.clear();
                        span_text.clear();
                        in_list = true;
                        list_items.clear();
                    }
                    b"ol" if in_body => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            bold,
                            italic,
                            superscript,
                            &href,
                        );
                        flush_block(
                            &mut blocks,
                            &mut current_text,
                            &mut rich_spans,
                            &mut block_index,
                            block_type.clone(),
                            heading_level,
                            None,
                        );
                        current_text.clear();
                        rich_spans.clear();
                        span_text.clear();
                        in_list = true;
                        list_items.clear();
                    }
                    b"li" if in_list => {
                        span_text.clear();
                        rich_spans.clear();
                    }
                    // Inline formatting tags
                    b"strong" | b"b" if in_block => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            bold,
                            italic,
                            superscript,
                            &href,
                        );
                        bold = true;
                    }
                    b"em" | b"i" if in_block => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            bold,
                            italic,
                            superscript,
                            &href,
                        );
                        italic = true;
                    }
                    b"sup" if in_block => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            bold,
                            italic,
                            superscript,
                            &href,
                        );
                        superscript = true;
                    }
                    b"a" if in_block => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            bold,
                            italic,
                            superscript,
                            &href,
                        );
                        href =
                            get_xml_attr(e, b"href").and_then(|h| crate::book::sanitize_href(&h));
                    }
                    b"br" if in_block => {
                        span_text.push('\n');
                        current_text.push('\n');
                    }
                    _ => {}
                }
            }
            Ok(Event::Text(ref e)) => {
                if in_body {
                    let text = e.xml10_content().unwrap_or_default();
                    if in_block {
                        span_text.push_str(&text);
                        current_text.push_str(&text);
                    } else if in_table {
                        // Inside td/th - accumulate for cell
                        span_text.push_str(&text);
                    } else {
                        current_text.push_str(&text);
                    }
                }
            }
            Ok(Event::CData(ref e)) => {
                if in_body {
                    let text = e.xml10_content().unwrap_or_default();
                    if in_block || in_table {
                        span_text.push_str(&text);
                        if in_block {
                            current_text.push_str(&text);
                        }
                    } else {
                        current_text.push_str(&text);
                    }
                }
            }
            Ok(Event::GeneralRef(ref e)) => {
                if in_body {
                    let text = e.xml10_content().unwrap_or_default();
                    if in_block || in_table {
                        span_text.push_str(&text);
                        if in_block {
                            current_text.push_str(&text);
                        }
                    } else {
                        current_text.push_str(&text);
                    }
                }
            }
            Ok(Event::End(ref e)) => {
                let local_name = e.local_name();
                let name = local_name.as_ref();
                match name {
                    b"body" => in_body = false,
                    b"aside" if in_block && block_type == BlockType::Footnote => {
                        flush_block(
                            &mut blocks,
                            &mut current_text,
                            &mut rich_spans,
                            &mut block_index,
                            BlockType::Footnote,
                            None,
                            None,
                        );
                        current_text.clear();
                        rich_spans.clear();
                        span_text.clear();
                        in_block = false;
                        block_type = BlockType::Paragraph;
                    }
                    b"p" | b"pre" if in_block && block_type == BlockType::Paragraph => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            bold,
                            italic,
                            superscript,
                            &href,
                        );
                        let t = current_text.trim().to_string();
                        let rich = if rich_spans.is_empty() {
                            None
                        } else {
                            // If we only have one span that covers all text, flatten
                            if rich_spans.len() == 1 && rich_spans[0].text == t {
                                None
                            } else {
                                Some(rich_spans.clone())
                            }
                        };
                        if !t.is_empty() || rich.is_some() {
                            blocks.push(ReaderBlock {
                                index: block_index,
                                text: t,
                                block_type: BlockType::Paragraph,
                                image_url: None,
                                note_ref: None,
                                rich_spans: rich,
                                heading_level: None,
                                ordered: None,
                                list_items: None,
                                table_rows: None,
                                image_alt: None,
                                text_indent: None,
                                text_align: if in_pre {
                                    Some("ws:pre".to_string())
                                } else {
                                    None
                                },
                                note_id: None,
                            });
                            if let Some(cls) = current_class {
                                if let Some(last) = blocks.last_mut() {
                                    apply_css_props(last, "p", Some(cls), css);
                                    apply_css_props(last, "pre", Some(cls), css);
                                }
                                // MD-1.4: track page-break-before
                                if css_has_page_break(css, "p", Some(cls))
                                    || css_has_page_break(css, "pre", Some(cls))
                                {
                                    page_breaks.push(blocks.len());
                                }
                            } else if css_has_page_break(css, "p", None)
                                || css_has_page_break(css, "pre", None)
                            {
                                page_breaks.push(blocks.len());
                            }
                            block_index += 1;
                        }
                        current_text.clear();
                        rich_spans.clear();
                        span_text.clear();
                        in_block = false;
                        bold = false;
                        italic = false;
                        superscript = false;
                        href = None;
                    }
                    b if b.starts_with(b"h")
                        && b.len() == 2
                        && in_block
                        && block_type == BlockType::Heading =>
                    {
                        let digit = b[1];
                        if digit.is_ascii_digit() {
                            let expected_level = digit as i32 - b'0' as i32;
                            if heading_level == Some(expected_level) {
                                flush_rich_span(
                                    &mut rich_spans,
                                    &mut span_text,
                                    bold,
                                    italic,
                                    superscript,
                                    &href,
                                );
                                let t_text = current_text.trim().to_string();
                                if !t_text.is_empty() {
                                    blocks.push(ReaderBlock {
                                        index: block_index,
                                        text: t_text,
                                        block_type: BlockType::Heading,
                                        image_url: None,
                                        note_ref: None,
                                        rich_spans: if rich_spans.is_empty() {
                                            None
                                        } else {
                                            Some(rich_spans.clone())
                                        },
                                        heading_level,
                                        ordered: None,
                                        list_items: None,
                                        table_rows: None,
                                        image_alt: None,
                                        text_indent: None,
                                        text_align: None,
                                        note_id: None,
                                    });
                                    let htag = match heading_level {
                                        Some(lv @ 1..=6) => H_TAGS[(lv - 1) as usize],
                                        _ => "h1",
                                    };
                                    if let Some(cls) = current_class {
                                        if let Some(last) = blocks.last_mut() {
                                            apply_css_props(last, htag, Some(cls), css);
                                        }
                                        // MD-1.4: track page-break-before on headings
                                        if css_has_page_break(css, htag, Some(cls)) {
                                            page_breaks.push(blocks.len());
                                        }
                                    } else if css_has_page_break(css, htag, None) {
                                        page_breaks.push(blocks.len());
                                    }
                                    block_index += 1;
                                }
                                current_text.clear();
                                rich_spans.clear();
                                span_text.clear();
                                in_block = false;
                                in_pre = false;
                                bold = false;
                                italic = false;
                                superscript = false;
                                href = None;
                                blockquote_depth = (blockquote_depth - 1).max(0);
                            }
                        }
                    }
                    b"blockquote" if in_block && block_type == BlockType::Quote => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            bold,
                            italic,
                            superscript,
                            &href,
                        );
                        let t = current_text.trim().to_string();
                        if !t.is_empty() {
                            blocks.push(ReaderBlock {
                                index: block_index,
                                text: t,
                                block_type: BlockType::Quote,
                                image_url: None,
                                note_ref: None,
                                rich_spans: if rich_spans.is_empty() {
                                    None
                                } else {
                                    Some(rich_spans.clone())
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
                            if let Some(cls) = current_class {
                                if let Some(last) = blocks.last_mut() {
                                    apply_css_props(last, "blockquote", Some(cls), css);
                                }
                            }
                            block_index += 1;
                        }
                        current_text.clear();
                        rich_spans.clear();
                        span_text.clear();
                        in_block = false;
                        bold = false;
                        italic = false;
                        superscript = false;
                        href = None;
                    }
                    b"td" | b"th" if in_table => {
                        let t = span_text.trim().to_string();
                        current_row.push(t);
                        span_text.clear();
                    }
                    b"tr" if in_table => {
                        if !current_row.is_empty() {
                            table_rows.push(current_row.clone());
                            current_row.clear();
                        }
                    }
                    b"table" if in_table => {
                        in_table = false;
                        if !table_rows.is_empty() {
                            let text = table_rows
                                .iter()
                                .map(|r| r.join(" | "))
                                .collect::<Vec<_>>()
                                .join("\n");
                            blocks.push(ReaderBlock {
                                index: block_index,
                                text,
                                block_type: BlockType::Table,
                                image_url: None,
                                note_ref: None,
                                rich_spans: None,
                                heading_level: None,
                                ordered: None,
                                list_items: None,
                                table_rows: Some(table_rows.clone()),
                                image_alt: None,
                                text_indent: None,
                                text_align: None,
                                note_id: None,
                            });
                            block_index += 1;
                            table_rows.clear();
                        }
                    }
                    b"li" if in_list => {
                        let t = span_text.trim().to_string();
                        if !t.is_empty() {
                            list_items.push(t);
                        }
                        span_text.clear();
                    }
                    b"ul" if in_list => {
                        in_list = false;
                        if !list_items.is_empty() {
                            let text = list_items.join("\n");
                            let items = list_items
                                .iter()
                                .enumerate()
                                .map(|(i, item)| ReaderBlock {
                                    index: block_index + i as i32,
                                    text: item.clone(),
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
                                index: block_index,
                                text,
                                block_type: BlockType::List,
                                image_url: None,
                                note_ref: None,
                                rich_spans: None,
                                heading_level: None,
                                ordered: Some(false),
                                list_items: Some(items),
                                table_rows: None,
                                image_alt: None,
                                text_indent: None,
                                text_align: None,
                                note_id: None,
                            });
                            block_index += 1;
                            list_items.clear();
                        }
                    }
                    b"ol" if in_list => {
                        in_list = false;
                        if !list_items.is_empty() {
                            let text = list_items.join("\n");
                            let items = list_items
                                .iter()
                                .enumerate()
                                .map(|(i, item)| ReaderBlock {
                                    index: block_index + i as i32,
                                    text: item.clone(),
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
                                index: block_index,
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
                            block_index += 1;
                            list_items.clear();
                        }
                    }
                    // Inline formatting end tags
                    b"strong" | b"b" if in_block => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            bold,
                            italic,
                            superscript,
                            &href,
                        );
                        bold = false;
                    }
                    b"em" | b"i" if in_block => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            bold,
                            italic,
                            superscript,
                            &href,
                        );
                        italic = false;
                    }
                    b"sup" if in_block => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            bold,
                            italic,
                            superscript,
                            &href,
                        );
                        superscript = false;
                    }
                    b"a" if in_block => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            bold,
                            italic,
                            superscript,
                            &href,
                        );
                        href = None;
                    }
                    _ => {}
                }
            }
            Ok(Event::Empty(ref e)) => {
                let local_name = e.local_name();
                let name = local_name.as_ref();
                if name == b"hr" && in_body {
                    blocks.push(ReaderBlock {
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
                } else if name == b"img" && in_body {
                    let src = get_xml_attr(e, b"src");
                    let alt = get_xml_attr(e, b"alt");
                    blocks.push(ReaderBlock {
                        index: block_index,
                        text: String::new(),
                        block_type: BlockType::Image,
                        image_url: src,
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
                    });
                    block_index += 1;
                } else if name == b"image" && in_body {
                    // CRT-1.15: SVG <image> tags — extract raster fallback from xlink:href or href
                    let src = get_xml_attr(e, b"xlink:href").or_else(|| get_xml_attr(e, b"href"));
                    if let Some(image_src) = src {
                        blocks.push(ReaderBlock {
                            index: block_index,
                            text: String::new(),
                            block_type: BlockType::Image,
                            image_url: Some(image_src),
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
                } else if name == b"br" && in_body {
                    if in_block {
                        span_text.push('\n');
                    } else {
                        current_text.push('\n');
                    }
                } else if name == b"img" && in_block {
                    // Inline image inside paragraph - treat as text placeholder
                    let src = get_xml_attr(e, b"src").unwrap_or_default();
                    span_text.push_str(&format!("[img:{}]", src));
                }
            }
            Err(_) => break,
            _ => {}
        }
    }

    // Flush any remaining text
    flush_rich_span(
        &mut rich_spans,
        &mut span_text,
        bold,
        italic,
        superscript,
        &href,
    );
    flush_block(
        &mut blocks,
        &mut current_text,
        &mut rich_spans,
        &mut block_index,
        block_type.clone(),
        heading_level,
        None,
    );

    // CRT-1.11: apply CSS tag-based selectors to all blocks
    // ponytail: no class tracking in post-process; only tag selectors apply here
    for block in &mut blocks {
        let tag = match block.block_type {
            BlockType::Paragraph => "p",
            BlockType::Heading => {
                if let Some(lvl) = block.heading_level {
                    match lvl {
                        1 => "h1",
                        2 => "h2",
                        3 => "h3",
                        _ => "h4",
                    }
                } else {
                    "h1"
                }
            }
            BlockType::Quote => "blockquote",
            BlockType::Epigraph => "blockquote",
            BlockType::Poem => "p",
            BlockType::Cite => "cite",
            BlockType::List => "ul",
            BlockType::Table => "table",
            BlockType::Separator => "hr",
            _ => "p",
        };
        apply_css_props(block, tag, None, css);
    }

    (blocks, block_index, page_breaks)
}

#[allow(dead_code)]
fn push_block(
    blocks: &mut Vec<ReaderBlock>,
    text: String,
    block_type: BlockType,
    heading_level: Option<i32>,
    note_id: Option<String>,
    rich_spans: Option<Vec<RichSpan>>,
    class: Option<&str>,
    css: &HashMap<String, HashMap<String, String>>,
    index: &mut i32,
) {
    if text.is_empty() && rich_spans.is_none() {
        return;
    }
    let tag = match block_type {
        BlockType::Paragraph => "p",
        BlockType::Heading => "h1",
        BlockType::Quote => "blockquote",
        BlockType::Epigraph => "blockquote",
        BlockType::Poem => "p",
        BlockType::Cite => "cite",
        BlockType::List => "ul",
        BlockType::Table => "table",
        BlockType::Separator => "hr",
        _ => "p",
    };
    let mut block = ReaderBlock {
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
        text_align: None,
        note_id,
    };
    apply_css_props(&mut block, tag, class, css);
    blocks.push(block);
    *index += 1;
}

fn flush_block(
    blocks: &mut Vec<ReaderBlock>,
    text: &mut String,
    rich_spans: &mut Vec<RichSpan>,
    index: &mut i32,
    block_type: BlockType,
    heading_level: Option<i32>,
    note_id: Option<String>,
) {
    let trimmed = crate::book::normalize_typography(text.trim());
    if !trimmed.is_empty() {
        let rich = if rich_spans.is_empty() {
            None
        } else {
            Some(rich_spans.clone())
        };
        // ponytail: flush_block doesn't apply CSS (used for cross-block flushes where class is stale)
        blocks.push(ReaderBlock {
            index: *index,
            text: trimmed,
            block_type,
            image_url: None,
            note_ref: None,
            rich_spans: rich,
            heading_level,
            ordered: None,
            list_items: None,
            table_rows: None,
            image_alt: None,
            text_indent: None,
            text_align: None,
            note_id,
        });
        *index += 1;
    }
    text.clear();
    rich_spans.clear();
}

fn extract_chapter_title(text: &str) -> String {
    let mut reader = Reader::from_str(text);
    reader.config_mut().trim_text(true);
    reader.config_mut().allow_dangling_amp = true;
    let mut in_body = false;
    let mut in_title = false;
    let mut title = String::new();
    let mut heading_title = String::new();
    let mut in_heading = false;

    loop {
        match reader.read_event() {
            Ok(Event::Eof) | Err(_) => break,
            Ok(Event::Start(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                match tag.as_str() {
                    "body" => in_body = true,
                    "title" if !in_body && heading_title.is_empty() => {
                        in_title = true;
                        title.clear();
                    }
                    t if t.starts_with('h')
                        && t.len() == 2
                        && in_body
                        && heading_title.is_empty() =>
                    {
                        if let Some(&d) = t.as_bytes().get(1) {
                            if d.is_ascii_digit() {
                                in_heading = true;
                                heading_title.clear();
                            }
                        }
                    }
                    _ => {}
                }
            }
            Ok(Event::Text(ref e)) => {
                if in_title {
                    title.push_str(&e.xml10_content().unwrap_or_default());
                } else if in_heading {
                    heading_title.push_str(&e.xml10_content().unwrap_or_default());
                }
            }
            Ok(Event::GeneralRef(ref e)) => {
                if in_title {
                    title.push_str(&e.xml10_content().unwrap_or_default());
                } else if in_heading {
                    heading_title.push_str(&e.xml10_content().unwrap_or_default());
                }
            }
            Ok(Event::End(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                if tag == "title" && in_title {
                    in_title = false;
                } else if in_heading && tag.starts_with('h') && tag.len() == 2 {
                    in_heading = false;
                }
            }
            _ => {}
        }
    }

    // Prefer heading from body over <title>
    let result = if !heading_title.is_empty() {
        heading_title
    } else {
        title
    };
    result.trim().to_string()
}
