use std::cmp::Ordering;
use std::io::Read;
use std::path::Path;

use anyhow::{Context, Result, bail};
use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use quick_xml::Reader;
use quick_xml::events::Event;
use sha2::{Digest, Sha256};
use unrar_ng::Archive;
use unrar_ng::error::{Code as UnrarErrorCode, UnrarError, When as UnrarErrorWhen};

use crate::api::models::{
    BlockType, BookFormat, MAX_COMPRESSION_RATIO, MAX_EXTRACTED_FILES, MAX_FILE_SIZE,
    MAX_IMAGE_SIZE, NormalizedBook, ReaderBlock, ReaderChapter,
};

const IMAGE_EXTENSIONS: &[&str] = &["jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff"];
const MAX_COMIC_INFO_BYTES: u64 = 1024 * 1024;

/// Parse a CBR archive from its path. UnRAR can only operate on filesystem paths.
pub fn parse_cbr_path(path: &Path) -> Result<NormalizedBook> {
    let metadata = std::fs::metadata(path)
        .with_context(|| format!("Failed to read CBR file metadata: {}", path.display()))?;
    if metadata.len() > MAX_FILE_SIZE {
        bail!(
            "CBR exceeds maximum file size of {} MiB",
            MAX_FILE_SIZE / 1024 / 1024
        );
    }
    let id = cbr_content_id(path)?;

    let mut archive = Archive::new(path).open_for_processing().map_err(|error| {
        cbr_unrar_error(
            format!("Failed to open CBR archive: {}", path.display()),
            error,
        )
    })?;
    let mut entry_count = 0usize;
    let mut total_uncompressed_size = 0u64;
    let mut images = Vec::new();
    let mut comic_info = None;

    loop {
        let Some(entry) = archive
            .read_header()
            .map_err(|error| cbr_unrar_error("Failed to read CBR entry header", error))?
        else {
            break;
        };
        entry_count = entry_count.saturating_add(1);
        if entry_count > MAX_EXTRACTED_FILES {
            bail!(
                "CBR has too many entries: {} (max {})",
                entry_count,
                MAX_EXTRACTED_FILES
            );
        }

        let entry_name = entry.entry().filename.to_string_lossy().into_owned();
        let entry_size = entry.entry().unpacked_size;
        total_uncompressed_size = total_uncompressed_size
            .checked_add(entry_size)
            .context("CBR decompressed size overflow")?;
        if total_uncompressed_size > MAX_FILE_SIZE {
            bail!(
                "CBR exceeds maximum decompressed size of {} MiB",
                MAX_FILE_SIZE / 1024 / 1024
            );
        }
        if total_uncompressed_size > metadata.len().saturating_mul(MAX_COMPRESSION_RATIO) {
            bail!(
                "CBR exceeds maximum compression ratio of {}:1",
                MAX_COMPRESSION_RATIO
            );
        }
        if entry_name
            .rsplit(['/', '\\'])
            .next()
            .is_some_and(|name| name.eq_ignore_ascii_case("ComicInfo.xml"))
            && entry.entry().is_file()
        {
            if entry_size <= MAX_COMIC_INFO_BYTES {
                let (bytes, next_archive) = entry
                    .read()
                    .map_err(|error| cbr_unrar_error("Failed to extract ComicInfo.xml", error))?;
                comic_info = parse_comic_info(&bytes);
                archive = next_archive;
            } else {
                archive = entry.skip().map_err(|error| {
                    cbr_unrar_error("Failed to skip oversized ComicInfo.xml", error)
                })?;
            }
            continue;
        }

        let Some(media_type) = image_media_type(&entry_name).filter(|_| entry.entry().is_file())
        else {
            archive = entry
                .skip()
                .map_err(|error| cbr_unrar_error("Failed to skip CBR entry", error))?;
            continue;
        };
        if entry_size > MAX_IMAGE_SIZE as u64 {
            bail!(
                "CBR image '{}' exceeds maximum size of {} MiB",
                entry_name,
                MAX_IMAGE_SIZE / 1024 / 1024
            );
        }

        let (bytes, next_archive) = entry
            .read()
            .map_err(|error| cbr_unrar_error("Failed to extract CBR image", error))?;
        if bytes.len() > MAX_IMAGE_SIZE {
            bail!(
                "CBR image '{}' exceeds maximum size after extraction",
                entry_name
            );
        }
        images.push((entry_name, media_type, bytes));
        archive = next_archive;
    }

    if images.is_empty() {
        bail!("CBR archive contains no supported images");
    }
    images.sort_unstable_by(|left, right| natural_cmp(&left.0, &right.0));

    let blocks = images
        .into_iter()
        .enumerate()
        .map(|(index, (_, media_type, bytes))| ReaderBlock {
            index: index as i32,
            text: String::new(),
            block_type: BlockType::Image,
            image_url: Some(format!(
                "data:{media_type};base64,{}",
                STANDARD.encode(bytes)
            )),
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
        })
        .collect::<Vec<_>>();
    let cover_url = first_image_cover(&blocks);

    let fallback_title = path
        .file_stem()
        .and_then(|name| name.to_str())
        .filter(|name| !name.trim().is_empty())
        .unwrap_or("CBR");
    let title = comic_info
        .as_ref()
        .and_then(|info| info.title.clone())
        .unwrap_or_else(|| fallback_title.to_owned());
    let authors = comic_info
        .as_ref()
        .and_then(|info| info.authors.clone())
        .unwrap_or_default();
    let comic_metadata = comic_info.as_ref().and_then(ComicInfo::metadata);

    Ok(NormalizedBook {
        id,
        title,
        authors,
        description: None,
        cover_url,
        chapters: vec![ReaderChapter {
            index: 0,
            title: "Pages".to_owned(),
            blocks,
        }],
        metadata: comic_metadata,
        book_format: BookFormat::Cbr,
        language: None,
        warnings: Vec::new(),
        images: Vec::new(),
        toc: Vec::new(),
    })
}

/// Hash the archive contents without materializing the complete CBR in memory.
///
/// Unlike the other parsers this path is handed directly to UnRAR, so its stable
/// book ID must be derived from the file rather than from the filesystem path.
fn cbr_content_id(path: &Path) -> Result<String> {
    let mut file = std::fs::File::open(path)
        .with_context(|| format!("Failed to open CBR for hashing: {}", path.display()))?;
    let mut hasher = Sha256::new();
    let mut buffer = [0_u8; 64 * 1024];

    loop {
        let read = file
            .read(&mut buffer)
            .with_context(|| format!("Failed to read CBR for hashing: {}", path.display()))?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
    }

    Ok(format!("{:x}", hasher.finalize()))
}

fn cbr_unrar_error(context: impl Into<String>, error: UnrarError) -> anyhow::Error {
    if matches!(
        error.code,
        UnrarErrorCode::MissingPassword | UnrarErrorCode::BadPassword
    ) {
        return anyhow::anyhow!("CBR archive is encrypted and cannot be opened without a password");
    }
    if error.code == UnrarErrorCode::EOpen && error.when == UnrarErrorWhen::Process {
        return anyhow::anyhow!("CBR archive is incomplete: a required volume is missing");
    }

    anyhow::Error::new(error).context(context.into())
}

fn first_image_cover(blocks: &[ReaderBlock]) -> Option<String> {
    blocks
        .iter()
        .find(|block| block.block_type == BlockType::Image)
        .and_then(|block| block.image_url.clone())
}

#[derive(Default)]
struct ComicInfo {
    title: Option<String>,
    authors: Option<Vec<String>>,
    series: Option<String>,
    number: Option<String>,
}

impl ComicInfo {
    fn metadata(&self) -> Option<serde_json::Value> {
        let mut metadata = serde_json::Map::new();
        if let Some(series) = &self.series {
            metadata.insert(
                "series".to_owned(),
                serde_json::Value::String(series.clone()),
            );
        }
        if let Some(number) = &self.number {
            metadata.insert(
                "number".to_owned(),
                serde_json::Value::String(number.clone()),
            );
        }
        (!metadata.is_empty()).then_some(serde_json::Value::Object(metadata))
    }
}

fn parse_comic_info(bytes: &[u8]) -> Option<ComicInfo> {
    let text = decode_comic_info(bytes)?;
    let mut reader = Reader::from_str(&text);
    reader.config_mut().trim_text(true);
    let mut info = ComicInfo::default();
    let mut field = None;

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(element)) => {
                field = match element.local_name().as_ref() {
                    b"Title" => Some("title"),
                    b"Writer" => Some("writer"),
                    b"Series" => Some("series"),
                    b"Number" => Some("number"),
                    _ => None,
                };
            }
            Ok(Event::Text(value)) => {
                let value = value.xml10_content().ok()?.trim().to_owned();
                if value.is_empty() {
                    continue;
                }
                match field {
                    Some("title") => info.title = Some(value),
                    Some("writer") => {
                        let authors = value
                            .split([',', ';'])
                            .map(str::trim)
                            .filter(|author| !author.is_empty())
                            .map(str::to_owned)
                            .collect::<Vec<_>>();
                        if !authors.is_empty() {
                            info.authors = Some(authors);
                        }
                    }
                    Some("series") => info.series = Some(value),
                    Some("number") => info.number = Some(value),
                    _ => {}
                }
            }
            Ok(Event::End(_)) => field = None,
            Err(_) => return None,
            _ => {}
        }
    }

    Some(info)
}

fn decode_comic_info(bytes: &[u8]) -> Option<String> {
    let (bytes, big_endian) = match bytes {
        [0xFF, 0xFE, rest @ ..] => (rest, false),
        [0xFE, 0xFF, rest @ ..] => (rest, true),
        _ => return std::str::from_utf8(bytes).ok().map(str::to_owned),
    };
    if bytes.len() % 2 != 0 {
        return None;
    }
    let code_units = bytes
        .chunks_exact(2)
        .map(|pair| {
            if big_endian {
                u16::from_be_bytes([pair[0], pair[1]])
            } else {
                u16::from_le_bytes([pair[0], pair[1]])
            }
        })
        .collect::<Vec<_>>();
    String::from_utf16(&code_units).ok()
}

fn image_media_type(path: &str) -> Option<&'static str> {
    let extension = path.rsplit_once('.')?.1.to_ascii_lowercase();
    if !IMAGE_EXTENSIONS.contains(&extension.as_str()) {
        return None;
    }
    Some(match extension.as_str() {
        "jpg" | "jpeg" => "image/jpeg",
        "png" => "image/png",
        "gif" => "image/gif",
        "webp" => "image/webp",
        "bmp" => "image/bmp",
        "tiff" => "image/tiff",
        _ => unreachable!("extension was checked against IMAGE_EXTENSIONS"),
    })
}

fn natural_cmp(left: &str, right: &str) -> Ordering {
    let left = left.as_bytes();
    let right = right.as_bytes();
    let (mut left_index, mut right_index) = (0, 0);

    while left_index < left.len() && right_index < right.len() {
        let left_digit = left[left_index].is_ascii_digit();
        let right_digit = right[right_index].is_ascii_digit();
        if left_digit && right_digit {
            let left_start = left_index;
            let right_start = right_index;
            while left_index < left.len() && left[left_index].is_ascii_digit() {
                left_index += 1;
            }
            while right_index < right.len() && right[right_index].is_ascii_digit() {
                right_index += 1;
            }
            let left_number = trim_leading_zeroes(&left[left_start..left_index]);
            let right_number = trim_leading_zeroes(&right[right_start..right_index]);
            let ordering = left_number
                .len()
                .cmp(&right_number.len())
                .then_with(|| left_number.cmp(right_number))
                .then_with(|| (left_index - left_start).cmp(&(right_index - right_start)));
            if ordering != Ordering::Equal {
                return ordering;
            }
        } else {
            let ordering = left[left_index]
                .to_ascii_lowercase()
                .cmp(&right[right_index].to_ascii_lowercase());
            if ordering != Ordering::Equal {
                return ordering;
            }
            left_index += 1;
            right_index += 1;
        }
    }

    left.len().cmp(&right.len())
}

fn trim_leading_zeroes(number: &[u8]) -> &[u8] {
    let first_non_zero = number
        .iter()
        .position(|byte| *byte != b'0')
        .unwrap_or(number.len().saturating_sub(1));
    &number[first_non_zero..]
}

#[cfg(test)]
mod tests {
    use super::{
        cbr_content_id, cbr_unrar_error, first_image_cover, image_media_type, natural_cmp,
        parse_cbr_path, parse_comic_info,
    };
    use crate::api::models::{BlockType, ReaderBlock};
    use std::cmp::Ordering;
    use unrar_ng::error::{Code as UnrarErrorCode, UnrarError, When as UnrarErrorWhen};

    // Minimal valid RAR4 archive from UnRAR's own test corpus. It contains a
    // `VERSION` file, not a comic page.
    const RAR4_ARCHIVE: &[u8] = &[
        0x52, 0x61, 0x72, 0x21, 0x1a, 0x07, 0x00, 0xcf, 0x90, 0x73, 0x00, 0x00, 0x0d, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x0f, 0x0c, 0x74, 0x20, 0x80, 0x27, 0x00, 0x15, 0x00, 0x00,
        0x00, 0x0b, 0x00, 0x00, 0x00, 0x03, 0x45, 0xf3, 0x7d, 0xc6, 0xa4, 0x8a, 0x07, 0x47, 0x1d,
        0x33, 0x07, 0x00, 0xa4, 0x81, 0x00, 0x00, 0x56, 0x45, 0x52, 0x53, 0x49, 0x4f, 0x4e, 0x0c,
        0x00, 0x8f, 0xec, 0x8a, 0x45, 0xcc, 0x23, 0xc8, 0x48, 0x08, 0x83, 0x62, 0xfe, 0x5f, 0xdd,
        0x5c, 0x53, 0x88, 0xf0, 0x72, 0xc4, 0x3d, 0x7b, 0x00, 0x40, 0x07, 0x00,
    ];
    // RAR5 marker followed by an intentionally incomplete main header.  This
    // is not presented as a valid RAR5/solid fixture; it only exercises the
    // native parser's damaged-RAR5 error path without an external RAR writer.
    const TRUNCATED_RAR5_HEADER: &[u8] = b"Rar!\x1a\x07\x01\x00\x00";

    #[test]
    fn recognizes_supported_image_extensions_case_insensitively() {
        assert_eq!(image_media_type("pages/001.JPEG"), Some("image/jpeg"));
        assert_eq!(image_media_type("pages/002.webp"), Some("image/webp"));
        assert_eq!(image_media_type("notes.txt"), None);
    }

    #[test]
    fn sorts_page_names_naturally() {
        assert_eq!(natural_cmp("pages/2.jpg", "pages/10.jpg"), Ordering::Less);
        assert_eq!(
            natural_cmp("pages/001.jpg", "pages/1.jpg"),
            Ordering::Greater
        );
    }

    #[test]
    fn derives_cbr_id_from_contents_instead_of_its_path() {
        let directory =
            std::env::temp_dir().join(format!("glibusta-cbr-id-{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&directory).expect("create CBR id test directory");
        let first = directory.join("first.cbr");
        let second = directory.join("second.cbr");
        std::fs::write(&first, b"same archive contents").expect("write first CBR");
        std::fs::write(&second, b"same archive contents").expect("write second CBR");

        let first_id = cbr_content_id(&first).expect("hash first CBR");
        let second_id = cbr_content_id(&second).expect("hash second CBR");
        std::fs::write(&second, b"replaced archive contents").expect("replace second CBR");
        let replaced_id = cbr_content_id(&second).expect("hash replaced CBR");
        let _ = std::fs::remove_dir_all(directory);

        assert_eq!(first_id, second_id);
        assert_ne!(first_id, replaced_id);
        assert_eq!(first_id.len(), 64);
    }

    #[test]
    fn classifies_missing_cbr_password_as_a_controlled_error() {
        let error = cbr_unrar_error(
            "Failed to open CBR archive",
            UnrarError::from(UnrarErrorCode::MissingPassword, UnrarErrorWhen::Open),
        );

        assert_eq!(
            error.to_string(),
            "CBR archive is encrypted and cannot be opened without a password"
        );
    }

    #[test]
    fn classifies_a_missing_cbr_volume_as_a_controlled_error() {
        let error = cbr_unrar_error(
            "Failed to extract CBR image",
            UnrarError::from(UnrarErrorCode::EOpen, UnrarErrorWhen::Process),
        );

        assert_eq!(
            error.to_string(),
            "CBR archive is incomplete: a required volume is missing"
        );
    }

    #[test]
    fn parses_comic_info_metadata() {
        let info = parse_comic_info(
            br#"<ComicInfo><Title>Comic</Title><Writer>A; B</Writer><Series>Series</Series><Number>7</Number></ComicInfo>"#,
        )
        .expect("parse ComicInfo.xml");

        assert_eq!(info.title.as_deref(), Some("Comic"));
        assert_eq!(
            info.authors.as_deref(),
            Some(["A".to_string(), "B".to_string()].as_slice())
        );
        assert_eq!(
            info.metadata(),
            Some(serde_json::json!({"series": "Series", "number": "7"}))
        );
    }

    #[test]
    fn parses_utf8_bom_comic_info_metadata() {
        let bytes = b"\xEF\xBB\xBF<ComicInfo><Title>\xD0\x9A\xD0\xBE\xD0\xBC\xD0\xB8\xD0\xBA\xD1\x81</Title><Writer>\xD0\x90\xD0\xB2\xD1\x82\xD0\xBE\xD1\x80</Writer></ComicInfo>";

        let info = parse_comic_info(bytes).expect("parse UTF-8 BOM ComicInfo.xml");

        assert_eq!(info.title.as_deref(), Some("Комикс"));
        assert_eq!(
            info.authors.as_deref(),
            Some([String::from("Автор")].as_slice())
        );
    }

    #[test]
    fn parses_utf16le_comic_info_metadata() {
        let xml = "<ComicInfo><Title>Комикс</Title><Writer>Автор</Writer></ComicInfo>";
        let mut bytes = vec![0xFF, 0xFE];
        bytes.extend(xml.encode_utf16().flat_map(u16::to_le_bytes));

        let info = parse_comic_info(&bytes).expect("parse UTF-16 ComicInfo.xml");

        assert_eq!(info.title.as_deref(), Some("Комикс"));
        assert_eq!(
            info.authors.as_deref(),
            Some([String::from("Автор")].as_slice())
        );
    }

    #[test]
    fn parses_utf16be_comic_info_metadata() {
        let xml = "<ComicInfo><Title>Comic</Title></ComicInfo>";
        let mut bytes = vec![0xFE, 0xFF];
        bytes.extend(xml.encode_utf16().flat_map(u16::to_be_bytes));

        let info = parse_comic_info(&bytes).expect("parse UTF-16 ComicInfo.xml");

        assert_eq!(info.title.as_deref(), Some("Comic"));
    }

    #[test]
    fn uses_the_first_comic_page_as_the_cover() {
        let blocks = vec![ReaderBlock {
            index: 0,
            text: String::new(),
            block_type: BlockType::Image,
            image_url: Some("data:image/png;base64,cGFnZQ==".to_owned()),
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
        }];

        assert_eq!(
            first_image_cover(&blocks).as_deref(),
            Some("data:image/png;base64,cGFnZQ==")
        );
    }

    #[test]
    #[cfg_attr(
        miri,
        ignore = "UnRAR is a native C++ dependency that Miri cannot execute"
    )]
    fn rejects_a_non_rar_file_without_crashing_the_native_parser() {
        let path =
            std::env::temp_dir().join(format!("glibusta-invalid-cbr-{}.cbr", uuid::Uuid::new_v4()));
        std::fs::write(&path, b"not a RAR archive").expect("write invalid CBR fixture");

        let result = parse_cbr_path(&path);
        let _ = std::fs::remove_file(path);

        assert!(result.is_err());
    }

    #[test]
    #[cfg_attr(
        miri,
        ignore = "UnRAR is a native C++ dependency that Miri cannot execute"
    )]
    fn reads_a_rar4_archive_before_rejecting_non_image_contents() {
        let path =
            std::env::temp_dir().join(format!("glibusta-rar4-cbr-{}.cbr", uuid::Uuid::new_v4()));
        std::fs::write(&path, RAR4_ARCHIVE).expect("write RAR4 fixture");

        let result = parse_cbr_path(&path);
        let _ = std::fs::remove_file(path);

        assert!(matches!(result, Err(error) if error.to_string().contains("no supported images")));
    }

    #[test]
    #[cfg_attr(
        miri,
        ignore = "UnRAR is a native C++ dependency that Miri cannot execute"
    )]
    fn rejects_a_truncated_rar4_archive_without_panicking() {
        // Truncate the known-good RAR4 fixture inside its only file payload.
        // This needs no archive-creation binary and exercises UnRAR's damaged
        // archive path through the same streaming parser used for CBR imports.
        let damaged = &RAR4_ARCHIVE[..RAR4_ARCHIVE.len() - 8];
        let path = std::env::temp_dir().join(format!(
            "glibusta-truncated-rar4-cbr-{}.cbr",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(&path, damaged).expect("write truncated RAR4 fixture");

        let result = parse_cbr_path(&path);
        let _ = std::fs::remove_file(path);

        assert!(result.is_err(), "truncated RAR4 archive must be rejected");
    }

    #[test]
    #[cfg_attr(
        miri,
        ignore = "UnRAR is a native C++ dependency that Miri cannot execute"
    )]
    fn rejects_a_truncated_rar5_header_without_panicking() {
        let path = std::env::temp_dir().join(format!(
            "glibusta-truncated-rar5-cbr-{}.cbr",
            uuid::Uuid::new_v4()
        ));
        std::fs::write(&path, TRUNCATED_RAR5_HEADER).expect("write truncated RAR5 header fixture");

        let result = parse_cbr_path(&path);
        let _ = std::fs::remove_file(path);

        assert!(result.is_err(), "truncated RAR5 archive must be rejected");
    }
}
