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
                footnotes: false,
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
            BookFormat::Unknown => "unknown",
        }
    }

    pub fn from_ext(ext: &str) -> Self {
        match ext.to_lowercase().as_str() {
            "fb2" | "fb2.zip" => BookFormat::Fb2,
            "epub" => BookFormat::Epub,
            "txt" => BookFormat::Txt,
            "docx" => BookFormat::Docx,
            "rtf" => BookFormat::Rtf,
            "mobi" => BookFormat::Mobi,
            "azw3" | "azw" => BookFormat::Azw3,
            "prc" => BookFormat::Prc,
            "pdf" => BookFormat::Pdf,
            "djvu" | "djv" => BookFormat::Djvu,
            _ => BookFormat::Unknown,
        }
    }

    pub fn extensions() -> &'static [&'static str] {
        &[
            "fb2", "fb2.zip", "epub", "txt", "docx", "rtf", "mobi", "azw3", "azw", "prc", "pdf",
            "djvu", "djv",
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
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TocEntry {
    pub title: String,
    /// Chapter index (0-based) or -1 for non-chapter entries.
    pub chapter_index: i32,
    /// Nested sub-entries.
    #[serde(default)]
    pub children: Vec<TocEntry>,
}

/// An embedded image extracted from the book.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmbeddedImage {
    /// Identifier (filename or URL reference).
    pub id: String,
    /// MIME type (e.g. "image/jpeg").
    pub media_type: String,
    /// Raw image bytes.
    pub data: Vec<u8>,
}

/// Non-fatal warning from parsing.
#[derive(Debug, Clone, Serialize, Deserialize)]
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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RichSpan {
    pub text: String,
    pub bold: bool,
    pub italic: bool,
    pub superscript: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub href: Option<String>,
    #[serde(default)]
    pub line_break: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
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
