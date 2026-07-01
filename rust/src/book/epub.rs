use crate::api::models::{BlockType, NormalizedBook, ReaderBlock, ReaderChapter, RichSpan};
use crate::book::archive::{self, ZipFile};
use crate::book::encoding::{decode_bytes, get_xml_attr};
use crate::book::flush_rich_span;
use anyhow::{Context, Result, bail};
use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use quick_xml::Reader;
use quick_xml::events::{BytesStart, Event};
use serde::Deserialize;
use std::collections::HashMap;

pub fn parse_epub(bytes: &[u8], forced_encoding: Option<&str>) -> Result<NormalizedBook> {
    let mut zip = archive::decode_zip(bytes).context("Failed to open EPUB archive")?;
    let encoding_name = forced_encoding.unwrap_or("utf-8");

    let container_xml = zip
        .find_file("META-INF/container.xml")
        .context("EPUB missing META-INF/container.xml")?;
    let container_text = decode_bytes(&container_xml, encoding_name);
    let opf_path = parse_container_xml(&container_text)?;

    let opf_bytes = zip
        .find_file(&opf_path)
        .with_context(|| format!("OPF file not found: {}", opf_path))?;
    let opf_text = decode_bytes(&opf_bytes, encoding_name);

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

    let cover_url = extract_cover_url(&mut zip, &manifest_items, &metadata, opf_dir, encoding_name);

    let mut chapters: Vec<ReaderChapter> = Vec::new();
    let mut chapter_index = 0i32;
    let mut block_index = 0i32;
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

        let Some(xhtml_bytes) = zip.find_file(&item_href).or_else(|| {
            let name = zip
                .entry_names()
                .iter()
                .find(|n| n.eq_ignore_ascii_case(&item_href))
                .cloned()?;
            zip.find_file(&name)
        }) else {
            continue;
        };

        let xhtml_text = decode_bytes(&xhtml_bytes, encoding_name);
        let css = extract_css(&xhtml_text);
        // CRT-1.14: extract @font-face declarations
        for (family, src) in extract_font_faces(&xhtml_text) {
            font_faces.entry(family).or_insert(src);
        }
        let (blocks, next_block_index, page_breaks_in_file) =
            parse_xhtml_to_blocks(&xhtml_text, block_index, &css);
        block_index = next_block_index;

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

    // CRT-1.14: include font-face declarations in metadata
    let meta = if font_faces.is_empty() {
        None
    } else {
        Some(serde_json::json!({ "fonts": font_faces }))
    };

    Ok(NormalizedBook {
        id,
        title,
        authors,
        description,
        cover_url,
        chapters,
        metadata: meta,
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
    reader.config_mut().allow_dangling_amp = true;
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
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
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
                    current_text.push_str(&e.xml10_content().unwrap_or_default());
                }
            }
            Ok(Event::CData(ref e)) => {
                let text = e.xml10_content().unwrap_or_default();
                if in_dc_tag {
                    current_text.push_str(&text);
                }
            }
            Ok(Event::GeneralRef(ref e)) => {
                let text = e.xml10_content().unwrap_or_default();
                if in_dc_tag {
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
                    }
                }
            }
            Err(e) => bail!("OPF parse error: {}", e),
            _ => {}
        }
    }

    Ok((metadata, manifest_items, spine_ids))
}

fn extract_cover_url(
    zip: &mut ZipFile,
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
                return Some(encode_data_uri(&item.media_type, &bytes));
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
                return Some(encode_data_uri(&item.media_type, &bytes));
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
                return Some(encode_data_uri(&item.media_type, &bytes));
            }
        }
    }

    None
}

fn encode_data_uri(mime: &str, bytes: &[u8]) -> String {
    format!("data:{};base64,{}", mime, STANDARD.encode(bytes))
}

/// Collect CSS class→properties map from inline `<style>` elements in XHTML.
/// CRT-1.11: parses simple `.class { name: value; }` rules.
/// ponytail: no cascade, no inheritance, no `@` rules, no compound selectors.
/// Upgrade to a full CSS engine if EPUB styling quality matters.
fn extract_css(text: &str) -> HashMap<String, HashMap<String, String>> {
    let mut rules: HashMap<String, HashMap<String, String>> = HashMap::new();
    let mut reader = Reader::from_str(text);
    reader.config_mut().trim_text(true);

    let mut in_style = false;
    let mut style_content = String::new();

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                if tag == "style" {
                    in_style = true;
                    style_content.clear();
                }
            }
            Ok(Event::Text(ref e)) if in_style => {
                style_content.push_str(&e.xml10_content().unwrap_or_default());
            }
            Ok(Event::CData(ref e)) if in_style => {
                style_content.push_str(&e.xml10_content().unwrap_or_default());
            }
            Ok(Event::End(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                if tag == "style" && in_style {
                    in_style = false;
                    // LW-1.4: extract rules from @media blocks before line parsing
                    let expanded = expand_media_queries(&style_content);
                    for line in expanded.lines() {
                        let line = line.trim();
                        // Match: .className { ... }
                        if let Some(body_start) = line.find('{') {
                            if let Some(body_end) = line.rfind('}') {
                                let selector = &line[..body_start].trim();
                                let body = &line[body_start + 1..body_end];
                                let selector = if selector.starts_with('.') {
                                    selector
                                } else if !selector.contains(' ') && !selector.contains('#') {
                                    // Pure tag selector — prefix with "tag:" for disambiguation
                                    let tag = selector.trim();
                                    if !tag.is_empty() {
                                        selector
                                    } else {
                                        continue;
                                    }
                                } else {
                                    // Compound/other selectors: skip for now
                                    // ponytail: no compound selectors, no pseudo-classes, no @rules
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
                }
            }
            _ => {}
        }
    }
    // ponytail: case-insensitive matching would be more correct but CSS is author-controlled
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
/// Returns Vec of (font-family, src-url) pairs.
fn extract_font_faces(text: &str) -> Vec<(String, String)> {
    let mut faces = Vec::new();
    let mut reader = Reader::from_str(text);
    reader.config_mut().trim_text(true);

    let mut in_style = false;
    let mut style_content = String::new();

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                if tag == "style" {
                    in_style = true;
                    style_content.clear();
                }
            }
            Ok(Event::Text(ref e)) if in_style => {
                style_content.push_str(&e.xml10_content().unwrap_or_default());
            }
            Ok(Event::CData(ref e)) if in_style => {
                style_content.push_str(&e.xml10_content().unwrap_or_default());
            }
            Ok(Event::End(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                if tag == "style" && in_style {
                    in_style = false;
                    // Find @font-face { ... } blocks
                    let expanded = expand_media_queries(&style_content);
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
                                        font_family = value
                                            .trim_matches(|c| c == '\'' || c == '"')
                                            .to_string();
                                    } else if name == "src" {
                                        // Extract url("...") from src
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
            _ => {}
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
    // MD-1.1: cascade by specificity — tag < class
    // Tag selector (lowest specificity)
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

/// ponytail: text-indent, text-align, margin-left, page-break-before.
fn apply_props(block: &mut ReaderBlock, props: &HashMap<String, String>) {
    if let Some(indent) = props.get("text-indent") {
        if let Some(v) = parse_css_length(indent) {
            block.text_indent = Some(v);
        }
    }
    if let Some(align) = props.get("text-align") {
        block.text_align = Some(align.clone());
    }
    // MD-1.7: white-space: pre/pre-wrap — store as special text_align value
    if let Some(ws) = props.get("white-space") {
        let v = ws.trim();
        if v == "pre" || v == "pre-wrap" || v == "nowrap" {
            block.text_align = Some(format!("ws:{v}"));
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
}

/// MD-1.4: check if CSS has page-break-before: always for given tag/class.
fn css_has_page_break(
    css: &HashMap<String, HashMap<String, String>>,
    tag: &str,
    class: Option<&str>,
) -> bool {
    for props in css
        .get(tag)
        .into_iter()
        .chain(css.get(&format!(".{}", class.unwrap_or(""))))
    {
        if let Some(val) = props
            .get("page-break-before")
            .or_else(|| props.get("break-before"))
        {
            let v = val.trim();
            if v == "always" || v == "page" {
                return true;
            }
        }
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

/// Extract class attribute value from a quick-xml element.
fn get_class_attr(e: &BytesStart<'_>) -> Option<String> {
    for attr in e.attributes().flatten() {
        if attr.key.local_name().as_ref() == b"class" {
            return Some(String::from_utf8_lossy(&attr.value).to_string());
        }
    }
    None
}

fn parse_xhtml_to_blocks(
    text: &str,
    mut block_index: i32,
    css: &HashMap<String, HashMap<String, String>>,
) -> (Vec<ReaderBlock>, i32, Vec<usize>) {
    let mut reader = Reader::from_str(text);
    reader.config_mut().trim_text(true);
    reader.config_mut().allow_dangling_amp = true;
    let mut blocks: Vec<ReaderBlock> = Vec::new();
    let mut page_breaks: Vec<usize> = Vec::new();
    let mut current_text = String::new();
    let mut in_body = false;
    let mut in_block = false; // inside p, h1-h6, blockquote
    let mut block_type = BlockType::Paragraph;
    let mut heading_level: Option<i32> = None;
    let mut blockquote_depth: i32 = 0;
    let mut current_class: Option<String> = None;

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

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref e)) => {
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                current_class = get_class_attr(e);
                match tag.as_str() {
                    "body" => in_body = true,
                    "p" if in_body => {
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
                        block_type = if blockquote_depth > 0 {
                            BlockType::Quote
                        } else {
                            BlockType::Paragraph
                        };
                        heading_level = None;
                    }
                    t if t.starts_with('h') && t.len() == 2 && in_body => {
                        if let Some(d) = t.as_bytes().get(1) {
                            if d.is_ascii_digit() {
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
                                heading_level = Some(*d as i32 - '0' as i32);
                            }
                        }
                    }
                    "blockquote" if in_body => {
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
                    "table" if in_body => {
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
                    "tr" if in_table => {
                        current_row.clear();
                    }
                    "td" | "th" if in_table => {
                        span_text.clear();
                        rich_spans.clear();
                    }
                    "ul" if in_body => {
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
                    "ol" if in_body => {
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
                    "li" if in_list => {
                        span_text.clear();
                        rich_spans.clear();
                    }
                    // Inline formatting tags
                    "strong" | "b" if in_block => {
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
                    "em" | "i" if in_block => {
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
                    "sup" if in_block => {
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
                    "a" if in_block => {
                        flush_rich_span(
                            &mut rich_spans,
                            &mut span_text,
                            bold,
                            italic,
                            superscript,
                            &href,
                        );
                        href = get_xml_attr(e, b"href");
                    }
                    "br" if in_block => {
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
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                match tag.as_str() {
                    "body" => in_body = false,
                    "p" if in_block && block_type == BlockType::Paragraph => {
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
                                text_align: None,
                                note_id: None,
                            });
                            if let Some(ref cls) = current_class {
                                if let Some(last) = blocks.last_mut() {
                                    apply_css_props(last, "p", Some(cls), css);
                                }
                                // MD-1.4: track page-break-before
                                if css_has_page_break(css, "p", Some(cls)) {
                                    page_breaks.push(blocks.len());
                                }
                            } else if css_has_page_break(css, "p", None) {
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
                    t if t.starts_with('h')
                        && t.len() == 2
                        && in_block
                        && block_type == BlockType::Heading =>
                    {
                        if let Some(d) = t.as_bytes().get(1) {
                            if d.is_ascii_digit() {
                                let expected_level = *d as i32 - '0' as i32;
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
                                        if let Some(ref cls) = current_class {
                                            if let Some(last) = blocks.last_mut() {
                                                let htag =
                                                    format!("h{}", heading_level.unwrap_or(1));
                                                apply_css_props(last, &htag, Some(cls), css);
                                            }
                                            // MD-1.4: track page-break-before on headings
                                            let htag = format!("h{}", heading_level.unwrap_or(1));
                                            if css_has_page_break(css, &htag, Some(cls)) {
                                                page_breaks.push(blocks.len());
                                            }
                                        } else {
                                            let htag = format!("h{}", heading_level.unwrap_or(1));
                                            if css_has_page_break(css, &htag, None) {
                                                page_breaks.push(blocks.len());
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
                                    blockquote_depth = (blockquote_depth - 1).max(0);
                                }
                            }
                        }
                    }
                    "blockquote" if in_block && block_type == BlockType::Quote => {
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
                            if let Some(ref cls) = current_class {
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
                    "td" | "th" if in_table => {
                        let t = span_text.trim().to_string();
                        current_row.push(t);
                        span_text.clear();
                    }
                    "tr" if in_table => {
                        if !current_row.is_empty() {
                            table_rows.push(current_row.clone());
                            current_row.clear();
                        }
                    }
                    "table" if in_table => {
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
                    "li" if in_list => {
                        let t = span_text.trim().to_string();
                        if !t.is_empty() {
                            list_items.push(t);
                        }
                        span_text.clear();
                    }
                    "ul" if in_list => {
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
                    "ol" if in_list => {
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
                    "strong" | "b" if in_block => {
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
                    "em" | "i" if in_block => {
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
                    "sup" if in_block => {
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
                    "a" if in_block => {
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
                let tag = String::from_utf8_lossy(e.local_name().as_ref()).to_string();
                if tag == "hr" && in_body {
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
                } else if tag == "img" && in_body {
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
                } else if tag == "image" && in_body {
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
                } else if tag == "br" && in_body {
                    if in_block {
                        span_text.push('\n');
                    } else {
                        current_text.push('\n');
                    }
                } else if tag == "img" && in_block {
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
