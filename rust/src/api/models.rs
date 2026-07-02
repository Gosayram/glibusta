use serde::{Deserialize, Serialize};

/// Lightweight book metadata — no chapters, no blocks.
/// Used by extract_metadata() for fast scanning.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BookMeta {
    pub title: String,
    pub authors: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
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
}

impl NormalizedBook {
    pub fn to_json_string(&self) -> anyhow::Result<String> {
        Ok(serde_json::to_string(self)?)
    }

    pub fn from_json_str(json: &str) -> anyhow::Result<Self> {
        Ok(serde_json::from_str(json)?)
    }
}
