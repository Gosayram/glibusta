use crate::api::models::{
    BlockType, BookFormat, NormalizedBook, ParseWarning, ReaderBlock, ReaderChapter, TocEntry,
};
use crate::book::normalize_whitespace;
use anyhow::Result;
use regex::Regex;
use std::sync::LazyLock;

// ARC-10.2: Lazy-compiled regex patterns (avoid recompilation on every call)
static CHAPTER_HEADING_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)^(глава|часть|пролог|эпилог|chapter|part|prologue|epilogue|section|§)\s+")
        .unwrap()
});

static SHORT_LINE_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^[\s\d]+$").unwrap());

static CHAPTER_SPLIT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"(?i)^(глава|часть|пролог|эпилог|chapter|part|prologue|epilogue|section|§)\s+[\dIVXLCDM\.]+|^[\dIVXLCDM]+\.\s|^[IVXLCDM]+\.\s|^\d+\.\d+\s|^§\s+\d+",
    )
    .unwrap()
});

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

    // `decode_without_bom_handling` intentionally preserves a BOM. It is an
    // encoding marker, not book content, so never expose it in the title or
    // first reader block.
    let text = text.strip_prefix('\u{feff}').unwrap_or(&text);
    let paragraphs = split_paragraphs(text);

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

fn split_paragraphs(text: &str) -> Vec<String> {
    let mut paragraphs = Vec::new();
    let mut current = String::new();

    // NUL is not reader content. Treat it as whitespace so an embedded byte
    // cannot join words, while a NUL-only line remains a paragraph separator.
    let normalized = text
        .replace('\0', " ")
        .replace("\r\n", "\n")
        .replace('\r', "\n");
    for line in normalized.split('\n') {
        if line.trim().is_empty() {
            let paragraph = normalize_whitespace(&current);
            if !paragraph.is_empty() {
                paragraphs.push(paragraph);
            }
            current.clear();
        } else {
            if !current.is_empty() {
                current.push('\n');
            }
            current.push_str(line);
        }
    }

    let paragraph = normalize_whitespace(&current);
    if !paragraph.is_empty() {
        paragraphs.push(paragraph);
    }
    paragraphs
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
    // ARC-10.2: use lazy-compiled regex statics
    for block in blocks {
        let text = block.text.trim();
        if text.len() < 3 {
            continue;
        }
        if CHAPTER_HEADING_RE.is_match(text) {
            return text.to_string();
        }
        if SHORT_LINE_RE.is_match(text) {
            continue;
        }
        // Skip if it's a single word of 5 or fewer chars (likely metadata)
        if text.len() <= 5 && !text.contains(' ') {
            continue;
        }
        return text.to_string();
    }
    blocks
        .first()
        .map(|block| block.text.clone())
        .unwrap_or_default()
}

fn is_chapter_heading(text: &str, re: &Regex) -> bool {
    re.is_match(text)
}

fn split_into_chapters(blocks: Vec<ReaderBlock>, book_title: &str) -> Vec<ReaderChapter> {
    if blocks.is_empty() {
        return vec![];
    }

    // ARC-10.2: use lazy-compiled regex
    let re = &*CHAPTER_SPLIT_RE;

    let mut chapter_indices: Vec<usize> = Vec::new();
    for (i, block) in blocks.iter().enumerate() {
        if is_chapter_heading(&block.text, re) {
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

#[cfg(test)]
mod tests {
    use super::parse_txt;

    #[test]
    fn detects_chapters_separated_by_windows_line_endings() {
        let book = parse_txt(
            b"A Windows Book\r\n\r\nChapter 1\r\n\r\nThe first chapter.",
            Some("utf-8"),
        )
        .expect("parse TXT");

        assert_eq!(book.chapters.len(), 2);
        assert_eq!(book.chapters[1].title, "Chapter 1");
    }

    #[test]
    fn detects_chapters_separated_by_classic_mac_line_endings() {
        let book = parse_txt(
            b"A Mac Book\r\rChapter 1\r\rThe first chapter.",
            Some("utf-8"),
        )
        .expect("parse TXT");

        assert_eq!(book.chapters.len(), 2);
        assert_eq!(book.chapters[1].title, "Chapter 1");
    }

    #[test]
    fn strips_utf8_bom_from_the_first_paragraph() {
        let book = parse_txt(b"\xEF\xBB\xBFBOM title\n\nBody", None).expect("parse BOM TXT");

        assert_eq!(book.title, "BOM title");
        assert!(!book.chapters[0].blocks[0].text.starts_with('\u{feff}'));
    }

    #[test]
    fn auto_detects_cp866_text() {
        let book = parse_txt(b"\x8f\xe0\xa8\xa2\xa5\xe2", None).expect("parse CP866 TXT");

        assert_eq!(book.chapters[0].blocks[0].text, "Привет");
    }

    #[test]
    fn preserves_utf8_western_diacritics() {
        let book = parse_txt("äöå café Görünen".as_bytes(), None).expect("parse UTF-8 TXT");

        assert_eq!(book.chapters[0].blocks[0].text, "äöå café Görünen");
    }

    #[test]
    fn uses_the_initial_chapter_heading_when_no_separate_title_exists() {
        let book = parse_txt(b"Chapter 1\n\nThe first chapter text.", Some("utf-8"))
            .expect("parse TXT chapter");

        assert_eq!(book.title, "Chapter 1");
    }

    #[test]
    fn normalizes_null_bytes_without_creating_spurious_paragraphs() {
        let book = parse_txt(
            b"Null\0separated text\r\n\r\n\0\r\n\r\nSecond paragraph",
            Some("utf-8"),
        )
        .expect("parse TXT with null bytes");

        let blocks = &book.chapters[0].blocks;
        assert_eq!(blocks.len(), 2);
        assert_eq!(blocks[0].text, "Null separated text");
        assert_eq!(blocks[1].text, "Second paragraph");
        assert!(blocks.iter().all(|block| !block.text.contains('\0')));
    }
}
