use crate::api::models::{
    BookAssetMeta, BookFormat, BookMeta, BookValidationResult, ChapterLanguage, CoreError,
    FormatCapabilities, ImportReport, NormalizedBook, ReaderBlock, TocEntry,
};
use std::path::Path;

// ---------------------------------------------------------------------------
// Internal helpers (not FRB-visible)
// ---------------------------------------------------------------------------

fn ext_from_path(path: &str) -> &str {
    Path::new(path)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
}

fn detect_format_from_path(path: &str) -> Result<BookFormat, CoreError> {
    let ext = ext_from_path(path);
    let fmt = BookFormat::from_ext(ext);
    if fmt == BookFormat::Unknown {
        return Err(CoreError::UnsupportedFormat(format!(
            "Cannot detect format from extension '.{}'",
            ext
        )));
    }
    Ok(fmt)
}

fn read_file_bytes(path: &str) -> Result<Vec<u8>, CoreError> {
    std::fs::read(path).map_err(|e| CoreError::IoError(e.to_string()))
}

fn dispatch_parse(bytes: &[u8], format: BookFormat) -> Result<NormalizedBook, CoreError> {
    match format {
        BookFormat::Fb2 => crate::book::fb2::parse_fb2(bytes, None)
            .map_err(|e| CoreError::ParserFailed(e.to_string())),
        BookFormat::Epub => crate::book::epub::parse_epub(bytes, None)
            .map_err(|e| CoreError::ParserFailed(e.to_string())),
        BookFormat::Txt => crate::book::txt::parse_txt(bytes, None)
            .map_err(|e| CoreError::ParserFailed(e.to_string())),
        BookFormat::Docx => crate::book::docx::parse_docx(bytes, None)
            .map_err(|e| CoreError::ParserFailed(e.to_string())),
        BookFormat::Rtf => crate::book::rtf::parse_rtf(bytes, None)
            .map_err(|e| CoreError::ParserFailed(e.to_string())),
        BookFormat::Mobi | BookFormat::Azw3 | BookFormat::Prc => {
            crate::book::mobi::parse_mobi(bytes, None)
                .map_err(|e| CoreError::ParserFailed(e.to_string()))
        }
        BookFormat::Pdf => {
            #[cfg(feature = "pdf")]
            {
                // PDF needs path-based rendering; for parse use placeholder
                Err(CoreError::FeatureDisabled(
                    "PDF full parsing not yet implemented, use render_pdf_thumbnail".into(),
                ))
            }
            #[cfg(not(feature = "pdf"))]
            Err(CoreError::FeatureDisabled(
                "PDF support disabled, rebuild with --features pdf".into(),
            ))
        }
        BookFormat::Djvu => Err(CoreError::FeatureDisabled(
            "DJVU support not yet implemented".into(),
        )),
        BookFormat::Unknown => Err(CoreError::UnsupportedFormat("unknown".into())),
    }
}

// ---------------------------------------------------------------------------
// FRB-visible API — path-based, unified
// ---------------------------------------------------------------------------

/// Read a book from filesystem, detect format by extension, parse into NormalizedBook.
pub fn parse_book(path: String) -> anyhow::Result<NormalizedBook> {
    let format = detect_format_from_path(&path).map_err(|e| anyhow::anyhow!("{}", e))?;
    let bytes = read_file_bytes(&path).map_err(|e| anyhow::anyhow!("{}", e))?;
    let mut book = dispatch_parse(&bytes, format).map_err(|e| anyhow::anyhow!("{}", e))?;
    // Set format on the output
    book.book_format = format;
    Ok(book)
}

/// Panic-safe wrapper for parse_book. Returns error instead of crashing.
pub fn safe_parse_book(path: String) -> anyhow::Result<NormalizedBook> {
    let result = std::panic::catch_unwind(|| parse_book(path));
    match result {
        Ok(Ok(book)) => Ok(book),
        Ok(Err(e)) => Err(e),
        Err(panic) => {
            let msg = if let Some(s) = panic.downcast_ref::<&str>() {
                s.to_string()
            } else if let Some(s) = panic.downcast_ref::<String>() {
                s.clone()
            } else {
                "Unknown panic".to_string()
            };
            Err(anyhow::anyhow!("Parser panicked: {}", msg))
        }
    }
}

/// Parse with a timeout. Returns error if parsing takes longer than timeout_secs.
pub fn parse_book_with_timeout(path: String, timeout_secs: u64) -> anyhow::Result<NormalizedBook> {
    let handle = std::thread::spawn(move || parse_book(path));
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(timeout_secs);
    loop {
        if std::time::Instant::now() >= deadline {
            return Err(anyhow::anyhow!("Parse timeout after {}s", timeout_secs));
        }
        if handle.is_finished() {
            return handle
                .join()
                .map_err(|_| anyhow::anyhow!("Parser thread panicked"))?;
        }
        std::thread::sleep(std::time::Duration::from_millis(50));
    }
}

/// Extract metadata without full chapter parsing.
pub fn extract_metadata(path: String) -> anyhow::Result<BookMeta> {
    let format = detect_format_from_path(&path).map_err(|e| anyhow::anyhow!("{}", e))?;
    let bytes = read_file_bytes(&path).map_err(|e| anyhow::anyhow!("{}", e))?;

    let book = dispatch_parse(&bytes, format).map_err(|e| anyhow::anyhow!("{}", e))?;

    Ok(BookMeta {
        title: book.title,
        authors: book.authors,
        description: book.description,
        language: book.language,
        genres: Vec::new(),
        cover_data: None,
        toc: book.toc,
    })
}

/// Extract cover image bytes. Returns None (empty Vec) if no cover.
pub fn extract_cover(path: String) -> anyhow::Result<Vec<u8>> {
    let format = detect_format_from_path(&path).map_err(|e| anyhow::anyhow!("{}", e))?;
    let bytes = read_file_bytes(&path).map_err(|e| anyhow::anyhow!("{}", e))?;

    let book = dispatch_parse(&bytes, format).map_err(|e| anyhow::anyhow!("{}", e))?;

    if let Some(cover_b64) = &book.cover_url {
        use base64::Engine;
        let engine = base64::engine::general_purpose::STANDARD;
        let decoded = engine
            .decode(cover_b64)
            .map_err(|e| anyhow::anyhow!("Failed to decode cover base64: {}", e))?;
        return Ok(decoded);
    }
    Ok(Vec::new())
}

/// Detect book format from file extension.
pub fn detect_format(path: String) -> anyhow::Result<String> {
    let fmt = detect_format_from_path(&path)?;
    Ok(fmt.as_str().to_string())
}

/// Calculate SHA-256 hash of a file (first 64KB for speed).
pub fn calculate_hash(path: String) -> anyhow::Result<String> {
    let bytes = read_file_bytes(&path)?;
    let limit = 65536.min(bytes.len());
    Ok(crate::book::sha256_hex(&bytes[..limit]))
}

/// Extract table of contents without full chapter parsing.
pub fn parse_toc(path: String) -> anyhow::Result<Vec<TocEntry>> {
    let format = detect_format_from_path(&path).map_err(|e| anyhow::anyhow!("{}", e))?;
    let bytes = read_file_bytes(&path).map_err(|e| anyhow::anyhow!("{}", e))?;
    let book = dispatch_parse(&bytes, format).map_err(|e| anyhow::anyhow!("{}", e))?;
    Ok(book.toc)
}

/// Get format capabilities (what features a book format supports).
pub fn get_format_capabilities(path: String) -> anyhow::Result<FormatCapabilities> {
    let fmt = detect_format_from_path(&path)?;
    Ok(fmt.capabilities())
}

/// Detect the language of a text snippet using whatlang.
pub fn detect_chapter_language(text: String) -> anyhow::Result<ChapterLanguage> {
    let info =
        whatlang::detect(&text).ok_or_else(|| anyhow::anyhow!("Could not detect language"))?;
    Ok(ChapterLanguage {
        lang: info.lang().code().to_string(),
        confidence: info.confidence(),
    })
}

/// Generate import report: parse book and return structured statistics.
pub fn generate_import_report(path: String) -> anyhow::Result<ImportReport> {
    let format = detect_format_from_path(&path)?;
    let bytes = read_file_bytes(&path)?;
    let file_hash = crate::book::sha256_hex(&bytes);
    let start = std::time::Instant::now();
    let book = dispatch_parse(&bytes, format)?;
    let parse_time_ms = start.elapsed().as_millis() as u64;
    let blocks_count: usize = book.chapters.iter().map(|c| c.blocks.len()).sum();
    let images_count = book
        .chapters
        .iter()
        .flat_map(|c| &c.blocks)
        .filter(|b| b.block_type == crate::api::models::BlockType::Image)
        .count();
    Ok(ImportReport {
        format,
        parser_used: format!("{}-native", format.as_str()),
        chapters_count: book.chapters.len(),
        blocks_count,
        images_count,
        footnotes_count: 0,
        warnings: book.warnings,
        parse_time_ms,
        file_hash,
    })
}

/// Validate reading order: empty chapters, duplicates, spine/TOC mismatch.
pub fn validate_book(path: String) -> anyhow::Result<BookValidationResult> {
    let book = parse_book(path)?;
    let mut empty_chapters = Vec::new();
    let mut titles_seen = std::collections::HashSet::new();
    let mut duplicate_chapters = Vec::new();
    for ch in &book.chapters {
        if ch.blocks.is_empty() || (ch.blocks.len() == 1 && ch.blocks[0].text.trim().is_empty()) {
            empty_chapters.push(ch.index);
        }
        if !titles_seen.insert(ch.title.clone()) {
            duplicate_chapters.push(ch.index);
        }
    }
    let spine_toc_mismatch = !book.toc.is_empty()
        && book.toc.len() != book.chapters.len()
        && book
            .toc
            .iter()
            .any(|t| t.chapter_index >= book.chapters.len() as i32);
    Ok(BookValidationResult {
        valid: empty_chapters.is_empty() && duplicate_chapters.is_empty() && !spine_toc_mismatch,
        empty_chapters,
        duplicate_chapters,
        spine_toc_mismatch,
    })
}

/// Get asset metadata (IDs, types, sizes) without downloading bytes.
pub fn get_book_assets(path: String) -> anyhow::Result<Vec<BookAssetMeta>> {
    let book = parse_book(path)?;
    let mut assets = Vec::new();
    for ch in &book.chapters {
        for b in &ch.blocks {
            if let Some(url) = &b.image_url {
                assets.push(BookAssetMeta {
                    asset_id: url.clone(),
                    media_type: "image".to_string(),
                    size: 0,
                });
            }
        }
    }
    Ok(assets)
}

/// Lazy-load a single asset (image) from a book file by its asset_id (href).
pub fn get_asset_bytes(path: String, asset_id: String) -> anyhow::Result<Vec<u8>> {
    let format = detect_format_from_path(&path)?;
    let bytes = read_file_bytes(&path)?;

    match format {
        BookFormat::Epub => {
            let mut zip = crate::book::archive::decode_zip(&bytes)?;
            let entry = zip.find_file(&asset_id).or_else(|| {
                zip.entry_names()
                    .iter()
                    .find(|n| n.ends_with(&asset_id))
                    .cloned()
                    .and_then(|name| zip.find_file(&name))
            });
            Ok(entry.unwrap_or_default())
        }
        BookFormat::Docx => {
            let mut zip = crate::book::archive::decode_zip(&bytes)?;
            let entry = zip.find_file(&asset_id).or_else(|| {
                zip.entry_names()
                    .iter()
                    .find(|n| n.ends_with(&asset_id))
                    .cloned()
                    .and_then(|name| zip.find_file(&name))
            });
            Ok(entry.unwrap_or_default())
        }
        _ => Err(anyhow::anyhow!(
            "Asset extraction not supported for format: {:?}",
            format
        )),
    }
}

// ---------------------------------------------------------------------------
// Legacy byte-based API (still needed by some callers)
// ---------------------------------------------------------------------------

/// Extract blocks from HTML content using html5ever + scraper.
pub fn parse_html_blocks(html: String) -> anyhow::Result<Vec<ReaderBlock>> {
    let (blocks, _) = crate::book::html_parser::html_to_blocks(&html, 0);
    Ok(blocks)
}

pub fn parse_fb2(
    bytes: Vec<u8>,
    forced_encoding: Option<String>,
) -> anyhow::Result<NormalizedBook> {
    crate::book::fb2::parse_fb2(&bytes, forced_encoding.as_deref())
        .map_err(|e| anyhow::anyhow!("{}", e))
}

pub fn parse_epub(
    bytes: Vec<u8>,
    forced_encoding: Option<String>,
) -> anyhow::Result<NormalizedBook> {
    crate::book::epub::parse_epub(&bytes, forced_encoding.as_deref())
        .map_err(|e| anyhow::anyhow!("{}", e))
}

pub fn parse_txt(
    bytes: Vec<u8>,
    forced_encoding: Option<String>,
) -> anyhow::Result<NormalizedBook> {
    crate::book::txt::parse_txt(&bytes, forced_encoding.as_deref())
        .map_err(|e| anyhow::anyhow!("{}", e))
}

pub fn parse_docx(
    bytes: Vec<u8>,
    forced_encoding: Option<String>,
) -> anyhow::Result<NormalizedBook> {
    crate::book::docx::parse_docx(&bytes, forced_encoding.as_deref())
        .map_err(|e| anyhow::anyhow!("{}", e))
}

pub fn parse_rtf(
    bytes: Vec<u8>,
    forced_encoding: Option<String>,
) -> anyhow::Result<NormalizedBook> {
    crate::book::rtf::parse_rtf(&bytes, forced_encoding.as_deref())
        .map_err(|e| anyhow::anyhow!("{}", e))
}

pub fn parse_mobi(
    bytes: Vec<u8>,
    forced_encoding: Option<String>,
) -> anyhow::Result<NormalizedBook> {
    crate::book::mobi::parse_mobi(&bytes, forced_encoding.as_deref())
        .map_err(|e| anyhow::anyhow!("{}", e))
}

pub fn decode_zip_entries(bytes: Vec<u8>) -> anyhow::Result<Vec<String>> {
    let zip = crate::book::archive::decode_zip(&bytes)
        .map_err(|e| anyhow::anyhow!("Failed to decode ZIP: {}", e))?;
    Ok(zip.entry_names().to_vec())
}

pub fn extract_zip_entry(bytes: Vec<u8>, entry_name: String) -> anyhow::Result<Vec<u8>> {
    let mut zip = crate::book::archive::decode_zip(&bytes)
        .map_err(|e| anyhow::anyhow!("Failed to decode ZIP: {}", e))?;
    zip.find_file(&entry_name)
        .ok_or_else(|| anyhow::anyhow!("Entry '{}' not found in ZIP", entry_name))
}

pub fn detect_encoding(bytes: Vec<u8>) -> anyhow::Result<String> {
    Ok(crate::book::encoding::detect_encoding(&bytes).to_string())
}

/// Compute SHA-256 hash of bytes (first `max_bytes` only for efficiency).
pub fn sha256_hash(bytes: Vec<u8>, max_bytes: Option<usize>) -> anyhow::Result<String> {
    let limit = max_bytes.unwrap_or(bytes.len());
    let to_hash = &bytes[..bytes.len().min(limit)];
    Ok(crate::book::sha256_hex(to_hash))
}

/// Legacy dispatcher — kept for backward compat.
pub fn parse_book_legacy(
    bytes: Vec<u8>,
    format: String,
    forced_encoding: Option<String>,
) -> anyhow::Result<NormalizedBook> {
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

/// Render a PDF page as a PNG thumbnail.
#[cfg(feature = "pdf")]
pub fn render_pdf_thumbnail(path: String, page_index: u16, width: u16) -> anyhow::Result<Vec<u8>> {
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

#[cfg(not(feature = "pdf"))]
pub fn render_pdf_thumbnail(
    _path: String,
    _page_index: u16,
    _width: u16,
) -> anyhow::Result<Vec<u8>> {
    anyhow::bail!("PDF support is not enabled. Rebuild with --features pdf")
}
