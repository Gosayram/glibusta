use crate::api::models::{
    BlockType, BookFormat, NormalizedBook, ParseWarning, ReaderBlock, ReaderChapter, TocEntry,
};
use crate::book::normalize_whitespace;
use anyhow::Result;
use regex::Regex;

pub fn parse_txt(bytes: &[u8], forced_encoding: Option<&str>) -> Result<NormalizedBook> {
    let mut warnings = Vec::new();
    let text = if let Some(enc) = forced_encoding {
        decode_text(bytes, enc)?
    } else {
        let encoding = crate::book::encoding::detect_encoding(bytes);
        warnings.push(ParseWarning {
            message: format!("Encoding auto-detected: {}", encoding),
        });
        decode_text(bytes, encoding)?
    };

    let paragraphs: Vec<String> = text
        .split("\n\n")
        .map(normalize_whitespace)
        .filter(|p| !p.is_empty())
        .collect();

    let mut blocks: Vec<ReaderBlock> = Vec::new();
    for (i, paragraph) in paragraphs.into_iter().enumerate() {
        blocks.push(ReaderBlock {
            index: i as i32,
            text: paragraph,
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
        });
    }

    let id = crate::book::sha256_hex(bytes);

    let title = extract_title_from_first_line(&blocks);

    let chapters = split_into_chapters(blocks, &title);
    let toc: Vec<TocEntry> = chapters
        .iter()
        .map(|ch| TocEntry {
            title: ch.title.clone(),
            chapter_index: ch.index,
            children: Vec::new(),
        })
        .collect();

    Ok(NormalizedBook {
        id,
        title,
        authors: Vec::new(),
        description: None,
        cover_url: None,
        chapters,
        metadata: None,
        book_format: BookFormat::Txt,
        language: None,
        warnings,
        images: Vec::new(),
        toc,
    })
}

fn decode_text(bytes: &[u8], encoding_name: &str) -> Result<String> {
    if encoding_name.eq_ignore_ascii_case("utf-8") {
        Ok(String::from_utf8_lossy(bytes).into_owned())
    } else {
        let (decoded, _, had_errors) = encoding_rs::Encoding::for_label(encoding_name.as_bytes())
            .unwrap_or(encoding_rs::UTF_8)
            .decode(bytes);
        if had_errors {
            Ok(String::from_utf8_lossy(bytes).into_owned())
        } else {
            Ok(decoded.into_owned())
        }
    }
}

fn extract_title_from_first_line(blocks: &[ReaderBlock]) -> String {
    let chapter_re =
        Regex::new(r"(?i)^(глава|часть|пролог|эпилог|chapter|part|prologue|epilogue|section|§)\s+")
            .unwrap();
    let short_re = Regex::new(r"^[\s\d]+$").unwrap();
    // Skip very short lines, lines that look like chapter headings, or common non-title intros
    for block in blocks {
        let text = block.text.trim();
        if text.len() < 3 {
            continue;
        }
        if chapter_re.is_match(text) {
            continue;
        }
        if short_re.is_match(text) {
            continue;
        }
        // Skip if it's a single word of 5 or fewer chars (likely metadata)
        if text.len() <= 5 && !text.contains(' ') {
            continue;
        }
        return text.to_string();
    }
    blocks.first().map(|b| b.text.clone()).unwrap_or_default()
}

fn is_chapter_heading(text: &str, re: &Regex) -> bool {
    re.is_match(text)
}

fn split_into_chapters(blocks: Vec<ReaderBlock>, book_title: &str) -> Vec<ReaderChapter> {
    if blocks.is_empty() {
        return vec![];
    }

    let re = Regex::new(
        r"(?i)^(глава|часть|пролог|эпилог|chapter|part|prologue|epilogue|section|§)\s+[\dIVXLCDM\.]+|^[\dIVXLCDM]+\.\s|^[IVXLCDM]+\.\s|^\d+\.\d+\s|^§\s+\d+",
    )
    .unwrap();

    let mut chapter_indices: Vec<usize> = Vec::new();
    for (i, block) in blocks.iter().enumerate() {
        if is_chapter_heading(&block.text, &re) {
            chapter_indices.push(i);
        }
    }

    if chapter_indices.is_empty() {
        return vec![ReaderChapter {
            index: 0,
            title: book_title.to_string(),
            blocks,
        }];
    }

    let mut chapters: Vec<ReaderChapter> = Vec::new();

    if chapter_indices[0] > 0 {
        let preamble_blocks: Vec<ReaderBlock> = blocks[0..chapter_indices[0]]
            .iter()
            .enumerate()
            .map(|(i, b)| ReaderBlock {
                index: i as i32,
                text: b.text.clone(),
                block_type: b.block_type.clone(),
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
        if !preamble_blocks.is_empty() {
            chapters.push(ReaderChapter {
                index: 0,
                title: book_title.to_string(),
                blocks: preamble_blocks,
            });
        }
    }

    for (ci, &ch_idx) in chapter_indices.iter().enumerate() {
        let end = if ci + 1 < chapter_indices.len() {
            chapter_indices[ci + 1]
        } else {
            blocks.len()
        };

        let chapter_blocks: Vec<ReaderBlock> = blocks[ch_idx..end]
            .iter()
            .enumerate()
            .map(|(i, b)| ReaderBlock {
                index: i as i32,
                text: b.text.clone(),
                block_type: b.block_type.clone(),
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

        let title = chapter_blocks
            .first()
            .map(|b| b.text.clone())
            .unwrap_or_else(|| format!("Глава {}", chapters.len() + 1));

        chapters.push(ReaderChapter {
            index: chapters.len() as i32,
            title,
            blocks: chapter_blocks,
        });
    }

    // Re-index chapters
    for (i, ch) in chapters.iter_mut().enumerate() {
        ch.index = i as i32;
    }

    chapters
}
