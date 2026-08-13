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
    serde_json::from_slice(&data).ok()
}

fn disk_cache_store(key: &std::path::Path, book: &NormalizedBook) {
    // The public model uses `skip_serializing_if`, which is not round-trippable
    // in postcard's positional struct encoding. JSON preserves omitted optional
    // fields and makes older binary cache entries safely degrade to a cache miss.
    let Ok(data) = serde_json::to_vec(book) else {
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
    let mut book = match format {
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
        BookFormat::Cbr => Err(CoreError::FeatureDisabled(
            "CBR parsing requires a filesystem path".into(),
        )),
        BookFormat::Cbz => Err(CoreError::FeatureDisabled(
            "CBZ parsing requires a filesystem path".into(),
        )),
        BookFormat::Unknown => Err(CoreError::UnsupportedFormat("unknown".into())),
    }?;
    crate::book::postprocess_chapters(&mut book.chapters);
    Ok(book)
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
    // Path-based formats that need filesystem access
    if format == BookFormat::Cbz {
        let book = crate::book::cbz::parse_cbz_path(Path::new(&path))
            .map_err(|e| anyhow::anyhow!("{e}"))?;
        let book = repair_normalized_book(book);
        memory_cache_store(fingerprint, book.clone());
        disk_cache_store(&cache_key, &book);
        return Ok(book);
    }
    let mmap = map_file(&path).map_err(|e| anyhow::anyhow!("{}", e))?;
    let mut book = dispatch_parse(&mmap, format).map_err(|e| anyhow::anyhow!("{}", e))?;
    book.book_format = format;
    if format == BookFormat::Txt {
        apply_txt_filename_author(&mut book, Path::new(&path));
    }
    // Store in both caches
    memory_cache_store(fingerprint, book.clone());
    disk_cache_store(&cache_key, &book);
    Ok(book)
}

/// TXT has no reliable embedded author metadata.  Use a conservative
/// `Author - Title.txt` filename fallback only for path-based imports and only
/// when the parser did not already provide an author.
fn apply_txt_filename_author(book: &mut NormalizedBook, path: &Path) {
    if !book.authors.is_empty() {
        return;
    }
    let Some(stem) = path.file_stem().and_then(|stem| stem.to_str()) else {
        return;
    };
    let author = [" — ", " – ", " - "]
        .iter()
        .find_map(|separator| stem.split_once(separator).map(|(author, _)| author.trim()))
        .filter(|author| !author.is_empty() && author.chars().any(char::is_alphabetic));
    if let Some(author) = author {
        book.authors.push(author.to_string());
    }
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

/// Extract metadata without full chapter parsing.
pub fn extract_metadata(path: String) -> anyhow::Result<BookMeta> {
    let format = detect_format_from_path(&path).map_err(|e| anyhow::anyhow!("{}", e))?;
    let bytes = map_file(&path).map_err(|e| anyhow::anyhow!("{}", e))?;

    let book = dispatch_parse(&bytes, format).map_err(|e| anyhow::anyhow!("{}", e))?;

    let genres = book
        .metadata
        .as_ref()
        .and_then(|metadata| metadata.get("genres"))
        .and_then(serde_json::Value::as_array)
        .map(|genres| {
            genres
                .iter()
                .filter_map(serde_json::Value::as_str)
                .map(str::to_owned)
                .collect()
        })
        .unwrap_or_default();

    Ok(BookMeta {
        title: book.title,
        authors: book.authors,
        description: book.description,
        language: book.language,
        genres,
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
        return decode_cover_data_uri(cover_b64, MAX_IMAGE_SIZE);
    }
    Ok(Vec::new())
}

fn decode_cover_data_uri(cover_url: &str, max_size: usize) -> anyhow::Result<Vec<u8>> {
    let encoded = if let Some(data_uri) = cover_url.strip_prefix("data:") {
        let (metadata, payload) = data_uri
            .split_once(',')
            .ok_or_else(|| anyhow::anyhow!("Cover data URI is missing its payload"))?;
        if !metadata.ends_with(";base64") {
            anyhow::bail!("Cover data URI is not base64-encoded");
        }
        payload
    } else {
        // Preserve compatibility with cached books created before cover URLs
        // were consistently emitted as data URIs.
        cover_url
    };

    let max_encoded_size = max_size
        .checked_add(2)
        .and_then(|size| size.checked_div(3))
        .and_then(|groups| groups.checked_mul(4))
        .unwrap_or(usize::MAX);
    if encoded.len() > max_encoded_size {
        anyhow::bail!("Encoded cover exceeds maximum size of {max_size} bytes");
    }

    use base64::Engine;
    let decoded = base64::engine::general_purpose::STANDARD
        .decode(encoded)
        .map_err(|error| anyhow::anyhow!("Failed to decode cover base64: {error}"))?;
    if decoded.len() > max_size {
        anyhow::bail!("Cover exceeds maximum size of {max_size} bytes");
    }

    Ok(decoded)
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
        if !chapter_has_renderable_content(ch) {
            empty_chapters.push(ch.index);
        }
        if !titles_seen.insert(ch.title.clone()) {
            duplicate_chapters.push(ch.index);
        }
    }
    let spine_toc_mismatch = !book.toc.is_empty()
        && (book.toc.len() != book.chapters.len()
            || toc_has_invalid_chapter(&book.toc, book.chapters.len() as i32));
    Ok(BookValidationResult {
        valid: empty_chapters.is_empty() && duplicate_chapters.is_empty() && !spine_toc_mismatch,
        empty_chapters,
        duplicate_chapters,
        spine_toc_mismatch,
    })
}

fn chapter_has_renderable_content(chapter: &ReaderChapter) -> bool {
    chapter.blocks.iter().any(|block| {
        !block.text.trim().is_empty()
            || block.image_url.is_some()
            || block.list_items.is_some()
            || block.table_rows.is_some()
            || matches!(
                block.block_type,
                crate::api::models::BlockType::Image
                    | crate::api::models::BlockType::List
                    | crate::api::models::BlockType::Table
            )
    })
}

fn toc_has_invalid_chapter(entries: &[TocEntry], chapter_count: i32) -> bool {
    entries.iter().any(|entry| {
        entry.chapter_index < 0
            || entry.chapter_index >= chapter_count
            || toc_has_invalid_chapter(&entry.children, chapter_count)
    })
}

/// Repair a book: remove empty chapters, deduplicate, fix TOC/chapter index mapping.
pub fn repair_book(path: String) -> anyhow::Result<NormalizedBook> {
    Ok(repair_normalized_book(parse_book(path)?))
}

fn repair_normalized_book(mut book: NormalizedBook) -> NormalizedBook {
    // Auto-populate metadata_json from metadata for Dart-side access
    if book.metadata_json.is_none() {
        if let Some(ref m) = book.metadata {
            if let Ok(json) = serde_json::to_string(m) {
                book.metadata_json = Some(json);
            }
        }
    }
    // Remove empty chapters and re-index
    let mut new_chapters = Vec::new();
    let mut old_to_new: std::collections::HashMap<i32, i32> = std::collections::HashMap::new();
    for ch in &book.chapters {
        if chapter_has_renderable_content(ch) {
            let new_idx = new_chapters.len() as i32;
            old_to_new.insert(ch.index, new_idx);
            let mut fixed = ch.clone();
            fixed.index = new_idx;
            new_chapters.push(fixed);
        }
    }
    book.chapters = new_chapters;
    // Keep only TOC entries that still point to a retained chapter before
    // deduplication. Reassigning invalid entries to zero could discard the
    // legitimate first chapter entry.
    repair_toc_entries(&mut book.toc, &old_to_new);
    // Deduplicate TOC by chapter_index
    let mut seen = std::collections::HashSet::new();
    book.toc.retain(|t| {
        t.chapter_index >= 0
            && (t.chapter_index as usize) < book.chapters.len()
            && seen.insert(t.chapter_index)
    });
    book
}

fn repair_toc_entries(
    entries: &mut Vec<TocEntry>,
    old_to_new: &std::collections::HashMap<i32, i32>,
) {
    entries.retain(|entry| old_to_new.contains_key(&entry.chapter_index));
    for entry in entries {
        entry.chapter_index = old_to_new[&entry.chapter_index];
        repair_toc_entries(&mut entry.children, old_to_new);
    }
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
        BookFormat::Cbz => {
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
    let requested_name = Path::new(asset_id)
        .file_name()
        .and_then(|name| name.to_str())
        .filter(|name| !name.is_empty())
        .ok_or_else(|| anyhow::anyhow!("Asset ID must include a file name"))?;
    if let Some(entry) = zip.read_file_limited(asset_id, MAX_IMAGE_SIZE)? {
        return Ok(entry);
    }
    let matching_name = zip
        .entry_names()
        .iter()
        .find(|name| {
            Path::new(name).file_name().and_then(|name| name.to_str()) == Some(requested_name)
        })
        .cloned();
    match matching_name {
        Some(name) => zip
            .read_file_limited(&name, MAX_IMAGE_SIZE)?
            .ok_or_else(|| anyhow::anyhow!("Asset '{asset_id}' is no longer available in archive")),
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
    if query.is_empty() {
        return Ok(Vec::new());
    }
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
                let preview_end = ceil_char_boundary(
                    &block.text,
                    end.saturating_add(preview_len).min(block.text.len()),
                );
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

fn validate_legacy_input_size(bytes: &[u8], max_size: u64) -> anyhow::Result<()> {
    if bytes.len() as u64 > max_size {
        anyhow::bail!(
            "Book data exceeds maximum size of {} MiB",
            max_size / 1024 / 1024
        );
    }
    Ok(())
}

/// Extract blocks from HTML content using html5ever + scraper.
pub fn parse_html_blocks(html: String) -> anyhow::Result<Vec<ReaderBlock>> {
    let (blocks, _) = crate::book::html_parser::html_to_blocks(&html, 0);
    Ok(blocks)
}

pub fn parse_fb2(
    bytes: Vec<u8>,
    forced_encoding: Option<String>,
) -> anyhow::Result<NormalizedBook> {
    validate_legacy_input_size(&bytes, MAX_FILE_SIZE)?;
    crate::book::fb2::parse_fb2(&bytes, forced_encoding.as_deref())
        .map_err(|e| anyhow::anyhow!("{}", e))
}

pub fn parse_epub(
    bytes: Vec<u8>,
    forced_encoding: Option<String>,
) -> anyhow::Result<NormalizedBook> {
    validate_legacy_input_size(&bytes, MAX_FILE_SIZE)?;
    crate::book::epub::parse_epub(&bytes, forced_encoding.as_deref())
        .map_err(|e| anyhow::anyhow!("{}", e))
}

pub fn parse_txt(
    bytes: Vec<u8>,
    forced_encoding: Option<String>,
) -> anyhow::Result<NormalizedBook> {
    validate_legacy_input_size(&bytes, MAX_FILE_SIZE)?;
    crate::book::txt::parse_txt(&bytes, forced_encoding.as_deref())
        .map_err(|e| anyhow::anyhow!("{}", e))
}

pub fn parse_docx(
    bytes: Vec<u8>,
    forced_encoding: Option<String>,
) -> anyhow::Result<NormalizedBook> {
    validate_legacy_input_size(&bytes, MAX_FILE_SIZE)?;
    crate::book::docx::parse_docx(&bytes, forced_encoding.as_deref())
        .map_err(|e| anyhow::anyhow!("{}", e))
}

pub fn parse_rtf(
    bytes: Vec<u8>,
    forced_encoding: Option<String>,
) -> anyhow::Result<NormalizedBook> {
    validate_legacy_input_size(&bytes, MAX_FILE_SIZE)?;
    crate::book::rtf::parse_rtf(&bytes, forced_encoding.as_deref())
        .map_err(|e| anyhow::anyhow!("{}", e))
}

pub fn parse_mobi(
    bytes: Vec<u8>,
    forced_encoding: Option<String>,
) -> anyhow::Result<NormalizedBook> {
    validate_legacy_input_size(&bytes, MAX_FILE_SIZE)?;
    crate::book::mobi::parse_mobi(&bytes, forced_encoding.as_deref())
        .map_err(|e| anyhow::anyhow!("{}", e))
}

/// Parse a CBR/RAR comic from a filesystem path.
///
/// The native UnRAR API is path-based, so unlike the legacy parsers this
/// entry point deliberately does not accept an in-memory byte buffer.
pub fn parse_cbr(path: String) -> anyhow::Result<NormalizedBook> {
    crate::book::cbr::parse_cbr_path(Path::new(&path)).map_err(|e| anyhow::anyhow!("{e}"))
}

/// Parse a CBZ (comic book ZIP) from a filesystem path.
pub fn parse_cbz(path: String) -> anyhow::Result<NormalizedBook> {
    crate::book::cbz::parse_cbz_path(Path::new(&path)).map_err(|e| anyhow::anyhow!("{e}"))
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

/// Quality scoring for Russian/English text decoding.
/// Returns 0.0–1.0 where higher is better. Catches cases where
/// a charset detector confidently returns the wrong encoding.
pub fn score_encoding_quality(text: String) -> f64 {
    if text.is_empty() {
        return 0.0;
    }
    let sample: String = if text.len() > 20000 {
        text.chars().take(20000).collect()
    } else {
        text
    };

    let mut score: f64 = 1.0;

    // Penalize replacement characters (U+FFFD)
    let replacement_count = sample.chars().filter(|&c| c == '\u{FFFD}').count();
    score -= replacement_count as f64 * 0.08;

    // Penalize control characters (except common whitespace: \t \n \r and space)
    let control_count = sample
        .chars()
        .filter(|&c| {
            ('\x00'..='\x08').contains(&c)
                || c == '\x0B'
                || c == '\x0C'
                || ('\x0E'..='\x1F').contains(&c)
        })
        .count();
    score -= control_count as f64 * 0.04;

    // Penalize mojibake patterns (common in wrong-encoding decode)
    let chars: Vec<char> = sample.chars().collect();
    let mojibake_count = chars
        .windows(2)
        .filter(|w| matches!(w[0], 'Р' | 'С' | 'Ð' | 'Ñ' | 'â' | 'Ã'))
        .count();
    score -= mojibake_count as f64 * 0.03;

    // Reward letter density
    let cyrillic_count = sample
        .chars()
        .filter(|c| ('\u{0400}'..='\u{04FF}').contains(c) || *c == 'ё' || *c == 'Ё')
        .count();
    let latin_count = sample.chars().filter(|c| c.is_ascii_alphabetic()).count();
    let letters_count = cyrillic_count + latin_count;
    if (letters_count as f64) < (sample.len() as f64 * 0.20) {
        score -= 0.25;
    }

    // Reward whitespace density (normal text has spaces/newlines)
    let whitespace_count = sample.chars().filter(|c| c.is_whitespace()).count();
    if (whitespace_count as f64) < (sample.len() as f64 * 0.05) {
        score -= 0.15;
    }

    // Reward common Russian words (simple contains with word-boundary heuristic)
    let lower = sample.to_lowercase();
    let common_words = [
        "и",
        "в",
        "не",
        "на",
        "что",
        "он",
        "она",
        "как",
        "это",
        "его",
        "книга",
        "глава",
    ];
    let common_hits = common_words
        .iter()
        .filter(|word| {
            // Check if word appears as a whole word (surrounded by non-alphanumeric or at boundaries)
            if let Some(pos) = lower.find(*word) {
                let before_ok = pos == 0 || !lower.as_bytes()[pos - 1].is_ascii_alphanumeric();
                let after_pos = pos + word.len();
                let after_ok = after_pos >= lower.len()
                    || !lower.as_bytes()[after_pos].is_ascii_alphanumeric();
                before_ok && after_ok
            } else {
                false
            }
        })
        .count();
    score += common_hits as f64 * 0.02;

    score.clamp(0.0, 1.0)
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

#[cfg(test)]
mod cover_data_uri_tests {
    use super::{decode_cover_data_uri, validate_legacy_input_size};

    #[test]
    fn decodes_base64_data_uri() {
        let decoded = decode_cover_data_uri("data:image/png;base64,Y292ZXI=", 5).unwrap();

        assert_eq!(decoded, b"cover");
    }

    #[test]
    fn rejects_oversized_encoded_cover_before_decoding() {
        let error = decode_cover_data_uri("data:image/png;base64,Y292ZXI=", 3).unwrap_err();

        assert!(error.to_string().contains("Encoded cover exceeds"));
    }

    #[test]
    fn rejects_oversized_legacy_input_before_parsing() {
        let error = validate_legacy_input_size(&[0, 1], 1).unwrap_err();

        assert!(error.to_string().contains("Book data exceeds"));
    }
}

#[cfg(test)]
mod document_open_smoke_tests {
    use super::{djvu_page_count, extract_djvu_text, render_djvu_thumbnail};
    use std::panic::{AssertUnwindSafe, catch_unwind};

    // A minimal single-page document. Keeping this local makes the path-API
    // smoke test independent from parser integration fixtures.
    const MINIMAL_DJVU: &[u8] = &[
        0x41, 0x54, 0x26, 0x54, 0x46, 0x4f, 0x52, 0x4d, 0x00, 0x00, 0x00, 0x20, 0x44, 0x4a, 0x56,
        0x55, 0x49, 0x4e, 0x46, 0x4f, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x02, 0x00, 0x02, 0x18, 0x00,
        0x2c, 0x01, 0x16, 0x01, 0x53, 0x6a, 0x62, 0x7a, 0x00, 0x00, 0x00, 0x02, 0xab, 0x7f,
    ];

    fn malformed_djvu_path() -> std::path::PathBuf {
        let path = std::env::temp_dir().join(format!(
            "glibusta-malformed-djvu-{}.djvu",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(&path, b"this is not a DjVu document")
            .expect("write malformed DjVu fixture");
        path
    }

    fn missing_djvu_path() -> String {
        std::env::temp_dir()
            .join(format!(
                "glibusta-missing-djvu-{}.djvu",
                uuid::Uuid::new_v4()
            ))
            .to_string_lossy()
            .into_owned()
    }

    #[test]
    fn malformed_djvu_is_reported_by_every_path_api_without_panicking() {
        let path = malformed_djvu_path();
        let path_text = path.to_string_lossy().into_owned();

        let page_count = catch_unwind(AssertUnwindSafe(|| djvu_page_count(path_text.clone())));
        let text = catch_unwind(AssertUnwindSafe(|| extract_djvu_text(path_text.clone())));
        let thumbnail = catch_unwind(AssertUnwindSafe(|| {
            render_djvu_thumbnail(path_text, 0, 1080)
        }));

        let _ = std::fs::remove_file(path);

        assert!(page_count.expect("page count must not panic").is_err());
        assert!(text.expect("text extraction must not panic").is_err());
        assert!(
            thumbnail
                .expect("thumbnail rendering must not panic")
                .is_err()
        );
    }

    #[test]
    fn missing_djvu_is_reported_by_every_path_api_without_panicking() {
        let path = missing_djvu_path();

        let page_count = catch_unwind(AssertUnwindSafe(|| djvu_page_count(path.clone())));
        let text = catch_unwind(AssertUnwindSafe(|| extract_djvu_text(path.clone())));
        let thumbnail = catch_unwind(AssertUnwindSafe(|| render_djvu_thumbnail(path, 0, 1080)));

        assert!(page_count.expect("page count must not panic").is_err());
        assert!(text.expect("text extraction must not panic").is_err());
        assert!(
            thumbnail
                .expect("thumbnail rendering must not panic")
                .is_err()
        );
    }

    #[test]
    fn djvu_path_api_accepts_a_cyrillic_filename() {
        let path =
            std::env::temp_dir().join(format!("glibusta-книга-{}.djvu", uuid::Uuid::new_v4()));
        std::fs::write(&path, MINIMAL_DJVU).expect("write DjVu fixture with a Cyrillic name");

        let page_count = djvu_page_count(path.to_string_lossy().into_owned());

        let _ = std::fs::remove_file(path);
        assert_eq!(
            page_count.expect("Cyrillic path must reach the DjVu parser"),
            1
        );
    }

    #[cfg(not(feature = "pdf"))]
    #[test]
    fn disabled_pdf_ffi_api_returns_a_controlled_error() {
        let error = super::pdf_page_count("ignored.pdf".to_string())
            .expect_err("PDF API must report that the optional native engine is disabled");

        assert!(error.to_string().contains("PDF support disabled"));
    }
}

#[cfg(test)]
mod parse_api_tests {
    use super::{
        MAX_FILE_SIZE, apply_txt_filename_author, disk_cache_lookup, disk_cache_store, parse_book,
        parse_book_legacy, read_archive_asset, repair_normalized_book, search_in_book,
        toc_has_invalid_chapter,
    };
    use crate::api::models::{BlockType, TocEntry};
    use std::io::{Cursor, Write};
    use std::path::Path;

    #[test]
    fn path_and_legacy_txt_parsers_return_the_same_book() {
        let bytes = b"A test book\n\nChapter 1\n\nText of the chapter.".to_vec();
        let path = std::env::temp_dir().join(format!(
            "glibusta-parser-parity-{}.txt",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(&path, &bytes).expect("write temporary TXT file");

        let result = (|| {
            let path_book = parse_book(path.to_string_lossy().into_owned())?;
            let legacy_book = parse_book_legacy(bytes, "txt".to_owned(), None)?;
            anyhow::Result::<_>::Ok((path_book, legacy_book))
        })();
        let _ = std::fs::remove_file(&path);

        let (path_book, legacy_book) = result.expect("parse temporary TXT file");
        assert_eq!(
            serde_json::to_value(path_book).expect("serialize path book"),
            serde_json::to_value(legacy_book).expect("serialize legacy book"),
        );
    }

    #[test]
    fn nested_path_rtf_parser_preserves_the_same_bytes_as_legacy_import() {
        let bytes = br"{\rtf1\ansi First paragraph.\par Second paragraph.\par}".to_vec();
        let directory = std::env::temp_dir().join(format!(
            "glibusta-rtf-subdirectory-{}",
            uuid::Uuid::new_v4()
        ));
        let path = directory.join("nested").join("book.rtf");
        std::fs::create_dir_all(path.parent().expect("nested RTF parent"))
            .expect("create nested RTF directory");
        std::fs::write(&path, &bytes).expect("write nested RTF fixture");

        let result = (|| {
            let path_book = parse_book(path.to_string_lossy().into_owned())?;
            let legacy_book = parse_book_legacy(bytes, "rtf".to_owned(), None)?;
            anyhow::Result::<_>::Ok((path_book, legacy_book))
        })();
        let _ = std::fs::remove_dir_all(directory);

        let (path_book, legacy_book) = result.expect("parse nested RTF through both APIs");
        assert_eq!(
            serde_json::to_value(path_book).expect("serialize path book"),
            serde_json::to_value(legacy_book).expect("serialize legacy book"),
        );
    }

    #[test]
    fn txt_path_import_uses_author_from_filename_without_replacing_book_title() {
        let path = std::env::temp_dir().join(format!(
            "Тестовый Автор - filename-metadata-{}.txt",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(&path, "Declared title\n\nBook content.").expect("write temporary TXT file");

        let result = parse_book(path.to_string_lossy().into_owned());
        let _ = std::fs::remove_file(&path);
        let book = result.expect("parse temporary TXT file");

        assert_eq!(book.title, "Declared title");
        assert_eq!(book.authors, ["Тестовый Автор"]);
    }

    #[test]
    fn txt_filename_author_does_not_replace_declared_metadata() {
        let mut book = parse_book_legacy(
            b"Declared title\n\nBook content.".to_vec(),
            "txt".to_owned(),
            None,
        )
        .expect("parse TXT fixture");
        book.authors = vec!["Declared author".to_string()];

        apply_txt_filename_author(&mut book, Path::new("Filename author - filename title.txt"));

        assert_eq!(book.authors, ["Declared author"]);
    }

    #[test]
    fn disk_cache_round_trips_and_ignores_corrupted_data() {
        let directory =
            std::env::temp_dir().join(format!("glibusta-disk-cache-test-{}", uuid::Uuid::new_v4()));
        let key = directory.join("book.bin");
        let book = parse_book_legacy(
            b"Cached title\n\nCached body.".to_vec(),
            "txt".to_owned(),
            None,
        )
        .expect("parse cache fixture");

        disk_cache_store(&key, &book);
        let cached = disk_cache_lookup(&key).expect("deserialize cached book");
        assert_eq!(
            serde_json::to_value(cached).expect("serialize cached book"),
            serde_json::to_value(book).expect("serialize source book"),
        );

        std::fs::write(&key, b"corrupted disk cache").expect("corrupt cache fixture");
        assert!(disk_cache_lookup(&key).is_none());

        let _ = std::fs::remove_dir_all(directory);
    }

    #[test]
    fn path_parser_rejects_oversized_file_before_mapping() {
        let path = std::env::temp_dir().join(format!(
            "glibusta-parser-oversize-{}.txt",
            uuid::Uuid::new_v4()
        ));
        std::fs::File::create(&path)
            .and_then(|file| file.set_len(MAX_FILE_SIZE + 1))
            .expect("create oversized sparse TXT file");

        let error = parse_book(path.to_string_lossy().into_owned())
            .expect_err("oversized file must be rejected before mapping");
        let _ = std::fs::remove_file(&path);

        assert!(
            error
                .to_string()
                .contains("File exceeds maximum supported size")
        );
    }

    #[test]
    fn repair_keeps_chapter_with_renderable_image_only() {
        let mut book = parse_book_legacy(b"Book title".to_vec(), "txt".to_owned(), None)
            .expect("parse fixture book");
        let chapter = &mut book.chapters[0];
        chapter.index = 7;
        chapter.blocks[0].text.clear();
        chapter.blocks[0].block_type = BlockType::Image;
        chapter.blocks[0].image_url = Some("images/cover.jpg".to_string());
        book.toc = vec![TocEntry {
            title: "Illustration".to_string(),
            chapter_index: 7,
            children: Vec::new(),
        }];

        let repaired = repair_normalized_book(book);

        assert_eq!(repaired.chapters.len(), 1);
        assert_eq!(repaired.chapters[0].index, 0);
        assert_eq!(repaired.toc[0].chapter_index, 0);
    }

    #[test]
    fn repair_removes_invalid_nested_toc_entries() {
        let mut book = parse_book_legacy(b"Book title".to_vec(), "txt".to_owned(), None)
            .expect("parse fixture book");
        book.toc = vec![TocEntry {
            title: "Chapter".to_string(),
            chapter_index: 0,
            children: vec![TocEntry {
                title: "Missing section".to_string(),
                chapter_index: 99,
                children: Vec::new(),
            }],
        }];

        let repaired = repair_normalized_book(book);

        assert!(repaired.toc[0].children.is_empty());
    }

    #[test]
    fn toc_validation_rejects_negative_chapter_indices() {
        let toc = [TocEntry {
            title: "Missing chapter".to_string(),
            chapter_index: -1,
            children: Vec::new(),
        }];

        assert!(toc_has_invalid_chapter(&toc, 1));
    }

    #[test]
    fn search_with_empty_query_returns_no_zero_length_matches() {
        let path = std::env::temp_dir().join(format!(
            "glibusta-empty-search-{}.txt",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(&path, b"A searchable title\n\nSome searchable text.")
            .expect("write temporary TXT file");

        let result = search_in_book(path.to_string_lossy().into_owned(), String::new(), 100);
        let _ = std::fs::remove_file(&path);

        assert!(
            result.expect("search temporary TXT file").is_empty(),
            "empty queries must not produce zero-length matches"
        );
    }

    #[test]
    fn asset_lookup_matches_the_entry_basename_not_an_arbitrary_suffix() {
        let mut bytes = Cursor::new(Vec::new());
        let mut writer = zip::ZipWriter::new(&mut bytes);
        let options = zip::write::FileOptions::<()>::default()
            .compression_method(zip::CompressionMethod::Stored);
        writer
            .start_file("word/media/notimage1.png", options)
            .expect("start colliding asset");
        writer.write_all(b"wrong").expect("write colliding asset");
        writer
            .start_file("word/media/image1.png", options)
            .expect("start requested asset");
        writer.write_all(b"correct").expect("write requested asset");
        writer.finish().expect("finish archive");

        let archive_bytes = bytes.into_inner();
        let mut archive = crate::book::archive::decode_zip(&archive_bytes).expect("open archive");

        assert_eq!(
            read_archive_asset(&mut archive, "image1.png").expect("load requested asset"),
            b"correct",
        );
    }
}

#[cfg(test)]
mod extract_metadata_tests {
    use super::extract_metadata;

    #[test]
    fn metadata_extraction_preserves_raw_fb2_genre_codes() {
        let path = std::env::temp_dir().join(format!(
            "glibusta-fb2-metadata-genres-{}.fb2",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(
            &path,
            br#"<FictionBook><description><title-info><book-title>Genres</book-title><genre>sf_history</genre><genre>custom-unmapped</genre></title-info></description><body><section><p>Content</p></section></body></FictionBook>"#,
        )
        .expect("write FB2 metadata fixture");

        let result = extract_metadata(path.to_string_lossy().into_owned());
        let _ = std::fs::remove_file(path);
        let metadata = result.expect("extract FB2 metadata");

        assert_eq!(metadata.genres, ["sf_history", "custom-unmapped"]);
    }
}
