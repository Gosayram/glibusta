use crate::api::models::{
    BlockType, BookFormat, NormalizedBook, ReaderBlock, ReaderChapter, RichSpan, TocEntry,
};
use crate::book::add_soft_hyphens;
use crate::book::archive::{self, ZipFile};
use crate::book::encoding::{
    attr_eq, decode_bytes, get_class_attr_arena, get_normalized_xml_attr, get_xml_attr,
};
use anyhow::{Context, Result, bail};
use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use bumpalo::Bump;
use quick_xml::Reader;
use quick_xml::events::Event;
use serde::Deserialize;
use std::collections::HashMap;

const IDPF_FONT_OBFUSCATION_ALGORITHM: &str = "http://www.idpf.org/2008/embedding";
const ADOBE_FONT_OBFUSCATION_ALGORITHM: &str = "http://ns.adobe.com/pdf/enc#RC";

/// Decode an EPUB XML resource using an explicitly selected encoding, its BOM,
/// or the XML declaration. EPUBs in the wild occasionally use UTF-16 package
/// and content documents; treating every resource as UTF-8 makes such books
/// fail before the XML parser can inspect them.
fn decode_epub_xml(bytes: &[u8], forced_encoding: Option<&str>) -> String {
    let encoding = forced_encoding.or_else(|| {
        if bytes.starts_with(&[0xFF, 0xFE]) {
            Some("utf-16le")
        } else if bytes.starts_with(&[0xFE, 0xFF]) {
            Some("utf-16be")
        } else {
            xml_declared_encoding(bytes)
        }
    });

    decode_bytes(bytes, encoding.unwrap_or("utf-8"))
}

/// Extract an ASCII XML declaration encoding without scanning an unbounded
/// resource. UTF-16 declarations are covered by their mandatory BOM above.
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

fn encryption_algorithm(e: &quick_xml::events::BytesStart<'_>) -> Option<String> {
    e.attributes().flatten().find_map(|attribute| {
        (attribute.key.local_name().as_ref() == b"Algorithm")
            .then(|| String::from_utf8_lossy(&attribute.value).into_owned())
    })
}

fn is_font_obfuscation_algorithm(algorithm: &str) -> bool {
    matches!(
        algorithm,
        IDPF_FONT_OBFUSCATION_ALGORITHM | ADOBE_FONT_OBFUSCATION_ALGORITHM
    )
}

/// Reject content encryption while allowing the two EPUB font-obfuscation
/// algorithms. Font obfuscation is reversible at render time and does not make
/// the book content inaccessible to this parser.
fn validate_epub_encryption(encryption_xml: &[u8]) -> Result<()> {
    let mut reader = Reader::from_reader(encryption_xml);
    let mut buffer = Vec::new();
    let mut in_encrypted_data = false;
    let mut has_algorithm = false;

    loop {
        match reader
            .read_event_into(&mut buffer)
            .context("Invalid META-INF/encryption.xml")?
        {
            Event::Start(e) => {
                let name = e.local_name();
                if name.as_ref() == b"EncryptedData" {
                    if in_encrypted_data {
                        bail!("Invalid nested EPUB EncryptedData entry");
                    }
                    in_encrypted_data = true;
                    has_algorithm = false;
                    if let Some(algorithm) = encryption_algorithm(&e) {
                        if !is_font_obfuscation_algorithm(&algorithm) {
                            bail!("EPUB encryption algorithm is not supported: {algorithm}");
                        }
                        has_algorithm = true;
                    }
                } else if in_encrypted_data && name.as_ref() == b"EncryptionMethod" {
                    let Some(algorithm) = encryption_algorithm(&e) else {
                        bail!("EPUB EncryptionMethod is missing its Algorithm attribute");
                    };
                    if !is_font_obfuscation_algorithm(&algorithm) {
                        bail!("EPUB encryption algorithm is not supported: {algorithm}");
                    }
                    has_algorithm = true;
                }
            }
            Event::Empty(e) => {
                let name = e.local_name();
                if name.as_ref() == b"EncryptedData" {
                    let Some(algorithm) = encryption_algorithm(&e) else {
                        bail!("EPUB EncryptedData is missing an encryption algorithm");
                    };
                    if !is_font_obfuscation_algorithm(&algorithm) {
                        bail!("EPUB encryption algorithm is not supported: {algorithm}");
                    }
                } else if in_encrypted_data && name.as_ref() == b"EncryptionMethod" {
                    let Some(algorithm) = encryption_algorithm(&e) else {
                        bail!("EPUB EncryptionMethod is missing its Algorithm attribute");
                    };
                    if !is_font_obfuscation_algorithm(&algorithm) {
                        bail!("EPUB encryption algorithm is not supported: {algorithm}");
                    }
                    has_algorithm = true;
                }
            }
            Event::End(e) if e.local_name().as_ref() == b"EncryptedData" => {
                if !has_algorithm {
                    bail!("EPUB EncryptedData is missing an encryption algorithm");
                }
                in_encrypted_data = false;
            }
            Event::Eof => break,
            _ => {}
        }
        buffer.clear();
    }

    if in_encrypted_data {
        bail!("Invalid unterminated EPUB EncryptedData entry");
    }
    Ok(())
}

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
    if let Some(encryption_path) = zip
        .entry_names()
        .iter()
        .find(|name| name.eq_ignore_ascii_case("META-INF/encryption.xml"))
        .cloned()
    {
        let encryption_xml = zip
            .read_file_limited(&encryption_path, crate::api::models::MAX_CHAPTER_SIZE)?
            .context("EPUB encryption entry disappeared from archive")?;
        validate_epub_encryption(&encryption_xml)?;
    }

    let mimetype = zip
        .read_file_limited("mimetype", 64)?
        .context("EPUB missing mimetype entry")?;
    if mimetype != b"application/epub+zip" {
        bail!("EPUB has an invalid mimetype entry");
    }

    let container_xml = zip
        .read_file_limited(
            "META-INF/container.xml",
            crate::api::models::MAX_CHAPTER_SIZE,
        )?
        .context("EPUB missing META-INF/container.xml")?;
    let container_text = decode_epub_xml(&container_xml, forced_encoding);
    let opf_path = parse_container_xml(&container_text)?;

    let opf_bytes = zip
        .read_file_limited(&opf_path, crate::api::models::MAX_CHAPTER_SIZE)?
        .with_context(|| format!("OPF file not found: {}", opf_path))?;
    let opf_text = decode_epub_xml(&opf_bytes, forced_encoding);

    let opf_dir = opf_path.rsplit_once('/').map_or("", |(dir, _)| dir);

    let (metadata, manifest_items, spine_ids, ncx_id) = parse_opf(&opf_text)?;
    let guide_references = parse_opf_guide(&opf_text);

    let title = metadata.get("title").cloned().unwrap_or_default();
    let authors_raw = metadata.get("creator").cloned().unwrap_or_default();
    let authors: Vec<String> = authors_raw
        .split(';')
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect();
    let description = metadata.get("description").cloned();
    let language = metadata.get("language").cloned();

    let (cover_url, cover_href) = extract_cover_url(
        &mut zip,
        &manifest_items,
        &metadata,
        opf_dir,
        &spine_ids,
        &guide_references,
    )?
    .map_or((None, None), |cover| (Some(cover.url), Some(cover.href)));

    let mut chapters: Vec<ReaderChapter> = Vec::new();
    // Maps each spine document to its first rendered reader chapter. A single
    // XHTML document may be split at CSS page breaks, while an empty or cover
    // wrapper document intentionally has no reader chapter at all.
    let mut spine_chapter_indices: HashMap<String, i32> = HashMap::new();
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

        let xhtml_text = decode_epub_xml(&xhtml_bytes, forced_encoding);
        let css = extract_css(&xhtml_text);
        // CRT-1.14: extract @font-face declarations
        for (family, src) in extract_font_faces(&xhtml_text) {
            font_faces.entry(family).or_insert(src);
        }
        let (mut blocks, next_block_index, page_breaks_in_file) =
            parse_xhtml_to_blocks(&xhtml_text, block_index, &css);
        // RCE-7.5: collapse empty div/span — remove blocks with no visible content
        let is_renderable = |b: &ReaderBlock| {
            !b.text.trim().is_empty()
                || b.image_url.is_some()
                || b.block_type == BlockType::Separator
                || b.table_rows.is_some()
                || b.list_items.is_some()
        };
        let page_breaks_in_file: Vec<usize> = page_breaks_in_file
            .into_iter()
            .filter_map(|break_index| {
                let remapped_index = blocks
                    .iter()
                    .take(break_index)
                    .filter(|block| is_renderable(block))
                    .count();
                (remapped_index > 0).then_some(remapped_index)
            })
            .collect();
        blocks.retain(is_renderable);
        block_index = next_block_index;

        // A spine document containing only the already selected cover image is
        // a wrapper for the synthetic reader cover page, not a second chapter.
        if cover_href
            .as_deref()
            .is_some_and(|href| is_single_cover_image_document(&blocks, &item_href, href))
        {
            continue;
        }

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
        let first_chapter_index = chapter_index;
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

        if chapter_index > first_chapter_index {
            spine_chapter_indices.insert(item_href, first_chapter_index);
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
    let toc = extract_epub_toc(
        &mut zip,
        &manifest_items,
        &ncx_id,
        opf_dir,
        forced_encoding,
        &spine_chapter_indices,
    )?;

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
        metadata_json: None,
        book_format: BookFormat::Epub,
        language,
        warnings,
        images: Vec::new(),
        toc,
    })
}

/// Find and parse EPUB table of contents (NCX for EPUB 2, nav.xhtml for EPUB 3).
fn extract_epub_toc(
    zip: &mut ZipFile<'_>,
    manifest: &HashMap<String, ManifestItem>,
    ncx_id: &Option<String>,
    opf_dir: &str,
    forced_encoding: Option<&str>,
    spine_chapter_indices: &HashMap<String, i32>,
) -> Result<Vec<TocEntry>> {
    // Try EPUB 3 nav.xhtml first (preferred)
    if let Some(toc) = try_parse_nav_xhtml(
        zip,
        manifest,
        opf_dir,
        forced_encoding,
        spine_chapter_indices,
    )? {
        if !toc.is_empty() {
            return Ok(toc);
        }
    }

    // Fall back to EPUB 2 NCX
    if let Some(toc) = try_parse_ncx(
        zip,
        manifest,
        ncx_id,
        opf_dir,
        forced_encoding,
        spine_chapter_indices,
    )? {
        return Ok(toc);
    }

    Ok(Vec::new())
}

fn try_parse_nav_xhtml(
    zip: &mut ZipFile<'_>,
    manifest: &HashMap<String, ManifestItem>,
    opf_dir: &str,
    forced_encoding: Option<&str>,
    spine_chapter_indices: &HashMap<String, i32>,
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
    let text = decode_epub_xml(&bytes, forced_encoding);
    Ok(Some(resolve_toc_entries(
        parse_nav_xhtml(&text),
        &nav_path,
        spine_chapter_indices,
    )))
}

fn try_parse_ncx(
    zip: &mut ZipFile<'_>,
    manifest: &HashMap<String, ManifestItem>,
    ncx_id: &Option<String>,
    opf_dir: &str,
    forced_encoding: Option<&str>,
    spine_chapter_indices: &HashMap<String, i32>,
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
    let text = decode_epub_xml(&bytes, forced_encoding);
    Ok(Some(resolve_toc_entries(
        parse_ncx(&text),
        &ncx_path,
        spine_chapter_indices,
    )))
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
    let mut saw_root_element = false;

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                if !saw_root_element {
                    if tag != "package" {
                        bail!("OPF root element must be <package>");
                    }
                    saw_root_element = true;
                }
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
                                let linear = get_xml_attr(e, b"linear");
                                if linear.as_deref() != Some("no") {
                                    spine_ids.push(idref);
                                }
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
                    "metadata" => {
                        if in_dc_tag {
                            let val = current_text.trim().to_string();
                            if !val.is_empty() {
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
                        in_metadata = false;
                    }
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
                if !saw_root_element {
                    if tag != "package" {
                        bail!("OPF root element must be <package>");
                    }
                    saw_root_element = true;
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
                        let linear = get_xml_attr(e, b"linear");
                        if linear.as_deref() != Some("no") {
                            spine_ids.push(idref);
                        }
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

    if !saw_root_element {
        bail!("OPF package document is empty");
    }

    Ok((metadata, manifest_items, spine_ids, ncx_id))
}

/// Parse `<guide>` section from OPF to extract reference entries.
fn parse_opf_guide(text: &str) -> Vec<(String, String)> {
    let mut reader = Reader::from_str(text);
    let mut references = Vec::new();
    let mut in_guide = false;
    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                if tag == "guide" {
                    in_guide = true;
                } else if in_guide && tag == "reference" {
                    if let (Some(t), Some(h)) = (get_xml_attr(e, b"type"), get_xml_attr(e, b"href"))
                    {
                        references.push((t, h));
                    }
                }
            }
            Ok(Event::Empty(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                if in_guide && tag == "reference" {
                    if let (Some(t), Some(h)) = (get_xml_attr(e, b"type"), get_xml_attr(e, b"href"))
                    {
                        references.push((t, h));
                    }
                }
            }
            Ok(Event::End(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                if tag == "guide" {
                    in_guide = false;
                }
            }
            _ => {}
        }
    }
    references
}

#[derive(Debug, Default)]
struct ParsedTocEntry {
    title: String,
    href: String,
    children: Vec<ParsedTocEntry>,
}

/// Parse NCX (EPUB 2 table of contents), preserving the source href until it
/// can be resolved against the rendered spine.
fn parse_ncx(text: &str) -> Vec<ParsedTocEntry> {
    let mut reader = Reader::from_str(text);
    reader.config_mut().trim_text(true);
    let mut entries = Vec::new();
    let mut pending_entries: Vec<ParsedTocEntry> = Vec::new();
    let mut in_nav_label = false;
    let mut in_text = false;

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                match tag.as_str() {
                    "navPoint" => pending_entries.push(ParsedTocEntry::default()),
                    "navLabel" => in_nav_label = true,
                    "text" if in_nav_label => in_text = true,
                    "content" => {
                        if let Some(entry) = pending_entries.last_mut() {
                            entry.href = get_xml_attr(e, b"src").unwrap_or_default();
                        }
                    }
                    _ => {}
                }
            }
            Ok(Event::Empty(ref e)) if e.local_name().as_ref() == b"content" => {
                if let Some(entry) = pending_entries.last_mut() {
                    entry.href = get_xml_attr(e, b"src").unwrap_or_default();
                }
            }
            Ok(Event::Text(ref e)) => {
                if in_text {
                    if let Some(entry) = pending_entries.last_mut() {
                        entry.title.push_str(&e.xml10_content().unwrap_or_default());
                    }
                }
            }
            Ok(Event::End(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                match tag.as_str() {
                    "text" if in_nav_label => in_text = false,
                    "navLabel" => in_nav_label = false,
                    "navPoint" => {
                        if let Some(mut entry) = pending_entries.pop() {
                            entry.title = entry.title.trim().to_string();
                            if !entry.title.is_empty() && !entry.href.trim().is_empty() {
                                if let Some(parent) = pending_entries.last_mut() {
                                    parent.children.push(entry);
                                } else {
                                    entries.push(entry);
                                }
                            }
                        }
                    }
                    _ => {}
                }
            }
            _ => {}
        }
    }
    entries
}

/// Parse EPUB 3 nav.xhtml (table of contents), preserving each link target.
fn parse_nav_xhtml(text: &str) -> Vec<ParsedTocEntry> {
    // Look for <nav epub:type="toc"> <ol> <li> <a href="...">text</a> ...
    let mut reader = Reader::from_str(text);
    let mut entries = Vec::new();
    let mut pending_entries: Vec<ParsedTocEntry> = Vec::new();
    let mut in_toc_nav = false;
    let mut in_a = false;

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
                } else if tag == "li" {
                    pending_entries.push(ParsedTocEntry::default());
                } else if !pending_entries.is_empty() && tag == "a" {
                    in_a = true;
                    if let Some(entry) = pending_entries.last_mut() {
                        entry.href = get_xml_attr(e, b"href").unwrap_or_default();
                    }
                }
            }
            Ok(Event::Text(ref e)) => {
                let text = e.xml10_content().unwrap_or_default().to_string();
                if in_a {
                    if let Some(entry) = pending_entries.last_mut() {
                        entry.title.push_str(&text);
                    }
                }
            }
            Ok(Event::End(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                if tag == "li" {
                    if let Some(mut entry) = pending_entries.pop() {
                        entry.title = entry.title.trim().to_string();
                        if !entry.title.is_empty() {
                            if let Some(parent) = pending_entries.last_mut() {
                                parent.children.push(entry);
                            } else {
                                entries.push(entry);
                            }
                        }
                    }
                } else if tag == "a" {
                    in_a = false;
                } else if tag == "nav" {
                    in_toc_nav = false;
                }
            }
            _ => {}
        }
    }
    entries
}

/// Converts source-relative TOC links to reader chapter indices. Unknown,
/// external, fragment-only, or non-spine links are deliberately omitted: a
/// `TocEntry` cannot represent a non-navigable group without an invalid index.
fn resolve_toc_entries(
    entries: Vec<ParsedTocEntry>,
    toc_document_href: &str,
    spine_chapter_indices: &HashMap<String, i32>,
) -> Vec<TocEntry> {
    resolve_toc_entries_inner(entries, toc_document_href, spine_chapter_indices, 0)
}

fn resolve_toc_entries_inner(
    entries: Vec<ParsedTocEntry>,
    toc_document_href: &str,
    spine_chapter_indices: &HashMap<String, i32>,
    depth: usize,
) -> Vec<TocEntry> {
    if depth > 100 {
        return Vec::new();
    }
    entries
        .into_iter()
        .filter_map(|entry| {
            let target = resolve_epub_href(toc_document_href, &entry.href)?;
            let chapter_index = *spine_chapter_indices.get(&target)?;
            Some(TocEntry {
                title: entry.title,
                chapter_index,
                children: resolve_toc_entries_inner(
                    entry.children,
                    toc_document_href,
                    spine_chapter_indices,
                    depth + 1,
                ),
            })
        })
        .collect()
}

struct ExtractedCover {
    url: String,
    href: String,
}

/// Find the first image reference in an XHTML document and resolve it
/// against the XHTML file's archive path.
fn extract_image_from_xhtml(xhtml_content: &str, xhtml_href: &str) -> Option<String> {
    let mut reader = Reader::from_str(xhtml_content);
    let mut buffer = Vec::new();
    loop {
        match reader.read_event_into(&mut buffer) {
            Ok(Event::Empty(ref e)) | Ok(Event::Start(ref e)) => {
                let name = e.local_name();
                let src = if name.as_ref() == b"img" {
                    get_xml_attr(e, b"src")
                } else if name.as_ref() == b"image" {
                    get_normalized_xml_attr(e, b"xlink:href")
                        .or_else(|| get_normalized_xml_attr(e, b"href"))
                } else {
                    None
                };
                if let Some(src) = src {
                    return resolve_epub_href(xhtml_href, &src);
                }
            }
            Ok(Event::Eof) => break,
            Err(_) => break,
            _ => {}
        }
        buffer.clear();
    }
    None
}

fn is_xhtml_media_type(media_type: &str) -> bool {
    media_type == "application/xhtml+xml"
}

fn is_xhtml_item(item: &ManifestItem) -> bool {
    is_xhtml_media_type(&item.media_type)
        || item.href.ends_with(".xhtml")
        || item.href.ends_with(".html")
}

fn guess_image_mime(href: &str) -> &str {
    if href.ends_with(".png") {
        "image/png"
    } else if href.ends_with(".gif") {
        "image/gif"
    } else if href.ends_with(".svg") {
        "image/svg+xml"
    } else {
        "image/jpeg"
    }
}

fn join_opf_dir(opf_dir: &str, href: &str) -> String {
    if opf_dir.is_empty() {
        href.to_string()
    } else {
        format!("{}/{}", opf_dir, href)
    }
}

fn find_manifest_item_by_href<'a>(
    manifest: &'a HashMap<String, ManifestItem>,
    href: &str,
) -> Option<&'a ManifestItem> {
    let href = href.split('#').next().unwrap_or(href);
    manifest.values().find(|item| item.href == href)
}

fn resolve_cover_from_item(
    zip: &mut ZipFile<'_>,
    item: &ManifestItem,
    full_href: &str,
) -> Result<Option<ExtractedCover>> {
    if is_xhtml_item(item) {
        let bytes = zip.read_file_limited(full_href, crate::api::models::MAX_CHAPTER_SIZE)?;
        if let Some(xhtml_bytes) = bytes {
            let text = decode_epub_xml(&xhtml_bytes, None);
            if let Some(img_href) = extract_image_from_xhtml(&text, full_href) {
                let img_mime = guess_image_mime(&img_href);
                if let Some(url) = read_cover_image(zip, &img_href, img_mime)? {
                    return Ok(Some(ExtractedCover {
                        url,
                        href: img_href,
                    }));
                }
            }
        }
    } else {
        if let Some(url) = read_cover_image(zip, full_href, &item.media_type)? {
            return Ok(Some(ExtractedCover {
                url,
                href: full_href.to_string(),
            }));
        }
    }
    Ok(None)
}

fn extract_cover_url(
    zip: &mut ZipFile<'_>,
    manifest: &HashMap<String, ManifestItem>,
    metadata: &HashMap<String, String>,
    opf_dir: &str,
    spine_ids: &[String],
    guide: &[(String, String)],
) -> Result<Option<ExtractedCover>> {
    // Strategy 1: meta[name="cover"] — enhanced with XHTML wrapper handling
    if let Some(cover_id) = metadata.get("cover-id") {
        if let Some(item) = manifest.get(cover_id.as_str()) {
            let href = join_opf_dir(opf_dir, &item.href);
            if let Some(cover) = resolve_cover_from_item(zip, item, &href)? {
                return Ok(Some(cover));
            }
        }
    }

    // Strategy 2: properties="cover-image"
    for item in manifest.values() {
        if item.properties.iter().any(|p| p == "cover-image") {
            let href = join_opf_dir(opf_dir, &item.href);
            if let Some(cover) = resolve_cover_from_item(zip, item, &href)? {
                return Ok(Some(cover));
            }
        }
    }

    // Strategy 3: guide reference type="cover" or type="title-page"
    // ponytail: from freeLib — guide fallback for cover detection
    for (ref_type, ref_href) in guide {
        if ref_type == "cover" || ref_type == "title-page" {
            if let Some(item) = find_manifest_item_by_href(manifest, ref_href) {
                let href = join_opf_dir(opf_dir, &item.href);
                if let Some(cover) = resolve_cover_from_item(zip, item, &href)? {
                    return Ok(Some(cover));
                }
            }
        }
    }

    // Strategy 4: first spine itemref
    // ponytail: from freeLib — first spine item as cover fallback
    if let Some(first_id) = spine_ids.first() {
        if let Some(item) = manifest.get(first_id.as_str()) {
            let href = join_opf_dir(opf_dir, &item.href);
            if let Some(cover) = resolve_cover_from_item(zip, item, &href)? {
                return Ok(Some(cover));
            }
        }
    }

    // Strategy 5: heuristic id matching — expanded patterns with XHTML support
    for (id, item) in manifest.iter() {
        let id_lower = id.to_ascii_lowercase();
        if (id_lower.contains("cover")
            || id_lower.contains("titlepage")
            || id_lower.contains("frontcover")
            || id_lower.contains("cover-image"))
            && (item.media_type.starts_with("image/") || is_xhtml_media_type(&item.media_type))
        {
            let href = join_opf_dir(opf_dir, &item.href);
            if let Some(cover) = resolve_cover_from_item(zip, item, &href)? {
                return Ok(Some(cover));
            }
        }
    }

    Ok(None)
}

fn is_single_cover_image_document(
    blocks: &[ReaderBlock],
    document_href: &str,
    cover_href: &str,
) -> bool {
    let [block] = blocks else {
        return false;
    };
    if block.block_type != BlockType::Image || !block.text.trim().is_empty() {
        return false;
    }
    let Some(image_href) = block.image_url.as_deref() else {
        return false;
    };
    resolve_epub_href(document_href, image_href).as_deref() == Some(cover_href)
}

fn resolve_epub_href(document_href: &str, href: &str) -> Option<String> {
    let href = href.split(['#', '?']).next()?.trim();
    if href.is_empty() || href.contains("://") || href.starts_with('/') {
        return None;
    }
    let base_dir = document_href.rsplit_once('/').map_or("", |(dir, _)| dir);
    let path = if base_dir.is_empty() {
        href.to_string()
    } else {
        format!("{base_dir}/{href}")
    };
    let mut segments = Vec::new();
    for segment in path.split('/') {
        match segment {
            "" | "." => {}
            ".." => {
                segments.pop()?;
            }
            _ => segments.push(segment),
        }
    }
    Some(segments.join("/"))
}

fn read_cover_image(zip: &mut ZipFile<'_>, href: &str, media_type: &str) -> Result<Option<String>> {
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
    let bytes = expanded.as_bytes();
    let mut i = 0;
    while i < bytes.len() {
        // Skip whitespace between rules
        while i < bytes.len() && bytes[i].is_ascii_whitespace() {
            i += 1;
        }
        if i >= bytes.len() {
            break;
        }
        // Find selector (everything up to the opening brace)
        let selector_start = i;
        while i < bytes.len() && bytes[i] != b'{' {
            i += 1;
        }
        if i >= bytes.len() {
            break;
        }
        let selector = expanded[selector_start..i].trim();
        i += 1; // skip '{'

        // Find matching '}' with brace-depth tracking (handles multi-line rules)
        let body_start = i;
        let mut depth = 1i32;
        while i < bytes.len() && depth > 0 {
            match bytes[i] {
                b'{' => depth += 1,
                b'}' => depth -= 1,
                _ => {}
            }
            if depth > 0 {
                i += 1;
            }
        }
        let body = &expanded[body_start..i];
        if depth == 0 {
            i += 1; // skip '}'
        }

        // Filter selector: class selectors and simple tag selectors only
        // Handle comma-separated selectors (e.g. "h1, h2, h3 { ... }")
        let mut dominated = false;
        for sel in selector.split(',').map(|s| s.trim()).filter(|s| !s.is_empty()) {
            let valid = sel.starts_with('.') || (!sel.contains(' ') && !sel.contains(':'));
            if valid {
                let props = rules.entry(sel.to_string()).or_default();
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
                dominated = true;
            }
        }
        if !dominated {
            continue;
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
        // Skip CSS comments — they must not be parsed as real rules
        if bytes[i] == b'/' && i + 1 < bytes.len() && bytes[i + 1] == b'*' {
            if let Some(end) = css[i + 2..].find("*/") {
                i = i + 2 + end + 2;
            } else {
                break;
            }
            continue;
        }
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
                    let inner_end = if depth == 0 { j - 1 } else { j };
                    let inner = &css[i + open + 1..inner_end];
                    result.push_str(inner);
                    result.push('\n');
                    i = j;
                    continue;
                }
            }
        }
        let ch = css[i..].chars().next().unwrap();
        result.push(ch);
        i += ch.len_utf8();
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
                        let block_end = if depth == 0 { j - 1 } else { j };
                        let block = &expanded[block_start..block_end];
                        let mut font_family = String::new();
                        let mut src = String::new();
                        for prop in split_css_declarations(block) {
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
                                                .trim()
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

/// Split CSS declarations without breaking `data:` URLs, whose base64 payload
/// commonly contains a semicolon before the comma separator.
#[cfg(not(miri))]
fn split_css_declarations(block: &str) -> Vec<&str> {
    let mut declarations = Vec::new();
    let mut start = 0;
    let mut paren_depth = 0u32;
    let mut quote = None;

    for (index, character) in block.char_indices() {
        match character {
            '\'' | '"' if quote.is_none() => quote = Some(character),
            character if quote == Some(character) => quote = None,
            '(' if quote.is_none() => paren_depth += 1,
            ')' if quote.is_none() => paren_depth = paren_depth.saturating_sub(1),
            ';' if quote.is_none() && paren_depth == 0 => {
                declarations.push(&block[start..index]);
                start = index + character.len_utf8();
            }
            _ => {}
        }
    }
    declarations.push(&block[start..]);
    declarations
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

fn inline_style_has_drop_cap(style: &str) -> bool {
    let lower = style.to_ascii_lowercase();
    lower.contains("first-letter") || lower.contains("float:left") || lower.contains("float: left")
}

fn css_has_drop_cap(
    css: &HashMap<String, HashMap<String, String>>,
    tag: &str,
    class: Option<&str>,
) -> bool {
    if let Some(cls) = class {
        for cls_part in cls.split_whitespace() {
            let class_sel = format!(".{}", cls_part);
            if let Some(props) = css.get(&class_sel) {
                if props.contains_key("float") || props.contains_key("initial-letter") {
                    return true;
                }
            }
            let compound = format!("{}.{}", tag, cls_part);
            if let Some(props) = css.get(&compound) {
                if props.contains_key("float") || props.contains_key("initial-letter") {
                    return true;
                }
            }
        }
    }
    false
}

fn class_matches_verse(class: Option<&str>) -> bool {
    let Some(cls) = class else { return false };
    cls.split_whitespace().any(|c| {
        let lower = c.to_ascii_lowercase();
        lower == "verse" || lower == "poem" || lower == "stanza" || lower == "poetry"
    })
}

fn css_hides_element(
    element: &quick_xml::events::BytesStart<'_>,
    tag: &[u8],
    css: &HashMap<String, HashMap<String, String>>,
) -> bool {
    if get_xml_attr(element, b"style").is_some_and(|style| inline_style_hides_content(&style)) {
        return true;
    }

    let Ok(tag) = std::str::from_utf8(tag) else {
        return false;
    };
    if css.get(tag).is_some_and(css_properties_hide_content) {
        return true;
    }

    get_xml_attr(element, b"class").is_some_and(|classes| {
        classes.split_whitespace().any(|class| {
            css.get(&format!(".{class}"))
                .or_else(|| css.get(&format!("{tag}.{class}")))
                .is_some_and(css_properties_hide_content)
        })
    })
}

/// These elements are not reader content. Their attributes are not retained in
/// `ReaderBlock`, and their descendants must not become fallback text either.
fn element_discards_reader_content(tag: &[u8]) -> bool {
    matches!(
        tag,
        b"script" | b"style" | b"iframe" | b"object" | b"embed" | b"template"
    )
}

/// EPUB image assets must always be archive-relative. Keeping a URI scheme
/// here would let a later platform renderer interpret a document-controlled
/// source as a local file or external resource.
pub(crate) fn sanitize_epub_asset_href(href: &str) -> Option<String> {
    let trimmed = href.trim();
    if trimmed.is_empty() || trimmed.starts_with('/') || trimmed.starts_with('\\') {
        return None;
    }

    if let Some(colon) = trimmed.find(':') {
        let has_scheme = trimmed.as_bytes()[..colon]
            .iter()
            .copied()
            .any(|byte| !byte.is_ascii_whitespace() && !byte.is_ascii_control());
        if has_scheme {
            return None;
        }
    }

    Some(trimmed.to_string())
}

fn inline_style_hides_content(style: &str) -> bool {
    style.split(';').any(|declaration| {
        let Some((name, value)) = declaration.split_once(':') else {
            return false;
        };
        matches!(name.trim(), "display" | "visibility")
            && ((name.trim() == "display" && css_value_is(value, "none"))
                || (name.trim() == "visibility"
                    && (css_value_is(value, "hidden") || css_value_is(value, "collapse"))))
    })
}

fn css_properties_hide_content(props: &HashMap<String, String>) -> bool {
    props
        .get("display")
        .is_some_and(|value| css_value_is(value, "none"))
        || props
            .get("visibility")
            .is_some_and(|value| css_value_is(value, "hidden") || css_value_is(value, "collapse"))
}

fn css_value_is(value: &str, expected: &str) -> bool {
    value
        .split_ascii_whitespace()
        .next()
        .is_some_and(|value| value.eq_ignore_ascii_case(expected))
}

/// RCE-7.3: Inline CSS normalization — apply CSS properties to a ReaderBlock.
/// ponytail: text-indent, text-align, white-space, margin-left, line-height, font-weight, font-style, color, display.
fn apply_props(block: &mut ReaderBlock, props: &HashMap<String, String>) {
    // RCE-7.3: hidden CSS removes every renderable payload from the block.
    if css_properties_hide_content(props) {
        block.text.clear();
        block.block_type = BlockType::Paragraph;
        block.image_url = None;
        block.image_alt = None;
        block.rich_spans = None;
        block.list_items = None;
        block.table_rows = None;
        return;
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

fn css_has_page_break_after(
    css: &HashMap<String, HashMap<String, String>>,
    tag: &str,
    class: Option<&str>,
) -> bool {
    if let Some(props) = css.get(tag) {
        if has_page_break_after_prop(props) {
            return true;
        }
    }
    if let Some(cls) = class {
        let class_sel = format!(".{}", cls);
        if css.get(&class_sel).is_some_and(has_page_break_after_prop) {
            return true;
        }
    }
    false
}

fn has_page_break_after_prop(props: &HashMap<String, String>) -> bool {
    if let Some(val) = props
        .get("page-break-after")
        .or_else(|| props.get("break-after"))
    {
        let v = val.trim();
        return v == "always" || v == "page";
    }
    false
}

fn css_has_page_break_inside_avoid(
    css: &HashMap<String, HashMap<String, String>>,
    tag: &str,
    class: Option<&str>,
) -> bool {
    if let Some(props) = css.get(tag) {
        if has_page_break_inside_avoid_prop(props) {
            return true;
        }
    }
    if let Some(cls) = class {
        let class_sel = format!(".{}", cls);
        if css
            .get(&class_sel)
            .is_some_and(has_page_break_inside_avoid_prop)
        {
            return true;
        }
    }
    false
}

fn has_page_break_inside_avoid_prop(props: &HashMap<String, String>) -> bool {
    if let Some(val) = props
        .get("page-break-inside")
        .or_else(|| props.get("break-inside"))
    {
        let v = val.trim();
        return v == "avoid";
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
    // Keep text-node boundaries so an unresolved GeneralRef does not consume
    // the whitespace on either side. Ordinary XHTML prose is normalised below;
    // <pre> retains its original whitespace.
    reader.config_mut().trim_text(false);
    reader.config_mut().allow_dangling_amp = true;
    let mut blocks: Vec<ReaderBlock> = Vec::new();
    let mut page_breaks: Vec<usize> = Vec::new();
    let mut current_text = String::new();
    let mut in_body = false;
    let mut in_block = false; // inside p, h1-h6, blockquote
    let mut in_pre = false;
    let mut verse_depth: i32 = 0;
    let mut block_type = BlockType::Paragraph;
    let mut heading_level: Option<i32> = None;
    let mut blockquote_depth: i32 = 0;
    let mut block_class: Option<&str> = None;
    let mut block_inline_style: Option<String> = None;
    let mut hidden_elements: Vec<bool> = Vec::new();
    let mut hidden_depth = 0usize;
    let mut pending_page_break_before = false;

    // Rich span tracking
    let mut rich_spans: Vec<RichSpan> = Vec::new();
    let mut span_text = String::new();
    let mut bold = false;
    let mut italic = false;
    let mut superscript = false;
    let mut href: Option<String> = None;
    let mut footnote_id: Option<String> = None;

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
                // The native reader renders only `ReaderBlock` data, never HTML.
                // Still discard active/fallback markup here so it cannot leak into
                // visible text or image placeholders.
                let element_is_hidden = hidden_depth > 0
                    || element_discards_reader_content(name)
                    || css_hides_element(e, name, css);
                hidden_elements.push(element_is_hidden);
                if element_is_hidden {
                    hidden_depth += 1;
                }
                if hidden_depth > 0 {
                    continue;
                }
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
                            footnote_id = get_xml_attr(e, b"id");
                        }
                    }
                    b"p" | b"pre" if in_body && in_block && block_type == BlockType::Footnote => {
                        if !current_text.is_empty() {
                            flush_rich_span(
                                &mut rich_spans,
                                &mut span_text,
                                bold,
                                italic,
                                superscript,
                                &href,
                            );
                            current_text.push('\n');
                            rich_spans.push(RichSpan {
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
                            });
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
                        block_class = get_class_attr_arena(e, &arena);
                        block_inline_style = get_xml_attr(e, b"style");
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
                            block_class = get_class_attr_arena(e, &arena);
                            block_inline_style = get_xml_attr(e, b"style");
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
                        block_class = get_class_attr_arena(e, &arena);
                        block_inline_style = get_xml_attr(e, b"style");
                        blockquote_depth += 1;
                    }
                    b"div" | b"section" if in_body => {
                        if attr_eq(e, b"epub:type", b"verse") || attr_eq(e, b"type", b"verse") {
                            verse_depth += 1;
                        } else {
                            let cls = get_class_attr_arena(e, &arena);
                            if class_matches_verse(cls) {
                                verse_depth += 1;
                            }
                        }
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
                        href = get_normalized_xml_attr(e, b"href")
                            .and_then(|h| crate::book::sanitize_href(&h));
                    }
                    b"br" if hidden_depth == 0 => {
                        // The reader renders rich spans when present. Represent
                        // `<br>` explicitly there as well as in the plain block
                        // text, otherwise the visual hard break is lost as soon
                        // as surrounding inline content creates rich spans.
                        if in_block {
                            flush_rich_span(
                                &mut rich_spans,
                                &mut span_text,
                                bold,
                                italic,
                                superscript,
                                &href,
                            );
                            rich_spans.push(RichSpan {
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
                            });
                            current_text.push('\n');
                        } else if in_table || in_list {
                            span_text.push('\n');
                        } else {
                            current_text.push('\n');
                        }
                    }
                    _ => {}
                }
            }
            Ok(Event::Text(ref e)) => {
                if in_body && hidden_depth == 0 {
                    let decoded = e.xml10_content().unwrap_or_default();
                    let text = if in_pre {
                        decoded.into_owned()
                    } else {
                        collapse_xhtml_whitespace(&decoded)
                    };
                    if in_block {
                        append_xhtml_text(&mut span_text, &text);
                        append_xhtml_text(&mut current_text, &text);
                    } else if in_table || in_list {
                        // Table cells and list items are accumulated separately
                        // until their container is flushed.
                        append_xhtml_text(&mut span_text, &text);
                    } else {
                        append_xhtml_text(&mut current_text, &text);
                    }
                }
            }
            Ok(Event::CData(ref e)) => {
                if in_body && hidden_depth == 0 {
                    let text = e.xml10_content().unwrap_or_default();
                    if in_block || in_table || in_list {
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
                if in_body && hidden_depth == 0 {
                    // `GeneralRef` is emitted for an entity that the XML reader
                    // cannot resolve. Keep its source spelling rather than
                    // silently dropping the delimiters from visible prose.
                    let text = decode_xhtml_general_ref(e.as_ref())
                        .unwrap_or_else(|| format!("&{};", String::from_utf8_lossy(e.as_ref())));
                    if in_block || in_table || in_list {
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
                if hidden_depth > 0 {
                    if hidden_elements.pop().unwrap_or(false) {
                        hidden_depth = hidden_depth.saturating_sub(1);
                    }
                    continue;
                }
                match name {
                    b"body" => in_body = false,
                    b"div" | b"section" if verse_depth > 0 => verse_depth -= 1,
                    b"aside" if in_block && block_type == BlockType::Footnote => {
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
                            BlockType::Footnote,
                            None,
                            footnote_id.take(),
                        );
                        current_text.clear();
                        rich_spans.clear();
                        span_text.clear();
                        in_block = false;
                        block_type = BlockType::Paragraph;
                    }
                    b"p" | b"pre" if in_block && matches!(block_type, BlockType::Paragraph | BlockType::Quote) => {
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
                            // Flatten only unstyled single spans — styled spans must
                            // retain formatting (bold, italic, superscript, href).
                            if rich_spans.len() == 1
                                && rich_spans[0].text == t
                                && !rich_spans[0].bold
                                && !rich_spans[0].italic
                                && !rich_spans[0].superscript
                                && rich_spans[0].href.is_none()
                            {
                                None
                            } else {
                                Some(rich_spans.clone())
                            }
                        };
                        if !t.is_empty() || rich.is_some() {
                            let t = add_soft_hyphens(&t);
                            let has_pb = pending_page_break_before;
                            pending_page_break_before = false;
                            let effective_type =
                                if verse_depth > 0 || class_matches_verse(block_class) {
                                    BlockType::Poem
                                } else {
                                    BlockType::Paragraph
                                };
                            blocks.push(ReaderBlock {
                                index: block_index,
                                text: t,
                                block_type: effective_type,
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
                                page_break_before: has_pb,
                                page_break_inside_avoid: false,
                                has_drop_cap: false,
                            });
                            if let Some(cls) = block_class {
                                if let Some(last) = blocks.last_mut() {
                                    apply_css_props(last, "p", Some(cls), css);
                                    apply_css_props(last, "pre", Some(cls), css);
                                }
                                if css_has_drop_cap(css, "p", Some(cls)) {
                                    if let Some(last) = blocks.last_mut() {
                                        last.has_drop_cap = true;
                                    }
                                }
                                if let Some(ref style) = block_inline_style {
                                    if inline_style_has_drop_cap(style) {
                                        if let Some(last) = blocks.last_mut() {
                                            last.has_drop_cap = true;
                                        }
                                    }
                                }
                                // MD-1.4: track page-break-before
                                if css_has_page_break(css, "p", Some(cls))
                                    || css_has_page_break(css, "pre", Some(cls))
                                {
                                    if let Some(last) = blocks.last_mut() {
                                        last.page_break_before = true;
                                    }
                                    page_breaks.push(blocks.len() - 1);
                                }
                                if css_has_page_break_after(css, "p", Some(cls))
                                    || css_has_page_break_after(css, "pre", Some(cls))
                                {
                                    pending_page_break_before = true;
                                }
                                if css_has_page_break_inside_avoid(css, "p", Some(cls))
                                    || css_has_page_break_inside_avoid(css, "pre", Some(cls))
                                {
                                    if let Some(last) = blocks.last_mut() {
                                        last.page_break_inside_avoid = true;
                                    }
                                }
                            } else {
                                if css_has_page_break(css, "p", None)
                                    || css_has_page_break(css, "pre", None)
                                {
                                    if let Some(last) = blocks.last_mut() {
                                        last.page_break_before = true;
                                    }
                                    page_breaks.push(blocks.len() - 1);
                                }
                                if css_has_page_break_after(css, "p", None)
                                    || css_has_page_break_after(css, "pre", None)
                                {
                                    pending_page_break_before = true;
                                }
                                if css_has_page_break_inside_avoid(css, "p", None)
                                    || css_has_page_break_inside_avoid(css, "pre", None)
                                {
                                    if let Some(last) = blocks.last_mut() {
                                        last.page_break_inside_avoid = true;
                                    }
                                }
                                if let Some(ref style) = block_inline_style {
                                    if inline_style_has_drop_cap(style) {
                                        if let Some(last) = blocks.last_mut() {
                                            last.has_drop_cap = true;
                                        }
                                    }
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
                        block_class = None;
                        block_inline_style = None;
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
                                let t_text = add_soft_hyphens(current_text.trim());
                                if !t_text.is_empty() {
                                    let has_pb = pending_page_break_before;
                                    pending_page_break_before = false;
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
                                        page_break_before: has_pb,
                                        page_break_inside_avoid: false,
                                        has_drop_cap: false,
                                    });
                                    let htag = match heading_level {
                                        Some(lv @ 1..=6) => H_TAGS[(lv - 1) as usize],
                                        _ => "h1",
                                    };
                                    if let Some(cls) = block_class {
                                        if let Some(last) = blocks.last_mut() {
                                            apply_css_props(last, htag, Some(cls), css);
                                        }
                                        // MD-1.4: track page-break-before on headings
                                        if css_has_page_break(css, htag, Some(cls)) {
                                            if let Some(last) = blocks.last_mut() {
                                                last.page_break_before = true;
                                            }
                                            page_breaks.push(blocks.len() - 1);
                                        }
                                        if css_has_page_break_after(css, htag, Some(cls)) {
                                            pending_page_break_before = true;
                                        }
                                        if css_has_page_break_inside_avoid(css, htag, Some(cls)) {
                                            if let Some(last) = blocks.last_mut() {
                                                last.page_break_inside_avoid = true;
                                            }
                                        }
                                    } else {
                                        if css_has_page_break(css, htag, None) {
                                            if let Some(last) = blocks.last_mut() {
                                                last.page_break_before = true;
                                            }
                                            page_breaks.push(blocks.len() - 1);
                                        }
                                        if css_has_page_break_after(css, htag, None) {
                                            pending_page_break_before = true;
                                        }
                                        if css_has_page_break_inside_avoid(css, htag, None) {
                                            if let Some(last) = blocks.last_mut() {
                                                last.page_break_inside_avoid = true;
                                            }
                                        }
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
                                block_class = None;
                                block_inline_style = None;
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
                        let t = add_soft_hyphens(current_text.trim());
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
                                page_break_before: false,
                                page_break_inside_avoid: false,
                                has_drop_cap: false,
                            });
                            if let Some(cls) = block_class {
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
                        block_class = None;
                        block_inline_style = None;
                        blockquote_depth = blockquote_depth.saturating_sub(1);
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
                                page_break_before: false,
                                page_break_inside_avoid: false,
                                has_drop_cap: false,
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
                                    text: add_soft_hyphens(item),
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
                                    page_break_before: false,
                                    page_break_inside_avoid: false,
                                    has_drop_cap: false,
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
                                page_break_before: false,
                                page_break_inside_avoid: false,
                                has_drop_cap: false,
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
                                    text: add_soft_hyphens(item),
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
                                    page_break_before: false,
                                    page_break_inside_avoid: false,
                                    has_drop_cap: false,
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
                                page_break_before: false,
                                page_break_inside_avoid: false,
                                has_drop_cap: false,
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
                if hidden_elements.pop().unwrap_or(false) {
                    hidden_depth = hidden_depth.saturating_sub(1);
                }
            }
            Ok(Event::Empty(ref e)) => {
                let local_name = e.local_name();
                let name = local_name.as_ref();
                let element_is_hidden = hidden_depth > 0 || css_hides_element(e, name, css);
                if name == b"hr" && in_body && !element_is_hidden {
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
                        page_break_before: false,
                        page_break_inside_avoid: false,
                        has_drop_cap: false,
                    });
                    block_index += 1;
                } else if name == b"img" && in_body && !element_is_hidden {
                    let raw_src = get_normalized_xml_attr(e, b"src");
                    let src = raw_src.as_deref().and_then(sanitize_epub_asset_href);
                    if raw_src.is_some() && src.is_none() {
                        continue;
                    }
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
                        page_break_before: false,
                        page_break_inside_avoid: false,
                        has_drop_cap: false,
                    });
                    block_index += 1;
                } else if name == b"image" && in_body && !element_is_hidden {
                    // CRT-1.15: SVG <image> tags — extract raster fallback from xlink:href or href
                    let src = get_normalized_xml_attr(e, b"xlink:href")
                        .or_else(|| get_normalized_xml_attr(e, b"href"))
                        .and_then(|href| sanitize_epub_asset_href(&href));
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
                            page_break_before: false,
                            page_break_inside_avoid: false,
                            has_drop_cap: false,
                        });
                        block_index += 1;
                    }
                } else if name == b"br" && in_body && !element_is_hidden {
                    if in_block {
                        // Self-closing `<br/>` is reported as `Event::Empty`,
                        // so it must follow the same rich-span path as `<br>`.
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            bold,
                            italic,
                            superscript,
                            &href,
                        );
                        rich_spans.push(RichSpan {
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
                        });
                        current_text.push('\n');
                    } else if in_table || in_list {
                        // Table cells and list items are accumulated in
                        // `span_text`, so writing to `current_text` here loses
                        // their hard break when the container is flushed.
                        span_text.push('\n');
                    } else {
                        current_text.push('\n');
                    }
                } else if name == b"img" && in_block && !element_is_hidden {
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

/// Decode the numeric and non-breaking-space entity references emitted as
/// `GeneralRef` by `quick-xml`. Other unresolved XHTML entities stay literal
/// so malformed input remains visible to the reader.
fn decode_xhtml_general_ref(reference: &[u8]) -> Option<String> {
    let reference = std::str::from_utf8(reference).ok()?;
    if reference.eq_ignore_ascii_case("nbsp") {
        return Some('\u{a0}'.to_string());
    }
    let value = reference
        .strip_prefix("#x")
        .or_else(|| reference.strip_prefix("#X"))
        .and_then(|hex| u32::from_str_radix(hex, 16).ok())
        .or_else(|| {
            reference
                .strip_prefix('#')
                .and_then(|decimal| decimal.parse::<u32>().ok())
        })?;
    char::from_u32(value).map(|character| character.to_string())
}

/// Collapse formatting whitespace in ordinary XHTML text nodes while retaining
/// a single space at a text-node boundary. The latter matters for unresolved
/// entities, which quick-xml reports as a separate `GeneralRef` event.
fn collapse_xhtml_whitespace(text: &str) -> String {
    let mut collapsed = String::with_capacity(text.len());
    let mut previous_was_whitespace = false;
    for character in text.chars() {
        if character.is_whitespace() {
            if !previous_was_whitespace {
                collapsed.push(' ');
                previous_was_whitespace = true;
            }
        } else {
            collapsed.push(character);
            previous_was_whitespace = false;
        }
    }
    collapsed
}

/// Append normalised XHTML text without duplicating a whitespace boundary
/// introduced by a filtered inline element.
fn append_xhtml_text(buffer: &mut String, text: &str) {
    let text = if buffer.ends_with(char::is_whitespace) {
        text.trim_start_matches(char::is_whitespace)
    } else {
        text
    };
    buffer.push_str(text);
}

/// Flush every EPUB inline segment, including unstyled text.
///
/// Reader blocks render `rich_spans` instead of their plain `text`; keeping
/// only styled spans therefore drops prose around a footnote reference.
fn flush_rich_span(
    spans: &mut Vec<RichSpan>,
    span_text: &mut String,
    bold: bool,
    italic: bool,
    superscript: bool,
    href: &Option<String>,
) {
    let text = std::mem::take(span_text);
    if text.is_empty() {
        return;
    }
    spans.push(RichSpan {
        text,
        bold,
        italic,
        superscript,
        subscript: false,
        strikethrough: false,
        code: false,
        style_name: None,
        href: href.clone(),
        line_break: false,
    });
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
        page_break_before: false,
        page_break_inside_avoid: false,
        has_drop_cap: false,
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
    let trimmed = add_soft_hyphens(&trimmed);
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
            page_break_before: false,
            page_break_inside_avoid: false,
            has_drop_cap: false,
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
                    "br" if in_heading => {
                        heading_title.push(' ');
                    }
                    _ => {}
                }
            }
            Ok(Event::Empty(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                if tag == "br" && in_heading {
                    heading_title.push(' ');
                }
            }
            Ok(Event::Text(ref e)) => {
                if in_title {
                    title.push_str(&e.xml10_content().unwrap_or_default());
                } else if in_heading {
                    heading_title.push_str(&e.xml10_content().unwrap_or_default());
                }
            }
            Ok(Event::CData(ref e)) => {
                if in_title {
                    title.push_str(&e.decode().unwrap_or_default());
                } else if in_heading {
                    heading_title.push_str(&e.decode().unwrap_or_default());
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
    let trimmed = result.trim().to_string();
    // ponytail: 150-char sanity cap prevents paragraph text leaking as title
    if trimmed.chars().count() > 150 {
        let truncated: String = trimmed.chars().take(150).collect();
        if let Some(pos) = truncated.rfind(' ') {
            format!("{}…", &trimmed[..pos])
        } else {
            format!("{truncated}…")
        }
    } else {
        trimmed
    }
}

#[cfg(test)]
mod tests {
    #[cfg(not(miri))]
    use super::extract_font_faces;
    use super::{
        extract_chapter_title, parse_nav_xhtml, parse_ncx, parse_xhtml_to_blocks,
        resolve_toc_entries,
    };
    use crate::api::models::BlockType;

    #[test]
    fn extract_title_handles_br_in_heading() {
        let html = r#"<html><head><title>X</title></head><body><h1>Chapter 1<br/>The Beginning</h1><p>Text</p></body></html>"#;
        assert_eq!(extract_chapter_title(html), "Chapter 1 The Beginning");
    }

    #[test]
    fn extract_title_caps_long_text() {
        let long = "A".repeat(200);
        let html = format!(r#"<html><body><h1>{long}</h1></body></html>"#);
        let title = extract_chapter_title(&html);
        assert!(title.ends_with('…'));
        assert!(title.chars().count() <= 152);
    }

    #[test]
    fn extract_title_prefers_h1_over_title_tag() {
        let html = r#"<html><head><title>Old Title</title></head><body><h1>Real Chapter</h1></body></html>"#;
        assert_eq!(extract_chapter_title(html), "Real Chapter");
    }

    #[test]
    fn extract_title_falls_back_to_title_tag() {
        let html =
            r#"<html><head><title>From Head</title></head><body><p>No heading</p></body></html>"#;
        assert_eq!(extract_chapter_title(html), "From Head");
    }

    #[test]
    fn extract_title_skips_empty_h1_uses_h2() {
        let html = r#"<html><body><h1></h1><h2>Subtitle</h2></body></html>"#;
        assert_eq!(extract_chapter_title(html), "Subtitle");
    }

    #[test]
    fn extract_title_handles_cdata() {
        let html = r#"<html><body><h1><![CDATA[CDATA Title]]></h1></body></html>"#;
        assert_eq!(extract_chapter_title(html), "CDATA Title");
    }

    #[test]
    fn parses_epub3_nav_toc_with_nested_entries() {
        let toc = parse_nav_xhtml(
            r#"<html xmlns:epub="http://www.idpf.org/2007/ops"><body>
                <nav epub:type="toc"><ol>
                  <li><a href="chapter-1.xhtml">Chapter 1</a><ol>
                    <li><a href="chapter-1.xhtml#part-1">Part 1</a></li>
                  </ol></li>
                  <li><a href="chapter-2.xhtml">Chapter 2</a></li>
                </ol></nav>
            </body></html>"#,
        );

        assert_eq!(toc.len(), 2);
        assert_eq!(toc[0].title, "Chapter 1");
        assert_eq!(toc[0].href, "chapter-1.xhtml");
        assert_eq!(toc[0].children[0].title, "Part 1");
        assert_eq!(toc[1].title, "Chapter 2");
    }

    #[test]
    fn resolves_ncx_entries_to_rendered_spine_chapters() {
        let parsed = parse_ncx(
            r#"<ncx><navMap>
                <navPoint><navLabel><text>Chapter one</text></navLabel>
                  <content src="../Text/chapter-1.xhtml#part-1"/>
                  <navPoint><navLabel><text>Part one</text></navLabel>
                    <content src="../Text/chapter-1.xhtml#part-2"/>
                  </navPoint>
                </navPoint>
                <navPoint><navLabel><text>Chapter two</text></navLabel>
                  <content src="../Text/chapter-2.xhtml?from=toc"/>
                </navPoint>
            </navMap></ncx>"#,
        );
        let chapter_indices = std::collections::HashMap::from([
            ("OPS/Text/chapter-1.xhtml".to_owned(), 3),
            ("OPS/Text/chapter-2.xhtml".to_owned(), 4),
        ]);

        let toc = resolve_toc_entries(parsed, "OPS/Navigation/toc.ncx", &chapter_indices);

        assert_eq!(toc.len(), 2);
        assert_eq!(toc[0].chapter_index, 3);
        assert_eq!(toc[0].children[0].chapter_index, 3);
        assert_eq!(toc[1].chapter_index, 4);
    }

    #[test]
    fn preserves_numeric_in_book_links_as_regular_spans() {
        let (blocks, _, _) = parse_xhtml_to_blocks(
            r##"<html><body><p>See <a href="#12">12</a> and <a href="chapter.xhtml#verse-3">3</a>.</p></body></html>"##,
            0,
            &std::collections::HashMap::new(),
        );

        assert_eq!(blocks.len(), 1);
        assert_eq!(blocks[0].block_type, BlockType::Paragraph);
        assert_eq!(
            blocks[0]
                .rich_spans
                .as_ref()
                .expect("links retain rich spans")
                .iter()
                .filter_map(|span| span.href.as_deref())
                .collect::<Vec<_>>(),
            vec!["#12", "chapter.xhtml#verse-3"],
        );
    }

    #[test]
    fn drops_active_markup_and_non_archive_sources() {
        let (blocks, _, _) = parse_xhtml_to_blocks(
            r##"<html><body>
                <p>Visible <script>alert(1)</script><iframe>frame fallback</iframe>
                <a href="#note">Local</a><a href="https://example.test/reference">Web</a>
                <a href="java&#x0A;script:alert(1)">Script</a><a href="file:///private/secret">File</a>.</p>
                <img src="images/local.png"/><img src="file:///private/secret.png"/>
                <svg><image href="https://example.test/pixel.png"/></svg>
            </body></html>"##,
            0,
            &std::collections::HashMap::new(),
        );

        assert_eq!(blocks.len(), 2);
        assert_eq!(blocks[0].block_type, BlockType::Paragraph);
        assert!(blocks[0].text.contains("Visible"));
        assert!(!blocks[0].text.contains("alert(1)"));
        assert!(!blocks[0].text.contains("frame fallback"));
        assert_eq!(
            blocks[0]
                .rich_spans
                .as_ref()
                .expect("links retain rich spans")
                .iter()
                .filter_map(|span| span.href.as_deref())
                .collect::<Vec<_>>(),
            vec!["#note", "https://example.test/reference"],
        );
        assert_eq!(blocks[1].block_type, BlockType::Image);
        assert_eq!(blocks[1].image_url.as_deref(), Some("images/local.png"));
    }

    #[test]
    fn preserves_dense_footnote_links_and_identifies_note_asides() {
        let (blocks, _, _) = parse_xhtml_to_blocks(
            r##"<html xmlns:epub="http://www.idpf.org/2007/ops"><body>
                <p>One<a href="#note-1" epub:type="noteref"><sup>1</sup></a>, then
                two<a href="#note-2" epub:type="noteref"><sup>2</sup></a>.</p>
                <aside id="note-1" epub:type="footnote"><p>First note.</p></aside>
                <aside id="note-2" epub:type="footnote"><p>Second note.</p></aside>
            </body></html>"##,
            0,
            &std::collections::HashMap::new(),
        );

        let source = &blocks[0];
        let source_spans = source.rich_spans.as_ref().expect("link spans are retained");
        assert_eq!(
            source_spans
                .iter()
                .map(|span| span.text.as_str())
                .collect::<String>(),
            source.text,
            "unstyled prose around dense references must remain renderable"
        );
        assert_eq!(
            source_spans
                .iter()
                .filter_map(|span| span.href.as_deref())
                .collect::<Vec<_>>(),
            vec!["#note-1", "#note-2"],
        );

        assert_eq!(blocks[1].block_type, BlockType::Footnote);
        assert_eq!(blocks[1].note_id.as_deref(), Some("note-1"));
        assert_eq!(blocks[1].text, "First note.");
        assert_eq!(blocks[2].block_type, BlockType::Footnote);
        assert_eq!(blocks[2].note_id.as_deref(), Some("note-2"));
        assert_eq!(blocks[2].text, "Second note.");
    }

    #[test]
    fn preserves_unknown_entities_as_literal_text() {
        let (blocks, _, _) = parse_xhtml_to_blocks(
            "<html><body><p>Before &unknown; after.</p></body></html>",
            0,
            &std::collections::HashMap::new(),
        );

        assert_eq!(blocks.len(), 1);
        assert_eq!(blocks[0].text, "Before &unknown; after.");
    }

    #[test]
    fn preserves_non_breaking_spaces_in_epub_prose() {
        let (blocks, _, _) = parse_xhtml_to_blocks(
            "<html><body><p>В&#160;доме горел свет. И&nbsp;за окном дождь.</p></body></html>",
            0,
            &std::collections::HashMap::new(),
        );

        assert_eq!(blocks.len(), 1);
        assert_eq!(
            blocks[0].text,
            "В\u{a0}доме горел свет. И\u{a0}за окном дождь."
        );
    }

    #[test]
    fn preserves_br_as_a_rich_span_line_break() {
        let (blocks, _, _) = parse_xhtml_to_blocks(
            r##"<html><body><p><a href="#note">First<br/>second</a> line.</p></body></html>"##,
            0,
            &std::collections::HashMap::new(),
        );

        assert_eq!(blocks.len(), 1);
        assert_eq!(blocks[0].text, "First\nsecond line.");
        let spans = blocks[0]
            .rich_spans
            .as_ref()
            .expect("inline link keeps spans");
        assert_eq!(spans.len(), 4);
        assert_eq!(spans[0].text, "First");
        assert_eq!(spans[0].href.as_deref(), Some("#note"));
        assert!(spans[1].line_break);
        assert_eq!(spans[2].text, "second");
        assert_eq!(spans[2].href.as_deref(), Some("#note"));
        assert_eq!(spans[3].text, " line.");
    }

    #[test]
    fn preserves_br_inside_table_cells_and_list_items() {
        let (blocks, _, _) = parse_xhtml_to_blocks(
            "<html><body><table><tr><td>First<br/>second</td></tr></table><ul><li>Third<br></br>fourth</li></ul></body></html>",
            0,
            &std::collections::HashMap::new(),
        );

        assert_eq!(
            blocks
                .iter()
                .map(|block| (&block.block_type, block.text.as_str()))
                .collect::<Vec<_>>(),
            vec![
                (&BlockType::Table, "First\nsecond"),
                (&BlockType::List, "Third\nfourth"),
            ],
        );
        assert_eq!(blocks[0].block_type, BlockType::Table);
        assert_eq!(blocks[0].text, "First\nsecond");
        assert_eq!(
            blocks[0]
                .table_rows
                .as_ref()
                .expect("table keeps cell content"),
            &vec![vec!["First\nsecond".to_string()]],
        );

        assert_eq!(blocks[1].text, "Third\nfourth");
        assert_eq!(
            blocks[1]
                .list_items
                .as_ref()
                .expect("list keeps item content")[0]
                .text,
            "Third\nfourth"
        );
    }

    #[test]
    fn falls_back_for_malformed_xhtml_after_a_complete_block() {
        let (blocks, _, _) = parse_xhtml_to_blocks(
            "<html><body><p>First paragraph.</p><p>Second paragraph.",
            0,
            &std::collections::HashMap::new(),
        );

        assert_eq!(
            blocks
                .iter()
                .map(|block| block.text.as_str())
                .collect::<Vec<_>>(),
            ["First paragraph.", "Second paragraph."],
        );
    }

    #[cfg(not(miri))]
    #[test]
    fn preserves_data_font_urls_with_semicolon_parameters() {
        let faces = extract_font_faces(
            r#"<html><head><style>
                @font-face {
                  font-family: "Embedded";
                  src: url("data:font/woff2;charset=utf-8;base64,AAEC");
                }
            </style></head><body><p>Text</p></body></html>"#,
        );

        assert_eq!(
            faces,
            vec![(
                "Embedded".to_string(),
                "data:font/woff2;charset=utf-8;base64,AAEC".to_string(),
            )]
        );
    }

    #[test]
    fn drop_cap_detected_from_inline_style_first_letter() {
        let html = r#"<html><body><p style="font-variant:small-caps; ::first-letter { font-size: 3em }">Once upon a time there was a story.</p></body></html>"#;
        let (blocks, _, _) = parse_xhtml_to_blocks(html, 0, &std::collections::HashMap::new());
        assert_eq!(blocks.len(), 1);
        assert!(blocks[0].has_drop_cap);
    }

    #[test]
    fn drop_cap_detected_from_inline_style_float_left() {
        let html = r#"<html><body><p style="float: left; font-size: 2em">A</p><p>Once upon a time.</p></body></html>"#;
        let (blocks, _, _) = parse_xhtml_to_blocks(html, 0, &std::collections::HashMap::new());
        assert!(blocks.iter().any(|b| b.has_drop_cap));
    }

    #[test]
    fn no_drop_cap_without_style() {
        let html = r#"<html><body><p>Normal paragraph without drop cap.</p></body></html>"#;
        let (blocks, _, _) = parse_xhtml_to_blocks(html, 0, &std::collections::HashMap::new());
        assert_eq!(blocks.len(), 1);
        assert!(!blocks[0].has_drop_cap);
    }

    #[test]
    fn extract_image_from_xhtml_finds_html_img() {
        let xhtml = r#"<html><body><img src="../images/cover.jpg" alt="Cover"/></body></html>"#;
        let result = super::extract_image_from_xhtml(xhtml, "OEBPS/Text/cover.xhtml");
        assert_eq!(result.as_deref(), Some("OEBPS/images/cover.jpg"));
    }

    #[test]
    fn extract_image_from_xhtml_finds_svg_image_href() {
        let xhtml = r#"<html><body><svg><image href="cover.png"/></svg></body></html>"#;
        let result = super::extract_image_from_xhtml(xhtml, "OEBPS/Text/cover.xhtml");
        assert_eq!(result.as_deref(), Some("OEBPS/Text/cover.png"));
    }

    #[test]
    fn extract_image_from_xhtml_finds_svg_image_xlink_href() {
        let xhtml = r#"<html><body><svg><image xlink:href="img/cover.jpg"/></svg></body></html>"#;
        let result = super::extract_image_from_xhtml(xhtml, "OEBPS/Text/cover.xhtml");
        assert_eq!(result.as_deref(), Some("OEBPS/Text/img/cover.jpg"));
    }

    #[test]
    fn extract_image_from_xhtml_returns_none_when_no_image() {
        let xhtml = r#"<html><body><p>No image here</p></body></html>"#;
        let result = super::extract_image_from_xhtml(xhtml, "OEBPS/Text/cover.xhtml");
        assert!(result.is_none());
    }

    #[test]
    fn parse_opf_guide_extracts_references() {
        let opf = r#"<?xml version="1.0"?>
        <package xmlns="http://www.idpf.org/2007/opf">
            <guide>
                <reference type="cover" title="Cover" href="cover.xhtml"/>
                <reference type="toc" title="TOC" href="toc.xhtml"/>
            </guide>
        </package>"#;
        let refs = super::parse_opf_guide(opf);
        assert_eq!(refs.len(), 2);
        assert_eq!(refs[0], ("cover".to_string(), "cover.xhtml".to_string()));
        assert_eq!(refs[1], ("toc".to_string(), "toc.xhtml".to_string()));
    }

    #[test]
    fn parse_opf_guide_handles_empty_guide() {
        let opf = r#"<?xml version="1.0"?>
        <package xmlns="http://www.idpf.org/2007/opf">
            <guide/>
        </package>"#;
        let refs = super::parse_opf_guide(opf);
        assert!(refs.is_empty());
    }
}
