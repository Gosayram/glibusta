use crate::api::models::{BookMeta, NormalizedBook, ReaderBlock};
use anyhow::{Context, Result};

/// Extract blocks from HTML content using html5ever + scraper.
/// Returns a JSON-serialized list of ReaderBlock for Dart consumption.
pub fn parse_html_blocks(html: String) -> Result<Vec<ReaderBlock>> {
    let (blocks, _) = crate::book::html_parser::html_to_blocks(&html, 0);
    Ok(blocks)
}

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
    let mut zip = crate::book::archive::decode_zip(&bytes).context("Failed to decode ZIP")?;
    zip.find_file(&entry_name)
        .with_context(|| format!("Entry '{}' not found in ZIP", entry_name))
}

pub fn detect_encoding(bytes: Vec<u8>) -> Result<String> {
    Ok(crate::book::encoding::detect_encoding(&bytes).to_string())
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

/// Extract metadata (title, authors, description) without full chapter parsing.
/// Faster than parse_book when only metadata is needed.
pub fn extract_metadata(
    bytes: Vec<u8>,
    format: String,
    forced_encoding: Option<String>,
) -> Result<BookMeta> {
    let book = parse_book(bytes, format, forced_encoding)?;
    Ok(BookMeta {
        title: book.title,
        authors: book.authors,
        description: book.description,
    })
}

/// Extract cover image bytes (if available). Returns empty Vec if no cover.
pub fn extract_cover(
    bytes: Vec<u8>,
    format: String,
    forced_encoding: Option<String>,
) -> Result<Vec<u8>> {
    let book = parse_book(bytes, format, forced_encoding)?;
    // NormalizedBook stores cover as base64 in cover_url
    if let Some(cover_b64) = &book.cover_url {
        use base64::Engine;
        let engine = base64::engine::general_purpose::STANDARD;
        let decoded = engine
            .decode(cover_b64)
            .context("Failed to decode cover base64")?;
        return Ok(decoded);
    }
    Ok(Vec::new())
}

/// Render a PDF page as a PNG thumbnail.
///
/// Requires the `pdf` feature and a PDFium binary available on the system.
#[cfg(feature = "pdf")]
pub fn render_pdf_thumbnail(path: String, page_index: u16, width: u16) -> Result<Vec<u8>> {
    use pdfium_render::prelude::*;

    let bindings = Pdfium::bind_to_system_library()
        .map_err(|e| anyhow::anyhow!("Failed to bind PDFium: {}", e))?;
    let pdfium = Pdfium::new(bindings);

    let document = pdfium
        .load_pdf_from_file(&path, None)
        .map_err(|e| anyhow::anyhow!("Failed to load PDF: {}", e))?;

    let page = document
        .pages()
        .get(page_index as i32)
        .map_err(|e| anyhow::anyhow!("Failed to get page {}: {}", page_index, e))?;

    let config = PdfRenderConfig::new()
        .set_target_width(width as i32)
        .render_form_data(true);

    let bitmap = page
        .render_with_config(&config)
        .map_err(|e| anyhow::anyhow!("Failed to render page: {}", e))?;

    let img = bitmap
        .as_image()
        .map_err(|e| anyhow::anyhow!("Failed to convert bitmap to image: {}", e))?;

    let mut bytes = Vec::new();
    img.write_to(
        &mut std::io::Cursor::new(&mut bytes),
        image::ImageFormat::Png,
    )
    .map_err(|e| anyhow::anyhow!("Failed to encode PNG: {}", e))?;

    Ok(bytes)
}

/// Stub when pdf feature is disabled.
#[cfg(not(feature = "pdf"))]
pub fn render_pdf_thumbnail(_path: String, _page_index: u16, _width: u16) -> Result<Vec<u8>> {
    anyhow::bail!("PDF support is not enabled. Rebuild with --features pdf")
}
