use crate::api::models::{
    BlockType, BookFormat, NormalizedBook, ParseWarning, ReaderBlock, ReaderChapter, TocEntry,
};
use crate::book::normalize_whitespace;
use anyhow::Result;
use regex::Regex;
use std::sync::LazyLock;

// ARC-10.2: Lazy-compiled regex patterns (avoid recompilation on every call)
static CHAPTER_HEADING_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"(?i)^(глава|часть|пролог|эпилог|chapter|part|prologue|epilogue|section|§)\s+|^(番外|外传)(?:\s|[：:（(]|$)",
    )
    .unwrap()
});

static SHORT_LINE_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^[\s\d]+$").unwrap());

static CHAPTER_SPLIT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"(?i)^(глава|часть|пролог|эпилог|chapter|part|prologue|epilogue|section|§)\s+[\dIVXLCDM\.]+|^(番外|外传)(?:\s|[：:（(]|$)|^[\dIVXLCDM]+\.\s|^[IVXLCDM]+\.\s|^\d+\.\d+\s|^§\s+\d+",
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
        let is_scene_break = is_scene_break(&paragraph);
        blocks.push(ReaderBlock {
            index: i as i32,
            // A scene break belongs to the surrounding chapter.  Preserve it
            // as the reader's semantic separator instead of an ordinary text
            // paragraph, so it cannot become a synthetic heading or a
            // separately styled section.
            text: if is_scene_break {
                String::new()
            } else {
                paragraph
            },
            block_type: if is_scene_break {
                BlockType::Separator
            } else {
                BlockType::Paragraph
            },
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

fn is_scene_break(text: &str) -> bool {
    let trimmed = text.trim();
    let Some(marker) = trimmed.chars().next() else {
        return false;
    };
    if marker == '*' {
        return trimmed.chars().count() >= 3 && trimmed.chars().all(|c| c == marker);
    }

    // `normalize_whitespace` converts `---` to `—-` before this point.  Both
    // spellings represent an input separator, whereas a single em dash is
    // ordinary prose punctuation.
    trimmed.chars().count() >= 2 && trimmed.chars().all(|c| matches!(c, '-' | '—'))
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
            let paragraph = normalize_txt_whitespace(&current);
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

    let paragraph = normalize_txt_whitespace(&current);
    if !paragraph.is_empty() {
        paragraphs.push(paragraph);
    }
    paragraphs
}

/// TXT has no layout semantics besides whitespace. Preserve tabs as four
/// spaces so imported indents remain readable instead of being collapsed by
/// the shared prose normalizer.
fn normalize_txt_whitespace(text: &str) -> String {
    if !text.contains('\t') {
        return normalize_whitespace(text);
    }

    text.split('\t')
        .map(normalize_whitespace)
        .collect::<Vec<_>>()
        .join("    ")
}

fn decode_text(bytes: &[u8], encoding_name: &str) -> Result<String> {
    if encoding_name.eq_ignore_ascii_case("utf-8") {
        Ok(String::from_utf8_lossy(bytes).into_owned())
    } else {
        let (decoded, _) = encoding_rs::Encoding::for_label(encoding_name.as_bytes())
            .unwrap_or(encoding_rs::UTF_8)
            .decode_without_bom_handling(bytes);
        // Keep the decoder's partial result when the selected legacy encoding
        // contains malformed trailing bytes. Falling back to lossy UTF-8 would
        // turn every preceding non-UTF-8 byte into U+FFFD as well.
        Ok(decoded.into_owned())
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
                page_break_before: false,
                page_break_inside_avoid: false,
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
                page_break_before: false,
                page_break_inside_avoid: false,
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
    use super::{BlockType, parse_txt};
    use encoding_rs::{BIG5, GBK, ISO_2022_JP, KOI8_R, SHIFT_JIS, WINDOWS_1251};

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
    fn auto_detects_cp1251_without_losing_non_utf8_text() {
        let (bytes, _, _) = WINDOWS_1251.encode(
            "Заголовок русской книги\n\nЭто достаточно длинный абзац на русском языке для определения кодировки.",
        );
        let book = parse_txt(&bytes, None).expect("parse CP1251 TXT");

        assert_eq!(book.title, "Заголовок русской книги");
        assert!(
            book.chapters[0].blocks[1]
                .text
                .contains("достаточно длинный абзац")
        );
    }

    #[test]
    fn auto_detects_koi8_r_text() {
        let (bytes, _, _) = KOI8_R.encode(
            "Заголовок книги\n\nДостаточно длинный русский абзац нужен для устойчивого определения KOI8-R.",
        );

        let book = parse_txt(&bytes, None).expect("parse KOI8-R TXT");

        assert_eq!(book.title, "Заголовок книги");
        assert!(
            book.chapters[0].blocks[1]
                .text
                .contains("устойчивого определения")
        );
    }

    #[test]
    fn auto_detects_cjk_legacy_encodings() {
        for (encoding, text) in [
            (
                SHIFT_JIS,
                "日本語の本の題名\n\nこれは文字コードを判定するための十分に長い日本語の文章です。",
            ),
            (
                BIG5,
                "繁體中文書名\n\n這是一段足夠長的繁體中文內容，用來驗證自動編碼偵測。",
            ),
            (
                GBK,
                "简体中文书名\n\n这是一段足够长的简体中文内容，用来验证自动编码检测。",
            ),
        ] {
            let (bytes, _, _) = encoding.encode(text);

            let book = parse_txt(&bytes, None).expect("parse legacy CJK TXT");

            assert_eq!(
                book.chapters[0].blocks[0].text,
                text.split("\n\n").next().unwrap()
            );
            assert_eq!(
                book.chapters[0].blocks[1].text,
                text.split("\n\n").nth(1).unwrap()
            );
        }
    }

    #[test]
    fn decodes_utf16_bom_in_both_byte_orders() {
        for (little_endian, bom) in [(true, [0xff, 0xfe]), (false, [0xfe, 0xff])] {
            let mut bytes = bom.to_vec();
            for unit in "UTF-16 title\n\nBody".encode_utf16() {
                let encoded = if little_endian {
                    unit.to_le_bytes()
                } else {
                    unit.to_be_bytes()
                };
                bytes.extend_from_slice(&encoded);
            }

            let book = parse_txt(&bytes, None).expect("parse UTF-16 BOM TXT");

            assert_eq!(book.title, "UTF-16 title");
            assert_eq!(book.chapters[0].blocks[1].text, "Body");
        }
    }

    #[test]
    fn preserves_iso_2022_jp_prefix_before_incomplete_escape_sequence() {
        let (encoded, _, _) = ISO_2022_JP.encode("日本語の本文");
        let mut bytes = encoded.into_owned();
        // An incomplete escape sequence is a decoder error, but must not cause
        // the valid Japanese text already decoded from this file to be retried
        // as lossy UTF-8.
        bytes.extend_from_slice(b"\x1b$");

        let book = parse_txt(&bytes, Some("iso-2022-jp")).expect("parse ISO-2022-JP TXT");

        assert!(book.chapters[0].blocks[0].text.starts_with("日本語の本文"));
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

    #[test]
    fn expands_tabs_to_a_readable_fixed_width_indent() {
        let book = parse_txt(b"Column\tValue", Some("utf-8")).expect("parse tabbed TXT");

        assert_eq!(book.chapters[0].blocks[0].text, "Column    Value");
    }

    #[test]
    fn adds_chinese_extra_chapters_to_the_toc() {
        let book = parse_txt(
            "小说标题\n\n第一章\n\n正文\n\n番外：后日谈\n\n番外正文\n\n外传 特别篇\n\n外传正文"
                .as_bytes(),
            Some("utf-8"),
        )
        .expect("parse TXT with Chinese chapter prefixes");

        assert_eq!(
            book.toc
                .iter()
                .map(|entry| entry.title.as_str())
                .collect::<Vec<_>>(),
            ["小说标题", "番外：后日谈", "外传 特别篇"],
        );
    }

    #[test]
    fn normalizes_mixed_line_endings_and_null_bytes_in_one_pass() {
        let book = parse_txt(
            b"Mixed title\r\n\r\nFirst\r\nwrapped\nline\r\0\r\nSecond\0paragraph\r\r\nThird",
            Some("utf-8"),
        )
        .expect("parse TXT with mixed separators");

        let blocks = &book.chapters[0].blocks;
        assert_eq!(blocks.len(), 4);
        assert_eq!(blocks[0].text, "Mixed title");
        assert_eq!(blocks[1].text, "First wrapped line");
        assert_eq!(blocks[2].text, "Second paragraph");
        assert_eq!(blocks[3].text, "Third");
        assert!(blocks.iter().all(|block| !block.text.contains('\0')));
    }

    #[test]
    fn keeps_scene_breaks_inside_the_preceding_chapter() {
        let book = parse_txt(
            b"Book title\n\nChapter 1\n\nFirst scene\n\n***\n\nSecond scene\n\n---\n\nThird scene\n\nChapter 2\n\nFinal scene",
            Some("utf-8"),
        )
        .expect("parse TXT with scene breaks");

        assert_eq!(book.chapters.len(), 3);
        let first_chapter = &book.chapters[1];
        assert_eq!(first_chapter.title, "Chapter 1");
        assert_eq!(
            first_chapter
                .blocks
                .iter()
                .filter(|block| block.block_type == BlockType::Separator)
                .count(),
            2
        );
        assert!(first_chapter.blocks.iter().all(|block| block.text != "***"));
        assert!(first_chapter.blocks.iter().all(|block| block.text != "---"));
    }
}
