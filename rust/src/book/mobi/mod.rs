use std::collections::HashMap;
use std::sync::LazyLock;

use anyhow::{Result, bail};
use regex::Regex;

use crate::api::models::{
    BlockType, BookFormat, MAX_FILE_SIZE, MAX_IMAGE_SIZE, NormalizedBook, ReaderBlock, TocEntry,
};

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

const MAX_TOTAL_TEXT_BYTES: usize = 32 * 1024 * 1024;
const PALMDOC_LOGICAL_RECORD_BYTES: usize = 4096;
const MAX_INLINE_IMAGE_DATA_BYTES: usize = 128 * 1024 * 1024;
const MAX_CONSECUTIVE_INDEX_RECORDS: usize = 1024;

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

    fn check(&self, offset: usize, length: usize) -> Result<usize> {
        let Some(end) = offset.checked_add(length) else {
            bail!(
                "BinaryReader: offset {} + length {} overflows usize",
                offset,
                length
            );
        };
        if end > self.bytes.len() {
            bail!(
                "BinaryReader: offset {} + length {} out of range (len {})",
                offset,
                length,
                self.bytes.len()
            );
        }
        Ok(end)
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
        let end = self.check(offset, length)?;
        Ok(self.bytes[offset..end].iter().map(|&b| b as char).collect())
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
        if bytes.get(60..64) != Some(b"BOOK".as_slice())
            || bytes.get(64..68) != Some(b"MOBI".as_slice())
        {
            bail!("Invalid PalmDB/MOBI container type or creator");
        }
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
        first_text_record_index: usize,
        forced_encoding: Option<&str>,
    ) -> Result<String> {
        if header.compression != 1 && header.compression != 2 {
            bail!("Unsupported MOBI compression: {}", header.compression);
        }
        if header.record_size as usize != PALMDOC_LOGICAL_RECORD_BYTES {
            bail!(
                "Unsupported PalmDOC logical record size: {}",
                header.record_size
            );
        }
        let text_length = usize::try_from(header.text_length)
            .map_err(|_| anyhow::anyhow!("PalmDOC text length does not fit usize"))?;
        if text_length > MAX_TOTAL_TEXT_BYTES {
            bail!("MOBI declared text length is too large");
        }
        let text_record_count = header.text_record_count as usize;
        let expected_record_count = text_length
            .checked_add(PALMDOC_LOGICAL_RECORD_BYTES - 1)
            .ok_or_else(|| anyhow::anyhow!("PalmDOC text length overflows"))?
            / PALMDOC_LOGICAL_RECORD_BYTES;
        if text_record_count != expected_record_count {
            bail!(
                "PalmDOC text record count {} does not match declared text length {}",
                text_record_count,
                text_length
            );
        }
        let Some(last_text_record_index) = first_text_record_index.checked_add(text_record_count)
        else {
            bail!("MOBI text record range overflows");
        };
        if text_record_count == 0 || last_text_record_index > palm_db.records.len() {
            bail!("Invalid MOBI text record count");
        }

        let mut chunks: Vec<u8> = Vec::new();
        let decompressor = PalmDocDecompressor;

        for i in first_text_record_index..last_text_record_index {
            let record = strip_extra_record_data(
                record_bytes(full_bytes, palm_db, i)?,
                header.extra_data_flags,
            )?;
            let remaining = text_length
                .checked_sub(chunks.len())
                .ok_or_else(|| anyhow::anyhow!("PalmDOC text exceeds declared length"))?;
            let expected_record_length = remaining.min(PALMDOC_LOGICAL_RECORD_BYTES);
            let decompressed = if header.compression == 1 {
                if record.len() > expected_record_length {
                    bail!("PalmDOC record exceeds its declared logical length");
                }
                record.to_vec()
            } else {
                decompressor.decompress_limited(record, expected_record_length)?
            };
            if decompressed.len() != expected_record_length {
                bail!("PalmDOC record length does not match declared text length");
            }
            chunks.extend_from_slice(&decompressed);
        }

        Ok(encoding::decode_text(
            &chunks,
            header.text_encoding,
            forced_encoding,
        ))
    }

    fn extract_blocks(
        &self,
        full_bytes: &[u8],
        palm_db: &PalmDb,
        header: &MobiHeader,
        first_text_record_index: usize,
        forced_encoding: Option<&str>,
    ) -> Result<Vec<ReaderBlock>> {
        let text = self.extract_text(
            full_bytes,
            palm_db,
            header,
            first_text_record_index,
            forced_encoding,
        )?;
        if self.looks_like_html(&text) {
            let mut blocks = self.html_parser.parse(&text);
            resolve_inline_images(full_bytes, palm_db, header, &mut blocks);
            Ok(blocks)
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
                page_break_before: false,
                page_break_inside_avoid: false,
                has_drop_cap: false,
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
                page_break_before: false,
                page_break_inside_avoid: false,
                has_drop_cap: false,
            });
        }
        blocks
    }
}

/// Remove per-record metadata declared by MOBI Extra Record Data Flags before
/// treating a PalmDOC record as compressed/text content. Entries for bits 2+
/// are `<data><backward-VWI size>` and therefore must be consumed from the
/// highest set bit down; bit 1 is the multibyte overlap tail.
fn strip_extra_record_data(record: &[u8], extra_data_flags: u32) -> Result<&[u8]> {
    let mut end = record.len();

    for bit in (1..u32::BITS).rev() {
        if extra_data_flags & (1_u32 << bit) == 0 {
            continue;
        }
        let entry_size = backward_vwi_entry_size(&record[..end])?;
        end = end
            .checked_sub(entry_size)
            .ok_or_else(|| anyhow::anyhow!("MOBI trailing entry exceeds record length"))?;
    }

    if extra_data_flags & 1 != 0 {
        let count_and_flags = *record
            .get(end.checked_sub(1).ok_or_else(|| {
                anyhow::anyhow!("MOBI multibyte overlap is missing its count byte")
            })?)
            .ok_or_else(|| anyhow::anyhow!("MOBI multibyte overlap is truncated"))?;
        let overlap_size = usize::from(count_and_flags & 0x03)
            .checked_add(1)
            .ok_or_else(|| anyhow::anyhow!("MOBI multibyte overlap size overflows"))?;
        end = end
            .checked_sub(overlap_size)
            .ok_or_else(|| anyhow::anyhow!("MOBI multibyte overlap exceeds record length"))?;
    }

    Ok(&record[..end])
}

fn backward_vwi_entry_size(record: &[u8]) -> Result<usize> {
    let mut start = record.len();
    let mut width = 0usize;
    loop {
        start = start
            .checked_sub(1)
            .ok_or_else(|| anyhow::anyhow!("MOBI trailing entry is missing its backward VWI"))?;
        width += 1;
        if width > 5 {
            bail!("MOBI trailing entry backward VWI exceeds u32 width");
        }
        if record[start] & 0x80 != 0 {
            break;
        }
    }

    let mut value = 0usize;
    for &byte in &record[start..] {
        value = value
            .checked_shl(7)
            .and_then(|value| value.checked_add(usize::from(byte & 0x7F)))
            .ok_or_else(|| anyhow::anyhow!("MOBI trailing entry VWI overflows usize"))?;
    }
    if value < width || value > record.len() {
        bail!("Invalid MOBI trailing entry size");
    }
    Ok(value)
}

fn resolve_inline_images(
    full_bytes: &[u8],
    palm_db: &PalmDb,
    header: &MobiHeader,
    blocks: &mut Vec<ReaderBlock>,
) {
    let mut resolved = HashMap::<u32, Option<String>>::new();
    let mut total_data_uri_bytes = 0usize;

    blocks.retain_mut(|block| {
        if block.block_type != BlockType::Image {
            return true;
        }
        let Some(recindex) = block
            .image_url
            .as_deref()
            .and_then(|url| url.strip_prefix("mobi-recindex:"))
            .and_then(|value| value.parse::<u32>().ok())
        else {
            return false;
        };

        let image_url = if let Some(cached) = resolved.get(&recindex) {
            cached.clone()
        } else {
            let image_url = inline_image_data_uri(full_bytes, palm_db, header, recindex);
            resolved.insert(recindex, image_url.clone());
            image_url
        };
        let Some(image_url) = image_url else {
            return false;
        };
        let Some(next_total) = total_data_uri_bytes.checked_add(image_url.len()) else {
            return false;
        };
        if next_total > MAX_INLINE_IMAGE_DATA_BYTES {
            return false;
        }
        total_data_uri_bytes = next_total;
        block.image_url = Some(image_url);
        true
    });

    for (index, block) in blocks.iter_mut().enumerate() {
        block.index = index as i32;
    }
}

fn inline_image_data_uri(
    full_bytes: &[u8],
    palm_db: &PalmDb,
    header: &MobiHeader,
    recindex: u32,
) -> Option<String> {
    let relative_index = usize::try_from(recindex).ok()?.checked_sub(1)?;
    let first_image = usize::try_from(header.first_image_record_index).ok()?;
    let record_index = first_image.checked_add(relative_index)?;
    let bytes = record_bytes(full_bytes, palm_db, record_index).ok()?;
    (bytes.len() <= MAX_IMAGE_SIZE)
        .then(|| encode_image_data_uri(bytes))
        .flatten()
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

/// Count the immediately following INDX/TAGX records without interpreting
/// their producer-controlled offsets or tag bytes. Full MOBI navigation needs
/// a validated decoder; this bounded probe keeps those records out of the text
/// stream while retaining useful diagnostic metadata.
struct IndexRecordProbe {
    indx_count: usize,
    tagx_count: usize,
    truncated: bool,
}

fn consecutive_index_record_counts(
    full_bytes: &[u8],
    palm_db: &PalmDb,
    first_text_record_index: usize,
    text_record_count: u16,
) -> IndexRecordProbe {
    let Some(first_index_record) = first_text_record_index.checked_add(text_record_count as usize)
    else {
        return IndexRecordProbe {
            indx_count: 0,
            tagx_count: 0,
            truncated: false,
        };
    };

    let mut indx_count = 0;
    let mut tagx_count = 0;
    let probe_end = palm_db
        .records
        .len()
        .min(first_index_record.saturating_add(MAX_CONSECUTIVE_INDEX_RECORDS));
    for record_index in first_index_record..probe_end {
        let Ok(record) = record_bytes(full_bytes, palm_db, record_index) else {
            break;
        };
        match record.get(..4) {
            Some(b"INDX") => indx_count += 1,
            Some(b"TAGX") => tagx_count += 1,
            _ => break,
        }
    }
    let truncated = indx_count + tagx_count == MAX_CONSECUTIVE_INDEX_RECORDS
        && record_bytes(full_bytes, palm_db, probe_end)
            .ok()
            .and_then(|record| record.get(..4))
            .is_some_and(|signature| matches!(signature, b"INDX" | b"TAGX"));
    IndexRecordProbe {
        indx_count,
        tagx_count,
        truncated,
    }
}

fn full_name(record0: &[u8], header: &MobiHeader, forced_encoding: Option<&str>) -> Option<String> {
    if header.full_name_length == 0 {
        return None;
    }
    let start = header.full_name_offset as usize;
    let end = start.checked_add(header.full_name_length as usize)?;
    if start >= record0.len() || end > record0.len() {
        return None;
    }
    let name = encoding::decode_text(&record0[start..end], header.text_encoding, forced_encoding)
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

fn reject_encrypted_mobi(header: &MobiHeader) -> Result<()> {
    if header.encryption_type != 0 {
        bail!(
            "Encrypted MOBI is not supported (PalmDOC encryption type {})",
            header.encryption_type
        );
    }
    Ok(())
}

fn is_likely_kf8(header: &MobiHeader, record0: &[u8]) -> bool {
    let _ = header;
    let (text, _, _) = encoding_rs::WINDOWS_1252.decode(record0);
    text.contains("BOUNDARY") || text.contains("FDST") || text.contains("RESC")
}

/// Return the KF8 header and metadata when a valid EXTH boundary points to a
/// complete KF8 section. Broken dual-format metadata must not make an
/// otherwise readable legacy MOBI fail to open.
fn kf8_section<'a>(
    full_bytes: &'a [u8],
    palm_db: &PalmDb,
    legacy_metadata: &MobiMetadata,
    forced_encoding: Option<&str>,
) -> Option<(usize, &'a [u8], MobiHeader, MobiMetadata)> {
    let boundary_index = legacy_metadata.kf8_boundary_record_index? as usize;
    let boundary = record_bytes(full_bytes, palm_db, boundary_index).ok()?;
    if boundary != b"BOUNDARY" {
        return None;
    }

    let header_index = boundary_index.checked_add(1)?;
    let record0 = record_bytes(full_bytes, palm_db, header_index).ok()?;
    let header = MobiHeaderParser.parse(record0).ok()?;
    let metadata = ExthParser.parse(record0, &header, forced_encoding).ok()?;
    Some((header_index, record0, header, metadata))
}

fn encode_image_data_uri(bytes: &[u8]) -> Option<String> {
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

pub fn parse_mobi(bytes: &[u8], forced_encoding: Option<&str>) -> Result<NormalizedBook> {
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
    let legacy_record0 = record_bytes(bytes, &palm_db, 0)?;
    let legacy_header = MobiHeaderParser.parse(legacy_record0)?;
    reject_encrypted_mobi(&legacy_header)?;
    let legacy_metadata = ExthParser.parse(legacy_record0, &legacy_header, forced_encoding)?;
    let (header_record_index, record0, header, metadata, using_kf8) =
        if let Some((header_index, kf8_record0, kf8_header, kf8_metadata)) =
            kf8_section(bytes, &palm_db, &legacy_metadata, forced_encoding)
        {
            (header_index, kf8_record0, kf8_header, kf8_metadata, true)
        } else {
            (0, legacy_record0, legacy_header, legacy_metadata, false)
        };

    reject_encrypted_mobi(&header)?;

    let text_extractor = MobiTextExtractor::new();
    let first_text_record_index = header_record_index
        .checked_add(1)
        .ok_or_else(|| anyhow::anyhow!("MOBI text record index overflows"))?;
    let blocks = text_extractor.extract_blocks(
        bytes,
        &palm_db,
        &header,
        first_text_record_index,
        forced_encoding,
    )?;
    let index_record_probe = consecutive_index_record_counts(
        bytes,
        &palm_db,
        first_text_record_index,
        header.text_record_count,
    );

    let title = first_non_empty(&[
        metadata.title.as_deref(),
        full_name(record0, &header, forced_encoding).as_deref(),
        Some(&palm_db.name),
        None,
    ]);

    let authors = metadata
        .authors
        .iter()
        .flat_map(|author| split_authors(Some(author)))
        .collect::<Vec<_>>();

    let chapters = MobiChapterSplitter::new().split(&blocks);
    let toc = chapters
        .iter()
        .map(|chapter| TocEntry {
            title: chapter.title.clone(),
            chapter_index: chapter.index,
            children: Vec::new(),
        })
        .collect();

    let cover_extractor = MobiCoverExtractor;
    let cover_bytes = cover_extractor.extract(bytes, &palm_db, &header, &metadata);
    let cover_url = cover_bytes.as_ref().and_then(|b| encode_image_data_uri(b));

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
    // MOBI stores these as locale integers, not BCP-47 tags. Preserve the
    // values for diagnostics/round-tripping without guessing a language tag.
    if let Some(locale) = header.locale {
        meta.insert("mobiLocale".to_string(), serde_json::json!(locale));
    }
    if let Some(input_language) = header.input_language {
        meta.insert(
            "mobiInputLanguage".to_string(),
            serde_json::json!(input_language),
        );
    }
    if let Some(output_language) = header.output_language {
        meta.insert(
            "mobiOutputLanguage".to_string(),
            serde_json::json!(output_language),
        );
    }
    if let Some(ref lang) = metadata.language {
        meta.insert(
            "mobiLanguage".to_string(),
            serde_json::Value::String(lang.to_string()),
        );
    }
    if !metadata.authors.is_empty() {
        meta.insert(
            "mobiAuthors".to_string(),
            serde_json::Value::Array(
                metadata
                    .authors
                    .iter()
                    .map(|author| serde_json::Value::String(author.to_string()))
                    .collect(),
            ),
        );
    }
    if let Some(value) = &metadata.publisher {
        meta.insert(
            "mobiPublisher".to_string(),
            serde_json::Value::String(value.to_string()),
        );
    }
    if let Some(value) = &metadata.isbn {
        meta.insert(
            "mobiIsbn".to_string(),
            serde_json::Value::String(value.to_string()),
        );
    }
    if !metadata.subjects.is_empty() {
        meta.insert(
            "mobiSubjects".to_string(),
            serde_json::Value::Array(
                metadata
                    .subjects
                    .iter()
                    .map(|subject| serde_json::Value::String(subject.to_string()))
                    .collect(),
            ),
        );
    }
    meta.insert(
        "mobiFirstImageRecordIndex".to_string(),
        serde_json::json!(header.first_image_record_index),
    );
    meta.insert(
        "mobiKf8Likely".to_string(),
        serde_json::json!(using_kf8 || is_likely_kf8(&header, record0)),
    );
    meta.insert(
        "mobiTocSource".to_string(),
        serde_json::Value::String("chapter-splitter".to_string()),
    );
    if index_record_probe.indx_count != 0 || index_record_probe.tagx_count != 0 {
        meta.insert(
            "mobiIndxRecordCount".to_string(),
            serde_json::json!(index_record_probe.indx_count),
        );
        meta.insert(
            "mobiTagxRecordCount".to_string(),
            serde_json::json!(index_record_probe.tagx_count),
        );
    }
    if index_record_probe.truncated {
        meta.insert(
            "mobiIndexProbeTruncated".to_string(),
            serde_json::json!(true),
        );
    }
    if let Some(ref cover) = cover_bytes {
        meta.insert("mobiCoverBytes".to_string(), serde_json::json!(cover.len()));
    }
    if let Some(idx) = metadata.cover_record_index {
        meta.insert("mobiCoverRecordIndex".to_string(), serde_json::json!(idx));
    }
    let comic_book_type = metadata
        .book_type
        .as_deref()
        .is_some_and(|book_type| book_type.eq_ignore_ascii_case("comic"));
    let has_layout_hints = metadata.fixed_layout
        || comic_book_type
        || metadata.orientation_lock.is_some()
        || metadata.resource_count.is_some()
        || metadata.original_resolution.is_some()
        || metadata.zero_gutter
        || metadata.zero_margin
        || metadata.metadata_resource_uri.is_some();
    if has_layout_hints {
        // Glibusta has no fixed-layout MOBI renderer. Retain the producer hints
        // for diagnostics while deliberately keeping the validated text stream
        // on the normal reflow path.
        meta.insert(
            "mobiLayoutPolicy".to_string(),
            serde_json::Value::String("reflow_fallback".to_string()),
        );
        meta.insert(
            "mobiFixedLayout".to_string(),
            serde_json::json!(metadata.fixed_layout),
        );
        meta.insert(
            "mobiComicBookType".to_string(),
            serde_json::json!(comic_book_type),
        );
        meta.insert(
            "mobiZeroGutter".to_string(),
            serde_json::json!(metadata.zero_gutter),
        );
        meta.insert(
            "mobiZeroMargin".to_string(),
            serde_json::json!(metadata.zero_margin),
        );
        if let Some(value) = &metadata.book_type {
            meta.insert(
                "mobiBookType".to_string(),
                serde_json::Value::String(value.to_string()),
            );
        }
        if let Some(value) = &metadata.orientation_lock {
            meta.insert(
                "mobiOrientationLock".to_string(),
                serde_json::Value::String(value.to_string()),
            );
        }
        if let Some(value) = metadata.resource_count {
            meta.insert("mobiResourceCount".to_string(), serde_json::json!(value));
        }
        if let Some(value) = &metadata.original_resolution {
            meta.insert(
                "mobiOriginalResolution".to_string(),
                serde_json::Value::String(value.to_string()),
            );
        }
        if let Some(value) = &metadata.metadata_resource_uri {
            meta.insert(
                "mobiMetadataResourceUri".to_string(),
                serde_json::Value::String(value.to_string()),
            );
        }
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
            .or_else(|| Some(description_for(&header))),
        cover_url,
        chapters,
        metadata: Some(serde_json::Value::Object(meta)),
        metadata_json: None,
        book_format: BookFormat::Mobi,
        language: metadata.language.map(|s| s.to_string()),
        warnings: Vec::new(),
        images: Vec::new(),
        toc,
    })
}

#[cfg(test)]
mod tests {
    use super::BinaryReader;

    #[test]
    fn binary_reader_rejects_overflowing_ranges() {
        let reader = BinaryReader::new(&[]);

        assert!(reader.u16be(usize::MAX).is_err());
    }
}
