use crate::api::models::NormalizedBook;
use anyhow::{Context, Result};

pub fn parse_fb2(bytes: Vec<u8>, forced_encoding: Option<String>) -> Result<NormalizedBook> {
    crate::book::fb2::parse_fb2(&bytes, forced_encoding.as_deref()).context("Failed to parse FB2")
}

pub fn parse_epub(bytes: Vec<u8>, forced_encoding: Option<String>) -> Result<NormalizedBook> {
    crate::book::epub::parse_epub(&bytes, forced_encoding.as_deref())
        .context("Failed to parse EPUB")
}

pub fn parse_txt(bytes: Vec<u8>, forced_encoding: Option<String>) -> Result<NormalizedBook> {
    crate::book::txt::parse_txt(&bytes, forced_encoding.as_deref()).context("Failed to parse TXT")
}

pub fn parse_docx(bytes: Vec<u8>, forced_encoding: Option<String>) -> Result<NormalizedBook> {
    crate::book::docx::parse_docx(&bytes, forced_encoding.as_deref())
        .context("Failed to parse DOCX")
}

pub fn parse_rtf(bytes: Vec<u8>, forced_encoding: Option<String>) -> Result<NormalizedBook> {
    crate::book::rtf::parse_rtf(&bytes, forced_encoding.as_deref()).context("Failed to parse RTF")
}

pub fn parse_mobi(bytes: Vec<u8>, forced_encoding: Option<String>) -> Result<NormalizedBook> {
    crate::book::mobi::parse_mobi(&bytes, forced_encoding.as_deref())
        .context("Failed to parse MOBI")
}

pub fn decode_zip_entries(bytes: Vec<u8>) -> Result<Vec<String>> {
    let zip = crate::book::archive::decode_zip(&bytes).context("Failed to decode ZIP")?;
    Ok(zip.entry_names().to_vec())
}

pub fn extract_zip_entry(bytes: Vec<u8>, entry_name: String) -> Result<Vec<u8>> {
    let zip = crate::book::archive::decode_zip(&bytes).context("Failed to decode ZIP")?;
    zip.find_file(&entry_name)
        .map(|v| v.to_vec())
        .with_context(|| format!("Entry '{}' not found in ZIP", entry_name))
}

pub fn detect_encoding(bytes: Vec<u8>) -> Result<String> {
    let encoding = detect_encoding_inner(&bytes);
    Ok(encoding.to_string())
}

/// Compute SHA-256 hash of bytes (first `max_bytes` only for efficiency).
pub fn sha256_hash(bytes: Vec<u8>, max_bytes: Option<usize>) -> Result<String> {
    let limit = max_bytes.unwrap_or(bytes.len());
    let to_hash = &bytes[..bytes.len().min(limit)];
    Ok(crate::book::sha256_hex(to_hash))
}

pub fn parse_book(
    bytes: Vec<u8>,
    format: String,
    forced_encoding: Option<String>,
) -> Result<NormalizedBook> {
    match format.as_str() {
        "fb2" => parse_fb2(bytes, forced_encoding),
        "epub" => parse_epub(bytes, forced_encoding),
        "txt" => parse_txt(bytes, forced_encoding),
        "docx" => parse_docx(bytes, forced_encoding),
        "rtf" => parse_rtf(bytes, forced_encoding),
        "mobi" | "azw3" | "prc" => parse_mobi(bytes, forced_encoding),
        _ => anyhow::bail!("Unsupported format: {}", format),
    }
}

fn detect_encoding_inner(bytes: &[u8]) -> &'static str {
    if bytes.len() >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF {
        return "utf-8";
    }
    if bytes.len() >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE {
        return "utf-16le";
    }
    if bytes.len() >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF {
        return "utf-16be";
    }

    if std::str::from_utf8(bytes).is_ok() {
        return "utf-8";
    }

    let (decoded, encoding_used, _) = encoding_rs::WINDOWS_1252.decode(bytes);
    if decoded
        .chars()
        .all(|c| !c.is_control() || c == '\n' || c == '\r' || c == '\t')
    {
        return encoding_used.name();
    }

    let (decoded, _, _) = encoding_rs::UTF_8.decode(bytes);
    if decoded.chars().any(|c| c == '\u{FFFD}') {
        return "windows-1252";
    }

    "utf-8"
}
