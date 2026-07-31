use crate::api::models::{
    BlockType, BookFormat, MAX_FILE_SIZE, MAX_IMAGE_SIZE, NormalizedBook, ReaderBlock,
    ReaderChapter, RichSpan,
};
use crate::book::archive;
use crate::book::encoding::{attr_eq, get_xml_attr};
use anyhow::{Context, Result, bail};
use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use quick_xml::Reader;
use quick_xml::events::{BytesStart, Event};

#[derive(Clone, Copy, PartialEq, Eq)]
enum Fb2RootPhase {
    Stylesheets,
    Bodies,
    Binaries,
}

const MAX_FB2_SECTION_DEPTH: usize = 64;

#[derive(Default)]
struct Fb2SectionStructure {
    has_nested_section: bool,
    has_streaming_content: bool,
}

#[derive(serde::Serialize)]
struct Fb2SequenceMetadata {
    name: Option<String>,
    number: Option<String>,
    children: Vec<Fb2SequenceMetadata>,
}

fn enter_fb2_section(stack: &mut Vec<Fb2SectionStructure>) -> Result<()> {
    if stack.len() >= MAX_FB2_SECTION_DEPTH {
        bail!("FB2 section nesting exceeds the maximum depth of {MAX_FB2_SECTION_DEPTH}");
    }
    if let Some(parent) = stack.last_mut() {
        if parent.has_streaming_content {
            bail!("FB2 section cannot mix nested sections with streaming content");
        }
        parent.has_nested_section = true;
    }
    stack.push(Fb2SectionStructure::default());
    Ok(())
}

fn mark_fb2_section_content(stack: &mut [Fb2SectionStructure]) -> Result<()> {
    if let Some(section) = stack.last_mut() {
        if section.has_nested_section {
            bail!("FB2 section cannot mix nested sections with streaming content");
        }
        section.has_streaming_content = true;
    }
    Ok(())
}

fn validate_fb2_root_child(
    name: &[u8],
    phase: &mut Fb2RootPhase,
    description_count: &mut u32,
    body_count: &mut u32,
) -> Result<()> {
    match name {
        b"stylesheet" if *phase == Fb2RootPhase::Stylesheets => Ok(()),
        b"description" if *phase == Fb2RootPhase::Stylesheets && *description_count == 0 => {
            *description_count += 1;
            *phase = Fb2RootPhase::Bodies;
            Ok(())
        }
        b"body" if *phase == Fb2RootPhase::Bodies => {
            *body_count += 1;
            Ok(())
        }
        b"binary" if *phase == Fb2RootPhase::Bodies || *phase == Fb2RootPhase::Binaries => {
            *phase = Fb2RootPhase::Binaries;
            Ok(())
        }
        b"description" if *description_count > 0 => {
            bail!("FB2 root must contain exactly one description element")
        }
        b"body" if *description_count == 0 => {
            bail!("FB2 body must follow the description element")
        }
        b"body" => bail!("FB2 body elements must precede binary elements"),
        b"binary" if *body_count == 0 => {
            bail!("FB2 binary elements must follow at least one body element")
        }
        b"stylesheet" => bail!("FB2 stylesheet elements must precede description"),
        _ => bail!(
            "FB2 root contains unsupported or out-of-order element '{}'",
            String::from_utf8_lossy(name)
        ),
    }
}

fn validate_fb2_root_structure(
    root_closed: bool,
    description_count: u32,
    body_count: u32,
) -> Result<()> {
    if !root_closed {
        bail!("FB2 document must contain a complete FictionBook root element");
    }
    if description_count != 1 {
        bail!("FB2 root must contain exactly one description element");
    }
    if body_count == 0 {
        bail!("FB2 root must contain at least one body element");
    }
    Ok(())
}

pub fn parse_fb2(bytes: &[u8], forced_encoding: Option<&str>) -> Result<NormalizedBook> {
    if bytes.len() as u64 > MAX_FILE_SIZE {
        bail!(
            "FB2 file exceeds maximum size of {} MiB",
            MAX_FILE_SIZE / 1024 / 1024
        );
    }

    let (raw_bytes, archive_binaries, archive_media_types) = if looks_like_zip(bytes) {
        let mut zip = archive::decode_zip(bytes).context("Failed to open FB2.ZIP")?;
        let raw_bytes = find_fb2_in_zip(&mut zip)?.context("No .fb2 file found in archive")?;
        let (binaries, media_types) = read_zip_image_resources(&mut zip)?;
        (raw_bytes, binaries, media_types)
    } else {
        (
            bytes.to_vec(),
            std::collections::HashMap::new(),
            std::collections::HashMap::new(),
        )
    };

    let encoding_name = forced_encoding
        .map(|s| s.to_string())
        .unwrap_or_else(|| detect_fb2_encoding(&raw_bytes));
    let encoding =
        encoding_rs::Encoding::for_label(encoding_name.as_bytes()).unwrap_or(encoding_rs::UTF_8);
    let (xml_text, _) = encoding.decode_with_bom_removal(&raw_bytes);
    let xml_text = xml_text.into_owned();

    parse_fb2_xml(&xml_text, &raw_bytes, archive_binaries, archive_media_types)
}

fn parse_fb2_xml(
    xml_text: &str,
    bytes: &[u8],
    mut binaries: std::collections::HashMap<String, String>,
    mut binary_media_types: std::collections::HashMap<String, String>,
) -> Result<NormalizedBook> {
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
    let mut in_nickname = false;
    let mut in_genre = false;
    let mut in_body = false;
    let mut in_section = false;
    let mut in_content_title = false;
    let mut in_p = false;
    let mut in_subtitle = false;
    let mut in_epigraph = false;
    let mut in_image = false;
    let mut current_image_ref: Option<String> = None;
    let mut current_image_alt: Option<String> = None;
    let mut current_image_id: Option<String> = None;
    let mut in_empty_line = false;
    let mut in_coverpage = false;
    let mut in_binary = false;
    let mut in_text_author = false;
    let mut in_poem = false;
    let mut in_stanza = false;
    let mut in_cite = false;
    let mut in_pre = false;
    let mut in_table = false;
    let mut in_table_row = false;
    let mut in_table_cell = false;
    let mut in_lang = false;

    // CRT-1.13: FB2 footnotes parsing
    let mut in_notes_body = false;
    let mut note_section_depth = 0_usize;
    let mut current_note_id: Option<String> = None;
    let mut current_note_text = String::new();
    let mut footnotes: std::collections::HashMap<String, String> = std::collections::HashMap::new();
    let mut current_note_ref: Option<String> = None;

    let mut current_text = String::new();
    let mut current_author_parts: Vec<String> = Vec::new();
    let mut in_translator = false;
    let mut current_translator_parts: Vec<String> = Vec::new();
    let mut translators: Vec<String> = Vec::new();
    let mut keywords: Option<String> = None;
    let mut in_keywords = false;
    let mut current_keywords = String::new();
    let mut dates: Vec<serde_json::Value> = Vec::new();
    let mut in_date = false;
    let mut current_date = String::new();
    let mut current_date_value: Option<String> = None;
    let mut src_language: Option<String> = None;
    let mut in_src_lang = false;
    let mut current_src_lang = String::new();
    let mut sequences: Vec<Fb2SequenceMetadata> = Vec::new();
    let mut sequence_stack: Vec<Fb2SequenceMetadata> = Vec::new();
    let mut in_publish_info = false;
    let mut publish_info = serde_json::Map::new();
    let mut publish_field: Option<&'static str> = None;
    let mut current_publish_value = String::new();
    let mut current_rich_spans: Vec<RichSpan> = Vec::new();
    let mut current_span_text = String::new();
    let mut current_span_bold = false;
    let mut current_span_italic = false;
    let mut current_span_superscript = false;
    let mut current_span_subscript = false;
    let mut current_span_strikethrough = false;
    let mut current_span_code = false;
    let mut current_span_bold_depth = 0u32;
    let mut current_span_italic_depth = 0u32;
    let mut current_span_superscript_depth = 0u32;
    let mut current_span_subscript_depth = 0u32;
    let mut current_span_strikethrough_depth = 0u32;
    let mut current_span_code_depth = 0u32;
    let mut current_span_style_names: Vec<String> = Vec::new();
    let mut current_span_href: Option<String> = None;
    let mut table_rows: Vec<Vec<String>> = Vec::new();
    let mut current_table_row: Vec<String> = Vec::new();
    let mut current_table_cell = String::new();
    let mut section_depth = 0i32;
    let mut section_structure: Vec<Fb2SectionStructure> = Vec::new();
    let mut current_binary_id: Option<String> = None;
    let mut current_binary_media_type: Option<String> = None;
    let mut cover_media_type: Option<String> = None;
    let mut cover_image_ref: Option<String> = None;
    let mut root_depth = 0usize;
    let mut root_closed = false;
    let mut root_phase = Fb2RootPhase::Stylesheets;
    let mut root_description_count = 0u32;
    let mut root_body_count = 0u32;

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref e)) => {
                let name = e.name();
                if root_depth == 0 {
                    if root_closed || name.as_ref() != b"FictionBook" {
                        bail!("FB2 document must have FictionBook as its root element");
                    }
                    root_depth = 1;
                } else {
                    if root_depth == 1 {
                        validate_fb2_root_child(
                            name.as_ref(),
                            &mut root_phase,
                            &mut root_description_count,
                            &mut root_body_count,
                        )?;
                    }
                    root_depth += 1;
                }
                match e.name().as_ref() {
                    b"title-info" => in_title_info = true,
                    b"book-title" if in_title_info => in_book_title = true,
                    b"annotation" if in_title_info => in_annotation = true,
                    b"author" if in_title_info && !in_translator => {
                        in_author = true;
                        current_author_parts.clear();
                    }
                    b"first-name" if in_author || in_translator => in_first_name = true,
                    b"middle-name" if in_author || in_translator => in_middle_name = true,
                    b"last-name" if in_author || in_translator => in_last_name = true,
                    b"nickname" if in_author || in_translator => in_nickname = true,
                    b"genre" if in_title_info => in_genre = true,
                    b"lang" if in_title_info => in_lang = true,
                    b"src-lang" if in_title_info => {
                        in_src_lang = true;
                        current_src_lang.clear();
                    }
                    b"keywords" if in_title_info => {
                        in_keywords = true;
                        current_keywords.clear();
                    }
                    b"date" if in_title_info => {
                        in_date = true;
                        current_date.clear();
                        current_date_value = get_xml_attr(e, b"value");
                    }
                    b"translator" if in_title_info => {
                        in_translator = true;
                        current_translator_parts.clear();
                    }
                    b"sequence" if in_title_info => sequence_stack.push(Fb2SequenceMetadata {
                        name: get_xml_attr(e, b"name"),
                        number: get_xml_attr(e, b"number"),
                        children: Vec::new(),
                    }),
                    b"publish-info" => in_publish_info = true,
                    b"book-name" | b"publisher" | b"city" | b"year" | b"isbn"
                        if in_publish_info =>
                    {
                        publish_field = Some(match e.name().as_ref() {
                            b"book-name" => "bookName",
                            b"publisher" => "publisher",
                            b"city" => "city",
                            b"year" => "year",
                            b"isbn" => "isbn",
                            _ => unreachable!(),
                        });
                        current_publish_value.clear();
                    }
                    b"coverpage" => in_coverpage = true,
                    b"binary" => {
                        let binary_id = get_xml_attr(e, b"id").unwrap_or_default();
                        current_binary_media_type = get_xml_attr(e, b"content-type");
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
                        if language.is_none() {
                            language = get_xml_attr(e, b"xml:lang");
                        }
                    }
                    b"section" if in_body => {
                        if in_notes_body {
                            if note_section_depth == 0 {
                                current_note_id = get_xml_attr(e, b"id");
                                current_note_text.clear();
                            }
                            note_section_depth = note_section_depth.saturating_add(1);
                        } else {
                            if language.is_none() {
                                language = get_xml_attr(e, b"xml:lang");
                            }
                            enter_fb2_section(&mut section_structure)?;
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
                    b"table" if in_body && !in_notes_body => {
                        mark_fb2_section_content(&mut section_structure)?;
                        in_table = true;
                        table_rows.clear();
                    }
                    b"tr" if in_table => {
                        in_table_row = true;
                        current_table_row.clear();
                    }
                    b"td" | b"th" if in_table_row => {
                        in_table_cell = true;
                        current_table_cell.clear();
                    }
                    b"p" if in_body => {
                        if !in_notes_body {
                            mark_fb2_section_content(&mut section_structure)?;
                        }
                        if in_table_cell {
                            if !current_table_cell.is_empty() {
                                current_table_cell.push('\n');
                            }
                        } else {
                            in_p = true;
                        }
                    }
                    b"title" if in_body => {
                        mark_fb2_section_content(&mut section_structure)?;
                        in_content_title = true;
                    }
                    b"subtitle" if in_body => {
                        mark_fb2_section_content(&mut section_structure)?;
                        in_subtitle = true;
                    }
                    b"epigraph" if in_body => {
                        mark_fb2_section_content(&mut section_structure)?;
                        in_epigraph = true;
                    }
                    b"empty-line" if in_body => {
                        mark_fb2_section_content(&mut section_structure)?;
                        in_empty_line = true;
                    }
                    b"image" if in_coverpage => {
                        cover_image_ref = get_fb2_href(e);
                    }
                    b"image" if in_body && !in_coverpage => {
                        mark_fb2_section_content(&mut section_structure)?;
                        in_image = true;
                        current_image_ref = get_fb2_href(e);
                        current_image_alt =
                            get_xml_attr(e, b"alt").or_else(|| get_xml_attr(e, b"title"));
                        current_image_id = get_xml_attr(e, b"id");
                    }
                    b"text-author" if in_body => {
                        mark_fb2_section_content(&mut section_structure)?;
                        in_text_author = true;
                    }
                    b"poem" if in_body => {
                        mark_fb2_section_content(&mut section_structure)?;
                        in_poem = true;
                    }
                    b"stanza" if in_body && in_poem => {
                        if !in_notes_body && !current_text.trim().is_empty() {
                            body_blocks.push(ReaderBlock {
                                index: block_index,
                                text: current_text.trim().to_string(),
                                block_type: BlockType::Poem,
                                ..default_block()
                            });
                            block_index += 1;
                        }
                        if !in_notes_body {
                            current_text.clear();
                        }
                        in_stanza = true;
                    }
                    b"v" if in_body && in_poem => {
                        if !in_notes_body {
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
                    }
                    b"cite" if in_body => {
                        mark_fb2_section_content(&mut section_structure)?;
                        in_cite = true;
                    }
                    b"pre" if in_body => {
                        mark_fb2_section_content(&mut section_structure)?;
                        in_pre = true;
                    }
                    // `<code>` is not part of the core FB2 schema, but occurs in
                    // real-world books as a block extension. Treat it like `<pre>`
                    // when it is not inline paragraph content.
                    b"code" if in_body && !in_p => {
                        mark_fb2_section_content(&mut section_structure)?;
                        in_pre = true;
                    }
                    b"strong" if in_p || in_subtitle => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            current_span_subscript,
                            current_span_strikethrough,
                            current_span_code,
                            current_span_style_names.last(),
                            &current_span_href,
                        );
                        current_span_bold_depth = current_span_bold_depth.saturating_add(1);
                        current_span_bold = true;
                    }
                    b"emphasis" if in_p || in_subtitle => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            current_span_subscript,
                            current_span_strikethrough,
                            current_span_code,
                            current_span_style_names.last(),
                            &current_span_href,
                        );
                        current_span_italic_depth = current_span_italic_depth.saturating_add(1);
                        current_span_italic = true;
                    }
                    b"a" if in_p => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            current_span_subscript,
                            current_span_strikethrough,
                            current_span_code,
                            current_span_style_names.last(),
                            &current_span_href,
                        );
                        current_span_href =
                            get_fb2_href(e).and_then(|h| crate::book::sanitize_href(&h));
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
                            current_span_subscript,
                            current_span_strikethrough,
                            current_span_code,
                            current_span_style_names.last(),
                            &current_span_href,
                        );
                        current_span_superscript_depth =
                            current_span_superscript_depth.saturating_add(1);
                        current_span_superscript = true;
                    }
                    b"sub" if in_p || in_subtitle => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            current_span_subscript,
                            current_span_strikethrough,
                            current_span_code,
                            current_span_style_names.last(),
                            &current_span_href,
                        );
                        current_span_subscript_depth =
                            current_span_subscript_depth.saturating_add(1);
                        current_span_subscript = true;
                    }
                    b"strikethrough" if in_p || in_subtitle => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            current_span_subscript,
                            current_span_strikethrough,
                            current_span_code,
                            current_span_style_names.last(),
                            &current_span_href,
                        );
                        current_span_strikethrough_depth =
                            current_span_strikethrough_depth.saturating_add(1);
                        current_span_strikethrough = true;
                    }
                    b"code" if in_p || in_subtitle => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            current_span_subscript,
                            current_span_strikethrough,
                            current_span_code,
                            current_span_style_names.last(),
                            &current_span_href,
                        );
                        current_span_code_depth = current_span_code_depth.saturating_add(1);
                        current_span_code = true;
                    }
                    b"style" if in_p || in_subtitle => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            current_span_subscript,
                            current_span_strikethrough,
                            current_span_code,
                            current_span_style_names.last(),
                            &current_span_href,
                        );
                        current_span_style_names.push(get_xml_attr(e, b"name").unwrap_or_default());
                    }
                    _ => {}
                }
            }
            Ok(Event::Text(ref e)) => {
                let text = e.xml10_content().unwrap_or_default();
                if in_notes_body && (in_p || in_poem) {
                    current_note_text.push_str(&text);
                } else if in_book_title && title.is_empty() {
                    title = text.into_owned();
                } else if in_translator
                    && (in_first_name || in_middle_name || in_last_name || in_nickname)
                {
                    current_translator_parts.push(text.into_owned());
                } else if in_first_name || in_middle_name || in_last_name || in_nickname {
                    current_author_parts.push(text.into_owned());
                } else if in_genre {
                    genres.push(text.into_owned());
                } else if in_lang {
                    language = Some(text.into_owned());
                } else if in_src_lang {
                    current_src_lang.push_str(&text);
                } else if in_keywords {
                    current_keywords.push_str(&text);
                } else if in_date {
                    current_date.push_str(&text);
                } else if publish_field.is_some() {
                    current_publish_value.push_str(&text);
                } else if in_annotation {
                    description = Some(description.take().unwrap_or_default() + &text);
                } else if in_binary {
                    append_binary_data(&mut current_text, &text)?;
                } else if in_pre && in_body {
                    current_text.push_str(&text);
                } else if in_table_cell {
                    current_table_cell.push_str(&text);
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
                    && ((in_subtitle || in_epigraph || in_text_author || in_poem)
                        || (!in_section && !in_image && !in_empty_line))
                {
                    current_text.push_str(&text);
                }
            }
            Ok(Event::GeneralRef(ref e)) => {
                let text = e.xml10_content().unwrap_or_default();
                if in_notes_body && (in_p || in_poem) {
                    current_note_text.push_str(&text);
                } else if in_book_title && title.is_empty() {
                    title = text.into_owned();
                } else if in_translator
                    && (in_first_name || in_middle_name || in_last_name || in_nickname)
                {
                    current_translator_parts.push(text.into_owned());
                } else if in_first_name || in_middle_name || in_last_name || in_nickname {
                    current_author_parts.push(text.into_owned());
                } else if in_genre {
                    genres.push(text.into_owned());
                } else if in_lang {
                    language = Some(text.into_owned());
                } else if in_src_lang {
                    current_src_lang.push_str(&text);
                } else if in_keywords {
                    current_keywords.push_str(&text);
                } else if in_date {
                    current_date.push_str(&text);
                } else if publish_field.is_some() {
                    current_publish_value.push_str(&text);
                } else if in_pre && in_body {
                    current_text.push_str(&text);
                } else if in_p && in_body {
                    let owned = text.into_owned();
                    if let Some(last) = current_rich_spans.last_mut() {
                        if last.text.is_empty() && last.href.is_some() {
                            last.text = owned;
                        } else {
                            current_span_text.push_str(&owned);
                        }
                    } else {
                        current_span_text.push_str(&owned);
                    }
                } else if in_table_cell {
                    current_table_cell.push_str(&text);
                } else if in_body
                    && ((in_subtitle || in_epigraph || in_text_author || in_poem)
                        || (!in_section && !in_image && !in_empty_line))
                {
                    current_text.push_str(&text);
                }
            }
            Ok(Event::CData(ref e)) => {
                let text = e.xml10_content().unwrap_or_default();
                if in_notes_body && (in_p || in_poem) {
                    current_note_text.push_str(&text);
                } else if in_book_title && title.is_empty() {
                    title = text.into_owned();
                } else if in_translator
                    && (in_first_name || in_middle_name || in_last_name || in_nickname)
                {
                    current_translator_parts.push(text.into_owned());
                } else if in_first_name || in_middle_name || in_last_name || in_nickname {
                    current_author_parts.push(text.into_owned());
                } else if in_genre {
                    genres.push(text.into_owned());
                } else if in_lang {
                    language = Some(text.into_owned());
                } else if in_src_lang {
                    current_src_lang.push_str(&text);
                } else if in_keywords {
                    current_keywords.push_str(&text);
                } else if in_date {
                    current_date.push_str(&text);
                } else if publish_field.is_some() {
                    current_publish_value.push_str(&text);
                } else if in_annotation {
                    description = Some(description.take().unwrap_or_default() + &text);
                } else if in_binary {
                    append_binary_data(&mut current_text, &text)?;
                } else if in_pre && in_body {
                    current_text.push_str(&text);
                } else if in_table_cell {
                    current_table_cell.push_str(&text);
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
                    && ((in_subtitle || in_epigraph || in_text_author || in_poem)
                        || (!in_section && !in_image && !in_empty_line))
                {
                    current_text.push_str(&text);
                }
            }
            Ok(Event::End(ref e)) => {
                if root_depth == 0 {
                    bail!("FB2 document contains an unexpected closing element");
                }
                root_depth -= 1;
                if root_depth == 0 {
                    root_closed = true;
                }
                match e.name().as_ref() {
                    b"title-info" => in_title_info = false,
                    b"book-title" => in_book_title = false,
                    b"annotation" if in_title_info => {
                        in_annotation = false;
                        description =
                            Some(description.take().unwrap_or_default().trim().to_string());
                    }
                    b"first-name" => in_first_name = false,
                    b"middle-name" => in_middle_name = false,
                    b"last-name" => in_last_name = false,
                    b"nickname" => in_nickname = false,
                    b"author" => {
                        if !current_author_parts.is_empty() {
                            authors.push(current_author_parts.join(" "));
                            current_author_parts.clear();
                        }
                        in_author = false;
                    }
                    b"genre" => in_genre = false,
                    b"lang" => in_lang = false,
                    b"src-lang" if in_src_lang => {
                        src_language = Some(current_src_lang.trim().to_string());
                        current_src_lang.clear();
                        in_src_lang = false;
                    }
                    b"keywords" if in_keywords => {
                        keywords = Some(current_keywords.trim().to_string());
                        current_keywords.clear();
                        in_keywords = false;
                    }
                    b"date" if in_date => {
                        dates.push(serde_json::json!({
                            "text": current_date.trim(),
                            "value": current_date_value.take(),
                        }));
                        current_date.clear();
                        in_date = false;
                    }
                    b"translator" if in_translator => {
                        if !current_translator_parts.is_empty() {
                            translators.push(current_translator_parts.join(" "));
                            current_translator_parts.clear();
                        }
                        in_translator = false;
                    }
                    b"sequence" if in_title_info => {
                        if let Some(sequence) = sequence_stack.pop() {
                            if let Some(parent) = sequence_stack.last_mut() {
                                parent.children.push(sequence);
                            } else {
                                sequences.push(sequence);
                            }
                        }
                    }
                    b"book-name" | b"publisher" | b"city" | b"year" | b"isbn"
                        if publish_field.is_some() =>
                    {
                        if let Some(field) = publish_field.take() {
                            publish_info.insert(
                                field.to_string(),
                                serde_json::Value::String(current_publish_value.trim().to_string()),
                            );
                        }
                        current_publish_value.clear();
                    }
                    b"publish-info" => in_publish_info = false,
                    b"coverpage" => in_coverpage = false,
                    b"binary" => {
                        if in_binary && !current_text.is_empty() {
                            if let Some(ref id) = current_binary_id {
                                if id.starts_with("cover") && cover_data.is_none() {
                                    cover_data = Some(current_text.trim().to_string());
                                    cover_media_type = current_binary_media_type.clone();
                                }
                                binaries.insert(id.clone(), current_text.trim().to_string());
                                if let Some(media_type) = current_binary_media_type.clone() {
                                    binary_media_types.insert(id.clone(), media_type);
                                }
                            }
                        }
                        in_binary = false;
                        current_binary_id = None;
                        current_binary_media_type = None;
                        current_text.clear();
                    }
                    b"body" => {
                        in_body = false;
                        in_notes_body = false;
                        note_section_depth = 0;
                    }
                    b"td" | b"th" if in_table_cell => {
                        current_table_row.push(
                            current_table_cell
                                .split_whitespace()
                                .collect::<Vec<_>>()
                                .join(" "),
                        );
                        current_table_cell.clear();
                        in_table_cell = false;
                    }
                    b"tr" if in_table_row => {
                        table_rows.push(std::mem::take(&mut current_table_row));
                        in_table_row = false;
                    }
                    b"table" if in_table => {
                        if in_table_row {
                            table_rows.push(std::mem::take(&mut current_table_row));
                            in_table_row = false;
                        }
                        if !table_rows.is_empty() {
                            body_blocks.push(ReaderBlock {
                                index: block_index,
                                text: String::new(),
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
                                page_break_before: false,
                                page_break_inside_avoid: false,
                                has_drop_cap: false,
                            });
                            block_index += 1;
                        }
                        in_table = false;
                        in_table_cell = false;
                        current_table_cell.clear();
                    }
                    b"section" => {
                        if in_notes_body {
                            note_section_depth = note_section_depth.saturating_sub(1);
                            if note_section_depth == 0 {
                                if let Some(ref id) = current_note_id {
                                    let text = current_note_text.trim().to_string();
                                    if !text.is_empty() {
                                        footnotes.insert(id.clone(), text);
                                    }
                                }
                                current_note_id = None;
                                current_note_text.clear();
                            }
                        } else {
                            section_structure.pop();
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
                    b"p" if in_body && in_notes_body => {
                        if !current_note_text.is_empty() && !current_note_text.ends_with('\n') {
                            current_note_text.push('\n');
                        }
                        in_p = false;
                    }
                    b"p" if in_body => {
                        if !current_span_text.trim().is_empty() {
                            flush_rich_span(
                                &mut current_rich_spans,
                                &mut current_span_text,
                                current_span_bold,
                                current_span_italic,
                                current_span_superscript,
                                current_span_subscript,
                                current_span_strikethrough,
                                current_span_code,
                                current_span_style_names.last(),
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
                                block_type: if in_content_title {
                                    BlockType::Heading
                                } else if in_epigraph {
                                    BlockType::Epigraph
                                } else if in_cite {
                                    BlockType::Cite
                                } else {
                                    BlockType::Paragraph
                                },
                                image_url: None,
                                note_ref: current_note_ref.take(),
                                rich_spans: rich,
                                heading_level: in_content_title.then_some(section_depth.max(1)),
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
                        current_rich_spans.clear();
                        current_span_text.clear();
                        current_span_bold = false;
                        current_span_italic = false;
                        current_span_superscript = false;
                        current_span_subscript = false;
                        current_span_strikethrough = false;
                        current_span_code = false;
                        current_span_bold_depth = 0;
                        current_span_italic_depth = 0;
                        current_span_superscript_depth = 0;
                        current_span_subscript_depth = 0;
                        current_span_strikethrough_depth = 0;
                        current_span_code_depth = 0;
                        current_span_style_names.clear();
                        current_span_href = None;
                        in_p = false;
                    }
                    b"title" if in_body => in_content_title = false,
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
                                page_break_before: false,
                                page_break_inside_avoid: false,
                                has_drop_cap: false,
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
                                page_break_before: false,
                                page_break_inside_avoid: false,
                                has_drop_cap: false,
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
                                page_break_before: false,
                                page_break_inside_avoid: false,
                                has_drop_cap: false,
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
                        if in_notes_body {
                            if !current_note_text.ends_with('\n') {
                                current_note_text.push('\n');
                            }
                            in_stanza = false;
                            continue;
                        }
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
                        if in_notes_body {
                            if !current_note_text.ends_with('\n') {
                                current_note_text.push('\n');
                            }
                            continue;
                        }
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
                            BlockType::Preformatted,
                        );
                        in_pre = false;
                    }
                    b"code" if in_body && in_pre => {
                        flush_fb2_block(
                            &mut body_blocks,
                            &mut current_text,
                            &mut current_rich_spans,
                            &mut current_span_text,
                            &mut block_index,
                            BlockType::Preformatted,
                        );
                        in_pre = false;
                    }
                    b"empty-line" if in_body && !in_notes_body => {
                        mark_fb2_section_content(&mut section_structure)?;
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
                            page_break_before: false,
                            page_break_inside_avoid: false,
                            has_drop_cap: false,
                        });
                        block_index += 1;
                        in_empty_line = false;
                    }
                    b"image" if in_body && !in_coverpage => {
                        let image_ref = current_image_ref
                            .take()
                            .unwrap_or_else(|| current_text.trim().to_string());
                        current_text.clear();
                        let key = image_ref.trim_start_matches('#').to_string();
                        body_blocks.push(ReaderBlock {
                            index: block_index,
                            text: String::new(),
                            block_type: BlockType::Image,
                            image_url: fb2_binary_reference(&key),
                            note_ref: None,
                            rich_spans: None,
                            heading_level: None,
                            ordered: None,
                            list_items: None,
                            table_rows: None,
                            image_alt: current_image_alt.take(),
                            text_indent: None,
                            text_align: None,
                            note_id: current_image_id.take(),
                            page_break_before: false,
                            page_break_inside_avoid: false,
                            has_drop_cap: false,
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
                            current_span_subscript,
                            current_span_strikethrough,
                            current_span_code,
                            current_span_style_names.last(),
                            &current_span_href,
                        );
                        current_span_bold_depth = current_span_bold_depth.saturating_sub(1);
                        current_span_bold = current_span_bold_depth > 0;
                    }
                    b"emphasis" if in_p => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            current_span_subscript,
                            current_span_strikethrough,
                            current_span_code,
                            current_span_style_names.last(),
                            &current_span_href,
                        );
                        current_span_italic_depth = current_span_italic_depth.saturating_sub(1);
                        current_span_italic = current_span_italic_depth > 0;
                    }
                    b"a" if in_p => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            current_span_subscript,
                            current_span_strikethrough,
                            current_span_code,
                            current_span_style_names.last(),
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
                            current_span_subscript,
                            current_span_strikethrough,
                            current_span_code,
                            current_span_style_names.last(),
                            &current_span_href,
                        );
                        current_span_superscript_depth =
                            current_span_superscript_depth.saturating_sub(1);
                        current_span_superscript = current_span_superscript_depth > 0;
                    }
                    b"sub" if in_p => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            current_span_subscript,
                            current_span_strikethrough,
                            current_span_code,
                            current_span_style_names.last(),
                            &current_span_href,
                        );
                        current_span_subscript_depth =
                            current_span_subscript_depth.saturating_sub(1);
                        current_span_subscript = current_span_subscript_depth > 0;
                    }
                    b"strikethrough" if in_p => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            current_span_subscript,
                            current_span_strikethrough,
                            current_span_code,
                            current_span_style_names.last(),
                            &current_span_href,
                        );
                        current_span_strikethrough_depth =
                            current_span_strikethrough_depth.saturating_sub(1);
                        current_span_strikethrough = current_span_strikethrough_depth > 0;
                    }
                    b"code" if in_p => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            current_span_subscript,
                            current_span_strikethrough,
                            current_span_code,
                            current_span_style_names.last(),
                            &current_span_href,
                        );
                        current_span_code_depth = current_span_code_depth.saturating_sub(1);
                        current_span_code = current_span_code_depth > 0;
                    }
                    b"style" if in_p => {
                        flush_rich_span(
                            &mut current_rich_spans,
                            &mut current_span_text,
                            current_span_bold,
                            current_span_italic,
                            current_span_superscript,
                            current_span_subscript,
                            current_span_strikethrough,
                            current_span_code,
                            current_span_style_names.last(),
                            &current_span_href,
                        );
                        current_span_style_names.pop();
                    }
                    _ => {}
                }
            }
            Ok(Event::Empty(ref e)) => {
                if root_depth == 1 {
                    validate_fb2_root_child(
                        e.name().as_ref(),
                        &mut root_phase,
                        &mut root_description_count,
                        &mut root_body_count,
                    )?;
                }
                match e.name().as_ref() {
                    b"sequence" if in_title_info => {
                        let sequence = Fb2SequenceMetadata {
                            name: get_xml_attr(e, b"name"),
                            number: get_xml_attr(e, b"number"),
                            children: Vec::new(),
                        };
                        if let Some(parent) = sequence_stack.last_mut() {
                            parent.children.push(sequence);
                        } else {
                            sequences.push(sequence);
                        }
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
                            page_break_before: false,
                            page_break_inside_avoid: false,
                            has_drop_cap: false,
                        });
                        block_index += 1;
                    }
                    b"image" if in_coverpage => {
                        cover_image_ref = get_fb2_href(e);
                    }
                    b"image" if in_body && !in_coverpage => {
                        mark_fb2_section_content(&mut section_structure)?;
                        let href = get_fb2_href(e).unwrap_or_default();
                        let key = href.trim_start_matches('#').to_string();
                        body_blocks.push(ReaderBlock {
                            index: block_index,
                            text: String::new(),
                            block_type: BlockType::Image,
                            image_url: fb2_binary_reference(&key),
                            note_ref: None,
                            rich_spans: None,
                            heading_level: None,
                            ordered: None,
                            list_items: None,
                            table_rows: None,
                            image_alt: get_xml_attr(e, b"alt")
                                .or_else(|| get_xml_attr(e, b"title")),
                            text_indent: None,
                            text_align: None,
                            note_id: get_xml_attr(e, b"id"),
                            page_break_before: false,
                            page_break_inside_avoid: false,
                            has_drop_cap: false,
                        });
                        block_index += 1;
                    }
                    _ => {}
                }
            }
            Err(e) => {
                bail!("FB2 XML parse error: {}", e);
            }
            _ => {}
        }
    }

    validate_fb2_root_structure(root_closed, root_description_count, root_body_count)?;

    let cover_url = cover_image_ref
        .as_deref()
        .map(|reference| reference.trim_start_matches('#'))
        .and_then(|id| {
            binaries
                .get(id)
                .map(|data| binary_data_uri(data, binary_media_types.get(id)))
        })
        .or_else(|| cover_data.map(|data| binary_data_uri(&data, cover_media_type.as_ref())));

    let mut chapters = if !chapters_blocks.is_empty() {
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
    resolve_fb2_binary_references(&mut chapters, &binaries, &binary_media_types);

    let id = crate::book::sha256_hex(bytes);

    let mut metadata = serde_json::Map::new();
    if !footnotes.is_empty() {
        metadata.insert("footnotes".to_string(), serde_json::json!(footnotes));
    }
    if !genres.is_empty() {
        // NormalizedBook has no dedicated genre field. Preserve raw FB2 codes
        // instead of guessing an unofficial 2.0 → 2.1 mapping.
        metadata.insert("genres".to_string(), serde_json::json!(genres));
    }
    if let Some(keywords) = keywords.filter(|keywords| !keywords.is_empty()) {
        metadata.insert("keywords".to_string(), serde_json::json!(keywords));
    }
    if !dates.is_empty() {
        metadata.insert("dates".to_string(), serde_json::json!(dates));
    }
    if let Some(src_language) = src_language.filter(|language| !language.is_empty()) {
        metadata.insert("srcLanguage".to_string(), serde_json::json!(src_language));
    }
    if !translators.is_empty() {
        metadata.insert("translators".to_string(), serde_json::json!(translators));
    }
    if !sequences.is_empty() {
        metadata.insert("sequences".to_string(), serde_json::json!(sequences));
    }
    if !publish_info.is_empty() {
        metadata.insert(
            "publication".to_string(),
            serde_json::Value::Object(publish_info),
        );
    }
    let metadata = (!metadata.is_empty()).then_some(serde_json::Value::Object(metadata));

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

fn binary_data_uri(data: &str, declared_media_type: Option<&String>) -> String {
    let media_type = declared_media_type
        .map(|value| value.trim().to_ascii_lowercase())
        .and_then(|value| match value.as_str() {
            "image/jpeg" | "image/png" | "image/gif" | "image/webp" | "image/bmp"
            | "image/tiff" => Some(value),
            _ => None,
        })
        .unwrap_or_else(|| "image/jpeg".to_string());
    format!("data:{media_type};base64,{data}")
}

const FB2_BINARY_REFERENCE_PREFIX: &str = "fb2-binary:";

fn fb2_binary_reference(key: &str) -> Option<String> {
    (!key.is_empty()).then(|| format!("{FB2_BINARY_REFERENCE_PREFIX}{key}"))
}

/// Binary nodes are valid after the body in FB2, so image references are
/// resolved only once the complete XML document has been read.
fn resolve_fb2_binary_references(
    chapters: &mut [ReaderChapter],
    binaries: &std::collections::HashMap<String, String>,
    binary_media_types: &std::collections::HashMap<String, String>,
) {
    for block in chapters.iter_mut().flat_map(|chapter| &mut chapter.blocks) {
        let Some(reference) = block.image_url.as_deref() else {
            continue;
        };
        let Some(key) = reference.strip_prefix(FB2_BINARY_REFERENCE_PREFIX) else {
            continue;
        };
        block.image_url = binaries
            .get(key)
            .map(|data| binary_data_uri(data, binary_media_types.get(key)));
    }
}

/// XML namespace prefixes are document-local, so accept any prefix whose local
/// attribute name is `href` (`l:href`, `xlink:href`, or an unprefixed href).
fn get_fb2_href(element: &BytesStart<'_>) -> Option<String> {
    element
        .attributes()
        .flatten()
        .find(|attribute| attribute.key.local_name().as_ref() == b"href")
        // Attribute values are XML-escaped. Normalize them before the scheme
        // allow/deny check so `java&#x0A;script:` cannot bypass it.
        .and_then(|attribute| {
            attribute
                .normalized_value(quick_xml::XmlVersion::Implicit1_0)
                .ok()
                .map(|value| value.into_owned())
        })
}

fn max_base64_image_size() -> usize {
    MAX_IMAGE_SIZE
        .checked_add(2)
        .and_then(|size| size.checked_div(3))
        .and_then(|groups| groups.checked_mul(4))
        .unwrap_or(usize::MAX)
}

fn append_binary_data(buffer: &mut String, data: &str) -> Result<()> {
    if buffer.len().saturating_add(data.len()) > max_base64_image_size() {
        bail!(
            "FB2 image exceeds maximum size of {} MiB",
            MAX_IMAGE_SIZE / 1024 / 1024
        );
    }
    buffer.push_str(data);
    Ok(())
}

fn looks_like_zip(bytes: &[u8]) -> bool {
    bytes.len() >= 2 && bytes[0] == b'P' && bytes[1] == b'K'
}

fn find_fb2_in_zip(zip: &mut archive::ZipFile<'_>) -> Result<Option<Vec<u8>>> {
    let Some(name) = zip
        .entry_names()
        .iter()
        .find(|name| is_fb2_book_entry(name))
        .cloned()
    else {
        return Ok(None);
    };
    zip.read_file_limited(&name, crate::api::models::MAX_FILE_SIZE as usize)
}

fn read_zip_image_resources(
    zip: &mut archive::ZipFile<'_>,
) -> Result<(
    std::collections::HashMap<String, String>,
    std::collections::HashMap<String, String>,
)> {
    let mut binaries = std::collections::HashMap::new();
    let mut media_types = std::collections::HashMap::new();

    for name in zip.entry_names().to_vec() {
        let Some(key) = normalized_zip_image_path(&name) else {
            continue;
        };
        let Some(media_type) = image_media_type(&key) else {
            continue;
        };
        let Some(bytes) = zip.read_file_limited(&name, MAX_IMAGE_SIZE)? else {
            continue;
        };
        binaries.insert(key.clone(), STANDARD.encode(bytes));
        media_types.insert(key, media_type.to_string());
    }

    Ok((binaries, media_types))
}

fn normalized_zip_image_path(path: &str) -> Option<String> {
    let normalized = path.trim().replace('\\', "/");
    if normalized.is_empty()
        || normalized.starts_with('/')
        || normalized
            .split('/')
            .any(|part| part.is_empty() || part == "..")
    {
        return None;
    }
    Some(
        normalized
            .strip_prefix("./")
            .unwrap_or(&normalized)
            .to_string(),
    )
}

fn image_media_type(path: &str) -> Option<&'static str> {
    match path.rsplit_once('.')?.1.to_ascii_lowercase().as_str() {
        "jpg" | "jpeg" => Some("image/jpeg"),
        "png" => Some("image/png"),
        "gif" => Some("image/gif"),
        "webp" => Some("image/webp"),
        "bmp" => Some("image/bmp"),
        "tif" | "tiff" => Some("image/tiff"),
        _ => None,
    }
}

fn is_fb2_book_entry(name: &str) -> bool {
    let normalized = name.replace('\\', "/");
    normalized
        .rsplit_once('.')
        .is_some_and(|(_, extension)| extension.eq_ignore_ascii_case("fb2"))
        && !normalized.starts_with('/')
        && !normalized.split('/').any(|segment| {
            segment.is_empty()
                || matches!(segment, "." | ".." | "__MACOSX")
                || segment.starts_with('.')
        })
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
    // XML processors must recognize UTF-16 documents from the initial markup
    // even when a producer omitted the optional BOM.
    if bytes.starts_with(&[b'<', 0]) {
        return "utf-16le".to_string();
    }
    if bytes.starts_with(&[0, b'<']) {
        return "utf-16be".to_string();
    }
    let snippet = &bytes[..bytes.len().min(200)];
    if let Some(pos) = snippet
        .windows(b"encoding=".len())
        .position(|window| window == b"encoding=")
    {
        let after = &snippet[pos + b"encoding=".len()..];
        if let Some(q) = after.first() {
            if *q == b'"' || *q == b'\'' {
                let quote = *q;
                if let Some(end) = after[1..].iter().position(|&b| b == quote) {
                    let label = std::str::from_utf8(&after[1..1 + end]).unwrap_or("utf-8");
                    if encoding_rs::Encoding::for_label_no_replacement(label.as_bytes()).is_some() {
                        if label.eq_ignore_ascii_case("utf-8")
                            && std::str::from_utf8(bytes).is_err()
                        {
                            // A false UTF-8 declaration must not turn legacy bytes into
                            // replacement characters. Use the same statistical fallback as a
                            // missing/unknown declaration instead of assuming Cyrillic.
                            return crate::book::encoding::detect_encoding(bytes).to_string();
                        }
                        return label.to_lowercase();
                    }
                }
            }
        }
    }
    if std::str::from_utf8(bytes).is_err() {
        return crate::book::encoding::detect_encoding(bytes).to_string();
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
        page_break_before: false,
        page_break_inside_avoid: false,
        has_drop_cap: false,
    }
}

/// FB2 paragraphs are reconstructed from spans, so keep unformatted segments
/// as spans too. The shared helper intentionally drops them for parsers that
/// retain plain text separately.
fn flush_rich_span(
    spans: &mut Vec<RichSpan>,
    span_text: &mut String,
    bold: bool,
    italic: bool,
    superscript: bool,
    subscript: bool,
    strikethrough: bool,
    code: bool,
    style_name: Option<&String>,
    href: &Option<String>,
) {
    let text = std::mem::take(span_text);
    if text.trim().is_empty() {
        return;
    }
    spans.push(RichSpan {
        text,
        bold,
        italic,
        superscript,
        subscript,
        strikethrough,
        code,
        style_name: style_name.cloned(),
        href: href.clone(),
        line_break: false,
    });
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
        false,
        false,
        false,
        None,
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
            page_break_before: false,
            page_break_inside_avoid: false,
            has_drop_cap: false,
        });
        *block_index += 1;
    }
    current_text.clear();
    current_rich_spans.clear();
    current_span_text.clear();
}

#[cfg(test)]
mod tests {
    use super::{MAX_FB2_SECTION_DEPTH, max_base64_image_size, parse_fb2};
    use crate::api::models::BlockType;

    #[test]
    fn accepts_schema_ordered_root_children() {
        let book = parse_fb2(
            br#"<FictionBook>
                <stylesheet type="text/css">p { color: red; }</stylesheet>
                <stylesheet type="text/css"/>
                <description><title-info><book-title>Ordered root</book-title></title-info></description>
                <body><section><p>Reader content.</p></section></body>
                <body name="notes"><section id="note"><p>Note.</p></section></body>
                <binary id="cover" content-type="image/png">iVBORw0KGgo=</binary>
            </FictionBook>"#,
            Some("utf-8"),
        )
        .expect("schema-ordered FB2 root must parse");

        assert_eq!(book.title, "Ordered root");
        assert_eq!(book.chapters[0].blocks[0].text, "Reader content.");
    }

    #[test]
    fn rejects_out_of_order_or_duplicate_root_children() {
        for (xml, expected_error) in [
            (
                "<FictionBook><description/><body/><description/></FictionBook>",
                "exactly one description",
            ),
            (
                "<FictionBook><description/><binary/><body/></FictionBook>",
                "body elements must precede binary",
            ),
            (
                "<FictionBook><body/></FictionBook>",
                "body must follow the description",
            ),
            (
                "<FictionBook><description/></FictionBook>",
                "at least one body",
            ),
        ] {
            let error = parse_fb2(xml.as_bytes(), Some("utf-8"))
                .expect_err("invalid FB2 root order must return a controlled error");
            assert!(
                error.to_string().contains(expected_error),
                "unexpected error: {error:#}",
            );
        }
    }

    #[test]
    fn preserves_title_info_fields_represented_by_normalized_book() {
        let book = parse_fb2(
            br##"<FictionBook xmlns:l="http://www.w3.org/1999/xlink">
                <description><title-info>
                    <genre match="90">science</genre><genre match="10">fiction</genre>
                    <author><first-name>Ada</first-name><last-name>Lovelace</last-name></author>
                    <author><nickname>The Poet</nickname></author>
                    <book-title>Metadata fixture</book-title>
                    <annotation><p>First annotation paragraph.</p><p>Second paragraph.</p></annotation>
                    <keywords>analytical engine, notes</keywords>
                    <date value="1843-01-01">1843</date><lang>en</lang><src-lang>fr</src-lang>
                    <translator><nickname>Translator</nickname></translator>
                    <sequence name="Collected"><sequence name="Volume" number="1"/></sequence>
                    <coverpage><image l:href="#front-art"/></coverpage>
                </title-info></description>
                <body><section><p>Reader content.</p></section></body>
                <binary id="front-art" content-type="image/png">iVBORw0KGgo=</binary>
            </FictionBook>"##,
            Some("utf-8"),
        )
        .expect("parse complete title-info metadata");

        assert_eq!(book.title, "Metadata fixture");
        assert_eq!(book.authors, ["Ada Lovelace", "The Poet"]);
        assert_eq!(book.language.as_deref(), Some("en"));
        assert!(
            book.description
                .as_deref()
                .is_some_and(|description| description.contains("First annotation paragraph."))
        );
        assert!(
            book.cover_url
                .as_deref()
                .is_some_and(|url| url.starts_with("data:image/png;base64,"))
        );
        let metadata = book.metadata.as_ref().expect("extended metadata");
        assert_eq!(metadata["keywords"], "analytical engine, notes");
        assert_eq!(metadata["dates"][0]["text"], "1843");
        assert_eq!(metadata["dates"][0]["value"], "1843-01-01");
        assert_eq!(metadata["srcLanguage"], "fr");
        assert_eq!(metadata["translators"], serde_json::json!(["Translator"]));
        assert_eq!(metadata["sequences"][0]["name"], "Collected");
        assert_eq!(metadata["sequences"][0]["children"][0]["name"], "Volume");
        assert_eq!(book.chapters[0].blocks[0].text, "Reader content.");
    }

    #[test]
    fn preserves_raw_unknown_genre_codes_without_guessing_a_mapping() {
        let book = parse_fb2(
            br#"<FictionBook><description><title-info><genre>sf_history</genre><genre>custom-unmapped</genre></title-info></description><body><section><p>Content</p></section></body></FictionBook>"#,
            Some("utf-8"),
        )
        .expect("parse FB2 with unknown genres");

        assert_eq!(
            book.metadata
                .as_ref()
                .and_then(|metadata| metadata["genres"].as_array())
                .expect("raw genres are retained")
                .iter()
                .filter_map(serde_json::Value::as_str)
                .collect::<Vec<_>>(),
            vec!["sf_history", "custom-unmapped"],
        );
    }

    #[test]
    fn preserves_publication_metadata_without_overriding_canonical_title_info() {
        let book = parse_fb2(
            br#"<FictionBook><description>
                <title-info><book-title>Canonical title</book-title><author><nickname>Canonical author</nickname></author></title-info>
                <src-title-info><book-title>Source title</book-title><author><nickname>Source author</nickname></author></src-title-info>
                <document-info><author><nickname>Document author</nickname></author><id>uuid</id><version>2.0</version><history><p>history</p></history><src-url>https://example.test/source</src-url></document-info>
                <publish-info><book-name>Published title</book-name><publisher>Publisher</publisher><city>City</city><year>2026</year><isbn>isbn</isbn></publish-info>
            </description><body><section><p>Canonical content.</p></section></body></FictionBook>"#,
            Some("utf-8"),
        )
        .expect("parse FB2 source and publication metadata");

        assert_eq!(book.title, "Canonical title");
        assert_eq!(book.authors, ["Canonical author"]);
        assert_eq!(
            book.metadata
                .as_ref()
                .and_then(|metadata| metadata["publication"]["publisher"].as_str()),
            Some("Publisher"),
        );
        assert_eq!(
            book.metadata
                .as_ref()
                .and_then(|metadata| metadata["publication"]["isbn"].as_str()),
            Some("isbn"),
        );
        assert_eq!(book.chapters[0].blocks[0].text, "Canonical content.");
    }

    #[test]
    fn ignores_custom_info_and_stylesheet_processing_instruction() {
        let book = parse_fb2(
            br#"<?xml version="1.0" encoding="utf-8"?>
                <?xml-stylesheet type="text/xsl" href="https://example.test/untrusted.xsl"?>
                <FictionBook><description>
                    <title-info>
                        <book-title>Safe title</book-title>
                        <author><nickname>Safe author</nickname></author>
                    </title-info>
                    <custom-info info-type="tracking">https://example.test/custom</custom-info>
                </description><body><section><p>Safe content.</p></section></body></FictionBook>"#,
            Some("utf-8"),
        )
        .expect("custom metadata must not affect FB2 parsing");

        assert_eq!(book.title, "Safe title");
        assert_eq!(book.authors, ["Safe author"]);
        assert_eq!(book.chapters[0].blocks[0].text, "Safe content.");
        assert!(
            book.description.is_none(),
            "custom-info must not become reader metadata"
        );
    }

    #[test]
    fn ignores_output_policy_metadata_without_hiding_book_content() {
        let book = parse_fb2(
            br#"<FictionBook><description><title-info>
                    <book-title>Preview</book-title>
                    <author><nickname>Author</nickname></author>
                    <output>paid</output><part>sample</part>
                    <output-document-class>commercial</output-document-class>
                </title-info></description>
                <body><section><title><p>Chapter</p></title>
                    <output>do not render this policy</output>
                    <part>do not render this policy either</part>
                    <p>Visible reader content.</p>
                </section></body></FictionBook>"#,
            Some("utf-8"),
        )
        .expect("FB2 output policy metadata must not reject the book");

        assert_eq!(book.title, "Preview");
        assert_eq!(book.authors, ["Author"]);
        assert_eq!(book.chapters[0].blocks[0].text, "Chapter");
        assert_eq!(book.chapters[0].blocks[1].text, "Visible reader content.");
        assert!(
            book.chapters[0]
                .blocks
                .iter()
                .all(|block| !block.text.contains("do not render")),
            "output policy directives must not become reader content",
        );
    }

    #[test]
    #[cfg_attr(
        miri,
        ignore = "large CDATA limit test is prohibitively slow under Miri"
    )]
    fn rejects_oversized_image_in_cdata() {
        let base64 = "A".repeat(max_base64_image_size() + 1);
        let fb2 = format!(
            "<FictionBook><description/><body/><binary id=\"illustration\"><![CDATA[{base64}]]></binary></FictionBook>"
        );

        let error = parse_fb2(fb2.as_bytes(), Some("utf-8"))
            .expect_err("CDATA image above the size limit must be rejected");

        assert!(error.to_string().contains("FB2 image exceeds maximum size"));
    }

    #[test]
    fn preserves_declared_mime_type_for_binary_cover() {
        let book = parse_fb2(
            br#"<FictionBook><description><title-info><book-title>PNG cover</book-title></title-info></description><body/><binary id="cover.png" content-type="image/png">iVBORw0KGgo=</binary></FictionBook>"#,
            Some("utf-8"),
        )
        .expect("parse FB2 with PNG cover");

        assert!(
            book.cover_url
                .is_some_and(|url| url.starts_with("data:image/png;base64,"))
        );
    }

    #[test]
    fn recovers_from_a_false_utf8_declaration_for_windows_1251_bytes() {
        let mut bytes = b"<?xml version=\"1.0\" encoding=\"UTF-8\"?><FictionBook><description><title-info><book-title>".to_vec();
        for _ in 0..32 {
            bytes.extend_from_slice(&[0xcf, 0xf0, 0xe8, 0xe2, 0xe5, 0xf2, b' ']);
        }
        bytes.extend_from_slice(b"</book-title></title-info></description><body><section><p>Text</p></section></body></FictionBook>");

        let book = parse_fb2(&bytes, None).expect("parse CP1251 FB2 with false UTF-8 declaration");

        assert!(book.title.starts_with("Привет"), "{}", book.title);
    }

    #[test]
    fn decodes_declared_windows_1250_and_windows_1252_fb2() {
        for (label, title) in [
            ("windows-1250", "Příliš žluťoučký kůň"),
            ("windows-1252", "Résumé — café"),
        ] {
            let encoding = encoding_rs::Encoding::for_label(label.as_bytes())
                .expect("fixture encoding must be supported");
            let (encoded_title, _, _) = encoding.encode(title);
            let mut bytes = format!(
                "<?xml version=\"1.0\" encoding=\"{label}\"?><FictionBook><description><title-info><book-title>"
            )
            .into_bytes();
            bytes.extend_from_slice(&encoded_title);
            bytes.extend_from_slice(
                b"</book-title></title-info></description><body><section><p>Text</p></section></body></FictionBook>",
            );

            let book = parse_fb2(&bytes, None).expect("parse declared legacy FB2");
            assert_eq!(book.title, title, "{label}");
        }
    }

    #[test]
    fn decodes_utf16_fb2_with_or_without_bom_without_leaking_it_into_content() {
        for (label, bom, encode_unit) in [
            (
                "UTF-16LE",
                &[0xff, 0xfe][..],
                u16::to_le_bytes as fn(u16) -> [u8; 2],
            ),
            (
                "UTF-16BE",
                &[0xfe, 0xff][..],
                u16::to_be_bytes as fn(u16) -> [u8; 2],
            ),
        ] {
            let xml = format!(
                "<?xml version=\"1.0\" encoding=\"{label}\"?><FictionBook><description><title-info><book-title>Книга 漢字</book-title></title-info></description><body><section><p>Текст 漢字.</p></section></body></FictionBook>"
            );
            for with_bom in [true, false] {
                let mut bytes = if with_bom { bom } else { &[] }.to_vec();
                for unit in xml.encode_utf16() {
                    bytes.extend_from_slice(&encode_unit(unit));
                }

                let book = parse_fb2(&bytes, None).expect("parse UTF-16 FB2");

                assert_eq!(book.title, "Книга 漢字", "{label}, with_bom={with_bom}");
                assert_eq!(
                    book.chapters[0].blocks[0].text, "Текст 漢字.",
                    "{label}, with_bom={with_bom}",
                );
            }
        }
    }

    #[test]
    fn decodes_utf8_bom_fb2_without_leaking_the_bom_into_content() {
        let mut bytes = b"\xef\xbb\xbf".to_vec();
        bytes.extend_from_slice(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?><FictionBook><description><title-info><book-title>Книга</book-title></title-info></description><body><section><p>Текст.</p></section></body></FictionBook>".as_bytes(),
        );

        let book = parse_fb2(&bytes, None).expect("parse BOM-marked UTF-8 FB2");

        assert_eq!(book.title, "Книга");
        assert_eq!(book.chapters[0].blocks[0].text, "Текст.");
    }

    #[test]
    fn imports_compact_cp1251_fb2_21_compatibility_corpus_fixture() {
        let xml = r##"<?xml version="1.0" encoding="windows-1251"?>
            <FictionBook xmlns:alt="http://www.w3.org/1999/xlink">
              <description><title-info><book-title>Тестовая книга</book-title><lang>ru</lang><output>paid</output></title-info></description>
              <body><section><section><section>
                <p>Основной<a alt:href="#note-1" type="note">1</a><strikethrough>зачеркнуто</strikethrough><style name="code">Стиль</style></p>
                <output>не показывать</output>
              </section></section></section>
              <section><table><tr><th>Заголовок</th></tr><tr><td>Ячейка</td></tr></table></section></body>
              <body name="notes"><section id="note-1"><p>Текст сноски</p></section></body>
            </FictionBook>"##;
        let (bytes, _, _) = encoding_rs::WINDOWS_1251.encode(xml);

        let book = parse_fb2(&bytes, None).expect("parse compact CP1251 FB2 2.1 fixture");

        assert_eq!(book.title, "Тестовая книга");
        assert_eq!(book.language.as_deref(), Some("ru"));
        assert_eq!(book.chapters.len(), 2);
        let spans = book.chapters[0].blocks[0]
            .rich_spans
            .as_ref()
            .expect("formatted paragraph spans");
        assert!(
            spans
                .iter()
                .any(|span| span.href.as_deref() == Some("#note-1"))
        );
        assert!(spans.iter().any(|span| span.strikethrough));
        assert!(
            spans
                .iter()
                .any(|span| span.style_name.as_deref() == Some("code"))
        );
        assert_eq!(
            book.metadata
                .as_ref()
                .and_then(|metadata| metadata["footnotes"]["note-1"].as_str()),
            Some("Текст сноски"),
        );
        assert_eq!(
            book.chapters[1].blocks[0].table_rows.as_deref(),
            Some(&[vec!["Заголовок".to_string()], vec!["Ячейка".to_string()]][..]),
        );
        assert!(
            book.chapters
                .iter()
                .flat_map(|chapter| &chapter.blocks)
                .all(|block| !block.text.contains("не показывать")),
        );
    }

    #[test]
    fn falls_back_for_unknown_or_false_utf8_declarations_without_corrupting_windows_1252() {
        let title = "Résumé — café";
        let (encoded_title, _, _) = encoding_rs::WINDOWS_1252.encode(title);

        for declaration in ["x-fictionbook-legacy", "utf-8"] {
            let mut bytes = format!(
                "<?xml version=\"1.0\" encoding=\"{declaration}\"?><FictionBook><description><title-info><book-title>"
            )
            .into_bytes();
            bytes.extend_from_slice(&encoded_title);
            bytes.extend_from_slice(
                b"</book-title></title-info></description><body><section><p>Text</p></section></body></FictionBook>",
            );

            let book = parse_fb2(&bytes, None).expect("fallback must keep FB2 readable");
            assert_eq!(book.title, title, "{declaration}");
        }
    }

    #[test]
    fn detects_cp866_without_an_xml_declaration() {
        let (encoded, _, _) = encoding_rs::IBM866.encode("Привет ");
        let mut bytes = b"<FictionBook><description><title-info><book-title>".to_vec();
        for _ in 0..32 {
            bytes.extend_from_slice(&encoded);
        }
        bytes.extend_from_slice(b"</book-title></title-info></description><body><section><p>Text</p></section></body></FictionBook>");

        let book = parse_fb2(&bytes, None).expect("parse CP866 FB2 without declaration");

        assert!(book.title.starts_with("Привет"), "{}", book.title);
    }

    #[test]
    fn detects_koi8_r_without_an_xml_declaration() {
        let (encoded, _, _) = encoding_rs::KOI8_R.encode("Привет ");
        let mut bytes = b"<FictionBook><description><title-info><book-title>".to_vec();
        for _ in 0..32 {
            bytes.extend_from_slice(&encoded);
        }
        bytes.extend_from_slice(b"</book-title></title-info></description><body><section><p>Text</p></section></body></FictionBook>");

        let book = parse_fb2(&bytes, None).expect("parse KOI8-R FB2 without declaration");

        assert!(book.title.starts_with("Привет"), "{}", book.title);
    }

    #[test]
    fn preserves_declared_mime_type_for_inline_binary_images() {
        let book = parse_fb2(
            br##"<FictionBook xmlns:l="http://www.w3.org/1999/xlink"><description/><body><section><image l:href="#illustration.webp"/></section></body><binary id="illustration.webp" content-type="image/webp">UklGRg==</binary></FictionBook>"##,
            Some("utf-8"),
        )
        .expect("parse FB2 with WebP illustration");

        assert!(
            book.chapters[0].blocks[0]
                .image_url
                .as_deref()
                .is_some_and(|url| url.starts_with("data:image/webp;base64,"))
        );
    }

    #[test]
    fn preserves_fb2_21_image_alt_and_anchor_without_affecting_binary_lookup() {
        let book = parse_fb2(
            br##"<FictionBook xmlns:l="http://www.w3.org/1999/xlink"><description><title-info><coverpage><image l:href="#cover-art" alt="Cover alternative" title="Cover title" id="cover-anchor"/></coverpage></title-info></description><body><section><image l:href="#inline-art" alt="Inline alternative" title="Inline title" id="inline-anchor"/></section></body><binary id="cover-art" content-type="image/png">AQID</binary><binary id="inline-art" content-type="image/jpeg">AQID</binary></FictionBook>"##,
            Some("utf-8"),
        )
        .expect("parse FB2 2.1 image attributes");

        assert_eq!(
            book.cover_url.as_deref(),
            Some("data:image/png;base64,AQID")
        );
        let image = &book.chapters[0].blocks[0];
        assert_eq!(
            image.image_url.as_deref(),
            Some("data:image/jpeg;base64,AQID")
        );
        assert_eq!(image.image_alt.as_deref(), Some("Inline alternative"));
        assert_eq!(image.note_id.as_deref(), Some("inline-anchor"));
    }

    #[test]
    fn imports_fb2_21_compatibility_fixture_like_equivalent_fb2_20() {
        let book_21 = parse_fb2(
            br##"<FictionBook xmlns:l="http://www.w3.org/1999/xlink"><description><title-info><book-title>Canonical title</book-title><author><nickname>Canonical author</nickname></author></title-info><src-title-info><book-title>Source title must not replace canonical title</book-title><author><nickname>Source author</nickname></author></src-title-info></description><body><section><p><strong>Bold</strong><style name="emphasis">Styled</style></p><table><tr><th colspan="2">Header</th></tr><tr><td rowspan="2">Left</td><td>Right</td></tr></table><image l:href="#figure" title="Figure title" id="figure-anchor"/></section></body><binary id="figure" content-type="image/png">AQID</binary></FictionBook>"##,
            Some("utf-8"),
        )
        .expect("parse FB2 2.1 compatibility fixture");
        let book_20 = parse_fb2(
            br##"<FictionBook xmlns:l="http://www.w3.org/1999/xlink"><description><title-info><book-title>Canonical title</book-title><author><nickname>Canonical author</nickname></author></title-info></description><body><section><p><strong>Bold</strong><style name="emphasis">Styled</style></p><table><tr><td>Header</td></tr><tr><td>Left</td><td>Right</td></tr></table><image l:href="#figure"/></section></body><binary id="figure" content-type="image/png">AQID</binary></FictionBook>"##,
            Some("utf-8"),
        )
        .expect("parse equivalent FB2 2.0 fixture");

        assert_eq!(book_21.title, book_20.title);
        assert_eq!(book_21.authors, book_20.authors);
        let blocks_21 = &book_21.chapters[0].blocks;
        let blocks_20 = &book_20.chapters[0].blocks;
        let expected_rows = vec![
            vec!["Header".to_string()],
            vec!["Left".to_string(), "Right".to_string()],
        ];
        assert_eq!(blocks_21[0].rich_spans, blocks_20[0].rich_spans);
        assert_eq!(blocks_21[1].table_rows, blocks_20[1].table_rows);
        assert_eq!(
            blocks_21[1].table_rows.as_deref(),
            Some(expected_rows.as_slice())
        );
        assert_eq!(blocks_21[2].image_url, blocks_20[2].image_url);
        assert_eq!(blocks_21[2].image_alt.as_deref(), Some("Figure title"));
        assert_eq!(blocks_21[2].note_id.as_deref(), Some("figure-anchor"));
    }

    #[test]
    fn preserves_supported_body_and_section_structure() {
        let book = parse_fb2(
            br##"<FictionBook xmlns:l="http://www.w3.org/1999/xlink"><description/><body><title><p>Body title</p></title><epigraph><p>Body epigraph</p></epigraph><image l:href="#body-art"/><section><title><p>Section title</p></title><epigraph><p>Section epigraph</p></epigraph><annotation><p>Section annotation</p></annotation><image l:href="#section-art"/></section><section><section><section><p>Deep text</p></section></section></section></body><binary id="body-art" content-type="image/png">AQID</binary><binary id="section-art" content-type="image/jpeg">AQID</binary></FictionBook>"##,
            Some("utf-8"),
        )
        .expect("parse supported FB2 body and section structure");

        assert_eq!(book.chapters.len(), 3);
        assert_eq!(
            book.chapters[0]
                .blocks
                .iter()
                .map(|block| (&block.block_type, block.text.as_str()))
                .collect::<Vec<_>>(),
            vec![
                (&BlockType::Heading, "Body title"),
                (&BlockType::Epigraph, "Body epigraph"),
                (&BlockType::Image, ""),
            ],
        );
        assert_eq!(
            book.chapters[1]
                .blocks
                .iter()
                .map(|block| (&block.block_type, block.text.as_str()))
                .collect::<Vec<_>>(),
            vec![
                (&BlockType::Heading, "Section title"),
                (&BlockType::Epigraph, "Section epigraph"),
                (&BlockType::Paragraph, "Section annotation"),
                (&BlockType::Image, ""),
            ],
        );
        assert_eq!(book.chapters[2].blocks[0].text, "Deep text");
        assert_eq!(
            book.chapters[0].blocks[2].image_url.as_deref(),
            Some("data:image/png;base64,AQID")
        );
        assert_eq!(
            book.chapters[1].blocks[3].image_url.as_deref(),
            Some("data:image/jpeg;base64,AQID")
        );
        assert!(book.description.is_none());
    }

    #[test]
    fn rejects_mixed_nested_sections_and_streaming_content() {
        let error = parse_fb2(
            br#"<FictionBook><description/><body><section><section><p>Child</p></section><p>Parent stream</p></section></body></FictionBook>"#,
            Some("utf-8"),
        )
        .expect_err("mixed section content must be rejected");

        assert!(error.to_string().contains("cannot mix nested sections"));
    }

    #[test]
    fn rejects_excessive_section_nesting() {
        let mut xml = String::from("<FictionBook><description/><body>");
        for _ in 0..=MAX_FB2_SECTION_DEPTH {
            xml.push_str("<section>");
        }
        for _ in 0..=MAX_FB2_SECTION_DEPTH {
            xml.push_str("</section>");
        }
        xml.push_str("</body></FictionBook>");

        let error = parse_fb2(xml.as_bytes(), Some("utf-8"))
            .expect_err("excessive nesting must be rejected");
        assert!(error.to_string().contains("maximum depth"));
    }

    #[test]
    fn preserves_fb2_content_boundaries_and_body_language() {
        let book = parse_fb2(
            br#"<FictionBook><description/><body xml:lang="fr"><section xml:lang="de"><title><p>Chapter title</p></title><subtitle>Subtitle</subtitle><empty-line/><cite><p>Quoted paragraph</p><text-author>Quoted author</text-author></cite><poem><stanza><v>First verse</v><v>Second verse</v></stanza></poem><p>Ordinary paragraph</p></section></body></FictionBook>"#,
            Some("utf-8"),
        )
        .expect("parse FB2 content boundaries");

        let blocks = &book.chapters[0].blocks;
        assert_eq!(book.language.as_deref(), Some("fr"));
        assert_eq!(
            blocks
                .iter()
                .map(|block| (&block.block_type, block.text.as_str()))
                .collect::<Vec<_>>(),
            vec![
                (&BlockType::Heading, "Chapter title"),
                (&BlockType::Subtitle, "Subtitle"),
                (&BlockType::Separator, ""),
                (&BlockType::Cite, "Quoted paragraph"),
                (&BlockType::TextAuthor, "Quoted author"),
                (&BlockType::Poem, "First verse"),
                (&BlockType::Poem, "Second verse"),
                (&BlockType::Separator, ""),
                (&BlockType::Paragraph, "Ordinary paragraph"),
            ],
        );
    }

    #[test]
    fn uses_section_xml_language_when_body_does_not_declare_one() {
        let book = parse_fb2(
            br#"<FictionBook><description/><body><section xml:lang="de"><p>In German</p></section></body></FictionBook>"#,
            Some("utf-8"),
        )
        .expect("parse FB2 section language");

        assert_eq!(book.language.as_deref(), Some("de"));
    }

    #[test]
    fn preserves_safe_link_targets_and_drops_unsafe_schemes() {
        let book = parse_fb2(
            br##"<FictionBook xmlns:l="http://www.w3.org/1999/xlink"><description/><body><section><p><a l:href="#note-1">Local</a><a l:href="notes/chapter.fb2#note-2">Relative</a><a l:href="https://example.test/reference">External</a><a l:href="java&#x0A;script:alert(1)">JavaScript</a><a l:href="vbscript:msgbox(1)">VBScript</a><a l:href="data:text/html,unsafe">Data</a></p></section></body></FictionBook>"##,
            Some("utf-8"),
        )
        .expect("parse FB2 link matrix");

        let spans = book.chapters[0].blocks[0]
            .rich_spans
            .as_ref()
            .expect("links create rich spans");
        assert_eq!(
            spans
                .iter()
                .map(|span| (span.text.as_str(), span.href.as_deref()))
                .collect::<Vec<_>>(),
            vec![
                ("Local", Some("#note-1")),
                ("Relative", Some("notes/chapter.fb2#note-2")),
                ("External", Some("https://example.test/reference")),
                ("JavaScript", None),
                ("VBScript", None),
                ("Data", None),
            ],
        );
    }

    #[test]
    fn links_namespaced_footnote_references_to_notes() {
        let book = parse_fb2(
            br##"<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
                <description/><body><section><p>Text<a l:href="#n1" type="note">1</a></p></section></body>
                <body name="notes"><section id="n1"><p>Footnote text</p></section></body>
            </FictionBook>"##,
            Some("utf-8"),
        )
        .expect("parse FB2 with namespaced footnote");

        assert_eq!(book.chapters.len(), 1, "{book:#?}");
        assert_eq!(book.chapters[0].blocks[0].text, "Text1");
        assert_eq!(book.chapters[0].blocks[0].note_ref.as_deref(), Some("n1"));
        assert_eq!(
            book.metadata
                .as_ref()
                .and_then(|metadata| metadata["footnotes"]["n1"].as_str()),
            Some("Footnote text")
        );
    }

    #[test]
    fn preserves_line_breaks_for_poetry_inside_footnotes() {
        let book = parse_fb2(
            br#"<FictionBook><description/><body><section><p>Text</p></section></body>
                <body name="notes"><section id="n1"><poem><stanza>
                <v>First line</v><v>Second line</v></stanza></poem></section></body>
            </FictionBook>"#,
            Some("utf-8"),
        )
        .expect("parse FB2 note with poetry");

        assert_eq!(
            book.metadata
                .as_ref()
                .and_then(|metadata| metadata["footnotes"]["n1"].as_str()),
            Some("First line\nSecond line")
        );
    }

    #[test]
    fn preserves_paragraph_and_nested_section_boundaries_inside_footnotes() {
        let book = parse_fb2(
            br#"<FictionBook><description/><body><section><p>Text</p></section></body>
                <body name="notes"><section id="n1">
                  <p>First paragraph.</p>
                  <section><p>Nested section.</p></section>
                  <p>Last paragraph.</p>
                </section></body>
            </FictionBook>"#,
            Some("utf-8"),
        )
        .expect("parse FB2 note with nested sections");

        assert_eq!(
            book.metadata
                .as_ref()
                .and_then(|metadata| metadata["footnotes"]["n1"].as_str()),
            Some("First paragraph.\nNested section.\nLast paragraph.")
        );
    }

    #[test]
    fn preserves_epigraph_and_stanza_boundaries() {
        let book = parse_fb2(
            br#"<FictionBook><description/><body><section>
                <epigraph>Opening quote</epigraph>
                <poem><stanza><v>First line</v><v>Second line</v></stanza></poem>
            </section></body></FictionBook>"#,
            Some("utf-8"),
        )
        .expect("parse FB2 with epigraph and poem");

        let blocks = &book.chapters[0].blocks;
        assert_eq!(blocks[0].block_type, BlockType::Epigraph);
        assert_eq!(blocks[0].text, "Opening quote");
        assert_eq!(blocks[1].block_type, BlockType::Poem);
        assert_eq!(blocks[1].text, "First line");
        assert_eq!(blocks[2].block_type, BlockType::Poem);
        assert_eq!(blocks[2].text, "Second line");
        assert!(
            blocks
                .iter()
                .any(|block| block.block_type == BlockType::Separator)
        );
    }

    #[test]
    fn preserves_fb2_tables_as_table_blocks() {
        let book = parse_fb2(
            br#"<FictionBook><description/><body><section><table>
                <tr><td><p>Header A</p></td><td><p>Header B</p></td></tr>
                <tr><td><p>Cell A</p></td><td><p>Cell B</p></td></tr>
            </table></section></body></FictionBook>"#,
            Some("utf-8"),
        )
        .expect("parse FB2 table");

        let blocks = &book.chapters[0].blocks;
        assert_eq!(blocks.len(), 1, "{blocks:#?}");
        assert_eq!(blocks[0].block_type, BlockType::Table);
        assert_eq!(
            blocks[0].table_rows.as_ref(),
            Some(&vec![
                vec!["Header A".to_string(), "Header B".to_string()],
                vec!["Cell A".to_string(), "Cell B".to_string()],
            ]),
        );
    }

    #[test]
    fn preserves_complex_table_and_image_blocks_for_reader_layout() {
        let book = parse_fb2(
            br##"<FictionBook xmlns:l="http://www.w3.org/1999/xlink"><description/><body><section>
                <table align="center"><tr><th colspan="2">Header</th></tr><tr><td valign="top"><p>Left cell</p></td><td><p>Right cell</p></td></tr></table>
                <image l:href="#illustration" alt="Illustration"/>
            </section></body><binary id="illustration" content-type="image/webp">UklGRh4AAABXRUJQVlA4TBEAAAAvAUAAEA8Q8x/zH4wRiOh/CAA=</binary></FictionBook>"##,
            Some("utf-8"),
        )
        .expect("parse FB2 table and illustration");

        let blocks = &book.chapters[0].blocks;
        assert_eq!(blocks.len(), 2, "{blocks:#?}");
        assert_eq!(blocks[0].block_type, BlockType::Table);
        assert_eq!(
            blocks[0].table_rows.as_deref(),
            Some(
                &[
                    vec!["Header".to_string()],
                    vec!["Left cell".to_string(), "Right cell".to_string()],
                ][..]
            ),
        );
        assert_eq!(blocks[1].block_type, BlockType::Image);
        assert_eq!(blocks[1].image_alt.as_deref(), Some("Illustration"));
        assert!(
            blocks[1]
                .image_url
                .as_deref()
                .is_some_and(|url| url.starts_with("data:image/webp;base64,")),
        );
    }

    #[test]
    fn preserves_outer_inline_formatting_after_nested_equivalent_tags() {
        let book = parse_fb2(
            br#"<FictionBook><description/><body><section><p><strong>Outer <strong>inner</strong> tail</strong></p></section></body></FictionBook>"#,
            Some("utf-8"),
        )
        .expect("parse FB2 with nested formatting");
        let spans = book.chapters[0].blocks[0]
            .rich_spans
            .as_ref()
            .expect("rich spans");

        assert_eq!(spans[2].text, "tail");
        assert!(spans[2].bold);
    }

    #[test]
    fn preserves_nested_inline_semantics_and_links() {
        let book = parse_fb2(
            br##"<FictionBook xmlns:xlink="http://www.w3.org/1999/xlink"><description/><body><section><p>plain <strong>bold <emphasis>both <a xlink:href="#note">link <strikethrough>strike <sub>sub</sub></strikethrough></a></emphasis></strong> <style name="code"><code>mono</code></style><sup>up</sup></p></section></body></FictionBook>"##,
            Some("utf-8"),
        )
        .expect("parse FB2 with nested inline semantics");
        let spans = book.chapters[0].blocks[0]
            .rich_spans
            .as_ref()
            .expect("rich spans");

        assert_eq!(
            spans
                .iter()
                .map(|span| span.text.as_str())
                .collect::<Vec<_>>(),
            [
                "plain", "bold", "both", "link", "strike", "sub", "mono", "up"
            ],
        );
        assert!(spans[1].bold);
        assert!(spans[2].bold && spans[2].italic);
        assert_eq!(spans[3].href.as_deref(), Some("#note"));
        assert!(spans[4].strikethrough && spans[4].href.is_some());
        assert!(spans[5].subscript && spans[5].strikethrough);
        assert!(
            spans.iter().any(|span| span.text == "mono" && span.code),
            "{spans:#?}"
        );
        assert!(
            spans
                .iter()
                .any(|span| span.text == "mono" && span.style_name.as_deref() == Some("code")),
            "{spans:#?}"
        );
        assert!(spans[7].superscript);
    }

    #[test]
    fn ignores_embedded_stylesheet_without_leaking_css_into_book_content() {
        let book = parse_fb2(
            br#"<FictionBook><stylesheet type="text/css">p { color: red; }</stylesheet><description/><body><section><p>Visible text</p></section></body></FictionBook>"#,
            Some("utf-8"),
        )
        .expect("parse FB2 with an embedded stylesheet");

        let blocks = &book.chapters[0].blocks;
        assert_eq!(blocks.len(), 1, "{blocks:#?}");
        assert_eq!(blocks[0].text, "Visible text");
    }

    #[test]
    fn preserves_block_code_as_preformatted_content() {
        let book = parse_fb2(
            br#"<FictionBook><description/><body><section><code>let answer = 42;</code></section></body></FictionBook>"#,
            Some("utf-8"),
        )
        .expect("parse FB2 with a code block");

        let blocks = &book.chapters[0].blocks;
        assert_eq!(blocks.len(), 1, "{blocks:#?}");
        assert_eq!(blocks[0].block_type, BlockType::Preformatted);
        assert_eq!(blocks[0].text, "let answer = 42;");
    }
}
