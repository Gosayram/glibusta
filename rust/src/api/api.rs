use crate::api::models::{
    BookAssetMeta, BookDiff, BookFormat, BookMeta, BookValidationResult, ChapterLanguage,
    CoreError, FormatCapabilities, ImportReport, MAX_FILE_SIZE, MAX_IMAGE_SIZE, NormalizedBook,
    ReaderBlock, ReaderChapter, TocEntry,
};
use hyphenation::{Hyphenator, Language, Load, Standard};
use std::collections::HashMap;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::ops::Deref;
use std::path::Path;
use std::sync::{Arc, LazyLock, Mutex};
use std::time::Duration;
use unicode_segmentation::UnicodeSegmentation;

// ---------------------------------------------------------------------------
// ARC-8.1 + ARC-8.2 + ARC-8.3: Two-level cache (RAM + Disk)
// ---------------------------------------------------------------------------

#[cfg(not(miri))]
static BOOK_CACHE: LazyLock<moka::sync::Cache<String, NormalizedBook>> = LazyLock::new(|| {
    moka::sync::Cache::builder()
        .max_capacity(32)
        .time_to_idle(Duration::from_secs(600))
        .build()
});

/// Miri cannot model Moka's lock-free internals. A small mutex-protected cache
/// preserves the L1 cache contract while Miri validates our cache logic.
#[cfg(miri)]
static MIRI_BOOK_CACHE: LazyLock<Mutex<HashMap<String, NormalizedBook>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

fn memory_cache_get(fingerprint: &str) -> Option<NormalizedBook> {
    #[cfg(not(miri))]
    {
        BOOK_CACHE.get(fingerprint)
    }
    #[cfg(miri)]
    {
        MIRI_BOOK_CACHE
            .lock()
            .ok()
            .and_then(|cache| cache.get(fingerprint).cloned())
    }
}

fn memory_cache_store(fingerprint: String, book: NormalizedBook) {
    #[cfg(not(miri))]
    BOOK_CACHE.insert(fingerprint, book);
    #[cfg(miri)]
    if let Ok(mut cache) = MIRI_BOOK_CACHE.lock() {
        cache.insert(fingerprint, book);
    }
}

const DISK_CACHE_DIR_NAME: &str = "glibusta-book-cache";
const DISK_CACHE_MAX_ENTRIES: usize = 64;
const DISK_CACHE_TTL: Duration = Duration::from_secs(24 * 60 * 60);

/// Identifies a source file for caches that must never survive its replacement.
///
/// A path alone is not enough: imports and downloads may overwrite a file while
/// retaining its name. File size plus the modification timestamp are cheap to
/// read before parsing and invalidate both in-memory Moka and disk caches.
fn cache_fingerprint(path: &str) -> Result<String, CoreError> {
    let metadata = std::fs::metadata(path).map_err(|e| CoreError::IoError(e.to_string()))?;
    let modified = metadata
        .modified()
        .map_err(|e| CoreError::IoError(e.to_string()))?;
    let modified_nanos = modified
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(|e| CoreError::IoError(e.to_string()))?
        .as_nanos();
    Ok(format!("{path}:{}:{modified_nanos}", metadata.len()))
}

fn disk_cache_key(fingerprint: &str) -> std::path::PathBuf {
    // Keep cached books out of the temp root and use a stable cryptographic
    // digest rather than a process-dependent hash for the filename.
    std::env::temp_dir().join(DISK_CACHE_DIR_NAME).join(format!(
        "{}.bin",
        crate::book::sha256_hex(fingerprint.as_bytes())
    ))
}

fn disk_cache_lookup(key: &std::path::Path) -> Option<NormalizedBook> {
    let metadata = fs::symlink_metadata(key).ok()?;
    if metadata.file_type().is_symlink() || metadata.len() > MAX_FILE_SIZE {
        return None;
    }
    let data = fs::read(key).ok()?;
    postcard::from_bytes(&data).ok()
}

fn disk_cache_store(key: &std::path::Path, book: &NormalizedBook) {
    let Ok(data) = postcard::to_allocvec(book) else {
        return;
    };
    if data.len() as u64 > MAX_FILE_SIZE {
        return;
    }
    let Some(parent) = key.parent() else {
        return;
    };
    if fs::create_dir_all(parent).is_err() {
        return;
    }
    cleanup_disk_cache(parent);

    let temporary = parent.join(format!(".{}.tmp", uuid::Uuid::new_v4()));
    let result = (|| -> std::io::Result<()> {
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&temporary)?;
        file.write_all(&data)?;
        file.sync_all()?;
        fs::rename(&temporary, key)
    })();
    if result.is_err() {
        let _ = fs::remove_file(temporary);
    }
}

fn cleanup_disk_cache(directory: &Path) {
    let now = std::time::SystemTime::now();
    let mut entries = fs::read_dir(directory)
        .ok()
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|entry| {
            let path = entry.path();
            let metadata = fs::symlink_metadata(&path).ok()?;
            if !metadata.is_file() || metadata.len() > MAX_FILE_SIZE {
                return None;
            }
            let modified = metadata.modified().ok()?;
            if now
                .duration_since(modified)
                .is_ok_and(|age| age > DISK_CACHE_TTL)
            {
                let _ = fs::remove_file(path);
                return None;
            }
            Some((modified, path))
        })
        .collect::<Vec<_>>();
    entries.sort_unstable_by_key(|(modified, _)| *modified);
    let excess = entries
        .len()
        .saturating_sub(DISK_CACHE_MAX_ENTRIES.saturating_sub(1));
    for (_, path) in entries.into_iter().take(excess) {
        let _ = fs::remove_file(path);
    }
}

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

enum BookBytes {
    #[cfg(not(miri))]
    Mapped(memmap2::Mmap),
    #[cfg(miri)]
    Owned(Vec<u8>),
}

impl Deref for BookBytes {
    type Target = [u8];

    fn deref(&self) -> &[u8] {
        match self {
            #[cfg(not(miri))]
            Self::Mapped(bytes) => bytes,
            #[cfg(miri)]
            Self::Owned(bytes) => bytes,
        }
    }
}

/// Maps a file in production and uses an owned buffer under Miri, which does
/// not implement either file-backed or anonymous memory mappings.
fn map_file(path: &str) -> Result<BookBytes, CoreError> {
    let file = std::fs::File::open(path).map_err(|e| CoreError::IoError(e.to_string()))?;
    let size = file
        .metadata()
        .map_err(|e| CoreError::IoError(e.to_string()))?
        .len();
    if size > MAX_FILE_SIZE {
        return Err(CoreError::IoError(format!(
            "File exceeds maximum supported size: {} bytes (max {} bytes)",
            size, MAX_FILE_SIZE
        )));
    }
    #[cfg(miri)]
    {
        return fs::read(path)
            .map(BookBytes::Owned)
            .map_err(|e| CoreError::IoError(e.to_string()));
    }

    #[cfg(not(miri))]
    unsafe {
        memmap2::Mmap::map(&file)
            .map(BookBytes::Mapped)
            .map_err(|e| CoreError::IoError(e.to_string()))
    }
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
        BookFormat::Djvu => crate::book::djvu::DjvuEngine::parse_djvu(bytes)
            .map_err(|e| CoreError::ParserFailed(e.to_string())),
        BookFormat::Unknown => Err(CoreError::UnsupportedFormat("unknown".into())),
    }
}

// ---------------------------------------------------------------------------
// FRB-visible API — path-based, unified
// ---------------------------------------------------------------------------

/// Read a book from filesystem, detect format by extension, parse into NormalizedBook.
/// Two-level cache: L1 moka RAM (TTL 10min) → L2 file disk → parse.
pub fn parse_book(path: String) -> anyhow::Result<NormalizedBook> {
    let _span = tracing::info_span!("parse_book", path = %path).entered();
    let fingerprint = cache_fingerprint(&path).map_err(|e| anyhow::anyhow!("{e}"))?;
    // L1: RAM cache. Miri uses a mutex-protected equivalent of Moka.
    if let Some(cached) = memory_cache_get(&fingerprint) {
        tracing::info!("cache_hit_l1");
        return Ok(cached);
    }
    // L2: disk cache
    let cache_key = disk_cache_key(&fingerprint);
    if let Some(cached) = disk_cache_lookup(&cache_key) {
        memory_cache_store(fingerprint, cached.clone());
        return Ok(cached);
    }
    // Cache miss: parse from file
    let format = detect_format_from_path(&path).map_err(|e| anyhow::anyhow!("{}", e))?;
    let mmap = map_file(&path).map_err(|e| anyhow::anyhow!("{}", e))?;
    let mut book = dispatch_parse(&mmap, format).map_err(|e| anyhow::anyhow!("{}", e))?;
    book.book_format = format;
    // Store in both caches
    memory_cache_store(fingerprint, book.clone());
    disk_cache_store(&cache_key, &book);
    Ok(book)
}

/// RCE-1.4: Extract a single chapter from a book file.
pub fn parse_chapter(
    path: String,
    chapter_index: i32,
) -> anyhow::Result<crate::api::models::ReaderChapter> {
    let book = parse_book(path)?;
    book.chapters
        .into_iter()
        .find(|c| c.index == chapter_index)
        .ok_or_else(|| anyhow::anyhow!("Chapter {} not found", chapter_index))
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
    let bytes = map_file(&path).map_err(|e| anyhow::anyhow!("{}", e))?;

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
    let bytes = map_file(&path).map_err(|e| anyhow::anyhow!("{}", e))?;

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
    let bytes = map_file(&path)?;
    let limit = 65536.min(bytes.len());
    Ok(crate::book::sha256_hex(&bytes[..limit]))
}

/// Extract table of contents without full chapter parsing.
pub fn parse_toc(path: String) -> anyhow::Result<Vec<TocEntry>> {
    let format = detect_format_from_path(&path).map_err(|e| anyhow::anyhow!("{}", e))?;
    let bytes = map_file(&path).map_err(|e| anyhow::anyhow!("{}", e))?;
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
    let bytes = map_file(&path)?;
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
        && (book.toc.len() != book.chapters.len()
            || book
                .toc
                .iter()
                .any(|t| t.chapter_index >= book.chapters.len() as i32));
    Ok(BookValidationResult {
        valid: empty_chapters.is_empty() && duplicate_chapters.is_empty() && !spine_toc_mismatch,
        empty_chapters,
        duplicate_chapters,
        spine_toc_mismatch,
    })
}

/// Repair a book: remove empty chapters, deduplicate, fix TOC/chapter index mapping.
pub fn repair_book(path: String) -> anyhow::Result<NormalizedBook> {
    let mut book = parse_book(path)?;
    // Remove empty chapters and re-index
    let mut new_chapters = Vec::new();
    let mut old_to_new: std::collections::HashMap<i32, i32> = std::collections::HashMap::new();
    for ch in &book.chapters {
        let has_content = ch.blocks.iter().any(|b| !b.text.trim().is_empty());
        if has_content {
            let new_idx = new_chapters.len() as i32;
            old_to_new.insert(ch.index, new_idx);
            let mut fixed = ch.clone();
            fixed.index = new_idx;
            new_chapters.push(fixed);
        }
    }
    book.chapters = new_chapters;
    // Fix TOC chapter_index mapping
    for toc in &mut book.toc {
        if let Some(&new_idx) = old_to_new.get(&toc.chapter_index) {
            toc.chapter_index = new_idx;
        } else {
            toc.chapter_index = 0;
        }
    }
    // Deduplicate TOC by chapter_index
    let mut seen = std::collections::HashSet::new();
    book.toc.retain(|t| seen.insert(t.chapter_index));
    Ok(book)
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
    let bytes = map_file(&path)?;

    match format {
        BookFormat::Epub => {
            let mut zip = crate::book::archive::decode_zip(&bytes)?;
            read_archive_asset(&mut zip, &asset_id)
        }
        BookFormat::Docx => {
            let mut zip = crate::book::archive::decode_zip(&bytes)?;
            read_archive_asset(&mut zip, &asset_id)
        }
        _ => Err(anyhow::anyhow!(
            "Asset extraction not supported for format: {:?}",
            format
        )),
    }
}

fn read_archive_asset(
    zip: &mut crate::book::archive::ZipFile<'_>,
    asset_id: &str,
) -> anyhow::Result<Vec<u8>> {
    if let Some(entry) = zip.read_file_limited(asset_id, MAX_IMAGE_SIZE)? {
        return Ok(entry);
    }
    let matching_name = zip
        .entry_names()
        .iter()
        .find(|name| name.ends_with(asset_id))
        .cloned();
    match matching_name {
        Some(name) => Ok(zip
            .read_file_limited(&name, MAX_IMAGE_SIZE)?
            .unwrap_or_default()),
        None => Err(anyhow::anyhow!("Asset '{asset_id}' not found in archive")),
    }
}

/// Compare two books parsed from the same file at different times.
pub fn diff_parsed_book(old_path: String, new_path: String) -> anyhow::Result<BookDiff> {
    let old = parse_book(old_path)?;
    let new = parse_book(new_path)?;
    Ok(BookDiff::compute(&old, &new))
}

/// RCE-19.1: Find word break positions in a word for hyphenation.
/// Returns Vec of byte offsets where breaks can occur (before each grapheme cluster).
static HYPHENATORS: LazyLock<Mutex<HashMap<Language, Standard>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

/// RCE-19.2: Hyphenate a word using Knuth-Liang TeX patterns.
/// Returns byte positions where hyphenation is allowed.
/// Falls back to every-grapheme approach when the dictionary is unavailable.
pub fn hyphenate_word(word: String) -> Vec<usize> {
    let graphemes: Vec<&str> = word.graphemes(true).collect();
    let len = graphemes.len();
    if len < 3 {
        return Vec::new();
    }

    // Map language to Language enum for dictionary lookup
    let lang = detect_hyphen_lang(&word);

    if let Some(dict) = load_dictionary(lang) {
        let h = dict.hyphenate(&word);
        return h.breaks;
    }

    // Fallback: every grapheme break except first and last
    let mut positions = Vec::new();
    let mut byte_offset = 0;
    for (i, g) in graphemes.iter().enumerate() {
        byte_offset += g.len();
        if i >= 1 && i < len - 1 {
            positions.push(byte_offset);
        }
    }
    positions
}

fn load_dictionary(lang: Language) -> Option<Standard> {
    let mut map = HYPHENATORS.lock().ok()?;
    if let Some(dict) = map.get(&lang) {
        return Some(dict.clone());
    }
    match Standard::from_embedded(lang) {
        Ok(dict) => {
            map.insert(lang, dict.clone());
            Some(dict)
        }
        Err(_) => None,
    }
}

fn detect_hyphen_lang(word: &str) -> Language {
    // Simple heuristic: check for Cyrillic characters → Russian, else English
    if word
        .chars()
        .any(|c| ('\u{0400}'..='\u{04FF}').contains(&c) || c == 'ё' || c == 'Ё')
    {
        Language::Russian
    } else {
        Language::EnglishUS
    }
}

/// RCE-5.1: Search for a query across all chapters of a book.
/// Returns SearchMatch results with chapter/block positions and preview text.
pub fn search_in_book(
    path: String,
    query: String,
    limit: usize,
) -> anyhow::Result<Vec<crate::api::models::SearchMatch>> {
    use crate::api::models::SearchMatch;
    let book = parse_book(path)?;
    let ac = aho_corasick::AhoCorasick::new([&query])
        .map_err(|e| anyhow::anyhow!("Search error: {}", e))?;
    let mut results = Vec::new();
    let max_results = if limit == 0 { 100 } else { limit };
    'outer: for chapter in &book.chapters {
        for block in &chapter.blocks {
            for mat in ac.find_iter(&block.text) {
                let start = mat.start();
                let end = mat.end();
                let preview_len = 40usize;
                let preview_start =
                    floor_char_boundary(&block.text, start.saturating_sub(preview_len));
                let preview_end =
                    ceil_char_boundary(&block.text, (end + preview_len).min(block.text.len()));
                let preview = format!(
                    "...{}...",
                    block.text[preview_start..preview_end].replace('\n', " ")
                );
                results.push(SearchMatch {
                    chapter_index: chapter.index,
                    block_index: block.index,
                    span_start: start,
                    span_end: end,
                    preview,
                });
                if results.len() >= max_results {
                    break 'outer;
                }
            }
        }
    }
    Ok(results)
}

fn floor_char_boundary(text: &str, mut index: usize) -> usize {
    index = index.min(text.len());
    while index > 0 && !text.is_char_boundary(index) {
        index -= 1;
    }
    index
}

fn ceil_char_boundary(text: &str, mut index: usize) -> usize {
    index = index.min(text.len());
    while index < text.len() && !text.is_char_boundary(index) {
        index += 1;
    }
    index
}

/// CRT-20.2: Render PDF page to PNG thumbnail.
/// Requires `pdf` feature flag and PDFium binary.
#[cfg(feature = "pdf")]
pub fn render_pdf_thumbnail(
    path: String,
    page_index: usize,
    max_width: usize,
) -> anyhow::Result<Vec<u8>> {
    let bytes = map_file(&path)?;
    let engine = crate::book::pdf::PdfEngine::new()?;
    engine.render_page_to_png(&bytes, page_index, max_width as u16)
}

/// CRT-20.3: Extract text from PDF for search.
#[cfg(feature = "pdf")]
pub fn extract_pdf_text(path: String) -> anyhow::Result<String> {
    let bytes = map_file(&path)?;
    let engine = crate::book::pdf::PdfEngine::new()?;
    engine.extract_text(&bytes)
}

/// Get PDF page count.
#[cfg(feature = "pdf")]
pub fn pdf_page_count(path: String) -> anyhow::Result<i32> {
    let bytes = map_file(&path)?;
    let engine = crate::book::pdf::PdfEngine::new()?;
    engine.page_count(&bytes)
}

/// Stub: PDF thumbnail not available without pdf feature.
#[cfg(not(feature = "pdf"))]
pub fn render_pdf_thumbnail(
    _path: String,
    _page_index: usize,
    _max_width: usize,
) -> anyhow::Result<Vec<u8>> {
    anyhow::bail!("PDF support disabled. Rebuild with --features pdf")
}

/// Stub: PDF text extraction not available without pdf feature.
#[cfg(not(feature = "pdf"))]
pub fn extract_pdf_text(_path: String) -> anyhow::Result<String> {
    anyhow::bail!("PDF support disabled. Rebuild with --features pdf")
}

/// Stub: PDF page count not available without pdf feature.
#[cfg(not(feature = "pdf"))]
pub fn pdf_page_count(_path: String) -> anyhow::Result<i32> {
    anyhow::bail!("PDF support disabled. Rebuild with --features pdf")
}

// ---------------------------------------------------------------------------
// CRT-20.4/20.5: DjVu rendering and text extraction via djvu-rs (pure Rust)
// ---------------------------------------------------------------------------

/// CRT-20.4: Render DjVu page to PNG thumbnail.
pub fn render_djvu_thumbnail(
    path: String,
    page_index: usize,
    max_width: usize,
) -> anyhow::Result<Vec<u8>> {
    let bytes = map_file(&path)?;
    crate::book::djvu::DjvuEngine::render_page_to_png(&bytes, page_index, max_width as u16)
}

/// CRT-20.5: Extract text from DjVu document (from all pages' OCR/embedded text layers).
pub fn extract_djvu_text(path: String) -> anyhow::Result<String> {
    let bytes = map_file(&path)?;
    crate::book::djvu::DjvuEngine::extract_text(&bytes)
}

/// Get DjVu page count.
pub fn djvu_page_count(path: String) -> anyhow::Result<i32> {
    let bytes = map_file(&path)?;
    crate::book::djvu::DjvuEngine::page_count(&bytes)
}

/// RCE-1.6/2.2: Check if cached book needs reparse by comparing file hash.
/// Returns (needs_reparse, file_hash, file_size).
pub fn check_book_cache(path: String) -> anyhow::Result<(bool, String, u64)> {
    let bytes = map_file(&path)?;
    let file_hash = crate::book::sha256_hex(&bytes);
    let file_size = bytes.len() as u64;
    let fingerprint = cache_fingerprint(&path).map_err(|e| anyhow::anyhow!("{e}"))?;
    let cache_key = disk_cache_key(&fingerprint);
    let has_cached_book =
        memory_cache_get(&fingerprint).is_some() || disk_cache_lookup(&cache_key).is_some();
    Ok((!has_cached_book, file_hash, file_size))
}

// ---------------------------------------------------------------------------
// ARC-1.1: Opaque BookEngine — data stays in Rust heap
// ---------------------------------------------------------------------------

/// Opaque handle to a parsed book. Data lives in Rust-heap,
/// Dart gets only the handle (pointer). Chapters/blocks copied on demand.
pub struct BookEngine {
    inner: Mutex<Option<NormalizedBook>>,
}

impl BookEngine {
    pub fn new(book: NormalizedBook) -> Self {
        Self {
            inner: Mutex::new(Some(book)),
        }
    }

    pub fn get_chapter(&self, index: usize) -> Option<ReaderChapter> {
        self.inner
            .lock()
            .ok()?
            .as_ref()?
            .chapters
            .get(index)
            .cloned()
    }

    pub fn chapter_count(&self) -> usize {
        self.inner
            .lock()
            .ok()
            .and_then(|b| b.as_ref().map(|b| b.chapters.len()))
            .unwrap_or(0)
    }

    pub fn title(&self) -> String {
        self.inner
            .lock()
            .ok()
            .and_then(|b| b.as_ref().map(|b| b.title.clone()))
            .unwrap_or_default()
    }

    pub fn drop_engine(&self) {
        if let Ok(mut guard) = self.inner.lock() {
            *guard = None;
        }
    }
}

/// ARC-1.1: Open book and return opaque handle.
pub fn open_book_engine(path: String) -> anyhow::Result<Arc<BookEngine>> {
    let book = parse_book(path)?;
    Ok(Arc::new(BookEngine::new(book)))
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
        .map_err(|e| anyhow::anyhow!("Failed to extract ZIP entry: {}", e))?
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
