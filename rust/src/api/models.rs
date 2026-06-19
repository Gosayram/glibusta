use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum BlockType {
    Paragraph,
    Heading,
    Image,
    Quote,
    Footnote,
    Separator,
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
        }
    }

    pub fn from_str(s: &str) -> Self {
        match s {
            "heading" => BlockType::Heading,
            "image" => BlockType::Image,
            "quote" => BlockType::Quote,
            "footnote" => BlockType::Footnote,
            "separator" => BlockType::Separator,
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
    pub href: Option<String>,
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
