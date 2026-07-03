use serde::{Deserialize, Serialize};
use std::fmt;

/// Increment when NormalizedBook fields change. Flutter compares this to invalidate cache.
pub const NORMALIZED_BOOK_SCHEMA_VERSION: u32 = 1;

/// Safety limits for parsing.
pub const MAX_FILE_SIZE: u64 = 500 * 1024 * 1024; // 500 MB
pub const MAX_CHAPTER_SIZE: usize = 10 * 1024 * 1024; // 10 MB
pub const MAX_IMAGE_SIZE: usize = 50 * 1024 * 1024; // 50 MB

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
