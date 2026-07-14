use std::sync::LazyLock;

use anyhow::{Result, bail};
use regex::Regex;

use crate::api::models::{BlockType, BookFormat, MAX_FILE_SIZE, NormalizedBook, ReaderBlock};

mod chapters;
mod cover;
mod decompressor;
mod encoding;
mod exth;
mod header;
mod html_parser;

pub(crate) use chapters::MobiChapterSplitter;
pub(crate) use cover::MobiCoverExtractor;
pub(crate) use decompressor::PalmDocDecompressor;
pub(crate) use exth::{ExthParser, MobiMetadata};
pub(crate) use header::{MobiHeader, MobiHeaderParser};
pub(crate) use html_parser::MobiHtmlParser;

pub(crate) static TAG_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"<[^>]*>").unwrap());

static AUTHORS_SPLIT_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?i)\s*(?:;|,|and|&)\s*"#).unwrap());

const MAX_DECOMPRESSED_RECORD_BYTES: usize = 8 * 1024 * 1024;
const MAX_TOTAL_TEXT_BYTES: usize = 32 * 1024 * 1024;

// ---------------------------------------------------------------------------
// BinaryReader
// ---------------------------------------------------------------------------

pub(crate) struct BinaryReader<'a> {
    bytes: &'a [u8],
}

impl<'a> BinaryReader<'a> {
    pub fn new(bytes: &'a [u8]) -> Self {
        Self { bytes }
    }

    fn check(&self, offset: usize, length: usize) -> Result<()> {
        if offset + length > self.bytes.len() {
            bail!(
                "BinaryReader: offset {} + length {} out of range (len {})",
                offset,
                length,
                self.bytes.len()
            );
        }
        Ok(())
    }

    pub fn u16be(&self, offset: usize) -> Result<u16> {
        self.check(offset, 2)?;
        Ok(((self.bytes[offset] as u16) << 8) | (self.bytes[offset + 1] as u16))
    }

    pub fn u32be(&self, offset: usize) -> Result<u32> {
        self.check(offset, 4)?;
        Ok(((self.bytes[offset] as u32) << 24)
            | ((self.bytes[offset + 1] as u32) << 16)
            | ((self.bytes[offset + 2] as u32) << 8)
            | (self.bytes[offset + 3] as u32))
    }

    pub fn ascii(&self, offset: usize, length: usize) -> Result<String> {
        self.check(offset, length)?;
        Ok(self.bytes[offset..offset + length]
            .iter()
            .map(|&b| b as char)
            .collect())
    }

    #[allow(dead_code)]
    fn slice(&self, start: usize, end: usize) -> Result<&'a [u8]> {
        if start > end || end > self.bytes.len() {
            bail!(
                "BinaryReader::slice: start {} end {} out of range (len {})",
                start,
                end,
                self.bytes.len()
            );
        }
        Ok(&self.bytes[start..end])
    }
}

// ---------------------------------------------------------------------------
// PalmRecord
// ---------------------------------------------------------------------------

pub(crate) struct PalmRecord {
    pub offset: usize,
    #[allow(dead_code)]
    pub attributes: u8,
    #[allow(dead_code)]
    pub unique_id: u32,
}

// ---------------------------------------------------------------------------
// PalmDb
// ---------------------------------------------------------------------------

pub(crate) struct PalmDb {
    pub name: String,
    pub records: Vec<PalmRecord>,
}

// ---------------------------------------------------------------------------
// PalmDbParser
// ---------------------------------------------------------------------------

struct PalmDbParser;

impl PalmDbParser {
    fn parse(&self, bytes: &[u8]) -> Result<PalmDb> {
        let reader = BinaryReader::new(bytes);
        let record_count = reader.u16be(76)? as usize;
        let table_end = 78 + record_count * 8;

        if record_count == 0 || table_end > bytes.len() {
            bail!("Invalid PalmDB record table");
        }

        let mut records = Vec::with_capacity(record_count);
        let mut offset = 78;
        let mut previous_record_offset: i64 = -1;

        for _ in 0..record_count {
            let record_offset = reader.u32be(offset)? as i64;
            if record_offset < table_end as i64 || record_offset >= bytes.len() as i64 {
                bail!("Invalid PalmDB record offset: {}", record_offset);
            }
            if previous_record_offset > record_offset {
                bail!("PalmDB record offsets are not sorted");
            }
            previous_record_offset = record_offset;
            records.push(PalmRecord {
                offset: record_offset as usize,
                attributes: bytes[offset + 4],
                unique_id: ((bytes[offset + 5] as u32) << 16)
                    | ((bytes[offset + 6] as u32) << 8)
                    | (bytes[offset + 7] as u32),
            });
            offset += 8;
        }

        let name = reader.ascii(0, 32)?.replace('\0', "").trim().to_string();

        Ok(PalmDb { name, records })
    }
}

// ---------------------------------------------------------------------------
// MobiTextExtractor
// ---------------------------------------------------------------------------

struct MobiTextExtractor {
    html_parser: MobiHtmlParser,
}

impl MobiTextExtractor {
    fn new() -> Self {
        Self {
            html_parser: MobiHtmlParser::new(),
        }
    }

    fn extract_text(
        &self,
        full_bytes: &[u8],
        palm_db: &PalmDb,
        header: &MobiHeader,
    ) -> Result<String> {
        if header.compression != 1 && header.compression != 2 {
            bail!("Unsupported MOBI compression: {}", header.compression);
        }
        if header.text_record_count == 0
            || (header.text_record_count as usize) >= palm_db.records.len()
        {
            bail!("Invalid MOBI text record count");
        }

        let mut chunks: Vec<u8> = Vec::new();
        let decompressor = PalmDocDecompressor;

        for i in 1..=header.text_record_count as usize {
            let record = record_bytes(full_bytes, palm_db, i)?;
            let decompressed = if header.compression == 1 {
                record.to_vec()
            } else {
                decompressor.decompress(record)?
            };
            chunks.extend_from_slice(&decompressed);
            if chunks.len() > MAX_TOTAL_TEXT_BYTES {
                bail!("MOBI text stream is too large");
            }
        }

        Ok(encoding::decode_text(&chunks, header.text_encoding))
    }

    fn extract_blocks(
        &self,
        full_bytes: &[u8],
        palm_db: &PalmDb,
        header: &MobiHeader,
    ) -> Result<Vec<ReaderBlock>> {
        let text = self.extract_text(full_bytes, palm_db, header)?;
        if self.looks_like_html(&text) {
            Ok(self.html_parser.parse(&text))
        } else {
            Ok(self.plain_text_to_blocks(&text))
        }
    }

    fn looks_like_html(&self, text: &str) -> bool {
        let sample_len = std::cmp::min(text.len(), 2000);
        let sample = if sample_len == text.len() {
            text
        } else {
            let mut end = sample_len;
            while end > 0 && !text.is_char_boundary(end) {
                end -= 1;
            }
            &text[..end]
        };
        sample.contains("<p")
            || sample.contains("<h")
            || sample.contains("<br")
            || sample.contains("<div")
            || sample.contains("<b>")
            || sample.contains("<i>")
    }

    fn plain_text_to_blocks(&self, text: &str) -> Vec<ReaderBlock> {
        let mut blocks: Vec<ReaderBlock> = Vec::new();
        let mut idx = 0i32;
        for line in text.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() {
                continue;
            }
            blocks.push(ReaderBlock {
                index: idx,
                text: trimmed.to_string(),
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
            idx += 1;
        }
        if blocks.is_empty() && !text.trim().is_empty() {
            blocks.push(ReaderBlock {
                index: 0,
                text: text.trim().to_string(),
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
        blocks
    }
}

// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------

fn record_bytes<'a>(full_bytes: &'a [u8], palm_db: &PalmDb, index: usize) -> Result<&'a [u8]> {
    if index >= palm_db.records.len() {
        bail!("Record index {} out of range", index);
    }
    let start = palm_db.records[index].offset;
    let end = if index + 1 < palm_db.records.len() {
        palm_db.records[index + 1].offset
    } else {
        full_bytes.len()
    };
    if start > end || end > full_bytes.len() {
        bail!("Invalid record byte range: {}..{}", start, end);
    }
    Ok(&full_bytes[start..end])
}

fn full_name(record0: &[u8], header: &MobiHeader) -> Option<String> {
    if header.full_name_length == 0 {
        return None;
    }
    let end = header.full_name_offset as usize + header.full_name_length as usize;
    if header.full_name_offset as usize >= record0.len() || end > record0.len() {
        return None;
    }
    let name = String::from_utf8_lossy(&record0[header.full_name_offset as usize..end])
        .trim()
        .to_string();
    if name.is_empty() { None } else { Some(name) }
}

fn first_non_empty(values: &[Option<&str>]) -> String {
    for s in values.iter().flatten() {
        let trimmed = s.trim();
        if !trimmed.is_empty() {
            return trimmed.to_string();
        }
    }
    "MOBI document".to_string()
}

fn split_authors(value: Option<&str>) -> Vec<String> {
    let val = match value {
        Some(v) => v.trim(),
        None => return Vec::new(),
    };
    if val.is_empty() {
        return Vec::new();
    }
    AUTHORS_SPLIT_RE
        .split(val)
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect()
}

fn stable_id(file_name: Option<&str>, bytes: &[u8]) -> String {
    let take_len = std::cmp::min(bytes.len(), 1024 * 1024);
    let digest = crate::book::sha256_hex(&bytes[..take_len]);
    let prefix = strip_extension(file_name).unwrap_or_else(|| "mobi".to_string());
    format!("{}_{}", prefix, digest)
}

fn strip_extension(file_name: Option<&str>) -> Option<String> {
    let name = file_name?;
    if name.is_empty() {
        return None;
    }
    let normalized = name
        .rsplit('/')
        .next()
        .unwrap_or(name)
        .rsplit('\\')
        .next()
        .unwrap_or(name);
    let dot = normalized.rfind('.');
    Some(if let Some(d) = dot {
        normalized[..d].to_string()
    } else {
        normalized.to_string()
    })
}

fn description_for(header: &MobiHeader) -> String {
    if header.compression == 17480 {
        "MOBI/AZW3 document: Huff/CDIC compression is not supported yet".to_string()
    } else {
        "MOBI document".to_string()
    }
}

fn is_likely_kf8(header: &MobiHeader, record0: &[u8]) -> bool {
    let _ = header;
    let (text, _, _) = encoding_rs::WINDOWS_1252.decode(record0);
    text.contains("BOUNDARY") || text.contains("FDST") || text.contains("RESC")
}

fn encode_cover_data_uri(bytes: &[u8]) -> Option<String> {
    let mime = if bytes.len() >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8 {
        "image/jpeg"
    } else if bytes.len() >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 {
        "image/png"
    } else if bytes.len() >= 3 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 {
        "image/gif"
    } else {
        return None;
    };
    use base64::Engine;
    Some(format!(
        "data:{};base64,{}",
        mime,
        base64::engine::general_purpose::STANDARD.encode(bytes)
    ))
}

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

pub fn parse_mobi(bytes: &[u8], _forced_encoding: Option<&str>) -> Result<NormalizedBook> {
    if bytes.len() as u64 > MAX_FILE_SIZE {
        bail!(
            "MOBI file exceeds maximum size of {} MiB",
            MAX_FILE_SIZE / 1024 / 1024
        );
    }
    if bytes.len() < 86 {
        bail!("File is too small for PalmDB/MOBI");
    }

    let palm_db = PalmDbParser.parse(bytes)?;
    let record0 = record_bytes(bytes, &palm_db, 0)?;
    let header = MobiHeaderParser.parse(record0)?;
    let metadata = ExthParser.parse(record0, &header)?;

    let text_extractor = MobiTextExtractor::new();
    let blocks = text_extractor.extract_blocks(bytes, &palm_db, &header)?;

    let title = first_non_empty(&[
        metadata.title.as_deref(),
        full_name(record0, &header).as_deref(),
        Some(&palm_db.name),
        None,
    ]);

    let authors = split_authors(metadata.author.as_deref());

    let chapters = MobiChapterSplitter::new().split(&blocks);

    let cover_extractor = MobiCoverExtractor;
    let cover_bytes = cover_extractor.extract(bytes, &palm_db, &header, &metadata);
    let cover_url = cover_bytes.as_ref().and_then(|b| encode_cover_data_uri(b));

    let mut meta = serde_json::Map::new();
    meta.insert(
        "format".to_string(),
        serde_json::Value::String("mobi".to_string()),
    );
    meta.insert(
        "mobiCompression".to_string(),
        serde_json::json!(header.compression),
    );
    meta.insert(
        "mobiTextRecordCount".to_string(),
        serde_json::json!(header.text_record_count),
    );
    meta.insert(
        "mobiRecordCount".to_string(),
        serde_json::json!(palm_db.records.len()),
    );
    meta.insert(
        "mobiExthPresent".to_string(),
        serde_json::json!(metadata.has_exth),
    );
    if let Some(ref lang) = metadata.language {
        meta.insert(
            "mobiLanguage".to_string(),
            serde_json::Value::String(lang.to_string()),
        );
    }
    meta.insert(
        "mobiFirstImageRecordIndex".to_string(),
        serde_json::json!(header.first_image_record_index),
    );
    meta.insert(
        "mobiKf8Likely".to_string(),
        serde_json::json!(is_likely_kf8(&header, record0)),
    );
    if let Some(ref cover) = cover_bytes {
        meta.insert("mobiCoverBytes".to_string(), serde_json::json!(cover.len()));
    }
    if let Some(idx) = metadata.cover_record_index {
        meta.insert("mobiCoverRecordIndex".to_string(), serde_json::json!(idx));
    }

    Ok(NormalizedBook {
        id: stable_id(None, bytes),
        title,
        authors: if authors.is_empty() {
            vec!["Unknown".to_string()]
        } else {
            authors
        },
        description: metadata
            .description
            .map(|s| s.to_string())
            .or(Some(description_for(&header))),
        cover_url,
        chapters,
        metadata: Some(serde_json::Value::Object(meta)),
        book_format: BookFormat::Mobi,
        language: metadata.language.map(|s| s.to_string()),
        warnings: Vec::new(),
        images: Vec::new(),
        toc: Vec::new(),
    })
}
