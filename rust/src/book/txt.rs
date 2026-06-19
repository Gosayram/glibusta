use crate::api::models::{BlockType, NormalizedBook, ReaderBlock, ReaderChapter};
use anyhow::{Context, Result};
use sha2::{Digest, Sha256};

pub fn parse_txt(bytes: &[u8], forced_encoding: Option<&str>) -> Result<NormalizedBook> {
    let encoding_name = forced_encoding.unwrap_or("utf-8");
    let text = decode_text(bytes, encoding_name)?;

    let paragraphs: Vec<String> = text
        .split("\n\n")
        .map(|p| normalize_whitespace(p))
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
        });
    }

    let id = {
        let mut hasher = Sha256::new();
        hasher.update(bytes);
        format!("{:x}", hasher.finalize())
    };

    let title = extract_title_from_first_line(&blocks);

    let chapters = if blocks.is_empty() {
        vec![]
    } else {
        vec![ReaderChapter {
            index: 0,
            title: title.clone(),
            blocks,
        }]
    };

    Ok(NormalizedBook {
        id,
        title,
        authors: Vec::new(),
        description: None,
        cover_url: None,
        chapters,
        metadata: None,
    })
}

fn decode_text(bytes: &[u8], encoding_name: &str) -> Result<String> {
    if encoding_name.eq_ignore_ascii_case("utf-8") {
        Ok(String::from_utf8_lossy(bytes).into_owned())
    } else {
        let (decoded, _, had_errors) =
            encoding_rs::Encoding::for_label(encoding_name.as_bytes())
                .unwrap_or(encoding_rs::UTF_8)
                .decode(bytes);
        if had_errors {
            // Fallback to UTF-8 lossy
            Ok(String::from_utf8_lossy(bytes).into_owned())
        } else {
            Ok(decoded.into_owned())
        }
    }
}

fn normalize_whitespace(text: &str) -> String {
    let mut result = String::with_capacity(text.len());
    let mut prev_was_space = false;

    for ch in text.chars() {
        match ch {
            '\r' => continue,
            '\n' => {
                if !prev_was_space {
                    result.push(' ');
                }
                prev_was_space = true;
            }
            ' ' | '\t' => {
                if !prev_was_space {
                    result.push(' ');
                }
                prev_was_space = true;
            }
            _ => {
                result.push(ch);
                prev_was_space = false;
            }
        }
    }

    result.trim().to_string()
}

fn extract_title_from_first_line(blocks: &[ReaderBlock]) -> String {
    blocks
        .first()
        .map(|b| b.text.clone())
        .unwrap_or_default()
}
