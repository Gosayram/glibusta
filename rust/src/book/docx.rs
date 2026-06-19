use crate::api::models::{BlockType, NormalizedBook, ReaderBlock, ReaderChapter, RichSpan};
use crate::book::archive::{self, ZipFile};
use anyhow::{Context, Result};
use quick_xml::events::Event;
use quick_xml::Reader;
use std::io::BufRead;

pub fn parse_docx(bytes: &[u8], forced_encoding: Option<&str>) -> Result<NormalizedBook> {
    let zip = archive::decode_zip(bytes).context("Failed to open DOCX archive")?;
    let encoding_name = forced_encoding.unwrap_or("utf-8");

    let (title, authors, created_date) = parse_core_properties(&zip, encoding_name)?;

    let document_xml = zip
        .find_file("word/document.xml")
        .context("DOCX missing word/document.xml")?;
    let doc_text = decode_bytes(document_xml, encoding_name);

    let (blocks, chapter_title) = parse_document_xml(&doc_text);

    let id = {
        use sha2::{Digest, Sha256};
        let mut hasher = Sha256::new();
        hasher.update(bytes);
        format!("{:x}", hasher.finalize())
    };

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

    Ok(NormalizedBook {
        id,
        title: final_title,
        authors,
        description: None,
        cover_url: None,
        chapters,
        metadata: Some(metadata),
    })
}

fn decode_bytes(bytes: &[u8], encoding_name: &str) -> String {
    if encoding_name.eq_ignore_ascii_case("utf-8") {
        String::from_utf8_lossy(bytes).into_owned()
    } else {
        let (decoded, _, _) = encoding_rs::Encoding::for_label(encoding_name.as_bytes())
            .unwrap_or(encoding_rs::UTF_8)
            .decode(bytes);
        decoded.into_owned()
    }
}

fn parse_core_properties(
    zip: &ZipFile,
    encoding_name: &str,
) -> Result<(String, Vec<String>, String)> {
    let props_bytes = zip
        .find_file("docProps/core.xml")
        .context("DOCX missing docProps/core.xml")?;
    let props_text = decode_bytes(props_bytes, encoding_name);

    let mut reader = Reader::from_str(&props_text);
    reader.config_mut().trim_text(true);
    let mut buf = Vec::new();

    let mut title = String::new();
    let mut authors: Vec<String> = Vec::new();
    let mut created = String::new();

    let mut in_title = false;
    let mut in_creator = false;
    let mut in_created = false;
    let mut current_text = String::new();

    loop {
        buf.clear();
        match reader.read_event_into(&mut buf) {
            Ok(Event::Eof) => break,
            Ok(Event::Start(ref e)) => {
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                match tag.as_str() {
                    "dc:title" => {
                        in_title = true;
                        current_text.clear();
                    }
                    "dc:creator" => {
                        in_creator = true;
                        current_text.clear();
                    }
                    "dcterms:created" => {
                        in_created = true;
                        current_text.clear();
                    }
                    _ => {}
                }
            }
            Ok(Event::Text(ref e)) => {
                let text = e.unescape().unwrap_or_default().to_string();
                current_text.push_str(&text);
            }
            Ok(Event::End(ref e)) => {
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                match tag.as_str() {
                    "dc:title" => {
                        if in_title {
                            title = current_text.trim().to_string();
                            in_title = false;
                            current_text.clear();
                        }
                    }
                    "dc:creator" => {
                        if in_creator {
                            let name = current_text.trim().to_string();
                            if !name.is_empty() {
                                authors.push(name);
                            }
                            in_creator = false;
                            current_text.clear();
                        }
                    }
                    "dcterms:created" => {
                        if in_created {
                            created = current_text.trim().to_string();
                            in_created = false;
                            current_text.clear();
                        }
                    }
                    _ => {}
                }
            }
            Err(_) => break,
            _ => {}
        }
    }

    Ok((title, authors, created))
}

fn parse_document_xml(text: &str) -> (Vec<ReaderBlock>, String) {
    let mut reader = Reader::from_str(text);
    reader.config_mut().trim_text(true);
    let mut buf = Vec::new();

    let mut blocks: Vec<ReaderBlock> = Vec::new();
    let mut block_index = 0i32;
    let mut chapter_title = String::new();

    let mut in_body = false;
    let mut in_paragraph = false;
    let mut in_run = false;
    let mut in_bold = false;
    let mut in_italic = false;
    let mut in_pstyle = false;
    let mut pstyle_val = String::new();

    let mut current_text = String::new();
    let mut rich_spans: Vec<RichSpan> = Vec::new();
    let mut current_span_text = String::new();
    let mut current_span_bold = false;
    let mut current_span_italic = false;

    loop {
        buf.clear();
        match reader.read_event_into(&mut buf) {
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
                                pstyle_val =
                                    String::from_utf8_lossy(&attr.value).into_owned();
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
                        in_bold = true;
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
                        in_italic = true;
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
                let text = e.unescape().unwrap_or_default().to_string();
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
                    "w:b" => in_bold = false,
                    "w:i" => in_italic = false,
                    "w:r" if in_paragraph => {
                        if !current_span_text.is_empty() {
                            rich_spans.push(RichSpan {
                                text: current_span_text.clone(),
                                bold: current_span_bold,
                                italic: current_span_italic,
                                superscript: false,
                                href: None,
                            });
                        }
                        current_span_text.clear();
                        in_run = false;
                    }
                    "w:p" if in_paragraph => {
                        // Combine all span texts for the block text field
                        let full_text: String = rich_spans.iter().map(|s| s.text.as_str()).collect();
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
