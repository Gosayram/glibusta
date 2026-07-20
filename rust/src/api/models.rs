use serde::{Deserialize, Serialize};
use std::fmt;

/// Increment when NormalizedBook fields change. Flutter compares this to invalidate cache.
pub const NORMALIZED_BOOK_SCHEMA_VERSION: u32 = 1;

/// Safety limits for parsing.
pub const MAX_FILE_SIZE: u64 = 500 * 1024 * 1024; // 500 MB
pub const MAX_CHAPTER_SIZE: usize = 10 * 1024 * 1024; // 10 MB
pub const MAX_IMAGE_SIZE: usize = 50 * 1024 * 1024; // 50 MB
pub const MAX_EXTRACTED_FILES: usize = 5000; // max files in a ZIP archive
/// Zip bomb threshold: ratio of uncompressed/compressed size
pub const MAX_COMPRESSION_RATIO: u64 = 100;

/// Capabilities that each format supports.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FormatCapabilities {
    pub metadata: bool,
    pub cover: bool,
    pub toc: bool,
    pub text: bool,
    pub images: bool,
    pub css: bool,
    pub footnotes: bool,
}

impl BookFormat {
    pub fn capabilities(&self) -> FormatCapabilities {
        match self {
            BookFormat::Fb2 => FormatCapabilities {
                metadata: true,
                cover: true,
                toc: true,
                text: true,
                images: true,
                css: false,
                footnotes: true,
            },
            BookFormat::Epub => FormatCapabilities {
                metadata: true,
                cover: true,
                toc: true,
                text: true,
                images: true,
                css: true,
                footnotes: true,
            },
            BookFormat::Txt => FormatCapabilities {
                metadata: false,
                cover: false,
                toc: true,
                text: true,
                images: false,
                css: false,
                footnotes: false,
            },
            BookFormat::Docx => FormatCapabilities {
                metadata: true,
                cover: false,
                toc: false,
                text: true,
                images: true,
                css: false,
                footnotes: true,
            },
            BookFormat::Rtf => FormatCapabilities {
                metadata: false,
                cover: false,
                toc: false,
                text: true,
                images: false,
                css: false,
                footnotes: false,
            },
            BookFormat::Mobi | BookFormat::Azw3 | BookFormat::Prc => FormatCapabilities {
                metadata: true,
                cover: true,
                toc: true,
                text: true,
                images: false,
                css: false,
                footnotes: false,
            },
            BookFormat::Pdf => FormatCapabilities {
                metadata: false,
                cover: true,
                toc: false,
                text: false,
                images: true,
                css: false,
                footnotes: false,
            },
            BookFormat::Djvu => FormatCapabilities {
                metadata: false,
                cover: false,
                toc: false,
                text: false,
                images: true,
                css: false,
                footnotes: false,
            },
            BookFormat::Cbr => FormatCapabilities {
                metadata: false,
                cover: false,
                toc: false,
                text: false,
                images: true,
                css: false,
                footnotes: false,
            },
            BookFormat::Unknown => FormatCapabilities {
                metadata: false,
                cover: false,
                toc: false,
                text: false,
                images: false,
                css: false,
                footnotes: false,
            },
        }
    }
}

#[cfg(test)]
mod format_capability_tests {
    use super::BookFormat;

    #[test]
    fn docx_advertises_its_footnote_support() {
        assert!(BookFormat::Docx.capabilities().footnotes);
        assert!(!BookFormat::Txt.capabilities().footnotes);
    }
}

/// Book format detected by extension or content sniffing.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum BookFormat {
    Fb2,
    Epub,
    Txt,
    Docx,
    Rtf,
    Mobi,
    Azw3,
    Prc,
    Pdf,
    Djvu,
    Cbr,
    Unknown,
}

impl BookFormat {
    pub fn as_str(&self) -> &'static str {
        match self {
            BookFormat::Fb2 => "fb2",
            BookFormat::Epub => "epub",
            BookFormat::Txt => "txt",
            BookFormat::Docx => "docx",
            BookFormat::Rtf => "rtf",
            BookFormat::Mobi => "mobi",
            BookFormat::Azw3 => "azw3",
            BookFormat::Prc => "prc",
            BookFormat::Pdf => "pdf",
            BookFormat::Djvu => "djvu",
            BookFormat::Cbr => "cbr",
            BookFormat::Unknown => "unknown",
        }
    }

    pub fn from_ext(ext: &str) -> Self {
        match ext.to_lowercase().as_str() {
            "fb2" | "fb2.zip" | "zip" => BookFormat::Fb2,
            "epub" => BookFormat::Epub,
            "txt" => BookFormat::Txt,
            "docx" | "docm" => BookFormat::Docx,
            "rtf" => BookFormat::Rtf,
            "mobi" => BookFormat::Mobi,
            "azw3" | "azw" => BookFormat::Azw3,
            "prc" => BookFormat::Prc,
            "pdf" => BookFormat::Pdf,
            "djvu" | "djv" => BookFormat::Djvu,
            "cbr" => BookFormat::Cbr,
            _ => BookFormat::Unknown,
        }
    }

    pub fn extensions() -> &'static [&'static str] {
        &[
            "fb2", "fb2.zip", "epub", "txt", "docx", "docm", "rtf", "mobi", "azw3", "azw", "prc",
            "pdf", "djvu", "djv", "cbr",
        ]
    }
}

impl fmt::Display for BookFormat {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

/// СoreError — единый тип ошибок для glibusta_core.
#[derive(Debug)]
pub enum CoreError {
    UnsupportedFormat(String),
    InvalidArchive(String),
    EncodingFailed(String),
    ParserFailed(String),
    BookEmpty(String),
    CoverNotFound,
    IoError(String),
    FeatureDisabled(String),
}

impl fmt::Display for CoreError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CoreError::UnsupportedFormat(msg) => write!(f, "Unsupported format: {}", msg),
            CoreError::InvalidArchive(msg) => write!(f, "Invalid archive: {}", msg),
            CoreError::EncodingFailed(msg) => write!(f, "Encoding detection failed: {}", msg),
            CoreError::ParserFailed(msg) => write!(f, "Parser error: {}", msg),
            CoreError::BookEmpty(msg) => write!(f, "Book is empty: {}", msg),
            CoreError::CoverNotFound => write!(f, "Cover not found"),
            CoreError::IoError(msg) => write!(f, "IO error: {}", msg),
            CoreError::FeatureDisabled(msg) => write!(f, "Feature disabled: {}", msg),
        }
    }
}

impl std::error::Error for CoreError {}

impl From<std::io::Error> for CoreError {
    fn from(e: std::io::Error) -> Self {
        CoreError::IoError(e.to_string())
    }
}

/// TOC entry for navigation.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TocEntry {
    pub title: String,
    /// Chapter index (0-based) or -1 for non-chapter entries.
    pub chapter_index: i32,
    /// Nested sub-entries.
    #[serde(default)]
    pub children: Vec<TocEntry>,
}

/// An embedded image extracted from the book.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EmbeddedImage {
    /// Identifier (filename or URL reference).
    pub id: String,
    /// MIME type (e.g. "image/jpeg").
    pub media_type: String,
    /// Raw image bytes.
    pub data: Vec<u8>,
}

/// Non-fatal warning from parsing.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ParseWarning {
    pub message: String,
}

/// Lightweight book metadata — no chapters, no blocks.
/// Used by extract_metadata() for fast scanning.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BookMeta {
    pub title: String,
    pub authors: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub language: Option<String>,
    #[serde(default)]
    pub genres: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cover_data: Option<Vec<u8>>,
    #[serde(default)]
    pub toc: Vec<TocEntry>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum BlockType {
    Paragraph,
    Heading,
    Image,
    Quote,
    Footnote,
    Separator,
    Table,
    List,
    Epigraph,
    Poem,
    Cite,
    TextAuthor,
    Subtitle,
    ListItem,
    Preformatted,
}

impl BlockType {
    pub fn as_str(&self) -> &'static str {
        match self {
            BlockType::Paragraph => "paragraph",
            BlockType::Heading => "heading",
            BlockType::Image => "image",
            BlockType::Quote => "quote",
            BlockType::Footnote => "footnote",
            BlockType::Separator => "separator",
            BlockType::Table => "table",
            BlockType::List => "list",
            BlockType::Epigraph => "epigraph",
            BlockType::Poem => "poem",
            BlockType::Cite => "cite",
            BlockType::TextAuthor => "textAuthor",
            BlockType::Subtitle => "subtitle",
            BlockType::ListItem => "listItem",
            BlockType::Preformatted => "preformatted",
        }
    }

    #[allow(clippy::should_implement_trait)]
    pub fn from_str(s: &str) -> Self {
        match s {
            "heading" => BlockType::Heading,
            "image" => BlockType::Image,
            "quote" => BlockType::Quote,
            "footnote" => BlockType::Footnote,
            "separator" => BlockType::Separator,
            "table" => BlockType::Table,
            "list" => BlockType::List,
            "epigraph" => BlockType::Epigraph,
            "poem" => BlockType::Poem,
            "cite" => BlockType::Cite,
            "textAuthor" => BlockType::TextAuthor,
            "subtitle" => BlockType::Subtitle,
            "listItem" => BlockType::ListItem,
            "preformatted" => BlockType::Preformatted,
            _ => BlockType::Paragraph,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RichSpan {
    pub text: String,
    pub bold: bool,
    pub italic: bool,
    pub superscript: bool,
    #[serde(default)]
    pub subscript: bool,
    #[serde(default)]
    pub strikethrough: bool,
    #[serde(default)]
    pub code: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub style_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub href: Option<String>,
    #[serde(default)]
    pub line_break: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ReaderBlock {
    pub index: i32,
    pub text: String,
    #[serde(rename = "type")]
    pub block_type: BlockType,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub image_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub note_ref: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub rich_spans: Option<Vec<RichSpan>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub heading_level: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ordered: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub list_items: Option<Vec<ReaderBlock>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub table_rows: Option<Vec<Vec<String>>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub image_alt: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub text_indent: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub text_align: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub note_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReaderChapter {
    pub index: i32,
    pub title: String,
    pub blocks: Vec<ReaderBlock>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NormalizedBook {
    pub id: String,
    pub title: String,
    pub authors: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cover_url: Option<String>,
    #[serde(default)]
    pub chapters: Vec<ReaderChapter>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub metadata: Option<serde_json::Value>,
    /// New fields
    pub book_format: BookFormat,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub language: Option<String>,
    #[serde(default)]
    pub warnings: Vec<ParseWarning>,
    #[serde(default)]
    pub images: Vec<EmbeddedImage>,
    #[serde(default)]
    pub toc: Vec<TocEntry>,
}

impl NormalizedBook {
    pub fn to_json_string(&self) -> anyhow::Result<String> {
        Ok(serde_json::to_string(self)?)
    }

    pub fn from_json_str(json: &str) -> anyhow::Result<Self> {
        Ok(serde_json::from_str(json)?)
    }

    /// Compute content_hash per chapter for stable anchors during reparse.
    pub fn chapter_hashes(&self) -> Vec<(i32, String)> {
        self.chapters
            .iter()
            .map(|ch| {
                let mut content = Vec::new();
                append_hash_part(&mut content, &ch.title);
                for b in &ch.blocks {
                    append_hash_part(&mut content, &b.text);
                }
                (ch.index, stable_short_hash(&content))
            })
            .collect()
    }

    /// RCE-15.2: Stable chapter ID from title + content.
    pub fn chapter_id(&self, chapter_index: usize) -> String {
        if let Some(ch) = self.chapters.get(chapter_index) {
            let mut content = Vec::new();
            append_hash_part(&mut content, &self.title);
            append_hash_part(&mut content, &ch.title);
            content.extend_from_slice(&(ch.blocks.len() as u64).to_le_bytes());
            for block in &ch.blocks {
                append_hash_part(&mut content, &block.text);
            }
            format!("ch_{}", stable_short_hash(&content))
        } else {
            format!("ch_missing_{}", chapter_index)
        }
    }

    /// RCE-15.3: Stable block ID from chapter + block content.
    pub fn block_id(&self, chapter_index: usize, block_index: usize) -> String {
        if let Some(ch) = self.chapters.get(chapter_index) {
            if let Some(b) = ch.blocks.get(block_index) {
                let mut content = Vec::new();
                append_hash_part(&mut content, &self.title);
                append_hash_part(&mut content, &ch.title);
                append_hash_part(&mut content, &b.text);
                format!("blk_{}", stable_short_hash(&content))
            } else {
                format!("blk_missing_{}_{}", chapter_index, block_index)
            }
        } else {
            format!("blk_missing_{}_{}", chapter_index, block_index)
        }
    }

    /// RCE-15.4: Stable asset ID from image URL.
    pub fn asset_id(url: &str) -> String {
        format!("asset_{}", stable_short_hash(url.as_bytes()))
    }

    /// RCE-15.6: Stable annotation anchor from chapter + block + char offset.
    pub fn annotation_anchor_id(
        chapter_index: usize,
        block_index: usize,
        char_offset: usize,
    ) -> String {
        format!("ann_{}_{}_{}", chapter_index, block_index, char_offset)
    }

    /// RCE-17.1 + RCE-17.2: Migrate an old reading position to new book state
    /// with fuzzy title matching when exact hash fails.
    pub fn migrate_chapter_index(
        old_chapter_id: &str,
        old_book: &NormalizedBook,
        new_book: &NormalizedBook,
    ) -> i32 {
        let old_hashes = old_book.chapter_hashes();
        let new_hashes = new_book.chapter_hashes();
        let old_position = old_hashes
            .iter()
            .position(|(_, hash)| hash == old_chapter_id)
            .or_else(|| {
                old_book
                    .chapters
                    .iter()
                    .enumerate()
                    .find_map(|(position, _)| {
                        (old_book.chapter_id(position) == old_chapter_id).then_some(position)
                    })
            });
        let Some(old_position) = old_position else {
            return 0;
        };

        let old_hash = &old_hashes[old_position].1;
        if let Some((position, _)) = new_hashes
            .iter()
            .enumerate()
            .find(|(_, (_, hash))| hash == old_hash)
        {
            return new_book.chapters[position].index;
        }

        let old_stable_id = old_book.chapter_id(old_position);
        if let Some((position, _)) = new_book
            .chapters
            .iter()
            .enumerate()
            .find(|(position, _)| new_book.chapter_id(*position) == old_stable_id)
        {
            return new_book.chapters[position].index;
        }

        // Fuzzy: match by title similarity when text changed during reparse.
        let old_ch = &old_book.chapters[old_position];
        for new_ch in &new_book.chapters {
            if levenshtein_ratio(&old_ch.title, &new_ch.title) > 0.6 {
                return new_ch.index;
            }
        }
        0
    }
}

fn append_hash_part(output: &mut Vec<u8>, value: &str) {
    output.extend_from_slice(&(value.len() as u64).to_le_bytes());
    output.extend_from_slice(value.as_bytes());
}

fn stable_short_hash(bytes: &[u8]) -> String {
    crate::book::sha256_hex(bytes)[..16].to_string()
}

/// Simple Levenshtein distance for small strings.
fn levenshtein_distance(a: &str, b: &str) -> usize {
    let a: Vec<char> = a.chars().collect();
    let b: Vec<char> = b.chars().collect();
    let (a_len, b_len) = (a.len(), b.len());
    let mut dp = vec![vec![0usize; b_len + 1]; a_len + 1];
    for (i, row) in dp.iter_mut().enumerate() {
        row[0] = i;
    }
    for (j, val) in dp[0].iter_mut().enumerate() {
        *val = j;
    }
    for i in 1..=a_len {
        for j in 1..=b_len {
            let cost = if a[i - 1] == b[j - 1] { 0 } else { 1 };
            dp[i][j] = (dp[i - 1][j] + 1)
                .min(dp[i][j - 1] + 1)
                .min(dp[i - 1][j - 1] + cost);
        }
    }
    dp[a_len][b_len]
}

/// Levenshtein similarity ratio (0.0 .. 1.0).
fn levenshtein_ratio(a: &str, b: &str) -> f64 {
    if a == b {
        return 1.0;
    }
    let max_len = a.len().max(b.len());
    if max_len == 0 {
        return 1.0;
    }
    1.0 - (levenshtein_distance(a, b) as f64 / max_len as f64)
}

// ---------------------------------------------------------------------------
// RCE-4.1: Cache manifest for rapid cache hit/miss
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BookCacheManifest {
    pub file_hash: String,
    pub file_size: u64,
    pub modified_at: u64,
    pub schema_version: u32,
    pub parser_version: String,
    pub format: BookFormat,
    #[serde(default)]
    pub warnings: Vec<ParseWarning>,
}

// ---------------------------------------------------------------------------
// RCE-5.2: Search match result
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchMatch {
    pub chapter_index: i32,
    pub block_index: i32,
    pub span_start: usize,
    pub span_end: usize,
    pub preview: String,
}

// ---------------------------------------------------------------------------
// RCE-20: Text normalization modes
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TextNormalizationMode {
    /// Keep original formatting as-is
    PreserveOriginal,
    /// Normalize whitespace + typography (default)
    ReaderFriendly,
    /// Aggressively clean: remove page numbers, headers, OCR artifacts
    AggressiveCleanup,
}

// ---------------------------------------------------------------------------
// RCE-18.2: Chapter language detection result
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChapterLanguage {
    pub lang: String,
    pub confidence: f64,
}

// ---------------------------------------------------------------------------
// RCE-22: Import report
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportReport {
    pub format: BookFormat,
    pub parser_used: String,
    pub chapters_count: usize,
    pub blocks_count: usize,
    pub images_count: usize,
    pub footnotes_count: usize,
    pub warnings: Vec<ParseWarning>,
    pub parse_time_ms: u64,
    pub file_hash: String,
}

// ---------------------------------------------------------------------------
// RCE-21: Reading order validator
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BookValidationResult {
    pub valid: bool,
    pub empty_chapters: Vec<i32>,
    pub duplicate_chapters: Vec<i32>,
    pub spine_toc_mismatch: bool,
}

// ---------------------------------------------------------------------------
// RCE-10: Asset metadata
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BookAssetMeta {
    pub asset_id: String,
    pub media_type: String,
    pub size: usize,
}

// ---------------------------------------------------------------------------
// RCE-27: Parser events (structured logging)
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ParserEvent {
    ParserStarted {
        format: String,
    },
    EncodingDetected {
        encoding: String,
    },
    CoverExtracted {
        found: bool,
    },
    ChapterParsed {
        index: i32,
        blocks: usize,
    },
    WarningAdded {
        message: String,
    },
    ParserFinished {
        total_chapters: usize,
        total_blocks: usize,
        elapsed_ms: u64,
    },
}

// ---------------------------------------------------------------------------
// RCE-9.3: Footnote model
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Footnote {
    pub id: String,
    pub number: usize,
    pub content_blocks: Vec<ReaderBlock>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub back_ref: Option<String>,
}

// ---------------------------------------------------------------------------
// RCE-16: Book diff after reparse
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BookDiff {
    pub chapters_changed: bool,
    pub text_changed: bool,
    pub metadata_only: bool,
    pub needs_anchor_migration: bool,
}

impl BookDiff {
    pub fn compute(old: &NormalizedBook, new: &NormalizedBook) -> Self {
        let structure_changed = old.chapters.len() != new.chapters.len()
            || old.chapters.iter().zip(new.chapters.iter()).any(|(a, b)| {
                a.index != b.index
                    || a.blocks.len() != b.blocks.len()
                    || a.blocks
                        .iter()
                        .zip(b.blocks.iter())
                        .any(|(x, y)| x.index != y.index || x.block_type != y.block_type)
            });
        let text_changed = text_fragments(old) != text_fragments(new);
        let block_content_changed = old
            .chapters
            .iter()
            .zip(new.chapters.iter())
            .any(|(a, b)| a.blocks.iter().zip(b.blocks.iter()).any(|(x, y)| x != y));
        let chapters_changed = structure_changed || text_changed || block_content_changed;
        let metadata_changed = old.title != new.title
            || old.authors != new.authors
            || old.description != new.description
            || old.cover_url != new.cover_url
            || old.metadata != new.metadata
            || old.book_format != new.book_format
            || old.language != new.language
            || old.warnings != new.warnings
            || old.images != new.images
            || old.toc != new.toc;
        let metadata_only = !chapters_changed && metadata_changed;
        let needs_anchor_migration = structure_changed;
        Self {
            chapters_changed,
            text_changed,
            metadata_only,
            needs_anchor_migration,
        }
    }
}

/// Keep the textual signal independent from structural changes.  Comparing the
/// complete ordered stream also catches text in added/removed chapters, which
/// a pairwise `zip()` comparison silently ignored.
fn text_fragments(book: &NormalizedBook) -> Vec<&str> {
    book.chapters
        .iter()
        .flat_map(|chapter| {
            std::iter::once(chapter.title.as_str())
                .chain(chapter.blocks.iter().map(|block| block.text.as_str()))
        })
        .filter(|text| !text.trim().is_empty())
        .collect()
}

#[cfg(test)]
mod book_diff_tests {
    use super::{BlockType, BookDiff, BookFormat, NormalizedBook, ReaderBlock, ReaderChapter};

    fn test_book() -> NormalizedBook {
        NormalizedBook {
            id: "book".to_string(),
            title: "Title".to_string(),
            authors: vec!["Author".to_string()],
            description: None,
            cover_url: None,
            chapters: vec![ReaderChapter {
                index: 0,
                title: "Chapter".to_string(),
                blocks: vec![ReaderBlock {
                    index: 0,
                    text: "Original text".to_string(),
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
                }],
            }],
            metadata: None,
            book_format: BookFormat::Txt,
            language: None,
            warnings: Vec::new(),
            images: Vec::new(),
            toc: Vec::new(),
        }
    }

    #[test]
    fn text_change_does_not_require_anchor_migration() {
        let old = test_book();
        let mut new = old.clone();
        new.chapters[0].blocks[0].text = "Updated text".to_string();

        let diff = BookDiff::compute(&old, &new);

        assert!(diff.chapters_changed);
        assert!(diff.text_changed);
        assert!(!diff.needs_anchor_migration);
        assert!(!diff.metadata_only);
    }

    #[test]
    fn added_textual_chapter_is_reported_as_a_text_change() {
        let old = test_book();
        let mut new = old.clone();
        let mut added = new.chapters[0].clone();
        added.index = 1;
        added.title = "Added chapter".to_string();
        added.blocks[0].text = "Added text".to_string();
        new.chapters.push(added);

        let diff = BookDiff::compute(&old, &new);

        assert!(diff.chapters_changed);
        assert!(diff.text_changed);
        assert!(diff.needs_anchor_migration);
    }

    #[test]
    fn metadata_change_is_reported_without_content_change() {
        let old = test_book();
        let mut new = old.clone();
        new.description = Some("Updated description".to_string());
        new.language = Some("ru".to_string());
        new.cover_url = Some("data:image/png;base64,AA==".to_string());
        new.book_format = BookFormat::Epub;

        let diff = BookDiff::compute(&old, &new);

        assert!(!diff.chapters_changed);
        assert!(!diff.text_changed);
        assert!(diff.metadata_only);
        assert!(!diff.needs_anchor_migration);
    }

    #[test]
    fn block_structure_change_requires_anchor_migration() {
        let old = test_book();
        let mut new = old.clone();
        new.chapters[0].blocks.push(ReaderBlock {
            index: 1,
            text: "Inserted block".to_string(),
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

        let diff = BookDiff::compute(&old, &new);

        assert!(diff.chapters_changed);
        assert!(diff.text_changed);
        assert!(!diff.metadata_only);
        assert!(diff.needs_anchor_migration);
    }

    #[test]
    fn block_type_change_requires_anchor_migration() {
        let old = test_book();
        let mut new = old.clone();
        new.chapters[0].blocks[0].block_type = BlockType::Heading;

        let diff = BookDiff::compute(&old, &new);

        assert!(diff.chapters_changed);
        assert!(!diff.text_changed);
        assert!(!diff.metadata_only);
        assert!(diff.needs_anchor_migration);
    }

    #[test]
    fn non_text_block_content_change_does_not_require_anchor_migration() {
        let old = test_book();
        let mut new = old.clone();
        new.chapters[0].blocks[0].image_url = Some("cover.png".to_string());

        let diff = BookDiff::compute(&old, &new);

        assert!(diff.chapters_changed);
        assert!(!diff.text_changed);
        assert!(!diff.needs_anchor_migration);
    }

    #[test]
    fn chapter_id_migration_finds_a_reordered_chapter() {
        let mut old = test_book();
        old.chapters[0].index = 10;
        old.chapters[0].title = "First".to_string();
        let mut second = old.chapters[0].clone();
        second.index = 20;
        second.title = "Second".to_string();
        second.blocks[0].text = "Second chapter".to_string();
        old.chapters.push(second);

        let old_id = old.chapter_id(1);
        let mut new = old.clone();
        new.chapters.swap(0, 1);

        assert_eq!(
            NormalizedBook::migrate_chapter_index(&old_id, &old, &new),
            20
        );
    }
}
